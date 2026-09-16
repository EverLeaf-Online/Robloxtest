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

local function setPartDefaults(part)
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
end

local function modelCenter(model)
	return Vector3.new(
		model:GetAttribute("CenterX") or 0,
		model:GetAttribute("CenterY") or 0,
		model:GetAttribute("CenterZ") or 0
	)
end

local function createTilePart(model, index)
	local tilesFolder = model:FindFirstChild("Tiles")
	if not tilesFolder then
		return nil
	end

	local part = Instance.new("Part")
	part.Name = "Tile_" .. tostring(index)
	part.Size = config.TILE_SIZE
	setPartDefaults(part)
	part.CanQuery = false
	part.CastShadow = false
	part:SetAttribute("TileIndex", index)

	local normal = PlanetMath.getDirection(index)
	local pos = modelCenter(model) + normal * config.TILE_RADIUS
	part.CFrame = PlanetMath.getCFrameFromNormal(pos, normal)
	part.Parent = tilesFolder
	return part
end

local function createAtmosphere(model, position)
	local atmosphere = Instance.new("Part")
	atmosphere.Name = "AtmosphereShell"
	atmosphere.Shape = Enum.PartType.Ball
	atmosphere.Size = Vector3.new(config.PLANET_RADIUS * 2 + 3, config.PLANET_RADIUS * 2 + 3, config.PLANET_RADIUS * 2 + 3)
	atmosphere.CFrame = CFrame.new(position)
	setPartDefaults(atmosphere)
	atmosphere.CanQuery = false
	atmosphere.CastShadow = false
	atmosphere.Material = Enum.Material.ForceField
	atmosphere.Color = Color3.fromRGB(92, 184, 255)
	atmosphere.Transparency = 0.94
	atmosphere.Parent = model
end

function PlanetFactory.getTileCFrame(model, index)
	local normal = PlanetMath.getDirection(index)
	local pos = modelCenter(model) + normal * config.TILE_RADIUS
	return PlanetMath.getCFrameFromNormal(pos, normal)
end

local function clearTileDetail(model, index)
	local details = model:FindFirstChild("Details")
	local existing = details and details:FindFirstChild("Detail_" .. tostring(index))
	if existing then
		existing:Destroy()
	end
end

function PlanetFactory.refreshTileDetail(model, index, tileType)
	clearTileDetail(model, index)
	if tileType ~= config.TILE.Plant and tileType ~= config.TILE.GlowPlant then
		return
	end

	local details = model:FindFirstChild("Details")
	if not details then
		return
	end

	local detail = Instance.new("Model")
	detail.Name = "Detail_" .. tostring(index)
	detail:SetAttribute("TileIndex", index)
	detail.Parent = details
	local cf = PlanetFactory.getTileCFrame(model, index)

	if tileType == config.TILE.Plant then
		local trunk = Instance.new("Part")
		trunk.Name = "Trunk"
		trunk.Size = Vector3.new(0.65, 2.4, 0.65)
		setPartDefaults(trunk)
		trunk.CanQuery = false
		trunk.CastShadow = true
		trunk.Material = Enum.Material.Wood
		trunk.Color = Color3.fromRGB(105, 72, 45)
		trunk.CFrame = cf * CFrame.new(math.sin(index * 1.7) * 0.7, 1.28, math.cos(index * 2.1) * 0.7)
		trunk.Parent = detail

		local canopy = Instance.new("Part")
		canopy.Name = "Canopy"
		canopy.Shape = Enum.PartType.Ball
		canopy.Size = Vector3.new(2.7, 2.7, 2.7)
		setPartDefaults(canopy)
		canopy.CanQuery = false
		canopy.CastShadow = true
		canopy.Material = Enum.Material.Grass
		canopy.Color = Color3.fromRGB(48, 172, 76)
		canopy.CFrame = trunk.CFrame * CFrame.new(0, 1.85, 0)
		canopy.Parent = detail

		local bush = Instance.new("Part")
		bush.Name = "Bush"
		bush.Shape = Enum.PartType.Ball
		bush.Size = Vector3.new(1.8, 1.25, 1.8)
		setPartDefaults(bush)
		bush.CanQuery = false
		bush.CastShadow = true
		bush.Material = Enum.Material.Grass
		bush.Color = Color3.fromRGB(64, 158, 72)
		bush.CFrame = cf * CFrame.new(-1.8, 0.75, 1.15)
		bush.Parent = detail
	else
		for crystalIndex = 1, 3 do
			local height = crystalIndex == 1 and 3.2 or 2.2
			local angle = (crystalIndex - 1) * math.pi * 2 / 3 + index * 0.21
			local radius = crystalIndex == 1 and 0 or 0.95
			local crystal = Instance.new("Part")
			crystal.Name = "Crystal_" .. crystalIndex
			crystal.Size = Vector3.new(0.65, height, 0.65)
			setPartDefaults(crystal)
			crystal.CanQuery = false
			crystal.CastShadow = false
			crystal.Material = Enum.Material.Neon
			crystal.Color = config.COLORS.GlowPlant
			crystal.CFrame = cf * CFrame.new(math.cos(angle) * radius, height * 0.55, math.sin(angle) * radius)
			crystal.Parent = detail
			if crystalIndex == 1 then
				local light = Instance.new("PointLight")
				light.Color = config.COLORS.GlowPlant
				light.Brightness = 0.8
				light.Range = 8
				light.Shadows = false
				light.Parent = crystal
			end
		end
	end
