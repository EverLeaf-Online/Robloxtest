--!strict

-- Historical paid-receipt recovery is intentionally opt-in and case-by-case.
--
-- Add a case here only after independently verifying the Roblox purchase and a
-- durable pre-grant profile snapshot. ReceiptRecoveryService will refuse to
-- grant unless:
--   1. the lifetime receipt ledger already contains PurchaseId;
--   2. the dedicated recovery audit does not already contain PurchaseId;
--   3. the live profile exactly matches the expected revision/product state.
--
-- Never populate a case from the player's current profile alone. Expected
-- values must come from incident evidence or a known durable backup.
--
-- Example shape:
-- {
--     UserId = 123456,
--     PurchaseId = "purchase-id-from-roblox",
--     ProductId = 3713191584,
--     EvidenceReference = "support-ticket-or-incident-id",
--     ExpectedRevision = 42,
--     ExpectedInstantProcessTokens = 7,
-- }

local HistoricalReceiptRecoveries = {}

return table.freeze(HistoricalReceiptRecoveries)
