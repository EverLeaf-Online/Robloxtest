--!strict

export type UpgradeLevel = {
	CostCredits: number,
	Value: number,
}

export type UpgradeDefinition = {
	Id: string,
	DisplayName: string,
	Stat: string,
	Levels: { UpgradeLevel },
}

local Upgrades: { [string]: UpgradeDefinition } = {
	ProcessorSpeed = {
		Id = "ProcessorSpeed",
		DisplayName = "Processor Speed",
		Stat = "ProcessorSeconds",
		Levels = {
			{ CostCredits = 0, Value = 6 },
			{ CostCredits = 100, Value = 4.75 },
			{ CostCredits = 450, Value = 3.75 },
			{ CostCredits = 1_500, Value = 3 },
		},
	},
	AssemblerSpeed = {
		Id = "AssemblerSpeed",
		DisplayName = "Assembler Speed",
		Stat = "AssemblerSeconds",
		Levels = {
			{ CostCredits = 0, Value = 8 },
			{ CostCredits = 150, Value = 6.5 },
			{ CostCredits = 600, Value = 5 },
			{ CostCredits = 2_000, Value = 4 },
		},
	},
	Storage = {
		Id = "Storage",
		DisplayName = "Material Storage",
		Stat = "StorageCapacity",
		Levels = {
			{ CostCredits = 0, Value = 50 },
			{ CostCredits = 125, Value = 100 },
			{ CostCredits = 500, Value = 225 },
			{ CostCredits = 1_800, Value = 500 },
		},
	},
	WorkSlots = {
		Id = "WorkSlots",
		DisplayName = "Robot Work Slots",
		Stat = "WorkSlots",
		Levels = {
			{ CostCredits = 0, Value = 1 },
			{ CostCredits = 250, Value = 2 },
			{ CostCredits = 1_100, Value = 3 },
			{ CostCredits = 4_000, Value = 4 },
		},
	},
}

return table.freeze(Upgrades)
