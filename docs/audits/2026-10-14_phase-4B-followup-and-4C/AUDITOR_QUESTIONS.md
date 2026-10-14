# Questions for the auditor: 2026-10-14_phase-4B-followup-and-4C

Answer each by number. Where you disagree with a design choice, say what you would do instead and why.

## Correctness and security
1. `DealershipService` guards purchases with an in-flight flag, a 1 s rate limit, `AlreadyOwned` and the persisted transaction list. `EconomyRules.purchaseVehicle` never yields. Is there any path where one player could be charged twice or get the car without paying?
2. The client receives prices through a read-only shared config and sends only a vehicle id. Do you see any way the client influences the price or ownership?
3. `VehicleService` lets the starter Coupe spawn even while cash data is unavailable, and requires a loaded profile for any other car. Is that the right trade-off?
4. Robbery payouts use three guards: phase transition, per-server paid set, and persisted tx id `robbery:<GUID>`. Is the per-server set redundant, or is it worth keeping?

## Data safety and persistence
1. The migration runs inside the load's `UpdateAsync`, so the v2 record is written in the same atomic update that claims the session lock. Any risk in migrating on load instead of on first save?
2. Records with a version newer than the server knows are refused untouched (`Corrupt`). This makes the player's cash unavailable on an old server during a rollout. Is that acceptable, or should an old server load read-only instead?
3. Orphan saves keep a profile in memory for up to 15 min after a failed leave-save. If the player joins another server during that time, that server waits for the 180 s lock to go stale and then loads the older stored record. Afterwards, this server's orphan save is refused (`LockLost`) and the newer in-memory data is dropped with a warning. Is that ordering safe enough, or should the lock timeout and orphan behaviour change?
4. A pending robbery reward is lost if the player leaves while their data is still offline. Is in-session retry plus "stay in game" messaging enough for now, or should pending rewards be persisted separately (another DataStore key or MemoryStore)?

## Design and maintainability
1. Prices live in `DealershipConfig` (shared, frozen) and ownership in the economy profile. Should ownership and purchases move to their own service/profile section before more vehicles are added?
2. `EconomyService` now owns cash, ownership, orphan saves and several Studio test hooks. Is it getting too large, and where would you split it?

## Testing gaps
1. No robbery getaway has paid out in 13 solo attempts. Which test would best show whether escapes are possible: a longer scripted route with line-of-sight breaks, or a tuning change first?
2. What multiplayer tests should run first when real players are available (see `docs/MULTIPLAYER_TESTS.md`)?

## Decisions the owner should make
1. Police pursuit tuning for robbery getaways: remove or lower `ChaseGain`, shorten `SightRange` (160 → 100), shorten the decay delay for 2★, or keep as is. Which would you recommend?
2. Should "Allow HTTP Requests" (currently on in the place, unused by game code) be switched off before any public test?
