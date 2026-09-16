-- StarterPlayer/StarterPlayerScripts/PlanetClient.client.lua
-- Tile selection, visual updates, animal animation, and moon orbit.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local Workspace = game:GetService("Workspace")

local shared = ReplicatedStorage:WaitForChild("Shared")
local config = require(shared:WaitForChild("GameConfig"))
local PlanetMath = require(shared:WaitForChild("PlanetMath"))
local ClientState = require(shared:WaitForChild("ClientState"))

local remotes = ReplicatedFirst:WaitForChild("Remotes", 30)
if not remotes then
	warn("[PlanetClient] Remotes folder not found")
	return
end

local updateTile = remotes:WaitForChild("UpdateTile")
local player = Players.LocalPlayer
local camera = Workspace.CurrentCamera

local planetsFolder = Workspace:WaitForChild("Planets", 30)
if not planetsFolder then
	warn("[PlanetClient] Planets folder not found")
	return
end

local planet = planetsFolder:WaitForChild("Planet_" .. player.UserId, 60)
if not planet then
	warn("[PlanetClient] Local player planet not found")
	return
end

local baseSphere = planet:WaitForChild("BaseSphere", 30)
local tilesFolder = planet:WaitForChild("Tiles", 30)
if not baseSphere or not tilesFolder then
	warn("[PlanetClient] Planet geometry did not replicate")
	return
end

local currentHighlight = nil
local mouseDownPosition = nil
local CLICK_THRESHOLD = 9
local PICK_RADIUS = config.PLANET_RADIUS + 2

local function getTilePart(index)
	return tilesFolder:FindFirstChild("Tile_" .. tostring(index))
end

local function setSelectedTile(index)
	ClientState:SetSelectedTile(index)

	if currentHighlight then
		currentHighlight:Destroy()
		currentHighlight = nil
	end

	if index < 0 then
		return
	end

	local tilePart = getTilePart(index)
	if not tilePart then
		return
	end

	local highlight = Instance.new("Highlight")
	highlight.Name = "SelectedTileHighlight"
	highlight.Adornee = tilePart
	highlight.FillColor = config.COLORS.UI.Accent
	highlight.OutlineColor = config.COLORS.UI.Accent2
	highlight.FillTransparency = 0.6
	highlight.OutlineTransparency = 0
	highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	highlight.Parent = planet
	currentHighlight = highlight
end

local function nearestTileForDirection(surfaceDirection)
	local bestIndex = 0
	local bestDot = -math.huge
	for index = 0, PlanetMath.getTileCount() - 1 do
		local dot = surfaceDirection:Dot(PlanetMath.getDirection(index))
		if dot > bestDot then
			bestDot = dot
			bestIndex = index
		end
	end
	return bestIndex
end

local function pickTile(screenPosition)
	camera = Workspace.CurrentCamera
	if not camera or not baseSphere.Parent then
		return nil
	end

	local ray = camera:ScreenPointToRay(screenPosition.X, screenPosition.Y)
	local direction = ray.Direction.Unit
	local relativeOrigin = ray.Origin - baseSphere.Position

	local b = 2 * relativeOrigin:Dot(direction)
	local c = relativeOrigin:Dot(relativeOrigin) - PICK_RADIUS * PICK_RADIUS
	local discriminant = b * b - 4 * c
	if discriminant < 0 then
		return nil
	end

	local root = math.sqrt(discriminant)
	local distance = (-b - root) * 0.5
	if distance < 0 then
		distance = (-b + root) * 0.5
	end
	if distance < 0 then
		return nil
	end

	local hitPosition = ray.Origin + direction * distance
	local surfaceDirection = (hitPosition - baseSphere.Position).Unit
	return nearestTileForDirection(surfaceDirection)
end

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then
		return
	end
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		local p = UserInputService:GetMouseLocation()
		mouseDownPosition = Vector2.new(p.X, p.Y)
	end
end)

UserInputService.InputEnded:Connect(function(input, gameProcessed)
	if input.UserInputType ~= Enum.UserInputType.MouseButton1 or gameProcessed or not mouseDownPosition then
		return
	end

	local p = UserInputService:GetMouseLocation()
	local mouseUpPosition = Vector2.new(p.X, p.Y)
	local moved = (mouseUpPosition - mouseDownPosition).Magnitude
	mouseDownPosition = nil
	if moved > CLICK_THRESHOLD then
		return
	end

	local tileIndex = pickTile(mouseUpPosition)
	if tileIndex ~= nil then
		setSelectedTile(tileIndex)
	end
end)

updateTile.OnClientEvent:Connect(function(info)
	if typeof(info) ~= "table" or typeof(info.tileIndex) ~= "number" then
		return
	end

	local tilePart = getTilePart(info.tileIndex)
	if not tilePart then
		return
	end

	local cosmicSkin = planet:GetAttribute("CosmicSkin") == true
	local color, material, transparency = PlanetMath.getTileVisual(info.tileType, info.tileIndex, cosmicSkin)
	tilePart.Color = color
	tilePart.Material = material
	tilePart.Transparency = transparency
end)

local animalBases = {}
local function registerAnimal(obj)
	if obj:IsA("BasePart") and obj:GetAttribute("AnimalType") then
		animalBases[obj] = obj.CFrame
	end
end

local objectsFolder = planet:WaitForChild("Objects", 30)
if objectsFolder then
	for _, obj in ipairs(objectsFolder:GetChildren()) do
		registerAnimal(obj)
	end
	objectsFolder.ChildAdded:Connect(function(obj)
		task.wait()
		registerAnimal(obj)
	end)
end

RunService.RenderStepped:Connect(function(t)
	for part, baseCFrame in pairs(animalBases) do
		if part.Parent then
			local seed = part:GetAttribute("Seed") or 0
			local bob = math.sin(t * 2.2 + seed) * 1.4
			local spin = t * 0.8 + seed
			part.CFrame = baseCFrame * CFrame.new(0, bob, 0) * CFrame.Angles(0, spin, 0)
		else
			animalBases[part] = nil
		end
	end

	local moon = planet:FindFirstChild("Moon")
	if moon and baseSphere.Parent then
		local center = baseSphere.Position
		local radius = moon:GetAttribute("OrbitRadius") or 80
		local speed = moon:GetAttribute("OrbitSpeed") or 0.25
		local angle = t * speed
		local pos = center + Vector3.new(
			math.cos(angle) * radius,
			math.sin(angle * 0.6) * 18,
			math.sin(angle) * radius
		)
		moon.CFrame = CFrame.lookAt(pos, center)
	end
end)

print("[Grow a Tiny Planet] Planet client attached to", planet.Name)
