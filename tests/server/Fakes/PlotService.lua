--!strict

export type StationConfig = {
	BotConsole: BasePart?,
	RecycleStation: BasePart?,
	Assembler: BasePart?,
	Plot: Model?,
	ProcessorControls: { [string]: BasePart }?,
}

local PlotService = {}

local stationByPlayer: { [Player]: StationConfig } = {}
local refreshCountByPlayer: { [Player]: number } = {}

function PlotService.Reset()
	table.clear(stationByPlayer)
	table.clear(refreshCountByPlayer)
end

function PlotService.SetStations(player: Player, config: StationConfig)
	stationByPlayer[player] = config
end

function PlotService.GetRefreshCount(player: Player): number
	return refreshCountByPlayer[player] or 0
end

function PlotService.RefreshPresentation(player: Player)
	refreshCountByPlayer[player] = (refreshCountByPlayer[player] or 0) + 1
end

local function getConfig(player: Player): StationConfig?
	return stationByPlayer[player]
end

function PlotService.GetBotConsole(player: Player): BasePart?
	local config = getConfig(player)
	return if config ~= nil then config.BotConsole else nil
end

function PlotService.GetRecycleStation(player: Player): BasePart?
	local config = getConfig(player)
	return if config ~= nil then config.RecycleStation else nil
end

function PlotService.GetAssembler(player: Player): BasePart?
	local config = getConfig(player)
	return if config ~= nil then config.Assembler else nil
end

function PlotService.GetProcessorControl(player: Player, recipeId: string): BasePart?
	local config = getConfig(player)
	local controls = if config ~= nil then config.ProcessorControls else nil
	return if controls ~= nil then controls[recipeId] else nil
end

function PlotService.GetPlot(player: Player): Model?
	local config = getConfig(player)
	return if config ~= nil then config.Plot else nil
end

function PlotService.OwnsPart(_player: Player, _part: BasePart): boolean
	return true
end

return PlotService
