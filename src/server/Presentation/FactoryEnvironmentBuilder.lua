--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local WorldLayout = require(ReplicatedStorage.Shared.Config.WorldLayout)
local ScrapProcessAssetBuilder = require(script.Parent.ScrapProcessAssetBuilder)

local FactoryEnvironmentBuilder = {}

local COLORS = table.freeze({
	Concrete = Color3.fromRGB(82, 85, 84),
	ConcreteDark = Color3.fromRGB(58, 62, 64),
	ConcreteLight = Color3.fromRGB(112, 115, 113),
	SteelBlack = Color3.fromRGB(28, 32, 36),
	SteelDark = Color3.fromRGB(43, 49, 55),
	Steel = Color3.fromRGB(70, 79, 88),
	SteelLight = Color3.fromRGB(111, 122, 132),
	Rust = Color3.fromRGB(136, 79, 45),
	RustDark = Color3.fromRGB(96, 58, 38),
	Copper = Color3.fromRGB(177, 103, 57),
	Safety = Color3.fromRGB(232, 188, 54),
	Cyan = Color3.fromRGB(72, 214, 229),
	Orange = Color3.fromRGB(225, 132, 56),
	Red = Color3.fromRGB(205, 71, 62),
	Green = Color3.fromRGB(70, 177, 116),
	Window = Color3.fromRGB(126, 181, 193),
})

