-- StarterGui/UIManager.client.lua
-- Creates the full space-themed UI: main panel, action buttons, shop, notifications.

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ReplicatedFirst = game:GetService("ReplicatedFirst")

local shared = ReplicatedStorage:WaitForChild("Shared")
local config = require(shared:WaitForChild("GameConfig"))
local ClientState = require(shared:WaitForChild("ClientState"))

local remotes = ReplicatedFirst:WaitForChild("Remotes", 30)
if not remotes then
	return
end

local applyAction = remotes:WaitForChild("ApplyAction")
local updateEnergy = remotes:WaitForChild("UpdateEnergy")
local updateStats = remotes:WaitForChild("UpdateStats")
local milestoneReached = remotes:WaitForChild("MilestoneReached")
local notifyRemote = remotes:WaitForChild("Notify")
local purchaseConfirmed = remotes:WaitForChild("PurchaseConfirmed")
local getPlanetState = remotes:WaitForChild("GetPlanetState")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local gui = Instance.new("ScreenGui")
gui.Name = "GrowTinyPlanetGui"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 10
gui.Parent = playerGui

local function addCorner(parent, radius)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius or 10)
	corner.Parent = parent
	return corner
end

local function addStroke(parent, color)
	local stroke = Instance.new("UIStroke")
	stroke.Color = color or config.COLORS.UI.Accent
	stroke.Thickness = 1.5
	stroke.Transparency = 0.25
	stroke.Parent = parent
	return stroke
end

local function makeLabel(props)
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.Gotham
	label.TextColor3 = config.COLORS.UI.Text
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextYAlignment = Enum.TextYAlignment.Center
	label.TextWrapped = true

	for key, value in pairs(props) do
		label[key] = value
	end

	return label
end

-- Main panel
local main = Instance.new("Frame")
main.Name = "MainPanel"
main.Size = UDim2.new(0, 320, 0, 540)
main.Position = UDim2.new(0, 16, 0, 16)
main.BackgroundColor3 = config.COLORS.UI.Background
main.BackgroundTransparency = 0.06
main.BorderSizePixel = 0
main.Parent = gui

addCorner(main, 12)
addStroke(main, config.COLORS.UI.Accent)

local titleLabel = makeLabel({
	Text = "Grow a Tiny Planet",
	Font = Enum.Font.GothamBold,
	TextSize = 22,
	Size = UDim2.new(1, -20, 0, 32),
	Position = UDim2.new(0, 10, 0, 8),
	TextXAlignment = Enum.TextXAlignment.Center,
	Parent = main,
})

local energyLabel = makeLabel({
	Text = "Energy: " .. tostring(config.START_ENERGY),
	TextSize = 18,
	Font = Enum.Font.GothamBold,
	Size = UDim2.new(1, -20, 0, 24),
	Position = UDim2.new(0, 10, 0, 44),
	Parent = main,
})

local statsLabel = makeLabel({
	Text = "Waiting for planet data...",
	TextSize = 14,
	Size = UDim2.new(1, -20, 0, 96),
	Position = UDim2.new(0, 10, 0, 72),
	Parent = main,
})

local selectedLabel = makeLabel({
	Text = "Selected tile: none",
	TextSize = 13,
	Size = UDim2.new(1, -20, 0, 20),
	Position = UDim2.new(0, 10, 0, 172),
	Parent = main,
})

local buttonFrame = Instance.new("Frame")
buttonFrame.Name = "Buttons"
buttonFrame.Size = UDim2.new(1, -20, 0, 320)
buttonFrame.Position = UDim2.new(0, 10, 0, 200)
buttonFrame.BackgroundTransparency = 1
buttonFrame.Parent = main

local buttonLayout = Instance.new("UIListLayout")
buttonLayout.Padding = UDim.new(0, 8)
buttonLayout.SortOrder = Enum.SortOrder.LayoutOrder
buttonLayout.Parent = buttonFrame

