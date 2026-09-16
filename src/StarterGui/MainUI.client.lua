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

local state = nil
local queuedEnergy = nil
local queuedTileUpdates = {}
local queuedSummary = nil
local toastGeneration = 0

local ACTIONS = {
	{ Key = "AddWater", Label = "Add Water", Icon = "💧", Cost = Config.ACTION_COSTS.AddWater, Shortcut = Enum.KeyCode.One },
	{ Key = "AddPlants", Label = "Add Plants", Icon = "🌱", Cost = Config.ACTION_COSTS.AddPlants, Shortcut = Enum.KeyCode.Two },
	{ Key = "AddAnimals", Label = "Add Animals", Icon = "🐾", Cost = Config.ACTION_COSTS.AddAnimals, Shortcut = Enum.KeyCode.Three },
	{ Key = "BuildSettlement", Label = "Build Settlement", Icon = "🏠", Cost = Config.ACTION_COSTS.BuildSettlement, Shortcut = Enum.KeyCode.Four },
	{ Key = "TerraformBurst", Label = "Terraform Burst", Icon = "✨", Cost = Config.ACTION_COSTS.TerraformBurst, Shortcut = Enum.KeyCode.Five, Global = true },
}

local ACTION_BY_KEY = {}
for _, definition in ipairs(ACTIONS) do
	ACTION_BY_KEY[definition.Key] = definition
end

local gui = Instance.new("ScreenGui")
gui.Name = "GrowPlanetUI"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.DisplayOrder = 20
gui.Parent = player:WaitForChild("PlayerGui")

local uiScale = Instance.new("UIScale")
uiScale.Parent = gui

local function updateUIScale()
	local camera = Workspace.CurrentCamera
	if not camera then
		uiScale.Scale = 1
		return
	end
	local viewport = camera.ViewportSize
	local scale = math.min(viewport.X / 1440, viewport.Y / 900)
	uiScale.Scale = math.clamp(scale, 0.72, 1)
end

updateUIScale()
Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(updateUIScale)
if Workspace.CurrentCamera then
	Workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(updateUIScale)
end

local function addCorner(instance, radius)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius or 10)
	corner.Parent = instance
end

local function addStroke(instance, color, transparency, thickness)
	local stroke = Instance.new("UIStroke")
	stroke.Color = color or Color3.fromRGB(82, 210, 255)
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
	label.TextColor3 = Color3.fromRGB(230, 239, 255)
	label.TextXAlignment = alignment or Enum.TextXAlignment.Left
	label.TextYAlignment = Enum.TextYAlignment.Center
	label.TextWrapped = true
	label.Parent = parent
	return label
end

local function makeButton(parent, text, size, position)
	local button = Instance.new("TextButton")
	button.AutoButtonColor = false
	button.BackgroundColor3 = Color3.fromRGB(26, 48, 78)
	button.TextColor3 = Color3.fromRGB(238, 247, 255)
	button.Text = text
	button.Font = Enum.Font.GothamSemibold
	button.TextSize = 14
	button.Size = size
	button.Position = position
	button.Parent = parent
	addCorner(button, 9)
	addStroke(button, Color3.fromRGB(77, 207, 255), 0.5, 1)
	return button
end

local function makePanel(name, size, position)
	local panel = Instance.new("Frame")
	panel.Name = name
	panel.BackgroundColor3 = Color3.fromRGB(8, 15, 31)
	panel.BackgroundTransparency = 0.04
	panel.Size = size
	panel.Position = position
	panel.Parent = gui
	addCorner(panel, 14)
	addStroke(panel, Color3.fromRGB(91, 205, 255), 0.38, 1)
	return panel
end

local topBar = makePanel("TopBar", UDim2.fromOffset(560, 72), UDim2.new(0.5, -280, 0, 16))
local titleLabel = makeLabel(topBar, "GROW A TINY PLANET", UDim2.fromOffset(280, 28), UDim2.fromOffset(18, 8), 19)
titleLabel.Font = Enum.Font.GothamBold
local energyLabel = makeLabel(topBar, "⚡ Energy: loading...", UDim2.fromOffset(230, 28), UDim2.new(1, -248, 0, 8), 17, Enum.TextXAlignment.Right)
energyLabel.TextColor3 = Color3.fromRGB(105, 230, 255)
local stageLabel = makeLabel(topBar, "Loading planet state...", UDim2.new(1, -36, 0, 22), UDim2.fromOffset(18, 40), 12)
stageLabel.TextColor3 = Color3.fromRGB(157, 178, 209)

