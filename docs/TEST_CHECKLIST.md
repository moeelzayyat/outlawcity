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
- [ ] `WantedRules.spec` — thresholds, 5-star extensibility, cooldowns, cap, invalid input, decay, sightings, escape, reset
- [ ] `DevCommandRules.spec` — dev command validation, no public remote touches wanted state, DevRemotes only in Studio
- [ ] `CombatRules.spec` — full PvP / police / safe-zone / spawn-protection matrix with mock players
- [ ] `CombatStatusRules.spec` — Peaceful start, cooldown, wanted lock, activity, invalid requests
- [ ] `PoliceNavigation.spec` — road network on drivable surface, connectivity, planner, steering/corner/chase speed, stuck logic
- [ ] `PoliceDispatch.spec` — single unit, no dispatch unwanted, spawn band, bust rules, combat gate
- [ ] `SafeZoneRules.spec` — plaza zone geometry, hysteresis, PvP blocked in zones, police allowed, wanted unaffected
- [ ] `VehicleValidation.spec` — limits, normal-driving trace, spikes, overspeed, teleports, grace, non-finite, ownership
- [ ] `JailRules.spec` — sentence length, duplicates, zero-wanted, release timing, restrictions, slots, combat gate, cell placement
- [ ] `EconomyRules.spec` / `ProfileStore.spec` — cash validation, duplicates, caps, saved-data checks, locks, outages with a fake store

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

## Wanted level (3B, solo, Studio dev panel — press F8 to toggle)
All of these use **dev tools**. The only gameplay crime detector is ramming a police car (tested in the NPC police section); speeding and evading have no detectors yet.
- [ ] `WantedRules.spec` (14) and `DevCommandRules.spec` (5) pass
- [ ] Dev panel appears in a Studio playtest (left side, "DEV (Studio)"), and `ReplicatedStorage.DevRemotes` exists
- [ ] "Crime: Ramming" → 1 star, heat 25; clicking again within 2 s shows "failed: Cooldown" and heat stays 25
- [ ] "Set 3 stars" → three lit stars at top centre
- [ ] "Police sees me: ON" for 10+ s → heat does not drop, no Evading banner
- [ ] "Police sees me: OFF" → after ~8 s "EVADING..." banner, stars blink and step down
- [ ] Heat reaches 0 → "ESCAPED! +25 REP" banner, stars hide, `CriminalReputation` +25 (server view)
- [ ] From 1 star, escape shows "ESCAPED!" with no reputation
- [ ] "Clear wanted" → stars hide immediately, no Escaped banner, no reputation
- [ ] Wanted level survives a character reset
- [ ] Tamper check (client context): set `CriminalReputation`/`WantedLevel` attributes locally and invoke dev commands with bad values → server values unchanged, commands rejected
- [ ] Vehicle spawn/drive/camera still work while wanted

- [ ] Dev "Set 3 stars" does not drop to 2 stars on the first decay tick (heat is placed mid-band)

## Peaceful / Combat status (3C, solo)
No weapons or damage exist: player-vs-player harm is verified only through `CombatRules.spec` with mock players.
- [ ] `CombatRules.spec` (7) and `CombatStatusRules.spec` (9) pass
- [ ] On join the top-left-of-centre button reads PEACEFUL (green); `CombatStatus` attribute = Peaceful
- [ ] Click → COMBAT (red) with a live countdown from 30 s
- [ ] Two clicks within 1 s → "Too fast"
- [ ] Click during the countdown → "Wait for cooldown", stays COMBAT
- [ ] Dev "Set 2 stars" → button reads "COMBAT (locked)"; after the countdown, asking for Peaceful → "Locked: wanted"; stars unchanged
- [ ] While Peaceful, dev "Set 1 star" → button reads "PEACEFUL (wanted!)" (wanted players lose peaceful protection)
- [ ] Clear wanted after the cooldown → Peaceful accepted
- [ ] Client snippet with invalid targets (`123`, `"Admin"`, `"combat"`, long string, nil) → `InvalidStatus`

