local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local TileGeometry = require(ReplicatedStorage.Shared.TileGeometry)
local PlanetStateService = require(script.Parent.PlanetStateService)

local PlanetRenderer = {}

local planetsFolder = Workspace:FindFirstChild("Planets")
if not planetsFolder then
	planetsFolder = Instance.new("Folder")
	planetsFolder.Name = "Planets"
	planetsFolder.Parent = Workspace
end

local function tileStyle(tileType, index, cosmic)
	if tileType == "Water" then
		return Config.COLORS.Water, Enum.Material.Glass, 0.05
	elseif tileType == "Plant" then
		return Config.COLORS.Plant, Enum.Material.Grass, 0
	elseif tileType == "RarePlant" then
		return Config.COLORS.RarePlant, Enum.Material.Neon, 0
	elseif cosmic then
		local color = index % 3 == 0 and Config.COLORS.CosmicB or Config.COLORS.CosmicA
		return color, Enum.Material.SmoothPlastic, 0.05
	end
	local color = index % 2 == 0 and Config.COLORS.Land or Config.COLORS.LandAlt
	return color, Enum.Material.Ground, 0
end

local function getPlanetModel(player)
	return planetsFolder:FindFirstChild("Planet_" .. player.UserId)
end

local function createPart(className, name, size, color, material, cframe, parent)
	local part = Instance.new(className)
	part.Name = name
	part.Size = size
	part.Color = color
	part.Material = material
	part.CFrame = cframe
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = true
	part.CastShadow = true
	part.Parent = parent
	return part
end

local function ensureMoon(player, model, center)
	local moon = model:FindFirstChild("Moon")
	if moon then
		return moon
	end
	moon = createPart(
		"Part",
		"Moon",
		Vector3.new(10, 10, 10),
		Config.COLORS.Moon,
		Enum.Material.Slate,
		CFrame.new(center + Vector3.new(70, 0, 0)),
		model
	)
	moon.Shape = Enum.PartType.Ball
	moon.CanQuery = false
	moon:SetAttribute("OrbitPhase", (player.UserId % 360) * math.pi / 180)
	return moon
end

function PlanetRenderer.CreatePlanet(player)
	local state = PlanetStateService.GetState(player)
	local center = PlanetStateService.GetCenter(player)
	if not state or not center then
		return nil
	end

	local existing = getPlanetModel(player)
	if existing then
		existing:Destroy()
	end

	local flags = PlanetStateService.GetPassFlags(player)
	local model = Instance.new("Model")
	model.Name = "Planet_" .. player.UserId
	model:SetAttribute("OwnerUserId", player.UserId)
	model:SetAttribute("OwnerName", player.Name)
	model.Parent = planetsFolder

	local baseColor = flags.CosmicSkin and Color3.fromRGB(45, 28, 90) or Config.COLORS.Base
	local core = createPart("Part", "Core", Vector3.new(Config.PLANET_RADIUS * 2, Config.PLANET_RADIUS * 2, Config.PLANET_RADIUS * 2), baseColor, Enum.Material.SmoothPlastic, CFrame.new(center), model)
	core.Shape = Enum.PartType.Ball
	core.CanQuery = false
	core.CastShadow = true
	model.PrimaryPart = core

	local tilesFolder = Instance.new("Folder")
	tilesFolder.Name = "Tiles"
	tilesFolder.Parent = model

	for index = 1, Config.TILE_COUNT do
		local color, material, transparency = tileStyle(state.Tiles[index], index, flags.CosmicSkin == true)
		local tile = createPart(
			"Part",
			"Tile_" .. index,
			Vector3.new(0.75, Config.TILE_DIAMETER, Config.TILE_DIAMETER),
			color,
			material,
			TileGeometry.GetTileCFrame(center, index, Config.PLANET_RADIUS + Config.TILE_SURFACE_OFFSET),
			tilesFolder
		)
		tile.Shape = Enum.PartType.Cylinder
		tile.Transparency = transparency
		tile:SetAttribute("TileIndex", index)
		tile:SetAttribute("OwnerUserId", player.UserId)
		tile:SetAttribute("TileType", state.Tiles[index])
	end

	local animalsFolder = Instance.new("Folder")
	animalsFolder.Name = "Animals"
	animalsFolder.Parent = model
	local settlementsFolder = Instance.new("Folder")
	settlementsFolder.Name = "Settlements"
	settlementsFolder.Parent = model

	for _, animal in ipairs(state.Animals) do
		PlanetRenderer.SpawnAnimal(player, animal)
	end
	for _, tileIndex in ipairs(state.Settlements) do
		PlanetRenderer.SpawnSettlement(player, tileIndex)
	end

	if flags.MoonCompanion then
		ensureMoon(player, model, center)
	end

	return model
end

function PlanetRenderer.UpdateTile(player, tileIndex)
	local state = PlanetStateService.GetState(player)
	local model = getPlanetModel(player)
	if not state or not model then
		return
	end
	local tiles = model:FindFirstChild("Tiles")
	local tile = tiles and tiles:FindFirstChild("Tile_" .. tileIndex)
	if not tile then
		return
	end
	local flags = PlanetStateService.GetPassFlags(player)
	local color, material, transparency = tileStyle(state.Tiles[tileIndex], tileIndex, flags.CosmicSkin == true)
	tile.Color = color
	tile.Material = material
	tile.Transparency = transparency
	tile:SetAttribute("TileType", state.Tiles[tileIndex])