local actionPanel = makePanel("Actions", UDim2.fromOffset(290, 430), UDim2.new(0, 18, 0.5, -215))
local actionHeader = makeLabel(actionPanel, "GROWTH TOOLS", UDim2.new(1, -32, 0, 26), UDim2.fromOffset(16, 13), 17)
actionHeader.Font = Enum.Font.GothamBold
local actionSub = makeLabel(actionPanel, "Choose a tool, then click the planet.", UDim2.new(1, -32, 0, 32), UDim2.fromOffset(16, 39), 12)
actionSub.TextColor3 = Color3.fromRGB(150, 171, 201)
actionSub.TextYAlignment = Enum.TextYAlignment.Top

local actionButtons = {}
for index, definition in ipairs(ACTIONS) do
	local shortcutNumber = tostring(index)
	local button = makeButton(
		actionPanel,
		string.format("[%s]  %s %s  •  %d Energy", shortcutNumber, definition.Icon, definition.Label, definition.Cost),
		UDim2.new(1, -32, 0, 48),
		UDim2.fromOffset(16, 76 + (index - 1) * 55)
	)
	actionButtons[definition.Key] = button
end

local randomButton = makeButton(actionPanel, "🎲 Apply selected tool randomly [R]", UDim2.new(1, -32, 0, 40), UDim2.fromOffset(16, 356))
randomButton.Visible = false
local actionHint = makeLabel(actionPanel, "Click any point on the sphere to select the nearest surface tile. Drag to orbit.", UDim2.new(1, -32, 0, 36), UDim2.fromOffset(16, 399), 11)
actionHint.TextColor3 = Color3.fromRGB(133, 153, 183)
actionHint.TextYAlignment = Enum.TextYAlignment.Top

local statsPanel = makePanel("Stats", UDim2.fromOffset(280, 292), UDim2.new(1, -298, 0.5, -146))
local statsHeader = makeLabel(statsPanel, "PLANET STATUS", UDim2.new(1, -28, 0, 28), UDim2.fromOffset(14, 12), 17)
statsHeader.Font = Enum.Font.GothamBold
local statsLabel = makeLabel(statsPanel, "Loading...", UDim2.new(1, -28, 0, 150), UDim2.fromOffset(14, 45), 13)
statsLabel.TextYAlignment = Enum.TextYAlignment.Top
local objectiveHeader = makeLabel(statsPanel, "NEXT OBJECTIVE", UDim2.new(1, -28, 0, 22), UDim2.fromOffset(14, 195), 12)
objectiveHeader.Font = Enum.Font.GothamBold
objectiveHeader.TextColor3 = Color3.fromRGB(110, 229, 255)
local objectiveLabel = makeLabel(statsPanel, "Create your first water or plant tile.", UDim2.new(1, -28, 0, 45), UDim2.fromOffset(14, 218), 11)
objectiveLabel.TextColor3 = Color3.fromRGB(176, 192, 217)
objectiveLabel.TextYAlignment = Enum.TextYAlignment.Top
local shopButton = makeButton(statsPanel, "🛒 Cosmic Shop [B]", UDim2.new(1, -28, 0, 38), UDim2.new(0, 14, 1, -49))

local inspector = makePanel("TileInspector", UDim2.fromOffset(560, 176), UDim2.new(0.5, -280, 1, -230))
inspector.Visible = false
local inspectorTitle = makeLabel(inspector, "SURFACE TILE", UDim2.fromOffset(250, 26), UDim2.fromOffset(16, 12), 16)
inspectorTitle.Font = Enum.Font.GothamBold
local inspectorType = makeLabel(inspector, "", UDim2.fromOffset(250, 24), UDim2.new(1, -266, 0, 12), 14, Enum.TextXAlignment.Right)
inspectorType.TextColor3 = Color3.fromRGB(110, 229, 255)
local inspectorDescription = makeLabel(inspector, "", UDim2.new(1, -32, 0, 34), UDim2.fromOffset(16, 39), 12)
inspectorDescription.TextColor3 = Color3.fromRGB(164, 183, 210)
inspectorDescription.TextYAlignment = Enum.TextYAlignment.Top