## NPC police — single unit (3D, solo)
Watch the Output for `[Police]` lines, or read `Workspace.NpcVehicles` attribute `EventLog` from the server. Unit tests alone don't prove navigation.
- [ ] `PoliceNavigation.spec` (10) and `PoliceDispatch.spec` (8) pass
- [ ] At 0 stars for 10 s: `Workspace.NpcVehicles` stays empty
- [ ] Dev "Set 1 star": a blue/red-lit police cruiser appears on a road 160–450 studs away within ~0.5 s ("dispatched" log line)
- [ ] Drive around the grid: the unit follows through intersections and 90° corners, slows for turns, doesn't hit buildings or barriers
- [ ] Stop and wait: the unit stops ~10–15 studs away; after 2.5 s "BUSTED!" banner, stars clear, you respawn on a plaza pad, the unit leaves 3 s later
- [ ] Get out of its sight (behind buildings or far away): "EVADING..." after ~8 s, then "ESCAPED!", the unit stops and despawns
- [ ] While the unit can see you, heat doesn't drop (dev panel heat value stays)
- [ ] Clear wanted (dev) while the unit is close: no bust, unit despawns
- [ ] Blocked road: place an anchored wall across the road in front of the unit → it reverses, then re-enters elsewhere ("hard recovery" log) and continues
- [ ] Drive your car into the unit at speed: "crime detected: … rammed police" log and heat +25 (real gameplay detection)
- [ ] Try `RequestSpawnVehicle("Police")` from the client → `UnknownVehicle`
- [ ] Physics FPS stays ~60 during a pursuit; status lines show step cost well under 1 ms

## Safe zones (3E, solo)
- [ ] `SafeZoneRules.spec` (8) passes
- [ ] Spawn in the plaza: Output shows `[SafeZone] … entered Plaza`; green SAFE ZONE badge under the Combat button
- [ ] Walk or drive out of the plaza: badge hides within ~0.5 s; back in: it shows again
- [ ] Stand just past the plaza edge (1–2 studs): still inside; 3+ studs past: outside
- [ ] Become wanted (dev) outside, then enter: stars and heat unchanged, no notice; the badge turns amber
- [ ] Stay in the plaza while wanted: the police unit still comes and busts you
- [ ] After respawn in the plaza: ForceField + spawn protection; the combat cooldown still blocks Peaceful
- [ ] Combat status changes don't affect zone protection (covered by spec; there's no PvP damage to test live)

## Vehicle movement validation (3G, solo, MONITOR-ONLY)
Read results on the server: `ServerStorage.Diagnostics` attributes `Samples`, `Observations`, `Alerts`, `ValidationLog`, plus `[VehicleValidation]` lines in the Output. Nothing is ever corrected or punished.
- [ ] `VehicleValidation.spec` (12) passes
- [ ] Spawn a car: no observation (spawn grace)
- [ ] Drive normally for a few minutes (top speed, braking, reverse, drift, crashes, flips, exit/enter, respawn): **0 observations**
- [ ] Client teleports its car 300+ studs -> `Teleport` observation + ALERT
- [ ] Client forces 230 studs/s for 2 s -> `SustainedOverspeed` + ALERT
- [ ] Two 90-stud client jumps within 10 s -> ALERT on the repeat (one alone: observation only)
- [ ] Server sets the car's network owner to nil for 3 s -> `OwnershipMismatch`
- [ ] NPC police chase: no observations for the police car
- [ ] Summary line every 30 s shows loop cost well under 1 ms

## Short jail (solo)
- [ ] `JailRules.spec` (10) passes
- [ ] Dev "Simulate bust" at 0 stars -> refused (`NotWanted`), not jailed
- [ ] Get busted by the police unit while wanted -> `[Jail] … jailed for 12 s`, ejected from the car, in the cell south of the city, stars 0, BUSTED! banner, IN JAIL countdown
- [ ] Countdown ticks down in step with the server (12 -> 0) and hides on release
- [ ] While jailed: Spawn Car refused ("can't spawn a car while in jail"), Combat button refused, second "Simulate bust" refused
- [ ] Reset the character while jailed -> back in the cell, same release time
- [ ] On release: respawn on a plaza pad with ForceField / spawn protection; car spawning, driving and combat work again
- [ ] Reputation and the parked car are unchanged after jail
- [ ] Phone (iPhone 7): BUSTED! banner and IN JAIL panel both visible, no overlap

## Cash and persistence (4A, solo; Studio DataStore uses a `_Studio` store)
- [ ] `EconomyRules.spec` (10) and `ProfileStore.spec` (7) pass
- [ ] Join: Output `[Economy] … loaded (New|Existing) cash=…`; HUD shows `$` balance (new accounts: $500)
- [ ] Dev "Cash +100" / "Cash -100" change the balance and HUD
- [ ] Dev GrantCash with -5, 0, NaN, inf, 1.5, "100", 2000000 -> `InvalidAmount`, balance unchanged
- [ ] Dev DeductCash more than the balance -> `InsufficientFunds`
- [ ] Dev "Cash +100 (tx dup-test)" twice -> second refused `DuplicateTransaction`; still refused after a rejoin
- [ ] Client sets its own `Cash` attribute -> server value unchanged
- [ ] Stop and start the playtest: same balance (`saved on leave`, then `loaded (Existing)`)
- [ ] Dev `SetDataStoreFailure` true -> grant, "Save data now" fails (logged); false -> save succeeds
- [ ] Set Workspace attribute `SimulateDataStoreFailureOnStart = true`, play: `Unavailable`, "$ offline", grants refused; stop -> "nothing saved"; play again, dev `SetDataStoreFailure` false -> within ~30 s `recovered`, real balance (not 500). **Remove the attribute afterwards.**

