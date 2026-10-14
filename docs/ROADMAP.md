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
- **4A ✅ approved (solo; real Studio DataStore):** server-authoritative cash, starting cash, DataStore persistence with retries and session safety, one EconomyService, pure economy rules, duplicate-transaction protection, cash HUD, Studio-only cash dev tools. No robberies, purchases or monetization yet.
- **4B ✅ provisionally approved (solo):** one convenience-store robbery (24/7 MART): server-owned sessions, 15 s holdout, 2★, $2,000 paid once only after escaping, 180 s store cooldown, fails on death/bust/leaving/disconnect, robbery HUD. No banks, more stores, gangs or weapons.
- **4B follow-up ✅:** recoverable robbery payouts; police sent at holdout end; police roadside stop proposed.
- **Audit remediation ✅ (solo; awaiting audit):** write-through economy (acknowledged = stored), durable reward ledger, lock heartbeat, experimental police tuning (paid getaways 5/5 vs 3/5), Muscle touch check, HTTP off.
- **Final targeted audit fixes ✅ (solo; awaiting audit + owner approval before Phase 5):** ambiguous-write reconciliation, durable reward dedupe (profile v3 `PaidRewards`), periodic ledger recovery with backoff, explicit ledger invalid states, leave/lock queue safety, dealership handler safety. Approved with conditions; conditions done (FIFO queue, leave-safe saves, reward validation).
- **Five-minute player-experience plan ✅ reviewed** (audit 4: APPROVE on Part A), `docs/PLAYER_EXPERIENCE_AUDIT.md`.
- **Onboarding batch ✅ (solo; awaiting owner/auditor review):** one-car spawn shortcut, store/dealership markers, first-spawn tip, escape hint, store reopen time + 90 s failed-robbery cooldown trial, Muscle progress (price unchanged), compact phone robbery panel, Studio-only milestone timings; reward timestamps reject ±infinity. Auditor: APPROVE WITH CONDITIONS; conditions done (solo).
- **Playability gate ✅ (solo):** re-spawn-while-driving fixed; regression passed. Next: the owner's 10-minute playtest (`docs/PLAYTEST_CHECKLIST.md`); further development follows that feedback, not feature count.
- **City atmosphere and audio audit (plan only, awaiting The Architect's review and owner approval):** `docs/CITY_ATMOSPHERE_AUDIO_AUDIT.md`. In ranked order: siren and flashing police lights, lighting preset, robbery alarm and payout sounds, stop lines, engine/tyre audio. Proposed Batch 1: lighting + police lights/siren. Roblox-owned audio only.
- **4C ✅ (solo; awaiting owner review):** OUTLAW MOTORS dealership, the $15,000 Muscle (faster, heavier handling), server purchase API (atomic cash + ownership, duplicate-safe), persistent ownership in profile v2 with safe migration from cash-only profiles, garage window, ownership-checked spawning, PC + mobile UI.
- Original line: cash, server-authoritative rewards for arrests and robberies, DataStore persistence.
- A first purchasable vehicle.

## Phase 5 — Content and polish (needs approval)
- Robbery locations, more vehicles, sounds, effects, map expansion, performance pass for low-end mobile.

## Phase 6 — Launch prep (needs approval)
- Analytics, moderation, monetisation (game passes), store page, soft launch.
