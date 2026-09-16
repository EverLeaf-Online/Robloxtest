--!strict

local GameConfig = require(script.Parent.Parent.Config.GameConfig)

local Validation = {}

function Validation.isFiniteNumber(value: any): boolean
	return typeof(value) == "number" and value == value and value > -math.huge and value < math.huge
end

function Validation.isSafeInteger(value: any, minimum: number?, maximum: number?): boolean
	if not Validation.isFiniteNumber(value) then
		return false
	end

	local numberValue = value :: number
	if numberValue % 1 ~= 0 then
		return false
	end

	if minimum ~= nil and numberValue < minimum then
		return false
	end

	if maximum ~= nil and numberValue > maximum then
		return false
	end

	return true
end

function Validation.isBoundedString(value: any, maximumLength: number?): boolean
	if typeof(value) ~= "string" then
		return false
	end

	local limit = maximumLength or GameConfig.Networking.MaxStringLength
	return #value > 0 and #value <= limit
end

function Validation.isVector3Finite(value: any): boolean
	if typeof(value) ~= "Vector3" then
		return false
	end

	local vector = value :: Vector3
	return Validation.isFiniteNumber(vector.X)
		and Validation.isFiniteNumber(vector.Y)
		and Validation.isFiniteNumber(vector.Z)
end

function Validation.isInstanceOf(value: any, className: string): boolean
	return typeof(value) == "Instance" and (value :: Instance):IsA(className)
end

function Validation.isKnownId<T>(value: any, definitions: { [string]: T }): boolean
	return Validation.isBoundedString(value) and definitions[value :: string] ~= nil
end

return table.freeze(Validation)
