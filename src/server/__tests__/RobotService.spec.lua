--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JestGlobals = require(ReplicatedStorage.DevPackages.JestGlobals)
local describe = JestGlobals.describe
local expect = JestGlobals.expect
local it = JestGlobals.it

local FactoryRules = require(ReplicatedStorage.Shared.Domain.FactoryRules)
local Robots = require(ReplicatedStorage.Shared.Config.Robots)

local serverRoot = script.Parent.Parent
local ProfileTemplate = require(serverRoot.Data.ProfileTemplate)
local AnalyticsService = require(serverRoot.Services.AnalyticsService)
local DataService = require(serverRoot.Services.DataService)
local MonetizationService = require(serverRoot.Services.MonetizationService)
local PlotService = require(serverRoot.Services.PlotService)
local RobotService = require(serverRoot.Services.RobotService)
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
	AnalyticsService.Reset()
	DataService.Reset()
	MonetizationService.Reset()
	PlotService.Reset()
	StateService.Reset()
	PlayerCharacter.Reset()
end

local function configurePlayer(player: Player, data: any)
	local botConsole = makeStation("BotConsole")
	local recycle = makeStation("RecycleStation")
	PlotService.SetStations(player, {
		BotConsole = botConsole,
		RecycleStation = recycle,
	})
	PlayerCharacter.SetNear(player, true)
	DataService.SetData(player, data)
	return botConsole, recycle
end

describe("RobotService integration", function()
	it("assigns an owned robot and records the tutorial milestone", function()
		resetFakes()
		local player = makeFakePlayer()
		local data = deepCopy(ProfileTemplate)
		data.Robots.OwnedByUid.R000001 = { RobotId = "TinScout", AcquiredAt = 1 }
		configurePlayer(player, data)

		RobotService.Assign(player, "R000001", "Pad1")

		expect(data.Assignments.WorkPads.Pad1).toBe("R000001")
		expect(data.Tutorial.Milestones.FirstBotAssigned).toBe(true)
		expect(data.Revision).toBe(1)
		expect(StateService.GetLastResult(player).Code).toBe("ROBOT_ASSIGNED")
		expect(StateService.GetSnapshotPushCount(player)).toBe(1)

		player:Destroy()
	end)

	it("integrates the +2 work-slot entitlement without unlocking a fourth paid slot", function()
		resetFakes()
		local player = makeFakePlayer()
		local data = deepCopy(ProfileTemplate)
		data.Robots.OwnedByUid.R000001 = { RobotId = "TinScout", AcquiredAt = 1 }
		data.Robots.OwnedByUid.R000002 = { RobotId = "BoltBuddy", AcquiredAt = 2 }
		configurePlayer(player, data)
		MonetizationService.SetExtraWorkSlots(player, 2)

		expect(FactoryRules.GetWorkSlots(data.Machines.WorkSlotsLevel)).toBe(1)

		RobotService.Assign(player, "R000001", "Pad3")
		expect(data.Assignments.WorkPads.Pad3).toBe("R000001")
		expect(StateService.GetLastResult(player).Code).toBe("ROBOT_ASSIGNED")

		RobotService.Assign(player, "R000002", "Pad4")
		expect(data.Assignments.WorkPads.Pad4).toBe(nil)
		expect(StateService.GetLastResult(player).Code).toBe("WORK_PAD_LOCKED")

		player:Destroy()
	end)

	it("rejects transaction contention without leaking an assignment", function()
		resetFakes()
		local player = makeFakePlayer()
		local data = deepCopy(ProfileTemplate)
		data.Robots.OwnedByUid.R000001 = { RobotId = "TinScout", AcquiredAt = 1 }
		configurePlayer(player, data)
		DataService.SetBusy(player, true)

		RobotService.Assign(player, "R000001", "Pad1")

		expect(data.Assignments.WorkPads.Pad1).toBe(nil)
		expect(data.Revision).toBe(0)
		expect(StateService.GetLastResult(player).Code).toBe("TRANSACTION_BUSY")
		expect(StateService.GetSnapshotPushCount(player)).toBe(0)

		player:Destroy()
	end)

	it("rejects assignment requests made away from the authoritative bot console", function()
		resetFakes()
		local player = makeFakePlayer()
		local data = deepCopy(ProfileTemplate)
		data.Robots.OwnedByUid.R000001 = { RobotId = "TinScout", AcquiredAt = 1 }
		configurePlayer(player, data)
		PlayerCharacter.SetNear(player, false)

		RobotService.Assign(player, "R000001", "Pad1")

		expect(data.Assignments.WorkPads.Pad1).toBe(nil)
		expect(data.Revision).toBe(0)
		expect(StateService.GetLastResult(player).Code).toBe("TOO_FAR_AWAY")

		player:Destroy()
	end)

	it("never recycles an assigned robot", function()
		resetFakes()
		local player = makeFakePlayer()
		local data = deepCopy(ProfileTemplate)
		data.Robots.OwnedByUid.R000001 = { RobotId = "TinScout", AcquiredAt = 1 }
		data.Assignments.WorkPads.Pad1 = "R000001"
		configurePlayer(player, data)

		RobotService.Sell(player, "R000001")

		expect(data.Robots.OwnedByUid.R000001 ~= nil).toBe(true)
		expect(data.Currencies.Credits).toBe(0)
		expect(StateService.GetLastResult(player).Code).toBe("ROBOT_IS_ASSIGNED")
		expect(#AnalyticsService.GetCreditSources()).toBe(0)

		player:Destroy()
	end)

	it("recycles exactly once and records the authoritative credit source", function()
		resetFakes()
		local player = makeFakePlayer()
		local data = deepCopy(ProfileTemplate)
		data.Robots.OwnedByUid.R000001 = { RobotId = "TinScout", AcquiredAt = 1 }
		configurePlayer(player, data)

		local expectedCredits = Robots.Definitions.TinScout.RecycleCredits
		RobotService.Sell(player, "R000001")

		expect(data.Robots.OwnedByUid.R000001).toBe(nil)
		expect(data.Currencies.Credits).toBe(expectedCredits)
		expect(StateService.GetLastResult(player).Code).toBe("ROBOT_RECYCLED")
		expect(#AnalyticsService.GetCreditSources()).toBe(1)
		expect(AnalyticsService.GetCreditSources()[1].Amount).toBe(expectedCredits)

		RobotService.Sell(player, "R000001")
		expect(data.Currencies.Credits).toBe(expectedCredits)
		expect(StateService.GetLastResult(player).Code).toBe("ROBOT_NOT_OWNED")
		expect(#AnalyticsService.GetCreditSources()).toBe(1)

		player:Destroy()
	end)
end)
