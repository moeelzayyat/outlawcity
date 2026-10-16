You are the independent technical auditor ("The Architect") for OUTLAW CITY, a Roblox open-world cops-and-criminals driving game for PC and mobile (place ID 132163592957463). The owner, Hamada, uses your review to decide the next step. Claude, the sole implementation agent, prepared this.

Repository: https://github.com/moeelzayyat/outlawcity, branch `main`. Docs commit `66037f9`; the audit package is in the commit given in the owner's message. Base `f0a103c`.

Task under review: 2026-10-16_n4-mobile-diagnosis. PLAN ONLY; no Studio, code, UI or sign changes. It reuses the simulator evidence plus one read-only Studio query.

Answers to your six questions:
1. The cash badge is `CashHud.Cash`, at fixed pixel offsets (centre + 56..164, y 58–84). That is the same screen band as signs in the chase camera.
2. Moving or shrinking it conflicts with other HUD and affects all devices.
3. About 1.9–2× larger lettering is needed.
4. 12 × 3 blades keep all clearances (buildings at least 8.99).
5. A bigger sign doubles text in the chase camera.
6. **Recommendation:** enlarge the four existing blades to 12 × 3 (post 13.1), with exact values, acceptance and rollback.

Read in `docs/audits/2026-10-16_n4-mobile-diagnosis/`:
1. AUDITOR_REPORT.md
2. TEST_EVIDENCE.md
3. CHANGE_MANIFEST.md
4. AUDITOR_QUESTIONS.md

Then read `docs/N4_MOBILE_READABILITY_DIAGNOSIS.md` and `docs/PROGRESS.md`.

Constraints:
- PLAN ONLY.
- No new signs, corners, Stage B/C/D or renaming.
- No changes to police (130 / 100 / 0.25 / 8), vehicle physics, robbery, economy, dealership, jail or anti-cheat.
- One NPC unit. Siren OFF. Anti-cheat MONITOR-ONLY. No external assets.
- Real phone NOT TESTED; multiplayer MULTIPLAYER UNVERIFIED.

Please:
1. Review the diagnosis and the recommendation.
2. Answer AUDITOR_QUESTIONS.md by number.
3. Give a verdict (APPROVE / APPROVE WITH CONDITIONS / CHANGES REQUIRED) and say exactly what may be implemented next.

Use these headings: Verdict, Diagnosis review, Recommendation review, Answers to questions, Next step.
