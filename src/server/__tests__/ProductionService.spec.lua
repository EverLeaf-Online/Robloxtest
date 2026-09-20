--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JestGlobals = require(ReplicatedStorage.DevPackages.JestGlobals)
local describe = JestGlobals.describe
local expect = JestGlobals.expect
local it = JestGlobals.it

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local Robots = require(ReplicatedStorage.Shared.Config.Robots)

local serverRoot = script.Parent.Parent
local ProfileTemplate = require(serverRoot.Data.ProfileTemplate)
local AnalyticsService = require(serverRoot.Services.AnalyticsService)
local DataService = require(serverRoot.Services.DataService)
local MonetizationService = require(serverRoot.Services.MonetizationService)
local ProductionService = require(serverRoot.Services.ProductionServiceUnderTest)
local StateService = require(serverRoot.Services.StateService)

local nextUserId = 97000

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
	nextUserId += 1
	local attributes: { [string]: any } = {}
	local player: any = {
		UserId = nextUserId,
		Parent = nil,
	}
	function player:SetAttribute(name: string, value: any)
		attributes[name] = value
	end
	function player:GetAttribute(name: string): any
		return attributes[name]
	end
	return player :: Player
end

local function resetFakes()
	AnalyticsService.Reset()
	DataService.Reset()
	MonetizationService.Reset()
	StateService.Reset()
end

local function maxOfflineBaseline(data: any): number
	local now = os.time()
	local baseline = now - math.min(120, GameConfig.Factory.OfflineProductionMaxSeconds)
	data.Timestamps.LastProductionTick = baseline
	data.Timestamps.LastLeave = baseline
	return baseline
end

local function addRobot(data: any, uid: string, robotId: string, padId: string)
	data.Robots.OwnedByUid[uid] = {
		RobotId = robotId,
		AcquiredAt = 1,
	}
	data.Assignments.WorkPads[padId] = uid
end

