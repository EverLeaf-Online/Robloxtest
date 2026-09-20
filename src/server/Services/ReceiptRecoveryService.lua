--!strict

local DataService = require(script.Parent.DataService)
local MonetizationService = require(script.Parent.MonetizationService)
local HistoricalReceiptRecoveries = require(script.Parent.Parent.Data.HistoricalReceiptRecoveries)
local ReceiptRecoveryRules = require(script.Parent.Parent.Domain.ReceiptRecoveryRules)

type RecoveryEvidence = ReceiptRecoveryRules.RecoveryEvidence

local ReceiptRecoveryService = {}
local initialized = false

local MAX_CONFIGURED_CASES = 100
local casesByUserId: { [number]: { RecoveryEvidence } } = {}

local function indexConfiguredCases()
	local configured = HistoricalReceiptRecoveries :: { RecoveryEvidence }
	if #configured > MAX_CONFIGURED_CASES then
		warn(
			("[ReceiptRecoveryService] Refusing %d configured cases; maximum is %d"):format(
				#configured,
				MAX_CONFIGURED_CASES
			)
		)
		return
	end

	local seen: { [string]: boolean } = {}
	for _, evidence in configured do
		local valid, code = ReceiptRecoveryRules.ValidateEvidence(evidence)
		if not valid then
			warn(
				("[ReceiptRecoveryService] Invalid recovery case for user %s (%s): %s"):format(
					tostring(evidence.UserId),
					tostring(evidence.EvidenceReference),
					code
				)
			)
			continue
		end

		local uniqueKey = ("%d:%s"):format(evidence.UserId, evidence.PurchaseId)
		if seen[uniqueKey] then
			warn(
				("[ReceiptRecoveryService] Duplicate recovery case for user %d (%s)"):format(
					evidence.UserId,
					evidence.EvidenceReference
				)
			)
			continue
		end
		seen[uniqueKey] = true

		local userCases = casesByUserId[evidence.UserId]
		if userCases == nil then
			userCases = {}
			casesByUserId[evidence.UserId] = userCases
		end
		table.insert(userCases, evidence)
	end
end

local function recoverForPlayer(player: Player)
	local userCases = casesByUserId[player.UserId]
	if userCases == nil then
		return
	end

	for _, evidence in userCases do
		local success, code = MonetizationService.RecoverHistoricalReceipt(player, evidence)
		if success then
			print(
				("[ReceiptRecoveryService] %s for user %d (%s)"):format(
					code,
					player.UserId,
					evidence.EvidenceReference
				)
			)
		else
			warn(
				("[ReceiptRecoveryService] Recovery refused for user %d (%s): %s"):format(
					player.UserId,
					evidence.EvidenceReference,
					code
				)
			)
		end
	end
end

function ReceiptRecoveryService.Init()
	if initialized then
		return
	end
	initialized = true

	indexConfiguredCases()
	if next(casesByUserId) == nil then
		return
	end

	DataService.ProfileLoaded:Connect(function(player)
		task.spawn(recoverForPlayer, player)
	end)
end

return ReceiptRecoveryService
