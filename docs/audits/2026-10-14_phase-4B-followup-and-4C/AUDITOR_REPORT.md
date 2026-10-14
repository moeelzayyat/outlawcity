# Auditor report: 2026-10-14_phase-4B-followup-and-4C

- Project: OUTLAW CITY (Roblox, place ID 132163592957463)
- Date: 2026-10-14
- Commit range: `4ed77f3..5bdb1c9` (4ed77f3 = Phase 4B as provisionally approved by the owner)
- Prepared by: Claude (primary integration agent)
- Status: awaiting owner approval (4C), plus one open owner decision (police pursuit tuning)

## 1. What was asked

**4B follow-up.** The owner provisionally approved 4B and asked for these before 4C:
- recoverable robbery payouts with stable server transaction ids and no duplicate grants;
- tests where the reward is accepted but the save fails, and where the grant fails before it is applied;
- pending rewards survive session transitions, or mission completion is clearly prevented when durable reward handling is unavailable;
- validate at least one driving getaway;
- record the NPC storefront issue and propose a simple roadside stop, without building complex pathfinding.

Later the owner chose "send police when the holdout ends" (option 1).

**Phase 4C:**
- one dealership in the existing city;
- one purchasable second vehicle at a configurable $15,000;
- a server-authoritative purchase API;
- persistent ownership in the existing profile, with a safe migration from cash-only;
- dealership and garage UI for PC and mobile;
- spawning restricted to owned vehicles;
- clear purchase feedback and distinct handling for the new car.

Security requirements: purchases validated on the server, client prices and ownership never trusted, duplicate requests rejected, cash and ownership updated atomically, and safe handling of DataStore failures, session locks and disconnects. Not allowed: more vehicles, banks, garages, property, gangs, weapons or monetization. NPC police stay at one unit, and anti-cheat stays monitor-only.

## 2. What was built

**4B follow-up**
- A robbery can't start unless the player's cash data is loaded (`CashUnavailable`).
- A reward that fails temporarily stays pending under the fixed id `robbery:<sessionId>` and is retried every 2 s until paid once (`PayoutPending`).
- A profile whose save on leave fails is kept on the server and retried ("orphan" saves).
- During a robbery the police unit is held back until the holdout ends (`PoliceService.setDispatchHold`).
- Driving getaway tested 13 times with real vehicle physics. **It has not yet produced a paid escape** (see section 8).

**4C**
- OUTLAW MOTORS dealership at (200, 136): a showroom, a sales desk with a prompt, and a display car.
- `Muscle` car for $15,000: top speed 138 vs 120 and acceleration 68 vs 55, but less grip, slower turning and longer braking.
- `RequestPurchaseVehicle`, validated by `DealershipService`.
- Profile version 2 with `OwnedVehicles`, and an in-load migration from version 1.
- Garage window: Spawn Car opens it, and V spawns the last pick.
- The server refuses to spawn cars the player doesn't own (`NotOwned`).

## 3. How it works

- **EconomyRules (pure, `src/ReplicatedStorage/Shared/Economy/EconomyRules.luau`):**
  - `validateSaved` migrates v1 to v2 and refuses newer or damaged records (`Corrupt`).
  - `purchaseVehicle` checks the vehicle id, price, transaction id, duplicate tx, already-owned, garage limit and funds, then changes cash, ownership and tx history in one step without yielding.
- **ProfileStore:** saves `OwnedVehicles` with the rest of the profile in one `UpdateAsync` record. A migration is written back in the same update that claims the session lock.
- **EconomyService:**
  - `purchaseVehicle` applies the rule, saves immediately, and on failure leaves the dirty profile for autosave, leave and orphan retries.
  - `ownsVehicle`: the starter is always owned; anything else needs a loaded profile.
  - Publishes `OwnedVehicles` as a display-only attribute.
- **DealershipService:**
  - Handles `RequestPurchaseVehicle(vehicleId)`: id type and length, catalogue membership (price from `DealershipConfig`), one request in flight, a 1 s rate limit, alive, not jailed, within 20 studs of the desk.
  - Then calls `EconomyService.purchaseVehicle` with a server GUID transaction id.
- **VehicleService:** calls `EconomyService.ownsVehicle` before every spawn.
- **RobberyService:** pending payouts with retries, and calls to `PoliceService.setDispatchHold`.
- **Client:**
  - `GarageController`, `DealershipController` and `UiKit` are display and request only.
  - `RobberyHudController` adds a "REWARD PENDING" state.

