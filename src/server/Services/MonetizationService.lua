--!strict

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local RobloxIds = require(ReplicatedStorage.Shared.Config.RobloxIds)

local DataService = require(script.Parent.DataService)
local EconomyService = require(script.Parent.EconomyService)
local StateService = require(script.Parent.StateService)

local MonetizationService = {}
local initialized = false

local PRODUCT = RobloxIds.DeveloperProducts
local PASSES = RobloxIds.Passes
local FACTORY_CLUB = RobloxIds.Subscription.FactoryClub
local RECEIPT_CAP = 100
local PASS_NAMES = table.freeze({
	"Production2x",
	"ExpandedStorage",
	"BotWorkSlots2",
	"AutoCollect",
	"FactoryVIP",
})

local passFlags: { [Player]: { [string]: boolean } } = {}
local subscriptionActive: { [Player]: boolean } = {}
local serverOverclockUntil = 0

local productGrantedEvent = Instance.new("BindableEvent")
local factoryClubRewardEvent = Instance.new("BindableEvent")
local passUpdatedEvent = Instance.new("BindableEvent")

MonetizationService.ProductGranted = productGrantedEvent.Event
MonetizationService.FactoryClubRewardGranted = factoryClubRewardEvent.Event
MonetizationService.PassUpdated = passUpdatedEvent.Event

local function setPresentationAttributes(player: Player)
	local flags = passFlags[player] or {}
	player:SetAttribute("PassProduction2x", flags.Production2x == true)
	player:SetAttribute("PassExpandedStorage", flags.ExpandedStorage == true)
	player:SetAttribute("PassBotWorkSlots2", flags.BotWorkSlots2 == true)
	player:SetAttribute("PassAutoCollect", flags.AutoCollect == true)
	player:SetAttribute("PassFactoryVIP", flags.FactoryVIP == true)
	player:SetAttribute("VIPNameplateEnabled", flags.FactoryVIP == true)
	player:SetAttribute("VIPNameplateText", if flags.FactoryVIP == true then "FACTORY VIP" else "")
	player:SetAttribute(
		"VIPAssemblerTimeMultiplier",
		if flags.FactoryVIP == true then GameConfig.Factory.FactoryVIPAssemblerTimeMultiplier else 1
	)

	local clubActive = subscriptionActive[player] == true
	player:SetAttribute("FactoryClubActive", clubActive)
	player:SetAttribute("FactoryClubNameplateEnabled", clubActive)
	player:SetAttribute("FactoryClubNameplateText", if clubActive then "FACTORY CLUB" else "")
	player:SetAttribute(
		"FactoryClubStorageMultiplier",
		if clubActive then GameConfig.Factory.FactoryClubStorageMultiplier else 1
	)

	local data = DataService.GetData(player)
	if data ~= nil then
		EconomyService.SetRuntimeStorageMultiplier(
			data,
			if clubActive then GameConfig.Factory.FactoryClubStorageMultiplier else 1
		)
		player:SetAttribute("InstantProcessTokens", data.Consumables.InstantProcessTokens)
		player:SetAttribute("StarterPackClaimed", data.Entitlements.StarterPackClaimed)
		player:SetAttribute("PersonalOverclockUntil", data.Entitlements.PersonalOverclockUntil)
		player:SetAttribute("FactoryClubLastGrantedCycle", data.Entitlements.FactoryClubLastGrantedCycle)
		player:SetAttribute("FactoryClubEquippedCosmetic", data.Entitlements.EquippedFactoryClubCosmetic)
		local cosmeticCount = 0
		for _ in data.Entitlements.FactoryClubCosmetics do
			cosmeticCount += 1
		end
		player:SetAttribute("FactoryClubCosmeticCount", cosmeticCount)
	end
end

