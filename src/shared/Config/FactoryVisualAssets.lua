--!strict

export type AssetFamily =
	"Processor"
	| "Assembler"
	| "Storage"
	| "WorkerBot"
	| "Salvage"
	| "Conveyor"
	| "FactoryProp"

export type CollisionPolicy = "GameplayPrimitive" | "None"
export type PivotPolicy = "BottomCenter" | "Center"

export type AssetSpec = {
	Id: string,
	Family: AssetFamily,
	Variant: string,
	UpgradeLevel: number?,
	Bounds: Vector3,
	TriangleBudget: number,
	TextureResolution: number,
	CollisionPolicy: CollisionPolicy,
	PivotPolicy: PivotPolicy,
	RobloxAssetId: number?,
	AssetBrief: string,
}

local BASE_STYLE_BRIEF = table.concat({
	"Original stylized low-poly industrial game asset for Scrap-to-Bot Factory.",
	"Chunky readable silhouette, rounded machine guards, modular bolted panels,",
	"scrapyard-built manufacturing aesthetic, worn galvanized steel and charcoal structural steel,",
	"industrial-yellow safety accents, restrained copper/brass mechanics, small cyan status lights, clean PBR materials, efficient UVs, no text, no logos,",
	"no copyrighted branding, isolated object, production-ready topology.",
}, " ")

local function brief(subject: string): string
	return BASE_STYLE_BRIEF .. " " .. subject
end

local function asset(
	id: string,
	family: AssetFamily,
	variant: string,
	upgradeLevel: number?,
	bounds: Vector3,
	triangleBudget: number,
	textureResolution: number,
	collisionPolicy: CollisionPolicy,
	pivotPolicy: PivotPolicy,
	subject: string
): AssetSpec
	return table.freeze({
		Id = id,
		Family = family,
		Variant = variant,
		UpgradeLevel = upgradeLevel,
		Bounds = bounds,
		TriangleBudget = triangleBudget,
		TextureResolution = textureResolution,
		CollisionPolicy = collisionPolicy,
		PivotPolicy = pivotPolicy,
		RobloxAssetId = nil,
		AssetBrief = brief(subject),
	})
end

