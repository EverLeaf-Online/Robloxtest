--!strict

local TransactionRules = {}

local function deepCopy(value: any, seen: { [any]: any }): any
	if typeof(value) ~= "table" then
		return value
	end

	local existing = seen[value]
	if existing ~= nil then
		return existing
	end

	local copy = {}
	seen[value] = copy
	for key, child in value do
		copy[deepCopy(key, seen)] = deepCopy(child, seen)
	end
	return copy
end

local function replaceContents(target: any, source: any)
	table.clear(target)
	for key, value in source do
		target[key] = value
	end
end

function TransactionRules.Execute(
	liveData: any,
	transaction: (any) -> (boolean, any?),
	prepareCommit: ((any) -> ())?
): (boolean, any?, string?)
	assert(typeof(liveData) == "table", "live transaction data must be a table")

	local draft = deepCopy(liveData, {})
	local ok, shouldCommit, result = pcall(transaction, draft)
	if not ok then
		return false, "TRANSACTION_FAILED", tostring(shouldCommit)
	end

	if shouldCommit ~= true then
		return true, result, nil
	end

	if prepareCommit ~= nil then
		local prepared, prepareError = pcall(prepareCommit, draft)
		if not prepared then
			return false, "TRANSACTION_FAILED", tostring(prepareError)
		end
	end

	replaceContents(liveData, draft)
	return true, result, nil
end

return table.freeze(TransactionRules)
