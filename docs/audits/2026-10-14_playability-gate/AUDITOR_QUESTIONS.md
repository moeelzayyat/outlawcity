# Questions for the auditor: 2026-10-14_playability-gate

Answer each by number.

## Correctness and security
1. Is the re-seat retry in `VehicleService.spawnVehicle` safe? It runs up to 10 × 0.1 s, stops after the first successful seat, and also stops when the seat is taken, the car is gone, or the player has died or may not drive. Can you see a case where it seats someone who shouldn't be seated?
2. The client now follows `Humanoid.SeatPart` as well as `Seated`, and clears a removed current car. Any risk of double "driving changed" handling?

## Testing gaps
1. The seat fix has no unit test (it depends on Roblox seat welds); it is verified in Studio. Is that acceptable?

## Earlier conditions (included in this range)
1. Do `spawnChoice`, the tip rule and the fail-once guard close the four onboarding conditions?

## Decisions the owner should make
1. Is `docs/PLAYTEST_CHECKLIST.md` the right size and focus for deciding the next step (escape difficulty, the 90 s cooldown, the Muscle price)?
