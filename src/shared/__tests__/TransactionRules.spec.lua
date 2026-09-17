--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JestGlobals = require(ReplicatedStorage.DevPackages.JestGlobals)
local describe = JestGlobals.describe
local expect = JestGlobals.expect
local it = JestGlobals.it

local TransactionRules = require(script.Parent.Parent.Domain.TransactionRules)

describe("TransactionRules", function()
	it("creates isolated snapshots and restores nested contents", function()
		local live = {
			Credits = 100,
			Nested = { Value = 5 },
		}
		local snapshot = TransactionRules.Snapshot(live)

		live.Credits = 1
		live.Nested.Value = 99
		expect(snapshot.Credits).toBe(100)
		expect(snapshot.Nested.Value).toBe(5)

		TransactionRules.Restore(live, snapshot)
		expect(live.Credits).toBe(100)
		expect(live.Nested.Value).toBe(5)

		live.Nested.Value = 12
		expect(snapshot.Nested.Value).toBe(5)
	end)

	it("does not leak draft mutations when a transaction declines commit", function()
		local live = {
			Credits = 100,
			Nested = { Value = 5 },
		}

		local executed, result = TransactionRules.Execute(live, function(draft)
			draft.Credits = 0
			draft.Nested.Value = 99
			return false, "NO_COMMIT"
		end, nil)

		expect(executed).toBe(true)
		expect(result).toBe("NO_COMMIT")
		expect(live.Credits).toBe(100)
		expect(live.Nested.Value).toBe(5)
	end)

	it("rolls back draft mutations when the transaction throws", function()
		local live = {
			Credits = 100,
		}

		local executed, result = TransactionRules.Execute(live, function(draft)
			draft.Credits = 0
			error("boom")
			return true, nil
		end, nil)

		expect(executed).toBe(false)
		expect(result).toBe("TRANSACTION_FAILED")
		expect(live.Credits).toBe(100)
	end)

	it("commits prepared draft contents without replacing the live root table", function()
		local live = {
			Revision = 7,
			Credits = 100,
		}
		local root = live

		local executed, result = TransactionRules.Execute(live, function(draft)
			draft.Credits = 75
			return true, "COMMITTED"
		end, function(draft)
			draft.Revision += 1
		end)

		expect(executed).toBe(true)
		expect(result).toBe("COMMITTED")
		expect(live == root).toBe(true)
		expect(live.Credits).toBe(75)
		expect(live.Revision).toBe(8)
	end)

	it("rolls back when prepare-commit validation throws", function()
		local live = {
			Credits = 100,
		}

		local executed, result = TransactionRules.Execute(live, function(draft)
			draft.Credits = 75
			return true, "SHOULD_NOT_COMMIT"
		end, function()
			error("sanitize failed")
		end)

		expect(executed).toBe(false)
		expect(result).toBe("TRANSACTION_FAILED")
		expect(live.Credits).toBe(100)
	end)
end)
