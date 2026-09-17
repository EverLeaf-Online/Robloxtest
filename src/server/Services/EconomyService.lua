--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local FactoryRules = require(ReplicatedStorage.Shared.Domain.FactoryRules)
local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local Materials = require(ReplicatedStorage.Shared.Config.Materials)
local Recipes = require(ReplicatedStorage.Shared.Config.Recipes)

local EconomyService = {}

local function isValidAmount(amount: any): boolean
	return typeof(amount) == "number"
		and amount % 1 == 0
		and amount >= 0
		and amount <= GameConfig.Economy.MaxTransactionQuantity
end

local function totalAmounts(amounts: { [string]: number }): number
	local total = 0
	for _, amount in amounts do
		total += amount
	end
	return total
end

local function normalizeStorageMultiplier(multiplier: number?): number
	if
		typeof(multiplier) == "number"
		and multiplier == multiplier
		and multiplier >= 1
		and multiplier <= 10
		and multiplier < math.huge
	then
		return multiplier
	end
	return 1
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

function EconomyService.GetStorageCapacity(data: any, storageMultiplier: number?): number
	local capacity = FactoryRules.GetStorageCapacity(data.Machines.StorageLevel)
	capacity *= normalizeStorageMultiplier(storageMultiplier)
	return math.floor(capacity)
end

function EconomyService.GetReservedProcessorStorage(data: any): number
	local job = data.Machines.ProcessorJob
	if not job.Active then
		return 0
	end

	local recipe = Recipes.Processor[job.RecipeId]
	if recipe == nil or not EconomyService.ValidateMaterialAmounts(recipe.Output) then
		return 0
	end
	return totalAmounts(recipe.Output)
end

function EconomyService.CanAffordMaterials(data: any, cost: { [string]: number }): boolean
	return EconomyService.ValidateMaterialAmounts(cost)
		and FactoryRules.CanAfford(data.Materials, cost)
end

function EconomyService.CanFitTransaction(
	data: any,
	cost: { [string]: number },
	output: { [string]: number },
	storageMultiplier: number?
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
		EconomyService.GetStorageCapacity(data, storageMultiplier)
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

function EconomyService.GrantPaidMaterials(data: any, amounts: { [string]: number }): boolean
	if not EconomyService.ValidateMaterialAmounts(amounts) then
		return false
	end

	for materialId, amount in amounts do
		local current = data.Materials[materialId]
		if current > GameConfig.Economy.MaxMaterialCount - amount then
			return false
		end
	end

	-- Paid grants may exceed normal storage capacity, but never the hard profile cap.
	-- Normal collection/processing remains capacity-gated until the player spends below capacity.
	for materialId, amount in amounts do
		data.Materials[materialId] += amount
	end
	return true
end

function EconomyService.GrantMaterials(
	data: any,
	amounts: { [string]: number },
	storageMultiplier: number?
): boolean
	if not EconomyService.ValidateMaterialAmounts(amounts) then
		return false
	end

	local reserved = EconomyService.GetReservedProcessorStorage(data)
	local currentTotal = FactoryRules.TotalMaterials(data.Materials)
	local added = totalAmounts(amounts)
	if
		not FactoryRules.CanGrantWithReservation(
			currentTotal,
			added,
			EconomyService.GetStorageCapacity(data, storageMultiplier),
			reserved
		)
	then
		return false
	end

	for materialId, amount in amounts do
		data.Materials[materialId] += amount
	end
	return true
end

function EconomyService.GrantProcessorOutput(
	data: any,
	amounts: { [string]: number },
	storageMultiplier: number?
): boolean
	if not EconomyService.ValidateMaterialAmounts(amounts) then
		return false
	end

	local reserved = EconomyService.GetReservedProcessorStorage(data)
	local currentTotal = FactoryRules.TotalMaterials(data.Materials)
	local added = totalAmounts(amounts)
	if
		not FactoryRules.CanCompleteReservedOutput(
			currentTotal,
			added,
			EconomyService.GetStorageCapacity(data, storageMultiplier),
			reserved
		)
	then
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

function EconomyService.CanGrantCreditsExact(data: any, amount: number): boolean
	return isValidAmount(amount)
		and amount > 0
		and data.Currencies.Credits <= GameConfig.Economy.MaxCredits - amount
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

function EconomyService.GrantCreditsExact(data: any, amount: number): boolean
	if not EconomyService.CanGrantCreditsExact(data, amount) then
		return false
	end

	local granted = EconomyService.GrantCredits(data, amount)
	assert(granted == amount, "validated exact credit grant must not truncate")
	return true
end

return table.freeze(EconomyService)
