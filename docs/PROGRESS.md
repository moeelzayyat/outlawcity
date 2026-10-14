# OUTLAW CITY — Progress

Last updated 2026-10-14. Testing policy: solo Studio playtests; anything needing real players is marked **MULTIPLAYER UNVERIFIED** and listed in `MULTIPLAYER_TESTS.md`.

## Phase 2 — provisional sign-off (solo)

| Acceptance check | Result | Evidence |
|---|---|---|
| Vehicle spawning works | ✅ | V key, Spawn Car button (mouse and touch) and remote all spawn and seat the player |
| Acceleration, steering, braking, reversing | ✅ | 0 → 113 studs/s in ~4 s; brakes to 0 then reverses; steady turns; lane change at top speed without spin-out |
| Camera operates correctly | ✅ | Chase cam 20 studs behind, 8.6 up, looking forward (dot 0.97); FOV widens with speed; restores on exit |
| Car navigates city and highway | ✅ | Drove 400 studs across 2 grid intersections; up connector onto highway; 650 studs along highway; barrier hit at 109 studs/s stops cleanly, car stays upright |
| No critical Studio errors | ✅ | Output shows only test summary and Studio-assistant notices |
| Recoverable backup | ✅ | The owner saves before each stage (cloud save + downloaded file, confirmed in the Studio log). Latest: `OutlawCity_3E.rbxl` (144 KB, 20:46:39Z, after 3E). Earlier: `OutlawCity_3D.rbxl`, `OutlawCity_3C.rbxl`, `backup.rbxl`. One backup copy was opened and played in 3C. Every script is also in git and the map is rebuildable from `CityLayout` |
| Multiplayer behaviour | MULTIPLAYER UNVERIFIED | see `MULTIPLAYER_TESTS.md` |

## Completed (each verified in a solo Studio playtest unless noted)

