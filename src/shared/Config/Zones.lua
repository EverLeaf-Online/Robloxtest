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
}

return table.freeze(Zones)
