--!strict

export type Eligibility = "Pending" | "Eligible" | "Rejected"

export type ProgressRecord = {
	InviterUserId: number,
	StartedAt: number,
	ActivePlaySeconds: number,
	Eligibility: Eligibility,
	Qualified: boolean,
	UpdatedAt: number,
}

local ReferralProgressRules = {}

local function clampInteger(value: any, minimum: number, maximum: number, fallback: number): number
	if typeof(value) ~= "number" or value ~= value or value % 1 ~= 0 then
		return fallback
	end
	return math.clamp(value, minimum, maximum)
end

local function normalizeEligibility(value: any): Eligibility
	if value == "Eligible" or value == "Rejected" then
		return value
	end
	return "Pending"
end

function ReferralProgressRules.Normalize(raw: any, qualificationSeconds: number): ProgressRecord
	local source = if typeof(raw) == "table" then raw else {}
	local inviterUserId = clampInteger(source.InviterUserId, 0, 2_147_483_647, 0)
	local eligibility = normalizeEligibility(source.Eligibility)
	if inviterUserId == 0 then
		eligibility = "Rejected"
	end

	return {
		InviterUserId = inviterUserId,
		StartedAt = clampInteger(source.StartedAt, 0, 4_102_444_800, 0),
		ActivePlaySeconds = clampInteger(
			source.ActivePlaySeconds,
			0,
			math.max(0, qualificationSeconds),
			0
		),
		Eligibility = eligibility,
		Qualified = source.Qualified == true,
		UpdatedAt = clampInteger(source.UpdatedAt, 0, 4_102_444_800, 0),
	}
end

function ReferralProgressRules.Capture(
	raw: any,
	inviterUserId: number,
	now: number,
	qualificationSeconds: number
): (ProgressRecord, boolean, string)
	local existing = ReferralProgressRules.Normalize(raw, qualificationSeconds)
	if existing.InviterUserId > 0 then
		return existing, false, "INVITER_ALREADY_CAPTURED"
	end
	if inviterUserId <= 0 or inviterUserId % 1 ~= 0 then
		return existing, false, "INVITER_INVALID"
	end

	return {
		InviterUserId = inviterUserId,
		StartedAt = math.max(0, math.floor(now)),
		ActivePlaySeconds = 0,
		Eligibility = "Pending",
		Qualified = false,
		UpdatedAt = math.max(0, math.floor(now)),
	},
		true,
		"INVITER_CAPTURED"
end

function ReferralProgressRules.SetEligibility(
	raw: any,
	isEligible: boolean,
	now: number,
	qualificationSeconds: number
): ProgressRecord
	local record = ReferralProgressRules.Normalize(raw, qualificationSeconds)
	if record.InviterUserId == 0 or record.Qualified then
		return record
	end

	record.Eligibility = if isEligible then "Eligible" else "Rejected"
	record.UpdatedAt = math.max(record.UpdatedAt, math.max(0, math.floor(now)))
	return record
end

function ReferralProgressRules.AddActiveSeconds(
	raw: any,
	elapsedSeconds: number,
	now: number,
	qualificationSeconds: number
): (ProgressRecord, boolean)
	local record = ReferralProgressRules.Normalize(raw, qualificationSeconds)
	if
		record.InviterUserId == 0
		or record.Eligibility == "Rejected"
		or record.Qualified
		or elapsedSeconds <= 0
	then
		return record, false
	end

	local previous = record.ActivePlaySeconds
	record.ActivePlaySeconds = math.min(
		math.max(0, qualificationSeconds),
		previous + math.max(0, math.floor(elapsedSeconds))
	)
	record.UpdatedAt = math.max(record.UpdatedAt, math.max(0, math.floor(now)))

	return record,
		previous < qualificationSeconds and record.ActivePlaySeconds >= qualificationSeconds
end

function ReferralProgressRules.MarkQualified(
	raw: any,
	now: number,
	qualificationSeconds: number
): ProgressRecord
	local record = ReferralProgressRules.Normalize(raw, qualificationSeconds)
	if
		record.InviterUserId > 0
		and record.Eligibility == "Eligible"
		and record.ActivePlaySeconds >= qualificationSeconds
	then
		record.Qualified = true
		record.UpdatedAt = math.max(record.UpdatedAt, math.max(0, math.floor(now)))
	end
	return record
end

function ReferralProgressRules.ShouldTrack(raw: any, qualificationSeconds: number): boolean
	local record = ReferralProgressRules.Normalize(raw, qualificationSeconds)
	return record.InviterUserId > 0
		and record.Eligibility ~= "Rejected"
		and record.Qualified ~= true
end

function ReferralProgressRules.CanFinalize(raw: any, qualificationSeconds: number): boolean
	local record = ReferralProgressRules.Normalize(raw, qualificationSeconds)
	return record.InviterUserId > 0
		and record.Eligibility == "Eligible"
		and record.Qualified ~= true
		and record.ActivePlaySeconds >= qualificationSeconds
end

return table.freeze(ReferralProgressRules)
