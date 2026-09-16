local GAME_PASS_IDS = {
	FastGrowth = 0,
	CosmicSkin = 0,
	StarterPlanet = 0,
	MoonCompanion = 0,
}

local DEVELOPER_PRODUCT_IDS = {
	EnergyBoost = 0,
	RareSeedPack = 0,
	CometStrike = 0,
}

local GameConfig = {}

GameConfig.PLANET_RADIUS = 40
GameConfig.TILE_RADIUS = 40.8
GameConfig.TILE_ROWS = 12
GameConfig.TILE_COLS = 16
GameConfig.TILE_SIZE = Vector3.new(13, 1.2, 13)

-- Fast enough for an actual play session while still making Energy matter.
GameConfig.START_ENERGY = 300
GameConfig.MAX_ENERGY = 1_000_000
GameConfig.ENERGY_REGEN_AMOUNT = 5
GameConfig.ENERGY_REGEN_INTERVAL = 2
GameConfig.ACTION_COOLDOWN = 0.6

GameConfig.TILE = {
	Land = 0,
	Water = 1,
	Plant = 2,
	GlowPlant = 3,
}

GameConfig.ACTIONS = {
	AddWater = "AddWater",
	AddPlant = "AddPlant",
	AddAnimal = "AddAnimal",
	BuildSettlement = "BuildSettlement",
}

GameConfig.COSTS = {
	AddWater = 50,
	AddPlant = 75,
	AddAnimal = 100,
	BuildSettlement = 200,
}

GameConfig.MILESTONES = {
	{
		Tiles = 10,
		Title = "Milestone: 10 Developed Tiles",
		Message = "Animals are now unlocked!",
		Unlock = "Animal",
	},
	{
		Tiles = 25,
		Title = "Milestone: 25 Developed Tiles",
		Message = "Settlements are now unlocked!",
		Unlock = "Settlement",
	},
	{
		Tiles = 50,
		Title = "Milestone: 50 Developed Tiles",
		Message = "Your planet now has a chance to grow glowing plants!",
		Unlock = "GoldenPlant",
	},
}

GameConfig.GAME_PASSES = GAME_PASS_IDS
GameConfig.DEVELOPER_PRODUCTS = DEVELOPER_PRODUCT_IDS

GameConfig.SHOP = {
	GamePasses = {
		{
			Key = "FastGrowth",
			Id = GAME_PASS_IDS.FastGrowth,
			Name = "Fast Growth",
			Description = "Doubles your Energy regeneration speed.",
			Price = "299 R$",
		},
		{
			Key = "CosmicSkin",
			Id = GAME_PASS_IDS.CosmicSkin,
			Name = "Cosmic Skin",
			Description = "Changes your planet to a rare cosmic color pattern.",
			Price = "499 R$",
		},
		{
			Key = "StarterPlanet",
			Id = GAME_PASS_IDS.StarterPlanet,
			Name = "Starter Planet",
			Description = "Start with 5 water tiles and 5 plant tiles.",
			Price = "999 R$",
		},
		{
			Key = "MoonCompanion",
			Id = GAME_PASS_IDS.MoonCompanion,
			Name = "Moon Companion",
			Description = "Adds a small moon orbiting your planet.",
			Price = "799 R$",
		},
	},
	Products = {
		{
			Key = "EnergyBoost",
			Id = DEVELOPER_PRODUCT_IDS.EnergyBoost,
			Name = "Energy Boost",
			Description = "+500 Energy instantly.",
			Price = "49 R$",
		},
		{
			Key = "RareSeedPack",
			Id = DEVELOPER_PRODUCT_IDS.RareSeedPack,
			Name = "Rare Seed Pack",
			Description = "Unlocks special glowing plants and adds one immediately.",
			Price = "99 R$",
		},
		{
			Key = "CometStrike",
			Id = DEVELOPER_PRODUCT_IDS.CometStrike,
			Name = "Comet Strike",
			Description = "A comet instantly develops 3 random land tiles.",
			Price = "199 R$",
		},
	},
}

GameConfig.COLORS = {
	Base = Color3.fromRGB(116, 86, 62),
	CosmicBase = Color3.fromRGB(58, 36, 96),
	Land = Color3.fromRGB(149, 111, 74),
	CosmicLandA = Color3.fromRGB(90, 58, 132),
	CosmicLandB = Color3.fromRGB(62, 42, 102),
	Water = Color3.fromRGB(38, 143, 232),
	Plant = Color3.fromRGB(58, 190, 92),
	GlowPlant = Color3.fromRGB(120, 255, 165),
	UI = {
		Background = Color3.fromRGB(11, 13, 26),
		Button = Color3.fromRGB(30, 35, 68),
		ButtonDisabled = Color3.fromRGB(20, 22, 36),
		Accent = Color3.fromRGB(0, 220, 255),
		Accent2 = Color3.fromRGB(170, 85, 255),
		Text = Color3.fromRGB(235, 240, 255),
	},
}

return GameConfig
