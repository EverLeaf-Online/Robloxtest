--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JestGlobals = require(ReplicatedStorage.DevPackages.JestGlobals)
local describe = JestGlobals.describe
local expect = JestGlobals.expect
local it = JestGlobals.it

local ReceiptRules = require(script.Parent.Parent.Domain.ReceiptRules)

describe("ReceiptRules", function()
	it("keeps valid ordered purchase ids", function()
		local normalized = ReceiptRules.NormalizeRecentPurchaseIds({ "A", "B", "C" }, 100, 128)

		expect(#normalized).toBe(3)
		expect(normalized[1]).toBe("A")
		expect(normalized[2]).toBe("B")
		expect(normalized[3]).toBe("C")
	end)

	it("keeps only the most recent duplicate occurrence", function()
		local normalized = ReceiptRules.NormalizeRecentPurchaseIds({ "A", "B", "A", "C" }, 100, 128)

		expect(#normalized).toBe(3)
		expect(normalized[1]).toBe("B")
		expect(normalized[2]).toBe("A")
		expect(normalized[3]).toBe("C")
	end)

	it("drops malformed and arbitrary keyed entries", function()
		local normalized = ReceiptRules.NormalizeRecentPurchaseIds({
			[1] = "A",
			[3] = "C",
			["junk"] = "SHOULD_DROP",
			[4] = "",
			[5] = 123,
		}, 100, 128)

		expect(#normalized).toBe(2)
		expect(normalized[1]).toBe("A")
		expect(normalized[2]).toBe("C")
	end)

	it("keeps only the newest bounded history", function()
		local normalized = ReceiptRules.NormalizeRecentPurchaseIds({ "A", "B", "C", "D" }, 2, 128)

		expect(#normalized).toBe(2)
		expect(normalized[1]).toBe("C")
		expect(normalized[2]).toBe("D")
	end)

	it("rejects overlong ids and malformed source tables", function()
		local normalized =
			ReceiptRules.NormalizeRecentPurchaseIds({ string.rep("x", 129), "OK" }, 100, 128)
		local malformed = ReceiptRules.NormalizeRecentPurchaseIds("bad", 100, 128)

		expect(#normalized).toBe(1)
		expect(normalized[1]).toBe("OK")
		expect(#malformed).toBe(0)
	end)
end)
