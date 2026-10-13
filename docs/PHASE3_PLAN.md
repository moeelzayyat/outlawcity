# OUTLAW CITY — Revised Phase 3 plan

**Status: APPROVED by the owner with revisions (2026-10-13).** The owner's decisions override the proposal below where they differ:
1. 3-star wanted system for the MVP; rules must allow more levels later.
2. Everyone joins as a civilian; no permanent teams.
3. Replace team selection after confirming a recoverable backup; keep its code in git history. ✅ done in 3A
4. Busted → short jail of ~10–15 s, no cash fine. Jail is built after basic busting works.
5. NPC police pursue and bust wanted players regardless of combat status.
6. Wanted players cannot switch to Peaceful.
7. Wanted players are vulnerable to eligible Combat-status opponents outside safe zones; Peaceful players cannot attack them just because they are wanted.
8. No PvP attacks inside safe zones, including against wanted players.
9. Safe zones never cancel wanted levels and never protect wanted players from NPC police.
10. No weapons or real PvP damage in Phase 3: combat rules are implemented and unit-tested only.

NPC police: build and validate **one** pursuit vehicle first (chase on the test roads, stuck recovery; record chase behaviour, collisions, recovery frequency, performance), and only then raise the count. Reports must separate wanted rules exercised through dev tools from crimes detected by real gameplay events.

Order: 3A → 3B → 3C → 3D → 3E → 3G → jail, with 3F throughout; report after each stage before starting the next.

---

*Original proposal (2026-10-13):* Each step is built and solo-tested in Studio on its own, with a report after each one. Anything that needs real players is marked MULTIPLAYER UNVERIFIED.

## 0. Inspection: where the project stands

| Area | State in Studio | Fit with new design |
|---|---|---|
| Vehicle physics, factory, spawning, controls, camera, HUD | Solo-verified (Phase 2) | **Keep unchanged** |
| City + highway map (`CityLayout`, `CityBuilder`, `Workspace.City`) | Solo-verified | **Keep**; add safe-zone volumes and NPC police spawn points as data in `CityLayout` |
| Network contract, `RateLimiter`, test runner, `Signal` | Solo-verified | **Keep**; reused by every new system |
| `TeamService`, `TeamConfig`, `TeamRules`, `TeamSelectController`, `RequestJoinTeam`, team types, 2 team specs | Built and solo-tested (Phase 3.1/3.2), now **superseded** | **Retire** (see step 3A). Kept in git history (commit tagged `teams-superseded`) in case player police return later |
| `Teams` service | Holds Police + Criminal teams at runtime only (created by TeamService; not saved in the place) | Goes away when TeamService is removed |

The team code is still active in Studio right now (the team screen opens on join). It does no harm in testing, but it is wrong for the new design, so step 3A removes it first. I have not deleted anything yet.

## Proposed steps

### 3A. Civilian spawning (and team retirement)
- Remove the 7 team scripts, the `RequestJoinTeam` remote and the team types, and put the Spawn Car button back as the only top-centre button. The top-centre layout stays, because the player list may still cover the top right.
- Add `PlayerStateService` (server), the single owner of per-player gameplay state. It publishes read-only `Player` attributes: `Status = "Civilian"`, `WantedLevel`, `CombatStatus`, `InSafeZone`, `SpawnProtectedUntil`.
- Add civilian spawns: several spawn points around the plaza, with a random free one picked on each respawn and 5 s of spawn protection.
- Solo tests: unit tests for spawn selection; playtest join and respawn (reset character) to confirm plaza spawn, attributes set, no team UI, and vehicle spawning unaffected.

