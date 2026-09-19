--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JestGlobals = require(ReplicatedStorage.DevPackages.JestGlobals)
local describe = JestGlobals.describe
local expect = JestGlobals.expect
local it = JestGlobals.it

local FactoryRules = require(ReplicatedStorage.Shared.Domain.FactoryRules)
local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)

local serverRoot = script.Parent.Parent
local ProfileTemplate = require(serverRoot.Data.ProfileTemplate)
local DataService = require(serverRoot.Services.DataService)
local MachineService = require(serverRoot.Services.MachineService)
local MonetizationService = require(serverRoot.Services.MonetizationService)
local PlotService = require(serverRoot.Services.PlotService)
local StateService = require(serverRoot.Services.StateService)
local PlayerCharacter = require(serverRoot.Util.PlayerCharacter)

local function deepCopy(value: any): any
	if typeof(value) ~= "table" then
		return value
	end
	local result = {}
	for key, child in value do
		result[deepCopy(key)] = deepCopy(child)
	end
	return result
end

local function makeFakePlayer(): Player
	return Instance.new("Folder") :: any
end

local function makeStation(name: string): BasePart
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	return part
end

local function resetFakes()
	DataService.Reset()
	MonetizationService.Reset()
	PlotService.Reset()
	StateService.Reset()
	PlayerCharacter.Reset()
end

local function configurePlayer(player: Player, data: any)
	local processor = makeStation("ProcessorControl")
	processor:SetAttribute("ProcessorRecipeId", "MakeWiring")
	local assembler = makeStation("Assembler")
	local plot = Instance.new("Model")
	plot.Name = "Plot"
	PlotService.SetStations(player, {
		Assembler = assembler,
		Plot = plot,
		ProcessorControls = {
			MakeWiring = processor,
			RecoverCore = processor,
		},
	})
	PlayerCharacter.SetNear(player, true)
	DataService.SetData(player, data)
	return processor, assembler, plot
end

describe("MachineService integration", function()
	it("starts processor jobs from authoritative recipe data and spends exact inputs", function()
		resetFakes()
		local player = makeFakePlayer()
		local data = deepCopy(ProfileTemplate)
		data.Materials.ScrapMetal = 10
		configurePlayer(player, data)

		MachineService.StartProcessor(player, "MakeWiring")

		expect(data.Materials.ScrapMetal).toBe(6)
		expect(data.Machines.ProcessorJob.Active).toBe(true)
		expect(data.Machines.ProcessorJob.RecipeId).toBe("MakeWiring")
		expect(data.Machines.ProcessorJob.CompletesAt > data.Machines.ProcessorJob.StartedAt).toBe(
			true
		)
		expect(data.Revision).toBe(1)
		expect(StateService.GetLastResult(player).Code).toBe("PROCESS_STARTED")
		expect(StateService.GetSnapshotPushCount(player)).toBe(1)

		player:Destroy()
	end)

	it("rejects unknown recipes before entering the transaction boundary", function()
		resetFakes()
		local player = makeFakePlayer()
		local data = deepCopy(ProfileTemplate)
		data.Materials.ScrapMetal = 10
		configurePlayer(player, data)

		MachineService.StartProcessor(player, "ForgedRecipe")

		expect(data.Materials.ScrapMetal).toBe(10)
		expect(data.Machines.ProcessorJob.Active).toBe(false)
		expect(data.Revision).toBe(0)
		expect(StateService.GetLastResult(player).Code).toBe("UNKNOWN_RECIPE")

		player:Destroy()
	end)

	it("rejects processor requests made away from the authoritative control", function()
		resetFakes()
		local player = makeFakePlayer()
		local data = deepCopy(ProfileTemplate)
		data.Materials.ScrapMetal = 10
		configurePlayer(player, data)
		PlayerCharacter.SetNear(player, false)

		MachineService.StartProcessor(player, "MakeWiring")

		expect(data.Materials.ScrapMetal).toBe(10)
		expect(data.Machines.ProcessorJob.Active).toBe(false)
		expect(data.Revision).toBe(0)
		expect(StateService.GetLastResult(player).Code).toBe("TOO_FAR_AWAY")

		player:Destroy()
	end)

	it("applies the exact Factory VIP assembler duration multiplier server-side", function()
		resetFakes()
		local player = makeFakePlayer()
		local data = deepCopy(ProfileTemplate)
		data.Materials.ScrapMetal = 4
		data.Materials.Wiring = 1
		configurePlayer(player, data)
		MonetizationService.SetAssemblerTimeMultiplier(
			player,
			GameConfig.Factory.FactoryVIPAssemblerTimeMultiplier
		)

		MachineService.StartAssembler(player)

		local job = data.Machines.AssemblerJob
		local expectedDuration = FactoryRules.GetAssemblerDuration(
			data.Machines.AssemblerLevel,
			GameConfig.Factory.FactoryVIPAssemblerTimeMultiplier
		)
		expect(job.Active).toBe(true)
		expect(math.abs((job.CompletesAt - job.StartedAt) - expectedDuration) < 0.0001).toBe(true)
		expect(data.Materials.ScrapMetal).toBe(0)
		expect(data.Materials.Wiring).toBe(0)
		expect(data.Revision).toBe(1)
		expect(StateService.GetLastResult(player).Code).toBe("ASSEMBLY_STARTED")

		player:Destroy()
	end)

	it("blocks assembly when the robot inventory is at the configured hard cap", function()
		resetFakes()
		local player = makeFakePlayer()
		local data = deepCopy(ProfileTemplate)
		data.Materials.ScrapMetal = 100
		data.Materials.Wiring = 100
		data.Materials.PowerCoreFragments = 100
		for index = 1, GameConfig.Economy.MaxOwnedRobots do
			data.Robots.OwnedByUid[("R%06d"):format(index)] = {
				RobotId = "TinScout",
				AcquiredAt = index,
			}
		end
		configurePlayer(player, data)

		MachineService.StartAssembler(player)

		expect(data.Machines.AssemblerJob.Active).toBe(false)
		expect(data.Materials.ScrapMetal).toBe(100)
		expect(StateService.GetLastResult(player).Code).toBe("ROBOT_INVENTORY_FULL")

		player:Destroy()
	end)

	it("rejects transaction contention without consuming assembler materials", function()
		resetFakes()
		local player = makeFakePlayer()
		local data = deepCopy(ProfileTemplate)
		data.Materials.ScrapMetal = 4
		data.Materials.Wiring = 1
		configurePlayer(player, data)
		DataService.SetBusy(player, true)

		MachineService.StartAssembler(player)

		expect(data.Machines.AssemblerJob.Active).toBe(false)
		expect(data.Materials.ScrapMetal).toBe(4)
		expect(data.Materials.Wiring).toBe(1)
		expect(data.Revision).toBe(0)
		expect(StateService.GetLastResult(player).Code).toBe("TRANSACTION_BUSY")

		player:Destroy()
	end)
end)
