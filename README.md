# Robloxtest — Profit-First Roblox Simulation Project

Status: **Production planning locked / implementation not yet started**  
Research baseline: **2026-09-16**

This repository is being rebuilt from a clean `main` branch for a new Roblox simulation game whose primary business objective is sustainable Robux revenue and eventual DevEx profit.

## Current rule

**Implementation follows `docs/MASTER_PRODUCTION_PLAN.md`. Research findings, playtest data, or platform changes may justify deliberate revisions, but gameplay should not drift ad hoc.**

For this project, "research" does **not** mean only identifying a trending genre. It means understanding the full production system required to design, build, secure, test, publish, monetize, measure, operate, update, and grow the game. The master research gate is documented in `docs/ROBLOX_GAME_PRODUCTION_RESEARCH_MASTER_2026-09-16.md`.

The first production candidate is **Scrap-to-Bot Factory**: collect salvage, process it through a visibly growing personal factory, assemble collectible robots, assign those robots to automate production, expand into better zones, and eventually progress into higher factory tiers.

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

## Planning and research documents

- `docs/MASTER_PRODUCTION_PLAN.md` — **implementation blueprint**: locked v1 scope, first-session/30-minute progression, economy rules, profile model, service architecture, networking contract, security gates, UI/art plan, analytics, monetization, testing, production phases, exit criteria, and implementation order.
- `docs/ROBLOX_GAME_PRODUCTION_RESEARCH_MASTER_2026-09-16.md` — **master research gate** covering product design, architecture, networking, exploit resistance, persistence, economy, monetization, analytics, UI/input, performance, testing, assets, publishing/operations, safety, discovery, and the remaining unanswered research questions before production starts.
- `docs/ROBLOX_CREATOR_HUB_BASELINE.md` — **primary implementation authority**, converting current official Roblox Creator Hub guidance into project rules for design, analytics, monetization, security, persistence, mobile UX, and performance.
- `docs/ROBLOX_OFFICIAL_GITHUB_RESEARCH_2026-09-16.md` — audit of the official `Roblox` GitHub organization, including current UI/testing/Open Cloud/data-operations/asset tooling and stale/archived projects to avoid as new foundations.
- `docs/GITHUB_ECOSYSTEM_RESEARCH_2026-09-16.md` — curated current Roblox/Luau OSS ecosystem, toolchain modernization, library candidates, archived projects to avoid, and the proposed clean-project stack.
- `docs/UNCOPYLOCKED_ARCHIVE_RESEARCH_2026-09-16.md` — provenance/licensing review of a large third-party uncopylocked-game archive plus high-level simulator/tycoon design lessons that may be studied without copying its code/assets.
- `docs/MARKET_RESEARCH_2026-09-16.md` — current Roblox market, discovery, retention, and competitor findings.
- `docs/PRODUCT_STRATEGY.md` — product requirements, concept shortlist, and current recommended direction.
- `docs/MONETIZATION_AND_SECURITY.md` — revenue architecture, compliance, persistence, receipts, and exploit threat model.
- `docs/EXPLOIT_THREAT_RESEARCH.md` — defensive analysis of historical public exploit and reverse-engineering repositories, including remote spying and runtime introspection, translated into server-authoritative simulator requirements.
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

**Public availability is not a commercial-use license.** Third-party `.rbxl`/`.rbxlx` archives with unclear provenance are not code or asset sources for this project. We may study general mechanics and then implement original systems/assets from scratch.

## Historical code

The previous **Grow a Tiny Planet** source was intentionally removed from `main` on 2026-09-16, but remains recoverable from Git history. Commit `79875d7599e4ddd44d5433e9683ed5c1e07335ff` is a useful pre-deletion reference for persistence, receipt handling, and service organization. We will selectively reuse proven architectural ideas rather than restoring the old game wholesale.

## Reference exploit / reverse-engineering repositories

The following repositories are treated only as historical exploit/threat catalogs:

- `https://github.com/retpirato/Roblox-Scripts`
- `https://github.com/Stefanuk12/ROBLOX`
- `https://github.com/Upbolt/Hydroxide`

Their exploit/reverse-engineering code is **not a production dependency and must never be imported into the game**. They are used to identify threat classes such as remote spoofing and capture, autofarming, teleport collection, anti-cheat bypass, client function hooking, runtime constant/upvalue inspection, hidden-key extraction, ESP, and progression automation so the simulator can be hardened server-side from the beginning.

The security assumption is simple: if a value or decision exists on the client, a capable attacker may be able to observe or alter it. Durable value must therefore be authorized and calculated server-side.

## Reference-only game archive

`https://github.com/IIIStatusIII/Roblox-Uncopylocked-Games` is treated only as design archaeology. Its README says the files came from multiple third-party sources and do not belong to the repository owner, and the repository has no license establishing commercial reuse rights. Do not copy its games, scripts, maps, UI, assets, branding, or third-party IP into Robloxtest.
