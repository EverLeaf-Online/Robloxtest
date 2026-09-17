--!strict

export type MaterialId = "ScrapMetal" | "Wiring" | "PowerCoreFragments"

export type MaterialDefinition = {
	Id: MaterialId,
	DisplayName: string,
	SortOrder: number,
	Rarity: string,
}

local Materials: { [MaterialId]: MaterialDefinition } = {
	ScrapMetal = {
		Id = "ScrapMetal",
		DisplayName = "Scrap Metal",
		SortOrder = 1,
		Rarity = "Common",
	},
	Wiring = {
		Id = "Wiring",
		DisplayName = "Wiring",
		SortOrder = 2,
		Rarity = "Common",
	},
	PowerCoreFragments = {
		Id = "PowerCoreFragments",
		DisplayName = "Power Core Fragments",
		SortOrder = 3,
		Rarity = "Uncommon",
	},
}

return table.freeze(Materials)
