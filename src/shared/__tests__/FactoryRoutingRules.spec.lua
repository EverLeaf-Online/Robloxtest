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
end)
