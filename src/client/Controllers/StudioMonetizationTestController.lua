--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local StudioMonetizationTestController = {}
local mountedPage: Frame? = nil

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
	button.Name = ("MonetizationAction%d"):format(order)
	button.LayoutOrder = order
	button.Size = UDim2.new(1, 0, 0, 36)
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

function StudioMonetizationTestController.Mount(parent: Instance): Frame?
	if not RunService:IsStudio() then
		return nil
	end
	if mountedPage ~= nil and mountedPage.Parent ~= nil then
		return mountedPage
	end

	local remotes = ReplicatedStorage:WaitForChild("Remotes", REMOTE_WAIT_TIMEOUT_SECONDS)
	if remotes == nil or not remotes:IsA("Folder") then
		warn("[StudioMonetizationTestController] Remotes folder was not created by the server")
		return nil
	end

	local remoteInstance = remotes:WaitForChild(REMOTE_NAME, REMOTE_WAIT_TIMEOUT_SECONDS)
	if remoteInstance == nil or not remoteInstance:IsA("RemoteEvent") then
		warn(
			("[StudioMonetizationTestController] %s remote was not created by the server"):format(
				REMOTE_NAME
			)
		)
		return nil
	end
	local remote = remoteInstance

	local page = Instance.new("Frame")
	page.Name = "MonetizationPage"
	page.Size = UDim2.fromScale(1, 1)
	page.BackgroundTransparency = 1
	page.Parent = parent
	mountedPage = page

	local scroll = Instance.new("ScrollingFrame")
	scroll.Name = "Scroll"
	scroll.Size = UDim2.fromScale(1, 1)
	scroll.BackgroundTransparency = 1
	scroll.BorderSizePixel = 0
	scroll.ScrollBarThickness = 6
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.CanvasSize = UDim2.new()
	scroll.Parent = page

	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 4)
	padding.PaddingBottom = UDim.new(0, 8)
	padding.PaddingLeft = UDim.new(0, 4)
	padding.PaddingRight = UDim.new(0, 8)
	padding.Parent = scroll

	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 8)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = scroll

	local status = Instance.new("TextLabel")
	status.LayoutOrder = 1
	status.Size = UDim2.new(1, 0, 0, 36)
	status.BackgroundTransparency = 1
	status.Font = Enum.Font.Gotham
	status.Text = "Ready"
	status.TextColor3 = Color3.fromRGB(170, 178, 190)
	status.TextSize = 11
	status.TextWrapped = true
	status.Parent = scroll

	for index, item in ACTIONS do
		makeButton(scroll, item.Label, index + 1, function()
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

	return page
end

return StudioMonetizationTestController
