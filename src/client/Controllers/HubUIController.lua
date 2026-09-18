--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local Theme = require(script.Parent.Parent.UI.Theme)

local HubUIController = {}
local initialized = false

local ENTER_FACTORY_REMOTE = "HubEnterFactory"
local COLORS = Theme.Colors

local player = Players.LocalPlayer
local populationValue: TextLabel? = nil
local statusLabel: TextLabel? = nil

local function corner(parent: Instance, radius: number)
	local uiCorner = Instance.new("UICorner")
	uiCorner.CornerRadius = UDim.new(0, radius)
	uiCorner.Parent = parent
end

local function stroke(parent: Instance, color: Color3, transparency: number)
	local uiStroke = Instance.new("UIStroke")
	uiStroke.Color = color
	uiStroke.Thickness = 1
	uiStroke.Transparency = transparency
	uiStroke.Parent = parent
end

local function makeLabel(
	parent: Instance,
	name: string,
	text: string,
	font: Enum.Font,
	textSize: number,
	color: Color3,
	position: UDim2,
	size: UDim2
): TextLabel
	local label = Instance.new("TextLabel")
	label.Name = name
	label.BackgroundTransparency = 1
	label.Font = font
	label.Position = position
	label.Size = size
	label.Text = text
	label.TextColor3 = color
	label.TextSize = textSize
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextYAlignment = Enum.TextYAlignment.Center
	label.Parent = parent
	return label
end

