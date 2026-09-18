--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TeleportService = game:GetService("TeleportService")

local WorldLayout = require(ReplicatedStorage.Shared.Config.WorldLayout)

local FactorySessionService = require(script.Parent.FactorySessionService)
local WorldService = require(script.Parent.WorldService)

local FactoryReturnService = {}
local initialized = false
local busy: { [Player]: boolean } = {}

local function makePart(
	parent: Instance,
	name: string,
	size: Vector3,
	cframe: CFrame,
	color: Color3,
	material: Enum.Material,
	shape: Enum.PartType?
): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = material
	if shape ~= nil then
		part.Shape = shape
	end
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part:SetAttribute("PlotId", 1)
	part:SetAttribute("PresentationPart", true)
	part.Parent = parent
	return part
end

local function addLabel(adornee: BasePart)
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "TransitLabel"
	billboard.Adornee = adornee
	billboard.AlwaysOnTop = true
	billboard.Size = UDim2.fromOffset(180, 54)
	billboard.StudsOffset = Vector3.new(0, 5.6, 0)
	billboard.MaxDistance = 55
	billboard.Parent = adornee

	local label = Instance.new("TextLabel")
	label.BackgroundColor3 = Color3.fromRGB(21, 25, 31)
	label.BackgroundTransparency = 0.08
	label.BorderSizePixel = 0
	label.Font = Enum.Font.GothamBold
	label.Size = UDim2.fromScale(1, 1)
	label.Text = "TRANSIT BOT\nRETURN TO HUB"
	label.TextColor3 = Color3.fromRGB(235, 245, 250)
	label.TextScaled = true
	label.TextWrapped = true
	label.Parent = billboard

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = label
end

local function buildAttendant(): BasePart
	local plot = WorldService.GetPlot(1)
	assert(plot ~= nil, "Factory plot missing")

	local existing = plot:FindFirstChild("HubReturnAttendant")
	if existing ~= nil and existing:IsA("BasePart") then
		return existing
	end

	local floor = plot:FindFirstChild("Floor")
	assert(floor ~= nil and floor:IsA("BasePart"), "Factory floor missing")

	local center = floor.Position + WorldLayout.Plot.HubReturnAttendantOffset
	local facing = WorldLayout.Plot.HubReturnAttendantFacing
	local frame = CFrame.lookAt(center, center + facing)
	local anchor = Instance.new("Part")
	anchor.Name = "HubReturnAttendant"
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanTouch = false
	anchor.CanQuery = false
	anchor.Transparency = 1
	anchor.Size = Vector3.new(5, 7, 5)
	anchor.CFrame = frame
	anchor:SetAttribute("PlotId", 1)
	anchor.Parent = plot

	local visual = Instance.new("Model")
	visual.Name = "HubReturnAttendantVisual"
	visual.Parent = plot

	local dark = Color3.fromRGB(43, 49, 58)
	local steel = Color3.fromRGB(89, 101, 113)
	local cyan = Color3.fromRGB(70, 211, 229)
	local orange = Color3.fromRGB(224, 140, 63)

	makePart(
		visual,
		"Base",
		Vector3.new(5.5, 0.45, 5.5),
		frame * CFrame.new(0, -3.2, 0),
		dark,
		Enum.Material.DiamondPlate,
		nil
	)
	makePart(
		visual,
		"Body",
		Vector3.new(3.2, 3.8, 2.4),
		frame * CFrame.new(0, -0.9, 0),
		steel,
		Enum.Material.Metal,
		nil
	)
	makePart(
		visual,
		"ChestPanel",
		Vector3.new(2.3, 1.2, 0.24),
		frame * CFrame.new(0, -0.8, -1.32),
		cyan,
		Enum.Material.Neon,
		nil
	)
	makePart(
		visual,
		"Head",
		Vector3.new(2.6, 1.8, 2.1),
		frame * CFrame.new(0, 1.9, 0),
		dark,
		Enum.Material.Metal,
		nil
	)
	makePart(
		visual,
		"Visor",
		Vector3.new(1.9, 0.48, 0.2),
		frame * CFrame.new(0, 2.05, -1.12),
		cyan,
		Enum.Material.Neon,
		nil
	)
	makePart(
		visual,
		"LeftArm",
		Vector3.new(0.65, 2.7, 0.65),
		frame * CFrame.new(-2, -0.6, 0),
		orange,
		Enum.Material.Metal,
		nil
	)
	makePart(
		visual,
		"RightArm",
		Vector3.new(0.65, 2.7, 0.65),
		frame * CFrame.new(2, -0.6, 0),
		orange,
		Enum.Material.Metal,
		nil
	)
	makePart(
		visual,
		"LeftFoot",
		Vector3.new(1.15, 0.6, 1.8),
		frame * CFrame.new(-0.9, -2.75, -0.1),
		dark,
		Enum.Material.Metal,
		nil
	)
	makePart(
		visual,
		"RightFoot",
		Vector3.new(1.15, 0.6, 1.8),
		frame * CFrame.new(0.9, -2.75, -0.1),
		dark,
		Enum.Material.Metal,
		nil
	)

	addLabel(anchor)

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "ReturnToHubPrompt"
	prompt.ActionText = if RunService:IsStudio() then "Live Only" else "Return"
	prompt.ObjectText = "Factory District"
	prompt.HoldDuration = 0.2
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Enabled = true
	prompt.Parent = anchor

	return anchor
end

local function returnToHub(player: Player)
	if busy[player] or not FactorySessionService.IsParticipant(player) then
		return
	end
	if RunService:IsStudio() then
		return
	end

	busy[player] = true
	local ok, err = pcall(function()
		TeleportService:TeleportAsync(game.PlaceId, { player })
	end)
	if not ok then
		warn(
			("[FactoryReturnService] Hub teleport failed for %d: %s"):format(
				player.UserId,
				tostring(err)
			)
		)
		busy[player] = nil
	end
end

function FactoryReturnService.Init()
	if initialized then
		return
	end
	initialized = true

	local attendant = buildAttendant()
	local prompt = attendant:FindFirstChildOfClass("ProximityPrompt")
	assert(prompt ~= nil, "Hub return attendant prompt missing")
	prompt.Triggered:Connect(returnToHub)
end

return FactoryReturnService
