--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

export type Mode = "Hub" | "Factory"

local StudioRuntimeSelectorController = {}

local REMOTE_NAME = "StudioRuntimeSelector"

local function makeButton(
	parent: Instance,
	name: string,
	title: string,
	description: string,
	position: UDim2
): TextButton
	local button = Instance.new("TextButton")
	button.Name = name
	button.AutoButtonColor = true
	button.BackgroundColor3 = Color3.fromRGB(42, 49, 59)
	button.BorderSizePixel = 0
	button.Position = position
	button.Size = UDim2.fromOffset(240, 112)
	button.Font = Enum.Font.GothamBold
	button.Text = ""
	button.Parent = parent

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = button

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(78, 94, 111)
	stroke.Thickness = 1
	stroke.Transparency = 0.15
	stroke.Parent = button

	local titleLabel = Instance.new("TextLabel")
	titleLabel.BackgroundTransparency = 1
	titleLabel.Position = UDim2.fromOffset(16, 14)
	titleLabel.Size = UDim2.new(1, -32, 0, 30)
	titleLabel.Font = Enum.Font.GothamBold
	titleLabel.Text = title
	titleLabel.TextColor3 = Color3.fromRGB(245, 248, 252)
	titleLabel.TextSize = 22
	titleLabel.TextXAlignment = Enum.TextXAlignment.Left
	titleLabel.Parent = button

	local descriptionLabel = Instance.new("TextLabel")
	descriptionLabel.BackgroundTransparency = 1
	descriptionLabel.Position = UDim2.fromOffset(16, 48)
	descriptionLabel.Size = UDim2.new(1, -32, 0, 48)
	descriptionLabel.Font = Enum.Font.Gotham
	descriptionLabel.Text = description
	descriptionLabel.TextColor3 = Color3.fromRGB(178, 190, 203)
	descriptionLabel.TextSize = 14
	descriptionLabel.TextWrapped = true
	descriptionLabel.TextXAlignment = Enum.TextXAlignment.Left
	descriptionLabel.TextYAlignment = Enum.TextYAlignment.Top
	descriptionLabel.Parent = button

	return button
end

local function createSelectorGui(): (ScreenGui, TextButton, TextButton, TextLabel)
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")

	local gui = Instance.new("ScreenGui")
	gui.Name = "StudioRuntimeSelector"
	gui.DisplayOrder = 10_000
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = playerGui

	local dim = Instance.new("Frame")
	dim.Name = "Dim"
	dim.BackgroundColor3 = Color3.fromRGB(9, 12, 16)
	dim.BackgroundTransparency = 0.12
	dim.BorderSizePixel = 0
	dim.Size = UDim2.fromScale(1, 1)
	dim.Parent = gui

	local panel = Instance.new("Frame")
	panel.Name = "Panel"
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.BackgroundColor3 = Color3.fromRGB(24, 29, 36)
	panel.BorderSizePixel = 0
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = UDim2.fromOffset(540, 300)
	panel.Parent = dim

	local panelCorner = Instance.new("UICorner")
	panelCorner.CornerRadius = UDim.new(0, 16)
	panelCorner.Parent = panel

	local panelStroke = Instance.new("UIStroke")
	panelStroke.Color = Color3.fromRGB(76, 91, 108)
	panelStroke.Thickness = 1
	panelStroke.Transparency = 0.2
	panelStroke.Parent = panel

	local title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.Position = UDim2.fromOffset(24, 20)
	title.Size = UDim2.new(1, -48, 0, 34)
	title.Font = Enum.Font.GothamBold
	title.Text = "Choose Studio Runtime"
	title.TextColor3 = Color3.fromRGB(247, 250, 253)
	title.TextSize = 26
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Parent = panel

	local subtitle = Instance.new("TextLabel")
	subtitle.BackgroundTransparency = 1
	subtitle.Position = UDim2.fromOffset(24, 56)
	subtitle.Size = UDim2.new(1, -48, 0, 42)
	subtitle.Font = Enum.Font.Gotham
	subtitle.Text =
		"Choose what this Play session should boot. Actual Hub ↔ Factory teleporting still requires the published Roblox client."
	subtitle.TextColor3 = Color3.fromRGB(166, 178, 191)
	subtitle.TextSize = 14
	subtitle.TextWrapped = true
	subtitle.TextXAlignment = Enum.TextXAlignment.Left
	subtitle.TextYAlignment = Enum.TextYAlignment.Top
	subtitle.Parent = panel

	local hubButton = makeButton(
		panel,
		"HubButton",
		"Hub",
		"Shared social server preview. Tests the 16-player hub layout and portal presentation.",
		UDim2.fromOffset(24, 116)
	)

	local factoryButton = makeButton(
		panel,
		"FactoryButton",
		"Factory",
		"Personal production instance. Tests machines, salvage, workers, progression, and UI.",
		UDim2.fromOffset(276, 116)
	)

	local status = Instance.new("TextLabel")
	status.Name = "Status"
	status.BackgroundTransparency = 1
	status.Position = UDim2.fromOffset(24, 246)
	status.Size = UDim2.new(1, -48, 0, 30)
	status.Font = Enum.Font.GothamMedium
	status.Text = "This choice only affects the current Studio Play session."
	status.TextColor3 = Color3.fromRGB(121, 211, 228)
	status.TextSize = 13
	status.TextXAlignment = Enum.TextXAlignment.Center
	status.Parent = panel

	return gui, hubButton, factoryButton, status
end

local function isMode(value: any): boolean
	return value == "Hub" or value == "Factory"
end

function StudioRuntimeSelectorController.ResolveMode(): Mode
	local current = game:GetAttribute("RuntimeMode")
	if isMode(current) then
		return current :: Mode
	end

	if not RunService:IsStudio() then
		while not isMode(current) do
			game:GetAttributeChangedSignal("RuntimeMode"):Wait()
			current = game:GetAttribute("RuntimeMode")
		end
		return current :: Mode
	end

	local remote = ReplicatedStorage:WaitForChild(REMOTE_NAME, 10)
	if remote == nil or not remote:IsA("RemoteEvent") then
		warn("[StudioRuntimeSelector] Selector remote unavailable; waiting for server runtime")
		while not isMode(current) do
			game:GetAttributeChangedSignal("RuntimeMode"):Wait()
			current = game:GetAttribute("RuntimeMode")
		end
		return current :: Mode
	end

	local gui, hubButton, factoryButton, status = createSelectorGui()
	local sent = false

	local function choose(mode: Mode)
		if sent then
			return
		end
		sent = true
		hubButton.Active = false
		hubButton.AutoButtonColor = false
		factoryButton.Active = false
		factoryButton.AutoButtonColor = false
		status.Text = ("Starting %s runtime..."):format(mode)
		remote:FireServer(mode)
	end

	hubButton.Activated:Connect(function()
		choose("Hub")
	end)
	factoryButton.Activated:Connect(function()
		choose("Factory")
	end)

	current = game:GetAttribute("RuntimeMode")
	while not isMode(current) do
		game:GetAttributeChangedSignal("RuntimeMode"):Wait()
		current = game:GetAttribute("RuntimeMode")
	end

	gui:Destroy()
	return current :: Mode
end

return StudioRuntimeSelectorController
