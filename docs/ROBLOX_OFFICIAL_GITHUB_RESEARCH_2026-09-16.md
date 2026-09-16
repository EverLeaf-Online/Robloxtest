# Official Roblox GitHub Research — 2026-09-16

Purpose: audit `https://github.com/Roblox` for current, official Roblox-maintained sources that can improve the profit-first simulator's engineering, UI, testing, asset pipeline, cloud automation, and live operations.

This document does **not** mean every repository under the Roblox organization should be adopted. The organization contains active creator tooling, internal mirrors, archived projects, infrastructure software, research code, and limited-use archives. Maintenance status and relevance still matter.

## Source rule

For implementation questions, current Creator Hub guidance remains the primary authority. Official Roblox GitHub repositories are valuable when they provide current source code, reference implementations, tooling, or searchable implementation details that complement Creator Hub.

Prefer, in order:

1. current Creator Hub/API/policy documentation;
2. `Roblox/creator-docs` when searchable source text helps;
3. current official Roblox repositories directly relevant to the feature;
4. current maintained community OSS;
5. archived/stale official projects only as historical references.

## Adopt / strongly consider

### Roblox/creator-docs

`https://github.com/Roblox/creator-docs`

Official public Creator documentation source. It was synchronized from Roblox internal documentation on 2026-09-16.

Use for:
- DataStore/MemoryStore/Open Cloud behavior;
- security/client-server boundary guidance;
- monetization/policy requirements;
- analytics/discovery/retention research;
- UI/accessibility/performance guidance;
- API details when web docs are difficult to search precisely.

Decision: **high-authority research source**.

### Roblox/react-luau

`https://github.com/Roblox/react-luau`

Official declarative UI library, based on React 17 and tuned for Roblox. The official repository has active 2026 development and publishes packages for Roblox creators.

Useful for a monetization-heavy simulator because the UI surface will become substantial:
- onboarding;
- HUD/currency displays;
- upgrade menus;
- collection/index screens;
- shop and purchase surfaces;
- rewards/daily streaks;
- event UI;
- settings/accessibility;
- responsive cross-device layouts.

Decision: **leading declarative UI candidate**, but still prototype against Fusion/plain Roblox UI before final lock. We care more about shipping speed and maintenance cost than framework preference.

### Roblox/jest-roblox

`https://github.com/Roblox/jest-roblox`

Current Roblox-maintained test framework. Roblox states it uses Jest Roblox for apps, core scripts, plugins, and libraries. It has active September 2026 repository work.

Decision: **preferred automated test framework**.

Priority tests:
- economy arithmetic;
- progression/prestige formulas;
- reward caps;
- receipt idempotency;
- profile migrations;
- pricing/config tables;
- remote validators;
- rate limits;
- offline earnings;
- guaranteed reward logic;
- server-side purchase fulfillment.

### Roblox/react-testing-library-lua

`https://github.com/Roblox/react-testing-library-lua`

Testing utilities for React Luau/React Roblox. It is intended to test UI through user-visible behavior rather than component internals and requires Jest Roblox 3+.

Decision: **optional dev dependency if React Luau is selected**.

High-value targets:
- onboarding progression;
- shop buttons and state;
- upgrade affordability/disabled states;
- reward claim state;
- collection filters;
- responsive UI behavior;
- regression tests around monetization surfaces.

### Roblox/focus-navigation

`https://github.com/Roblox/focus-navigation`

Actively maintained in August 2026. Provides richer directional/gamepad/keyboard focus behavior and input-method detection, with React integration.

Decision: **reference/optional dependency for console/gamepad UX**, not mandatory for the first prototype.

The first build should keep input abstractions simple, but the library is valuable when we harden console navigation and accessibility.

### Roblox/rocale-cli

`https://github.com/Roblox/rocale-cli`

Active command-line tool for building, uploading, and running Roblox projects through Open Cloud Luau Execution. It can load Rojo projects and execute Luau in Roblox cloud sessions.

Decision: **strong CI/integration-test candidate** once the core project exists.

Potential uses:
- run server-side automated tests against a built place;
- smoke-test profile schema migrations;
- verify startup/config integrity;
- run release-gate scripts before publishing;
- validate behavior in Roblox execution rather than only a local static environment.

Do not expose production API keys in source or logs.

### Roblox/data-stores-batch-processor-cli

`https://github.com/Roblox/data-stores-batch-processor-cli`

Official bulk DataStore management tool using Open Cloud Luau Execution, MemoryStore, and DataStore APIs. It supports custom Luau processing across large sets of keys/stores and explicitly warns about irreversible data loss if misused.

Decision: **future live-operations tool; never part of the runtime client/server game**.

Potential uses after launch:
- schema migration;
- cleanup of obsolete profile fields;
- bulk compensation/corrections;
- controlled data repair;
- auditing or transforming a large profile population.

Operational rule:
- test against a separate experience first;
- perform scope tests;
- spot-test one production key before broad runs;
- keep backups/recovery strategy;
- design live-path migrations before touching keys that live servers are actively writing.

This is preferable to shipping dangerous hidden admin commands for bulk player-data mutation.

### Roblox/roblox-blender-plugin

`https://github.com/Roblox/roblox-blender-plugin`

Official Open Cloud reference integration for uploading selected Blender assets to Roblox as packages. It supports asset versioning and package auto-update workflows and had 2026 maintenance for Blender 5.0-era UI/installation changes.

