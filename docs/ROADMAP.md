# OUTLAW CITY — Roadmap

Budget: $3,500. Team: owner + AI agents (see `AGENTS.md`). Each phase ends with a Studio playtest and owner approval before the next one starts.

## Phase 1 — Project foundation ✅
- Inspect the existing place (fresh Baseplate template, no scripts) — done before any change.
- Modular typed-Luau layout: `Shared` / `Server` / `Client` / `Tests`.
- Naming conventions, boot order, network contract, security rules (`ARCHITECTURE.md`).
- Git repo for docs and source snapshots; Rojo dropped by owner decision, Studio MCP is the workflow.
- Roadmap, progress tracking, agent roles, test checklist.

## Phase 2 — First playable prototype ✅ (awaiting owner playtest)
- Small city test area: 4×4 road grid with intersections, centre plaza, raised sidewalks, buildings.
- Short highway (1,400 studs, 4 lanes, median, barriers, turnaround plazas) joined by two connector roads.
- One vehicle (Coupe) with acceleration, steering, braking, reverse and handbrake.
- Follow (chase) camera with speed-based distance and FOV.
- Keyboard, gamepad and mobile touch controls.
- Basic vehicle spawning on pads, one car per player, server-validated.

## Phase 3 — Cops vs criminals core (needs approval)
- Police and Criminal teams, team selection, team spawns.
- Simple wanted levels (crime events raise it, time lowers it).
- Arrests (server-validated proximity + wanted check), jail and release.
- Police vehicle variant; server-side vehicle speed/teleport sanity checks.
- Multiplayer test pass with 4–8 players.

## Phase 4 — Economy (needs approval)
- Cash, server-authoritative rewards for arrests and robberies, DataStore persistence.
- A first purchasable vehicle.

## Phase 5 — Content and polish (needs approval)
- Robbery locations, more vehicles, sounds, effects, map expansion, performance pass for low-end mobile.

## Phase 6 — Launch prep (needs approval)
- Analytics, moderation, monetisation (game passes), store page, soft launch.
