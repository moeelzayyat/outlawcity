# Test evidence: 2026-10-14_final-audit-fixes

- Studio instance used: `Outlaw City (placeId: 132163592957463)`, confirmed with the Studio instance list. Every Edit-mode call also asserted `game.PlaceId == 132163592957463`. Two Lighthouse Keepers Studios were open and never touched.
- Backup before the work: Studio log `Place file downloaded to 'G:\Roblox\Outlaw City\backups\OutlawCity_Remediation1.rbxl'` at 16:35:06Z.
- Test mode: solo Studio playtests with the real Studio DataStore (`_Studio` suffix). Faults were injected with Studio-only Workspace attributes, all removed afterwards. **Not multiplayer validation.**
- Automated tests: `[Tests] 181 passed, 0 failed`, quoted exactly from the Output (167 before; +14).

## Automated tests (new or changed)
| Spec | Case | Result |
|---|---|---|
| ProfileSession.spec | ambiguous write: stored-then-errored purchase detected and counted once (`AlreadyApplied`, store charged once) | PASS |
| ProfileSession.spec | ambiguous write + unreadable store → `SaveUnconfirmed`; the next heartbeat reconciles, so the stored purchase survives; retry → `AlreadyOwned`, never charged twice | PASS |
| ProfileSession.spec | write that failed before storing → retried, applied once | PASS |
| ProfileSession.spec | unreachable store → `SaveUnconfirmed`, nothing applied | PASS |
| ProfileSession.spec | **session departure / commit overlap:** commit A in flight, B queued, player leaves → A finishes, B `SessionClosed` and never written; final save runs; later commits refused | PASS |
| ProfileSession.spec | **lock taken mid-write:** A → `SessionClosed/LockLost`, queued B refused, new owner's data untouched | PASS |
| ProfileSession.spec | heartbeat after the lock moved → closes instead of writing | PASS |
| RewardLedger.spec | **dedupe beyond 200:** reward paid, ledger removal fails, then 250 more transactions → the claim pays nothing (PaidRewards), clears the ledger, then prunes the id | PASS |
| RewardLedger.spec | **recovery:** unreadable ledger reported, claim fails, then pays once readable | PASS |
| RewardLedger.spec | **BalanceCap:** entry kept as Blocked (note BalanceCap), not paid; paid once after the player spends | PASS |
| RewardLedger.spec | **overflow:** full ledger → `LedgerFull`, nothing dropped | PASS |
| RewardLedger.spec | **malformed:** corrupt record → `LedgerCorrupt`, untouched; malformed entry kept through rewrites | PASS |
| RewardLedger.spec | idempotent record; profile write fails → paid once on another server; outage keeps the entry; several rewards each once | PASS |
| EconomyRules.spec | v2→v3 migration; payReward refused after 250 later transactions; prune only when gone from the ledger; full history refuses (`RewardHistoryFull`) | PASS |

## Studio tests (exact Output)
| # | Requirement | Steps | Actual (exact output) | Result |
|---|---|---|---|---|
| S0 | Real migration | Join | `[Economy] Lighthouse8282: loaded (Migrated) cash=20900` | PASS |
| S1 | Ambiguous write reconciled | `SimulateCommitThenError_OutlawCity_PlayerData_v1` = 1; dev grant 1000; Save data now | `write attempt 1 failed (…Simulated ambiguous DataStore write: stored, then errored (Studio test))`, `reconciled from the store (cash=21900)`, `grant 1000 (dev grant, tx dev:5310bfd9-…) -> 21900 (stored, AlreadyApplied)`; client `true/nil cash 20900 -> 21900`; heartbeat `true`; stored `version=3 cash=21900` | PASS |
| S2 | Ambiguous purchase | `WriteLegacyProfile`, rejoin (`loaded (Migrated) cash=21900`, owned `Coupe`); same switch; buy Muscle | `reconciled from the store (cash=6900)`, `purchase Muscle for 15000 (tx buy:Muscle:6e2ab4a3-…) -> 6900 (stored, AlreadyApplied)`; client `true/nil cash 21900 -> 6900 owned=Coupe,Muscle` | PASS |
| S3 | Dealership flag cleared on error | `SimulatePurchaseError` = true; buy; switch off; buy 1.1 s later | `[Dealership] Lighthouse8282: purchase raised an error: …Simulated purchase error (Studio test)`; client `false/SaveUnconfirmed cash=21900`; second buy `true` (not `Busy`) | PASS |
| S4 | Ledger recovery in a long session | Dev `AddLedgerReward` 500; restart with `SimulateStoreFailure_OutlawCity_PendingRewards_v1` set; switch off after ~40 s | `reward ledger unreadable (…Simulated DataStore failure (Studio test)); retrying later` (at load and ~30 s later); `settled 1 recorded reward(s) -> cash 7400` on the next backoff retry (6900 + 500, once) | PASS |
| R1 | Regression | Robbery + escape | `[Robbery] … started 590493be-…`, `holdout complete; escaping`, `[Police] dispatched … (437 studs away)`, `reward 2000 (store robbery Store1, tx robbery:590493be-…) -> 9400 (stored)`, `escaped; paid 2000`; ledger `{"Rewards":[]}`; stored `v3 cash=9400 owned=Coupe,Muscle PaidRewards=2` | PASS |

The `PaidRewards=2` in R1 are the two rewards just paid. Their ledger entries are already removed, so the next claim prunes them.

## Not tested
- Leave/commit overlap and lock hand-over across real servers (MULTIPLAYER UNVERIFIED; spec-level only).
- A real BalanceCap or full ledger in Studio (spec-level only).
- Carried over: human getaway playtest, Muscle on a real phone.