## 4. Security and authority

- There is one new client→server remote, `RequestPurchaseVehicle`.
  - The client sends only a vehicle id. Extra arguments are ignored (tested with a fake price of 1).
  - Prices exist only in server config. The client copy is read-only and display only.
- Duplicate protection on purchases has four layers: one request in flight per player, a 1 s rate limit, `AlreadyOwned`, and the persisted duplicate-transaction list.
- Robbery payouts are guarded three ways: the phase transition, a per-server paid set, and the persisted transaction id.
- Spawning is checked against the server profile.
- No cash, balance or ownership remote exists. A spec checks remote names.
- Studio-only dev commands (`SetCashUnavailable`, `TryRobStore`, `WriteLegacyProfile`, `ClearRobberyCooldown`) exist only when `RunService:IsStudio()`.

## 5. Persistence and data safety

- **Schema:** v1 `{Version, Cash, RecentTransactions}` → v2 adds `OwnedVehicles`. A v1 record migrates on load, keeping its cash and transaction ids. A v2 record without the list, a newer version, or a non-integer version is refused untouched.
- **Atomicity:** cash and ownership travel in the same record, so a failed save leaves the stored record entirely pre-purchase. Tested in a spec and in Studio.
- **Failed saves:** saves on leave that fail are retried for up to 15 min while the lock is held, and once more at shutdown. A player who rejoins the same server before then gets the unsaved profile back.
- **Session lock:** another live server's lock (<180 s old) refuses the load. This was seen in Studio after a failed save (the load succeeded about 2.5 min later).

## 6. Decisions made

- **Owner, option 1:** robbery stars come at the start, and police are sent when the holdout ends.
- **Claude, robbery start needs loaded cash data:** this is the "prevent completion when durable handling is unavailable" choice.
- **Claude, starter Coupe always spawnable**, even while data is unavailable, so a DataStore outage doesn't stop driving.
- **Claude, newer-version records are refused** (not downgraded), to protect data if an older server version is still running.
- **Claude, dealership site (200, 136):** checked free of buildings and roads by a spec.
- **Claude, UI windows top-centre below the HUD row:** after an iPhone 7 overlap was found in testing.

## 7. Deviations from the request

- **Driving getaway not validated as a paid escape.** The owner asked for at least one; none succeeded (13 attempts). The owner said "continue", and 4C went ahead with this recorded as open.
- **Roadside stop** was proposed and documented, not built (as instructed).

## 8. Unresolved risks and known issues

| # | Issue | Severity | Fix |
|---|---|---|---|
| 1 | No robbery getaway has ended in a payout. The single police unit keeps pace: `ChaseSpeed` 110 plus `ChaseGain` +1 stud/s per stud of gap, against the Coupe's ~119 (Muscle 138), with `SightRange` 160 and an 8 s decay delay. | Medium (gameplay) | Owner tuning decision: lower or remove `ChaseGain`, a shorter sight range, or a shorter decay delay |
| 2 | A pending robbery reward is lost if the player leaves while their cash data is still unavailable. | Low | Persist pending rewards in a separate key or MemoryStore |
| 3 | An unsaved profile is lost if the server itself shuts down before the DataStore recovers. | Low | Inherent to DataStore; only shortens with fewer failures |
| 4 | Holdout area check uses the client-simulated character position. | Low | Server-side sanity bounds; exploit tests need real clients |
| 5 | The place has "Allow HTTP Requests" enabled (HttpService.HttpEnabled = true). It wasn't changed in this task, and game code doesn't use it. | Low | Owner to review before public release |
| 6 | NPC police can't enter the store and stall at the storefront. | Low | Roadside-stop proposal (ARCHITECTURE.md) |

## 9. Multiplayer status

MULTIPLAYER UNVERIFIED:
- two buyers at once;
- keeping ownership when rejoining onto another server (lock hand-over between two live servers);
- other players seeing the display car or another player's Muscle;
- two robbers at one store;
- exploits under real latency.

All are listed in `docs/MULTIPLAYER_TESTS.md`.

## 10. Files for the auditor

- CHANGE_MANIFEST.md
- TEST_EVIDENCE.md
- AUDITOR_QUESTIONS.md
- diffs/ALL.diff, one diff per changed source file, and diffs/FILES.txt
- screenshots/ (8 images, all from place 132163592957463)
