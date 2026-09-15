local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local PlanetStateService = require(script.Parent.PlanetStateService)
local PlanetRenderer = require(script.Parent.PlanetRenderer)
local MilestoneSystem = require(script.Parent.MilestoneSystem)

local MonetizationService = {}

local remotes = ReplicatedFirst:WaitForChild("Remotes")
local updateEnergy = remotes:WaitForChild("UpdateEnergy")
local updateTile = remotes:WaitForChild("UpdateTile")
local stateUpdated = remotes:WaitForChild("StateUpdated")
local purchaseConfirmed = remotes:WaitForChild("PurchaseConfirmed")
local notify = remotes:WaitForChild("Notify")

local function passKeyForId(passId)
	for key, info in pairs(Config.PASSES) do
		if info.Id ~= 0 and info.Id == passId then
			return key
		end
	end
	return nil
end

local function productKeyForId(productId)
	for key, info in pairs(Config.PRODUCTS) do
		if info.Id ~= 0 and info.Id == productId then
			return key
		end
	end
	return nil
end

function MonetizationService.RefreshPasses(player)
	local flags = {}
	for key, info in pairs(Config.PASSES) do
		flags[key] = false
		if info.Id ~= 0 then
			local success, owns = pcall(function()
				return MarketplaceService:UserOwnsGamePassAsync(player.UserId, info.Id)
			end)
			if success then
				flags[key] = owns == true
			else
				warn(string.format("[Monetization] Could not check %s for %s", key, player.Name))
			end
		end
	end
	PlanetStateService.SetPassFlags(player, flags)
	return flags
end

function MonetizationService.ApplyStarterBenefit(player)
	local state = PlanetStateService.GetState(player)
	local flags = PlanetStateService.GetPassFlags(player)
	if not state or not flags.StarterPlanet or state.StarterPassApplied then
		return false
	end

	local available = {}
	for index, tileType in ipairs(state.Tiles) do
		if tileType == "Land" then
			table.insert(available, index)
		end
	end
	local rng = Random.new(player.UserId)
	for index = #available, 2, -1 do
		local swapIndex = rng:NextInteger(1, index)
		available[index], available[swapIndex] = available[swapIndex], available[index]
	end

	local cursor = 1
	for _ = 1, math.min(5, #available) do
		state.Tiles[available[cursor]] = "Water"
		cursor += 1
	end
	for _ = 1, 5 do
		if cursor > #available then
			break
		end
		state.Tiles[available[cursor]] = "Plant"
		cursor += 1
	end
	state.StarterPassApplied = true
	PlanetStateService.MarkChanged(player)
	return true
end

function MonetizationService.HandlePassPurchaseFinished(player, passId, purchased)
	if not purchased or not PlanetStateService.IsLoaded(player) then
		return
	end
	local key = passKeyForId(passId)
	if not key then
		return
	end
	local flags = PlanetStateService.GetPassFlags(player)
	flags[key] = true
	PlanetStateService.SetPassFlags(player, flags)
	if key == "StarterPlanet" then
		MonetizationService.ApplyStarterBenefit(player)
		MilestoneSystem.Check(player)
	end
	if key == "CosmicSkin" or key == "MoonCompanion" or key == "StarterPlanet" then
		PlanetRenderer.RefreshAppearance(player)
	end
	PlanetStateService.QueueSave(player)
	purchaseConfirmed:FireClient(player, passId)
	stateUpdated:FireClient(player, PlanetStateService.GetSummary(player))
	notify:FireClient(player, Config.PASSES[key].Name .. " activated!", "success")
end

local function applyCometStrike(player, state)
	local candidates = {}
	for index, tileType in ipairs(state.Tiles) do
		if tileType == "Land" then
			table.insert(candidates, index)
		end
	end
	local updates = {}
	for step = 1, math.min(3, #candidates) do
		local pick = math.random(1, #candidates)
		local tileIndex = table.remove(candidates, pick)
		local tileType = step % 2 == 1 and "Plant" or "Water"
		state.Tiles[tileIndex] = tileType
		PlanetRenderer.UpdateTile(player, tileIndex)
		table.insert(updates, { TileIndex = tileIndex, TileType = tileType })
	end
	return updates
end

function MonetizationService.ProcessReceipt(receiptInfo)
	local player = Players:GetPlayerByUserId(receiptInfo.PlayerId)
	if not player or not PlanetStateService.IsLoaded(player) then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local productKey = productKeyForId(receiptInfo.ProductId)
	if not productKey then
		warn(string.format("[Monetization] Unknown developer product ID %s", tostring(receiptInfo.ProductId)))
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local state = PlanetStateService.GetState(player)
	local purchaseId = tostring(receiptInfo.PurchaseId)
	if state.ProcessedReceipts[purchaseId] == true then
		if PlanetStateService.SavePlayer(player) then
			return Enum.ProductPurchaseDecision.PurchaseGranted
		end
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local tileUpdates = {}
	if productKey == "EnergyBoost" then
		state.Energy = math.min(Config.ENERGY_MAX, state.Energy + 500)
		PlanetStateService.MarkChanged(player)
	elseif productKey == "RareSeedPack" then
		state.RareSeedCharges += 3
		PlanetStateService.MarkChanged(player)
	elseif productKey == "CometStrike" then
		tileUpdates = applyCometStrike(player, state)
		PlanetStateService.MarkChanged(player)
	end

	state.ProcessedReceipts[purchaseId] = true
	PlanetStateService.MarkChanged(player)
	MilestoneSystem.Check(player)

	if not PlanetStateService.SavePlayer(player) then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	for _, update in ipairs(tileUpdates) do
		updateTile:FireClient(player, update)
	end
	updateEnergy:FireClient(player, state.Energy)
	stateUpdated:FireClient(player, PlanetStateService.GetSummary(player))
	purchaseConfirmed:FireClient(player, receiptInfo.ProductId)
	notify:FireClient(player, Config.PRODUCTS[productKey].Name .. " received!", "success")
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

return MonetizationService
