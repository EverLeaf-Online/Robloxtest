--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JestGlobals = require(ReplicatedStorage.DevPackages.JestGlobals)
local describe = JestGlobals.describe
local expect = JestGlobals.expect
local it = JestGlobals.it

local RobotWorkRules = require(script.Parent.Parent.Domain.RobotWorkRules)

describe("RobotWorkRules", function()
	it("gives every launch family a bounded valid route", function()
		for _, family in
			{
				"Salvager",
				"Technician",
				"Hauler",
				"Courier",
				"Extractor",
				"Foreman",
			}
		do
			local route = RobotWorkRules.GetRoute(family)
			expect(#route >= 2).toBe(true)
			expect(#route <= 4).toBe(true)
			for _, nodeName in route do
				expect(RobotWorkRules.IsValidWorkNode(nodeName)).toBe(true)
			end
		end
	end)

	it("falls back safely for an unknown family", function()
		local route = RobotWorkRules.GetRoute("Unknown")
		expect(#route).toBe(2)
		expect(route[1]).toBe("Processor")
		expect(route[2]).toBe("Storage")
	end)

	it("keeps movement speeds positive and bounded", function()
		for _, locomotion in { "Wheels", "Tracks", "Legs", "Hover", "Unknown" } do
			local speed = RobotWorkRules.GetMoveSpeed(locomotion)
			expect(speed >= 6).toBe(true)
			expect(speed <= 14).toBe(true)
		end
	end)
end)
