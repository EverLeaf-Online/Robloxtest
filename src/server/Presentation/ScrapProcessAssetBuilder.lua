--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local WorldLayout = require(ReplicatedStorage.Shared.Config.WorldLayout)
local FactoryAssetLibrary = require(script.Parent.FactoryAssetLibrary)

local ScrapProcessAssetBuilder = {}

local COLORS = table.freeze({
	Black = Color3.fromRGB(27, 31, 35),
	Dark = Color3.fromRGB(44, 50, 56),
	Steel = Color3.fromRGB(78, 87, 96),
	LightSteel = Color3.fromRGB(116, 126, 135),
	Rust = Color3.fromRGB(139, 80, 46),
	DarkRust = Color3.fromRGB(91, 54, 37),
	Copper = Color3.fromRGB(180, 105, 59),
	Safety = Color3.fromRGB(232, 188, 54),
	Red = Color3.fromRGB(197, 70, 60),
	Cyan = Color3.fromRGB(72, 213, 229),
	Green = Color3.fromRGB(74, 181, 121),
})

local function configure(instance: BasePart, plotId: number, collidable: boolean)
	instance.Anchored = true
	instance.CanCollide = collidable
	instance.CanTouch = false
	instance.CanQuery = collidable
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

local function wedge(
	parent: Instance,
	plotId: number,
	name: string,
	size: Vector3,
	cframe: CFrame,
	color: Color3,
	collidable: boolean?
): WedgePart
	local result = Instance.new("WedgePart")
	result.Name = name
	result.Size = size
	result.CFrame = cframe
	result.Color = color
	result.Material = Enum.Material.Metal
	configure(result, plotId, collidable == true)
	result.Parent = parent
	return result
end

local function model(parent: Instance, name: string): Model
	local result = Instance.new("Model")
	result.Name = name
	result:SetAttribute("FactoryProcessAsset", true)
	result.Parent = parent
	return result
end

local function addSign(adornee: BasePart, text: string, face: Enum.NormalId)
	local gui = Instance.new("SurfaceGui")
	gui.Name = "MachineSign"
	gui.Face = face
	gui.PixelsPerStud = 28
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.LightInfluence = 0
	gui.Parent = adornee

	local label = Instance.new("TextLabel")
	label.BackgroundColor3 = Color3.fromRGB(20, 23, 27)
	label.BackgroundTransparency = 0.04
	label.BorderSizePixel = 0
	label.Font = Enum.Font.GothamBold
	label.Size = UDim2.fromScale(1, 1)
	label.Text = text
	label.TextColor3 = Color3.fromRGB(239, 242, 244)
	label.TextScaled = true
	label.Parent = gui
end

local function conveyor(
	parent: Instance,
	plotId: number,
	name: string,
	cframe: CFrame,
	length: number,
	width: number,
	height: number
): Model
	local result = model(parent, name)
	local assetKey = if name == "FinishedRobotOutfeed" then "OutfeedConveyor" else "InfeedConveyor"
	local imported = FactoryAssetLibrary.TryPlace(
		assetKey,
		result,
		cframe * CFrame.Angles(0, math.rad(90), 0),
		plotId,
		length
	)
	if imported ~= nil then
		imported.Name = name .. "Visual"
		local collision = part(
			result,
			plotId,
			name .. "Collision",
			Vector3.new(width, 0.8, length),
			cframe * CFrame.new(0, height, 0),
			COLORS.Black,
			Enum.Material.SmoothPlastic,
			true,
			nil
		)
		collision.Transparency = 1
		collision.CastShadow = false
		return result
	end
	part(
		result,
		plotId,
		"Bed",
		Vector3.new(width, 0.8, length),
		cframe * CFrame.new(0, height, 0),
		COLORS.Black,
		Enum.Material.Metal,
		true,
		nil
	)
	for _, x in { -(width / 2 - 0.32), width / 2 - 0.32 } do
		part(
			result,
			plotId,
			"Guard",
			Vector3.new(0.32, 1.5, length),
			cframe * CFrame.new(x, height + 0.9, 0),
			COLORS.LightSteel,
			Enum.Material.Metal,
			true,
			nil
		)
	end
	for z = -(length / 2 - 1), length / 2 - 1, 2.5 do
		part(
			result,
			plotId,
			"Roller",
			Vector3.new(0.4, width - 1, width - 1),
			cframe * CFrame.new(0, height + 0.55, z) * CFrame.Angles(0, 0, math.rad(90)),
			COLORS.Steel,
			Enum.Material.Metal,
			false,
			Enum.PartType.Cylinder
		)
	end
	return result
