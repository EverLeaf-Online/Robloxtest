--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local WorldLayout = require(ReplicatedStorage.Shared.Config.WorldLayout)
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
local plotWorkNodes: { [number]: { [string]: BasePart } } = {}
local plotSigns: { [number]: BasePart } = {}
local plotEntries: { [number]: BasePart } = {}
local plotZoneGates: { [number]: { [number]: BasePart } } = {}
local plotZoneArrivals: { [number]: { [number]: BasePart } } = {}
local plotZoneReturns: { [number]: { [number]: BasePart } } = {}
local allZoneGates: { BasePart } = {}
local allZoneReturns: { BasePart } = {}

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

local function makeMarker(parent: Instance, name: string, position: Vector3): Part
	local marker = makePart(parent, name, Vector3.new(2, 0.4, 2), position)
	marker.Transparency = 1
	marker.CanCollide = false
	marker.CanTouch = false
	marker.CanQuery = false
	return marker
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
	billboard.Size = UDim2.fromOffset(160, 44)
	billboard.StudsOffset = Vector3.new(0, 4.5, 0)
	billboard.MaxDistance = 45
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

local function buildTransitBotVisual(
	plot: Model,
	plotId: number,
	anchor: BasePart,
	name: string,
	labelText: string,
	accent: Color3
)
	local visual = Instance.new("Model")
	visual.Name = name
	visual.Parent = plot

	local dark = Color3.fromRGB(43, 49, 58)
	local steel = Color3.fromRGB(89, 101, 113)
	local orange = Color3.fromRGB(224, 140, 63)
	local frame = anchor.CFrame

	local function piece(
		partName: string,
		size: Vector3,
		offset: Vector3,
		color: Color3,
		material: Enum.Material
	)
		local item = makePart(visual, partName, size, frame:PointToWorldSpace(offset))
		item.CFrame = frame * CFrame.new(offset)
		item.Color = color
		item.Material = material
		item.CanCollide = false
		item.CanTouch = false
		item.CanQuery = false
		item:SetAttribute("PresentationPart", true)
		tagPlotPart(item, plotId)
	end

	piece(
		"Base",
		Vector3.new(5.5, 0.45, 5.5),
		Vector3.new(0, -3.2, 0),
		dark,
		Enum.Material.DiamondPlate
	)
	piece("Body", Vector3.new(3.2, 3.8, 2.4), Vector3.new(0, -0.9, 0), steel, Enum.Material.Metal)
	piece(
		"ChestPanel",
		Vector3.new(2.3, 1.2, 0.24),
		Vector3.new(0, -0.8, -1.32),
		accent,
		Enum.Material.Neon
	)
	piece("Head", Vector3.new(2.6, 1.8, 2.1), Vector3.new(0, 1.9, 0), dark, Enum.Material.Metal)
	piece(
		"Visor",
		Vector3.new(1.9, 0.48, 0.2),
		Vector3.new(0, 2.05, -1.12),
		accent,
		Enum.Material.Neon
	)
	piece(
		"LeftArm",
		Vector3.new(0.65, 2.7, 0.65),
		Vector3.new(-2, -0.6, 0),
		orange,
		Enum.Material.Metal
	)
	piece(
		"RightArm",
		Vector3.new(0.65, 2.7, 0.65),
		Vector3.new(2, -0.6, 0),
		orange,
		Enum.Material.Metal
	)
	piece(
		"LeftFoot",
		Vector3.new(1.15, 0.6, 1.8),
		Vector3.new(-0.9, -2.75, -0.1),
		dark,
		Enum.Material.Metal
	)
	piece(
		"RightFoot",
		Vector3.new(1.15, 0.6, 1.8),
		Vector3.new(0.9, -2.75, -0.1),
		dark,
		Enum.Material.Metal
	)

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "TransitLabel"
	billboard.Adornee = anchor
	billboard.AlwaysOnTop = true
	billboard.Size = UDim2.fromOffset(190, 58)
	billboard.StudsOffset = Vector3.new(0, 5.7, 0)
	billboard.MaxDistance = 55
	billboard.Parent = anchor

	local label = Instance.new("TextLabel")
	label.Name = "Label"
	label.BackgroundColor3 = Color3.fromRGB(21, 25, 31)
	label.BackgroundTransparency = 0.08
	label.BorderSizePixel = 0
	label.Font = Enum.Font.GothamBold
	label.Size = UDim2.fromScale(1, 1)
	label.Text = labelText
	label.TextColor3 = Color3.fromRGB(235, 245, 250)
	label.TextScaled = true
	label.TextWrapped = true
	label.Parent = billboard

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = label
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
	zoneId: number,
	plotId: number?
)
	local node = makePart(parent, nodeId, Vector3.new(7, 3, 7), position)
	node.Material = Enum.Material.Metal
	node.Color = if zoneId == 1 then Color3.fromRGB(93, 84, 73) else Color3.fromRGB(67, 92, 104)
	node:SetAttribute("SalvageNodeId", nodeId)
	node:SetAttribute("ZoneId", zoneId)
	if plotId ~= nil then
		tagPlotPart(node, plotId)
		node:SetAttribute("PrivateSalvage", true)
	end

	addPrompt(node, "Collect", if zoneId == 1 then "Your Scrap Pile" else "Your Circuit Scrap")
	salvageNodes[nodeId] = node
