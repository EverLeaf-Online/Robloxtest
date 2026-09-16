local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local MarketplaceService = game:GetService("MarketplaceService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local camera = Workspace.CurrentCamera

local shared = ReplicatedStorage:WaitForChild("Shared")
local config = require(shared:WaitForChild("GameConfig"))
local PlanetMath = require(shared:WaitForChild("PlanetMath"))

local remotes = ReplicatedFirst:WaitForChild("Remotes")
local applyAction = remotes:WaitForChild("ApplyAction")
local updateEnergy = remotes:WaitForChild("UpdateEnergy")
local updateStats = remotes:WaitForChild("UpdateStats")
local updateTile = remotes:WaitForChild("UpdateTile")
local milestoneReached = remotes:WaitForChild("MilestoneReached")
local notifyRemote = remotes:WaitForChild("Notify")
local purchaseConfirmed = remotes:WaitForChild("PurchaseConfirmed")
local getPlanetState = remotes:WaitForChild("GetPlanetState")

local state = {
	Energy = config.START_ENERGY,
	Stats = nil,
	Ownership = {},
	Tiles = nil,
}

local planet = nil
local tilesFolder = nil
local planetCenter = Vector3.zero
local planetRadius = config.PLANET_RADIUS
local selectedTile = -1
local pendingAction = nil
local highlight = nil

local yaw = math.rad(35)
local pitch = math.rad(-12)
local targetYaw = yaw
local targetPitch = pitch
local distance = 118
local targetDistance = distance
local pointerDown = false
local pointerStart = nil
local lastPointer = nil
local pointerDragged = false

local MIN_DISTANCE = 82
local MAX_DISTANCE = 220
local DRAG_THRESHOLD = 8
local ROTATE_SPEED = 0.0055

local ACTIONS = {
	{ Key = config.ACTIONS.AddWater, Label = "Add Water", Icon = "💧", Cost = config.COSTS.AddWater, Unlock = nil },
	{ Key = config.ACTIONS.AddPlant, Label = "Add Plants", Icon = "🌱", Cost = config.COSTS.AddPlant, Unlock = nil },
	{ Key = config.ACTIONS.AddAnimal, Label = "Add Animal", Icon = "🐾", Cost = config.COSTS.AddAnimal, Unlock = "Animal" },
	{ Key = config.ACTIONS.BuildSettlement, Label = "Build Settlement", Icon = "🏠", Cost = config.COSTS.BuildSettlement, Unlock = "Settlement" },
}

local actionByKey = {}
for _, action in ipairs(ACTIONS) do
	actionByKey[action.Key] = action
end

local function makeCorner(parent, radius)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius or 10)
	corner.Parent = parent
	return corner
end

local function makeStroke(parent, color, transparency)
	local stroke = Instance.new("UIStroke")
	stroke.Color = color or config.COLORS.UI.Accent
	stroke.Thickness = 1.25
	stroke.Transparency = transparency or 0.35
	stroke.Parent = parent
	return stroke
end

local gui = Instance.new("ScreenGui")
gui.Name = "GrowTinyPlanetGui"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 20
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = playerGui

local rootScale = Instance.new("UIScale")
rootScale.Parent = gui

local function updateUIScale()
	if not camera then
		return
	end
	local viewport = camera.ViewportSize
	rootScale.Scale = math.clamp(math.min(viewport.X / 1440, viewport.Y / 900), 0.72, 1)
end
updateUIScale()
camera:GetPropertyChangedSignal("ViewportSize"):Connect(updateUIScale)

local function makePanel(name, size, position, anchor)
	local frame = Instance.new("Frame")
	frame.Name = name
	frame.Size = size
	frame.Position = position
	frame.AnchorPoint = anchor or Vector2.zero
	frame.BackgroundColor3 = config.COLORS.UI.Background
	frame.BackgroundTransparency = 0.04
	frame.BorderSizePixel = 0
	frame.Parent = gui
	makeCorner(frame, 14)
	makeStroke(frame, config.COLORS.UI.Accent, 0.35)
	return frame
end

