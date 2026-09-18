--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local WorldService = require(script.Parent.WorldService)

local PlotPresentationService = {}
local initialized = false

local PROCESSOR_COLORS = {
	Color3.fromRGB(54, 94, 112),
	Color3.fromRGB(60, 116, 133),
	Color3.fromRGB(67, 140, 158),
	Color3.fromRGB(76, 169, 188),
}

local ASSEMBLER_COLORS = {
	Color3.fromRGB(129, 89, 52),
	Color3.fromRGB(153, 103, 55),
	Color3.fromRGB(178, 121, 58),
	Color3.fromRGB(207, 148, 68),
}

local STORAGE_COLORS = {
	Color3.fromRGB(76, 105, 128),
	Color3.fromRGB(69, 120, 139),
	Color3.fromRGB(62, 139, 151),
	Color3.fromRGB(66, 165, 173),
}

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

local function makeDecoration(
	plot: Model,
	plotId: number,
	name: string,
	size: Vector3,
	position: Vector3,
	color: Color3,
	material: Enum.Material?
): Part
	local part = makePart(plot, plotId, name, size, position, color, material)
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
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
			STORAGE_COLORS[1],
			Enum.Material.Metal
		)
		if index == 2 then
			addLabel(bin, "MATERIAL STORAGE")
			addUIPrompt(bin, "Storage", "Material Storage")
		end
	end

	makeDecoration(
		plot,
		plotId,
		"StorageUpgrade4",
		Vector3.new(17, 1, 2),
		center + Vector3.new(-16, 4.3, 14),
		STORAGE_COLORS[4],
		Enum.Material.Neon
	)
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

local function buildMachineUpgradeModules(plot: Model, plotId: number)
	local processor = plot:FindFirstChild("Processor")
	local assembler = plot:FindFirstChild("Assembler")
	if processor == nil or not processor:IsA("BasePart") then
		return
	end
	if assembler == nil or not assembler:IsA("BasePart") then
		return
	end

	makeDecoration(
		plot,
		plotId,
		"ProcessorUpgrade2",
		Vector3.new(2.5, 3.5, 4),
		processor.Position + Vector3.new(-6.25, -1, 0),
		PROCESSOR_COLORS[2],
		Enum.Material.Metal
	)
	makeDecoration(
		plot,
		plotId,
		"ProcessorUpgrade3",
		Vector3.new(7, 1.5, 5),
		processor.Position + Vector3.new(0, 4.75, 0),
		PROCESSOR_COLORS[3],
		Enum.Material.DiamondPlate
	)
	makeDecoration(
		plot,
		plotId,
		"ProcessorUpgrade4",
		Vector3.new(1.5, 5, 6),
		processor.Position + Vector3.new(5.75, 0, 0),
		PROCESSOR_COLORS[4],
		Enum.Material.Neon
	)

	makeDecoration(
		plot,
		plotId,
		"AssemblerUpgrade2",
		Vector3.new(2.5, 4, 3),
		assembler.Position + Vector3.new(-6.25, 0, 0),
		ASSEMBLER_COLORS[2],
		Enum.Material.Metal
	)
	makeDecoration(
		plot,
		plotId,
		"AssemblerUpgrade3",
		Vector3.new(9, 1.25, 2),
		assembler.Position + Vector3.new(0, 4.65, 0),
		ASSEMBLER_COLORS[3],
		Enum.Material.DiamondPlate
	)
	makeDecoration(
		plot,
		plotId,
		"AssemblerUpgrade4",
		Vector3.new(1.5, 5, 6),
		assembler.Position + Vector3.new(5.75, 0, 0),
		ASSEMBLER_COLORS[4],
		Enum.Material.Neon
	)

	makeDecoration(
		plot,
		plotId,
		"ProcessorBusyLight",
		Vector3.new(1.2, 0.6, 1.2),
		processor.Position + Vector3.new(0, 4.5, -3.4),
		Color3.fromRGB(81, 232, 255),
		Enum.Material.Neon
	)
	makeDecoration(
		plot,
		plotId,
		"AssemblerBusyLight",
		Vector3.new(1.2, 0.6, 1.2),
		assembler.Position + Vector3.new(0, 4.5, -3.4),
		Color3.fromRGB(255, 194, 82),
		Enum.Material.Neon
	)
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

