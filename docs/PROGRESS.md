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
| Unit test runner (runs at the start of every Studio playtest) | `[Tests] 52 passed, 0 failed` (after 3B) |
| City test map: grid, intersections, plaza, sidewalks, buildings, highway | `CityLayout.spec`; drive tests above; visual check in screenshots |
| Vehicle: spawn, drive, brake, reverse, steer, handbrake, exit/enter | Playtest logs (see Phase 2 table) |
| Chase camera | Playtest measurements above |
| Mobile driving controls | iPhone 17 Pro simulator: GAS, BRAKE/reverse, EXIT work; jump button hidden while driving |
| ~~3.1 Police and Criminal teams~~ / ~~3.2 Team selection screen~~ | Built and solo-tested, then **removed in 3A** after the owner's direction change. Code kept in git tag `teams-superseded` |
| **3A Team system removed** | 6 team scripts, `RequestJoinTeam`, team types removed from Studio; `PlayerAttributes.spec` asserts no team modules and no Teams remain; playtest: no team screen, `Teams` empty, players Neutral with no team, only 2 remotes |
| **3A Civilian spawning** | `PlayerStateService` sets `Status = "Civilian"`; `SpawnService` picks a random free spawn among 6 plaza `CivilianSpawns` before every spawn. Playtest: 13 respawns landed on the chosen spawn every time and covered all 6 spawns; with a car parked on CivilianNorth, 10 respawns never used it. `SpawnRules.spec` (free / occupied / fallback / simulated 3-player join) and `CityLayout.spec` spawn-placement test pass |
| **3A Spawn protection** | Every spawn sets `SpawnProtectedUntil` = now + 5 s and the SpawnLocation gives a 5 s ForceField; playtest: protected 4.5 s after spawn with ForceField, expired after 5.5 s with ForceField gone. Nothing deals damage yet, so protection is only observable as state (enforced via CombatRules in 3C) |
| 3A regression | Vehicle spawn, exit, drive (70.8 studs/s after 1.5 s W), chase camera all unchanged; Spawn Car button re-centred top-centre |
| **3B pre-checks** | Owner-saved place backup found: `G:\Roblox\Outlaw City\backup.rbxl` (117 KB, 2026-10-13 15:48 local; existence/size/time verified, contents not opened). Original template `Workspace.SpawnLocation` disabled (`Enabled = false`, object kept); playtest spawns still land on civilian pads (East, South) |
| **3B Wanted rules engine** | `WantedRules.spec` (14 tests): 3 stars, threshold mapping, 5-star config with no code change, crime heat, repeated-crime cooldown + heat cap, invalid crime/heat input, clamping, no decay before delay, police sighting blocks decay, decay starts evading and drops stars, escape with reputation by peak, 1-star escape earns 0, new crime while evading restarts delay, reset clears with no reward |
| **3B WantedService + reportCrime** | Single server entry point `reportCrime(player, crimeType)`; 4 Hz decay loop; attributes `WantedLevel/WantedHeat/WantedEvading/CriminalReputation`. Playtest (crimes injected via **dev tools**, not gameplay): Ramming → heat 25, 1★; repeat within 2 s → `Cooldown`, heat unchanged; Set 3★ + "police sees me" for 12 s → heat stayed 100; sight off → Evading notice after ~8 s, heat 87.7 at 9.5 s, stars 3→2→1→0, Escaped notice `{FromStars=3, Reputation=25}`, server reputation 25. Wanted level persists through respawn (2★ before and after reset) |
| **3B Wanted HUD + notifications** | Stars (top centre under Spawn Car), lit/unlit, blink while evading; "EVADING..." and "ESCAPED! +25 REP" banners confirmed on screen and in GUI state; stars hide at 0 |
| **3B Studio-only dev tools** | `DevToolsService` creates `ReplicatedStorage.DevRemotes` only when `RunService:IsStudio()`; F8 panel with crime, star, clear and police-sight buttons all exercised by mouse. `DevCommandRules.spec` (5 tests) incl. invalid input and "DevRemotes present only in Studio". Behaviour in a published server not testable from Studio: guarded by design + test, not observed |
| **3B Security** | Client set `CriminalReputation=9999` and `WantedLevel=3` locally and fired `OnWantedNotice` at the server; server still read rep 25 / level 0. Bad dev commands (`GiveReputation`, `SetHeat 1e9`, `SetHeat NaN`, `SetStars 7`, unknown crime) all rejected. Spec asserts no public `Request*` remote names wanted/heat/crime/reputation/dev |
| 3B regression | 52/52 tests; vehicle spawn while wanted, drive 71.8 studs/s after 1.5 s, chase camera; no console errors |

## Known issues / limitations

1. Place file save/publish not verified by the agent (see backup row above).
2. All multiplayer behaviour is unverified (policy); see `MULTIPLAYER_TESTS.md`.
3. Parked cars have a tiny vertical velocity jitter at rest (positions stable to ±0.01 stud). Revisit only if visible.
4. Other players see wheels at rest pose (wheel animation is local to the simulating client). Cosmetic. MULTIPLAYER UNVERIFIED.
5. No server-side speed/teleport check on client-simulated vehicles yet (Phase 3G).
6. The driver's head pokes through the Coupe roof. Cosmetic; leave until a vehicle art pass.
7. Steering is fairly sharp at low speed (turn radius ~16 studs at 30 studs/s); tune after owner feedback.
8. The original template `Workspace.SpawnLocation` is disabled (owner-approved), not deleted.
9. Spawn choice with several simultaneous joiners is only tested with mock positions — MULTIPLAYER UNVERIFIED.
10. **No real crime detection yet.** Every wanted-level change in 3B testing came from Studio dev tools. Gameplay detectors (ramming police, speeding near police, evading) need NPC police (3D).
11. When heat sits exactly on a star threshold, the first decay tick drops a star immediately, so the Evading notice can report one star fewer than the HUD showed a moment earlier (seen: set 3★ → notice said 2★). Cosmetic; candidate fix is to start the decay "grace" at the threshold.
12. Wanted level survives death/respawn by design (prevents "reset to escape"). Owner may want to confirm.
13. `CriminalReputation` is session-only until the persistence/economy phase.
14. Wanted HUD not yet checked on the phone simulator (layout is a 102-px row under the Spawn Car button).

## Fixed during development

- Camera occasionally reverted to the default camera while driving. Cause: the Studio MCP tool resets `CameraType` after running test code. Camera controller now re-asserts Scriptable each frame while driving.
- Team and Spawn Car buttons sat in the top-right corner, which Roblox's player list covers once teams exist (clicks hit Roblox UI). Moved both to a top-centre row.

## Direction change (2026-10-13)

Permanent Police/Criminal teams were **superseded** by a civilian open-world design (`DESIGN.md`), approved by the owner with revisions (see `PHASE3_PLAN.md`). The team code was removed from Studio in 3A and is preserved in git (tag `teams-superseded`).

## Upcoming (approved order; each waits for the previous report)

- ~~3B Wanted rules, status, HUD~~ — done (solo), awaiting owner approval
- 3C Peaceful/Combat status rules (rules only, no damage) — **next, after approval**
- 3D One NPC police pursuit vehicle (prototype, then more units)
- 3E Safe-zone protection
- 3F Studio-only test tools (throughout)
- 3G Server vehicle speed/teleport validation
- Short jail (10–15 s) once busting works