local function makeLabel(parent, text, size, position, textSize, bold, alignment)
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Text = text
	label.Size = size
	label.Position = position
	label.Font = bold and Enum.Font.GothamBold or Enum.Font.Gotham
	label.TextSize = textSize or 14
	label.TextColor3 = config.COLORS.UI.Text
	label.TextXAlignment = alignment or Enum.TextXAlignment.Left
	label.TextYAlignment = Enum.TextYAlignment.Center
	label.TextWrapped = true
	label.Parent = parent
	return label
end

local function makeButton(parent, text, size, position)
	local button = Instance.new("TextButton")
	button.AutoButtonColor = false
	button.BackgroundColor3 = config.COLORS.UI.Button
	button.BorderSizePixel = 0
	button.Text = text
	button.TextColor3 = config.COLORS.UI.Text
	button.Font = Enum.Font.GothamSemibold
	button.TextSize = 15
	button.TextWrapped = true
	button.Size = size
	button.Position = position
	button.Parent = parent
	makeCorner(button, 10)
	makeStroke(button, config.COLORS.UI.Accent2, 0.45)
	return button
end

local leftPanel = makePanel("MainPanel", UDim2.fromOffset(300, 520), UDim2.fromOffset(16, 16))
local title = makeLabel(leftPanel, "GROW A TINY PLANET", UDim2.new(1, -24, 0, 32), UDim2.fromOffset(12, 10), 20, true, Enum.TextXAlignment.Center)
local energyLabel = makeLabel(leftPanel, "⚡ Energy: loading...", UDim2.new(1, -24, 0, 26), UDim2.fromOffset(12, 48), 17, true)
energyLabel.TextColor3 = Color3.fromRGB(105, 228, 255)
local statsLabel = makeLabel(leftPanel, "Loading planet data...", UDim2.new(1, -24, 0, 105), UDim2.fromOffset(12, 82), 13, false)
statsLabel.TextYAlignment = Enum.TextYAlignment.Top
local selectedLabel = makeLabel(leftPanel, "Selected tile: none", UDim2.new(1, -24, 0, 24), UDim2.fromOffset(12, 188), 13, false)
selectedLabel.TextColor3 = Color3.fromRGB(175, 197, 226)

local actionButtons = {}
for i, action in ipairs(ACTIONS) do
	local button = makeButton(leftPanel, action.Icon .. "  " .. action.Label, UDim2.new(1, -24, 0, 50), UDim2.fromOffset(12, 222 + (i - 1) * 58))
	actionButtons[action.Key] = button
end

local randomButton = makeButton(leftPanel, "🎲 Random valid tile", UDim2.new(1, -24, 0, 42), UDim2.fromOffset(12, 454))
local shopButton = makeButton(leftPanel, "🛒 Shop [B]", UDim2.new(1, -24, 0, 42), UDim2.fromOffset(12, 502))
shopButton.Position = UDim2.fromOffset(12, 502)
leftPanel.Size = UDim2.fromOffset(300, 562)

local statusPanel = makePanel("Status", UDim2.fromOffset(560, 54), UDim2.new(0.5, 0, 1, -18), Vector2.new(0.5, 1))
local statusLabel = makeLabel(statusPanel, "Preparing your planet...", UDim2.new(1, -24, 1, 0), UDim2.fromOffset(12, 0), 13, false, Enum.TextXAlignment.Center)

local toast = Instance.new("TextLabel")
toast.Name = "Toast"
toast.AnchorPoint = Vector2.new(0.5, 0)
toast.Position = UDim2.new(0.5, 0, 0, 20)
toast.Size = UDim2.fromOffset(520, 52)
toast.BackgroundColor3 = Color3.fromRGB(20, 55, 70)
toast.BackgroundTransparency = 1
toast.TextTransparency = 1
toast.TextColor3 = config.COLORS.UI.Text
toast.Font = Enum.Font.GothamSemibold
toast.TextSize = 14
toast.TextWrapped = true
toast.ZIndex = 100
toast.Parent = gui
makeCorner(toast, 12)
makeStroke(toast, config.COLORS.UI.Accent, 0.35)
local toastGeneration = 0