| Feature | How it was verified |
|---|---|
| Typed Luau architecture (Shared / Server / Client / Tests) | Place boots with no errors |
| Network contract + server validation | `Remotes.spec`; spawn and exit requests behave in playtest |
| Unit test runner (runs at the start of every Studio playtest) | `[Tests] 135 passed, 0 failed` (after 4A) |
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
| 3D regression | Player driving 71.7 studs/s after 1.5 s W, chase camera, civilian respawn after bust, Combat toggle while wanted, wanted HUD; no console errors |
| **3E safe-zone rules** | `SafeZoneRules.spec` (8): the Plaza zone matches the plaza part exactly; all civilian spawns inside; inside/outside/edge/height; hysteresis; PvP blocked when either side is in a zone (incl. a wanted victim, and a wanted Peaceful victim); combat-status changes can't bypass a zone; police can bust wanted players in a zone but not unwanted ones; the wanted engine behaves identically in and out (no zone input). 96/96 |
| **3E enter/exit + published state** | Playtest: spawn in plaza → server `[SafeZone] entered Plaza`, InSafeZone true, badge shown; teleport out → false after 0.63 s; back in → true after 0.43 s; 1 stud past the edge stays inside, 4 studs past leaves; driving out of the plaza in a car → false, badge hidden |
| **3E wanted unchanged in zone** | 2★ (heat 70, police sight held) outside → walked in → after 2 s still 2★ / heat 70, no Escaped or other notice |
| **3E police in zone** | Wanted 1★ standing inside the plaza: unit dispatched, approached to 11 studs, BUSTED after 6.8 s, InSafeZone was true at every sample while the unit was near. Also busted a player parked in their car on a plaza pad |
| **3E spawn protection + combat cooldown** | After the in-zone bust: respawned on a plaza pad, InSafeZone true, 4.0 s protection left with ForceField. Combat toggle inside the zone: Peaceful → Combat accepted, switching back immediately refused with `Cooldown` |
| **3E HUD** | PC: green SAFE ZONE badge under the Combat button. iPhone 7 simulator (666×374) while driving at 2★: amber badge, stars, Combat button and Spawn Car have no overlap, clipping or truncation |
| **3G pre-work** | Current backup confirmed from the Studio log: cloud save + `OutlawCity_3E.rbxl` (144 KB) at 20:46:39Z, after 3E. PROGRESS cleaned (duplicates and stale items removed). Docs now say ramming police is the only implemented crime detector |
| **3G unit tests** | `VehicleValidation.spec` (12): per-vehicle limits; 3 min of generated normal driving (full throttle, brake, reverse, handbrake drift) -> 0 observations; single 260 studs/s collision spike tolerated; falling not counted; sustained overspeed detected + alert; 300-stud teleport -> immediate alert; 90-stud jump noted, alert only when repeated; isolated jumps far apart never alert; authorized reposition and spawn grace not judged; NaN position rejected with baseline kept; brief ownership handover tolerated, persistent mismatch observed. **108/108** |
| **3G false positives (normal play)** | Solo playtest with keyboard driving on the highway: full throttle to top speed, braking, reversing, handbrake drift, a crash into the end wall after a 10 s run, a forced flip with automatic recovery, then exit, new car spawn, exit, character respawn, and an NPC police chase ending in a bust. About 450 samples of legitimate play produced **0 observations and 0 alerts** |
| **3G detection (simulated cheats)** | 815-stud client teleport -> observation + alert in the next sample. Speed hack forcing 230 studs/s (limit 166) for 2.5 s -> 2 SustainedOverspeed observations + 2 alerts. 90-stud jumps: 3 of 4 noted, and the alert fired on the repeat. Server took network ownership for 3 s -> OwnershipMismatch after 1.7 s. Seven observations in total, all from deliberate tests |
| **3G NPC exclusion** | Police dispatched, chased and busted the player during monitoring: no observations; only player vehicles are sampled (NpcVehicles excluded by design) |
| **3G performance** | 5 Hz loop: 0.034 ms average, 0.32 ms max per loop with one player car (869 loops, 764 vehicle samples) |
| **Jail pre-checks** | Studio matched the 3G snapshot (66 scripts); current backup `OutlawCity_3G.rbxl` (cloud save at 00:53Z, after 3G); project CLAUDE.md updated (it still said Phase 2) |
| **Jail unit tests** | `JailRules.spec` (10): 12 s default clamped to 10-15 (bad values -> default); wanted player jailed until the server releases them; zero-wanted refused; duplicate bust neither stacks nor extends; countdown rounding; spawn/drive/combat/robbery blocked only while jailed; cell slots don't overlap; jailed players out of play in `CombatRules` (police, attacker, victim); no remote name touches jail/release; the cell is south of the grid and its 4 slots are ≥ 6 studs apart. **118/118** |
| **Jail: zero wanted** | `SimulateBust` at 0 stars -> refused `NotWanted`, not jailed |
| **Jail: real police bust** | Player in their car at 1★: unit dispatched, busted after 7.9 s -> `[Jail] jailed for 12 s in slot 1`, ejected from the car (car kept), placed in the cell, stars 0, reputation unchanged, pursuit ended, unit despawned |
| **Jail: countdown** | HUD showed 12, 11, 10 s at the same moments the server release time gave 12, 11, 10; it hides on release |
| **Jail: restrictions** | While jailed: `RequestSpawnVehicle` -> `Jailed`; `RequestSetCombatStatus` -> `Jailed`; second bust -> `AlreadyJailed` with the release time unchanged; a server-forced `Seat:Sit` left the seat empty and the player in the cell |
| **Jail: reset doesn't bypass** | Character reset right after the bust: the new character spawned back in the cell (slot 1) with 7.5 s still to serve and the same release time |
| **Jail: release** | Released 0.14 s after the release time (client-observed). Respawned on a civilian plaza pad inside the safe zone with ForceField and 4.6 s spawn protection, 0 stars. Could spawn a car, drive (69 studs/s after 1.5 s W) and use combat again |
| **Jail: reputation preserved** | Reputation 25 before a 3★ bust -> still 25 in jail; stars cleared with no escape reward |
| **Jail: HUD** | PC: IN JAIL / "Release in 11s" panel. Fixed: the panel first overlapped the BUSTED! banner, so it was moved below it, and a light was added to the dark cell. iPhone 7 simulator: banner + panel + top buttons with no overlap, clipping or truncation |
| **4A pre-work** | Fresh backup `OutlawCity_3FINAL.rbxl` (cloud save 01:15:17Z, after the jail). ARCHITECTURE/PROGRESS/ROADMAP headers and outdated lines updated. Jail-reset spawn flash recorded as **must fix before public release**. Studio DataStore API access confirmed (Set/Get probe succeeded) |
| **4A unit tests** | `EconomyRules.spec` (10): starting cash; -5/0/NaN/±inf/1.5/"100"/true/{}/over-max rejected for grant and deduct; missing or too-long tx id; grant/deduct; insufficient funds (exact balance OK); duplicate tx (shared across grant/deduct); bounded tx memory; balance cap; valid saved data kept exactly; 6 malformed shapes refused as Corrupt; lock claim rules; no cash remote. `ProfileStore.spec` (7, fake store that serializes like a DataStore): new player locked; save/load round-trip; **outage during load never creates or overwrites data and later recovers the real balance**; corrupt data untouched (0 writes); live foreign lock blocks, stale lock doesn't; a server that lost its lock can't overwrite; failed save reports an error. **135/135** |
| **4A starting cash + HUD** | First load for this account: `loaded (New) cash=500`; HUD `$500` |
| **4A server-validated changes** | Dev grant +100 -> 600, deduct 100 -> 500. Bad amounts -5, 0, NaN, inf, 1.5, "100", 2,000,000 all `InvalidAmount`, balance unchanged. Deduct 1,000,000 -> `InsufficientFunds`. Tx `dup-test` twice -> second `DuplicateTransaction` |
| **4A tampering** | Client set its `Cash` attribute to 999999: only its local view changed; server still 600 |
| **4A persistence / rejoin (real Studio DataStore)** | Stop play -> `saved on leave (cash=600)`; new playtest -> `loaded (Existing) cash=600`; replaying tx `dup-test` from the previous session -> `DuplicateTransaction` (duplicate guard persists) |
| **4A simulated failures** | Mid-session outage: grant applied in memory (700), 3 save attempts failed and were logged, the save after the outage succeeded. Outage from server start: 3 load attempts failed -> `Unavailable`, HUD "$ offline", grant refused `DataNotLoaded`; left while Unavailable -> nothing saved; next session with the outage ending mid-session -> background retry loaded the real **700** (not the default 500) after 30.7 s: `recovered after a failed load` |
| **4A HUD (mobile)** | iPhone 7 simulator while driving at 2★ in the safe zone: `$700` badge, stars, SAFE ZONE, Combat and Spawn Car with no overlap, clipping or truncation |
| 4A regression | Police dispatch -> bust -> jail -> release with cash unchanged (700); vehicle validation 0 observations; safe-zone enter/leave; driving; no console errors |
| Jail regression | Police dispatch/chase/bust, wanted levels, safe-zone enter/leave, vehicle validation (0 observations in normal play), driving and spawning all working; no console errors |
| 3G regression | Driving, car spawn/exit, civilian respawn, wanted, police chase/bust and the safe-zone enter/exit log all working; 108/108 tests; no console errors |
| 3E regression | Driving, car spawning, civilian spawning, wanted HUD, police dispatch/chase/bust all working; no console errors (one error came from my own test snippet when the player had just been busted, not from game code) |