local function addMaterialBundle(data: any)
	data.Materials.ScrapMetal = math.min(
		GameConfig.Economy.MaxMaterialCount,
		data.Materials.ScrapMetal + 250
	)
	data.Materials.Wiring = math.min(
		GameConfig.Economy.MaxMaterialCount,
		data.Materials.Wiring + 75
	)
	data.Materials.PowerCoreFragments = math.min(
		GameConfig.Economy.MaxMaterialCount,
		data.Materials.PowerCoreFragments + 10
	)
end

local function addTokens(data: any, amount: number)
	data.Consumables.InstantProcessTokens = math.min(
		GameConfig.Economy.MaxInstantProcessTokens,
		data.Consumables.InstantProcessTokens + amount
	)
end

local function addCredits(data: any, amount: number)
	local room = GameConfig.Economy.MaxCredits - data.Currencies.Credits
	local granted = math.max(0, math.min(room, amount))
	data.Currencies.Credits += granted
	data.Stats.LifetimeCredits = math.min(
		GameConfig.Economy.MaxCredits,
		data.Stats.LifetimeCredits + granted
	)
end

local function receiptExists(data: any, purchaseId: string): boolean
	return table.find(data.Receipts.RecentPurchaseIds, purchaseId) ~= nil
end

local function recordReceipt(data: any, purchaseId: string)
	if receiptExists(data, purchaseId) then
		return
	end
	table.insert(data.Receipts.RecentPurchaseIds, purchaseId)
	while #data.Receipts.RecentPurchaseIds > RECEIPT_CAP do
		table.remove(data.Receipts.RecentPurchaseIds, 1)
	end
end

local function refreshServerOverclockAttributes()
	local active = serverOverclockUntil > os.time()
	workspace:SetAttribute("ServerOverclockUntil", serverOverclockUntil)
	workspace:SetAttribute("ServerOverclockActive", active)
end

local function scheduleServerOverclockExpiry(expectedUntil: number)
	task.delay(math.max(0, expectedUntil - os.time()) + 0.1, function()
		if serverOverclockUntil == expectedUntil and serverOverclockUntil <= os.time() then
			refreshServerOverclockAttributes()
		end
	end)
end

local function grantProduct(data: any, productId: number): (boolean, string)
	if productId == PRODUCT.MaterialSupplyCrate then
		addMaterialBundle(data)
		return true, "MaterialSupplyCrate"
	elseif productId == PRODUCT.FactoryOverclock15m then
		local now = os.time()
		data.Entitlements.PersonalOverclockUntil =
			math.max(data.Entitlements.PersonalOverclockUntil, now) + 15 * 60
		return true, "FactoryOverclock15m"
	elseif productId == PRODUCT.InstantProcessTokens then
		addTokens(data, 5)
		return true, "InstantProcessTokens"
	elseif productId == PRODUCT.StarterPack then
		if data.Entitlements.StarterPackClaimed then
			return true, "StarterPackRepeatBlocked"
		end
		addMaterialBundle(data)
		addTokens(data, 3)
		addCredits(data, 1_000)
		data.Entitlements.StarterPackClaimed = true
		return true, "StarterPack"
	elseif productId == PRODUCT.ServerOverclock then
		serverOverclockUntil = math.max(serverOverclockUntil, os.time()) + 15 * 60
		refreshServerOverclockAttributes()
		scheduleServerOverclockExpiry(serverOverclockUntil)
		return true, "ServerOverclock"
	end
	return false, "UnknownProduct"
end

