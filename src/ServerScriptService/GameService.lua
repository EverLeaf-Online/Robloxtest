local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local MarketplaceService = game:GetService("MarketplaceService")

local shared = ReplicatedStorage:WaitForChild("Shared")
local config = require(shared:WaitForChild("GameConfig"))
local PlanetMath = require(shared:WaitForChild("PlanetMath"))

local DataManager = require(script.Parent:WaitForChild("DataManager"))
local PlanetFactory = require(script.Parent:WaitForChild("PlanetFactory"))

local GameService = {}
local states = {}
local remotes = ReplicatedFirst:WaitForChild("Remotes")

local function notify(player, title, message)
	if player and player.Parent then
		remotes.Notify:FireClient(player, {
			Title = title,
			Message = message,
		})
	end
end

local function getCounts(data)
	local water = 0
	local plants = 0
	local glow = 0
	for _, tileType in ipairs(data.Tiles) do
		if tileType == config.TILE.Water then
			water += 1
		elseif tileType == config.TILE.Plant then
			plants += 1
		elseif tileType == config.TILE.GlowPlant then
			glow += 1
		end
	end
	return {
		Water = water,
		Plants = plants,
		Glow = glow,
		Developed = water + plants + glow,
		Animals = #data.Animals,
		Settlements = #data.Settlements,
	}
end

local function syncAttributes(player)
	local state = states[player]
	if not state then
		return
	end
	local counts = getCounts(state.data)
	player:SetAttribute("PlanetEnergy", state.data.Energy)
	player:SetAttribute("PlanetDeveloped", counts.Developed)
	player:SetAttribute("PlanetWater", counts.Water)
	player:SetAttribute("PlanetPlants", counts.Plants)
	player:SetAttribute("PlanetGlow", counts.Glow)
	player:SetAttribute("PlanetAnimals", counts.Animals)
	player:SetAttribute("PlanetSettlements", counts.Settlements)
end

local function fireStats(player)
	local stats = GameService.getStats(player)
	if stats then
		syncAttributes(player)
		remotes.UpdateStats:FireClient(player, stats)
	end
end

local function checkMilestones(player)
	local state = states[player]
	if not state then
		return
	end
	local counts = getCounts(state.data)
	for _, milestone in ipairs(config.MILESTONES) do
		local key = tostring(milestone.Tiles)
		if counts.Developed >= milestone.Tiles and state.data.Milestones[key] ~= true then
			state.data.Milestones[key] = true
			remotes.MilestoneReached:FireClient(player, milestone)
			DataManager.queueSave(player)
		end
	end
end

