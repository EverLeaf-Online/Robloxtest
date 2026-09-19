--!strict

export type StationConfig = {
	BotConsole: BasePart?,
	RecycleStation: BasePart?,
	Assembler: BasePart?,
	UpgradeConsole: BasePart?,
	StorageStation: BasePart?,
	Plot: Model?,
	PlotId: number?,
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

function PlotService.SetPlotId(player: Player, plotId: number?)
	local config = stationByPlayer[player]
	if config == nil then
		config = {}
		stationByPlayer[player] = config
	end
	config.PlotId = plotId
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

function PlotService.GetPlotId(player: Player): number?
	local config = getConfig(player)
	return if config ~= nil then config.PlotId else nil
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

function PlotService.GetUpgradeConsole(player: Player): BasePart?
	local config = getConfig(player)
	return if config ~= nil then config.UpgradeConsole else nil
end

function PlotService.GetStorageStation(player: Player): BasePart?
	local config = getConfig(player)
	return if config ~= nil then config.StorageStation else nil
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

function PlotService.OwnsPart(player: Player, part: BasePart): boolean
	local plotId = PlotService.GetPlotId(player)
	return plotId ~= nil and part:GetAttribute("PlotId") == plotId
end

return PlotService
