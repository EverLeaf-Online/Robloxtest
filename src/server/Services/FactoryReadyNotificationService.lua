--!strict

local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)

local FactoryReadyDeliveryRules = require(script.Parent.Parent.Domain.FactoryReadyDeliveryRules)
local NotificationService = require(script.Parent.NotificationService)

type DeliveryState = FactoryReadyDeliveryRules.DeliveryState

local FactoryReadyNotificationService = {}

local QUEUE_STORE_NAME = "ScrapToBot_FactoryReadyQueue_v1"
-- Keep the existing store name so legacy lock rows can be migrated lazily when a
-- queued notification is next claimed.
local DELIVERY_STATE_STORE_NAME = "ScrapToBot_FactoryReadyLocks_v1"
local POLL_SECONDS = 60
local PAGE_SIZE = 25
local CLAIM_SECONDS = 45
local CLAIM_RENEW_SECONDS = 10
local RETRY_DELAY_SECONDS = 10 * 60

local queueStore = DataStoreService:GetOrderedDataStore(QUEUE_STORE_NAME)
local deliveryStateStore = DataStoreService:GetDataStore(DELIVERY_STATE_STORE_NAME)
local DELIVERY_OWNER_ID = if game.JobId ~= ""
	then game.JobId
	else "Studio_" .. HttpService:GenerateGUID(false)

local pollerInitialized = false
local factorySchedulingInitialized = false

local function stateKey(userId: number): string
	return ("User_%d"):format(userId)
end

local function legacyQueueKey(userId: number): string
	return ("User_%d"):format(userId)
end

local function queueKey(userId: number, generation: string): string
	return ("F_%d_%s"):format(userId, generation)
end

local function newGeneration(): string
	local compact = string.gsub(HttpService:GenerateGUID(false), "-", "")
	return string.sub(compact, 1, 16)
end

local function removeQueueEntry(key: string)
	local ok, err = pcall(queueStore.RemoveAsync, queueStore, key)
	if not ok then
		warn(
			("[FactoryReadyNotificationService] Failed removing queue entry %s: %s"):format(
				key,
				tostring(err)
			)
		)
	end
end

local function queueKeyForState(userId: number, state: DeliveryState): string?
	if state.Generation == "" then
		return nil
	end
	if string.sub(state.Generation, 1, 7) == "legacy-" then
		return legacyQueueKey(userId)
	end
	return queueKey(userId, state.Generation)
end

local function cancel(userId: number)
	if RunService:IsStudio() then
		return
	end

	local now = os.time()
	local ok, stateOrError = pcall(function()
		return deliveryStateStore:UpdateAsync(stateKey(userId), function(old)
			return FactoryReadyDeliveryRules.Cancel(old, now)
		end)
	end)
	if not ok then
		warn(
			("[FactoryReadyNotificationService] Failed cancelling %d: %s"):format(
				userId,
				tostring(stateOrError)
			)
		)
		return
	end

	local state = FactoryReadyDeliveryRules.Normalize(stateOrError)
	local activeQueueKey = queueKeyForState(userId, state)
	if activeQueueKey ~= nil then
		removeQueueEntry(activeQueueKey)
	end
	-- Remove the v1 queue key as well. New-generation queue keys are unique, so this
	-- cannot erase a schedule created concurrently after the cancellation state write.
	removeQueueEntry(legacyQueueKey(userId))
end

local function claimDelivery(
	userId: number,
	generation: string,
	dueAt: number
): (boolean, string)
	local now = os.time()
	local claimed = false
	local claimCode = "ERROR"
	local ok, stateOrError = pcall(function()
		return deliveryStateStore:UpdateAsync(stateKey(userId), function(old)
			local nextState, accepted, code = FactoryReadyDeliveryRules.Claim(
				old,
				generation,
				dueAt,
				DELIVERY_OWNER_ID,
				now,
				CLAIM_SECONDS
			)
			claimed = accepted
			claimCode = code
			return nextState
		end)
	end)
	if not ok then
		warn(
			("[FactoryReadyNotificationService] Claim failed for %d/%s: %s"):format(
				userId,
				generation,
				tostring(stateOrError)
			)
		)
		return false, "ERROR"
	end
	return claimed, claimCode
end