local inspectorButtons = {}
local inspectorActionKeys = { "AddWater", "AddPlants", "AddAnimals", "BuildSettlement" }
for index, actionKey in ipairs(inspectorActionKeys) do
	local definition = ACTION_BY_KEY[actionKey]
	local column = (index - 1) % 2
	local row = math.floor((index - 1) / 2)
	local button = makeButton(
		inspector,
		string.format("%s %s", definition.Icon, definition.Label),
		UDim2.fromOffset(250, 38),
		UDim2.fromOffset(16 + column * 264, 78 + row * 44)
	)
	inspectorButtons[actionKey] = button
end

local clearTargetButton = makeButton(inspector, "Clear target", UDim2.fromOffset(100, 26), UDim2.new(1, -116, 1, -31))
clearTargetButton.TextSize = 11

local toast = Instance.new("TextLabel")
toast.Name = "Toast"
toast.BackgroundColor3 = Color3.fromRGB(18, 55, 69)
toast.BackgroundTransparency = 1
toast.TextTransparency = 1
toast.TextColor3 = Color3.fromRGB(236, 246, 255)
toast.Font = Enum.Font.GothamSemibold
toast.TextSize = 14
toast.TextWrapped = true
toast.AnchorPoint = Vector2.new(0.5, 0)
toast.Size = UDim2.fromOffset(540, 54)
toast.Position = UDim2.new(0.5, 0, 0, 96)
toast.ZIndex = 100
toast.Parent = gui
addCorner(toast, 12)
addStroke(toast, Color3.fromRGB(96, 225, 255), 0.4, 1)

local tutorial = makePanel("Tutorial", UDim2.fromOffset(560, 42), UDim2.new(0.5, -280, 1, -48))
tutorial.BackgroundTransparency = 0.12
local tutorialText = makeLabel(tutorial, "Click the planet to select a tile. Choose Water or Plants to begin.", UDim2.new(1, -24, 1, 0), UDim2.fromOffset(12, 0), 12, Enum.TextXAlignment.Center)

local shop = makePanel("Shop", UDim2.fromOffset(610, 520), UDim2.new(0.5, -305, 0.5, -260))
shop.Visible = false
shop.ZIndex = 50
local shopHeader = makeLabel(shop, "COSMIC SHOP", UDim2.new(1, -85, 0, 34), UDim2.fromOffset(22, 16), 22)
shopHeader.Font = Enum.Font.GothamBold
shopHeader.ZIndex = 52
local shopSub = makeLabel(shop, "Permanent passes and repeatable boosts", UDim2.new(1, -90, 0, 24), UDim2.fromOffset(22, 51), 13)
shopSub.TextColor3 = Color3.fromRGB(147, 164, 193)
shopSub.ZIndex = 52
local closeShop = makeButton(shop, "✕", UDim2.fromOffset(42, 36), UDim2.new(1, -58, 0, 14))
closeShop.ZIndex = 53

local scrolling = Instance.new("ScrollingFrame")
scrolling.BackgroundTransparency = 1
scrolling.BorderSizePixel = 0
scrolling.Size = UDim2.new(1, -32, 1, -90)
scrolling.Position = UDim2.fromOffset(16, 80)
scrolling.ScrollBarThickness = 5
scrolling.ScrollBarImageColor3 = Color3.fromRGB(92, 211, 255)
scrolling.AutomaticCanvasSize = Enum.AutomaticSize.Y
scrolling.CanvasSize = UDim2.new()
scrolling.ZIndex = 51
scrolling.Parent = shop
local listLayout = Instance.new("UIListLayout")
listLayout.Padding = UDim.new(0, 10)
listLayout.Parent = scrolling

local function showToast(message, kind)
	toastGeneration += 1
	local generation = toastGeneration
	toast.Text = tostring(message)

	if kind == "error" then
		toast.BackgroundColor3 = Color3.fromRGB(84, 31, 45)
	elseif kind == "warning" then
		toast.BackgroundColor3 = Color3.fromRGB(86, 64, 28)
	elseif kind == "milestone" then
		toast.BackgroundColor3 = Color3.fromRGB(59, 40, 103)
	else
		toast.BackgroundColor3 = Color3.fromRGB(18, 55, 69)
	end

	TweenService:Create(toast, TweenInfo.new(0.15), {
		BackgroundTransparency = 0.05,
		TextTransparency = 0,
	}):Play()

	task.delay(3.3, function()
		if toastGeneration ~= generation then
			return
		end
		TweenService:Create(toast, TweenInfo.new(0.22), {
			BackgroundTransparency = 1,
			TextTransparency = 1,
		}):Play()
	end)
end

