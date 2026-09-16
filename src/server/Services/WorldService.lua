--!strict

local Workspace = game:GetService("Workspace")

local WorldService = {}
local initialized = false
local root: Folder? = nil
local salvageNodes: { [string]: BasePart } = {}
local processorControls: { BasePart } = {}
local assemblerPart: BasePart? = nil

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

local function buildWorld(): Folder
	local existing = Workspace:FindFirstChild("ScrapToBotGraybox")
	if existing then
		assert(existing:IsA("Folder"), "Workspace.ScrapToBotGraybox must be a Folder")
		existing:Destroy()
	end

	local folder = Instance.new("Folder")
	folder.Name = "ScrapToBotGraybox"
	folder.Parent = Workspace

	local floor = makePart(folder, "FactoryFloor", Vector3.new(160, 1, 100), Vector3.new(0, 0, 0))
	floor.Material = Enum.Material.Concrete

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "GrayboxSpawn"
	spawn.Anchored = true
	spawn.Neutral = true
	spawn.Size = Vector3.new(8, 1, 8)
	spawn.Position = Vector3.new(-58, 1, 0)
	spawn.Parent = folder

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
		local nodeId = ("Scrap%02d"):format(index)
		local node = makePart(salvageFolder, nodeId, Vector3.new(7, 3, 7), position)
		node.Material = Enum.Material.Metal
		node:SetAttribute("SalvageNodeId", nodeId)
		addPrompt(node, "Collect", "Scrap Pile")
		salvageNodes[nodeId] = node
	end

	local factoryFolder = Instance.new("Folder")
	factoryFolder.Name = "Factory"
	factoryFolder.Parent = folder

	local processor = makePart(factoryFolder, "Processor", Vector3.new(14, 8, 10), Vector3.new(-18, 4.5, 24))
	processor.Material = Enum.Material.Metal

	local wiringControl = makePart(factoryFolder, "MakeWiring", Vector3.new(5, 2, 4), Vector3.new(-22, 2, 17))
	wiringControl:SetAttribute("ProcessorRecipeId", "MakeWiring")
	addPrompt(wiringControl, "Process", "Make Wiring")
	table.insert(processorControls, wiringControl)

	local coreControl = makePart(factoryFolder, "RecoverCore", Vector3.new(5, 2, 4), Vector3.new(-14, 2, 17))
	coreControl:SetAttribute("ProcessorRecipeId", "RecoverCore")
	addPrompt(coreControl, "Process", "Recover Core")
	table.insert(processorControls, coreControl)

	local assembler = makePart(factoryFolder, "Assembler", Vector3.new(14, 8, 10), Vector3.new(3, 4.5, 24))
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

function WorldService.GetAssemblerPart(): BasePart
	assert(assemblerPart ~= nil, "WorldService.Init() must run before GetAssemblerPart()")
	return assemblerPart :: BasePart
end

function WorldService.Init()
	if initialized then
		return
	end
	initialized = true
	root = buildWorld()
end

return WorldService
