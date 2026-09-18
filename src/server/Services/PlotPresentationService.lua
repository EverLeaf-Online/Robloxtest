--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local WorldLayout = require(ReplicatedStorage.Shared.Config.WorldLayout)
local NativeAssetBuilder = require(script.Parent.Parent.Presentation.NativeAssetBuilder)
local WorldService = require(script.Parent.WorldService)

local PlotPresentationService = {}
local initialized = false

local COLORS = NativeAssetBuilder.GetColors()

local function makeAnchor(
	plot: Model,
	plotId: number,
	name: string,
	size: Vector3,
	position: Vector3
): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.Size = size
	part.Position = position
	part.Transparency = 1
	part.Material = Enum.Material.SmoothPlastic
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part:SetAttribute("PlotId", plotId)
	part.Parent = plot
	return part
end

local function makeDecoration(
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
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.Size = size
	part.Position = position
	part.Color = color
	part.Material = material or Enum.Material.Metal
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part:SetAttribute("PlotId", plotId)
	part:SetAttribute("PresentationPart", true)
	part.Parent = plot
	return part
end

local function addLabel(part: BasePart, text: string)
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "StationLabel"
	billboard.Adornee = part
	billboard.Size = UDim2.fromOffset(136, 30)
	billboard.StudsOffset = Vector3.new(0, part.Size.Y / 2 + 2, 0)
	billboard.MaxDistance = 38
	billboard.Parent = part

	local label = Instance.new("TextLabel")
	label.Name = "Label"
	label.BackgroundColor3 = Color3.fromRGB(24, 27, 34)
	label.BackgroundTransparency = 0.12
	label.BorderSizePixel = 0
	label.Font = Enum.Font.GothamBold
	label.Size = UDim2.fromScale(1, 1)
	label.Text = text
	label.TextColor3 = Color3.fromRGB(245, 247, 250)
	label.TextScaled = true
	label.Parent = billboard

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 7)
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

local function buildPerimeterPresentation(plot: Model, plotId: number, center: Vector3)
	local halfX = WorldLayout.Plot.Size.X / 2
	local halfZ = WorldLayout.Plot.Size.Z / 2
	local railColor = Color3.fromRGB(72, 82, 92)
	local postColor = Color3.fromRGB(92, 104, 116)

	local function rail(name: string, size: Vector3, position: Vector3)
		makeDecoration(plot, plotId, name, size, position, railColor, Enum.Material.Metal)
	end

	local function post(name: string, position: Vector3)
		makeDecoration(
			plot,
			plotId,
			name,
			Vector3.new(0.9, 5.4, 0.9),
			position + Vector3.new(0, 3.1, 0),
			postColor,
			Enum.Material.Metal
		)
	end

	for level, y in { 2.1, 4.5 } do
		rail(
			("NorthRail%d"):format(level),
			Vector3.new(WorldLayout.Plot.Size.X - 6, 0.38, 0.38),
			center + Vector3.new(0, y, halfZ - 2)
		)
		for _, side in { -1, 1 } do
			rail(
				("SideRail%d_%d"):format(if side < 0 then 1 else 2, level),
				Vector3.new(0.38, 0.38, WorldLayout.Plot.Size.Z - 6),
				center + Vector3.new(side * (halfX - 2), y, 0)
			)
			rail(
				("SouthRail%d_%d"):format(if side < 0 then 1 else 2, level),
				Vector3.new(96, 0.38, 0.38),
				center + Vector3.new(side * 70, y, -(halfZ - 2))
			)
		end
	end

	for index, offset in
		{
			Vector3.new(-(halfX - 2), 0, -(halfZ - 2)),
			Vector3.new(halfX - 2, 0, -(halfZ - 2)),
			Vector3.new(-(halfX - 2), 0, halfZ - 2),
			Vector3.new(halfX - 2, 0, halfZ - 2),
			Vector3.new(-20, 0, -(halfZ - 2)),
			Vector3.new(20, 0, -(halfZ - 2)),
			Vector3.new(-(halfX - 2), 0, 0),
			Vector3.new(halfX - 2, 0, 0),
		}
	do
		post(("PerimeterPost%d"):format(index), center + offset)
	end
