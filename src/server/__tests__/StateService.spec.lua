--!strict

local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JestGlobals = require(ReplicatedStorage.DevPackages.JestGlobals)
local describe = JestGlobals.describe
local expect = JestGlobals.expect
local it = JestGlobals.it

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)

local serverRoot = script.Parent.Parent
local ProfileTemplate = require(serverRoot.Data.ProfileTemplate)
local StateService = require(serverRoot.Services.StateServiceUnderTest)

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

local PROFILE_COUNT = 8
local SNAPSHOT_ITERATIONS = 5
local BUILD_ENCODE_AVERAGE_BUDGET_MS = 2
local MAX_AVERAGE_PAYLOAD_BYTES = 20_000

local function makeMaxProfile(seed: number): any
	local data = deepCopy(ProfileTemplate)
	data.Revision = seed
	data.Currencies.Credits = 25_000_000 + seed
	data.Materials.ScrapMetal = 250_000
	data.Materials.Wiring = 125_000
	data.Materials.PowerCoreFragments = 25_000
	data.Stats.LifetimeCredits = 100_000_000
	data.Stats.LifetimeRobotsBuilt = GameConfig.Economy.MaxOwnedRobots
	data.Progression.Zone = 2

	for index = 1, GameConfig.Economy.MaxOwnedRobots do
		local uid = ("R%d"):format(index)
		data.Robots.OwnedByUid[uid] = {
			RobotId = if index % 2 == 0 then "TinScout" else "BoltBuddy",
			AcquiredAt = 1_800_000_000 + index,
		}
	end
	data.Robots.NextUid = GameConfig.Economy.MaxOwnedRobots + 1

	return data
end

describe("StateService snapshot payload", function()
	it("omits server-only robot acquisition timestamps at the max inventory cap", function()
		local data = deepCopy(ProfileTemplate)

		for index = 1, GameConfig.Economy.MaxOwnedRobots do
			local uid = ("R%d"):format(index)
			data.Robots.OwnedByUid[uid] = {
				RobotId = "TinScout",
				AcquiredAt = 1_800_000_000 + index,
			}
		end

		local snapshot = StateService.BuildSnapshot(data)
		local robotCount = 0
		local replicatedRobotScalars = 0

		for uid, robot in snapshot.Robots.OwnedByUid do
			robotCount += 1
			expect(robot.RobotId).toBe("TinScout")
			expect(robot.AcquiredAt).toBe(nil)
			expect(data.Robots.OwnedByUid[uid].AcquiredAt ~= nil).toBe(true)

			for _ in robot do
				replicatedRobotScalars += 1
			end
		end

		expect(robotCount).toBe(GameConfig.Economy.MaxOwnedRobots)
		expect(replicatedRobotScalars).toBe(GameConfig.Economy.MaxOwnedRobots)

		local optimizedBytes = #HttpService:JSONEncode(snapshot)
		local legacySnapshot = deepCopy(snapshot)
		for uid, robot in legacySnapshot.Robots.OwnedByUid do
			robot.AcquiredAt = data.Robots.OwnedByUid[uid].AcquiredAt
		end
		local legacyBytes = #HttpService:JSONEncode(legacySnapshot)
		local savedBytes = legacyBytes - optimizedBytes

		print(
			("[StateSnapshotPerf] robots=%d optimized_bytes=%d legacy_bytes=%d saved_bytes=%d"):format(
				robotCount,
				optimizedBytes,
				legacyBytes,
				savedBytes
			)
		)

		expect(savedBytes >= 10_000).toBe(true)
	end)

	it("profiles full snapshot build and JSON payload across eight max profiles", function()
		local profiles = table.create(PROFILE_COUNT)
		for index = 1, PROFILE_COUNT do
			profiles[index] = makeMaxProfile(index)
		end

		-- Warm table/module paths before timing.
		for _, profile in profiles do
			StateService.BuildSnapshot(profile)
		end

		local totalBytes = 0
		local start = os.clock()
		for _ = 1, SNAPSHOT_ITERATIONS do
			for _, profile in profiles do
				local snapshot = StateService.BuildSnapshot(profile)
				local encoded = HttpService:JSONEncode(snapshot)
				totalBytes += #encoded
			end
		end
		local elapsedSeconds = os.clock() - start
		local sampleCount = PROFILE_COUNT * SNAPSHOT_ITERATIONS
		local averageMs = elapsedSeconds * 1_000 / sampleCount
		local averageBytes = totalBytes / sampleCount
		local estimatedEightPlayerBurstMs = averageMs * PROFILE_COUNT

		print(
			("[StateSnapshot8PPerf] players=%d robots_per_player=%d samples=%d avg_build_encode_ms=%.3f avg_bytes=%.0f estimated_8p_burst_ms=%.3f"):format(
				PROFILE_COUNT,
				GameConfig.Economy.MaxOwnedRobots,
				SNAPSHOT_ITERATIONS,
				averageMs,
				averageBytes,
				estimatedEightPlayerBurstMs
			)
		)

		-- First OCALE baseline on 2026-09-20 measured 0.200 ms/profile for
		-- BuildSnapshot + JSONEncode and ~15,950 bytes/profile at 500 robots.
		-- These ceilings leave substantial cloud-runtime/content headroom while
		-- still catching a large CPU or payload regression before public launch.
		expect(averageMs <= BUILD_ENCODE_AVERAGE_BUDGET_MS).toBe(true)
		expect(averageBytes <= MAX_AVERAGE_PAYLOAD_BYTES).toBe(true)
	end, 15_000)
end)
