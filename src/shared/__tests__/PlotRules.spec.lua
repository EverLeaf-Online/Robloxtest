--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JestGlobals = require(ReplicatedStorage.DevPackages.JestGlobals)
local describe = JestGlobals.describe
local expect = JestGlobals.expect
local it = JestGlobals.it

local PlotRules = require(script.Parent.Parent.Domain.PlotRules)

describe("PlotRules", function()
	it("returns the first unclaimed plot", function()
		local claimed = {
			[1] = true,
			[3] = true,
		}

		expect(PlotRules.FindFirstFree(4, claimed)).toBe(2)
	end)

	it("returns nil when every plot is claimed", function()
		local claimed = {
			[1] = true,
			[2] = true,
			[3] = true,
		}

		expect(PlotRules.FindFirstFree(3, claimed)).toBe(nil)
	end)

	it("returns nil when no plots exist", function()
		expect(PlotRules.FindFirstFree(0, {})).toBe(nil)
	end)

	it("validates plot ids against configured bounds", function()
		expect(PlotRules.IsValidPlotId(1, 8)).toBe(true)
		expect(PlotRules.IsValidPlotId(8, 8)).toBe(true)
		expect(PlotRules.IsValidPlotId(0, 8)).toBe(false)
		expect(PlotRules.IsValidPlotId(9, 8)).toBe(false)
		expect(PlotRules.IsValidPlotId(1.5, 8)).toBe(false)
	end)
end)
