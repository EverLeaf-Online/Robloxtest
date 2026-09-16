-- StarterPlayer/StarterPlayerScripts/PlanetClient.client.lua
-- Handles tile selection, tile visual updates, animal animation, and moon orbit.

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
	return
end

local updateTile = remotes:WaitForChild("UpdateTile")

local player = Players.LocalPlayer
local camera = Workspace.CurrentCamera
local mouse = player:GetMouse()

local planetsFolder = Workspace:WaitForChild("Planets", 60)
if not planetsFolder then
	return
end

local planet = planetsFolder:WaitForChild("Planet_" .. player.UserId, 120)
if not planet then
	return
end

local currentHighlight = nil

local function getTilePart(index)
	local tilesFolder = planet:FindFirstChild("Tiles")
	if not tilesFolder then
		return nil
	end

	return tilesFolder:FindFirstChild("Tile_" .. tostring(index))
end

local function setSelectedTile(index)
	ClientState:SetSelectedTile(index)

	if currentHighlight then
		currentHighlight:Destroy()
		currentHighlight = nil
	end

	if index >= 0 then
		local tilePart = getTilePart(index)
		if tilePart then
			local highlight = Instance.new("Highlight")
			highlight.Adornee = tilePart
			highlight.FillColor = config.COLORS.UI.Accent
			highlight.OutlineColor = config.COLORS.UI.Accent2
			highlight.FillTransparency = 0.65
			highlight.OutlineTransparency = 0
			highlight.Parent = tilePart

			currentHighlight = highlight
		end
	end
end

-- Click-select tile, but only if it was a click rather than a drag.
local mouseDownPos = nil

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then
		return
	end

	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		mouseDownPos = input.Position
	end
end)

UserInputService.InputEnded:Connect(function(input, gameProcessed)
	if gameProcessed then
		return
	end

	if input.UserInputType == Enum.UserInputType.MouseButton1 and mouseDownPos then
		local delta = input.Position - mouseDownPos
		mouseDownPos = nil

		if delta.Magnitude < 6 then
			local ray = camera:ViewportPointToRay(mouse.X, mouse.Y)

			local params = RaycastParams.new()
			params.FilterType = Enum.RaycastFilterType.Include
			params.FilterDescendantsInstances = {planet}

			local result = Workspace:Raycast(ray.Origin, ray.Direction * 1000, params)
			if result and result.Instance then
				local tileIndex = result.Instance:GetAttribute("TileIndex")
				if typeof(tileIndex) == "number" then
					setSelectedTile(tileIndex)
				end
			end
		end
	end
end)

updateTile.OnClientEvent:Connect(function(info)
	if typeof(info) ~= "table" then
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

-- Animal animation.
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
	-- Animals bob and slowly spin.
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

	-- Moon orbit if the player owns Moon Companion.
	local moon = planet:FindFirstChild("Moon")
	if moon and planet.PrimaryPart then
		local center = planet.PrimaryPart.Position
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