--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local FactoryRules = require(ReplicatedStorage.Shared.Domain.FactoryRules)
local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local RemoteNames = require(ReplicatedStorage.Shared.Networking.RemoteNames)
local Robots = require(ReplicatedStorage.Shared.Config.Robots)
local Validation = require(ReplicatedStorage.Shared.Util.Validation)

local AnalyticsService = require(script.Parent.AnalyticsService)
local DataService = require(script.Parent.DataService)
local EconomyService = require(script.Parent.EconomyService)
local RemoteService = require(script.Parent.RemoteService)
local StateService = require(script.Parent.StateService)

local RobotService = {}
local initialized = false

local function result(success: boolean, code: string, payload: any?): any
	return {
		Success = success,
		Code = code,
		Payload = payload,
	}
end

local function validString(value: any): boolean
	return Validation.isBoundedString(value, GameConfig.Networking.MaxStringLength)
end

local function parsePadIndex(padId: string): number?
	local match = string.match(padId, "^Pad(%d+)$")
	if match == nil then
		return nil
	end
	local index = tonumber(match)
	if index == nil or index % 1 ~= 0 then
		return nil
	end
	return index
end

local function findAssignedPad(workPads: any, robotUid: string): string?
	for padId, assignedUid in workPads do
		if assignedUid == robotUid then
			return padId
		end
	end
	return nil
end

local function sendResult(
	player: Player,
	actionName: string,
	executed: boolean,
	transactionResult: any?
)
	if not executed then
		StateService.ActionResult(player, actionName, false, tostring(transactionResult), nil)
		return
	end
	if typeof(transactionResult) ~= "table" then
		StateService.ActionResult(player, actionName, false, "INVALID_TRANSACTION_RESULT", nil)
		return
	end

	StateService.ActionResult(
		player,
		actionName,
		transactionResult.Success == true,
		tostring(transactionResult.Code),
		transactionResult.Payload
	)
	if transactionResult.Success == true then
		StateService.PushSnapshot(player)
	end
end

function RobotService.Assign(player: Player, robotUid: any, padId: any)
	if not validString(robotUid) or not validString(padId) then
		StateService.ActionResult(
			player,
			RemoteNames.RequestAssignRobot,
			false,
			"INVALID_ASSIGNMENT",
			nil
		)
		return
	end

	local padIndex = parsePadIndex(padId)
	if padIndex == nil then
		StateService.ActionResult(
			player,
			RemoteNames.RequestAssignRobot,
			false,
			"UNKNOWN_WORK_PAD",
			nil
		)
		return
	end

	local executed, transactionResult = DataService.Transaction(player, function(data)
		local robot = data.Robots.OwnedByUid[robotUid]
		if robot == nil then
			return false, result(false, "ROBOT_NOT_OWNED", nil)
		end

		local unlockedSlots = FactoryRules.GetWorkSlots(data.Machines.WorkSlotsLevel)
		if padIndex > unlockedSlots then
			return false, result(false, "WORK_PAD_LOCKED", { UnlockedSlots = unlockedSlots })
		end

		local workPads = data.Assignments.WorkPads
		if findAssignedPad(workPads, robotUid) ~= nil then
			return false, result(false, "ROBOT_ALREADY_ASSIGNED", nil)
		end
		if workPads[padId] ~= nil then
			return false, result(false, "WORK_PAD_OCCUPIED", nil)
		end

		workPads[padId] = robotUid
		data.Tutorial.Milestones.FirstBotAssigned = true
		return true, result(true, "ROBOT_ASSIGNED", {
			RobotUid = robotUid,
			PadId = padId,
		})
	end)

	sendResult(player, RemoteNames.RequestAssignRobot, executed, transactionResult)
end

function RobotService.Unassign(player: Player, robotUid: any)
	if not validString(robotUid) then
		StateService.ActionResult(
			player,
			RemoteNames.RequestUnassignRobot,
			false,
			"INVALID_ROBOT_UID",
			nil
		)
		return
	end

	local executed, transactionResult = DataService.Transaction(player, function(data)
		if data.Robots.OwnedByUid[robotUid] == nil then
			return false, result(false, "ROBOT_NOT_OWNED", nil)
		end

		local padId = findAssignedPad(data.Assignments.WorkPads, robotUid)
		if padId == nil then
			return false, result(false, "ROBOT_NOT_ASSIGNED", nil)
		end

		data.Assignments.WorkPads[padId] = nil
		return true,
			result(true, "ROBOT_UNASSIGNED", {
				RobotUid = robotUid,
				PadId = padId,
			})
	end)

	sendResult(player, RemoteNames.RequestUnassignRobot, executed, transactionResult)
end

function RobotService.Sell(player: Player, robotUid: any)
	if not validString(robotUid) then
		StateService.ActionResult(
			player,
			RemoteNames.RequestSellRobot,
			false,
			"INVALID_ROBOT_UID",
			nil
		)
		return
	end

	local executed, transactionResult = DataService.Transaction(player, function(data)
		local robot = data.Robots.OwnedByUid[robotUid]
		if robot == nil then
			return false, result(false, "ROBOT_NOT_OWNED", nil)
		end
		if findAssignedPad(data.Assignments.WorkPads, robotUid) ~= nil then
			return false, result(false, "ROBOT_IS_ASSIGNED", nil)
		end

		local definition = Robots.Definitions[robot.RobotId]
		if definition == nil then
			return false, result(false, "UNKNOWN_ROBOT_DEFINITION", nil)
		end

		local granted = EconomyService.GrantCredits(data, definition.RecycleCredits)
		if granted <= 0 then
			return false, result(false, "CREDIT_CAP_REACHED", nil)
		end

		data.Robots.OwnedByUid[robotUid] = nil
		return true,
			result(true, "ROBOT_RECYCLED", {
				RobotUid = robotUid,
				Credits = granted,
			})
	end)

	if executed and typeof(transactionResult) == "table" and transactionResult.Success == true then
		local payload = transactionResult.Payload
		local updatedData = DataService.GetData(player)
		if
			typeof(payload) == "table"
			and typeof(payload.Credits) == "number"
			and updatedData ~= nil
		then
			AnalyticsService.RecordCreditSource(
				player,
				"RobotRecycle",
				payload.Credits,
				updatedData.Currencies.Credits
			)
		end
	end

	sendResult(player, RemoteNames.RequestSellRobot, executed, transactionResult)
end

function RobotService.Init()
	if initialized then
		return
	end
	initialized = true

	RemoteService.BindRequest(RemoteNames.RequestAssignRobot, function(player, robotUid, padId)
		RobotService.Assign(player, robotUid, padId)
	end)
	RemoteService.BindRequest(RemoteNames.RequestUnassignRobot, function(player, robotUid)
		RobotService.Unassign(player, robotUid)
	end)
	RemoteService.BindRequest(RemoteNames.RequestSellRobot, function(player, robotUid)
		RobotService.Sell(player, robotUid)
	end)
end

return RobotService
