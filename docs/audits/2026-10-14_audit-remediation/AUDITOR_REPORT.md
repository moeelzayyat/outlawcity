# Auditor report: 2026-10-14_audit-remediation

- Project: OUTLAW CITY (Roblox, place ID 132163592957463)
- Date: 2026-10-14
- Commit range: `5bdb1c9..882e857`. 5bdb1c9 is Phase 4C, which the previous audit marked CHANGES REQUIRED.
- Prepared by: Claude (primary integration agent)
- Status: awaiting the auditor's review and owner approval. No Phase 5 and no new gameplay features were started.

## 1. What was asked
The auditor's mandatory remediation, relayed by the owner:
1. Resolve the risk of acknowledged vehicle purchases disappearing after failed saves and session-lock expiry.
2. Inspect and test EconomyRules.purchaseVehicle, EconomyRules.validateSaved, ProfileStore.load/save, EconomyService.purchaseVehicle and orphan-save recovery for concurrency, idempotency and lost updates.
3. Durable handling of earned but temporarily unpaid robbery rewards across disconnects and server failures.
4. Preserve server-authoritative pricing, purchases, ownership and cash.
5. Do not enable automatic anti-cheat enforcement or increase the police count.
6. Reduce pursuit aggressiveness experimentally (ChaseGain 0.25, ChaseSpeed 100, SightRange 130, decay delay unchanged at 8 s) and compare with the baseline.
7. Demonstrate at least one successful paid getaway using normal vehicle movement, then do human playtesting.
8. Test the Muscle with mobile touch controls.
9. Disable unused outbound HTTP after verifying nothing needs it.

Deliverables: source diffs, fault-injection evidence, getaway results, known limitations and exact Studio output. Don't call simulated tests multiplayer validation.

## 2. What was built
- **Write-through economy.** `ProfileStore.commit` applies a change to a copy of the profile, writes the copy in one `UpdateAsync` while holding the session lock, and only then adopts it. EconomyService routes every grant, deduction and purchase through it. A failed write returns `SaveFailed` with nothing applied. Anything acknowledged is already stored.
- **Per-player serialisation.** EconomyService's `withLock` makes commits and saves for one player run one at a time, so concurrent requests can't produce a lost update.
- **Lock heartbeat.** Every loaded profile is now re-saved every 60 s. Before this, only changed profiles were saved, so a quiet player's lock could go stale while they were still online. This was a lost-update risk found during the inspection.
- **Reward ledger.**
  - New `RewardLedger`, a separate DataStore `OutlawCity_PendingRewards_v1`.
  - `EconomyService.grantReward` records the reward in the ledger first, then grants it write-through, then clears the entry.
  - On every successful load, `claimRewards` pays outstanding entries in one commit. Duplicate transaction ids make this exactly-once.
  - RobberyService uses it and retries without blocking its tick loop.
- **Police tuning (experimental):** `PoliceConfig` SightRange 130, ChaseSpeed 100, ChaseGain 0.25, with an A/B comparison. `PoliceDriveRules` is unchanged.
- **HTTP:** `HttpService.HttpEnabled` set to false after a code search.
- **Client messages:** for `SaveFailed` ("Nothing was charged") and for a recorded pending reward.
- **Studio-only fault switch:** `SimulateStoreFailure_<storeName>`, so one store can fail while the other works.

## 3. How it works
- **Commit path:**
  `DealershipService.purchase`
  → `EconomyService.purchaseVehicle`
  → `withLock`
  → `commit` (2 attempts)
  → `ProfileStore.commit`, which builds a draft copy, runs the `EconomyRules.purchaseVehicle(draft)` rule, writes with `ProfileStore.save(draft)` (lock check), then adopts the draft.
  Grants and deductions follow the same path. `LockLost` marks the session Unavailable, so this server stops writing.
