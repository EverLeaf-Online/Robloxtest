--!strict

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local ReferralProgressRules = require(ReplicatedStorage.Shared.Domain.ReferralProgressRules)

type ProgressRecord = ReferralProgressRules.ProgressRecord

local ReferralProgressService = {}

local PROGRESS_STORE_NAME = "ScrapToBot_ReferralProgress_v1"
local REWARD_STORE_NAME = "ScrapToBot_ReferralRewards_v1"
local PLAYER_STORE_NAME = "ScrapToBot_Player_v1"

local progressStore = DataStoreService:GetDataStore(PROGRESS_STORE_NAME)
local rewardStore = DataStoreService:GetDataStore(REWARD_STORE_NAME)
local playerStore = DataStoreService:GetDataStore(PLAYER_STORE_NAME)

local initialized = false
local started: { [Player]: boolean } = {}
local starting: { [Player]: boolean } = {}
local lastPersistAt: { [Player]: number } = {}

local function progressKey(userId: number): string
	return ("Referred_%d"):format(userId)
end

local function rewardKey(inviterUserId: number): string
	return ("Inviter_%d"):format(inviterUserId)
end

local function countQualified(map: any): number
	if typeof(map) ~= "table" then
		return 0
	end

	local count = 0
	for referredUserId, qualified in map do
		if typeof(referredUserId) == "string" and qualified == true then
			count += 1
		end
	end
	return math.min(count, GameConfig.Economy.MaxReferralRewards)
end

local function isFreshProfileData(data: any): boolean
	if typeof(data) ~= "table" then
		return false
	end

	local stats = data.Stats
	local tutorial = data.Tutorial
	local milestones = if typeof(tutorial) == "table" then tutorial.Milestones else nil

	return typeof(stats) == "table"
		and (stats.LifetimePlaySeconds == 0 or stats.LifetimePlaySeconds == nil)
		and (stats.LifetimeRobotsBuilt == 0 or stats.LifetimeRobotsBuilt == nil)
		and (milestones == nil or (typeof(milestones) == "table" and next(milestones) == nil))
end

local function isFreshStoredProfile(raw: any): boolean
	if raw == nil then
		return true
	end
	if typeof(raw) ~= "table" then
		return false
	end

	local data = if typeof(raw.Data) == "table" then raw.Data else raw
	return isFreshProfileData(data)
end

local function readProgress(userId: number): (boolean, ProgressRecord?)
	local ok, valueOrError = pcall(progressStore.GetAsync, progressStore, progressKey(userId))
	if not ok then
		warn(
			("[ReferralProgressService] Failed reading progress for %d: %s"):format(
				userId,
				tostring(valueOrError)
			)
		)
		return false, nil
	end
	if valueOrError == nil then
		return true, nil
	end
	return true,
		ReferralProgressRules.Normalize(
			valueOrError,
			GameConfig.Engagement.ReferralQualificationSeconds
		)
end

local function captureCandidate(
	referredUserId: number,
	inviterUserId: number
): (boolean, ProgressRecord?)
	if inviterUserId <= 0 or inviterUserId % 1 ~= 0 or inviterUserId == referredUserId then
		return false, nil
	end

	local ok, valueOrError = pcall(function()
		return progressStore:UpdateAsync(progressKey(referredUserId), function(old)
			local nextRecord = ReferralProgressRules.Capture(
				old,
				inviterUserId,
				os.time(),
				GameConfig.Engagement.ReferralQualificationSeconds
			)
			return nextRecord
		end)
	end)
	if not ok then
		warn(
			("[ReferralProgressService] Failed capturing %d -> %d: %s"):format(
				referredUserId,
				inviterUserId,
				tostring(valueOrError)
			)
		)
		return false, nil
	end

	return true,
		ReferralProgressRules.Normalize(
			valueOrError,
			GameConfig.Engagement.ReferralQualificationSeconds
		)
end

