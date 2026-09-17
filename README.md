# Robloxtest — Profit-First Roblox Simulation Project

Status: **First playable live validation / monetization-engagement hardening**  
Current validation status: **2026-09-17**

This repository contains the current Scrap-to-Bot Factory prototype and supporting production research for a Roblox simulation game whose primary business objective is sustainable Robux revenue and eventual DevEx profit.

## Current rule

**Implementation follows `docs/MASTER_PRODUCTION_PLAN.md`, while the newest execution/test truth is tracked in `docs/LIVE_VALIDATION_STATUS_2026-09-17.md`. Research findings, playtest data, or platform changes may justify deliberate revisions, but gameplay should not drift ad hoc.**

## Git / Rojo runtime source of truth

For normal Roblox Studio development and playtesting, use **Git branch `main` with `default.project.json`**. Rojo serves one checked-out working tree; historical feature branches are not simultaneously layered into Studio.

The full repository content audit is recorded in `docs/FULL_GIT_CONTENT_AUDIT_2026-09-17.md`. That audit inspected the divergent parallel implementation and every surviving legacy branch, selectively ported bounded offline production and useful configuration documentation into the canonical architecture, and explicitly rejected obsolete duplicate service/UI implementations. The legacy backup/feature/audit branch refs from that reconciliation were then removed.

`test.project.json` is reserved for the dedicated Jest/OCALE test project. Merged short-lived development branches may temporarily remain as Git housekeeping refs, but they are not runtime layers and contain no required content once their work is verified in `main`.

See `docs/BRANCH_RUNTIME_RECONCILIATION_2026-09-17.md` for the runtime/branch rule and `docs/FULL_GIT_CONTENT_AUDIT_2026-09-17.md` for the full content-level audit.

The active production candidate is **Scrap-to-Bot Factory**: collect salvage, process it through a visibly growing personal factory, assemble collectible robots, assign those robots to automate production, expand into better zones, and eventually progress into higher factory tiers.

We are optimizing for:

- strong play-through rate and low first-session bounce;
- D1, D7, and D28 repeat play;
- qualified repeat sessions and intentional co-play;
- payer conversion, spend days, ARPPU, and Robux/user;
- a very simple premise that is understandable in seconds;
- low development cost per content update;
- mobile-first performance and controls;
- server-authoritative economy and purchase handling;
- monetization that accelerates or customizes play without making free progression non-viable.

## Current execution state

The first playable is implemented and has moved beyond planning-only status. Current verified work includes:

- server-authoritative salvage, processing, assembly, robot ownership/assignment, production, upgrades, and zone progression;
- ProfileStore-backed persistence with real published-game reconnect validation;
- live persistence verified for Credits, materials, robots, assignments, upgrades, and zone progression;
- configured passes, Developer Products, Factory Club subscription, badges, referrals, and experience-notification IDs;
- Studio verification of pass benefits, paid product grants, overclock extension behavior, Factory Club benefits, and receipt idempotency/replay;
- live notification opt-in path verified, with the experience shown as notification-enabled on the test account;
- `FactoryReady` delivery left pending until the experience reaches Roblox's required visit threshold for meaningful delivery testing;
- real charged-Robux receipts and a real Factory Club subscription remain intentionally unverified because the current test account has no Robux available for those production purchases.

See `docs/LIVE_VALIDATION_STATUS_2026-09-17.md` for the exact verified/pending matrix.

## Planning and research documents

- `docs/BRANCH_RUNTIME_RECONCILIATION_2026-09-17.md` — **Git/Rojo runtime source of truth** and branch-switch safety rules.
- `docs/FULL_GIT_CONTENT_AUDIT_2026-09-17.md` — **full content-level reconciliation** of the legacy branch stack, selective ports, rejected duplicate implementations, and cleanup disposition.
- `docs/LIVE_VALIDATION_STATUS_2026-09-17.md` — **current authoritative execution status** for published persistence, monetization, receipt, Factory Club, and notification validation.
- `docs/MASTER_PRODUCTION_PLAN.md` — **implementation blueprint**: locked v1 scope, first-session/30-minute progression, economy rules, profile model, service architecture, networking contract, security gates, UI/art plan, analytics, monetization, testing, production phases, exit criteria, and implementation order.
- `docs/FIRST_PLAYABLE_STATUS_2026-09-16.md` — historical first-playable implementation/static-validation snapshot; use the 2026-09-17 live status for newer runtime results.
- `docs/ROBLOX_GAME_PRODUCTION_RESEARCH_MASTER_2026-09-16.md` — **master research gate** covering product design, architecture, networking, exploit resistance, persistence, economy, monetization, analytics, UI/input, performance, testing, assets, publishing/operations, safety, discovery, and remaining research questions.
- `docs/ROBLOX_CREATOR_HUB_BASELINE.md` — **primary implementation authority**, converting current official Roblox Creator Hub guidance into project rules for design, analytics, monetization, security, persistence, mobile UX, and performance.
- `docs/ROBLOX_OFFICIAL_GITHUB_RESEARCH_2026-09-16.md` — audit of the official `Roblox` GitHub organization, including current UI/testing/Open Cloud/data-operations/asset tooling and stale/archived projects to avoid as new foundations.
- `docs/GITHUB_ECOSYSTEM_RESEARCH_2026-09-16.md` — curated current Roblox/Luau OSS ecosystem, toolchain modernization, library candidates, archived projects to avoid, and the proposed clean-project stack.
- `docs/UNCOPYLOCKED_ARCHIVE_RESEARCH_2026-09-16.md` — provenance/licensing review of a large third-party uncopylocked-game archive plus high-level simulator/tycoon design lessons that may be studied without copying its code/assets.
- `docs/MARKET_RESEARCH_2026-09-16.md` — current Roblox market, discovery, retention, and competitor findings.
- `docs/PRODUCT_STRATEGY.md` — product requirements, concept shortlist, and current recommended direction.
- `docs/MONETIZATION_AND_SECURITY.md` — revenue architecture, compliance, persistence, receipts, and exploit threat model.
- `docs/EXPLOIT_THREAT_RESEARCH.md` — defensive analysis of historical public exploit and reverse-engineering repositories, translated into server-authoritative simulator requirements.
- `docs/VALIDATION_PLAN.md` — prototype and KPI validation gates before scaling development or advertising.

## Source hierarchy

When implementation guidance conflicts, use sources in this order:

1. Roblox Creator Hub / current official API and policy documentation (`https://create.roblox.com/docs`);
2. `https://github.com/Roblox/creator-docs`, the searchable public Creator documentation source synchronized from Roblox internal docs;
3. current, relevant repositories under `https://github.com/Roblox` and official Luau sources, after checking maintenance/archive status;
4. Roblox staff platform announcements;
5. our own live analytics and experiments;
6. reviewed maintained OSS dependencies with compatible licenses;
7. competitor/market research;
8. community discussion;
9. old scripts/tutorials and third-party game archives only as historical/design/exploit references.

**Official ownership alone is not enough.** Archived or stale Roblox repositories are treated as historical references unless current Creator Hub guidance or a maintained replacement says otherwise.
