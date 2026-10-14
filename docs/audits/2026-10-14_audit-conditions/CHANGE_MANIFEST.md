# Change manifest: 2026-10-14_audit-conditions

- Commit range: `1057d17..d442381`
- Commits:
  - `5fa77a8` Audit conditions: FIFO profile queue, leave-safe saves, reward validation
  - `d442381` Docs: audit conditions done; five-minute player-experience plan

The `src/` snapshot matches Studio for all 4 changed files (length + FNV-1a hash compared).

## Added
| File | Purpose |
|---|---|
| `docs/PLAYER_EXPERIENCE_AUDIT.md` | Five-minute player-experience audit: measurements and proposals P1–P8 (plan only) |

## Changed
| File | What changed and why |
|---|---|
| `src/ServerScriptService/Server/Data/ProfileSession.luau` | FIFO ticket queue in `run` (condition 1); non-release saves refused after `beginLeave` (condition 2) |
| `src/ServerScriptService/Server/Data/RewardLedger.luau` | `validate` + validation in `record` (condition 4) |
| `src/ServerStorage/Tests/ProfileSession.spec.luau` | +3 tests (FIFO, heartbeat after leave, ambiguous multi-reward claim); deterministic `Hold` in the fake store |
| `src/ServerStorage/Tests/RewardLedger.spec.luau` | +1 test (10 invalid reward shapes refused, nothing written) |
| `docs/ARCHITECTURE.md`, `docs/PROGRESS.md`, `docs/ROADMAP.md`, `docs/TEST_CHECKLIST.md` | Conditions, tracked limitations (8o), plan reference |

## Removed
| File | Why |
|---|---|
| None | |

## Docs updated
See Changed.

## Studio-only changes (not in src/)
None. No Workspace test attributes remain.

## Configuration values introduced or changed
| Setting | Old | New | Where |
|---|---|---|---|
| Reward reason limit | none | 100 characters | RewardLedger |