end

function PlanetFactory.applyTileVisual(tilePart, tileType, index, cosmicSkin)
	local color, material, transparency = PlanetMath.getTileVisual(tileType, index, cosmicSkin)
	tilePart.Color = color
	tilePart.Material = material
	tilePart.Transparency = transparency
	tilePart:SetAttribute("TileType", tileType)
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
	model:SetAttribute("CenterX", position.X)
	model:SetAttribute("CenterY", position.Y)
	model:SetAttribute("CenterZ", position.Z)
	model:SetAttribute("PlanetRadius", config.PLANET_RADIUS)
	model:SetAttribute("Ready", false)
	pcall(function()
		model.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
	end)
	model.Parent = folder

	local base = Instance.new("Part")
	base.Name = "BaseSphere"
	base.Shape = Enum.PartType.Ball
	base.Size = Vector3.new(config.PLANET_RADIUS * 2, config.PLANET_RADIUS * 2, config.PLANET_RADIUS * 2)
	base.CFrame = CFrame.new(position)
	setPartDefaults(base)
	base.CanQuery = false
	base.CastShadow = true
	base.Material = cosmicSkin and Enum.Material.SmoothPlastic or Enum.Material.Ground
	base.Color = cosmicSkin and config.COLORS.CosmicBase or config.COLORS.Base
	base.Parent = model
	model.PrimaryPart = base

	local tilesFolder = Instance.new("Folder")
	tilesFolder.Name = "Tiles"
	tilesFolder.Parent = model

	local detailsFolder = Instance.new("Folder")
	detailsFolder.Name = "Details"
	detailsFolder.Parent = model

	local objectsFolder = Instance.new("Folder")
	objectsFolder.Name = "Objects"
	objectsFolder.Parent = model

	createAtmosphere(model, position)

	for index = 0, PlanetMath.getTileCount() - 1 do
		createTilePart(model, index)
	end

	model:SetAttribute("Ready", true)
	return model
end

function PlanetFactory.getTilePart(model, index)
	local tilesFolder = model:FindFirstChild("Tiles")
	return tilesFolder and tilesFolder:FindFirstChild("Tile_" .. tostring(index)) or nil
end

function PlanetFactory.setTile(model, index, tileType)
	local tilePart = PlanetFactory.getTilePart(model, index)
	if not tilePart then
		return false
	end
	PlanetFactory.applyTileVisual(tilePart, tileType, index, model:GetAttribute("CosmicSkin") == true)
	PlanetFactory.refreshTileDetail(model, index, tileType)
	return true
