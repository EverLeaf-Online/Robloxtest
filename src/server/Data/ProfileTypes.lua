--!strict

local ProfileTypes = {}

export type ProcessorJob = {
	Active: boolean,
	RecipeId: string,
	StartedAt: number,
	CompletesAt: number,
}

export type AssemblerJob = {
	Active: boolean,
	StartedAt: number,
	CompletesAt: number,
}

export type OwnedRobot = {
	RobotId: string,
	AcquiredAt: number,
}

export type ProfileData = {
	Version: number,
	Revision: number,
	Currencies: {
		Credits: number,
	},
	Materials: { [string]: number },
	Consumables: {
		InstantProcessTokens: number,
	},
	Robots: {
		OwnedByUid: { [string]: OwnedRobot },
		NextUid: number,
	},
	Assignments: {
		WorkPads: { [string]: string },
	},
	Machines: {
		ProcessorLevel: number,
		AssemblerLevel: number,
		StorageLevel: number,
		WorkSlotsLevel: number,
		ProcessorJob: ProcessorJob,
		AssemblerJob: AssemblerJob,
	},
	Progression: {
		Zone: number,
		FactoryTier: number,
		PrestigeCount: number,
	},
	Collection: {
		RobotSeen: { [string]: boolean },
		RobotOwned: { [string]: boolean },
	},
	Tutorial: {
		Milestones: { [string]: boolean },
	},
	Entitlements: {
		CachedPassFlags: { [string]: boolean },
		StarterPackClaimed: boolean,
		PersonalOverclockUntil: number,
		ServerOverclockUntil: number,
		ServerOverclockLeaseId: string,
		FactoryClubActiveCached: boolean,
		FactoryClubLastGrantedCycle: string,
		FactoryClubCosmetics: { [string]: boolean },
		EquippedFactoryClubCosmetic: string,
	},
	Referrals: {
		PendingInviterUserId: number,
		PendingStartedAt: number,
		PendingPlaySeconds: number,
		QualifiedRewardCount: number,
	},
	Receipts: {
		RecentPurchaseIds: { string },
	},
	Stats: {
		LifetimeCredits: number,
		LifetimeRobotsBuilt: number,
		LifetimePlaySeconds: number,
	},
	Timestamps: {
		LastJoin: number,
		LastLeave: number,
		LastSave: number,
		LastProductionTick: number,
	},
	Settings: {
		Audio: boolean,
		Haptics: boolean,
		UI: { [string]: any },
	},
}

return table.freeze(ProfileTypes)