local function renewDeliveryClaim(userId: number, generation: string): boolean
	local now = os.time()
	local renewed = false
	local ok, stateOrError = pcall(function()
		return deliveryStateStore:UpdateAsync(stateKey(userId), function(old)
			local nextState, accepted = FactoryReadyDeliveryRules.Renew(
				old,
				generation,
				DELIVERY_OWNER_ID,
				now,
				CLAIM_SECONDS
			)
			renewed = accepted
			return nextState
		end)
	end)
	if not ok then
		warn(
			("[FactoryReadyNotificationService] Claim renewal failed for %d/%s: %s"):format(
				userId,
				generation,
				tostring(stateOrError)
			)
		)
		return false
	end
	return renewed
end

local function stillOwnsDelivery(userId: number, generation: string): boolean
	local now = os.time()
	local ok, stateOrError =
		pcall(deliveryStateStore.GetAsync, deliveryStateStore, stateKey(userId))
	if not ok then
		warn(
			("[FactoryReadyNotificationService] Claim revalidation failed for %d/%s: %s"):format(
				userId,
				generation,
				tostring(stateOrError)
			)
		)
		return false
	end
	return FactoryReadyDeliveryRules.IsOwnedClaim(
		stateOrError,
		generation,
		DELIVERY_OWNER_ID,
		now
	)
end

local function completeDelivery(userId: number, generation: string): boolean
	local completed = false
	local ok, stateOrError = pcall(function()
		return deliveryStateStore:UpdateAsync(stateKey(userId), function(old)
			local nextState, accepted = FactoryReadyDeliveryRules.Complete(
				old,
				generation,
				DELIVERY_OWNER_ID,
				os.time()
			)
			completed = accepted
			return nextState
		end)
	end)
	if not ok then
		warn(
			("[FactoryReadyNotificationService] Completion write failed for %d/%s: %s"):format(
				userId,
				generation,
				tostring(stateOrError)
			)
		)
		return false
	end
	return completed
end

local function deferRetry(userId: number, generation: string, entryKey: string)
	local retryAt = os.time() + RETRY_DELAY_SECONDS
	local retried = false
	local ok, stateOrError = pcall(function()
		return deliveryStateStore:UpdateAsync(stateKey(userId), function(old)
			local nextState, accepted = FactoryReadyDeliveryRules.Retry(
				old,
				generation,
				DELIVERY_OWNER_ID,
				retryAt,
				os.time()
			)
			retried = accepted
			return nextState
		end)
	end)
	if not ok then
		warn(
			("[FactoryReadyNotificationService] Failed deferring %d/%s: %s"):format(
				userId,
				generation,
				tostring(stateOrError)
			)
		)
		return
	end

	if not retried then
		-- The generation was cancelled or superseded while the send was in flight.
		-- This stale index entry is safe to remove because a newer generation has a
		-- different ordered-store key.
		removeQueueEntry(entryKey)
		return
	end

	local queueOk, queueError =
		pcall(queueStore.SetAsync, queueStore, entryKey, retryAt)
	if not queueOk then
		warn(
			("[FactoryReadyNotificationService] Failed requeueing %d/%s: %s"):format(
				userId,
				generation,
				tostring(queueError)
			)
		)
	end
end

local function parseQueueEntry(entry: any): (number?, string?, number?)
	local dueAt = entry.value
	if typeof(dueAt) ~= "number" then
		return nil, nil, nil
	end

	local userIdText, generation = string.match(entry.key, "^F_(%d+)_([%w_%-]+)$")
	if userIdText ~= nil and generation ~= nil then
		return tonumber(userIdText), generation, dueAt
	end

	local legacyUserIdText = string.match(entry.key, "^User_(%d+)$")
	if legacyUserIdText ~= nil then
		return tonumber(legacyUserIdText), ("legacy-%d"):format(math.floor(dueAt)), dueAt
	end
	return nil, nil, nil
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
		local userId, generation, dueAt = parseQueueEntry(entry)
		if userId == nil or generation == nil or dueAt == nil then
			continue
		end

		-- If the player is in this server, do not spend their daily notification quota.
		if Players:GetPlayerByUserId(userId) ~= nil then
			cancel(userId)
			removeQueueEntry(entry.key)
			continue
		end

		local claimed, claimCode = claimDelivery(userId, generation, dueAt)
		if not claimed then
			if claimCode == "STALE" or claimCode == "NOT_DUE" then
				removeQueueEntry(entry.key)
			end
			continue
		end

		local renewing = true
		task.spawn(function()
			while renewing do
				task.wait(CLAIM_RENEW_SECONDS)
				if not renewing then
					break
				end
				if not renewDeliveryClaim(userId, generation) then
					renewing = false
				end
			end
		end)

		-- The queue page may be stale even though the claim transaction succeeded.
		-- Re-read the authoritative generation immediately before crossing the
		-- external notification boundary.
		if not stillOwnsDelivery(userId, generation) then
			renewing = false
			removeQueueEntry(entry.key)
			continue
		end

		local sent = NotificationService.SendToUser(userId, "FactoryReady", "factory-ready")
		renewing = false

		if sent then
			if completeDelivery(userId, generation) then
				removeQueueEntry(entry.key)
			else
				-- A cancellation/reschedule won the state race while the external send was
				-- in flight. Never mutate its queue key from this stale generation.
				removeQueueEntry(entry.key)
			end
		else
			-- Keep failed deliveries queued so another active server can retry after
			-- transient API failures or after the Open Cloud package becomes available.
			deferRetry(userId, generation, entry.key)
		end
	end
