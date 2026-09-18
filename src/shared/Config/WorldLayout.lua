--!strict

local WorldLayout = {
	Plot = {
		Size = Vector3.new(240, 1, 200),
		FactoryOffset = Vector3.new(0, 0, -18),
		EntryOffset = Vector3.new(0, 1, -68),
		HubReturnAttendantOffset = Vector3.new(-104, 3.5, -84),
	},

	StarterSalvageOffsets = table.freeze({
		Vector3.new(-86, 2, 34),
		Vector3.new(-66, 2, 48),
		Vector3.new(-44, 2, 36),
		Vector3.new(-88, 2, 67),
		Vector3.new(-64, 2, 72),
		Vector3.new(-40, 2, 64),
	}),

	CircuitIsland = {
		CenterOffset = Vector3.new(-82, 0, -165),
		Size = Vector3.new(86, 1, 70),
		BridgeCenterOffset = Vector3.new(-82, 0.8, -115),
		BridgeSize = Vector3.new(14, 0.6, 30),
		BoundaryOpeningCenterX = -82,
		BoundaryOpeningWidth = 20,
	},

	CircuitSalvageOffsets = table.freeze({
		Vector3.new(-108, 2, -179),
		Vector3.new(-91, 2, -159),
		Vector3.new(-72, 2, -180),
		Vector3.new(-54, 2, -158),
		Vector3.new(-100, 2, -143),
		Vector3.new(-66, 2, -143),
	}),

	BotWorkOffsets = table.freeze({
		Salvage = Vector3.new(-66, 1.5, 52),
		Processor = Vector3.new(-30, 1.5, -4),
		Assembler = Vector3.new(-5, 1.5, -4),
		Storage = Vector3.new(-16, 1.5, 13),
		Recycle = Vector3.new(-2, 1.5, 13),
		CircuitSalvage = Vector3.new(-82, 1.5, -165),
	}),

	CircuitGateOffset = Vector3.new(-82, 3.5, -84),
	CircuitArrivalOffset = Vector3.new(-82, 1, -143),
}

return table.freeze(WorldLayout)
