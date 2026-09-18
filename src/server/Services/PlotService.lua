--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local FactoryRules = require(ReplicatedStorage.Shared.Domain.FactoryRules)
local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)

local DataService = require(script.Parent.DataService)
local FactorySessionService = require(script.Parent.FactorySessionService)
local WorldService = require(script.Parent.WorldService)

local PlotService = {}
local initialized = false
local plotByPlayer: { [Player]: number } = {}
local ownerByPlot: { [number]: Player } = {}

local function teleportToEntry(player: Player, plotId: number)
	local entry = WorldService.GetPlotEntry(plotId)
	local character = player.Character
	if entry == nil or character == nil then
		return
	end
	character:PivotTo(CFrame.new(entry.Position + Vector3.new(0, 4, 0)))
end

local function setPlotProgressionAttributes(plotId: number, player: Player?)
	local plot = WorldService.GetPlot(plotId)
	if plot == nil then
		return
	end

	local processorLevel = 1
	local assemblerLevel = 1
	local storageLevel = 1
	local workSlotsLevel = 1
	local unlockedZone = 1
	local extraWorkSlots = 0

	if player ~= nil then
		local data = DataService.GetData(player)
		if data ~= nil then
			processorLevel = data.Machines.ProcessorLevel
			assemblerLevel = data.Machines.AssemblerLevel
			storageLevel = data.Machines.StorageLevel
			workSlotsLevel = data.Machines.WorkSlotsLevel
			unlockedZone = data.Progression.Zone
		end
		extraWorkSlots = if player:GetAttribute("PassBotWorkSlots2") == true then 2 else 0
	end

	local unlockedWorkSlots = math.min(
		GameConfig.Factory.MaxWorkSlots + 2,
		FactoryRules.GetWorkSlots(workSlotsLevel) + extraWorkSlots
	)

	plot:SetAttribute("ProcessorLevel", processorLevel)
	plot:SetAttribute("AssemblerLevel", assemblerLevel)
	plot:SetAttribute("StorageLevel", storageLevel)
	plot:SetAttribute("WorkSlotsLevel", workSlotsLevel)
	plot:SetAttribute("UnlockedWorkSlots", unlockedWorkSlots)
	plot:SetAttribute("UnlockedZone", unlockedZone)
end

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
			then ("%s's Factory"):format(player.DisplayName)
			else "Private Factory"
	end
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
		setPlotProgressionAttributes(plotId, nil)
	end
end

local function getOwnedStation(player: Player, stationName: string): BasePart?
	local plot = PlotService.GetPlot(player)
	if plot == nil then
		return nil
	end
	local station = plot:FindFirstChild(stationName)
	return if station ~= nil and station:IsA("BasePart") then station else nil
end

function PlotService.Assign(player: Player): number?
	local existing = plotByPlayer[player]
	if existing ~= nil then
		return existing
	end

	-- Visitors can observe an owner's factory, but only the verified owner receives
	-- authoritative plot ownership and therefore gameplay interaction authority.
	if not FactorySessionService.IsOwner(player) then
		return nil
	end

	local plotId = 1
	local existingOwner = ownerByPlot[plotId]
	if existingOwner ~= nil and existingOwner ~= player then
		warn(
			("[PlotService] Factory owner collision: %d vs %d"):format(
				existingOwner.UserId,
				player.UserId
			)
		)
		return nil
	end

	plotByPlayer[player] = plotId
	ownerByPlot[plotId] = player
	setPlotLabel(plotId, player)
	setPlotProgressionAttributes(plotId, player)
	task.defer(teleportToEntry, player, plotId)
	return plotId
end

function PlotService.RefreshPresentation(player: Player)
	local plotId = plotByPlayer[player]
	if plotId ~= nil then
		setPlotProgressionAttributes(plotId, player)
	end
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

function PlotService.GetBotConsole(player: Player): BasePart?
	return getOwnedStation(player, "BotConsole")
end

function PlotService.GetStorageStation(player: Player): BasePart?
	return getOwnedStation(player, "StorageBin2")
end

function PlotService.GetRecycleStation(player: Player): BasePart?
	return getOwnedStation(player, "RecycleStation")
end

function PlotService.GetUpgradeConsole(player: Player): BasePart?
	return getOwnedStation(player, "UpgradeConsole")
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
	Players.PlayerAdded:Connect(function(player)
		player.CharacterAdded:Connect(function()
			task.defer(function()
				local plotId = plotByPlayer[player]
				if plotId ~= nil then
					teleportToEntry(player, plotId)
				end
			end)
		end)
	end)

	for _, player in Players:GetPlayers() do
		player.CharacterAdded:Connect(function()
			task.defer(function()
				local plotId = plotByPlayer[player]
				if plotId ~= nil then
					teleportToEntry(player, plotId)
				end
			end)
		end)
		if DataService.IsReady(player) then
			PlotService.Assign(player)
		end
	end
end

return PlotService
