--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemoteNames = require(ReplicatedStorage.Shared.Networking.RemoteNames)

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

local function createGui(): (TextBox, TextButton, TextLabel)
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui") :: PlayerGui
	local existing = playerGui:FindFirstChild("CreatorAdminGui")
	if existing ~= nil then
		existing:Destroy()
	end

	local gui = Instance.new("ScreenGui")
	gui.Name = "CreatorAdminGui"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 110
	gui.Parent = playerGui

	local frame = Instance.new("Frame")
	frame.Name = "Panel"
	frame.AnchorPoint = Vector2.new(0, 1)
	frame.Position = UDim2.new(0, 16, 1, -16)
	frame.Size = UDim2.fromOffset(360, 154)
	frame.BackgroundColor3 = Color3.fromRGB(20, 24, 30)
	frame.BackgroundTransparency = 0.05
	frame.BorderSizePixel = 0
	frame.Parent = gui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = frame

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Position = UDim2.fromOffset(10, 8)
	title.Size = UDim2.new(1, -20, 0, 20)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.GothamBold
	title.Text = "CREATOR: NEW CONTENT BROADCAST"
	title.TextColor3 = Color3.fromRGB(230, 235, 245)
	title.TextSize = 13
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Parent = frame

	local box = Instance.new("TextBox")
	box.Name = "Message"
	box.Position = UDim2.fromOffset(10, 34)
	box.Size = UDim2.new(1, -20, 0, 54)
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

	local boxCorner = Instance.new("UICorner")
	boxCorner.CornerRadius = UDim.new(0, 7)
	boxCorner.Parent = box

	local button = Instance.new("TextButton")
	button.Name = "Broadcast"
	button.Position = UDim2.fromOffset(10, 96)
	button.Size = UDim2.new(1, -20, 0, 32)
	button.BackgroundColor3 = Color3.fromRGB(45, 112, 205)
	button.BorderSizePixel = 0
	button.Font = Enum.Font.GothamBold
	button.Text = "Broadcast New Content"
	button.TextColor3 = Color3.fromRGB(255, 255, 255)
	button.TextSize = 14
	button.Parent = frame

	local buttonCorner = Instance.new("UICorner")
	buttonCorner.CornerRadius = UDim.new(0, 7)
	buttonCorner.Parent = button

	local status = Instance.new("TextLabel")
	status.Name = "Status"
	status.Position = UDim2.fromOffset(10, 130)
	status.Size = UDim2.new(1, -20, 0, 16)
	status.BackgroundTransparency = 1
	status.Font = Enum.Font.Gotham
	status.Text = ""
	status.TextColor3 = Color3.fromRGB(180, 190, 205)
	status.TextSize = 11
	status.TextXAlignment = Enum.TextXAlignment.Left
	status.Parent = frame

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
