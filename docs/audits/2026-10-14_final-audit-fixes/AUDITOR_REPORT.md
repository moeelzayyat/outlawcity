# Auditor report: 2026-10-14_final-audit-fixes

- Project: OUTLAW CITY (Roblox, place ID 132163592957463)
- Date: 2026-10-14
- Commit range: `882e857..9404c20`. 882e857 is the remediation the auditor reviewed; commits in between are audit docs only.
- Prepared by: Claude (primary integration agent)
- Status: awaiting the auditor's review, then owner approval before Phase 5. No Phase 5 work and no new features.

## 1. What was asked
The six targeted corrections from the second audit:
1. Ambiguous commit reconciliation.
2. Durable reward dedupe beyond the last 200 transaction ids.
3. Ledger recovery during long sessions, with bounded backoff.
4. Explicit handling of BalanceCap, malformed records and a full ledger.
5. No queued profile operation after the player leaves, the lock is lost, or another server takes ownership.
6. The dealership in-flight flag always cleared.

Constraints: keep the architecture, keep cash and ownership in one profile, one police unit, monitor-only anti-cheat, police tuning 130/100/0.25 with an 8 s decay delay, no new content, solo tests aren't multiplayer proof.

## 2. What was built
| # | Fix | Where |
|---|---|---|
| 1 | Every profile write goes through a new **ProfileSession**. After any failed write the session is Stale and nothing is written from memory until the stored profile is read back (`ProfileStore.read`, own lock only) and adopted. A retried commit is re-applied to the stored state; if the change is already there (transaction id present), it returns `AlreadyApplied` without applying it twice. If the store can't be read, it returns `SaveUnconfirmed`, and the next operation reconciles. Heartbeat and leave saves reconcile first. | `ProfileSession.commit/save`, `ProfileStore.read` |
| 2 | **Profile v3 adds `PaidRewards`.** Paying a ledger reward records its id there in the same write (`EconomyRules.payReward`). Ids are pruned only after a claim sees the ledger no longer lists them (`prunePaidRewards`). v1 and v2 records migrate on load. | `EconomyRules`, `ProfileStore`, `EconomyConfig` |
| 3 | **Periodic ledger claim per session:** at load, then every 300 s when idle or 30 s with outstanding entries. On failure, backoff doubles from 30 s up to 900 s. | `EconomyService.claimRewards` + scheduler |
| 4 | **Ledger invalid states:** a corrupt record is `LedgerCorrupt` (never overwritten, reported). Malformed entries are kept untouched and counted. A full ledger returns `LedgerFull`. Lasting refusals (BalanceCap, RewardHistoryFull, invalid amount or id) are marked `Blocked` with the reason and retried at the claim pace. | `RewardLedger` |
| 5 | Operations run one at a time. **`beginLeave`** refuses any commit queued or started after the player leaves; only the final release-save runs. **Lock loss** (another server took ownership, seen on a commit, save or reconcile) closes the session, and every queued operation returns `SessionClosed`. | `ProfileSession.run/commit/beginLeave/close`, `EconomyService.onPlayerRemoving/checkClosed` |
| 6 | `DealershipService` calls the economy through `pcall` and always clears `inFlight`. An error returns `SaveUnconfirmed`. | `DealershipService.purchase` |

Studio-only test switches:
- `SimulateCommitThenError_<store>` = N: the next N writes are stored, then error.
- `SimulatePurchaseError`.
- Dev command `AddLedgerReward`.

## 3. How it works
EconomyService now holds a `ProfileSession` per loaded player.
- **Commits:** `grant`, `deduct`, `purchaseVehicle` and `grantReward` go through `commitChange` → `ProfileSession.commit` → `ProfileStore.commit` (draft copy → write under lock → adopt).
- **Saves:** the heartbeat (every 60 s) and the leave save use `ProfileSession.save`, which reconciles first if the session is Stale.
- **Reward ledger:** `grantReward` records the reward in the ledger, pays it with `payReward` (so PaidRewards is written in the same commit), then removes it from the ledger. Claims list the ledger, then in one commit prune PaidRewards and run `applyAll`, then `RewardLedger.update` (settle, block or retry).
- **Fixed sizes:** `CommitAttempts` = 3, `MaxPaidRewards` = 1000, `LedgerMaxEntries` = 50.

## 4. Security and authority
Unchanged:
- prices come only from server config;
- the client sends only a vehicle id;
- ownership is checked on the server before spawning;
- there is no new remote.

Dev and test switches are Studio-only (`RunService:IsStudio()`).

## 5. Persistence and data safety
- **Schema:** v3 = v2 + `PaidRewards`. Migration happens on load; it was seen for real in Studio: `loaded (Migrated) cash=20900`, v2 → v3.
- **Unchanged:** the newer-version and damaged-record rules, and the store and lock design.

## 6. Decisions made
- **Reconcile by reading the store, not by trusting a probe:** a retry re-runs the rule on the stored state, and the duplicate-transaction answer proves the earlier ambiguous write was stored.
- **Bounded PaidRewards (1000):** at the limit, new ledger payouts are refused and kept as Blocked, never forgotten.
- **Unknown outcome is reported, not guessed:** a write that fails while the store can't be read returns `SaveUnconfirmed` rather than claiming success or failure.

## 7. Deviations from the request
None.

## 8. Unresolved risks and known issues
| # | Issue | Severity | Note |
|---|---|---|---|
| 1 | A reward is lost if the ledger write AND every grant retry fail and the player leaves (total outage). It is logged. | Low | Unchanged from the last audit; inherent |
| 2 | `SaveUnconfirmed` leaves the player unsure until the next operation reconciles. | Low | Never applied twice |
| 3 | A corrupt ledger record needs manual review. | Low | Logged; never overwritten |
| 4 | Lock hand-over and leave overlap are proven with a fake store and in solo Studio only. | Medium | MULTIPLAYER UNVERIFIED |
| 5 | Pending from earlier: human getaway playtest, Muscle on a real phone, DataStore budgets with many players. | n/a | Owner and multiplayer |

## 9. Multiplayer status
All cross-server behaviour (lock hand-over, a ledger claimed on another live server, leaving mid-operation under real latency) is MULTIPLAYER UNVERIFIED. The specs simulate it with a fake store; solo Studio covers one server.

## 10. Files for the auditor
AUDITOR_REPORT.md, CHANGE_MANIFEST.md, TEST_EVIDENCE.md, AUDITOR_QUESTIONS.md, SOURCE_DIFFS.md and PROGRESS.md (updated known issues). ARCHITECTURE.md is optional context.
