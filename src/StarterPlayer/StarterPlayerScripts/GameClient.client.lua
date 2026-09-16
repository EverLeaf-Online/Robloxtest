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

local planet
local tilesFolder
local objectsFolder
local planetCenter = Vector3.zero
local planetRadius = config.PLANET_RADIUS
local selectedTile = -1
local pendingAction
local highlight
local animalBases = {}

local yaw = math.rad(35)
local pitch = math.rad(-12)
local targetYaw = yaw
local targetPitch = pitch
local distance = 118
local targetDistance = distance
local pointerDown = false
local pointerStart
local lastPointer
local pointerDragged = false

local MIN_DISTANCE = 82
local MAX_DISTANCE = 220
local DRAG_THRESHOLD = 8
local ROTATE_SPEED = 0.0055

local ACTIONS = {
	{ Key = config.ACTIONS.AddWater, Label = "Add Water", Icon = "💧", Cost = config.COSTS.AddWater },
	{ Key = config.ACTIONS.AddPlant, Label = "Add Plants", Icon = "🌱", Cost = config.COSTS.AddPlant },
	{ Key = config.ACTIONS.AddAnimal, Label = "Add Animal", Icon = "🐾", Cost = config.COSTS.AddAnimal, Unlock = "Animal" },
	{ Key = config.ACTIONS.BuildSettlement, Label = "Build Settlement", Icon = "🏠", Cost = config.COSTS.BuildSettlement, Unlock = "Settlement" },
}

local actionByKey = {}
for _, action in ipairs(ACTIONS) do
	actionByKey[action.Key] = action
end

local function corner(parent, radius)
	local value = Instance.new("UICorner")
	value.CornerRadius = UDim.new(0, radius or 10)
	value.Parent = parent
end

local function stroke(parent, color, transparency)
	local value = Instance.new("UIStroke")
	value.Color = color or config.COLORS.UI.Accent
	value.Thickness = 1.25
	value.Transparency = transparency or 0.35
	value.Parent = parent
end

local gui = Instance.new("ScreenGui")
gui.Name = "GrowTinyPlanetGui"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = false
gui.DisplayOrder = 20
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = playerGui

local scale = Instance.new("UIScale")
scale.Parent = gui

local function refreshScale()
	local viewport = camera.ViewportSize
	scale.Scale = math.clamp(math.min(viewport.X / 1440, viewport.Y / 900), 0.72, 1)
end
refreshScale()
camera:GetPropertyChangedSignal("ViewportSize"):Connect(refreshScale)

local function panel(name, size, position, anchor)
	local frame = Instance.new("Frame")
	frame.Name = name
	frame.Size = size
	frame.Position = position
	frame.AnchorPoint = anchor or Vector2.zero
	frame.BackgroundColor3 = config.COLORS.UI.Background
	frame.BackgroundTransparency = 0.04
	frame.BorderSizePixel = 0
	frame.Parent = gui
	corner(frame, 14)
	stroke(frame, config.COLORS.UI.Accent, 0.35)
	return frame
end

local function label(parent, text, size, position, textSize, bold, alignment)
	local value = Instance.new("TextLabel")
	value.BackgroundTransparency = 1
	value.Text = text
	value.Size = size
	value.Position = position
	value.Font = bold and Enum.Font.GothamBold or Enum.Font.Gotham
	value.TextSize = textSize or 14
	value.TextColor3 = config.COLORS.UI.Text
	value.TextXAlignment = alignment or Enum.TextXAlignment.Left
	value.TextYAlignment = Enum.TextYAlignment.Center
	value.TextWrapped = true
	value.Parent = parent
	return value
end

local function button(parent, text, size, position)
	local value = Instance.new("TextButton")
	value.AutoButtonColor = false
	value.BackgroundColor3 = config.COLORS.UI.Button
	value.BorderSizePixel = 0
	value.Text = text
	value.TextColor3 = config.COLORS.UI.Text
	value.Font = Enum.Font.GothamSemibold
	value.TextSize = 15
	value.TextWrapped = true
	value.Size = size
	value.Position = position
	value.Parent = parent
	corner(value, 10)
	stroke(value, config.COLORS.UI.Accent2, 0.45)
	return value
