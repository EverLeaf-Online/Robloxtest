local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local TileGeometry = require(ReplicatedStorage.Shared.TileGeometry)

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
local core = planet:WaitForChild("Core")
local tilesFolder = planet:WaitForChild("Tiles")

local state
local selectedTileIndex
local selectedHighlight
local pendingAction
local mouseDownPosition
local toastGeneration = 0

local ACTIONS = {
	{ Key = "AddWater", Label = "Add Water", Icon = "💧", Cost = Config.ACTION_COSTS.AddWater, Shortcut = "1" },
	{ Key = "AddPlants", Label = "Add Plants", Icon = "🌱", Cost = Config.ACTION_COSTS.AddPlants, Shortcut = "2" },
	{ Key = "AddAnimals", Label = "Add Animals", Icon = "🐾", Cost = Config.ACTION_COSTS.AddAnimals, Shortcut = "3" },
	{ Key = "BuildSettlement", Label = "Build Settlement", Icon = "🏠", Cost = Config.ACTION_COSTS.BuildSettlement, Shortcut = "4" },
	{ Key = "TerraformBurst", Label = "Terraform Burst", Icon = "✨", Cost = Config.ACTION_COSTS.TerraformBurst, Shortcut = "5", Global = true },
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

local function addCorner(instance, radius)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius or 10)
	corner.Parent = instance
	return corner
end

local function addStroke(instance, color, transparency, thickness)
	local stroke = Instance.new("UIStroke")
	stroke.Color = color or Color3.fromRGB(70, 220, 255)
	stroke.Transparency = transparency or 0.35
	stroke.Thickness = thickness or 1
	stroke.Parent = instance
	return stroke
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
	label.TextYAlignment = Enum.TextYAlignment.Center
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
	button.TextSize = 14
	button.Size = size
	button.Position = position
	button.Parent = parent
	addCorner(button, 9)
	addStroke(button, Color3.fromRGB(78, 213, 255), 0.5, 1)
	return button
end

local function makePanel(name, size, position, parent)
	local frame = Instance.new("Frame")
	frame.Name = name
	frame.BackgroundColor3 = Color3.fromRGB(9, 15, 31)
	frame.BackgroundTransparency = 0.05
	frame.Size = size
	frame.Position = position
	frame.Parent = parent or gui
	addCorner(frame, 14)
	addStroke(frame, Color3.fromRGB(88, 202, 255), 0.38, 1)
	return frame
end

local topBar = makePanel("TopBar", UDim2.fromOffset(520, 72), UDim2.new(0.5, -260, 0, 16))
local titleLabel = makeLabel(topBar, "GROW A TINY PLANET", UDim2.fromOffset(265, 28), UDim2.fromOffset(18, 8), 19)
titleLabel.Font = Enum.Font.GothamBold
local energyLabel = makeLabel(topBar, "⚡ Energy: loading...", UDim2.fromOffset(220, 28), UDim2.new(1, -238, 0, 8), 17, Enum.TextXAlignment.Right)
energyLabel.TextColor3 = Color3.fromRGB(111, 229, 255)
local stageLabel = makeLabel(topBar, "Preparing your world...", UDim2.new(1, -36, 0, 24), UDim2.fromOffset(18, 39), 12)
stageLabel.TextColor3 = Color3.fromRGB(157, 178, 209)

local actionPanel = makePanel("Actions", UDim2.fromOffset(280, 450), UDim2.new(0, 18, 0.5, -225))
local actionHeader = makeLabel(actionPanel, "GROWTH TOOLS", UDim2.new(1, -32, 0, 26), UDim2.fromOffset(16, 13), 17)
actionHeader.Font = Enum.Font.GothamBold
local actionSub = makeLabel(actionPanel, "Choose a tool, then click the planet.", UDim2.new(1, -32, 0, 34), UDim2.fromOffset(16, 37), 12)
actionSub.TextColor3 = Color3.fromRGB(149, 169, 199)
actionSub.TextYAlignment = Enum.TextYAlignment.Top

local buttons = {}
for index, definition in ipairs(ACTIONS) do
	local button = makeButton(
		actionPanel,
		string.format("[%s]  %s %s  •  %d", definition.Shortcut, definition.Icon, definition.Label, definition.Cost),
		UDim2.new(1, -32, 0, 48),
		UDim2.fromOffset(16, 76 + (index - 1) * 55)
	)
	buttons[definition.Key] = button