end

local function registerWorkNode(
	folder: Folder,
	plotId: number,
	nodeName: string,
	position: Vector3
): BasePart
	local node = makeMarker(folder, nodeName, position)
	tagPlotPart(node, plotId)
	node:SetAttribute("BotWorkNode", true)
	node:SetAttribute("WorkNodeKind", nodeName)
	plotWorkNodes[plotId][nodeName] = node
	return node
end

local function buildPlotPerimeter(plot: Model, plotId: number, center: Vector3)
	local halfX = WorldLayout.Plot.Size.X / 2
	local halfZ = WorldLayout.Plot.Size.Z / 2
	local wallColor = Color3.fromRGB(67, 72, 78)

	local north = makePart(
		plot,
		"NorthBoundary",
		Vector3.new(WorldLayout.Plot.Size.X, 7, 4),
		center + Vector3.new(0, 3.5, halfZ - 2)
	)
	north.Material = Enum.Material.SmoothPlastic
	north.Color = wallColor
	north.Transparency = 1
	north.CanTouch = false
	north.CanQuery = false
	tagPlotPart(north, plotId)

	for _, side in { -1, 1 } do
		local wall = makePart(
			plot,
			if side < 0 then "WestBoundary" else "EastBoundary",
			Vector3.new(4, 7, WorldLayout.Plot.Size.Z),
			center + Vector3.new(side * (halfX - 2), 3.5, 0)
		)
		wall.Material = Enum.Material.SmoothPlastic
		wall.Color = wallColor
		wall.Transparency = 1
		wall.CanTouch = false
		wall.CanQuery = false
		tagPlotPart(wall, plotId)
	end

	local openingCenter = WorldLayout.CircuitIsland.BoundaryOpeningCenterX
	local openingHalfWidth = WorldLayout.CircuitIsland.BoundaryOpeningWidth / 2
	local leftMax = openingCenter - openingHalfWidth
	local rightMin = openingCenter + openingHalfWidth

	local function southBoundary(name: string, minX: number, maxX: number)
		local width = maxX - minX
		if width <= 0 then
			return
		end

		local wall = makePart(
			plot,
			name,
			Vector3.new(width, 7, 4),
			center + Vector3.new((minX + maxX) / 2, 3.5, -(halfZ - 2))
		)
		wall.Material = Enum.Material.SmoothPlastic
		wall.Color = wallColor
		wall.Transparency = 1
		wall.CanTouch = false
		wall.CanQuery = false
		tagPlotPart(wall, plotId)
	end

	southBoundary("SouthBoundaryLeft", -halfX, leftMax)
	southBoundary("SouthBoundaryRight", rightMin, halfX)
end

