--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemoteNames = require(ReplicatedStorage.Shared.Networking.RemoteNames)

local InstantProcessController = {}
local initialized = false

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local useTokenRemote = remotes:WaitForChild(RemoteNames.RequestUseInstantProcessToken) :: RemoteEvent

local function tokenCount(): number
	local value = player:GetAttribute("InstantProcessTokens")
	return if typeof(value) == "number" then math.max(0, math.floor(value)) else 0
end

function InstantProcessController.Init()
	if initialized then
		return
	end
	initialized = true

	local gui = Instance.new("ScreenGui")
	gui.Name = "InstantProcessUI"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = false
	gui.DisplayOrder = 20
	gui.Parent = player:WaitForChild("PlayerGui")

	local button = Instance.new("TextButton")
	button.Name = "UseInstantProcessToken"
	button.AnchorPoint = Vector2.new(1, 1)
	button.Position = UDim2.new(1, -20, 1, -20)
	button.Size = UDim2.fromOffset(190, 46)
	button.BackgroundColor3 = Color3.fromRGB(48, 132, 88)
	button.BorderSizePixel = 0
	button.Font = Enum.Font.GothamBold
	button.TextColor3 = Color3.fromRGB(245, 247, 250)
	button.TextSize = 14
	button.AutoButtonColor = true
	button.Parent = gui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = button

	local function refresh()
		local count = tokenCount()
		button.Visible = count > 0
		button.Text = ("Instant Finish (%d)"):format(count)
	end

	button.Activated:Connect(function()
		if tokenCount() <= 0 then
			return
		end
		useTokenRemote:FireServer()
	end)

	player:GetAttributeChangedSignal("InstantProcessTokens"):Connect(refresh)
	refresh()
end

return InstantProcessController
