--!strict

local FactoryAssetLibrary = require(script.Parent.FactoryAssetLibrary)

local NativeAssetBuilder = {}

local COLORS = table.freeze({
	Dark = Color3.fromRGB(48, 53, 61),
	Steel = Color3.fromRGB(78, 86, 96),
	SteelLight = Color3.fromRGB(111, 121, 132),
	Copper = Color3.fromRGB(181, 111, 61),
	Brass = Color3.fromRGB(202, 157, 72),
	Cyan = Color3.fromRGB(71, 211, 226),
	Orange = Color3.fromRGB(230, 139, 58),
	Red = Color3.fromRGB(202, 75, 70),
	Green = Color3.fromRGB(74, 181, 125),
	Blue = Color3.fromRGB(69, 133, 192),
	Violet = Color3.fromRGB(145, 92, 196),
})

local function model(parent: Instance, name: string): Model
	local result = Instance.new("Model")
	result.Name = name
	result:SetAttribute("NativePresentation", true)
	result.Parent = parent
	return result
end

local function configurePart(part: BasePart, plotId: number)
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
	material: Enum.Material?,
	shape: Enum.PartType?
): Part
	local result = Instance.new("Part")
	result.Name = name
	result.Size = size
	result.CFrame = cframe
	result.Color = color
	result.Material = material or Enum.Material.Metal
	if shape ~= nil then
		result.Shape = shape
	end
	configurePart(result, plotId)
	result.Parent = parent
	return result
end

local function wedge(
	parent: Instance,
	plotId: number,
	name: string,
	size: Vector3,
	cframe: CFrame,
	color: Color3,
	material: Enum.Material?
): WedgePart
	local result = Instance.new("WedgePart")
	result.Name = name
	result.Size = size
	result.CFrame = cframe
	result.Color = color
	result.Material = material or Enum.Material.Metal
	configurePart(result, plotId)
	result.Parent = parent
	return result
end

local function tier(instance: Instance, requiredTier: number): Instance
	instance:SetAttribute("RequiredTier", requiredTier)
	return instance
end

local function busy(instance: Instance): Instance
	instance:SetAttribute("BusyOnly", true)
	return instance
end

local function unlocked(instance: Instance): Instance
	instance:SetAttribute("UnlockedOnly", true)
	return instance
end

local function locked(instance: Instance): Instance
	instance:SetAttribute("LockedOnly", true)
	return instance
end

local function hideAuthority(anchor: BasePart)
	anchor.Transparency = 1
end

