--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JestGlobals = require(ReplicatedStorage.DevPackages.JestGlobals)
local describe = JestGlobals.describe
local expect = JestGlobals.expect
local it = JestGlobals.it

local OfflineProductionRules = require(script.Parent.Parent.Domain.OfflineProductionRules)

describe("OfflineProductionRules", function()
	it("uses the newest persisted activity timestamp", function()
		expect(OfflineProductionRules.GetElapsedSeconds(1_000, 700, 900, 8 * 60 * 60)).toBe(100)
	end)

	it("caps offline elapsed time", function()
		expect(OfflineProductionRules.GetElapsedSeconds(100_000, 1, 0, 28_800)).toBe(28_800)
	end)

	it("does not grant time for new or future timestamps", function()
		expect(OfflineProductionRules.GetElapsedSeconds(1_000, 0, 0, 28_800)).toBe(0)
		expect(OfflineProductionRules.GetElapsedSeconds(1_000, 1_001, 0, 28_800)).toBe(0)
	end)

	it("applies efficiency and permanent production multiplier", function()
		expect(OfflineProductionRules.GetCreditGrant(5, 3_600, 0.5, 2, 1_000_000)).toBe(18_000)
	end)

	it("caps credit grants and rejects invalid values", function()
		expect(OfflineProductionRules.GetCreditGrant(1_000, 28_800, 1, 2, 10_000)).toBe(10_000)
		expect(OfflineProductionRules.GetCreditGrant(0 / 0, 10, 1, 1, 10_000)).toBe(0)
	end)
end)
