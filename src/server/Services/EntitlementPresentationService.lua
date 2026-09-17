--!strict

local Players = game:GetService("Players")

local EntitlementPresentationService = {}
local initialized = false
local connectionsByPlayer: { [Player]: { RBXScriptConnection } } = {}

local NAMEPLATE_NAME = "FactoryEntitlementNameplate"

local function disconnectPlayer(player: Player)
	local connections = connectionsByPlayer[player]
	if connections == nil then
		return
	end
	for _, connection in connections do
		connection:Disconnect()
	end
	connectionsByPlayer[player] = nil
end

local function cosmeticLabel(cosmeticId: string): string
	if cosmeticId == "" then
		return ""
	end
	local cycle = string.match(cosmeticId, "^Club_(.+)$") or cosmeticId
	local timestamp = tonumber(cycle)
	if timestamp ~= nil and timestamp > 0 then
		return string.upper(os.date("!%b %Y", timestamp))
	end
	local year, month = string.match(cycle, "^(%d%d%d%d)%-(%d%d)$")
	if year ~= nil and month ~= nil then
		return ("%s/%s"):format(month, year)
	end
	if cycle == "StudioTestCycle" then
		return "TEST"
	end
	return string.upper(string.sub(cycle, 1, 12))
end

local function cosmeticColor(cosmeticId: string): Color3
	if cosmeticId == "" then
		return Color3.fromRGB(255, 214, 92)
	end
	local hash = 0
	for index = 1, #cosmeticId do
		hash = (hash * 31 + string.byte(cosmeticId, index)) % 360
	end
	return Color3.fromHSV(hash / 360, 0.55, 1)
end

local function entitlementText(player: Player): string
	local club = player:GetAttribute("FactoryClubNameplateEnabled") == true
	local vip = player:GetAttribute("VIPNameplateEnabled") == true
	local cosmeticId = tostring(player:GetAttribute("FactoryClubEquippedCosmetic") or "")
	local cosmetic = if club then cosmeticLabel(cosmeticId) else ""
	local suffix = if cosmetic ~= "" then ("  [%s]"):format(cosmetic) else ""
	if club and vip then
		return "FACTORY CLUB  •  VIP" .. suffix
	elseif club then
		return "FACTORY CLUB" .. suffix
	elseif vip then
		return "FACTORY VIP"
	end
	return ""
end

local function applyNameplate(player: Player)
	local character = player.Character
	if character == nil then
		return
	end
	local head = character:FindFirstChild("Head")
	if head == nil or not head:IsA("BasePart") then
		return
	end

	local existing = head:FindFirstChild(NAMEPLATE_NAME)
	local text = entitlementText(player)
	if text == "" then
		if existing ~= nil then
			existing:Destroy()
		end
		return
	end

	local billboard: BillboardGui
	local label: TextLabel
	if existing ~= nil and existing:IsA("BillboardGui") then
		billboard = existing
		local existingLabel = billboard:FindFirstChild("Label")
		if existingLabel == nil or not existingLabel:IsA("TextLabel") then
			billboard:Destroy()
			existing = nil
		else
			label = existingLabel
		end
	end

	if existing == nil then
		billboard = Instance.new("BillboardGui")
		billboard.Name = NAMEPLATE_NAME
		billboard.Adornee = head
		billboard.AlwaysOnTop = true
		billboard.Size = UDim2.fromOffset(220, 30)
		billboard.StudsOffset = Vector3.new(0, 2.8, 0)
		billboard.MaxDistance = 80
		billboard.Parent = head

		label = Instance.new("TextLabel")
		label.Name = "Label"
		label.BackgroundColor3 = Color3.fromRGB(20, 23, 30)
		label.BackgroundTransparency = 0.15
		label.BorderSizePixel = 0
		label.Font = Enum.Font.GothamBold
		label.Size = UDim2.fromScale(1, 1)
		label.TextColor3 = Color3.fromRGB(255, 214, 92)
		label.TextScaled = true
		label.Parent = billboard

		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 7)
		corner.Parent = label
	end

	label.Text = text
	local cosmeticId = tostring(player:GetAttribute("FactoryClubEquippedCosmetic") or "")
	label.TextColor3 = cosmeticColor(if player:GetAttribute("FactoryClubNameplateEnabled") == true then cosmeticId else "")
end

local function bindPlayer(player: Player)
	disconnectPlayer(player)
	local connections = {}
	connectionsByPlayer[player] = connections

	table.insert(connections, player.CharacterAdded:Connect(function()
		task.defer(applyNameplate, player)
	end))
	table.insert(connections, player:GetAttributeChangedSignal("VIPNameplateEnabled"):Connect(function()
		applyNameplate(player)
	end))
	table.insert(connections, player:GetAttributeChangedSignal("FactoryClubNameplateEnabled"):Connect(function()
		applyNameplate(player)
	end))
	table.insert(connections, player:GetAttributeChangedSignal("FactoryClubEquippedCosmetic"):Connect(function()
		applyNameplate(player)
	end))

	if player.Character ~= nil then
		task.defer(applyNameplate, player)
	end
end

function EntitlementPresentationService.Init()
	if initialized then
		return
	end
	initialized = true

	Players.PlayerAdded:Connect(bindPlayer)
	Players.PlayerRemoving:Connect(disconnectPlayer)
	for _, player in Players:GetPlayers() do
		bindPlayer(player)
	end
end

return EntitlementPresentationService