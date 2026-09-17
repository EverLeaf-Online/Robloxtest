# Full Git Content Audit — 2026-09-17

This is the branch-by-branch content reconciliation for `EverLeaf-Online/Robloxtest`. It supersedes the earlier branch-role-only review.

## Result

The canonical runtime remains `main` + `default.project.json`, but this audit went beyond ancestry and inspected the surviving content of every current branch.

The only branch with genuinely surviving implementation content not already represented by the canonical architecture was `backup/main-parallel-implementation-2026-09-17`. Its final tree diverges from the common base by 69 commits / 32 files and uses an obsolete alternative filesystem/service architecture.

That branch is **not safe to merge wholesale**. Useful content was selectively reconciled instead.

## Branch disposition

| Branch | Main comparison at audit | Content disposition |
|---|---:|---|
| `main` | canonical | Runtime source of truth. |
| `docs/branch-runtime-reconciliation-2026-09-17` | 1 behind / 0 ahead | PR #6 merged; no unique content remains. |
| `feat/scrap-to-bot-architecture` | 8 behind / 0 ahead | Fully contained by current `main`. |
| `feat/scrap-to-bot-graybox-loop` | 8 behind / 0 ahead | Fully contained by current `main`. |
| `feat/scrap-to-bot-monetization-engagement` | 8 behind / 0 ahead | Fully contained by current `main`. |
| `fix/scrap-to-bot-post-merge-hardening-2026-09-17` | divergent ancestry | PR #4 was merged; its intended hardening content is represented in `main`. The apparent ahead count is merge/squash ancestry, not required runtime content. |
| `audit/static-security-performance-2026-09-17` | divergent ancestry | PR #5 was merged; its intended audit/hardening content is represented in `main`. The apparent ahead count is merge/squash ancestry. |
| `backup/main-before-reconcile-safety` | 366 behind / 0 ahead | Historical checkpoint; no unique current content. |
| `backup/checkpoint-before-reconcile-files` | 101 behind / 0 ahead | Historical checkpoint; no unique current content. |
| `backup/graybox-before-monetization-reconcile-2026-09-17` | 101 behind / 0 ahead | Historical checkpoint; no unique current content. |
| `backup/main-parallel-implementation-2026-09-17` | 366 behind / 69 ahead | Fully content-audited below; selective ports only. Do not merge wholesale. |

## Parallel implementation final-tree audit

The parallel branch has 32 surviving changed files relative to its merge base. Each one was mapped to the current architecture:

| Parallel file / area | Disposition |
|---|---|
| `default.project.json` | Superseded by current project mapping. Current main also carries the required TextChatService configuration. |
| `selene.toml`, `stylua.toml`, `wally.toml` | Superseded by the current pinned/linted/tested toolchain. |
| `docs/IMPLEMENTATION_STATUS_2026-09-17.md` | Superseded by `LIVE_VALIDATION_STATUS_2026-09-17.md`; useful missing feature notes were audited individually. |
| `docs/ROBLOX_BADGE_IDS.md` | **Ported and refreshed** into the canonical docs. |
| `docs/ROBLOX_CREATOR_DASHBOARD_CONFIG.md` | **Selectively ported and refreshed** as a configuration record; stale implementation checklists were not copied. |
| `docs/ROBLOX_MONETIZATION_IDS.md` | Existing canonical doc retained; **Factory Club subscription data reconciled** into it. |
| old shared `GameConfig`, `Ids`, `ProfileTemplate` | Superseded by `src/shared/Config/*`, domain rules, and current profile template/migrations/sanitizer. |
| old `Bootstrap.server.luau` | Superseded by current split-service bootstrap. |
| `AdminBroadcastService` | Current service is the hardened implementation from PR #4 with creator checks, filtering, MessagingService dedupe, and bounded state. |
| `AnalyticsService` | Current analytics service supersedes the parallel version. |
| `AutoCollectService` | Current `SalvageService` owns Auto-Collect server-side. The parallel spatial-query variant is not needed at the current bounded world size: 8 players × 13 current salvage nodes is about 104 distance checks per 1.25-second sweep. |
| `CosmeticPreferenceService` | Superseded by current Factory Club cosmetic entitlement/state/controller path. |
| `DataService` | Current ProfileStore service has the canonical migrations, sanitizer, transaction boundary, session lock and save path. Offline timestamp handling was selectively reconciled. |
| `EconomyService` | Current economy/domain-rule implementation is more complete. The parallel service bypasses current capacity/transaction rules and is not safe to transplant. |
| `EngagementService` | Superseded by current referral, notification, badge and engagement services. |
| `GameplayService` | Split across current salvage, machine, robot, upgrade, zone and production services. Its bounded offline-production concept was the main useful missing feature and was **ported into current `ProductionService` using current profile/domain rules**. |
| `MachineProcessingService` | Superseded by current `MachineService`. The parallel version also uses integer/`math.ceil` VIP timing and therefore does not solve the current VIP precision issue. |
| `MonetizationService` | Current implementation has the canonical receipt, pass, subscription and entitlement flow. Do not transplant the older service. |
| `NotificationSchedulerService` | Superseded by current `FactoryReadyNotificationService` plus `NotificationService`. |
| `PlayerStateService` | Superseded by current revisioned `StateService` snapshot/delta model. |
| `PresentationService` | Superseded by current plot, robot and entitlement presentation services. |
| `RemoteGuard` | Superseded by current centralized remote names, rate limiting, validation, plot ownership and authoritative distance checks. |
| old `SalvageService` | Superseded by current claim-safe, zone-aware, storage-gated salvage service. |
| `CreatorAdmin.client.luau` | Superseded by current creator admin controller/UI path. |
| `FactoryHUD.client.luau` | Current React `App.lua` is the canonical richer/responsive HUD. The old HUD's Button-Y focus shortcut is intentionally **not transplanted** because it assumes one monolithic HUD and does not provide complete navigation across the current Bots/Upgrades/Index/modal UI. A dedicated full-gamepad navigation pass remains tracked in the production plan. |
| `InteractionController.client.luau` | Superseded by current `WorldInteractionController` plus server-created ProximityPrompts. Copying the old client-created prompts would duplicate interactions. |
| `NotificationOptIn.client.luau` | Superseded by current `NotificationOptInController`. |
| `WorldPresentation.client.luau` | Superseded by current server/client presentation services. |

