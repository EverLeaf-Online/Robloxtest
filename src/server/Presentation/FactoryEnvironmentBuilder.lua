--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local WorldLayout = require(ReplicatedStorage.Shared.Config.WorldLayout)

local FactoryEnvironmentBuilder = {}

local COLORS = table.freeze({
	ConcreteDark = Color3.fromRGB(72, 76, 78),
	ConcreteLight = Color3.fromRGB(105, 108, 107),
	SteelDark = Color3.fromRGB(43, 48, 54),
	Steel = Color3.fromRGB(72, 80, 88),
	SteelLight = Color3.fromRGB(104, 115, 124),
	Rust = Color3.fromRGB(139, 82, 48),
	Copper = Color3.fromRGB(178, 106, 57),
	Brass = Color3.fromRGB(207, 162, 70),
	Safety = Color3.fromRGB(226, 174, 57),
	Cyan = Color3.fromRGB(71, 211, 226),
	Orange = Color3.fromRGB(230, 139, 58),
	Red = Color3.fromRGB(199, 72, 68),
	Green = Color3.fromRGB(76, 181, 125),
	Blue = Color3.fromRGB(67, 129, 187),
})

local function configure(part: BasePart, plotId: number, collidable: boolean)
	part.Anchored = true
	part.CanCollide = collidable
	part.CanTouch = false
	part.CanQuery = collidable
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
	collidable: boolean?,
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
	configure(result, plotId, collidable == true)
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
	material: Enum.Material?,
	collidable: boolean?
): WedgePart
	local result = Instance.new("WedgePart")
	result.Name = name
	result.Size = size
	result.CFrame = cframe
	result.Color = color
	result.Material = material or Enum.Material.Metal
	configure(result, plotId, collidable == true)
	result.Parent = parent
	return result
end

local function model(parent: Instance, name: string): Model
	local result = Instance.new("Model")
	result.Name = name
	result:SetAttribute("FactoryEnvironmentAsset", true)
	result.Parent = parent
	return result
end

local function floorPlate(
	parent: Instance,
	plotId: number,
	name: string,
	size: Vector3,
	position: Vector3,
	color: Color3,
	material: Enum.Material?
)
	local plate = part(
		parent,
		plotId,
		name,
		size,
		CFrame.new(position),
		color,
		material or Enum.Material.Concrete,
		false,
		nil
	)
	plate.CastShadow = false
	return plate
end

local function workLight(parent: Instance, plotId: number, name: string, position: Vector3)
	local fixture = part(
		parent,
		plotId,
		name,
		Vector3.new(4.5, 0.35, 1.4),
		CFrame.new(position),
		COLORS.SteelDark,
		Enum.Material.Metal,
		false,
		nil
	)
	local lens = part(
		parent,
		plotId,
		name .. "Lens",
		Vector3.new(3.7, 0.12, 0.85),
		fixture.CFrame * CFrame.new(0, -0.24, 0),
		Color3.fromRGB(206, 239, 244),
		Enum.Material.Neon,
		false,
		nil
	)
	local light = Instance.new("PointLight")
	light.Name = "WorkLight"
	light.Brightness = 0.85
	light.Color = Color3.fromRGB(210, 239, 243)
	light.Range = 26
	light.Shadows = false
	light.Parent = lens
end

local function safetyStripe(
	parent: Instance,
	plotId: number,
	name: string,
	size: Vector3,
	position: Vector3
)
	local stripe =
		floorPlate(parent, plotId, name, size, position, COLORS.Safety, Enum.Material.SmoothPlastic)
	stripe:SetAttribute("FloorMarking", true)
end

local function addSurfaceSign(partInstance: BasePart, text: string, face: Enum.NormalId)
	local surface = Instance.new("SurfaceGui")
	surface.Name = "IndustrialSign"
	surface.Face = face
	surface.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	surface.PixelsPerStud = 28
	surface.LightInfluence = 0
	surface.Parent = partInstance

	local label = Instance.new("TextLabel")
	label.BackgroundColor3 = Color3.fromRGB(24, 27, 31)
	label.BackgroundTransparency = 0.08
	label.BorderSizePixel = 0
	label.Font = Enum.Font.GothamBold
	label.Size = UDim2.fromScale(1, 1)
	label.Text = text
	label.TextColor3 = Color3.fromRGB(238, 241, 244)
	label.TextScaled = true
	label.TextWrapped = true
	label.Parent = surface
