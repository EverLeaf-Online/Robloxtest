--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local FactoryRules = require(ReplicatedStorage.Shared.Domain.FactoryRules)
local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local Recipes = require(ReplicatedStorage.Shared.Config.Recipes)
local RemoteNames = require(ReplicatedStorage.Shared.Networking.RemoteNames)
local RobotInventoryRules = require(ReplicatedStorage.Shared.Domain.RobotInventoryRules)
local Robots = require(ReplicatedStorage.Shared.Config.Robots)
local Validation = require(ReplicatedStorage.Shared.Util.Validation)

local DataService = require(script.Parent.DataService)
local EconomyService = require(script.Parent.EconomyService)
local PlotService = require(script.Parent.PlotService)
local RateLimiter = require(script.Parent.RateLimiter)
local RemoteService = require(script.Parent.RemoteService)
local StateService = require(script.Parent.StateService)
local WorldService = require(script.Parent.WorldService)

local MachineService = {}
local initialized = false
local random = Random.new()

local function resetProcessorJob(job: any)
	job.Active = false
	job.RecipeId = ""
	job.StartedAt = 0
	job.CompletesAt = 0
end

local function resetAssemblerJob(job: any)
	job.Active = false
	job.StartedAt = 0
	job.CompletesAt = 0
end

local function ownedRobotCount(data: any): number
	local count = 0
	for _ in data.Robots.OwnedByUid do
		count += 1
	end
	return count
end

local function result(success: boolean, code: string, payload: any?): any
	return {
		Success = success,
		Code = code,
		Payload = payload,
	}
end

local function playerPosition(player: Player): Vector3?
	local character = player.Character
	if character == nil then
		return nil
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	if root == nil or not root:IsA("BasePart") then
		return nil
	end
	return root.Position
end

local function isNear(player: Player, part: BasePart): boolean
	local position = playerPosition(player)
	return position ~= nil
		and (position - part.Position).Magnitude <= GameConfig.World.InteractionDistance
end

local function sendTransactionResult(
	player: Player,
	actionName: string,
	executed: boolean,
	transactionResult: any?
)
	if not executed then
		StateService.ActionResult(player, actionName, false, tostring(transactionResult), nil)
		return
	end

	local actionResult = transactionResult
	if typeof(actionResult) ~= "table" then
		StateService.ActionResult(player, actionName, false, "INVALID_TRANSACTION_RESULT", nil)
		return
	end

	StateService.ActionResult(
		player,
		actionName,
		actionResult.Success == true,
		tostring(actionResult.Code),
		actionResult.Payload
	)
	if actionResult.Success == true then
		StateService.PushSnapshot(player)
	end
end

function MachineService.StartProcessor(player: Player, recipeId: any)
	if not Validation.isBoundedString(recipeId, GameConfig.Networking.MaxStringLength) then
		StateService.ActionResult(
			player,
			RemoteNames.RequestProcess,
			false,
			"INVALID_RECIPE_ID",
			nil
		)
		return
	end

	local recipe = Recipes.Processor[recipeId]
	if recipe == nil then
		StateService.ActionResult(player, RemoteNames.RequestProcess, false, "UNKNOWN_RECIPE", nil)
		return
	end

	local control = PlotService.GetProcessorControl(player, recipeId)
	if control == nil then
		StateService.ActionResult(player, RemoteNames.RequestProcess, false, "NO_FACTORY_PLOT", nil)
		return
	end
	if not isNear(player, control) then
		StateService.ActionResult(player, RemoteNames.RequestProcess, false, "TOO_FAR_AWAY", nil)
		return
	end

	local executed, transactionResult = DataService.Transaction(player, function(data)
		local job = data.Machines.ProcessorJob
		if job.Active then
			return false, result(false, "PROCESSOR_BUSY", { CompletesAt = job.CompletesAt })
		end
		if not EconomyService.CanAffordMaterials(data, recipe.Input) then
			return false, result(false, "MISSING_MATERIALS", nil)
		end
		if not EconomyService.CanFitTransaction(data, recipe.Input, recipe.Output) then
			return false, result(false, "STORAGE_FULL", nil)
		end

		assert(
			EconomyService.SpendMaterials(data, recipe.Input),
			"validated processor cost must be spendable"
		)
		local startedAt = os.time()
		local duration =
			math.max(1, math.ceil(FactoryRules.GetProcessorSeconds(data.Machines.ProcessorLevel)))
		job.Active = true
		job.RecipeId = recipe.Id
		job.StartedAt = startedAt
		job.CompletesAt = startedAt + duration

		return true,
			result(true, "PROCESS_STARTED", {
				RecipeId = recipe.Id,
				CompletesAt = job.CompletesAt,
			})
	end)

	sendTransactionResult(player, RemoteNames.RequestProcess, executed, transactionResult)
