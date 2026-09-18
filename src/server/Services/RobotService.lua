--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AssignmentRules = require(ReplicatedStorage.Shared.Domain.AssignmentRules)
local FactoryRules = require(ReplicatedStorage.Shared.Domain.FactoryRules)
local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local RemoteNames = require(ReplicatedStorage.Shared.Networking.RemoteNames)
local Robots = require(ReplicatedStorage.Shared.Config.Robots)
local Validation = require(ReplicatedStorage.Shared.Util.Validation)

local AnalyticsService = require(script.Parent.AnalyticsService)
local DataService = require(script.Parent.DataService)
local EconomyService = require(script.Parent.EconomyService)
local MonetizationService = require(script.Parent.MonetizationService)
local PlotService = require(script.Parent.PlotService)
local RemoteService = require(script.Parent.RemoteService)
local StateService = require(script.Parent.StateService)
local PlayerCharacter = require(script.Parent.Parent.Util.PlayerCharacter)

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

local function isNear(player: Player, part: BasePart): boolean
	return PlayerCharacter.IsNear(player, part, GameConfig.World.InteractionDistance)
end

local function requireStation(player: Player, actionName: string, station: BasePart?): boolean
	local console = station
	if console == nil then
		StateService.ActionResult(player, actionName, false, "NO_FACTORY_PLOT", nil)
		return false
	end
	if not isNear(player, console) then
		StateService.ActionResult(player, actionName, false, "TOO_FAR_AWAY", nil)
		return false
	end
	return true
end

local function requireBotConsole(player: Player, actionName: string): boolean
	return requireStation(player, actionName, PlotService.GetBotConsole(player))
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
	if not requireBotConsole(player, RemoteNames.RequestAssignRobot) then
		return
	end

	local executed, transactionResult = DataService.Transaction(player, function(data)
		local baseSlots = FactoryRules.GetWorkSlots(data.Machines.WorkSlotsLevel)
		local unlockedSlots = math.min(
			GameConfig.Factory.MaxWorkSlots + 2,
			baseSlots + MonetizationService.GetExtraWorkSlots(player)
		)
		local decision = AssignmentRules.EvaluateAssignment(
			data.Assignments.WorkPads,
			data.Robots.OwnedByUid,
			robotUid,
			padId,
			unlockedSlots
		)
		if not decision.Allowed then
			local payload = if decision.Code == "WORK_PAD_LOCKED"
				then { UnlockedSlots = unlockedSlots }
				else nil
			return false, result(false, decision.Code, payload)
		end

		data.Assignments.WorkPads[padId] = robotUid
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
	if not requireBotConsole(player, RemoteNames.RequestUnassignRobot) then
		return
	end

	local executed, transactionResult = DataService.Transaction(player, function(data)
		if data.Robots.OwnedByUid[robotUid] == nil then
			return false, result(false, "ROBOT_NOT_OWNED", nil)
		end

		local padId = AssignmentRules.FindAssignedPad(data.Assignments.WorkPads, robotUid)
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
	local botConsole = PlotService.GetBotConsole(player)
	local recycleStation = PlotService.GetRecycleStation(player)
	if botConsole == nil or recycleStation == nil then
		StateService.ActionResult(
			player,
			RemoteNames.RequestSellRobot,
			false,
			"NO_FACTORY_PLOT",
			nil
		)
		return
	end
	if not isNear(player, botConsole) and not isNear(player, recycleStation) then
		StateService.ActionResult(player, RemoteNames.RequestSellRobot, false, "TOO_FAR_AWAY", nil)
		return
	end

	local executed, transactionResult = DataService.Transaction(player, function(data)
		local robot = data.Robots.OwnedByUid[robotUid]
		if robot == nil then
			return false, result(false, "ROBOT_NOT_OWNED", nil)
		end
		if AssignmentRules.FindAssignedPad(data.Assignments.WorkPads, robotUid) ~= nil then
			return false, result(false, "ROBOT_IS_ASSIGNED", nil)
		end

		local definition = Robots.Definitions[robot.RobotId]
		if definition == nil then
			return false, result(false, "UNKNOWN_ROBOT_DEFINITION", nil)
		end
		if not EconomyService.GrantCreditsExact(data, definition.RecycleCredits) then
			return false, result(false, "CREDIT_CAP_WOULD_TRUNCATE", nil)
		end

		data.Robots.OwnedByUid[robotUid] = nil
		return true,
			result(true, "ROBOT_RECYCLED", {
				RobotUid = robotUid,
				Credits = definition.RecycleCredits,
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
