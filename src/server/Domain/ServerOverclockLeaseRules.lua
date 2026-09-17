--!strict

local ServerOverclockLeaseRules = {}

export type LeaseRecord = {
	BoostUntil: number,
	OwnerJobId: string,
	LeaseUntil: number,
	UpdatedAt: number,
	AppliedPurchases: { [string]: boolean },
}

local function cloneApplied(source: { [string]: boolean }): { [string]: boolean }
	local result: { [string]: boolean } = {}
	for purchaseId, applied in source do
		if applied == true then
			result[purchaseId] = true
		end
	end
	return result
end

function ServerOverclockLeaseRules.Normalize(value: any): LeaseRecord
	local record = if typeof(value) == "table" then value else {}
	local sourceApplied = if typeof(record.AppliedPurchases) == "table"
		then record.AppliedPurchases
		else {}
	return {
		BoostUntil = if typeof(record.BoostUntil) == "number" then record.BoostUntil else 0,
		OwnerJobId = if typeof(record.OwnerJobId) == "string" then record.OwnerJobId else "",
		LeaseUntil = if typeof(record.LeaseUntil) == "number" then record.LeaseUntil else 0,
		UpdatedAt = if typeof(record.UpdatedAt) == "number" then record.UpdatedAt else 0,
		AppliedPurchases = cloneApplied(sourceApplied),
	}
end

function ServerOverclockLeaseRules.CanClaim(
	record: LeaseRecord,
	sessionId: string,
	now: number
): boolean
	return record.OwnerJobId == "" or record.OwnerJobId == sessionId or record.LeaseUntil <= now
end

function ServerOverclockLeaseRules.ApplyPurchase(
	record: LeaseRecord,
	sessionId: string,
	purchaseId: string,
	now: number,
	boostSeconds: number,
	leaseSeconds: number
): (LeaseRecord, boolean)
	local nextRecord = ServerOverclockLeaseRules.Normalize(record)
	if not ServerOverclockLeaseRules.CanClaim(nextRecord, sessionId, now) then
		return nextRecord, false
	end

	if nextRecord.AppliedPurchases[purchaseId] ~= true then
		nextRecord.BoostUntil = math.max(nextRecord.BoostUntil, now) + boostSeconds
		nextRecord.AppliedPurchases[purchaseId] = true
	end
	nextRecord.OwnerJobId = sessionId
	nextRecord.LeaseUntil = now + leaseSeconds
	nextRecord.UpdatedAt = now
	return nextRecord, true
end

function ServerOverclockLeaseRules.Claim(
	record: LeaseRecord,
	sessionId: string,
	now: number,
	leaseSeconds: number
): (LeaseRecord, boolean)
	local nextRecord = ServerOverclockLeaseRules.Normalize(record)
	if nextRecord.BoostUntil <= now then
		return nextRecord, false
	end
	if not ServerOverclockLeaseRules.CanClaim(nextRecord, sessionId, now) then
		return nextRecord, false
	end

	nextRecord.OwnerJobId = sessionId
	nextRecord.LeaseUntil = now + leaseSeconds
	nextRecord.UpdatedAt = now
	return nextRecord, true
end

function ServerOverclockLeaseRules.Renew(
	record: LeaseRecord,
	sessionId: string,
	now: number,
	leaseSeconds: number
): (LeaseRecord, boolean)
	local nextRecord = ServerOverclockLeaseRules.Normalize(record)
	if nextRecord.OwnerJobId ~= sessionId or nextRecord.BoostUntil <= now then
		return nextRecord, false
	end
	nextRecord.LeaseUntil = now + leaseSeconds
	nextRecord.UpdatedAt = now
	return nextRecord, true
end

function ServerOverclockLeaseRules.Release(
	record: LeaseRecord,
	sessionId: string,
	now: number
): LeaseRecord
	local nextRecord = ServerOverclockLeaseRules.Normalize(record)
	if nextRecord.OwnerJobId == sessionId then
		nextRecord.OwnerJobId = ""
		nextRecord.LeaseUntil = 0
		nextRecord.UpdatedAt = now
	end
	return nextRecord
end

return table.freeze(ServerOverclockLeaseRules)