end

local function buildScrapStockpiles(root: Model, plotId: number, center: Vector3)
	local yard = model(root, "ScrapStockpiles")
	local yardCenter = center + WorldLayout.Environment.ScrapYardCenterOffset
	local piles = {
		Vector3.new(-15, 0, -20),
		Vector3.new(6, 0, -18),
		Vector3.new(-13, 0, 15),
		Vector3.new(9, 0, 17),
	}

	for pileIndex, pileOffset in piles do
		local pile = model(yard, ("Pile%d"):format(pileIndex))
		local targetSize = 10 + ((pileIndex * 3) % 4)
		local position = yardCenter + pileOffset + Vector3.new(0, 0.84, 0)
		local yaw = math.rad((pileIndex * 47) % 180)
		local imported = FactoryAssetLibrary.TryPlace(
			"ScrapPileMedium",
			pile,
			CFrame.new(position) * CFrame.Angles(0, yaw, 0),
			plotId,
			targetSize
		)
		if imported ~= nil then
			imported.Name = "ScrapPileVisual"
			local collision = part(
				pile,
				plotId,
				"ScrapPileCollision",
				Vector3.new(targetSize * 0.78, 3.6, targetSize * 0.86),
				CFrame.new(position + Vector3.new(0, 1.8, 0)) * CFrame.Angles(0, yaw, 0),
				COLORS.Rust,
				Enum.Material.SmoothPlastic,
				true,
				nil
			)
			collision.Transparency = 1
			collision.CastShadow = false
			continue
		end

		for itemIndex = 1, 11 do
			local x = ((itemIndex * 17 + pileIndex * 7) % 13) - 6
			local z = ((itemIndex * 11 + pileIndex * 5) % 11) - 5
			local y = 0.6 + ((itemIndex * 3) % 5) * 0.48
			local angle = math.rad((itemIndex * 37 + pileIndex * 23) % 180)
			local size: Vector3
			local color: Color3
			if itemIndex % 3 == 0 then
				size = Vector3.new(0.7, 5.5, 0.7)
				color = COLORS.DarkRust
			elseif itemIndex % 3 == 1 then
				size = Vector3.new(4.6, 0.45, 2.2)
				color = COLORS.Rust
			else
				size = Vector3.new(3.4, 0.55, 1.2)
				color = COLORS.Steel
			end
			part(
				pile,
				plotId,
				("Scrap%d"):format(itemIndex),
				size,
				CFrame.new(yardCenter + pileOffset + Vector3.new(x, y, z))
					* CFrame.Angles(angle * 0.35, angle, angle * 0.2),
				color,
				Enum.Material.CorrodedMetal,
				true,
				nil
			)
		end
	end
end

