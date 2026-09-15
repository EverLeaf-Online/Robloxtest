local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local player = Players.LocalPlayer
local remotes = ReplicatedFirst:WaitForChild("Remotes")
local applyAction = remotes:WaitForChild("ApplyAction")
local updateEnergy = remotes:WaitForChild("UpdateEnergy")
local updateTile = remotes:WaitForChild("UpdateTile")
local milestoneReached = remotes:WaitForChild("MilestoneReached")
local purchaseConfirmed = remotes:WaitForChild("PurchaseConfirmed")
local stateUpdated = remotes:WaitForChild("StateUpdated")
local notifyRemote = remotes:WaitForChild("Notify")
local getPlanetState = remotes:WaitForChild("GetPlanetState")

local planet = Workspace:WaitForChild("Planets"):WaitForChild("Planet_" .. player.UserId)
local tilesFolder = planet:WaitForChild("Tiles")
local state
local selectedTileIndex
local selectedHighlight
local mouseDownPosition

local gui = Instance.new("ScreenGui")
gui.Name = "GrowPlanetUI"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = player:WaitForChild("PlayerGui")

local function addCorner(instance, radius)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius or 10)
	corner.Parent = instance
end

local function addStroke(instance, color, transparency, thickness)
	local stroke = Instance.new("UIStroke")
	stroke.Color = color or Color3.fromRGB(70, 220, 255)
	stroke.Transparency = transparency or 0.35
	stroke.Thickness = thickness or 1
	stroke.Parent = instance
end

local function makeLabel(parent, text, size, position, fontSize, alignment)
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Text = text
	label.Size = size
	label.Position = position
	label.Font = Enum.Font.Gotham
	label.TextSize = fontSize or 16
	label.TextColor3 = Color3.fromRGB(225, 237, 255)
	label.TextXAlignment = alignment or Enum.TextXAlignment.Left
	label.TextWrapped = true
	label.Parent = parent
	return label
end

local function makeButton(parent, text, size, position)
	local button = Instance.new("TextButton")
	button.AutoButtonColor = false
	button.BackgroundColor3 = Color3.fromRGB(28, 47, 76)
	button.TextColor3 = Color3.fromRGB(236, 247, 255)
	button.Text = text
	button.Font = Enum.Font.GothamSemibold
	button.TextSize = 15
	button.Size = size
	button.Position = position
	button.Parent = parent
	addCorner(button, 9)
	addStroke(button, Color3.fromRGB(78, 213, 255), 0.45, 1)
	button.MouseEnter:Connect(function()
		if button.Active then
			TweenService:Create(button, TweenInfo.new(0.12), { BackgroundColor3 = Color3.fromRGB(38, 67, 103) }):Play()
		end
	end)
	button.MouseLeave:Connect(function()
		if button.Active then
			TweenService:Create(button, TweenInfo.new(0.12), { BackgroundColor3 = Color3.fromRGB(28, 47, 76) }):Play()
		end
	end)
	return button
end

local topBar = Instance.new("Frame")
topBar.Name = "TopBar"
topBar.BackgroundColor3 = Color3.fromRGB(10, 16, 33)
topBar.BackgroundTransparency = 0.08
topBar.Size = UDim2.new(0, 430, 0, 62)
topBar.Position = UDim2.new(0.5, -215, 0, 18)
topBar.Parent = gui
addCorner(topBar, 14)
addStroke(topBar, Color3.fromRGB(96, 225, 255), 0.3, 1.5)

local titleLabel = makeLabel(topBar, "GROW A TINY PLANET", UDim2.new(0, 245, 0, 28), UDim2.fromOffset(18, 8), 19)
titleLabel.Font = Enum.Font.GothamBold
local energyLabel = makeLabel(topBar, "⚡ Energy: --", UDim2.new(0, 190, 0, 26), UDim2.fromOffset(225, 8), 18, Enum.TextXAlignment.Right)
energyLabel.TextColor3 = Color3.fromRGB(104, 231, 255)
local targetLabel = makeLabel(topBar, "Target: Random tile", UDim2.new(1, -36, 0, 20), UDim2.fromOffset(18, 36), 13)
targetLabel.TextColor3 = Color3.fromRGB(165, 183, 211)

local actionPanel = Instance.new("Frame")
actionPanel.Name = "Actions"
actionPanel.BackgroundColor3 = Color3.fromRGB(10, 16, 33)
actionPanel.BackgroundTransparency = 0.06
actionPanel.Size = UDim2.fromOffset(255, 355)
actionPanel.Position = UDim2.new(0, 18, 0.5, -177)
actionPanel.Parent = gui
addCorner(actionPanel, 14)
addStroke(actionPanel, Color3.fromRGB(96, 225, 255), 0.4, 1)

