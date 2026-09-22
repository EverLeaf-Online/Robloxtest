--!strict
-- Native, anchored expedition scenery. All positions are relative to the owning plot.
local ExpeditionBuilder = {}
local RUST = Color3.fromRGB(155, 83, 48)
local STEEL = Color3.fromRGB(49, 64, 70)
local GOLD = Color3.fromRGB(243, 182, 65)
local MINT = Color3.fromRGB(85, 231, 174)

local function part(
	parent: Instance,
	name: string,
	size: Vector3,
	position: Vector3,
	color: Color3,
	material: Enum.Material?
): Part
	local result = Instance.new("Part")
	result.Name = name
	result.Size = size
	result.Position = position
	result.Color = color
	result.Material = material or Enum.Material.Metal
	result.Anchored = true
	result.TopSurface = Enum.SurfaceType.Smooth
	result.BottomSurface = Enum.SurfaceType.Smooth
	result.Parent = parent
	return result
end

local function sign(parent: Instance, text: string, position: Vector3, color: Color3)
	local board = part(parent, "Wayfinding", Vector3.new(18, 5, 0.6), position, STEEL)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.CanvasSize = Vector2.new(720, 200)
	gui.Parent = board
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextColor3 = color
	label.TextScaled = true
	label.TextWrapped = true
	label.Font = Enum.Font.GothamBold
	label.Parent = gui
	part(parent, "SignPost", Vector3.new(0.6, 6, 0.6), position - Vector3.new(0, 5, 0), STEEL)
end