local function buildShredderFeed(root: Model, plotId: number, center: Vector3)
	local shredder = model(root, "PrimaryShredderFeed")
	local base = center + Vector3.new(-60, 0, 20)

	conveyor(
		shredder,
		plotId,
		"InfeedConveyor",
		CFrame.new(base + Vector3.new(-8, 0, 0)) * CFrame.Angles(0, math.rad(90), 0),
		24,
		8,
		2
	)

	local importedShredder =
		FactoryAssetLibrary.TryPlace("IndustrialScrapShredder", shredder, CFrame.new(base), plotId)
	if importedShredder ~= nil then
		local collision = part(
			shredder,
			plotId,
			"ShredderCollision",
			Vector3.new(15.5, 8, 11.5),
			CFrame.new(base + Vector3.new(0, 4, 0)),
			COLORS.Black,
			Enum.Material.SmoothPlastic,
			true,
			nil
		)
		collision.Transparency = 1
		collision.CastShadow = false

		local header = part(
			shredder,
			plotId,
			"ShredderHeader",
			Vector3.new(12, 1.4, 0.8),
			CFrame.new(base + Vector3.new(0, 9.6, -5.7)),
			COLORS.Black,
			Enum.Material.Metal,
			false,
			nil
		)
		addSign(header, "PRIMARY SHREDDER", Enum.NormalId.Front)
		return
	end

	for _, side in { -1, 1 } do
		wedge(
			shredder,
			plotId,
			"HopperWall",
			Vector3.new(5.5, 6.5, 11),
			CFrame.new(base + Vector3.new(side * 3.8, 6.2, 0))
				* CFrame.Angles(0, if side < 0 then 0 else math.rad(180), 0),
			COLORS.Steel,
			true
		)
	end

	local header = part(
		shredder,
		plotId,
		"ShredderHeader",
		Vector3.new(12, 2.2, 11),
		CFrame.new(base + Vector3.new(0, 9.1, 0)),
		COLORS.Black,
		Enum.Material.Metal,
		true,
		nil
	)
	addSign(header, "PRIMARY SHREDDER", Enum.NormalId.Front)

	for index, z in { -2.2, 2.2 } do
		local rotor = part(
			shredder,
			plotId,
			("Rotor%d"):format(index),
			Vector3.new(7, 2.4, 2.4),
			CFrame.new(base + Vector3.new(0, 3.1, z)),
			COLORS.Dark,
			Enum.Material.Metal,
			false,
			Enum.PartType.Cylinder
		)
		rotor.CFrame *= CFrame.Angles(0, 0, math.rad(90))
		for tooth = 0, 7 do
			local theta = math.rad(tooth * 45)
			part(
				shredder,
				plotId,
				"RotorTooth",
				Vector3.new(0.55, 0.9, 1.25),
				CFrame.new(
					base + Vector3.new(math.cos(theta) * 1.6, 3.1 + math.sin(theta) * 1.6, z)
				) * CFrame.Angles(0, 0, theta),
				COLORS.LightSteel,
				Enum.Material.Metal,
				false,
				nil
			)
		end
	end

	for _, side in { -1, 1 } do
		part(
			shredder,
			plotId,
			"DriveMotor",
			Vector3.new(3, 3, 4.2),
			CFrame.new(base + Vector3.new(side * 7.2, 3.2, 0)),
			COLORS.Copper,
			Enum.Material.Metal,
			true,
			nil
		)
		part(
			shredder,
			plotId,
			"MotorShaft",
			Vector3.new(1, 2.2, 2.2),
			CFrame.new(base + Vector3.new(side * 5.5, 3.2, 0)),
			COLORS.Steel,
			Enum.Material.Metal,
			false,
			Enum.PartType.Cylinder
		)
	end
end

local function buildDustCollection(root: Model, plotId: number, center: Vector3)
	local dust = model(root, "ShredderDustCollection")
	local cycloneBase = center + Vector3.new(-64, 0, 39)

	part(
		dust,
		plotId,
		"CycloneBody",
		Vector3.new(8, 11, 8),
		CFrame.new(cycloneBase + Vector3.new(0, 9, 0)),
		COLORS.Steel,
		Enum.Material.Metal,
		true,
		Enum.PartType.Cylinder
	)
	wedge(
		dust,
		plotId,
		"CycloneCone",
		Vector3.new(8, 7, 8),
		CFrame.new(cycloneBase + Vector3.new(0, 2.7, 0)) * CFrame.Angles(math.rad(180), 0, 0),
		COLORS.LightSteel,
		true
	)
	part(
		dust,
		plotId,
		"ExhaustStack",
		Vector3.new(3, 13, 3),
		CFrame.new(cycloneBase + Vector3.new(0, 20, 0)),
		COLORS.Dark,
		Enum.Material.Metal,
		true,
		Enum.PartType.Cylinder
	)

	local baghouse = part(
		dust,
		plotId,
		"Baghouse",
		Vector3.new(13, 11, 9),
		CFrame.new(cycloneBase + Vector3.new(14, 6, 0)),
		COLORS.Dark,
		Enum.Material.Metal,
		true,
		nil
	)
	for x = -4, 4, 4 do
		part(
			dust,
			plotId,
			"FilterDoor",
			Vector3.new(2.5, 6.5, 0.22),
			baghouse.CFrame * CFrame.new(x, 0, -4.6),
			COLORS.LightSteel,
			Enum.Material.Metal,
			false,
			nil
		)
	end

	part(
		dust,
		plotId,
		"MainDuct",
		Vector3.new(2.4, 24, 2.4),
		CFrame.new(center + Vector3.new(-60, 15, 28)) * CFrame.Angles(math.rad(90), 0, 0),
		COLORS.LightSteel,
		Enum.Material.Metal,
		false,
		Enum.PartType.Cylinder
	)
	part(
		dust,
		plotId,
		"ShredderDropDuct",
		Vector3.new(2.1, 10, 2.1),
		CFrame.new(center + Vector3.new(-60, 11, 20)),
		COLORS.LightSteel,
		Enum.Material.Metal,
		false,
		Enum.PartType.Cylinder
	)
