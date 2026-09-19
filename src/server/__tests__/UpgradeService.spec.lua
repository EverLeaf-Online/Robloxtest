--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JestGlobals = require(ReplicatedStorage.DevPackages.JestGlobals)
local describe = JestGlobals.describe
local expect = JestGlobals.expect
local it = JestGlobals.it

local Upgrades = require(ReplicatedStorage.Shared.Config.Upgrades)

local serverRoot = script.Parent.Parent
local ProfileTemplate = require(serverRoot.Data.ProfileTemplate)
local AnalyticsService = require(serverRoot.Services.AnalyticsService)
local DataService = require(serverRoot.Services.DataService)
local PlotService = require(serverRoot.Services.PlotService)
local StateService = require(serverRoot.Services.StateService)
local UpgradeService = require(serverRoot.Services.UpgradeServiceUnderTest)
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
	AnalyticsService.Reset()
	DataService.Reset()
	PlotService.Reset()
	StateService.Reset()
	PlayerCharacter.Reset()
end

local function configurePlayer(player: Player, data: any)
	PlotService.SetStations(player, {
		UpgradeConsole = makeStation("UpgradeConsole"),
		StorageStation = makeStation("StorageBin2"),
	})
	PlayerCharacter.SetNear(player, true)
	DataService.SetData(player, data)
end

describe("UpgradeService integration", function()
	it("purchases an upgrade with exact authoritative cost and analytics", function()
		resetFakes()
		local player = makeFakePlayer()
		local data = deepCopy(ProfileTemplate)
		local nextLevel = Upgrades.ProcessorSpeed.Levels[2]
		data.Currencies.Credits = nextLevel.CostCredits
		configurePlayer(player, data)

		UpgradeService.Purchase(player, "ProcessorSpeed")

		expect(data.Machines.ProcessorLevel).toBe(2)
		expect(data.Currencies.Credits).toBe(0)
		expect(data.Tutorial.Milestones.FirstUpgrade).toBe(true)
		expect(data.Revision).toBe(1)
		expect(StateService.GetLastResult(player).Code).toBe("UPGRADE_PURCHASED")
		expect(StateService.GetSnapshotPushCount(player)).toBe(1)
		expect(PlotService.GetRefreshCount(player)).toBe(1)

		local sinks = AnalyticsService.GetCreditSinks()
		expect(#sinks).toBe(1)
		expect(sinks[1].Source).toBe("Upgrade:ProcessorSpeed")
		expect(sinks[1].Amount).toBe(nextLevel.CostCredits)
		expect(sinks[1].Balance).toBe(0)

		player:Destroy()
	end)

	it("rejects a distant upgrade request before spending credits", function()
		resetFakes()
		local player = makeFakePlayer()
		local data = deepCopy(ProfileTemplate)
		data.Currencies.Credits = 1_000_000
		configurePlayer(player, data)
		PlayerCharacter.SetNear(player, false)

		UpgradeService.Purchase(player, "AssemblerSpeed")

		expect(data.Machines.AssemblerLevel).toBe(1)
		expect(data.Currencies.Credits).toBe(1_000_000)
		expect(data.Revision).toBe(0)
		expect(StateService.GetLastResult(player).Code).toBe("TOO_FAR_AWAY")
		expect(#AnalyticsService.GetCreditSinks()).toBe(0)

		player:Destroy()
	end)

	it("rejects unknown and oversized upgrade identifiers without mutation", function()
		resetFakes()
		local player = makeFakePlayer()
		local data = deepCopy(ProfileTemplate)
		data.Currencies.Credits = 1_000_000
		configurePlayer(player, data)

		UpgradeService.Purchase(player, "ForgedUpgrade")
		expect(StateService.GetLastResult(player).Code).toBe("UNKNOWN_UPGRADE")
		expect(data.Revision).toBe(0)

		UpgradeService.Purchase(player, string.rep("X", 65))
		expect(StateService.GetLastResult(player).Code).toBe("INVALID_UPGRADE_ID")
		expect(data.Revision).toBe(0)
		expect(data.Currencies.Credits).toBe(1_000_000)
		expect(#AnalyticsService.GetCreditSinks()).toBe(0)

		player:Destroy()
	end)

	it("does not double-spend once an upgrade is already at max level", function()
		resetFakes()
		local player = makeFakePlayer()
		local data = deepCopy(ProfileTemplate)
		data.Machines.WorkSlotsLevel = #Upgrades.WorkSlots.Levels
		data.Currencies.Credits = 25_000
		configurePlayer(player, data)

		UpgradeService.Purchase(player, "WorkSlots")
		UpgradeService.Purchase(player, "WorkSlots")

		expect(data.Machines.WorkSlotsLevel).toBe(#Upgrades.WorkSlots.Levels)
		expect(data.Currencies.Credits).toBe(25_000)
		expect(data.Revision).toBe(0)
		expect(StateService.GetLastResult(player).Code).toBe("MAX_LEVEL")
		expect(#AnalyticsService.GetCreditSinks()).toBe(0)
		expect(StateService.GetSnapshotPushCount(player)).toBe(0)

		player:Destroy()
	end)

	it("rejects transaction contention without charging an upgrade", function()
		resetFakes()
		local player = makeFakePlayer()
		local data = deepCopy(ProfileTemplate)
		local nextLevel = Upgrades.Storage.Levels[2]
		data.Currencies.Credits = nextLevel.CostCredits
		configurePlayer(player, data)
		DataService.SetBusy(player, true)

		UpgradeService.Purchase(player, "Storage")

		expect(data.Machines.StorageLevel).toBe(1)
		expect(data.Currencies.Credits).toBe(nextLevel.CostCredits)
		expect(data.Revision).toBe(0)
		expect(StateService.GetLastResult(player).Code).toBe("TRANSACTION_BUSY")
		expect(#AnalyticsService.GetCreditSinks()).toBe(0)

		player:Destroy()
	end)

	it("requires the player to own a factory interaction surface", function()
		resetFakes()
		local player = makeFakePlayer()
		local data = deepCopy(ProfileTemplate)
		data.Currencies.Credits = 1_000_000
		DataService.SetData(player, data)
		PlayerCharacter.SetNear(player, true)

		UpgradeService.Purchase(player, "ProcessorSpeed")

		expect(data.Machines.ProcessorLevel).toBe(1)
		expect(data.Currencies.Credits).toBe(1_000_000)
		expect(data.Revision).toBe(0)
		expect(StateService.GetLastResult(player).Code).toBe("NO_FACTORY_PLOT")
		expect(#AnalyticsService.GetCreditSinks()).toBe(0)

		player:Destroy()
	end)
end)
