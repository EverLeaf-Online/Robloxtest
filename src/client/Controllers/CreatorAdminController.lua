--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local RemoteNames = require(ReplicatedStorage.Shared.Networking.RemoteNames)
local HUDIconFactory = require(script.Parent.Parent.UI.HUDIconFactory)

local CreatorAdminController = {}
local initialized = false
local requestGeneration = 0

local function isCreator(player: Player): boolean
	if game.CreatorType == Enum.CreatorType.User then
		return player.UserId == game.CreatorId
	end
	if game.CreatorType == Enum.CreatorType.Group then
		local ok, rankOrError = pcall(player.GetRankInGroup, player, game.CreatorId)
		return ok and rankOrError >= 255
	end
	return false
end

local function round(instance: Instance, radius: number)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius)
	corner.Parent = instance
end

local function createGui(): (TextBox, TextButton, TextLabel)
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui") :: PlayerGui
	local existing = playerGui:FindFirstChild("CreatorAdminGui")
	if existing ~= nil then
		existing:Destroy()
	end

	local gui = Instance.new("ScreenGui")
	gui.Name = "CreatorAdminGui"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = false
	gui.DisplayOrder = 110
	gui.Parent = playerGui

	local launcher = Instance.new("TextButton")
	launcher.Name = "AdminButton"
	launcher.AnchorPoint = Vector2.new(1, 0)
	launcher.Position = UDim2.new(1, -16, 0, 82)
	launcher.Size = UDim2.fromOffset(64, 72)
	launcher.BackgroundTransparency = 1
	launcher.BorderSizePixel = 0
	launcher.Text = ""
	launcher.AutoButtonColor = false
	launcher.Parent = gui

	local launcherIcon = HUDIconFactory.CreateAdmin(launcher, 50)

	local launcherLabel = Instance.new("TextLabel")
	launcherLabel.AnchorPoint = Vector2.new(0.5, 1)
	launcherLabel.Position = UDim2.fromScale(0.5, 1)
	launcherLabel.Size = UDim2.new(1, 0, 0, 18)
	launcherLabel.BackgroundTransparency = 1
	launcherLabel.Font = Enum.Font.GothamBold
	launcherLabel.Text = "ADMIN"
	launcherLabel.TextColor3 = Color3.fromRGB(245, 248, 255)
	launcherLabel.TextSize = 10
	launcherLabel.TextStrokeTransparency = 0.35
	launcherLabel.Parent = launcher

	local frame = Instance.new("Frame")
	frame.Name = "Panel"
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Position = UDim2.fromScale(0.5, 0.53)
	frame.Size = UDim2.fromOffset(390, 188)
	frame.BackgroundColor3 = Color3.fromRGB(20, 24, 30)
	frame.BackgroundTransparency = 0.03
	frame.BorderSizePixel = 0
	frame.Visible = false
	frame.Parent = gui
	round(frame, 12)

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Position = UDim2.fromOffset(12, 10)
	title.Size = UDim2.new(1, -58, 0, 22)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.GothamBold
	title.Text = "CREATOR: NEW CONTENT"
	title.TextColor3 = Color3.fromRGB(230, 235, 245)
	title.TextSize = 14
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Parent = frame

	local close = Instance.new("TextButton")
	close.Name = "Close"
	close.AnchorPoint = Vector2.new(1, 0)
	close.Position = UDim2.new(1, -10, 0, 8)
	close.Size = UDim2.fromOffset(32, 28)
	close.BackgroundColor3 = Color3.fromRGB(43, 48, 59)
	close.BorderSizePixel = 0
	close.Font = Enum.Font.GothamBold
	close.Text = "×"
	close.TextColor3 = Color3.fromRGB(245, 248, 255)
	close.TextSize = 18
	close.Parent = frame
	round(close, 7)

	local box = Instance.new("TextBox")
	box.Name = "Message"
	box.Position = UDim2.fromOffset(12, 44)
	box.Size = UDim2.new(1, -24, 0, 64)
	box.BackgroundColor3 = Color3.fromRGB(34, 40, 48)
	box.BorderSizePixel = 0
	box.ClearTextOnFocus = false
	box.Font = Enum.Font.Gotham
	box.PlaceholderText = "New content announcement (max 120 characters)"
	box.Text = ""
	box.TextColor3 = Color3.fromRGB(245, 248, 255)
	box.TextSize = 14
	box.TextWrapped = true
	box.Parent = frame
	round(box, 7)

	local button = Instance.new("TextButton")
	button.Name = "Broadcast"
	button.Position = UDim2.fromOffset(12, 118)
	button.Size = UDim2.new(1, -24, 0, 36)
	button.BackgroundColor3 = Color3.fromRGB(45, 112, 205)
	button.BorderSizePixel = 0
	button.Font = Enum.Font.GothamBold
	button.Text = "Broadcast New Content"
	button.TextColor3 = Color3.fromRGB(255, 255, 255)
	button.TextSize = 13
	button.Parent = frame
	round(button, 7)

	local status = Instance.new("TextLabel")
	status.Name = "Status"
	status.Position = UDim2.fromOffset(12, 158)
	status.Size = UDim2.new(1, -24, 0, 18)
	status.BackgroundTransparency = 1
	status.Font = Enum.Font.Gotham
	status.Text = ""
	status.TextColor3 = Color3.fromRGB(180, 190, 205)
	status.TextSize = 11
	status.TextXAlignment = Enum.TextXAlignment.Left
	status.Parent = frame

	local function refreshLayout()
		local camera = Workspace.CurrentCamera
		if camera == nil then
			return
		end
		local phone = camera.ViewportSize.X <= 760
		launcher.Position = UDim2.new(1, if phone then -12 else -16, 0, if phone then 74 else 82)
		launcher.Size = if phone then UDim2.fromOffset(58, 66) else UDim2.fromOffset(64, 72)
		launcherIcon.Size = if phone then UDim2.fromOffset(44, 44) else UDim2.fromOffset(50, 50)
		frame.Size = if phone then UDim2.new(0.78, 0, 0, 188) else UDim2.fromOffset(390, 188)
	end
	refreshLayout()
	local camera = Workspace.CurrentCamera
	if camera ~= nil then
		camera:GetPropertyChangedSignal("ViewportSize"):Connect(refreshLayout)
	end

	launcher.Activated:Connect(function()
		frame.Visible = not frame.Visible
	end)
	close.Activated:Connect(function()
		frame.Visible = false
	end)

	return box, button, status