local function refreshPopulation()
	local value = populationValue
	if value == nil then
		return
	end

	value.Text = ("%d / %d"):format(#Players:GetPlayers(), GameConfig.Session.HubTargetPlayers)
end

local function setFactoryStatus(text: string, color: Color3)
	local label = statusLabel
	if label ~= nil then
		label.Text = text
		label.TextColor3 = color
	end
end

local function createBrandCard(parent: ScreenGui)
	local card = Instance.new("Frame")
	card.Name = "BrandCard"
	card.BackgroundColor3 = COLORS.Panel
	card.BackgroundTransparency = 0.08
	card.BorderSizePixel = 0
	card.Position = UDim2.fromOffset(18, 18)
	card.Size = UDim2.fromOffset(286, 72)
	card.Parent = parent
	corner(card, 12)
	stroke(card, Color3.fromRGB(68, 81, 96), 0.2)

	local accent = Instance.new("Frame")
	accent.Name = "Accent"
	accent.BackgroundColor3 = Color3.fromRGB(73, 202, 222)
	accent.BorderSizePixel = 0
	accent.Position = UDim2.fromOffset(0, 10)
	accent.Size = UDim2.fromOffset(4, 52)
	accent.Parent = card
	corner(accent, 2)

	makeLabel(
		card,
		"Title",
		"SCRAP-TO-BOT",
		Enum.Font.GothamBold,
		19,
		COLORS.Text,
		UDim2.fromOffset(18, 10),
		UDim2.new(1, -32, 0, 25)
	)

	makeLabel(
		card,
		"Subtitle",
		"FACTORY DISTRICT",
		Enum.Font.GothamBold,
		11,
		Color3.fromRGB(174, 187, 201),
		UDim2.fromOffset(18, 35),
		UDim2.new(1, -32, 0, 18)
	)

	local badge = Instance.new("TextLabel")
	badge.Name = "HubBadge"
	badge.AnchorPoint = Vector2.new(1, 0.5)
	badge.BackgroundColor3 = Color3.fromRGB(47, 130, 145)
	badge.BorderSizePixel = 0
	badge.Font = Enum.Font.GothamBold
	badge.Position = UDim2.new(1, -12, 0.5, 12)
	badge.Size = UDim2.fromOffset(48, 20)
	badge.Text = "HUB"
	badge.TextColor3 = Color3.fromRGB(226, 250, 255)
	badge.TextSize = 10
	badge.Parent = card
	corner(badge, 6)
end

local function createPopulationCard(parent: ScreenGui)
	local card = Instance.new("Frame")
	card.Name = "PopulationCard"
	card.AnchorPoint = Vector2.new(1, 0)
	card.BackgroundColor3 = COLORS.Panel
	card.BackgroundTransparency = 0.08
	card.BorderSizePixel = 0
	card.Position = UDim2.new(1, -18, 0, 18)
	card.Size = UDim2.fromOffset(168, 64)
	card.Parent = parent
	corner(card, 12)
	stroke(card, Color3.fromRGB(68, 81, 96), 0.2)

	makeLabel(
		card,
		"Title",
		"HUB POPULATION",
		Enum.Font.GothamBold,
		10,
		COLORS.Muted,
		UDim2.fromOffset(14, 8),
		UDim2.new(1, -28, 0, 18)
	)

	populationValue = makeLabel(
		card,
		"Value",
		"0 / 16",
		Enum.Font.GothamBold,
		22,
		COLORS.Text,
		UDim2.fromOffset(14, 26),
		UDim2.new(1, -28, 0, 28)
	)
end

local function createFactoryCard(parent: ScreenGui)
	local card = Instance.new("Frame")
	card.Name = "FactoryCard"
	card.AnchorPoint = Vector2.new(0.5, 1)
	card.BackgroundColor3 = COLORS.Panel
	card.BackgroundTransparency = 0.04
	card.BorderSizePixel = 0
	card.Position = UDim2.new(0.5, 0, 1, -24)
	card.Size = UDim2.fromOffset(520, 122)
	card.Parent = parent
	corner(card, 14)
	stroke(card, Color3.fromRGB(70, 87, 105), 0.15)

	local iconPlate = Instance.new("Frame")
	iconPlate.Name = "IconPlate"
	iconPlate.BackgroundColor3 = Color3.fromRGB(39, 92, 104)
	iconPlate.BorderSizePixel = 0
	iconPlate.Position = UDim2.fromOffset(16, 16)
	iconPlate.Size = UDim2.fromOffset(64, 64)
	iconPlate.Parent = card
	corner(iconPlate, 12)

	local icon = makeLabel(
		iconPlate,
		"Icon",
		"⚙",
		Enum.Font.GothamBold,
		34,
		Color3.fromRGB(178, 239, 249),
		UDim2.fromScale(0, 0),
		UDim2.fromScale(1, 1)
	)
	icon.TextXAlignment = Enum.TextXAlignment.Center

	makeLabel(
		card,
		"Title",
		"YOUR FACTORY",
		Enum.Font.GothamBold,
		17,
		COLORS.Text,
		UDim2.fromOffset(94, 15),
		UDim2.fromOffset(230, 24)
	)

	makeLabel(
		card,
		"Description",
		"Private production instance • your machines, robots, salvage, and progression.",
		Enum.Font.Gotham,
		12,
		COLORS.Muted,
		UDim2.fromOffset(94, 40),
		UDim2.fromOffset(250, 40)
	).TextWrapped =
		true

	local button = Instance.new("TextButton")
	button.Name = "EnterFactory"
	button.AnchorPoint = Vector2.new(1, 0)
	button.BackgroundColor3 = COLORS.AccentDark
	button.BorderSizePixel = 0
	button.Font = Enum.Font.GothamBold
	button.Position = UDim2.new(1, -16, 0, 20)
	button.Size = UDim2.fromOffset(150, 46)
	button.Text = if RunService:IsStudio() then "LIVE CLIENT ONLY" else "ENTER FACTORY"
	button.TextColor3 = COLORS.Text
	button.TextSize = if RunService:IsStudio() then 11 else 13
	button.AutoButtonColor = not RunService:IsStudio()
	button.Active = not RunService:IsStudio()
	button.Parent = card
	corner(button, 9)

	statusLabel = makeLabel(
		card,
		"Status",
		if RunService:IsStudio()
			then "Teleporting is disabled in Studio."
			else "Ready to enter your private instance.",
		Enum.Font.GothamMedium,
		10,
		if RunService:IsStudio() then Color3.fromRGB(226, 180, 90) else COLORS.Accent,
		UDim2.fromOffset(16, 91),
		UDim2.new(1, -32, 0, 18)
	)
	statusLabel.TextXAlignment = Enum.TextXAlignment.Center

	if not RunService:IsStudio() then
		button.Activated:Connect(function()
			if not button.Active then
				return
			end

			local remote = ReplicatedStorage:FindFirstChild(ENTER_FACTORY_REMOTE)
			if remote == nil or not remote:IsA("RemoteEvent") then
				setFactoryStatus("Factory service unavailable. Try again.", COLORS.Danger)
				return
			end

			button.Active = false
			button.AutoButtonColor = false
			button.Text = "CONNECTING..."
			setFactoryStatus("Reserving your private factory...", Color3.fromRGB(121, 211, 228))
			remote:FireServer()

			task.delay(8, function()
				if button.Parent ~= nil then
					button.Active = true
					button.AutoButtonColor = true
					button.Text = "ENTER FACTORY"
					setFactoryStatus("Ready to enter your private instance.", COLORS.Accent)
				end
			end)
		end)
	end
end

local function bindResponsiveLayout(gui: ScreenGui)
	local connection: RBXScriptConnection? = nil

	local function bindCamera()
		if connection ~= nil then
			connection:Disconnect()
			connection = nil
		end

		local camera = Workspace.CurrentCamera
		if camera == nil then
			return
		end

		local function refresh()
			local compact = camera.ViewportSize.X <= 760
			local brand = gui:FindFirstChild("BrandCard")
			local population = gui:FindFirstChild("PopulationCard")
			local factory = gui:FindFirstChild("FactoryCard")

			if brand ~= nil and brand:IsA("Frame") then
				brand.Position = if compact
					then UDim2.fromOffset(10, 10)
					else UDim2.fromOffset(18, 18)
				brand.Size = if compact
					then UDim2.fromOffset(236, 64)
					else UDim2.fromOffset(286, 72)
			end

			if population ~= nil and population:IsA("Frame") then
				population.Position = if compact
					then UDim2.new(1, -10, 0, 10)
					else UDim2.new(1, -18, 0, 18)
				population.Size = if compact
					then UDim2.fromOffset(132, 56)
					else UDim2.fromOffset(168, 64)
			end

			if factory ~= nil and factory:IsA("Frame") then
				factory.Position = if compact
					then UDim2.new(0.5, 0, 1, -12)
					else UDim2.new(0.5, 0, 1, -24)
				factory.Size = if compact
					then UDim2.new(1, -20, 0, 116)
					else UDim2.fromOffset(520, 122)
			end
		end

		refresh()
		connection = camera:GetPropertyChangedSignal("ViewportSize"):Connect(refresh)
	end

	bindCamera()
	Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(bindCamera)
end

local function createUi()
	local playerGui = player:WaitForChild("PlayerGui")
	local existing = playerGui:FindFirstChild("HubHUD")
	if existing ~= nil then
		existing:Destroy()
	end

	local gui = Instance.new("ScreenGui")
	gui.Name = "HubHUD"
	gui.DisplayOrder = 20
	gui.IgnoreGuiInset = false
	gui.ResetOnSpawn = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = playerGui

	createBrandCard(gui)
	createPopulationCard(gui)
	createFactoryCard(gui)
	bindResponsiveLayout(gui)
	refreshPopulation()
end

function HubUIController.Init()
	if initialized then
		return
	end
	initialized = true

	createUi()

	Players.PlayerAdded:Connect(refreshPopulation)
	Players.PlayerRemoving:Connect(function()
		task.defer(refreshPopulation)
	end)
end

return table.freeze(HubUIController)
