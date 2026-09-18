--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JestGlobals = require(ReplicatedStorage.DevPackages.JestGlobals)
local describe = JestGlobals.describe
local expect = JestGlobals.expect
local it = JestGlobals.it

local WorldLayout = require(script.Parent.Parent.Config.WorldLayout)

describe("WorldLayout", function()
	it("keeps all eight private yards well separated", function()
		local centers = {}
		for plotId = 1, 8 do
			centers[plotId] = WorldLayout.GetPlotCenter(plotId)
		end

		for first = 1, 8 do
			for second = first + 1, 8 do
				local distance = (centers[first] - centers[second]).Magnitude
				expect(distance >= 400).toBe(true)
			end
		end
	end)

	it("keeps private salvage fields inside the plot footprint", function()
		local halfX = WorldLayout.Plot.Size.X / 2
		local halfZ = WorldLayout.Plot.Size.Z / 2

		for _, offsets in
			{
				WorldLayout.StarterSalvageOffsets,
				WorldLayout.CircuitSalvageOffsets,
			}
		do
			for _, offset in offsets do
				expect(math.abs(offset.X) < halfX).toBe(true)
				expect(math.abs(offset.Z) < halfZ).toBe(true)
			end
		end
	end)

	it("gives every yard independent starter and circuit salvage sets", function()
		expect(#WorldLayout.StarterSalvageOffsets).toBe(6)
		expect(#WorldLayout.CircuitSalvageOffsets).toBe(6)
	end)
end)
