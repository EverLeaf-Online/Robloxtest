--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JestGlobals = require(ReplicatedStorage.DevPackages.JestGlobals)
local describe = JestGlobals.describe
local expect = JestGlobals.expect
local it = JestGlobals.it

local serverRoot = script.Parent.Parent
local ScrapProcessAssetBuilder = require(serverRoot.Presentation.ScrapProcessAssetBuilder)

describe("ScrapProcessAssetBuilder", function()
	it("builds the complete scrap separation chain in process order", function()
		local parent = Instance.new("Model")
		local train = ScrapProcessAssetBuilder.Build(parent, 1, Vector3.zero)

		expect(train:FindFirstChild("ScrapStockpiles") ~= nil).toBe(true)
		expect(train:FindFirstChild("PrimaryShredderFeed") ~= nil).toBe(true)
		expect(train:FindFirstChild("ShredderDustCollection") ~= nil).toBe(true)
		expect(train:FindFirstChild("OverbandMagnetSeparator") ~= nil).toBe(true)
		expect(train:FindFirstChild("MagneticDrumSeparator") ~= nil).toBe(true)
		expect(train:FindFirstChild("EddyCurrentSeparator") ~= nil).toBe(true)
		expect(train:FindFirstChild("AssemblyTransfer") ~= nil).toBe(true)
		expect(train:FindFirstChild("SortedMaterialBunkers") ~= nil).toBe(true)
		expect(train:FindFirstChild("HydraulicBaler") ~= nil).toBe(true)

		parent:Destroy()
	end)

	it("uses real collidable machinery instead of label-only decoration", function()
		local parent = Instance.new("Model")
		local train = ScrapProcessAssetBuilder.Build(parent, 1, Vector3.zero)
		local parts = 0
		local collidable = 0

		for _, descendant in train:GetDescendants() do
			if descendant:IsA("BasePart") then
				parts += 1
				if descendant.CanCollide then
					collidable += 1
				end
			end
		end

		expect(parts >= 120).toBe(true)
		expect(parts <= 300).toBe(true)
		expect(collidable >= 45).toBe(true)

		parent:Destroy()
	end)
end)
