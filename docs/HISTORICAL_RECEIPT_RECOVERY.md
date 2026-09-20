# Historical Developer-Product Receipt Recovery

This path exists only for purchases affected by the historical receipt-ledger ordering bug.

It is **not** a general grant tool and is never exposed through a RemoteEvent.

## Safety model

A configured recovery is refused unless all of the following are true:

1. The player's ProfileStore session is active.
2. `UserId`, `PurchaseId`, `ProductId`, and `EvidenceReference` are valid.
3. The lifetime receipt ledger already contains the exact `PurchaseId`.
4. The dedicated receipt-recovery audit does not already contain the exact `PurchaseId`.
5. The profile does not already have the receipt, or that receipt can be durably confirmed.
6. The current profile revision and every product-specific expected field exactly match the configured evidence.
7. The recovered receipt and reward are durably confirmed by `DataService.SaveNow` before the recovery audit is written.

If the recovery-audit write fails after the profile save succeeds, a retry observes the durable profile receipt and records the audit without granting the product again.

## Evidence requirements

Do not create a case from the player's current profile alone.

`Expected*` values must come from independent incident evidence, such as a known durable profile backup captured before the missing grant, and the Roblox purchase record must independently confirm the exact purchase ID and product.

Every case requires:

- `UserId`
- `PurchaseId`
- `ProductId`
- `EvidenceReference`
- `ExpectedRevision`

Product-specific fields:

- Material Supply Crate: `ExpectedScrapMetal`, `ExpectedWiring`, `ExpectedPowerCoreFragments`
- Factory Overclock 15m: `ExpectedPersonalOverclockUntil`
- Instant Process Tokens: `ExpectedInstantProcessTokens`
- Starter Pack: `ExpectedCredits`, all three expected material counts, `ExpectedInstantProcessTokens`, `ExpectedStarterPackClaimed`
- Server Overclock: `ExpectedServerOverclockUntil`

## Running one recovery

Add the verified case to:

`src/server/Data/HistoricalReceiptRecoveries.lua`

Merge through the normal reviewed/CI path and publish only when intentionally performing that recovery.

When that user loads an owned Factory profile, `ReceiptRecoveryService` evaluates the configured case. It either logs a refusal code without mutation, confirms an already-recorded receipt without regranting, or applies the exact product once and durably records the recovery audit.

After the successful recovery has been verified, remove the case from `HistoricalReceiptRecoveries.lua` in a follow-up change. The recovery-audit DataStore remains as the permanent duplicate-grant guard.

## Important limitation

A ledger-only mismatch is not proof that a player missed their reward. The profile receipt history is intentionally bounded, so old legitimate receipt IDs can disappear from the profile while remaining in the lifetime ledger.

For that reason there is no global scan-and-regrant migration.
