--!strict

local CircuitUnlockButtonBuilder = {}

local COLORS = table.freeze({
	Base = Color3.fromRGB(30, 34, 39),
	BaseEdge = Color3.fromRGB(55, 61, 68),
	Plate = Color3.fromRGB(73, 80, 86),
	Hazard = Color3.fromRGB(238, 214, 37),
	ButtonRing = Color3.fromRGB(20, 23, 27),
	Button = Color3.fromRGB(232, 70, 55),
	ButtonGlow = Color3.fromRGB(255, 99, 79),
	Bolt = Color3.fromRGB(150, 157, 164),
})

local function configure(part: BasePart, plotId: number)
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.CastShadow = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part:SetAttribute("PlotId", plotId)
	part:SetAttribute("PresentationPart", true)
end

local function part(
	parent: Instance,
	plotId: number,
	name: string,
	size: Vector3,
	cframe: CFrame,
	color: Color3,
	material: Enum.Material,
	shape: Enum.PartType?
): Part
	local result = Instance.new("Part")
	result.Name = name
	result.Size = size
	result.CFrame = cframe
	result.Color = color
	result.Material = material
	if shape ~= nil then
		result.Shape = shape
	end
	configure(result, plotId)
	result.Parent = parent
	return result
end

local function wedge(
	parent: Instance,
	plotId: number,
	name: string,
	size: Vector3,
	cframe: CFrame,
	color: Color3
): WedgePart
	local result = Instance.new("WedgePart")
	result.Name = name
	result.Size = size
	result.CFrame = cframe
	result.Color = color
	result.Material = Enum.Material.Metal
	configure(result, plotId)
	result.Parent = parent
	return result
end

function CircuitUnlockButtonBuilder.Build(parent: Instance, plotId: number, anchor: BasePart): Model
	local existing = parent:FindFirstChild("CircuitUnlockControlVisual")
	if existing ~= nil then
		assert(existing:IsA("Model"), "CircuitUnlockControlVisual must be a Model")
		return existing
	end

	local model = Instance.new("Model")
	model.Name = "CircuitUnlockControlVisual"
	model:SetAttribute("RequiredZone", 2)
	model:SetAttribute("AuthoredInRepo", true)
	model.Parent = parent

	local floorY = anchor.Position.Y - (anchor.Size.Y / 2) + 0.04
	local frame = CFrame.new(anchor.Position.X, floorY, anchor.Position.Z)

	part(
		model,
		plotId,
		"LowerBase",
		Vector3.new(7.4, 0.26, 7.4),
		frame * CFrame.new(0, 0.13, 0),
		COLORS.Base,
		Enum.Material.DiamondPlate,
		nil
	)
	part(
		model,
		plotId,
		"BaseEdge",
		Vector3.new(6.9, 0.22, 6.9),
		frame * CFrame.new(0, 0.35, 0),
		COLORS.BaseEdge,
		Enum.Material.Metal,
		nil
	)
	part(
		model,
		plotId,
		"TopPlate",
		Vector3.new(6.25, 0.18, 6.25),
		frame * CFrame.new(0, 0.55, 0),
		COLORS.Plate,
		Enum.Material.DiamondPlate,
		nil
	)

	for index, offset in
		{
			Vector3.new(-2.55, 0.68, -2.55),
			Vector3.new(2.55, 0.68, -2.55),
			Vector3.new(-2.55, 0.68, 2.55),
			Vector3.new(2.55, 0.68, 2.55),
		}
	do
		local cornerFrame = frame * CFrame.new(offset)
		part(
			model,
			plotId,
			("HazardPad%d"):format(index),
			Vector3.new(1.3, 0.16, 1.3),
			cornerFrame,
			COLORS.Hazard,
			Enum.Material.Neon,
			nil
		)
	end

	for index, offset in
		{
			Vector3.new(-3.05, 0.62, -3.05),
			Vector3.new(3.05, 0.62, -3.05),
			Vector3.new(-3.05, 0.62, 3.05),
			Vector3.new(3.05, 0.62, 3.05),
		}
	do
		part(
			model,
			plotId,
			("Bolt%d"):format(index),
			Vector3.new(0.28, 0.18, 0.28),
			frame * CFrame.new(offset),
			COLORS.Bolt,
			Enum.Material.Metal,
			Enum.PartType.Cylinder
		).CFrame = frame
			* CFrame.new(offset)
			* CFrame.Angles(0, 0, math.rad(90))
	end

	local ring = part(
		model,
		plotId,
		"ButtonRing",
		Vector3.new(0.55, 3.65, 3.65),
		frame * CFrame.new(0, 0.9, 0) * CFrame.Angles(0, 0, math.rad(90)),
		COLORS.ButtonRing,
		Enum.Material.Metal,
		Enum.PartType.Cylinder
	)
	ring:SetAttribute("CircuitUnlockButtonRing", true)

	local buttonBase = part(
		model,
		plotId,
		"ButtonBase",
		Vector3.new(0.58, 2.95, 2.95),
		frame * CFrame.new(0, 1.04, 0) * CFrame.Angles(0, 0, math.rad(90)),
		COLORS.Button,
		Enum.Material.SmoothPlastic,
		Enum.PartType.Cylinder
	)
	buttonBase:SetAttribute("CircuitUnlockButton", true)

	local dome = part(
		model,
		plotId,
		"ButtonDome",
		Vector3.new(2.6, 0.62, 2.6),
		frame * CFrame.new(0, 1.36, 0),
		COLORS.ButtonGlow,
		Enum.Material.Neon,
		Enum.PartType.Ball
	)
	dome:SetAttribute("CircuitUnlockButton", true)

	for index, rotation in { -1, 1 } do
		wedge(
			model,
			plotId,
			("FrontChamfer%d"):format(index),
			Vector3.new(1.2, 0.32, 2.1),
			frame
				* CFrame.new(rotation * 2.2, 0.42, -3.12)
				* CFrame.Angles(0, if rotation < 0 then math.rad(90) else math.rad(-90), 0),
			COLORS.Base
		)
	end

	local point = Instance.new("PointLight")
	point.Name = "ButtonGlow"
	point.Brightness = 0.35
	point.Range = 7
	point.Color = COLORS.ButtonGlow
	point.Shadows = false
	point.Parent = dome

	model.PrimaryPart = buttonBase
	return model
end

return table.freeze(CircuitUnlockButtonBuilder)