local shop = makePanel("Shop", UDim2.fromOffset(610, 520), UDim2.new(0.5, 0, 0.5, 0), Vector2.new(0.5, 0.5))
shop.Visible = false
shop.ZIndex = 50
local shopTitle = makeLabel(shop, "COSMIC SHOP", UDim2.new(1, -90, 0, 36), UDim2.fromOffset(20, 12), 21, true)
shopTitle.ZIndex = 52
local closeShop = makeButton(shop, "✕", UDim2.fromOffset(42, 36), UDim2.new(1, -58, 0, 12))
closeShop.ZIndex = 52
local shopList = Instance.new("ScrollingFrame")
shopList.BackgroundTransparency = 1
shopList.BorderSizePixel = 0
shopList.Size = UDim2.new(1, -30, 1, -64)
shopList.Position = UDim2.fromOffset(15, 55)
shopList.ScrollBarThickness = 5
shopList.AutomaticCanvasSize = Enum.AutomaticSize.Y
shopList.CanvasSize = UDim2.new()
shopList.ZIndex = 51
shopList.Parent = shop
local shopLayout = Instance.new("UIListLayout")
shopLayout.Padding = UDim.new(0, 9)
shopLayout.Parent = shopList

local function showToast(text, kind)
	toastGeneration += 1
	local generation = toastGeneration
	toast.Text = tostring(text)
	if kind == "error" then
		toast.BackgroundColor3 = Color3.fromRGB(91, 35, 47)
	elseif kind == "warning" then
		toast.BackgroundColor3 = Color3.fromRGB(86, 65, 30)
	elseif kind == "milestone" then
		toast.BackgroundColor3 = Color3.fromRGB(59, 39, 102)
	else
		toast.BackgroundColor3 = Color3.fromRGB(20, 55, 70)
	end
	TweenService:Create(toast, TweenInfo.new(0.15), { BackgroundTransparency = 0.05, TextTransparency = 0 }):Play()
	task.delay(3.4, function()
		if toastGeneration ~= generation then
			return
		end
		TweenService:Create(toast, TweenInfo.new(0.2), { BackgroundTransparency = 1, TextTransparency = 1 }):Play()
	end)
end

local function setButtonEnabled(button, enabled)
	button.Active = enabled
	button.Selectable = enabled
	button.BackgroundColor3 = enabled and config.COLORS.UI.Button or config.COLORS.UI.ButtonDisabled
	button.TextTransparency = enabled and 0 or 0.42
end

local function refreshUI()
	local stats = state.Stats
	energyLabel.Text = "⚡ Energy: " .. tostring(math.floor(state.Energy or 0))

	if stats then
		statsLabel.Text = string.format(
			"Developed: %d / %d\n💧 Water: %d\n🌱 Plants: %d\n✨ Glow: %d\n🐾 Animals: %d\n🏠 Settlements: %d",
			stats.Developed or 0,
			PlanetMath.getTileCount(),
			stats.Water or 0,
			stats.Plants or 0,
			stats.Glow or 0,
			stats.Animals or 0,
			stats.Settlements or 0
		)
	else
		statsLabel.Text = "Loading planet data..."
	end

	selectedLabel.Text = selectedTile >= 0 and ("Selected tile: #" .. selectedTile) or "Selected tile: none"
	local unlocks = stats and stats.Unlocks or {}

	for _, action in ipairs(ACTIONS) do
		local unlocked = action.Unlock == nil or unlocks[action.Unlock] == true
		local affordable = (state.Energy or 0) >= action.Cost
		local enabled = unlocked and affordable
		local button = actionButtons[action.Key]
		setButtonEnabled(button, enabled)

		if not unlocked then
			local requirement = action.Unlock == "Animal" and "10 developed tiles" or "25 developed tiles"
			button.Text = "🔒 " .. action.Label .. " — " .. requirement
		elseif pendingAction == action.Key then
			button.Text = "🎯 " .. action.Label .. " — CLICK PLANET"
		else
			button.Text = string.format("%s  %s  •  %d Energy", action.Icon, action.Label, action.Cost)
		end
	end
end

