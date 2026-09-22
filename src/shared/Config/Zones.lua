--!strict

export type ZoneDefinition = {
	Id: number,
	DisplayName: string,
	UnlockCredits: number,
	RequiredLifetimeRobots: number,
	Salvage: {
		ScrapMin: number,
		ScrapMax: number,
		WiringChance: number,
		CoreChance: number,
	},
}

local Zones: { [number]: ZoneDefinition } = {
	[1] = {
		Id = 1,
		DisplayName = "Starter Yard",
		UnlockCredits = 0,
		RequiredLifetimeRobots = 0,
		Salvage = {
			ScrapMin = 2,
			ScrapMax = 4,
			WiringChance = 0.18,
			CoreChance = 0.03,
		},
	},
	[2] = {
		Id = 2,
		DisplayName = "Circuit Yard",
		UnlockCredits = 2_500,
		RequiredLifetimeRobots = 3,
		Salvage = {
			ScrapMin = 4,
			ScrapMax = 7,
			WiringChance = 0.3,
			CoreChance = 0.08,
		},
	},
	[3] = {
		Id = 3,
		DisplayName = "Rustrail Depot",
		UnlockCredits = 8000,
		RequiredLifetimeRobots = 8,
		Salvage = { ScrapMin = 6, ScrapMax = 10, WiringChance = 0.42, CoreChance = 0.12 },
	},
	[4] = {
		Id = 4,
		DisplayName = "Dynamo Works",
		UnlockCredits = 20000,
		RequiredLifetimeRobots = 16,
		Salvage = { ScrapMin = 8, ScrapMax = 13, WiringChance = 0.55, CoreChance = 0.2 },
	},
}

return table.freeze(Zones)
