# Robloxtest — Profit-First Roblox Simulation Project

Status: **Research / product design**  
Research baseline: **2026-09-16**

This repository is being rebuilt from a clean `main` branch for a new Roblox simulation game whose primary business objective is sustainable Robux revenue and eventual DevEx profit.

## Current rule

**Do not begin production gameplay implementation until the research and product brief are locked.**

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

## Research documents

- `docs/ROBLOX_CREATOR_HUB_BASELINE.md` — **primary implementation authority**, converting current official Roblox Creator Hub guidance into project rules for design, analytics, monetization, security, persistence, mobile UX, and performance.
- `docs/ROBLOX_OFFICIAL_GITHUB_RESEARCH_2026-09-16.md` — audit of the official `Roblox` GitHub organization, including current UI/testing/Open Cloud/data-operations/asset tooling and stale/archived projects to avoid as new foundations.
- `docs/GITHUB_ECOSYSTEM_RESEARCH_2026-09-16.md` — curated current Roblox/Luau OSS ecosystem, toolchain modernization, library candidates, archived projects to avoid, and the proposed clean-project stack.
- `docs/MARKET_RESEARCH_2026-09-16.md` — current Roblox market, discovery, retention, and competitor findings.
- `docs/PRODUCT_STRATEGY.md` — product requirements, concept shortlist, and current recommended direction.
- `docs/MONETIZATION_AND_SECURITY.md` — revenue architecture, compliance, persistence, receipts, and exploit threat model.
- `docs/EXPLOIT_THREAT_RESEARCH.md` — defensive analysis of historical public exploit repositories, translated into server-authoritative simulator requirements.
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
9. old scripts/tutorials only as historical or exploit references.

**Official ownership alone is not enough.** Archived or stale Roblox repositories are treated as historical references unless current Creator Hub guidance or a maintained replacement says otherwise.

## Historical code

The previous **Grow a Tiny Planet** source was intentionally removed from `main` on 2026-09-16, but remains recoverable from Git history. Commit `79875d7599e4ddd44d5433e9683ed5c1e07335ff` is a useful pre-deletion reference for persistence, receipt handling, and service organization. We will selectively reuse proven architectural ideas rather than restoring the old game wholesale.

## Reference exploit repositories

The following repositories are treated only as historical exploit/threat catalogs:

- `https://github.com/retpirato/Roblox-Scripts`
- `https://github.com/Stefanuk12/ROBLOX`

Their client exploit scripts are **not production dependencies and must never be imported into the game**. They are used to identify threat classes such as remote spoofing, autofarming, teleport collection, anti-cheat bypass, client function hooking, hidden-key extraction, ESP, and progression automation so the simulator can be hardened server-side from the beginning.
