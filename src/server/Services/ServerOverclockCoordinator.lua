--!strict

local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local RobloxIds = require(ReplicatedStorage.Shared.Config.RobloxIds)

local DataService = require(script.Parent.DataService)
local MonetizationService = require(script.Parent.MonetizationService)

local ServerOverclockCoordinator = {}

local STORE_NAME = "ScrapToBot_ServerOverclockLease_v1"
local LEASE_SECONDS = 75
local HEARTBEAT_SECONDS = 30
local BOOST_SECONDS = 15 * 60
local SERVER_OVERCLOCK_PRODUCT_ID = RobloxIds.DeveloperProducts.ServerOverclock
local LeaseStore = DataStoreService:GetDataStore(STORE_NAME)
local SESSION_ID = if game.JobId ~= ""
	then game.JobId
	else "Studio_" .. HttpService:GenerateGUID(false)

local initialized = false
local activeLeaseId = ""
local activeBoostUntil = 0
local activeLeaseUntil = 0
local attributeWriteActive = false

type LeaseRecord = {
	BoostUntil: number,
	OwnerJobId: string,
	LeaseUntil: number,
	UpdatedAt: number,
	AppliedPurchases: { [string]: boolean },
}

local function leaseKey(leaseId: string): string
	return "Lease_" .. leaseId
end

local function isValidLeaseId(value: any): boolean
	return typeof(value) == "string" and #value > 0 and #value <= 128
end

local function normalizeRecord(value: any): LeaseRecord
	local record = if typeof(value) == "table" then value else {}
	local applied = if typeof(record.AppliedPurchases) == "table"
		then record.AppliedPurchases
		else {}
	return {
		BoostUntil = if typeof(record.BoostUntil) == "number" then record.BoostUntil else 0,
		OwnerJobId = if typeof(record.OwnerJobId) == "string" then record.OwnerJobId else "",
		LeaseUntil = if typeof(record.LeaseUntil) == "number" then record.LeaseUntil else 0,
		UpdatedAt = if typeof(record.UpdatedAt) == "number" then record.UpdatedAt else 0,
		AppliedPurchases = applied,
	}
end

local function hasEffectiveServerOverclock(): boolean
	local now = os.time()
	return activeLeaseId ~= "" and activeBoostUntil > now and activeLeaseUntil > now
end

local function refreshWorkspaceAttributes()
	local active = hasEffectiveServerOverclock()
	attributeWriteActive = true
	Workspace:SetAttribute("ServerOverclockUntil", if active then activeBoostUntil else 0)
	Workspace:SetAttribute("ServerOverclockActive", active)
	attributeWriteActive = false
end

local function clearActiveLease()
	activeLeaseId = ""
	activeBoostUntil = 0
	activeLeaseUntil = 0
	refreshWorkspaceAttributes()
end

local function adoptLease(leaseId: string, record: LeaseRecord)
	activeLeaseId = leaseId
	activeBoostUntil = record.BoostUntil
	activeLeaseUntil = record.LeaseUntil
	refreshWorkspaceAttributes()
end

local function updateLease(
	leaseId: string,
	transform: (LeaseRecord, number) -> LeaseRecord?
): LeaseRecord?
	local ok, updatedOrError = pcall(function()
		return LeaseStore:UpdateAsync(leaseKey(leaseId), function(current)
			local now = os.time()
			local record = normalizeRecord(current)
			return transform(record, now)
		end)
	end)
	if not ok then
		warn(
			("[ServerOverclockCoordinator] Lease update failed for %s: %s"):format(
				leaseId,
				tostring(updatedOrError)
			)
		)
		return nil
	end
	if typeof(updatedOrError) ~= "table" then
		return nil
	end
	return normalizeRecord(updatedOrError)
end

local function choosePurchaseLeaseId(): string
	if hasEffectiveServerOverclock() then
		return activeLeaseId
	end
	return SESSION_ID
end

local function ensurePurchaseApplied(player: Player, purchaseId: string): boolean
	if not DataService.IsReady(player) or purchaseId == "" then
		return false
	end

	local leaseId = choosePurchaseLeaseId()
	local updated = updateLease(leaseId, function(record, now)
		if record.OwnerJobId ~= "" and record.OwnerJobId ~= SESSION_ID and record.LeaseUntil > now then
			return record
		end

		if record.AppliedPurchases[purchaseId] ~= true then
			record.BoostUntil = math.max(record.BoostUntil, now) + BOOST_SECONDS
			record.AppliedPurchases[purchaseId] = true
		end
		record.OwnerJobId = SESSION_ID
		record.LeaseUntil = now + LEASE_SECONDS
		record.UpdatedAt = now
		return record
	end)
	if
		updated == nil
		or updated.OwnerJobId ~= SESSION_ID
		or updated.AppliedPurchases[purchaseId] ~= true
	then
		return false
	end

	local executed = DataService.Transaction(player, function(data)
		data.Entitlements.ServerOverclockLeaseId = leaseId
		data.Entitlements.ServerOverclockUntil = updated.BoostUntil
		return true, nil
	end)
	if not executed or not DataService.SaveNow(player) then
		return false
	end

	adoptLease(leaseId, updated)
	return true