## Known issues / limitations (open)

1. All multiplayer behaviour is unverified (policy); see `MULTIPLAYER_TESTS.md`.
2. **NPC navigation against unpredictable human driving is UNVERIFIED** (owner note, 3D review). Every moving-target test in 3D used a scripted car on a fixed route at constant speed; those tests are not human-driving validation.
3. **Crime detection:** exactly one gameplay crime detector exists — *ramming a police car* (`PoliceCollisionDetector`; first observed firing in 3D, triggered by a scripted test car). *Speeding near police* and *evading* are defined in `WantedConfig` but have **no detectors**; no other crimes exist. All other wanted levels in testing came from Studio dev tools.
4. Vehicle validation is **monitor-only**: anomalies are logged, nothing is corrected or punished. Its false-positive data covers ~1 minute of solo driving plus transitions and a police chase (about 450 samples); more normal-driving data is needed before enabling corrections. Medium jumps (60-150 studs) can occasionally go unnoticed: one of four was missed, probably because a longer sample gap raised the allowance. Large jumps were always caught. Real network latency is MULTIPLAYER UNVERIFIED.
5. NPC navigation only verified on the grid + highway; the plaza diagonal and highway end plazas weren't driven in tests. No lane discipline (centre line); no knowledge of blocked roads beyond hard recovery. A head-on meet with the target can cause a U-turn before the chase.
6. **MUST FIX BEFORE PUBLIC RELEASE (owner, jail review):** after a reset mid-sentence the new character briefly appears at its civilian respawn pad for a split second before being moved into the jail cell (re-placed immediately and again 0.3 s later). Likely fix: make the jailed player's next spawn the cell itself (a jail SpawnLocation via SpawnService) instead of moving them after spawning.
6a. Jail is session-only: leaving the game mid-sentence ends it.
7. Wanted level survives death/respawn by design (prevents "reset to escape"); owner may want to confirm.
8. `CriminalReputation`, combat status and jail sentences are still session-only. 4A persists **cash only**; adding reputation/jail to the profile needs approval.
8a. Cash persistence was tested in Studio against a real DataStore (`_Studio` suffix). Not tested: two real servers contending for one player's lock (needs two live servers; MULTIPLAYER UNVERIFIED), DataStore throttling under load, and the published game's live store.
8b. The Studio-only dev panel is now taller than a small phone screen (it is clipped; F8 hides it; never in published servers).
9. Player-vs-player harm (combat rules, safe zones, spawn protection) is verified only with mock players: no PvP damage exists yet.
10. Parked cars have a tiny vertical velocity jitter at rest (positions stable to ±0.01 stud).
11. Other players see wheels at rest pose (wheel animation is local to the simulating client). Cosmetic. MULTIPLAYER UNVERIFIED.
12. The driver's head pokes through the Coupe roof. Cosmetic.
13. Steering is fairly sharp at low speed (turn radius ~16 studs at 30 studs/s); tune after owner feedback.
14. The original template `Workspace.SpawnLocation` is disabled (owner-approved), not deleted.
15. The Studio-only dev panel covers the left edge on small phones (toggle with F8). Never present in published servers.