end

local main = panel("MainPanel", UDim2.fromOffset(300, 562), UDim2.fromOffset(16, 12))
label(main, "GROW A TINY PLANET", UDim2.new(1, -24, 0, 32), UDim2.fromOffset(12, 10), 20, true, Enum.TextXAlignment.Center)
local energyLabel = label(main, "⚡ Energy: loading...", UDim2.new(1, -24, 0, 26), UDim2.fromOffset(12, 48), 17, true)
energyLabel.TextColor3 = Color3.fromRGB(105, 228, 255)
local statsLabel = label(main, "Loading planet data...", UDim2.new(1, -24, 0, 105), UDim2.fromOffset(12, 82), 13)
statsLabel.TextYAlignment = Enum.TextYAlignment.Top
local selectedLabel = label(main, "Selected tile: none", UDim2.new(1, -24, 0, 24), UDim2.fromOffset(12, 188), 13)
selectedLabel.TextColor3 = Color3.fromRGB(175, 197, 226)

local actionButtons = {}
for index, action in ipairs(ACTIONS) do
	local value = button(main, action.Icon .. "  " .. action.Label, UDim2.new(1, -24, 0, 50), UDim2.fromOffset(12, 222 + (index - 1) * 58))
	actionButtons[action.Key] = value
end

local randomButton = button(main, "🎲 Random valid tile", UDim2.new(1, -24, 0, 42), UDim2.fromOffset(12, 454))
local shopButton = button(main, "🛒 Shop [B]", UDim2.new(1, -24, 0, 42), UDim2.fromOffset(12, 502))

local status = panel("Status", UDim2.fromOffset(560, 54), UDim2.new(0.5, 0, 1, -16), Vector2.new(0.5, 1))
local statusLabel = label(status, "Preparing your planet...", UDim2.new(1, -24, 1, 0), UDim2.fromOffset(12, 0), 13, false, Enum.TextXAlignment.Center)

local toast = Instance.new("TextLabel")
toast.AnchorPoint = Vector2.new(0.5, 0)
toast.Position = UDim2.new(0.5, 0, 0, 12)
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
corner(toast, 12)
stroke(toast, config.COLORS.UI.Accent, 0.35)
local toastGeneration = 0

local shop = panel("Shop", UDim2.fromOffset(610, 520), UDim2.new(0.5, 0, 0.5, 0), Vector2.new(0.5, 0.5))
shop.Visible = false
shop.ZIndex = 50
local shopTitle = label(shop, "COSMIC SHOP", UDim2.new(1, -90, 0, 36), UDim2.fromOffset(20, 12), 21, true)
shopTitle.ZIndex = 52
local closeShop = button(shop, "✕", UDim2.fromOffset(42, 36), UDim2.new(1, -58, 0, 12))
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
		if generation == toastGeneration then
			TweenService:Create(toast, TweenInfo.new(0.2), { BackgroundTransparency = 1, TextTransparency = 1 }):Play()
		end
	end)
end

local function setEnabled(control, enabled)
	control.Active = enabled
	control.Selectable = enabled
	control.BackgroundColor3 = enabled and config.COLORS.UI.Button or config.COLORS.UI.ButtonDisabled
	control.TextTransparency = enabled and 0 or 0.42
end