end

local randomButton = makeButton(actionPanel, "🎲 Use selected tool on random valid tile [R]", UDim2.new(1, -32, 0, 40), UDim2.fromOffset(16, 356))
randomButton.Visible = false
local actionHint = makeLabel(actionPanel, "Click a tile first for exact placement. Drag the planet to rotate it.", UDim2.new(1, -32, 0, 42), UDim2.fromOffset(16, 402), 11)
actionHint.TextColor3 = Color3.fromRGB(133, 153, 183)
actionHint.TextYAlignment = Enum.TextYAlignment.Top

local statsPanel = makePanel("Stats", UDim2.fromOffset(270, 292), UDim2.new(1, -288, 0.5, -146))
local statsHeader = makeLabel(statsPanel, "PLANET STATUS", UDim2.new(1, -28, 0, 28), UDim2.fromOffset(14, 12), 17)
statsHeader.Font = Enum.Font.GothamBold
local statsLabel = makeLabel(statsPanel, "Loading planet data...", UDim2.new(1, -28, 0, 152), UDim2.fromOffset(14, 45), 13)
statsLabel.TextYAlignment = Enum.TextYAlignment.Top
local objectiveHeader = makeLabel(statsPanel, "NEXT OBJECTIVE", UDim2.new(1, -28, 0, 22), UDim2.fromOffset(14, 198), 12)
objectiveHeader.Font = Enum.Font.GothamBold
objectiveHeader.TextColor3 = Color3.fromRGB(111, 229, 255)
local objectiveLabel = makeLabel(statsPanel, "Create your first water or plant tile.", UDim2.new(1, -28, 0, 42), UDim2.fromOffset(14, 220), 11)
objectiveLabel.TextColor3 = Color3.fromRGB(175, 191, 216)
objectiveLabel.TextYAlignment = Enum.TextYAlignment.Top
local shopButton = makeButton(statsPanel, "🛒 Cosmic Shop  [B]", UDim2.new(1, -28, 0, 38), UDim2.new(0, 14, 1, -49))

local inspector = makePanel("TileInspector", UDim2.fromOffset(520, 184), UDim2.new(0.5, -260, 1, -250))
inspector.Visible = false
local inspectorTitle = makeLabel(inspector, "SURFACE TILE", UDim2.fromOffset(220, 26), UDim2.fromOffset(16, 12), 16)
inspectorTitle.Font = Enum.Font.GothamBold
local inspectorType = makeLabel(inspector, "", UDim2.fromOffset(260, 24), UDim2.new(1, -278, 0, 12), 14, Enum.TextXAlignment.Right)
inspectorType.TextColor3 = Color3.fromRGB(112, 225, 255)
local inspectorDescription = makeLabel(inspector, "", UDim2.new(1, -32, 0, 36), UDim2.fromOffset(16, 40), 12)
inspectorDescription.TextColor3 = Color3.fromRGB(162, 181, 208)
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
		UDim2.fromOffset(230, 38),
		UDim2.fromOffset(16 + column * 242, 82 + row * 44)
	)
	inspectorButtons[actionKey] = button
end
local clearTargetButton = makeButton(inspector, "✕ Clear target", UDim2.fromOffset(110, 28), UDim2.new(1, -126, 1, -33))
clearTargetButton.TextSize = 11

local shop = makePanel("Shop", UDim2.fromOffset(610, 520), UDim2.new(0.5, -305, 0.5, -260))
shop.Visible = false
shop.ZIndex = 50
local shopHeader = makeLabel(shop, "COSMIC SHOP", UDim2.new(1, -85, 0, 35), UDim2.fromOffset(22, 16), 22)
shopHeader.Font = Enum.Font.GothamBold
local closeShop = makeButton(shop, "✕", UDim2.fromOffset(42, 36), UDim2.new(1, -58, 0, 14))
closeShop.ZIndex = 52
local shopSub = makeLabel(shop, "Permanent passes and repeatable boosts", UDim2.new(1, -44, 0, 24), UDim2.fromOffset(22, 53), 13)
shopSub.TextColor3 = Color3.fromRGB(146, 163, 192)

