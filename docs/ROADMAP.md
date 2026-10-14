# OUTLAW CITY — Roadmap

Budget: $3,500. Team: owner + AI agents (see `AGENTS.md`). Each phase ends with a Studio playtest and owner approval before the next one starts.

## Testing policy (owner decision, 2026-10-13)

Manual multiplayer testing is not currently possible, so development continues on **solo Studio playtests**:
- Keep the server/client architecture multiplayer-ready; no large architectural changes just to suit solo testing.
- Use unit tests, mocks and simulated player scenarios (Studio-only dev tools) wherever possible.
- Any feature that needs real multiplayer verification is labelled **MULTIPLAYER UNVERIFIED**; solo tests never count as multiplayer confirmation.
- Deferred multiplayer tests are tracked in `MULTIPLAYER_TESTS.md`.
- **Gate:** before live monetization or any public beta, real multiplayer testing and owner approval are required.

## Phase 1 — Project foundation ✅
- Inspect the existing place (fresh Baseplate template, no scripts) — done before any change.
- Modular typed-Luau layout: `Shared` / `Server` / `Client` / `Tests`.
- Naming conventions, boot order, network contract, security rules (`ARCHITECTURE.md`).
- Git repo for docs and source snapshots; Rojo dropped by owner decision, Studio MCP is the workflow.
- Roadmap, progress tracking, agent roles, test checklist.

## Phase 2 — First playable prototype ✅ provisional (solo-tested; MULTIPLAYER UNVERIFIED)
- Small city test area: 4×4 road grid with intersections, centre plaza, raised sidewalks, buildings.
- Short highway (1,400 studs, 4 lanes, median, barriers, turnaround plazas) joined by two connector roads.
- One vehicle (Coupe) with acceleration, steering, braking, reverse and handbrake.
- Follow (chase) camera with speed-based distance and FOV.
- Keyboard, gamepad and mobile touch controls.
- Basic vehicle spawning on pads, one car per player, server-validated.

## Phase 3 — REVISED: civilian open world (APPROVED with revisions 2026-10-13, in progress)
The owner replaced permanent teams with a GTA-style civilian open world (`DESIGN.md`); plan and approved decisions in `PHASE3_PLAN.md`. Order: 3A civilian spawning ✅ (solo) → 3B wanted rules/status/HUD ✅ (solo, dev-tool driven) → 3C Peaceful/Combat rules ✅ (solo, rules only) → 3D one NPC police pursuit vehicle ✅ (solo prototype; stays at one unit) → 3E safe zones ✅ (solo) → 3G vehicle movement validation ✅ (solo, monitor-only) → short jail ✅ (solo; 12 s, server-timed). 3F Studio-only tools are maintained throughout. Each stage is reported before the next begins.

### Superseded: Police vs Criminal teams (original Phase 3)
Items 1–2 were built and solo-tested before the change of direction, and the code is tagged `teams-superseded` in git. Items 3–8 were never started. Original order:
1. Police and Criminal teams
2. Team selection interface
3. Separate team spawn locations
4. Three-level wanted system
5. Basic server-authoritative arrest mechanics
6. Jail and automatic release
7. Police pursuit alerts
8. Server-side vehicle speed and teleport sanity checks

Plus isolated Studio-only dev tools to simulate wanted players and arrests (must never activate in published servers).
Out of scope for Phase 3: robberies, weapons, gangs, helicopters, new districts, monetization. Vehicle physics stays as-is unless fixing a documented defect.

## Phase 3.5 — Multiplayer verification (when possible)
- Run every test in `MULTIPLAYER_TESTS.md` with real players; required before monetization or public beta.

## Phase 4 — Economy
- **4A ✅ (solo; real Studio DataStore):** server-authoritative cash, starting cash, DataStore persistence with retries and session safety, one EconomyService, pure economy rules, duplicate-transaction protection, cash HUD, Studio-only cash dev tools. No robberies, purchases or monetization yet.
- Later (needs approval): robbery system and rewards, vehicle ownership/purchases.
- Original line: cash, server-authoritative rewards for arrests and robberies, DataStore persistence.
- A first purchasable vehicle.

## Phase 5 — Content and polish (needs approval)
- Robbery locations, more vehicles, sounds, effects, map expansion, performance pass for low-end mobile.

## Phase 6 — Launch prep (needs approval)
- Analytics, moderation, monetisation (game passes), store page, soft launch.
