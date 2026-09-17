--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local FactoryRules = require(ReplicatedStorage.Shared.Domain.FactoryRules)
local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local Recipes = require(ReplicatedStorage.Shared.Config.Recipes)
local RemoteNames = require(ReplicatedStorage.Shared.Networking.RemoteNames)
local RobotInventoryRules = require(ReplicatedStorage.Shared.Domain.RobotInventoryRules)
local Robots = require(ReplicatedStorage.Shared.Config.Robots)
local Validation = require(ReplicatedStorage.Shared.Util.Validation)

local DataService = require(script.Parent.DataService)
local EconomyService = require(script.Parent.EconomyService)
local MonetizationService = require(script.Parent.MonetizationService)
local PlotService = require(script.Parent.PlotService)
local RateLimiter = require(script.Parent.RateLimiter)
local RemoteService = require(script.Parent.RemoteService)
local StateService = require(script.Parent.StateService)
local WorldService = require(script.Parent.WorldService)
local PlayerCharacter = require(script.Parent.Parent.Util.PlayerCharacter)
local ProfileTypes = require(script.Parent.Parent.Data.ProfileTypes)

type AssemblerJob = ProfileTypes.AssemblerJob
type ProcessorJob = ProfileTypes.ProcessorJob
type ProfileData = ProfileTypes.ProfileData

local MachineService = {}
local initialized = false
local random = Random.new()

local function serverNow(): number
	return Workspace:GetServerTimeNow()
end

local function resetProcessorJob(job: ProcessorJob)
	job.Active = false
	job.RecipeId = ""
	job.StartedAt = 0
	job.CompletesAt = 0
end

local function resetAssemblerJob(job: AssemblerJob)
	job.Active = false
	job.StartedAt = 0
	job.CompletesAt = 0
end

local function ownedRobotCount(data: ProfileData): number
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

local function isNear(player: Player, part: BasePart): boolean
	return PlayerCharacter.IsNear(player, part, GameConfig.World.InteractionDistance)
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

	local storageMultiplier = MonetizationService.GetStorageMultiplier(player)
	local executed, transactionResult = DataService.Transaction(player, function(data)
		local job = data.Machines.ProcessorJob
		if job.Active then
			return false, result(false, "PROCESSOR_BUSY", { CompletesAt = job.CompletesAt })
		end
		if not EconomyService.CanAffordMaterials(data, recipe.Input) then
			return false, result(false, "MISSING_MATERIALS", nil)
		end
		if
			not EconomyService.CanFitTransaction(
				data,
				recipe.Input,
				recipe.Output,
				storageMultiplier
			)
		then
			return false, result(false, "STORAGE_FULL", nil)
		end

		assert(
			EconomyService.SpendMaterials(data, recipe.Input),
			"validated processor cost must be spendable"
		)
		local startedAt = serverNow()
		local duration =
			math.max(0.001, FactoryRules.GetProcessorSeconds(data.Machines.ProcessorLevel))
		job.Active = true
		job.RecipeId = recipe.Id
		job.StartedAt = startedAt
		job.CompletesAt = startedAt + duration

		return true,
			result(true, "PROCESS_STARTED", { RecipeId = recipe.Id, CompletesAt = job.CompletesAt })
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

	local assemblerTimeMultiplier = MonetizationService.GetAssemblerTimeMultiplier(player)
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
		local startedAt = serverNow()
		local duration =
			FactoryRules.GetAssemblerDuration(data.Machines.AssemblerLevel, assemblerTimeMultiplier)
		job.Active = true
		job.StartedAt = startedAt
		job.CompletesAt = startedAt + duration

		return true, result(true, "ASSEMBLY_STARTED", { CompletesAt = job.CompletesAt })
	end)

	sendTransactionResult(player, RemoteNames.RequestAssemble, executed, transactionResult)
end

local function completeProcessor(player: Player, now: number): boolean
	local storageMultiplier = MonetizationService.GetStorageMultiplier(player)
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
		if not EconomyService.GrantProcessorOutput(data, recipe.Output, storageMultiplier) then
			return false, result(false, "PROCESS_WAITING_FOR_STORAGE", nil)
		end
		local recipeId = job.RecipeId
		resetProcessorJob(job)
		data.Tutorial.Milestones.FirstProcess = true
		return true,
			result(true, "PROCESS_COMPLETE", { RecipeId = recipeId, Output = recipe.Output })
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
		data.Robots.OwnedByUid[uid] = { RobotId = robotId, AcquiredAt = math.floor(now) }
		data.Stats.LifetimeRobotsBuilt += 1
		data.Collection.RobotSeen[robotId] = true
		data.Collection.RobotOwned[robotId] = true
		data.Tutorial.Milestones.FirstBotReveal = true
		resetAssemblerJob(job)
		return true, result(true, "ASSEMBLY_COMPLETE", { RobotUid = uid, RobotId = robotId })
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

function MachineService.UseInstantProcessToken(player: Player)
	local now = serverNow()
	local executed, transactionResult = DataService.Transaction(player, function(data)
		if data.Consumables.InstantProcessTokens <= 0 then
			return false, result(false, "NO_INSTANT_PROCESS_TOKENS", nil)
		end
		local processorJob = data.Machines.ProcessorJob
		local assemblerJob = data.Machines.AssemblerJob
		local target = ""
		if processorJob.Active and processorJob.CompletesAt > now then
			processorJob.CompletesAt = now
			target = "Processor"
		elseif assemblerJob.Active and assemblerJob.CompletesAt > now then
			assemblerJob.CompletesAt = now
			target = "Assembler"
		else
			return false, result(false, "NO_ACTIVE_PROCESS", nil)
		end
		data.Consumables.InstantProcessTokens -= 1
		return true,
			result(
				true,
				"INSTANT_PROCESS_USED",
				{ Target = target, TokensRemaining = data.Consumables.InstantProcessTokens }
			)
	end)
	if not executed then
		StateService.ActionResult(
			player,
			RemoteNames.RequestUseInstantProcessToken,
			false,
			tostring(transactionResult),
			nil
		)
		return
	end
	if typeof(transactionResult) ~= "table" then
		StateService.ActionResult(
			player,
			RemoteNames.RequestUseInstantProcessToken,
			false,
			"INVALID_TRANSACTION_RESULT",
			nil
		)
		return
	end
	StateService.ActionResult(
		player,
		RemoteNames.RequestUseInstantProcessToken,
		transactionResult.Success == true,
		tostring(transactionResult.Code),
		transactionResult.Payload
	)
	if transactionResult.Success ~= true then
		return
	end
	MachineService.PollPlayer(player)
	MonetizationService.RefreshPlayer(player)
	StateService.PushSnapshot(player)
end

function MachineService.PollPlayer(player: Player)
	local data = DataService.GetData(player)
	if data == nil then
		return
	end
	local now = serverNow()
	local processorJob = data.Machines.ProcessorJob
	if processorJob.Active and processorJob.CompletesAt <= now then
		completeProcessor(player, now)
	end
	local assemblerJob = data.Machines.AssemblerJob
	if assemblerJob.Active and assemblerJob.CompletesAt <= now then
		completeAssembler(player, now)
	end
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
	RemoteService.BindRequest(RemoteNames.RequestUseInstantProcessToken, function(player)
		MachineService.UseInstantProcessToken(player)
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