end

local function buildEntrance(plot: Model, plotId: number, center: Vector3)
	local entry = center + WorldLayout.Plot.EntryOffset
	local dark = Color3.fromRGB(48, 54, 62)
	local steel = Color3.fromRGB(86, 96, 106)
	local cyan = Color3.fromRGB(70, 205, 224)

	for index, zOffset in { -58, -46, -34 } do
		makeDecoration(
			plot,
			plotId,
			("EntryApron%d"):format(index),
			Vector3.new(14, 0.14, 10),
			Vector3.new(center.X, center.Y + 0.58, center.Z + zOffset),
			dark,
			Enum.Material.DiamondPlate
		)

		for _, xOffset in { -6.4, 6.4 } do
			local strip = makeDecoration(
				plot,
				plotId,
				("EntryGuide%d_%d"):format(index, if xOffset < 0 then 1 else 2),
				Vector3.new(0.18, 0.08, 8.6),
				Vector3.new(center.X + xOffset, center.Y + 0.72, center.Z + zOffset),
				cyan,
				Enum.Material.Neon
			)
			strip.Transparency = 0.08
		end
	end

	for _, xOffset in { -10, 10 } do
		for index, zOffset in { -60, -40 } do
			makeDecoration(
				plot,
				plotId,
				("EntryBollard_%d_%d"):format(if xOffset < 0 then 1 else 2, index),
				Vector3.new(0.8, 3.4, 0.8),
				Vector3.new(center.X + xOffset, center.Y + 2.2, center.Z + zOffset),
				steel,
				Enum.Material.Metal
			)
			local lamp = makeDecoration(
				plot,
				plotId,
				("EntryLamp_%d_%d"):format(if xOffset < 0 then 1 else 2, index),
				Vector3.new(1, 0.35, 1),
				Vector3.new(center.X + xOffset, center.Y + 4, center.Z + zOffset),
				cyan,
				Enum.Material.Neon
			)
			lamp.Transparency = 0.05
		end
	end

	local welcome = makeDecoration(
		plot,
		plotId,
		"EntryWelcomePlate",
		Vector3.new(18, 0.25, 3.4),
		Vector3.new(entry.X, center.Y + 0.7, entry.Z + 9),
		Color3.fromRGB(66, 73, 82),
		Enum.Material.Metal
	)
	welcome:SetAttribute("EntryPresentation", true)
end

local function buildStorage(plot: Model, plotId: number, center: Vector3)
	local anchor = makeAnchor(
		plot,
		plotId,
		"StorageBin2",
		Vector3.new(18, 5, 7),
		center + Vector3.new(-16, 2.7, 14)
	)
	addLabel(anchor, "MATERIAL STORAGE")
	addUIPrompt(anchor, "Storage", "Material Storage")
	NativeAssetBuilder.BuildStorage(anchor, plotId)
end

local function buildStations(plot: Model, plotId: number, center: Vector3)
	local recycle = makeAnchor(
		plot,
		plotId,
		"RecycleStation",
		Vector3.new(7, 5, 5),
		center + Vector3.new(-2, 2.8, 14)
	)
	addLabel(recycle, "RECYCLE")
	addUIPrompt(recycle, "Recycle", "Recycle Bots")
	NativeAssetBuilder.BuildRecycle(recycle, plotId)

	local indexTerminal = makeAnchor(
		plot,
		plotId,
		"IndexTerminal",
		Vector3.new(5, 5, 4),
		center + Vector3.new(-12, 2.8, -10)
	)
	addLabel(indexTerminal, "ROBOT INDEX")
	addUIPrompt(indexTerminal, "Index", "Robot Index")
	NativeAssetBuilder.BuildTerminal(indexTerminal, plotId, "IndexTerminal", COLORS.Violet)

	local botConsole = makeAnchor(
		plot,
		plotId,
		"BotConsole",
		Vector3.new(5, 5, 4),
		center + Vector3.new(-4, 2.8, -10)
	)
	addLabel(botConsole, "BOT CONTROL")
	addUIPrompt(botConsole, "Bots", "Bot Control")
	NativeAssetBuilder.BuildTerminal(botConsole, plotId, "BotConsole", COLORS.Blue)

	local upgradeConsole = makeAnchor(
		plot,
		plotId,
		"UpgradeConsole",
		Vector3.new(5, 5, 4),
		center + Vector3.new(4, 2.8, -10)
	)
	addLabel(upgradeConsole, "UPGRADES")
	addUIPrompt(upgradeConsole, "Upgrades", "Factory Upgrades")
	NativeAssetBuilder.BuildTerminal(upgradeConsole, plotId, "UpgradeConsole", COLORS.Brass)
