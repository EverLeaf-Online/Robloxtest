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
}

return table.freeze(FactoryAssetRegistry)
