--!strict

local HttpService = game:GetService("HttpService")
local MemoryStoreService = game:GetService("MemoryStoreService")

local FactoryRoutingRules =
	require(game:GetService("ReplicatedStorage").Shared.Domain.FactoryRoutingRules)

export type RouteRole = FactoryRoutingRules.RouteRole
export type RouteRecord = FactoryRoutingRules.RouteRecord

local FactoryRouteRegistry = {}

local ROUTE_TTL_SECONDS = 120
local FACTORY_ACCESS_TTL_SECONDS = 6 * 60 * 60
local RETRIES = 2

local routeMap = MemoryStoreService:GetHashMap("ScrapToBot_FactoryRoutes_v1")
local accessMap = MemoryStoreService:GetHashMap("ScrapToBot_FactoryAccess_v1")

local function retry<T>(label: string, callback: () -> T): (boolean, T?)
	local lastError: any = nil
	for attempt = 1, RETRIES do
		local ok, result = pcall(callback)
		if ok then
			return true, result
		end
		lastError = result
		if attempt < RETRIES then
			task.wait(0.2 * attempt)
		end
	end
	warn(("[FactoryRouteRegistry] %s failed: %s"):format(label, tostring(lastError)))
	return false, nil
end

local function routeKey(token: string): string
	return "route:" .. token
end

local function accessKey(ownerUserId: number): string
	return ("owner:%d"):format(ownerUserId)
end

function FactoryRouteRegistry.CreateRoute(
	playerUserId: number,
	ownerUserId: number,
	role: RouteRole
): string?
	local token = HttpService:GenerateGUID(false)
	local record: RouteRecord = {
		PlayerUserId = playerUserId,
		OwnerUserId = ownerUserId,
		Role = role,
		IssuedAt = os.time(),
	}

	local ok = retry("CreateRoute", function()
		routeMap:SetAsync(routeKey(token), record, ROUTE_TTL_SECONDS)
		return true
	end)
	return if ok then token else nil
end

function FactoryRouteRegistry.ConsumeRoute(token: string, playerUserId: number): RouteRecord?
	local claimId = HttpService:GenerateGUID(false)
	local claimedRecord: RouteRecord? = nil
	local rejectionCode = "ROUTE_MISSING"

	local ok, updatedValue = retry("ConsumeRoute", function()
		return routeMap:UpdateAsync(routeKey(token), function(current)
			local replacement, record, code = FactoryRoutingRules.TryClaimRoute(
				current,
				playerUserId,
				os.time(),
				ROUTE_TTL_SECONDS,
				claimId
			)
			rejectionCode = code
			if replacement == nil or record == nil then
				claimedRecord = nil
				return nil
			end

			claimedRecord = record
			return replacement
		end, ROUTE_TTL_SECONDS)
	end)
	if not ok then
		return nil
	end
	if
		typeof(updatedValue) ~= "table"
		or updatedValue.Consumed ~= true
		or updatedValue.ClaimId ~= claimId
		or claimedRecord == nil
	then
		warn(
			("[FactoryRouteRegistry] Rejected route %s for %d"):format(rejectionCode, playerUserId)
		)
		return nil
	end

	-- The atomic tombstone above is the replay barrier. Physical removal is cleanup
	-- only; if RemoveAsync fails, later consumers still see ROUTE_CONSUMED until TTL.
	retry("RemoveConsumedRoute", function()
		routeMap:RemoveAsync(routeKey(token))
		return true
	end)

	return claimedRecord
end

function FactoryRouteRegistry.DeleteRoute(token: string)
	retry("DeleteRoute", function()
		routeMap:RemoveAsync(routeKey(token))
		return true
	end)
end

function FactoryRouteRegistry.GetFactoryAccessCode(ownerUserId: number): string?
	local ok, value = retry("GetFactoryAccessCode", function()
		return accessMap:GetAsync(accessKey(ownerUserId))
	end)
	if not ok or typeof(value) ~= "string" or value == "" then
		return nil
	end
	return value
end

function FactoryRouteRegistry.SetFactoryAccessCode(ownerUserId: number, accessCode: string): boolean
	if accessCode == "" then
		return false
	end
	local ok = retry("SetFactoryAccessCode", function()
		accessMap:SetAsync(accessKey(ownerUserId), accessCode, FACTORY_ACCESS_TTL_SECONDS)
		return true
	end)
	return ok
end

function FactoryRouteRegistry.ClearFactoryAccessCode(ownerUserId: number)
	retry("ClearFactoryAccessCode", function()
		accessMap:RemoveAsync(accessKey(ownerUserId))
		return true
	end)
end

return FactoryRouteRegistry
