--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local FactoryRules = require(ReplicatedStorage.Shared.Domain.FactoryRules)
local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local OfflineProductionRules = require(ReplicatedStorage.Shared.Domain.OfflineProductionRules)
local Robots = require(ReplicatedStorage.Shared.Config.Robots)

local AnalyticsService = require(script.Parent.AnalyticsService)
local DataService = require(script.Parent.DataService)
local EconomyService = require(script.Parent.EconomyService)
local MonetizationService = require(script.Parent.MonetizationService)
local StateService = require(script.Parent.StateService)
local ProfileTypes = require(script.Parent.Parent.Data.ProfileTypes)

type ProfileData = ProfileTypes.ProfileData

local ProductionService = {}
local initialized = false
local lastTickByUser: { [number]: number } = {}
local creditCarryByUser: { [number]: number } = {}
local offlineAppliedByUser: { [number]: boolean } = {}

local function parsePadIndex(padId: string): number?
	local match = string.match(padId, "^Pad(%d+)$")
	if match == nil then
		return nil
	end
	return tonumber(match)
end

local function productionRate(player: Player, data: ProfileData): number
	local baseSlots = FactoryRules.GetWorkSlots(data.Machines.WorkSlotsLevel)
	local unlockedSlots = math.min(
		GameConfig.Factory.MaxWorkSlots + 2,
		baseSlots + MonetizationService.GetExtraWorkSlots(player)
	)
	local total = 0

	for padId, robotUid in data.Assignments.WorkPads do
		local padIndex = parsePadIndex(padId)
		if padIndex ~= nil and padIndex >= 1 and padIndex <= unlockedSlots then
			local robot = data.Robots.OwnedByUid[robotUid]
			if robot ~= nil then
				local definition = Robots.Definitions[robot.RobotId]
				if definition ~= nil then
					total += definition.ProductionPerSecond
				end
			end
		end
	end

	return total
end

local function restoreGrantToCarry(userId: number, amount: number)
	creditCarryByUser[userId] =
		math.min(GameConfig.Economy.MaxCredits, (creditCarryByUser[userId] or 0) + amount)
end

local function queueOfflineProduction(player: Player)
	task.spawn(function()
		local deadline = os.clock() + 10
		while
			player.Parent == Players
			and DataService.IsReady(player)
			and player:GetAttribute("PassProduction2x") == nil
			and os.clock() < deadline
		do
			task.wait(0.05)
		end

		if player.Parent == Players and DataService.IsReady(player) then
			ProductionService.ApplyOfflineProduction(player)
		end
	end)
end

function ProductionService.ApplyOfflineProduction(player: Player): number
	local userId = player.UserId
	if offlineAppliedByUser[userId] == true or not DataService.IsReady(player) then
		return 0
	end

	-- Claim the join before opening the transaction so repeated entitlement refreshes
	-- cannot double-grant the same offline interval. A failed transaction clears the
	-- claim and schedules one bounded retry.
	offlineAppliedByUser[userId] = true
	local now = os.time()
	local executed, transactionResult = DataService.Transaction(player, function(profileData)
		local elapsed = OfflineProductionRules.GetElapsedSeconds(
			now,
			profileData.Timestamps.LastProductionTick,
			profileData.Timestamps.LastLeave,
			GameConfig.Factory.OfflineProductionMaxSeconds
		)
		local rate = productionRate(player, profileData)
		local requested = OfflineProductionRules.GetCreditGrant(
			rate,
			elapsed,
			GameConfig.Factory.OfflineProductionEfficiency,
			MonetizationService.GetPermanentProductionMultiplier(player),
			GameConfig.Economy.MaxCredits
		)

		local room = math.max(0, GameConfig.Economy.MaxCredits - profileData.Currencies.Credits)
		local granted = math.min(requested, room)
		if granted > 0 then
			profileData.Currencies.Credits += granted
			profileData.Stats.LifetimeCredits =
				math.min(GameConfig.Economy.MaxCredits, profileData.Stats.LifetimeCredits + granted)
			profileData.Tutorial.Milestones.FirstIncomeEarned = true
		end
		profileData.Timestamps.LastProductionTick = now

		return true, {
			Elapsed = elapsed,
			Granted = granted,
		}
	end)

	if not executed or typeof(transactionResult) ~= "table" then
		offlineAppliedByUser[userId] = nil
		task.delay(1, function()
			if player.Parent == Players and DataService.IsReady(player) then
				ProductionService.ApplyOfflineProduction(player)
			end
		end)
		return 0
	end

	local elapsed = if typeof(transactionResult.Elapsed) == "number"
		then transactionResult.Elapsed
		else 0
	local granted = if typeof(transactionResult.Granted) == "number"
		then transactionResult.Granted
		else 0
	player:SetAttribute("OfflineProductionSeconds", elapsed)
	player:SetAttribute("OfflineCreditsGranted", granted)

	if granted > 0 then
		local updatedData = DataService.GetData(player)
		if updatedData ~= nil then
			AnalyticsService.RecordCreditSource(
				player,
				"OfflineBotProduction",
				granted,
				updatedData.Currencies.Credits
			)
		end
	end

	StateService.PushProductionDelta(player)
	return granted
