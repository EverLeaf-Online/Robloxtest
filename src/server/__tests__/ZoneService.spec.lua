--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JestGlobals = require(ReplicatedStorage.DevPackages.JestGlobals)
local describe = JestGlobals.describe
local expect = JestGlobals.expect
local it = JestGlobals.it

local Zones = require(ReplicatedStorage.Shared.Config.Zones)

local serverRoot = script.Parent.Parent
local ProfileTemplate = require(serverRoot.Data.ProfileTemplate)
local AnalyticsService = require(serverRoot.Services.AnalyticsService)
local DataService = require(serverRoot.Services.DataService)
local PlotService = require(serverRoot.Services.PlotService)
local StateService = require(serverRoot.Services.StateService)
local WorldService = require(serverRoot.Services.WorldService)
local ZoneService = require(serverRoot.Services.ZoneServiceUnderTest)
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

local function makeGate(plotId: number, targetZone: number): BasePart
	local gate = Instance.new("Part")
	gate.Name = ("Zone%dGate"):format(targetZone)
	gate.Anchored = true
	gate:SetAttribute("PlotId", plotId)
	gate:SetAttribute("TargetZone", targetZone)
	return gate
end

local function resetFakes()
	AnalyticsService.Reset()
	DataService.Reset()
	PlotService.Reset()
	StateService.Reset()
	WorldService.Reset()
	PlayerCharacter.Reset()
end

local function configureOwner(player: Player, data: any, plotId: number): BasePart
	local gate = makeGate(plotId, 2)
	PlotService.SetStations(player, {
		PlotId = plotId,
	})
	WorldService.SetPlotZoneGate(plotId, 2, gate)
	PlayerCharacter.SetNear(player, true)
	DataService.SetData(player, data)
	return gate
end

describe("ZoneService integration", function()
	it("unlocks Circuit Yard exactly once and records the authoritative credit sink", function()
		resetFakes()
		local player = makeFakePlayer()
		local data = deepCopy(ProfileTemplate)
		data.Currencies.Credits = Zones[2].UnlockCredits
		data.Stats.LifetimeRobotsBuilt = Zones[2].RequiredLifetimeRobots
		configureOwner(player, data, 1)

		ZoneService.UseGate(player, 2)

		expect(data.Progression.Zone).toBe(2)
		expect(data.Currencies.Credits).toBe(0)
		expect(data.Tutorial.Milestones.FirstZoneUnlock).toBe(true)
		expect(data.Revision).toBe(1)
		expect(StateService.GetLastResult(player).Code).toBe("ZONE_UNLOCKED")
		expect(StateService.GetSnapshotPushCount(player)).toBe(1)
		expect(PlotService.GetRefreshCount(player)).toBe(1)

		local sinks = AnalyticsService.GetCreditSinks()
		expect(#sinks).toBe(1)
		expect(sinks[1].Source).toBe("ZoneUnlock:2")
		expect(sinks[1].Amount).toBe(Zones[2].UnlockCredits)
		expect(sinks[1].Balance).toBe(0)

		ZoneService.UseGate(player, 2)

		expect(data.Currencies.Credits).toBe(0)
		expect(data.Revision).toBe(1)
		expect(StateService.GetLastResult(player).Code).toBe("ZONE_ALREADY_UNLOCKED")
		expect(#AnalyticsService.GetCreditSinks()).toBe(1)

		player:Destroy()
	end)

	it("does not let a visitor invoke an owner's zone gate through the remote path", function()
		resetFakes()
		local owner = makeFakePlayer()
		local visitor = makeFakePlayer()
		local ownerData = deepCopy(ProfileTemplate)
		local visitorData = deepCopy(ProfileTemplate)
		ownerData.Currencies.Credits = Zones[2].UnlockCredits
		ownerData.Stats.LifetimeRobotsBuilt = Zones[2].RequiredLifetimeRobots
		visitorData.Currencies.Credits = Zones[2].UnlockCredits
		visitorData.Stats.LifetimeRobotsBuilt = Zones[2].RequiredLifetimeRobots

		configureOwner(owner, ownerData, 1)
		DataService.SetData(visitor, visitorData)
		PlayerCharacter.SetNear(visitor, true)

		ZoneService.UseGate(visitor, 2)

		expect(visitorData.Progression.Zone).toBe(1)
		expect(visitorData.Currencies.Credits).toBe(Zones[2].UnlockCredits)
		expect(visitorData.Revision).toBe(0)
		expect(StateService.GetLastResult(visitor).Code).toBe("UNKNOWN_ZONE")
		expect(ownerData.Progression.Zone).toBe(1)
		expect(ownerData.Currencies.Credits).toBe(Zones[2].UnlockCredits)
		expect(#AnalyticsService.GetCreditSinks()).toBe(0)

		owner:Destroy()
		visitor:Destroy()
	end)

	it("rejects a distant owner before spending credits or entering a transaction", function()
		resetFakes()
		local player = makeFakePlayer()
		local data = deepCopy(ProfileTemplate)
		data.Currencies.Credits = Zones[2].UnlockCredits
		data.Stats.LifetimeRobotsBuilt = Zones[2].RequiredLifetimeRobots
		configureOwner(player, data, 1)
		PlayerCharacter.SetNear(player, false)

		ZoneService.UseGate(player, 2)

		expect(data.Progression.Zone).toBe(1)
		expect(data.Currencies.Credits).toBe(Zones[2].UnlockCredits)
		expect(data.Revision).toBe(0)
		expect(StateService.GetLastResult(player).Code).toBe("TOO_FAR_AWAY")
		expect(#AnalyticsService.GetCreditSinks()).toBe(0)

		player:Destroy()
	end)

	it("rejects a forged nonexistent later-zone gate without mutating progression", function()
		resetFakes()
		local player = makeFakePlayer()
		local data = deepCopy(ProfileTemplate)
		data.Currencies.Credits = 1_000_000
		data.Stats.LifetimeRobotsBuilt = 100
		PlotService.SetStations(player, {
			PlotId = 1,
		})
		local forgedGate = makeGate(1, 3)
		WorldService.SetPlotZoneGate(1, 3, forgedGate)
		PlayerCharacter.SetNear(player, true)
		DataService.SetData(player, data)

		ZoneService.UseGate(player, 3)

		expect(data.Progression.Zone).toBe(1)
		expect(data.Currencies.Credits).toBe(1_000_000)
		expect(data.Tutorial.Milestones.FirstZoneGoalSeen).toBe(false)
		expect(data.Revision).toBe(0)
		expect(StateService.GetLastResult(player).Code).toBe("UNKNOWN_ZONE")
		expect(#AnalyticsService.GetCreditSinks()).toBe(0)

		player:Destroy()
	end)

	it("does not spend credits when robot requirements are not met", function()
		resetFakes()
		local player = makeFakePlayer()
		local data = deepCopy(ProfileTemplate)
		data.Currencies.Credits = Zones[2].UnlockCredits
		data.Stats.LifetimeRobotsBuilt = Zones[2].RequiredLifetimeRobots - 1
		configureOwner(player, data, 1)

		ZoneService.UseGate(player, 2)

		expect(data.Progression.Zone).toBe(1)
		expect(data.Currencies.Credits).toBe(Zones[2].UnlockCredits)
		expect(data.Tutorial.Milestones.FirstZoneGoalSeen).toBe(true)
		expect(data.Revision).toBe(1)
		expect(StateService.GetLastResult(player).Code).toBe("MORE_ROBOTS_REQUIRED")
		expect(#AnalyticsService.GetCreditSinks()).toBe(0)

		player:Destroy()
	end)
end)