end

local function buildOverbandMagnet(root: Model, plotId: number, center: Vector3)
	local magnet = model(root, "OverbandMagnetSeparator")
	local base = center + Vector3.new(-27, 0, 20)

	local importedMagnet =
		FactoryAssetLibrary.TryPlace("MagneticSortingConveyor", magnet, CFrame.new(base), plotId)
	if importedMagnet ~= nil then
		importedMagnet.Name = "MagneticSortingConveyor"

		local collision = part(
			magnet,
			plotId,
			"MagneticSorterCollision",
			Vector3.new(24, 4, 8.5),
			CFrame.new(base + Vector3.new(0, 2, 0)),
			COLORS.Black,
			Enum.Material.SmoothPlastic,
			true,
			nil
		)
		collision.Transparency = 1
		collision.CastShadow = false

		local sign = part(
			magnet,
			plotId,
			"MagnetSign",
			Vector3.new(9, 1.8, 0.45),
			CFrame.new(base + Vector3.new(0, 10.8, -4.6)),
			COLORS.Black,
			Enum.Material.Metal,
			false,
			nil
		)
		addSign(sign, "FERROUS MAGNET", Enum.NormalId.Front)
		return
	end

	conveyor(
		magnet,
		plotId,
		"FeedBelt",
		CFrame.new(base) * CFrame.Angles(0, math.rad(90), 0),
		24,
		7,
		2
	)

	for _, x in { -5.2, 5.2 } do
		for _, z in { -8, 8 } do
			part(
				magnet,
				plotId,
				"SupportLeg",
				Vector3.new(0.9, 9, 0.9),
				CFrame.new(base + Vector3.new(x, 5.2, z)),
				COLORS.Black,
				Enum.Material.Metal,
				true,
				nil
			)
		end
	end
	part(
		magnet,
		plotId,
		"MagnetHousing",
		Vector3.new(9, 2.4, 16),
		CFrame.new(base + Vector3.new(0, 9.2, 0)) * CFrame.Angles(math.rad(-8), 0, 0),
		COLORS.Safety,
		Enum.Material.Metal,
		false,
		nil
	)
	part(
		magnet,
		plotId,
		"MagnetCore",
		Vector3.new(6.8, 1.4, 11.5),
		CFrame.new(base + Vector3.new(0, 7.9, 0)),
		COLORS.Dark,
		Enum.Material.Metal,
		false,
		nil
	)
	local sign = part(
		magnet,
		plotId,
		"MagnetSign",
		Vector3.new(8, 1.8, 0.5),
		CFrame.new(base + Vector3.new(0, 10.7, -8.3)),
		COLORS.Black,
		Enum.Material.Metal,
		false,
		nil
	)
	addSign(sign, "FERROUS MAGNET", Enum.NormalId.Front)
end

local function buildMagneticDrum(root: Model, plotId: number, center: Vector3)
	local separator = model(root, "MagneticDrumSeparator")
	local base = center + Vector3.new(-6, 0, 20)

	conveyor(
		separator,
		plotId,
		"DrumFeed",
		CFrame.new(base) * CFrame.Angles(0, math.rad(90), 0),
		19,
		7,
		2
	)

	for _, x in { -4.8, 4.8 } do
		part(
			separator,
			plotId,
			"FramePost",
			Vector3.new(0.9, 7.5, 0.9),
			CFrame.new(base + Vector3.new(x, 4.4, 1)),
			COLORS.Black,
			Enum.Material.Metal,
			true,
			nil
		)
	end

	local drum = part(
		separator,
		plotId,
		"MagneticDrum",
		Vector3.new(1.4, 6.8, 6.8),
		CFrame.new(base + Vector3.new(0, 5.8, 5.2)) * CFrame.Angles(0, 0, math.rad(90)),
		COLORS.LightSteel,
		Enum.Material.Metal,
		false,
		Enum.PartType.Cylinder
	)
	drum:SetAttribute("ProcessDrum", true)

	wedge(
		separator,
		plotId,
		"FerrousChute",
		Vector3.new(5.5, 4.5, 6),
		CFrame.new(base + Vector3.new(-5.6, 3.2, 8.1)) * CFrame.Angles(0, math.rad(90), 0),
		COLORS.Rust,
		true
	)