## Selective ports made by this reconciliation

### Bounded offline production

The parallel implementation contained the only meaningful gameplay feature missing from current `main`: bounded offline bot production.

It was reimplemented against the current architecture rather than copied:

- `src/shared/Domain/OfflineProductionRules.lua`
- `src/shared/__tests__/OfflineProductionRules.spec.lua`
- `src/server/Services/ProductionService.lua`
- `src/server/Services/DataService.lua`

Rules:

- maximum offline window remains `8 hours`;
- offline efficiency remains `50%`;
- the permanent 2× Production pass applies;
- temporary personal/server overclocks do not get retroactively applied while offline;
- only server-owned bot assignments and current server entitlement state are used;
- the grant is applied once per loaded profile/session;
- clean disconnect records both leave and production timestamps to prevent online time from being counted again as offline time;
- production is held until the one-time offline reconciliation finishes, preventing an online tick/offline-grant race;
- the resulting credit update is bounded by the canonical credit cap and replicated with the production delta path.

### Operational documentation

Useful non-code configuration from the parallel branch was retained without restoring stale implementation claims:

- `docs/ROBLOX_BADGE_IDS.md`
- `docs/ROBLOX_CREATOR_DASHBOARD_CONFIG.md`
- Factory Club subscription details in `docs/ROBLOX_MONETIZATION_IDS.md`

## Explicitly rejected/deferred parallel-only ideas

### Old standalone controller HUD navigation

Not merged. Its `ButtonY` toggle and `GuiService.SelectedObject = instantButton` behavior only covers the obsolete monolithic FactoryHUD. Transplanting it would give a false impression of full controller support while leaving the current multi-panel React UI incomplete. The current UI already uses `Activated` actions and ProximityPrompt interaction primitives; explicit focus/selection routing should be implemented against the current React surface as one coherent gamepad QA pass.

### Old Auto-Collect spatial-query implementation

Not merged. Current node count is small and statically bounded, making the current nearest-node scan cheaper and simpler than maintaining an additional spatial-query/tag path. Revisit only if world/node scale increases substantially.

### Old machine/monetization implementations

Not merged. They are older than current server-authority and receipt hardening, and the old assembler implementation retains the same integer VIP-duration precision problem already identified in the current audit.

## Remaining issues are not branch-reconciliation gaps

The separate static audit identified current-main defects such as Factory Club transactional storage capacity, VIP assembler duration precision, client +2-slot double counting, Server Overclock durability, long-term receipt idempotency, and Factory Club billing-cycle fallback behavior. Those are defects in the canonical implementation, not useful code stranded on another branch. None of the audited branches contains a safer drop-in solution for them.

They should be fixed on normal short-lived fix branches after this reconciliation, not by restoring obsolete branch architecture.

## Cleanup gate

After this reconciliation PR passes CI/OCALE and is merged, the following branch pointers contain no required unique game content and can be removed from the remote:

- `docs/branch-runtime-reconciliation-2026-09-17`
- `feat/scrap-to-bot-architecture`
- `feat/scrap-to-bot-graybox-loop`
- `feat/scrap-to-bot-monetization-engagement`
- `fix/scrap-to-bot-post-merge-hardening-2026-09-17`
- `audit/static-security-performance-2026-09-17`
- `backup/main-before-reconcile-safety`
- `backup/checkpoint-before-reconcile-files`
- `backup/graybox-before-monetization-reconcile-2026-09-17`
- `backup/main-parallel-implementation-2026-09-17`

Git history and merged PRs preserve the commits. The parallel branch should only be deleted after this selective-port PR is merged successfully.
