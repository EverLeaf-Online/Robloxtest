--!strict

local Salvage = table.freeze({
	ScrapMin = 2,
	ScrapMax = 4,
	WiringChance = 0.18,
	CoreChance = 0.03,
	FirstCollectBonus = table.freeze({
		ScrapMetal = 2,
		Wiring = 1,
	}),
})

return Salvage
