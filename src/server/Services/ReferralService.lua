--!strict

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local RemoteNames = require(ReplicatedStorage.Shared.Networking.RemoteNames)

local DataService = require(script.Parent.DataService)
local EconomyService = require(script.Parent.EconomyService)
local NotificationService = require(script.Parent.NotificationService)
local RemoteService = require(script.Parent.RemoteService)
local StateService = require(script.Parent.StateService)

local ReferralService = {}
local initialized = false

local STORE_NAME = "ScrapToBot_ReferralRewards_v1"
local referralStore = DataStoreService:GetDataStore(STORE_NAME)
local studioQualifiedByInviter: { [number]: { [string]: boolean } } = {}
local lastPersistAt: { [Player]: number } = {}

local function pendingKey(inviterUserId: number): string
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

local function readQualifiedCount(inviterUserId: number): number?
	if RunService:IsStudio() then
		return countQualified(studioQualifiedByInviter[inviterUserId])
	end

	local ok, valueOrError = pcall(function()
		return referralStore:GetAsync(pendingKey(inviterUserId))
	end)
	if not ok then
		warn(
			("[ReferralService] Failed reading rewards for %d: %s"):format(
				inviterUserId,
				tostring(valueOrError)
			)
		)
		return nil
	end

	if typeof(valueOrError) ~= "table" then
		return 0
	end
	return countQualified((valueOrError :: any).Qualified)
end

local function queueQualifiedReferral(inviterUserId: number, referredUserId: number): boolean
	local referredKey = tostring(referredUserId)
	if RunService:IsStudio() then
		local qualified = studioQualifiedByInviter[inviterUserId]
		if qualified == nil then
			qualified = {}
			studioQualifiedByInviter[inviterUserId] = qualified
		end
		if qualified[referredKey] == true then
			return true
		end
		if countQualified(qualified) >= GameConfig.Economy.MaxReferralRewards then
			return true
		end
		qualified[referredKey] = true
		return true
	end

	local ok, errorMessage = pcall(function()
		referralStore:UpdateAsync(pendingKey(inviterUserId), function(oldValue)
			local record = if typeof(oldValue) == "table" then oldValue else {}
			local qualified = if typeof(record.Qualified) == "table" then record.Qualified else {}
			if qualified[referredKey] ~= true and countQualified(qualified) < GameConfig.Economy.MaxReferralRewards then
				qualified[referredKey] = true
			end
			record.Qualified = qualified
			return record
		end)
	end)
	if not ok then
		warn(
			("[ReferralService] Failed queueing %d -> %d: %s"):format(
				referredUserId,
				inviterUserId,
				tostring(errorMessage)
			)
		)
		return false
	end
	return true
end

local function claimQueuedRewards(player: Player)
	local qualifiedCount = readQualifiedCount(player.UserId)
	if qualifiedCount == nil or qualifiedCount <= 0 then
		return
	end

	local grantedRewards = 0
	local executed = DataService.Transaction(player, function(data)
		local alreadyGranted = data.Referrals.QualifiedRewardCount
		local available = math.clamp(
			qualifiedCount - alreadyGranted,
			0,
			GameConfig.Economy.MaxReferralRewards - alreadyGranted
		)
		if available <= 0 then
			return true, 0
		end

		EconomyService.GrantCredits(data, GameConfig.Engagement.ReferralRewardCredits * available)
		data.Consumables.InstantProcessTokens = math.min(
			GameConfig.Economy.MaxInstantProcessTokens,
			data.Consumables.InstantProcessTokens + GameConfig.Engagement.ReferralRewardTokens * available
		)
		data.Referrals.QualifiedRewardCount += available
		grantedRewards = available
		return true, available
	end)
	if not executed or grantedRewards <= 0 then
		return
	end

	if not DataService.SaveNow(player) then
		warn(("[ReferralService] Immediate reward save failed for %d"):format(player.UserId))
	end

	local data = DataService.GetData(player)
	if data ~= nil then
		player:SetAttribute("InstantProcessTokens", data.Consumables.InstantProcessTokens)
		player:SetAttribute("ReferralQualifiedRewardCount", data.Referrals.QualifiedRewardCount)
	end
	StateService.PushSnapshot(player)
	RemoteService.Get(RemoteNames.Announcement):FireClient(
		player,
		("Referral reward! +%d Credits and +%d Instant Process Token%s"):format(
			GameConfig.Engagement.ReferralRewardCredits * grantedRewards,
			GameConfig.Engagement.ReferralRewardTokens * grantedRewards,
			if GameConfig.Engagement.ReferralRewardTokens * grantedRewards == 1 then "" else "s"
		)
	)
end