local scrolling = Instance.new("ScrollingFrame")
scrolling.BackgroundTransparency = 1
scrolling.BorderSizePixel = 0
scrolling.Size = UDim2.new(1, -32, 1, -94)
scrolling.Position = UDim2.fromOffset(16, 84)
scrolling.ScrollBarThickness = 5
scrolling.ScrollBarImageColor3 = Color3.fromRGB(92, 211, 255)
scrolling.AutomaticCanvasSize = Enum.AutomaticSize.Y
scrolling.CanvasSize = UDim2.new()
scrolling.ZIndex = 51
scrolling.Parent = shop
local listLayout = Instance.new("UIListLayout")
listLayout.Padding = UDim.new(0, 10)
listLayout.Parent = scrolling

local toast = Instance.new("TextLabel")
toast.Name = "Toast"
toast.BackgroundColor3 = Color3.fromRGB(18, 55, 69)
toast.BackgroundTransparency = 1
toast.TextTransparency = 1
toast.TextColor3 = Color3.fromRGB(235, 245, 255)
toast.Font = Enum.Font.GothamSemibold
toast.TextSize = 14
toast.TextWrapped = true
toast.AnchorPoint = Vector2.new(0.5, 0)
toast.Size = UDim2.fromOffset(520, 54)
toast.Position = UDim2.new(0.5, 0, 0, 96)
toast.ZIndex = 100
toast.Parent = gui
addCorner(toast, 12)
addStroke(toast, Color3.fromRGB(96, 225, 255), 0.4, 1)

local tutorial = makePanel("Tutorial", UDim2.fromOffset(520, 42), UDim2.new(0.5, -260, 1, -54))
tutorial.BackgroundTransparency = 0.14
local tutorialText = makeLabel(tutorial, "Start: click a land tile, then choose 💧 Water or 🌱 Plants.", UDim2.new(1, -24, 1, 0), UDim2.fromOffset(12, 0), 12, Enum.TextXAlignment.Center)
tutorialText.TextColor3 = Color3.fromRGB(203, 220, 243)

local function showToast(message, kind)
	toastGeneration += 1
	local generation = toastGeneration
	toast.Text = tostring(message)
	if kind == "error" then
		toast.BackgroundColor3 = Color3.fromRGB(83, 31, 45)
	elseif kind == "warning" then
		toast.BackgroundColor3 = Color3.fromRGB(86, 64, 28)
	elseif kind == "milestone" then
		toast.BackgroundColor3 = Color3.fromRGB(58, 39, 102)
	else
		toast.BackgroundColor3 = Color3.fromRGB(18, 55, 69)
	end
	TweenService:Create(toast, TweenInfo.new(0.15), { BackgroundTransparency = 0.05, TextTransparency = 0 }):Play()
	task.delay(3.4, function()
		if toastGeneration ~= generation then
			return
		end
		TweenService:Create(toast, TweenInfo.new(0.22), { BackgroundTransparency = 1, TextTransparency = 1 }):Play()
	end)
end

local function setButtonEnabled(button, enabled)
	button.Active = enabled
	button.Selectable = enabled
	button.TextTransparency = enabled and 0 or 0.42
	button.BackgroundColor3 = enabled and Color3.fromRGB(28, 47, 76) or Color3.fromRGB(30, 33, 44)
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

local function getNextMilestone(developed)
	for _, milestone in ipairs(Config.MILESTONES) do
		if developed < milestone then
			return milestone
		end
	end
	return nil
end

local function refreshActionVisuals()
	if not state then
		return
	end
	local unlocks = state.Unlocks or {}
	for _, definition in ipairs(ACTIONS) do
		local button = buttons[definition.Key]
		local unlocked = unlocks[definition.Key] ~= false
		local affordable = (state.Energy or 0) >= definition.Cost
		setButtonEnabled(button, unlocked and affordable)
		if not unlocked then
			button.Text = string.format("🔒 [%s] %s  •  %d tiles", definition.Shortcut, definition.Label, Config.ACTION_UNLOCKS[definition.Key])
		elseif pendingAction == definition.Key then
			button.Text = string.format("🎯 [%s] %s — CLICK PLANET", definition.Shortcut, definition.Label)
			button.BackgroundColor3 = Color3.fromRGB(31, 91, 111)
		else
			button.Text = string.format("[%s]  %s %s  •  %d", definition.Shortcut, definition.Icon, definition.Label, definition.Cost)
		end
	end

	randomButton.Visible = pendingAction ~= nil and pendingAction ~= "TerraformBurst"
	if randomButton.Visible then
		local definition = ACTION_BY_KEY[pendingAction]
		randomButton.Text = string.format("🎲 Use %s on a random valid tile [R]", definition.Label)
		setButtonEnabled(randomButton, true)
	end