end

local function buildEntry(root: Model, plotId: number, center: Vector3)
	local entry = center + WorldLayout.Plot.EntryOffset
	local gate = model(root, "ReceivingGate")

	floorPlate(
		gate,
		plotId,
		"TruckApron",
		Vector3.new(34, 0.16, 42),
		center + Vector3.new(0, 0.59, -77),
		COLORS.ConcreteDark,
		Enum.Material.Concrete
	)

	for _, x in { -15, 15 } do
		part(
			gate,
			plotId,
			"GatePost",
			Vector3.new(1.8, 9, 1.8),
			CFrame.new(center + Vector3.new(x, 5, -98)),
			COLORS.SteelDark,
			Enum.Material.Metal,
			true,
			nil
		)
		part(
			gate,
			plotId,
			"Beacon",
			Vector3.new(0.6, 0.6, 0.6),
			CFrame.new(center + Vector3.new(x, 9.8, -98)),
			COLORS.Orange,
			Enum.Material.Neon,
			false,
			Enum.PartType.Ball
		)
	end

	local header = part(
		gate,
		plotId,
		"GateHeader",
		Vector3.new(32, 1.4, 1.5),
		CFrame.new(center + Vector3.new(0, 8.4, -98)),
		COLORS.Steel,
		Enum.Material.Metal,
		false,
		nil
	)
	addSurfaceSign(header, "SCRAP RECEIVING  •  PRODUCTION", Enum.NormalId.Front)

	local booth = part(
		gate,
		plotId,
		"ScaleBooth",
		Vector3.new(9, 7, 8),
		CFrame.new(center + Vector3.new(22, 4, -82)),
		COLORS.Steel,
		Enum.Material.Metal,
		true,
		nil
	)
	part(
		gate,
		plotId,
		"BoothWindow",
		Vector3.new(6.8, 2.4, 0.2),
		booth.CFrame * CFrame.new(0, 0.8, -4.1),
		COLORS.Cyan,
		Enum.Material.Glass,
		false,
		nil
	).Transparency =
		0.35

	for _, x in { -7, 7 } do
		safetyStripe(
			gate,
			plotId,
			("EntryLane_%d"):format(if x < 0 then 1 else 2),
			Vector3.new(0.28, 0.06, 38),
			center + Vector3.new(x, 0.72, -76)
		)
	end

	local spawnPlate = floorPlate(
		gate,
		plotId,
		"SpawnPlate",
		Vector3.new(16, 0.22, 10),
		Vector3.new(entry.X, center.Y + 0.66, entry.Z + 5),
		COLORS.SteelDark,
		Enum.Material.DiamondPlate
	)
	spawnPlate:SetAttribute("EntryPresentation", true)
end

local function buildScrapCrane(root: Model, plotId: number, center: Vector3)
	local crane = model(root, "ScrapGantryCrane")
	local yardCenter = center + WorldLayout.Environment.ScrapYardCenterOffset
	local xSpan = 58
	local zSpan = 50
	local postHeight = 17

	for _, x in { -xSpan / 2, xSpan / 2 } do
		for _, z in { -zSpan / 2, zSpan / 2 } do
			part(
				crane,
				plotId,
				"CraneLeg",
				Vector3.new(1.8, postHeight, 1.8),
				CFrame.new(yardCenter + Vector3.new(x, postHeight / 2 + 0.5, z)),
				COLORS.SteelDark,
				Enum.Material.Metal,
				true,
				nil
			)
		end
	end

	for _, z in { -zSpan / 2, zSpan / 2 } do
		part(
			crane,
			plotId,
			"CraneEndBeam",
			Vector3.new(xSpan + 4, 1.6, 1.6),
			CFrame.new(yardCenter + Vector3.new(0, postHeight, z)),
			COLORS.Steel,
			Enum.Material.Metal,
			false,
			nil
		)
	end

	local bridge = part(
		crane,
		plotId,
		"CraneBridge",
		Vector3.new(2, 2, zSpan),
		CFrame.new(yardCenter + Vector3.new(-8, postHeight + 0.4, 0)),
		COLORS.Safety,
		Enum.Material.Metal,
		false,
		nil
	)
	bridge:SetAttribute("MachineEffect", "CraneTravel")

	part(
		crane,
		plotId,
		"Trolley",
		Vector3.new(4.5, 2, 4.5),
		CFrame.new(yardCenter + Vector3.new(-8, postHeight - 1, 5)),
		COLORS.SteelDark,
		Enum.Material.Metal,
		false,
		nil
	)
	part(
		crane,
		plotId,
		"HoistCable",
		Vector3.new(0.32, 9, 0.32),
		CFrame.new(yardCenter + Vector3.new(-8, postHeight - 6.2, 5)),
		Color3.fromRGB(34, 36, 39),
		Enum.Material.Metal,
		false,
		Enum.PartType.Cylinder
	)
	local magnet = part(
		crane,
		plotId,
		"ScrapMagnet",
		Vector3.new(1, 6.5, 6.5),
		CFrame.new(yardCenter + Vector3.new(-8, postHeight - 10.7, 5))
			* CFrame.Angles(0, 0, math.rad(90)),
		COLORS.Rust,
		Enum.Material.Metal,
		false,
		Enum.PartType.Cylinder
	)
	magnet:SetAttribute("MachineEffect", "Swing")
