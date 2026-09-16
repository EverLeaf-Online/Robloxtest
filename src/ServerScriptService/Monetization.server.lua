-- ServerScriptService/Monetization.server.lua
-- Handles Developer Product receipts. Game Pass effects are applied on join.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local shared = ReplicatedStorage:WaitForChild("Shared")
local config = require(shared:WaitForChild("GameConfig"))

local DataManager = require(script.Parent:WaitForChild("DataManager"))
local GameService = require(script.Parent:WaitForChild("GameService"))

MarketplaceService.ProcessReceipt = function(receiptInfo)
	local player = Players:GetPlayerByUserId(receiptInfo.PlayerId)

	if not player or not GameService.isReady(player) then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local data = DataManager.getData(player)
	if not data then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	-- Idempotency check: do not grant the same receipt twice.
	if DataManager.hasPurchaseId(player, receiptInfo.PurchaseId) then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end

	local productId = receiptInfo.ProductId

	if productId == config.DEVELOPER_PRODUCTS.EnergyBoost and productId ~= 0 then
		GameService.addEnergy(player, 500)
		GameService.notifyPlayer(player, "Energy Boost", "+500 Energy added to your planet.")

	elseif productId == config.DEVELOPER_PRODUCTS.RareSeedPack and productId ~= 0 then
		GameService.addRareSeed(player)
		GameService.notifyPlayer(player, "Rare Seed Pack", "Glowing plants are now unlocked.")

	elseif productId == config.DEVELOPER_PRODUCTS.CometStrike and productId ~= 0 then
		GameService.addRandomDevelopedTiles(player, 3)
		GameService.notifyPlayer(player, "Comet Strike", "A comet developed 3 random tiles.")

	else
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	DataManager.recordPurchaseId(player, receiptInfo.PurchaseId)
	DataManager.savePlayer(player)
	GameService.firePurchaseConfirmed(player, productId)

	return Enum.ProductPurchaseDecision.PurchaseGranted
end

print("[Grow a Tiny Planet] Monetization ProcessReceipt ready")