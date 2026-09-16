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
	if not data or data.SaveBlocked then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local purchaseId = tostring(receiptInfo.PurchaseId)
	if DataManager.hasPurchaseId(player, purchaseId) then
		-- A previous attempt may have granted the item but failed its final write.
		-- Retry persistence before acknowledging the receipt to Roblox.
		if DataManager.savePlayer(player) then
			return Enum.ProductPurchaseDecision.PurchaseGranted
		end
		return Enum.ProductPurchaseDecision.NotProcessedYet
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

	DataManager.recordPurchaseId(player, purchaseId)
	if not DataManager.savePlayer(player) then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	GameService.firePurchaseConfirmed(player, productId)
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

print("[Grow a Tiny Planet] Monetization ProcessReceipt ready")
