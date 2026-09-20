--!strict

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)

local HUDIconFactory = require(script.Parent.Parent.UI.HUDIconFactory)
local Theme = require(script.Parent.Parent.UI.Theme)
local UIBus = require(script.Parent.Parent.UI.UIBus)

local HubUIController = {}
local initialized = false

local COLORS = Theme.Colors
local player = Players.LocalPlayer

type PanelName = "Shop" | "Social" | "Codes"

local populationLabel: TextLabel? = nil
local activePanel: PanelName? = nil
local panelFrame: Frame? = nil
local panelTween: Tween? = nil
local launcherFrame: Frame? = nil
local phoneLayout = false
local launcherHints: { [PanelName]: TextLabel } = {}

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

local function label(
	parent: Instance,
	name: string,
	text: string,
	font: Enum.Font,
	textSize: number,
	color: Color3,
	position: UDim2,
	size: UDim2
): TextLabel
	local value = Instance.new("TextLabel")
	value.Name = name
	value.BackgroundTransparency = 1
	value.Font = font
	value.Position = position
	value.Size = size
	value.Text = text
	value.TextColor3 = color
	value.TextSize = textSize
	value.TextStrokeColor3 = Color3.new(0, 0, 0)
	value.TextStrokeTransparency = 0.32
	value.TextXAlignment = Enum.TextXAlignment.Left
	value.TextYAlignment = Enum.TextYAlignment.Center
	value.Parent = parent
	return value
end