function NativeAssetBuilder.BuildProcessor(anchor: BasePart, plotId: number): Model
	hideAuthority(anchor)
	local root = model(anchor.Parent, "ProcessorVisual")
	local cf = anchor.CFrame
	local baseY = -(anchor.Size.Y / 2) + 0.65

	part(
		root,
		plotId,
		"Base",
		Vector3.new(10.8, 1.2, 8.7),
		cf * CFrame.new(0, baseY, 0),
		COLORS.Dark,
		Enum.Material.DiamondPlate,
		nil
	)
	part(
		root,
		plotId,
		"MainHousing",
		Vector3.new(8.4, 4.8, 6.4),
		cf * CFrame.new(0, -0.35, 0.4),
		COLORS.Steel,
		Enum.Material.Metal,
		nil
	)
	wedge(
		root,
		plotId,
		"IntakeHopperL",
		Vector3.new(3.2, 3.1, 4.2),
		cf * CFrame.new(-2.2, 2.3, -2.1) * CFrame.Angles(0, math.rad(180), 0),
		COLORS.SteelLight,
		Enum.Material.Metal
	)
	wedge(
		root,
		plotId,
		"IntakeHopperR",
		Vector3.new(3.2, 3.1, 4.2),
		cf * CFrame.new(2.2, 2.3, -2.1) * CFrame.Angles(0, math.rad(180), 0),
		COLORS.SteelLight,
		Enum.Material.Metal
	)

	for index, zOffset in { -2.15, -0.35 } do
		local drum = part(
			root,
			plotId,
			("CrusherDrum%d"):format(index),
			Vector3.new(5.4, 1.5, 1.5),
			cf * CFrame.new(0, 0.75, zOffset),
			COLORS.Dark,
			Enum.Material.Metal,
			Enum.PartType.Cylinder
		)
		drum:SetAttribute("MachineEffect", "Spin")
		drum:SetAttribute("EffectSpeedDegrees", if index == 1 then 210 else -190)
	end

	part(
		root,
		plotId,
		"SideMotor",
		Vector3.new(2.4, 2.4, 2.6),
		cf * CFrame.new(5, -0.5, 0.7),
		COLORS.Copper,
		Enum.Material.Metal,
		nil
	)
	part(
		root,
		plotId,
		"MotorCap",
		Vector3.new(0.7, 2, 2),
		cf * CFrame.new(6.15, -0.5, 0.7),
		COLORS.Brass,
		Enum.Material.Metal,
		Enum.PartType.Cylinder
	)
	wedge(
		root,
		plotId,
		"OutputChute",
		Vector3.new(5.2, 1.5, 3.2),
		cf * CFrame.new(0, -2.5, 3.6),
		COLORS.SteelLight,
		Enum.Material.Metal
	)

	tier(
		part(
			root,
			plotId,
			"Tier2Motor",
			Vector3.new(2.2, 2.2, 2.2),
			cf * CFrame.new(-4.8, -0.7, 1.2),
			COLORS.Copper,
			Enum.Material.Metal,
			nil
		),
		2
	)
	tier(
		part(
			root,
			plotId,
			"Tier2Guard",
			Vector3.new(9.2, 0.45, 1),
			cf * CFrame.new(0, 2.7, -2.7),
			COLORS.Brass,
			Enum.Material.Metal,
			nil
		),
		2
	)
	tier(
		part(
			root,
			plotId,
			"Tier3Cooler",
			Vector3.new(6.6, 1.1, 2),
			cf * CFrame.new(0, 3.15, 1.4),
			COLORS.SteelLight,
			Enum.Material.DiamondPlate,
			nil
		),
		3
	)
	tier(
		part(
			root,
			plotId,
			"Tier3Pipe",
			Vector3.new(0.8, 4.4, 0.8),
			cf * CFrame.new(-3.4, 1.5, 3),
			COLORS.Copper,
			Enum.Material.Metal,
			Enum.PartType.Cylinder
		),
		3
	)
	tier(
		part(
			root,
			plotId,
			"Tier4Core",
			Vector3.new(1.2, 4.2, 1.2),
			cf * CFrame.new(4.1, 1.3, 2.8),
			COLORS.Cyan,
			Enum.Material.Neon,
			nil
		),
		4
	)
	tier(
		part(
			root,
			plotId,
			"Tier4Rail",
			Vector3.new(8, 0.4, 0.4),
			cf * CFrame.new(0, 3.55, -0.2),
			COLORS.Cyan,
			Enum.Material.Neon,
			nil
		),
		4
	)

	busy(
		part(
			root,
			plotId,
			"BusyBeacon",
			Vector3.new(0.7, 0.7, 0.7),
			cf * CFrame.new(0, 4.55, -2.4),
			COLORS.Cyan,
			Enum.Material.Neon,
			Enum.PartType.Ball
		)
	)
	return root
end

