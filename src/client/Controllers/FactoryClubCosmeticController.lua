--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemoteNames = require(ReplicatedStorage.Shared.Networking.RemoteNames)

local FactoryClubCosmeticController = {}
local initialized = false

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local stateRemote = remotes:WaitForChild(RemoteNames.StateSnapshot) :: RemoteEvent
local equipRemote = remotes:WaitForChild(RemoteNames.RequestEquipClubCosmetic) :: RemoteEvent

local cosmetics: { string } = {}
local equipped = ""
local gui: ScreenGui? = nil
local button: TextButton? = nil
local label: TextLabel? = nil

local function displayName(cosmeticId: string): string
	if cosmeticId == "" then
		return "DEFAULT"
	end
	local cycle = string.match(cosmeticId, "^Club_(.+)$") or cosmeticId
	local timestamp = tonumber(cycle)
	if timestamp ~= nil and timestamp > 0 then
		return string.upper(os.date("!%b %Y", timestamp))
	end
	if cycle == "StudioTestCycle" then
		return "TEST COSMETIC"
	end
	return string.upper(string.sub(cycle, 1, 18))
end

local function refreshUi()
	if gui == nil or button == nil or label == nil then
		return
	end
	gui.Enabled = #cosmetics > 1
	label.Text = ("CLUB COSMETIC: %s"):format(displayName(equipped))
	button.Text = if #cosmetics > 1 then "NEXT COSMETIC" else "EQUIP COSMETIC"
end

local function applySnapshot(snapshot: any)
	local entitlements = snapshot.Entitlements
	if typeof(entitlements) ~= "table" then
		return
	end

	local nextCosmetics = { "" }
	if typeof(entitlements.FactoryClubCosmetics) == "table" then
		for cosmeticId, owned in entitlements.FactoryClubCosmetics do
			if typeof(cosmeticId) == "string" and owned == true then
				table.insert(nextCosmetics, cosmeticId)
			end
		end
	end
	table.sort(nextCosmetics, function(a, b)
		if a == "" then
			return true
		elseif b == "" then
			return false
		end
		return a < b
	end)

	cosmetics = nextCosmetics
	equipped = if typeof(entitlements.EquippedFactoryClubCosmetic) == "string"
		then entitlements.EquippedFactoryClubCosmetic
		else ""
	refreshUi()
end

local function cycleCosmetic()
	if #cosmetics <= 1 then
		if #cosmetics == 1 then
			equipRemote:FireServer(cosmetics[1])
		end
		return
	end

	local currentIndex = table.find(cosmetics, equipped) or 1
	local nextIndex = currentIndex % #cosmetics + 1
	equipRemote:FireServer(cosmetics[nextIndex])
end

local function createUi()
	local playerGui = player:WaitForChild("PlayerGui") :: PlayerGui
	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "FactoryClubCosmetics"
	screenGui.ResetOnSpawn = false
	screenGui.IgnoreGuiInset = true
	screenGui.Enabled = false
	screenGui.Parent = playerGui

	local frame = Instance.new("Frame")
	frame.AnchorPoint = Vector2.new(1, 1)
	frame.BackgroundColor3 = Color3.fromRGB(20, 23, 30)
	frame.BackgroundTransparency = 0.08
	frame.BorderSizePixel = 0
	frame.Position = UDim2.new(1, -14, 1, -112)
	frame.Size = UDim2.fromOffset(220, 88)
	frame.Parent = screenGui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = frame

	local title = Instance.new("TextLabel")
	title.Name = "Current"
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.GothamBold
	title.Position = UDim2.fromOffset(8, 6)
	title.Size = UDim2.new(1, -16, 0, 24)
	title.TextColor3 = Color3.fromRGB(255, 235, 175)
	title.TextSize = 12
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Parent = frame

	local nextButton = Instance.new("TextButton")
	nextButton.Name = "Next"
	nextButton.BackgroundColor3 = Color3.fromRGB(56, 65, 82)
	nextButton.BorderSizePixel = 0
	nextButton.Font = Enum.Font.GothamBold
	nextButton.Position = UDim2.fromOffset(8, 36)
	nextButton.Size = UDim2.new(1, -16, 0, 44)
	nextButton.TextColor3 = Color3.fromRGB(255, 255, 255)
	nextButton.TextSize = 12
	nextButton.Parent = frame

	local buttonCorner = Instance.new("UICorner")
	buttonCorner.CornerRadius = UDim.new(0, 6)
	buttonCorner.Parent = nextButton

	gui = screenGui
	button = nextButton
	label = title
	nextButton.Activated:Connect(cycleCosmetic)
	refreshUi()
end

function FactoryClubCosmeticController.Init()
	if initialized then
		return
	end
	initialized = true

	createUi()
	stateRemote.OnClientEvent:Connect(applySnapshot)
end

return FactoryClubCosmeticController