local function refreshPopulation()
	local current = populationLabel
	if current == nil then
		return
	end

	current.Text = ("%d / %d"):format(#Players:GetPlayers(), GameConfig.Session.HubTargetPlayers)
end

local function makeMonogramIcon(parent: Instance, text: string, accent: Color3, size: number): Frame
	local plate = Instance.new("Frame")
	plate.Name = "Icon"
	plate.AnchorPoint = Vector2.new(0, 0.5)
	plate.BackgroundColor3 = Color3.fromRGB(28, 33, 41)
	plate.BorderSizePixel = 0
	plate.Position = UDim2.fromScale(0, 0.5)
	plate.Size = UDim2.fromOffset(size, size)
	plate.Parent = parent
	corner(plate, math.floor(size * 0.22))
	stroke(plate, accent, 0.18)

	local glyph = label(
		plate,
		"Glyph",
		text,
		Enum.Font.GothamBold,
		math.floor(size * 0.42),
		accent,
		UDim2.fromScale(0, 0),
		UDim2.fromScale(1, 1)
	)
	glyph.TextXAlignment = Enum.TextXAlignment.Center
	return plate
end

local function createLauncher(
	parent: Instance,
	panelName: PanelName,
	title: string,
	order: number,
	accent: Color3,
	iconKind: "Shop" | "Monogram",
	monogram: string?
): TextButton
	local button = Instance.new("TextButton")
	button.Name = panelName .. "Launcher"
	button.LayoutOrder = order
	button.BackgroundTransparency = 1
	button.BorderSizePixel = 0
	button.Size = UDim2.fromOffset(158, 54)
	button.Text = ""
	button.Active = true
	button.AutoButtonColor = false
	button.Selectable = true
	button.Parent = parent

	if iconKind == "Shop" then
		local icon = HUDIconFactory.CreateShop(button, 50)
		icon.AnchorPoint = Vector2.new(0, 0.5)
		icon.Position = UDim2.fromScale(0, 0.5)
	else
		makeMonogramIcon(button, monogram or "•", accent, 48)
	end

	label(
		button,
		"Title",
		title,
		Enum.Font.GothamBold,
		11,
		COLORS.Text,
		UDim2.fromOffset(56, 8),
		UDim2.new(1, -78, 0, 18)
	)

	local hint = label(
		button,
		"Hint",
		"OPEN",
		Enum.Font.GothamBold,
		10,
		accent,
		UDim2.fromOffset(56, 27),
		UDim2.new(1, -78, 0, 16)
	)
	launcherHints[panelName] = hint

	local arrow = label(
		button,
		"Arrow",
		"›",
		Enum.Font.GothamBold,
		27,
		COLORS.Text,
		UDim2.new(1, -22, 0, 8),
		UDim2.fromOffset(22, 36)
	)
	arrow.TextXAlignment = Enum.TextXAlignment.Center

	button.Activated:Connect(function()
		local nextPanel = if activePanel == panelName then nil else panelName
		HubUIController.OpenPanel(nextPanel)
	end)

	return button
end

local function clearPanelContent()
	local panel = panelFrame
	if panel == nil then
		return
	end

	for _, child in panel:GetChildren() do
		if child:GetAttribute("PanelContent") == true then
			child:Destroy()
		end
	end
end

local function addPanelLabel(
	panel: Frame,
	name: string,
	text: string,
	textSize: number,
	color: Color3,
	y: number,
	height: number,
	bold: boolean?
): TextLabel
	local item = label(
		panel,
		name,
		text,
		if bold then Enum.Font.GothamBold else Enum.Font.Gotham,
		textSize,
		color,
		UDim2.fromOffset(18, y),
		UDim2.new(1, -36, 0, height)
	)
	item.TextWrapped = true
	item.TextYAlignment = Enum.TextYAlignment.Top
	item:SetAttribute("PanelContent", true)
	return item
end

local function renderShop(panel: Frame)
	addPanelLabel(panel, "Title", "DISTRICT SHOP", 17, COLORS.Text, 16, 24, true)
	addPanelLabel(
		panel,
		"Body",
		"Hub cosmetics, social items, event items, and other district purchases will live here.",
		12,
		COLORS.Muted,
		48,
		50
	)

	local callout = Instance.new("Frame")
	callout.Name = "ComingSoon"
	callout.BackgroundColor3 = COLORS.PanelSoft
	callout.BackgroundTransparency = 0.08
	callout.BorderSizePixel = 0
	callout.Position = UDim2.fromOffset(18, 112)
	callout.Size = UDim2.new(1, -36, 0, 72)
	callout:SetAttribute("PanelContent", true)
	callout.Parent = panel
	corner(callout, 9)

	addPanelLabel(
		callout,
		"CalloutTitle",
		"MORE SHOP ITEMS COMING",
		11,
		Color3.fromRGB(104, 223, 151),
		10,
		18,
		true
	)
	addPanelLabel(
		callout,
		"CalloutBody",
		"This Hub shop stays separate from factory progression purchases.",
		11,
		COLORS.Muted,
		31,
		30
	)
end

local function renderSocial(panel: Frame)
	addPanelLabel(panel, "Title", "SOCIAL", 17, COLORS.Text, 16, 24, true)
	addPanelLabel(
		panel,
		"Body",
		"This is the home for friends, parties, factory visits, and other co-op features.",
		12,
		COLORS.Muted,
		48,
		48
	)
	addPanelLabel(
		panel,
		"Status",
		"FRIEND VISITS + PARTIES  •  COMING NEXT",
		11,
		Color3.fromRGB(105, 183, 239),
		112,
		22,
		true
	)
end

local function renderCodes(panel: Frame)
	addPanelLabel(panel, "Title", "CODES", 17, COLORS.Text, 16, 24, true)
	addPanelLabel(
		panel,
		"Body",
		"Promo and community-code redemption will appear here when the code service is enabled.",
		12,
		COLORS.Muted,
		48,
		48
	)

	local input = Instance.new("TextBox")
	input.Name = "CodeInput"
	input.BackgroundColor3 = COLORS.PanelSoft
	input.BorderSizePixel = 0
	input.ClearTextOnFocus = false
	input.Font = Enum.Font.GothamBold
	input.PlaceholderText = "ENTER CODE"
	input.PlaceholderColor3 = Color3.fromRGB(126, 137, 151)
	input.Position = UDim2.fromOffset(18, 112)
	input.Size = UDim2.new(1, -124, 0, 38)
	input.Text = ""
	input.TextColor3 = COLORS.Text
	input.TextSize = 12
	input.TextEditable = false
	input:SetAttribute("PanelContent", true)
	input.Parent = panel
	corner(input, 8)

	local redeem = Instance.new("TextButton")
	redeem.Name = "Redeem"
	redeem.AnchorPoint = Vector2.new(1, 0)
	redeem.BackgroundColor3 = COLORS.PanelSoft
	redeem.BorderSizePixel = 0
	redeem.Font = Enum.Font.GothamBold
	redeem.Position = UDim2.new(1, -18, 0, 112)
	redeem.Size = UDim2.fromOffset(88, 38)
	redeem.Text = "SOON"
	redeem.TextColor3 = COLORS.Muted
	redeem.TextSize = 11
	redeem.AutoButtonColor = false
	redeem.Active = false
	redeem:SetAttribute("PanelContent", true)
	redeem.Parent = panel
	corner(redeem, 8)
end

local function renderPanel(panelName: PanelName)
	local panel = panelFrame
	if panel == nil then
		return
	end

	clearPanelContent()
	if panelName == "Shop" then
		renderShop(panel)
	elseif panelName == "Social" then
		renderSocial(panel)
	else
		renderCodes(panel)
	end
end

function HubUIController.OpenPanel(panelName: PanelName?)
	local panel = panelFrame
	if panel == nil then
		return
	end

	if panelTween ~= nil then
		panelTween:Cancel()
		panelTween = nil
	end

	activePanel = panelName
	for name, hint in launcherHints do
		hint.Text = if panelName == name then "CLOSE" else "OPEN"
	end

	if panelName == nil then
		panelTween = TweenService:Create(
			panel,
			TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ Size = UDim2.fromOffset(0, panel.Size.Y.Offset) }
		)
		panelTween.Completed:Once(function()
			panel.Visible = false
			if launcherFrame ~= nil then
				launcherFrame.Visible = true
			end
			panelTween = nil
		end)
		panelTween:Play()
		return
	end

	renderPanel(panelName)
	panel.Visible = true

	local camera = Workspace.CurrentCamera
	local viewportWidth = if camera ~= nil then camera.ViewportSize.X else 390
	local targetWidth = if phoneLayout then math.clamp(viewportWidth - 20, 280, 340) else 310
	local targetHeight = if phoneLayout then 218 else 230
	panel.Position = if phoneLayout then UDim2.fromScale(0.5, 0.54) else UDim2.new(0, 188, 0.58, 0)
	panel.AnchorPoint = if phoneLayout then Vector2.new(0.5, 0.5) else Vector2.new(0, 0.5)

	if launcherFrame ~= nil then
		launcherFrame.Visible = not phoneLayout
	end

	panelTween = TweenService:Create(
		panel,
		TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Size = UDim2.fromOffset(targetWidth, targetHeight) }
	)
	panelTween.Completed:Once(function()
		panelTween = nil
	end)
	panelTween:Play()
