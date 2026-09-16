local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local TileGeometry = require(ReplicatedStorage.Shared.TileGeometry)

local player = Players.LocalPlayer
local camera = Workspace.CurrentCamera
local remotes = ReplicatedFirst:WaitForChild("Remotes")
local applyAction = remotes:WaitForChild("ApplyAction")

local planets = Workspace:WaitForChild("Planets")
local planet = planets:WaitForChild("Planet_" .. player.UserId)
local core = planet:WaitForChild("Core")
local tilesFolder = planet:WaitForChild("Tiles")

local clickStartPosition = nil
local clickStartedInWorld = false
local touchStartPosition = nil
local touchInput = nil
local selectedHighlight = nil

local CLICK_DRAG_THRESHOLD = 10
local PICK_RADIUS = Config.PLANET_RADIUS + Config.TILE_SURFACE_OFFSET + 2

local function nearestTileForDirection(direction)
	local bestIndex = 1
	local bestDot = -math.huge

	for index = 1, Config.TILE_COUNT do
		local dot = direction:Dot(TileGeometry.GetDirection(index))
		if dot > bestDot then
			bestDot = dot
			bestIndex = index
		end
	end

	return bestIndex
end

local function screenPositionToTile(screenPosition)
	if not camera or not core.Parent then
		return nil
	end

	-- GetMouseLocation/InputObject.Position are screen-space coordinates, so use
	-- ScreenPointToRay rather than ViewportPointToRay. This accounts for the
	-- Roblox top inset and prevents the picking ray from being vertically offset.
	local ray = camera:ScreenPointToRay(screenPosition.X, screenPosition.Y)
	local direction = ray.Direction.Unit
	local relativeOrigin = ray.Origin - core.Position

	-- Analytic ray/sphere intersection. The decorative tile cylinders are not
	-- used for hit detection, so there are no dead zones between surface tiles.
	local b = 2 * relativeOrigin:Dot(direction)
	local c = relativeOrigin:Dot(relativeOrigin) - PICK_RADIUS * PICK_RADIUS
	local discriminant = b * b - 4 * c
	if discriminant < 0 then
		return nil
	end

	local root = math.sqrt(discriminant)
	local distance = (-b - root) * 0.5
	if distance < 0 then
		distance = (-b + root) * 0.5
	end
	if distance < 0 then
		return nil
	end

	local hitPosition = ray.Origin + direction * distance
	local surfaceDirection = (hitPosition - core.Position).Unit
	return nearestTileForDirection(surfaceDirection)
end

local function updateHighlight(tileIndex)
	if selectedHighlight then
		selectedHighlight:Destroy()
		selectedHighlight = nil
	end

	local tilePart = tilesFolder:FindFirstChild("Tile_" .. tileIndex)
	if not tilePart then
		return
	end

	local highlight = Instance.new("Highlight")
	highlight.Name = "PlanetSelectionHighlight"
	highlight.Adornee = tilePart
	highlight.FillColor = Color3.fromRGB(73, 220, 255)
	highlight.FillTransparency = 0.62
	highlight.OutlineColor = Color3.fromRGB(225, 253, 255)
	highlight.OutlineTransparency = 0
	highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	highlight.Parent = planet
	selectedHighlight = highlight
end

local function selectTile(tileIndex)
	if not tileIndex then
		return
	end

	local tilePart = tilesFolder:FindFirstChild("Tile_" .. tileIndex)
	local tileType = tilePart and tilePart:GetAttribute("TileType") or "Land"

	player:SetAttribute("PlanetSelectedTile", tileIndex)
	player:SetAttribute("PlanetSelectedTileType", tileType)
	updateHighlight(tileIndex)

	local pendingAction = player:GetAttribute("PlanetPendingAction")
	if type(pendingAction) == "string" and pendingAction ~= "" then
		player:SetAttribute("PlanetPendingAction", "")
		applyAction:FireServer({
			actionType = pendingAction,
			tileIndex = tileIndex,
		})
	end
end

local function handleClick(screenPosition)
	local tileIndex = screenPositionToTile(screenPosition)
	if tileIndex then
		selectTile(tileIndex)
	end
end

player:SetAttribute("PlanetSelectedTile", 0)
player:SetAttribute("PlanetSelectedTileType", "")
if player:GetAttribute("PlanetPendingAction") == nil then
	player:SetAttribute("PlanetPendingAction", "")
end

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		clickStartedInWorld = not gameProcessed
		clickStartPosition = Vector2.new(input.Position.X, input.Position.Y)
		return
	end

	if input.UserInputType == Enum.UserInputType.Touch and not gameProcessed and not touchInput then
		touchInput = input
		touchStartPosition = Vector2.new(input.Position.X, input.Position.Y)
	end
end)

UserInputService.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		if clickStartedInWorld and clickStartPosition then
			local endPosition = Vector2.new(input.Position.X, input.Position.Y)
			if (endPosition - clickStartPosition).Magnitude <= CLICK_DRAG_THRESHOLD then
				handleClick(endPosition)
			end
		end
		clickStartedInWorld = false
		clickStartPosition = nil
		return
	end

	if input.UserInputType == Enum.UserInputType.Touch and input == touchInput then
		if touchStartPosition then
			local endPosition = Vector2.new(input.Position.X, input.Position.Y)
			if (endPosition - touchStartPosition).Magnitude <= CLICK_DRAG_THRESHOLD then
				handleClick(endPosition)
			end
		end
		touchInput = nil
		touchStartPosition = nil
	end
end)

player:GetAttributeChangedSignal("PlanetSelectedTile"):Connect(function()
	local tileIndex = player:GetAttribute("PlanetSelectedTile")
	if type(tileIndex) ~= "number" or tileIndex <= 0 then
		if selectedHighlight then
			selectedHighlight:Destroy()
			selectedHighlight = nil
		end
	end
end)
