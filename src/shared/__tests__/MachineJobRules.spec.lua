--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JestGlobals = require(ReplicatedStorage.DevPackages.JestGlobals)
local describe = JestGlobals.describe
local expect = JestGlobals.expect
local it = JestGlobals.it

local MachineJobRules = require(script.Parent.Parent.Domain.MachineJobRules)

describe("MachineJobRules", function()
	it("treats reconnect-loaded overdue jobs as due immediately", function()
		expect(MachineJobRules.IsDue(true, 100, 100)).toBe(true)
		expect(MachineJobRules.IsDue(true, 100, 125)).toBe(true)
	end)

	it("does not complete an active future job early", function()
		expect(MachineJobRules.IsDue(true, 125, 100)).toBe(false)
		expect(MachineJobRules.IsWaiting(true, 125, 100)).toBe(true)
	end)

	it("ignores inactive jobs even if their persisted timestamp is stale", function()
		expect(MachineJobRules.IsDue(false, 10, 100)).toBe(false)
		expect(MachineJobRules.IsWaiting(false, 200, 100)).toBe(false)
	end)

	it("rejects malformed persisted timing values instead of treating them as complete", function()
		expect(MachineJobRules.IsDue(true, 0 / 0, 100)).toBe(false)
		expect(MachineJobRules.IsDue(true, math.huge, 100)).toBe(false)
		expect(MachineJobRules.IsDue(true, "100", 100)).toBe(false)
		expect(MachineJobRules.IsDue(true, 100, 0 / 0)).toBe(false)
	end)
end)
