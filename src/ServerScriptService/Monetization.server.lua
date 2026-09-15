local MarketplaceService = game:GetService("MarketplaceService")

local MonetizationService = require(script.Parent.MonetizationService)

MarketplaceService.ProcessReceipt = function(receiptInfo)
	return MonetizationService.ProcessReceipt(receiptInfo)
end

MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
	MonetizationService.HandlePassPurchaseFinished(player, passId, purchased)
end)
