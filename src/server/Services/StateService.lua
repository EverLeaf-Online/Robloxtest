--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemoteNames = require(ReplicatedStorage.Shared.Networking.RemoteNames)
local DataService = require(script.Parent.DataService)
local PlotService = require(script.Parent.PlotService)
local RemoteService = require(script.Parent.RemoteService)

local StateService = {}
local initialized = false

local function cloneDictionary(source: any): any
	return table.clone(source)
end

local function cloneRobots(ownedByUid: any): any
	local result = {}
	for uid, robot in ownedByUid do
		result[uid] = {
			RobotId = robot.RobotId,
			AcquiredAt = robot.AcquiredAt,
		}
	end
	return result
end

function StateService.BuildSnapshot(data: any): any
	return {
		Revision = data.Revision,
		Currencies = {
			Credits = data.Currencies.Credits,
		},
		Materials = cloneDictionary(data.Materials),
		Robots = {
			OwnedByUid = cloneRobots(data.Robots.OwnedByUid),
		},
		Assignments = {
			WorkPads = cloneDictionary(data.Assignments.WorkPads),
		},
		Machines = {
			ProcessorLevel = data.Machines.ProcessorLevel,
			AssemblerLevel = data.Machines.AssemblerLevel,
			StorageLevel = data.Machines.StorageLevel,
			WorkSlotsLevel = data.Machines.WorkSlotsLevel,
			ProcessorJob = {
				Active = data.Machines.ProcessorJob.Active,
				RecipeId = data.Machines.ProcessorJob.RecipeId,
				StartedAt = data.Machines.ProcessorJob.StartedAt,
				CompletesAt = data.Machines.ProcessorJob.CompletesAt,
			},
			AssemblerJob = {
				Active = data.Machines.AssemblerJob.Active,
				StartedAt = data.Machines.AssemblerJob.StartedAt,
				CompletesAt = data.Machines.AssemblerJob.CompletesAt,
			},
		},
		Progression = {
			Zone = data.Progression.Zone,
			FactoryTier = data.Progression.FactoryTier,
			PrestigeCount = data.Progression.PrestigeCount,
		},
		Collection = {
			RobotSeen = cloneDictionary(data.Collection.RobotSeen),
			RobotOwned = cloneDictionary(data.Collection.RobotOwned),
		},
		Stats = {
			LifetimeCredits = data.Stats.LifetimeCredits,
			LifetimeRobotsBuilt = data.Stats.LifetimeRobotsBuilt,
		},
		Tutorial = {
			Milestones = cloneDictionary(data.Tutorial.Milestones),
		},
	}
end

function StateService.PushSnapshot(player: Player)
	local data = DataService.GetData(player)
	if data == nil then
		return
	end

	local snapshot = StateService.BuildSnapshot(data)
	snapshot.Plot = {
		Id = PlotService.GetPlotId(player),
	}
	RemoteService.Get(RemoteNames.StateSnapshot):FireClient(player, snapshot)
end

function StateService.ActionResult(
	player: Player,
	actionName: string,
	success: boolean,
	code: string,
	payload: any?
)
	RemoteService.Get(RemoteNames.ActionResult):FireClient(player, {
		Action = actionName,
		Success = success,
		Code = code,
		Payload = payload,
	})
end

function StateService.Init()
	if initialized then
		return
	end
	initialized = true

	RemoteService.BindRequest(RemoteNames.RequestState, function(player)
		StateService.PushSnapshot(player)
	end)

	DataService.ProfileLoaded:Connect(function(player)
		StateService.PushSnapshot(player)
	end)

	for _, player in Players:GetPlayers() do
		if DataService.IsReady(player) then
			StateService.PushSnapshot(player)
		end
	end
end

return StateService
