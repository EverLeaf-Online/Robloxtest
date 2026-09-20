--!strict

local DataStoreService = game:GetService("DataStoreService")
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local RobloxIds = require(ReplicatedStorage.Shared.Config.RobloxIds)
local RemoteNames = require(ReplicatedStorage.Shared.Networking.RemoteNames)

local DataService = require(script.Parent.DataService)
local DeveloperProductRules = require(script.Parent.Parent.Domain.DeveloperProductRules)
local ReceiptRecoveryRules = require(script.Parent.Parent.Domain.ReceiptRecoveryRules)
local EconomyService = require(script.Parent.EconomyService)
local PlotService = require(script.Parent.PlotService)
local RemoteService = require(script.Parent.RemoteService)
local StateService = require(script.Parent.StateService)
local ProfileTypes = require(script.Parent.Parent.Data.ProfileTypes)

type ProfileData = ProfileTypes.ProfileData
type RecoveryEvidence = ReceiptRecoveryRules.RecoveryEvidence
type ReceiptLedgerContains = (number, string) -> boolean?
type ReceiptLedgerMark = (number, string) -> boolean
type RecoveryAuditContains = (number, string) -> boolean?
type RecoveryAuditMark = (number, string, number, string, number) -> boolean
type RecoveryNow = () -> number

local MonetizationService = {}
local initialized = false

local PRODUCT = RobloxIds.DeveloperProducts
local PASSES = RobloxIds.Passes
local FACTORY_CLUB = RobloxIds.Subscription.FactoryClub
local ReceiptLedgerStore = DataStoreService:GetDataStore("ScrapToBot_ReceiptLedger_v1")
local ReceiptRecoveryAuditStore = DataStoreService:GetDataStore("ScrapToBot_ReceiptRecoveryAudit_v1")
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

local function receiptLedgerKey(userId: number): string
	return ("Player_%d"):format(userId)
end

local function receiptLedgerContains(userId: number, purchaseId: string): boolean?
	if RunService:IsStudio() then
		return false
	end
	local ok, ledgerOrError =
		pcall(ReceiptLedgerStore.GetAsync, ReceiptLedgerStore, receiptLedgerKey(userId))
	if not ok then
		warn(
			("[MonetizationService] Receipt ledger read failed for %d: %s"):format(
				userId,
				tostring(ledgerOrError)
			)
		)
		return nil
	end
	return typeof(ledgerOrError) == "table" and (ledgerOrError :: any)[purchaseId] == true
end

local function markReceiptInLedger(userId: number, purchaseId: string): boolean
	if RunService:IsStudio() then
		return true
	end
	local ok, err = pcall(function()
		ReceiptLedgerStore:UpdateAsync(receiptLedgerKey(userId), function(current)
			local ledger = if typeof(current) == "table" then current else {}
			ledger[purchaseId] = true
			return ledger
		end)
	end)
	if not ok then
		warn(
			("[MonetizationService] Receipt ledger write failed for %d/%s: %s"):format(
				userId,
				purchaseId,
				tostring(err)
			)
		)
		return false
	end
	return true
end

local function receiptRecoveryAuditContains(userId: number, purchaseId: string): boolean?
	if RunService:IsStudio() then
		return false
	end
	local ok, auditOrError =
		pcall(ReceiptRecoveryAuditStore.GetAsync, ReceiptRecoveryAuditStore, receiptLedgerKey(userId))
	if not ok then
		warn(
			("[MonetizationService] Receipt recovery audit read failed for %d: %s"):format(
				userId,
				tostring(auditOrError)
			)
		)
		return nil
	end
	return typeof(auditOrError) == "table" and (auditOrError :: any)[purchaseId] ~= nil
end

local function markReceiptRecoveryAudit(
	userId: number,
	purchaseId: string,
	productId: number,
	evidenceReference: string,
	recoveredAt: number
): boolean
	if RunService:IsStudio() then
		return true
	end
	local ok, err = pcall(function()
		ReceiptRecoveryAuditStore:UpdateAsync(receiptLedgerKey(userId), function(current)
			local audit = if typeof(current) == "table" then current else {}
			audit[purchaseId] = {
				ProductId = productId,
				EvidenceReference = evidenceReference,
				RecoveredAt = recoveredAt,
			}
			return audit
		end)
	end)
	if not ok then
		warn(
			("[MonetizationService] Receipt recovery audit write failed for %d/%s: %s"):format(
				userId,
				purchaseId,
				tostring(err)
			)
		)
		return false
	end
	return true
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

