--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local FactoryRules = require(ReplicatedStorage.Shared.Domain.FactoryRules)
local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local Materials = require(ReplicatedStorage.Shared.Config.Materials)

local EconomyService = {}

local function isValidAmount(amount: any): boolean
	return typeof(amount) == "number"
		and amount % 1 == 0
		and amount >= 0
		and amount <= GameConfig.Economy.MaxTransactionQuantity
end

function EconomyService.ValidateMaterialAmounts(amounts: any): boolean
	if typeof(amounts) ~= "table" then
		return false
	end

	for materialId, amount in amounts do
		if Materials[materialId] == nil or not isValidAmount(amount) then
			return false
		end
	end
	return true
end

function EconomyService.GetStorageCapacity(data: any): number
	return FactoryRules.GetStorageCapacity(data.Machines.StorageLevel)
end

function EconomyService.CanAffordMaterials(data: any, cost: { [string]: number }): boolean
	return EconomyService.ValidateMaterialAmounts(cost)
		and FactoryRules.CanAfford(data.Materials, cost)
end

function EconomyService.CanFitTransaction(
	data: any,
	cost: { [string]: number },
	output: { [string]: number }
): boolean
	if
		not EconomyService.ValidateMaterialAmounts(cost)
		or not EconomyService.ValidateMaterialAmounts(output)
	then
		return false
	end

	return FactoryRules.CanFitTransaction(
		data.Materials,
		cost,
		output,
		EconomyService.GetStorageCapacity(data)
	)
end

function EconomyService.SpendMaterials(data: any, cost: { [string]: number }): boolean
	if not EconomyService.CanAffordMaterials(data, cost) then
		return false
	end

	for materialId, amount in cost do
		data.Materials[materialId] -= amount
	end
	return true
end

function EconomyService.GrantMaterials(data: any, amounts: { [string]: number }): boolean
	if not EconomyService.ValidateMaterialAmounts(amounts) then
		return false
	end

	local capacity = EconomyService.GetStorageCapacity(data)
	local total = FactoryRules.TotalMaterials(data.Materials)
	local added = 0
	for _, amount in amounts do
		added += amount
	end
	if total + added > capacity then
		return false
	end

	for materialId, amount in amounts do
		data.Materials[materialId] += amount
	end
	return true
end

function EconomyService.SpendCredits(data: any, amount: number): boolean
	if not isValidAmount(amount) or data.Currencies.Credits < amount then
		return false
	end
	data.Currencies.Credits -= amount
	return true
end

function EconomyService.GrantCredits(data: any, amount: number): number
	if not isValidAmount(amount) or amount == 0 then
		return 0
	end

	local room = GameConfig.Economy.MaxCredits - data.Currencies.Credits
	local granted = math.max(0, math.min(room, amount))
	data.Currencies.Credits += granted
	data.Stats.LifetimeCredits =
		math.min(GameConfig.Economy.MaxCredits, data.Stats.LifetimeCredits + granted)
	return granted
end

return table.freeze(EconomyService)
