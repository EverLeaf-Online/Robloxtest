--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JestGlobals = require(ReplicatedStorage.DevPackages.JestGlobals)
local describe = JestGlobals.describe
local expect = JestGlobals.expect
local it = JestGlobals.it

local RemoteNames = require(script.Parent.Parent.Networking.RemoteNames)
local RequestPolicy = require(script.Parent.Parent.Networking.RequestPolicy)

local function accepts(requestName: string, ...: any): boolean
	local allowed = RequestPolicy.Validate(requestName, ...)
	return allowed
end

describe("RequestPolicy", function()
	it("accepts only the canonical public request signatures", function()
		expect(accepts(RemoteNames.RequestState)).toBe(true)
		expect(accepts(RemoteNames.RequestCollect, "Node_1")).toBe(true)
		expect(accepts(RemoteNames.RequestProcess, "ScrapToParts")).toBe(true)
		expect(accepts(RemoteNames.RequestAssemble)).toBe(true)
		expect(accepts(RemoteNames.RequestAssignRobot, "Robot_1", "WorkPad1")).toBe(true)
		expect(accepts(RemoteNames.RequestUnassignRobot, "Robot_1")).toBe(true)
		expect(accepts(RemoteNames.RequestSellRobot, "Robot_1")).toBe(true)
		expect(accepts(RemoteNames.RequestUpgrade, "Storage")).toBe(true)
		expect(accepts(RemoteNames.RequestUnlockZone, 2)).toBe(true)
		expect(accepts(RemoteNames.RequestPrestige)).toBe(true)
		expect(accepts(RemoteNames.RequestUseInstantProcessToken)).toBe(true)
		expect(accepts(RemoteNames.RequestEquipClubCosmetic, "FactoryGlow")).toBe(true)
		expect(accepts(RemoteNames.RequestAdminBroadcast, "Factory update")).toBe(true)
	end)

	it("rejects missing, extra, and unexpected argument types", function()
		expect(accepts(RemoteNames.RequestCollect)).toBe(false)
		expect(accepts(RemoteNames.RequestCollect, "Node_1", "extra")).toBe(false)
		expect(accepts(RemoteNames.RequestCollect, 1)).toBe(false)
		expect(accepts(RemoteNames.RequestAssignRobot, "Robot_1")).toBe(false)
		expect(accepts(RemoteNames.RequestAssignRobot, "Robot_1", {})).toBe(false)
		expect(accepts(RemoteNames.RequestAssemble, true)).toBe(false)
		expect(accepts("NotARealRemote", "payload")).toBe(false)
	end)

	it("rejects empty and oversized public strings before service handlers run", function()
		expect(accepts(RemoteNames.RequestCollect, "")).toBe(false)
		expect(accepts(RemoteNames.RequestCollect, string.rep("x", 64))).toBe(true)
		expect(accepts(RemoteNames.RequestCollect, string.rep("x", 65))).toBe(false)

		expect(accepts(RemoteNames.RequestAdminBroadcast, string.rep("x", 120))).toBe(true)
		expect(accepts(RemoteNames.RequestAdminBroadcast, string.rep("x", 121))).toBe(false)
	end)

	it("rejects unsafe zone numbers before progression code runs", function()
		expect(accepts(RemoteNames.RequestUnlockZone, 2)).toBe(true)
		expect(accepts(RemoteNames.RequestUnlockZone, 100)).toBe(true)
		expect(accepts(RemoteNames.RequestUnlockZone, 1)).toBe(false)
		expect(accepts(RemoteNames.RequestUnlockZone, 101)).toBe(false)
		expect(accepts(RemoteNames.RequestUnlockZone, 2.5)).toBe(false)
		expect(accepts(RemoteNames.RequestUnlockZone, 0 / 0)).toBe(false)
		expect(accepts(RemoteNames.RequestUnlockZone, math.huge)).toBe(false)
	end)
end)