local actionHeader = makeLabel(actionPanel, "PLANET ACTIONS", UDim2.new(1, -32, 0, 28), UDim2.fromOffset(16, 14), 17)
actionHeader.Font = Enum.Font.GothamBold

local buttons = {}
local actionDefinitions = {
	{ Key = "AddWater", Label = "💧 Add Water", Cost = Config.ACTION_COSTS.AddWater },
	{ Key = "AddPlants", Label = "🌱 Add Plants", Cost = Config.ACTION_COSTS.AddPlants },
	{ Key = "AddAnimals", Label = "🐾 Add Animals", Cost = Config.ACTION_COSTS.AddAnimals },
	{ Key = "BuildSettlement", Label = "🏠 Build Settlement", Cost = Config.ACTION_COSTS.BuildSettlement },
	{ Key = "TerraformBurst", Label = "✨ Terraform Burst", Cost = Config.ACTION_COSTS.TerraformBurst },
}

for index, definition in ipairs(actionDefinitions) do
	local button = makeButton(actionPanel, string.format("%s  •  %d Energy", definition.Label, definition.Cost), UDim2.new(1, -32, 0, 48), UDim2.fromOffset(16, 51 + (index - 1) * 56))
	button.Activated:Connect(function()
		if not state then
			return
		end
		applyAction:FireServer({
			actionType = definition.Key,
			tileIndex = selectedTileIndex,
		})
	end)
	buttons[definition.Key] = button
end

local hintLabel = makeLabel(actionPanel, "Click a surface tile to target it, or leave no target for a valid random tile.", UDim2.new(1, -32, 0, 44), UDim2.new(0, 16, 1, -52), 12)
hintLabel.TextColor3 = Color3.fromRGB(142, 159, 187)

local statsPanel = Instance.new("Frame")
statsPanel.Name = "Stats"
statsPanel.BackgroundColor3 = Color3.fromRGB(10, 16, 33)
statsPanel.BackgroundTransparency = 0.06
statsPanel.Size = UDim2.fromOffset(245, 210)
statsPanel.Position = UDim2.new(1, -263, 0.5, -105)
statsPanel.Parent = gui
addCorner(statsPanel, 14)
addStroke(statsPanel, Color3.fromRGB(153, 111, 255), 0.35, 1)

local statsHeader = makeLabel(statsPanel, "PLANET STATUS", UDim2.new(1, -28, 0, 28), UDim2.fromOffset(14, 13), 17)
statsHeader.Font = Enum.Font.GothamBold
local statsLabel = makeLabel(statsPanel, "Loading...", UDim2.new(1, -28, 0, 126), UDim2.fromOffset(14, 48), 14)
statsLabel.TextYAlignment = Enum.TextYAlignment.Top
local shopButton = makeButton(statsPanel, "🛒 Cosmic Shop  [B]", UDim2.new(1, -28, 0, 38), UDim2.new(0, 14, 1, -50))

local shop = Instance.new("Frame")
shop.Name = "Shop"
shop.Visible = false
shop.BackgroundColor3 = Color3.fromRGB(8, 12, 27)
shop.Size = UDim2.fromOffset(590, 500)
shop.Position = UDim2.new(0.5, -295, 0.5, -250)
shop.Parent = gui
addCorner(shop, 16)
addStroke(shop, Color3.fromRGB(159, 106, 255), 0.18, 2)

local shopHeader = makeLabel(shop, "COSMIC SHOP", UDim2.new(1, -80, 0, 35), UDim2.fromOffset(22, 16), 22)
shopHeader.Font = Enum.Font.GothamBold
local closeShop = makeButton(shop, "✕", UDim2.fromOffset(42, 36), UDim2.new(1, -58, 0, 14))
local shopSub = makeLabel(shop, "Permanent game passes and repeatable developer products", UDim2.new(1, -44, 0, 24), UDim2.fromOffset(22, 52), 13)
shopSub.TextColor3 = Color3.fromRGB(146, 163, 192)

local scrolling = Instance.new("ScrollingFrame")
scrolling.BackgroundTransparency = 1
scrolling.BorderSizePixel = 0
scrolling.Size = UDim2.new(1, -32, 1, -92)
scrolling.Position = UDim2.fromOffset(16, 82)
scrolling.ScrollBarThickness = 5
scrolling.ScrollBarImageColor3 = Color3.fromRGB(92, 211, 255)
scrolling.AutomaticCanvasSize = Enum.AutomaticSize.Y
scrolling.CanvasSize = UDim2.new()
scrolling.Parent = shop
local listLayout = Instance.new("UIListLayout")
listLayout.Padding = UDim.new(0, 10)
listLayout.Parent = scrolling

local function makeShopSection(text)
	local label = makeLabel(scrolling, text, UDim2.new(1, -8, 0, 30), UDim2.new(), 16)
	label.Font = Enum.Font.GothamBold
	label.TextColor3 = Color3.fromRGB(112, 224, 255)
	return label
