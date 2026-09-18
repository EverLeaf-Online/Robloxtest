--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JestGlobals = require(ReplicatedStorage.DevPackages.JestGlobals)
local describe = JestGlobals.describe
local expect = JestGlobals.expect
local it = JestGlobals.it

local SalvageAccessRules = require(script.Parent.Parent.Domain.SalvageAccessRules)

describe("SalvageAccessRules", function()
	it("allows the owner to collect from private salvage", function()
		local allowed, code = SalvageAccessRules.Evaluate(3, 3, 1, 1)
		expect(allowed).toBe(true)
		expect(code).toBe("SALVAGE_ALLOWED")
	end)

	it("rejects another player's private salvage", function()
		local allowed, code = SalvageAccessRules.Evaluate(2, 3, 2, 1)
		expect(allowed).toBe(false)
		expect(code).toBe("NOT_YOUR_PLOT")
	end)

	it("rejects private salvage when the player has no plot", function()
		local allowed, code = SalvageAccessRules.Evaluate(nil, 1, 2, 1)
		expect(allowed).toBe(false)
		expect(code).toBe("NOT_YOUR_PLOT")
	end)

	it("keeps advanced private salvage zone-gated", function()
		local allowed, code = SalvageAccessRules.Evaluate(4, 4, 1, 2)
		expect(allowed).toBe(false)
		expect(code).toBe("ZONE_LOCKED")
	end)

	it("still supports explicitly shared salvage nodes", function()
		local allowed, code = SalvageAccessRules.Evaluate(4, nil, 2, 2)
		expect(allowed).toBe(true)
		expect(code).toBe("SALVAGE_ALLOWED")
	end)
end)
