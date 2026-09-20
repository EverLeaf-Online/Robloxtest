--!strict

export type MaterialAmounts = { [string]: number }

export type ProcessorRecipe = {
	Id: string,
	DisplayName: string,
	Input: MaterialAmounts,
	Output: MaterialAmounts,
}

local Processor: { [string]: ProcessorRecipe } = {
	MakeWiring = {
		Id = "MakeWiring",
		DisplayName = "Make Wiring",
		Input = {
			ScrapMetal = 4,
		},
		Output = {
			Wiring = 1,
		},
	},
	RecoverCore = {
		Id = "RecoverCore",
		DisplayName = "Recover Power Core",
		Input = {
			ScrapMetal = 6,
			Wiring = 1,
		},
		Output = {
			PowerCoreFragments = 1,
		},
	},
}

local Assembler = table.freeze({
	FirstBuildInput = table.freeze({
		ScrapMetal = 4,
		Wiring = 1,
		PowerCoreFragments = 1,
	}),
	StandardInput = table.freeze({
		ScrapMetal = 5,
		Wiring = 2,
		PowerCoreFragments = 1,
	}),
})

return table.freeze({
	Processor = table.freeze(Processor),
	Assembler = Assembler,
})
