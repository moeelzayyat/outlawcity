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
| Recoverable backup | ✅ (updated 3C) | Owner saved to Roblox cloud and downloaded `backup.rbxl` (19:58:41Z, 124 KB, includes 3B); a copy was opened in Studio and played (41 scripts, 52/52 tests). Every script is also in git and the map is rebuildable from `CityLayout`. A fresh backup is requested before each major stage (see stage rows) |
| Multiplayer behaviour | MULTIPLAYER UNVERIFIED | see `MULTIPLAYER_TESTS.md` |

## Completed (each verified in a solo Studio playtest unless noted)

| Feature | How it was verified |
|---|---|
| Typed Luau architecture (Shared / Server / Client / Tests) | Place boots with no errors |
| Network contract + server validation | `Remotes.spec`; spawn and exit requests behave in playtest |
| Unit test runner (runs at the start of every Studio playtest) | `[Tests] 96 passed, 0 failed` (after 3E) |
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
| **3C pre-check: backup** | A *copy* of `backup.rbxl` (re-downloaded by the owner at 19:58:41Z, 124 KB, includes 3B) was opened in a separate Studio window: 41 scripts, City (199 parts), 6 civilian spawns, original spawn disabled; playtest 52/52 tests, car spawn + seat, dev command → 2★ HUD. Copy closed unsaved; original file hash/timestamp unchanged. Note: the owner's Studio window closed during this check (log shows a normal close request right after the cloud save); nothing was lost, owner reopened from the cloud and the place had all 41 scripts |
| **3C pre-check: star thresholds** | Rule specified (star lost the instant heat drops below its threshold); Evading notice now reports the stars held before the decay tick; dev "Set N stars" places heat mid-band. 2 new `WantedRules.spec` tests + updated `DevCommandRules.spec` |
| **3C pre-check: mobile HUD** | iPhone 7 simulator (666×374), driving + 3★ + Combat: no clipping, truncation or small targets; Combat button, Spawn Car, stars and driving buttons don't overlap |
| **3C Combat status** | All players start Peaceful (playtest). Toggle by mouse: Peaceful → Combat with live "COMBAT 28s" countdown; second click within 1 s → "Too fast" (rate limit); Peaceful during cooldown → "Wait for cooldown"; at 2★ after cooldown → `Wanted`, status stays Combat and **stars stay 2** (toggling never clears wanted); invalid targets (`123`, `"Admin"`, `"combat"`, 100-char string, nil) → `InvalidStatus`; wanted cleared → Peaceful accepted |
| **3C Combat rules** | `CombatRules.spec` (7 tests, full matrix with mock players): peaceful attackers never allowed (wanted victims included); peaceful victims protected unless wanted; Combat vs Combat allowed outside safe zones; safe zone blocks PvP incl. wanted victims; spawn protection blocks both ways; self-harm denied; NPC police bust wanted players regardless of status, zone, spawn protection; never non-wanted; malformed input denied. `CombatStatusRules.spec` (9 tests): start Peaceful, 30 s configurable cooldown, Combat anytime, Peaceful blocked by cooldown/wanted, activity extends cooldown, invalid/redundant requests, no wanted access. **No real PvP damage exists** — player-vs-player harm is verified only through these rules |
| 3C regression | 70/70 tests; no console errors; vehicle spawn + seating on mobile simulator; wanted system unchanged apart from the threshold fix |
| **3D pre-work** | Backup docs corrected; duplicate 3D entry removed; current backup confirmed from the Studio log: cloud save at 20:12:28Z and `OutlawCity_3C.rbxl` (130 KB) downloaded, taken after 3C was complete (not opened — no second Studio while the owner's is open) |
| **3D unit tests** | `PoliceNavigation.spec` (10): every node and every edge on drivable surface, network connected, shortest paths use real edges and reach the highway via a connector, planner skips passed nodes and ends at the target, steering signs, corner slowdown, chase speed, stuck → reverse → hard recovery, no false stuck. `PoliceDispatch.spec` (8): one unit max, Police car not player-spawnable, no dispatch at 0 stars, dispatch at 1–3, spawn band 160–450, bust timing/range/speed/permission, gap resets, combat gate. **88/88**. Unit tests alone do not prove navigation; see playtests |
| **3D: no pursuit of unwanted player** | 6 s at 0 stars → 0 units (playtest) |
| **3D: activation** | Dev "Set 1 star" → unit dispatched 0.17 s later, 202 studs away on a road node |
| **3D: pursuit through intersections and corners** | Scripted moving target (35 studs/s) north on x=−300 then a 90° right turn east along z=−100: unit crossed 2 intersections at 95 studs/s, slowed 95→30 for its own 90° turn, took the target's corner and the (−100,−100) intersection, then held a steady **25-stud** gap for 15 s. First version trailed at ~65 studs (aimed at a 1 s-old position) → fixed with predicted target + chase-speed rule (bug 18) |
| **3D: avoids buildings** | Server-side contact counter on the unit's chassis: **0** contacts with buildings, barriers or curbs across the chase runs (~4 min of driving) |
| **3D: blocked/stuck recovery** | Wall dropped across the road 30 studs ahead: unit reversed twice (soft), then hard-recovered by re-entering at a node out of sight, drove 230 studs and busted the player. First version sat at the wall for 30 s with no recovery (obstacle braking hid the stall) → fixed (bug 19). Recovery frequency in normal chases: 0–1 soft, 0 hard per pursuit |
| **3D: sight loss → decay → escape ends pursuit** | Unit sighted player; heat held at 25 for 3 s while seen; player moved out of sight → Evading at 8.3 s, Escaped at 12.2 s, pursuit ended, unit despawned at 13.8 s. Also seen incidentally when the unit was blocked and never saw the player (3★ escaped after ~27 s) |
| **3D: bust stationary wanted player** | 4 busts in playtests: unit stops ~10–14 studs away, bust after 2.5 s → stars 0, "BUSTED!" banner, player respawned on a civilian pad, unit despawned after 3 s |
| **3D: no bust at zero stars** | Stars cleared when the unit was < 30 studs away (closest 20): no bust, pursuit ended, unit despawned |
| **3D: real crime detection** | `PoliceCollisionDetector` fired once in playtest: "rammed police at 27 studs/s" — the *scripted* test car was pushed into the unit, so this is a real gameplay detector triggered by a test contact, not a human ramming. Other crimes (speeding near police, evading) are not detected yet; wanted levels in these tests came from dev tools |
| **3D: performance** | Server physics 60 FPS idle and during pursuit; police step ≈ 0.09–0.12 ms average, 0.44 ms max per frame; ~60 physics updates/s, AI tick 4/s, re-plan 1/s; status logged every 5 s |
| **3E safe-zone rules** | `SafeZoneRules.spec` (8): the Plaza zone matches the plaza part exactly; all civilian spawns inside; inside/outside/edge/height; hysteresis; PvP blocked when either side is in a zone (incl. a wanted victim, and a wanted Peaceful victim); combat-status changes can't bypass a zone; police can bust wanted players in a zone but not unwanted ones; the wanted engine behaves identically in and out (no zone input). 96/96 |
| **3E enter/exit + published state** | Playtest: spawn in plaza → server `[SafeZone] entered Plaza`, InSafeZone true, badge shown; teleport out → false after 0.63 s; back in → true after 0.43 s; 1 stud past the edge stays inside, 4 studs past leaves; driving out of the plaza in a car → false, badge hidden |
| **3E wanted unchanged in zone** | 2★ (heat 70, police sight held) outside → walked in → after 2 s still 2★ / heat 70, no Escaped or other notice |
| **3E police in zone** | Wanted 1★ standing inside the plaza: unit dispatched, approached to 11 studs, BUSTED after 6.8 s, InSafeZone was true at every sample while the unit was near. Also busted a player parked in their car on a plaza pad |
| **3E spawn protection + combat cooldown** | After the in-zone bust: respawned on a plaza pad, InSafeZone true, 4.0 s protection left with ForceField. Combat toggle inside the zone: Peaceful → Combat accepted, switching back immediately refused with `Cooldown` |
| **3E HUD** | PC: green SAFE ZONE badge under the Combat button. iPhone 7 simulator (666×374) while driving at 2★: amber badge, stars, Combat button and Spawn Car have no overlap, clipping or truncation |
| 3E regression | Driving, car spawning, civilian spawning, wanted HUD, police dispatch/chase/bust all working; no console errors (one error came from my own test snippet when the player had just been busted, not from game code) |
| 3D regression | Player driving 71.7 studs/s after 1.5 s W, chase camera, civilian respawn after bust, Combat toggle while wanted, wanted HUD; no console errors |

## Known issues / limitations

1. ~~Place file save/publish not verified~~ — verified in 3C (cloud save + `backup.rbxl` opened and played). The agent cannot save the place itself; each stage asks the owner for a fresh save.
2. All multiplayer behaviour is unverified (policy); see `MULTIPLAYER_TESTS.md`.
3. Parked cars have a tiny vertical velocity jitter at rest (positions stable to ±0.01 stud). Revisit only if visible.
4. Other players see wheels at rest pose (wheel animation is local to the simulating client). Cosmetic. MULTIPLAYER UNVERIFIED.
5. No server-side speed/teleport check on client-simulated vehicles yet (Phase 3G).
6. The driver's head pokes through the Coupe roof. Cosmetic; leave until a vehicle art pass.
7. Steering is fairly sharp at low speed (turn radius ~16 studs at 30 studs/s); tune after owner feedback.
8. The original template `Workspace.SpawnLocation` is disabled (owner-approved), not deleted.
9. Spawn choice with several simultaneous joiners is only tested with mock positions — MULTIPLAYER UNVERIFIED.
10. Crime detection: as of 3D one gameplay detector exists (ramming police). Wanted levels in 3B/3C/3D testing otherwise came from Studio dev tools.
11. ~~Evading notice reported one star fewer at an exact threshold~~ — fixed in 3C pre-checks (rule documented in ARCHITECTURE).
12. Wanted level survives death/respawn by design (prevents "reset to escape"). Owner may want to confirm.
13. `CriminalReputation` is session-only until the persistence/economy phase.
14. ~~Wanted HUD not checked on phone~~ — checked on iPhone 7 simulator in 3C.
15. `CombatService.canPlayerHarm` / `canPoliceBust` wrappers are only exercised indirectly (rules unit-tested with mocks); they get their first live caller in 3D (police bust).
16. The Studio-only dev panel covers the left edge on small phones (toggle with F8). Never present in published servers.
17. Combat status is session-only and survives respawn; it resets to Peaceful on rejoin.
18. ~~NPC trailed a moving target by ~65 studs~~ — fixed in 3D (predicted target, chase-speed rule).
19. ~~NPC stalled forever in front of a wall~~ — fixed in 3D (stuck detection keyed on wanted progress, not throttle).
20. NPC navigation is only verified on this test map's grid + highway; the plaza diagonal and highway end plazas were not driven in tests. The road network has no lane discipline (drives on the centre line) and no knowledge of blocked roads beyond hard recovery.
21. A head-on meet with a target can make the unit swing round (U-turn) before chasing; it recovers without stuck events.
22. Busted = respawn at a civilian pad for now; the 10–15 s jail comes later (approved order).
23. Only one gameplay crime detector exists (ramming police). Speeding-near-police and evading detectors are not built.
24. All NPC behaviour with several players (target choice, other players' cars in the way, ramming by a second player) is MULTIPLAYER UNVERIFIED; the moving target in tests was a scripted car, not a human driver.
25. **NPC navigation against unpredictable human driving is UNVERIFIED** (owner note, 3D review). Every moving-target test in 3D used a scripted car following a fixed route at constant speed; those tests are not human-driving validation.

## Fixed during development

- Camera occasionally reverted to the default camera while driving. Cause: the Studio MCP tool resets `CameraType` after running test code. Camera controller now re-asserts Scriptable each frame while driving.
- Team and Spawn Car buttons sat in the top-right corner, which Roblox's player list covers once teams exist (clicks hit Roblox UI). Moved both to a top-centre row.

## Direction change (2026-10-13)

Permanent Police/Criminal teams were **superseded** by a civilian open-world design (`DESIGN.md`), approved by the owner with revisions (see `PHASE3_PLAN.md`). The team code was removed from Studio in 3A and is preserved in git (tag `teams-superseded`).

## Upcoming (approved order; each waits for the previous report)

- ~~3B Wanted rules, status, HUD~~ — done (solo), awaiting owner approval
- ~~3C Peaceful/Combat status rules~~ — done (solo), awaiting owner approval
- ~~3D One NPC police pursuit vehicle~~ — provisionally approved (solo); dispatch stays at **one unit** by owner decision
- ~~3E Safe zones~~ — done (solo); awaiting owner approval
- Next by the approved order: 3G server vehicle speed/teleport validation, then the short jail
- 3E Safe-zone protection
- 3F Studio-only test tools (throughout)
- 3G Server vehicle speed/teleport validation
- Short jail (10–15 s) once busting works
