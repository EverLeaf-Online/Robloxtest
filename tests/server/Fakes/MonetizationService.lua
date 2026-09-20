--!strict

local MonetizationService = {}

local extraWorkSlotsByPlayer: { [Player]: number } = {}
local storageMultiplierByPlayer: { [Player]: number } = {}
local assemblerMultiplierByPlayer: { [Player]: number } = {}
local refreshCountByPlayer: { [Player]: number } = {}
local autoCollectByPlayer: { [Player]: boolean } = {}

function MonetizationService.Reset()
	table.clear(extraWorkSlotsByPlayer)
	table.clear(storageMultiplierByPlayer)
	table.clear(assemblerMultiplierByPlayer)
	table.clear(refreshCountByPlayer)
	table.clear(autoCollectByPlayer)
end

function MonetizationService.SetExtraWorkSlots(player: Player, value: number)
	extraWorkSlotsByPlayer[player] = value
end

function MonetizationService.SetStorageMultiplier(player: Player, value: number)
	storageMultiplierByPlayer[player] = value
end

function MonetizationService.SetAssemblerTimeMultiplier(player: Player, value: number)
	assemblerMultiplierByPlayer[player] = value
end

function MonetizationService.GetExtraWorkSlots(player: Player): number
	return extraWorkSlotsByPlayer[player] or 0
end

function MonetizationService.GetStorageMultiplier(player: Player): number
	return storageMultiplierByPlayer[player] or 1
end

function MonetizationService.GetAssemblerTimeMultiplier(player: Player): number
	return assemblerMultiplierByPlayer[player] or 1
end

function MonetizationService.SetAutoCollect(player: Player, enabled: boolean)
	autoCollectByPlayer[player] = enabled
end

function MonetizationService.HasAutoCollect(player: Player): boolean
	return autoCollectByPlayer[player] == true
end

function MonetizationService.RefreshPlayer(player: Player)
	refreshCountByPlayer[player] = (refreshCountByPlayer[player] or 0) + 1
end

function MonetizationService.GetRefreshCount(player: Player): number
	return refreshCountByPlayer[player] or 0
end

return MonetizationService