local function adoptServerOverclock(untilTimestamp: number)
	if untilTimestamp <= serverOverclockUntil or untilTimestamp <= os.time() then
		return
	end
	serverOverclockUntil = untilTimestamp
	refreshServerOverclockAttributes()
	scheduleServerOverclockExpiry(serverOverclockUntil)
end

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
		player:SetAttribute("InstantProcessTokens", data.Consumables.InstantProcessTokens)
		player:SetAttribute("StarterPackClaimed", data.Entitlements.StarterPackClaimed)
		player:SetAttribute("PersonalOverclockUntil", data.Entitlements.PersonalOverclockUntil)
		player:SetAttribute("PurchasedServerOverclockUntil", data.Entitlements.ServerOverclockUntil)
		player:SetAttribute(
			"FactoryClubLastGrantedCycle",
			data.Entitlements.FactoryClubLastGrantedCycle
		)
		player:SetAttribute(
			"FactoryClubEquippedCosmetic",
			data.Entitlements.EquippedFactoryClubCosmetic
		)
		local cosmeticCount = 0
		for _ in data.Entitlements.FactoryClubCosmetics do
			cosmeticCount += 1
		end
		player:SetAttribute("FactoryClubCosmeticCount", cosmeticCount)
	end
	PlotService.RefreshPresentation(player)
end

local MATERIAL_BUNDLE = table.freeze({
	ScrapMetal = 250,
	Wiring = 75,
	PowerCoreFragments = 10,
})

local function addMaterialBundle(data: ProfileData): boolean
	return EconomyService.GrantPaidMaterials(data, MATERIAL_BUNDLE)
end

local function addTokens(data: ProfileData, amount: number): boolean
	if
		amount <= 0
		or data.Consumables.InstantProcessTokens
			> GameConfig.Economy.MaxInstantProcessTokens - amount
	then
		return false
	end
	data.Consumables.InstantProcessTokens += amount
	return true
end

local function acknowledgeRecordedReceipt(
	player: Player,
	purchaseId: string,
	productId: number,
	ledgerMark: ReceiptLedgerMark
): Enum.ProductPurchaseDecision
	local saved, persistedData = DataService.SaveNow(player, function(snapshot)
		return DeveloperProductRules.HasReceipt(snapshot, purchaseId)
	end)
	if not saved or persistedData == nil then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	if productId == PRODUCT.ServerOverclock then
		adoptServerOverclock(persistedData.Entitlements.ServerOverclockUntil)
	end
	-- The lifetime ledger is written only after ProfileStore has emitted OnAfterSave
	-- for a snapshot that contains this PurchaseId. A ledger entry therefore never
	-- acknowledges paid value that only exists in volatile server memory.
	if not ledgerMark(player.UserId, purchaseId) then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

local function processReceiptForPlayer(
	player: Player,
	receiptInfo: { [string]: any },
	ledgerContainsOverride: ReceiptLedgerContains?,
	ledgerMarkOverride: ReceiptLedgerMark?
): Enum.ProductPurchaseDecision
	local ledgerContainsFn = ledgerContainsOverride or receiptLedgerContains
	local ledgerMarkFn = ledgerMarkOverride or markReceiptInLedger
	if not DataService.IsReady(player) then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local purchaseId = tostring(receiptInfo.PurchaseId)
	local existing = DataService.GetData(player)
	if existing == nil then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	if DeveloperProductRules.HasReceipt(existing, purchaseId) then
		return acknowledgeRecordedReceipt(player, purchaseId, receiptInfo.ProductId, ledgerMarkFn)
	end

	local ledgerContains = ledgerContainsFn(player.UserId, purchaseId)
	if ledgerContains == nil then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	if ledgerContains then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end

	local productName = ""
	local executed, result = DataService.Transaction(player, function(data)
		local granted, resolvedName =
			DeveloperProductRules.ApplyReceipt(data, purchaseId, receiptInfo.ProductId, os.time())
		if not granted then
			return false, resolvedName
		end
		if resolvedName ~= "AlreadyGranted" then
			productName = resolvedName
		end
		return true, resolvedName
	end)

	if not executed then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	if result == "AlreadyGranted" then
		return acknowledgeRecordedReceipt(player, purchaseId, receiptInfo.ProductId, ledgerMarkFn)
	end
	if productName == "" then
		if result == "UnknownProduct" then
			warn(
				("[MonetizationService] Unknown developer product %s"):format(
					tostring(receiptInfo.ProductId)
				)
			)
		end
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local saved, persistedData = DataService.SaveNow(player, function(snapshot)
		return DeveloperProductRules.HasReceipt(snapshot, purchaseId)
	end)
	if not saved or persistedData == nil then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	if productName == "ServerOverclock" then
		adoptServerOverclock(persistedData.Entitlements.ServerOverclockUntil)
	end
	if not ledgerMarkFn(player.UserId, purchaseId) then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	setPresentationAttributes(player)
	StateService.PushSnapshot(player)
	productGrantedEvent:Fire(player, productName, receiptInfo.ProductId)
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