end

local function scheduleUser(userId: number, dueAt: number): boolean
	local generation = newGeneration()
	local previousGeneration = ""
	local now = os.time()
	local ok, stateOrError = pcall(function()
		return deliveryStateStore:UpdateAsync(stateKey(userId), function(old)
			local previous = FactoryReadyDeliveryRules.Normalize(old)
			previousGeneration = previous.Generation
			return FactoryReadyDeliveryRules.Schedule(generation, dueAt, now)
		end)
	end)
	if not ok or stateOrError == nil then
		warn(
			("[FactoryReadyNotificationService] Failed scheduling state for %d: %s"):format(
				userId,
				tostring(stateOrError)
			)
		)
		return false
	end

	local entryKey = queueKey(userId, generation)
	local queueOk, queueError = pcall(queueStore.SetAsync, queueStore, entryKey, dueAt)
	if not queueOk then
		warn(
			("[FactoryReadyNotificationService] Failed scheduling %d: %s"):format(
				userId,
				tostring(queueError)
			)
		)
		-- Roll back only if this generation is still authoritative. A concurrent
		-- reschedule must never be cancelled by this failed index write.
		pcall(function()
			deliveryStateStore:UpdateAsync(stateKey(userId), function(old)
				local state = FactoryReadyDeliveryRules.Normalize(old)
				if state.Generation == generation then
					return FactoryReadyDeliveryRules.Cancel(state, os.time())
				end
				return state
			end)
		end)
		return false
	end

	if previousGeneration ~= "" and previousGeneration ~= generation then
		local previousState = FactoryReadyDeliveryRules.Normalize({
			Generation = previousGeneration,
		})
		local previousKey = queueKeyForState(userId, previousState)
		if previousKey ~= nil then
			removeQueueEntry(previousKey)
		end
	end
	removeQueueEntry(legacyQueueKey(userId))
	return true
end

function FactoryReadyNotificationService.InitPoller()
	if pollerInitialized then
		return
	end
	pollerInitialized = true

	Players.PlayerAdded:Connect(function(player)
		-- Rejoining makes the push obsolete. A later Factory leave will schedule a
		-- fresh due time if that player still has active factory production.
		task.spawn(cancel, player.UserId)
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

function FactoryReadyNotificationService.InitFactoryScheduling()
	if factorySchedulingInitialized then
		return
	end
	factorySchedulingInitialized = true

	FactoryReadyNotificationService.InitPoller()

	-- Keep the profile/data stack out of Hub servers. Only Factory servers need
	-- profile access to decide whether a leaving owner has active production.
	local DataService = require(script.Parent.DataService)

	local function hasFactoryActivity(player: Player): boolean
		local data = DataService.GetData(player)
		if data == nil then
			return false
		end
		if next(data.Assignments.WorkPads) ~= nil then
			return true
		end
		return data.Machines.ProcessorJob.Active == true
			or data.Machines.AssemblerJob.Active == true
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
		scheduleUser(player.UserId, dueAt)
	end

	Players.PlayerRemoving:Connect(schedule)
end

-- Backwards-compatible Factory initializer. New call sites should be explicit.
function FactoryReadyNotificationService.Init()
	FactoryReadyNotificationService.InitFactoryScheduling()
end

return FactoryReadyNotificationService
