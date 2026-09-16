--!strict

local GameConfig = {
	ProfileSchemaVersion = 2,

	Economy = {
		MaxCredits = 1_000_000_000_000,
		MaxMaterialCount = 10_000_000,
		MaxOwnedRobots = 500,
		MaxTransactionQuantity = 10_000,
	},

	World = {
		SalvageCollectDistance = 20,
		InteractionDistance = 24,
		NodeRespawnSeconds = 8,
	},

	Factory = {
		BaseWorkSlots = 1,
		MaxWorkSlots = 4,
		ProductionTickSeconds = 1,
		MachinePollSeconds = 0.25,
	},

	Networking = {
		MaxStringLength = 64,
		RateLimits = {
			RequestState = { Capacity = 4, RefillPerSecond = 1 },
			RequestCollect = { Capacity = 8, RefillPerSecond = 4 },
			RequestProcess = { Capacity = 5, RefillPerSecond = 2 },
			RequestAssemble = { Capacity = 4, RefillPerSecond = 1 },
			RequestAssignRobot = { Capacity = 8, RefillPerSecond = 4 },
			RequestSellRobot = { Capacity = 6, RefillPerSecond = 2 },
			RequestUpgrade = { Capacity = 4, RefillPerSecond = 1 },
			RequestUnlockZone = { Capacity = 3, RefillPerSecond = 0.5 },
			RequestPrestige = { Capacity = 2, RefillPerSecond = 0.25 },
		},
	},
}

return table.freeze(GameConfig)
