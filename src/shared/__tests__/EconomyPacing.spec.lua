--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JestGlobals = require(ReplicatedStorage.DevPackages.JestGlobals)
local describe = JestGlobals.describe
local expect = JestGlobals.expect
local it = JestGlobals.it

local Recipes = require(script.Parent.Parent.Config.Recipes)
local Robots = require(script.Parent.Parent.Config.Robots)
local Salvage = require(script.Parent.Parent.Config.Salvage)
local Upgrades = require(script.Parent.Parent.Config.Upgrades)
local Zones = require(script.Parent.Parent.Config.Zones)

local function minimumFirstRevealProduction(): number
	local minimum = math.huge
	for _, robotId in Robots.FirstRevealPool do
		minimum = math.min(minimum, Robots.Definitions[robotId].ProductionPerSecond)
	end
	return minimum
end

local function minimumRobotProduction(): number
	local minimum = math.huge
	for _, definition in Robots.Definitions do
		minimum = math.min(minimum, definition.ProductionPerSecond)
	end
	return minimum
end

describe("first-session economy pacing", function()
	it("guarantees the first salvage claim can start the tutorial processor path", function()
		local guaranteedScrap = Zones[1].Salvage.ScrapMin
			+ (Salvage.FirstCollectBonus.ScrapMetal or 0)
		local wiringInput = Recipes.Processor.MakeWiring.Input.ScrapMetal or 0

		expect(guaranteedScrap >= wiringInput).toBe(true)
	end)

	it(
		"keeps a first meaningful upgrade within two minutes of assigning even the slowest first bot",
		function()
			local firstUpgradeCost = math.min(
				Upgrades.ProcessorSpeed.Levels[2].CostCredits,
				Upgrades.AssemblerSpeed.Levels[2].CostCredits,
				Upgrades.Storage.Levels[2].CostCredits,
				Upgrades.WorkSlots.Levels[2].CostCredits
			)
			local slowestFirstBot = minimumFirstRevealProduction()
			local secondsToFirstUpgrade = firstUpgradeCost / slowestFirstBot

			expect(secondsToFirstUpgrade <= 120).toBe(true)
		end
	)

	it(
		"keeps the conservative two-slot path to Circuit Yard inside the 30-minute target",
		function()
			local workSlotCost = Upgrades.WorkSlots.Levels[2].CostCredits
			local slowestFirstBot = minimumFirstRevealProduction()
			local slowestBot = minimumRobotProduction()
			local zoneTwo = Zones[2]

			local secondsToSecondSlot = workSlotCost / slowestFirstBot
			local twoBotRate = slowestFirstBot + slowestBot
			local secondsToZoneCredits = zoneTwo.UnlockCredits / twoBotRate
			local totalSeconds = secondsToSecondSlot + secondsToZoneCredits

			expect(zoneTwo.RequiredLifetimeRobots <= 3).toBe(true)
			expect(totalSeconds <= 30 * 60).toBe(true)
		end
	)
end)
