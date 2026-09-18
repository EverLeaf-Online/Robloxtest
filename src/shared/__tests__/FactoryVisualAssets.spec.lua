--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JestGlobals = require(ReplicatedStorage.DevPackages.JestGlobals)
local describe = JestGlobals.describe
local expect = JestGlobals.expect
local it = JestGlobals.it

local FactoryVisualAssets = require(script.Parent.Parent.Config.FactoryVisualAssets)

describe("FactoryVisualAssets", function()
	it("keeps all generated assets inside the v1 geometry budget", function()
		for _, spec in FactoryVisualAssets.Assets do
			expect(spec.TriangleBudget > 0).toBe(true)
			expect(spec.TriangleBudget <= 5_000).toBe(true)
			expect(spec.TextureResolution == 512 or spec.TextureResolution == 1024).toBe(true)
		end
	end)

	it("uses gameplay primitives for interactive machine collision", function()
		for _, family in { "Processor", "Assembler", "Storage" } do
			for _, assetId in FactoryVisualAssets.UpgradeVariants[family] do
				local spec = FactoryVisualAssets.Assets[assetId]
				expect(spec ~= nil).toBe(true)
				expect(spec.CollisionPolicy).toBe("GameplayPrimitive")
			end
		end
	end)

	it("defines exactly four visual tiers for each upgradeable machine family", function()
		for _, family in { "Processor", "Assembler", "Storage" } do
			local variants = FactoryVisualAssets.UpgradeVariants[family]
			expect(#variants).toBe(4)

			for level, assetId in variants do
				local spec = FactoryVisualAssets.Assets[assetId]
				expect(spec.UpgradeLevel).toBe(level)
			end
		end
	end)

	it("keeps every asset prompt original-brand safe and generation-ready", function()
		for _, spec in FactoryVisualAssets.Assets do
			expect(#spec.MeshyPrompt > 120).toBe(true)
			expect(string.find(string.lower(spec.MeshyPrompt), "no logos", 1, true) ~= nil).toBe(
				true
			)
			expect(
				string.find(string.lower(spec.MeshyPrompt), "no copyrighted branding", 1, true)
					~= nil
			).toBe(true)
		end
	end)

	it("accepts only real positive Roblox ids when an asset is resolved", function()
		for _, spec in FactoryVisualAssets.Assets do
			if spec.RobloxAssetId ~= nil then
				expect(spec.RobloxAssetId > 0).toBe(true)
			end
		end
	end)
end)