end

function MachineService.StartAssembler(player: Player)
	local assembler = PlotService.GetAssembler(player)
	if assembler == nil then
		StateService.ActionResult(
			player,
			RemoteNames.RequestAssemble,
			false,
			"NO_FACTORY_PLOT",
			nil
		)
		return
	end
	if not isNear(player, assembler) then
		StateService.ActionResult(player, RemoteNames.RequestAssemble, false, "TOO_FAR_AWAY", nil)
		return
	end

	local executed, transactionResult = DataService.Transaction(player, function(data)
		local job = data.Machines.AssemblerJob
		if job.Active then
			return false, result(false, "ASSEMBLER_BUSY", { CompletesAt = job.CompletesAt })
		end
		if ownedRobotCount(data) >= GameConfig.Economy.MaxOwnedRobots then
			return false, result(false, "ROBOT_INVENTORY_FULL", nil)
		end

		local cost = FactoryRules.GetAssemblerCost(data.Stats.LifetimeRobotsBuilt)
		if not EconomyService.CanAffordMaterials(data, cost) then
			return false, result(false, "MISSING_MATERIALS", nil)
		end

		assert(
			EconomyService.SpendMaterials(data, cost),
			"validated assembler cost must be spendable"
		)
		local startedAt = os.time()
		local duration =
			math.max(1, math.ceil(FactoryRules.GetAssemblerSeconds(data.Machines.AssemblerLevel)))
		job.Active = true
		job.StartedAt = startedAt
		job.CompletesAt = startedAt + duration

		return true, result(true, "ASSEMBLY_STARTED", {
			CompletesAt = job.CompletesAt,
		})
	end)

	sendTransactionResult(player, RemoteNames.RequestAssemble, executed, transactionResult)
end

local function completeProcessor(player: Player, now: number): boolean
	local executed, transactionResult = DataService.Transaction(player, function(data)
		local job = data.Machines.ProcessorJob
		if not job.Active or job.CompletesAt > now then
			return false, nil
		end

		local recipe = Recipes.Processor[job.RecipeId]
		if recipe == nil then
			resetProcessorJob(job)
			return true, result(false, "PROCESS_RECIPE_REMOVED", nil)
		end
		if not EconomyService.GrantMaterials(data, recipe.Output) then
			return false, result(false, "PROCESS_WAITING_FOR_STORAGE", nil)
		end

		local recipeId = job.RecipeId
		resetProcessorJob(job)
		data.Tutorial.Milestones.FirstProcess = true
		return true,
			result(true, "PROCESS_COMPLETE", {
				RecipeId = recipeId,
				Output = recipe.Output,
			})
	end)

	if not executed or transactionResult == nil then
		return false
	end
	if transactionResult.Success == true then
		StateService.ActionResult(
			player,
			"ProcessorComplete",
			true,
			transactionResult.Code,
			transactionResult.Payload
		)
		StateService.PushSnapshot(player)
		return true
	end
	return false
end