- **Reward path:** `RobberyService.onEscaped` creates a pending entry, then `tryPayout` (spawned) calls `EconomyService.grantReward`. That runs `RewardLedger.record`, then the write-through grant, then `RewardLedger.remove` once the reward is paid or found to be a duplicate. If the outcome is Retry, it tries again every 2 s. On the next load (any server), `claimRewards` runs `RewardLedger.list`, applies everything in one commit with `RewardLedger.applyAll`, then removes the paid entries.
- **Orphan saves:** these remain for releasing the lock after a failed leave-save. They no longer carry unstored money, because every change was already committed.

## 4. Security and authority
- Unchanged.
- Prices come from `DealershipConfig` only.
- The client sends only a vehicle id.
- The ownership check sits in `VehicleService`.
- There's no new remote.
- Rewards are created only by the server (`RobberyService`) with server GUID transaction ids.
- Dev hooks remain Studio-only.

## 5. Persistence and data safety
- **New store:** `OutlawCity_PendingRewards_v1`, `_Studio` suffix in Studio.
- **New record:** `{Rewards = [{TxId, Amount, Reason, At}]}`, capped at 50 entries, deduplicated by TxId.
- **Profile schema:** unchanged (v2).
- **Lock-expiry scenario** (the auditor's item 1): a purchase is stored at acknowledgement. When another server later claims the stale lock, it loads the purchase. The old server's later writes are refused (`LockLost`). Covered by a spec and by Studio test F2.

## 6. Decisions made
- Write-through for all money changes, rather than only purchases, because the same loss window applied to robbery grants. The cost is one DataStore write per cash change.
- A separate DataStore ledger instead of MemoryStore. It goes through the same adapter, so it can be fault-injected and is durable beyond MemoryStore's TTL.
- The tuned police values stay in place as EXPERIMENTAL pending human playtests. Reverting needs only 3 config values (shown in comments).

## 7. Deviations from the request
- Human playtesting and testing on a real phone weren't done. They need the owner (see section 8).
- Thumbstick steering on touch wasn't tested in the simulator; GAS and BRAKE were.

## 8. Unresolved risks and known issues
| # | Issue | Severity | Fix |
|---|---|---|---|
| 1 | A reward is lost if the ledger write AND every grant retry fail and the player then leaves (a total DataStore outage). It is logged. | Low | Inherent; a third store would hit the same outage |
| 2 | The ledger dedupes via the profile's last 200 transaction ids. An entry older than 200 newer transactions could be paid again. | Low | Persist a settled-reward set, or timestamp checks |
| 3 | Escapes may now be too easy: 18–35 s with the tuning. This is a small solo sample from a scripted driver. | Medium (balance) | Human playtests; adjust the 3 values |
| 4 | DataStore budget: one write per cash change plus a 60 s heartbeat per player. Not tested with many players. | Low now | Measure in a multiplayer test |
| 5 | A rule refusal inside `claimRewards` (for example BalanceCap) leaves the entry in the ledger permanently. | Low | Expire or flag entries |
| 6 | Studio needed the owner to click Play/Stop once after a long failing shutdown. This is Studio tooling, not the game. | Info | None |

## 9. Multiplayer status
MULTIPLAYER UNVERIFIED:
- cross-server lock hand-over with real servers;
- a ledger reward paid on a different live server;
- DataStore budgets;
- police tuning with human drivers and latency;
- everything from earlier phases.

The cross-server cases were simulated only: one server per Studio session and a fake store in specs.

## 10. Files for the auditor
- AUDITOR_REPORT.md
- CHANGE_MANIFEST.md
- TEST_EVIDENCE.md
- AUDITOR_QUESTIONS.md
- SOURCE_DIFFS.md
- the updated project docs (ARCHITECTURE, PROGRESS, ROADMAP, TEST_CHECKLIST, MULTIPLAYER_TESTS)

Kept as records but not uploaded: per-file `.diff`s, `getaway_test_harness.lua`, and the simulator screenshot.
