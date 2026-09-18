--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local WorldService = require(script.Parent.WorldService)

local PlotPresentationService = {}
local initialized = false

local function makePart(
	plot: Model,
	plotId: number,
	name: string,
	size: Vector3,
	position: Vector3,
	color: Color3,
	material: Enum.Material?
): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.Size = size
	part.Position = position
	part.Color = color
	part.Material = material or Enum.Material.Metal
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part:SetAttribute("PlotId", plotId)
	part.Parent = plot
	return part
end

local function addLabel(part: BasePart, text: string)
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "StationLabel"
	billboard.Adornee = part
	billboard.Size = UDim2.fromOffset(118, 26)
	billboard.StudsOffset = Vector3.new(0, part.Size.Y / 2 + 1.5, 0)
	billboard.MaxDistance = 30
	billboard.Parent = part

	local label = Instance.new("TextLabel")
	label.BackgroundColor3 = Color3.fromRGB(24, 27, 34)
	label.BackgroundTransparency = 0.15
	label.BorderSizePixel = 0
	label.Font = Enum.Font.GothamBold
	label.Size = UDim2.fromScale(1, 1)
	label.Text = text
	label.TextColor3 = Color3.fromRGB(245, 247, 250)
	label.TextScaled = true
	label.Parent = billboard

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = label
end

local function addUIPrompt(part: BasePart, panelName: string, objectText: string)
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = ("Open%sPrompt"):format(panelName)
	prompt.ActionText = "Open"
	prompt.ObjectText = objectText
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = GameConfig.World.PromptActivationDistance
	prompt.RequiresLineOfSight = false
	prompt:SetAttribute("LocalUIPanel", panelName)
	prompt.Parent = part
end

local function buildStorage(plot: Model, plotId: number, center: Vector3)
	local positions = {
		center + Vector3.new(-22, 1.75, 14),
		center + Vector3.new(-16, 1.75, 14),
		center + Vector3.new(-10, 1.75, 14),
	}
	for index, position in positions do
		local bin = makePart(
			plot,
			plotId,
			("StorageBin%d"):format(index),
			Vector3.new(5, 3.5, 5),
			position,
			Color3.fromRGB(76, 105, 128),
			Enum.Material.Metal
		)
		if index == 2 then
			addLabel(bin, "MATERIAL STORAGE")
			addUIPrompt(bin, "Storage", "Material Storage")
		end
	end
end

local function buildStations(plot: Model, plotId: number, center: Vector3)
	local recycle = makePart(
		plot,
		plotId,
		"RecycleStation",
		Vector3.new(7, 4, 5),
		center + Vector3.new(-2, 2.5, 14),
		Color3.fromRGB(130, 73, 73),
		Enum.Material.Metal
	)
	addLabel(recycle, "RECYCLE")
	addUIPrompt(recycle, "Recycle", "Recycle Bots")

	local indexTerminal = makePart(
		plot,
		plotId,
		"IndexTerminal",
		Vector3.new(5, 4, 4),
		center + Vector3.new(-12, 2.5, -10),
		Color3.fromRGB(63, 122, 132),
		Enum.Material.Metal
	)
	addLabel(indexTerminal, "ROBOT INDEX")
	addUIPrompt(indexTerminal, "Index", "Robot Index")

	local botConsole = makePart(
		plot,
		plotId,
		"BotConsole",
		Vector3.new(5, 4, 4),
		center + Vector3.new(-4, 2.5, -10),
		Color3.fromRGB(66, 104, 138),
		Enum.Material.Metal
	)
	addLabel(botConsole, "BOT CONTROL")
	addUIPrompt(botConsole, "Bots", "Bot Control")

	local upgradeConsole = makePart(
		plot,
		plotId,
		"UpgradeConsole",
		Vector3.new(5, 4, 4),
		center + Vector3.new(4, 2.5, -10),
		Color3.fromRGB(138, 112, 60),
		Enum.Material.Metal
	)
	addLabel(upgradeConsole, "UPGRADES")
	addUIPrompt(upgradeConsole, "Upgrades", "Factory Upgrades")
end

local function buildExpansionSockets(plot: Model, plotId: number, center: Vector3)
	for index, xOffset in { 15, 24 } do
		local socket = makePart(
			plot,
			plotId,
			("ExpansionSocket%d"):format(index),
			Vector3.new(7, 0.4, 7),
			center + Vector3.new(xOffset, 0.7, 14),
			Color3.fromRGB(60, 64, 73),
			Enum.Material.DiamondPlate
		)
		socket:SetAttribute("ReservedExpansion", true)
		if index == 1 then
			addLabel(socket, "FUTURE EXPANSION")
		end
	end
end

local function decoratePlot(plotId: number, plot: Model)
	if plot:FindFirstChild("PlotPresentation") ~= nil then
		return
	end

	local floor = plot:FindFirstChild("Floor")
	if floor == nil or not floor:IsA("BasePart") then
		warn(("[PlotPresentationService] Plot %d has no floor"):format(plotId))
		return
	end

	local marker = Instance.new("Folder")
	marker.Name = "PlotPresentation"
	marker.Parent = plot

	local center = floor.Position
	buildStorage(plot, plotId, center)
	buildStations(plot, plotId, center)
	buildExpansionSockets(plot, plotId, center)
end

function PlotPresentationService.Init()
	if initialized then
		return
	end
	initialized = true

	for plotId, plot in WorldService.GetPlots() do
		decoratePlot(plotId, plot)
	end
end

return PlotPresentationService
