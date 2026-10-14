# Change manifest: 2026-10-14_audit-remediation

- Commit range: `5bdb1c9..882e857`
- Commits:
  - `882e857` Audit remediation: write-through economy, reward ledger, police tuning
  - Docs-only commits in between set up this audit workflow; they're not part of the game.

Studio is the source of truth. `src/` is a snapshot exported from Studio after testing, and the export matched Studio byte for byte (92/92 scripts). The diffs are in SOURCE_DIFFS.md.

## Added
| File | Purpose |
|---|---|
| `src/ServerScriptService/Server/Data/RewardLedger.luau` | Durable earned-reward ledger (record, list, remove, applyAll) in its own DataStore |
| `src/ServerStorage/Tests/RewardLedger.spec.luau` | 6 fault and idempotency tests with a fake store |

## Changed
| File | What changed and why |
|---|---|
| `src/ServerScriptService/Server/Data/ProfileStore.luau` | `commit`: write-through change (draft copy → write under lock → adopt); `copyProfile` |
| `src/ServerScriptService/Server/Services/EconomyService.luau` | All changes go through `commit` under a per-player lock; `SaveFailed`; `grantReward` and `claimRewards` using the ledger; heartbeat re-saves every loaded profile; orphan saves only release the lock now |
| `src/ServerScriptService/Server/Services/RobberyService.luau` | Payout through `grantReward`; tracks `Recorded`; payout retries spawned off the tick loop with an in-flight guard; leave-with-pending logs whether it is recorded |
| `src/ReplicatedStorage/Shared/Robbery/RobberyRules.luau` | `payoutOutcome`: `SaveFailed` → Retry |
| `src/ServerScriptService/Server/Data/DataStoreAdapter.luau` | Studio-only per-store failure switch `SimulateStoreFailure_<storeName>` |
| `src/ReplicatedStorage/Shared/Config/EconomyConfig.luau` | `RewardStoreName`, `CommitAttempts = 2` |
| `src/ReplicatedStorage/Shared/Types.luau` | EconomyError adds `SaveFailed` |
| `src/ServerScriptService/Server/Police/PoliceConfig.luau` | Experimental tuning: SightRange 130, ChaseSpeed 100, ChaseGain 0.25 (baselines in comments) |
| `src/ServerStorage/Tests/ProfileStore.spec.luau` | +5: commit stores before acknowledging; failed write changes nothing and burns no tx id; refusal writes nothing; lock-expiry hand-over keeps the purchase; no lost updates |
| `src/ServerStorage/Tests/RobberyRules.spec.luau` | `SaveFailed` → Retry |
| `src/ServerStorage/Tests/PoliceNavigation.spec.luau` | Chase-speed test asserts the formula, so it no longer hard-codes the old aggressive gain |
| `src/StarterPlayer/StarterPlayerScripts/Client/Controllers/RobberyHudController.luau` | Message for a recorded pending reward |
| `src/StarterPlayer/StarterPlayerScripts/Client/Controllers/DealershipController.luau` | Message for `SaveFailed` ("Nothing was charged") |

## Removed
| File | Why |
|---|---|
| None | |

## Docs updated
- `docs/ARCHITECTURE.md`: write-through, lock heartbeat, reward ledger, police tuning, HTTP off, fault switches.
- `docs/PROGRESS.md`: remediation rows and known issues 8e, 8i, 8l and 8m.
- `docs/ROADMAP.md`, `docs/TEST_CHECKLIST.md` and `docs/MULTIPLAYER_TESTS.md`.
- `docs/audits/tools/make_audit_package.py`: diffs now exclude `docs/audits/`.

## Studio-only changes (not in src/)
- Place setting `HttpService.HttpEnabled`: true → **false**. Verified in Studio; a playtest afterwards ran GUID generation, a grant and a robbery start normally. The owner needs to save the place to the cloud for this, and the script changes, to persist.

## Configuration values introduced or changed
| Setting | Old | New | Where |
|---|---|---|---|
| SightRange | 160 | 130 | PoliceConfig (experimental) |
| ChaseSpeed | 110 | 100 | PoliceConfig (experimental) |
| ChaseGain | 1.0 | 0.25 | PoliceConfig (experimental) |
| DecayDelay | 8 | 8 (unchanged) | WantedConfig |
| RewardStoreName | n/a | OutlawCity_PendingRewards_v1 | EconomyConfig |
| CommitAttempts | n/a | 2 | EconomyConfig |
| Heartbeat | changed profiles only | every loaded profile every 60 s | EconomyService |
| HttpEnabled | true | false | Place setting |