end

function PlanetRenderer.RefreshAppearance(player)
	local model = getPlanetModel(player)
	local state = PlanetStateService.GetState(player)
	local center = PlanetStateService.GetCenter(player)
	if not model or not state or not center or not model.PrimaryPart then
		return
	end
	local flags = PlanetStateService.GetPassFlags(player)
	model.PrimaryPart.Color = flags.CosmicSkin and Color3.fromRGB(45, 28, 90) or Config.COLORS.Base
	for index = 1, Config.TILE_COUNT do
		PlanetRenderer.UpdateTile(player, index)
	end
	if flags.MoonCompanion then
		ensureMoon(player, model, center)
	else
		local moon = model:FindFirstChild("Moon")
		if moon then
			moon:Destroy()
		end
	end
end

function PlanetRenderer.SpawnAnimal(player, animal)
	local model = getPlanetModel(player)
	local center = PlanetStateService.GetCenter(player)
	if not model or not center then
		return
	end
	local folder = model:FindFirstChild("Animals")
	if not folder then
		return
	end
	local old = folder:FindFirstChild("Animal_" .. animal.Id)
	if old then
		old:Destroy()
	end

	local animalModel = Instance.new("Model")
	animalModel.Name = "Animal_" .. animal.Id
	animalModel:SetAttribute("TileIndex", animal.TileIndex)
	animalModel:SetAttribute("Kind", animal.Kind)
	animalModel:SetAttribute("AnimationPhase", tonumber(animal.Id) or 0)
	animalModel.Parent = folder

	local baseCF = TileGeometry.GetObjectCFrame(center, animal.TileIndex, Config.PLANET_RADIUS + 3.4)
	animalModel:SetAttribute("BaseCFrame", baseCF)

	if animal.Kind == "Fish" then
		local body = createPart("Part", "Body", Vector3.new(3.2, 1.2, 1.5), Color3.fromRGB(72, 191, 255), Enum.Material.SmoothPlastic, baseCF, animalModel)
		body.Shape = Enum.PartType.Ball
		local tail = createPart("WedgePart", "Tail", Vector3.new(1.2, 1.3, 1.2), Color3.fromRGB(47, 146, 235), Enum.Material.SmoothPlastic, baseCF * CFrame.new(0, 0, 1.6) * CFrame.Angles(0, math.rad(90), 0), animalModel)
		tail.CanQuery = false
		animalModel.PrimaryPart = body
	else
		local body = createPart("Part", "Body", Vector3.new(2.4, 1.5, 3), Color3.fromRGB(205, 148, 87), Enum.Material.SmoothPlastic, baseCF, animalModel)
		body.Shape = Enum.PartType.Ball
		local head = createPart("Part", "Head", Vector3.new(1.4, 1.4, 1.4), Color3.fromRGB(230, 178, 109), Enum.Material.SmoothPlastic, baseCF * CFrame.new(0, 0.6, -1.7), animalModel)
		head.Shape = Enum.PartType.Ball
		head.CanQuery = false
		animalModel.PrimaryPart = body
	end
end

function PlanetRenderer.SpawnSettlement(player, tileIndex)
	local model = getPlanetModel(player)
	local center = PlanetStateService.GetCenter(player)
	if not model or not center then
		return
	end
	local folder = model:FindFirstChild("Settlements")
	if not folder then
		return
	end
	local name = "Settlement_" .. tileIndex
	if folder:FindFirstChild(name) then
		return
	end

	local house = Instance.new("Model")
	house.Name = name
	house:SetAttribute("TileIndex", tileIndex)
	house.Parent = folder
	local baseCF = TileGeometry.GetObjectCFrame(center, tileIndex, Config.PLANET_RADIUS + 3.4)
	local walls = createPart("Part", "Walls", Vector3.new(4.3, 4, 4.3), Color3.fromRGB(225, 190, 132), Enum.Material.WoodPlanks, baseCF * CFrame.new(0, 2, 0), house)
	local roof = createPart("WedgePart", "RoofA", Vector3.new(4.8, 2.2, 4.8), Color3.fromRGB(126, 57, 52), Enum.Material.Brick, baseCF * CFrame.new(0, 4.9, 0) * CFrame.Angles(0, math.rad(90), 0), house)
	local door = createPart("Part", "Door", Vector3.new(1.1, 2.1, 0.25), Color3.fromRGB(93, 63, 42), Enum.Material.Wood, baseCF * CFrame.new(0, 1.3, -2.25), house)
	roof.CanQuery = false
	door.CanQuery = false
	house.PrimaryPart = walls
end

function PlanetRenderer.DestroyPlanet(player)
	local model = getPlanetModel(player)
	if model then
		model:Destroy()
	end
end

function PlanetRenderer.GetPlanetModel(player)
	return getPlanetModel(player)
end

return PlanetRenderer
