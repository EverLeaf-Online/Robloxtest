--!strict

export type FactoryAssetSpec = {
	AssetId: number,
	DisplayName: string,
	TargetMaxDimension: number,
}

local FactoryAssetRegistry: { [string]: FactoryAssetSpec } = {
	IndustrialScrapShredder = table.freeze({
		AssetId = 76139540142450,
		DisplayName = "Industrial Scrap Shredder",
		TargetMaxDimension = 18,
	}),
	HydraulicScrapBaler = table.freeze({
		AssetId = 119687239055490,
		DisplayName = "Hydraulic Scrap Baler",
		TargetMaxDimension = 15,
	}),
	MagneticSortingConveyor = table.freeze({
		AssetId = 82587853233083,
		DisplayName = "Magnetic Sorting Conveyor",
		TargetMaxDimension = 24,
	}),
	LargeScrapHopper = table.freeze({
		AssetId = 96263374977934,
		DisplayName = "Large Scrap Hopper",
		TargetMaxDimension = 10,
	}),
	BotAssemblerStation = table.freeze({
		AssetId = 88933326882163,
		DisplayName = "Bot Assembler Station",
		TargetMaxDimension = 12,
	}),
	InfeedConveyor = table.freeze({
		AssetId = 112925855673224,
		DisplayName = "Infeed Conveyor",
		TargetMaxDimension = 24,
	}),
	OutfeedConveyor = table.freeze({
		AssetId = 112992563260380,
		DisplayName = "Outfeed Conveyor",
		TargetMaxDimension = 22,
	}),
	ScrapPileMedium = table.freeze({
		AssetId = 94121661837836,
		DisplayName = "Scrap Pile",
		TargetMaxDimension = 12,
	}),
	ExpandedStorageRack = table.freeze({
		AssetId = 133330484140056,
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
		AssetId = 77920368437090,
		DisplayName = "Electrical Control Cabinet",
		TargetMaxDimension = 8,
	}),
	MaterialBin = table.freeze({
		AssetId = 90582751977534,
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
}

return table.freeze(FactoryAssetRegistry)
