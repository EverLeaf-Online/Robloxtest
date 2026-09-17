--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local FactoryRules = require(ReplicatedStorage.Shared.Domain.FactoryRules)
local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local Robots = require(ReplicatedStorage.Shared.Config.Robots)

local DataService = require(script.Parent.DataService)
local MonetizationService = require(script.Parent.MonetizationService)
local PlotService = require(script.Parent.PlotService)
local WorldService = require(script.Parent.WorldService)

local RobotVisualService = {}
local initialized = false

local SYNC_SECONDS = 0.5

local accentColors = table.freeze({
	Steel = Color3.fromRGB(151, 158, 168),
	Orange = Color3.fromRGB(235, 137, 56),
	Blue = Color3.fromRGB(78, 145, 224),
	Yellow = Color3.fromRGB(232, 192, 67),
	Copper = Color3.fromRGB(184, 115, 74),
	Green = Color3.fromRGB(78, 187, 118),
	Teal = Color3.fromRGB(63, 184, 175),
	Red = Color3.fromRGB(211, 78, 78),
	Violet = Color3.fromRGB(133, 91, 213),
	Cyan = Color3.fromRGB(68, 205, 224),
	Magenta = Color3.fromRGB(210, 74, 181),
	Gold = Color3.fromRGB(232, 188, 67),
})

local rarityColors = table.freeze({
	Common = Color3.fromRGB(182, 188, 199),
	Uncommon = Color3.fromRGB(91, 199, 121),
	Rare = Color3.fromRGB(83, 151, 232),
	Epic = Color3.fromRGB(186, 95, 229),
})

local function makePart(
	model: Model,
	name: string,
	size: Vector3,
	cframe: CFrame,
	color: Color3,
	shape: Enum.PartType?
): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.CastShadow = false
	part.Material = Enum.Material.Metal
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	if shape ~= nil then
		part.Shape = shape
	end
	part.Parent = model
	return part
end

local function bodySize(bodyType: string): Vector3
	if bodyType == "Heavy" then
		return Vector3.new(3.8, 2.8, 3.1)
	elseif bodyType == "Command" then
		return Vector3.new(4, 3.2, 3.2)
	elseif bodyType == "Utility" then
		return Vector3.new(3.4, 2.5, 2.8)
	elseif bodyType == "Orb" then
		return Vector3.new(3, 3, 3)
	end
	return Vector3.new(3, 2.4, 2.5)
end

local function buildHead(model: Model, headType: string, accent: Color3, bodyHeight: number)
	local headCFrame = CFrame.new(0, bodyHeight / 2 + 1.1, 0)
	if headType == "Round" then
		makePart(model, "Head", Vector3.new(1.8, 1.8, 1.8), headCFrame, accent, Enum.PartType.Ball)
	elseif headType == "Lens" then
		makePart(model, "Head", Vector3.new(1.9, 1.5, 1.5), headCFrame, accent, Enum.PartType.Ball)
		makePart(
			model,
			"Lens",
			Vector3.new(0.55, 0.55, 0.25),
			headCFrame * CFrame.new(0, 0, -0.8),
			Color3.fromRGB(211, 242, 255),
			Enum.PartType.Ball
		)
	elseif headType == "Visor" then
		makePart(model, "Head", Vector3.new(2.1, 1.5, 1.6), headCFrame, accent, nil)
		makePart(
			model,
			"Visor",
			Vector3.new(1.55, 0.45, 0.18),
			headCFrame * CFrame.new(0, 0.1, -0.88),
			Color3.fromRGB(121, 226, 255),
			nil
		)
	else
		makePart(model, "Head", Vector3.new(2, 1.6, 1.6), headCFrame, accent, nil)
	end
end

local function buildLocomotion(
	model: Model,
	locomotion: string,
	bodySizeValue: Vector3,
	baseColor: Color3
)
	local y = -(bodySizeValue.Y / 2 + 0.55)
	if locomotion == "Hover" then
		makePart(
			model,
			"HoverRing",
			Vector3.new(0.55, bodySizeValue.X * 0.9, bodySizeValue.X * 0.9),
			CFrame.new(0, y, 0) * CFrame.Angles(0, 0, math.rad(90)),
			Color3.fromRGB(87, 200, 224),
			Enum.PartType.Cylinder
		)
	elseif locomotion == "Tracks" then
		makePart(
			model,
			"LeftTrack",
			Vector3.new(1, 0.8, 3),
			CFrame.new(-1.25, y, 0),
			baseColor,
			nil
		)
		makePart(
			model,
			"RightTrack",
			Vector3.new(1, 0.8, 3),
			CFrame.new(1.25, y, 0),
			baseColor,
			nil
		)
	elseif locomotion == "Legs" then
		makePart(
			model,
			"LeftLeg",
			Vector3.new(0.75, 1.3, 0.75),
			CFrame.new(-0.9, y, 0),
			baseColor,
			nil
		)
		makePart(
			model,
			"RightLeg",
			Vector3.new(0.75, 1.3, 0.75),
			CFrame.new(0.9, y, 0),
			baseColor,
			nil
		)
	else
		makePart(
			model,
			"LeftWheel",
			Vector3.new(0.75, 1.35, 1.35),
			CFrame.new(-1.45, y, 0) * CFrame.Angles(0, 0, math.rad(90)),
			baseColor,
			Enum.PartType.Cylinder
		)
		makePart(
			model,
			"RightWheel",
			Vector3.new(0.75, 1.35, 1.35),
			CFrame.new(1.45, y, 0) * CFrame.Angles(0, 0, math.rad(90)),
			baseColor,
			Enum.PartType.Cylinder
		)
	end
end

