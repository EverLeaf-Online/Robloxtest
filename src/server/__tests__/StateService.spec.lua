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
end)