function ExpeditionBuilder.Build(plot: Model, plotId: number, center: Vector3, zoneId: number): any
	assert(zoneId == 3 or zoneId == 4, "Unknown expedition")
	local depot = zoneId == 3
	local origin = center + Vector3.new(-420, 0, if depot then -80 else -350)
	local accent = if depot then GOLD else MINT
	local root = Instance.new("Model")
	root.Name = if depot then "RustrailDepot" else "DynamoWorks"
	root:SetAttribute("PlotId", plotId)
	root:SetAttribute("ZoneId", zoneId)
	root:SetAttribute("ArtRevision", "SalvageExpeditions1")
	root.Parent = plot
	part(
		root,
		"Island",
		Vector3.new(176, 8, 176),
		origin + Vector3.new(0, -4, 0),
		if depot then Color3.fromRGB(83, 75, 59) else Color3.fromRGB(46, 67, 64),
		Enum.Material.Slate
	)
	-- Wide, continuous perimeter route and a cross aisle keep every salvage cluster accessible.
	for _, x in { -66, 66 } do
		part(
			root,
			"LoopWalkway",
			Vector3.new(14, 0.3, 144),
			origin + Vector3.new(x, 0.15, 0),
			STEEL,
			Enum.Material.Concrete
		)
	end
	for _, z in { -66, 0, 66 } do
		part(
			root,
			"CrossWalkway",
			Vector3.new(144, 0.3, 14),
			origin + Vector3.new(0, 0.15, z),
			STEEL,
			Enum.Material.Concrete
		)
	end
	for _, x in { -87, 87 } do
		part(root, "SafetyBarrier", Vector3.new(2, 5, 176), origin + Vector3.new(x, 2.5, 0), STEEL)
	end
	for _, z in { -87, 87 } do
		part(root, "SafetyBarrier", Vector3.new(176, 5, 2), origin + Vector3.new(0, 2.5, z), STEEL)
	end
	local names = if depot
		then { "DERAILED FREIGHT", "ENGINE GRAVEYARD", "SIGNAL SHED" }
		else { "COOLING FIELD", "TURBINE RUINS", "CAPACITOR GARDEN" }
	for cluster, x in { -44, 0, 44 } do
		sign(root, names[cluster], origin + Vector3.new(x, 9, -44), accent)
		if depot then
			for _, z in { -32, 32 } do
				for _, railX in { -4, 4 } do
					part(
						root,
						"Track",
						Vector3.new(0.5, 0.5, 36),
						origin + Vector3.new(x + railX, 0.4, z),
						RUST
					)
				end
				local wagon = part(
					root,
					"WreckedFreightCar",
					Vector3.new(14, 8, 24),
					origin + Vector3.new(x, 7, z),
					RUST
				)
				wagon.Orientation = Vector3.new(0, if cluster == 2 then 12 else -8, 0)
				part(
					root,
					"OpenCargoRim",
					Vector3.new(15, 0.8, 25),
					origin + Vector3.new(x, 11, z),
					GOLD
				)
				for _, side in { -6, 6 } do
					for _, axle in { -8, 8 } do
						local wheel = part(
							root,
							"Wheel",
							Vector3.new(2, 4, 4),
							origin + Vector3.new(x + side, 2.5, z + axle),
							STEEL
						)
						wheel.Shape = Enum.PartType.Cylinder
					end
				end
			end
		else
			for _, z in { -30, 30 } do
				part(
					root,
					"GeneratorFoot",
					Vector3.new(20, 2, 20),
					origin + Vector3.new(x, 1, z),
					STEEL
				)
				local tower = part(
					root,
					"Dynamo",
					Vector3.new(20, 12, 12),
					origin + Vector3.new(x, 12, z),
					STEEL
				)
				tower.Shape = Enum.PartType.Cylinder
				tower.Orientation = Vector3.new(0, 0, 90)
				local ring = part(
					root,
					"ChargeRing",
					Vector3.new(1, 13, 13),
					origin + Vector3.new(x, 16, z),
					accent,
					Enum.Material.Neon
				)
				ring.Shape = Enum.PartType.Cylinder
				ring.Orientation = Vector3.new(0, 0, 90)
				part(
					root,
					"PowerFeed",
					Vector3.new(3, 2, 14),
					origin + Vector3.new(x, 1, z + 13),
					RUST
				)
			end
		end
	end
	-- A broken signal gantry silhouettes the depot; the works has a giant dormant rotor.
	if depot then
		for _, x in { -24, 24 } do
			part(
				root,
				"SignalGantryLeg",
				Vector3.new(2, 22, 2),
				origin + Vector3.new(x, 11, -57),
				RUST
			)
		end
		part(root, "SignalGantry", Vector3.new(52, 2, 3), origin + Vector3.new(0, 22, -57), RUST)
		for _, x in { -16, 0, 16 } do
			part(
				root,
				"Signal",
				Vector3.new(3, 3, 1),
				origin + Vector3.new(x, 20, -55),
				GOLD,
				Enum.Material.Neon
			)
		end
	else
		local rotor = part(
			root,
			"DormantRotor",
			Vector3.new(6, 30, 30),
			origin + Vector3.new(0, 20, -55),
			RUST
		)
		rotor.Shape = Enum.PartType.Cylinder
		rotor.Orientation = Vector3.new(0, 90, 0)
		part(root, "RotorPedestal", Vector3.new(18, 8, 10), origin + Vector3.new(0, 4, -55), STEEL)
	end
	sign(root, "LOST PARTS CACHES →", origin + Vector3.new(-54, 8, -77), accent)
	-- Side alcoves reward walking the entire loop; none require jumping or paid equipment.
	local nodes = {}
	for _, x in { -66, 66 } do
		for _, z in { -48, -24, 0, 24, 48 } do
			table.insert(nodes, origin + Vector3.new(x + (if x < 0 then -10 else 10), 1.5, z))
		end
	end
	for _, x in { -22, 22 } do
		table.insert(nodes, origin + Vector3.new(x, 1.5, -72))
	end
	sign(
		root,
		if depot then "RUSTRAIL DEPOT" else "DYNAMO WORKS",
		origin + Vector3.new(0, 10, 79),
		accent
	)
	sign(root, "RETURN TO FACTORY", origin + Vector3.new(28, 8, 77), accent)
	local returnPart =
		part(root, "FactoryReturn", Vector3.new(6, 3, 6), origin + Vector3.new(28, 1.5, 66), accent)
	returnPart:SetAttribute("PlotId", plotId)
	returnPart:SetAttribute("CurrentZone", zoneId)
	local arrival = part(
		root,
		"ExpeditionArrival",
		Vector3.new(2, 0.3, 2),
		origin + Vector3.new(0, 0.5, 66),
		accent
	)
	arrival.CanCollide = false
	arrival.Transparency = 1
	return { Root = root, Nodes = nodes, Arrival = arrival, Return = returnPart }
end

return table.freeze(ExpeditionBuilder)
