--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JestGlobals = require(ReplicatedStorage.DevPackages.JestGlobals)
local describe = JestGlobals.describe
local expect = JestGlobals.expect
local it = JestGlobals.it

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local RemoteNames = require(ReplicatedStorage.Shared.Networking.RemoteNames)

local serverRoot = script.Parent.Parent
local RateLimiter = require(serverRoot.Services.RateLimiter)

local function fakePlayer(userId: number): Player
	return ({ UserId = userId } :: any) :: Player
end

describe("RateLimiter", function()
	it("enforces configured burst capacity per action", function()
		local player = fakePlayer(91001)
		RateLimiter.Forget(player)

		expect(RateLimiter.Consume(player, RemoteNames.RequestState)).toBe(true)
		expect(RateLimiter.Consume(player, RemoteNames.RequestState)).toBe(true)
		expect(RateLimiter.Consume(player, RemoteNames.RequestState)).toBe(false)

		RateLimiter.Forget(player)
	end)

	it("isolates buckets by player and action", function()
		local playerA = fakePlayer(91002)
		local playerB = fakePlayer(91003)
		RateLimiter.Forget(playerA)
		RateLimiter.Forget(playerB)

		expect(RateLimiter.Consume(playerA, RemoteNames.RequestState, 2)).toBe(true)
		expect(RateLimiter.Consume(playerA, RemoteNames.RequestState)).toBe(false)

		expect(RateLimiter.Consume(playerA, RemoteNames.RequestCollect)).toBe(true)
		expect(RateLimiter.Consume(playerB, RemoteNames.RequestState)).toBe(true)

		RateLimiter.Forget(playerA)
		RateLimiter.Forget(playerB)
	end)

	it("rejects unknown actions and invalid token costs", function()
		local player = fakePlayer(91004)
		RateLimiter.Forget(player)

		expect(RateLimiter.Consume(player, "UnknownRemote")).toBe(false)
		expect(RateLimiter.Consume(player, RemoteNames.RequestState, 0)).toBe(false)
		expect(RateLimiter.Consume(player, RemoteNames.RequestState, -1)).toBe(false)
		expect(RateLimiter.Consume(player, RemoteNames.RequestState, 0 / 0)).toBe(false)
		expect(RateLimiter.Consume(player, RemoteNames.RequestState, math.huge)).toBe(false)
		expect(RateLimiter.Consume(player, RemoteNames.RequestState, 3)).toBe(false)

		-- Invalid costs must not drain the legitimate burst allowance.
		expect(RateLimiter.Consume(player, RemoteNames.RequestState)).toBe(true)
		expect(RateLimiter.Consume(player, RemoteNames.RequestState)).toBe(true)

		RateLimiter.Forget(player)
	end)

	it("keeps the request catalog and rate-limit policy in exact lockstep", function()
		local requestSet: { [string]: boolean } = {}

		for _, requestName in RemoteNames.Requests do
			requestSet[requestName] = true
			local policy = GameConfig.Networking.RateLimits[requestName]
			expect(policy ~= nil).toBe(true)
			if policy ~= nil then
				expect(policy.Capacity > 0).toBe(true)
				expect(policy.RefillPerSecond > 0).toBe(true)
				expect(policy.Capacity < math.huge).toBe(true)
				expect(policy.RefillPerSecond < math.huge).toBe(true)
			end
		end

		for actionName in GameConfig.Networking.RateLimits do
			expect(requestSet[actionName] == true).toBe(true)
		end
	end)

	it("clears a player's buckets on disconnect cleanup", function()
		local player = fakePlayer(91005)
		RateLimiter.Forget(player)

		expect(RateLimiter.Consume(player, RemoteNames.RequestState, 2)).toBe(true)
		expect(RateLimiter.Consume(player, RemoteNames.RequestState)).toBe(false)

		RateLimiter.Forget(player)
		expect(RateLimiter.Consume(player, RemoteNames.RequestState)).toBe(true)

		RateLimiter.Forget(player)
	end)
end)