end

local function refreshInspector()
	if not state or not selectedTileIndex then
		inspector.Visible = false
		return
	end

	local tileType = state.Tiles and state.Tiles[selectedTileIndex] or "Land"
	inspector.Visible = true
	inspectorTitle.Text = string.format("SURFACE TILE #%d", selectedTileIndex)
	inspectorType.Text = string.upper(tileType)

	if tileType == "Land" then
		inspectorDescription.Text = "Bare land. Add water to form oceans or plants to begin an ecosystem."
	elseif tileType == "Water" then
		inspectorDescription.Text = "Water habitat. Fish can live here after the animal milestone and 3 water tiles."
	elseif tileType == "RarePlant" then
		inspectorDescription.Text = "Rare glowing vegetation. Supports land animals and settlements."
	else
		inspectorDescription.Text = "Vegetated habitat. Supports land animals and can anchor settlements."
	end

	local unlocks = state.Unlocks or {}
	local counts = state.Counts or {}
	local plantCount = (counts.Plant or 0) + (counts.RarePlant or 0)
	local canFish = (counts.Water or 0) >= 3
	local canLandAnimal = plantCount >= 5

	setButtonEnabled(inspectorButtons.AddWater, tileType == "Land" and (state.Energy or 0) >= Config.ACTION_COSTS.AddWater)
	setButtonEnabled(inspectorButtons.AddPlants, tileType == "Land" and (state.Energy or 0) >= Config.ACTION_COSTS.AddPlants)
	setButtonEnabled(
		inspectorButtons.AddAnimals,
		unlocks.AddAnimals == true
			and (state.Energy or 0) >= Config.ACTION_COSTS.AddAnimals
			and ((tileType == "Water" and canFish) or ((tileType == "Plant" or tileType == "RarePlant") and canLandAnimal))
	)
	setButtonEnabled(
		inspectorButtons.BuildSettlement,
		unlocks.BuildSettlement == true
			and (state.Energy or 0) >= Config.ACTION_COSTS.BuildSettlement
			and (tileType == "Plant" or tileType == "RarePlant")
	)
end

