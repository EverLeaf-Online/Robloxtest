--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local JestGlobals = require(ReplicatedStorage.DevPackages.JestGlobals)
local describe = JestGlobals.describe
local expect = JestGlobals.expect
local it = JestGlobals.it

local serverRoot = script.Parent.Parent
local CircuitUnlockButtonBuilder = require(serverRoot.Presentation.CircuitUnlockButtonBuilder)

local function makeAnchor(): Part
	local anchor = Instance.new("Part")
	anchor.Name = "CircuitYardGate"
	anchor.Anchored = true
	anchor.Size = Vector3.new(8, 2, 8)
	anchor.Position = Vector3.new(-101, 1.1, -94)
	return anchor
end

describe("CircuitUnlockButtonBuilder", function()
	it("builds a committed low-profile floor button", function()
		local plot = Instance.new("Model")
		plot.Parent = Workspace
		local anchor = makeAnchor()
		anchor.Parent = plot

		local button = CircuitUnlockButtonBuilder.Build(plot, 1, anchor)
		local base = button:FindFirstChild("LowerBase")
		local dome = button:FindFirstChild("ButtonDome")

		expect(button:GetAttribute("AuthoredInRepo")).toBe(true)
		expect(button:GetAttribute("RequiredZone")).toBe(2)
		expect(base ~= nil and base:IsA("BasePart")).toBe(true)
		expect(dome ~= nil and dome:IsA("BasePart")).toBe(true)

		local basePart = base :: BasePart
		local domePart = dome :: BasePart
		local floorY = anchor.Position.Y - (anchor.Size.Y / 2)

		expect(basePart.Size.X >= 9).toBe(true)
		expect(basePart.Size.Z >= 9).toBe(true)
		expect(domePart.Position.Y - floorY < 2).toBe(true)
		expect(button:FindFirstChild("HazardPad1") ~= nil).toBe(true)

		plot:Destroy()
	end)

	it("contains no runtime-loaded or executable third-party content", function()
		local plot = Instance.new("Model")
		plot.Parent = Workspace
		local anchor = makeAnchor()
		anchor.Parent = plot

		local button = CircuitUnlockButtonBuilder.Build(plot, 1, anchor)
		expect(button:GetAttribute("CreatorStoreAssetId")).toBe(nil)
		expect(button:GetAttribute("CreatorStoreFallback")).toBe(nil)

		for _, descendant in button:GetDescendants() do
			expect(descendant:IsA("Script")).toBe(false)
			expect(descendant:IsA("LocalScript")).toBe(false)
			expect(descendant:IsA("ModuleScript")).toBe(false)
			expect(descendant:IsA("LayerCollector")).toBe(false)
			expect(descendant:IsA("RemoteEvent")).toBe(false)
			expect(descendant:IsA("RemoteFunction")).toBe(false)
		end

		plot:Destroy()
	end)

	it("keeps every visual part anchored and non-colliding", function()
		local plot = Instance.new("Model")
		plot.Parent = Workspace
		local anchor = makeAnchor()
		anchor.Parent = plot

		local button = CircuitUnlockButtonBuilder.Build(plot, 1, anchor)
		local partCount = 0

		for _, descendant in button:GetDescendants() do
			if descendant:IsA("BasePart") then
				partCount += 1
				expect(descendant.Anchored).toBe(true)
				expect(descendant.CanCollide).toBe(false)
				expect(descendant.CanTouch).toBe(false)
				expect(descendant.CanQuery).toBe(false)
			end
		end

		expect(partCount >= 12).toBe(true)
		expect(partCount <= 24).toBe(true)

		plot:Destroy()
	end)
end)
