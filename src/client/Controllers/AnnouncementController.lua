--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local RemoteNames = require(ReplicatedStorage.Shared.Networking.RemoteNames)

local AnnouncementController = {}
local initialized = false
local displayGeneration = 0

local SHOW_SECONDS = 5

local function createGui(): TextLabel
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui") :: PlayerGui
	local existing = playerGui:FindFirstChild("SystemAnnouncementGui")
	if existing ~= nil then
		existing:Destroy()
	end

	local gui = Instance.new("ScreenGui")
	gui.Name = "SystemAnnouncementGui"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = false
	gui.DisplayOrder = 100
	gui.Parent = playerGui

	local label = Instance.new("TextLabel")
	label.Name = "Announcement"
	label.AnchorPoint = Vector2.new(0.5, 0)
	label.Position = UDim2.new(0.5, 0, 0, -70)
	label.Size = UDim2.new(0.8, 0, 0, 52)
	label.BackgroundColor3 = Color3.fromRGB(25, 30, 38)
	label.BackgroundTransparency = 0.08
	label.BorderSizePixel = 0
	label.Font = Enum.Font.GothamBold
	label.Text = ""
	label.TextColor3 = Color3.fromRGB(245, 248, 255)
	label.TextSize = 18
	label.TextWrapped = true
	label.Visible = false
	label.Parent = gui

	local sizeConstraint = Instance.new("UISizeConstraint")
	sizeConstraint.MinSize = Vector2.new(260, 52)
	sizeConstraint.MaxSize = Vector2.new(720, 72)
	sizeConstraint.Parent = label

	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, 16)
	padding.PaddingRight = UDim.new(0, 16)
	padding.PaddingTop = UDim.new(0, 8)
	padding.PaddingBottom = UDim.new(0, 8)
	padding.Parent = label

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = label

	return label
end

local function show(label: TextLabel, text: string)
	if text == "" then
		return
	end

	displayGeneration += 1
	local generation = displayGeneration

	label.Text = text
	label.TextTransparency = 0
	label.BackgroundTransparency = 0.08
	label.Position = UDim2.new(0.5, 0, 0, -70)
	label.Visible = true

	TweenService:Create(
		label,
		TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Position = UDim2.new(0.5, 0, 0, 14) }
	):Play()

	task.delay(SHOW_SECONDS, function()
		if generation ~= displayGeneration then
			return
		end

		local tween = TweenService:Create(
			label,
			TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
			{
				TextTransparency = 1,
				BackgroundTransparency = 1,
				Position = UDim2.new(0.5, 0, 0, -20),
			}
		)
		tween.Completed:Once(function()
			if generation == displayGeneration then
				label.Visible = false
			end
		end)
		tween:Play()
	end)
end

function AnnouncementController.Init()
	if initialized then
		return
	end
	initialized = true

	local label = createGui()
	local remotes = ReplicatedStorage:WaitForChild("Remotes")
	local announcement = remotes:WaitForChild(RemoteNames.Announcement)
	assert(announcement:IsA("RemoteEvent"), "Announcement remote must be a RemoteEvent")

	announcement.OnClientEvent:Connect(function(text: any)
		if typeof(text) ~= "string" then
			return
		end
		show(label, string.sub(text, 1, 300))
	end)
end

return table.freeze(AnnouncementController)