end

local function buildExpansionSockets(plot: Model, plotId: number, center: Vector3)
	for index, xOffset in { 15, 24 } do
		local socket = makeDecoration(
			plot,
			plotId,
			("ExpansionSocket%d"):format(index),
			Vector3.new(7, 0.35, 7),
			center + Vector3.new(xOffset, 0.68, 14),
			Color3.fromRGB(45, 50, 58),
			Enum.Material.DiamondPlate
		)
		socket:SetAttribute("ReservedExpansion", true)

		local rail = makeDecoration(
			plot,
			plotId,
			("ExpansionRail%d"):format(index),
			Vector3.new(5.8, 0.12, 0.2),
			socket.Position + Vector3.new(0, 0.25, -2.3),
			Color3.fromRGB(92, 101, 110),
			Enum.Material.Metal
		)
		rail.Transparency = 0.15

		if index == 1 then
			addLabel(socket, "FUTURE EXPANSION")
		end
	end
end

local function readLevel(plot: Model, attributeName: string): number
	local value = plot:GetAttribute(attributeName)
	if typeof(value) ~= "number" or value % 1 ~= 0 then
		return 1
	end
	return math.clamp(value, 1, 4)
end

local function setVisible(part: BasePart, visible: boolean)
	part.Transparency = if visible then 0 else 1
end

local function applyTierModel(modelInstance: Instance?, currentTier: number, isBusy: boolean?)
	if modelInstance == nil then
		return
	end

	for _, descendant in modelInstance:GetDescendants() do
		if descendant:IsA("BasePart") then
			local requiredTier = descendant:GetAttribute("RequiredTier")
			local busyOnly = descendant:GetAttribute("BusyOnly") == true
			local visible = true

			if typeof(requiredTier) == "number" and currentTier < requiredTier then
				visible = false
			end
			if busyOnly and isBusy ~= true then
				visible = false
			end

			setVisible(descendant, visible)
		end
	end
end

local function applyWorkPadVisual(visual: Instance?, unlockedPad: boolean)
	if visual == nil then
		return
	end

	for _, descendant in visual:GetDescendants() do
		if descendant:IsA("BasePart") then
			local unlockedOnly = descendant:GetAttribute("UnlockedOnly") == true
			local lockedOnly = descendant:GetAttribute("LockedOnly") == true
			local visible = true

			if unlockedOnly then
				visible = unlockedPad
			elseif lockedOnly then
				visible = not unlockedPad
			end

			setVisible(descendant, visible)
		end
	end
end

local function setWorldLabel(part: BasePart, text: string)
	local label = part:FindFirstChild("Label", true)
	if label ~= nil and label:IsA("TextLabel") then
		label.Text = text
	end
end

