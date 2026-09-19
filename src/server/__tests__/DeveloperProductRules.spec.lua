--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JestGlobals = require(ReplicatedStorage.DevPackages.JestGlobals)
local describe = JestGlobals.describe
local expect = JestGlobals.expect
local it = JestGlobals.it

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local RobloxIds = require(ReplicatedStorage.Shared.Config.RobloxIds)
local TransactionRules = require(ReplicatedStorage.Shared.Domain.TransactionRules)

local serverRoot = script.Parent.Parent
local ProfileTemplate = require(serverRoot.Data.ProfileTemplate)
local DeveloperProductRules = require(serverRoot.Domain.DeveloperProductRules)

local PRODUCT = RobloxIds.DeveloperProducts

local function deepCopy(value: any): any
	if typeof(value) ~= "table" then
		return value
	end
	local result = {}
	for key, child in value do
		result[deepCopy(key)] = deepCopy(child)
	end
	return result
end

local function applyTransaction(
	data: any,
	purchaseId: string,
	productId: number,
	now: number
): (boolean, any?)
	local boundaryOk, result = TransactionRules.Execute(data, function(draft)
		local granted, code = DeveloperProductRules.ApplyReceipt(draft, purchaseId, productId, now)
		return granted, code
	end)
	return boundaryOk, result
end

describe("DeveloperProductRules", function()
	it("grants a developer product exactly once for a duplicate purchase id", function()
		local data = deepCopy(ProfileTemplate)

		local ok, code =
			applyTransaction(data, "purchase-1", PRODUCT.InstantProcessTokens, 1_700_000_000)
		expect(ok).toBe(true)
		expect(code).toBe("InstantProcessTokens")
		expect(data.Consumables.InstantProcessTokens).toBe(5)
		expect(#data.Receipts.RecentPurchaseIds).toBe(1)

		local duplicateOk, duplicateCode =
			applyTransaction(data, "purchase-1", PRODUCT.InstantProcessTokens, 1_700_000_001)
		expect(duplicateOk).toBe(true)
		expect(duplicateCode).toBe("AlreadyGranted")
		expect(data.Consumables.InstantProcessTokens).toBe(5)
		expect(#data.Receipts.RecentPurchaseIds).toBe(1)
	end)

	it("does not record a failed paid-material grant and permits a later retry", function()
		local data = deepCopy(ProfileTemplate)
		data.Materials.ScrapMetal = GameConfig.Economy.MaxMaterialCount

		local ok, code =
			applyTransaction(data, "purchase-materials", PRODUCT.MaterialSupplyCrate, 1_700_000_000)
		expect(ok).toBe(true)
		expect(code).toBe("MATERIAL_HARD_CAP")
		expect(#data.Receipts.RecentPurchaseIds).toBe(0)
		expect(data.Materials.Wiring).toBe(0)
		expect(data.Materials.PowerCoreFragments).toBe(0)

		data.Materials.ScrapMetal = 0
		local retryOk, retryCode =
			applyTransaction(data, "purchase-materials", PRODUCT.MaterialSupplyCrate, 1_700_000_001)
		expect(retryOk).toBe(true)
		expect(retryCode).toBe("MaterialSupplyCrate")
		expect(DeveloperProductRules.HasReceipt(data, "purchase-materials")).toBe(true)
		expect(data.Materials.ScrapMetal).toBe(250)
		expect(data.Materials.Wiring).toBe(75)
		expect(data.Materials.PowerCoreFragments).toBe(10)
	end)

	it("keeps Starter Pack grants atomic when any reward component is at capacity", function()
		local data = deepCopy(ProfileTemplate)
		data.Consumables.InstantProcessTokens = GameConfig.Economy.MaxInstantProcessTokens - 2

		local ok, code =
			applyTransaction(data, "purchase-starter", PRODUCT.StarterPack, 1_700_000_000)
		expect(ok).toBe(true)
		expect(code).toBe("TOKEN_CAPACITY_FULL")
		expect(data.Materials.ScrapMetal).toBe(0)
		expect(data.Materials.Wiring).toBe(0)
		expect(data.Materials.PowerCoreFragments).toBe(0)
		expect(data.Currencies.Credits).toBe(0)
		expect(data.Consumables.InstantProcessTokens).toBe(
			GameConfig.Economy.MaxInstantProcessTokens - 2
		)
		expect(data.Entitlements.StarterPackClaimed).toBe(false)
		expect(#data.Receipts.RecentPurchaseIds).toBe(0)
	end)

	it("does not record unknown products or invalid purchase ids", function()
		local data = deepCopy(ProfileTemplate)

		local unknownOk, unknownCode =
			applyTransaction(data, "purchase-unknown", 999_999_999, 1_700_000_000)
		expect(unknownOk).toBe(true)
		expect(unknownCode).toBe("UnknownProduct")
		expect(#data.Receipts.RecentPurchaseIds).toBe(0)

		local invalidOk, invalidCode = applyTransaction(
			data,
			string.rep("X", 129),
			PRODUCT.InstantProcessTokens,
			1_700_000_000
		)
		expect(invalidOk).toBe(true)
		expect(invalidCode).toBe("INVALID_PURCHASE_ID")
		expect(data.Consumables.InstantProcessTokens).toBe(0)
		expect(#data.Receipts.RecentPurchaseIds).toBe(0)
	end)

	it("caps the profile receipt history without duplicating retained ids", function()
		local data = deepCopy(ProfileTemplate)
		local total = GameConfig.Economy.MaxReceiptHistory + 1

		for index = 1, total do
			local purchaseId = ("overclock-%04d"):format(index)
			local ok, code = applyTransaction(
				data,
				purchaseId,
				PRODUCT.FactoryOverclock15m,
				1_700_000_000 + index
			)
			expect(ok).toBe(true)
			expect(code).toBe("FactoryOverclock15m")
		end

		expect(#data.Receipts.RecentPurchaseIds).toBe(GameConfig.Economy.MaxReceiptHistory)
		expect(DeveloperProductRules.HasReceipt(data, "overclock-0001")).toBe(false)
		expect(DeveloperProductRules.HasReceipt(data, ("overclock-%04d"):format(total))).toBe(true)
	end, 15_000)
end)