local function setEligibility(userId: number, isEligible: boolean): (boolean, ProgressRecord?)
	local ok, valueOrError = pcall(function()
		return progressStore:UpdateAsync(progressKey(userId), function(old)
			local current = ReferralProgressRules.Normalize(
				old,
				GameConfig.Engagement.ReferralQualificationSeconds
			)
			if current.Eligibility ~= "Pending" then
				return current
			end
			return ReferralProgressRules.SetEligibility(
				current,
				isEligible,
				os.time(),
				GameConfig.Engagement.ReferralQualificationSeconds
			)
		end)
	end)
	if not ok then
		warn(
			("[ReferralProgressService] Failed setting eligibility for %d: %s"):format(
				userId,
				tostring(valueOrError)
			)
		)
		return false, nil
	end

	return true,
		ReferralProgressRules.Normalize(
			valueOrError,
			GameConfig.Engagement.ReferralQualificationSeconds
		)
end

local function verifyFromStoredProfile(userId: number): (boolean, ProgressRecord?)
	local ok, rawOrError = pcall(playerStore.GetAsync, playerStore, ("Player_%d"):format(userId))
	if not ok then
		warn(
			("[ReferralProgressService] Failed checking prior profile for %d: %s"):format(
				userId,
				tostring(rawOrError)
			)
		)
		return false, nil
	end
	return setEligibility(userId, isFreshStoredProfile(rawOrError))
end

local function queueQualifiedReferral(
	inviterUserId: number,
	referredUserId: number
): (boolean, boolean)
	local referredKey = tostring(referredUserId)
	local added = false
	local accepted = false

	local ok, errorMessage = pcall(function()
		rewardStore:UpdateAsync(rewardKey(inviterUserId), function(oldValue)
			local record = if typeof(oldValue) == "table" then oldValue else {}
			local qualified = if typeof(record.Qualified) == "table" then record.Qualified else {}

			if
				qualified[referredKey] == true
				or countQualified(qualified) >= GameConfig.Economy.MaxReferralRewards
			then
				-- Existing grants and capped inviters are terminal/idempotent.
				accepted = true
			else
				qualified[referredKey] = true
				record.Qualified = qualified
				added = true
				accepted = true
			end

			return record
		end)
	end)
	if not ok then
		warn(
			("[ReferralProgressService] Failed queueing %d -> %d: %s"):format(
				referredUserId,
				inviterUserId,
				tostring(errorMessage)
			)
		)
		return false, false
	end
	return accepted, added
end

local function markQualified(referredUserId: number): boolean
	local ok, valueOrError = pcall(function()
		return progressStore:UpdateAsync(progressKey(referredUserId), function(old)
			return ReferralProgressRules.MarkQualified(
				old,
				os.time(),
				GameConfig.Engagement.ReferralQualificationSeconds
			)
		end)
	end)
	if not ok then
		warn(
			("[ReferralProgressService] Failed completing referral for %d: %s"):format(
				referredUserId,
				tostring(valueOrError)
			)
		)
		return false
	end
	return true
end

local function finalizeIfReady(referredUserId: number, record: ProgressRecord): boolean
	if
		not ReferralProgressRules.CanFinalize(
			record,
			GameConfig.Engagement.ReferralQualificationSeconds
		)
	then
		return false
	end

	local accepted, added = queueQualifiedReferral(record.InviterUserId, referredUserId)
	if not accepted then
		return false
	end
	if not markQualified(referredUserId) then
		return false
	end

	if added then
		task.spawn(function()
			local NotificationService = require(script.Parent.NotificationService)
			NotificationService.SendToUser(
				record.InviterUserId,
				"ReferralReward",
				"referral_reward"
			)
		end)
	end
	return true
end

