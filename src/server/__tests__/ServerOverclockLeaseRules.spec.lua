--!strict

local ServerOverclockLeaseRules = require(script.Parent.Parent.Domain.ServerOverclockLeaseRules)

local function emptyRecord()
	return ServerOverclockLeaseRules.Normalize(nil)
end

describe("ServerOverclockLeaseRules", function()
	it("claims an unowned lease when a purchase is applied", function()
		local record, accepted = ServerOverclockLeaseRules.ApplyPurchase(
			emptyRecord(),
			"server-a",
			"purchase-1",
			1_000,
			900,
			75
		)
		expect(accepted).toBe(true)
		expect(record.OwnerJobId).toBe("server-a")
		expect(record.BoostUntil).toBe(1_900)
		expect(record.LeaseUntil).toBe(1_075)
		expect(record.AppliedPurchases["purchase-1"]).toBe(true)
	end)

	it("does not extend twice for the same purchase id", function()
		local first = ServerOverclockLeaseRules.ApplyPurchase(
			emptyRecord(),
			"server-a",
			"purchase-1",
			1_000,
			900,
			75
		)
		local second, accepted =
			ServerOverclockLeaseRules.ApplyPurchase(first, "server-a", "purchase-1", 1_010, 900, 75)
		expect(accepted).toBe(true)
		expect(second.BoostUntil).toBe(1_900)
		expect(second.LeaseUntil).toBe(1_085)
	end)

	it("stacks a distinct purchase on the same owned lease", function()
		local first = ServerOverclockLeaseRules.ApplyPurchase(
			emptyRecord(),
			"server-a",
			"purchase-1",
			1_000,
			900,
			75
		)
		local second, accepted =
			ServerOverclockLeaseRules.ApplyPurchase(first, "server-a", "purchase-2", 1_010, 900, 75)
		expect(accepted).toBe(true)
		expect(second.BoostUntil).toBe(2_800)
	end)

	it("rejects a second live server while the lease is valid", function()
		local first = ServerOverclockLeaseRules.ApplyPurchase(
			emptyRecord(),
			"server-a",
			"purchase-1",
			1_000,
			900,
			75
		)
		local second, accepted =
			ServerOverclockLeaseRules.ApplyPurchase(first, "server-b", "purchase-2", 1_020, 900, 75)
		expect(accepted).toBe(false)
		expect(second.OwnerJobId).toBe("server-a")
		expect(second.AppliedPurchases["purchase-2"]).toBe(nil)
	end)

	it("allows crash recovery after the old lease expires without extending the boost", function()
		local first = ServerOverclockLeaseRules.ApplyPurchase(
			emptyRecord(),
			"server-a",
			"purchase-1",
			1_000,
			900,
			75
		)
		local recovered, claimed = ServerOverclockLeaseRules.Claim(first, "server-b", 1_076, 75)
		expect(claimed).toBe(true)
		expect(recovered.OwnerJobId).toBe("server-b")
		expect(recovered.BoostUntil).toBe(1_900)
		expect(recovered.LeaseUntil).toBe(1_151)
	end)

	it("will not recover a lease that is still owned by a live server", function()
		local first = ServerOverclockLeaseRules.ApplyPurchase(
			emptyRecord(),
			"server-a",
			"purchase-1",
			1_000,
			900,
			75
		)
		local recovered, claimed = ServerOverclockLeaseRules.Claim(first, "server-b", 1_050, 75)
		expect(claimed).toBe(false)
		expect(recovered.OwnerJobId).toBe("server-a")
	end)

	it("renews only for the current owner and releases on shutdown", function()
		local first = ServerOverclockLeaseRules.ApplyPurchase(
			emptyRecord(),
			"server-a",
			"purchase-1",
			1_000,
			900,
			75
		)
		local foreign, foreignRenewed =
			ServerOverclockLeaseRules.Renew(first, "server-b", 1_020, 75)
		expect(foreignRenewed).toBe(false)
		expect(foreign.LeaseUntil).toBe(1_075)

		local renewed, ownerRenewed = ServerOverclockLeaseRules.Renew(first, "server-a", 1_020, 75)
		expect(ownerRenewed).toBe(true)
		expect(renewed.LeaseUntil).toBe(1_095)

		local released = ServerOverclockLeaseRules.Release(renewed, "server-a", 1_021)
		expect(released.OwnerJobId).toBe("")
		expect(released.LeaseUntil).toBe(0)
		expect(released.BoostUntil).toBe(1_900)
	end)
end)