local function processReceipt(receiptInfo: { [string]: any }): Enum.ProductPurchaseDecision
	local player = Players:GetPlayerByUserId(receiptInfo.PlayerId)
	if player == nil or not DataService.IsReady(player) then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local purchaseId = tostring(receiptInfo.PurchaseId)
	local existing = DataService.GetData(player)
	if existing == nil then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	if receiptExists(existing, purchaseId) then
		return if DataService.SaveNow(player)
			then Enum.ProductPurchaseDecision.PurchaseGranted
			else Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local productName = ""
	local executed, result = DataService.Transaction(player, function(data)
		if receiptExists(data, purchaseId) then
			return true, "AlreadyGranted"
		end

		local granted, resolvedName = grantProduct(data, receiptInfo.ProductId)
		if not granted then
			return false, "UNKNOWN_PRODUCT"
		end
		productName = resolvedName
		recordReceipt(data, purchaseId)
		return true, resolvedName
	end)

	if not executed then
		if result == "UNKNOWN_PRODUCT" then
			warn(("[MonetizationService] Unknown developer product %s"):format(tostring(receiptInfo.ProductId)))
		end
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	if not DataService.SaveNow(player) then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	setPresentationAttributes(player)
	StateService.PushSnapshot(player)
	productGrantedEvent:Fire(player, productName, receiptInfo.ProductId)
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

local function refreshPass(player: Player, passName: string, passId: number): boolean?
	local ok, ownsOrError = pcall(
		MarketplaceService.UserOwnsGamePassAsync,
		MarketplaceService,
		player.UserId,
		passId
	)
	if not ok then
		warn(
			("[MonetizationService] Pass check failed for %d/%s: %s"):format(
				player.UserId,
				passName,
				tostring(ownsOrError)
			)
		)
		return nil
	end
	return ownsOrError == true
end

function MonetizationService.RefreshPasses(player: Player)
	if not DataService.IsReady(player) then
		return
	end

	local resolved: { [string]: boolean } = {}
	for _, passName in PASS_NAMES do
		local passId = PASSES[passName]
		local owns = refreshPass(player, passName, passId)
		if owns ~= nil then
			resolved[passName] = owns
		end
	end

	passFlags[player] = passFlags[player] or {}
	local flags = passFlags[player]
	for passName, owns in resolved do
		flags[passName] = owns
	end

	DataService.Transaction(player, function(data)
		for passName, owns in resolved do
			data.Entitlements.CachedPassFlags[passName] = owns
		end
		return true, nil
	end)
	setPresentationAttributes(player)
end

function MonetizationService.HasPass(player: Player, passName: string): boolean
	local flags = passFlags[player]
	if flags ~= nil and flags[passName] ~= nil then
		return flags[passName] == true
	end
	local data = DataService.GetData(player)
	return data ~= nil and data.Entitlements.CachedPassFlags[passName] == true
end

function MonetizationService.GetPermanentProductionMultiplier(player: Player): number
	return if MonetizationService.HasPass(player, "Production2x") then 2 else 1
end

function MonetizationService.GetProductionMultiplier(player: Player): number
	local multiplier = MonetizationService.GetPermanentProductionMultiplier(player)
	local data = DataService.GetData(player)
	if data ~= nil and data.Entitlements.PersonalOverclockUntil > os.time() then
		multiplier *= 2
	end
	if serverOverclockUntil > os.time() then
		multiplier *= 2
	end
	return multiplier
end

function MonetizationService.GetAssemblerTimeMultiplier(player: Player): number
	return if MonetizationService.HasPass(player, "FactoryVIP")
		then GameConfig.Factory.FactoryVIPAssemblerTimeMultiplier
		else 1
end

function MonetizationService.GetStorageMultiplier(player: Player): number
	local multiplier = if MonetizationService.HasPass(player, "ExpandedStorage") then 2 else 1
	if subscriptionActive[player] == true then
		multiplier *= GameConfig.Factory.FactoryClubStorageMultiplier
	end
	return multiplier
end

function MonetizationService.GetExtraWorkSlots(player: Player): number
	return if MonetizationService.HasPass(player, "BotWorkSlots2") then 2 else 0
end

function MonetizationService.HasAutoCollect(player: Player): boolean
	return MonetizationService.HasPass(player, "AutoCollect")
end

function MonetizationService.HasVIP(player: Player): boolean
	return MonetizationService.HasPass(player, "FactoryVIP")
end

function MonetizationService.IsFactoryClubActive(player: Player): boolean
	return subscriptionActive[player] == true
end

