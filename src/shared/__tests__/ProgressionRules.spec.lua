--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JestGlobals = require(ReplicatedStorage.DevPackages.JestGlobals)
local describe = JestGlobals.describe
local expect = JestGlobals.expect
local it = JestGlobals.it

local ProgressionRules = require(script.Parent.Parent.Domain.ProgressionRules)

describe("ProgressionRules", function()
	it("returns the next configured zone", function()
		local nextZone = ProgressionRules.GetNextZone(1)
		expect(nextZone ~= nil).toBe(true)
		expect(nextZone.Id).toBe(2)
	end)

	it("normalizes persisted progression to the contiguous configured catalog", function()
		expect(ProgressionRules.NormalizeCurrentZone(1)).toBe(1)
		expect(ProgressionRules.NormalizeCurrentZone(2)).toBe(2)
		expect(ProgressionRules.NormalizeCurrentZone(99)).toBe(4)
	end)

	it("repairs malformed persisted zone values to the starter zone", function()
		expect(ProgressionRules.NormalizeCurrentZone(0)).toBe(1)
		expect(ProgressionRules.NormalizeCurrentZone(-10)).toBe(1)
		expect(ProgressionRules.NormalizeCurrentZone(1.5)).toBe(1)
		expect(ProgressionRules.NormalizeCurrentZone("2")).toBe(1)
	end)

	it("requires sequential zone unlocks", function()
		local allowed, code = ProgressionRules.EvaluateZoneUnlock(0, 2, 99_999, 99)
		expect(allowed).toBe(false)
		expect(code).toBe("ZONE_SEQUENCE_INVALID")
	end)

	it("requires enough lifetime robots", function()
		local allowed, code = ProgressionRules.EvaluateZoneUnlock(1, 2, 99_999, 2)
		expect(allowed).toBe(false)
		expect(code).toBe("MORE_ROBOTS_REQUIRED")
	end)

	it("requires enough credits", function()
		local allowed, code = ProgressionRules.EvaluateZoneUnlock(1, 2, 2_499, 3)
		expect(allowed).toBe(false)
		expect(code).toBe("NOT_ENOUGH_CREDITS")
	end)

	it("accepts the configured Zone 2 requirements", function()
		local allowed, code, definition = ProgressionRules.EvaluateZoneUnlock(1, 2, 2_500, 3)
		expect(allowed).toBe(true)
		expect(code).toBe("ZONE_UNLOCK_READY")
		expect(definition.DisplayName).toBe("Circuit Yard")
	end)

	it("rejects repeat unlocks and unknown zones", function()
		local repeatAllowed, repeatCode = ProgressionRules.EvaluateZoneUnlock(2, 2, 99_999, 99)
		local unknownAllowed, unknownCode = ProgressionRules.EvaluateZoneUnlock(2, 99, 99_999, 99)

		expect(repeatAllowed).toBe(false)
		expect(repeatCode).toBe("ZONE_ALREADY_UNLOCKED")
		expect(unknownAllowed).toBe(false)
		expect(unknownCode).toBe("UNKNOWN_ZONE")
	end)
end)