local function readLevel(plot: Model, attributeName: string): number
	local value = plot:GetAttribute(attributeName)
	if typeof(value) ~= "number" or value % 1 ~= 0 then
		return 1
	end
	return math.clamp(value, 1, 4)
end

local function setDecorationVisible(instance: Instance?, visible: boolean)
	if instance == nil or not instance:IsA("BasePart") then
		return
	end
	instance.Transparency = if visible then 0 else 1
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
	if processor ~= nil and processor:IsA("BasePart") then
		processor.Color = PROCESSOR_COLORS[processorLevel]
		processor.Material = if processorLevel >= 3
			then Enum.Material.DiamondPlate
			else Enum.Material.Metal
		setWorldLabel(processor, ("PROCESSOR  T%d"):format(processorLevel))
	end

	local assembler = plot:FindFirstChild("Assembler")
	if assembler ~= nil and assembler:IsA("BasePart") then
		assembler.Color = ASSEMBLER_COLORS[assemblerLevel]
		assembler.Material = if assemblerLevel >= 3
			then Enum.Material.DiamondPlate
			else Enum.Material.Metal
		setWorldLabel(assembler, ("ASSEMBLER  T%d"):format(assemblerLevel))
	end

	for level = 2, 4 do
		setDecorationVisible(
			plot:FindFirstChild(("ProcessorUpgrade%d"):format(level)),
			processorLevel >= level
		)
		setDecorationVisible(
			plot:FindFirstChild(("AssemblerUpgrade%d"):format(level)),
			assemblerLevel >= level
		)
	end

	for index = 1, 3 do
		local bin = plot:FindFirstChild(("StorageBin%d"):format(index))
		if bin ~= nil and bin:IsA("BasePart") then
			local visible = index == 2 or storageLevel >= (if index == 1 then 2 else 3)
			bin.Transparency = if visible then 0 else 1
			bin.CanCollide = visible
			bin.CanTouch = visible
			bin.CanQuery = visible
			bin.Color = STORAGE_COLORS[storageLevel]
			bin.Material = if storageLevel >= 3
				then Enum.Material.DiamondPlate
				else Enum.Material.Metal
		end
	end
	setDecorationVisible(plot:FindFirstChild("StorageUpgrade4"), storageLevel >= 4)

	local processorBusy = processor ~= nil
		and processor:IsA("BasePart")
		and processor:GetAttribute("Busy") == true
	local assemblerBusy = assembler ~= nil
		and assembler:IsA("BasePart")
		and assembler:GetAttribute("Busy") == true
	setDecorationVisible(plot:FindFirstChild("ProcessorBusyLight"), processorBusy)
	setDecorationVisible(plot:FindFirstChild("AssemblerBusyLight"), assemblerBusy)

	local workPads = plot:FindFirstChild("WorkPads")
	if workPads ~= nil then
		for _, child in workPads:GetChildren() do
			if child:IsA("BasePart") then
				local indexText = string.match(child.Name, "^Pad(%d+)$")
				local index = if indexText ~= nil then tonumber(indexText) else nil
				local unlocked = index ~= nil and index <= unlockedWorkSlots
				child.Color = if unlocked
					then Color3.fromRGB(72, 145, 154)
					else Color3.fromRGB(57, 60, 68)
				child.Material = if unlocked
					then Enum.Material.DiamondPlate
					else Enum.Material.SmoothPlastic
				child.Transparency = if unlocked then 0.05 else 0.55
			end
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
	buildMachineUpgradeModules(plot, plotId)
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