local function addShopItem(entry, isPass)
	local card = Instance.new("Frame")
	card.Size = UDim2.new(1, -8, 0, 88)
	card.BackgroundColor3 = config.COLORS.UI.Button
	card.BackgroundTransparency = 0.28
	card.BorderSizePixel = 0
	card.ZIndex = 52
	card.Parent = shopList
	makeCorner(card, 10)

	local name = makeLabel(card, entry.Name, UDim2.new(1, -150, 0, 24), UDim2.fromOffset(12, 8), 15, true)
	name.ZIndex = 53
	local desc = makeLabel(card, entry.Description, UDim2.new(1, -150, 0, 46), UDim2.fromOffset(12, 32), 12, false)
	desc.TextYAlignment = Enum.TextYAlignment.Top
	desc.ZIndex = 53
	local buy = makeButton(card, entry.Price, UDim2.fromOffset(118, 42), UDim2.new(1, -130, 0.5, -21))
	buy.ZIndex = 53

	if entry.Id == 0 then
		buy.Text = "Not configured"
		setButtonEnabled(buy, false)
	else
		buy.Activated:Connect(function()
			if isPass then
				MarketplaceService:PromptGamePassPurchase(player, entry.Id)
			else
				MarketplaceService:PromptProductPurchase(player, entry.Id)
			end
		end)
	end
end

for _, entry in ipairs(config.SHOP.GamePasses) do
	addShopItem(entry, true)
end
for _, entry in ipairs(config.SHOP.Products) do
	addShopItem(entry, false)
end

local function toggleShop(force)
	if typeof(force) == "boolean" then
		shop.Visible = force
	else
		shop.Visible = not shop.Visible
	end
end
shopButton.Activated:Connect(function() toggleShop() end)
closeShop.Activated:Connect(function() toggleShop(false) end)

local function readPlanetCenter(model)
	return Vector3.new(
		model:GetAttribute("CenterX") or 0,
		model:GetAttribute("CenterY") or 0,
		model:GetAttribute("CenterZ") or 0
	)
end

local function nearestTileForDirection(direction)
	local bestIndex = 0
	local bestDot = -math.huge
	for index = 0, PlanetMath.getTileCount() - 1 do
		local dot = direction:Dot(PlanetMath.getDirection(index))
		if dot > bestDot then
			bestDot = dot
			bestIndex = index
		end
	end
	return bestIndex
end

local function pickTile(screenPosition)
	if not planet then
		return nil
	end
	local ray = camera:ScreenPointToRay(screenPosition.X, screenPosition.Y)
	local rayDirection = ray.Direction.Unit
	local origin = ray.Origin - planetCenter
	local radius = planetRadius + 2.5
	local b = 2 * origin:Dot(rayDirection)
	local c = origin:Dot(origin) - radius * radius
	local discriminant = b * b - 4 * c
	if discriminant < 0 then
		return nil
	end
	local root = math.sqrt(discriminant)
	local t = (-b - root) * 0.5
	if t < 0 then
		t = (-b + root) * 0.5
	end
	if t < 0 then
		return nil
	end
	local hit = ray.Origin + rayDirection * t
	return nearestTileForDirection((hit - planetCenter).Unit)
end

local function refreshHighlight()
	if highlight then
		highlight:Destroy()
		highlight = nil
	end
	if selectedTile < 0 or not tilesFolder then
		return
	end
	local tile = tilesFolder:FindFirstChild("Tile_" .. selectedTile)
	if not tile then
		return
	end
	local h = Instance.new("Highlight")
	h.Name = "SelectedTileHighlight"
	h.Adornee = tile
	h.FillColor = config.COLORS.UI.Accent
	h.OutlineColor = config.COLORS.UI.Accent2
	h.FillTransparency = 0.62
	h.OutlineTransparency = 0
	h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	h.Parent = planet
	highlight = h
end

local function sendAction(actionKey, tileIndex)
	local action = actionByKey[actionKey]
	if not action then
		return
	end
	if (state.Energy or 0) < action.Cost then
		showToast("Not enough Energy for " .. action.Label .. ".", "warning")
		return
	end
	applyAction:FireServer(actionKey, tileIndex)
end

local function chooseAction(actionKey)
	local action = actionByKey[actionKey]
	if not action then
		return
	end
	local unlocks = state.Stats and state.Stats.Unlocks or {}
	if action.Unlock and unlocks[action.Unlock] ~= true then
		showToast(action.Label .. " is still locked.", "warning")
		return
	end
	if selectedTile >= 0 then
		sendAction(actionKey, selectedTile)
	else
		pendingAction = actionKey
		statusLabel.Text = action.Label .. " armed — click the planet to place it."
		showToast(action.Label .. " selected. Click the planet.", "success")
		refreshUI()
	end