local function createButton(text, order)
	local button = Instance.new("TextButton")
	button.Size = UDim2.new(1, 0, 0, 48)
	button.BackgroundColor3 = config.COLORS.UI.Button
	button.BorderSizePixel = 0
	button.Text = text
	button.TextWrapped = true
	button.TextColor3 = config.COLORS.UI.Text
	button.Font = Enum.Font.GothamMedium
	button.TextSize = 16
	button.LayoutOrder = order
	button.Parent = buttonFrame

	addCorner(button, 10)
	addStroke(button, config.COLORS.UI.Accent2)

	return button
end

local waterButton = createButton("Add Water", 1)
local plantButton = createButton("Add Plants", 2)
local animalButton = createButton("Add Animal", 3)
local settlementButton = createButton("Build Settlement", 4)
local shopButton = createButton("Shop (B)", 5)

waterButton.MouseButton1Click:Connect(function()
	applyAction:FireServer(config.ACTIONS.AddWater, ClientState.SelectedTile)
end)

plantButton.MouseButton1Click:Connect(function()
	applyAction:FireServer(config.ACTIONS.AddPlant, ClientState.SelectedTile)
end)

animalButton.MouseButton1Click:Connect(function()
	applyAction:FireServer(config.ACTIONS.AddAnimal, ClientState.SelectedTile)
end)

settlementButton.MouseButton1Click:Connect(function()
	applyAction:FireServer(config.ACTIONS.BuildSettlement, ClientState.SelectedTile)
end)

-- Shop panel
local shop = Instance.new("Frame")
shop.Name = "ShopPanel"
shop.Size = UDim2.new(0, 360, 0, 520)
shop.Position = UDim2.new(1, -376, 0.5, -260)
shop.BackgroundColor3 = config.COLORS.UI.Background
shop.BackgroundTransparency = 0.05
shop.BorderSizePixel = 0
shop.Visible = false
shop.Parent = gui

addCorner(shop, 12)
addStroke(shop, config.COLORS.UI.Accent2)

local shopTitle = makeLabel({
	Text = "Cosmic Shop",
	Font = Enum.Font.GothamBold,
	TextSize = 22,
	Size = UDim2.new(1, -100, 0, 34),
	Position = UDim2.new(0, 12, 0, 8),
	TextXAlignment = Enum.TextXAlignment.Left,
	Parent = shop,
})

local closeButton = Instance.new("TextButton")
closeButton.Size = UDim2.new(0, 70, 0, 30)
closeButton.Position = UDim2.new(1, -82, 0, 10)
closeButton.BackgroundColor3 = config.COLORS.UI.Button
closeButton.BorderSizePixel = 0
closeButton.Text = "Close"
closeButton.Font = Enum.Font.GothamBold
closeButton.TextSize = 15
closeButton.TextColor3 = config.COLORS.UI.Text
closeButton.Parent = shop

addCorner(closeButton, 8)

closeButton.MouseButton1Click:Connect(function()
	shop.Visible = false
end)

local shopList = Instance.new("ScrollingFrame")
shopList.Size = UDim2.new(1, -20, 1, -58)
shopList.Position = UDim2.new(0, 10, 0, 50)
shopList.BackgroundTransparency = 1
shopList.BorderSizePixel = 0
shopList.ScrollBarThickness = 6
shopList.CanvasSize = UDim2.new(0, 0, 0, 1000)
shopList.Parent = shop

local shopLayout = Instance.new("UIListLayout")
shopLayout.Padding = UDim.new(0, 8)
shopLayout.SortOrder = Enum.SortOrder.LayoutOrder
shopLayout.Parent = shopList

local passItems = {}

