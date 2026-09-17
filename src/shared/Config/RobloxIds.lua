--!strict

local RobloxIds = {
	UniverseId = 10766713640,

	DeveloperProducts = {
		MaterialSupplyCrate = 3713191213,
		FactoryOverclock15m = 3713191406,
		InstantProcessTokens = 3713191584,
		StarterPack = 3713191832,
		ServerOverclock = 3713191857,
	},

	Passes = {
		Production2x = 1982138683,
		ExpandedStorage = 1985786272,
		BotWorkSlots2 = 1985060498,
		AutoCollect = 1982138684,
		FactoryVIP = 1982714688,
	},

	Subscription = {
		FactoryClub = "EXP-418664834641560145",
	},

	Badges = {
		FirstScrap = 3252417673375380,
		FirstBotBuilt = 1761109998097830,
		FactoryOnline = 2465984964619301,
		RareDiscovery = 2071285833691013,
		ZoneTwoUnlocked = 1290904645327424,
	},

	Notifications = {
		FactoryReady = "3e45ef59-0f23-ee44-9365-5c4402e5e3cd",
		ReferralReward = "806403da-e0cf-494e-9cb7-974fab0ff1a4",
		FactoryClubReward = "9de31ecb-88a8-4645-843a-b90c1952419d",
		NewContent = "e1abb235-8da6-814a-a388-a99aefb23213",
	},
}

table.freeze(RobloxIds.DeveloperProducts)
table.freeze(RobloxIds.Passes)
table.freeze(RobloxIds.Subscription)
table.freeze(RobloxIds.Badges)
table.freeze(RobloxIds.Notifications)
table.freeze(RobloxIds)

return RobloxIds