local function processReceipt(receiptInfo: { [string]: any }): Enum.ProductPurchaseDecision
	local player = Players:GetPlayerByUserId(receiptInfo.PlayerId)
	if player == nil then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	return processReceiptForPlayer(player, receiptInfo, nil, nil)
end

local function recoverHistoricalReceiptForPlayer(
	player: Player,
	evidence: RecoveryEvidence,
	ledgerContainsFn: ReceiptLedgerContains,
	recoveryAuditContainsFn: RecoveryAuditContains,
	recoveryAuditMarkFn: RecoveryAuditMark,
	nowFn: RecoveryNow
): (boolean, string)
	if not DataService.IsReady(player) then
		return false, "PROFILE_NOT_READY"
	end
	if evidence.UserId ~= player.UserId then
		return false, "USER_ID_MISMATCH"
	end

	local validEvidence, evidenceCode = ReceiptRecoveryRules.ValidateEvidence(evidence)
	if not validEvidence then
		return false, evidenceCode
	end

	local ledgerContains = ledgerContainsFn(player.UserId, evidence.PurchaseId)
	if ledgerContains == nil then
		return false, "RECEIPT_LEDGER_READ_FAILED"
	end
	if ledgerContains ~= true then
		return false, "LEDGER_ENTRY_NOT_FOUND"
	end

	local recoveryRecorded = recoveryAuditContainsFn(player.UserId, evidence.PurchaseId)
	if recoveryRecorded == nil then
		return false, "RECOVERY_AUDIT_READ_FAILED"
	end
	if recoveryRecorded then
		return true, "ALREADY_RECOVERED"
	end

	local existing = DataService.GetData(player)
	if existing == nil then
		return false, "PROFILE_NOT_READY"
	end

	-- If the profile already has the receipt, never re-grant. Record the recovery
	-- audit so a future bounded receipt-history eviction cannot turn this case into
	-- a duplicate compensation.
	if DeveloperProductRules.HasReceipt(existing, evidence.PurchaseId) then
		local recoveredAt = nowFn()
		if
			not recoveryAuditMarkFn(
				player.UserId,
				evidence.PurchaseId,
				evidence.ProductId,
				evidence.EvidenceReference,
				recoveredAt
			)
		then
			return false, "RECOVERY_AUDIT_WRITE_FAILED"
		end
		return true, "PROFILE_ALREADY_RECORDED"
	end

	local matches, matchCode = ReceiptRecoveryRules.MatchesProfile(existing, evidence)
	if not matches then
		return false, matchCode
	end

	local recoveredProductName = ""
	local recoveredAt = nowFn()
	local executed, result = DataService.Transaction(player, function(data)
		if DeveloperProductRules.HasReceipt(data, evidence.PurchaseId) then
			return true, "AlreadyGranted"
		end

		local stillMatches, currentMatchCode = ReceiptRecoveryRules.MatchesProfile(data, evidence)
		if not stillMatches then
			return false, currentMatchCode
		end

		local granted, productName = DeveloperProductRules.ApplyReceipt(
			data,
			evidence.PurchaseId,
			evidence.ProductId,
			recoveredAt
		)
		if not granted then
			return false, productName
		end
		if productName ~= "AlreadyGranted" then
			recoveredProductName = productName
		end
		return true, productName
	end)
	if not executed then
		return false, tostring(result)
	end

	local saved, persistedData = DataService.SaveNow(player, function(snapshot)
		return DeveloperProductRules.HasReceipt(snapshot, evidence.PurchaseId)
	end)
	if not saved or persistedData == nil then
		return false, "RECOVERY_SAVE_FAILED"
	end

	if
		not recoveryAuditMarkFn(
			player.UserId,
			evidence.PurchaseId,
			evidence.ProductId,
			evidence.EvidenceReference,
			recoveredAt
		)
	then
		return false, "RECOVERY_AUDIT_WRITE_FAILED"
	end

	if recoveredProductName == "ServerOverclock" then
		adoptServerOverclock(persistedData.Entitlements.ServerOverclockUntil)
	end
	if recoveredProductName ~= "" then
		setPresentationAttributes(player)
		StateService.PushSnapshot(player)
		productGrantedEvent:Fire(player, recoveredProductName, evidence.ProductId)
		return true, "RECOVERED_" .. recoveredProductName
	end

	return true, "PROFILE_ALREADY_RECORDED"
