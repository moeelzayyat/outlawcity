# Test evidence: 2026-10-14_phase-4B-followup-and-4C

- Studio instance used: `Outlaw City (placeId: 132163592957463)`. Every test session first listed the connected Studio instances, and this was the only one connected each time (its session id changed when the owner restarted Studio).
- Test mode: solo Studio playtests. Studio DataStore uses the `_Studio` store suffix, so no live player data was touched.
- Automated tests: `[Tests] 156 passed, 0 failed` (after 4C; it was 145 after the 4B follow-up).

## Automated tests
| Spec | Cases | Result |
|---|---|---|
| EconomyRules.spec | 15: 10 earlier + 5 new (starter Coupe; v1 and versionless migration; v2 ownership kept, damaged/newer refused; purchase once; failed purchase changes nothing) | PASS |
| ProfileStore.spec | 9: 7 earlier + 2 new (v1 migrates and is written back; a failed purchase save leaves the record unchanged) | PASS |
| Dealership.spec | 4 (catalogue/price, Muscle handling, read-only prices + remote, placement) | PASS |
| RobberyRules.spec | 10: 9 earlier + 1 new payout-outcome case; the CashUnavailable start case was added to an existing test | PASS |
| All other specs | unchanged | PASS (156/156 total) |

## Manual / scripted Studio tests

### 4B follow-up
| # | Requirement | Steps | Expected | Actual (exact output) | Result |
|---|---|---|---|---|---|
| 1 | Prevent completion when rewards can't be recorded | Dev `SetCashUnavailable` true, rob | Refused | `Rejected:CashUnavailable`, no session, no stars | PASS |
| 2 | Grant fails before it is applied | Rob; data made unavailable during the escape; escape; data restored | Pending, then paid once | `PayoutPending:2000`, then `grant 2000 (store robbery Store1, tx robbery:455cf198-…) -> 6700`, `Paid:2000`; no second grant | PASS |
| 3 | Reward accepted but the save fails | `SimulateDataStoreFailure` on; rob + escape; SaveNow; kick player; failure off | Kept and saved later | `-> 8700`; saves failed (logged); `save on leave failed; keeping the profile and retrying (cash=8700)`; `saved after leaving (cash=8700)`; next playtest `loaded (Existing) cash=8700` | PASS |
| 4 | Police respond at holdout end (owner option 1) | 3 robberies | No unit during the holdout | Unit `none` at 8 s into the holdout; dispatched at the end from 300–500 studs | PASS |
| 5 | Driving getaway | 13 attempts (10 before option 1, 3 after), real VehiclePhysics: 7 keyboard-driven, 6 scripted waypoint driver | At least one paid escape | Robber reached the car in all 3 post-change runs, but no attempt paid out (busted 12, died off map edge 1). Best run: 1,000+ studs at up to 116 studs/s with the unit 90–100 studs behind and in sight | **FAIL (open, owner tuning decision)** |
| 6 | Every failed getaway pays nothing | All 13 above | No cash | Cash unchanged in every run | PASS |

