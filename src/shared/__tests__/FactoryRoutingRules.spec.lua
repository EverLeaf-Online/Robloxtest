--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JestGlobals = require(ReplicatedStorage.DevPackages.JestGlobals)
local describe = JestGlobals.describe
local expect = JestGlobals.expect
local it = JestGlobals.it

local FactoryRoutingRules = require(script.Parent.Parent.Domain.FactoryRoutingRules)

describe("FactoryRoutingRules", function()
	local now = 1_000
	local maxAge = 120

	it("accepts a current owner route for the routed player", function()
		local ok, code = FactoryRoutingRules.ValidateRoute({
			PlayerUserId = 42,
			OwnerUserId = 42,
			Role = "Owner",
			IssuedAt = 950,
		}, 42, now, maxAge)
		expect(ok).toBe(true)
		expect(code).toBe("ROUTE_VALID")
	end)

	it("rejects a route copied by another player", function()
		local ok, code = FactoryRoutingRules.ValidateRoute({
			PlayerUserId = 42,
			OwnerUserId = 42,
			Role = "Owner",
			IssuedAt = 950,
		}, 99, now, maxAge)
		expect(ok).toBe(false)
		expect(code).toBe("ROUTE_PLAYER_MISMATCH")
	end)

	it("rejects expired routes", function()
		local ok, code = FactoryRoutingRules.ValidateRoute({
			PlayerUserId = 42,
			OwnerUserId = 42,
			Role = "Owner",
			IssuedAt = 800,
		}, 42, now, maxAge)
		expect(ok).toBe(false)
		expect(code).toBe("ROUTE_EXPIRED")
	end)

	it("rejects an owner route that names somebody else as owner", function()
		local ok, code = FactoryRoutingRules.ValidateRoute({
			PlayerUserId = 42,
			OwnerUserId = 99,
			Role = "Owner",
			IssuedAt = 950,
		}, 42, now, maxAge)
		expect(ok).toBe(false)
		expect(code).toBe("OWNER_ROUTE_MISMATCH")
	end)

	it("allows a visitor route to target another player's factory", function()
		local ok, code = FactoryRoutingRules.ValidateRoute({
			PlayerUserId = 42,
			OwnerUserId = 99,
			Role = "Visitor",
			IssuedAt = 950,
		}, 42, now, maxAge)
		expect(ok).toBe(true)
		expect(code).toBe("ROUTE_VALID")
	end)

	it("allows exactly one atomic claim and rejects a replay tombstone", function()
		local route = {
			PlayerUserId = 42,
			OwnerUserId = 42,
			Role = "Owner",
			IssuedAt = 950,
		}

		local tombstone, claimedRecord, code =
			FactoryRoutingRules.TryClaimRoute(route, 42, now, maxAge, "claim-a")
		expect(tombstone).toEqual({
			Consumed = true,
			ClaimId = "claim-a",
		})
		expect(claimedRecord).toEqual(route)
		expect(code).toBe("ROUTE_CLAIMED")

		local replayTombstone, replayRecord, replayCode =
			FactoryRoutingRules.TryClaimRoute(tombstone, 42, now, maxAge, "claim-b")
		expect(replayTombstone).toBe(nil)
		expect(replayRecord).toBe(nil)
		expect(replayCode).toBe("ROUTE_CONSUMED")
	end)

	it("never lets a copied route claim succeed for a different player", function()
		local route = {
			PlayerUserId = 42,
			OwnerUserId = 99,
			Role = "Visitor",
			IssuedAt = 950,
		}

		local tombstone, claimedRecord, code =
			FactoryRoutingRules.TryClaimRoute(route, 7, now, maxAge, "claim-copy")
		expect(tombstone).toBe(nil)
		expect(claimedRecord).toBe(nil)
		expect(code).toBe("ROUTE_PLAYER_MISMATCH")
	end)

	it("rejects malformed atomic-claim ids without consuming a valid route", function()
		local route = {
			PlayerUserId = 42,
			OwnerUserId = 42,
			Role = "Owner",
			IssuedAt = 950,
		}

		local tombstone, claimedRecord, code =
			FactoryRoutingRules.TryClaimRoute(route, 42, now, maxAge, "")
		expect(tombstone).toBe(nil)
		expect(claimedRecord).toBe(nil)
		expect(code).toBe("CLAIM_ID_INVALID")

		local retryTombstone, retryRecord, retryCode =
			FactoryRoutingRules.TryClaimRoute(route, 42, now, maxAge, "claim-valid")
		expect(retryTombstone ~= nil).toBe(true)
		expect(retryRecord).toEqual(route)
		expect(retryCode).toBe("ROUTE_CLAIMED")
	end)
end)
