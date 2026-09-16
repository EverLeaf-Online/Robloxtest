-- ServerScriptService/PlanetFactory.module.lua
-- Creates and updates the physical/visual planet model for each player.

local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local shared = ReplicatedStorage:WaitForChild("Shared")
local config = require(shared:WaitForChild("GameConfig"))
local PlanetMath = require(shared:WaitForChild("PlanetMath"))

local PlanetFactory = {}

function PlanetFactory.getPlanetsFolder()
	local folder = Workspace:FindFirstChild("Planets")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "Planets"
		folder.Parent = Workspace
	end
	return folder
end

function PlanetFactory.getFreePlanetPosition()
	local folder = PlanetFactory.getPlanetsFolder()
	local usedSlots = {}

	for _, model in ipairs(folder:GetChildren()) do
		local slot = model:GetAttribute("Slot")
		if typeof(slot) == "number" then
			usedSlots[slot] = true
		end
	end

	local slot = 0
	while usedSlots[slot] do
		slot += 1
	end

	return Vector3.new(slot * 350, 0, 0), slot
end

local function createTilePart(model, index)
	local tilesFolder = model:FindFirstChild("Tiles")
	if not tilesFolder then
		return nil
	end

	local part = Instance.new("Part")
	part.Name = "Tile_" .. tostring(index)
	part.Size = config.TILE_SIZE
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part:SetAttribute("TileIndex", index)

	local base = model.PrimaryPart
	local normal = PlanetMath.getDirection(index)
	local pos = base.Position + normal * config.TILE_RADIUS
	part.CFrame = PlanetMath.getCFrameFromNormal(pos, normal)

	part.Parent = tilesFolder
	return part
end

function PlanetFactory.applyTileVisual(tilePart, tileType, index, cosmicSkin)
	local color, material, transparency = PlanetMath.getTileVisual(tileType, index, cosmicSkin)
	tilePart.Color = color
	tilePart.Material = material
	tilePart.Transparency = transparency
end

function PlanetFactory.createPlanetModel(player, position, cosmicSkin)
	local folder = PlanetFactory.getPlanetsFolder()
	local modelName = "Planet_" .. player.UserId

	local existing = folder:FindFirstChild(modelName)
	if existing then
		existing:Destroy()
	end

	local model = Instance.new("Model")
	model.Name = modelName
	model:SetAttribute("PlayerId", player.UserId)
	model:SetAttribute("CosmicSkin", cosmicSkin == true)

	local base = Instance.new("Part")
	base.Name = "BaseSphere"
	base.Shape = Enum.PartType.Ball
	base.Size = Vector3.new(config.PLANET_RADIUS * 2, config.PLANET_RADIUS * 2, config.PLANET_RADIUS * 2)
	base.CFrame = CFrame.new(position)
	base.Anchored = true
	base.CanCollide = false
	base.CanTouch = false
	base.Material = Enum.Material.SmoothPlastic
	base.Color = cosmicSkin and config.COLORS.CosmicBase or config.COLORS.Base
	base.Parent = model

	model.PrimaryPart = base

	local tilesFolder = Instance.new("Folder")
	tilesFolder.Name = "Tiles"
	tilesFolder.Parent = model

	local objectsFolder = Instance.new("Folder")
	objectsFolder.Name = "Objects"
	objectsFolder.Parent = model

	for index = 0, PlanetMath.getTileCount() - 1 do
		createTilePart(model, index)
	end

	model.Parent = folder
	return model
end

function PlanetFactory.getTilePart(model, index)
	local tilesFolder = model:FindFirstChild("Tiles")
	if not tilesFolder then
		return nil
	end

	return tilesFolder:FindFirstChild("Tile_" .. tostring(index))
end

function PlanetFactory.setTile(model, index, tileType)
	local tilePart = PlanetFactory.getTilePart(model, index)
	if not tilePart then
		return
	end

	local cosmicSkin = model:GetAttribute("CosmicSkin") == true
	PlanetFactory.applyTileVisual(tilePart, tileType, index, cosmicSkin)
end

function PlanetFactory.createTiles(model, tiles, cosmicSkin)
	for index = 0, PlanetMath.getTileCount() - 1 do
		local tileType = tiles[index + 1]
		if typeof(tileType) ~= "number" then
			tileType = config.TILE.Land
		end

		local tilePart = PlanetFactory.getTilePart(model, index)
		if not tilePart then
			tilePart = createTilePart(model, index)
		end

		if tilePart then
			PlanetFactory.applyTileVisual(tilePart, tileType, index, cosmicSkin)
		end
	end
end

function PlanetFactory.getTileCFrame(model, index)
	local base = model.PrimaryPart
	local normal = PlanetMath.getDirection(index)
	local pos = base.Position + normal * config.TILE_RADIUS
	return PlanetMath.getCFrameFromNormal(pos, normal)
