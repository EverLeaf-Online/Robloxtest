--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local StudioMonetizationTestController = {}
local initialized = false

local REMOTE_NAME = "StudioMonetizationTest"
local REMOTE_WAIT_TIMEOUT_SECONDS = 10

local ACTIONS = {
	{ Label = "Material Crate", Action = "MaterialSupplyCrate" },
	{ Label = "15m Overclock", Action = "FactoryOverclock15m" },
	{ Label = "+5 Tokens", Action = "InstantProcessTokens" },
	{ Label = "Starter Pack", Action = "StarterPack" },
	{ Label = "Server Overclock", Action = "ServerOverclock" },
	{ Label = "Factory Club ON", Action = "FactoryClubOn" },
	{ Label = "Factory Club OFF", Action = "FactoryClubOff" },
	{ Label = "Referral Reward", Action = "ReferralReward" },
	{ Label = "Replay Last Receipt", Action = "ReplayLastReceipt" },
}

local function makeButton(parent: Instance, label: string, order: number, callback: () -> ())
	local button = Instance.new("TextButton")
	button.Name = ("Action%d"):format(order)
	button.LayoutOrder = order
	button.Size = UDim2.new(1, 0, 0, 34)
	button.BackgroundColor3 = Color3.fromRGB(48, 132, 88)
	button.BorderSizePixel = 0
	button.Font = Enum.Font.GothamBold
	button.Text = label
	button.TextColor3 = Color3.fromRGB(245, 247, 250)
	button.TextSize = 12
	button.AutoButtonColor = true
	button.Parent = parent

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 7)
	corner.Parent = button

	button.Activated:Connect(callback)
end

function StudioMonetizationTestController.Init()
	if initialized then
		return
	end
	initialized = true

	if not RunService:IsStudio() then
		return
	end

	local player = Players.LocalPlayer
	local remotes = ReplicatedStorage:WaitForChild("Remotes", REMOTE_WAIT_TIMEOUT_SECONDS)
	if remotes == nil then
		warn("[StudioMonetizationTestController] Remotes folder was not created by the server")
		return
	end

	local remoteInstance = remotes:WaitForChild(REMOTE_NAME, REMOTE_WAIT_TIMEOUT_SECONDS)
	if remoteInstance == nil or not remoteInstance:IsA("RemoteEvent") then
		warn(
			("[StudioMonetizationTestController] %s remote was not created by the server"):format(
				REMOTE_NAME
			)
		)
		return
	end
	local remote = remoteInstance

	local gui = Instance.new("ScreenGui")
	gui.Name = "StudioMonetizationTestUI"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 1000
	gui.Parent = player:WaitForChild("PlayerGui")

	local panel = Instance.new("Frame")
	panel.Name = "Panel"
	panel.AnchorPoint = Vector2.new(1, 0)
	panel.Position = UDim2.new(1, -340, 0, 72)
	panel.Size = UDim2.fromOffset(210, 412)
	panel.BackgroundColor3 = Color3.fromRGB(24, 27, 34)
	panel.BorderSizePixel = 0
	panel.Parent = gui

	local panelCorner = Instance.new("UICorner")
	panelCorner.CornerRadius = UDim.new(0, 10)
	panelCorner.Parent = panel

	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 10)
	padding.PaddingBottom = UDim.new(0, 10)
	padding.PaddingLeft = UDim.new(0, 10)
	padding.PaddingRight = UDim.new(0, 10)
	padding.Parent = panel

	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 6)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = panel

	local title = Instance.new("TextLabel")
	title.LayoutOrder = 0
	title.Size = UDim2.new(1, 0, 0, 24)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.GothamBold
	title.Text = "STUDIO MONETIZATION TEST"
	title.TextColor3 = Color3.fromRGB(245, 247, 250)
	title.TextSize = 12
	title.Parent = panel

	local status = Instance.new("TextLabel")
	status.LayoutOrder = 1
	status.Size = UDim2.new(1, 0, 0, 28)
	status.BackgroundTransparency = 1
	status.Font = Enum.Font.Gotham
	status.Text = "Ready"
	status.TextColor3 = Color3.fromRGB(170, 178, 190)
	status.TextSize = 11
	status.TextWrapped = true
	status.Parent = panel

	for index, item in ACTIONS do
		makeButton(panel, item.Label, index + 1, function()
			status.Text = ("Running %s..."):format(item.Label)
			status.TextColor3 = Color3.fromRGB(170, 178, 190)
			remote:FireServer(item.Action)
		end)
	end

	remote.OnClientEvent:Connect(function(kind, action, success, code)
		if kind == "ReceiptReady" then
			status.Text = ("%s: RECEIPT READY"):format(tostring(action))
			status.TextColor3 = Color3.fromRGB(104, 214, 156)
			return
		end
		if kind ~= "Result" then
			return
		end
		status.Text = ("%s: %s (%s)"):format(
			tostring(action),
			if success == true then "PASS" else "FAIL",
			tostring(code)
		)
		status.TextColor3 = if success == true
			then Color3.fromRGB(104, 214, 156)
			else Color3.fromRGB(228, 101, 101)
	end)
end

return StudioMonetizationTestController
