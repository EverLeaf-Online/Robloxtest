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

local function makeDecoration(
	parent: Instance,
	name: string,
	size: Vector3,
	cframe: CFrame,
	color: Color3,
	material: Enum.Material
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
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part:SetAttribute("PlotId", 1)
	part:SetAttribute("PresentationPart", true)
	part.Parent = parent
	return part
end

local function buildPortal(): BasePart
	local plot = WorldService.GetPlot(1)
	assert(plot ~= nil, "Factory plot missing")

	local existing = plot:FindFirstChild("ReturnToHub")
	if existing ~= nil and existing:IsA("BasePart") then
		return existing
	end

	local floor = plot:FindFirstChild("Floor")
	assert(floor ~= nil and floor:IsA("BasePart"), "Factory floor missing")

	local portalPosition = floor.Position + WorldLayout.Plot.ReturnPortalOffset
	local portal = Instance.new("Part")
	portal.Name = "ReturnToHub"
	portal.Anchored = true
	portal.CanCollide = false
	portal.CanTouch = false
	portal.Transparency = 1
	portal.Size = Vector3.new(12, 8, 5)
	portal.CFrame = CFrame.lookAt(portalPosition, portalPosition + Vector3.new(-1, 0, 0))
	portal:SetAttribute("PlotId", 1)
	portal.Parent = plot

	local visual = Instance.new("Model")
	visual.Name = "ReturnToHubVisual"
	visual.Parent = plot

	local dark = Color3.fromRGB(47, 54, 63)
	local steel = Color3.fromRGB(84, 96, 108)
	local cyan = Color3.fromRGB(74, 211, 229)

	local frame = portal.CFrame
	makeDecoration(
		visual,
		"Platform",
		Vector3.new(8, 0.45, 6),
		frame * CFrame.new(0, -3.7, 0),
		dark,
		Enum.Material.DiamondPlate
	)
	makeDecoration(
		visual,
		"LeftPost",
		Vector3.new(1, 7, 1),
		frame * CFrame.new(-3.5, 0, 0),
		steel,
		Enum.Material.Metal
	)
	makeDecoration(
		visual,
		"RightPost",
		Vector3.new(1, 7, 1),
		frame * CFrame.new(3.5, 0, 0),
		steel,
		Enum.Material.Metal
	)
	makeDecoration(
		visual,
		"Header",
		Vector3.new(8, 1.1, 1.2),
		frame * CFrame.new(0, 3.25, 0),
		steel,
		Enum.Material.Metal
	)
	makeDecoration(
		visual,
		"LeftGlow",
		Vector3.new(0.2, 5.4, 0.25),
		frame * CFrame.new(-3.05, 0, -0.56),
		cyan,
		Enum.Material.Neon
	)
	makeDecoration(
		visual,
		"RightGlow",
		Vector3.new(0.2, 5.4, 0.25),
		frame * CFrame.new(3.05, 0, -0.56),
		cyan,
		Enum.Material.Neon
	)
	makeDecoration(
		visual,
		"HeaderGlow",
		Vector3.new(5.8, 0.2, 0.25),
		frame * CFrame.new(0, 3.25, -0.66),
		cyan,
		Enum.Material.Neon
	)

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "ReturnToHubPrompt"
	prompt.ActionText = "Return"
	prompt.ObjectText = "Factory District"
	prompt.HoldDuration = 0.2
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Enabled = not RunService:IsStudio()
	prompt.Parent = portal

	return portal
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

	local portal = buildPortal()
	local prompt = portal:FindFirstChildOfClass("ProximityPrompt")
	assert(prompt ~= nil, "Return-to-hub prompt missing")
	prompt.Triggered:Connect(returnToHub)
end

return FactoryReturnService
