--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JestGlobals = require(ReplicatedStorage.DevPackages.JestGlobals)
local describe = JestGlobals.describe
local expect = JestGlobals.expect
local it = JestGlobals.it

local RobotInventoryRules = require(script.Parent.Parent.Domain.RobotInventoryRules)

describe("RobotInventoryRules", function()
	it("uses the requested uid when it is free", function()
		local nextUid = RobotInventoryRules.FindAvailableUidNumber({
			R1 = {},
		}, 2, 500)

		expect(nextUid).toBe(2)
		expect(RobotInventoryRules.FormatUid(nextUid :: number)).toBe("R2")
	end)

	it("skips occupied uid values instead of overwriting robots", function()
		local nextUid = RobotInventoryRules.FindAvailableUidNumber({
			R1 = {},
			R2 = {},
		}, 1, 500)

		expect(nextUid).toBe(3)
	end)

	it("wraps safely after the maximum uid number", function()
		local maxUid = 2_147_483_647
		local nextUid = RobotInventoryRules.FindAvailableUidNumber({
			[RobotInventoryRules.FormatUid(maxUid)] = {},
		}, maxUid, 500)

		expect(nextUid).toBe(1)
		expect(RobotInventoryRules.AdvanceUidNumber(maxUid)).toBe(1)
	end)

	it("repairs malformed requested counters by starting at one", function()
		local nextUid = RobotInventoryRules.FindAvailableUidNumber({}, -50, 500)
		expect(nextUid).toBe(1)
	end)

	it("returns nil when the bounded search has no free uid", function()
		local nextUid = RobotInventoryRules.FindAvailableUidNumber({
			R1 = {},
			R2 = {},
			R3 = {},
		}, 1, 2)

		expect(nextUid).toBe(nil)
	end)

	it("accepts only canonical bounded robot uid strings", function()
		expect(RobotInventoryRules.ParseUid("R1")).toBe(1)
		expect(RobotInventoryRules.ParseUid("R2147483647")).toBe(2_147_483_647)
		expect(RobotInventoryRules.IsValidUid("R42")).toBe(true)

		expect(RobotInventoryRules.ParseUid("R0")).toBe(nil)
		expect(RobotInventoryRules.ParseUid("R01")).toBe(nil)
		expect(RobotInventoryRules.ParseUid("R2147483648")).toBe(nil)
		expect(RobotInventoryRules.ParseUid("robot-1")).toBe(nil)
		expect(RobotInventoryRules.ParseUid(1)).toBe(nil)
		expect(RobotInventoryRules.IsValidUid("R01")).toBe(false)
	end)
end)