local function setEnabled(button, enabled)
	button.Active = enabled
	button.Selectable = enabled
	button.TextTransparency = enabled and 0 or 0.45
	button.BackgroundColor3 = enabled and Color3.fromRGB(26, 48, 78) or Color3.fromRGB(30, 33, 44)
end

local function currentSelectedTile()
	local value = player:GetAttribute("PlanetSelectedTile")
	if type(value) == "number" and value >= 1 and value <= Config.TILE_COUNT then
		return math.floor(value)
	end
	return nil
end

local function currentPendingAction()
	local value = player:GetAttribute("PlanetPendingAction")
	if type(value) == "string" and ACTION_BY_KEY[value] then
		return value
	end
	return nil
end

local function getStage(developed)
	local chosen = Config.PLANET_STAGES[1]
	for _, stage in ipairs(Config.PLANET_STAGES) do
		if developed >= stage.MinDeveloped then
			chosen = stage
		else
			break
		end
	end
	return chosen
end

local function refreshActionButtons()
	if not state then
		return
	end

	local unlocks = state.Unlocks or {}
	local pendingAction = currentPendingAction()

	for index, definition in ipairs(ACTIONS) do
		local button = actionButtons[definition.Key]
		local unlocked = unlocks[definition.Key] ~= false
		local affordable = (state.Energy or 0) >= definition.Cost
		setEnabled(button, unlocked and affordable)

		if not unlocked then
			button.Text = string.format("🔒 [%d] %s • unlock at %d tiles", index, definition.Label, Config.ACTION_UNLOCKS[definition.Key])
		elseif pendingAction == definition.Key then
			button.Text = string.format("🎯 [%d] %s — CLICK PLANET", index, definition.Label)
			button.BackgroundColor3 = Color3.fromRGB(31, 91, 111)
		else
			button.Text = string.format("[%d]  %s %s • %d Energy", index, definition.Icon, definition.Label, definition.Cost)
		end
	end

	randomButton.Visible = pendingAction ~= nil and pendingAction ~= "TerraformBurst"
end

local function refreshInspector()
	if not state then
		inspector.Visible = false
		return
	end

	local tileIndex = currentSelectedTile()
	if not tileIndex then
		inspector.Visible = false
		return
	end

	local tileType = state.Tiles and state.Tiles[tileIndex] or player:GetAttribute("PlanetSelectedTileType") or "Land"
	player:SetAttribute("PlanetSelectedTileType", tileType)

	inspector.Visible = true
	inspectorTitle.Text = string.format("SURFACE TILE #%d", tileIndex)
	inspectorType.Text = string.upper(tileType)

	if tileType == "Land" then
		inspectorDescription.Text = "Bare land. Add water or plants to physically develop this exact tile."
	elseif tileType == "Water" then
		inspectorDescription.Text = "Water habitat. Fish become valid after 3 water tiles and the animal unlock."
	elseif tileType == "RarePlant" then
		inspectorDescription.Text = "Rare glowing vegetation. Supports land animals and settlements."
	else
		inspectorDescription.Text = "Vegetated habitat. Supports land animals and can anchor a settlement."
	end

	local unlocks = state.Unlocks or {}
	local counts = state.Counts or {}
	local plantCount = (counts.Plant or 0) + (counts.RarePlant or 0)
	local canFish = (counts.Water or 0) >= 3
	local canLandAnimal = plantCount >= 5
	local energy = state.Energy or 0

	setEnabled(inspectorButtons.AddWater, tileType == "Land" and energy >= Config.ACTION_COSTS.AddWater)
	setEnabled(inspectorButtons.AddPlants, tileType == "Land" and energy >= Config.ACTION_COSTS.AddPlants)
	setEnabled(
		inspectorButtons.AddAnimals,
		unlocks.AddAnimals == true
			and energy >= Config.ACTION_COSTS.AddAnimals
			and ((tileType == "Water" and canFish) or ((tileType == "Plant" or tileType == "RarePlant") and canLandAnimal))
	)
	setEnabled(
		inspectorButtons.BuildSettlement,
		unlocks.BuildSettlement == true
			and energy >= Config.ACTION_COSTS.BuildSettlement
			and (tileType == "Plant" or tileType == "RarePlant")
	)
end

