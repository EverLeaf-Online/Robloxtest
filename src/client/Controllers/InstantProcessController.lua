--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local RemoteNames = require(ReplicatedStorage.Shared.Networking.RemoteNames)
local HUDIconFactory = require(script.Parent.Parent.UI.HUDIconFactory)

local InstantProcessController = {}
local initialized = false

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local useTokenRemote =
	remotes:WaitForChild(RemoteNames.RequestUseInstantProcessToken) :: RemoteEvent

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
	gui.DisplayOrder = 25
	gui.Parent = player:WaitForChild("PlayerGui")

	local button = Instance.new("TextButton")
	button.Name = "UseInstantProcessToken"
	button.AnchorPoint = Vector2.new(0, 0.5)
	button.Position = UDim2.new(0, 18, 0.63, 0)
	button.Size = UDim2.fromOffset(158, 54)
	button.BackgroundTransparency = 1
	button.BorderSizePixel = 0
	button.Text = ""
	button.AutoButtonColor = false
	button.Parent = gui

	local icon = HUDIconFactory.CreateInstantFinish(button, 50)
	icon.AnchorPoint = Vector2.new(0, 0.5)
	icon.Position = UDim2.fromScale(0, 0.5)

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.BackgroundTransparency = 1
	title.Position = UDim2.fromOffset(56, 5)
	title.Size = UDim2.new(1, -56, 0, 18)
	title.Font = Enum.Font.GothamBold
	title.Text = "INSTANT FINISH"
	title.TextColor3 = Color3.fromRGB(245, 247, 250)
	title.TextSize = 11
	title.TextStrokeColor3 = Color3.new(0, 0, 0)
	title.TextStrokeTransparency = 0.28
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Parent = button

	local countLabel = Instance.new("TextLabel")
	countLabel.Name = "Count"
	countLabel.BackgroundTransparency = 1
	countLabel.Position = UDim2.fromOffset(56, 25)
	countLabel.Size = UDim2.new(1, -56, 0, 18)
	countLabel.Font = Enum.Font.GothamBold
	countLabel.TextColor3 = Color3.fromRGB(104, 223, 151)
	countLabel.TextSize = 11
	countLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
	countLabel.TextStrokeTransparency = 0.28
	countLabel.TextXAlignment = Enum.TextXAlignment.Left
	countLabel.Parent = button

	local function refresh()
		local count = tokenCount()
		button.Visible = count > 0
		countLabel.Text = ("%d TOKEN%s"):format(count, if count == 1 then "" else "S")
	end

	local function refreshLayout()
		local camera = Workspace.CurrentCamera
		if camera == nil then
			return
		end
		local phone = camera.ViewportSize.X <= 760
		button.Position = if phone then UDim2.new(0, 10, 0.57, 0) else UDim2.new(0, 18, 0.63, 0)
		button.Size = if phone then UDim2.fromOffset(132, 48) else UDim2.fromOffset(158, 54)
		icon.Size = if phone then UDim2.fromOffset(42, 42) else UDim2.fromOffset(50, 50)
		title.Position = if phone then UDim2.fromOffset(48, 3) else UDim2.fromOffset(56, 5)
		countLabel.Position = if phone then UDim2.fromOffset(48, 22) else UDim2.fromOffset(56, 25)
	end

	button.Activated:Connect(function()
		if tokenCount() <= 0 then
			return
		end
		useTokenRemote:FireServer()
	end)

	player:GetAttributeChangedSignal("InstantProcessTokens"):Connect(refresh)
	refresh()

	refreshLayout()
	local camera = Workspace.CurrentCamera
	if camera ~= nil then
		camera:GetPropertyChangedSignal("ViewportSize"):Connect(refreshLayout)
	end
end

return table.freeze(InstantProcessController)