local function buildTool(model: Model, toolType: string, accent: Color3, bodySizeValue: Vector3)
	local front = -(bodySizeValue.Z / 2 + 0.75)
	local toolSize = if toolType == "Drill"
		then Vector3.new(0.9, 0.9, 1.7)
		elseif toolType == "TwinMagnet" or toolType == "MultiTool" then Vector3.new(
			2.2,
			0.75,
			1
		)
		else Vector3.new(1.2, 0.8, 1.2)
	makePart(model, "Tool", toolSize, CFrame.new(0, 0, front), accent, nil)
end

local function addLabel(model: Model, definition: any, bodyHeight: number)
	local adornee = model.PrimaryPart
	if adornee == nil then
		return
	end

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "RobotLabel"
	billboard.Adornee = adornee
	billboard.AlwaysOnTop = true
	billboard.Size = UDim2.fromOffset(180, 52)
	billboard.StudsOffset = Vector3.new(0, bodyHeight / 2 + 3.2, 0)
	billboard.Parent = model

	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 0.25
	label.BackgroundColor3 = Color3.fromRGB(22, 25, 31)
	label.BorderSizePixel = 0
	label.Font = Enum.Font.GothamBold
	label.Size = UDim2.fromScale(1, 1)
	label.Text = ("%s\n%s • %.1f/s"):format(
		definition.DisplayName,
		definition.Rarity,
		definition.ProductionPerSecond
	)
	label.TextColor3 = rarityColors[definition.Rarity] or Color3.new(1, 1, 1)
	label.TextScaled = true
	label.TextWrapped = true
	label.Parent = billboard
end

local function createRobotVisual(robotUid: string, definition: any): Model
	local model = Instance.new("Model")
	model.Name = "RobotVisual"
	model:SetAttribute("RobotUid", robotUid)
	model:SetAttribute("RobotId", definition.Id)

	local accent = accentColors[definition.Visual.Accent] or Color3.fromRGB(150, 160, 175)
	local baseColor = Color3.fromRGB(70, 76, 87)
	local size = bodySize(definition.Visual.Body)
	local bodyShape = if definition.Visual.Body == "Orb" then Enum.PartType.Ball else nil
	local body = makePart(model, "Body", size, CFrame.new(), baseColor, bodyShape)
	model.PrimaryPart = body

	buildHead(model, definition.Visual.Head, accent, size.Y)
	buildLocomotion(model, definition.Visual.Locomotion, size, baseColor)
	buildTool(model, definition.Visual.Tool, accent, size)
	addLabel(model, definition, size.Y)
	return model
end

local function getVisualFolder(plot: Model): Folder
	local existing = plot:FindFirstChild("RobotVisuals")
	if existing ~= nil then
		assert(existing:IsA("Folder"), "RobotVisuals must be a Folder")
		return existing
	end

	local folder = Instance.new("Folder")
	folder.Name = "RobotVisuals"
	folder.Parent = plot
	return folder
end

local function clearVisuals(plot: Model)
	local folder = plot:FindFirstChild("RobotVisuals")
	if folder == nil or not folder:IsA("Folder") then
		return
	end
	folder:ClearAllChildren()
end

local function syncPad(folder: Folder, pad: BasePart, robotUid: string?, data: any)
	local padId = pad:GetAttribute("WorkPadId")
	if typeof(padId) ~= "string" then
		return
	end

	local existing = folder:FindFirstChild(padId)
	if robotUid == nil then
		if existing ~= nil then
			existing:Destroy()
		end
		return
	end

	local owned = data.Robots.OwnedByUid[robotUid]
	local definition = if owned then Robots.Definitions[owned.RobotId] else nil
	if definition == nil then
		if existing ~= nil then
			existing:Destroy()
		end
		return
	end

	if
		existing ~= nil
		and existing:IsA("Model")
		and existing:GetAttribute("RobotUid") == robotUid
		and existing:GetAttribute("RobotId") == definition.Id
	then
		return
	end
	if existing ~= nil then
		existing:Destroy()
	end

	local visual = createRobotVisual(robotUid, definition)
	visual.Name = padId
	visual.Parent = folder
	visual:PivotTo(pad.CFrame * CFrame.new(0, 2.5, 0))
end

local function syncPlayer(player: Player)
	local data = DataService.GetData(player)
	local plot = PlotService.GetPlot(player)
	local plotId = PlotService.GetPlotId(player)
	if data == nil or plot == nil or plotId == nil then
		return
	end

	local baseSlots = FactoryRules.GetWorkSlots(data.Machines.WorkSlotsLevel)
	local unlockedSlots = math.min(
		GameConfig.Factory.MaxWorkSlots + 2,
		baseSlots + MonetizationService.GetExtraWorkSlots(player)
	)
	local folder = getVisualFolder(plot)
	for index = 1, GameConfig.Factory.MaxWorkSlots + 2 do
		local padId = ("Pad%d"):format(index)
		local pad = WorldService.GetPlotWorkPad(plotId, padId)
		if pad ~= nil then
			local assignedUid = if index <= unlockedSlots
				then data.Assignments.WorkPads[padId]
				else nil
			syncPad(folder, pad, assignedUid, data)
		end
	end
end

local function clearUnownedPlots()
	for _, plot in WorldService.GetPlots() do
		if plot:GetAttribute("OwnerUserId") == 0 then
			clearVisuals(plot)
		end
	end
end

function RobotVisualService.Init()
	if initialized then
		return
	end
	initialized = true

	task.spawn(function()
		while true do
			task.wait(SYNC_SECONDS)
			clearUnownedPlots()
			for _, player in Players:GetPlayers() do
				if DataService.IsReady(player) then
					syncPlayer(player)
				end
			end
		end
	end)
end

return RobotVisualService
