--!strict

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local RemoteNames = require(ReplicatedStorage.Shared.Networking.RemoteNames)
local RobloxIds = require(ReplicatedStorage.Shared.Config.RobloxIds)
local HUDIconFactory = require(script.Parent.Parent.UI.HUDIconFactory)

local MonetizationShopController = {}
local initialized = false

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local stateRemote = remotes:WaitForChild(RemoteNames.StateSnapshot) :: RemoteEvent

local productButtons: { [string]: TextButton } = {}
local starterPackClaimed = false
local statusLabel: TextLabel? = nil

local PRODUCT_ROWS = {
	{
		Key = "MaterialSupplyCrate",
		Label = "Material Supply Crate",
		Id = RobloxIds.DeveloperProducts.MaterialSupplyCrate,
	},
	{
		Key = "FactoryOverclock15m",
		Label = "15-Min Factory Overclock",
		Id = RobloxIds.DeveloperProducts.FactoryOverclock15m,
	},
	{
		Key = "InstantProcessTokens",
		Label = "+5 Instant Process Tokens",
		Id = RobloxIds.DeveloperProducts.InstantProcessTokens,
	},
	{ Key = "StarterPack", Label = "Starter Pack", Id = RobloxIds.DeveloperProducts.StarterPack },
	{
		Key = "ServerOverclock",
		Label = "Server Overclock",
		Id = RobloxIds.DeveloperProducts.ServerOverclock,
	},
}

local function formatDuration(seconds: number): string
	seconds = math.max(0, math.floor(seconds))
	local minutes = math.floor(seconds / 60)
	local remainder = seconds % 60
	return ("%02d:%02d"):format(minutes, remainder)
end

local function refreshStatus()
	local label = statusLabel
	if label == nil then
		return
	end

	local now = os.time()
	local tokens = tonumber(player:GetAttribute("InstantProcessTokens")) or 0
	local personalUntil = tonumber(player:GetAttribute("PersonalOverclockUntil")) or 0
	local serverUntil = tonumber(Workspace:GetAttribute("ServerOverclockUntil")) or 0
	label.Text = ("TOKENS %d   PERSONAL %s   SERVER %s"):format(
		tokens,
		formatDuration(personalUntil - now),
		formatDuration(serverUntil - now)
	)
end

local function setStarterPackVisibility()
	local button = productButtons.StarterPack
	if button ~= nil then
		button.Visible = not starterPackClaimed
	end
end

local function promptProduct(productId: number)
	local ok, err =
		pcall(MarketplaceService.PromptProductPurchase, MarketplaceService, player, productId)
	if not ok then
		warn(
			("[MonetizationShopController] Product prompt failed for %d: %s"):format(
				productId,
				tostring(err)
			)
		)
	end
end

local function promptFactoryClub()
	local ok, err = pcall(
		MarketplaceService.PromptSubscriptionPurchase,
		MarketplaceService,
		player,
		RobloxIds.Subscription.FactoryClub
	)
	if not ok then
		warn(("[MonetizationShopController] Factory Club prompt failed: %s"):format(tostring(err)))
	end
end

local function makeButton(parent: Instance, name: string, label: string, order: number): TextButton
	local button = Instance.new("TextButton")
	button.Name = name
	button.LayoutOrder = order
	button.Size = UDim2.new(1, 0, 0, 38)
	button.BackgroundColor3 = Color3.fromRGB(46, 54, 70)
	button.BorderSizePixel = 0
	button.Font = Enum.Font.GothamBold
	button.Text = label
	button.TextColor3 = Color3.fromRGB(245, 247, 250)
	button.TextSize = 12
	button.TextWrapped = true
	button.Parent = parent

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 7)
	corner.Parent = button
	return button
end

local function refreshPrice(button: TextButton, baseLabel: string, productId: number)
	task.spawn(function()
		local ok, infoOrError = pcall(
			MarketplaceService.GetProductInfo,
			MarketplaceService,
			productId,
			Enum.InfoType.Product
		)
		if not ok or typeof(infoOrError) ~= "table" then
			return
		end
		local price = (infoOrError :: any).PriceInRobux
		if typeof(price) == "number" and price >= 0 then
			button.Text = ("%s  •  %d R$"):format(baseLabel, price)
		end
	end)
end

local function applySnapshot(snapshot: any)
	if typeof(snapshot) ~= "table" then
		return
	end
	local entitlements = snapshot.Entitlements
	if typeof(entitlements) == "table" then
		starterPackClaimed = entitlements.StarterPackClaimed == true
		setStarterPackVisibility()
	end
	refreshStatus()
end