local function findRandomTile(data, predicate)
	local candidates = {}
	for index = 0, PlanetMath.getTileCount() - 1 do
		local tileType = data.Tiles[index + 1]
		if predicate(tileType, index) then
			table.insert(candidates, index)
		end
	end
	if #candidates == 0 then
		return nil
	end
	return candidates[math.random(1, #candidates)]
end

local function hasAnimalAt(data, index)
	for _, animal in ipairs(data.Animals) do
		if typeof(animal) == "table" and animal.tile == index then
			return true
		end
	end
	return false
end

local function hasSettlementAt(data, index)
	for _, settlementIndex in ipairs(data.Settlements) do
		if settlementIndex == index then
			return true
		end
	end
	return false
end

local function developedInRadius(data, centerIndex, radius)
	local count = 0
	for index = 0, PlanetMath.getTileCount() - 1 do
		if PlanetMath.isDeveloped(data.Tiles[index + 1]) and PlanetMath.indexWithinRadius(centerIndex, index, radius) then
			count += 1
		end
	end
	return count
end

local function setTile(player, index, tileType)
	local state = states[player]
	if not state or typeof(index) ~= "number" or index < 0 or index >= PlanetMath.getTileCount() then
		return false
	end
	state.data.Tiles[index + 1] = tileType
	PlanetFactory.setTile(state.model, index, tileType)
	remotes.UpdateTile:FireClient(player, {
		tileIndex = index,
		tileType = tileType,
	})
	DataManager.queueSave(player)
	return true
end

local function addEnergyInternal(player, amount)
	local state = states[player]
	if not state then
		return
	end
	state.data.Energy = math.clamp(math.floor(state.data.Energy + amount), 0, config.MAX_ENERGY)
	player:SetAttribute("PlanetEnergy", state.data.Energy)
	remotes.UpdateEnergy:FireClient(player, state.data.Energy)
	DataManager.queueSave(player)
end

local function spendEnergyInternal(player, cost)
	local state = states[player]
	if not state then
		return false
	end
	if state.data.Energy < cost then
		notify(player, "Not Enough Energy", ("This action costs %d Energy."):format(cost))
		return false
	end
	state.data.Energy -= cost
	player:SetAttribute("PlanetEnergy", state.data.Energy)
	remotes.UpdateEnergy:FireClient(player, state.data.Energy)
	DataManager.queueSave(player)
	return true
end

local function addWater(player, targetIndex)
	local data = states[player].data
	local index = targetIndex
	if index == -1 then
		index = findRandomTile(data, function(tileType)
			return tileType == config.TILE.Land
		end)
	elseif data.Tiles[index + 1] ~= config.TILE.Land then
		notify(player, "Invalid Tile", "Water can only be added to undeveloped land.")
		return false
	end
	if index == nil then
		notify(player, "No Land Left", "There are no undeveloped land tiles left.")
		return false
	end
	return setTile(player, index, config.TILE.Water)
end

local function addPlant(player, targetIndex)
	local state = states[player]
	local data = state.data
	local index = targetIndex
	if index == -1 then
		index = findRandomTile(data, function(tileType)
			return tileType == config.TILE.Land
		end)
	elseif data.Tiles[index + 1] ~= config.TILE.Land then
		notify(player, "Invalid Tile", "Plants can only be added to undeveloped land.")
		return false
	end
	if index == nil then
		notify(player, "No Land Left", "There are no undeveloped land tiles left.")
		return false
	end
	local tileType = config.TILE.Plant
	if (data.RareSeedUnlocked or data.Milestones["50"] == true) and math.random() < 0.25 then
		tileType = config.TILE.GlowPlant
	end
	return setTile(player, index, tileType)
end

local function addAnimal(player, targetIndex)
	local state = states[player]
	local data = state.data
	local counts = getCounts(data)
	local canFish = counts.Water >= 3
	local canLand = (counts.Plants + counts.Glow) >= 5
	if not canFish and not canLand then
		notify(player, "Habitat Missing", "Create 3 water tiles for fish or 5 planted tiles for land animals.")
		return false
	end

	local index = targetIndex
	local animalType
	if index >= 0 then
		if hasAnimalAt(data, index) then
			notify(player, "Tile Occupied", "That tile already has an animal.")
			return false
		end
		local tileType = data.Tiles[index + 1]
		if tileType == config.TILE.Water and canFish then
			animalType = "Fish"
		elseif (tileType == config.TILE.Plant or tileType == config.TILE.GlowPlant) and canLand then
			animalType = "Land"
		else
			notify(player, "Invalid Habitat", "Fish need water. Land animals need planted habitat.")
			return false
		end
	else
		if canLand then
			index = findRandomTile(data, function(tileType, i)
				return (tileType == config.TILE.Plant or tileType == config.TILE.GlowPlant) and not hasAnimalAt(data, i)
			end)
			animalType = index and "Land" or nil
		end
		if not index and canFish then
			index = findRandomTile(data, function(tileType, i)
				return tileType == config.TILE.Water and not hasAnimalAt(data, i)
			end)
			animalType = index and "Fish" or animalType
		end
		if not index then
			notify(player, "No Animal Space", "No free valid habitat tile is available.")
			return false
		end
	end

	table.insert(data.Animals, { tile = index, type = animalType })
	PlanetFactory.spawnAnimal(state.model, index, animalType)
	DataManager.queueSave(player)
	return true
end

local function buildSettlement(player, targetIndex)
	local state = states[player]
	local data = state.data
	local function isCandidate(index)
		local tileType = data.Tiles[index + 1]
		if tileType ~= config.TILE.Plant and tileType ~= config.TILE.GlowPlant then
			return false
		end
		if hasSettlementAt(data, index) then
			return false
		end
		return developedInRadius(data, index, 2) >= 5
	end

	local index = targetIndex
	if index >= 0 then
		if not isCandidate(index) then
			notify(player, "Invalid Settlement Location", "Build on a planted tile inside a cluster of at least 5 developed tiles.")
			return false
		end
	else
		local candidates = {}
		for i = 0, PlanetMath.getTileCount() - 1 do
			if isCandidate(i) then
				table.insert(candidates, i)
			end
		end
		if #candidates == 0 then
			notify(player, "No Settlement Space", "Develop a connected planted region first.")
			return false
		end
		index = candidates[math.random(1, #candidates)]
	end

	table.insert(data.Settlements, index)
	PlanetFactory.spawnSettlement(state.model, index)
	DataManager.queueSave(player)
	return true
end

function GameService.isReady(player)
	return states[player] ~= nil and player:GetAttribute("PlanetReady") == true
end

function GameService.getData(player)
	local state = states[player]
	return state and state.data or nil
end

function GameService.getStats(player)
	local state = states[player]
	if not state then
		return nil
	end
	local counts = getCounts(state.data)
	counts.Energy = state.data.Energy
	counts.Milestones = state.data.Milestones
	counts.Ownership = state.ownership
	counts.Unlocks = {
		Animal = state.data.Milestones["10"] == true,
		Settlement = state.data.Milestones["25"] == true,
		Golden = state.data.Milestones["50"] == true,
	}
	return counts
end

function GameService.getPlanetStateForClient(player)
	local state = states[player]
	if not state then
		return nil
	end
	return {
		Energy = state.data.Energy,
		Tiles = state.data.Tiles,
		Animals = state.data.Animals,
		Settlements = state.data.Settlements,
		Milestones = state.data.Milestones,
		Ownership = state.ownership,
		Stats = GameService.getStats(player),
		PlanetCenter = Vector3.new(
			state.model:GetAttribute("CenterX") or 0,
			state.model:GetAttribute("CenterY") or 0,
			state.model:GetAttribute("CenterZ") or 0
		),
	}
end

function GameService.getGamePassOwnership(player)
	local ownership = {
		FastGrowth = false,
		CosmicSkin = false,
		StarterPlanet = false,
		MoonCompanion = false,
	}
	for passName, passId in pairs(config.GAME_PASSES) do
		if typeof(passId) == "number" and passId > 0 then
			local ok, result = pcall(function()
				return MarketplaceService:UserOwnsGamePassAsync(player.UserId, passId)
			end)
			if ok then
				ownership[passName] = result == true
			end
		end
	end
	return ownership
end

function GameService.notifyPlayer(player, title, message)
	notify(player, title, message)
end

function GameService.firePurchaseConfirmed(player, productId)
	if player and player.Parent then
		remotes.PurchaseConfirmed:FireClient(player, productId)
	end
end

function GameService.addEnergy(player, amount)
	addEnergyInternal(player, amount)
end

function GameService.addRareSeed(player)
	local state = states[player]
	if not state then
		return false
	end
	state.data.RareSeedUnlocked = true
	local index = findRandomTile(state.data, function(tileType)
		return tileType == config.TILE.Land
	end)
	if index then
		setTile(player, index, config.TILE.GlowPlant)
	else
		notify(player, "Rare Seed Stored", "No undeveloped land is available, but rare plants are unlocked.")
	end
	checkMilestones(player)
	fireStats(player)
	DataManager.queueSave(player)
	return true
end

function GameService.addRandomDevelopedTiles(player, count)
	local state = states[player]
	if not state then
		return
	end
	for _ = 1, math.clamp(math.floor(count or 0), 0, 20) do
		local index = findRandomTile(state.data, function(tileType)
			return tileType == config.TILE.Land
		end)
		if not index then
			break
		end
		setTile(player, index, math.random() < 0.5 and config.TILE.Water or config.TILE.Plant)
	end
	checkMilestones(player)
	fireStats(player)
	DataManager.queueSave(player)
end

function GameService.tryAction(player, actionType, tileIndex)
	local state = states[player]
	if not state or player:GetAttribute("PlanetReady") ~= true then
		return
	end
	if typeof(actionType) ~= "string" or typeof(tileIndex) ~= "number" then
		return
	end
	tileIndex = math.floor(tileIndex)
	if tileIndex ~= -1 and (tileIndex < 0 or tileIndex >= PlanetMath.getTileCount()) then
		return
	end

	local validAction = actionType == config.ACTIONS.AddWater
		or actionType == config.ACTIONS.AddPlant
		or actionType == config.ACTIONS.AddAnimal
		or actionType == config.ACTIONS.BuildSettlement
	if not validAction then
		return
	end

	local now = os.clock()
	if now - state.lastAction < config.ACTION_COOLDOWN then
		notify(player, "Slow Down", "Please wait a moment before using another growth action.")
		return
	end
	state.lastAction = now

	if actionType == config.ACTIONS.AddAnimal and state.data.Milestones["10"] ~= true then
		notify(player, "Locked", "Animals unlock at 10 developed tiles.")
		return
	end
	if actionType == config.ACTIONS.BuildSettlement and state.data.Milestones["25"] ~= true then
		notify(player, "Locked", "Settlements unlock at 25 developed tiles.")
		return
	end

	local cost = config.COSTS[actionType]
	if not cost or not spendEnergyInternal(player, cost) then
		return
	end

	local success = false
	if actionType == config.ACTIONS.AddWater then
		success = addWater(player, tileIndex)
	elseif actionType == config.ACTIONS.AddPlant then
		success = addPlant(player, tileIndex)
	elseif actionType == config.ACTIONS.AddAnimal then
		success = addAnimal(player, tileIndex)
	elseif actionType == config.ACTIONS.BuildSettlement then
		success = buildSettlement(player, tileIndex)
	end

	if not success then
		addEnergyInternal(player, cost)
		return
	end

	checkMilestones(player)
	fireStats(player)
	DataManager.queueSave(player)
end

function GameService.startEnergyRegen(player)
	task.spawn(function()
		while player.Parent do
			local state = states[player]
			if not state or not state.active then
				break
			end
			local interval = config.ENERGY_REGEN_INTERVAL
			if state.ownership.FastGrowth then
				interval /= 2
			end
			task.wait(interval)
			state = states[player]
			if state and state.active then
				addEnergyInternal(player, config.ENERGY_REGEN_AMOUNT)
			end
		end
	end)
end

function GameService.initPlayer(player, data, ownership)
	if states[player] then
		GameService.cleanup(player)
	end

	player:SetAttribute("PlanetReady", false)
	local position, slot = PlanetFactory.getFreePlanetPosition()
	local model = PlanetFactory.createPlanetModel(player, position, ownership.CosmicSkin)
	model:SetAttribute("Slot", slot)

	states[player] = {
		data = data,
		model = model,
		ownership = ownership,
		lastAction = -math.huge,
		active = true,
	}

	if ownership.StarterPlanet and not data.StarterPlanetApplied then
		for _ = 1, 5 do
			local index = findRandomTile(data, function(tileType)
				return tileType == config.TILE.Land
			end)
			if index then
				data.Tiles[index + 1] = config.TILE.Water
			end
		end
		for _ = 1, 5 do
			local index = findRandomTile(data, function(tileType)
				return tileType == config.TILE.Land
			end)
			if index then
				data.Tiles[index + 1] = config.TILE.Plant
			end
		end
		data.StarterPlanetApplied = true
	end

	PlanetFactory.buildFromState(model, data, ownership.CosmicSkin)
	if ownership.MoonCompanion then
		PlanetFactory.spawnMoon(model)
	end

	checkMilestones(player)
	player:SetAttribute("PlanetModelName", model.Name)
	player:SetAttribute("PlanetCenterX", position.X)
	player:SetAttribute("PlanetCenterY", position.Y)
	player:SetAttribute("PlanetCenterZ", position.Z)
	player:SetAttribute("PlanetRadius", config.PLANET_RADIUS)
	syncAttributes(player)
	player:SetAttribute("PlanetReady", true)

	remotes.UpdateEnergy:FireClient(player, data.Energy)
	fireStats(player)
	GameService.startEnergyRegen(player)

	if data.SaveBlocked then
		task.delay(1, function()
			if states[player] then
				notify(player, "Cloud Saves Unavailable", "Progress in this test session will not be saved.")
			end
		end)
	end

	DataManager.queueSave(player)
	print(string.format("[Grow a Tiny Planet] Server initialized %s planet at %s", player.Name, tostring(position)))
end

function GameService.cleanup(player)
	local state = states[player]
	player:SetAttribute("PlanetReady", false)
	if not state then
		return
	end
	state.active = false
	if state.model then
		state.model:Destroy()
	end
	states[player] = nil
end

return GameService