local function refreshUI()
	if not state then
		return
	end

	local energy = state.Energy or 0
	local developed = state.DevelopedTiles or 0
	local counts = state.Counts or { Water = 0, Plant = 0, RarePlant = 0 }
	local plantCount = (counts.Plant or 0) + (counts.RarePlant or 0)
	local animalCount = state.AnimalCount or (state.Animals and #state.Animals or 0)
	local settlementCount = state.SettlementCount or (state.Settlements and #state.Settlements or 0)
	local stage = getStage(developed)
	local nextMilestone = getNextMilestone(developed)

	energyLabel.Text = string.format("⚡ Energy: %d", energy)
	stageLabel.Text = string.format("%s  •  %d/%d surface tiles developed", stage.Name, developed, Config.TILE_COUNT)
	statsLabel.Text = string.format(
		"Stage: %s\nDeveloped: %d / %d\n💧 Water: %d\n🌱 Plants: %d\n🐾 Animals: %d\n🏠 Settlements: %d\n✨ Rare seed charges: %d",
		stage.Name,
		developed,
		Config.TILE_COUNT,
		counts.Water or 0,
		plantCount,
		animalCount,
		settlementCount,
		state.RareSeedCharges or 0
	)

	if developed < 3 then
		objectiveLabel.Text = "Create your first water and plant tiles."
	elseif developed < 10 then
		objectiveLabel.Text = string.format("Develop %d more tiles to unlock animals (+%d Energy).", 10 - developed, Config.MILESTONE_ENERGY_REWARDS[10])
	elseif (counts.Water or 0) < 3 and plantCount < 5 then
		objectiveLabel.Text = "Build 3 water tiles for fish or 5 plant tiles for land animals."
	elseif developed < 25 then
		objectiveLabel.Text = string.format("Develop %d more tiles to unlock settlements (+%d Energy).", 25 - developed, Config.MILESTONE_ENERGY_REWARDS[25])
	elseif developed < 50 then
		objectiveLabel.Text = string.format("Develop %d more tiles to unlock Terraform Burst (+%d Energy).", 50 - developed, Config.MILESTONE_ENERGY_REWARDS[50])
	elseif nextMilestone then
		objectiveLabel.Text = string.format("Continue developing toward %d tiles.", nextMilestone)
	else
		objectiveLabel.Text = "Grow toward a 100-tile Garden World and build a thriving planet."
	end

	if developed == 0 then
		tutorialText.Text = "Start: click a land tile, then choose 💧 Water or 🌱 Plants."
	elseif developed < 10 then
		tutorialText.Text = "Tip: choose a tool first, then click tiles for fast exact placement."
	elseif developed < 25 then
		tutorialText.Text = "Animals unlocked: fish need water; land animals need vegetation."
	else
		tutorialText.Text = "Settlements need a planted tile inside a connected developed cluster."
	end

	refreshActionVisuals()
	refreshInspector()
end

local function clearSelection()
	selectedTileIndex = nil
	if selectedHighlight then
		selectedHighlight:Destroy()
		selectedHighlight = nil
	end
	inspector.Visible = false
end

local function clearPendingAction()
	pendingAction = nil
	refreshActionVisuals()
end

local function setSelectedTile(tileIndex, tilePart)
	selectedTileIndex = tileIndex
	if selectedHighlight then
		selectedHighlight:Destroy()
	end
	selectedHighlight = Instance.new("Highlight")
	selectedHighlight.Name = "SelectedTileHighlight"
	selectedHighlight.Adornee = tilePart
	selectedHighlight.FillColor = Color3.fromRGB(88, 232, 255)
	selectedHighlight.FillTransparency = 0.72
	selectedHighlight.OutlineColor = Color3.fromRGB(222, 252, 255)
	selectedHighlight.OutlineTransparency = 0
	selectedHighlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	selectedHighlight.Parent = planet
	refreshInspector()
end

local function sendAction(actionKey, tileIndex)
	if not state then
		showToast("Planet data is still loading.", "warning")
		return
	end
	local definition = ACTION_BY_KEY[actionKey]
	if not definition then
		return
	end
	applyAction:FireServer({
		actionType = actionKey,
		tileIndex = definition.Global and nil or tileIndex,
	})
end

local function selectOrUseAction(actionKey)
	if not state then
		showToast("Planet data is still loading.", "warning")
		return
	end
	local definition = ACTION_BY_KEY[actionKey]
	if not definition then
		return
	end
	if definition.Global then
		clearPendingAction()
		sendAction(actionKey, nil)
		return
	end
	if selectedTileIndex then
		sendAction(actionKey, selectedTileIndex)
		return
	end
	pendingAction = actionKey
	refreshActionVisuals()
	showToast(string.format("%s selected — click anywhere on the planet.", definition.Label), "success")
end

for _, definition in ipairs(ACTIONS) do
	buttons[definition.Key].Activated:Connect(function()
		if buttons[definition.Key].Active then
			selectOrUseAction(definition.Key)
		end
	end)
end

for actionKey, button in pairs(inspectorButtons) do
	button.Activated:Connect(function()
		if button.Active and selectedTileIndex then
			sendAction(actionKey, selectedTileIndex)
		end
	end)
end

randomButton.Activated:Connect(function()
	if pendingAction then
		local actionKey = pendingAction
		clearPendingAction()
		sendAction(actionKey, nil)
	end
end)

clearTargetButton.Activated:Connect(clearSelection)

local function makeShopSection(text)
	local label = makeLabel(scrolling, text, UDim2.new(1, -8, 0, 30), UDim2.new(), 16)
	label.Font = Enum.Font.GothamBold
	label.TextColor3 = Color3.fromRGB(112, 224, 255)
	label.ZIndex = 52
	return label
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

local keyToAction = {
	[Enum.KeyCode.One] = "AddWater",
	[Enum.KeyCode.Two] = "AddPlants",
	[Enum.KeyCode.Three] = "AddAnimals",
	[Enum.KeyCode.Four] = "BuildSettlement",
	[Enum.KeyCode.Five] = "TerraformBurst",
}

local function getNearestTileFromDirection(direction)
	local bestIndex = 1
	local bestDot = -math.huge
	for index = 1, Config.TILE_COUNT do
		local dot = direction:Dot(TileGeometry.GetDirection(index))
		if dot > bestDot then
			bestDot = dot
			bestIndex = index
		end
	end
	return bestIndex
end

local function findClickedTile(ray)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { tilesFolder }
	params.IgnoreWater = true
	local result = Workspace:Raycast(ray.Origin, ray.Direction * 1000, params)
	if result and result.Instance then
		local tileIndex = result.Instance:GetAttribute("TileIndex")
		if type(tileIndex) == "number" then
			return tileIndex, result.Instance
		end
	end

	-- The visible discs intentionally leave tiny gaps on a sphere. Fall back to
	-- analytic ray/sphere intersection so every click on the planet maps to the
	-- nearest logical surface tile instead of becoming a dead click.
	local direction = ray.Direction.Unit
	local relativeOrigin = ray.Origin - core.Position
	local radius = Config.PLANET_RADIUS + Config.TILE_SURFACE_OFFSET
	local b = 2 * relativeOrigin:Dot(direction)
	local c = relativeOrigin:Dot(relativeOrigin) - radius * radius
	local discriminant = b * b - 4 * c
	if discriminant < 0 then
		return nil, nil
	end

	local root = math.sqrt(discriminant)
	local distance = (-b - root) * 0.5
	if distance < 0 then
		distance = (-b + root) * 0.5
	end
	if distance < 0 then
		return nil, nil
	end

	local hitPosition = ray.Origin + direction * distance
	local surfaceDirection = (hitPosition - core.Position).Unit
	local tileIndex = getNearestTileFromDirection(surfaceDirection)
	local tilePart = tilesFolder:FindFirstChild("Tile_" .. tileIndex)
	if tilePart then
		return tileIndex, tilePart
	end
	return nil, nil
end

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then
		return
	end
	if input.KeyCode == Enum.KeyCode.B then
		toggleShop()
		return
	elseif input.KeyCode == Enum.KeyCode.Escape then
		clearSelection()
		clearPendingAction()
		return
	elseif input.KeyCode == Enum.KeyCode.R and pendingAction then
		local actionKey = pendingAction
		clearPendingAction()
		sendAction(actionKey, nil)
		return
	end

	local shortcutAction = keyToAction[input.KeyCode]
	if shortcutAction then
		selectOrUseAction(shortcutAction)
		return
	end
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
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
	local tileIndex, tilePart = findClickedTile(ray)
	if not tileIndex or not tilePart then
		return
	end

	setSelectedTile(tileIndex, tilePart)
	if pendingAction then
		local actionKey = pendingAction
		clearPendingAction()
		sendAction(actionKey, tileIndex)
	else
		local tileType = state and state.Tiles and state.Tiles[tileIndex] or tilePart:GetAttribute("TileType") or "Land"
		showToast(string.format("Tile #%d selected: %s. Choose a growth action.", tileIndex, tileType), "success")
	end
end)

updateEnergy.OnClientEvent:Connect(function(energy)
	if state then
		state.Energy = energy
		refreshUI()
	end
end)

updateTile.OnClientEvent:Connect(function(update)
	if not state or type(update) ~= "table" or type(update.TileIndex) ~= "number" then
		return
	end
	if state.Tiles then
		state.Tiles[update.TileIndex] = update.TileType
	end
	local tilePart = tilesFolder:FindFirstChild("Tile_" .. update.TileIndex)
	if tilePart then
		tilePart:SetAttribute("TileType", update.TileType)
	end
	refreshInspector()
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
		task.wait(0.25)
	end
	showToast("Planet data could not be loaded. Rejoin and try again.", "error")
end

loadInitialState()

for _, info in pairs(Config.PASSES) do
	if info.Id == 0 then
		warn("[Grow a Tiny Planet] Configure Marketplace IDs in ReplicatedStorage/Shared/Config.lua before production.")
		break
	end
end