function NativeAssetBuilder.BuildAssembler(anchor: BasePart, plotId: number): Model
	hideAuthority(anchor)
	local root = model(anchor.Parent, "AssemblerVisual")
	local cf = anchor.CFrame
	local baseY = -(anchor.Size.Y / 2) + 0.55

	local groundCFrame = cf * CFrame.new(0, -(anchor.Size.Y / 2) + 0.05, 0)
	local importedAssembler =
		FactoryAssetLibrary.TryPlace("BotAssemblerStation", root, groundCFrame, plotId)

	if importedAssembler ~= nil then
		importedAssembler.Name = "BotAssemblerStation"
	else
		part(
			root,
			plotId,
			"Base",
			Vector3.new(10.8, 1, 8.7),
			cf * CFrame.new(0, baseY, 0),
			COLORS.Dark,
			Enum.Material.DiamondPlate,
			nil
		)
		part(
			root,
			plotId,
			"BackWall",
			Vector3.new(10, 6.8, 1),
			cf * CFrame.new(0, 0.25, 3.4),
			COLORS.Steel,
			Enum.Material.Metal,
			nil
		)
		for x in { -4.3, 4.3 } do
			part(
				root,
				plotId,
				"GantryPost",
				Vector3.new(0.9, 7, 0.9),
				cf * CFrame.new(x, 0.4, 0.6),
				COLORS.SteelLight,
				Enum.Material.Metal,
				nil
			)
		end
		part(
			root,
			plotId,
			"GantryBeam",
			Vector3.new(9.5, 0.9, 0.9),
			cf * CFrame.new(0, 3.65, 0.6),
			COLORS.SteelLight,
			Enum.Material.Metal,
			nil
		)
	end

	local buildPlate = part(
		root,
		plotId,
		"BuildPlate",
		Vector3.new(0.65, 5.4, 5.4),
		cf * CFrame.new(0, -2.6, 0) * CFrame.Angles(0, 0, math.rad(90)),
		COLORS.Dark,
		Enum.Material.Metal,
		Enum.PartType.Cylinder
	)
	buildPlate:SetAttribute("MachineEffect", "Spin")
	buildPlate:SetAttribute("EffectSpeedDegrees", 70)
	part(
		root,
		plotId,
		"ArmBase",
		Vector3.new(1.8, 1.2, 1.8),
		cf * CFrame.new(-2.8, -1.6, 1.5),
		COLORS.Copper,
		Enum.Material.Metal,
		nil
	)
	part(
		root,
		plotId,
		"ArmLower",
		Vector3.new(0.8, 3.2, 0.8),
		cf * CFrame.new(-2.5, 0, 1.2) * CFrame.Angles(0, 0, math.rad(-20)),
		COLORS.Brass,
		Enum.Material.Metal,
		nil
	)
	part(
		root,
		plotId,
		"ArmUpper",
		Vector3.new(0.75, 2.8, 0.75),
		cf * CFrame.new(-1.5, 1.9, 0.4) * CFrame.Angles(math.rad(35), 0, math.rad(-30)),
		COLORS.Copper,
		Enum.Material.Metal,
		nil
	)
	part(
		root,
		plotId,
		"ToolHead",
		Vector3.new(1.3, 1, 1.5),
		cf * CFrame.new(-0.5, 2.5, -0.6),
		COLORS.Orange,
		Enum.Material.Metal,
		nil
	)

	tier(
		part(
			root,
			plotId,
			"Tier2SecondArm",
			Vector3.new(0.8, 3.3, 0.8),
			cf * CFrame.new(2.6, 0.1, 1.1) * CFrame.Angles(0, 0, math.rad(18)),
			COLORS.Brass,
			Enum.Material.Metal,
			nil
		),
		2
	)
	tier(
		part(
			root,
			plotId,
			"Tier2Feeder",
			Vector3.new(2, 2.2, 4.8),
			cf * CFrame.new(4.5, -1.2, -0.5),
			COLORS.Steel,
			Enum.Material.Metal,
			nil
		),
		2
	)
	tier(
		part(
			root,
			plotId,
			"Tier3TopRail",
			Vector3.new(7.2, 0.55, 0.55),
			cf * CFrame.new(0, 3.1, -2.5),
			COLORS.Cyan,
			Enum.Material.Neon,
			nil
		),
		3
	)
	tier(
		part(
			root,
			plotId,
			"Tier3ToolRack",
			Vector3.new(5, 1.1, 1.5),
			cf * CFrame.new(0, 1.9, 2.7),
			COLORS.SteelLight,
			Enum.Material.DiamondPlate,
			nil
		),
		3
	)
	tier(
		part(
			root,
			plotId,
			"Tier4BuildRing",
			Vector3.new(0.35, 6.5, 6.5),
			cf * CFrame.new(0, -2.15, 0) * CFrame.Angles(0, 0, math.rad(90)),
			COLORS.Cyan,
			Enum.Material.Neon,
			Enum.PartType.Cylinder
		),
		4
	)
	tier(
		part(
			root,
			plotId,
			"Tier4Core",
			Vector3.new(1.3, 2.8, 1.3),
			cf * CFrame.new(4.3, 1.7, 2.8),
			COLORS.Orange,
			Enum.Material.Neon,
			nil
		),
		4
	)

	busy(
		part(
			root,
			plotId,
			"BusyBeacon",
			Vector3.new(0.7, 0.7, 0.7),
			cf * CFrame.new(0, 4.45, 2.8),
			COLORS.Orange,
			Enum.Material.Neon,
			Enum.PartType.Ball
		)
	)
	return root
end