local function applyPlotPresentation(plot: Model)
	local processorLevel = readLevel(plot, "ProcessorLevel")
	local assemblerLevel = readLevel(plot, "AssemblerLevel")
	local storageLevel = readLevel(plot, "StorageLevel")
	local unlockedWorkSlots = plot:GetAttribute("UnlockedWorkSlots")
	if typeof(unlockedWorkSlots) ~= "number" then
		unlockedWorkSlots = 1
	end
	unlockedWorkSlots =
		math.clamp(math.floor(unlockedWorkSlots), 1, GameConfig.Factory.MaxWorkSlots + 2)

	local processor = plot:FindFirstChild("Processor")
	local processorBusy = processor ~= nil
		and processor:IsA("BasePart")
		and processor:GetAttribute("Busy") == true
	if processor ~= nil and processor:IsA("BasePart") then
		processor.Transparency = 1
		setWorldLabel(processor, ("PROCESSOR  T%d"):format(processorLevel))
	end
	applyTierModel(plot:FindFirstChild("ProcessorVisual"), processorLevel, processorBusy)

	local assembler = plot:FindFirstChild("Assembler")
	local assemblerBusy = assembler ~= nil
		and assembler:IsA("BasePart")
		and assembler:GetAttribute("Busy") == true
	if assembler ~= nil and assembler:IsA("BasePart") then
		assembler.Transparency = 1
		setWorldLabel(assembler, ("ASSEMBLER  T%d"):format(assemblerLevel))
	end
	applyTierModel(plot:FindFirstChild("AssemblerVisual"), assemblerLevel, assemblerBusy)
	applyTierModel(plot:FindFirstChild("StorageVisual"), storageLevel, false)

	local workPads = plot:FindFirstChild("WorkPads")
	if workPads ~= nil then
		for index = 1, GameConfig.Factory.MaxWorkSlots + 2 do
			local padId = ("Pad%d"):format(index)
			local pad = workPads:FindFirstChild(padId)
			if pad ~= nil and pad:IsA("BasePart") then
				pad.Transparency = 1
				pad.CanCollide = false
			end
			applyWorkPadVisual(
				workPads:FindFirstChild(padId .. "Visual"),
				index <= unlockedWorkSlots
			)
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

	local processor = plot:FindFirstChild("Processor")
	if processor ~= nil and processor:IsA("BasePart") then
		NativeAssetBuilder.BuildProcessor(processor, plotId)
	end

	local assembler = plot:FindFirstChild("Assembler")
	if assembler ~= nil and assembler:IsA("BasePart") then
		NativeAssetBuilder.BuildAssembler(assembler, plotId)
	end

	local workPads = plot:FindFirstChild("WorkPads")
	if workPads ~= nil then
		for index = 1, GameConfig.Factory.MaxWorkSlots + 2 do
			local pad = workPads:FindFirstChild(("Pad%d"):format(index))
			if pad ~= nil and pad:IsA("BasePart") then
				NativeAssetBuilder.BuildWorkPad(pad, plotId)
			end
		end
	end

	local center = floor.Position
	buildPerimeterPresentation(plot, plotId, center)
	buildEntrance(plot, plotId, center)
	buildStorage(plot, plotId, center)
	buildStations(plot, plotId, center)
	buildExpansionSockets(plot, plotId, center)

	for _, attributeName in
		{
			"ProcessorLevel",
			"AssemblerLevel",
			"StorageLevel",
			"UnlockedWorkSlots",
		}
	do
		plot:GetAttributeChangedSignal(attributeName):Connect(function()
			applyPlotPresentation(plot)
		end)
	end

	for _, machineName in { "Processor", "Assembler" } do
		local machine = plot:FindFirstChild(machineName)
		if machine ~= nil and machine:IsA("BasePart") then
			machine:GetAttributeChangedSignal("Busy"):Connect(function()
				applyPlotPresentation(plot)
			end)
		end
	end

	applyPlotPresentation(plot)
end

local function decorateSalvage()
	local sequence = 0
	for _, node in WorldService.GetSalvageNodes() do
		local plotId = node:GetAttribute("PlotId")
		local zoneId = node:GetAttribute("ZoneId")
		if typeof(plotId) == "number" and typeof(zoneId) == "number" then
			sequence += 1
			NativeAssetBuilder.BuildSalvage(node, plotId, zoneId, ((sequence - 1) % 3) + 1)
		end
	end
end

function PlotPresentationService.Init()
	if initialized then
		return
	end
	initialized = true

	for plotId, plot in WorldService.GetPlots() do
		decoratePlot(plotId, plot)
	end
	decorateSalvage()
end

return PlotPresentationService
