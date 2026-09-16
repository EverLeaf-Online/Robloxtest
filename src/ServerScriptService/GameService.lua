-- ServerScriptService/GameService.module.lua
-- Core server gameplay: energy, actions, milestones, anti-exploit, planet state.

local Players = game:GetService("Players")
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

local remotes = nil

local function getRemotes()
	if not remotes then
		remotes = ReplicatedFirst:WaitForChild("Remotes", 30)
	end
	return remotes
end

local function notify(player, title, message)
	local r = getRemotes()
	if r and player and player.Parent then
		r.Notify:FireClient(player, {
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

local function fireStats(player)
	local r = getRemotes()
	if not r then
		return
	end

	local stats = GameService.getStats(player)
	if stats then
		r.UpdateStats:FireClient(player, stats)
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

		if counts.Developed >= milestone.Tiles and not state.data.Milestones[key] then
			state.data.Milestones[key] = true

			local r = getRemotes()
			if r then
				r.MilestoneReached:FireClient(player, milestone)
			end

			DataManager.queueSave(player)
		end
	end

	fireStats(player)
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
		local tileType = data.Tiles[index + 1]
		if PlanetMath.isDeveloped(tileType) and PlanetMath.indexWithinRadius(centerIndex, index, radius) then
			count += 1
		end
	end

	return count
end

local function setTile(player, index, tileType)
	local state = states[player]
	if not state then
		return false
	end

	if typeof(index) ~= "number" or index < 0 or index >= PlanetMath.getTileCount() then
		return false
	end

	state.data.Tiles[index + 1] = tileType
	PlanetFactory.setTile(state.model, index, tileType)

	local r = getRemotes()
	if r then
		r.UpdateTile:FireClient(player, {
			tileIndex = index,
			tileType = tileType,
		})
	end

	DataManager.queueSave(player)
	return true
end

local function addEnergyInternal(player, amount)
	local state = states[player]
	if not state then
		return
	end

	local newValue = state.data.Energy + amount
	if newValue < 0 then
		newValue = 0
	end
	if newValue > config.MAX_ENERGY then
		newValue = config.MAX_ENERGY
	end

	state.data.Energy = math.floor(newValue)

	local r = getRemotes()
	if r then
		r.UpdateEnergy:FireClient(player, state.data.Energy)
	end

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

	local r = getRemotes()
	if r then
		r.UpdateEnergy:FireClient(player, state.data.Energy)
	end

	DataManager.queueSave(player)
	return true
end

local function addWater(player, targetIndex)
	local state = states[player]
	if not state then
		return false
	end

	local data = state.data
	local index = targetIndex

	if index < 0 then
		index = findRandomTile(data, function(tileType)
			return tileType == config.TILE.Land
		end)
	else
		if data.Tiles[index + 1] ~= config.TILE.Land then
			notify(player, "Invalid Tile", "Water can only be added to land tiles.")
			return false
		end
	end

	if not index then
		notify(player, "No Land Left", "There is no land tile available for water.")
		return false
	end

	return setTile(player, index, config.TILE.Water)
end

local function addPlant(player, targetIndex)
	local state = states[player]
	if not state then
		return false
	end

	local data = state.data
	local index = targetIndex

	if index < 0 then
		index = findRandomTile(data, function(tileType)
			return tileType == config.TILE.Land
		end)
	else
		if data.Tiles[index + 1] ~= config.TILE.Land then
			notify(player, "Invalid Tile", "Plants can only be added to land tiles.")
			return false
		end
	end

	if not index then
		notify(player, "No Land Left", "There is no land tile available for plants.")
		return false
	end

	local tileType = config.TILE.Plant

	-- Rare Seed product or 50-tile milestone can create glowing plants.
	if data.RareSeedUnlocked or data.Milestones["50"] then
		if math.random() < 0.25 then
			tileType = config.TILE.GlowPlant
		end
	end

	return setTile(player, index, tileType)
end

local function addAnimal(player, targetIndex)
	local state = states[player]
	if not state then
		return false
	end

	local data = state.data
	local counts = getCounts(data)

	local canFish = counts.Water >= 3
	local canLand = (counts.Plants + counts.Glow) >= 5

	if not canFish and not canLand then
		notify(player, "Animal Requirements Not Met", "Need 3 water tiles for fish or 5 plant tiles for land animals.")
		return false
	end

	local index = targetIndex
	local animalType = nil

	if index >= 0 then
		local tileType = data.Tiles[index + 1]

		if tileType == config.TILE.Water then
			if not canFish then
				notify(player, "Need More Water", "Fish require at least 3 water tiles.")
				return false
			end
			animalType = "Fish"
		elseif tileType == config.TILE.Plant or tileType == config.TILE.GlowPlant or tileType == config.TILE.Land then
			if not canLand then
				notify(player, "Need More Plants", "Land animals require at least 5 plant tiles.")
				return false
			end
			animalType = "Land"
		else
			notify(player, "Invalid Animal Tile", "Animals can only be placed on water, plants, or land.")
			return false
		end

		if hasAnimalAt(data, index) then
			notify(player, "Tile Occupied", "That tile already has an animal.")
			return false
		end
	else
		if canFish and (not canLand or math.random() < 0.5) then
			animalType = "Fish"
			index = findRandomTile(data, function(tileType, i)
				return tileType == config.TILE.Water and not hasAnimalAt(data, i)
			end)
		else
			animalType = "Land"
			index = findRandomTile(data, function(tileType, i)
				return (tileType == config.TILE.Plant or tileType == config.TILE.GlowPlant)
					and not hasAnimalAt(data, i)
			end)

			if not index then
				index = findRandomTile(data, function(tileType, i)
					return tileType == config.TILE.Land and not hasAnimalAt(data, i)
				end)
			end
		end

		if not index then
			notify(player, "No Animal Space", "No valid tile is available for an animal.")
			return false
		end
	end

	table.insert(data.Animals, {
		tile = index,
		type = animalType,
	})

	PlanetFactory.spawnAnimal(state.model, index, animalType)
	DataManager.queueSave(player)
	return true
end

local function buildSettlement(player, targetIndex)
	local state = states[player]
	if not state then
		return false
	end

	local data = state.data
	local counts = getCounts(data)

	if counts.Developed < 5 then
		notify(player, "Not Enough Development", "Settlements require at least 5 developed tiles nearby.")
		return false
	end

	local function isCandidate(index)
		local tileType = data.Tiles[index + 1]

		if tileType == config.TILE.Water then
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
			notify(player, "Invalid Settlement Location", "Build near a cluster of at least 5 developed land/plant/water tiles.")
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
			notify(player, "No Settlement Space", "No valid settlement location was found. Develop more tiles.")
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
	return states[player] ~= nil
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
	local r = getRemotes()
	if r then
		r.PurchaseConfirmed:FireClient(player, productId)
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
		notify(player, "Rare Seed Stored", "No land was available, but glowing plants are now unlocked.")
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

	for _ = 1, count do
		local index = findRandomTile(state.data, function(tileType)
			return tileType == config.TILE.Land
		end)

		if not index then
			break
		end

		local tileType = config.TILE.Plant
		if math.random() < 0.5 then
			tileType = config.TILE.Water
		end

		setTile(player, index, tileType)
	end

	checkMilestones(player)
	fireStats(player)
	DataManager.queueSave(player)
end

function GameService.tryAction(player, actionType, tileIndex)
	local state = states[player]
	if not state then
		return
	end

	if typeof(actionType) ~= "string" or typeof(tileIndex) ~= "number" then
		return
	end

	tileIndex = math.floor(tileIndex)
	if tileIndex < -1 then
		tileIndex = -1
	end

	if tileIndex >= PlanetMath.getTileCount() then
		tileIndex = -1
	end

	-- Rate limiting.
	local now = os.clock()
	if now - state.lastAction < config.ACTION_COOLDOWN then
		return
	end
	state.lastAction = now

	-- Milestone locks.
	if actionType == config.ACTIONS.AddAnimal and not state.data.Milestones["10"] then
		notify(player, "Locked", "Animals unlock at 10 developed tiles.")
		return
	end

	if actionType == config.ACTIONS.BuildSettlement and not state.data.Milestones["25"] then
		notify(player, "Locked", "Settlements unlock at 25 developed tiles.")
		return
	end

	local cost = config.COSTS[actionType]
	if typeof(cost) ~= "number" then
		return
	end

	if not spendEnergyInternal(player, cost) then
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

	if success then
		checkMilestones(player)
		fireStats(player)
		DataManager.queueSave(player)
	else
		-- Refund failed action.
		addEnergyInternal(player, cost)
	end
end

function GameService.startEnergyRegen(player)
	task.spawn(function()
		while player.Parent do
			local state = states[player]
			if not state or not state.active then
				break
			end

			local interval = config.ENERGY_REGEN_INTERVAL
			if state.ownership and state.ownership.FastGrowth then
				interval = interval / 2
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

	local position, slot = PlanetFactory.getFreePlanetPosition()
	local model = PlanetFactory.createPlanetModel(player, position, ownership.CosmicSkin)
	model:SetAttribute("Slot", slot)

	states[player] = {
		data = data,
		model = model,
		ownership = ownership,
		lastAction = 0,
		active = true,
	}

	-- Starter Planet game pass effect.
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

	if ownership.MoonCompanion and not model:FindFirstChild("Moon") then
		PlanetFactory.spawnMoon(model)
	end

	local r = getRemotes()
	if r then
		r.UpdateEnergy:FireClient(player, data.Energy)
	end

	fireStats(player)
	GameService.startEnergyRegen(player)

	if data.SaveBlocked then
		task.delay(2, function()
			if states[player] then
				notify(
					player,
					"Cloud Saves Unavailable",
					"DataStore is not accessible in this session. Progress will not be saved."
				)
			end
		end)
	end

	DataManager.queueSave(player)
end

function GameService.cleanup(player)
	local state = states[player]
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
