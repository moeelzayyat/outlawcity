# OUTLAW CITY — Progress

Last updated 2026-10-13.

## Completed (each verified in a Studio playtest unless noted)

| Feature | How it was verified |
|---|---|
| Typed Luau architecture (Shared / Server / Client / Tests) | Place boots with no errors in the Output window |
| Network contract + server validation | `Remotes.spec`; spawn and exit requests work in playtest |
| Unit test runner (runs at the start of every Studio playtest) | `[Tests] 25 passed, 0 failed` |
| City test map: road grid, intersections, plaza, sidewalks, buildings | `CityLayout.spec` (no overlaps, no gaps, spawns on road); built in Workspace.City (187 parts) |
| Highway with connectors, median, barriers, end plazas | `CityLayout.spec` connector tests; visual check pending (see known issues) |
| Vehicle spawning (V key / Spawn button), one car per player, 3 s cooldown | Playtest: car spawned on nearest free pad, player auto-seated |
| Acceleration, braking, reverse | Playtest log: 0 → 68 studs/s (~43 mph) in 1.5 s; S brakes to 0 then reverses |
| Steering | Playtest log: W+D gives a steady right turn (~-1.9 rad/s yaw at ~30 studs/s) |
| Handbrake on Space without ejecting the driver | Playtest: driver stays seated after Space |
| Exit (F / touch EXIT) and re-enter (E prompt) | Playtest: seated state, camera and HUD toggle correctly |
| Chase camera | Playtest: camera switches to Scriptable while driving, back to default on exit |
| Mobile controls (iPhone 17 Pro simulator) | GAS drives forward, BRAKE reverses, EXIT leaves the car, jump button hidden while driving; layout screenshot has no overlaps |
| Suspension rests the car on its springs | Chassis settles at the expected ride height (1.87 studs, up-vector 1.00) |

## Known issues / limitations

1. **Studio MCP screenshots render the 3D view white**, so the map and car have not been visually checked by the agent yet. Needs one look by the owner in Studio.
2. **Multiplayer not tested yet**: the Studio MCP can only start a solo playtest. Needs a manual Test → Clients and Servers run with 2 players (see `TEST_CHECKLIST.md`).
3. Parked cars have a tiny vertical jitter at rest (~1 stud/s velocity noise from per-frame spring impulses). Not visible in the logs' positions (±0.01 stud); revisit if it shows on camera.
4. Other players see wheels at their rest position (wheel animation is local to the simulating client). Cosmetic.
5. No server-side speed/teleport check on client-simulated vehicles yet (planned for Phase 3, required before rewards).
6. Vehicles have no collision damage, sounds or lights logic yet (out of scope for Phase 2).
7. Steering is fairly sharp at low speed (turn radius ~16 studs at 30 studs/s); tune `MaxYawRate` / `FullSteerSpeed` after owner feedback.

## Fixed during development

- Camera occasionally reverted to the default camera while driving. Cause: the Studio MCP tool itself resets `CameraType` after running test code. The camera controller now re-asserts Scriptable every frame while driving, which also guards against other scripts.

## Upcoming (Phase 2 sign-off)

- Owner playtest on PC and phone; collect handling feedback.
- Manual 2-player test.
- Then ask for approval to start Phase 3.
