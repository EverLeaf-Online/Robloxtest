--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JestGlobals = require(ReplicatedStorage.DevPackages.JestGlobals)
local describe = JestGlobals.describe
local expect = JestGlobals.expect
local it = JestGlobals.it

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local RobloxIds = require(ReplicatedStorage.Shared.Config.RobloxIds)

local serverRoot = script.Parent.Parent
local ProfileTemplate = require(serverRoot.Data.ProfileTemplate)
local DataService = require(serverRoot.Services.DataService)
local MonetizationService = require(serverRoot.Services.MonetizationServiceUnderTest)
local PlotService = require(serverRoot.Services.PlotService)
local StateService = require(serverRoot.Services.StateService)

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

local function makeFakePlayer(): Player
	return Instance.new("Folder") :: any
end

local function makeReceiptPlayer(userId: number): Player
	local attributes: { [string]: any } = {}
	local fake: any = {
		UserId = userId,
	}
	function fake:SetAttribute(name: string, value: any)
		attributes[name] = value
	end
	function fake:GetAttribute(name: string): any
		return attributes[name]
	end
	function fake:Destroy() end
	return fake :: Player
end

local function resetFakes()
	DataService.Reset()
	PlotService.Reset()
	StateService.Reset()
end

describe("MonetizationService integration", function()
	it("derives launch game-pass effects from authoritative cached entitlement data", function()
		resetFakes()
		local player = makeFakePlayer()
		local data = deepCopy(ProfileTemplate)
		data.Entitlements.CachedPassFlags.Production2x = true
		data.Entitlements.CachedPassFlags.ExpandedStorage = true
		data.Entitlements.CachedPassFlags.BotWorkSlots2 = true
		data.Entitlements.CachedPassFlags.AutoCollect = true
		data.Entitlements.CachedPassFlags.FactoryVIP = true
		DataService.SetData(player, data)

		expect(MonetizationService.GetPermanentProductionMultiplier(player)).toBe(2)
		expect(MonetizationService.GetStorageMultiplier(player)).toBe(2)
		expect(MonetizationService.GetExtraWorkSlots(player)).toBe(2)
		expect(MonetizationService.HasAutoCollect(player)).toBe(true)
		expect(MonetizationService.HasVIP(player)).toBe(true)
		expect(MonetizationService.GetAssemblerTimeMultiplier(player)).toBe(
			GameConfig.Factory.FactoryVIPAssemblerTimeMultiplier
		)

		player:Destroy()
	end)

	it("stacks a live personal overclock on top of the permanent 2x production pass", function()
		resetFakes()
		local player = makeFakePlayer()
		local data = deepCopy(ProfileTemplate)
		data.Entitlements.CachedPassFlags.Production2x = true
		data.Entitlements.PersonalOverclockUntil = os.time() + 60
		DataService.SetData(player, data)

		expect(MonetizationService.GetProductionMultiplier(player)).toBe(4)

		data.Entitlements.PersonalOverclockUntil = os.time() - 1
		expect(MonetizationService.GetProductionMultiplier(player)).toBe(2)

		player:Destroy()
	end)

	it("never acknowledges paid value before the receipt grant is durably saved", function()
		resetFakes()
		local player = makeReceiptPlayer(7001)
		local data = deepCopy(ProfileTemplate)
		DataService.SetData(player, data)
		DataService.SetPersistedData(player, deepCopy(data))
		DataService.SetSaveResult(player, false)

		local purchaseId = "durability-regression-1"
		local receipt = {
			PlayerId = player.UserId,
			PurchaseId = purchaseId,
			ProductId = RobloxIds.DeveloperProducts.InstantProcessTokens,
		}

		local firstDecision = MonetizationService.ProcessReceiptForPlayerForTests(player, receipt)
		expect(firstDecision).toBe(Enum.ProductPurchaseDecision.NotProcessedYet)
		expect(data.Consumables.InstantProcessTokens).toBe(5)
		expect(table.find(data.Receipts.RecentPurchaseIds, purchaseId)).never.toBe(nil)

		local beforeCrash = DataService.GetPersistedData(player)
		assert(beforeCrash ~= nil, "persisted baseline should exist")
		expect(beforeCrash.Consumables.InstantProcessTokens).toBe(0)
		expect(table.find(beforeCrash.Receipts.RecentPurchaseIds, purchaseId)).toBe(nil)

		expect(DataService.SimulateCrashReload(player)).toBe(true)
		local reloaded = DataService.GetData(player)
		assert(reloaded ~= nil, "crash reload should restore persisted data")
		expect(reloaded.Consumables.InstantProcessTokens).toBe(0)
		expect(table.find(reloaded.Receipts.RecentPurchaseIds, purchaseId)).toBe(nil)

		DataService.SetSaveResult(player, true)
		local retryDecision = MonetizationService.ProcessReceiptForPlayerForTests(player, receipt)
		expect(retryDecision).toBe(Enum.ProductPurchaseDecision.PurchaseGranted)

		local persisted = DataService.GetPersistedData(player)
		assert(persisted ~= nil, "successful retry should persist a snapshot")
		expect(persisted.Consumables.InstantProcessTokens).toBe(5)
		expect(table.find(persisted.Receipts.RecentPurchaseIds, purchaseId)).never.toBe(nil)
		expect(DataService.GetSaveCount(player)).toBe(2)

		player:Destroy()
	end)

	it("equips only owned Factory Club cosmetics and persists the selection", function()
		resetFakes()
		local player = makeFakePlayer()
		local data = deepCopy(ProfileTemplate)
		data.Entitlements.FactoryClubCosmetics.Club_1700000000 = true
		DataService.SetData(player, data)

		local success, code =
			MonetizationService.EquipFactoryClubCosmetic(player, "Club_1700000000")

		expect(success).toBe(true)
		expect(code).toBe("COSMETIC_EQUIPPED")
		expect(data.Entitlements.EquippedFactoryClubCosmetic).toBe("Club_1700000000")
		expect(data.Revision).toBe(1)
		expect(DataService.GetSaveCount(player)).toBe(1)
		expect(PlotService.GetRefreshCount(player)).toBe(1)
		expect(StateService.GetSnapshotPushCount(player)).toBe(1)
		expect(player:GetAttribute("FactoryClubEquippedCosmetic")).toBe("Club_1700000000")

		player:Destroy()
	end)

	it("rejects unowned Factory Club cosmetics without saving or mutating", function()
		resetFakes()
		local player = makeFakePlayer()
		local data = deepCopy(ProfileTemplate)
		DataService.SetData(player, data)

		local success, code = MonetizationService.EquipFactoryClubCosmetic(player, "Club_NotOwned")

		expect(success).toBe(false)
		expect(code).toBe("COSMETIC_NOT_OWNED")
		expect(data.Entitlements.EquippedFactoryClubCosmetic).toBe("")
		expect(data.Revision).toBe(0)
		expect(DataService.GetSaveCount(player)).toBe(0)
		expect(StateService.GetSnapshotPushCount(player)).toBe(0)

		player:Destroy()
	end)

	it("rejects oversized cosmetic identifiers before entering a transaction", function()
		resetFakes()
		local player = makeFakePlayer()
		local data = deepCopy(ProfileTemplate)
		DataService.SetData(player, data)

		local success, code =
			MonetizationService.EquipFactoryClubCosmetic(player, string.rep("X", 33))

		expect(success).toBe(false)
		expect(code).toBe("INVALID_COSMETIC")
		expect(data.Revision).toBe(0)
		expect(DataService.GetSaveCount(player)).toBe(0)

		player:Destroy()
	end)
end)
