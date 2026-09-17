--!strict

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)

local DataService = require(script.Parent.DataService)
local NotificationService = require(script.Parent.NotificationService)

local FactoryReadyNotificationService = {}
local initialized = false

local QUEUE_STORE_NAME = "ScrapToBot_FactoryReadyQueue_v1"
local LOCK_STORE_NAME = "ScrapToBot_FactoryReadyLocks_v1"
local POLL_SECONDS = 60
local PAGE_SIZE = 25
local LOCK_SECONDS = 30
local RETRY_DELAY_SECONDS = 10 * 60

local queueStore = DataStoreService:GetOrderedDataStore(QUEUE_STORE_NAME)
local lockStore = DataStoreService:GetDataStore(LOCK_STORE_NAME)

local function queueKey(userId: number): string
	return ("User_%d"):format(userId)
end

local function hasFactoryActivity(player: Player): boolean
	local data = DataService.GetData(player)
	if data == nil then
		return false
	end
	if next(data.Assignments.WorkPads) ~= nil then
		return true
	end
	return data.Machines.ProcessorJob.Active == true or data.Machines.AssemblerJob.Active == true
end

local function schedule(player: Player)
	if
		RunService:IsStudio()
		or not DataService.IsReady(player)
		or not hasFactoryActivity(player)
	then
		return
	end

	local dueAt = os.time() + GameConfig.Engagement.FactoryReadyDelaySeconds
	local ok, err = pcall(function()
		queueStore:SetAsync(queueKey(player.UserId), dueAt)
	end)
	if not ok then
		warn(
			("[FactoryReadyNotificationService] Failed scheduling %d: %s"):format(
				player.UserId,
				tostring(err)
			)
		)
	end
end

local function cancel(userId: number)
	if RunService:IsStudio() then
		return
	end
	local ok, err = pcall(function()
		queueStore:RemoveAsync(queueKey(userId))
	end)
	if not ok then
		warn(
			("[FactoryReadyNotificationService] Failed cancelling %d: %s"):format(
				userId,
				tostring(err)
			)
		)
	end
end

local function acquireLock(userId: number): boolean
	local now = os.time()
	local owner = game.JobId
	local claimed = false
	local ok, err = pcall(function()
		lockStore:UpdateAsync(queueKey(userId), function(old)
			if typeof(old) == "table" then
				local expiresAt = old.ExpiresAt
				local oldOwner = old.Owner
				if typeof(expiresAt) == "number" and expiresAt > now and oldOwner ~= owner then
					return old
				end
			end
			claimed = true
			return {
				Owner = owner,
				ExpiresAt = now + LOCK_SECONDS,
			}
		end)
	end)
	if not ok then
		warn(
			("[FactoryReadyNotificationService] Lock failed for %d: %s"):format(
				userId,
				tostring(err)
			)
		)
		return false
	end
	return claimed
end

local function releaseLock(userId: number)
	pcall(function()
		lockStore:RemoveAsync(queueKey(userId))
	end)
end

local function deferRetry(userId: number)
	local retryAt = os.time() + RETRY_DELAY_SECONDS
	pcall(function()
		queueStore:SetAsync(queueKey(userId), retryAt)
	end)
end

local function processDue()
	if RunService:IsStudio() then
		return
	end

	local ok, pagesOrError = pcall(function()
		return queueStore:GetSortedAsync(true, PAGE_SIZE, 0, os.time())
	end)
	if not ok then
		warn(
			("[FactoryReadyNotificationService] Queue poll failed: %s"):format(
				tostring(pagesOrError)
			)
		)
		return
	end

	local pages = pagesOrError
	local pageOk, entriesOrError = pcall(function()
		return pages:GetCurrentPage()
	end)
	if not pageOk then
		warn(
			("[FactoryReadyNotificationService] Queue page failed: %s"):format(
				tostring(entriesOrError)
			)
		)
		return
	end

	for _, entry in entriesOrError do
		local userIdText = string.match(entry.key, "^User_(%d+)$")
		local userId = userIdText and tonumber(userIdText) or nil
		if userId == nil then
			continue
		end

		-- If the player is in this server, do not spend their daily notification quota.
		if Players:GetPlayerByUserId(userId) ~= nil then
			cancel(userId)
			continue
		end

		if not acquireLock(userId) then
			continue
		end

		local sent = NotificationService.SendToUser(userId, "FactoryReady", "factory-ready")
		if sent then
			cancel(userId)
		else
			-- Keep failed deliveries queued so a later active server can retry after
			-- transient API failures or after the Open Cloud package becomes available.
			deferRetry(userId)
		end
		releaseLock(userId)
	end
end

function FactoryReadyNotificationService.Init()
	if initialized then
		return
	end
	initialized = true

	Players.PlayerAdded:Connect(function(player)
		-- Rejoining means the push is no longer useful; their next leave will create
		-- a fresh due time if their factory is active.
		task.spawn(cancel, player.UserId)
	end)

	Players.PlayerRemoving:Connect(function(player)
		schedule(player)
	end)

	if RunService:IsStudio() then
		return
	end

	task.spawn(function()
		while true do
			processDue()
			task.wait(POLL_SECONDS)
		end
	end)
end

return FactoryReadyNotificationService