end

local function buildScrapYard(root: Model, plotId: number, center: Vector3)
	local yard = model(root, "ScrapReceivingYard")
	local yardCenter = center + WorldLayout.Environment.ScrapYardCenterOffset

	floorPlate(
		yard,
		plotId,
		"YardFloor",
		Vector3.new(68, 0.18, 62),
		yardCenter + Vector3.new(0, 0.6, 0),
		Color3.fromRGB(87, 86, 81),
		Enum.Material.Concrete
	)

	for _, x in { -34, 34 } do
		for z = -28, 28, 14 do
			part(
				yard,
				plotId,
				"FencePost",
				Vector3.new(0.55, 5.5, 0.55),
				CFrame.new(yardCenter + Vector3.new(x, 3.2, z)),
				COLORS.Steel,
				Enum.Material.Metal,
				true,
				nil
			)
		end
	end

	for _, z in { -31, 31 } do
		for x = -28, 28, 14 do
			part(
				yard,
				plotId,
				"FencePost",
				Vector3.new(0.55, 5.5, 0.55),
				CFrame.new(yardCenter + Vector3.new(x, 3.2, z)),
				COLORS.Steel,
				Enum.Material.Metal,
				true,
				nil
			)
		end
	end

	for _, z in { -30, 30 } do
		part(
			yard,
			plotId,
			"FenceRail",
			Vector3.new(56, 0.35, 0.35),
			CFrame.new(yardCenter + Vector3.new(0, 2, z)),
			COLORS.SteelLight,
			Enum.Material.Metal,
			true,
			nil
		)
		part(
			yard,
			plotId,
			"FenceRail",
			Vector3.new(56, 0.35, 0.35),
			CFrame.new(yardCenter + Vector3.new(0, 4.2, z)),
			COLORS.SteelLight,
			Enum.Material.Metal,
			true,
			nil
		)
	end

	for _, x in { -33, 33 } do
		if x < 0 then
			for _, y in { 2, 4.2 } do
				part(
					yard,
					plotId,
					"FenceRail",
					Vector3.new(0.35, 0.35, 52),
					CFrame.new(yardCenter + Vector3.new(x, y, 0)),
					COLORS.SteelLight,
					Enum.Material.Metal,
					true,
					nil
				)
			end
		else
			for _, y in { 2, 4.2 } do
				for segmentIndex, z in { -18, 18 } do
					part(
						yard,
						plotId,
						("FenceRailGate%d_%d"):format(segmentIndex, math.floor(y * 10)),
						Vector3.new(0.35, 0.35, 20),
						CFrame.new(yardCenter + Vector3.new(x, y, z)),
						COLORS.SteelLight,
						Enum.Material.Metal,
						true,
						nil
					)
				end
			end

			for _, z in { -7, 7 } do
				part(
					yard,
					plotId,
					"GatePost",
					Vector3.new(0.7, 5.5, 0.7),
					CFrame.new(yardCenter + Vector3.new(x, 3.2, z)),
					COLORS.Safety,
					Enum.Material.Metal,
					true,
					nil
				)
			end
		end
	end

	local hopper = model(yard, "PrimaryIntakeHopper")
	for _, side in { -1, 1 } do
		wedge(
			hopper,
			plotId,
			"HopperWall",
			Vector3.new(8, 5.5, 10),
			CFrame.new(yardCenter + Vector3.new(26 + side * 3.2, 3.3, -21))
				* CFrame.Angles(0, if side < 0 then 0 else math.rad(180), 0),
			COLORS.Steel,
			Enum.Material.Metal,
			true
		)
	end
	part(
		hopper,
		plotId,
		"HopperThroat",
		Vector3.new(7, 3, 7),
		CFrame.new(yardCenter + Vector3.new(26, 1.9, -15)),
		COLORS.SteelDark,
		Enum.Material.Metal,
		true,
		nil
	)

	for index, x in { -21, 0, 21 } do
		local bin = model(yard, ("SortingBin%d"):format(index))
		local cf = CFrame.new(yardCenter + Vector3.new(x, 2.5, 24))
		part(
			bin,
			plotId,
			"Back",
			Vector3.new(16, 5, 0.7),
			cf * CFrame.new(0, 0, 5.5),
			COLORS.Rust,
			Enum.Material.Metal,
			true,
			nil
		)
		for _, sx in { -7.6, 7.6 } do
			part(
				bin,
				plotId,
				"Side",
				Vector3.new(0.7, 5, 11),
				cf * CFrame.new(sx, 0, 0),
				COLORS.Rust,
				Enum.Material.Metal,
				true,
				nil
			)
		end
	end

	buildScrapCrane(root, plotId, center)

	local sign = part(
		yard,
		plotId,
		"ScrapReceivingSign",
		Vector3.new(22, 4, 0.8),
		CFrame.new(yardCenter + Vector3.new(0, 7.2, -31)),
		COLORS.SteelDark,
		Enum.Material.Metal,
		false,
		nil
	)
	addSurfaceSign(sign, "SCRAP RECEIVING", Enum.NormalId.Front)
