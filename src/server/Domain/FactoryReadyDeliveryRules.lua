--!strict

local FactoryReadyDeliveryRules = {}

local MAX_GENERATION_LENGTH = 64
local STATUS_SCHEDULED = "scheduled"
local STATUS_SENDING = "sending"
local STATUS_SENT = "sent"
local STATUS_CANCELLED = "cancelled"

export type DeliveryState = {
	Generation: string,
	DueAt: number,
	Status: string,
	Owner: string,
	ClaimUntil: number,
	UpdatedAt: number,
}

local function isFiniteNonNegative(value: any): boolean
	return typeof(value) == "number" and value == value and value >= 0 and value < math.huge
end

local function isGeneration(value: any): boolean
	return typeof(value) == "string" and #value > 0 and #value <= MAX_GENERATION_LENGTH
end

local function isOwner(value: any): boolean
	return typeof(value) == "string" and #value > 0 and #value <= 128
end

local function normalizeStatus(value: any): string
	if
		value == STATUS_SCHEDULED
		or value == STATUS_SENDING
		or value == STATUS_SENT
		or value == STATUS_CANCELLED
	then
		return value
	end
	return STATUS_CANCELLED
end

function FactoryReadyDeliveryRules.Normalize(value: any): DeliveryState
	local state = if typeof(value) == "table" then value else {}
	local generation = if isGeneration(state.Generation) then state.Generation else ""
	local owner = if typeof(state.Owner) == "string" and #state.Owner <= 128
		then state.Owner
		else ""
	local claimUntil = if isFiniteNonNegative(state.ClaimUntil)
		then state.ClaimUntil
		elseif isFiniteNonNegative(state.ExpiresAt) then state.ExpiresAt
		else 0
	local status = normalizeStatus(state.Status)
	if generation == "" and owner ~= "" and claimUntil > 0 then
		-- v1 stored only { Owner, ExpiresAt }. Preserve that lease during a rolling
		-- deployment so a v2 poller cannot steal an in-flight legacy send.
		status = STATUS_SENDING
	end
	return {
		Generation = generation,
		DueAt = if isFiniteNonNegative(state.DueAt) then state.DueAt else 0,
		Status = status,
		Owner = owner,
		ClaimUntil = claimUntil,
		UpdatedAt = if isFiniteNonNegative(state.UpdatedAt) then state.UpdatedAt else 0,
	}
end

function FactoryReadyDeliveryRules.Schedule(
	generation: string,
	dueAt: number,
	now: number
): DeliveryState?
	if
		not isGeneration(generation)
		or not isFiniteNonNegative(dueAt)
		or not isFiniteNonNegative(now)
	then
		return nil
	end
	return {
		Generation = generation,
		DueAt = dueAt,
		Status = STATUS_SCHEDULED,
		Owner = "",
		ClaimUntil = 0,
		UpdatedAt = now,
	}
end

function FactoryReadyDeliveryRules.Cancel(value: any, now: number): DeliveryState
	local state = FactoryReadyDeliveryRules.Normalize(value)
	if not isFiniteNonNegative(now) then
		return state
	end
	state.Status = STATUS_CANCELLED
	state.Owner = ""
	state.ClaimUntil = 0
	state.UpdatedAt = now
	return state
end

function FactoryReadyDeliveryRules.Claim(
	value: any,
	generation: string,
	dueAt: number,
	owner: string,
	now: number,
	claimSeconds: number
): (DeliveryState, boolean, string)
	local state = FactoryReadyDeliveryRules.Normalize(value)
	if
		not isGeneration(generation)
		or not isOwner(owner)
		or not isFiniteNonNegative(dueAt)
		or not isFiniteNonNegative(now)
		or not isFiniteNonNegative(claimSeconds)
	then
		return state, false, "INVALID"
	end

	-- Legacy queue entries predate persisted delivery state. Respect an old live
	-- { Owner, ExpiresAt } lock first, then adopt the due generation after it expires.
	if state.Generation == "" then
		if
			state.Status == STATUS_SENDING
			and state.Owner ~= ""
			and state.Owner ~= owner
			and state.ClaimUntil > now
		then
			return state, false, "BUSY"
		end
		state.Generation = generation
		state.DueAt = dueAt
		state.Status = STATUS_SCHEDULED
		state.Owner = ""
		state.ClaimUntil = 0
		state.UpdatedAt = now
	end

	if state.Generation ~= generation or state.DueAt ~= dueAt then
		return state, false, "STALE"
	end
	if state.Status == STATUS_SENT or state.Status == STATUS_CANCELLED then
		return state, false, "STALE"
	end
	if dueAt > now then
		return state, false, "NOT_DUE"
	end
	if state.Status == STATUS_SENDING and state.Owner ~= owner and state.ClaimUntil > now then
		return state, false, "BUSY"
	end

	state.Status = STATUS_SENDING
	state.Owner = owner
	state.ClaimUntil = now + claimSeconds
	state.UpdatedAt = now
	return state, true, "CLAIMED"
end

function FactoryReadyDeliveryRules.Renew(
	value: any,
	generation: string,
	owner: string,
	now: number,
	claimSeconds: number
): (DeliveryState, boolean)
	local state = FactoryReadyDeliveryRules.Normalize(value)
	if
		not isGeneration(generation)
		or not isOwner(owner)
		or not isFiniteNonNegative(now)
		or not isFiniteNonNegative(claimSeconds)
	then
		return state, false
	end
	if state.Generation ~= generation or state.Status ~= STATUS_SENDING or state.Owner ~= owner then
		return state, false
	end
	state.ClaimUntil = now + claimSeconds
	state.UpdatedAt = now
	return state, true
end

function FactoryReadyDeliveryRules.Complete(
	value: any,
	generation: string,
	owner: string,
	now: number
): (DeliveryState, boolean)
	local state = FactoryReadyDeliveryRules.Normalize(value)
	if not isGeneration(generation) or not isOwner(owner) or not isFiniteNonNegative(now) then
		return state, false
	end
	if state.Generation ~= generation or state.Status ~= STATUS_SENDING or state.Owner ~= owner then
		return state, false
	end
	state.Status = STATUS_SENT
	state.Owner = ""
	state.ClaimUntil = 0
	state.UpdatedAt = now
	return state, true
end

function FactoryReadyDeliveryRules.Retry(
	value: any,
	generation: string,
	owner: string,
	retryAt: number,
	now: number
): (DeliveryState, boolean)
	local state = FactoryReadyDeliveryRules.Normalize(value)
	if
		not isGeneration(generation)
		or not isOwner(owner)
		or not isFiniteNonNegative(retryAt)
		or not isFiniteNonNegative(now)
	then
		return state, false
	end
	if state.Generation ~= generation or state.Status ~= STATUS_SENDING or state.Owner ~= owner then
		return state, false
	end
	state.Status = STATUS_SCHEDULED
	state.DueAt = retryAt
	state.Owner = ""
	state.ClaimUntil = 0
	state.UpdatedAt = now
	return state, true
end

function FactoryReadyDeliveryRules.IsOwnedClaim(
	value: any,
	generation: string,
	owner: string,
	now: number
): boolean
	local state = FactoryReadyDeliveryRules.Normalize(value)
	return isGeneration(generation)
		and isOwner(owner)
		and isFiniteNonNegative(now)
		and state.Generation == generation
		and state.Status == STATUS_SENDING
		and state.Owner == owner
		and state.ClaimUntil > now
end

return table.freeze(FactoryReadyDeliveryRules)
