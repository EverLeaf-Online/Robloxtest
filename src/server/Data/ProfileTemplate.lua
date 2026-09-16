--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)

local ProfileTemplate = {
	Version = GameConfig.ProfileSchemaVersion,
	Revision = 0,

	Currencies = {
		Credits = 0,
	},

	Materials = {
		ScrapMetal = 0,
		Wiring = 0,
		PowerCoreFragments = 0,
	},

	Robots = {
		OwnedByUid = {},
		NextUid = 1,
	},

	Assignments = {
		WorkPads = {},
	},

	Machines = {
		ProcessorLevel = 1,
		AssemblerLevel = 1,
		StorageLevel = 1,
		WorkSlotsLevel = 1,
	},

	Progression = {
		Zone = 1,
		FactoryTier = 1,
		PrestigeCount = 0,
	},

	Collection = {
		RobotSeen = {},
		RobotOwned = {},
	},

	Tutorial = {
		Milestones = {},
	},

	Entitlements = {
		CachedPassFlags = {},
	},

	Receipts = {
		RecentPurchaseIds = {},
	},

	Stats = {
		LifetimeCredits = 0,
		LifetimeRobotsBuilt = 0,
	},

	Timestamps = {
		LastJoin = 0,
		LastSave = 0,
		LastProductionTick = 0,
	},

	Settings = {
		Audio = true,
		Haptics = true,
		UI = {},
	},
}

return ProfileTemplate
