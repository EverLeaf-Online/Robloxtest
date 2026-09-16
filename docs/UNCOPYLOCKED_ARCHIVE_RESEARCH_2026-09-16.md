# Uncopylocked Archive Research — 2026-09-16

Source reviewed: `https://github.com/IIIStatusIII/Roblox-Uncopylocked-Games`

## Classification

**Reference-only design archaeology. Not an approved source of production code, maps, UI, meshes, textures, audio, branding, or other assets.**

The repository describes itself as a collection of more than 400 popular Roblox games. Its README states that the files came from many different places (including YouTube, Roblox, and Discord), that none of the files belong to the repository owner, and that credit belongs to the respective authors. The GitHub repository also has no repository-level license.

The tree contains additional provenance warning signs, including files whose names explicitly say they were copied, and many recognizable commercial games or third-party IP-based experiences.

Because commercial reuse rights are not established, availability in this repository does not mean EverLeaf has permission to republish, monetize, or incorporate the contained code/assets.

Roblox's current Creator Hub guidance also makes clear that creators are responsible for having rights to content they publish and that use of another party's IP without permission can violate Roblox's Terms. Creator Store availability/licensing is a separate, explicit permission path and should not be confused with a third-party GitHub dump.

## What we may safely learn from

We can study high-level product and systems patterns without copying expressive implementation details.

Useful categories present in the archive include older examples of:

- tycoon progression;
- simulator progression;
- mining/resource extraction;
- farming;
- retail/store management;
- job/task loops;
- player-owned plots and bases;
- collection/index loops;
- clicker/reveal loops;
- spatial upgrade paths;
- social spaces and hangouts;
- minigame/session loops.

Examples in the tree that are relevant only as historical product references include names such as:

- `Retail Tycoon 1.1.2`;
- `Lumber Tycoon 2`;
- `The Quarry`;
- `Azure Mines`;
- `[NEW CODE] Farmulator`;
- `Farming among Friends`;
- `Case Clicker`;
- `Cube Simulator`;
- `Limited Simulator` variants;
- `Supreme Fishing Simulator`;
- `Advanced Warfare Tycoon`;
- `Mansion Tycoon`;
- `Paint tycoon`;
- `Truck tycoon`;
- `Ice Cream Parlor Tycoon` variants;
- `Mining game`.

These names identify genres/mechanics to examine conceptually. They do **not** authorize copying those games.

## Product lessons for our profit-first simulator

### 1. Physical progression is stronger than menu-only progression

The tycoon/mining/retail examples reinforce a durable Roblox pattern: players like seeing their progress become a visible world change. For our project, upgrades should add machines, structures, workers/bots, storage, conveyors, processing stations, decorative prestige pieces, or new zones rather than only increasing hidden numerical multipliers.

### 2. Resource action -> conversion -> visible payoff is easy to understand

Mining, farming, retail, and simulator games repeatedly use a readable chain:

`perform action -> acquire resource -> convert/sell/process -> buy upgrade -> become more efficient`

Our new concept should preserve that clarity while using original art, names, rules, economy tuning, code, and UX.

### 3. Player-owned space creates attachment

Tycoons and management games commonly give players a plot/store/base that visibly becomes "theirs." This supports:

- personalization;
- social comparison;
- cosmetics;
- expansion monetization;
- return motivation;
- screenshot/share value.

This is a strong fit for a factory/workshop/robot-base style simulator.

### 4. Collection gives an infinite content surface

Simulator/archive examples demonstrate how collectible categories turn a short core loop into a longer-term objective. Our collection layer can use original robots, machine variants, blueprints, parts, skins, effects, badges, or product types.

Collection should be designed with deterministic progression protections so unlucky players are not trapped behind pure RNG.

### 5. Automation is a natural monetization surface

Tycoon and production games naturally support paid acceleration without requiring hard paywalls:

- extra processing slots;
- extra build queue;
- auto-collect convenience;
- temporary production multipliers;
- extra storage/offline capacity;
- cosmetic factory themes;
- optional premium worker/bot skins;
- event currency accelerators.

All economy authority remains server-side.

### 6. Historical code is not a modern architecture reference

Most archive files are complete `.rbxl`/`.rbxlx` binaries from older eras. Even where provenance were clean, their implementation may predate current Roblox APIs, mobile expectations, security guidance, DataStore practices, typed Luau, modern UI, Creator Rewards, subscriptions, rewarded ads, or current discovery analytics.

Therefore these files should not influence our technical stack more strongly than current Creator Hub and maintained Roblox OSS.

## Explicit prohibitions for Robloxtest

Do not:

- copy an `.rbxl` or `.rbxlx` file into this repository;
- publish one of these places under our account;
- extract and reuse proprietary maps, meshes, textures, audio, animations, icons, thumbnails, UI, or branding;
- copy scripts from recognizable commercial games;
- reuse third-party franchise IP (Pokemon, Mario, Star Wars, branded restaurants, etc.) without an appropriate license;
- assume the word "uncopylocked" transfers copyright or commercial rights;
- treat "credits to the author" as a software/content license;
- use the archive as a dependency.

## Allowed research workflow

When a mechanic in the archive looks useful:

1. describe the mechanic at a high level;
2. compare it with current successful Roblox products and Creator Hub guidance;
3. write an original product requirement for our game;
4. implement that requirement from scratch in our own architecture;
5. create or properly license all required assets;
6. test it against our own retention/revenue metrics.

## Current relevance to our concept

This archive strengthens the case for a simulator/tycoon hybrid rather than changing the concept outright.

A strong original direction remains:

`collect/salvage -> process -> assemble/reveal -> deploy/automate -> expand a visible player-owned factory -> unlock better zones/materials -> prestige/long-term collection`

The important distinction is that we will build the systems, economy, UI, map, characters, machines, assets, names, and progression ourselves.

## Source priority reminder

This archive ranks below:

1. Roblox Creator Hub;
2. `Roblox/creator-docs`;
3. current official Roblox/Luau repositories;
4. our live analytics and experiments;
5. reviewed, clearly licensed OSS.

It is a historical reference corpus only.
