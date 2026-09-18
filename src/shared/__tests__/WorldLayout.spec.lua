--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JestGlobals = require(ReplicatedStorage.DevPackages.JestGlobals)
local describe = JestGlobals.describe
local expect = JestGlobals.expect
local it = JestGlobals.it

local WorldLayout = require(script.Parent.Parent.Config.WorldLayout)

describe("WorldLayout", function()
	it("keeps the instanced factory footprint large enough for production and salvage", function()
		expect(WorldLayout.Plot.Size.X >= 220).toBe(true)
		expect(WorldLayout.Plot.Size.Z >= 180).toBe(true)
	end)

	it("keeps private salvage fields inside the factory footprint", function()
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

	it("keeps starter and circuit salvage as independent private fields", function()
		expect(#WorldLayout.StarterSalvageOffsets).toBe(6)
		expect(#WorldLayout.CircuitSalvageOffsets).toBe(6)
	end)

	it("keeps all bot work nodes within the private factory footprint", function()
		local halfX = WorldLayout.Plot.Size.X / 2
		local halfZ = WorldLayout.Plot.Size.Z / 2
		for _, offset in WorldLayout.BotWorkOffsets do
			expect(math.abs(offset.X) < halfX).toBe(true)
			expect(math.abs(offset.Z) < halfZ).toBe(true)
		end
	end)

	it("keeps the spawn camera comfortably inside the factory boundary", function()
		local halfZ = WorldLayout.Plot.Size.Z / 2
		local southEdge = -halfZ
		expect(WorldLayout.Plot.EntryOffset.Z - southEdge >= 25).toBe(true)
	end)

	it("keeps the hub return attendant out of the center spawn lane", function()
		local attendant = WorldLayout.Plot.HubReturnAttendantOffset
		expect(math.abs(attendant.X) >= 90).toBe(true)
	end)

	it("locks the travel cluster to the visual top-right factory corner", function()
		local halfX = WorldLayout.Plot.Size.X / 2
		local halfZ = WorldLayout.Plot.Size.Z / 2
		local attendant = WorldLayout.Plot.HubReturnAttendantOffset
		local circuitGate = WorldLayout.CircuitGateOffset

		-- Factory camera/map orientation: negative X + negative Z is the requested
		-- visual top-right quadrant. Keep both transit bots there.
		expect(attendant.X < -80).toBe(true)
		expect(attendant.Z < -70).toBe(true)
		expect(circuitGate.X < -60).toBe(true)
		expect(circuitGate.Z < -70).toBe(true)
		expect(math.abs(attendant.X) < halfX).toBe(true)
		expect(math.abs(attendant.Z) < halfZ).toBe(true)
		expect(math.abs(circuitGate.X) < halfX).toBe(true)
		expect(math.abs(circuitGate.Z) < halfZ).toBe(true)
		expect((attendant - circuitGate).Magnitude >= 18).toBe(true)
	end)
end)