end

local function createTopStatus(gui: ScreenGui)
	local cluster = Instance.new("Frame")
	cluster.Name = "HubStatus"
	cluster.AnchorPoint = Vector2.new(0.5, 0)
	cluster.BackgroundTransparency = 1
	cluster.BorderSizePixel = 0
	cluster.Position = UDim2.new(0.5, 0, 0, 10)
	cluster.Size = UDim2.fromOffset(390, 52)
	cluster.Parent = gui

	local district = Instance.new("Frame")
	district.Name = "District"
	district.BackgroundTransparency = 1
	district.BorderSizePixel = 0
	district.Size = UDim2.fromOffset(230, 52)
	district.Parent = cluster

	makeMonogramIcon(district, "H", Color3.fromRGB(74, 211, 229), 44)
	label(
		district,
		"Title",
		"FACTORY DISTRICT",
		Enum.Font.GothamBold,
		11,
		COLORS.Text,
		UDim2.fromOffset(50, 7),
		UDim2.new(1, -50, 0, 17)
	)
	label(
		district,
		"Status",
		"SOCIAL HUB",
		Enum.Font.GothamBold,
		10,
		Color3.fromRGB(74, 211, 229),
		UDim2.fromOffset(50, 25),
		UDim2.new(1, -50, 0, 17)
	)

	local population = Instance.new("Frame")
	population.Name = "Population"
	population.AnchorPoint = Vector2.new(1, 0)
	population.BackgroundTransparency = 1
	population.BorderSizePixel = 0
	population.Position = UDim2.fromScale(1, 0)
	population.Size = UDim2.fromOffset(145, 52)
	population.Parent = cluster

	makeMonogramIcon(population, "P", Color3.fromRGB(104, 223, 151), 44)
	label(
		population,
		"Title",
		"PLAYERS",
		Enum.Font.GothamBold,
		10,
		COLORS.Text,
		UDim2.fromOffset(50, 7),
		UDim2.new(1, -50, 0, 17)
	)
	populationLabel = label(
		population,
		"Value",
		"0 / 16",
		Enum.Font.GothamBold,
		11,
		Color3.fromRGB(104, 223, 151),
		UDim2.fromOffset(50, 25),
		UDim2.new(1, -50, 0, 17)
	)
