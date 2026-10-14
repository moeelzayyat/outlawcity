# Auditor report: 2026-10-14_playability-gate

- Project: OUTLAW CITY (Roblox, place ID 132163592957463)
- Date: 2026-10-14
- Commit range: `fc3e5c3..3693ab9`
- Prepared by: Claude (primary integration agent)
- Status: awaiting owner approval. Compact package. It also carries the onboarding-condition fixes (commit `9bfa55a`), which weren't submitted separately; their earlier draft package is superseded by this one.

## 1. What was asked
**Playability gate (owner), strictly limited to:**
1. Fix the bug where replacing a vehicle while driving leaves the player standing beside the new car.
2. Keep ownership validation, spawn cooldowns, jail restrictions, vehicle handling and camera behaviour.
3. Run the automated tests and normal solo regression checks.
4. Verify robbery, police pursuit, jail, dealership and cash persistence.
5. Write a simple 10-minute playtest checklist for the owner, with no dev tools.
6. Keep the experimental pursuit values and the 90 s failed-robbery cooldown.
7. Document the results and the remaining limits.
8. Stop with a compact audit package.

No new content or infrastructure. Anti-cheat stays monitor-only, multiplayer stays MULTIPLAYER UNVERIFIED, and decisions follow playability feedback.

## 2. What was built
- **The fix, in two parts:**
  - *Server* (`VehicleService.spawnVehicle`): the old car was destroyed while the character was still welded to its seat, so the new `seat:Sit` could fail. Now the player leaves the old seat cleanly first, the same way `exitVehicle` does. The server then sits them in the new car and retries for up to 1 s (10 × 0.1 s) until they have been seated once. It stops early if the seat is taken, the car is gone, the player died, or the player isn't allowed to drive (jail).
  - *Client* (`VehicleController`): moving straight from one seat to another may not fire `Seated` again. The client kept "driving" the destroyed car, so the new car got no input. It now also follows `Humanoid.SeatPart`, and clears a current car that was removed.
- **Onboarding conditions** (from the previous verdict, included here):
  - `OnboardingRules.spawnChoice` sends the only owned car; while the car list isn't loaded it sends the starter Coupe only; with no cars it sends nothing.
  - The tip closes only on Holding/Escaping.
  - A robbery fails, and changes the cooldown, at most once.
  - The 90 s cooldown is labelled EXPERIMENTAL.
- **`docs/PLAYTEST_CHECKLIST.md`:** 10 steps in about 10 minutes, no dev tools, with what to note at each step.

## 3. How it works
Only `VehicleService.spawnVehicle` (server) and `VehicleController` (client) changed for the fix. These were not touched:
- the ownership check (`EconomyService.ownsVehicle`);
- the jail check (`JailService.allows(player, "SpawnVehicle")`);
- the rate limiter (3 s);
- physics (`VehiclePhysics`);
- the camera controller.

## 4. Security and authority
- No remotes changed. The re-seat retry only seats the requesting player in their own new car, and only while they may drive.
- The client change only affects which car the local input drives. The car's simulation owner is still decided by the server (`SimulatedBy`).

## 5. Persistence and data safety
None changed.

## 6. Decisions made
- **Retry window of 1 s, stopping after the first successful seat,** so a player who gets out straight away isn't pulled back in.
- **No unit test for the seat fix:** it depends on Roblox seat welds and humanoid state, so it was verified in Studio instead (exact readings in TEST_EVIDENCE.md).

## 7. Deviations from the request
None.

## 8. Unresolved risks and known issues
- **Medium:** human feedback is still thin. There is one logged owner session: they briefly lost the police, then were busted. Escape difficulty, the 90 s cooldown and the $15,000 price wait for the playtest.
- **Low:** if no spawn pad is free, the old car is already gone and the player stays on foot (`NoFreeSpawn`). Unchanged and rare.
- **Low:** no real-phone check yet.

## 9. Multiplayer status
MULTIPLAYER UNVERIFIED: seat changes seen by other players, two players spawning at the same pads, and everything else multiplayer.

## 10. Files for the auditor
AUDITOR_REPORT.md, TEST_EVIDENCE.md, SOURCE_DIFFS.md, CHANGE_MANIFEST.md, AUDITOR_QUESTIONS.md, plus the docs PROGRESS.md, PLAYTEST_CHECKLIST.md, ARCHITECTURE.md, TEST_CHECKLIST.md, ROADMAP.md.
