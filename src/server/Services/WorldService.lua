--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local Zones = require(ReplicatedStorage.Shared.Config.Zones)

local WorldService = {}
local initialized = false
local root: Folder? = nil
local salvageNodes: { [string]: BasePart } = {}
local processorControls: { BasePart } = {}
local processorControlByRecipe: { [string]: BasePart } = {}
local assemblerPart: BasePart? = nil
local plotModels: { [number]: Model } = {}
local plotProcessorControls: { [number]: { [string]: BasePart } } = {}
local plotAssemblers: { [number]: BasePart } = {}
local plotWorkPads: { [number]: { [string]: BasePart } } = {}
local plotSigns: { [number]: BasePart } = {}
local plotEntries: { [number]: BasePart } = {}
local zoneGateByTarget: { [number]: BasePart } = {}
local zoneArrivalById: { [number]: BasePart } = {}
local zoneReturnById: { [number]: BasePart } = {}

local function makePart(parent: Instance, name: string, size: Vector3, position: Vector3): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.Size = size
	part.Position = position
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

local function addPrompt(part: BasePart, actionText: string, objectText: string): ProximityPrompt
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = actionText
	prompt.ObjectText = objectText
	prompt.HoldDuration = 0.15
	prompt.MaxActivationDistance = GameConfig.World.PromptActivationDistance
	prompt.RequiresLineOfSight = false
	prompt.Parent = part
	return prompt
end

local function addBillboard(part: BasePart, text: string, labelName: string?): TextLabel
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "WorldLabel"
	billboard.AlwaysOnTop = true
	billboard.Size = UDim2.fromOffset(210, 58)
	billboard.StudsOffset = Vector3.new(0, 5.5, 0)
	billboard.MaxDistance = 70
	billboard.Parent = part

	local label = Instance.new("TextLabel")
	label.Name = labelName or "Label"
	label.BackgroundTransparency = 0.2
	label.BackgroundColor3 = Color3.fromRGB(25, 28, 34)
	label.BorderSizePixel = 0
	label.Font = Enum.Font.GothamBold
	label.Size = UDim2.fromScale(1, 1)
	label.Text = text
	label.TextColor3 = Color3.fromRGB(245, 247, 250)
	label.TextScaled = true
	label.TextWrapped = true
	label.Parent = billboard
	return label
end

local function tagPlotPart(part: BasePart, plotId: number)
	part:SetAttribute("PlotId", plotId)
end

local function registerProcessorControl(plotId: number, part: BasePart, recipeId: string)
	part:SetAttribute("ProcessorRecipeId", recipeId)
	tagPlotPart(part, plotId)
	local controls = plotProcessorControls[plotId]
	if controls == nil then
		controls = {}
		plotProcessorControls[plotId] = controls
	end
	controls[recipeId] = part
	if plotId == 1 then
		processorControlByRecipe[recipeId] = part
	end
	table.insert(processorControls, part)
end

local function registerSalvageNode(
	parent: Instance,
	nodeId: string,
	position: Vector3,
	zoneId: number
)
	local node = makePart(parent, nodeId, Vector3.new(7, 3, 7), position)
	node.Material = Enum.Material.Metal
	node:SetAttribute("SalvageNodeId", nodeId)
	node:SetAttribute("ZoneId", zoneId)
	addPrompt(node, "Collect", if zoneId == 1 then "Scrap Pile" else "Circuit Scrap")
	salvageNodes[nodeId] = node
end