describe("ProductionService integration", function()
	it("grants offline production once from authoritative assigned robot rate", function()
		resetFakes()
		local player = fakePlayer()
		local data = deepCopy(ProfileTemplate)
		maxOfflineBaseline(data)
		addRobot(data, "R1", "TinScout", "Pad1")
		DataService.SetData(player, data)

		local granted = ProductionService.ApplyOfflineProduction(player)
		local elapsed = player:GetAttribute("OfflineProductionSeconds")
		local expected = math.floor(
			Robots.Definitions.TinScout.ProductionPerSecond
				* elapsed
				* GameConfig.Factory.OfflineProductionEfficiency
		)

		expect(granted).toBe(expected)
		expect(data.Currencies.Credits).toBe(expected)
		expect(data.Stats.LifetimeCredits).toBe(expected)
		expect(data.Tutorial.Milestones.FirstIncomeEarned).toBe(true)
		expect(data.Revision).toBe(1)
		expect(player:GetAttribute("OfflineCreditsGranted")).toBe(expected)
		expect(StateService.GetProductionDeltaCount(player)).toBe(1)

		local sources = AnalyticsService.GetCreditSources()
		expect(#sources).toBe(1)
		expect(sources[1].Source).toBe("OfflineBotProduction")
		expect(sources[1].Amount).toBe(expected)
		expect(sources[1].Balance).toBe(expected)

		local duplicateGrant = ProductionService.ApplyOfflineProduction(player)
		expect(duplicateGrant).toBe(0)
		expect(data.Currencies.Credits).toBe(expected)
		expect(data.Revision).toBe(1)
		expect(#AnalyticsService.GetCreditSources()).toBe(1)
		expect(StateService.GetProductionDeltaCount(player)).toBe(1)
	end)

	it("applies the permanent Production 2x multiplier to offline earnings", function()
		resetFakes()
		local player = fakePlayer()
		local data = deepCopy(ProfileTemplate)
		maxOfflineBaseline(data)
		addRobot(data, "R1", "TinScout", "Pad1")
		DataService.SetData(player, data)
		MonetizationService.SetPermanentProductionMultiplier(player, 2)

		local granted = ProductionService.ApplyOfflineProduction(player)
		local elapsed = player:GetAttribute("OfflineProductionSeconds")
		local expected = math.floor(
			Robots.Definitions.TinScout.ProductionPerSecond
				* elapsed
				* GameConfig.Factory.OfflineProductionEfficiency
				* 2
		)

		expect(granted).toBe(expected)
		expect(data.Currencies.Credits).toBe(expected)
		expect(StateService.GetProductionDeltaCount(player)).toBe(1)
	end)

	it("counts a paid extra work slot only when the entitlement unlocks that pad", function()
		resetFakes()
		local withoutPass = fakePlayer()
		local withoutPassData = deepCopy(ProfileTemplate)
		maxOfflineBaseline(withoutPassData)
		addRobot(withoutPassData, "R3", "TinScout", "Pad3")
		DataService.SetData(withoutPass, withoutPassData)

		local lockedGrant = ProductionService.ApplyOfflineProduction(withoutPass)
		expect(lockedGrant).toBe(0)
		expect(withoutPassData.Currencies.Credits).toBe(0)

		local withPass = fakePlayer()
		local withPassData = deepCopy(ProfileTemplate)
		maxOfflineBaseline(withPassData)
		addRobot(withPassData, "R3", "TinScout", "Pad3")
		DataService.SetData(withPass, withPassData)
		MonetizationService.SetExtraWorkSlots(withPass, 2)

		local unlockedGrant = ProductionService.ApplyOfflineProduction(withPass)
		expect(unlockedGrant > 0).toBe(true)
		expect(withPassData.Currencies.Credits).toBe(unlockedGrant)
	end)

	it("caps an offline grant at remaining credit capacity without overflow", function()
		resetFakes()
		local player = fakePlayer()
		local data = deepCopy(ProfileTemplate)
		maxOfflineBaseline(data)
		addRobot(data, "R1", "NovaForeman", "Pad1")
		data.Currencies.Credits = GameConfig.Economy.MaxCredits - 10
		DataService.SetData(player, data)

		local granted = ProductionService.ApplyOfflineProduction(player)

		expect(granted).toBe(10)
		expect(data.Currencies.Credits).toBe(GameConfig.Economy.MaxCredits)
		expect(data.Currencies.Credits <= GameConfig.Economy.MaxCredits).toBe(true)
		expect(AnalyticsService.GetCreditSources()[1].Amount).toBe(10)
	end)

	it("releases a failed offline claim so transaction contention can retry safely", function()
		resetFakes()
		local player = fakePlayer()
		local data = deepCopy(ProfileTemplate)
		maxOfflineBaseline(data)
		addRobot(data, "R1", "TinScout", "Pad1")
		DataService.SetData(player, data)
		DataService.SetBusy(player, true)

		local blockedGrant = ProductionService.ApplyOfflineProduction(player)

		expect(blockedGrant).toBe(0)
		expect(data.Currencies.Credits).toBe(0)
		expect(data.Revision).toBe(0)
		expect(StateService.GetProductionDeltaCount(player)).toBe(0)
		expect(#AnalyticsService.GetCreditSources()).toBe(0)

		DataService.SetBusy(player, false)
		local retryGrant = ProductionService.ApplyOfflineProduction(player)

		expect(retryGrant > 0).toBe(true)
		expect(data.Currencies.Credits).toBe(retryGrant)
		expect(data.Revision).toBe(1)
		expect(StateService.GetProductionDeltaCount(player)).toBe(1)
		expect(#AnalyticsService.GetCreditSources()).toBe(1)
	end)

	it("ignores malformed assignments instead of creating production value", function()
		resetFakes()
		local player = fakePlayer()
		local data = deepCopy(ProfileTemplate)
		maxOfflineBaseline(data)
		data.Robots.OwnedByUid.R1 = {
			RobotId = "NotARealRobot",
			AcquiredAt = 1,
		}
		data.Assignments.WorkPads.Pad1 = "R1"
		data.Assignments.WorkPads.ForgedPad = "R1"
		data.Assignments.WorkPads.Pad999 = "R1"
		DataService.SetData(player, data)

		local granted = ProductionService.ApplyOfflineProduction(player)

		expect(granted).toBe(0)
		expect(data.Currencies.Credits).toBe(0)
		expect(#AnalyticsService.GetCreditSources()).toBe(0)
	end)
end)
