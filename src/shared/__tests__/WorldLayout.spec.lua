--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JestGlobals = require(ReplicatedStorage.DevPackages.JestGlobals)
local describe = JestGlobals.describe
local expect = JestGlobals.expect
local it = JestGlobals.it

local WorldLayout = require(script.Parent.Parent.Config.WorldLayout)

describe("WorldLayout", function()
	it(
		"keeps the instanced factory footprint large enough for production and starter salvage",
		function()
			expect(WorldLayout.Plot.Size.X >= 220).toBe(true)
			expect(WorldLayout.Plot.Size.Z >= 180).toBe(true)
		end
	)

	it("keeps starter salvage inside the main factory footprint", function()
		local halfX = WorldLayout.Plot.Size.X / 2
		local halfZ = WorldLayout.Plot.Size.Z / 2

		for _, offset in WorldLayout.StarterSalvageOffsets do
			expect(math.abs(offset.X) < halfX).toBe(true)
			expect(math.abs(offset.Z) < halfZ).toBe(true)
		end
	end)

	it("keeps Circuit salvage inside the separate Circuit island", function()
		local island = WorldLayout.CircuitIsland
		local halfX = island.Size.X / 2
		local halfZ = island.Size.Z / 2

		for _, offset in WorldLayout.CircuitSalvageOffsets do
			local localOffset = offset - island.CenterOffset
			expect(math.abs(localOffset.X) < halfX).toBe(true)
			expect(math.abs(localOffset.Z) < halfZ).toBe(true)
		end
	end)

	it("keeps starter and Circuit salvage as independent six-node fields", function()
		expect(#WorldLayout.StarterSalvageOffsets).toBe(6)
		expect(#WorldLayout.CircuitSalvageOffsets).toBe(6)
	end)

	it("keeps starter bot work nodes on the main factory and Circuit work on the island", function()
		local halfX = WorldLayout.Plot.Size.X / 2
		local halfZ = WorldLayout.Plot.Size.Z / 2

		for name, offset in WorldLayout.BotWorkOffsets do
			if name == "CircuitSalvage" then
				local island = WorldLayout.CircuitIsland
				local localOffset = offset - island.CenterOffset
				expect(math.abs(localOffset.X) < island.Size.X / 2).toBe(true)
				expect(math.abs(localOffset.Z) < island.Size.Z / 2).toBe(true)
			else
				expect(math.abs(offset.X) < halfX).toBe(true)
				expect(math.abs(offset.Z) < halfZ).toBe(true)
			end
		end
	end)

	it("keeps the spawn camera comfortably inside the factory boundary", function()
		local halfZ = WorldLayout.Plot.Size.Z / 2
		local southEdge = -halfZ
		expect(WorldLayout.Plot.EntryOffset.Z - southEdge >= 25).toBe(true)
	end)

	it("keeps both transit attendants in the visual top-right corner", function()
		local attendant = WorldLayout.Plot.HubReturnAttendantOffset
		local circuitGate = WorldLayout.CircuitGateOffset

		expect(attendant.X < -80).toBe(true)
		expect(attendant.Z < -70).toBe(true)
		expect(circuitGate.X < -60).toBe(true)
		expect(circuitGate.Z < -70).toBe(true)
		expect((attendant - circuitGate).Magnitude >= 18).toBe(true)
	end)

	it(
		"places the Circuit island beyond the top-right edge with a bridge spanning the gap",
		function()
			local plotSouthEdge = -(WorldLayout.Plot.Size.Z / 2)
			local island = WorldLayout.CircuitIsland
			local islandNorthEdge = island.CenterOffset.Z + island.Size.Z / 2
			local bridgeNorthEdge = island.BridgeCenterOffset.Z + island.BridgeSize.Z / 2
			local bridgeSouthEdge = island.BridgeCenterOffset.Z - island.BridgeSize.Z / 2

			expect(islandNorthEdge < plotSouthEdge).toBe(true)
			expect(math.abs(bridgeNorthEdge - plotSouthEdge) <= 0.1).toBe(true)
			expect(math.abs(bridgeSouthEdge - islandNorthEdge) <= 0.1).toBe(true)
			expect(island.BridgeCenterOffset.X).toBe(island.BoundaryOpeningCenterX)
			expect(island.BridgeSize.X < island.BoundaryOpeningWidth).toBe(true)
		end
	)
end)
