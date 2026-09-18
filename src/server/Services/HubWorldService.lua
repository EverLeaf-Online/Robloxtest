--!strict

local Workspace = game:GetService("Workspace")

local HubWorldService = {}
local initialized = false
local root: Folder? = nil
local factoryPortal: BasePart? = nil

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

local function addLabel(part: BasePart, text: string)
	local gui = Instance.new("BillboardGui")
	gui.Name = "WorldLabel"
	gui.AlwaysOnTop = true
	gui.Size = UDim2.fromOffset(260, 72)
	gui.StudsOffset = Vector3.new(0, part.Size.Y / 2 + 3, 0)
	gui.MaxDistance = 80
	gui.Parent = part

	local label = Instance.new("TextLabel")
	label.BackgroundColor3 = Color3.fromRGB(22, 26, 32)
	label.BackgroundTransparency = 0.08
	label.BorderSizePixel = 0
	label.Font = Enum.Font.GothamBold
	label.Size = UDim2.fromScale(1, 1)
	label.Text = text
	label.TextColor3 = Color3.fromRGB(240, 244, 248)
	label.TextScaled = true
	label.TextWrapped = true
	label.Parent = gui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = label
end

local function build(): Folder
	local oldFactory = Workspace:FindFirstChild("ScrapToBotGraybox")
	if oldFactory ~= nil then
		oldFactory:Destroy()
	end
	local oldHub = Workspace:FindFirstChild("ScrapToBotHub")
	if oldHub ~= nil then
		oldHub:Destroy()
	end

	local folder = Instance.new("Folder")
	folder.Name = "ScrapToBotHub"
	folder.Parent = Workspace

	local floor = makePart(folder, "HubFloor", Vector3.new(180, 1, 150), Vector3.new(0, 0, 0))
	floor.Material = Enum.Material.Concrete
	floor.Color = Color3.fromRGB(95, 101, 107)

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "HubSpawn"
	spawn.Anchored = true
	spawn.Neutral = true
	spawn.Size = Vector3.new(10, 1, 10)
	spawn.Position = Vector3.new(0, 1, 45)
	spawn.Parent = folder

	local title = makePart(folder, "HubTitle", Vector3.new(18, 8, 1), Vector3.new(0, 4.5, 62))
	title.Material = Enum.Material.Metal
	title.Color = Color3.fromRGB(62, 70, 80)
	addLabel(title, "SCRAP-TO-BOT\nFACTORY DISTRICT")

	local portal =
		makePart(folder, "FactoryPortal", Vector3.new(18, 10, 3), Vector3.new(0, 5.5, -28))
	portal.Material = Enum.Material.Metal
	portal.Color = Color3.fromRGB(54, 126, 144)
	addLabel(portal, "YOUR FACTORY\nENTER PRIVATE INSTANCE")

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "EnterFactoryPrompt"
	prompt.ActionText = "Enter Factory"
	prompt.ObjectText = "Private Factory"
	prompt.HoldDuration = 0.25
	prompt.MaxActivationDistance = 14
	prompt.RequiresLineOfSight = false
	prompt.Parent = portal

	factoryPortal = portal
	return folder
end

function HubWorldService.GetFactoryPortal(): BasePart
	assert(factoryPortal ~= nil, "HubWorldService.Init() must run first")
	return factoryPortal :: BasePart
end

function HubWorldService.GetRoot(): Folder
	assert(root ~= nil, "HubWorldService.Init() must run first")
	return root :: Folder
end

function HubWorldService.Init()
	if initialized then
		return
	end
	initialized = true
	root = build()
end

return HubWorldService