function NativeAssetBuilder.BuildStorage(anchor: BasePart, plotId: number): Model
	hideAuthority(anchor)
	local root = model(anchor.Parent, "StorageVisual")
	local cf = anchor.CFrame
	part(
		root,
		plotId,
		"RackBase",
		Vector3.new(17.5, 0.7, 6.5),
		cf * CFrame.new(0, -1.6, 0),
		COLORS.Dark,
		Enum.Material.DiamondPlate,
		nil
	)
	for x in { -5.5, 0, 5.5 } do
		part(
			root,
			plotId,
			"Bin",
			Vector3.new(4.6, 3.2, 5),
			cf * CFrame.new(x, 0, 0),
			COLORS.Steel,
			Enum.Material.Metal,
			nil
		)
		part(
			root,
			plotId,
			"BinHandle",
			Vector3.new(2.6, 0.35, 0.35),
			cf * CFrame.new(x, 0.3, -2.55),
			COLORS.Brass,
			Enum.Material.Metal,
			nil
		)
	end
	tier(
		part(
			root,
			plotId,
			"Tier2UpperRack",
			Vector3.new(17, 0.5, 5.8),
			cf * CFrame.new(0, 2.2, 0),
			COLORS.SteelLight,
			Enum.Material.DiamondPlate,
			nil
		),
		2
	)
	tier(
		part(
			root,
			plotId,
			"Tier3Hopper",
			Vector3.new(9, 2.4, 5),
			cf * CFrame.new(0, 3.6, 0.3),
			COLORS.Steel,
			Enum.Material.Metal,
			nil
		),
		3
	)
	tier(
		part(
			root,
			plotId,
			"Tier4StatusBar",
			Vector3.new(14, 0.35, 0.35),
			cf * CFrame.new(0, 5.1, -2.3),
			COLORS.Cyan,
			Enum.Material.Neon,
			nil
		),
		4
	)
	return root
end

function NativeAssetBuilder.BuildTerminal(
	anchor: BasePart,
	plotId: number,
	name: string,
	accent: Color3
): Model
	hideAuthority(anchor)
	local root = model(anchor.Parent, name .. "Visual")
	local cf = anchor.CFrame
	part(
		root,
		plotId,
		"Foot",
		Vector3.new(4.6, 0.6, 3.8),
		cf * CFrame.new(0, -1.8, 0),
		COLORS.Dark,
		Enum.Material.DiamondPlate,
		nil
	)
	part(
		root,
		plotId,
		"Pedestal",
		Vector3.new(3.5, 3.2, 2.8),
		cf * CFrame.new(0, -0.1, 0.3),
		COLORS.Steel,
		Enum.Material.Metal,
		nil
	)
	wedge(
		root,
		plotId,
		"ConsoleHead",
		Vector3.new(4.3, 2.3, 3.3),
		cf * CFrame.new(0, 1.65, -0.15) * CFrame.Angles(0, math.rad(180), 0),
		COLORS.SteelLight,
		Enum.Material.Metal
	)
	local screen = part(
		root,
		plotId,
		"Screen",
		Vector3.new(3, 1.25, 0.18),
		cf * CFrame.new(0, 1.85, -1.62) * CFrame.Angles(math.rad(-13), 0, 0),
		accent,
		Enum.Material.Neon,
		nil
	)
	screen.Transparency = 0.08
	part(
		root,
		plotId,
		"Button",
		Vector3.new(0.45, 0.45, 0.18),
		cf * CFrame.new(1.35, 0.65, -1.15),
		COLORS.Green,
		Enum.Material.Neon,
		Enum.PartType.Ball
	)
	return root
end

function NativeAssetBuilder.BuildRecycle(anchor: BasePart, plotId: number): Model
	hideAuthority(anchor)
	local root = model(anchor.Parent, "RecycleVisual")
	local cf = anchor.CFrame
	part(
		root,
		plotId,
		"Base",
		Vector3.new(7.4, 0.7, 5.4),
		cf * CFrame.new(0, -1.8, 0),
		COLORS.Dark,
		Enum.Material.DiamondPlate,
		nil
	)
	part(
		root,
		plotId,
		"CrusherBody",
		Vector3.new(6.4, 3.2, 4.3),
		cf * CFrame.new(0, -0.1, 0.2),
		COLORS.Steel,
		Enum.Material.Metal,
		nil
	)
	wedge(
		root,
		plotId,
		"FeedChute",
		Vector3.new(5.4, 2.5, 3.3),
		cf * CFrame.new(0, 2, -1.1) * CFrame.Angles(0, math.rad(180), 0),
		COLORS.Red,
		Enum.Material.Metal
	)
	for x in { -1.6, 1.6 } do
		part(
			root,
			plotId,
			"CrusherRoll",
			Vector3.new(3.8, 0.8, 0.8),
			cf * CFrame.new(x, 0.3, -2.05) * CFrame.Angles(0, 0, math.rad(90)),
			COLORS.Dark,
			Enum.Material.Metal,
			Enum.PartType.Cylinder
		)
	end
	part(
		root,
		plotId,
		"Status",
		Vector3.new(3.5, 0.35, 0.25),
		cf * CFrame.new(0, 0.9, -2.25),
		COLORS.Red,
		Enum.Material.Neon,
		nil
	)
	return root
end

