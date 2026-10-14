# Auditor report: 2026-10-14_audit-conditions

- Project: OUTLAW CITY (Roblox, place ID 132163592957463)
- Date: 2026-10-14
- Commit range: `1057d17..d442381`
- Prepared by: Claude (primary integration agent)
- Status: conditions done. The player-experience plan awaits owner review; nothing in it is implemented.

## 1. What was asked
**Part A: your six conditions, small and with no rewrite.**
1. FIFO or documented non-FIFO `ProfileSession.run`.
2. Non-release saves can't run after `beginLeave`.
3. An ambiguous multi-reward claim test.
4. Stronger reward validation before insertion into the ledger.
5. Keep tracking the full-ledger and complete-outage limitations.
6. No cross-server behaviour labelled verified.

**Part B:** a five-minute player-experience audit, as a plan only, proposing small and measurable changes. Same constraints as before.

## 2. What was built
| # | Condition | Done |
|---|---|---|
| 1 | `ProfileSession.run` is now a **true FIFO queue**: each operation takes a ticket and runs when `Serving` reaches it. A refused ticket (session closed) still advances `Serving`, so the queue can't stall. | `ProfileSession.run` |
| 2 | `ProfileSession.save` refuses a non-release save once `Leaving` is set (`SessionClosed`). Only the final release-save runs. | `ProfileSession.save` |
| 3 | New spec: three rewards claimed in one commit whose write is stored and then errors. All three are settled, cash rises by the sum once, PaidRewards has 3, and a second claim pays nothing. | `ProfileSession.spec` |
| 4 | New `RewardLedger.validate`: the transaction id and amount use the profile's own rules (`EconomyRules.validateTransactionId` / `validateAmount`), the reason is a string of at most 100 characters, and the time is a non-NaN number. `record` refuses anything else as `InvalidReward: <why>` and writes nothing. | `RewardLedger.validate/record` |
| 5 | Known issue 8o tracks the full ledger (`LedgerFull`) and complete-outage loss explicitly; they are re-checked every audit. | `PROGRESS.md` |
| 6 | All cross-server items stay MULTIPLAYER UNVERIFIED (PROGRESS 8o, MULTIPLAYER_TESTS). | docs |

Part B is in `PLAYER_EXPERIENCE_AUDIT.md`: measurements across the seven areas and proposals P1–P8 (all small).

## 3. How it works
No structural change: two functions changed in ProfileSession and one validator was added to RewardLedger. EconomyService and the other services are unchanged.

## 4. Security and authority
Unchanged. Reward validation only tightens server-side input.

## 5. Persistence and data safety
Unchanged schema (v3). Invalid rewards never reach the ledger.

## 6. Decisions made
- **Condition 1:** I implemented the queue instead of documenting non-FIFO behaviour. It's small, and it makes the order deterministic.
- **Two test fixes:** two new overlap tests first failed because they relied on frame timing during server start. They now use a deterministic `Hold` on the fake store.

## 7. Deviations from the request
None.

## 8. Unresolved risks and known issues
- Unchanged: the full ledger and complete outage (8o), and everything cross-server is MULTIPLAYER UNVERIFIED.
- The player-experience findings in the plan are solo and simulator-based; human playtests are still needed.

## 9. Multiplayer status
Nothing new is verified across servers.

## 10. Files for the auditor
AUDITOR_REPORT.md, TEST_EVIDENCE.md, SOURCE_DIFFS.md, AUDITOR_QUESTIONS.md, PLAYER_EXPERIENCE_AUDIT.md, PROGRESS.md.