## Store robbery (4B, solo; F8 dev panel "Store: clear cooldown")
- [ ] `RobberyRules.spec` (9) passes
- [ ] 24/7 MART stands on block (-200, 0) by the x = -100 road; "Rob store" prompt appears at the register
- [ ] From the plaza (dev `TryRobStore`) -> "No robberies inside a safe zone"; 20 studs from the register -> "Get closer"; while jailed -> rejected; in a car -> "Get out of your car"
- [ ] Rob: alarm toast, 2★, "ROBBING THE STORE 15s" counts down from the server; stars don't decay while inside
- [ ] Holdout ends at 15 s -> "ESCAPE THE POLICE" panel; lose the stars -> one "+$2,000" toast; Output shows one `grant 2000 ... tx robbery:<id>`
- [ ] Busted during holdout or escape -> "busted ... No cash"; cash unchanged
- [ ] Die or reset during holdout or escape -> "you died. No cash"; later escape pays nothing
- [ ] Walk out during the holdout -> "you left the store too early"
- [ ] Prompt again during a robbery -> "already on a robbery"; prompt within 180 s of the last start -> "robbed recently. Try again in Ns"
- [ ] An ordinary escape (dev stars) after a robbery pays nothing
- [ ] Client sets its own `Cash` / `RobberyPhase` and fires `OnRobberyNotice` -> server unchanged
- [ ] Stop/start after a paid robbery -> same balance (`loaded (Existing)`)
- [ ] Phone (iPhone 7): prompt usable by tap; panel and toasts readable, no overlap with the top row
- [ ] Dev `SetCashUnavailable` true -> robbery refused "cash data isn't loaded"
- [ ] Rob, set `SetCashUnavailable` true during the escape, escape -> "REWARD PENDING"; set it false -> one +$2,000, one `grant` line
- [ ] Workspace `SimulateDataStoreFailure` = true, rob + escape (paid), leave -> "save on leave failed; keeping the profile"; set it false -> "saved after leaving"; rejoin -> same balance. **Clear the attribute afterwards.**
- [ ] Driving getaway: park a car at the storefront, rob, drive away and lose the police -> one +$2,000

## Dealership and second vehicle (4C, solo; dealership at (200, 136), desk at (188, 145))
- [ ] `EconomyRules.spec`, `ProfileStore.spec`, `Dealership.spec` pass
- [ ] Cash-only profile: join -> Output `loaded (Migrated) cash=<same>`; `OwnedVehicles` = Coupe (repeat with dev `WriteLegacyProfile`, then rejoin)
- [ ] `RequestSpawnVehicle("Muscle")` before buying -> `NotOwned`
- [ ] Buy from far away -> "Walk up to the sales desk"; with less than $15,000 -> "Not enough cash: you need $X more"; nothing charged
- [ ] With $15,000+: Buy -> "Bought the Muscle!", cash -15,000 exactly once, window shows Owned; spam Buy -> still one charge
- [ ] Garage (Spawn Car) lists Coupe and Muscle; picking Muscle spawns and seats you; V spawns the last pick
- [ ] Muscle is faster off the line and slides more than the Coupe
- [ ] Rejoin -> Muscle still owned, same cash
- [ ] Workspace `SimulateDataStoreFailure` = true, buy, leave with it still on -> next join (after the old lock clears) has neither the charge nor the car; buy during an outage that ends before leaving -> both saved. **Clear the attribute afterwards.**
- [ ] Phone (iPhone 7): garage and dealership windows below the top row, buttons tappable, cash badge visible
- [ ] Phone: Muscle with GAS / BRAKE / DRIFT / EXIT and thumbstick steering (real device: owner)

## Economy durability (audit remediation, solo; Workspace attributes are Studio-only)
- [ ] `ProfileStore.spec` and `RewardLedger.spec` pass
- [ ] `SimulateStoreFailure_OutlawCity_PlayerData_v1` = true, buy a car -> "Couldn't save your purchase… Nothing was charged"; Output `NOT applied`; cash and garage unchanged. Set it false, buy again -> bought once
- [ ] Same attribute on, rob + escape -> "Your reward is safely recorded"; stop the server with it still on; next session (after the old lock clears, up to 3 min) -> +2000 once, ledger empty
- [ ] `SimulateDataStoreFailure` = true during an escape -> pending (not recorded); set it false -> paid once
- [ ] Idle 3+ minutes in game: Output shows no lock problems; rejoin works (heartbeat keeps the lock fresh)