### 3B. Dynamic wanted level
- `WantedRules` (pure) and `WantedService` (server). Crimes add **heat**, heat maps to **stars**, and stars decay only while no police unit has seen the player for a set time ("escape").
- MVP crimes need no robberies or weapons, and the server detects each one:
  - **Ramming a police car** (collision between the player's car and an NPC police car)
  - **Speeding past police** (above the city limit within an NPC unit's sight)
  - **Evading** (wanted and still moving after police tell them to stop)
- `WantedService.reportCrime(player, crimeType)` is the single entry point that future crimes (robberies and so on) will plug into.
- Escaping from 2+ stars records an `EscapeCompleted` event and adds criminal **reputation** (a stat only for now; cash rewards wait for the economy phase).
- Client HUD shows wanted stars plus "Evading..." and "Escaped!" banners.
- Solo tests: unit tests for heat, thresholds, decay, escape and the crime table. A dev tool sets heat and stars, so the escape path can be tested without police.

### 3C. Peaceful / Combat status
- `CombatRules.canHarm(attacker, victim, context)` (pure) is the one gate every future damage source must use. Nothing does damage yet, because PvP combat is out of scope.
- `RequestSetCombatStatus` remote, with a 30 s cooldown and no switching to Peaceful while wanted or within 30 s of combat.
- HUD toggle and status badge.
- Solo tests: a full `canHarm` matrix (peaceful/combat × wanted × safe zone × spawn protection) with mock players, plus a playtest of the toggle, cooldown and rejection messages. Protection between two real players is MULTIPLAYER UNVERIFIED.

### 3D. Basic NPC police response
- Server-driven police cars. They reuse the existing vehicle model and handling maths, but the server simulates them, so `VehiclePhysics` moves from `Client` to `Shared`. The file itself does not change; this is the only architectural move in Phase 3.
- No pathfinding: units drive straight at the player's predicted position with simple raycast obstacle steering. A unit that gets stuck or falls far behind is despawned and respawned on a road point ahead.
- Dispatch: 1 unit at 1★, 2 at 2★, 3 at 3★, with a server-wide cap of 4 units for mobile performance. Units spawn out of the player's view on road points defined in `CityLayout`.
- **Busted**: when a wanted player is stopped or on foot within 15 studs of a unit for 3 s, their wanted level is cleared and they respawn at the plaza. Jail and fines wait for the economy phase.
- Solo tests: unit tests for dispatch counts and spawn-point choice. Playtests use the dev tool to set stars, then watch units spawn, chase, lose the player (escape) and bust a stopped player. Logs record distances, speeds and timings.

### 3E. Safe-zone protection
- Zones are box volumes kept as data in `CityLayout` (the plaza now, and future garages). The server checks positions 4 times a second and sets `InSafeZone`.
- In a safe zone, `canHarm` is false and spawn camping is blocked. **Exception:** a wanted player gets no protection, and police can still bust them, so the zone can't be used to escape.
- HUD shows a "Safe Zone" badge.
- Solo tests: geometry unit tests, plus a playtest driving in and out with and without a wanted level.

### 3F. Solo testing tools (built alongside each step, not at the end)
- `DevToolsService` is created **only when `RunService:IsStudio()`** on the server, and its remote is created only then too, so it cannot exist in published servers. A unit test proves it is absent outside Studio.
- Commands: set wanted stars, report a crime, spawn or clear police units, toggle combat status, teleport to or out of the safe zone, and add a mock "victim" (a dummy character carrying player attributes) to exercise `canHarm` paths.
- A small Studio-only panel, or `execute_luau` snippets documented in `TEST_CHECKLIST.md`.

### 3G. Vehicle speed and teleport sanity checks (carried over)
- Server samples each client-simulated vehicle and flags impossible speeds or jumps, then resets the vehicle. This is needed before escapes pay rewards. Thresholds come from `VehicleConfig`, and no physics changes are made.

## Order and effort
3A → 3B → 3C → 3D → 3E → 3G, with 3F growing at each step. Each step ends with a Studio playtest, a short report (what was built, scripts changed, tests, bugs, multiplayer still to verify) and updates to `PROGRESS.md` and `MULTIPLAYER_TESTS.md`.

## Decisions needed from the owner
1. **Wanted scale:** 3 stars (recommended: matches the earlier spec and keeps police counts mobile-friendly) or GTA-style 5 stars?
2. **Busted outcome for the MVP:** respawn at the plaza with wanted cleared (recommended), or a short timed jail now?
3. **Wanted players lose protection:** no Peaceful protection and no safe-zone protection while wanted (recommended, to stop exploits)?
4. **Team code:** remove it from Studio in step 3A and keep it in git history (recommended), or keep it disabled in the place?