local function configure(instance: BasePart, plotId: number, collidable: boolean)
	instance.Anchored = true
	instance.CanCollide = collidable
	instance.CanTouch = false
	instance.CanQuery = collidable
	instance.CastShadow = true
	instance.TopSurface = Enum.SurfaceType.Smooth
	instance.BottomSurface = Enum.SurfaceType.Smooth
	instance:SetAttribute("PlotId", plotId)
	instance:SetAttribute("PresentationPart", true)
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
): Part
	local result = part(
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
	result.CastShadow = false
	return result
end

local function addSurfaceSign(adornee: BasePart, text: string, face: Enum.NormalId)
	local surface = Instance.new("SurfaceGui")
	surface.Name = "IndustrialSign"
	surface.Face = face
	surface.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	surface.PixelsPerStud = 30
	surface.LightInfluence = 0
	surface.Parent = adornee

	local label = Instance.new("TextLabel")
	label.BackgroundColor3 = Color3.fromRGB(18, 21, 25)
	label.BackgroundTransparency = 0.05
	label.BorderSizePixel = 0
	label.Font = Enum.Font.GothamBold
	label.Size = UDim2.fromScale(1, 1)
	label.Text = text
	label.TextColor3 = Color3.fromRGB(240, 243, 245)
	label.TextScaled = true
	label.TextWrapped = true
	label.Parent = surface
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

local function workLight(parent: Instance, plotId: number, name: string, position: Vector3)
	local housing = part(
		parent,
		plotId,
		name,
		Vector3.new(5, 0.38, 1.5),
		CFrame.new(position),
		COLORS.SteelBlack,
		Enum.Material.Metal,
		false,
		nil
	)
	local lens = part(
		parent,
		plotId,
		name .. "Lens",
		Vector3.new(4.2, 0.13, 0.95),
		housing.CFrame * CFrame.new(0, -0.27, 0),
		Color3.fromRGB(208, 239, 242),
		Enum.Material.Neon,
		false,
		nil
	)

	local light = Instance.new("PointLight")
	light.Name = "WorkLight"
	light.Brightness = 0.7
	light.Color = Color3.fromRGB(210, 236, 240)
	light.Range = 24
	light.Shadows = false
	light.Parent = lens
end

local function bollard(
	parent: Instance,
	plotId: number,
	name: string,
	position: Vector3,
	color: Color3?
)
	part(
		parent,
		plotId,
		name,
		Vector3.new(0.9, 3.8, 0.9),
		CFrame.new(position),
		color or COLORS.Safety,
		Enum.Material.Metal,
		true,
		Enum.PartType.Cylinder
	)
end

local function guardRail(
	parent: Instance,
	plotId: number,
	name: string,
	startPosition: Vector3,
	length: number,
	alongX: boolean
)
	local rail = model(parent, name)
	local span = if alongX then Vector3.new(length, 0.36, 0.36) else Vector3.new(0.36, 0.36, length)
	local midpoint = startPosition
	for _, y in { 1.4, 2.8 } do
		part(
			rail,
			plotId,
			"Rail",
			span,
			CFrame.new(midpoint + Vector3.new(0, y, 0)),
			COLORS.Safety,
			Enum.Material.Metal,
			true,
			nil
		)
	end

	local half = length / 2
	for _, offset in { -half, 0, half } do
		local postOffset = if alongX
			then Vector3.new(offset, 1.5, 0)
			else Vector3.new(0, 1.5, offset)
		part(
			rail,
			plotId,
			"Post",
			Vector3.new(0.55, 3.1, 0.55),
			CFrame.new(midpoint + postOffset),
			COLORS.SteelDark,
			Enum.Material.Metal,
			true,
			nil
		)
	end
end

local function buildSiteSurface(root: Model, plotId: number, center: Vector3)
	local site = model(root, "FactorySite")

	floorPlate(
		site,
		plotId,
		"PlantApron",
		Vector3.new(228, 0.18, 178),
		center + Vector3.new(0, 0.6, 0),
		Color3.fromRGB(69, 71, 70),
		Enum.Material.Concrete
	)

	floorPlate(
		site,
		plotId,
		"MainServiceRoad",
		Vector3.new(214, 0.12, 22),
		center + Vector3.new(2, 0.71, -68),
		Color3.fromRGB(48, 51, 53),
		Enum.Material.Concrete
	)
	floorPlate(
		site,
		plotId,
		"WestServiceRoad",
		Vector3.new(20, 0.12, 120),
		center + Vector3.new(-108, 0.71, 7),
		Color3.fromRGB(48, 51, 53),
		Enum.Material.Concrete
	)
	floorPlate(
		site,
		plotId,
		"EastServiceRoad",
		Vector3.new(20, 0.12, 120),
		center + Vector3.new(108, 0.71, 7),
		Color3.fromRGB(48, 51, 53),
		Enum.Material.Concrete
	)

	for x = -92, 92, 23 do
		safetyStripe(
			site,
			plotId,
			("RoadDash_%d"):format(x),
			Vector3.new(9, 0.06, 0.28),
			center + Vector3.new(x, 0.79, -68)
		)
	end

	for _, x in { -103, 103 } do
		for z = -44, 44, 22 do
			bollard(
				site,
				plotId,
				("RoadBollard_%d_%d"):format(x, z),
				center + Vector3.new(x, 2.5, z),
				COLORS.SteelLight
			)
		end
	end
end

local function buildEntry(root: Model, plotId: number, center: Vector3)
	local entry = center + WorldLayout.Plot.EntryOffset
	local gate = model(root, "ReceivingGate")

	floorPlate(
		gate,
		plotId,
		"EntryApron",
		Vector3.new(40, 0.18, 30),
		center + Vector3.new(8, 0.74, -78),
		COLORS.ConcreteDark,
		Enum.Material.Concrete
	)

	for _, x in { -11, 27 } do
		part(
			gate,
			plotId,
			"GatePost",
			Vector3.new(1.8, 10, 1.8),
			CFrame.new(center + Vector3.new(x, 5.5, -91)),
			COLORS.SteelBlack,
			Enum.Material.Metal,
			true,
			nil
		)
		part(
			gate,
			plotId,
			"GateBeacon",
			Vector3.new(0.7, 0.7, 0.7),
			CFrame.new(center + Vector3.new(x, 10.7, -91)),
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
		Vector3.new(40, 1.6, 1.7),
		CFrame.new(center + Vector3.new(8, 9.1, -91)),
		COLORS.Steel,
		Enum.Material.Metal,
		false,
		nil
	)
	addSurfaceSign(header, "SCRAP-TO-BOT WORKS  •  RECEIVING", Enum.NormalId.Front)

	local booth = part(
		gate,
		plotId,
		"SecurityBooth",
		Vector3.new(10, 7.5, 9),
		CFrame.new(center + Vector3.new(33, 4.25, -76)),
		COLORS.Steel,
		Enum.Material.Metal,
		true,
		nil
	)
	local boothWindow = part(
		gate,
		plotId,
		"SecurityWindow",
		Vector3.new(7.2, 2.6, 0.2),
		booth.CFrame * CFrame.new(0, 0.7, -4.6),
		COLORS.Window,
		Enum.Material.Glass,
		false,
		nil
	)
	boothWindow.Transparency = 0.35
	boothWindow.CanQuery = false

	local scaleDeck = part(
		gate,
		plotId,
		"TruckWeighbridge",
		Vector3.new(13, 0.4, 25),
		CFrame.new(center + Vector3.new(8, 0.96, -69)),
		COLORS.SteelDark,
		Enum.Material.DiamondPlate,
		true,
		nil
	)
	for _, z in { -9.5, 0, 9.5 } do
		part(
			gate,
			plotId,
			"ScaleSensor",
			Vector3.new(11.5, 0.12, 0.45),
			scaleDeck.CFrame * CFrame.new(0, 0.27, z),
			COLORS.Safety,
			Enum.Material.Metal,
			false,
			nil
		)
	end
	local scaleDisplay = part(
		gate,
		plotId,
		"ScaleDisplay",
		Vector3.new(4.2, 5.5, 1.2),
		CFrame.new(center + Vector3.new(18, 3.45, -63)),
		COLORS.SteelBlack,
		Enum.Material.Metal,
		true,
		nil
	)
	local scaleScreen = part(
		gate,
		plotId,
		"ScaleScreen",
		Vector3.new(3.2, 1.5, 0.16),
		scaleDisplay.CFrame * CFrame.new(0, 0.65, -0.68),
		COLORS.Green,
		Enum.Material.Neon,
		false,
		nil
	)
	addSurfaceSign(scaleScreen, "WEIGH IN", Enum.NormalId.Front)

	for _, x in { 2, 14 } do
		safetyStripe(
			gate,
			plotId,
			("EntryLane_%d"):format(x),
			Vector3.new(0.3, 0.06, 32),
			center + Vector3.new(x, 0.83, -78)
		)
	end

	local spawnPlate = floorPlate(
		gate,
		plotId,
		"SpawnPlate",
		Vector3.new(15, 0.18, 10),
		Vector3.new(entry.X, center.Y + 0.79, entry.Z + 5),
		COLORS.SteelBlack,
		Enum.Material.DiamondPlate
	)
	spawnPlate:SetAttribute("EntryPresentation", true)
end

local function buildScrapGantry(root: Model, plotId: number, center: Vector3)
	local crane = model(root, "ScrapGantryCrane")
	local yardCenter = center + WorldLayout.Environment.ScrapYardCenterOffset
	local xSpan = 50
	local zSpan = 56
	local postHeight = 20

	for _, x in { -xSpan / 2, xSpan / 2 } do
		for _, z in { -zSpan / 2, zSpan / 2 } do
			part(
				crane,
				plotId,
				"CraneLeg",
				Vector3.new(1.8, postHeight, 1.8),
				CFrame.new(yardCenter + Vector3.new(x, postHeight / 2 + 0.6, z)),
				COLORS.SteelBlack,
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
			"EndBeam",
			Vector3.new(xSpan + 4, 1.7, 1.7),
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
		"TravelBridge",
		Vector3.new(2.2, 2.2, zSpan),
		CFrame.new(yardCenter + Vector3.new(-7, postHeight + 0.35, 0)),
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
		Vector3.new(5, 2.2, 4.8),
		CFrame.new(yardCenter + Vector3.new(-7, postHeight - 1.3, 7)),
		COLORS.SteelBlack,
		Enum.Material.Metal,
		false,
		nil
	)
	part(
		crane,
		plotId,
		"HoistCable",
		Vector3.new(0.32, 10, 0.32),
		CFrame.new(yardCenter + Vector3.new(-7, postHeight - 7, 7)),
		Color3.fromRGB(25, 27, 29),
		Enum.Material.Metal,
		false,
		Enum.PartType.Cylinder
	)
	local magnet = part(
		crane,
		plotId,
		"LiftMagnet",
		Vector3.new(1, 7, 7),
		CFrame.new(yardCenter + Vector3.new(-7, postHeight - 12.4, 7))
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
		"ScrapYardFloor",
		Vector3.new(58, 0.2, 70),
		yardCenter + Vector3.new(0, 0.72, 0),
		Color3.fromRGB(77, 74, 67),
		Enum.Material.Concrete
	)

	for _, x in { -28, 28 } do
		for z = -30, 30, 15 do
			part(
				yard,
				plotId,
				"FencePost",
				Vector3.new(0.55, 6, 0.55),
				CFrame.new(yardCenter + Vector3.new(x, 3.6, z)),
				COLORS.Steel,
				Enum.Material.Metal,
				true,
				nil
			)
		end
	end

	for _, z in { -34, 34 } do
		for x = -21, 21, 14 do
			part(
				yard,
				plotId,
				"FencePost",
				Vector3.new(0.55, 6, 0.55),
				CFrame.new(yardCenter + Vector3.new(x, 3.6, z)),
				COLORS.Steel,
				Enum.Material.Metal,
				true,
				nil
			)
		end
	end

	for _, z in { -33, 33 } do
		for _, y in { 2.2, 4.6 } do
			part(
				yard,
				plotId,
				"FenceRail",
				Vector3.new(44, 0.35, 0.35),
				CFrame.new(yardCenter + Vector3.new(-4, y, z)),
				COLORS.SteelLight,
				Enum.Material.Metal,
				true,
				nil
			)
		end
	end

	for _, y in { 2.2, 4.6 } do
		part(
			yard,
			plotId,
			"WestFenceRail",
			Vector3.new(0.35, 0.35, 62),
			CFrame.new(yardCenter + Vector3.new(-28, y, 0)),
			COLORS.SteelLight,
			Enum.Material.Metal,
			true,
			nil
		)
		-- East edge has a 16-stud opening that feeds the plant intake.
		for _, z in { -21, 21 } do
			part(
				yard,
				plotId,
				"EastFenceRail",
				Vector3.new(0.35, 0.35, 26),
				CFrame.new(yardCenter + Vector3.new(28, y, z)),
				COLORS.SteelLight,
				Enum.Material.Metal,
				true,
				nil
			)
		end
	end

	for _, z in { -8, 8 } do
		bollard(
			yard,
			plotId,
			"YardGateBollard",
			yardCenter + Vector3.new(28, 2.5, z),
			COLORS.Safety
		)
	end

	buildScrapGantry(root, plotId, center)

	local sign = part(
		yard,
		plotId,
		"ScrapReceivingSign",
		Vector3.new(24, 4, 0.8),
		CFrame.new(yardCenter + Vector3.new(0, 8, -37)),
		COLORS.SteelBlack,
		Enum.Material.Metal,
		false,
		nil
	)
	addSurfaceSign(sign, "SCRAP RECEIVING  •  SORTING", Enum.NormalId.Front)
end

local function buildHallShell(root: Model, plotId: number, center: Vector3)
	local hall = model(root, "ProductionHall")
	local hallCenter = center + WorldLayout.Environment.ProductionHallCenterOffset
	local width = 160
	local depth = 104
	local wallHeight = 17
	local roofY = 22

	floorPlate(
		hall,
		plotId,
		"FactoryFloor",
		Vector3.new(width, 0.22, depth),
		hallCenter + Vector3.new(0, 0.73, 0),
		Color3.fromRGB(62, 67, 69),
		Enum.Material.Concrete
	)

	-- Back wall and clerestory.
	part(
		hall,
		plotId,
		"NorthWall",
		Vector3.new(width, wallHeight, 1.4),
		CFrame.new(hallCenter + Vector3.new(0, wallHeight / 2 + 0.6, depth / 2)),
		COLORS.SteelDark,
		Enum.Material.Metal,
		true,
		nil
	)
	for x = -74, 74, 18.5 do
		local window = part(
			hall,
			plotId,
			"ClerestoryWindow",
			Vector3.new(13, 3.6, 0.18),
			CFrame.new(hallCenter + Vector3.new(x, 12.4, depth / 2 - 0.8)),
			COLORS.Window,
			Enum.Material.Glass,
			false,
			nil
		)
		window.Transparency = 0.35
		window.CanQuery = false
	end

	-- West wall leaves a 20-stud material-transfer opening to the scrap yard.
	for _, z in { -35, 32 } do
		part(
			hall,
			plotId,
			"WestWall",
			Vector3.new(1.4, wallHeight, 43),
			CFrame.new(hallCenter + Vector3.new(-width / 2, wallHeight / 2 + 0.6, z)),
			COLORS.SteelDark,
			Enum.Material.Metal,
			true,
			nil
		)
	end

	-- East wall is broken by three dock doors.
	for _, z in { -43, 43 } do
		part(
			hall,
			plotId,
			"EastWall",
			Vector3.new(1.4, wallHeight, 26),
			CFrame.new(hallCenter + Vector3.new(width / 2, wallHeight / 2 + 0.6, z)),
			COLORS.SteelDark,
			Enum.Material.Metal,
			true,
			nil
		)
	end

	-- Front wall segments keep the plant enclosed while preserving entry and robot-bay openings.
	for _, segment in
		{
			{ x = -64, width = 44 },
			{ x = -8, width = 42 },
			{ x = 54, width = 44 },
		}
	do
		part(
			hall,
			plotId,
			"SouthWall",
			Vector3.new(segment.width, wallHeight, 1.4),
			CFrame.new(hallCenter + Vector3.new(segment.x, wallHeight / 2 + 0.6, -(depth / 2))),
			COLORS.SteelDark,
			Enum.Material.Metal,
			true,
			nil
		)
	end

	-- Structural columns/trusses.
	for x = -72, 72, 24 do
		for _, z in { -(depth / 2 - 2), depth / 2 - 2 } do
			part(
				hall,
				plotId,
				"HallColumn",
				Vector3.new(1.3, 21, 1.3),
				CFrame.new(hallCenter + Vector3.new(x, 11, z)),
				COLORS.SteelBlack,
				Enum.Material.Metal,
				true,
				nil
			)
		end
		part(
			hall,
			plotId,
			"RoofTruss",
			Vector3.new(1.1, 1.1, depth - 4),
			CFrame.new(hallCenter + Vector3.new(x, roofY, 0)),
			COLORS.SteelLight,
			Enum.Material.Metal,
			false,
			nil
		)
	end

	for z = -42, 42, 21 do
		part(
			hall,
			plotId,
			"RoofPurlin",
			Vector3.new(width - 4, 0.65, 0.65),
			CFrame.new(hallCenter + Vector3.new(0, roofY + 0.35, z)),
			COLORS.Steel,
			Enum.Material.Metal,
			false,
			nil
		)
	end

	-- Sawtooth-style partial roof strips leave sightlines into the hall.
	for _, x in { -64, -32, 0, 32, 64 } do
		local roof = part(
			hall,
			plotId,
			"RoofPanel",
			Vector3.new(22, 0.34, depth - 6),
			CFrame.new(hallCenter + Vector3.new(x, roofY + 1, 0)),
			COLORS.SteelBlack,
			Enum.Material.Metal,
			false,
			nil
		)
		roof.CanQuery = false
	end
	for _, x in { -48, -16, 16, 48 } do
		local skylight = part(
			hall,
			plotId,
			"RoofSkylight",
			Vector3.new(8, 0.18, depth - 10),
			CFrame.new(hallCenter + Vector3.new(x, roofY + 1.25, 0)),
			COLORS.Window,
			Enum.Material.Glass,
			false,
			nil
		)
		skylight.Transparency = 0.42
		skylight.CanQuery = false
	end

	for _, x in { -52, -18, 18, 52 } do
		for _, z in { -25, 20 } do
			workLight(
				hall,
				plotId,
				("HallLight_%d_%d"):format(x, z),
				hallCenter + Vector3.new(x, roofY - 1.4, z)
			)
		end
	end

	local sign = part(
		hall,
		plotId,
		"PlantSign",
		Vector3.new(38, 5, 0.8),
		CFrame.new(hallCenter + Vector3.new(-5, 12.5, -(depth / 2 + 0.8))),
		COLORS.SteelBlack,
		Enum.Material.Metal,
		false,
		nil
	)
	addSurfaceSign(sign, "PROCESSING  •  ROBOT ASSEMBLY", Enum.NormalId.Front)
end

local function buildMezzanine(root: Model, plotId: number, center: Vector3)
	local mezz = model(root, "ServiceMezzanine")
	local deckCenter = center + Vector3.new(8, 10.5, 58)

	part(
		mezz,
		plotId,
		"MezzanineDeck",
		Vector3.new(78, 0.75, 10),
		CFrame.new(deckCenter),
		COLORS.SteelDark,
		Enum.Material.DiamondPlate,
		true,
		nil
	)
	for _, x in { -36, -18, 0, 18, 36 } do
		part(
			mezz,
			plotId,
			"MezzaninePost",
			Vector3.new(1, 10, 1),
			CFrame.new(deckCenter + Vector3.new(x, -5.2, 0)),
			COLORS.SteelBlack,
			Enum.Material.Metal,
			true,
			nil
		)
	end
	guardRail(mezz, plotId, "MezzanineRail", deckCenter + Vector3.new(0, 0.3, -4.6), 88, true)

	-- Compact industrial stair.
	for step = 0, 8 do
		part(
			mezz,
			plotId,
			("Stair%d"):format(step),
			Vector3.new(7, 0.55, 2.2),
			CFrame.new(center + Vector3.new(57, 1.25 + step * 1.05, 43 + step * 1.2)),
			COLORS.SteelDark,
			Enum.Material.DiamondPlate,
			true,
			nil
		)
	end
end

local function buildWorkerBay(root: Model, plotId: number, center: Vector3)
	local bay = model(root, "WorkerChargingBay")
	local bayCenter = center + WorldLayout.Environment.WorkerBayCenterOffset

	floorPlate(
		bay,
		plotId,
		"WorkerBayFloor",
		Vector3.new(50, 0.14, 42),
		bayCenter + Vector3.new(0, 0.78, 0),
		Color3.fromRGB(51, 57, 61),
		Enum.Material.DiamondPlate
	)

	for _, x in { -23, 23 } do
		for _, z in { -19, 19 } do
			part(
				bay,
				plotId,
				"BayPost",
				Vector3.new(0.9, 11, 0.9),
				CFrame.new(bayCenter + Vector3.new(x, 6, z)),
				COLORS.SteelBlack,
				Enum.Material.Metal,
				true,
				nil
			)
		end
	end
	part(
		bay,
		plotId,
		"BayHeader",
		Vector3.new(48, 1, 1),
		CFrame.new(bayCenter + Vector3.new(0, 10.5, -19)),
		COLORS.Steel,
		Enum.Material.Metal,
		false,
		nil
	)

	for row = 0, 2 do
		for column = 0, 1 do
			local pad = center
				+ WorldLayout.Production.WorkPadOriginOffset
				+ Vector3.new(
					column * WorldLayout.Production.WorkPadColumnSpacing,
					0,
					row * WorldLayout.Production.WorkPadRowSpacing
				)
			part(
				bay,
				plotId,
				"ChargePylon",
				Vector3.new(2.3, 5.2, 1.8),
				CFrame.new(pad + Vector3.new(0, 2.8, 4.8)),
				COLORS.Steel,
				Enum.Material.Metal,
				false,
				nil
			)
			part(
				bay,
				plotId,
				"ChargeIndicator",
				Vector3.new(1.5, 1.1, 0.16),
				CFrame.new(pad + Vector3.new(0, 3.5, 3.85)),
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
		Vector3.new(22, 3.4, 0.7),
		CFrame.new(bayCenter + Vector3.new(0, 8.2, -20)),
		COLORS.SteelBlack,
		Enum.Material.Metal,
		false,
		nil
	)
	addSurfaceSign(sign, "ROBOT SERVICE BAY", Enum.NormalId.Front)
end

local function buildLoadingDock(root: Model, plotId: number, center: Vector3)
	local dock = model(root, "MaterialWarehouse")
	local dockCenter = center + WorldLayout.Environment.LoadingDockCenterOffset

	floorPlate(
		dock,
		plotId,
		"DockApron",
		Vector3.new(34, 0.18, 78),
		dockCenter + Vector3.new(0, 0.76, 0),
		Color3.fromRGB(60, 63, 64),
		Enum.Material.Concrete
	)

	part(
		dock,
		plotId,
		"WarehouseWall",
		Vector3.new(1.4, 17, 78),
		CFrame.new(dockCenter + Vector3.new(-11, 9, 0)),
		COLORS.SteelDark,
		Enum.Material.Metal,
		true,
		nil
	)

	for index, z in { -27, 0, 27 } do
		local door = part(
			dock,
			plotId,
			("DockDoor%d"):format(index),
			Vector3.new(0.45, 10, 16),
			CFrame.new(dockCenter + Vector3.new(-11.8, 5.6, z)),
			Color3.fromRGB(50, 55, 59),
			Enum.Material.DiamondPlate,
			false,
			nil
		)
		for y = -4, 4, 1.6 do
			part(
				dock,
				plotId,
				"DoorRib",
				Vector3.new(0.15, 0.14, 15.2),
				door.CFrame * CFrame.new(-0.3, y, 0),
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
			Vector3.new(2, 1.3, 17),
			CFrame.new(dockCenter + Vector3.new(-9.8, 1.2, z)),
			COLORS.SteelBlack,
			Enum.Material.SmoothPlastic,
			true,
			nil
		)
	end

	for palletIndex, offset in
		{
			Vector3.new(6, 1.2, -29),
			Vector3.new(9, 1.2, -6),
			Vector3.new(7, 1.2, 20),
		}
	do
		local pallet = model(dock, ("PalletStack%d"):format(palletIndex))
		for level = 0, 2 do
			part(
				pallet,
				plotId,
				"Crate",
				Vector3.new(5.8, 2.3, 5),
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
		"ShippingSign",
		Vector3.new(4, 24, 0.7),
		CFrame.new(dockCenter + Vector3.new(-12, 13, 0)) * CFrame.Angles(0, math.rad(90), 0),
		COLORS.SteelBlack,
		Enum.Material.Metal,
		false,
		nil
	)
	addSurfaceSign(sign, "SHIPPING", Enum.NormalId.Front)
end

local function buildUtilities(root: Model, plotId: number, center: Vector3)
	local utilities = model(root, "UtilityYard")
	local utilityCenter = center + WorldLayout.Environment.UtilityYardCenterOffset

	floorPlate(
		utilities,
		plotId,
		"UtilityPad",
		Vector3.new(64, 0.18, 32),
		utilityCenter + Vector3.new(0, 0.75, 0),
		Color3.fromRGB(57, 61, 63),
		Enum.Material.Concrete
	)

	for _, x in { -18, 0, 18 } do
		part(
			utilities,
			plotId,
			"CoolingTank",
			Vector3.new(11, 11, 11),
			CFrame.new(utilityCenter + Vector3.new(x, 6.2, 7)),
			COLORS.Steel,
			Enum.Material.Metal,
			true,
			Enum.PartType.Cylinder
		)
		part(
			utilities,
			plotId,
			"TankBand",
			Vector3.new(11.4, 0.5, 11.4),
			CFrame.new(utilityCenter + Vector3.new(x, 5, 7)),
			COLORS.Copper,
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
		Vector3.new(26, 8, 10),
		CFrame.new(utilityCenter + Vector3.new(0, 4.7, -10)),
		COLORS.SteelBlack,
		Enum.Material.Metal,
		true,
		nil
	)
	for x = -9, 9, 6 do
		part(
			generator,
			plotId,
			"Vent",
			Vector3.new(4, 3.2, 0.22),
			CFrame.new(utilityCenter + Vector3.new(x, 5.2, -15.1)),
			COLORS.SteelLight,
			Enum.Material.Metal,
			false,
			nil
		)
	end

	for _, x in { -30, 30 } do
		part(
			utilities,
			plotId,
			"PipeRackPost",
			Vector3.new(0.8, 9, 0.8),
			CFrame.new(utilityCenter + Vector3.new(x, 5, 0)),
			COLORS.SteelBlack,
			Enum.Material.Metal,
			true,
			nil
		)
	end
	for index, y in { 5.8, 7.6 } do
		part(
			utilities,
			plotId,
			("UtilityPipe%d"):format(index),
			Vector3.new(0.8, 60, 0.8),
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
		"UtilitiesSign",
		Vector3.new(18, 3.4, 0.7),
		CFrame.new(utilityCenter + Vector3.new(0, 8.4, -20)),
		COLORS.SteelBlack,
		Enum.Material.Metal,
		false,
		nil
	)
	addSurfaceSign(sign, "PLANT UTILITIES", Enum.NormalId.Front)
end

local function buildCircuitApproach(root: Model, plotId: number, center: Vector3)
	local approach = model(root, "CircuitBridgeApproach")
	local bridge = WorldLayout.CircuitIsland

	floorPlate(
		approach,
		plotId,
		"BridgeThreshold",
		Vector3.new(28, 0.18, 16),
		center + Vector3.new(bridge.BoundaryOpeningCenterX, 0.78, -87),
		COLORS.SteelDark,
		Enum.Material.DiamondPlate
	)

	for _, x in { -12, 12 } do
		bollard(
			approach,
			plotId,
			"BridgeBollard",
			center + Vector3.new(bridge.BoundaryOpeningCenterX + x, 2.5, -89),
			COLORS.Safety
		)
	end

	for _, x in { -8, 8 } do
		safetyStripe(
			approach,
			plotId,
			"BridgeHazardStripe",
			Vector3.new(2.8, 0.07, 13),
			center + Vector3.new(bridge.BoundaryOpeningCenterX + x, 0.9, -87)
		)
	end

	local sign = part(
		approach,
		plotId,
		"CircuitAccessSign",
		Vector3.new(22, 3.5, 0.7),
		CFrame.new(center + Vector3.new(bridge.BoundaryOpeningCenterX, 7.5, -93)),
		COLORS.SteelBlack,
		Enum.Material.Metal,
		false,
		nil
	)
	addSurfaceSign(sign, "CIRCUIT YARD ACCESS", Enum.NormalId.Front)
end

local function buildCircuitAnnex(root: Model, plotId: number, center: Vector3)
	local annex = model(root, "CircuitAnnex")
	local island = WorldLayout.CircuitIsland
	local islandCenter = center + island.CenterOffset

	floorPlate(
		annex,
		plotId,
		"CircuitDeckOverlay",
		Vector3.new(island.Size.X - 4, 0.18, island.Size.Z - 4),
		islandCenter + Vector3.new(0, 0.76, 0),
		Color3.fromRGB(46, 56, 60),
		Enum.Material.DiamondPlate
	)

	for _, x in { -36, -12, 12, 36 } do
		part(
			annex,
			plotId,
			"CablePylon",
			Vector3.new(1.1, 12, 1.1),
			CFrame.new(islandCenter + Vector3.new(x, 6.6, 22)),
			COLORS.SteelBlack,
			Enum.Material.Metal,
			true,
			nil
		)
		part(
			annex,
			plotId,
			"CableTray",
			Vector3.new(1, 24, 1),
			CFrame.new(islandCenter + Vector3.new(x, 12.4, 10)) * CFrame.Angles(math.rad(90), 0, 0),
			COLORS.Copper,
			Enum.Material.Metal,
			false,
			Enum.PartType.Cylinder
		)
	end

	for index, x in { -27, 0, 27 } do
		local cabinet = model(annex, ("RecoveryCabinet%d"):format(index))
		part(
			cabinet,
			plotId,
			"Cabinet",
			Vector3.new(12, 7.5, 5.5),
			CFrame.new(islandCenter + Vector3.new(x, 4.3, -25)),
			COLORS.Steel,
			Enum.Material.Metal,
			true,
			nil
		)
		part(
			cabinet,
			plotId,
			"Status",
			Vector3.new(7.5, 0.5, 0.2),
			CFrame.new(islandCenter + Vector3.new(x, 5.4, -27.85)),
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
		Vector3.new(28, 4.3, 0.7),
		CFrame.new(islandCenter + Vector3.new(0, 8.6, 35)),
		COLORS.SteelBlack,
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
	buildSiteSurface(root, plotId, center)
	buildEntry(root, plotId, center)
	buildScrapYard(root, plotId, center)
	buildHallShell(root, plotId, center)
	ScrapProcessAssetBuilder.Build(root, plotId, center)
	buildMezzanine(root, plotId, center)
	buildWorkerBay(root, plotId, center)
	buildLoadingDock(root, plotId, center)
	buildUtilities(root, plotId, center)
	buildCircuitApproach(root, plotId, center)
	buildCircuitAnnex(root, plotId, center)
	return root
end

return table.freeze(FactoryEnvironmentBuilder)