local function fallbackStatsFromAttributes()
	return {
		Developed = player:GetAttribute("PlanetDeveloped") or 0,
		Water = player:GetAttribute("PlanetWater") or 0,
		Plants = player:GetAttribute("PlanetPlants") or 0,
		Glow = player:GetAttribute("PlanetGlow") or 0,
		Animals = player:GetAttribute("PlanetAnimals") or 0,
		Settlements = player:GetAttribute("PlanetSettlements") or 0,
		Unlocks = {
			Animal = (player:GetAttribute("PlanetDeveloped") or 0) >= 10,
			Settlement = (player:GetAttribute("PlanetDeveloped") or 0) >= 25,
			Golden = (player:GetAttribute("PlanetDeveloped") or 0) >= 50,
		},
	}
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
		local unlocked = not action.Unlock or unlocks[action.Unlock] == true
		local enabled = unlocked and (state.Energy or 0) >= action.Cost
		local control = actionButtons[action.Key]
		setEnabled(control, enabled)
		if not unlocked then
			local requirement = action.Unlock == "Animal" and "10 developed tiles" or "25 developed tiles"
			control.Text = "🔒 " .. action.Label .. " — " .. requirement
		elseif pendingAction == action.Key then
			control.Text = "🎯 " .. action.Label .. " — CLICK PLANET"
		else
			control.Text = string.format("%s  %s  •  %d Energy", action.Icon, action.Label, action.Cost)
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
	corner(card, 10)
	local itemName = label(card, entry.Name, UDim2.new(1, -150, 0, 24), UDim2.fromOffset(12, 8), 15, true)
	itemName.ZIndex = 53
	local description = label(card, entry.Description, UDim2.new(1, -150, 0, 46), UDim2.fromOffset(12, 32), 12)
	description.TextYAlignment = Enum.TextYAlignment.Top
	description.ZIndex = 53
	local buy = button(card, entry.Price, UDim2.fromOffset(118, 42), UDim2.new(1, -130, 0.5, -21))
	buy.ZIndex = 53
	if entry.Id == 0 then
		buy.Text = "Not configured"
		setEnabled(buy, false)
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
	shop.Visible = typeof(force) == "boolean" and force or not shop.Visible
end
shopButton.Activated:Connect(function() toggleShop() end)
closeShop.Activated:Connect(function() toggleShop(false) end)

local function nearestTile(direction)
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
	local direction = ray.Direction.Unit
	local origin = ray.Origin - planetCenter
	local radius = planetRadius + 2.5
	local b = 2 * origin:Dot(direction)
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
	local hit = ray.Origin + direction * t
	return nearestTile((hit - planetCenter).Unit)
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
	local value = Instance.new("Highlight")
	value.Name = "SelectedTileHighlight"
	value.Adornee = tile
	value.FillColor = config.COLORS.UI.Accent
	value.OutlineColor = config.COLORS.UI.Accent2
	value.FillTransparency = 0.62
	value.OutlineTransparency = 0
	value.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	value.Parent = planet
	highlight = value
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
	else
		showToast("Choose a growth action first.", "warning")
	end
end)

local function selectTile(index)
	selectedTile = index
	refreshHighlight()
	refreshUI()
	statusLabel.Text = "Tile #" .. index .. " selected. Choose an action."
	if pendingAction then
		local actionKey = pendingAction
		pendingAction = nil
		sendAction(actionKey, index)
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
		local index = pickTile(endPosition)
		if index ~= nil then
			selectTile(index)
		end
	end
end)

local function registerAnimal(obj)
	if obj:IsA("BasePart") and obj:GetAttribute("AnimalType") then
		animalBases[obj] = obj.CFrame
	end
end

