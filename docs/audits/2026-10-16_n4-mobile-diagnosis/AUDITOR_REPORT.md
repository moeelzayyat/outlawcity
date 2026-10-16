# Auditor report: 2026-10-16_n4-mobile-diagnosis

- Project: OUTLAW CITY (Roblox, place ID 132163592957463)
- Date: 2026-10-16
- Commit range: `f0a103c..` the package commit (docs `66037f9`); GitHub `moeelzayyat/outlawcity`, branch `main`
- Prepared by: Claude (sole implementation agent)
- Status: PLAN ONLY, awaiting audit. No Studio, code, UI or sign changes.

## Summary
The diagnosis answers the six questions in `docs/N4_MOBILE_READABILITY_DIAGNOSIS.md`:
1. **Cash badge:** owned by `CashHudController` (`CashHud.Cash`). It uses fixed pixel offsets at centre + 56..164 px, row y 58–84. On phones that lands at about 30–38% of screen height, the same band where signs appear in the chase camera.
2. **Moving or shrinking it:** every placement collides with the Spawn Car button, the wanted stars or banner, the robbery panel, the touch controls or Roblox core UI, and it would affect all devices. Not the first choice.
3. **Lettering:** about 1.9× the letter height is needed for at least 8 px at a 55–63-stud blade distance on iPhone 7. 2× is proposed.
4. **Clearances:** a 12 × 3 blade on all four signs stays fully on the sidewalk; road 3.90, markings 5.00, buildings 8.99.
5. **Chase camera:** a bigger sign doubles the projected text. Near-corner reading at 45 studs goes from 6.4 to 12.8 px (iPhone 7). Far-corner reading becomes legible at about 25 studs. Partial cash-badge overlap may remain.
6. **Recommendation:** enlarge the four existing blades to **12 × 3** (EW centre 9.1, NS centre 12.2, post 13.1). Constants only plus a one-off replacement of the four models. Acceptance criteria and exact rollback are in the doc.

## Risks
- Bigger boards are more visually prominent.
- Far-corner reading at 45+ studs stays marginal on phones.
- Some HUD overlap may remain.
- Real phone NOT TESTED.

## Not done
No changes. No new signs, corners, stages or renaming.
