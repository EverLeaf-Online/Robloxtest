--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)

export type Bucket = {
	Tokens: number,
	UpdatedAt: number,
}

export type RatePolicy = {
	Capacity: number,
	RefillPerSecond: number,
}

local RateLimiter = {}
local bucketsByUser: { [number]: { [string]: Bucket } } = {}
local policies = GameConfig.Networking.RateLimits :: { [string]: RatePolicy }

local function getPolicy(actionName: string): RatePolicy?
	return policies[actionName]
end

function RateLimiter.Consume(player: Player, actionName: string, cost: number?): boolean
	local policy = getPolicy(actionName)
	if policy == nil then
		return false
	end

	local now = os.clock()
	local userBuckets = bucketsByUser[player.UserId]
	if userBuckets == nil then
		userBuckets = {}
		bucketsByUser[player.UserId] = userBuckets
	end

	local bucket = userBuckets[actionName]
	if bucket == nil then
		bucket = {
			Tokens = policy.Capacity,
			UpdatedAt = now,
		}
		userBuckets[actionName] = bucket
	end

	local elapsed = math.max(0, now - bucket.UpdatedAt)
	bucket.UpdatedAt = now
	bucket.Tokens = math.min(policy.Capacity, bucket.Tokens + elapsed * policy.RefillPerSecond)

	local tokenCost = cost or 1
	if
		tokenCost ~= tokenCost
		or tokenCost <= 0
		or tokenCost == math.huge
		or tokenCost > policy.Capacity
	then
		return false
	end

	if bucket.Tokens < tokenCost then
		return false
	end

	bucket.Tokens -= tokenCost
	return true
end

function RateLimiter.Forget(player: Player)
	bucketsByUser[player.UserId] = nil
end

return table.freeze(RateLimiter)
