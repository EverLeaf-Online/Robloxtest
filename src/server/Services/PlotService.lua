--!strict

local Players = game:GetService("Players")

local DataService = require(script.Parent.DataService)
local WorldService = require(script.Parent.WorldService)

local PlotService = {}
local initialized = false
local plotByPlayer: { [Player]: number } = {}
local ownerByPlot: { [number]: Player } = {}

local function setPlotLabel(plotId: number, player: Player?)
	local sign = WorldService.GetPlotSign(plotId)
	local plot = WorldService.GetPlot(plotId)
	if sign == nil or plot == nil then
		return
	end

	if player == nil then
		plot:SetAttribute("OwnerUserId", 0)
		plot:SetAttribute("OwnerName", "")
	else
		plot:SetAttribute("OwnerUserId", player.UserId)
		plot:SetAttribute("OwnerName", player.DisplayName)
	end

	local label = sign:FindFirstChild("OwnerLabel", true)
	if label ~= nil and label:IsA("TextLabel") then
		label.Text = if player
			then ("%s's Factory\nPlot %d"):format(player.DisplayName, plotId)
			else ("Factory Plot %d\nUnclaimed"):format(plotId)
	end
end

local function firstFreePlot(): number?
	for plotId = 1, #WorldService.GetPlots() do
		if ownerByPlot[plotId] == nil then
			return plotId
		end
	end
	return nil
end

local function release(player: Player)
	local plotId = plotByPlayer[player]
	if plotId == nil then
		return
	end

	plotByPlayer[player] = nil
	if ownerByPlot[plotId] == player then
		ownerByPlot[plotId] = nil
		setPlotLabel(plotId, nil)
	end
end

function PlotService.Assign(player: Player): number?
	local existing = plotByPlayer[player]
	if existing ~= nil then
		return existing
	end

	local plotId = firstFreePlot()
	if plotId == nil then
		warn(("[PlotService] No free factory plot for %d"):format(player.UserId))
		return nil
	end

	plotByPlayer[player] = plotId
	ownerByPlot[plotId] = player
	setPlotLabel(plotId, player)
	return plotId
end

function PlotService.GetPlotId(player: Player): number?
	return plotByPlayer[player]
end

function PlotService.GetPlot(player: Player): Model?
	local plotId = plotByPlayer[player]
	return if plotId then WorldService.GetPlot(plotId) else nil
end

function PlotService.OwnsPart(player: Player, instance: Instance): boolean
	local ownedPlotId = plotByPlayer[player]
	if ownedPlotId == nil then
		return false
	end
	return WorldService.GetPlotIdForInstance(instance) == ownedPlotId
end

function PlotService.GetProcessorControl(player: Player, recipeId: string): BasePart?
	local plotId = plotByPlayer[player]
	return if plotId then WorldService.GetPlotProcessorControl(plotId, recipeId) else nil
end

function PlotService.GetAssembler(player: Player): BasePart?
	local plotId = plotByPlayer[player]
	return if plotId then WorldService.GetPlotAssembler(plotId) else nil
end

function PlotService.GetWorkPad(player: Player, padId: string): BasePart?
	local plotId = plotByPlayer[player]
	return if plotId then WorldService.GetPlotWorkPad(plotId, padId) else nil
end

function PlotService.GetEntry(player: Player): BasePart?
	local plotId = plotByPlayer[player]
	return if plotId then WorldService.GetPlotEntry(plotId) else nil
end

function PlotService.Init()
	if initialized then
		return
	end
	initialized = true

	for plotId in WorldService.GetPlots() do
		setPlotLabel(plotId, nil)
	end

	DataService.ProfileLoaded:Connect(function(player)
		PlotService.Assign(player)
	end)
	DataService.ProfileReleased:Connect(function(player)
		release(player)
	end)
	Players.PlayerRemoving:Connect(function(player)
		release(player)
	end)

	for _, player in Players:GetPlayers() do
		if DataService.IsReady(player) then
			PlotService.Assign(player)
		end
	end
end

return PlotService