end

local function conveyorSegment(
	parent: Instance,
	plotId: number,
	name: string,
	cframe: CFrame,
	length: number,
	width: number
)
	local conveyor = model(parent, name)
	part(
		conveyor,
		plotId,
		"Bed",
		Vector3.new(width, 0.65, length),
		cframe,
		COLORS.SteelDark,
		Enum.Material.Metal,
		true,
		nil
	)
	for _, x in { -(width / 2 - 0.35), width / 2 - 0.35 } do
		part(
			conveyor,
			plotId,
			"Rail",
			Vector3.new(0.35, 1.2, length),
			cframe * CFrame.new(x, 0.85, 0),
			COLORS.SteelLight,
			Enum.Material.Metal,
			true,
			nil
		)
	end
	for z = -(length / 2 - 1), length / 2 - 1, 2.5 do
		local roller = part(
			conveyor,
			plotId,
			"Roller",
			Vector3.new(0.38, width - 1, width - 1),
			cframe * CFrame.new(0, 0.52, z) * CFrame.Angles(0, 0, math.rad(90)),
			COLORS.Steel,
			Enum.Material.Metal,
			false,
			Enum.PartType.Cylinder
		)
		roller:SetAttribute("MachineEffect", "Spin")
		roller:SetAttribute("EffectSpeedDegrees", 125)
	end
end