local function persistActivePlay(player: Player)
	if RunService:IsStudio() then
		return
	end

	local previous = lastPersistAt[player]
	if previous == nil then
		return
	end

	local nowClock = os.clock()
	local elapsed = math.floor(nowClock - previous)
	if elapsed <= 0 then
		return
	end

	local ok, valueOrError = pcall(function()
		return progressStore:UpdateAsync(progressKey(player.UserId), function(old)
			local nextRecord = ReferralProgressRules.AddActiveSeconds(
				old,
				elapsed,
				os.time(),
				GameConfig.Engagement.ReferralQualificationSeconds
			)
			return nextRecord
		end)
	end)
	if not ok then
		warn(
			("[ReferralProgressService] Failed persisting active play for %d: %s"):format(
				player.UserId,
				tostring(valueOrError)
			)
		)
		return
	end

	lastPersistAt[player] = previous + elapsed
	local record = ReferralProgressRules.Normalize(
		valueOrError,
		GameConfig.Engagement.ReferralQualificationSeconds
	)

	if record.Eligibility == "Pending" then
		local verified, verifiedRecord = verifyFromStoredProfile(player.UserId)
		if verified and verifiedRecord ~= nil then
			record = verifiedRecord
		end
	end

	local finalized = finalizeIfReady(player.UserId, record)
	local shouldTrack = ReferralProgressRules.ShouldTrack(
		record,
		GameConfig.Engagement.ReferralQualificationSeconds
	)
	if finalized or not shouldTrack then
		lastPersistAt[player] = nil
	end
end

local function beginPlayer(player: Player)
	if RunService:IsStudio() or started[player] then
		return
	end
	if starting[player] then
		local deadline = os.clock() + 5
		while starting[player] and player.Parent == Players and os.clock() < deadline do
			task.wait(0.05)
		end
		return
	end

	starting[player] = true

	local okRead, record = readProgress(player.UserId)
	if not okRead then
		starting[player] = nil
		return
	end

	local joinData = player:GetJoinData()
	local referredBy = joinData.ReferredByPlayerId
	if
		typeof(referredBy) == "number"
		and referredBy % 1 == 0
		and referredBy > 0
		and referredBy ~= player.UserId
	then
		local capturedOk, capturedRecord = captureCandidate(player.UserId, referredBy)
		if capturedOk and capturedRecord ~= nil then
			record = capturedRecord
		end
	end

	if record ~= nil and record.Eligibility == "Pending" then
		local verified, verifiedRecord = verifyFromStoredProfile(player.UserId)
		if verified and verifiedRecord ~= nil then
			record = verifiedRecord
		end
	end

	if
		record ~= nil
		and ReferralProgressRules.ShouldTrack(
			record,
			GameConfig.Engagement.ReferralQualificationSeconds
		)
	then
		lastPersistAt[player] = os.clock()
	end

	if record ~= nil and finalizeIfReady(player.UserId, record) then
		lastPersistAt[player] = nil
	end

	started[player] = true
	starting[player] = nil
end

function ReferralProgressService.VerifyFromProfile(player: Player, profileData: any)
	if RunService:IsStudio() then
		return
	end

	beginPlayer(player)
	local okRead, record = readProgress(player.UserId)
	if not okRead or record == nil or record.Eligibility ~= "Pending" then
		return
	end

	local okSet, updated = setEligibility(player.UserId, isFreshProfileData(profileData))
	if not okSet or updated == nil then
		return
	end

	if
		ReferralProgressRules.ShouldTrack(
			updated,
			GameConfig.Engagement.ReferralQualificationSeconds
		)
	then
		lastPersistAt[player] = lastPersistAt[player] or os.clock()
	else
		lastPersistAt[player] = nil
	end
	if finalizeIfReady(player.UserId, updated) then
		lastPersistAt[player] = nil
	end
end

function ReferralProgressService.FlushPlayer(player: Player)
	if RunService:IsStudio() then
		return
	end
	beginPlayer(player)
	persistActivePlay(player)
end

function ReferralProgressService.Init()
	if initialized then
		return
	end
	initialized = true

	if RunService:IsStudio() then
		return
	end

	Players.PlayerAdded:Connect(function(player)
		task.spawn(beginPlayer, player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		persistActivePlay(player)
		lastPersistAt[player] = nil
		started[player] = nil
		starting[player] = nil
	end)

	for _, player in Players:GetPlayers() do
		task.spawn(beginPlayer, player)
	end

	task.spawn(function()
		while true do
			task.wait(GameConfig.Engagement.ReferralPersistIntervalSeconds)
			for player in lastPersistAt do
				if player.Parent == Players then
					persistActivePlay(player)
				else
					lastPersistAt[player] = nil
					started[player] = nil
					starting[player] = nil
				end
			end
		end
	end)
end

return ReferralProgressService
