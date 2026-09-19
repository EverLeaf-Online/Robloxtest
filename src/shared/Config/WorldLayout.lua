--!strict

local WorldLayout = {
	Plot = {
		Size = Vector3.new(280, 1, 220),
		FactoryOffset = Vector3.zero,
		EntryOffset = Vector3.new(8, 1, -84),
		HubReturnAttendantOffset = Vector3.new(-132, 3.5, -102),
		HubReturnAttendantFacing = Vector3.new(0, 0, 1),
	},

	Production = {
		ProcessorOffset = Vector3.new(-42, 4.5, 18),
		WiringControlOffset = Vector3.new(-47, 2, 3),
		CoreControlOffset = Vector3.new(-37, 2, 3),
		AssemblerOffset = Vector3.new(2, 4.5, 18),
		StorageOffset = Vector3.new(54, 2.7, 20),
		RecycleOffset = Vector3.new(40, 2.8, 39),
		IndexTerminalOffset = Vector3.new(-16, 2.8, -34),
		BotConsoleOffset = Vector3.new(-5, 2.8, -34),
		UpgradeConsoleOffset = Vector3.new(6, 2.8, -34),
		WorkPadOriginOffset = Vector3.new(46, 0.75, -29),
		WorkPadColumnSpacing = 11,
		WorkPadRowSpacing = 11,
	},

	Environment = {
		ScrapYardCenterOffset = Vector3.new(-105, 0, 35),
		ProductionHallCenterOffset = Vector3.new(4, 0, 17),
		LoadingDockCenterOffset = Vector3.new(112, 0, 24),
		UtilityYardCenterOffset = Vector3.new(92, 0, 82),
		WorkerBayCenterOffset = Vector3.new(56, 0, -24),
		MainAisleCenterOffset = Vector3.new(5, 0, -28),
	},

	StarterSalvageOffsets = table.freeze({
		Vector3.new(-126, 2, 14),
		Vector3.new(-106, 2, 17),
		Vector3.new(-87, 2, 13),
		Vector3.new(-126, 2, 43),
		Vector3.new(-106, 2, 50),
		Vector3.new(-87, 2, 44),
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
		Salvage = Vector3.new(-104, 1.5, 34),
		Processor = Vector3.new(-42, 1.5, 3),
		Assembler = Vector3.new(2, 1.5, 3),
		Storage = Vector3.new(54, 1.5, 10),
		Recycle = Vector3.new(40, 1.5, 29),
		CircuitSalvage = Vector3.new(-112, 1.5, -174),
	}),

	-- Ground-mounted unlock control sits directly on the main-plant side of the bridge.
	CircuitGateOffset = Vector3.new(-112, 1.1, -102),
	CircuitArrivalOffset = Vector3.new(-112, 1, -150),
}

return table.freeze(WorldLayout)