end

for _, action in ipairs(ACTIONS) do
	actionButtons[action.Key].Activated:Connect(function()
		if actionButtons[action.Key].Active then
			chooseAction(action.Key)
		end
	end)
end

randomButton.Activated:Connect(function()
	if pendingAction then
		local actionKey = pendingAction
		pendingAction = nil
		sendAction(actionKey, -1)
		refreshUI()
	elseif selectedTile >= 0 then
		showToast("Choose a growth action first.", "warning")
	else
		showToast("Choose Water, Plants, Animal, or Settlement first.", "warning")
	end
end)

local function selectTile(tileIndex)
	selectedTile = tileIndex
	refreshHighlight()
	refreshUI()
	statusLabel.Text = "Tile #" .. tileIndex .. " selected. Choose an action."
	if pendingAction then
		local actionKey = pendingAction
		pendingAction = nil
		sendAction(actionKey, tileIndex)
		refreshUI()
	end
end

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then
		return
	end
	if input.KeyCode == Enum.KeyCode.B then
		toggleShop()
		return
	elseif input.KeyCode == Enum.KeyCode.Escape then
		selectedTile = -1
		pendingAction = nil
		refreshHighlight()
		refreshUI()
		statusLabel.Text = "Selection cleared."
		return
	elseif input.KeyCode == Enum.KeyCode.One then
		chooseAction(config.ACTIONS.AddWater)
		return
	elseif input.KeyCode == Enum.KeyCode.Two then
		chooseAction(config.ACTIONS.AddPlant)
		return
	elseif input.KeyCode == Enum.KeyCode.Three then
		chooseAction(config.ACTIONS.AddAnimal)
		return
	elseif input.KeyCode == Enum.KeyCode.Four then
		chooseAction(config.ACTIONS.BuildSettlement)
		return
	end

	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		pointerDown = true
		pointerStart = Vector2.new(input.Position.X, input.Position.Y)
		lastPointer = pointerStart
		pointerDragged = false
	end
end)

UserInputService.InputChanged:Connect(function(input, gameProcessed)
	if input.UserInputType == Enum.UserInputType.MouseWheel then
		targetDistance = math.clamp(targetDistance - input.Position.Z * 9, MIN_DISTANCE, MAX_DISTANCE)
		return
	end

	if gameProcessed or not pointerDown then
		return
	end
	if input.UserInputType ~= Enum.UserInputType.MouseMovement and input.UserInputType ~= Enum.UserInputType.Touch then
		return
	end
	local current = Vector2.new(input.Position.X, input.Position.Y)
	if pointerStart and (current - pointerStart).Magnitude > DRAG_THRESHOLD then
		pointerDragged = true
	end
	if pointerDragged and lastPointer then
		local delta = current - lastPointer
		targetYaw -= delta.X * ROTATE_SPEED
		targetPitch = math.clamp(targetPitch - delta.Y * ROTATE_SPEED, math.rad(-75), math.rad(75))
	end
	lastPointer = current
end)

UserInputService.InputEnded:Connect(function(input)
	if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then
		return
	end
	local endPosition = Vector2.new(input.Position.X, input.Position.Y)
	local shouldClick = pointerDown and not pointerDragged
	pointerDown = false
	pointerStart = nil
	lastPointer = nil
	pointerDragged = false
	if shouldClick then
		local tileIndex = pickTile(endPosition)
		if tileIndex ~= nil then
			selectTile(tileIndex)
		end
	end
end)

RunService:BindToRenderStep("GrowTinyPlanetCamera", Enum.RenderPriority.Camera.Value + 1, function(dt)
	if not planet then
		return
	end
	camera.CameraType = Enum.CameraType.Scriptable
	local alpha = 1 - math.exp(-9 * dt)
	yaw += (targetYaw - yaw) * alpha
	pitch += (targetPitch - pitch) * alpha
	distance += (targetDistance - distance) * alpha
	local orbit = CFrame.fromOrientation(pitch, yaw, 0)
	local cameraPosition = planetCenter - orbit.LookVector * distance
	camera.CFrame = CFrame.lookAt(cameraPosition, planetCenter, Vector3.yAxis)
	camera.Focus = CFrame.new(planetCenter)
end)

