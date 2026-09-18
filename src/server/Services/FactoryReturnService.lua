--!strict

local RunService = game:GetService("RunService")
local TeleportService = game:GetService("TeleportService")

local FactorySessionService = require(script.Parent.FactorySessionService)
local WorldService = require(script.Parent.WorldService)

local FactoryReturnService = {}
local initialized = false
local busy: { [Player]: boolean } = {}

local function buildPortal(): BasePart
	local plot = WorldService.GetPlot(1)
	assert(plot ~= nil, "Factory plot missing")

	local existing = plot:FindFirstChild("ReturnToHub")
	if existing ~= nil and existing:IsA("BasePart") then
		return existing
	end

	local floor = plot:FindFirstChild("Floor")
	assert(floor ~= nil and floor:IsA("BasePart"), "Factory floor missing")

	local portal = Instance.new("Part")
	portal.Name = "ReturnToHub"
	portal.Anchored = true
	portal.Size = Vector3.new(10, 8, 3)
	portal.Position = floor.Position + Vector3.new(0, 4.5, -84)
	portal.Material = Enum.Material.Metal
	portal.Color = Color3.fromRGB(72, 92, 112)
	portal:SetAttribute("PlotId", 1)
	portal.Parent = plot

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Return"
	prompt.ObjectText = "Factory District"
	prompt.HoldDuration = 0.2
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Parent = portal

	return portal
end

local function returnToHub(player: Player)
	if busy[player] or not FactorySessionService.IsParticipant(player) then
		return
	end
	busy[player] = true

	if RunService:IsStudio() then
		warn("[FactoryReturnService] TeleportService is unavailable in Studio")
		busy[player] = nil
		return
	end

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
