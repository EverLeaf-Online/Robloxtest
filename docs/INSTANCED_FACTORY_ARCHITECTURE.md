# Instanced Factory Architecture

Status: active architecture as of 2026-09-18. This supersedes the earlier multi-plot-per-production-server layout.

## Runtime model

The experience uses one Roblox place in two server modes:

- Hub — standard/public server, target 16 players.
- Factory — developer-reserved server, one persistent factory owner plus up to 3 read-only visitors.

src/shared/RuntimeMode.lua resolves the mode:

- Roblox Studio defaults to Factory so gameplay/OCALE workflows remain usable without TeleportService.
- Standard live servers are Hub.
- Reserved live servers (PrivateServerId is non-empty and PrivateServerOwnerId is 0) are Factory.
- VIP/private servers stay Hub.

This lets the current experience migrate to the scalable architecture without requiring a second Place ID now. A later Hub/Factory place split can reuse the same routing/session services.

## Hub flow

The Hub does not open player profiles or simulate production.

It initializes only HubWorldService, HubSessionService, and HubFactoryPortalService.

The factory portal:

1. Looks up the owner's remembered reserved-server access code in MemoryStore.
2. Reserves a new server with TeleportService:ReserveServerAsync() when needed.
3. Creates a one-time, 120-second route capability in MemoryStore.
4. Sends only the opaque route token through TeleportOptions:SetTeleportData().
5. Uses server-side TeleportService:TeleportAsync() into the reserved server.

Currency, inventory, robots, machine levels, and other durable state are never transported in TeleportData.

## Route security

MemoryStore structures:

- ScrapToBot_FactoryRoutes_v1 — short-lived one-time routing capabilities.
- ScrapToBot_FactoryAccess_v1 — owner -> reserved-server access code lease.

A route record contains exact routed PlayerUserId, target OwnerUserId, Owner/Visitor role, and issue timestamp.

The Factory server consumes and validates the route before marking the player verified. An Owner route must name the routed player as the owner. A copied route token therefore fails the exact player-ID check. Expired routes fail before profile loading.

## Factory session

A Factory server builds one 240x200 production yard at world origin.

The verified owner receives plot authority, loads the persistent ProfileStore session, owns all gameplay interactions, and runs production/monetization systems.

Visitors are session participants but receive no plot authority, do not open their own persistent profile, do not run their own economy while visiting, and initialize presentation-only client systems.

The factory server enforces a maximum of 4 participants even though the Roblox place itself is configured for the 16-player Hub target.

## Persistence

The physical server/yard is disposable. Persistent player state remains in the existing session-locked profile: Credits, materials, robots, assignments, machine levels, zone progression, entitlements, cosmetics, stats, and tutorial progress.

Joining a different reserved Factory server reconstructs the same authoritative factory state.

## Return flow

A server-owned ReturnToHub portal uses TeleportService:TeleportAsync(game.PlaceId, { player }) without a reserved-server target. Roblox matchmaking places the player back into a standard public Hub server.

## Scale target

The place should be configured for 16 MaxPlayers in Roblox experience settings.

At 100 CCU, the expected shape is multiple 16-player Hub servers plus personal Factory reserved servers. Total CCU is therefore not constrained by the number of factory yards in one server.

Current capacity gates:

- Hub target: 16 players.
- Factory: 1 owner + up to 3 visitors.
- Factory physical production world: one yard.
- Assigned workers: max 6 visible working robots for the owner under the current progression/pass model.
- Private salvage: 12 nodes in the factory template.

## Current visitor scope

Routing/domain types support Owner and Visitor roles, but this first architecture pass exposes only the owner's Hub portal.

Friend invites/visit discovery should be implemented only after an active factory presence lease exists. Do not treat the stored reserved-server access code alone as proof that the owner is currently online.

The later visitor flow should verify social/invite permissions server-side, verify an active owner session, issue a route token bound to visitor + owner, teleport with the reserved access code, and keep visitors read-only unless explicit co-op permissions are added.

## Required live configuration / validation

- set the place MaxPlayers to 16;
- use secure server-initiated teleport access for the experience;
- verify MemoryStore access in the published experience;
- test Hub -> Factory -> Hub in the Roblox client because TeleportService does not work in Studio;
- test stale reserved-server code recovery;
- test reconnecting to the same owner factory;
- test route-token replay/copy rejection;
- test Factory full-cap rejection;
- add active-presence leasing before enabling visitor UI.
