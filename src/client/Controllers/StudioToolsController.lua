--!strict

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local StudioMonetizationTestController = require(script.Parent.StudioMonetizationTestController)
local StudioSecurityTestController = require(script.Parent.StudioSecurityTestController)

local StudioToolsController = {}
local initialized = false

local ACTIVE_TAB_COLOR = Color3.fromRGB(72, 84, 104)
local INACTIVE_TAB_COLOR = Color3.fromRGB(38, 43, 53)

local function round(instance: Instance, radius: number)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius)
	corner.Parent = instance
end

local function makeTab(parent: Instance, label: string, position: UDim2): TextButton
	local button = Instance.new("TextButton")
	button.Name = label:gsub("%s+", "") .. "Tab"
	button.Position = position
	button.Size = UDim2.new(0.5, -4, 1, 0)
	button.BackgroundColor3 = INACTIVE_TAB_COLOR
	button.BorderSizePixel = 0
	button.Font = Enum.Font.GothamBold
	button.Text = label
	button.TextColor3 = Color3.fromRGB(235, 239, 245)
	button.TextSize = 12
	button.AutoButtonColor = true
	button.Parent = parent
	round(button, 7)
	return button
end

function StudioToolsController.Init()
	if initialized then
		return
	end
	initialized = true

	if not RunService:IsStudio() then
		return
	end

	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui")

	local gui = Instance.new("ScreenGui")
	gui.Name = "StudioToolsUI"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 1002
	gui.IgnoreGuiInset = false
	gui.Parent = playerGui

	local launcher = Instance.new("TextButton")
	launcher.Name = "Launcher"
	launcher.AnchorPoint = Vector2.new(1, 0)
	launcher.Position = UDim2.new(1, -14, 0, 90)
	launcher.Size = UDim2.fromOffset(110, 30)
	launcher.BackgroundColor3 = Color3.fromRGB(45, 52, 64)
	launcher.BorderSizePixel = 0
	launcher.Font = Enum.Font.GothamBold
	launcher.Text = "STUDIO TOOLS"
	launcher.TextColor3 = Color3.fromRGB(245, 247, 250)
	launcher.TextSize = 12
	launcher.AutoButtonColor = true
	launcher.Parent = gui
	round(launcher, 8)

	local panel = Instance.new("Frame")
	panel.Name = "Panel"
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.53)
	panel.Size = UDim2.fromScale(0.68, 0.76)
	panel.BackgroundColor3 = Color3.fromRGB(24, 27, 34)
	panel.BorderSizePixel = 0
	panel.Visible = false
	panel.Parent = gui
	round(panel, 12)

	local sizeConstraint = Instance.new("UISizeConstraint")
	sizeConstraint.MinSize = Vector2.new(320, 300)
	sizeConstraint.MaxSize = Vector2.new(620, 600)
	sizeConstraint.Parent = panel

	local header = Instance.new("Frame")
	header.Name = "Header"
	header.Size = UDim2.new(1, 0, 0, 46)
	header.BackgroundTransparency = 1
	header.Parent = panel

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Position = UDim2.fromOffset(16, 0)
	title.Size = UDim2.new(1, -68, 1, 0)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.GothamBold
	title.Text = "STUDIO TOOLS"
	title.TextColor3 = Color3.fromRGB(245, 247, 250)
	title.TextSize = 14
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Parent = header

	local closeButton = Instance.new("TextButton")
	closeButton.Name = "Close"
	closeButton.AnchorPoint = Vector2.new(1, 0.5)
	closeButton.Position = UDim2.new(1, -12, 0.5, 0)
	closeButton.Size = UDim2.fromOffset(30, 30)
	closeButton.BackgroundColor3 = Color3.fromRGB(45, 52, 64)
	closeButton.BorderSizePixel = 0
	closeButton.Font = Enum.Font.GothamBold
	closeButton.Text = "×"
	closeButton.TextColor3 = Color3.fromRGB(235, 239, 245)
	closeButton.TextSize = 18
	closeButton.Parent = header
	round(closeButton, 7)

	local tabs = Instance.new("Frame")
	tabs.Name = "Tabs"
	tabs.Position = UDim2.fromOffset(12, 46)
	tabs.Size = UDim2.new(1, -24, 0, 38)
	tabs.BackgroundTransparency = 1
	tabs.Parent = panel

	local securityTab = makeTab(tabs, "SECURITY QA", UDim2.fromOffset(0, 0))
	local monetizationTab = makeTab(tabs, "MONETIZATION", UDim2.new(0.5, 4, 0, 0))

	local content = Instance.new("Frame")
	content.Name = "Content"
	content.Position = UDim2.fromOffset(12, 92)
	content.Size = UDim2.new(1, -24, 1, -104)
	content.BackgroundTransparency = 1
	content.ClipsDescendants = true
	content.Parent = panel

	local securityPage = StudioSecurityTestController.Mount(content)
	local monetizationPage = StudioMonetizationTestController.Mount(content)
	if securityPage == nil or monetizationPage == nil then
		warn("[StudioToolsController] One or more Studio tool pages failed to mount")
	end

	local function showSecurity()
		if securityPage ~= nil then
			securityPage.Visible = true
		end
		if monetizationPage ~= nil then
			monetizationPage.Visible = false
		end
		securityTab.BackgroundColor3 = ACTIVE_TAB_COLOR
		monetizationTab.BackgroundColor3 = INACTIVE_TAB_COLOR
	end

	local function showMonetization()
		if securityPage ~= nil then
			securityPage.Visible = false
		end
		if monetizationPage ~= nil then
			monetizationPage.Visible = true
		end
		securityTab.BackgroundColor3 = INACTIVE_TAB_COLOR
		monetizationTab.BackgroundColor3 = ACTIVE_TAB_COLOR
	end

	securityTab.Activated:Connect(showSecurity)
	monetizationTab.Activated:Connect(showMonetization)
	launcher.Activated:Connect(function()
		panel.Visible = not panel.Visible
	end)
	closeButton.Activated:Connect(function()
		panel.Visible = false
	end)

	local function refreshLayout()
		local camera = Workspace.CurrentCamera
		if camera == nil then
			return
		end
		local phone = camera.ViewportSize.X <= 760
		launcher.Size = if phone then UDim2.fromOffset(96, 28) else UDim2.fromOffset(110, 30)
		panel.Size = if phone then UDim2.fromScale(0.82, 0.78) else UDim2.fromScale(0.68, 0.76)
	end
	refreshLayout()
	local camera = Workspace.CurrentCamera
	if camera ~= nil then
		camera:GetPropertyChangedSignal("ViewportSize"):Connect(refreshLayout)
	end

	showSecurity()
end

return StudioToolsController