local function buildProductionHall(root: Model, plotId: number, center: Vector3)
	local hall = model(root, "ProductionHall")
	local hallCenter = center + WorldLayout.Environment.ProductionHallCenterOffset
	local hallWidth = 118
	local hallDepth = 72
	local roofY = 18.5

	floorPlate(
		hall,
		plotId,
		"EpoxyFloor",
		Vector3.new(hallWidth, 0.16, hallDepth),
		hallCenter + Vector3.new(0, 0.61, 0),
		Color3.fromRGB(68, 73, 76),
		Enum.Material.Concrete
	)

	for _, x in { -56, -28, 0, 28, 56 } do
		for _, z in { -34, 34 } do
			part(
				hall,
				plotId,
				"HallColumn",
				Vector3.new(1.4, 18, 1.4),
				CFrame.new(hallCenter + Vector3.new(x, 9.5, z)),
				COLORS.SteelDark,
				Enum.Material.Metal,
				true,
				nil
			)
		end
		part(
			hall,
			plotId,
			"RoofTruss",
			Vector3.new(1.2, 1.2, hallDepth),
			CFrame.new(hallCenter + Vector3.new(x, roofY, 0)),
			COLORS.SteelLight,
			Enum.Material.Metal,
			false,
			nil
		)
	end

	for z = -27, 27, 18 do
		part(
			hall,
			plotId,
			"RoofPurlin",
			Vector3.new(hallWidth, 0.7, 0.7),
			CFrame.new(hallCenter + Vector3.new(0, roofY + 0.4, z)),
			COLORS.Steel,
			Enum.Material.Metal,
			false,
			nil
		)
	end

	for _, x in { -42, 0, 42 } do
		local roof = part(
			hall,
			plotId,
			"RoofPanel",
			Vector3.new(31, 0.35, hallDepth - 5),
			CFrame.new(hallCenter + Vector3.new(x, roofY + 1, 0)),
			COLORS.SteelDark,
			Enum.Material.Metal,
			false,
			nil
		)
		roof.CanQuery = false
	end

	for _, x in { -21, 21 } do
		local skylight = part(
			hall,
			plotId,
			"Skylight",
			Vector3.new(8, 0.2, hallDepth - 8),
			CFrame.new(hallCenter + Vector3.new(x, roofY + 1.25, 0)),
			Color3.fromRGB(120, 192, 204),
			Enum.Material.Glass,
			false,
			nil
		)
		skylight.Transparency = 0.48
		skylight.CanQuery = false
	end

	for _, x in { -42, 0, 42 } do
		for _, z in { -14, 18 } do
			workLight(
				hall,
				plotId,
				("HallWorkLight_%d_%d"):format(x, z),
				hallCenter + Vector3.new(x, roofY - 1.2, z)
			)
		end
	end

	local dust = model(hall, "DustCollector")
	part(
		dust,
		plotId,
		"CollectorBody",
		Vector3.new(5.5, 11, 5.5),
		CFrame.new(center + Vector3.new(-49, 7, 25)),
		COLORS.Steel,
		Enum.Material.Metal,
		true,
		Enum.PartType.Cylinder
	)
	wedge(
		dust,
		plotId,
		"CollectorCone",
		Vector3.new(5.5, 5, 5.5),
		CFrame.new(center + Vector3.new(-49, 14.4, 25)) * CFrame.Angles(math.rad(180), 0, 0),
		COLORS.SteelLight,
		Enum.Material.Metal,
		false
	)
	part(
		dust,
		plotId,
		"ExhaustStack",
		Vector3.new(2, 13, 2),
		CFrame.new(center + Vector3.new(-49, 21.2, 25)),
		COLORS.SteelDark,
		Enum.Material.Metal,
		false,
		Enum.PartType.Cylinder
	)

	conveyorSegment(
		hall,
		plotId,
		"YardFeedConveyor",
		CFrame.new(center + Vector3.new(-60, 2.2, 25)),
		28,
		6
	)
	conveyorSegment(
		hall,
		plotId,
		"IntakeConveyor",
		CFrame.new(center + Vector3.new(-58, 2.2, 10)) * CFrame.Angles(0, math.rad(90), 0),
		38,
		6
	)
	conveyorSegment(
		hall,
		plotId,
		"ProcessConveyor",
		CFrame.new(center + Vector3.new(-10, 2.2, 10)) * CFrame.Angles(0, math.rad(90), 0),
		30,
		6
	)
	conveyorSegment(
		hall,
		plotId,
		"AssemblyOutfeed",
		CFrame.new(center + Vector3.new(41, 2.2, 10)) * CFrame.Angles(0, math.rad(90), 0),
		36,
		6
	)
	conveyorSegment(
		hall,
		plotId,
		"StorageTurn",
		CFrame.new(center + Vector3.new(59, 2.2, 19)),
		18,
		6
	)
	conveyorSegment(
		hall,
		plotId,
		"StorageFeed",
		CFrame.new(center + Vector3.new(66, 2.2, 28)) * CFrame.Angles(0, math.rad(90), 0),
		14,
		6
	)

	for x = -58, 58, 12 do
		safetyStripe(
			hall,
			plotId,
			("SafetyStripe_%d"):format(x),
			Vector3.new(0.35, 0.07, 56),
			hallCenter + Vector3.new(x, 0.74, 0)
		)
	end

	local hallSign = part(
		hall,
		plotId,
		"HallSign",
		Vector3.new(28, 4.5, 0.8),
		CFrame.new(hallCenter + Vector3.new(0, 11, -34.6)),
		COLORS.SteelDark,
		Enum.Material.Metal,
		false,
		nil
	)
	addSurfaceSign(hallSign, "PROCESSING  •  ASSEMBLY", Enum.NormalId.Front)
