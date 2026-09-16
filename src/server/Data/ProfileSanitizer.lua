--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AssignmentRules = require(ReplicatedStorage.Shared.Domain.AssignmentRules)
local FactoryRules = require(ReplicatedStorage.Shared.Domain.FactoryRules)
local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local RobotInventoryRules = require(ReplicatedStorage.Shared.Domain.RobotInventoryRules)
local Recipes = require(ReplicatedStorage.Shared.Config.Recipes)
local Robots = require(ReplicatedStorage.Shared.Config.Robots)
local Validation = require(ReplicatedStorage.Shared.Util.Validation)

local ProfileSanitizer = {}

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

local function sanitizeBoolean(value: any, fallback: boolean): boolean
	if typeof(value) == "boolean" then
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
	job.StartedAt = clampInteger(job.StartedAt, 0, 4_102_444_800, 0)
	job.CompletesAt = clampInteger(job.CompletesAt, 0, 4_102_444_800, 0)

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
	job.StartedAt = clampInteger(job.StartedAt, 0, 4_102_444_800, 0)
	job.CompletesAt = clampInteger(job.CompletesAt, 0, 4_102_444_800, 0)

	if not job.Active or job.StartedAt == 0 or job.CompletesAt < job.StartedAt then
		resetAssemblerJob(job)
	end
end

function ProfileSanitizer.Sanitize(data: any)
	assert(typeof(data) == "table", "Profile data must be a table")

	data.Version = GameConfig.ProfileSchemaVersion
	data.Revision = clampInteger(data.Revision, 0, 2_147_483_647, 0)

	local currencies = ensureTable(data, "Currencies")
	currencies.Credits = clampInteger(currencies.Credits, 0, GameConfig.Economy.MaxCredits, 0)

	local materials = ensureTable(data, "Materials")
	for _, materialId in { "ScrapMetal", "Wiring", "PowerCoreFragments" } do
		materials[materialId] =
			clampInteger(materials[materialId], 0, GameConfig.Economy.MaxMaterialCount, 0)
	end

	local robots = ensureTable(data, "Robots")
	local ownedByUid = ensureTable(robots, "OwnedByUid")
	local requestedNextUid = clampInteger(robots.NextUid, 1, 2_147_483_647, 1)

	local ownedCount = 0
	for uid, robot in ownedByUid do
		local valid = typeof(uid) == "string"
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
	machines.ProcessorLevel = clampInteger(machines.ProcessorLevel, 1, 4, 1)
	machines.AssemblerLevel = clampInteger(machines.AssemblerLevel, 1, 4, 1)
	machines.StorageLevel = clampInteger(machines.StorageLevel, 1, 4, 1)
	machines.WorkSlotsLevel = clampInteger(machines.WorkSlotsLevel, 1, 4, 1)
	sanitizeProcessorJob(machines)
	sanitizeAssemblerJob(machines)

	local assignments = ensureTable(data, "Assignments")
	local workPads = ensureTable(assignments, "WorkPads")
	local unlockedSlots = FactoryRules.GetWorkSlots(machines.WorkSlotsLevel)
	local normalizedWorkPads =
		AssignmentRules.NormalizeWorkPads(workPads, ownedByUid, unlockedSlots)
	table.clear(workPads)
	for padId, robotUid in normalizedWorkPads do
		workPads[padId] = robotUid
	end

	local progression = ensureTable(data, "Progression")
	progression.Zone = clampInteger(progression.Zone, 1, 100, 1)
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
	ensureTable(tutorial, "Milestones")

	local entitlements = ensureTable(data, "Entitlements")
	ensureTable(entitlements, "CachedPassFlags")

	local receipts = ensureTable(data, "Receipts")
	local recentPurchaseIds = receipts.RecentPurchaseIds
	if typeof(recentPurchaseIds) ~= "table" then
		recentPurchaseIds = {}
		receipts.RecentPurchaseIds = recentPurchaseIds
	end
	while #recentPurchaseIds > 100 do
		table.remove(recentPurchaseIds, 1)
	end
	for index = #recentPurchaseIds, 1, -1 do
		if not Validation.isBoundedString(recentPurchaseIds[index], 128) then
			table.remove(recentPurchaseIds, index)
		end
	end

	local stats = ensureTable(data, "Stats")
	stats.LifetimeCredits = clampInteger(stats.LifetimeCredits, 0, GameConfig.Economy.MaxCredits, 0)
	stats.LifetimeRobotsBuilt = clampInteger(stats.LifetimeRobotsBuilt, 0, 2_147_483_647, 0)

	local timestamps = ensureTable(data, "Timestamps")
	timestamps.LastJoin = clampInteger(timestamps.LastJoin, 0, 4_102_444_800, 0)
	timestamps.LastSave = clampInteger(timestamps.LastSave, 0, 4_102_444_800, 0)
	timestamps.LastProductionTick = clampInteger(timestamps.LastProductionTick, 0, 4_102_444_800, 0)

	local settings = ensureTable(data, "Settings")
	settings.Audio = sanitizeBoolean(settings.Audio, true)
	settings.Haptics = sanitizeBoolean(settings.Haptics, true)
	ensureTable(settings, "UI")
end

return table.freeze(ProfileSanitizer)
