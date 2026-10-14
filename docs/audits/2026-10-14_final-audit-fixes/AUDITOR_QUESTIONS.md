# Questions for the auditor: 2026-10-14_final-audit-fixes

Answer each by number.

## Correctness and security
1. After an ambiguous write, `ProfileSession.commit` re-runs the rule on the reconciled stored state and treats `DuplicateTransaction` as proof the earlier write was stored. Is that proof sound for every mutation we use (grant, deduct, purchase, payReward, the claim's applyAll)?
2. `ProfileSession.run` refuses queued operations once the session is closed, and commits once `beginLeave` is set. Is there any remaining path where a write can land after leave or after lock loss?

## Data safety and persistence
1. Is `PaidRewards` (pruned only after a claim confirms the ledger no longer lists the id, capped at 1000 with an explicit refusal) a sufficient replacement for dedupe by recent ids?
2. Is it acceptable that a corrupt ledger record is left untouched for manual review, with claims backing off?

## Testing gaps
1. Is the evidence enough to close items 1 to 6: specs with a fake store that can store-then-error, yield and fail, plus Studio fault injection on the real Studio DataStore?

## Decisions the owner should make
1. With these fixes, do you recommend approving the 4B follow-up, 4C and remediation, so the owner can decide on Phase 5?