local function createUi()
	local playerGui = player:WaitForChild("PlayerGui") :: PlayerGui
	local gui = Instance.new("ScreenGui")
	gui.Name = "FactoryShop"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = false
	gui.DisplayOrder = 30
	gui.Parent = playerGui

	local toggle = Instance.new("TextButton")
	toggle.Name = "ShopButton"
	toggle.Position = UDim2.fromOffset(16, 118)
	toggle.Size = UDim2.fromOffset(70, 78)
	toggle.BackgroundTransparency = 1
	toggle.BorderSizePixel = 0
	toggle.Text = ""
	toggle.AutoButtonColor = false
	toggle.Parent = gui

	local iconPlate = HUDIconFactory.CreateShop(toggle, 54)

	local toggleLabel = Instance.new("TextLabel")
	toggleLabel.Name = "Label"
	toggleLabel.AnchorPoint = Vector2.new(0.5, 1)
	toggleLabel.Position = UDim2.fromScale(0.5, 1)
	toggleLabel.Size = UDim2.new(1, 0, 0, 20)
	toggleLabel.BackgroundTransparency = 1
	toggleLabel.Font = Enum.Font.GothamBold
	toggleLabel.Text = "SHOP"
	toggleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	toggleLabel.TextSize = 12
	toggleLabel.TextStrokeTransparency = 0.35
	toggleLabel.Parent = toggle

	local shopPanel = Instance.new("ScrollingFrame")
	shopPanel.Name = "Panel"
	shopPanel.AnchorPoint = Vector2.new(1, 0)
	shopPanel.Position = UDim2.new(1, -14, 0, 52)
	shopPanel.Size = UDim2.fromOffset(310, 356)
	shopPanel.BackgroundColor3 = Color3.fromRGB(20, 23, 30)
	shopPanel.AutomaticCanvasSize = Enum.AutomaticSize.Y
	shopPanel.CanvasSize = UDim2.new()
	shopPanel.ScrollBarThickness = 4
	shopPanel.BackgroundTransparency = 0.04
	shopPanel.BorderSizePixel = 0
	shopPanel.Visible = false
	shopPanel.Parent = gui

	local panelCorner = Instance.new("UICorner")
	panelCorner.CornerRadius = UDim.new(0, 10)
	panelCorner.Parent = shopPanel

	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 10)
	padding.PaddingBottom = UDim.new(0, 10)
	padding.PaddingLeft = UDim.new(0, 10)
	padding.PaddingRight = UDim.new(0, 10)
	padding.Parent = shopPanel

	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 6)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = shopPanel

	local title = Instance.new("TextLabel")
	title.LayoutOrder = 0
	title.Size = UDim2.new(1, 0, 0, 26)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.GothamBold
	title.Text = "FACTORY SHOP"
	title.TextColor3 = Color3.fromRGB(245, 247, 250)
	title.TextSize = 16
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Parent = shopPanel

	local status = Instance.new("TextLabel")
	status.LayoutOrder = 1
	status.Size = UDim2.new(1, 0, 0, 34)
	status.BackgroundTransparency = 1
	status.Font = Enum.Font.Gotham
	status.TextColor3 = Color3.fromRGB(178, 188, 204)
	status.TextSize = 11
	status.TextWrapped = true
	status.TextXAlignment = Enum.TextXAlignment.Left
	status.Parent = shopPanel
	statusLabel = status

	for index, row in PRODUCT_ROWS do
		local button = makeButton(shopPanel, row.Key, row.Label, index + 1)
		productButtons[row.Key] = button
		button.Activated:Connect(function()
			if row.Key == "StarterPack" and starterPackClaimed then
				return
			end
			promptProduct(row.Id)
		end)
		refreshPrice(button, row.Label, row.Id)
	end

	local clubButton =
		makeButton(shopPanel, "FactoryClub", "FACTORY CLUB  •  49 R$/MONTH", #PRODUCT_ROWS + 2)
	clubButton.BackgroundColor3 = Color3.fromRGB(112, 77, 154)
	clubButton.Activated:Connect(promptFactoryClub)

	toggle.Activated:Connect(function()
		shopPanel.Visible = not shopPanel.Visible
	end)

	local function refreshLayout()
		local camera = Workspace.CurrentCamera
		if camera == nil then
			return
		end
		local viewport = camera.ViewportSize
		local phone = viewport.X <= 760
		toggle.Position = if phone then UDim2.fromOffset(12, 104) else UDim2.fromOffset(16, 118)
		toggle.Size = if phone then UDim2.fromOffset(62, 70) else UDim2.fromOffset(70, 78)
		iconPlate.Size = if phone then UDim2.fromOffset(48, 48) else UDim2.fromOffset(54, 54)
		shopPanel.Size = if phone then UDim2.new(0.48, 0, 1, -64) else UDim2.fromOffset(310, 356)
	end
	refreshLayout()
	local camera = Workspace.CurrentCamera
	if camera ~= nil then
		camera:GetPropertyChangedSignal("ViewportSize"):Connect(refreshLayout)
	end

	setStarterPackVisibility()
	refreshStatus()
end

function MonetizationShopController.Init()
	if initialized then
		return
	end
	initialized = true

	createUi()
	stateRemote.OnClientEvent:Connect(applySnapshot)
	player:GetAttributeChangedSignal("InstantProcessTokens"):Connect(refreshStatus)
	player:GetAttributeChangedSignal("PersonalOverclockUntil"):Connect(refreshStatus)
	Workspace:GetAttributeChangedSignal("ServerOverclockUntil"):Connect(refreshStatus)

	task.spawn(function()
		while initialized do
			task.wait(1)
			refreshStatus()
		end
	end)
end

return MonetizationShopController