end

function PlanetFactory.spawnAnimal(model, tileIndex, animalType)
	local objects = model:FindFirstChild("Objects")
	if not objects then
		return nil
	end

	local cf = PlanetFactory.getTileCFrame(model, tileIndex)

	local part = Instance.new("Part")
	part.Name = "Animal_" .. animalType .. "_" .. tostring(tileIndex) .. "_" .. tostring(math.random(1000, 9999))
	part.Size = Vector3.new(2.4, 2.4, 2.4)
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.Material = Enum.Material.Neon
	part.Color = animalType == "Fish" and Color3.fromRGB(70, 220, 255) or Color3.fromRGB(190, 255, 120)
	part.CFrame = cf * CFrame.new(0, 3.5, 0)
	part:SetAttribute("AnimalType", animalType)
	part:SetAttribute("TileIndex", tileIndex)
	part:SetAttribute("Seed", math.random() * 100)

	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.fromOffset(42, 42)
	billboard.StudsOffset = Vector3.new(0, 4, 0)
	billboard.AlwaysOnTop = true
	billboard.Parent = part

	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.TextScaled = true
	label.Font = Enum.Font.GothamBold
	label.TextColor3 = Color3.new(1, 1, 1)
	label.Text = animalType == "Fish" and "🐟" or "🐇"
	label.Parent = billboard

	part.Parent = objects
	return part
end

function PlanetFactory.spawnSettlement(model, tileIndex)
	local objects = model:FindFirstChild("Objects")
	if not objects then
		return nil
	end

	local cf = PlanetFactory.getTileCFrame(model, tileIndex)

	local settlement = Instance.new("Model")
	settlement.Name = "Settlement_" .. tostring(tileIndex) .. "_" .. tostring(math.random(1000, 9999))
	settlement:SetAttribute("TileIndex", tileIndex)

	local base = Instance.new("Part")
	base.Name = "Base"
	base.Size = Vector3.new(5, 3, 5)
	base.Anchored = true
	base.CanCollide = false
	base.CanTouch = false
	base.Material = Enum.Material.SmoothPlastic
	base.Color = Color3.fromRGB(225, 196, 154)
	base.CFrame = cf * CFrame.new(0, base.Size.Y / 2 + 0.8, 0)
	base.Parent = settlement

	settlement.PrimaryPart = base

	local roof = Instance.new("Part")
	roof.Name = "Roof"
	roof.Size = Vector3.new(6, 1.6, 6)
	roof.Anchored = true
	roof.CanCollide = false
	roof.CanTouch = false
	roof.Material = Enum.Material.Neon
	roof.Color = Color3.fromRGB(255, 110, 80)
	roof.CFrame = cf * CFrame.new(0, base.Size.Y + roof.Size.Y / 2 + 0.8, 0)
	roof.Parent = settlement

	local light = Instance.new("PointLight")
	light.Brightness = 1.25
	light.Range = 22
	light.Color = Color3.fromRGB(255, 210, 130)
	light.Parent = base

	settlement.Parent = objects
	return settlement
end

function PlanetFactory.spawnMoon(model)
	local base = model.PrimaryPart
	if not base then
		return nil
	end

	local moon = Instance.new("Part")
	moon.Name = "Moon"
	moon.Shape = Enum.PartType.Ball
	moon.Size = Vector3.new(12, 12, 12)
	moon.Anchored = true
	moon.CanCollide = false
	moon.CanTouch = false
	moon.Material = Enum.Material.SmoothPlastic
	moon.Color = Color3.fromRGB(205, 210, 225)
	moon.CFrame = CFrame.new(base.Position + Vector3.new(80, 20, 0))
	moon:SetAttribute("OrbitRadius", 80)
	moon:SetAttribute("OrbitSpeed", 0.25)
	moon.Parent = model

	return moon
end

function PlanetFactory.clearObjects(model)
	local objects = model:FindFirstChild("Objects")
	if objects then
		objects:ClearAllChildren()
	end
end

function PlanetFactory.buildFromState(model, data, cosmicSkin)
	PlanetFactory.createTiles(model, data.Tiles, cosmicSkin)
	PlanetFactory.clearObjects(model)

	for _, animal in ipairs(data.Animals) do
		if typeof(animal) == "table" and typeof(animal.tile) == "number" and typeof(animal.type) == "string" then
			PlanetFactory.spawnAnimal(model, animal.tile, animal.type)
		end
	end

	for _, settlementTile in ipairs(data.Settlements) do
		if typeof(settlementTile) == "number" then
			PlanetFactory.spawnSettlement(model, settlementTile)
		end
	end
end

return PlanetFactory