local function refreshUI()
	if not state then
		return
	end

	local energy = state.Energy or 0
	local developed = state.DevelopedTiles or 0
	local counts = state.Counts or {}
	local plantCount = (counts.Plant or 0) + (counts.RarePlant or 0)
	local animalCount = state.AnimalCount or (state.Animals and #state.Animals or 0)
	local settlementCount = state.SettlementCount or (state.Settlements and #state.Settlements or 0)
	local stage = getStage(developed)

	energyLabel.Text = string.format("⚡ Energy: %d", energy)
	stageLabel.Text = string.format("%s • %d/%d surface tiles developed", stage.Name, developed, Config.TILE_COUNT)
	statsLabel.Text = string.format(
		"Stage: %s\nDeveloped: %d / %d\n💧 Water: %d\n🌱 Plants: %d\n🐾 Animals: %d\n🏠 Settlements: %d\n✨ Rare seeds: %d",
		stage.Name,
		developed,
		Config.TILE_COUNT,
		counts.Water or 0,
		plantCount,
		animalCount,
		settlementCount,
		state.RareSeedCharges or 0
	)

	if developed < 10 then
		objectiveLabel.Text = string.format("Develop %d more tiles to unlock animals.", 10 - developed)
	elseif developed < 25 then
		objectiveLabel.Text = string.format("Develop %d more tiles to unlock settlements.", 25 - developed)
	elseif developed < 50 then
		objectiveLabel.Text = string.format("Develop %d more tiles to unlock Terraform Burst.", 50 - developed)
	else
		objectiveLabel.Text = "Keep building toward a 100-tile Garden World."
	end

	if developed == 0 then
		tutorialText.Text = "Click anywhere on the planet, then choose Water or Plants."
	elseif developed < 10 then
		tutorialText.Text = "Fast placement: click a growth tool first, then click the planet."
	else
		tutorialText.Text = "Rotate, zoom, and build habitats across the whole sphere."
	end

	refreshActionButtons()
	refreshInspector()
end

local function fireAction(actionKey, tileIndex)
	if not state then
		showToast("Planet data is still loading.", "warning")
		return
	end
	applyAction:FireServer({
		actionType = actionKey,
		tileIndex = tileIndex,
	})
end

local function chooseAction(actionKey)
	local definition = ACTION_BY_KEY[actionKey]
	if not definition then
		return
	end

	if definition.Global then
		player:SetAttribute("PlanetPendingAction", "")
		fireAction(actionKey, nil)
		return
	end

	local selectedTile = currentSelectedTile()
	if selectedTile then
		fireAction(actionKey, selectedTile)
		return
	end

	player:SetAttribute("PlanetPendingAction", actionKey)
	showToast(definition.Label .. " selected — click the planet to place it.", "success")
	refreshActionButtons()
end

for _, definition in ipairs(ACTIONS) do
	local button = actionButtons[definition.Key]
	button.Activated:Connect(function()
		if button.Active then
			chooseAction(definition.Key)
		end
	end)
end

for actionKey, button in pairs(inspectorButtons) do
	button.Activated:Connect(function()
		local tileIndex = currentSelectedTile()
		if button.Active and tileIndex then
			fireAction(actionKey, tileIndex)
		end
	end)
end

randomButton.Activated:Connect(function()
	local pendingAction = currentPendingAction()
	if pendingAction then
		player:SetAttribute("PlanetPendingAction", "")
		fireAction(pendingAction, nil)
	end
end)

clearTargetButton.Activated:Connect(function()
	player:SetAttribute("PlanetSelectedTile", 0)
	player:SetAttribute("PlanetSelectedTileType", "")
	refreshInspector()
end)

local function makeShopSection(text)
	local label = makeLabel(scrolling, text, UDim2.new(1, -8, 0, 30), UDim2.new(), 16)
	label.Font = Enum.Font.GothamBold
	label.TextColor3 = Color3.fromRGB(112, 224, 255)
	label.ZIndex = 52
end

local function makeShopItem(info, purchaseCallback)
	local card = Instance.new("Frame")
	card.BackgroundColor3 = Color3.fromRGB(17, 27, 50)
	card.Size = UDim2.new(1, -8, 0, 84)
	card.ZIndex = 52
	card.Parent = scrolling
	addCorner(card, 10)
	addStroke(card, Color3.fromRGB(100, 131, 188), 0.55, 1)

	local name = makeLabel(card, info.Name, UDim2.new(1, -160, 0, 24), UDim2.fromOffset(13, 8), 15)
	name.Font = Enum.Font.GothamSemibold
	name.ZIndex = 53
	local description = makeLabel(card, info.Description, UDim2.new(1, -160, 0, 44), UDim2.fromOffset(13, 31), 12)
	description.TextColor3 = Color3.fromRGB(156, 174, 203)
	description.ZIndex = 53
	local buy = makeButton(card, string.format("%d R$", info.Price), UDim2.fromOffset(120, 42), UDim2.new(1, -133, 0.5, -21))
	buy.ZIndex = 53
	buy.Activated:Connect(function()
		purchaseCallback(info)
	end)
end

makeShopSection("GAME PASSES")
for _, key in ipairs({ "FastGrowth", "CosmicSkin", "StarterPlanet", "MoonCompanion" }) do
	local info = Config.PASSES[key]
	makeShopItem(info, function(item)
		if item.Id == 0 then
			showToast(item.Name .. " is not configured with a Roblox Game Pass ID yet.", "warning")
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
			showToast(item.Name .. " is not configured with a Roblox Developer Product ID yet.", "warning")
			return
		end
		MarketplaceService:PromptProductPurchase(player, item.Id)
	end)
end

local function toggleShop()
	shop.Visible = not shop.Visible
end

shopButton.Activated:Connect(toggleShop)
closeShop.Activated:Connect(function()
	shop.Visible = false
end)

local shortcutActions = {
	[Enum.KeyCode.One] = "AddWater",
	[Enum.KeyCode.Two] = "AddPlants",
	[Enum.KeyCode.Three] = "AddAnimals",
	[Enum.KeyCode.Four] = "BuildSettlement",
	[Enum.KeyCode.Five] = "TerraformBurst",
}

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then
		return
	end

	if input.KeyCode == Enum.KeyCode.B then
		toggleShop()
		return
	end
	if input.KeyCode == Enum.KeyCode.Escape then
		player:SetAttribute("PlanetSelectedTile", 0)
		player:SetAttribute("PlanetSelectedTileType", "")
		player:SetAttribute("PlanetPendingAction", "")
		refreshUI()
		return
	end
	if input.KeyCode == Enum.KeyCode.R then
		local pendingAction = currentPendingAction()
		if pendingAction then
			player:SetAttribute("PlanetPendingAction", "")
			fireAction(pendingAction, nil)
		end
		return
	end

	local actionKey = shortcutActions[input.KeyCode]
	if actionKey then
		chooseAction(actionKey)
	end
end)

player:GetAttributeChangedSignal("PlanetSelectedTile"):Connect(function()
	refreshInspector()
end)
player:GetAttributeChangedSignal("PlanetSelectedTileType"):Connect(function()
	refreshInspector()
end)
player:GetAttributeChangedSignal("PlanetPendingAction"):Connect(function()
	refreshActionButtons()
end)

updateEnergy.OnClientEvent:Connect(function(energy)
	if state then
		state.Energy = energy
		refreshUI()
	else
		queuedEnergy = energy
	end
end)

updateTile.OnClientEvent:Connect(function(update)
	if type(update) ~= "table" or type(update.TileIndex) ~= "number" then
		return
	end
	if state and state.Tiles then
		state.Tiles[update.TileIndex] = update.TileType
	else
		table.insert(queuedTileUpdates, update)
	end
	if currentSelectedTile() == update.TileIndex then
		player:SetAttribute("PlanetSelectedTileType", update.TileType)
	end
	refreshInspector()
end)

stateUpdated.OnClientEvent:Connect(function(summary)
	if type(summary) ~= "table" then
		return
	end
	if state then
		for key, value in pairs(summary) do
			state[key] = value
		end
		refreshUI()
	else
		queuedSummary = summary
	end
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
	for _ = 1, 60 do
		local success, result = pcall(function()
			return getPlanetState:InvokeServer()
		end)
		if success and result then
			state = result

			if queuedEnergy ~= nil then
				state.Energy = queuedEnergy
			end
			if queuedSummary then
				for key, value in pairs(queuedSummary) do
					state[key] = value
				end
			end
			for _, update in ipairs(queuedTileUpdates) do
				if state.Tiles then
					state.Tiles[update.TileIndex] = update.TileType
				end
			end

			queuedEnergy = nil
			queuedSummary = nil
			queuedTileUpdates = {}
			refreshUI()
			return
		end
		task.wait(0.2)
	end

	energyLabel.Text = "⚡ Energy: unavailable"
	stageLabel.Text = "Planet state failed to load."
	showToast("Planet data could not be loaded. Stop and Play again.", "error")
end

loadInitialState()

for _, info in pairs(Config.PASSES) do
	if info.Id == 0 then
		warn("[Grow a Tiny Planet] Configure Marketplace IDs in ReplicatedStorage/Shared/Config.lua before production.")
		break
	end
end
