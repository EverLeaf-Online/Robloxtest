--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local RobloxIds = require(ReplicatedStorage.Shared.Config.RobloxIds)

local DataService = require(script.Parent.DataService)
local MonetizationService = require(script.Parent.MonetizationService)
local ReferralService = require(script.Parent.ReferralService)
local StateService = require(script.Parent.StateService)

local StudioTestService = {}
local initialized = false

local REMOTE_NAME = "StudioMonetizationTest"
local TEST_TOKEN_GRANT = 3
local MIN_REQUEST_INTERVAL = 0.15

local lastRequestAt: { [Player]: number } = {}
local receiptSequence = 0

local PRODUCT_IDS: { [string]: number } = {
	MaterialSupplyCrate = RobloxIds.DeveloperProducts.MaterialSupplyCrate,
	FactoryOverclock15m = RobloxIds.DeveloperProducts.FactoryOverclock15m,
	InstantProcessTokens = RobloxIds.DeveloperProducts.InstantProcessTokens,
	StarterPack = RobloxIds.DeveloperProducts.StarterPack,
	ServerOverclock = RobloxIds.DeveloperProducts.ServerOverclock,
}

local function grantTestTokens(player: Player)
	local executed = DataService.Transaction(player, function(data)
		if data.Consumables.InstantProcessTokens > 0 then
			return true, data.Consumables.InstantProcessTokens
		end

		data.Consumables.InstantProcessTokens = TEST_TOKEN_GRANT
		return true, TEST_TOKEN_GRANT
	end)

	if not executed then
		return
	end

	local data = DataService.GetData(player)
	if data ~= nil then
		player:SetAttribute("InstantProcessTokens", data.Consumables.InstantProcessTokens)
	end
end

local function nextPurchaseId(player: Player, productName: string): string
	receiptSequence += 1
	return ("StudioTest-%d-%s-%d-%d"):format(
		player.UserId,
		productName,
		os.time(),
		receiptSequence
	)
end

local function testDeveloperProduct(player: Player, productName: string): (boolean, string)
	local productId = PRODUCT_IDS[productName]
	if productId == nil then
		return false, "UNKNOWN_TEST_PRODUCT"
	end

	local ok, decisionOrError = pcall(MonetizationService.ProcessReceiptForStudio, {
		PlayerId = player.UserId,
		PurchaseId = nextPurchaseId(player, productName),
		ProductId = productId,
	})
	if not ok then
		warn(("[StudioTestService] Receipt simulation failed: %s"):format(tostring(decisionOrError)))
		return false, "RECEIPT_SIMULATION_FAILED"
	end

	if decisionOrError ~= Enum.ProductPurchaseDecision.PurchaseGranted then
		return false, "RECEIPT_NOT_GRANTED"
	end

	return true, productName
end

local function setFactoryClub(player: Player, active: boolean): (boolean, string)
	return MonetizationService.SetFactoryClubForStudio(player, active)
end

local function canHandleRequest(player: Player): boolean
	local now = os.clock()
	local previous = lastRequestAt[player] or 0
	if now - previous < MIN_REQUEST_INTERVAL then
		return false
	end
	lastRequestAt[player] = now
	return true
end

function StudioTestService.Init()
	if initialized then
		return
	end
	initialized = true

	if not RunService:IsStudio() then
		return
	end

	local remotes = ReplicatedStorage:WaitForChild("Remotes")
	local existing = remotes:FindFirstChild(REMOTE_NAME)
	local remote: RemoteEvent
	if existing ~= nil then
		assert(existing:IsA("RemoteEvent"), ("%s must be a RemoteEvent"):format(REMOTE_NAME))
		remote = existing
	else
		remote = Instance.new("RemoteEvent")
		remote.Name = REMOTE_NAME
		remote.Parent = remotes
	end

	remote.OnServerEvent:Connect(function(player, action)
		if not RunService:IsStudio() or not DataService.IsReady(player) then
			return
		end
		if typeof(action) ~= "string" or #action > 64 or not canHandleRequest(player) then
			return
		end

		local success = false
		local code = "UNKNOWN_TEST_ACTION"
		if PRODUCT_IDS[action] ~= nil then
			success, code = testDeveloperProduct(player, action)
		elseif action == "FactoryClubOn" then
			success, code = setFactoryClub(player, true)
		elseif action == "FactoryClubOff" then
			success, code = setFactoryClub(player, false)
		elseif action == "ReferralReward" then
			success, code = ReferralService.StudioGrantQualifiedReferral(player)
		end

		remote:FireClient(player, "Result", action, success, code)
	end)

	DataService.ProfileLoaded:Connect(function(player)
		grantTestTokens(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		lastRequestAt[player] = nil
	end)
end

return StudioTestService