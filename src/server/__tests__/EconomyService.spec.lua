--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local FactoryRules = require(ReplicatedStorage.Shared.Domain.FactoryRules)
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

	it("never lets paid material grants exceed the hard profile cap", function()
		local data = deepCopy(ProfileTemplate)
		data.Materials.ScrapMetal = 10_000_000
		expect(EconomyService.GrantPaidMaterials(data, { ScrapMetal = 1 })).toBe(false)
		expect(data.Materials.ScrapMetal).toBe(10_000_000)
	end)
end)