RunService:BindToRenderStep("GrowTinyPlanetRuntime", Enum.RenderPriority.Camera.Value + 1, function(dt)
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

	local now = os.clock()
	for part, baseCFrame in pairs(animalBases) do
		if part.Parent then
			local seed = part:GetAttribute("Seed") or 0
			part.CFrame = baseCFrame * CFrame.new(0, math.sin(now * 2.2 + seed) * 0.65, 0) * CFrame.Angles(0, now * 0.8 + seed, 0)
		else
			animalBases[part] = nil
		end
	end

	local moon = planet:FindFirstChild("Moon")
	if moon then
		local radius = moon:GetAttribute("OrbitRadius") or 80
		local speed = moon:GetAttribute("OrbitSpeed") or 0.25
		local angle = now * speed
		moon.CFrame = CFrame.lookAt(planetCenter + Vector3.new(math.cos(angle) * radius, math.sin(angle * 0.6) * 18, math.sin(angle) * radius), planetCenter)
	end
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
		state.Ownership = typeof(stats.Ownership) == "table" and stats.Ownership or state.Ownership
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

local function bootstrapPlanet()
	local planets = Workspace:WaitForChild("Planets", 30)
	if not planets then
		showToast("Planets folder missing.", "error")
		return false
	end
	planet = planets:WaitForChild("Planet_" .. player.UserId, 60)
	if not planet then
		showToast("Your planet model did not replicate.", "error")
		return false
	end

	planetCenter = Vector3.new(
		planet:GetAttribute("CenterX") or player:GetAttribute("PlanetCenterX") or 0,
		planet:GetAttribute("CenterY") or player:GetAttribute("PlanetCenterY") or 0,
		planet:GetAttribute("CenterZ") or player:GetAttribute("PlanetCenterZ") or 0
	)
	planetRadius = planet:GetAttribute("PlanetRadius") or player:GetAttribute("PlanetRadius") or config.PLANET_RADIUS

	camera.CameraType = Enum.CameraType.Scriptable
	camera.FieldOfView = 55
	camera.CFrame = CFrame.lookAt(planetCenter + Vector3.new(0, 20, 118), planetCenter)
	camera.Focus = CFrame.new(planetCenter)

	if Workspace.StreamingEnabled then
		pcall(function()
			player:RequestStreamAroundAsync(planetCenter, 8)
		end)
	end

	tilesFolder = planet:FindFirstChild("Tiles") or planet:WaitForChild("Tiles", 20)
	objectsFolder = planet:FindFirstChild("Objects") or planet:WaitForChild("Objects", 20)
	if tilesFolder then
		tilesFolder.ChildAdded:Connect(function(child)
			if selectedTile >= 0 and child.Name == "Tile_" .. selectedTile then
				refreshHighlight()
			end
		end)
	end
	if objectsFolder then
		for _, obj in ipairs(objectsFolder:GetChildren()) do
			registerAnimal(obj)
		end
		objectsFolder.ChildAdded:Connect(function(obj)
			task.defer(registerAnimal, obj)
		end)
	end

	print(string.format("[Grow a Tiny Planet] Unified client attached to %s at %s", planet.Name, tostring(planetCenter)))
	return true
end

local function loadInitialState()
	for _ = 1, 120 do
		local initError = player:GetAttribute("PlanetInitError")
		if typeof(initError) == "string" and initError ~= "" then
			statusLabel.Text = "Server initialization failed. See Output."
			showToast("Server init error: " .. initError, "error")
			return false
		end

		if player:GetAttribute("PlanetReady") == true then
			state.Energy = player:GetAttribute("PlanetEnergy") or state.Energy
			state.Stats = fallbackStatsFromAttributes()
			refreshUI()
			statusLabel.Text = "Planet ready. Loading full state..."

			local ok, result = pcall(function()
				return getPlanetState:InvokeServer()
			end)
			if ok and typeof(result) == "table" then
				state.Energy = result.Energy or state.Energy
				state.Stats = result.Stats or state.Stats
				state.Ownership = result.Ownership or {}
				state.Tiles = result.Tiles
				refreshUI()
			end
			statusLabel.Text = "Click the planet to select a tile, or choose a growth tool first."
			return true
		end
		task.wait(0.25)
	end
	statusLabel.Text = "Planet initialization timed out. Check Output."
	showToast("Planet initialization timed out.", "error")
	return false
end

for _, attribute in ipairs({ "PlanetEnergy", "PlanetDeveloped", "PlanetWater", "PlanetPlants", "PlanetGlow", "PlanetAnimals", "PlanetSettlements" }) do
	player:GetAttributeChangedSignal(attribute):Connect(function()
		if player:GetAttribute("PlanetReady") == true then
			state.Energy = player:GetAttribute("PlanetEnergy") or state.Energy
			state.Stats = fallbackStatsFromAttributes()
			refreshUI()
		end
	end)
end

refreshUI()
task.spawn(function()
	if bootstrapPlanet() then
		loadInitialState()
	end
end)