end

function MonetizationService.RecoverHistoricalReceipt(
	player: Player,
	evidence: RecoveryEvidence
): (boolean, string)
	return recoverHistoricalReceiptForPlayer(
		player,
		evidence,
		receiptLedgerContains,
		receiptRecoveryAuditContains,
		markReceiptRecoveryAudit,
		os.time
	)
end

-- Test-model entry point. Production callers use RecoverHistoricalReceipt above;
-- this variant injects ledgers so OCALE never touches live DataStores.
function MonetizationService.RecoverHistoricalReceiptForTests(
	player: Player,
	evidence: RecoveryEvidence,
	ledgerContainsFn: ReceiptLedgerContains,
	recoveryAuditContainsFn: RecoveryAuditContains,
	recoveryAuditMarkFn: RecoveryAuditMark,
	nowFn: RecoveryNow
): (boolean, string)
	return recoverHistoricalReceiptForPlayer(
		player,
		evidence,
		ledgerContainsFn,
		recoveryAuditContainsFn,
		recoveryAuditMarkFn,
		nowFn
	)
end

function MonetizationService.ProcessReceipt(
	receiptInfo: { [string]: any }
): Enum.ProductPurchaseDecision
	return processReceipt(receiptInfo)
end

function MonetizationService.ProcessReceiptForStudio(
	receiptInfo: { [string]: any }
): Enum.ProductPurchaseDecision
	assert(RunService:IsStudio(), "ProcessReceiptForStudio may only be used in Studio")
	return MonetizationService.ProcessReceipt(receiptInfo)
end

-- Test-model entry point for exercising ProcessReceipt with a fake Player. This is
-- server-only module API and is never bound to a RemoteEvent or Marketplace callback.
function MonetizationService.ProcessReceiptForPlayerForTests(
	player: Player,
	receiptInfo: { [string]: any }
): Enum.ProductPurchaseDecision
	return processReceiptForPlayer(player, receiptInfo, function()
		return false
	end, function()
		return true
	end)
end

local function refreshPass(player: Player, passName: string, passId: number): boolean?
	local ok, ownsOrError =
		pcall(MarketplaceService.UserOwnsGamePassAsync, MarketplaceService, player.UserId, passId)
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

local function subscriptionCycleId(player: Player): string?
	local ok, historyOrError = pcall(
		MarketplaceService.GetUserSubscriptionPaymentHistoryAsync,
		MarketplaceService,
		player,
		FACTORY_CLUB
	)
	if not ok then
		warn(
			("[MonetizationService] Subscription payment history failed for %d: %s"):format(
				player.UserId,
				tostring(historyOrError)
			)
		)
		return nil
	end
	if typeof(historyOrError) ~= "table" then
		return nil
	end
	local newest = 0
	for _, entry in historyOrError do
		local cycleStart = (entry :: any).CycleStartTime
		if typeof(cycleStart) == "DateTime" then
			newest = math.max(newest, cycleStart.UnixTimestamp)
		end
	end
	return if newest > 0 then tostring(newest) else nil
end

local function applyFactoryClubState(
	player: Player,
	isSubscribed: boolean,
	cycleId: string?
): (boolean, string)
	if not DataService.IsReady(player) then
		return false, "PROFILE_NOT_READY"
	end

	subscriptionActive[player] = isSubscribed
	local granted = false
	local cosmeticId = if cycleId ~= nil and cycleId ~= "" then "Club_" .. cycleId else ""
	local executed, transactionResult = DataService.Transaction(player, function(data)
		data.Entitlements.FactoryClubActiveCached = isSubscribed
		if not isSubscribed or cycleId == nil or cycleId == "" then
			return true, false
		end
		if data.Entitlements.FactoryClubLastGrantedCycle == cycleId then
			return true, false
		end
		if not addMaterialBundle(data) or not addTokens(data, 3) then
			return false, "FACTORY_CLUB_REWARD_CAPACITY"
		end
		data.Entitlements.FactoryClubLastGrantedCycle = cycleId
		data.Entitlements.FactoryClubCosmetics[cosmeticId] = true
		if data.Entitlements.EquippedFactoryClubCosmetic == "" then
			data.Entitlements.EquippedFactoryClubCosmetic = cosmeticId
		end
		granted = true
		return true, true
	end)
	if not executed then
		setPresentationAttributes(player)
		StateService.PushSnapshot(player)
		if transactionResult == "FACTORY_CLUB_REWARD_CAPACITY" then
			return false, "FACTORY_CLUB_REWARD_CAPACITY"
		end
		return false, "FACTORY_CLUB_TRANSACTION_FAILED"
	end

	setPresentationAttributes(player)
	StateService.PushSnapshot(player)

	if granted then
		if not DataService.SaveNow(player) then
			warn(
				("[MonetizationService] Failed to persist Factory Club grant for %d"):format(
					player.UserId
				)
			)
			return false, "FACTORY_CLUB_SAVE_FAILED"
		end
		factoryClubRewardEvent:Fire(player, cycleId, cosmeticId)
		return true, "FACTORY_CLUB_ENABLED_AND_GRANTED"
	end

	if isSubscribed and cycleId == nil then
		return true, "FACTORY_CLUB_ENABLED_REWARD_PENDING"
	end
	return true,
		if isSubscribed then "FACTORY_CLUB_ENABLED_NO_DUPLICATE" else "FACTORY_CLUB_DISABLED"