local Assets: { [string]: AssetSpec } = {
	Processor_L1 = asset(
		"Processor_L1",
		"Processor",
		"Starter",
		1,
		Vector3.new(11, 8, 9),
		3_000,
		1024,
		"GameplayPrimitive",
		"BottomCenter",
		"Starter salvage processor with one crushing drum, intake hopper, side motor, and output tray."
	),
	Processor_L2 = asset(
		"Processor_L2",
		"Processor",
		"Reinforced",
		2,
		Vector3.new(11, 8, 9),
		3_400,
		1024,
		"GameplayPrimitive",
		"BottomCenter",
		"Same processor proportions as Starter, reinforced shell, larger drive motor, twin intake rollers, extra pipework."
	),
	Processor_L3 = asset(
		"Processor_L3",
		"Processor",
		"Industrial",
		3,
		Vector3.new(11, 8, 9),
		3_900,
		1024,
		"GameplayPrimitive",
		"BottomCenter",
		"Same processor footprint, enclosed industrial shredder, visible cooling fins, dual output chutes, brighter status core."
	),
	Processor_L4 = asset(
		"Processor_L4",
		"Processor",
		"Overclocked",
		4,
		Vector3.new(11, 8, 9),
		4_500,
		1024,
		"GameplayPrimitive",
		"BottomCenter",
		"Same processor footprint, premium overclocked form, compact turbine housings, layered guards, energetic cyan conduit accents."
	),
	Assembler_L1 = asset(
		"Assembler_L1",
		"Assembler",
		"Starter",
		1,
		Vector3.new(11, 8, 9),
		3_200,
		1024,
		"GameplayPrimitive",
		"BottomCenter",
		"Starter robot assembler with one articulated tool arm, circular build plate, parts bin, and protected control housing."
	),
	Assembler_L2 = asset(
		"Assembler_L2",
		"Assembler",
		"DualTool",
		2,
		Vector3.new(11, 8, 9),
		3_600,
		1024,
		"GameplayPrimitive",
		"BottomCenter",
		"Same assembler proportions, second compact tool arm, stronger gantry, feeder rail, more visible wiring and clamps."
	),
	Assembler_L3 = asset(
		"Assembler_L3",
		"Assembler",
		"Industrial",
		3,
		Vector3.new(11, 8, 9),
		4_100,
		1024,
		"GameplayPrimitive",
		"BottomCenter",
		"Same assembler footprint, enclosed precision gantry, three tool heads, rotating build plate, reinforced side cabinets."
	),
	Assembler_L4 = asset(
		"Assembler_L4",
		"Assembler",
		"Precision",
		4,
		Vector3.new(11, 8, 9),
		4_800,
		1024,
		"GameplayPrimitive",
		"BottomCenter",
		"Same assembler footprint, top-tier precision robot cell, compact multi-axis arms, illuminated build ring, polished guards."
	),
	Storage_L1 = asset(
		"Storage_L1",
		"Storage",
		"Crates",
		1,
		Vector3.new(10, 5, 8),
		1_600,
		512,
		"GameplayPrimitive",
		"BottomCenter",
		"Starter material storage bank made from three rugged metal bins, simple latches, scrap labels represented only by shapes."
	),
	Storage_L2 = asset(
		"Storage_L2",
		"Storage",
		"Rack",
		2,
		Vector3.new(10, 6, 8),
		1_900,
		512,
		"GameplayPrimitive",
		"BottomCenter",
		"Expanded modular storage rack, stacked reinforced bins, visible side braces, compact indicator lamps."
	),
	Storage_L3 = asset(
		"Storage_L3",
		"Storage",
		"Hopper",
		3,
		Vector3.new(10, 7, 8),
		2_200,
		1024,
		"GameplayPrimitive",
		"BottomCenter",
		"Industrial storage hopper bank with sealed component drawers, upper reservoir, reinforced frame, clean access panels."
	),
	Storage_L4 = asset(
		"Storage_L4",
		"Storage",
		"SmartVault",
		4,
		Vector3.new(10, 8, 8),
		2_600,
		1024,
		"GameplayPrimitive",
		"BottomCenter",
		"High-capacity smart material vault, dense modular drawers, protected top hopper, cyan inventory lights, premium hardware."
	),
	WorkerBot_Wheeled = asset(
		"WorkerBot_Wheeled",
		"WorkerBot",
		"Wheeled",
		nil,
		Vector3.new(3.5, 4, 3.5),
		2_800,
		1024,
		"None",
		"BottomCenter",
		"Friendly compact worker robot with two sturdy wheels, boxy torso, two simple utility arms, antenna, expressive light face."
	),
	WorkerBot_Legged = asset(
		"WorkerBot_Legged",
		"WorkerBot",
		"Legged",
		nil,
		Vector3.new(3.5, 4.5, 3.5),
		3_200,
		1024,
		"None",
		"BottomCenter",
		"Friendly compact worker robot sharing the wheeled bot design language, two short mechanical legs, utility arms, antenna."
	),
	WorkerBot_Hover = asset(
		"WorkerBot_Hover",
		"WorkerBot",
		"Hover",
		nil,
		Vector3.new(3.5, 4, 3.5),
		3_000,
		1024,
		"None",
		"Center",
		"Friendly compact worker robot sharing the same torso language, rounded hover base, utility arms, antenna, protected thrusters."
	),
	SalvagePile_A = asset(
		"SalvagePile_A",
		"Salvage",
		"MetalScrap",
		nil,
		Vector3.new(7, 3, 7),
		800,
		512,
		"GameplayPrimitive",
		"BottomCenter",
		"Low irregular pile of bent sheet metal, gears, short pipes, and machine fragments; broad silhouette, no sharp tiny clutter."
	),
	SalvagePile_B = asset(
		"SalvagePile_B",
		"Salvage",
		"MotorScrap",
		nil,
		Vector3.new(7, 3, 7),
		900,
		512,
		"GameplayPrimitive",
		"BottomCenter",
		"Low pile of discarded motors, cable loops, metal plates, and one broken robot chassis fragment; readable from a distance."
	),
	SalvagePile_C = asset(
		"SalvagePile_C",
		"Salvage",
		"CircuitScrap",
		nil,
		Vector3.new(7, 3, 7),
		900,
		512,
		"GameplayPrimitive",
		"BottomCenter",
		"Low pile of circuit housings, battery shells, bundled wires, and compact electronic scrap with subtle cyan components."
	),
	Conveyor_Straight = asset(
		"Conveyor_Straight",
		"Conveyor",
		"Straight",
		nil,
		Vector3.new(8, 2.5, 4),
		1_100,
		512,
		"None",
		"BottomCenter",
		"Modular straight conveyor segment, chunky side rails, simple rollers and belt, closed motor housing, snap-friendly ends."
	),
	Conveyor_Corner = asset(
		"Conveyor_Corner",
		"Conveyor",
		"Corner90",
		nil,
		Vector3.new(8, 2.5, 8),
		1_300,
		512,
		"None",
		"BottomCenter",
		"Modular ninety-degree conveyor corner matching the straight conveyor rails, belt height, motor language, and snap endpoints."
	),
	Conveyor_Splitter = asset(
		"Conveyor_Splitter",
		"Conveyor",
		"Splitter",
		nil,
		Vector3.new(8, 2.5, 8),
		1_500,
		512,
		"None",
		"BottomCenter",
		"Compact conveyor splitter matching the same kit, one input and two outputs, guarded mechanical diverter, readable flow."
	),
	WorkPad = asset(
		"WorkPad",
		"FactoryProp",
		"RobotStation",
		nil,
		Vector3.new(7, 0.5, 7),
		650,
		512,
		"GameplayPrimitive",
		"BottomCenter",
		"Low-profile robot work pad with octagonal metal rim, recessed center plate, four corner bolts, subtle cyan status ring."
	),
	PipeCluster = asset(
		"PipeCluster",
		"FactoryProp",
		"PipeCluster",
		nil,
		Vector3.new(4, 5, 2),
		700,
		512,
		"None",
		"BottomCenter",
		"Reusable wall-side industrial pipe cluster, three pipe diameters, two elbows, simple mounting brackets and valve wheel."
	),
	CableBundle = asset(
		"CableBundle",
		"FactoryProp",
		"CableBundle",
		nil,
		Vector3.new(4, 1, 2),
		450,
		512,
		"None",
		"BottomCenter",
		"Reusable bundled heavy power cables with two junction housings and large readable curves, no thin loose strands."
	),
	WarningLight = asset(
		"WarningLight",
		"FactoryProp",
		"Beacon",
		nil,
		Vector3.new(1.5, 2.5, 1.5),
		350,
		512,
		"None",
		"BottomCenter",
		"Compact industrial warning beacon with protective cage, heavy base, simple lens housing, no text or hazard symbols."
	),
}

local UpgradeVariants = table.freeze({
	Processor = table.freeze({ "Processor_L1", "Processor_L2", "Processor_L3", "Processor_L4" }),
	Assembler = table.freeze({ "Assembler_L1", "Assembler_L2", "Assembler_L3", "Assembler_L4" }),
	Storage = table.freeze({ "Storage_L1", "Storage_L2", "Storage_L3", "Storage_L4" }),
})

return table.freeze({
	BaseStyleBrief = BASE_STYLE_BRIEF,
	Assets = table.freeze(Assets),
	UpgradeVariants = UpgradeVariants,
})
