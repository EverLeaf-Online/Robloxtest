--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JestGlobals = require(ReplicatedStorage.DevPackages.JestGlobals)
local describe = JestGlobals.describe
local expect = JestGlobals.expect
local it = JestGlobals.it

local FactoryRules = require(script.Parent.Parent.Domain.FactoryRules)
local Robots = require(script.Parent.Parent.Config.Robots)

describe("FactoryRules", function()
	it("uses cheaper first-build assembler cost", function()
		local firstCost = FactoryRules.GetAssemblerCost(0)
		local repeatCost = FactoryRules.GetAssemblerCost(1)

		expect(firstCost.ScrapMetal).toBe(4)
		expect(firstCost.Wiring).toBe(1)
		expect(firstCost.PowerCoreFragments).toBe(nil)
		expect(repeatCost.PowerCoreFragments).toBe(1)
	end)

	it("validates material affordability", function()
		local materials = {
			ScrapMetal = 10,
			Wiring = 2,
			PowerCoreFragments = 0,
		}

		expect(FactoryRules.CanAfford(materials, { ScrapMetal = 4, Wiring = 2 })).toBe(true)
		expect(FactoryRules.CanAfford(materials, { PowerCoreFragments = 1 })).toBe(false)
	end)

	it("accounts for spent inputs before storage outputs", function()
		local materials = {
			ScrapMetal = 49,
			Wiring = 1,
			PowerCoreFragments = 0,
		}

		expect(FactoryRules.CanFitTransaction(materials, { ScrapMetal = 4 }, { Wiring = 4 }, 50)).toBe(
			true
		)
		expect(FactoryRules.CanFitTransaction(materials, {}, { Wiring = 1 }, 50)).toBe(false)
	end)

	it("rejects transactions that would exceed storage", function()
		local materials = {
			ScrapMetal = 49,
			Wiring = 0,
			PowerCoreFragments = 0,
		}

		expect(FactoryRules.CanFitTransaction(materials, {}, { Wiring = 1 }, 50)).toBe(true)
		expect(FactoryRules.CanFitTransaction(materials, {}, { Wiring = 2 }, 50)).toBe(false)
	end)

	it("caps work slots to configured progression", function()
		expect(FactoryRules.GetWorkSlots(1)).toBe(1)
		expect(FactoryRules.GetWorkSlots(4)).toBe(4)
		expect(FactoryRules.GetWorkSlots(999)).toBe(1)
	end)

	it("returns the next upgrade and stops at max level", function()
		local nextStorage = FactoryRules.GetNextUpgrade("Storage", 1)
		local maxStorage = FactoryRules.GetNextUpgrade("Storage", 4)
		local unknown = FactoryRules.GetNextUpgrade("MissingUpgrade", 1)

		expect(nextStorage ~= nil).toBe(true)
		expect(nextStorage.CostCredits > 0).toBe(true)
		expect(maxStorage).toBe(nil)
		expect(unknown).toBe(nil)
	end)

	it("keeps first robot reveals inside the onboarding pool", function()
		local lowRoll = FactoryRules.RollRobot(0, true)
		local highRoll = FactoryRules.RollRobot(0.999999, true)

		expect(table.find(Robots.FirstRevealPool, lowRoll) ~= nil).toBe(true)
		expect(table.find(Robots.FirstRevealPool, highRoll) ~= nil).toBe(true)
	end)

	it("clamps out-of-range robot rolls to valid outcomes", function()
		local lowRoll = FactoryRules.RollRobot(-100, false)
		local highRoll = FactoryRules.RollRobot(100, false)

		expect(Robots.Definitions[lowRoll] ~= nil).toBe(true)
		expect(Robots.Definitions[highRoll] ~= nil).toBe(true)
	end)

	it("returns a known robot for standard rolls", function()
		local robotId = FactoryRules.RollRobot(0.5, false)
		expect(Robots.Definitions[robotId] ~= nil).toBe(true)
	end)
end)