local function addShopItem(entry, isPass, order)
	local item = Instance.new("Frame")
	item.Size = UDim2.new(1, -10, 0, 86)
	item.BackgroundColor3 = config.COLORS.UI.Button
	item.BackgroundTransparency = 0.35
	item.BorderSizePixel = 0
	item.LayoutOrder = order
	item.Parent = shopList

	addCorner(item, 10)

	makeLabel({
		Text = entry.Name,
		Font = Enum.Font.GothamBold,
		TextSize = 16,
		Size = UDim2.new(1, -120, 0, 22),
		Position = UDim2.new(0, 10, 0, 6),
		Parent = item,
	})

	makeLabel({
		Text = entry.Description,
		TextSize = 13,
		Size = UDim2.new(1, -120, 0, 42),
		Position = UDim2.new(0, 10, 0, 30),
		Parent = item,
	})

	makeLabel({
		Text = entry.Price,
		Font = Enum.Font.GothamBold,
		TextSize = 14,
		Size = UDim2.new(0, 100, 0, 22),
		Position = UDim2.new(1, -110, 0, 6),
		TextXAlignment = Enum.TextXAlignment.Right,
		Parent = item,
	})

	local buyButton = Instance.new("TextButton")
	buyButton.Size = UDim2.new(0, 100, 0, 36)
	buyButton.Position = UDim2.new(1, -110, 0, 40)
	buyButton.BackgroundColor3 = config.COLORS.UI.Accent
	buyButton.BorderSizePixel = 0
	buyButton.Text = "Buy"
	buyButton.Font = Enum.Font.GothamBold
	buyButton.TextSize = 16
	buyButton.TextColor3 = Color3.fromRGB(10, 12, 20)
	buyButton.Parent = item

	addCorner(buyButton, 8)

	if entry.Id == 0 then
		buyButton.Text = "Disabled"
		buyButton.BackgroundColor3 = config.COLORS.UI.ButtonDisabled
		buyButton.TextColor3 = config.COLORS.UI.Text
	else
		buyButton.MouseButton1Click:Connect(function()
			if isPass then
				MarketplaceService:PromptGamePassPurchase(player, entry.Id)
			else
				MarketplaceService:PromptProductPurchase(player, entry.Id)
			end
		end)
	end

	if isPass then
		table.insert(passItems, {
			Key = entry.Key,
			Button = buyButton,
		})
	end
end

for i, entry in ipairs(config.SHOP.GamePasses) do
	addShopItem(entry, true, i)
end

for i, entry in ipairs(config.SHOP.Products) do
	addShopItem(entry, false, 100 + i)
end

-- Notifications
local notifHolder = Instance.new("Frame")
notifHolder.AnchorPoint = Vector2.new(1, 1)
notifHolder.Position = UDim2.new(1, -16, 1, -16)
notifHolder.Size = UDim2.new(0, 300, 0, 0)
notifHolder.AutomaticSize = Enum.AutomaticSize.Y
notifHolder.BackgroundTransparency = 1
notifHolder.Parent = gui

local notifLayout = Instance.new("UIListLayout")
notifLayout.Padding = UDim.new(0, 8)
notifLayout.SortOrder = Enum.SortOrder.LayoutOrder
notifLayout.VerticalAlignment = Enum.VerticalAlignment.Bottom
notifLayout.Parent = notifHolder

local notifOrder = 0

local function notify(title, message)
	notifOrder += 1

	local note = Instance.new("Frame")
	note.Size = UDim2.new(1, 0, 0, 64)
	note.BackgroundColor3 = config.COLORS.UI.Background
	note.BackgroundTransparency = 0.08
	note.BorderSizePixel = 0
	note.LayoutOrder = notifOrder
	note.Parent = notifHolder

	addCorner(note, 10)
	addStroke(note, config.COLORS.UI.Accent2)

	local noteTitle = makeLabel({
		Text = title,
		Font = Enum.Font.GothamBold,
		TextSize = 15,
		Size = UDim2.new(1, -16, 0, 20),
		Position = UDim2.new(0, 8, 0, 6),
		Parent = note,
	})

	local noteMessage = makeLabel({
		Text = message,
		TextSize = 13,
		Size = UDim2.new(1, -16, 0, 30),
		Position = UDim2.new(0, 8, 0, 28),
		Parent = note,
	})

	task.delay(5, function()
		for _ = 1, 12 do
			note.BackgroundTransparency = math.min(1, note.BackgroundTransparency + 0.08)
			noteTitle.TextTransparency = math.min(1, noteTitle.TextTransparency + 0.08)
			noteMessage.TextTransparency = math.min(1, noteMessage.TextTransparency + 0.08)
			task.wait(0.03)
		end

		note:Destroy()
	end)
end