end

function PlanetFactory.createTiles(model, tiles, cosmicSkin)
	for index = 0, PlanetMath.getTileCount() - 1 do
		local tileType = tiles[index + 1]
		if typeof(tileType) ~= "number" then
			tileType = config.TILE.Land
		end
		local tilePart = PlanetFactory.getTilePart(model, index) or createTilePart(model, index)
		if tilePart then
			PlanetFactory.applyTileVisual(tilePart, tileType, index, cosmicSkin)
			PlanetFactory.refreshTileDetail(model, index, tileType)
		end
	end
end

function PlanetFactory.spawnAnimal(model, tileIndex, animalType)
	local objects = model:FindFirstChild("Objects")
	if not objects then
		return nil
	end
	local cf = PlanetFactory.getTileCFrame(model, tileIndex)
	local part = Instance.new("Part")
	part.Name = "Animal_" .. animalType .. "_" .. tostring(tileIndex) .. "_" .. tostring(math.random(1000, 9999))
	part.Size = Vector3.new(2.2, 2.2, 2.2)
	setPartDefaults(part)
	part.CanQuery = false
	part.Shape = Enum.PartType.Ball
	part.Material = Enum.Material.SmoothPlastic
	part.Color = animalType == "Fish" and Color3.fromRGB(70, 190, 255) or Color3.fromRGB(222, 170, 102)
	part.CFrame = cf * CFrame.new(0, 2.7, 0)
	part:SetAttribute("AnimalType", animalType)
	part:SetAttribute("TileIndex", tileIndex)
	part:SetAttribute("Seed", math.random() * 100)
	part.Parent = objects

	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.fromOffset(34, 34)
	billboard.StudsOffset = Vector3.new(0, 2.6, 0)
	billboard.AlwaysOnTop = true
	billboard.Parent = part
	local icon = Instance.new("TextLabel")
	icon.BackgroundTransparency = 1
	icon.Size = UDim2.fromScale(1, 1)
	icon.TextScaled = true
	icon.Font = Enum.Font.GothamBold
	icon.TextColor3 = Color3.new(1, 1, 1)
	icon.Text = animalType == "Fish" and "🐟" or "🐇"
	icon.Parent = billboard
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
	settlement.Parent = objects

	local base = Instance.new("Part")
	base.Name = "Base"
	base.Size = Vector3.new(4.2, 2.8, 4.2)
	setPartDefaults(base)
	base.CanQuery = false
	base.Material = Enum.Material.WoodPlanks
	base.Color = Color3.fromRGB(225, 196, 154)
	base.CFrame = cf * CFrame.new(0, 1.65, 0)
	base.Parent = settlement
	settlement.PrimaryPart = base

	local roof = Instance.new("Part")
	roof.Name = "Roof"
	roof.Size = Vector3.new(5, 1.2, 5)
	setPartDefaults(roof)
	roof.CanQuery = false
	roof.Material = Enum.Material.Brick
	roof.Color = Color3.fromRGB(205, 84, 70)
	roof.CFrame = cf * CFrame.new(0, 3.7, 0)
	roof.Parent = settlement

	local light = Instance.new("PointLight")
	light.Brightness = 1.0
	light.Range = 14
	light.Color = Color3.fromRGB(255, 210, 130)
	light.Parent = base
	return settlement
end

function PlanetFactory.spawnMoon(model)
	local center = modelCenter(model)
	local moon = Instance.new("Part")
	moon.Name = "Moon"
	moon.Shape = Enum.PartType.Ball
	moon.Size = Vector3.new(12, 12, 12)
	setPartDefaults(moon)
	moon.CanQuery = false
	moon.Material = Enum.Material.Slate
	moon.Color = Color3.fromRGB(205, 210, 225)
	moon.CFrame = CFrame.new(center + Vector3.new(80, 20, 0))
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
