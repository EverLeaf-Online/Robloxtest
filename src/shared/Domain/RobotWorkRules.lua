--!strict

local VALID_NODE = table.freeze({
	Salvage = true,
	Processor = true,
	Assembler = true,
	Storage = true,
	Recycle = true,
	CircuitSalvage = true,
})

local ROUTES = table.freeze({
	Salvager = table.freeze({ "Salvage", "Processor", "Storage" }),
	Technician = table.freeze({ "Processor", "Assembler", "Storage" }),
	Hauler = table.freeze({ "Storage", "Processor", "Assembler" }),
	Courier = table.freeze({ "Storage", "Assembler", "Salvage" }),
	Extractor = table.freeze({ "Salvage", "Processor", "CircuitSalvage", "Storage" }),
	Foreman = table.freeze({ "Processor", "Assembler", "Storage", "Salvage" }),
})

local MOVE_SPEED = table.freeze({
	Wheels = 11,
	Tracks = 8,
	Legs = 9,
	Hover = 12,
})

local RobotWorkRules = {}

function RobotWorkRules.GetRoute(family: string): { string }
	local route = ROUTES[family]
	if route == nil then
		return { "Processor", "Storage" }
	end
	return table.clone(route)
end

function RobotWorkRules.GetMoveSpeed(locomotion: string): number
	return MOVE_SPEED[locomotion] or 9
end

function RobotWorkRules.IsValidWorkNode(nodeName: string): boolean
	return VALID_NODE[nodeName] == true
end

function RobotWorkRules.GetWorkPauseSeconds(family: string): number
	if family == "Technician" or family == "Foreman" then
		return 1.8
	elseif family == "Extractor" then
		return 2.1
	end
	return 1.5
end

return table.freeze(RobotWorkRules)