end

local function buildWorkerBay(root: Model, plotId: number, center: Vector3)
	local bay = model(root, "WorkerChargingBay")
	local bayCenter = center + WorldLayout.Environment.WorkerBayCenterOffset

	floorPlate(
		bay,
		plotId,
		"ChargingFloor",
		Vector3.new(52, 0.14, 54),
		bayCenter + Vector3.new(0, 0.61, 0),
		Color3.fromRGB(58, 63, 68),
		Enum.Material.DiamondPlate
	)

	for _, x in { -24, 24 } do
		for _, z in { -24, 24 } do
			part(
				bay,
				plotId,
				"CanopyPost",
				Vector3.new(1, 10, 1),
				CFrame.new(bayCenter + Vector3.new(x, 5.5, z)),
				COLORS.SteelDark,
				Enum.Material.Metal,
				true,
				nil
			)
		end
	end

	part(
		bay,
		plotId,
		"CanopyBeam",
		Vector3.new(50, 0.9, 0.9),
		CFrame.new(bayCenter + Vector3.new(0, 10, -24)),
		COLORS.Steel,
		Enum.Material.Metal,
		false,
		nil
	)
	part(
		bay,
		plotId,
		"CanopyBeam",
		Vector3.new(50, 0.9, 0.9),
		CFrame.new(bayCenter + Vector3.new(0, 10, 24)),
		COLORS.Steel,
		Enum.Material.Metal,
		false,
		nil
	)

	for row = 0, 2 do
		for column = 0, 1 do
			local chargerCenter = center
				+ WorldLayout.Production.WorkPadOriginOffset
				+ Vector3.new(
					column * WorldLayout.Production.WorkPadColumnSpacing,
					0,
					row * WorldLayout.Production.WorkPadRowSpacing
				)
				+ Vector3.new(0, 2.7, 4.6)
			part(
				bay,
				plotId,
				"ChargePylon",
				Vector3.new(2.4, 5, 1.8),
				CFrame.new(chargerCenter),
				COLORS.Steel,
				Enum.Material.Metal,
				false,
				nil
			)
			part(
				bay,
				plotId,
				"ChargeLight",
				Vector3.new(1.5, 1.2, 0.18),
				CFrame.new(chargerCenter + Vector3.new(0, 0.6, -1)),
				COLORS.Cyan,
				Enum.Material.Neon,
				false,
				nil
			)
		end
	end

	local sign = part(
		bay,
		plotId,
		"WorkerBaySign",
		Vector3.new(20, 3.5, 0.7),
		CFrame.new(bayCenter + Vector3.new(0, 8, -25)),
		COLORS.SteelDark,
		Enum.Material.Metal,
		false,
		nil
	)
	addSurfaceSign(sign, "ROBOT CHARGING BAY", Enum.NormalId.Front)
end