local function completeAssembler(player: Player, now: number): boolean
	local executed, transactionResult = DataService.Transaction(player, function(data)
		local job = data.Machines.AssemblerJob
		if not job.Active or job.CompletesAt > now then
			return false, nil
		end
		if ownedRobotCount(data) >= GameConfig.Economy.MaxOwnedRobots then
			return false, result(false, "ROBOT_INVENTORY_FULL", nil)
		end

		local firstBuild = data.Stats.LifetimeRobotsBuilt == 0
		local robotId = FactoryRules.RollRobot(random:NextNumber(), firstBuild)
		assert(Robots.Definitions[robotId] ~= nil, "robot roll must resolve to a known definition")

		local uidNumber = RobotInventoryRules.FindAvailableUidNumber(
			data.Robots.OwnedByUid,
			data.Robots.NextUid,
			GameConfig.Economy.MaxOwnedRobots
		)
		if uidNumber == nil then
			return false, result(false, "ROBOT_UID_UNAVAILABLE", nil)
		end
		local uid = RobotInventoryRules.FormatUid(uidNumber)
		data.Robots.NextUid = RobotInventoryRules.AdvanceUidNumber(uidNumber)
		data.Robots.OwnedByUid[uid] = {
			RobotId = robotId,
			AcquiredAt = now,
		}
		data.Stats.LifetimeRobotsBuilt += 1
		data.Collection.RobotSeen[robotId] = true
		data.Collection.RobotOwned[robotId] = true
		data.Tutorial.Milestones.FirstBotReveal = true
		resetAssemblerJob(job)

		return true,
			result(true, "ASSEMBLY_COMPLETE", {
				RobotUid = uid,
				RobotId = robotId,
			})
	end)

	if not executed or transactionResult == nil then
		return false
	end
	if transactionResult.Success == true then
		StateService.ActionResult(
			player,
			"AssemblerComplete",
			true,
			transactionResult.Code,
			transactionResult.Payload
		)
		StateService.PushSnapshot(player)
		return true
	end
	return false
end

function MachineService.PollPlayer(player: Player)
	if not DataService.IsReady(player) then
		return
	end
	local now = os.time()
	completeProcessor(player, now)
	completeAssembler(player, now)
end

local function rejectForeignPlot(player: Player, actionName: string)
	StateService.ActionResult(player, actionName, false, "NOT_YOUR_PLOT", nil)
end

local function bindWorldPrompts()
	for _, control in WorldService.GetProcessorControls() do
		local recipeId = control:GetAttribute("ProcessorRecipeId")
		local prompt = control:FindFirstChildOfClass("ProximityPrompt")
		if typeof(recipeId) == "string" and prompt then
			prompt.Triggered:Connect(function(player)
				if not RateLimiter.Consume(player, RemoteNames.RequestProcess) then
					return
				end
				if not PlotService.OwnsPart(player, control) then
					rejectForeignPlot(player, RemoteNames.RequestProcess)
					return
				end
				MachineService.StartProcessor(player, recipeId)
			end)
		end
	end

	for _, assembler in WorldService.GetPlotAssemblers() do
		local assemblerPrompt = assembler:FindFirstChildOfClass("ProximityPrompt")
		if assemblerPrompt then
			assemblerPrompt.Triggered:Connect(function(player)
				if not RateLimiter.Consume(player, RemoteNames.RequestAssemble) then
					return
				end
				if not PlotService.OwnsPart(player, assembler) then
					rejectForeignPlot(player, RemoteNames.RequestAssemble)
					return
				end
				MachineService.StartAssembler(player)
			end)
		end
	end
end

function MachineService.Init()
	if initialized then
		return
	end
	initialized = true

	RemoteService.BindRequest(RemoteNames.RequestProcess, function(player, recipeId)
		MachineService.StartProcessor(player, recipeId)
	end)
	RemoteService.BindRequest(RemoteNames.RequestAssemble, function(player)
		MachineService.StartAssembler(player)
	end)
	bindWorldPrompts()

	DataService.ProfileLoaded:Connect(function(player)
		MachineService.PollPlayer(player)
	end)

	task.spawn(function()
		while true do
			task.wait(GameConfig.Factory.MachinePollSeconds)
			for _, player in Players:GetPlayers() do
				MachineService.PollPlayer(player)
			end
		end
	end)
end

return MachineService