end

local function buildEddyCurrent(root: Model, plotId: number, center: Vector3)
	local separator = model(root, "EddyCurrentSeparator")
	local base = center + Vector3.new(15, 0, 20)

	conveyor(
		separator,
		plotId,
		"EddyFeed",
		CFrame.new(base) * CFrame.Angles(0, math.rad(90), 0),
		21,
		7,
		2
	)
	part(
		separator,
		plotId,
		"SeparatorHousing",
		Vector3.new(11, 7.2, 10),
		CFrame.new(base + Vector3.new(0, 5.2, 4.7)),
		COLORS.Steel,
		Enum.Material.Metal,
		true,
		nil
	)

	local rotor = part(
		separator,
		plotId,
		"EddyRotor",
		Vector3.new(1.2, 6.8, 6.8),
		CFrame.new(base + Vector3.new(0, 5.3, 7.9)) * CFrame.Angles(0, 0, math.rad(90)),
		COLORS.Copper,
		Enum.Material.Metal,
		false,
		Enum.PartType.Cylinder
	)
	rotor:SetAttribute("ProcessDrum", true)

	for _, x in { -3.2, 0, 3.2 } do
		part(
			separator,
			plotId,
			"ServicePanel",
			Vector3.new(2.4, 3, 0.22),
			CFrame.new(base + Vector3.new(x, 5.1, -0.45)),
			COLORS.Black,
			Enum.Material.DiamondPlate,
			false,
			nil
		)
	end

	local sign = part(
		separator,
		plotId,
		"EddySign",
		Vector3.new(10, 1.7, 0.45),
		CFrame.new(base + Vector3.new(0, 9.2, -0.3)),
		COLORS.Black,
		Enum.Material.Metal,
		false,
		nil
	)
	addSign(sign, "NON-FERROUS SEPARATOR", Enum.NormalId.Front)
end

local function buildAssemblyTransfer(root: Model, plotId: number, center: Vector3)
	local transfer = model(root, "AssemblyTransfer")
	conveyor(
		transfer,
		plotId,
		"SortedMaterialFeed",
		CFrame.new(center + Vector3.new(29, 0, 20)) * CFrame.Angles(0, math.rad(90), 0),
		14,
		7,
		2
	)
	conveyor(
		transfer,
		plotId,
		"FinishedRobotOutfeed",
		CFrame.new(center + Vector3.new(54, 0, 20)) * CFrame.Angles(0, math.rad(90), 0),
		22,
		7,
		2
	)

	for _, x in { 24, 34, 47, 61 } do
		part(
			transfer,
			plotId,
			"SafetyBollard",
			Vector3.new(0.8, 3.4, 0.8),
			CFrame.new(center + Vector3.new(x, 2.2, 13)),
			COLORS.Safety,
			Enum.Material.Metal,
			true,
			Enum.PartType.Cylinder
		)
	end
end

local function buildMaterialBunkers(root: Model, plotId: number, center: Vector3)
	local bunkers = model(root, "SortedMaterialBunkers")
	local specs = {
		{ name = "FerrousBunker", offset = Vector3.new(-5, 0, 47), color = COLORS.Rust },
		{ name = "NonFerrousBunker", offset = Vector3.new(16, 0, 47), color = COLORS.Copper },
		{ name = "ResidueBunker", offset = Vector3.new(37, 0, 47), color = COLORS.Steel },
	}
	for _, spec in specs do
		local bunker = model(bunkers, spec.name)
		local base = center + spec.offset
		local imported =
			FactoryAssetLibrary.TryPlace("MaterialBin", bunker, CFrame.new(base), plotId, 13)
		if imported ~= nil then
			imported.Name = spec.name .. "Visual"
			local collision = part(
				bunker,
				plotId,
				"BunkerCollision",
				Vector3.new(12, 5.5, 10),
				CFrame.new(base + Vector3.new(0, 2.75, 0)),
				spec.color,
				Enum.Material.SmoothPlastic,
				true,
				nil
			)
			collision.Transparency = 1
			collision.CastShadow = false

			local label = part(
				bunker,
				plotId,
				"Label",
				Vector3.new(11, 1.8, 0.4),
				CFrame.new(base + Vector3.new(0, 6.8, 5.4)),
				COLORS.Black,
				Enum.Material.Metal,
				false,
				nil
			)
			addSign(label, string.upper(spec.name:gsub("Bunker", "")), Enum.NormalId.Front)
			continue
		end

		part(
			bunker,
			plotId,
			"Back",
			Vector3.new(17, 7, 0.7),
			CFrame.new(base + Vector3.new(0, 3.8, 7)),
			spec.color,
			Enum.Material.Metal,
			true,
			nil
		)
		for _, x in { -8.1, 8.1 } do
			part(
				bunker,
				plotId,
				"Side",
				Vector3.new(0.7, 7, 14),
				CFrame.new(base + Vector3.new(x, 3.8, 0)),
				spec.color,
				Enum.Material.Metal,
				true,
				nil
			)
		end
		local label = part(
			bunker,
			plotId,
			"Label",
			Vector3.new(12, 2, 0.4),
			CFrame.new(base + Vector3.new(0, 7.8, 7.5)),
			COLORS.Black,
			Enum.Material.Metal,
			false,
			nil
		)
		addSign(label, string.upper(spec.name:gsub("Bunker", "")), Enum.NormalId.Front)
	end