end

function CreatorAdminController.Init()
	if initialized then
		return
	end
	initialized = true

	local player = Players.LocalPlayer
	if not isCreator(player) then
		return
	end

	local remotes = ReplicatedStorage:WaitForChild("Remotes")
	local request = remotes:WaitForChild(RemoteNames.RequestAdminBroadcast)
	local actionResult = remotes:WaitForChild(RemoteNames.ActionResult)
	assert(request:IsA("RemoteEvent"), "RequestAdminBroadcast remote must be a RemoteEvent")
	assert(actionResult:IsA("RemoteEvent"), "ActionResult remote must be a RemoteEvent")

	local box, button, status = createGui()

	local function setPending(pending: boolean)
		button.Active = not pending
		button.AutoButtonColor = not pending
		button.Text = if pending then "Broadcasting..." else "Broadcast New Content"
	end

	button.Activated:Connect(function()
		local text = box.Text
		local length = utf8.len(text)
		if length == nil or length < 1 or length > 120 then
			status.Text = "Message must be 1-120 characters."
			return
		end

		requestGeneration += 1
		local generation = requestGeneration
		setPending(true)
		status.Text = "Submitting..."
		request:FireServer(text)

		task.delay(5, function()
			if generation == requestGeneration and not button.Active then
				setPending(false)
				status.Text = "No server response received."
			end
		end)
	end)

	actionResult.OnClientEvent:Connect(function(result: any)
		if typeof(result) ~= "table" or result.Action ~= "AdminBroadcast" then
			return
		end

		requestGeneration += 1
		setPending(false)
		if result.Success == true then
			box.Text = ""
			status.Text = "Broadcast accepted: " .. tostring(result.Code)
		else
			status.Text = "Broadcast failed: " .. tostring(result.Code)
		end
	end)
end

return table.freeze(CreatorAdminController)
