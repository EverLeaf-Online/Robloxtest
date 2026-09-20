--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JestGlobals = require(ReplicatedStorage.DevPackages.JestGlobals)
local describe = JestGlobals.describe
local expect = JestGlobals.expect
local it = JestGlobals.it

local FactoryRules = require(ReplicatedStorage.Shared.Domain.FactoryRules)
local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local TransactionRules = require(ReplicatedStorage.Shared.Domain.TransactionRules)

local serverRoot = script.Parent.Parent
local ProfileTemplate = require(serverRoot.Data.ProfileTemplate)
local EconomyService = require(serverRoot.Services.EconomyService)

local function deepCopy(value: any): any
	if typeof(value) ~= "table" then
		return value
	end
	local result = {}
	for key, nested in value do
		result[deepCopy(key)] = deepCopy(nested)
	end
	return result
end

describe("EconomyService", function()
	it("applies storage multipliers inside isolated transaction drafts", function()
		local data = deepCopy(ProfileTemplate)
		local baseCapacity = FactoryRules.GetStorageCapacity(data.Machines.StorageLevel)
		local executed, capacity = TransactionRules.Execute(data, function(draft)
			return true, EconomyService.GetStorageCapacity(draft, 1.10)
		end)
		expect(executed).toBe(true)
		expect(capacity).toBe(math.floor(baseCapacity * 1.10))
	end)

	it("uses the explicit multiplier when capacity-checking transaction output", function()
		local data = deepCopy(ProfileTemplate)
		local baseCapacity = FactoryRules.GetStorageCapacity(data.Machines.StorageLevel)
		data.Materials.ScrapMetal = baseCapacity

		local withoutClub = EconomyService.CanFitTransaction(
			data,
			{},
			{ Wiring = math.max(1, math.floor(baseCapacity * 0.05)) },
			1
		)
		local withClub = EconomyService.CanFitTransaction(
			data,
			{},
			{ Wiring = math.max(1, math.floor(baseCapacity * 0.05)) },
			1.10
		)
		expect(withoutClub).toBe(false)
		expect(withClub).toBe(true)
	end)

	it("honors the exact Factory Club storage boundary without overflowing", function()
		local data = deepCopy(ProfileTemplate)
		local baseCapacity = FactoryRules.GetStorageCapacity(data.Machines.StorageLevel)
		local clubMultiplier = GameConfig.Factory.FactoryClubStorageMultiplier
		local clubCapacity = math.floor(baseCapacity * clubMultiplier)

		data.Materials.ScrapMetal = clubCapacity - 1

		expect(EconomyService.GrantMaterials(data, { Wiring = 1 }, clubMultiplier)).toBe(true)
		expect(FactoryRules.TotalMaterials(data.Materials)).toBe(clubCapacity)

		local before = deepCopy(data.Materials)
		expect(EconomyService.GrantMaterials(data, { PowerCoreFragments = 1 }, clubMultiplier)).toBe(
			false
		)
		expect(data.Materials).toEqual(before)
	end)

	it("stacks Expanded Storage and Factory Club capacity deterministically", function()
		local data = deepCopy(ProfileTemplate)
		local baseCapacity = FactoryRules.GetStorageCapacity(data.Machines.StorageLevel)
		local stackedMultiplier = 2 * GameConfig.Factory.FactoryClubStorageMultiplier

		expect(EconomyService.GetStorageCapacity(data, stackedMultiplier)).toBe(
			math.floor(baseCapacity * stackedMultiplier)
		)
	end)

	it("never lets paid material grants exceed the hard profile cap", function()
		local data = deepCopy(ProfileTemplate)
		data.Materials.ScrapMetal = GameConfig.Economy.MaxMaterialCount
		expect(EconomyService.GrantPaidMaterials(data, { ScrapMetal = 1 })).toBe(false)
		expect(data.Materials.ScrapMetal).toBe(GameConfig.Economy.MaxMaterialCount)
	end)
end)
