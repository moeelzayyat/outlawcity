# OUTLAW CITY — Progress

Last updated 2026-10-13. Testing policy: solo Studio playtests; anything needing real players is marked **MULTIPLAYER UNVERIFIED** and listed in `MULTIPLAYER_TESTS.md`.

## Phase 2 — provisional sign-off (solo)

| Acceptance check | Result | Evidence |
|---|---|---|
| Vehicle spawning works | ✅ | V key, Spawn Car button (mouse and touch) and remote all spawn and seat the player |
| Acceleration, steering, braking, reversing | ✅ | 0 → 113 studs/s in ~4 s; brakes to 0 then reverses; steady turns; lane change at top speed without spin-out |
| Camera operates correctly | ✅ | Chase cam 20 studs behind, 8.6 up, looking forward (dot 0.97); FOV widens with speed; restores on exit |
| Car navigates city and highway | ✅ | Drove 400 studs across 2 grid intersections; up connector onto highway; 650 studs along highway; barrier hit at 109 studs/s stops cleanly, car stays upright |
| No critical Studio errors | ✅ | Output shows only test summary and Studio-assistant notices |
| Recoverable backup | ⚠️ partial | Every script is in git; the map is rebuildable from `CityLayout`. **Place file save/publish not verified by the agent** — owner to save/publish so Roblox version history has a restore point |
| Multiplayer behaviour | MULTIPLAYER UNVERIFIED | see `MULTIPLAYER_TESTS.md` |

## Completed (each verified in a solo Studio playtest unless noted)

| Feature | How it was verified |
|---|---|
| Typed Luau architecture (Shared / Server / Client / Tests) | Place boots with no errors |
| Network contract + server validation | `Remotes.spec`; spawn and exit requests behave in playtest |
| Unit test runner (runs at the start of every Studio playtest) | `[Tests] 33 passed, 0 failed` (after 3A) |
| City test map: grid, intersections, plaza, sidewalks, buildings, highway | `CityLayout.spec`; drive tests above; visual check in screenshots |
| Vehicle: spawn, drive, brake, reverse, steer, handbrake, exit/enter | Playtest logs (see Phase 2 table) |
| Chase camera | Playtest measurements above |
| Mobile driving controls | iPhone 17 Pro simulator: GAS, BRAKE/reverse, EXIT work; jump button hidden while driving |
| ~~3.1 Police and Criminal teams~~ / ~~3.2 Team selection screen~~ | Built and solo-tested, then **removed in 3A** after the owner's direction change. Code kept in git tag `teams-superseded` |
| **3A Team system removed** | 6 team scripts, `RequestJoinTeam`, team types removed from Studio; `PlayerAttributes.spec` asserts no team modules and no Teams remain; playtest: no team screen, `Teams` empty, players Neutral with no team, only 2 remotes |
| **3A Civilian spawning** | `PlayerStateService` sets `Status = "Civilian"`; `SpawnService` picks a random free spawn among 6 plaza `CivilianSpawns` before every spawn. Playtest: 13 respawns landed on the chosen spawn every time and covered all 6 spawns; with a car parked on CivilianNorth, 10 respawns never used it. `SpawnRules.spec` (free / occupied / fallback / simulated 3-player join) and `CityLayout.spec` spawn-placement test pass |
| **3A Spawn protection** | Every spawn sets `SpawnProtectedUntil` = now + 5 s and the SpawnLocation gives a 5 s ForceField; playtest: protected 4.5 s after spawn with ForceField, expired after 5.5 s with ForceField gone. Nothing deals damage yet, so protection is only observable as state (enforced via CombatRules in 3C) |
| 3A regression | Vehicle spawn, exit, drive (70.8 studs/s after 1.5 s W), chase camera all unchanged; Spawn Car button re-centred top-centre |

## Known issues / limitations

1. Place file save/publish not verified by the agent (see backup row above).
2. All multiplayer behaviour is unverified (policy); see `MULTIPLAYER_TESTS.md`.
3. Parked cars have a tiny vertical velocity jitter at rest (positions stable to ±0.01 stud). Revisit only if visible.
4. Other players see wheels at rest pose (wheel animation is local to the simulating client). Cosmetic. MULTIPLAYER UNVERIFIED.
5. No server-side speed/teleport check on client-simulated vehicles yet (Phase 3G).
6. The driver's head pokes through the Coupe roof. Cosmetic; leave until a vehicle art pass.
7. Steering is fairly sharp at low speed (turn radius ~16 studs at 30 studs/s); tune after owner feedback.
8. The original template `Workspace.SpawnLocation` (plaza centre) is still in the place and still a valid spawn if `RespawnLocation` were ever unset. Left untouched (pre-existing object); propose disabling or removing it with owner approval.
9. Spawn choice with several simultaneous joiners is only tested with mock positions — MULTIPLAYER UNVERIFIED.

## Fixed during development

- Camera occasionally reverted to the default camera while driving. Cause: the Studio MCP tool resets `CameraType` after running test code. Camera controller now re-asserts Scriptable each frame while driving.
- Team and Spawn Car buttons sat in the top-right corner, which Roblox's player list covers once teams exist (clicks hit Roblox UI). Moved both to a top-centre row.

## Direction change (2026-10-13)

Permanent Police/Criminal teams were **superseded** by a civilian open-world design (`DESIGN.md`), approved by the owner with revisions (see `PHASE3_PLAN.md`). The team code was removed from Studio in 3A and is preserved in git (tag `teams-superseded`).

## Upcoming (approved order; each waits for the previous report)

- 3B Wanted rules (3 stars, extensible), wanted status, HUD — **next, awaiting go-ahead after the 3A report**
- 3C Peaceful/Combat status rules (rules only, no damage)
- 3D One NPC police pursuit vehicle (prototype, then more units)
- 3E Safe-zone protection
- 3F Studio-only test tools (throughout)
- 3G Server vehicle speed/teleport validation
- Short jail (10–15 s) once busting works
