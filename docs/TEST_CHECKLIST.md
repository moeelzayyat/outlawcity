# OUTLAW CITY — Test checklist

Run after every change, in Roblox Studio. Unit tests run automatically at the start of every playtest; the Output window must show `[Tests] N passed, 0 failed` and no red errors.

## Automated (unit tests in ServerStorage.Tests)
- [ ] `VehicleMath.spec` — acceleration, top speed, braking into reverse, coasting, handbrake, steering signs, spring balance
- [ ] `VehicleConfig.spec` — every vehicle has 4 wheels, sane stats, frozen config
- [ ] `RateLimiter.spec` — cooldowns per key, reset
- [ ] `Remotes.spec` — remote classes, naming, all remotes created by the server
- [ ] `CityLayout.spec` — no overlapping road parts, no gaps along grid roads, spawns on road, connectors reach the highway

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

## Teams (solo)
- [ ] `TeamRules.spec` and `TeamConfig.spec` pass (balance, same-team, unknown team, simulated 8-player lobby)
- [ ] On join the "Choose your side" screen opens; there is no X button while Neutral
- [ ] Join Police: screen closes, top button reads "Team: Police", name colour is blue
- [ ] Reopen with the Team button; switching within 10 s shows the cooldown message; after 10 s switching works
- [ ] Card shows player counts and "Current team" on your own team
- [ ] Vehicle spawning still works after joining a team

## Mobile (Device Simulator, phone landscape)
- [ ] Team screen fits on the smallest phone (iPhone 7, 667×375): no clipping, text fits, buttons ≥ 44 px; Join works by tap
- [ ] Team and Spawn Car buttons (top centre) reachable, not under the Roblox top bar or player list
- [ ] GAS / BRAKE / DRIFT / EXIT visible only while driving, no overlap with the thumbstick
- [ ] Thumbstick steers; GAS drives; BRAKE brakes and reverses; EXIT leaves the car
- [ ] Jump button hidden while driving and back after exit

## Multiplayer — deferred
Solo playtests are the current policy (owner decision 2026-10-13). Multiplayer checks live in `MULTIPLAYER_TESTS.md` and stay **MULTIPLAYER UNVERIFIED** until run with real players. Never tick a multiplayer item based on a solo run.