local function buildLoadingDock(root: Model, plotId: number, center: Vector3)
	local dock = model(root, "MaterialWarehouse")
	local dockCenter = center + WorldLayout.Environment.LoadingDockCenterOffset

	floorPlate(
		dock,
		plotId,
		"DockApron",
		Vector3.new(58, 0.16, 64),
		dockCenter + Vector3.new(0, 0.61, 0),
		Color3.fromRGB(82, 84, 84),
		Enum.Material.Concrete
	)

	part(
		dock,
		plotId,
		"WarehouseBack",
		Vector3.new(58, 13, 1.3),
		CFrame.new(dockCenter + Vector3.new(0, 7, 26)),
		COLORS.SteelDark,
		Enum.Material.Metal,
		true,
		nil
	)

	for index, x in { -18, 0, 18 } do
		local door = part(
			dock,
			plotId,
			("DockDoor%d"):format(index),
			Vector3.new(13, 8.5, 0.5),
			CFrame.new(dockCenter + Vector3.new(x, 5, 25.2)),
			Color3.fromRGB(56, 61, 66),
			Enum.Material.DiamondPlate,
			false,
			nil
		)
		for y = -3, 3, 1.5 do
			part(
				dock,
				plotId,
				"DoorRib",
				Vector3.new(12.2, 0.14, 0.12),
				door.CFrame * CFrame.new(0, y, -0.33),
				COLORS.SteelLight,
				Enum.Material.Metal,
				false,
				nil
			)
		end
		part(
			dock,
			plotId,
			"DockBumper",
			Vector3.new(14, 1.2, 2),
			CFrame.new(dockCenter + Vector3.new(x, 1.1, 22.8)),
			COLORS.SteelDark,
			Enum.Material.SmoothPlastic,
			true,
			nil
		)
	end

	for x = -23, 23, 11.5 do
		part(
			dock,
			plotId,
			"WarehouseColumn",
			Vector3.new(1.1, 14, 1.1),
			CFrame.new(dockCenter + Vector3.new(x, 7.5, 25)),
			COLORS.Steel,
			Enum.Material.Metal,
			true,
			nil
		)
	end

	for palletIndex, offset in
		{
			Vector3.new(-18, 1.2, -12),
			Vector3.new(4, 1.2, -15),
			Vector3.new(18, 1.2, -7),
		}
	do
		local pallet = model(dock, ("PalletStack%d"):format(palletIndex))
		for level = 0, 2 do
			part(
				pallet,
				plotId,
				"Crate",
				Vector3.new(5.5, 2.3, 4.5),
				CFrame.new(dockCenter + offset + Vector3.new(0, level * 2.35, 0)),
				if level % 2 == 0 then COLORS.Rust else COLORS.Steel,
				Enum.Material.WoodPlanks,
				true,
				nil
			)
		end
	end

	local sign = part(
		dock,
		plotId,
		"WarehouseSign",
		Vector3.new(25, 4, 0.7),
		CFrame.new(dockCenter + Vector3.new(0, 12, 25.8)),
		COLORS.SteelDark,
		Enum.Material.Metal,
		false,
		nil
	)
	addSurfaceSign(sign, "MATERIALS  •  SHIPPING", Enum.NormalId.Back)
end

local function buildUtilities(root: Model, plotId: number, center: Vector3)
	local utilities = model(root, "UtilityYard")
	local utilityCenter = center + WorldLayout.Environment.UtilityYardCenterOffset

	floorPlate(
		utilities,
		plotId,
		"UtilityPad",
		Vector3.new(50, 0.16, 48),
		utilityCenter + Vector3.new(0, 0.61, 0),
		Color3.fromRGB(69, 73, 76),
		Enum.Material.Concrete
	)

	for _, x in { -13, 13 } do
		part(
			utilities,
			plotId,
			"CoolingTank",
			Vector3.new(10, 10, 10),
			CFrame.new(utilityCenter + Vector3.new(x, 5.7, 8)),
			COLORS.Steel,
			Enum.Material.Metal,
			true,
			Enum.PartType.Cylinder
		)
		part(
			utilities,
			plotId,
			"TankBand",
			Vector3.new(10.4, 0.45, 10.4),
			CFrame.new(utilityCenter + Vector3.new(x, 4.2, 8)),
			COLORS.Brass,
			Enum.Material.Metal,
			false,
			Enum.PartType.Cylinder
		)
	end

	local generator = model(utilities, "GeneratorSkid")
	part(
		generator,
		plotId,
		"GeneratorBody",
		Vector3.new(18, 7, 8),
		CFrame.new(utilityCenter + Vector3.new(0, 4.1, -10)),
		COLORS.SteelDark,
		Enum.Material.Metal,
		true,
		nil
	)
	for x = -6, 6, 4 do
		part(
			generator,
			plotId,
			"Vent",
			Vector3.new(2.8, 2.8, 0.22),
			CFrame.new(utilityCenter + Vector3.new(x, 4.7, -14.1)),
			COLORS.SteelLight,
			Enum.Material.Metal,
			false,
			nil
		)
	end
	part(
		generator,
		plotId,
		"GeneratorStatus",
		Vector3.new(8, 0.45, 0.22),
		CFrame.new(utilityCenter + Vector3.new(0, 2.2, -14.2)),
		COLORS.Green,
		Enum.Material.Neon,
		false,
		nil
	)

	for _, x in { -21, 21 } do
		part(
			utilities,
			plotId,
			"PipeRackPost",
			Vector3.new(0.8, 7, 0.8),
			CFrame.new(utilityCenter + Vector3.new(x, 4, 0)),
			COLORS.SteelDark,
			Enum.Material.Metal,
			true,
			nil
		)
	end
	for index, y in { 4.6, 6.2 } do
		part(
			utilities,
			plotId,
			("Pipe%d"):format(index),
			Vector3.new(0.75, 44, 0.75),
			CFrame.new(utilityCenter + Vector3.new(0, y, 0)) * CFrame.Angles(0, 0, math.rad(90)),
			if index == 1 then COLORS.Copper else COLORS.SteelLight,
			Enum.Material.Metal,
			false,
			Enum.PartType.Cylinder
		)
	end

	local sign = part(
		utilities,
		plotId,
		"UtilitySign",
		Vector3.new(16, 3, 0.7),
		CFrame.new(utilityCenter + Vector3.new(0, 8, -23)),
		COLORS.SteelDark,
		Enum.Material.Metal,
		false,
		nil
	)
	addSurfaceSign(sign, "UTILITIES", Enum.NormalId.Front)
