--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JestGlobals = require(ReplicatedStorage.DevPackages.JestGlobals)
local expect = JestGlobals.expect
local it = JestGlobals.it

local RecipeDisplay = require(script.Parent.Parent.Domain.RecipeDisplay)

it("formats recipe materials in deterministic player-facing order", function()
	expect(RecipeDisplay.FormatMaterials({
		PowerCoreFragments = 1,
		Wiring = 2,
		ScrapMetal = 6,
	})).toBe("6 Scrap + 2 Wiring + 1 Core")
end)

it("omits zero values", function()
	expect(RecipeDisplay.FormatMaterials({
		ScrapMetal = 4,
		Wiring = 0,
	})).toBe("4 Scrap")
end)
