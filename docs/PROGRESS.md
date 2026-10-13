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
| Network contract + server validation | `Remotes.spec`; spawn, exit and team requests behave in playtest |
| Unit test runner (runs at the start of every Studio playtest) | `[Tests] 33 passed, 0 failed` |
| City test map: grid, intersections, plaza, sidewalks, buildings, highway | `CityLayout.spec`; drive tests above; visual check in screenshots |
| Vehicle: spawn, drive, brake, reverse, steer, handbrake, exit/enter | Playtest logs (see Phase 2 table) |
| Chase camera | Playtest measurements above |
| Mobile driving controls | iPhone 17 Pro simulator: GAS, BRAKE/reverse, EXIT work; jump button hidden while driving |
| **3.1 Police and Criminal teams** | Server creates both teams; players start Neutral; remote rejects bad type, unknown team, same team, and switching within 10 s; switch after cooldown works; `TeamRules.spec` incl. simulated 8-player lobby stays within the 2-player imbalance limit. Team colours/balance with real players: MULTIPLAYER UNVERIFIED |
| **3.2 Team selection screen** | Opens on join while Neutral; Join buttons work by mouse (PC) and tap (iPhone 7 simulator, 666×374, no clipping/truncation/small targets); shows player counts, "Current team", cooldown message; X closes only once on a team; Team button reopens it |

## Known issues / limitations

1. Place file save/publish not verified by the agent (see backup row above).
2. All multiplayer behaviour is unverified (policy); see `MULTIPLAYER_TESTS.md`.
3. Parked cars have a tiny vertical velocity jitter at rest (positions stable to ±0.01 stud). Revisit only if visible.
4. Other players see wheels at rest pose (wheel animation is local to the simulating client). Cosmetic. MULTIPLAYER UNVERIFIED.
5. No server-side speed/teleport check on client-simulated vehicles yet — Phase 3 item 8.
6. The driver's head pokes through the Coupe roof. Cosmetic; leave until a vehicle art pass.
7. Steering is fairly sharp at low speed (turn radius ~16 studs at 30 studs/s); tune after owner feedback.
8. Team changes do not respawn the player yet; team spawn points come in Phase 3 item 3.

## Fixed during development

- Camera occasionally reverted to the default camera while driving. Cause: the Studio MCP tool resets `CameraType` after running test code. Camera controller now re-asserts Scriptable each frame while driving.
- Team and Spawn Car buttons sat in the top-right corner, which Roblox's player list covers once teams exist (clicks hit Roblox UI). Moved both to a top-centre row.

## Direction change (2026-10-13)

Permanent Police/Criminal teams are **superseded** by a civilian open-world design (`DESIGN.md`). The team features above (3.1, 3.2) still work and are still active in Studio, but they are slated for removal in step 3A of the revised plan. Their code is preserved in git (tag `teams-superseded`).

## Upcoming

The revised Phase 3 plan (`PHASE3_PLAN.md`) is waiting for owner approval. Nothing beyond it will be built until it is approved.