local function isNewPlayerReferralCandidate(data: any): boolean
	return data.Stats.LifetimePlaySeconds == 0
		and data.Stats.LifetimeRobotsBuilt == 0
		and next(data.Tutorial.Milestones) == nil
end

local function initializeReferral(player: Player)
	local data = DataService.GetData(player)
	if data == nil then
		return
	end

	if data.Referrals.PendingInviterUserId == 0 and isNewPlayerReferralCandidate(data) then
		local joinData = player:GetJoinData()
		local referredBy = joinData.ReferredByPlayerId
		if
			typeof(referredBy) == "number"
			and referredBy % 1 == 0
			and referredBy > 0
			and referredBy ~= player.UserId
		then
			DataService.Transaction(player, function(profileData)
				if profileData.Referrals.PendingInviterUserId ~= 0 then
					return true, nil
				end
				profileData.Referrals.PendingInviterUserId = referredBy
				profileData.Referrals.PendingStartedAt = os.time()
				profileData.Referrals.PendingPlaySeconds = 0
				return true, nil
			end)
		end
	end

	lastPersistAt[player] = os.clock()
	claimQueuedRewards(player)

	local refreshed = DataService.GetData(player)
	if refreshed ~= nil then
		player:SetAttribute("ReferralQualifiedRewardCount", refreshed.Referrals.QualifiedRewardCount)
	end
end

local function persistActivePlay(player: Player)
	local previous = lastPersistAt[player]
	if previous == nil or not DataService.IsReady(player) then
		return
	end

	local nowClock = os.clock()
	local elapsed = math.floor(nowClock - previous)
	if elapsed <= 0 then
		return
	end

	local data = DataService.GetData(player)
	if data == nil then
		return
	end

	local inviterUserId = data.Referrals.PendingInviterUserId
	local willQualify = inviterUserId > 0
		and data.Referrals.PendingPlaySeconds + elapsed >= GameConfig.Engagement.ReferralQualificationSeconds

	if willQualify then
		if not queueQualifiedReferral(inviterUserId, player.UserId) then
			return
		end
	end

	local executed = DataService.Transaction(player, function(profileData)
		profileData.Stats.LifetimePlaySeconds = math.min(
			2_147_483_647,
			profileData.Stats.LifetimePlaySeconds + elapsed
		)

		if profileData.Referrals.PendingInviterUserId == 0 then
			return true, false
		end

		profileData.Referrals.PendingPlaySeconds = math.min(
			GameConfig.Engagement.ReferralQualificationSeconds,
			profileData.Referrals.PendingPlaySeconds + elapsed
		)
		if profileData.Referrals.PendingPlaySeconds < GameConfig.Engagement.ReferralQualificationSeconds then
			return true, false
		end

		profileData.Referrals.PendingInviterUserId = 0
		profileData.Referrals.PendingStartedAt = 0
		profileData.Referrals.PendingPlaySeconds = 0
		return true, true
	end)
	if not executed then
		return
	end
	lastPersistAt[player] = previous + elapsed

	if willQualify then
		task.spawn(function()
			NotificationService.SendToUser(inviterUserId, "ReferralReward", "referral_reward")
		end)
		local inviter = Players:GetPlayerByUserId(inviterUserId)
		if inviter ~= nil and DataService.IsReady(inviter) then
			task.defer(claimQueuedRewards, inviter)
		end
	end
end

function ReferralService.StudioGrantQualifiedReferral(player: Player): (boolean, string)
	if not RunService:IsStudio() then
		return false, "STUDIO_ONLY"
	end
	if not DataService.IsReady(player) then
		return false, "PROFILE_NOT_READY"
	end
	local current = readQualifiedCount(player.UserId) or 0
	if current >= GameConfig.Economy.MaxReferralRewards then
		return false, "REFERRAL_REWARD_CAP_REACHED"
	end
	local fakeReferredUserId = 9_000_000_000 + current + 1
	if not queueQualifiedReferral(player.UserId, fakeReferredUserId) then
		return false, "REFERRAL_QUEUE_FAILED"
	end
	claimQueuedRewards(player)
	return true, "REFERRAL_REWARD_GRANTED"
end

function ReferralService.Init()
	if initialized then
		return
	end
	initialized = true

	DataService.ProfileLoaded:Connect(function(player)
		task.spawn(initializeReferral, player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		persistActivePlay(player)
		lastPersistAt[player] = nil
	end)

	task.spawn(function()
		while true do
			task.wait(GameConfig.Engagement.ReferralPersistIntervalSeconds)
			for player in lastPersistAt do
				if player.Parent == Players then
					persistActivePlay(player)
				else
					lastPersistAt[player] = nil
				end
			end
		end
	end)
end

return ReferralService
