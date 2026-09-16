local Config = {}

Config.PLANET_RADIUS = 40
Config.TILE_COUNT = 144
Config.TILE_SURFACE_OFFSET = 0.45
-- 144 equal-area cells on a radius-40 sphere need roughly a 13.3-stud
-- equivalent diameter.  The old 9.25-stud discs covered only about half of the
-- sphere and made the surface look like disconnected dots.
Config.TILE_DIAMETER = 13.1
Config.PLANET_SLOT_SPACING = 500

Config.ENERGY_START = 100
Config.ENERGY_MAX = 1_000_000
Config.ENERGY_REGEN_AMOUNT = 1
Config.ENERGY_REGEN_INTERVAL = 5
Config.ACTION_COOLDOWN = 1

Config.ACTION_COSTS = {
	AddWater = 50,
	AddPlants = 75,
	AddAnimals = 100,
	BuildSettlement = 200,
	TerraformBurst = 350,
}

Config.ACTION_UNLOCKS = {
	AddWater = 0,
	AddPlants = 0,
	AddAnimals = 10,
	BuildSettlement = 25,
	TerraformBurst = 50,
}

Config.ACTION_COOLDOWNS = {
	AddWater = 1,
	AddPlants = 1,
	AddAnimals = 1,
	BuildSettlement = 1,
	TerraformBurst = 15,
}

Config.MILESTONES = { 10, 25, 50 }
Config.MILESTONE_UNLOCK_NAMES = {
	[10] = "Add Animals",
	[25] = "Build Settlement",
	[50] = "Terraform Burst",
}
Config.MILESTONE_ENERGY_REWARDS = {
	[10] = 150,
	[25] = 350,
	[50] = 750,
}

Config.PLANET_STAGES = {
	{ MinDeveloped = 0, Name = "Barren World", Description = "A quiet world waiting for its first ecosystem." },
	{ MinDeveloped = 5, Name = "Young World", Description = "Water and vegetation are beginning to take hold." },
	{ MinDeveloped = 10, Name = "Living World", Description = "The biosphere is stable enough to support animals." },
	{ MinDeveloped = 25, Name = "Settled World", Description = "Life has grown dense enough for civilization." },
	{ MinDeveloped = 50, Name = "Thriving World", Description = "A mature planet with powerful terraforming unlocked." },
	{ MinDeveloped = 100, Name = "Garden World", Description = "Most of the surface has become a living world." },
}

Config.DATASTORE_PRIMARY = "GrowATinyPlanet_PlayerData_v1"
Config.DATASTORE_BACKUP = "GrowATinyPlanet_PlayerData_Backup_v1"
Config.AUTOSAVE_SECONDS = 60
Config.DATASTORE_RETRIES = 3

-- Replace each Id = 0 with the ID created for this Roblox experience.
Config.PASSES = {
	FastGrowth = {
		Id = 0,
		Name = "Fast Growth",
		Price = 299,
		Description = "Energy regenerates twice as fast.",
	},
	CosmicSkin = {
		Id = 0,
		Name = "Cosmic Skin",
		Price = 499,
		Description = "Applies a unique cosmic surface pattern to your planet.",
	},
	StarterPlanet = {
		Id = 0,
		Name = "Starter Planet",
		Price = 999,
		Description = "Begin with 5 water and 5 plant tiles already developed.",
	},
	MoonCompanion = {
		Id = 0,
		Name = "Moon Companion",
		Price = 799,
		Description = "Adds a moon that orbits your planet.",
	},
}

Config.PRODUCTS = {
	EnergyBoost = {
		Id = 0,
		Name = "Energy Boost",
		Price = 49,
		Description = "+500 Energy instantly.",
	},
	RareSeedPack = {
		Id = 0,
		Name = "Rare Seed Pack",
		Price = 99,
		Description = "Adds 3 glowing rare-seed charges. Your next plant actions use them.",
	},
	CometStrike = {
		Id = 0,
		Name = "Comet Strike",
		Price = 199,
		Description = "Instantly develops 3 random land tiles.",
	},
}

Config.COLORS = {
	Base = Color3.fromRGB(125, 91, 64),
	Land = Color3.fromRGB(166, 125, 83),
	LandAlt = Color3.fromRGB(143, 103, 72),
	Water = Color3.fromRGB(42, 151, 232),
	Plant = Color3.fromRGB(73, 199, 104),
	RarePlant = Color3.fromRGB(88, 255, 213),
	CosmicA = Color3.fromRGB(118, 82, 240),
	CosmicB = Color3.fromRGB(39, 220, 236),
	Moon = Color3.fromRGB(198, 207, 226),
}

Config.VALID_TILE_TYPES = {
	Land = true,
	Water = true,
	Plant = true,
	RarePlant = true,
}

return table.freeze(Config)