end

local function buildBaler(root: Model, plotId: number, center: Vector3)
	local baler = model(root, "HydraulicBaler")
	local base = center + Vector3.new(55, 0, 44)

	local importedBaler =
		FactoryAssetLibrary.TryPlace("HydraulicScrapBaler", baler, CFrame.new(base), plotId)
	if importedBaler ~= nil then
		importedBaler.Name = "HydraulicScrapBaler"

		local collision = part(
			baler,
			plotId,
			"BalerCollision",
			Vector3.new(15, 8, 9),
			CFrame.new(base + Vector3.new(0, 4, 0)),
			COLORS.Black,
			Enum.Material.SmoothPlastic,
			true,
			nil
		)
		collision.Transparency = 1
		collision.CastShadow = false

		local sign = part(
			baler,
			plotId,
			"BalerSign",
			Vector3.new(11, 1.8, 0.45),
			CFrame.new(base + Vector3.new(0, 9.3, -4.6)),
			COLORS.Black,
			Enum.Material.Metal,
			false,
			nil
		)
		addSign(sign, "SCRAP BALER", Enum.NormalId.Front)
		return
	end

	part(
		baler,
		plotId,
		"PressBody",
		Vector3.new(15, 10, 11),
		CFrame.new(base + Vector3.new(0, 5.5, 0)),
		COLORS.Dark,
		Enum.Material.Metal,
		true,
		nil
	)
	part(
		baler,
		plotId,
		"PressDoor",
		Vector3.new(11, 6.5, 0.5),
		CFrame.new(base + Vector3.new(0, 4.6, -5.7)),
		COLORS.Rust,
		Enum.Material.DiamondPlate,
		false,
		nil
	)
	for _, x in { -5.4, 5.4 } do
		part(
			baler,
			plotId,
			"HydraulicRam",
			Vector3.new(2, 2, 8),
			CFrame.new(base + Vector3.new(x, 11.5, 0)) * CFrame.Angles(math.rad(90), 0, 0),
			COLORS.LightSteel,
			Enum.Material.Metal,
			false,
			Enum.PartType.Cylinder
		)
	end
	local sign = part(
		baler,
		plotId,
		"BalerSign",
		Vector3.new(12, 2, 0.5),
		CFrame.new(base + Vector3.new(0, 10.4, -5.8)),
		COLORS.Black,
		Enum.Material.Metal,
		false,
		nil
	)
	addSign(sign, "SCRAP BALER", Enum.NormalId.Front)
end

function ScrapProcessAssetBuilder.Build(parent: Instance, plotId: number, center: Vector3): Model
	local existing = parent:FindFirstChild("ScrapProcessTrain")
	if existing ~= nil then
		assert(existing:IsA("Model"), "ScrapProcessTrain must be a Model")
		return existing
	end

	local root = model(parent, "ScrapProcessTrain")
	buildScrapStockpiles(root, plotId, center)
	buildShredderFeed(root, plotId, center)
	buildDustCollection(root, plotId, center)
	buildOverbandMagnet(root, plotId, center)
	buildMagneticDrum(root, plotId, center)
	buildEddyCurrent(root, plotId, center)
	buildAssemblyTransfer(root, plotId, center)
	buildMaterialBunkers(root, plotId, center)
	buildBaler(root, plotId, center)
	return root
end

return table.freeze(ScrapProcessAssetBuilder)