end

local function tryRecoverForPlayer(player: Player)
	if hasEffectiveServerOverclock() or not DataService.IsReady(player) then
		return
	end
	local data = DataService.GetData(player)
	if data == nil then
		return
	end
	local leaseId = data.Entitlements.ServerOverclockLeaseId
	if not isValidLeaseId(leaseId) or data.Entitlements.ServerOverclockUntil <= os.time() then
		return
	end

	local updated = updateLease(leaseId, function(record, now)
		if record.BoostUntil <= now then
			return record
		end
		if record.OwnerJobId ~= "" and record.OwnerJobId ~= SESSION_ID and record.LeaseUntil > now then
			return record
		end
		record.OwnerJobId = SESSION_ID
		record.LeaseUntil = now + LEASE_SECONDS
		record.UpdatedAt = now
		return record
	end)
	if updated ~= nil and updated.OwnerJobId == SESSION_ID and updated.BoostUntil > os.time() then
		adoptLease(leaseId, updated)
	end
end

local function heartbeat()
	if activeLeaseId == "" then
		return
	end
	local leaseId = activeLeaseId
	local now = os.time()
	if activeBoostUntil <= now then
		clearActiveLease()
		return
	end

	local updated = updateLease(leaseId, function(record, updateNow)
		if record.OwnerJobId ~= SESSION_ID or record.BoostUntil <= updateNow then
			return record
		end
		record.LeaseUntil = updateNow + LEASE_SECONDS
		record.UpdatedAt = updateNow
		return record
	end)
	if updated ~= nil and updated.OwnerJobId == SESSION_ID then
		adoptLease(leaseId, updated)
	elseif activeLeaseUntil <= now then
		clearActiveLease()
	else
		refreshWorkspaceAttributes()
	end
end

local function releaseActiveLease()
	if activeLeaseId == "" then
		return
	end
	local leaseId = activeLeaseId
	updateLease(leaseId, function(record, now)
		if record.OwnerJobId == SESSION_ID then
			record.OwnerJobId = ""
			record.LeaseUntil = 0
			record.UpdatedAt = now
		end
		return record
	end)
end

function ServerOverclockCoordinator.IsActive(): boolean
	return hasEffectiveServerOverclock()
end

function ServerOverclockCoordinator.GetUntil(): number
	return if hasEffectiveServerOverclock() then activeBoostUntil else 0
end

function ServerOverclockCoordinator.Init()
	if initialized then
		return
	end
	initialized = true

	local originalProcessReceipt = MarketplaceService.ProcessReceipt
	assert(typeof(originalProcessReceipt) == "function", "MonetizationService must initialize first")

	MarketplaceService.ProcessReceipt = function(receiptInfo: { [string]: any })
		local decision = originalProcessReceipt(receiptInfo)
		if
			receiptInfo.ProductId == SERVER_OVERCLOCK_PRODUCT_ID
			and decision == Enum.ProductPurchaseDecision.PurchaseGranted
		then
			local player = Players:GetPlayerByUserId(receiptInfo.PlayerId)
			if player == nil or not ensurePurchaseApplied(player, tostring(receiptInfo.PurchaseId)) then
				refreshWorkspaceAttributes()
				return Enum.ProductPurchaseDecision.NotProcessedYet
			end
		end
		return decision
	end

	MonetizationService.GetProductionMultiplier = function(player: Player): number
		local multiplier = MonetizationService.GetPermanentProductionMultiplier(player)
		local data = DataService.GetData(player)
		if data ~= nil and data.Entitlements.PersonalOverclockUntil > os.time() then
			multiplier *= 2
		end
		if hasEffectiveServerOverclock() then
			multiplier *= 2
		end
		return multiplier
	end

	DataService.ProfileLoaded:Connect(function(player)
		task.spawn(tryRecoverForPlayer, player)
	end)

	Workspace:GetAttributeChangedSignal("ServerOverclockUntil"):Connect(function()
		if not attributeWriteActive then
			task.defer(refreshWorkspaceAttributes)
		end
	end)
	Workspace:GetAttributeChangedSignal("ServerOverclockActive"):Connect(function()
		if not attributeWriteActive then
			task.defer(refreshWorkspaceAttributes)
		end
	end)

	for _, player in Players:GetPlayers() do
		if DataService.IsReady(player) then
			task.spawn(tryRecoverForPlayer, player)
		end
	end

	refreshWorkspaceAttributes()
	game:BindToClose(releaseActiveLease)
	task.spawn(function()
		while true do
			task.wait(HEARTBEAT_SECONDS)
			heartbeat()
		end
	end)
end

return ServerOverclockCoordinator