end

local function createLaunchers(gui: ScreenGui)
	local launchers = Instance.new("Frame")
	launchers.Name = "HubLaunchers"
	launchers.AnchorPoint = Vector2.new(0, 0.5)
	launchers.BackgroundTransparency = 1
	launchers.BorderSizePixel = 0
	launchers.Position = UDim2.new(0, 18, 0.58, 0)
	launchers.Size = UDim2.fromOffset(158, 178)
	launchers.Parent = gui
	launcherFrame = launchers

	local list = Instance.new("UIListLayout")
	list.FillDirection = Enum.FillDirection.Vertical
	list.Padding = UDim.new(0, 8)
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = launchers

	createLauncher(launchers, "Shop", "SHOP", 1, Color3.fromRGB(104, 223, 151), "Shop", nil)
	createLauncher(launchers, "Social", "SOCIAL", 2, Color3.fromRGB(105, 183, 239), "Monogram", "2")

	local panel = Instance.new("Frame")
	panel.Name = "HubPanel"
	panel.AnchorPoint = Vector2.new(0, 0.5)
	panel.BackgroundColor3 = Color3.fromRGB(20, 23, 30)
	panel.BackgroundTransparency = 0.08
	panel.BorderSizePixel = 0
	panel.ClipsDescendants = true
	panel.Position = UDim2.new(0, 188, 0.58, 0)
	panel.Size = UDim2.fromOffset(0, 230)
	panel.Visible = false
	panel.Parent = gui
	corner(panel, 10)
	stroke(panel, Color3.fromRGB(68, 81, 96), 0.2)

	local closeButton = Instance.new("TextButton")
	closeButton.Name = "Close"
	closeButton.AnchorPoint = Vector2.new(1, 0)
	closeButton.BackgroundColor3 = COLORS.PanelSoft
	closeButton.BorderSizePixel = 0
	closeButton.Font = Enum.Font.GothamBold
	closeButton.Position = UDim2.new(1, -12, 0, 10)
	closeButton.Selectable = true
	closeButton.Size = UDim2.fromOffset(72, 44)
	closeButton.Text = "CLOSE"
	closeButton.TextColor3 = COLORS.Text
	closeButton.TextSize = 11
	closeButton.ZIndex = 2
	closeButton.Parent = panel
	corner(closeButton, 8)
	closeButton.Activated:Connect(function()
		HubUIController.OpenPanel(nil)
	end)

	panelFrame = panel
end

local function createObjective(gui: ScreenGui)
	local objective = Instance.new("Frame")
	objective.Name = "HubObjective"
	objective.AnchorPoint = Vector2.new(0.5, 1)
	objective.BackgroundTransparency = 1
	objective.BorderSizePixel = 0
	objective.Position = UDim2.new(0.5, 0, 1, -18)
	objective.Size = UDim2.fromOffset(520, 64)
	objective.Parent = gui

	local title = label(
		objective,
		"Title",
		"Explore the Factory District",
		Enum.Font.GothamBold,
		14,
		COLORS.Accent,
		UDim2.fromOffset(0, 7),
		UDim2.new(1, 0, 0, 18)
	)
	title.TextXAlignment = Enum.TextXAlignment.Center

	local body = label(
		objective,
		"Body",
		"Meet players, browse district services, or use the world portal when you want to enter your private factory.",
		Enum.Font.Gotham,
		12,
		COLORS.Text,
		UDim2.fromOffset(0, 27),
		UDim2.new(1, 0, 1, -32)
	)
	body.TextWrapped = true
	body.TextXAlignment = Enum.TextXAlignment.Center
	body.TextYAlignment = Enum.TextYAlignment.Top
