--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Zones = require(ReplicatedStorage.Shared.Config.Zones)

local WorldService = {}
local initialized = false
local root: Folder? = nil
local salvageNodes: { [string]: BasePart } = {}
local processorControls: { BasePart } = {}
local processorControlByRecipe: { [string]: BasePart } = {}
local assemblerPart: BasePart? = nil
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
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Parent = part
	return prompt
end

local function addBillboard(part: BasePart, text: string)
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "ZoneLabel"
	billboard.AlwaysOnTop = true
	billboard.Size = UDim2.fromOffset(300, 84)
	billboard.StudsOffset = Vector3.new(0, 7, 0)
	billboard.Parent = part

	local label = Instance.new("TextLabel")
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
end

local function registerProcessorControl(part: BasePart, recipeId: string)
	part:SetAttribute("ProcessorRecipeId", recipeId)
	processorControlByRecipe[recipeId] = part
	table.insert(processorControls, part)
end

local function registerSalvageNode(parent: Instance, nodeId: string, position: Vector3, zoneId: number)
	local node = makePart(parent, nodeId, Vector3.new(7, 3, 7), position)
	node.Material = Enum.Material.Metal
	node:SetAttribute("SalvageNodeId", nodeId)
	node:SetAttribute("ZoneId", zoneId)
	addPrompt(node, "Collect", if zoneId == 1 then "Scrap Pile" else "Circuit Scrap")
	salvageNodes[nodeId] = node
end

local function buildStarterZone(folder: Folder)
	local floor = makePart(folder, "FactoryFloor", Vector3.new(160, 1, 100), Vector3.new(0, 0, 0))
	floor.Material = Enum.Material.Concrete

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "GrayboxSpawn"
	spawn.Anchored = true
	spawn.Neutral = true
	spawn.Size = Vector3.new(8, 1, 8)
	spawn.Position = Vector3.new(-58, 1, 0)
	spawn.Parent = folder

	local arrival = makePart(folder, "Zone1Arrival", Vector3.new(5, 1, 5), Vector3.new(-54, 1, 0))
	arrival.Transparency = 1
	arrival.CanCollide = false
	zoneArrivalById[1] = arrival

	local salvageFolder = Instance.new("Folder")
	salvageFolder.Name = "SalvageNodes"
	salvageFolder.Parent = folder

	local salvagePositions = {
		Vector3.new(-34, 2, -28),
		Vector3.new(-20, 2, -30),
		Vector3.new(-6, 2, -28),
		Vector3.new(8, 2, -30),
		Vector3.new(22, 2, -28),
		Vector3.new(36, 2, -30),
	}
	for index, position in salvagePositions do
		registerSalvageNode(salvageFolder, ("Scrap%02d"):format(index), position, 1)
	end

	local factoryFolder = Instance.new("Folder")
	factoryFolder.Name = "Factory"
	factoryFolder.Parent = folder

	local processor =
		makePart(factoryFolder, "Processor", Vector3.new(14, 8, 10), Vector3.new(-18, 4.5, 24))
	processor.Material = Enum.Material.Metal

	local wiringControl =
		makePart(factoryFolder, "MakeWiring", Vector3.new(5, 2, 4), Vector3.new(-22, 2, 17))
	registerProcessorControl(wiringControl, "MakeWiring")
	addPrompt(wiringControl, "Process", "Make Wiring")

	local coreControl =
		makePart(factoryFolder, "RecoverCore", Vector3.new(5, 2, 4), Vector3.new(-14, 2, 17))
	registerProcessorControl(coreControl, "RecoverCore")
	addPrompt(coreControl, "Process", "Recover Core")

	local assembler =
		makePart(factoryFolder, "Assembler", Vector3.new(14, 8, 10), Vector3.new(3, 4.5, 24))
	assembler.Material = Enum.Material.Metal
	addPrompt(assembler, "Assemble", "Build Robot")
	assemblerPart = assembler

	local padsFolder = Instance.new("Folder")
	padsFolder.Name = "WorkPads"
	padsFolder.Parent = factoryFolder
	for index = 1, 4 do
		local pad = makePart(
			padsFolder,
			("Pad%d"):format(index),
			Vector3.new(8, 0.5, 8),
			Vector3.new(24 + (index - 1) * 11, 0.75, 22)
		)
		pad:SetAttribute("WorkPadId", ("Pad%d"):format(index))
	end

	local zoneTwo = Zones[2]
	local gate = makePart(folder, "CircuitYardGate", Vector3.new(8, 10, 3), Vector3.new(70, 5.5, 0))
	gate.Material = Enum.Material.Metal
	gate:SetAttribute("TargetZone", 2)
	addPrompt(gate, "Unlock / Travel", zoneTwo.DisplayName)
	addBillboard(
		gate,
		("%s\n%,d Credits • Build %d Bots"):format(
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

	local floor = makePart(zoneFolder, "Floor", Vector3.new(100, 1, 84), Vector3.new(220, 0, 0))
	floor.Material = Enum.Material.Concrete

	local arrival = makePart(zoneFolder, "Arrival", Vector3.new(5, 1, 5), Vector3.new(184, 1, 0))
	arrival.Transparency = 1
	arrival.CanCollide = false
	zoneArrivalById[2] = arrival

	local returnPortal = makePart(zoneFolder, "ReturnPortal", Vector3.new(7, 7, 3), Vector3.new(177, 3.5, 0))
	returnPortal.Material = Enum.Material.Metal
	addPrompt(returnPortal, "Return", Zones[1].DisplayName)
	zoneReturnById[2] = returnPortal

	local salvageFolder = Instance.new("Folder")
	salvageFolder.Name = "SalvageNodes"
	salvageFolder.Parent = zoneFolder

	local positions = {
		Vector3.new(202, 2, -24),
		Vector3.new(218, 2, -27),
		Vector3.new(234, 2, -24),
		Vector3.new(202, 2, 24),
		Vector3.new(218, 2, 27),
		Vector3.new(234, 2, 24),
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
