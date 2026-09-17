--!strict

local GameConfig = {
	ProfileSchemaVersion = 4,

	Economy = {
		MaxCredits = 1_000_000_000_000,
		MaxMaterialCount = 10_000_000,
		MaxOwnedRobots = 500,
		MaxTransactionQuantity = 10_000,
		MaxInstantProcessTokens = 10_000,
		MaxFactoryClubCosmetics = 24,
		MaxReferralRewards = 5,
	},

	World = {
		PromptActivationDistance = 12,
		SalvageCollectDistance = 14,
		InteractionDistance = 14,
		NodeRespawnSeconds = 8,
		PlotCount = 8,
	},

	Factory = {
		BaseWorkSlots = 1,
		MaxWorkSlots = 4,
		ProductionTickSeconds = 1,
		MachinePollSeconds = 0.25,
		FactoryVIPAssemblerTimeMultiplier = 0.85,
		FactoryClubStorageMultiplier = 1.10,
		OfflineProductionMaxSeconds = 8 * 60 * 60,
		OfflineProductionEfficiency = 0.50,
	},

	Engagement = {
		ReferralQualificationSeconds = 10 * 60,
		ReferralPersistIntervalSeconds = 30,
		ReferralRewardCredits = 500,
		ReferralRewardTokens = 1,
		FactoryReadyDelaySeconds = 30 * 60,
		NotificationOptInDelaySeconds = 3 * 60,
	},

	Networking = {
		MaxStringLength = 64,
		RateLimits = {
			RequestState = { Capacity = 2, RefillPerSecond = 0.5 },
			RequestCollect = { Capacity = 8, RefillPerSecond = 4 },
			RequestProcess = { Capacity = 5, RefillPerSecond = 2 },
			RequestAssemble = { Capacity = 4, RefillPerSecond = 1 },
			RequestAssignRobot = { Capacity = 8, RefillPerSecond = 4 },
			RequestUnassignRobot = { Capacity = 8, RefillPerSecond = 4 },
			RequestSellRobot = { Capacity = 6, RefillPerSecond = 2 },
			RequestUpgrade = { Capacity = 4, RefillPerSecond = 1 },
			RequestUnlockZone = { Capacity = 3, RefillPerSecond = 0.5 },
			RequestUseInstantProcessToken = { Capacity = 3, RefillPerSecond = 0.5 },
			RequestEquipClubCosmetic = { Capacity = 4, RefillPerSecond = 1 },
			RequestAdminBroadcast = { Capacity = 1, RefillPerSecond = 0.1 },
		},
	},
}

return table.freeze(GameConfig)