local function buildFactoryPlot(parent: Folder, plotId: number, center: Vector3)
	local plot = Instance.new("Model")
	plot.Name = ("Plot%02d"):format(plotId)
	plot:SetAttribute("PlotId", plotId)
	plot:SetAttribute("OwnerUserId", 0)
	plot.Parent = parent
	plotModels[plotId] = plot
	plotWorkPads[plotId] = {}

	local floor = makePart(plot, "Floor", Vector3.new(56, 1, 40), center)
	floor.Material = Enum.Material.Concrete
	tagPlotPart(floor, plotId)

	local entry = makePart(plot, "Entry", Vector3.new(5, 1, 5), center + Vector3.new(0, 1, -16))
	entry.Transparency = 1
	entry.CanCollide = false
	tagPlotPart(entry, plotId)
	plotEntries[plotId] = entry

	local sign = makePart(plot, "OwnerSign", Vector3.new(6, 5, 1), center + Vector3.new(0, 3, -18))
	sign.Material = Enum.Material.Metal
	tagPlotPart(sign, plotId)
	addBillboard(sign, ("Factory Plot %d\nUnclaimed"):format(plotId), "OwnerLabel")
	plotSigns[plotId] = sign

	local processor =
		makePart(plot, "Processor", Vector3.new(11, 8, 9), center + Vector3.new(-15, 4.5, 4))
	processor.Material = Enum.Material.Metal
	tagPlotPart(processor, plotId)

	local wiringControl =
		makePart(plot, "MakeWiring", Vector3.new(5, 2, 4), center + Vector3.new(-18, 2, -5))
	registerProcessorControl(plotId, wiringControl, "MakeWiring")
	addPrompt(wiringControl, "Process", "Make Wiring")

	local coreControl =
		makePart(plot, "RecoverCore", Vector3.new(5, 2, 4), center + Vector3.new(-12, 2, -5))
	registerProcessorControl(plotId, coreControl, "RecoverCore")
	addPrompt(coreControl, "Process", "Recover Core")

	local assembler =
		makePart(plot, "Assembler", Vector3.new(11, 8, 9), center + Vector3.new(0, 4.5, 4))
	assembler.Material = Enum.Material.Metal
	tagPlotPart(assembler, plotId)
	addPrompt(assembler, "Assemble", "Build Robot")
	plotAssemblers[plotId] = assembler
	if plotId == 1 then
		assemblerPart = assembler
	end

	local padsFolder = Instance.new("Folder")
	padsFolder.Name = "WorkPads"
	padsFolder.Parent = plot
	for index = 1, GameConfig.Factory.MaxWorkSlots + 2 do
		local column = (index - 1) % 2
		local row = math.floor((index - 1) / 2)
		local padId = ("Pad%d"):format(index)
		local pad = makePart(
			padsFolder,
			padId,
			Vector3.new(7, 0.5, 7),
			center + Vector3.new(15 + column * 9, 0.75, -3 + row * 11)
		)
		pad:SetAttribute("WorkPadId", padId)
		tagPlotPart(pad, plotId)
		plotWorkPads[plotId][padId] = pad
	end
end

local function buildPlots(folder: Folder)
	local plotsFolder = Instance.new("Folder")
	plotsFolder.Name = "FactoryPlots"
	plotsFolder.Parent = folder

	local columns = 4
	for plotId = 1, GameConfig.World.PlotCount do
		local column = (plotId - 1) % columns
		local row = math.floor((plotId - 1) / columns)
		local center = Vector3.new(-90 + column * 60, 0, 28 + row * 50)
		buildFactoryPlot(plotsFolder, plotId, center)
	end
end

local function buildStarterZone(folder: Folder)
	local floor =
		makePart(folder, "StarterYardFloor", Vector3.new(260, 1, 190), Vector3.new(0, 0, 10))
	floor.Material = Enum.Material.Concrete

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "GrayboxSpawn"
	spawn.Anchored = true
	spawn.Neutral = true
	spawn.Size = Vector3.new(8, 1, 8)
	spawn.Position = Vector3.new(0, 1, -18)
	spawn.Parent = folder

	local arrival = makePart(folder, "Zone1Arrival", Vector3.new(5, 1, 5), Vector3.new(0, 1, -16))
	arrival.Transparency = 1
	arrival.CanCollide = false
	zoneArrivalById[1] = arrival

	local salvageFolder = Instance.new("Folder")
	salvageFolder.Name = "SalvageNodes"
	salvageFolder.Parent = folder

	local salvagePositions = {
		Vector3.new(-60, 2, -68),
		Vector3.new(-40, 2, -72),
		Vector3.new(-20, 2, -68),
		Vector3.new(0, 2, -72),
		Vector3.new(20, 2, -68),
		Vector3.new(40, 2, -72),
		Vector3.new(60, 2, -68),
	}
	for index, position in salvagePositions do
		registerSalvageNode(salvageFolder, ("Scrap%02d"):format(index), position, 1)
	end

	buildPlots(folder)

	local zoneTwo = Zones[2]
	local gate =
		makePart(folder, "CircuitYardGate", Vector3.new(8, 10, 3), Vector3.new(118, 5.5, -24))
	gate.Material = Enum.Material.Metal
	gate:SetAttribute("TargetZone", 2)
	addPrompt(gate, "Unlock / Travel", zoneTwo.DisplayName)
	addBillboard(
		gate,
		("%s\n%d Credits • Build %d Bots"):format(
			zoneTwo.DisplayName,
			zoneTwo.UnlockCredits,
			zoneTwo.RequiredLifetimeRobots
		)
	)
	zoneGateByTarget[2] = gate
end

