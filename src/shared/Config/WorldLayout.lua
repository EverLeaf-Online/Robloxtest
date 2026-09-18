--!strict

local WorldLayout = {
	Plot = {
		Size = Vector3.new(280, 1, 220),
		FactoryOffset = Vector3.zero,
		EntryOffset = Vector3.new(0, 1, -84),
		HubReturnAttendantOffset = Vector3.new(-132, 3.5, -102),
		HubReturnAttendantFacing = Vector3.new(0, 0, 1),
	},

	Production = {
		ProcessorOffset = Vector3.new(-34, 4.5, 10),
		WiringControlOffset = Vector3.new(-38, 2, -1),
		CoreControlOffset = Vector3.new(-30, 2, -1),
		AssemblerOffset = Vector3.new(14, 4.5, 10),
		StorageOffset = Vector3.new(72, 2.7, 28),
		RecycleOffset = Vector3.new(42, 2.8, 29),
		IndexTerminalOffset = Vector3.new(-12, 2.8, -20),
		BotConsoleOffset = Vector3.new(-3, 2.8, -20),
		UpgradeConsoleOffset = Vector3.new(6, 2.8, -20),
		WorkPadOriginOffset = Vector3.new(53, 0.75, -28),
		WorkPadColumnSpacing = 11,
		WorkPadRowSpacing = 12,
	},

	Environment = {
		ScrapYardCenterOffset = Vector3.new(-86, 0, 58),
		ProductionHallCenterOffset = Vector3.new(-6, 0, 13),
		LoadingDockCenterOffset = Vector3.new(96, 0, 44),
		UtilityYardCenterOffset = Vector3.new(108, 0, -64),
		WorkerBayCenterOffset = Vector3.new(60, 0, -26),
		MainAisleCenterOffset = Vector3.new(0, 0, -30),
	},

	StarterSalvageOffsets = table.freeze({
		Vector3.new(-112, 2, 44),
		Vector3.new(-90, 2, 48),
		Vector3.new(-67, 2, 43),
		Vector3.new(-110, 2, 72),
		Vector3.new(-86, 2, 78),
		Vector3.new(-62, 2, 70),
	}),

	CircuitIsland = {
		CenterOffset = Vector3.new(-112, 0, -174),
		Size = Vector3.new(96, 1, 76),
		BridgeCenterOffset = Vector3.new(-112, 0.8, -123),
		BridgeSize = Vector3.new(14, 0.6, 26),
		BoundaryOpeningCenterX = -112,
		BoundaryOpeningWidth = 20,
	},

	CircuitSalvageOffsets = table.freeze({
		Vector3.new(-142, 2, -188),
		Vector3.new(-120, 2, -170),
		Vector3.new(-96, 2, -190),
		Vector3.new(-76, 2, -168),
		Vector3.new(-132, 2, -150),
		Vector3.new(-92, 2, -150),
	}),

	BotWorkOffsets = table.freeze({
		Salvage = Vector3.new(-87, 1.5, 58),
		Processor = Vector3.new(-34, 1.5, -3),
		Assembler = Vector3.new(14, 1.5, -3),
		Storage = Vector3.new(72, 1.5, 20),
		Recycle = Vector3.new(42, 1.5, 21),
		CircuitSalvage = Vector3.new(-112, 1.5, -174),
	}),

	CircuitGateOffset = Vector3.new(-101, 1.1, -94),
	CircuitArrivalOffset = Vector3.new(-112, 1, -150),
}

return table.freeze(WorldLayout)