end

local function makeShopItem(info, purchaseCallback)
	local card = Instance.new("Frame")
	card.BackgroundColor3 = Color3.fromRGB(17, 27, 50)
	card.Size = UDim2.new(1, -8, 0, 82)
	card.Parent = scrolling
	addCorner(card, 10)
	addStroke(card, Color3.fromRGB(100, 131, 188), 0.55, 1)
	local name = makeLabel(card, info.Name, UDim2.new(1, -160, 0, 24), UDim2.fromOffset(13, 9), 15)
	name.Font = Enum.Font.GothamSemibold
	local description = makeLabel(card, info.Description, UDim2.new(1, -160, 0, 42), UDim2.fromOffset(13, 32), 12)
	description.TextColor3 = Color3.fromRGB(156, 174, 203)
	local buy = makeButton(card, string.format("%d R$", info.Price), UDim2.fromOffset(120, 42), UDim2.new(1, -133, 0.5, -21))
	buy.Activated:Connect(function()
		purchaseCallback(info)
	end)
	return card
end

makeShopSection("GAME PASSES")
for _, key in ipairs({ "FastGrowth", "CosmicSkin", "StarterPlanet", "MoonCompanion" }) do
	local info = Config.PASSES[key]
	makeShopItem(info, function(item)
		if item.Id == 0 then
			notifyRemote:FireServer()
			return
		end
		MarketplaceService:PromptGamePassPurchase(player, item.Id)
	end)
end

makeShopSection("DEVELOPER PRODUCTS")
for _, key in ipairs({ "EnergyBoost", "RareSeedPack", "CometStrike" }) do
	local info = Config.PRODUCTS[key]
	makeShopItem(info, function(item)
		if item.Id == 0 then
			return
		end
		MarketplaceService:PromptProductPurchase(player, item.Id)
	end)
end

local toast = Instance.new("TextLabel")
toast.Name = "Toast"
toast.BackgroundColor3 = Color3.fromRGB(18, 31, 56)
toast.BackgroundTransparency = 1
toast.TextTransparency = 1
toast.TextColor3 = Color3.fromRGB(235, 245, 255)
toast.Font = Enum.Font.GothamSemibold
toast.TextSize = 15
toast.TextWrapped = true
toast.AnchorPoint = Vector2.new(0.5, 0)
toast.Size = UDim2.fromOffset(460, 52)
toast.Position = UDim2.new(0.5, 0, 0, 90)
toast.Parent = gui
addCorner(toast, 12)
addStroke(toast, Color3.fromRGB(96, 225, 255), 0.45, 1)

local toastGeneration = 0
local function showToast(message, kind)
	toastGeneration += 1
	local generation = toastGeneration
	toast.Text = tostring(message)
	if kind == "error" then
		toast.BackgroundColor3 = Color3.fromRGB(80, 31, 45)
	elseif kind == "warning" then
		toast.BackgroundColor3 = Color3.fromRGB(83, 62, 28)
	elseif kind == "milestone" then
		toast.BackgroundColor3 = Color3.fromRGB(57, 37, 98)
	else
		toast.BackgroundColor3 = Color3.fromRGB(18, 55, 69)
	end
	TweenService:Create(toast, TweenInfo.new(0.18), { BackgroundTransparency = 0.08, TextTransparency = 0 }):Play()
	task.delay(3.2, function()
		if toastGeneration ~= generation then
			return
		end
		TweenService:Create(toast, TweenInfo.new(0.25), { BackgroundTransparency = 1, TextTransparency = 1 }):Play()
	end)
end

local function setButtonEnabled(button, enabled, lockedText)
	button.Active = enabled
	button.Selectable = enabled
	if enabled then
		button.BackgroundColor3 = Color3.fromRGB(28, 47, 76)
		button.TextTransparency = 0
	else
		button.BackgroundColor3 = Color3.fromRGB(32, 35, 47)
		button.TextTransparency = 0.25
		if lockedText then
			button.Text = lockedText
		end
	end
end

