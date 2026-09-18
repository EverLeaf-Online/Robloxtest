--!strict

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
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
	button.BackgroundTransparency = 0.08
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
	local existing = playerGui:FindFirstChild("FactoryShop")
	if existing ~= nil then
		existing:Destroy()
	end

	local gui = Instance.new("ScreenGui")
	gui.Name = "FactoryShop"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = false
	gui.DisplayOrder = 30
	gui.Parent = playerGui

	local toggle = Instance.new("TextButton")
	toggle.Name = "ShopButton"
	toggle.AnchorPoint = Vector2.new(0, 0.5)
	toggle.Position = UDim2.new(0, 18, 0.72, 0)
	toggle.Size = UDim2.fromOffset(158, 54)
	toggle.BackgroundTransparency = 1
	toggle.BorderSizePixel = 0
	toggle.Text = ""
	toggle.AutoButtonColor = false
	toggle.Parent = gui

	local icon = HUDIconFactory.CreateShop(toggle, 50)
	icon.AnchorPoint = Vector2.new(0, 0.5)
	icon.Position = UDim2.fromScale(0, 0.5)

	local toggleLabel = Instance.new("TextLabel")
	toggleLabel.Name = "Label"
	toggleLabel.Position = UDim2.fromOffset(56, 8)
	toggleLabel.Size = UDim2.new(1, -82, 0, 18)
	toggleLabel.BackgroundTransparency = 1
	toggleLabel.Font = Enum.Font.GothamBold
	toggleLabel.Text = "FACTORY SHOP"
	toggleLabel.TextColor3 = Color3.fromRGB(245, 247, 250)
	toggleLabel.TextSize = 11
	toggleLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
	toggleLabel.TextStrokeTransparency = 0.28
	toggleLabel.TextXAlignment = Enum.TextXAlignment.Left
	toggleLabel.Parent = toggle

	local toggleHint = Instance.new("TextLabel")
	toggleHint.Name = "Hint"
	toggleHint.Position = UDim2.fromOffset(56, 27)
	toggleHint.Size = UDim2.new(1, -82, 0, 16)
	toggleHint.BackgroundTransparency = 1
	toggleHint.Font = Enum.Font.GothamBold
	toggleHint.Text = "OPEN"
	toggleHint.TextColor3 = Color3.fromRGB(104, 223, 151)
	toggleHint.TextSize = 10
	toggleHint.TextStrokeColor3 = Color3.new(0, 0, 0)
	toggleHint.TextStrokeTransparency = 0.28
	toggleHint.TextXAlignment = Enum.TextXAlignment.Left
	toggleHint.Parent = toggle

	local arrow = Instance.new("TextLabel")
	arrow.Name = "Arrow"
	arrow.AnchorPoint = Vector2.new(1, 0.5)
	arrow.Position = UDim2.fromScale(1, 0.5)
	arrow.Size = UDim2.fromOffset(22, 36)
	arrow.BackgroundTransparency = 1
	arrow.Font = Enum.Font.GothamBold
	arrow.Text = "›"
	arrow.TextColor3 = Color3.fromRGB(245, 247, 250)
	arrow.TextSize = 28
	arrow.TextStrokeColor3 = Color3.new(0, 0, 0)
	arrow.TextStrokeTransparency = 0.3
	arrow.Parent = toggle

	local shopPanel = Instance.new("ScrollingFrame")
	shopPanel.Name = "Panel"
	shopPanel.AnchorPoint = Vector2.new(0, 0.5)
	shopPanel.Position = UDim2.new(0, 188, 0.63, 0)
	shopPanel.Size = UDim2.fromOffset(0, 356)
	shopPanel.BackgroundColor3 = Color3.fromRGB(20, 23, 30)
	shopPanel.AutomaticCanvasSize = Enum.AutomaticSize.Y
	shopPanel.CanvasSize = UDim2.new()
	shopPanel.ScrollBarThickness = 4
	shopPanel.BackgroundTransparency = 0.12
	shopPanel.BorderSizePixel = 0
	shopPanel.ClipsDescendants = true
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

	local panelOpen = false
	local currentTween: Tween? = nil
	local function setOpen(open: boolean)
		panelOpen = open
		if currentTween ~= nil then
			currentTween:Cancel()
			currentTween = nil
		end
		if open then
			shopPanel.Visible = true
		end
		arrow.Text = if open then "‹" else "›"
		toggleHint.Text = if open then "CLOSE" else "OPEN"
		local targetWidth = if open then 310 else 0
		currentTween = TweenService:Create(
			shopPanel,
			TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ Size = UDim2.fromOffset(targetWidth, shopPanel.Size.Y.Offset) }
		)
		currentTween.Completed:Once(function()
			currentTween = nil
			if not panelOpen then
				shopPanel.Visible = false
			end
		end)
		currentTween:Play()
	end

	toggle.Activated:Connect(function()
		setOpen(not panelOpen)
	end)

	local viewportConnection: RBXScriptConnection? = nil
	local function bindCamera()
		if viewportConnection ~= nil then
			viewportConnection:Disconnect()
			viewportConnection = nil
		end
		local camera = Workspace.CurrentCamera
		if camera == nil then
			return
		end

		local function refreshLayout()
			local phone = camera.ViewportSize.X <= 760
			toggle.Position = if phone then UDim2.new(0, 10, 0.66, 0) else UDim2.new(0, 18, 0.72, 0)
			toggle.Size = if phone then UDim2.fromOffset(132, 48) else UDim2.fromOffset(158, 54)
			icon.Size = if phone then UDim2.fromOffset(42, 42) else UDim2.fromOffset(50, 50)
			toggleLabel.Position = if phone
				then UDim2.fromOffset(48, 5)
				else UDim2.fromOffset(56, 8)
			toggleHint.Position = if phone
				then UDim2.fromOffset(48, 23)
				else UDim2.fromOffset(56, 27)
			shopPanel.Position = if phone
				then UDim2.new(0, 154, 0.58, 0)
				else UDim2.new(0, 188, 0.63, 0)
			shopPanel.Size = if phone
				then UDim2.fromOffset(
					if panelOpen then 286 else 0,
					math.max(300, camera.ViewportSize.Y - 150)
				)
				else UDim2.fromOffset(if panelOpen then 310 else 0, 356)
		end

		refreshLayout()
		viewportConnection = camera:GetPropertyChangedSignal("ViewportSize"):Connect(refreshLayout)
	end

	bindCamera()
	Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(bindCamera)

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

return table.freeze(MonetizationShopController)
