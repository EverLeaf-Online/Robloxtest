--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local Recipes = require(ReplicatedStorage.Shared.Config.Recipes)
local Robots = require(ReplicatedStorage.Shared.Config.Robots)
local Upgrades = require(ReplicatedStorage.Shared.Config.Upgrades)

local FactoryRules = {}

local function getUpgradeLevel(upgradeId: string, level: number): any?
	local definition = Upgrades[upgradeId]
	if definition == nil then
		return nil
	end
	return definition.Levels[level]
end

function FactoryRules.NormalizeUpgradeLevel(upgradeId: string, value: any): number
	local definition = Upgrades[upgradeId]
	if definition == nil or #definition.Levels == 0 then
		return 1
	end
	if
		typeof(value) ~= "number"
		or value ~= value
		or value == math.huge
		or value == -math.huge
		or value % 1 ~= 0
	then
		return 1
	end
	return math.clamp(value, 1, #definition.Levels)
end

function FactoryRules.GetProcessorSeconds(level: number): number
	local upgradeLevel = getUpgradeLevel("ProcessorSpeed", level)
	return if upgradeLevel then upgradeLevel.Value else Upgrades.ProcessorSpeed.Levels[1].Value
end

function FactoryRules.GetAssemblerSeconds(level: number): number
	local upgradeLevel = getUpgradeLevel("AssemblerSpeed", level)
	return if upgradeLevel then upgradeLevel.Value else Upgrades.AssemblerSpeed.Levels[1].Value
end

function FactoryRules.GetAssemblerDuration(level: number, timeMultiplier: number): number
	local multiplier = if typeof(timeMultiplier) == "number"
			and timeMultiplier == timeMultiplier
			and timeMultiplier > 0
			and timeMultiplier < math.huge
		then timeMultiplier
		else 1
	return math.max(0.001, FactoryRules.GetAssemblerSeconds(level) * multiplier)
end

function FactoryRules.GetStorageCapacity(level: number): number
	local upgradeLevel = getUpgradeLevel("Storage", level)
	return if upgradeLevel then upgradeLevel.Value else Upgrades.Storage.Levels[1].Value
end

function FactoryRules.GetWorkSlots(level: number): number
	local upgradeLevel = getUpgradeLevel("WorkSlots", level)
	local value = if upgradeLevel then upgradeLevel.Value else GameConfig.Factory.BaseWorkSlots
	return math.clamp(
		math.floor(value),
		GameConfig.Factory.BaseWorkSlots,
		GameConfig.Factory.MaxWorkSlots
	)
end

function FactoryRules.CanStartAssembler(
	lifetimeRobotsBuilt: number,
	firstProcessCompleted: boolean
): (boolean, string)
	if lifetimeRobotsBuilt <= 0 and not firstProcessCompleted then
		return false, "PROCESS_FIRST"
	end
	return true, "ASSEMBLER_READY"
end

function FactoryRules.GetAssemblerCost(lifetimeRobotsBuilt: number): { [string]: number }
	return if lifetimeRobotsBuilt <= 0
		then Recipes.Assembler.FirstBuildInput
		else Recipes.Assembler.StandardInput
end

function FactoryRules.TotalMaterials(materials: { [string]: number }): number
	local total = 0
	for _, amount in materials do
		if typeof(amount) == "number" and amount > 0 then
			total += amount
		end
	end
	return total
end

function FactoryRules.CanAfford(
	materials: { [string]: number },
	cost: { [string]: number }
): boolean
	for materialId, amount in cost do
		local owned = materials[materialId] or 0
		if amount < 0 or owned < amount then
			return false
		end
	end
	return true
end

function FactoryRules.CanFitTransaction(
	materials: { [string]: number },
	cost: { [string]: number },
	output: { [string]: number },
	storageCapacity: number
): boolean
	if not FactoryRules.CanAfford(materials, cost) then
		return false
	end

	local projected = FactoryRules.TotalMaterials(materials)
	for _, amount in cost do
		projected -= amount
	end
	for _, amount in output do
		projected += amount
	end

	return projected >= 0 and projected <= storageCapacity
end

function FactoryRules.CanGrantWithReservation(
	currentTotal: number,
	added: number,
	storageCapacity: number,
	reserved: number
): boolean
	if currentTotal < 0 or added < 0 or storageCapacity < 0 or reserved < 0 then
		return false
	end
	local usableCapacity = math.max(0, storageCapacity - reserved)
	return currentTotal + added <= usableCapacity
end

function FactoryRules.CanCompleteReservedOutput(
	currentTotal: number,
	added: number,
	storageCapacity: number,
	reserved: number
): boolean
	if currentTotal < 0 or added < 0 or storageCapacity < 0 or reserved <= 0 then
		return false
	end
	if added > reserved then
		return false
	end
	return currentTotal + added <= storageCapacity + reserved
end

local function getRollIds(firstBuild: boolean): { string }
	if firstBuild then
		return table.clone(Robots.FirstRevealPool)
	end

	local ids = {}
	for robotId in Robots.Definitions do
		table.insert(ids, robotId)
	end
	table.sort(ids)
	return ids
end

function FactoryRules.RollRobot(unitRoll: number, firstBuild: boolean): string
	local ids = getRollIds(firstBuild)
	assert(#ids > 0, "Robot roll pool must not be empty")

	local totalWeight = 0
	for _, robotId in ids do
		totalWeight += Robots.Definitions[robotId].Weight
	end
	assert(totalWeight > 0, "Robot roll pool must have positive total weight")

	local clampedRoll = math.clamp(unitRoll, 0, 0.999999999)
	local threshold = clampedRoll * totalWeight
	local cumulative = 0

	for _, robotId in ids do
		cumulative += Robots.Definitions[robotId].Weight
		if threshold < cumulative then
			return robotId
		end
	end

	return ids[#ids]
end

function FactoryRules.GetNextUpgrade(upgradeId: string, currentLevel: number): any?
	local definition = Upgrades[upgradeId]
	if definition == nil then
		return nil
	end
	return definition.Levels[currentLevel + 1]
end

return table.freeze(FactoryRules)