function NativeAssetBuilder.BuildWorkPad(anchor: BasePart, plotId: number): Model
	anchor.Transparency = 1
	anchor.CanCollide = false
	local root = model(anchor.Parent, anchor.Name .. "Visual")
	local cf = anchor.CFrame
	local base = part(
		root,
		plotId,
		"Base",
		Vector3.new(0.45, 8.4, 8.4),
		cf * CFrame.new(0, 0.05, 0) * CFrame.Angles(0, 0, math.rad(90)),
		COLORS.Dark,
		Enum.Material.Metal,
		Enum.PartType.Cylinder
	)
	base:SetAttribute("PadBase", true)
	local ring = part(
		root,
		plotId,
		"UnlockedRing",
		Vector3.new(0.22, 6.8, 6.8),
		cf * CFrame.new(0, 0.32, 0) * CFrame.Angles(0, 0, math.rad(90)),
		COLORS.Cyan,
		Enum.Material.Neon,
		Enum.PartType.Cylinder
	)
	unlocked(ring)
	local lockPlate = part(
		root,
		plotId,
		"LockedPlate",
		Vector3.new(4.3, 0.2, 1.2),
		cf * CFrame.new(0, 0.48, 0),
		COLORS.Red,
		Enum.Material.Neon,
		nil
	)
	locked(lockPlate)
	return root
end

function NativeAssetBuilder.BuildSalvage(
	anchor: BasePart,
	plotId: number,
	zoneId: number,
	variant: number
): Model
	anchor.Transparency = 1
	anchor.CanQuery = false
	local root = model(anchor, "SalvageVisual")
	local cf = anchor.CFrame
	local accent = if zoneId == 3
		then COLORS.Brass
		elseif zoneId == 4 then Color3.fromRGB(85, 231, 174)
		elseif zoneId >= 2 then COLORS.Cyan
		else COLORS.Copper
	if anchor:GetAttribute("ExpeditionCache") == true then
		part(
			root,
			plotId,
			"CacheCrate",
			Vector3.new(5, 2.4, 4),
			cf,
			COLORS.Dark,
			Enum.Material.Metal,
			nil
		)
		part(
			root,
			plotId,
			"CacheLatch",
			Vector3.new(0.6, 2.6, 4.2),
			cf,
			accent,
			Enum.Material.Neon,
			nil
		)
	end
	local metal = if zoneId >= 2 then Color3.fromRGB(67, 84, 92) else Color3.fromRGB(94, 79, 67)

	part(
		root,
		plotId,
		"PlateA",
		Vector3.new(3.8, 0.65, 2.4),
		cf
			* CFrame.new(-1.2, 0.2, 0.5)
			* CFrame.Angles(math.rad(10), math.rad(24 + variant * 9), math.rad(8)),
		metal,
		Enum.Material.Metal,
		nil
	)
	part(
		root,
		plotId,
		"PlateB",
		Vector3.new(3, 0.55, 3.1),
		cf
			* CFrame.new(1.4, 0.35, -0.8)
			* CFrame.Angles(math.rad(-8), math.rad(-30 - variant * 7), math.rad(12)),
		COLORS.Dark,
		Enum.Material.Metal,
		nil
	)
	part(
		root,
		plotId,
		"Motor",
		Vector3.new(1.5, 1.5, 1.5),
		cf * CFrame.new(0.4, 0.9, 1.2),
		accent,
		Enum.Material.Metal,
		Enum.PartType.Cylinder
	)
	part(
		root,
		plotId,
		"Pipe",
		Vector3.new(0.55, 3.4, 0.55),
		cf * CFrame.new(-1.6, 1.1, -1.3) * CFrame.Angles(0, 0, math.rad(62)),
		COLORS.SteelLight,
		Enum.Material.Metal,
		Enum.PartType.Cylinder
	)
	part(
		root,
		plotId,
		"Gear",
		Vector3.new(0.45, 1.9, 1.9),
		cf * CFrame.new(1.6, 1.05, 1.2) * CFrame.Angles(0, 0, math.rad(90)),
		COLORS.Brass,
		Enum.Material.Metal,
		Enum.PartType.Cylinder
	)
	if zoneId >= 2 then
		part(
			root,
			plotId,
			"CircuitCore",
			Vector3.new(0.75, 0.75, 0.75),
			cf * CFrame.new(-0.1, 1.65, -0.5),
			COLORS.Cyan,
			Enum.Material.Neon,
			Enum.PartType.Ball
		)
	end
	return root
end

function NativeAssetBuilder.GetColors()
	return COLORS
end

return table.freeze(NativeAssetBuilder)
