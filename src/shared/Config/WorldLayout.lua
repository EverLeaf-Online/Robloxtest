--!strict

local WorldLayout = {
	Plot = {
		Size = Vector3.new(240, 1, 190),
		FactoryOffset = Vector3.zero,
		EntryOffset = Vector3.new(10, 1, -68),
		HubReturnAttendantOffset = Vector3.new(-112, 3.5, -87),
		HubReturnAttendantFacing = Vector3.new(0, 0, 1),
	},

	Production = {
		ProcessorOffset = Vector3.new(-47, 4.5, 20),
		WiringControlOffset = Vector3.new(-49, 2, 5),
		CoreControlOffset = Vector3.new(-39, 2, 5),
		AssemblerOffset = Vector3.new(38, 4.5, 20),
		StorageOffset = Vector3.new(70, 2.7, 22),
		RecycleOffset = Vector3.new(60, 2.8, 43),
		IndexTerminalOffset = Vector3.new(-5, 2.8, -30),
		BotConsoleOffset = Vector3.new(6, 2.8, -30),
		UpgradeConsoleOffset = Vector3.new(17, 2.8, -30),
		WorkPadOriginOffset = Vector3.new(45, 0.75, -27),
		WorkPadColumnSpacing = 11,
		WorkPadRowSpacing = 10,
	},

	Environment = {
		ScrapYardCenterOffset = Vector3.new(-88, 0, 26),
		ProductionHallCenterOffset = Vector3.new(10, 0, 20),
		LoadingDockCenterOffset = Vector3.new(101, 0, 26),
		UtilityYardCenterOffset = Vector3.new(73, 0, 76),
		WorkerBayCenterOffset = Vector3.new(52, 0, -20),
		MainAisleCenterOffset = Vector3.new(8, 0, -28),
	},

	StarterSalvageOffsets = table.freeze({
		Vector3.new(-108, 2, 7),
		Vector3.new(-90, 2, 10),
		Vector3.new(-73, 2, 8),
		Vector3.new(-108, 2, 38),
		Vector3.new(-90, 2, 44),
		Vector3.new(-73, 2, 39),
	}),

	CircuitIsland = {
		CenterOffset = Vector3.new(-94, 0, -140),
		Size = Vector3.new(84, 1, 52),
		BridgeCenterOffset = Vector3.new(-94, 0.8, -104.5),
		BridgeSize = Vector3.new(14, 0.6, 19),
		BoundaryOpeningCenterX = -94,
		BoundaryOpeningWidth = 20,
	},

	CircuitSalvageOffsets = table.freeze({
		Vector3.new(-119, 2, -151),
		Vector3.new(-102, 2, -136),
		Vector3.new(-85, 2, -151),
		Vector3.new(-70, 2, -136),
		Vector3.new(-111, 2, -124),
		Vector3.new(-81, 2, -124),
	}),

	BotWorkOffsets = table.freeze({
		Salvage = Vector3.new(-88, 1.5, 25),
		Processor = Vector3.new(-47, 1.5, 5),
		Assembler = Vector3.new(38, 1.5, 5),
		Storage = Vector3.new(70, 1.5, 12),
		Recycle = Vector3.new(60, 1.5, 33),
		CircuitSalvage = Vector3.new(-94, 1.5, -140),
	}),

	CircuitGateOffset = Vector3.new(-94, 1.1, -87),
	CircuitArrivalOffset = Vector3.new(-94, 1, -120),
}

return table.freeze(WorldLayout)
