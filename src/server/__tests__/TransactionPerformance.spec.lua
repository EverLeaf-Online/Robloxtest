--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JestGlobals = require(ReplicatedStorage.DevPackages.JestGlobals)
local describe = JestGlobals.describe
local expect = JestGlobals.expect
local it = JestGlobals.it

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local TransactionRules = require(ReplicatedStorage.Shared.Domain.TransactionRules)

local serverRoot = script.Parent.Parent
local ProfileTemplate = require(serverRoot.Data.ProfileTemplate)

local PROFILE_COUNT = 8
local SAMPLE_ITERATIONS = 10

local function deepCopy(value: any): any
	if typeof(value) ~= "table" then
		return value
	end
	local result = {}
	for key, child in value do
		result[deepCopy(key)] = deepCopy(child)
	end
	return result
end

local function robotUid(index: number): string
	return ("R%06d"):format(index)
end

local function makeMaxRobotProfile(seed: number): any
	local profile = deepCopy(ProfileTemplate)
	profile.Revision = seed
	profile.Currencies.Credits = 50_000_000 + seed
	profile.Materials.ScrapMetal = 500_000
	profile.Materials.Wiring = 500_000
	profile.Materials.PowerCoreFragments = 500_000
	profile.Stats.LifetimeCredits = 100_000_000
	profile.Stats.LifetimeRobotsBuilt = GameConfig.Economy.MaxOwnedRobots

	for index = 1, GameConfig.Economy.MaxOwnedRobots do
		local uid = robotUid(index)
		local robotId = if index % 2 == 0 then "Scrapling" else "Wirebug"
		profile.Robots.OwnedByUid[uid] = {
			RobotId = robotId,
			AcquiredAt = 1_700_000_000 + index,
		}
		profile.Collection.RobotSeen[robotId] = true
		profile.Collection.RobotOwned[robotId] = true
	end
	profile.Robots.NextUid = GameConfig.Economy.MaxOwnedRobots + 1

	for index = 1, math.min(GameConfig.Factory.MaxWorkSlots + 2, 8) do
		profile.Assignments.WorkPads[("Pad%d"):format(index)] = robotUid(index)
	end

	return profile
end

local function countRobots(profile: any): number
	local count = 0
	for _ in profile.Robots.OwnedByUid do
		count += 1
	end
	return count
end

describe("Transaction performance profile", function()
	it("profiles max-inventory transaction cost across eight representative players", function()
		local profiles = table.create(PROFILE_COUNT)
		for index = 1, PROFILE_COUNT do
			profiles[index] = makeMaxRobotProfile(index)
		end

		-- Warm module paths/table shapes before collecting the sample.
		for _, profile in profiles do
			TransactionRules.Snapshot(profile)
		end

		local snapshotStart = os.clock()
		for _ = 1, SAMPLE_ITERATIONS do
			for _, profile in profiles do
				local snapshot = TransactionRules.Snapshot(profile)
				expect(countRobots(snapshot)).toBe(GameConfig.Economy.MaxOwnedRobots)
			end
		end
		local snapshotSeconds = os.clock() - snapshotStart
		local snapshotCount = PROFILE_COUNT * SAMPLE_ITERATIONS
		local snapshotAverageMs = (snapshotSeconds * 1_000) / snapshotCount

		local executeStart = os.clock()
		for _ = 1, SAMPLE_ITERATIONS do
			for _, profile in profiles do
				local executed = TransactionRules.Execute(profile, function(draft)
					draft.Revision += 1
					return true, true
				end)
				expect(executed).toBe(true)
			end
		end
		local executeSeconds = os.clock() - executeStart
		local executeCount = PROFILE_COUNT * SAMPLE_ITERATIONS
		local executeAverageMs = (executeSeconds * 1_000) / executeCount

		print(
			("[TransactionPerf] players=%d robots_per_player=%d samples=%d snapshot_avg_ms=%.3f execute_avg_ms=%.3f"):format(
				PROFILE_COUNT,
				GameConfig.Economy.MaxOwnedRobots,
				SAMPLE_ITERATIONS,
				snapshotAverageMs,
				executeAverageMs
			)
		)

		expect(snapshotAverageMs > 0).toBe(true)
		expect(executeAverageMs > 0).toBe(true)
	end, 15_000)
end)