local function buildCircuitYard(folder: Folder)
	local zoneFolder = Instance.new("Folder")
	zoneFolder.Name = "CircuitYard"
	zoneFolder.Parent = folder

	local floor = makePart(zoneFolder, "Floor", Vector3.new(110, 1, 100), Vector3.new(335, 0, 0))
	floor.Material = Enum.Material.Concrete

	local arrival = makePart(zoneFolder, "Arrival", Vector3.new(5, 1, 5), Vector3.new(294, 1, 0))
	arrival.Transparency = 1
	arrival.CanCollide = false
	zoneArrivalById[2] = arrival

	local returnPortal =
		makePart(zoneFolder, "ReturnPortal", Vector3.new(7, 7, 3), Vector3.new(287, 3.5, 0))
	returnPortal.Material = Enum.Material.Metal
	addPrompt(returnPortal, "Return", Zones[1].DisplayName)
	zoneReturnById[2] = returnPortal

	local salvageFolder = Instance.new("Folder")
	salvageFolder.Name = "SalvageNodes"
	salvageFolder.Parent = zoneFolder

	local positions = {
		Vector3.new(316, 2, -28),
		Vector3.new(334, 2, -31),
		Vector3.new(352, 2, -28),
		Vector3.new(316, 2, 28),
		Vector3.new(334, 2, 31),
		Vector3.new(352, 2, 28),
	}
	for index, position in positions do
		registerSalvageNode(salvageFolder, ("Circuit%02d"):format(index), position, 2)
	end
end

local function buildWorld(): Folder
	local existing = Workspace:FindFirstChild("ScrapToBotGraybox")
	if existing then
		assert(existing:IsA("Folder"), "Workspace.ScrapToBotGraybox must be a Folder")
		existing:Destroy()
	end

	local folder = Instance.new("Folder")
	folder.Name = "ScrapToBotGraybox"
	folder.Parent = Workspace

	buildStarterZone(folder)
	buildCircuitYard(folder)
	return folder
end

function WorldService.GetRoot(): Folder
	assert(root ~= nil, "WorldService.Init() must run before GetRoot()")
	return root :: Folder
end

function WorldService.GetSalvageNode(nodeId: string): BasePart?
	return salvageNodes[nodeId]
end

function WorldService.GetSalvageNodes(): { [string]: BasePart }
	return salvageNodes
end

function WorldService.GetProcessorControls(): { BasePart }
	return processorControls
end

function WorldService.GetProcessorControl(recipeId: string): BasePart?
	return processorControlByRecipe[recipeId]
end

function WorldService.GetAssemblerPart(): BasePart
	assert(assemblerPart ~= nil, "WorldService.Init() must run before GetAssemblerPart()")
	return assemblerPart :: BasePart
end

function WorldService.GetPlots(): { [number]: Model }
	return plotModels
end

function WorldService.GetPlot(plotId: number): Model?
	return plotModels[plotId]
end

function WorldService.GetPlotProcessorControl(plotId: number, recipeId: string): BasePart?
	local controls = plotProcessorControls[plotId]
	return if controls then controls[recipeId] else nil
end

function WorldService.GetPlotAssembler(plotId: number): BasePart?
	return plotAssemblers[plotId]
end

function WorldService.GetPlotAssemblers(): { [number]: BasePart }
	return plotAssemblers
end

function WorldService.GetPlotWorkPad(plotId: number, padId: string): BasePart?
	local pads = plotWorkPads[plotId]
	return if pads then pads[padId] else nil
end

function WorldService.GetPlotSign(plotId: number): BasePart?
	return plotSigns[plotId]
end

function WorldService.GetPlotEntry(plotId: number): BasePart?
	return plotEntries[plotId]
end

function WorldService.GetPlotIdForInstance(instance: Instance): number?
	local current: Instance? = instance
	while current ~= nil and current ~= root do
		local plotId = current:GetAttribute("PlotId")
		if typeof(plotId) == "number" and plotId % 1 == 0 then
			return plotId
		end
		current = current.Parent
	end
	return nil
end

function WorldService.GetZoneGate(targetZone: number): BasePart?
	return zoneGateByTarget[targetZone]
end

function WorldService.GetZoneGates(): { [number]: BasePart }
	return zoneGateByTarget
end

function WorldService.GetZoneArrival(zoneId: number): BasePart?
	return zoneArrivalById[zoneId]
end

function WorldService.GetZoneReturnPortals(): { [number]: BasePart }
	return zoneReturnById
end

function WorldService.Init()
	if initialized then
		return
	end
	initialized = true
	root = buildWorld()
end

return WorldService
