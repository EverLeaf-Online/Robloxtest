--!strict

local WorldLayout = {
	Plot = {
		Size = Vector3.new(240, 1, 200),
		FactoryOffset = Vector3.new(0, 0, -18),
		EntryOffset = Vector3.new(0, 1, -68),
		SignOffset = Vector3.new(-46, 3, -82),
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

	CircuitSalvageOffsets = table.freeze({
		Vector3.new(48, 2, 42),
		Vector3.new(70, 2, 55),
		Vector3.new(91, 2, 40),
		Vector3.new(50, 2, 72),
		Vector3.new(73, 2, 78),
		Vector3.new(94, 2, 68),
	}),

	BotWorkOffsets = table.freeze({
		Salvage = Vector3.new(-66, 1.5, 52),
		Processor = Vector3.new(-30, 1.5, -4),
		Assembler = Vector3.new(-5, 1.5, -4),
		Storage = Vector3.new(-16, 1.5, 13),
		Recycle = Vector3.new(-2, 1.5, 13),
		CircuitSalvage = Vector3.new(72, 1.5, 58),
	}),

	CircuitGateOffset = Vector3.new(-82, 3.5, -84),
	CircuitArrivalOffset = Vector3.new(72, 1, 58),
}

return table.freeze(WorldLayout)