local function refreshUI()
	if not state then
		return
	end
	energyLabel.Text = string.format("⚡ Energy: %d", state.Energy or 0)
	local counts = state.Counts or { Water = 0, Plant = 0, RarePlant = 0 }
	local plantCount = (counts.Plant or 0) + (counts.RarePlant or 0)
	statsLabel.Text = string.format(
		"Developed: %d / %d\n💧 Water: %d\n🌱 Plants: %d\n✨ Rare seeds: %d\n🐾 Animals: %d\n🏠 Settlements: %d",
		state.DevelopedTiles or 0,
		Config.TILE_COUNT,
		counts.Water or 0,
		plantCount,
		state.RareSeedCharges or 0,
		state.AnimalCount or (state.Animals and #state.Animals or 0),
		state.SettlementCount or (state.Settlements and #state.Settlements or 0)
	)

	local unlocks = state.Unlocks or {}
	for _, definition in ipairs(actionDefinitions) do
		local button = buttons[definition.Key]
		local unlocked = unlocks[definition.Key] ~= false
		local affordable = (state.Energy or 0) >= definition.Cost
		if unlocked then
			button.Text = string.format("%s  •  %d Energy", definition.Label, definition.Cost)
			setButtonEnabled(button, affordable, nil)
		else
			local threshold = Config.ACTION_UNLOCKS[definition.Key]
			setButtonEnabled(button, false, string.format("🔒 %s  •  %d tiles", definition.Label, threshold))
		end
	end
end

local function toggleShop(force)
	if type(force) == "boolean" then
		shop.Visible = force
	else
		shop.Visible = not shop.Visible
	end
end

shopButton.Activated:Connect(function()
	toggleShop()
end)
closeShop.Activated:Connect(function()
	toggleShop(false)
end)

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if input.KeyCode == Enum.KeyCode.B and not gameProcessed then
		toggleShop()
		return
	end
	if input.UserInputType == Enum.UserInputType.MouseButton1 and not gameProcessed then
		mouseDownPosition = UserInputService:GetMouseLocation()
	end
end)

UserInputService.InputEnded:Connect(function(input, gameProcessed)
	if input.UserInputType ~= Enum.UserInputType.MouseButton1 or gameProcessed or not mouseDownPosition then
		return
	end
	local mouseUp = UserInputService:GetMouseLocation()
	if (mouseUp - mouseDownPosition).Magnitude > 7 then
		mouseDownPosition = nil
		return
	end
	mouseDownPosition = nil

	local camera = Workspace.CurrentCamera
	local ray = camera:ViewportPointToRay(mouseUp.X, mouseUp.Y)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { tilesFolder }
	params.IgnoreWater = true
	local result = Workspace:Raycast(ray.Origin, ray.Direction * 1000, params)
	if result and result.Instance then
		local tileIndex = result.Instance:GetAttribute("TileIndex")
		if type(tileIndex) == "number" then
			selectedTileIndex = tileIndex
			targetLabel.Text = string.format("Target: Tile #%d (%s)", tileIndex, result.Instance:GetAttribute("TileType") or "Land")
			if selectedHighlight then
				selectedHighlight:Destroy()
			end
			selectedHighlight = Instance.new("Highlight")
			selectedHighlight.Name = "SelectedTileHighlight"
			selectedHighlight.Adornee = result.Instance
			selectedHighlight.FillColor = Color3.fromRGB(88, 232, 255)
			selectedHighlight.FillTransparency = 0.76
			selectedHighlight.OutlineColor = Color3.fromRGB(214, 250, 255)
			selectedHighlight.OutlineTransparency = 0
			selectedHighlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
			selectedHighlight.Parent = planet
		end
	end
end)

updateEnergy.OnClientEvent:Connect(function(energy)
	if state then
		state.Energy = energy
		refreshUI()
	end
end)

updateTile.OnClientEvent:Connect(function(update)
	if state and type(update) == "table" and type(update.TileIndex) == "number" then
		if state.Tiles then
			state.Tiles[update.TileIndex] = update.TileType
		end
		if selectedTileIndex == update.TileIndex then
			targetLabel.Text = string.format("Target: Tile #%d (%s)", update.TileIndex, update.TileType)
		end
	end
end)

stateUpdated.OnClientEvent:Connect(function(summary)
	if not state or type(summary) ~= "table" then
		return
	end
	for key, value in pairs(summary) do
		state[key] = value
	end
	refreshUI()
end)

milestoneReached.OnClientEvent:Connect(function(info)
	if type(info) == "table" then
		showToast((info.Title or "Milestone reached!") .. "  " .. (info.Message or ""), "milestone")
	end
end)

purchaseConfirmed.OnClientEvent:Connect(function()
	showToast("Purchase confirmed and applied.", "success")
end)

notifyRemote.OnClientEvent:Connect(function(message, kind)
	showToast(message, kind)
end)

local function loadInitialState()
	for _ = 1, 30 do
		local success, result = pcall(function()
			return getPlanetState:InvokeServer()
		end)
		if success and result then
			state = result
			refreshUI()
			return
		end
		task.wait(0.35)
	end
	showToast("Planet data could not be loaded. Rejoin and try again.", "error")
end

loadInitialState()

-- IDs are intentionally not invented. Shop entries with Id = 0 remain visible but do not prompt.
for _, info in pairs(Config.PASSES) do
	if info.Id == 0 then
		-- One concise warning in Studio output is more useful than invalid MarketplaceService calls.
		warn("[Grow a Tiny Planet] Configure Game Pass IDs in ReplicatedStorage/Shared/Config.lua")
		break
	end
end