updateEnergy.OnClientEvent:Connect(function(value)
	if typeof(value) == "number" then
		state.Energy = value
		refreshUI()
	end
end)

updateStats.OnClientEvent:Connect(function(stats)
	if typeof(stats) == "table" then
		state.Stats = stats
		if typeof(stats.Ownership) == "table" then
			state.Ownership = stats.Ownership
		end
		refreshUI()
	end
end)

updateTile.OnClientEvent:Connect(function(info)
	if typeof(info) ~= "table" or typeof(info.tileIndex) ~= "number" then
		return
	end
	if state.Tiles then
		state.Tiles[info.tileIndex + 1] = info.tileType
	end
	if tilesFolder then
		local tile = tilesFolder:FindFirstChild("Tile_" .. info.tileIndex)
		if tile then
			local color, material, transparency = PlanetMath.getTileVisual(info.tileType, info.tileIndex, planet:GetAttribute("CosmicSkin") == true)
			tile.Color = color
			tile.Material = material
			tile.Transparency = transparency
			tile:SetAttribute("TileType", info.tileType)
		end
	end
end)

milestoneReached.OnClientEvent:Connect(function(info)
	if typeof(info) == "table" then
		showToast((info.Title or "Milestone reached!") .. " — " .. (info.Message or ""), "milestone")
	end
end)

notifyRemote.OnClientEvent:Connect(function(info)
	if typeof(info) == "table" then
		showToast((info.Title or "Notice") .. ": " .. (info.Message or ""), "warning")
	end
end)

purchaseConfirmed.OnClientEvent:Connect(function()
	showToast("Purchase confirmed and applied.", "success")
end)

local function loadInitialState()
	for _ = 1, 120 do
		if player:GetAttribute("PlanetReady") == true then
			local ok, result = pcall(function()
				return getPlanetState:InvokeServer()
			end)
			if ok and typeof(result) == "table" then
				state.Energy = result.Energy or state.Energy
				state.Stats = result.Stats
				state.Ownership = result.Ownership or {}
				state.Tiles = result.Tiles
				refreshUI()
				statusLabel.Text = "Click the planet to select a tile, or choose a growth tool first."
				return true
			end
		end
		task.wait(0.25)
	end
	statusLabel.Text = "Planet state did not initialize. Check Output for server errors."
	showToast("Planet state failed to initialize.", "error")
	return false
end

local function bootstrapPlanet()
	local planetsFolder = Workspace:WaitForChild("Planets", 30)
	if not planetsFolder then
		statusLabel.Text = "Planets folder did not replicate."
		showToast("Planets folder missing.", "error")
		return false
	end

	planet = planetsFolder:WaitForChild("Planet_" .. player.UserId, 60)
	if not planet then
		statusLabel.Text = "Your planet model did not replicate."
		showToast("Planet model missing.", "error")
		return false
	end

	planetCenter = readPlanetCenter(planet)
	planetRadius = planet:GetAttribute("PlanetRadius") or config.PLANET_RADIUS

	camera.CameraType = Enum.CameraType.Scriptable
	camera.FieldOfView = 55
	camera.CFrame = CFrame.lookAt(planetCenter + Vector3.new(0, 20, 118), planetCenter)
	camera.Focus = CFrame.new(planetCenter)

	if Workspace.StreamingEnabled then
		pcall(function()
			player:RequestStreamAroundAsync(planetCenter, 8)
		end)
	end

	local readyDeadline = os.clock() + 20
	while planet:GetAttribute("Ready") ~= true and os.clock() < readyDeadline do
		task.wait(0.05)
	end

	tilesFolder = planet:FindFirstChild("Tiles") or planet:WaitForChild("Tiles", 20)
	if tilesFolder then
		tilesFolder.ChildAdded:Connect(function(child)
			if selectedTile >= 0 and child.Name == "Tile_" .. selectedTile then
				refreshHighlight()
			end
		end)
	end

	print(string.format("[Grow a Tiny Planet] Client attached to %s at %s", planet.Name, tostring(planetCenter)))
	return true
end

refreshUI()
task.spawn(function()
	if bootstrapPlanet() then
		loadInitialState()
	end
end)
