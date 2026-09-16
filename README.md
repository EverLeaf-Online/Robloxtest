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
- `docs/MARKET_RESEARCH_2026-09-16.md` — current Roblox market, discovery, retention, and competitor findings.
- `docs/PRODUCT_STRATEGY.md` — product requirements, concept shortlist, and current recommended direction.
- `docs/MONETIZATION_AND_SECURITY.md` — revenue architecture, compliance, persistence, receipts, and exploit threat model.
- `docs/VALIDATION_PLAN.md` — prototype and KPI validation gates before scaling development or advertising.

## Source hierarchy

When implementation guidance conflicts, use sources in this order:

1. Roblox Creator Hub / current official API and policy documentation (`https://create.roblox.com/docs`);
2. Roblox staff platform announcements;
3. our own live analytics and experiments;
4. competitor/market research;
5. community discussion;
6. old scripts/tutorials only as historical or exploit references.

## Historical code

The previous **Grow a Tiny Planet** source was intentionally removed from `main` on 2026-09-16, but remains recoverable from Git history. Commit `79875d7599e4ddd44d5433e9683ed5c1e07335ff` is a useful pre-deletion reference for persistence, receipt handling, and service organization. We will selectively reuse proven architectural ideas rather than restoring the old game wholesale.

## Reference exploit repository

`https://github.com/retpirato/Roblox-Scripts` is treated only as a historical exploit/threat catalog. Its client exploit scripts are **not production dependencies and must never be imported into the game**.