end

function ProductionService.TickPlayer(player: Player)
	local userId = player.UserId
	if not DataService.IsReady(player) then
		lastTickByUser[userId] = os.clock()
		return
	end
	if offlineAppliedByUser[userId] ~= true then
		lastTickByUser[userId] = os.clock()
		return
	end

	local now = os.clock()
	local previous = lastTickByUser[userId] or now
	lastTickByUser[userId] = now
	local elapsed = math.clamp(now - previous, 0, GameConfig.Factory.ProductionTickSeconds * 2)
	if elapsed <= 0 then
		return
	end

	local data = DataService.GetData(player)
	if data == nil then
		return
	end
	if data.Currencies.Credits >= GameConfig.Economy.MaxCredits then
		creditCarryByUser[userId] = 0
		return
	end

	local carry = creditCarryByUser[userId] or 0
	local rate = productionRate(player, data)
	if rate > 0 then
		local productionMultiplier = MonetizationService.GetProductionMultiplier(player)
		carry += rate * productionMultiplier * elapsed
	end
	carry = math.min(GameConfig.Economy.MaxCredits, carry)

	local grantAmount = math.min(math.floor(carry), GameConfig.Economy.MaxTransactionQuantity)
	creditCarryByUser[userId] = carry - grantAmount
	if grantAmount <= 0 then
		return
	end

	local executed, transactionResult = DataService.Transaction(player, function(profileData)
		local granted = EconomyService.GrantCredits(profileData, grantAmount)
		if granted <= 0 then
			return false, 0
		end
		profileData.Tutorial.Milestones.FirstIncomeEarned = true
		profileData.Timestamps.LastProductionTick = os.time()
		return true, granted
	end)

	if not executed then
		-- A concurrent profile transaction must not delete production earned during
		-- this tick. Keep it in a bounded carry and retry on the next production tick.
		restoreGrantToCarry(userId, grantAmount)
		return
	end
	if typeof(transactionResult) ~= "number" or transactionResult <= 0 then
		local latestData = DataService.GetData(player)
		if latestData ~= nil and latestData.Currencies.Credits >= GameConfig.Economy.MaxCredits then
			creditCarryByUser[userId] = 0
		else
			restoreGrantToCarry(userId, grantAmount)
		end
		return
	end

	local updatedData = DataService.GetData(player)
	if updatedData ~= nil then
		if updatedData.Currencies.Credits >= GameConfig.Economy.MaxCredits then
			creditCarryByUser[userId] = 0
		elseif transactionResult < grantAmount then
			restoreGrantToCarry(userId, grantAmount - transactionResult)
		end
		AnalyticsService.RecordCreditSource(
			player,
			"BotProduction",
			transactionResult,
			updatedData.Currencies.Credits
		)
	end

	-- Production runs every second. A tiny delta avoids cloning and replicating the
	-- complete robot inventory (up to 500 entries) on every successful production tick.
	StateService.PushProductionDelta(player)
end

function ProductionService.Init()
	if initialized then
		return
	end
	initialized = true

	DataService.ProfileLoaded:Connect(function(player)
		lastTickByUser[player.UserId] = os.clock()
		creditCarryByUser[player.UserId] = 0
		offlineAppliedByUser[player.UserId] = nil
		queueOfflineProduction(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		lastTickByUser[player.UserId] = nil
		creditCarryByUser[player.UserId] = nil
		offlineAppliedByUser[player.UserId] = nil
	end)

	for _, player in Players:GetPlayers() do
		lastTickByUser[player.UserId] = os.clock()
		creditCarryByUser[player.UserId] = 0
		offlineAppliedByUser[player.UserId] = nil
		if DataService.IsReady(player) then
			queueOfflineProduction(player)
		end
	end

	task.spawn(function()
		while true do
			task.wait(GameConfig.Factory.ProductionTickSeconds)
			for _, player in Players:GetPlayers() do
				ProductionService.TickPlayer(player)
			end
		end
	end)
end

return ProductionService
