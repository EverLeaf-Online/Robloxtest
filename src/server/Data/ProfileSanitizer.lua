--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AssignmentRules = require(ReplicatedStorage.Shared.Domain.AssignmentRules)
local FactoryRules = require(ReplicatedStorage.Shared.Domain.FactoryRules)
local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local Materials = require(ReplicatedStorage.Shared.Config.Materials)
local ProgressionRules = require(ReplicatedStorage.Shared.Domain.ProgressionRules)
local ReceiptRules = require(ReplicatedStorage.Shared.Domain.ReceiptRules)
local RobotInventoryRules = require(ReplicatedStorage.Shared.Domain.RobotInventoryRules)
local Recipes = require(ReplicatedStorage.Shared.Config.Recipes)
local Robots = require(ReplicatedStorage.Shared.Config.Robots)
local Validation = require(ReplicatedStorage.Shared.Util.Validation)

local ProfileSanitizer = {}

local knownTutorialMilestones = table.freeze({
	FirstScrap = true,
	FirstProcess = true,
	FirstBotReveal = true,
	FirstBotAssigned = true,
	FirstIncomeEarned = true,
	FirstUpgrade = true,
	FirstZoneGoalSeen = true,
	FirstZoneUnlock = true,
})

local knownPassFlags = table.freeze({
	Production2x = true,
	ExpandedStorage = true,
	BotWorkSlots2 = true,
	AutoCollect = true,
	FactoryVIP = true,
})

local function ensureTable(parent: any, key: string): any
	if typeof(parent[key]) ~= "table" then
		parent[key] = {}
	end
	return parent[key]
end

local function clampInteger(value: any, minimum: number, maximum: number, fallback: number): number
	if not Validation.isSafeInteger(value, minimum, maximum) then
		return fallback
	end
	return value :: number
end

local function clampFiniteNumber(value: any, minimum: number, maximum: number, fallback: number): number
	if
		typeof(value) ~= "number"
		or value ~= value
		or value == math.huge
		or value == -math.huge
		or value < minimum
		or value > maximum
	then
		return fallback
	end
	return value :: number
end

local function sanitizeBoolean(value: any, fallback: boolean): boolean
	if typeof(value) == "boolean" then
		return value
	end
	return fallback
end

local function sanitizeBoundedString(value: any, maximumLength: number, fallback: string): string
	if typeof(value) == "string" and #value <= maximumLength then
		return value
	end
	return fallback
end

local function resetProcessorJob(job: any)
	job.Active = false
	job.RecipeId = ""
	job.StartedAt = 0
	job.CompletesAt = 0
end

local function sanitizeProcessorJob(machines: any)
	local job = ensureTable(machines, "ProcessorJob")
	job.Active = sanitizeBoolean(job.Active, false)
	job.RecipeId = if Validation.isBoundedString(
			job.RecipeId,
			GameConfig.Networking.MaxStringLength
		)
		then job.RecipeId
		else ""
	job.StartedAt = clampFiniteNumber(job.StartedAt, 0, 4_102_444_800, 0)
	job.CompletesAt = clampFiniteNumber(job.CompletesAt, 0, 4_102_444_800, 0)

	if
		not job.Active
		or Recipes.Processor[job.RecipeId] == nil
		or job.StartedAt == 0
		or job.CompletesAt < job.StartedAt
	then
		resetProcessorJob(job)
	end
end

local function resetAssemblerJob(job: any)
	job.Active = false
	job.StartedAt = 0
	job.CompletesAt = 0
end

local function sanitizeAssemblerJob(machines: any)
	local job = ensureTable(machines, "AssemblerJob")
	job.Active = sanitizeBoolean(job.Active, false)
	job.StartedAt = clampFiniteNumber(job.StartedAt, 0, 4_102_444_800, 0)
	job.CompletesAt = clampFiniteNumber(job.CompletesAt, 0, 4_102_444_800, 0)

	if not job.Active or job.StartedAt == 0 or job.CompletesAt < job.StartedAt then
		resetAssemblerJob(job)
	end
end

local function sanitizePassFlags(entitlements: any)
	local passFlags = ensureTable(entitlements, "CachedPassFlags")
	for passName, owned in passFlags do
		if knownPassFlags[passName] ~= true or typeof(owned) ~= "boolean" then
			passFlags[passName] = nil
		end
	end
end

