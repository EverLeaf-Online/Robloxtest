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

		expect(parts <= 220).toBe(true)
		expect(collidable >= 20).toBe(true)
		expect(collidable <= 100).toBe(true)

		parent:Destroy()
	end)

	it(
		"uses optimized imported conveyors and scrap piles with server-authored collision",
		function()
			local parent = Instance.new("Model")
			local train = ScrapProcessAssetBuilder.Build(parent, 1, Vector3.zero)

			local infeed = train:FindFirstChild("InfeedConveyorVisual", true)
			local outfeed = train:FindFirstChild("FinishedRobotOutfeedVisual", true)
			local scrapPile = train:FindFirstChild("ScrapPileVisual", true)

			expect(infeed ~= nil and infeed:GetAttribute("FactoryImportedAsset") == true).toBe(true)
			expect(outfeed ~= nil and outfeed:GetAttribute("FactoryImportedAsset") == true).toBe(
				true
			)
			expect(scrapPile ~= nil and scrapPile:GetAttribute("FactoryImportedAsset") == true).toBe(
				true
			)

			for _, imported in { infeed, outfeed, scrapPile } do
				local baseParts = 0
				for _, descendant in (imported :: Instance):GetDescendants() do
					if descendant:IsA("BasePart") then
						baseParts += 1
						expect(descendant.Anchored).toBe(true)
						expect(descendant.CanCollide).toBe(false)
					end
				end
				expect(baseParts <= 2).toBe(true)
			end

			expect(train:FindFirstChild("InfeedConveyorCollision", true) ~= nil).toBe(true)
			expect(train:FindFirstChild("FinishedRobotOutfeedCollision", true) ~= nil).toBe(true)
			expect(train:FindFirstChild("ScrapPileCollision", true) ~= nil).toBe(true)

			parent:Destroy()
		end
	)

	it("anchors the complete process train before physics starts", function()
		local parent = Instance.new("Model")
		local train = ScrapProcessAssetBuilder.Build(parent, 1, Vector3.zero)
		local unanchored = {}

		for _, descendant in train:GetDescendants() do
			if descendant:IsA("BasePart") and not descendant.Anchored then
				table.insert(unanchored, descendant:GetFullName())
			end
		end

		expect(unanchored).toEqual({})
		parent:Destroy()
	end)
end)