local function subscriptionCycleId(player: Player): string
	local ok, historyOrError = pcall(
		MarketplaceService.GetUserSubscriptionPaymentHistoryAsync,
		MarketplaceService,
		player,
		FACTORY_CLUB
	)
	if ok and typeof(historyOrError) == "table" then
		local newest = 0
		for _, entry in historyOrError do
			local cycleStart = (entry :: any).CycleStartTime
			if typeof(cycleStart) == "DateTime" then
				newest = math.max(newest, cycleStart.UnixTimestamp)
			end
		end
		if newest > 0 then
			return tostring(newest)
		end
	end
	return os.date("!%Y-%m", os.time())
end

function MonetizationService.RefreshSubscription(player: Player)
	if not DataService.IsReady(player) then
		return
	end

	local ok, statusOrError = pcall(
		MarketplaceService.GetUserSubscriptionStatusAsync,
		MarketplaceService,
		player,
		FACTORY_CLUB
	)
	if not ok then
		warn(
			("[MonetizationService] Subscription check failed for %d: %s"):format(
				player.UserId,
				tostring(statusOrError)
			)
		)
		return
	end

	local isSubscribed = (statusOrError :: any).IsSubscribed == true
	subscriptionActive[player] = isSubscribed
	if not isSubscribed then
		setPresentationAttributes(player)
		return
	end

	local cycleId = subscriptionCycleId(player)
	local cosmeticId = "Club_" .. cycleId
	local granted = false
	local executed = DataService.Transaction(player, function(data)
		if data.Entitlements.FactoryClubLastGrantedCycle == cycleId then
			return true, false
		end
		addMaterialBundle(data)
		addTokens(data, 3)
		data.Entitlements.FactoryClubLastGrantedCycle = cycleId
		data.Entitlements.FactoryClubCosmetics[cosmeticId] = true
		if data.Entitlements.EquippedFactoryClubCosmetic == "" then
			data.Entitlements.EquippedFactoryClubCosmetic = cosmeticId
		end
		granted = true
		return true, true
	end)

	if executed and granted then
		if DataService.SaveNow(player) then
			factoryClubRewardEvent:Fire(player, cycleId, cosmeticId)
			StateService.PushSnapshot(player)
		else
			warn(("[MonetizationService] Failed to persist Factory Club grant for %d"):format(player.UserId))
		end
	end
	setPresentationAttributes(player)
end

function MonetizationService.RefreshPlayer(player: Player)
	MonetizationService.RefreshPasses(player)
	MonetizationService.RefreshSubscription(player)
end

function MonetizationService.Init()
	if initialized then
		return
	end
	initialized = true

	MarketplaceService.ProcessReceipt = processReceipt
	refreshServerOverclockAttributes()

	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(
		player: Player,
		gamePassId: number,
		wasPurchased: boolean
	)
		if not wasPurchased then
			return
		end
		for _, passName in PASS_NAMES do
			if PASSES[passName] == gamePassId then
				passFlags[player] = passFlags[player] or {}
				passFlags[player][passName] = true
				DataService.Transaction(player, function(data)
					data.Entitlements.CachedPassFlags[passName] = true
					return true, nil
				end)
				setPresentationAttributes(player)
				passUpdatedEvent:Fire(player, passName, true)
				break
			end
		end
	end)

	MarketplaceService.PromptSubscriptionPurchaseFinished:Connect(function(
		player: Player,
		subscriptionId: string,
		didTryPurchasing: boolean
	)
		if subscriptionId ~= FACTORY_CLUB or not didTryPurchasing then
			return
		end
		task.delay(3, function()
			if player.Parent == Players then
				MonetizationService.RefreshSubscription(player)
			end
		end)
	end)

	DataService.ProfileLoaded:Connect(function(player)
		task.spawn(MonetizationService.RefreshPlayer, player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		passFlags[player] = nil
		subscriptionActive[player] = nil
	end)
end

return MonetizationService
