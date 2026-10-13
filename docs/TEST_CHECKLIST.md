# OUTLAW CITY — Test checklist

Run after every change, in Roblox Studio. Unit tests run automatically at the start of every playtest; the Output window must show `[Tests] N passed, 0 failed` and no red errors.

## Automated (unit tests in ServerStorage.Tests)
- [ ] `VehicleMath.spec` — acceleration, top speed, braking into reverse, coasting, handbrake, steering signs, spring balance
- [ ] `VehicleConfig.spec` — every vehicle has 4 wheels, sane stats, frozen config
- [ ] `RateLimiter.spec` — cooldowns per key, reset
- [ ] `Remotes.spec` — remote classes, naming, all remotes created by the server
- [ ] `CityLayout.spec` — no overlapping road parts, no gaps along grid roads, spawns on road, connectors reach the highway, civilian spawns in the plaza and clear of vehicle pads
- [ ] `SpawnRules.spec` — random free spawn, occupied spawns skipped, least-crowded fallback
- [ ] `PlayerAttributes.spec` — attribute names, frozen gameplay config, no team system left

## Solo playtest (Play, PC)
- [ ] Press **V** or click **Spawn Car**: a car appears on the nearest free pad and you are seated
- [ ] **W** accelerates smoothly, speedometer rises; top speed is ~75 mph
- [ ] **S** brakes, then reverses after stopping
- [ ] **A/D** steer; turning feels responsive, not twitchy at highway speed
- [ ] **Space** handbrake slows the car and lets the rear slide; you stay in the seat
- [ ] Camera follows behind, pulls back and widens with speed, does not clip into buildings
- [ ] Drive the full grid, onto the highway via a connector, to both end plazas and back
- [ ] Hit a barrier and a building: the car stops, does not fling or fall through
- [ ] Flip the car (e.g. off a curb at speed): it rights itself after ~2 s if stuck on its roof
- [ ] **F** exits next to the car; camera returns to normal; **E** prompt re-enters
- [ ] Spawn again within 3 s: "Wait a moment" message; after 3 s the old car is replaced

## Civilian spawning (3A, solo)
- [ ] `SpawnRules.spec`, `PlayerAttributes.spec` and the `CityLayout.spec` spawn test pass
- [ ] On join there is no team screen; `Teams` is empty; the player has `Status = "Civilian"`
- [ ] The player appears on one of the 6 blue `City.CivilianSpawns` pads around the plaza (not the original centre SpawnLocation)
- [ ] Reset the character several times: spawns vary and the character appears on the chosen pad each time
- [ ] Park a car on a civilian pad and reset several times: that pad is never chosen
- [ ] After each spawn: ForceField visible and `SpawnProtectedUntil` ≈ now + 5 s; both gone after 5 s
- [ ] Vehicle spawn, drive, exit and camera still work (regression)

Server snippet for respawn checks (Studio command bar or MCP, Server context):
`local p = game.Players:GetPlayers()[1]; p.Character.Humanoid.Health = 0; p.CharacterAdded:Wait(); task.wait(0.5); print(p.RespawnLocation.Name, p.Character.HumanoidRootPart.Position)`

## Mobile (Device Simulator, phone landscape)
- [ ] Spawn Car button (top centre) reachable, not under the Roblox top bar or player list
- [ ] GAS / BRAKE / DRIFT / EXIT visible only while driving, no overlap with the thumbstick
- [ ] Thumbstick steers; GAS drives; BRAKE brakes and reverses; EXIT leaves the car
- [ ] Jump button hidden while driving and back after exit

## Multiplayer — deferred
Solo playtests are the current policy (owner decision 2026-10-13). Multiplayer checks live in `MULTIPLAYER_TESTS.md` and stay **MULTIPLAYER UNVERIFIED** until run with real players. Never tick a multiplayer item based on a solo run.
