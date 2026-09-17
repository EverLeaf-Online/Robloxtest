--!strict

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local RobloxIds = require(ReplicatedStorage.Shared.Config.RobloxIds)

local DataService = require(script.Parent.DataService)
local EconomyService = require(script.Parent.EconomyService)
local StateService = require(script.Parent.StateService)

local StudioTestService = {}
local initialized = false

local REMOTE_NAME = "StudioMonetizationTest"
local TEST_TOKEN_GRANT = 3
local TEST_FACTORY_CLUB_CYCLE = "StudioTestCycle"
local TEST_FACTORY_CLUB_COSMETIC = "Club_StudioTestCycle"
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

local function addMaterialBundle(data: any)
	data.Materials.ScrapMetal = math.min(GameConfig.Economy.MaxMaterialCount, data.Materials.ScrapMetal + 250)
	data.Materials.Wiring = math.min(GameConfig.Economy.MaxMaterialCount, data.Materials.Wiring + 75)
	data.Materials.PowerCoreFragments = math.min(
		GameConfig.Economy.MaxMaterialCount,
		data.Materials.PowerCoreFragments + 10
	)
end

local function addTokens(data: any, amount: number)
	data.Consumables.InstantProcessTokens = math.min(
		GameConfig.Economy.MaxInstantProcessTokens,
		data.Consumables.InstantProcessTokens + amount
	)
end

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

	local callback = MarketplaceService.ProcessReceipt
	if callback == nil then
		return false, "PROCESS_RECEIPT_NOT_BOUND"
	end

	local ok, decisionOrError = pcall(callback, {
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

local function setFactoryClubAttributes(player: Player, active: boolean, data: any)
	player:SetAttribute("FactoryClubActive", active)
	player:SetAttribute("FactoryClubNameplateEnabled", active)
	player:SetAttribute("FactoryClubNameplateText", if active then "FACTORY CLUB" else "")
	player:SetAttribute(
		"FactoryClubStorageMultiplier",
		if active then GameConfig.Factory.FactoryClubStorageMultiplier else 1
	)
	player:SetAttribute("InstantProcessTokens", data.Consumables.InstantProcessTokens)
	player:SetAttribute("FactoryClubLastGrantedCycle", data.Entitlements.FactoryClubLastGrantedCycle)
	player:SetAttribute("FactoryClubEquippedCosmetic", data.Entitlements.EquippedFactoryClubCosmetic)

	local cosmeticCount = 0
	for _ in data.Entitlements.FactoryClubCosmetics do
		cosmeticCount += 1
	end
	player:SetAttribute("FactoryClubCosmeticCount", cosmeticCount)
end

local function setFactoryClub(player: Player, active: boolean): (boolean, string)
	local granted = false
	local executed = DataService.Transaction(player, function(data)
		EconomyService.SetRuntimeStorageMultiplier(
			data,
			if active then GameConfig.Factory.FactoryClubStorageMultiplier else 1
		)

		if active and data.Entitlements.FactoryClubLastGrantedCycle ~= TEST_FACTORY_CLUB_CYCLE then
			addMaterialBundle(data)
			addTokens(data, 3)
			data.Entitlements.FactoryClubLastGrantedCycle = TEST_FACTORY_CLUB_CYCLE
			data.Entitlements.FactoryClubCosmetics[TEST_FACTORY_CLUB_COSMETIC] = true
			if data.Entitlements.EquippedFactoryClubCosmetic == "" then
				data.Entitlements.EquippedFactoryClubCosmetic = TEST_FACTORY_CLUB_COSMETIC
			end
			granted = true
		end

		return true, nil
	end)
	if not executed then
		return false, "FACTORY_CLUB_TRANSACTION_FAILED"
	end

	local data = DataService.GetData(player)
	if data == nil then
		return false, "PROFILE_NOT_READY"
	end

	setFactoryClubAttributes(player, active, data)
	StateService.PushSnapshot(player)

	if active then
		return true, if granted then "FACTORY_CLUB_ENABLED_AND_GRANTED" else "FACTORY_CLUB_ENABLED_NO_DUPLICATE"
	end
	return true, "FACTORY_CLUB_DISABLED"
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