Decision: **useful asset-pipeline tool/reference** if our robot/factory concept uses Blender-generated models.

Potential workflow:
- model/optimize robot and machine assets in Blender;
- upload as Roblox packages;
- use package versioning for controlled asset iteration;
- keep source `.blend`/export metadata outside the runtime project;
- profile triangle/material/texture costs before broad deployment.

### Roblox/roblox-lua-promise

`https://github.com/Roblox/roblox-lua-promise`

Roblox-maintained Promise implementation with 2026 work.

Decision: **optional**. Use only where async composition/cancellation improves correctness. Do not wrap ordinary gameplay logic in Promises unnecessarily.

## Useful reference / conditional adoption

### Roblox/tarmac

`https://github.com/Roblox/tarmac`

Resource compiler and asset manager designed to work with tools such as Rojo. It can synchronize assets and generate Luau mappings from source files to Roblox asset IDs.

Decision: **reference/conditional**.

The deterministic asset mapping idea is valuable, but its documented authentication/workflow is older than newer Open Cloud-oriented tooling. Before adoption, verify current authentication and maintenance behavior against Creator Hub and newer asset APIs. Do not add it just because it is in the Roblox organization.

### Roblox/cube

`https://github.com/Roblox/cube`

Roblox 3D foundation-model research, including Cube 3D and the 2026 CubePart work.

Decision: **asset R&D only**.

Possible future use:
- generate early robot/machine shape concepts;
- prototype part-segmented mechanical objects.

Not a runtime dependency. Generated assets still require topology cleanup, optimization, UV/material work, visual QA, provenance/license review, and Roblox import testing.

### Roblox/gear

`https://github.com/Roblox/gear`

Source representation of classic Roblox catalog gear. Roblox describes it as an as-is learning/experimentation archive with a Roblox Limited Use License.

Decision: **reference only**.

Do not copy classic gear into this simulator as filler content. The limited-use license and old gameplay patterns make it a poor base for an original monetizable simulator. It can be useful for learning historical Roblox interaction/script patterns only.

## Not relevant to the runtime simulator

### Roblox/Sentinel

Roblox Safety Toolkit Python library for rare-class text detection.

Decision: **not part of the game stack** unless we later build a separate text-safety/research service that specifically requires it.

### Roblox/RobloxGuard-1.0

LLM guardrail/safety-classification research for text-generation APIs.

Decision: **not part of the simulator stack** unless an AI-generated text feature is introduced later.

### Infrastructure repositories

The Roblox organization also contains infrastructure/system repositories such as networking/platform forks. These are not creator-runtime libraries and should not be pulled into the experience merely because they are official.

## Official but stale/archived warning

An official owner does not guarantee a repository is the correct 2026 choice.

Examples:

- `Roblox/roact` — archived; do not start new UI on Roact.
- `Roblox/testez` — archived; prefer Jest Roblox.
- `Roblox/Core-Scripts` — archived historical source.
- `Roblox/Studio-Tools` — archived.
- `Roblox/place-ci-cd-demo` — archived; current Open Cloud tooling should be preferred.
- `Roblox/t` — still public and useful as historical runtime-validation reference, but its latest observed commits are from 2023. Do not automatically make it a new foundational dependency simply because it is under `Roblox`.

## Revised UI decision

The official organization changes the UI shortlist.

Current order to prototype:

1. **React Luau** — official, actively maintained, strong testing ecosystem, large-system friendly.
2. **Fusion** — active community library, simpler reactive model, potentially faster for a smaller simulator.
3. **Plain Roblox UI** — lowest dependency count but can become expensive to maintain as screens/state multiply.

Prototype the same small shell in the top candidates:
- HUD currency counter;
- upgrade card/list;
- modal shop panel;
- collection grid;
- one responsive mobile layout.

Choose based on:
- implementation speed;
- code volume;
- mobile responsiveness;
- testability;
- animation ergonomics;
- memory/CPU impact;
- long-term maintainability.

Do not choose based on ideology or popularity.

## Revised testing/release pipeline candidate

For the eventual production repo:

1. format/static checks locally/CI;
2. Jest Roblox unit tests for pure/server modules;
3. build the Rojo project;
4. optional React Testing Library tests if React is selected;
5. run higher-level Roblox execution tests through `rocale-cli`/Open Cloud;
6. publish first to a staging/test experience;
7. automated smoke checks;
8. manual mobile/PC/gamepad playtest for release candidates;
9. publish production only after gates pass.

## Revised live-data operations rule

Runtime services should not contain broad data-mutation shortcuts just because they are convenient during development.

Instead:
- normal profile mutations happen through narrow server services;
- migrations are versioned and idempotent;
- production-wide repairs use reviewed external tooling such as the official batch processor;
- all bulk operations are tested on non-production data first;
- purchase receipts remain separately idempotent and auditable.

## Profit-first implication

The most valuable finds in the official org are not flashy gameplay systems. They reduce revenue risk:

- **React Luau / testing libraries** reduce shop/onboarding/UI regressions.
- **Jest Roblox** reduces economy and purchase bugs.
- **rocale-cli** improves release confidence in the real Roblox execution environment.
- **Data Stores Batch Processor** gives us a safer path for post-launch migrations and repairs.
- **Blender/Open Cloud tooling** can lower the cost of repeatedly shipping new visual content.
- **creator-docs** keeps implementation tied to current platform behavior.

That directly supports the project's business objective: ship faster, break less, protect player data/economy, and make content updates inexpensive enough to sustain LiveOps.