local function buildCircuitIsland(plot: Model, plotId: number, center: Vector3)
	local islandConfig = WorldLayout.CircuitIsland
	local island = makePart(
		plot,
		"CircuitIsland",
		islandConfig.Size,
		center + islandConfig.CenterOffset
	)
	island.Material = Enum.Material.Concrete
	island.Color = Color3.fromRGB(96, 102, 105)
	island:SetAttribute("ZoneId", 2)
	tagPlotPart(island, plotId)

	local bridgeFolder = Instance.new("Folder")
	bridgeFolder.Name = "CircuitBridge"
	bridgeFolder:SetAttribute("RequiredZone", 2)
	bridgeFolder.Parent = plot

	local bridgeCenter = center + islandConfig.BridgeCenterOffset
	local bridge = makePart(
		bridgeFolder,
		"BridgeDeck",
		islandConfig.BridgeSize,
		bridgeCenter
	)
	bridge.Material = Enum.Material.DiamondPlate
	bridge.Color = Color3.fromRGB(64, 72, 81)
	bridge.Transparency = 1
	bridge.CanCollide = false
	bridge.CanTouch = false
	bridge.CanQuery = false
	bridge:SetAttribute("BridgeCollidable", true)
	tagPlotPart(bridge, plotId)

	for _, side in { -1, 1 } do
		local rail = makePart(
			bridgeFolder,
			if side < 0 then "BridgeRailLeft" else "BridgeRailRight",
			Vector3.new(0.45, 2.8, islandConfig.BridgeSize.Z),
			bridgeCenter
				+ Vector3.new(
					side * (islandConfig.BridgeSize.X / 2 - 0.25),
					1.7,
					0
				)
		)
		rail.Material = Enum.Material.Metal
		rail.Color = Color3.fromRGB(91, 104, 117)
		rail.Transparency = 1
		rail.CanCollide = false
		rail.CanTouch = false
		rail.CanQuery = false
		rail:SetAttribute("BridgeCollidable", true)
		tagPlotPart(rail, plotId)

		local glow = makePart(
			bridgeFolder,
			if side < 0 then "BridgeGlowLeft" else "BridgeGlowRight",
			Vector3.new(0.14, 0.14, islandConfig.BridgeSize.Z),
			bridgeCenter
				+ Vector3.new(
					side * (islandConfig.BridgeSize.X / 2 - 0.3),
					0.45,
					0
				)
		)
		glow.Material = Enum.Material.Neon
		glow.Color = Color3.fromRGB(71, 211, 226)
		glow.Transparency = 1
		glow.CanCollide = false
		glow.CanTouch = false
		glow.CanQuery = false
		tagPlotPart(glow, plotId)
	end
end

local function buildPrivateSalvage(plot: Model, plotId: number, center: Vector3)
	local starterFolder = Instance.new("Folder")
	starterFolder.Name = "StarterSalvage"
	starterFolder.Parent = plot

	for index, offset in WorldLayout.StarterSalvageOffsets do
		registerSalvageNode(
			starterFolder,
			("P%02d_Scrap%02d"):format(plotId, index),
			center + offset,
			1,
			plotId
		)
	end

	local starterSign = makePart(
		plot,
		"StarterSalvageSign",
		Vector3.new(10, 5, 1),
		center + Vector3.new(-66, 3, 83)
	)
	starterSign.Material = Enum.Material.Metal
	tagPlotPart(starterSign, plotId)
	addBillboard(starterSign, "YOUR SCRAP FIELD")

	local circuitFolder = Instance.new("Folder")
	circuitFolder.Name = "CircuitSalvage"
	circuitFolder.Parent = plot

	for index, offset in WorldLayout.CircuitSalvageOffsets do
		registerSalvageNode(
			circuitFolder,
			("P%02d_Circuit%02d"):format(plotId, index),
			center + offset,
			2,
			plotId
		)
	end

	local circuitSign = makePart(
		plot,
		"CircuitSalvageSign",
		Vector3.new(12, 5, 1),
		center + WorldLayout.CircuitIsland.CenterOffset + Vector3.new(0, 3, -27)
	)
	circuitSign.Material = Enum.Material.Metal
	tagPlotPart(circuitSign, plotId)
	addBillboard(circuitSign, "CIRCUIT YARD")
end