shopButton.MouseButton1Click:Connect(function()
	shop.Visible = not shop.Visible
end)

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then
		return
	end

	if input.KeyCode == Enum.KeyCode.B then
		shop.Visible = not shop.Visible
	end
end)

local function updateSelectedLabel()
	if ClientState.SelectedTile >= 0 then
		selectedLabel.Text = "Selected tile: " .. tostring(ClientState.SelectedTile)
	else
		selectedLabel.Text = "Selected tile: none (click a planet tile)"
	end
end

local function updateShopOwnership()
	for _, item in ipairs(passItems) do
		if ClientState.Ownership[item.Key] then
			item.Button.Text = "Owned"
			item.Button.AutoButtonColor = false
			item.Button.BackgroundColor3 = config.COLORS.UI.ButtonDisabled
			item.Button.TextColor3 = config.COLORS.UI.Text
		end
	end
end

local function updateStatsLabel()
	local stats = ClientState.Stats

	if not stats then
		statsLabel.Text = "Waiting for planet data..."
		return
	end

	statsLabel.Text = string.format(
		"Developed: %d\nWater: %d | Plants: %d\nGlow: %d\nAnimals: %d | Settlements: %d",
		stats.Developed or 0,
		stats.Water or 0,
		(stats.Plants or 0) + (stats.Glow or 0),
		stats.Glow or 0,
		stats.Animals or 0,
		stats.Settlements or 0
	)
end

local function refreshButtons()
	local energy = ClientState.Energy or 0
	local stats = ClientState.Stats or {}
	local unlocks = stats.Unlocks or {}

	local function refresh(button, cost, unlocked, baseText, lockedText)
		local canUse = unlocked and energy >= cost

		button.AutoButtonColor = canUse
		button.BackgroundColor3 = canUse and config.COLORS.UI.Button or config.COLORS.UI.ButtonDisabled
		button.TextTransparency = canUse and 0 or 0.35

		if unlocked then
			button.Text = baseText .. "\nCost " .. tostring(cost)
		else
			button.Text = lockedText
		end
	end

	refresh(waterButton, config.COSTS.AddWater, true, "Add Water", "Add Water")
	refresh(plantButton, config.COSTS.AddPlant, true, "Add Plants", "Add Plants")
	refresh(animalButton, config.COSTS.AddAnimal, unlocks.Animal == true, "Add Animal", "Add Animal\nLocked: 10 developed tiles")
	refresh(settlementButton, config.COSTS.BuildSettlement, unlocks.Settlement == true, "Build Settlement", "Build Settlement\nLocked: 25 developed tiles")
end

ClientState.Changed:Connect(function(key, value)
	if key == "SelectedTile" then
		updateSelectedLabel()
	elseif key == "Energy" then
		energyLabel.Text = "Energy: " .. tostring(value)
		refreshButtons()
	elseif key == "Stats" then
		updateStatsLabel()
		refreshButtons()
		updateShopOwnership()
	elseif key == "Ownership" then
		updateShopOwnership()
	end
end)

updateEnergy.OnClientEvent:Connect(function(value)
	ClientState:SetEnergy(value)
end)

updateStats.OnClientEvent:Connect(function(stats)
	ClientState:SetStats(stats)
end)

milestoneReached.OnClientEvent:Connect(function(info)
	if typeof(info) == "table" then
		notify(info.Title or "Milestone", info.Message or "Milestone reached.")
	end
end)

notifyRemote.OnClientEvent:Connect(function(info)
	if typeof(info) == "table" then
		notify(info.Title or "Notice", info.Message or "")
	end
end)

purchaseConfirmed.OnClientEvent:Connect(function(_productId)
	notify("Purchase Confirmed", "Thank you for supporting your tiny planet!")
end)

-- Initial state fetch.
task.spawn(function()
	for _ = 1, 60 do
		local ok, state = pcall(function()
			return getPlanetState:InvokeServer()
		end)

		if ok and typeof(state) == "table" then
			ClientState:SetEnergy(state.Energy or 0)
			ClientState:SetStats(state.Stats)
			ClientState:SetOwnership(state.Ownership or {})
			break
		end

		task.wait(1)
	end
end)