end

local function buildCircuitAnnex(root: Model, plotId: number, center: Vector3)
	local annex = model(root, "CircuitAnnex")
	local island = WorldLayout.CircuitIsland
	local islandCenter = center + island.CenterOffset

	floorPlate(
		annex,
		plotId,
		"CircuitDeckOverlay",
		Vector3.new(island.Size.X - 4, 0.16, island.Size.Z - 4),
		islandCenter + Vector3.new(0, 0.61, 0),
		Color3.fromRGB(48, 59, 63),
		Enum.Material.DiamondPlate
	)

	for _, x in { -36, -12, 12, 36 } do
		part(
			annex,
			plotId,
			"CablePylon",
			Vector3.new(1.1, 11, 1.1),
			CFrame.new(islandCenter + Vector3.new(x, 6, 21)),
			COLORS.SteelDark,
			Enum.Material.Metal,
			true,
			nil
		)
		part(
			annex,
			plotId,
			"CableTray",
			Vector3.new(1, 22, 1),
			CFrame.new(islandCenter + Vector3.new(x, 11.2, 10)) * CFrame.Angles(math.rad(90), 0, 0),
			COLORS.Copper,
			Enum.Material.Metal,
			false,
			Enum.PartType.Cylinder
		)
	end

	for index, x in { -26, 0, 26 } do
		local cabinet = model(annex, ("CircuitCabinet%d"):format(index))
		part(
			cabinet,
			plotId,
			"Cabinet",
			Vector3.new(11, 7, 5),
			CFrame.new(islandCenter + Vector3.new(x, 4, -25)),
			COLORS.Steel,
			Enum.Material.Metal,
			true,
			nil
		)
		part(
			cabinet,
			plotId,
			"Status",
			Vector3.new(7, 0.5, 0.2),
			CFrame.new(islandCenter + Vector3.new(x, 5.2, -27.6)),
			COLORS.Cyan,
			Enum.Material.Neon,
			false,
			nil
		)
	end

	local sign = part(
		annex,
		plotId,
		"CircuitAnnexSign",
		Vector3.new(24, 4, 0.7),
		CFrame.new(islandCenter + Vector3.new(0, 8.2, 34)),
		COLORS.SteelDark,
		Enum.Material.Metal,
		false,
		nil
	)
	addSurfaceSign(sign, "CIRCUIT RECOVERY ANNEX", Enum.NormalId.Back)
end

function FactoryEnvironmentBuilder.Build(plot: Model, plotId: number, center: Vector3): Model
	local existing = plot:FindFirstChild("FactoryEnvironment")
	if existing ~= nil then
		assert(existing:IsA("Model"), "FactoryEnvironment must be a Model")
		return existing
	end

	local root = model(plot, "FactoryEnvironment")
	buildEntry(root, plotId, center)
	buildScrapYard(root, plotId, center)
	buildProductionHall(root, plotId, center)
	buildWorkerBay(root, plotId, center)
	buildLoadingDock(root, plotId, center)
	buildUtilities(root, plotId, center)
	buildCircuitAnnex(root, plotId, center)
	return root
end

return table.freeze(FactoryEnvironmentBuilder)
