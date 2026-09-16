--!strict

local ReceiptRules = {}

local MAX_SOURCE_INDEX = 1_000_000

local function isBoundedString(value: any, maxLength: number): boolean
	return typeof(value) == "string" and #value > 0 and #value <= maxLength
end

function ReceiptRules.NormalizeRecentPurchaseIds(
	source: any,
	maxEntries: number,
	maxLength: number
): { string }
	if typeof(source) ~= "table" or maxEntries <= 0 or maxLength <= 0 then
		return {}
	end

	local indices = {}
	for key in source do
		if
			typeof(key) == "number"
			and key % 1 == 0
			and key >= 1
			and key <= MAX_SOURCE_INDEX
		then
			table.insert(indices, key)
		end
	end
	table.sort(indices)

	local seen: { [string]: boolean } = {}
	local reverse: { string } = {}
	for index = #indices, 1, -1 do
		local purchaseId = source[indices[index]]
		if
			isBoundedString(purchaseId, maxLength)
			and seen[purchaseId :: string] ~= true
		then
			seen[purchaseId :: string] = true
			table.insert(reverse, purchaseId :: string)
			if #reverse >= maxEntries then
				break
			end
		end
	end

	local normalized: { string } = {}
	for index = #reverse, 1, -1 do
		table.insert(normalized, reverse[index])
	end
	return normalized
end

return table.freeze(ReceiptRules)
