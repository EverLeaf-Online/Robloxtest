--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JestGlobals = require(ReplicatedStorage.DevPackages.JestGlobals)
local describe = JestGlobals.describe
local expect = JestGlobals.expect
local it = JestGlobals.it

local AssignmentRules = require(script.Parent.Parent.Domain.AssignmentRules)

describe("AssignmentRules", function()
	it("keeps distinct owned robots on valid pads", function()
		local normalized = AssignmentRules.NormalizeWorkPads({
			Pad1 = "R1",
			Pad2 = "R2",
		}, {
			R1 = {},
			R2 = {},
		}, 4)

		expect(normalized.Pad1).toBe("R1")
		expect(normalized.Pad2).toBe("R2")
	end)

	it("deduplicates the same robot to the lowest valid pad", function()
		local normalized = AssignmentRules.NormalizeWorkPads({
			Pad1 = "R1",
			Pad2 = "R1",
			Pad3 = "R1",
		}, {
			R1 = {},
		}, 4)

		expect(normalized.Pad1).toBe("R1")
		expect(normalized.Pad2).toBe(nil)
		expect(normalized.Pad3).toBe(nil)
	end)

	it("drops unknown robots and out-of-range pad keys", function()
		local normalized = AssignmentRules.NormalizeWorkPads({
			Pad1 = "Missing",
			Pad4 = "R4",
			Pad5 = "R5",
			NotAPad = "R6",
		}, {
			R4 = {},
			R5 = {},
			R6 = {},
		}, 4)

		expect(normalized.Pad1).toBe(nil)
		expect(normalized.Pad4).toBe("R4")
		expect(normalized.Pad5).toBe(nil)
		expect(normalized.NotAPad).toBe(nil)
	end)

	it("drops assignments above the currently unlocked work-slot count", function()
		local normalized = AssignmentRules.NormalizeWorkPads({
			Pad1 = "R1",
			Pad2 = "R2",
			Pad3 = "R3",
		}, {
			R1 = {},
			R2 = {},
			R3 = {},
		}, 1)

		expect(normalized.Pad1).toBe("R1")
		expect(normalized.Pad2).toBe(nil)
		expect(normalized.Pad3).toBe(nil)
	end)

	it("returns an empty assignment set for malformed inputs", function()
		local normalized = AssignmentRules.NormalizeWorkPads("bad", {}, 4)
		expect(next(normalized)).toBe(nil)
	end)
end)