end

local function bindResponsiveLayout(gui: ScreenGui)
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

		local function refresh()
			local phone = camera.ViewportSize.X <= 760
			phoneLayout = phone
			local status = gui:FindFirstChild("HubStatus")
			local launchers = gui:FindFirstChild("HubLaunchers")
			local panel = gui:FindFirstChild("HubPanel")
			local objective = gui:FindFirstChild("HubObjective")

			if status ~= nil and status:IsA("Frame") then
				local statusWidth = if phone
					then math.clamp(camera.ViewportSize.X - 20, 280, 390)
					else 390
				status.Position = UDim2.new(0.5, 0, 0, if phone then 8 else 10)
				status.Size = UDim2.fromOffset(statusWidth, if phone then 46 else 52)

				local district = status:FindFirstChild("District")
				if district ~= nil and district:IsA("Frame") then
					district.Size = if phone
						then UDim2.fromScale(0.62, 1)
						else UDim2.fromOffset(230, 52)
				end
				local population = status:FindFirstChild("Population")
				if population ~= nil and population:IsA("Frame") then
					population.Size = if phone
						then UDim2.fromScale(0.36, 1)
						else UDim2.fromOffset(145, 52)
				end
			end

			if launchers ~= nil and launchers:IsA("Frame") then
				launchers.Position = if phone
					then UDim2.new(0, 10, 0.54, 0)
					else UDim2.new(0, 18, 0.58, 0)
				launchers.Size = if phone
					then UDim2.fromOffset(132, 160)
					else UDim2.fromOffset(158, 178)
				launchers.Visible = not (phone and activePanel ~= nil)
				for _, child in launchers:GetChildren() do
					if child:IsA("TextButton") then
						child.Size = if phone
							then UDim2.fromOffset(132, 48)
							else UDim2.fromOffset(158, 54)
					end
				end
			end

			if panel ~= nil and panel:IsA("Frame") then
				panel.AnchorPoint = if phone then Vector2.new(0.5, 0.5) else Vector2.new(0, 0.5)
				panel.Position = if phone
					then UDim2.fromScale(0.5, 0.54)
					else UDim2.new(0, 188, 0.58, 0)
				local phoneWidth = math.clamp(camera.ViewportSize.X - 20, 280, 340)
				local width = if activePanel == nil then 0 else if phone then phoneWidth else 310
				panel.Size = UDim2.fromOffset(width, if phone then 218 else 230)
			end

			if objective ~= nil and objective:IsA("Frame") then
				objective.Position = if phone
					then UDim2.new(0.5, 0, 1, -10)
					else UDim2.new(0.5, 0, 1, -18)
				objective.Size = if phone
					then UDim2.new(0.72, 0, 0, 58)
					else UDim2.fromOffset(520, 64)
			end
		end

		refresh()
		viewportConnection = camera:GetPropertyChangedSignal("ViewportSize"):Connect(refresh)
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

	createTopStatus(gui)
	createLaunchers(gui)
	createObjective(gui)
	bindResponsiveLayout(gui)
	refreshPopulation()
end

function HubUIController.Init()
	if initialized then
		return
	end
	initialized = true

	createUi()

	UIBus.BackRequested:Connect(function()
		if activePanel ~= nil then
			HubUIController.OpenPanel(nil)
		end
	end)

	Players.PlayerAdded:Connect(refreshPopulation)
	Players.PlayerRemoving:Connect(function()
		task.defer(refreshPopulation)
	end)
end

return HubUIController