local function sanitizeClubCosmetics(entitlements: any)
	local cosmetics = ensureTable(entitlements, "FactoryClubCosmetics")
	local keys: { string } = {}
	for cosmeticId, owned in cosmetics do
		if
			typeof(cosmeticId) ~= "string"
			or #cosmeticId == 0
			or #cosmeticId > 32
			or owned ~= true
		then
			cosmetics[cosmeticId] = nil
		else
			table.insert(keys, cosmeticId)
		end
	end
	table.sort(keys)
	while #keys > GameConfig.Economy.MaxFactoryClubCosmetics do
		local oldest = table.remove(keys, 1)
		if oldest ~= nil then
			cosmetics[oldest] = nil
		end
	end

	local equipped = sanitizeBoundedString(entitlements.EquippedFactoryClubCosmetic, 32, "")
	if equipped ~= "" and cosmetics[equipped] ~= true then
		equipped = ""
	end
	entitlements.EquippedFactoryClubCosmetic = equipped
end

function ProfileSanitizer.Sanitize(data: any)
	assert(typeof(data) == "table", "Profile data must be a table")

	data.Version = GameConfig.ProfileSchemaVersion
	data.Revision = clampInteger(data.Revision, 0, 2_147_483_647, 0)

	local currencies = ensureTable(data, "Currencies")
	currencies.Credits = clampInteger(currencies.Credits, 0, GameConfig.Economy.MaxCredits, 0)

	local materials = ensureTable(data, "Materials")
	for materialId in materials do
		if Materials[materialId] == nil then
			materials[materialId] = nil
		end
	end
	for materialId in Materials do
		materials[materialId] =
			clampInteger(materials[materialId], 0, GameConfig.Economy.MaxMaterialCount, 0)
	end

	local consumables = ensureTable(data, "Consumables")
	consumables.InstantProcessTokens = clampInteger(
		consumables.InstantProcessTokens,
		0,
		GameConfig.Economy.MaxInstantProcessTokens,
		0
	)

	local robots = ensureTable(data, "Robots")
	local ownedByUid = ensureTable(robots, "OwnedByUid")
	local requestedNextUid = clampInteger(robots.NextUid, 1, 2_147_483_647, 1)

	local ownedCount = 0
	for uid, robot in ownedByUid do
		local valid = RobotInventoryRules.IsValidUid(uid)
			and typeof(robot) == "table"
			and Validation.isKnownId(robot.RobotId, Robots.Definitions)

		if not valid or ownedCount >= GameConfig.Economy.MaxOwnedRobots then
			ownedByUid[uid] = nil
		else
			ownedCount += 1
			robot.RobotId = robot.RobotId :: string
			robot.AcquiredAt = clampInteger(robot.AcquiredAt, 0, 4_102_444_800, 0)
		end
	end

	robots.NextUid = RobotInventoryRules.FindAvailableUidNumber(
		ownedByUid,
		requestedNextUid,
		GameConfig.Economy.MaxOwnedRobots
	) or 1

	local machines = ensureTable(data, "Machines")
	machines.ProcessorLevel =
		FactoryRules.NormalizeUpgradeLevel("ProcessorSpeed", machines.ProcessorLevel)
	machines.AssemblerLevel =
		FactoryRules.NormalizeUpgradeLevel("AssemblerSpeed", machines.AssemblerLevel)
	machines.StorageLevel = FactoryRules.NormalizeUpgradeLevel("Storage", machines.StorageLevel)
	machines.WorkSlotsLevel =
		FactoryRules.NormalizeUpgradeLevel("WorkSlots", machines.WorkSlotsLevel)
	sanitizeProcessorJob(machines)
	sanitizeAssemblerJob(machines)

	local entitlements = ensureTable(data, "Entitlements")
	sanitizePassFlags(entitlements)
	entitlements.StarterPackClaimed = sanitizeBoolean(entitlements.StarterPackClaimed, false)
	entitlements.PersonalOverclockUntil =
		clampInteger(entitlements.PersonalOverclockUntil, 0, 4_102_444_800, 0)
	entitlements.ServerOverclockUntil =
		clampInteger(entitlements.ServerOverclockUntil, 0, 4_102_444_800, 0)
	entitlements.FactoryClubActiveCached =
		sanitizeBoolean(entitlements.FactoryClubActiveCached, false)
	entitlements.FactoryClubLastGrantedCycle =
		sanitizeBoundedString(entitlements.FactoryClubLastGrantedCycle, 32, "")
	sanitizeClubCosmetics(entitlements)

	local assignments = ensureTable(data, "Assignments")
	local workPads = ensureTable(assignments, "WorkPads")
	local unlockedSlots = FactoryRules.GetWorkSlots(machines.WorkSlotsLevel)
	local cachedPassFlags = entitlements.CachedPassFlags
	if typeof(cachedPassFlags) == "table" and cachedPassFlags.BotWorkSlots2 == true then
		unlockedSlots = math.min(GameConfig.Factory.MaxWorkSlots + 2, unlockedSlots + 2)
	end
	local normalizedWorkPads =
		AssignmentRules.NormalizeWorkPads(workPads, ownedByUid, unlockedSlots)
	table.clear(workPads)
	for padId, robotUid in normalizedWorkPads do
		workPads[padId] = robotUid
	end

	local progression = ensureTable(data, "Progression")
	progression.Zone = ProgressionRules.NormalizeCurrentZone(progression.Zone)
	progression.FactoryTier = clampInteger(progression.FactoryTier, 1, 100, 1)
	progression.PrestigeCount = clampInteger(progression.PrestigeCount, 0, 1_000_000, 0)

	local collection = ensureTable(data, "Collection")
	local robotSeen = ensureTable(collection, "RobotSeen")
	local robotOwned = ensureTable(collection, "RobotOwned")
	for robotId, seen in robotSeen do
		if Robots.Definitions[robotId] == nil or seen ~= true then
			robotSeen[robotId] = nil
		end
	end
	for robotId, hasOwned in robotOwned do
		if Robots.Definitions[robotId] == nil or hasOwned ~= true then
			robotOwned[robotId] = nil
		end
	end

	local tutorial = ensureTable(data, "Tutorial")
	local milestones = ensureTable(tutorial, "Milestones")
	for milestoneId, reached in milestones do
		if knownTutorialMilestones[milestoneId] ~= true or reached ~= true then
			milestones[milestoneId] = nil
		end
	end

	local referrals = ensureTable(data, "Referrals")
	referrals.PendingInviterUserId =
		clampInteger(referrals.PendingInviterUserId, 0, 2_147_483_647, 0)
	referrals.PendingStartedAt = clampInteger(referrals.PendingStartedAt, 0, 4_102_444_800, 0)
	referrals.PendingPlaySeconds = clampInteger(
		referrals.PendingPlaySeconds,
		0,
		GameConfig.Engagement.ReferralQualificationSeconds,
		0
	)
	referrals.QualifiedRewardCount =
		clampInteger(referrals.QualifiedRewardCount, 0, GameConfig.Economy.MaxReferralRewards, 0)
	if referrals.PendingInviterUserId == 0 then
		referrals.PendingStartedAt = 0
		referrals.PendingPlaySeconds = 0
	end

	local receipts = ensureTable(data, "Receipts")
	receipts.RecentPurchaseIds = ReceiptRules.NormalizeRecentPurchaseIds(
		receipts.RecentPurchaseIds,
		GameConfig.Economy.MaxReceiptHistory,
		128
	)

	local stats = ensureTable(data, "Stats")
	stats.LifetimeCredits = clampInteger(stats.LifetimeCredits, 0, GameConfig.Economy.MaxCredits, 0)
	stats.LifetimeRobotsBuilt = clampInteger(stats.LifetimeRobotsBuilt, 0, 2_147_483_647, 0)
	stats.LifetimePlaySeconds = clampInteger(stats.LifetimePlaySeconds, 0, 2_147_483_647, 0)

	local timestamps = ensureTable(data, "Timestamps")
	timestamps.LastJoin = clampInteger(timestamps.LastJoin, 0, 4_102_444_800, 0)
	timestamps.LastLeave = clampInteger(timestamps.LastLeave, 0, 4_102_444_800, 0)
	timestamps.LastSave = clampInteger(timestamps.LastSave, 0, 4_102_444_800, 0)
	timestamps.LastProductionTick = clampInteger(timestamps.LastProductionTick, 0, 4_102_444_800, 0)

	local settings = ensureTable(data, "Settings")
	settings.Audio = sanitizeBoolean(settings.Audio, true)
	settings.Haptics = sanitizeBoolean(settings.Haptics, true)
	ensureTable(settings, "UI")
end

return table.freeze(ProfileSanitizer)
