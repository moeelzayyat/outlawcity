# Change manifest: 2026-10-14_final-audit-fixes

- Commit range: `882e857..9404c20`
- Commits:
  - `9404c20` Final audit fixes: reconcile ambiguous writes, durable reward dedupe, ledger recovery
  - (in between: `8a56b26`, `0cea2f4`, which are audit docs and tooling only)

Studio is the source of truth. `src/` matches Studio byte for byte: 94/94 scripts, checked by FNV-1a hash and length.

## Added
| File | Purpose |
|---|---|
| `src/ServerScriptService/Server/Data/ProfileSession.luau` | Per-player write path: serialised operations, ambiguous-write reconciliation, leave and lock-loss closing |
| `src/ServerStorage/Tests/ProfileSession.spec.luau` | 7 tests: ambiguous writes, heartbeat after ambiguity, leave and lock-loss overlap |

## Changed
| File | What changed and why |
|---|---|
| `src/ServerScriptService/Server/Data/ProfileStore.luau` | `read` (read-only, own lock); `PaidRewards` copied and saved |
| `src/ServerScriptService/Server/Data/RewardLedger.luau` | Entry State (Pending/Blocked) and Note; corrupt, malformed and full handling; `update`; `applyAll` returns settled, blocked and retry lists |
| `src/ServerScriptService/Server/Services/EconomyService.luau` | Uses ProfileSession for every write; `claimRewards` with pruning, blocking and a backoff scheduler; leave via `beginLeave`; lock-loss handling (`checkClosed`); Studio hooks `SimulatePurchaseError` and `addLedgerRewardForTesting` |
| `src/ServerScriptService/Server/Services/DealershipService.luau` | `pcall` around the economy call; `inFlight` always cleared |
| `src/ReplicatedStorage/Shared/Economy/EconomyRules.luau` | v3 `PaidRewards` (validate/migrate), `payReward`, `prunePaidRewards` |
| `src/ReplicatedStorage/Shared/Config/EconomyConfig.luau` | ProfileVersion 3, CommitAttempts 3, MaxPaidRewards 1000, LedgerMaxEntries 50, ClaimRetryBase 30, ClaimRetryMax 900, ClaimIdleInterval 300 |
| `src/ReplicatedStorage/Shared/Types.luau` | Profile.PaidRewards; errors SaveUnconfirmed, SessionClosed, RewardHistoryFull |
| `src/ReplicatedStorage/Shared/Robbery/RobberyRules.luau` | Payout Retry for SaveUnconfirmed, SessionClosed and RewardHistoryFull |
| `src/ServerScriptService/Server/Data/DataStoreAdapter.luau` | Studio-only `SimulateCommitThenError_<store>` (store, then error) |
| `src/ServerScriptService/Server/Dev/DevCommandRules.luau`, `DevToolsService.luau` | Studio-only `AddLedgerReward` |
| `src/StarterPlayer/StarterPlayerScripts/Client/Controllers/DealershipController.luau` | Messages for SaveUnconfirmed and SessionClosed |
| `src/ServerStorage/Tests/RewardLedger.spec.luau` | 9 tests: dedupe across 250 transactions, recovery, BalanceCap, full, corrupt, malformed |
| `src/ServerStorage/Tests/EconomyRules.spec.luau` | +4: v2→v3 migration, payReward after 200+ tx, prune, full history; v3 fixtures |

## Removed
| File | Why |
|---|---|
| None | |

## Docs updated
- `docs/ARCHITECTURE.md`: ProfileSession, dedupe, ledger states, claim schedule, dealership safety, v3 record.
- `docs/PROGRESS.md`: test rows, known issues 8e and 8n, upcoming.
- `docs/ROADMAP.md`, `docs/TEST_CHECKLIST.md` and `docs/MULTIPLAYER_TESTS.md`.

## Studio-only changes (not in src/)
None. All Workspace test attributes were removed after testing (verified: no Workspace attributes remain).

## Configuration values introduced or changed
| Setting | Old | New | Where |
|---|---|---|---|
| ProfileVersion | 2 | 3 | EconomyConfig |
| CommitAttempts | 2 | 3 | EconomyConfig |
| MaxPaidRewards | n/a | 1000 | EconomyConfig |
| LedgerMaxEntries | 50 (hard-coded) | 50 | EconomyConfig |
| ClaimRetryBase / ClaimRetryMax / ClaimIdleInterval | n/a | 30 s / 900 s / 300 s | EconomyConfig |
| Police tuning | 130 / 100 / 0.25 | unchanged | PoliceConfig |
