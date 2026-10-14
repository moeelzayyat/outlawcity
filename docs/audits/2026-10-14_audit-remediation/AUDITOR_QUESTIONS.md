# Questions for the auditor: 2026-10-14_audit-remediation

Answer each by number. Where you disagree with a design choice, say what you would do instead and why.

## Correctness and security
1. `ProfileStore.commit` writes a draft copy and adopts it only after `UpdateAsync` returns. If `UpdateAsync` throws AFTER the write actually committed (an ambiguous result), memory keeps the old state and the next write overwrites the stored change. The caller was told "failed", so the result matches what was acknowledged. Is that ambiguity acceptable, or should the next commit re-read the stored profile first?
2. `withLock` serialises per player with a busy-wait (`task.wait()`), and a session that loses the lock becomes Unavailable. Do you see any deadlock or starvation path, for example a commit yielding while the player leaves?
3. Is it enough for `claimRewards` to run only after a successful load and when an orphan profile is adopted, or should it also run periodically for long sessions?

## Data safety and persistence
1. Writing every cash change through to the DataStore costs one write per change plus a 60 s heartbeat per player. Is that acceptable for Roblox budgets at this game's expected scale, or should cheap grants be batched?
2. Ledger dedupe relies on the profile's last 200 transaction ids. Should the ledger keep its own settled marker instead?
3. A ledger entry that `EconomyRules` refuses permanently (for example BalanceCap) stays in the ledger. How should such entries be handled?

## Design and maintainability
1. `EconomyService` now owns commits, the reward ledger, heartbeats, orphans and test hooks. Should the ledger/claim logic move into its own service?
2. The police tuning is config only (`PoliceDriveRules` unchanged). Is the A/B method (5 vs 5 scripted runs) good enough to keep the values as an experimental default until human playtests?

## Testing gaps
1. Which of the remaining MULTIPLAYER UNVERIFIED cases (cross-server lock hand-over, a ledger payout on another live server) is the highest priority once real servers are available?
2. Is the fault-injection coverage (profile store only, all stores, shutdown during an outage, specs for lock expiry) sufficient for the item 1 and item 3 requirements?

## Decisions the owner should make
1. Keep the tuned pursuit (5/5 paid, escapes in 18–35 s), use something in between, or go back to baseline (3/5)?
2. Do you agree with the verdict on HTTP (off, nothing needs it)?