local function buildBotWorkNodes(plot: Model, plotId: number, center: Vector3)
	local folder = Instance.new("Folder")
	folder.Name = "BotWorkNodes"
	folder.Parent = plot

	for nodeName, offset in WorldLayout.BotWorkOffsets do
		registerWorkNode(folder, plotId, nodeName, center + offset)
	end
end

local function buildPlotZoneAccess(plot: Model, plotId: number, center: Vector3)
	local zoneTwo = Zones[2]

	local gate = makePart(
		plot,
		"CircuitYardGate",
		Vector3.new(5, 7, 5),
		center + WorldLayout.CircuitGateOffset
	)
	gate.CFrame = CFrame.lookAt(
		gate.Position,
		Vector3.new(center.X, gate.Position.Y, center.Z)
	)
	gate.Transparency = 1
	gate.CanCollide = false
	gate.CanTouch = false
	gate.CanQuery = false
	gate:SetAttribute("TargetZone", 2)
	tagPlotPart(gate, plotId)
	addPrompt(gate, "Unlock / Travel", zoneTwo.DisplayName)
	buildTransitBotVisual(
		plot,
		plotId,
		gate,
		"CircuitTransitBotVisual",
		("CIRCUIT TRANSIT\n%d CREDITS • BUILD %d BOTS"):format(
			zoneTwo.UnlockCredits,
			zoneTwo.RequiredLifetimeRobots
		),
		Color3.fromRGB(225, 180, 84)
	)

	local arrival =
		makeMarker(plot, "CircuitYardArrival", center + WorldLayout.CircuitArrivalOffset)
	tagPlotPart(arrival, plotId)
	arrival:SetAttribute("ZoneId", 2)

	plotZoneGates[plotId] = { [2] = gate }
	plotZoneArrivals[plotId] = { [2] = arrival }
	plotZoneReturns[plotId] = {}
	table.insert(allZoneGates, gate)

	if plotId == 1 then
		zoneGateByTarget[2] = gate
		zoneArrivalById[2] = arrival
	end
end

local function buildFactoryPlot(parent: Folder, plotId: number, center: Vector3)
	local plot = Instance.new("Model")
	plot.Name = ("Plot%02d"):format(plotId)
	plot:SetAttribute("PlotId", plotId)
	plot:SetAttribute("OwnerUserId", 0)
	plot:SetAttribute("PlotWidth", WorldLayout.Plot.Size.X)
	plot:SetAttribute("PlotDepth", WorldLayout.Plot.Size.Z)
	plot.Parent = parent

	plotModels[plotId] = plot
	plotWorkPads[plotId] = {}
	plotWorkNodes[plotId] = {}

	local floor = makePart(plot, "Floor", WorldLayout.Plot.Size, center)
	floor.Material = Enum.Material.Concrete
	floor.Color = Color3.fromRGB(116, 116, 112)
	tagPlotPart(floor, plotId)

	local entry = makeMarker(plot, "Entry", center + WorldLayout.Plot.EntryOffset)
	tagPlotPart(entry, plotId)
	plotEntries[plotId] = entry
	if plotId == 1 then
		zoneArrivalById[1] = entry
	end

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "FactorySpawn"
	spawn.Anchored = true
	spawn.Neutral = true
	spawn.Size = Vector3.new(8, 1, 8)
	local spawnPosition = entry.Position + Vector3.new(0, 0.8, 0)
	spawn.CFrame = CFrame.lookAt(spawnPosition, spawnPosition + Vector3.new(0, 0, 24))
	spawn.Transparency = 1
	spawn.CanCollide = false
	spawn.Parent = plot

	local factoryCenter = center + WorldLayout.Plot.FactoryOffset

	local processor =
		makePart(plot, "Processor", Vector3.new(11, 8, 9), factoryCenter + Vector3.new(-30, 4.5, 0))
	processor.Material = Enum.Material.Metal
	processor.Color = Color3.fromRGB(54, 94, 112)
	tagPlotPart(processor, plotId)
	addBillboard(processor, "PROCESSOR")

	local wiringControl =
		makePart(plot, "MakeWiring", Vector3.new(5, 2, 4), factoryCenter + Vector3.new(-33, 2, -10))
	registerProcessorControl(plotId, wiringControl, "MakeWiring")
	addPrompt(wiringControl, "Process", "Make Wiring")

	local coreControl = makePart(
		plot,
		"RecoverCore",
		Vector3.new(5, 2, 4),
		factoryCenter + Vector3.new(-27, 2, -10)
	)
	registerProcessorControl(plotId, coreControl, "RecoverCore")
	addPrompt(coreControl, "Process", "Recover Core")

	local assembler =
		makePart(plot, "Assembler", Vector3.new(11, 8, 9), factoryCenter + Vector3.new(-5, 4.5, 0))
	assembler.Material = Enum.Material.Metal
	assembler.Color = Color3.fromRGB(129, 89, 52)
	tagPlotPart(assembler, plotId)
	addBillboard(assembler, "ASSEMBLER")
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
			Vector3.new(8, 0.5, 8),
			factoryCenter + Vector3.new(24 + column * 11, 0.75, -8 + row * 12)
		)
		pad:SetAttribute("WorkPadId", padId)
		tagPlotPart(pad, plotId)
		plotWorkPads[plotId][padId] = pad
	end

	buildPlotPerimeter(plot, plotId, center)
	buildCircuitIsland(plot, plotId, center)
	buildPrivateSalvage(plot, plotId, center)
	buildBotWorkNodes(plot, plotId, center)
	buildPlotZoneAccess(plot, plotId, center)
