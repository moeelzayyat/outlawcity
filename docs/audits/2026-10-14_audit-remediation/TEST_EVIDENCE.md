# Test evidence: 2026-10-14_audit-remediation

- Studio instance used: `Outlaw City (placeId: 132163592957463)`, confirmed with the Studio instance list. A second Studio (Lighthouse Keepers, place 132065051336560) was open on the owner's PC and was never touched.
- Backup before the work: `OutlawCity_4B3.rbxl`. Studio log: `Place file downloaded to 'G:\Roblox\Outlaw City\OutlawCity_4B3.rbxl'` at 14:41:37Z, which is after 4C.
- Test mode: solo Studio playtests with a real Studio DataStore (`_Studio` suffix). Faults were injected with Studio-only Workspace attributes. **Nothing here is multiplayer validation.**
- Automated tests: `[Tests] 167 passed, 0 failed`, quoted exactly from the Output. It was 156 before; one intermediate run showed `166 passed, 1 failed` because `PoliceNavigation.spec` still hard-coded the old ChaseGain. That test was fixed.

## Automated tests
| Spec | Cases | Result |
|---|---|---|
| ProfileStore.spec | 14 (+5): commit stored before acknowledgement; failed write changes nothing in memory or the store and burns no tx id, and a retry succeeds once; rule refusal writes nothing; acknowledged purchase survives another server taking the stale lock, and the old server can't write afterwards (`LockLost` on save and commit); 5 sequential commits keep all updates | PASS |
| RewardLedger.spec | 6 (new): idempotent record; profile write fails after escape → paid once on the next load by another server, ledger cleared, a second claim pays nothing; paid-but-not-cleared entry never paid twice; claim during an outage keeps the entry; several rewards each paid once; ledger outage reported | PASS |
| RobberyRules.spec | `SaveFailed` → Retry added | PASS |
| PoliceNavigation.spec | chase-speed test now checks the formula | PASS |
| All others | unchanged | PASS (167/167) |

## Manual / scripted Studio tests
| # | Requirement | Steps | Expected | Actual (exact output) | Result |
|---|---|---|---|---|---|
| F1 | Purchase never acknowledged without being stored | Fault `SimulateStoreFailure_OutlawCity_PlayerData_v1` = true; buy the Muscle at the desk with $15,800 | Refused, nothing changed | `purchase Muscle write attempt 1 failed (StoreError: …Simulated DataStore failure (Studio test))`, `… attempt 2 failed …`, `purchase Muscle NOT applied (StoreError); nothing changed`, `refused: SaveFailed`; client `false/SaveFailed cash=15800 owned=Coupe` | PASS |
| F1b | Retry after the outage | Fault off, buy again | Bought once | `bought Muscle for 15000 (tx buy:Muscle:c3ed0367-…) -> cash 800 (stored)`; client `true/nil cash=800 owned=Coupe,Muscle` | PASS |
| F2 | Acknowledged purchase + earned reward survive a server shutdown during an outage | After F1b: profile-store fault on (ledger working), rob + escape (teleport escape, payout test only), stop the server with the fault still on (every leave/shutdown save failed) | Next server: purchase kept; reward paid once from the ledger | During: `PayoutPending:2000 recorded=true`; shutdown `save attempt 3 failed …`, `save on leave failed; retrying in the background (every change was already stored when it happened)`. Next server: `cash=2800 owned=Coupe,Muscle` (800 + 2000). Store read directly: ledger `{"Rewards":[]}`, stored cash 2800, Muscle owned | PASS |
| F3 | Total outage during an escape | `SimulateDataStoreFailure` = true during the escape; then off | Pending; paid once on recovery | `reward robbery:22c0500e-… could not be recorded in the ledger (…Simulated DataStore failure…)`, `grant 2000 NOT applied (StoreError); nothing changed`, `payout pending (SaveFailed; recorded in ledger: false); retrying`; after recovery `grant 2000 (store robbery Store1, tx robbery:22c0500e-…) -> 4800 (stored)`, `escaped; paid 2000` | PASS |
| G1 | Police tuning: baseline (SightRange 160, ChaseSpeed 110, ChaseGain 1.0) | Scripted getaway harness ×5 (see below) | n/a | 1 PAID 24 s (unit spawned 426 studs north); 2 still wanted at 120 s (unit started ~120 studs away; max gap 129; never evading); 3 PAID 28 s; 4 still wanted at 120 s (max gap 128); 5 PAID 18 s. **3/5** | recorded |
| G2 | Police tuning: tuned (130 / 100 / 0.25) | Same harness ×5 | n/a | PAID 34 s, 34 s, 25 s, 18 s, 35 s (first "evading" at 21, 21, 12, 6, 23 s). Runs 1 and 4 started with the unit ~230 studs away (cases that failed at baseline). **5/5** | recorded |
| G3 | At least one paid getaway with normal vehicle movement | G1 + G2 | ≥1 paid | 8 paid getaways; each `Paid` once with cash +2000; the car was driven only by `VehiclePhysics` after the robbery (no teleport) | PASS |
| M1 | Muscle on touch controls | iPhone 7 simulator (666×374); spawn Muscle; hold the GAS button (mouse-as-touch); then BRAKE | Accelerates, brakes | Touch panel visible; after GAS: `speed=124`; HUD "76 MPH" mid-run (screenshot); after BRAKE 1.5 s: `speed=30` | PASS (simulator) |
| H1 | HTTP not needed | Code search; set `HttpEnabled` false; playtest | Game works | Search: only `GenerateGUID`/JSON use HttpService. `before=true … now=false place=132163592957463`; then `[Tests] 167 passed, 0 failed`, `grant 100 … -> 20900 (stored)`, `started 85012bd0-…` (robbery GUID) | PASS |
| R1 | Regression | Same sessions | Systems intact | Robbery start/holdout/escape, police dispatch at holdout end, bust → jail → release, dealership purchase, garage spawn, migration (`loaded (Migrated) cash=800`), cash persistence all observed working; no console errors except the injected failures | PASS |

### Getaway harness (identical for G1 and G2)
The harness is `getaway_test_harness.lua`, kept in the audit folder.
1. Spawn a Coupe and park it at the storefront facing north (-104, -72). Exit it.
2. Start the robbery with the Studio-only `TryRobStore` command, which runs the same server checks as the prompt.
3. Wait out the holdout, then walk to the car (humanoid MoveTo) and sit by touching the seat.
4. Take over the car's local simulation and step the real `VehiclePhysics` with waypoint steering around the outer grid roads, in a direction chosen away from the police unit.
5. Stop at 120 s or on Paid/Failed.

## Screenshots
| File | What it shows | Studio instance (place ID) | Device |
|---|---|---|---|
| screenshots/01_muscle_touch_gas_iphone7.jpg | Muscle accelerating on the GAS touch button, "76 MPH", touch panel | Outlaw City (placeId: 132163592957463) | iPhone 7 simulator |

## Regression checks
See R1.

## Not tested
- Human getaway playtest: needs the owner.
- Muscle on a real phone, and thumbstick steering: needs the owner.
- Anything across two live servers (MULTIPLAYER UNVERIFIED).
- DataStore budgets under load.