## Final audit fixes (solo; Workspace attributes are Studio-only)
- [ ] `ProfileSession.spec`, `RewardLedger.spec`, `EconomyRules.spec` pass
- [ ] `SimulateCommitThenError_OutlawCity_PlayerData_v1` = 1, dev grant -> Output `reconciled from the store` and `(stored, AlreadyApplied)`; cash +amount once in the store
- [ ] Same switch, buy a car -> charged once, owned; a heartbeat afterwards doesn't undo it
- [ ] `SimulatePurchaseError` = true, buy -> "couldn't confirm" message; switch off, buy again within 2 s -> works (no "Busy")
- [ ] Dev `AddLedgerReward` 500, restart with `SimulateStoreFailure_OutlawCity_PendingRewards_v1` set -> "ledger unreadable; retrying later" (backing off); clear it -> paid once. **Clear the attribute afterwards.**

## Audit conditions
- [ ] `ProfileSession.spec`: FIFO order; heartbeat refused after leave; ambiguous multi-reward claim paid once
- [ ] `RewardLedger.spec`: invalid rewards refused before reaching the ledger

## Onboarding batch (audit 4)
- [ ] `OnboardingRules.spec` (7) and `RobberyRules.spec` cooldown tests (+3) pass; `RewardLedger.spec` refuses ±infinity timestamps
- [ ] One owned car: one click/tap on Spawn Car seats you; two cars: the garage window opens
- [ ] On spawn, both markers show with distances; the store marker hides at the register
- [ ] First-spawn tip shows once, closes after 15 s, with X, or when a robbery starts; driving works while it shows
- [ ] Escape panel says "Break line of sight, then stay hidden until your stars are gone"; "Stars fading..." while evading
- [ ] After a failed robbery the store marker counts down and the store reopens 90 s after the start; after a successful one, 180 s
- [ ] Dealership window shows "Muscle: $X of $15,000. About N more successful robberies." (8 from $500)
- [ ] Phone (666x374): robbery panel 260x64 at y 92, text fits, no overlap with the top HUD row
- [ ] Studio Output prints `[Milestone] ... FirstCar / FirstRobbery / FirstEscape` once each
- [ ] **Owner, real phone:** panel, tip and markers readable; nothing blocks the touch controls
- [ ] Conditions: stale selection + one car spawns the owned car; not-loaded spawns the starter Coupe; the tip stays for PayoutPending/cleared and closes for Holding; repeated/overlapping failures change the cooldown once (`RobberyRules.spec`)

## Playability gate
- [ ] While driving, Spawn Car (or V, or picking the other car in the garage) seats you in the new car; W drives it at once; the camera stays behind the car; F still exits
- [ ] A second spawn within 3 s shows "Wait a moment before spawning again."; jailed players can't spawn; unknown/unowned cars are refused
- [ ] Owner's 10-minute playtest: `docs/PLAYTEST_CHECKLIST.md` (no dev tools)

## Atmosphere Batch 1
- [ ] `AtmosphereRules.spec` passes; client Lighting shows the preset values; the place's own Lighting (server) is unchanged
- [ ] The police unit's light bar alternates red/blue about every 0.25 s while it exists; one local PointLight; nothing left after despawn (repeat 5×)
- [ ] `Lighting = false` gives the original look; `PoliceLights = false` gives the static bar; the siren plays only with `Siren = true` and an approved id
- [ ] FPS and memory before vs after (Studio in front), idle and during a chase; phone simulator / real phone

## Police pursuit tuning (audit remediation, EXPERIMENTAL)
- [ ] With SightRange 130 / ChaseSpeed 100 / ChaseGain 0.25: rob, drive away normally, lose the police -> paid once
- [ ] Police still catch a robber who stops or crashes nearby (bust within 18 studs, slow for 2.5 s)
- [ ] **Human playtest (owner):** does escaping feel fair, too easy or too hard?

## Mobile (Device Simulator, phone landscape)
- [ ] SAFE ZONE badge visible on iPhone 7 with the stars and the Combat button, no overlap
- [ ] Combat button, Spawn Car, wanted stars and banners visible, no overlap or clipping on iPhone 7 (666×374) while driving
- [ ] Spawn Car button (top centre) reachable, not under the Roblox top bar or player list
- [ ] GAS / BRAKE / DRIFT / EXIT visible only while driving, no overlap with the thumbstick
- [ ] Thumbstick steers; GAS drives; BRAKE brakes and reverses; EXIT leaves the car
- [ ] Jump button hidden while driving and back after exit

## Multiplayer — deferred
Solo playtests are the current policy (owner decision 2026-10-13). Multiplayer checks live in `MULTIPLAYER_TESTS.md` and stay **MULTIPLAYER UNVERIFIED** until run with real players. Never tick a multiplayer item based on a solo run.