## Fixed during development

- Camera occasionally reverted to the default camera while driving. Cause: the Studio MCP tool resets `CameraType` after running test code. Camera controller now re-asserts Scriptable each frame while driving.
- Team and Spawn Car buttons sat in the top-right corner, which Roblox's player list covers once teams exist (clicks hit Roblox UI). Moved both to a top-centre row.
- Evading notice reported one star fewer at an exact threshold (3C pre-check): threshold rule documented, notice reports pre-tick stars, dev stars set mid-band.
- NPC trailed a moving target by ~65 studs (3D): predicted target + chase-speed rule → steady 25-stud gap.
- NPC stalled forever in front of a wall (3D): stuck detection now keys on wanted progress, not throttle.
- Backup status: verified each stage from the Studio log; a backup copy was opened and played in 3C.

## Direction change (2026-10-13)

Permanent Police/Criminal teams were **superseded** by a civilian open-world design (`DESIGN.md`), approved by the owner with revisions (see `PHASE3_PLAN.md`). The team code was removed from Studio in 3A and is preserved in git (tag `teams-superseded`).

## Upcoming (approved order; each waits for the previous report)

- 3A civilian spawning ✅ · 3B wanted ✅ · 3C combat status ✅ · 3D one NPC police unit ✅ (stays at one unit) · 3E safe zones ✅ — all solo-tested and provisionally approved
- ~~3G server vehicle movement validation~~ — done (solo, **monitor-only**); awaiting owner review before any automatic correction or the jail
- ~~Short jail (12 s, 10-15 configurable)~~ — provisionally approved (solo); Phase 3 signed off
- ~~4A cash and persistence~~ — done (solo, real Studio DataStore); **awaiting owner approval** before the robbery system
- Robbery system — after 4A review
- 3F Studio-only test tools — maintained throughout
