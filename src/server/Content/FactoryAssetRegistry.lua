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
		AssetId = 76484892239245,
		DisplayName = "Hydraulic Scrap Baler",
		TargetMaxDimension = 15,
	}),
	MagneticSortingConveyor = table.freeze({
		AssetId = 89816186092755,
		DisplayName = "Magnetic Sorting Conveyor",
		TargetMaxDimension = 24,
	}),
	LargeScrapHopper = table.freeze({
		AssetId = 74192034279073,
		DisplayName = "Large Scrap Hopper",
		TargetMaxDimension = 10,
	}),
	BotAssemblerStation = table.freeze({
		AssetId = 105480668154079,
		DisplayName = "Bot Assembler Station",
		TargetMaxDimension = 14,
	}),
}

return table.freeze(FactoryAssetRegistry)