end

function MonetizationService.SetFactoryClubForStudio(
	player: Player,
	active: boolean
): (boolean, string)
	assert(RunService:IsStudio(), "SetFactoryClubForStudio may only be used in Studio")
	return applyFactoryClubState(player, active, if active then "StudioTestCycle" else nil)
end

function MonetizationService.EquipFactoryClubCosmetic(
	player: Player,
	cosmeticId: string
): (boolean, string)
	if #cosmeticId > 32 then
		return false, "INVALID_COSMETIC"
	end

	local executed, code = DataService.Transaction(player, function(data)
		if cosmeticId ~= "" and data.Entitlements.FactoryClubCosmetics[cosmeticId] ~= true then
			return false, "COSMETIC_NOT_OWNED"
		end
		data.Entitlements.EquippedFactoryClubCosmetic = cosmeticId
		return true, "COSMETIC_EQUIPPED"
	end)
	if not executed then
		return false, tostring(code)
	end
	if code ~= "COSMETIC_EQUIPPED" then
		return false, tostring(code)
	end
	if not DataService.SaveNow(player) then
		return false, "SAVE_FAILED"
	end

	setPresentationAttributes(player)
	StateService.PushSnapshot(player)
	return true, "COSMETIC_EQUIPPED"
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
	local cycleId = if isSubscribed then subscriptionCycleId(player) else nil
	applyFactoryClubState(player, isSubscribed, cycleId)
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

	MarketplaceService.ProcessReceipt = MonetizationService.ProcessReceipt
	refreshServerOverclockAttributes()

	RemoteService.BindRequest(RemoteNames.RequestEquipClubCosmetic, function(player, cosmeticId)
		if typeof(cosmeticId) ~= "string" then
			StateService.ActionResult(player, "EquipClubCosmetic", false, "INVALID_COSMETIC")
			return
		end
		local success, code = MonetizationService.EquipFactoryClubCosmetic(player, cosmeticId)
		StateService.ActionResult(player, "EquipClubCosmetic", success, code)
	end)

	MarketplaceService.PromptGamePassPurchaseFinished:Connect(
		function(player: Player, gamePassId: number, wasPurchased: boolean)
			if not wasPurchased then
				return
			end
			for _, passName in PASS_NAMES do
				if PASSES[passName] == gamePassId then
					task.spawn(function()
						local owns = refreshPass(player, passName, gamePassId)
						if owns ~= true or player.Parent ~= Players then
							return
						end
						passFlags[player] = passFlags[player] or {}
						passFlags[player][passName] = true
						DataService.Transaction(player, function(data)
							data.Entitlements.CachedPassFlags[passName] = true
							return true, nil
						end)
						setPresentationAttributes(player)
						passUpdatedEvent:Fire(player, passName, true)
					end)
					break
				end
			end
		end
	)

	MarketplaceService.PromptSubscriptionPurchaseFinished:Connect(
		function(player: Player, subscriptionId: string, didTryPurchasing: boolean)
			if subscriptionId ~= FACTORY_CLUB or not didTryPurchasing then
				return
			end
			task.delay(3, function()
				if player.Parent == Players then
					MonetizationService.RefreshSubscription(player)
				end
			end)
		end
	)

	DataService.ProfileLoaded:Connect(function(player)
		local data = DataService.GetData(player)
		if data ~= nil then
			adoptServerOverclock(data.Entitlements.ServerOverclockUntil)
		end
		task.spawn(MonetizationService.RefreshPlayer, player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		passFlags[player] = nil
		subscriptionActive[player] = nil
	end)
end

return MonetizationService
