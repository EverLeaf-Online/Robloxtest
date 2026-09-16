# Phase A — Architecture Status

Baseline: 2026-09-16  
Branch: `feat/scrap-to-bot-architecture`

This document distinguishes what is implemented from what is merely selected or configured. No item is considered proven until its corresponding verification step has run.

## Locked decisions

- Source workflow: Rojo.
- Toolchain manager: Rokit, not Aftman.
- Package manager: Wally with committed manifest/lockfile once generated.
- Formatter: StyLua.
- Linter: Selene.
- Persistence: official `MadStudioRoblox/ProfileStore`, consumed through its own Wally package `lm-loleris/profilestore@1.0.3`.
- UI: official React Luau + ReactRoblox `17.3.11`.
- Tests: Roblox Jest `3.20.1`.
- Server architecture: explicit services; no Knit/framework service container.
- Network architecture: narrow action remotes, server-authoritative outcomes, profile-readiness gate, per-action token-bucket limits.

## Why React won the UI spike

### React Luau / ReactRoblox

Chosen because:

- current official Roblox packages are available through Wally;
- official repository activity is current;
- component/state architecture is suitable for shop, index, upgrades, objectives, collection lists, and responsive HUDs;
- Jest/React-oriented testing support is materially better than hand-wiring every screen;
- we can keep economic state outside React and treat React only as presentation.

### Fusion

Not selected for the production foundation because the latest tagged GitHub release is still `v0.3-beta` while the repository manifest is already on a `0.4.0-dev1` line. It remains a strong library, but this project benefits more from the current official Roblox React path than from adopting a beta/dev-moving foundation.

### Plain Roblox UI

Rejected as the primary architecture because the game is expected to have a shop, collection index, upgrade screens, settings, objectives, responsive mobile layouts, and later LiveOps surfaces. Plain Instance construction would minimize dependencies but increase manual state synchronization, cleanup, and UI regression risk.

## Implemented on the architecture branch

### Tooling

- `rokit.toml` with pinned Rojo/Wally/StyLua/Selene versions.
- `wally.toml` with pinned React, ReactRoblox, ProfileStore, Jest, and JestGlobals dependencies.
- `stylua.toml`.
- `selene.toml`.
- `.gitignore` for generated package/build artifacts.
- shipping `default.project.json`.
- isolated `test.project.json`.

### Shared contracts

- global economy/world/network safety limits;
- three-material catalog;
- twelve-bot graybox catalog;
- four rarity tiers;
- controlled first-reveal pool;
- initial processor/assembler/storage/work-slot upgrade curves;
- explicit remote names;
- hostile-input validation helpers.

### Persistence

- versioned profile template;
- migration pipeline before reconciliation;
- loaded-profile sanitizer and bounds enforcement;
- official ProfileStore session lifecycle wrapper;
- automatic ProfileStore mock backend in Studio;
- profile-ready lookup and mutation boundary;
- forced session-end handling.

### Networking/security

- server-created remote registry;
- no generic `SetStat`, `GiveItem`, `SetCurrency`, price, rarity, or arbitrary mutation remote;
- profile-readiness gate before request handlers;
- per-player/per-action token-bucket rate limiting;
- rate-limit cleanup on leave;
- handler isolation through protected calls.

### Client/UI

- client bootstrap;
- React/ReactRoblox UI root controller;
- mount/unmount lifecycle;
- empty transparent root component so framework integration can be tested before real UI is layered on.

### Tests

- separate Jest test project;
- Jest CLI entrypoint;
- test discovery configuration;
- initial validator tests for finite numbers, bounded integers, bounded strings, and known IDs.

## Still requires execution verification

The GitHub connector can create/review repository files but does not execute the Roblox/Rokit toolchain. These must be run before Phase A is considered fully proven:

1. `rokit install`
2. `wally install`
3. commit the generated `wally.lock`
4. `stylua --check src`
5. `selene src`
6. `rojo build default.project.json`
7. `rojo build test.project.json`
8. run the Jest entrypoint in a supported Roblox/OCALE test environment
9. Studio fresh-player test confirms ProfileStore mock session starts and releases cleanly
10. Studio client test confirms React root mounts without visible artifacts or warnings

## Phase A exit rule

Phase A is complete only when the above checks run successfully. Configuration/code being present is not enough.

Once Phase A passes, Phase B begins with the smallest complete graybox loop:

`plot allocation -> salvage node -> collect -> process -> assemble -> reveal -> assign -> production -> sell -> upgrade -> zone goal`
