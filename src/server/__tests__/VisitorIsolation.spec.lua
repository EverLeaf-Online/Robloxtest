--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JestGlobals = require(ReplicatedStorage.DevPackages.JestGlobals)
local describe = JestGlobals.describe
local expect = JestGlobals.expect
local it = JestGlobals.it

local Zones = require(ReplicatedStorage.Shared.Config.Zones)

local serverRoot = script.Parent.Parent
local ProfileTemplate = require(serverRoot.Data.ProfileTemplate)
local DataService = require(serverRoot.Services.DataService)
local MachineService = require(serverRoot.Services.MachineService)
local MonetizationService = require(serverRoot.Services.MonetizationService)
local PlotService = require(serverRoot.Services.PlotService)
local RobotService = require(serverRoot.Services.RobotService)
local SalvageService = require(serverRoot.Services.SalvageServiceUnderTest)
local StateService = require(serverRoot.Services.StateService)
local UpgradeService = require(serverRoot.Services.UpgradeServiceUnderTest)
local WorldService = require(serverRoot.Services.WorldService)
local ZoneService = require(serverRoot.Services.ZoneServiceUnderTest)
local AnalyticsService = require(serverRoot.Services.AnalyticsService)
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

local function fakePlayer(): Player
	return Instance.new("Folder") :: any
end

local function station(name: string, plotId: number): BasePart
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part:SetAttribute("PlotId", plotId)
	return part
end

local function salvageNode(nodeId: string, plotId: number): BasePart
	local node = station(nodeId, plotId)
	node:SetAttribute("SalvageNodeId", nodeId)
	node:SetAttribute("ZoneId", 1)

	local prompt = Instance.new("ProximityPrompt")
	prompt.Enabled = true
	prompt.Parent = node

	local presentation = Instance.new("Part")
	presentation.Name = "Presentation"
	presentation.Anchored = true
	presentation.CanCollide = false
	presentation:SetAttribute("PresentationPart", true)
	presentation.Parent = node

	WorldService.SetSalvageNode(nodeId, node)
	return node
end

local function resetFakes()
	AnalyticsService.Reset()
	DataService.Reset()
	MonetizationService.Reset()
	PlotService.Reset()
	StateService.Reset()
	WorldService.Reset()
	PlayerCharacter.Reset()
end

describe("Visitor read-only isolation", function()
	it("keeps owner economy and progression immutable under visitor action spam", function()
		resetFakes()

		local owner = fakePlayer()
		local visitor = fakePlayer()
		local ownerData = deepCopy(ProfileTemplate)
		ownerData.Currencies.Credits = 50_000
		ownerData.Materials.ScrapMetal = 500
		ownerData.Materials.Wiring = 100
		ownerData.Stats.LifetimeRobotsBuilt = Zones[2].RequiredLifetimeRobots
		ownerData.Robots.OwnedByUid.R1 = {
			RobotId = "TinScout",
			AcquiredAt = 1,
		}
		ownerData.Robots.NextUid = 2

		local processor = station("ProcessorControl", 1)
		processor:SetAttribute("ProcessorRecipeId", "MakeWiring")
		local assembler = station("Assembler", 1)
		local botConsole = station("BotConsole", 1)
		local recycleStation = station("RecycleStation", 1)
		local upgradeConsole = station("UpgradeConsole", 1)
		local storageStation = station("StorageBin2", 1)
		local gate = station("Zone2Gate", 1)
		gate:SetAttribute("TargetZone", 2)
		local node = salvageNode("visitor-isolation-node", 1)

		PlotService.SetStations(owner, {
			PlotId = 1,
			BotConsole = botConsole,
			RecycleStation = recycleStation,
			Assembler = assembler,
			UpgradeConsole = upgradeConsole,
			StorageStation = storageStation,
			ProcessorControls = {
				MakeWiring = processor,
				RecoverCore = processor,
			},
		})
		WorldService.SetPlotZoneGate(1, 2, gate)
		DataService.SetData(owner, ownerData)
		PlayerCharacter.SetNear(owner, true)
		PlayerCharacter.SetPosition(owner, Vector3.zero)

		-- A verified Visitor intentionally has no persistent profile and no plot
		-- authority. Simulate a hostile client still firing every valuable remote.
		PlayerCharacter.SetNear(visitor, true)
		PlayerCharacter.SetPosition(visitor, Vector3.zero)

		local before = deepCopy(ownerData)

		MachineService.StartProcessor(visitor, "MakeWiring")
		expect(StateService.GetLastResult(visitor).Code).toBe("NO_FACTORY_PLOT")

		MachineService.StartAssembler(visitor)
		expect(StateService.GetLastResult(visitor).Code).toBe("NO_FACTORY_PLOT")

		RobotService.Assign(visitor, "R1", "Pad1")
		expect(StateService.GetLastResult(visitor).Code).toBe("NO_FACTORY_PLOT")

		RobotService.Sell(visitor, "R1")
		expect(StateService.GetLastResult(visitor).Code).toBe("NO_FACTORY_PLOT")

		UpgradeService.Purchase(visitor, "ProcessorSpeed")
		expect(StateService.GetLastResult(visitor).Code).toBe("NO_FACTORY_PLOT")

		ZoneService.UseGate(visitor, 2)
		expect(StateService.GetLastResult(visitor).Code).toBe("UNKNOWN_ZONE")

		SalvageService.Collect(visitor, "visitor-isolation-node")

		expect(DataService.GetData(visitor)).toBe(nil)
		expect(DataService.IsReady(visitor)).toBe(false)
		expect(PlotService.GetPlotId(visitor)).toBe(nil)
		expect(ownerData).toEqual(before)
		expect(StateService.GetSnapshotPushCount(visitor)).toBe(0)
		expect(#AnalyticsService.GetCreditSources()).toBe(0)
		expect(#AnalyticsService.GetCreditSinks()).toBe(0)
		expect(node.CanCollide).toBe(true)

		owner:Destroy()
		visitor:Destroy()
		for _, instance in
			{
				processor,
				assembler,
				botConsole,
				recycleStation,
				upgradeConsole,
				storageStation,
				gate,
				node,
			}
		do
			instance:Destroy()
		end
	end)
end)
