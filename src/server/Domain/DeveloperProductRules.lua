--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local RobloxIds = require(ReplicatedStorage.Shared.Config.RobloxIds)

local EconomyService = require(script.Parent.Parent.Services.EconomyService)
local ProfileTypes = require(script.Parent.Parent.Data.ProfileTypes)

type ProfileData = ProfileTypes.ProfileData

local DeveloperProductRules = {}

local PRODUCT = RobloxIds.DeveloperProducts
local RECEIPT_CAP = GameConfig.Economy.MaxReceiptHistory

local MATERIAL_BUNDLE = table.freeze({
	ScrapMetal = 250,
	Wiring = 75,
	PowerCoreFragments = 10,
})

local function receiptExists(data: ProfileData, purchaseId: string): boolean
	return table.find(data.Receipts.RecentPurchaseIds, purchaseId) ~= nil
end

local function recordReceipt(data: ProfileData, purchaseId: string)
	if receiptExists(data, purchaseId) then
		return
	end

	table.insert(data.Receipts.RecentPurchaseIds, purchaseId)
	while #data.Receipts.RecentPurchaseIds > RECEIPT_CAP do
		table.remove(data.Receipts.RecentPurchaseIds, 1)
	end
end

local function canAddTokens(data: ProfileData, amount: number): boolean
	return amount > 0
		and data.Consumables.InstantProcessTokens
			<= GameConfig.Economy.MaxInstantProcessTokens - amount
end

local function addTokens(data: ProfileData, amount: number): boolean
	if not canAddTokens(data, amount) then
		return false
	end
	data.Consumables.InstantProcessTokens += amount
	return true
end

local function canGrantMaterialBundle(data: ProfileData): boolean
	for materialId, amount in MATERIAL_BUNDLE do
		local current = data.Materials[materialId]
		if current > GameConfig.Economy.MaxMaterialCount - amount then
			return false
		end
	end
	return true
end

local function grantProduct(data: ProfileData, productId: number, now: number): (boolean, string)
	if productId == PRODUCT.MaterialSupplyCrate then
		if not EconomyService.GrantPaidMaterials(data, MATERIAL_BUNDLE) then
			return false, "MATERIAL_HARD_CAP"
		end
		return true, "MaterialSupplyCrate"
	elseif productId == PRODUCT.FactoryOverclock15m then
		data.Entitlements.PersonalOverclockUntil = math.max(
			data.Entitlements.PersonalOverclockUntil,
			now
		) + 15 * 60
		return true, "FactoryOverclock15m"
	elseif productId == PRODUCT.InstantProcessTokens then
		if not addTokens(data, 5) then
			return false, "TOKEN_CAPACITY_FULL"
		end
		return true, "InstantProcessTokens"
	elseif productId == PRODUCT.StarterPack then
		local repeatPurchase = data.Entitlements.StarterPackClaimed == true
		if not canGrantMaterialBundle(data) then
			return false, "MATERIAL_HARD_CAP"
		end
		if not canAddTokens(data, 3) then
			return false, "TOKEN_CAPACITY_FULL"
		end
		if not EconomyService.CanGrantCreditsExact(data, 1_000) then
			return false, "CREDIT_CAPACITY_FULL"
		end

		assert(EconomyService.GrantPaidMaterials(data, MATERIAL_BUNDLE))
		assert(addTokens(data, 3))
		assert(EconomyService.GrantCreditsExact(data, 1_000))
		data.Entitlements.StarterPackClaimed = true
		return true, if repeatPurchase then "StarterPackRepeatPurchase" else "StarterPack"
	elseif productId == PRODUCT.ServerOverclock then
		data.Entitlements.ServerOverclockUntil = math.max(
			data.Entitlements.ServerOverclockUntil,
			now
		) + 15 * 60
		return true, "ServerOverclock"
	end

	return false, "UnknownProduct"
end

function DeveloperProductRules.HasReceipt(data: ProfileData, purchaseId: string): boolean
	return receiptExists(data, purchaseId)
end

function DeveloperProductRules.ApplyReceipt(
	data: ProfileData,
	purchaseId: string,
	productId: number,
	now: number
): (boolean, string)
	if purchaseId == "" or #purchaseId > 128 then
		return false, "INVALID_PURCHASE_ID"
	end
	if receiptExists(data, purchaseId) then
		return true, "AlreadyGranted"
	end

	local granted, productName = grantProduct(data, productId, now)
	if not granted then
		return false, productName
	end

	recordReceipt(data, purchaseId)
	return true, productName
end

return table.freeze(DeveloperProductRules)