end

local function buildPlots(folder: Folder)
	local plotsFolder = Instance.new("Folder")
	plotsFolder.Name = "FactoryPlots"
	plotsFolder.Parent = folder

	-- Instanced-factory runtime owns one large production yard. Public social servers
	-- never initialize WorldService; they initialize HubWorldService instead.
	buildFactoryPlot(plotsFolder, 1, Vector3.zero)
end

local function buildWorld(): Folder
	local existing = Workspace:FindFirstChild("ScrapToBotGraybox")
	if existing then
		assert(existing:IsA("Folder"), "Workspace.ScrapToBotGraybox must be a Folder")
		existing:Destroy()
	end

	table.clear(salvageNodes)
	table.clear(processorControls)
	table.clear(processorControlByRecipe)
	table.clear(plotModels)
	table.clear(plotProcessorControls)
	table.clear(plotAssemblers)
	table.clear(plotWorkPads)
	table.clear(plotWorkNodes)
	table.clear(plotSigns)
	table.clear(plotEntries)
	table.clear(plotZoneGates)
	table.clear(plotZoneArrivals)
	table.clear(plotZoneReturns)
	table.clear(allZoneGates)
	table.clear(allZoneReturns)
	table.clear(zoneGateByTarget)
	table.clear(zoneArrivalById)
	table.clear(zoneReturnById)
	assemblerPart = nil

	local folder = Instance.new("Folder")
	folder.Name = "ScrapToBotGraybox"
	folder.Parent = Workspace

	buildPlots(folder)
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

function WorldService.GetPlotWorkNode(plotId: number, nodeName: string): BasePart?
	local nodes = plotWorkNodes[plotId]
	return if nodes then nodes[nodeName] else nil
end

function WorldService.GetPlotWorkNodes(plotId: number): { [string]: BasePart }?
	return plotWorkNodes[plotId]
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

function WorldService.GetPlotZoneGate(plotId: number, targetZone: number): BasePart?
	local gates = plotZoneGates[plotId]
	return if gates then gates[targetZone] else nil
end

function WorldService.GetAllZoneGates(): { BasePart }
	return allZoneGates
end

function WorldService.GetPlotZoneArrival(plotId: number, zoneId: number): BasePart?
	if zoneId == 1 then
		return plotEntries[plotId]
	end
	local arrivals = plotZoneArrivals[plotId]
	return if arrivals then arrivals[zoneId] else nil
end

function WorldService.GetPlotZoneReturn(plotId: number, zoneId: number): BasePart?
	local portals = plotZoneReturns[plotId]
	return if portals then portals[zoneId] else nil
end

function WorldService.GetAllZoneReturnPortals(): { BasePart }
	return allZoneReturns
end

-- Legacy accessors remain for Studio security probes and old tests. Plot-aware gameplay
-- uses the accessors above so a player can never travel through another player's yard.
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
