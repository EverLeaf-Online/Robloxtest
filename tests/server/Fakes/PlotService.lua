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

function PlotService.Reset()
	table.clear(stationByPlayer)
end

function PlotService.SetStations(player: Player, config: StationConfig)
	stationByPlayer[player] = config
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
