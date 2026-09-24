--!strict

export type FactoryAssetSpec = {
	AssetId: number,
	DisplayName: string,
	TargetMaxDimension: number,
}

local FactoryAssetRegistry: { [string]: FactoryAssetSpec } = {
	IndustrialScrapShredder = table.freeze({
		AssetId = 125655812080459,
		DisplayName = "Industrial Scrap Shredder",
		TargetMaxDimension = 18,
	}),
	HydraulicScrapBaler = table.freeze({
		AssetId = 84444976587250,
		DisplayName = "Hydraulic Scrap Baler",
		TargetMaxDimension = 15,
	}),
	MagneticSortingConveyor = table.freeze({
		AssetId = 107116249649986,
		DisplayName = "Magnetic Sorting Conveyor",
		TargetMaxDimension = 24,
	}),
	LargeScrapHopper = table.freeze({
		AssetId = 105012050478324,
		DisplayName = "Large Scrap Hopper",
		TargetMaxDimension = 10,
	}),
	BotAssemblerStation = table.freeze({
		AssetId = 94018253290056,
		DisplayName = "Bot Assembler Station",
		TargetMaxDimension = 12,
	}),
	InfeedConveyor = table.freeze({
		AssetId = 81363791665301,
		DisplayName = "Infeed Conveyor",
		TargetMaxDimension = 24,
	}),
	OutfeedConveyor = table.freeze({
		AssetId = 137929434328583,
		DisplayName = "Outfeed Conveyor",
		TargetMaxDimension = 22,
	}),
	ScrapPileMedium = table.freeze({
		AssetId = 94121661837836,
		DisplayName = "Scrap Pile",
		TargetMaxDimension = 12,
	}),
	ExpandedStorageRack = table.freeze({
		AssetId = 118800985728623,
		DisplayName = "Expanded Storage Rack",
		TargetMaxDimension = 13,
	}),
	FactoryLightFixture = table.freeze({
		AssetId = 95471113233773,
		DisplayName = "Factory Light Fixture",
		TargetMaxDimension = 5,
	}),
	FactoryStairs = table.freeze({
		AssetId = 127476836459285,
		DisplayName = "Factory Stairs",
		TargetMaxDimension = 14,
	}),
	UtilityPipeRack = table.freeze({
		AssetId = 91418551606339,
		DisplayName = "Utility Pipe Rack",
		TargetMaxDimension = 14,
	}),
	SafetyBarrier = table.freeze({
		AssetId = 104919039194566,
		DisplayName = "Safety Barrier",
		TargetMaxDimension = 10,
	}),
	ElectricalCabinet = table.freeze({
		AssetId = 75379655395195,
		DisplayName = "Electrical Control Cabinet",
		TargetMaxDimension = 8,
	}),
	MaterialBin = table.freeze({
		AssetId = 97856479635885,
		DisplayName = "Material Bin",
		TargetMaxDimension = 10,
	}),
	CatwalkModule = table.freeze({
		AssetId = 110382675585798,
		DisplayName = "Catwalk Module",
		TargetMaxDimension = 14,
	}),
	StructuralColumn = table.freeze({
		AssetId = 84439007347573,
		DisplayName = "Structural Column",
		TargetMaxDimension = 18,
	}),
	SalvageTruck = table.freeze({
		AssetId = 115224937966494,
		DisplayName = "Salvage Truck",
		TargetMaxDimension = 36,
	}),
}

return table.freeze(FactoryAssetRegistry)
