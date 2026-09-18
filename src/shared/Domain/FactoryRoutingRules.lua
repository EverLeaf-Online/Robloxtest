--!strict

export type RouteRole = "Owner" | "Visitor"

export type RouteRecord = {
	PlayerUserId: number,
	OwnerUserId: number,
	Role: RouteRole,
	IssuedAt: number,
}

local FactoryRoutingRules = {}

function FactoryRoutingRules.ValidateRoute(
	record: any,
	playerUserId: number,
	now: number,
	maxAgeSeconds: number
): (boolean, string)
	if typeof(record) ~= "table" then
		return false, "ROUTE_MISSING"
	end
	if typeof(record.PlayerUserId) ~= "number" or record.PlayerUserId ~= playerUserId then
		return false, "ROUTE_PLAYER_MISMATCH"
	end
	if typeof(record.OwnerUserId) ~= "number" or record.OwnerUserId <= 0 then
		return false, "ROUTE_OWNER_INVALID"
	end
	if record.Role ~= "Owner" and record.Role ~= "Visitor" then
		return false, "ROUTE_ROLE_INVALID"
	end
	if typeof(record.IssuedAt) ~= "number" then
		return false, "ROUTE_TIMESTAMP_INVALID"
	end
	if now - record.IssuedAt < 0 or now - record.IssuedAt > maxAgeSeconds then
		return false, "ROUTE_EXPIRED"
	end
	if record.Role == "Owner" and record.OwnerUserId ~= playerUserId then
		return false, "OWNER_ROUTE_MISMATCH"
	end

	return true, "ROUTE_VALID"
end

return table.freeze(FactoryRoutingRules)
