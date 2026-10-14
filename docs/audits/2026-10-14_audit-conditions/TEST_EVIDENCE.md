# Test evidence: 2026-10-14_audit-conditions

- Studio instance used: `Outlaw City (placeId: 132163592957463)`. Every Edit call asserted `game.PlaceId`. The Lighthouse Keepers Studios that were also open were never touched.
- Backup before the work: Studio log `Place file downloaded to 'G:\Roblox\Outlaw City\backups\OutlawCity_Approved1.rbxl'` at 16:54:48Z.
- Solo Studio only. **Not multiplayer validation.**

## Automated tests
| Run | Output (exact) |
|---|---|
| First run after the changes | `[Tests] FAIL ProfileSession.spec > once leaving, a queued heartbeat save is refused and only the release-save runs: ServerStorage.Tests.ProfileSession.spec:248: equal: expected false, got true` / `[Tests] FAIL ProfileSession.spec > operations run strictly in arrival order (FIFO): ServerStorage.Tests.ProfileSession.spec:222: equal: expected 6, got 5` / `[Tests] 183 passed, 2 failed` |
| Cause | Both new tests relied on timing. The overlap test assumed one frame is shorter than the fake store's 0.1 s write, which isn't true at server start. The FIFO test read the store before the sixth write finished. The same overlap scenario run by hand (Server context) gave `commit done true | heartbeat false SessionClosed`, as expected. Both tests now use a deterministic `Hold` / completion count. |
| After the test fix | `[Tests] 185 passed, 0 failed` |

| New test | Asserts | Result |
|---|---|---|
| ProfileSession: FIFO | 6 concurrent commits run in order `1,2,3,4,5,6`; all 6 stored | PASS |
| ProfileSession: heartbeat after leave | commit in flight, heartbeat queued, player leaves, release queued → commit ok; heartbeat `false/SessionClosed`; release ok; lock released; session closed | PASS |
| ProfileSession: ambiguous multi-reward claim | 3 rewards (2000 + 2000 + 500); the claim's write is stored, then errors → `ok`; 3 settled; cash +4500 once (memory and store); PaidRewards 3; a repeat claim pays nothing | PASS |
| RewardLedger: invalid rewards | empty, over-long or non-string tx; zero, negative, fractional, NaN or over-max amount; 101-character reason; NaN time → all `InvalidReward…`, ledger untouched | PASS |

## Studio regression
Robbery + escape after the changes: `[Robbery] … started 93672843-…`, `holdout complete; escaping`, `[Police] dispatched … (449 studs away)`, `reward 2000 (store robbery Store1, tx robbery:93672843-…) -> 11400 (stored)`, `escaped; paid 2000`. The reward passed the new validation.

## Player-experience measurements (inputs to the plan)
| Measurement | Result |
|---|---|
| Cash data ready after join | 2.0 s (Studio client) |
| On-foot HUD, iPhone 7 | `OutlawHud:1(3%) CombatStatus:1(3%) SafeZoneHud:1(1%) CashHud:1(1%) TouchGui:1(0%)` |
| Driving HUD, iPhone 7 | `OutlawHud:6(6%) CombatStatus:1(3%) SafeZoneHud:1(1%) CashHud:1(1%)`. Touch buttons ≈ 12% by size; only top-level frames count toward the percentages |
| Taps to first car, mobile | 2 (Spawn Car → garage → Coupe), verified by clicking through the simulator: `seated=Coupe_…` |
| Distances (Edit mode) | `avg straight-line spawn->store 151 studs, spawn->dealership desk 238 studs; plaza->store 150, plaza->desk 237, store->desk 384` |
| Sign line of sight from the 6 spawns | Store sign visible 6/6; dealership sign visible 4/6 (2 blocked by `Building_3_2_3`) |

## Not tested
- Real first-time players (the owner's human playtest).
- Cross-server behaviour.
