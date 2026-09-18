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

	it("rejects foreign robots before mutating work-pad state", function()
		local workPads = { Pad1 = "R1" }
		local decision = AssignmentRules.EvaluateAssignment(workPads, { R1 = {} }, "R2", "Pad2", 2)

		expect(decision.Allowed).toBe(false)
		expect(decision.Code).toBe("ROBOT_NOT_OWNED")
		expect(workPads.Pad2).toBe(nil)
	end)

	it("rejects a second robot racing for an occupied pad", function()
		local workPads = { Pad1 = "R1" }
		local owned = {
			R1 = {},
			R2 = {},
		}
		local decision = AssignmentRules.EvaluateAssignment(workPads, owned, "R2", "Pad1", 2)

		expect(decision.Allowed).toBe(false)
		expect(decision.Code).toBe("WORK_PAD_OCCUPIED")
		expect(workPads.Pad1).toBe("R1")
	end)

	it("rejects assigning the same robot to a second pad", function()
		local workPads = { Pad1 = "R1" }
		local decision = AssignmentRules.EvaluateAssignment(workPads, { R1 = {} }, "R1", "Pad2", 2)

		expect(decision.Allowed).toBe(false)
		expect(decision.Code).toBe("ROBOT_ALREADY_ASSIGNED")
		expect(decision.ExistingPadId).toBe("Pad1")
	end)

	it("rejects malformed and locked pad ids", function()
		local owned = { R1 = {} }
		local malformed = AssignmentRules.EvaluateAssignment({}, owned, "R1", "Pad0", 2)
		local locked = AssignmentRules.EvaluateAssignment({}, owned, "R1", "Pad3", 2)

		expect(malformed.Allowed).toBe(false)
		expect(malformed.Code).toBe("UNKNOWN_WORK_PAD")
		expect(locked.Allowed).toBe(false)
		expect(locked.Code).toBe("WORK_PAD_LOCKED")
	end)

	it("accepts an owned unassigned robot on a free unlocked pad", function()
		local decision = AssignmentRules.EvaluateAssignment({}, { R1 = {} }, "R1", "Pad2", 2)
		expect(decision.Allowed).toBe(true)
		expect(decision.Code).toBe("ROBOT_ASSIGNED")
		expect(decision.PadIndex).toBe(2)
	end)

	it("returns an empty assignment set for malformed inputs", function()
		local normalized = AssignmentRules.NormalizeWorkPads("bad", {}, 4)
		expect(next(normalized)).toBe(nil)
	end)
end)