### Phase 4C
| # | Requirement | Steps | Expected | Actual (exact output) | Result |
|---|---|---|---|---|---|
| 7 | Existing cash-only profile migrates | Join with the v1 Studio profile | Cash kept, owns Coupe | `loaded (Migrated) cash=9800`; `OwnedVehicles=Coupe` | PASS |
| 8 | Migration repeatable | Dev `WriteLegacyProfile` (cash 800), rejoin | Cash kept, Coupe only | `loaded (Migrated) cash=800`; `owned=Coupe` | PASS |
| 9 | New players own the starter Coupe | Spec (no second account in solo Studio) | Coupe only | EconomyRules.spec "new profiles own exactly the starter Coupe" | PASS (spec only) |
| 10 | Unauthorized spawning blocked | `RequestSpawnVehicle("Muscle")` before buying | Refused | `false/NotOwned` | PASS |
| 11 | Must be at the desk | Buy from the plaza | Refused | `false/TooFar`, cash 9800 | PASS |
| 12 | Insufficient funds | Buy with $9,800 | Refused, no change | `false/InsufficientFunds`, cash 9800 | PASS |
| 13 | Client can't pick cars or prices | Buy `Police`, `Coupe`, `Tank`, `15000`, `""`; buy Muscle with an extra price=1 arg | Refused | `NotForSale` ×3, `BadRequest` ×2, `InsufficientFunds` (extra arg ignored) | PASS |
| 14 | Deducts exactly once; duplicates rejected | Grant to $15,800; 5 simultaneous requests | 1 success, cash -15000 once | `true/nil`, `Cooldown` ×4; cash 15800 → 800; `bought Muscle for 15000 (tx buy:Muscle:421f8b5d-…) -> cash 800`; `purchase saved` | PASS |
| 15 | Buying an owned car | Request again later | Refused, no charge | `false/AlreadyOwned`, cash 800 | PASS |
| 16 | Second vehicle spawns and drives | Garage click on Muscle; keyboard W | Spawns, faster than Coupe | Seated in Muscle; 0→123 studs/s in 3.1 s, 134 at 4.6 s (Coupe ~100 at 4 s, 104 after 3 s) | PASS |
| 17 | Ownership persists after rejoin | Stop/start | Muscle still owned | `loaded (Existing) cash=800`; `Coupe,Muscle`; Muscle spawn `true` | PASS |
| 18 | Purchase while data unavailable | After `WriteLegacyProfile` (session unavailable) | Refused | `false/DataNotLoaded` | PASS |
| 19 | Outage during purchase, still down at leave | Failure on, buy, leave | Neither charge nor car stored | In memory `cash=800 owned=Coupe,Muscle`; saves failed; next join `SessionLocked` (old lock) ×3, then loaded about 2.5 min later: `cash=15800 owned=Coupe` | PASS |
| 20 | Outage during purchase, recovered before leaving | Failure on, buy, failure off, leave | Both stored | `saved on leave (cash=800)`; rejoin `cash=800 owned=Coupe,Muscle` | PASS |
| 21 | Dealership and garage UI on PC | Desk prompt; Spawn Car button | Windows usable | Screenshots 04, 05 | PASS |
| 22 | Dealership and garage UI on mobile | iPhone 7 simulator (666×374) | No overlap | First run overlapped the cash badge (06); moved below the HUD row; no overlap (07, 08) | PASS after fix |
| 23 | Muscle on touch controls | Not run | | Touch driving buttons are shared with the Coupe (tested in Phase 2) | NOT RUN |

## Screenshots
| File | What it shows | Studio instance (place ID) | Device |
|---|---|---|---|
| screenshots/01_store_exterior_edit.jpg | 24/7 MART exterior (context, 4B) | Outlaw City (placeId: 132163592957463) | Edit view |
| screenshots/02_robbery_escape_hud_pc.jpg | "ESCAPE THE POLICE" panel (context, 4B) | Outlaw City (placeId: 132163592957463) | PC; 3D viewport rendered white (known Studio capture issue) |
| screenshots/03_robbery_countdown_iphone7.jpg | Robbery countdown on phone (context, 4B) | Outlaw City (placeId: 132163592957463) | iPhone 7 |
| screenshots/04_garage_pc.jpg | Garage window: Coupe ✓, Muscle | Outlaw City (placeId: 132163592957463) | PC |
| screenshots/05_dealership_pc.jpg | Dealership window (Muscle, Owned) and display car | Outlaw City (placeId: 132163592957463) | PC |
| screenshots/06_dealership_iphone7_before_fix.jpg | Window covering the cash badge (bug found) | Outlaw City (placeId: 132163592957463) | iPhone 7 |
| screenshots/07_dealership_iphone7_after_fix.jpg | Window moved below the HUD row | Outlaw City (placeId: 132163592957463) | iPhone 7 |
| screenshots/08_garage_iphone7.jpg | Garage window on phone | Outlaw City (placeId: 132163592957463) | iPhone 7 |

The Studio-only dev panel (left edge) is visible in the screenshots. It never exists in published servers.

## Regression checks
After 4C, one session checked:
- robbery start (2★, no police during the holdout, unit dispatched at the end);
- bust → jail 12 s → release;
- cash unchanged (800);
- Coupe spawn and drive after release (V and request);
- safe-zone enter/leave;
- 0 vehicle-validation observations;
- no console errors.

## Not tested
- Everything multiplayer: two buyers, server hand-over, other players' view, two robbers, exploits under latency. All MULTIPLAYER UNVERIFIED.
- A genuinely new account (only the spec).
- Muscle on touch driving controls.
- A paid driving getaway (test 5).
