--!strict

local OfflineProductionRules = {}

local function isFiniteNonNegative(value: number): boolean
	return value >= 0 and value == value and value < math.huge
end

function OfflineProductionRules.GetElapsedSeconds(
	now: number,
	lastProductionTick: number,
	lastLeave: number,
	maxSeconds: number
): number
	if
		not isFiniteNonNegative(now)
		or not isFiniteNonNegative(lastProductionTick)
		or not isFiniteNonNegative(lastLeave)
		or not isFiniteNonNegative(maxSeconds)
	then
		return 0
	end

	local baseline = math.max(lastProductionTick, lastLeave)
	if baseline <= 0 or now <= baseline then
		return 0
	end

	return math.clamp(now - baseline, 0, maxSeconds)
end

function OfflineProductionRules.GetCreditGrant(
	productionPerSecond: number,
	elapsedSeconds: number,
	efficiency: number,
	permanentMultiplier: number,
	maxCredits: number
): number
	if
		not isFiniteNonNegative(productionPerSecond)
		or not isFiniteNonNegative(elapsedSeconds)
		or not isFiniteNonNegative(efficiency)
		or not isFiniteNonNegative(permanentMultiplier)
		or not isFiniteNonNegative(maxCredits)
	then
		return 0
	end

	local raw = productionPerSecond * elapsedSeconds * efficiency * permanentMultiplier
	if raw ~= raw or raw == math.huge then
		return math.floor(maxCredits)
	end

	return math.floor(math.clamp(raw, 0, maxCredits))
end

return table.freeze(OfflineProductionRules)
