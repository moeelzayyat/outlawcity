# Auditor report: 2026-10-16_n4-stage-a

- Project: OUTLAW CITY (Roblox, place ID 132163592957463)
- Date: 2026-10-16
- Commit range: `6031627..` the package commit (code and docs `87b6198`); GitHub `moeelzayyat/outlawcity`, branch `main`
- Prepared by: Claude (sole implementation agent)
- Status: **APPROVED by the Architect (2026-10-16, reviewed `fe693f1`).** Stage B blocked (see `N4_STAGE_B_PLAN.md`). Originally: Stage A done (solo), awaiting audit. **Stages B, C and D are not started.**

## 1. What was asked
Implement exactly three more street signs with the approved cantilever design:

| Junction | Corner | Post | Labels |
|---|---|---|---|
| (−100, −100) | (−,−) | (−122, −122) | 2nd St / B Ave |
| (100, −100) | (+,+) | (122, −78) | 2nd St / C Ave |
| (−100, 100) | (−,−) | (−122, 78) | 3rd St / B Ave |

**Rules:**
- The prototype stays unchanged (signature `87d79268`).
- Add only the three configuration entries and the tests, reusing `streetSigns()` and `buildStreetSigns()`.
- Each sign: 3 parts, 4 SurfaceGuis, Atomic streaming, flags off.
- No other changes.

**Evidence and go/no-go rules:** as in the approval; the results table is in TEST_EVIDENCE.

## 2. What was built
- **`CityLayout.STREET_SIGNS`:** four entries (the prototype first, unchanged, then the three Stage A entries). No other code changed.
- **`CityLayout.spec`:** the one-sign tests now cover every sign.
  - Count 4, the expected names, no duplicates.
  - Sizes, heights, orientation, names from the tables.
  - Full footprints, road and marking clearance, 3 or more studs from buildings, store and dealership, pad clearance.
  - The cantilever check per sign (blade starts at the post face away from the junction, no shared volume). The prototype's exact centres are kept.
  - New test: the exact post positions and names of all four.
- **Studio:** `buildStreetSigns` (from fresh module clones) added the three missing models and skipped the prototype by name. Nothing else was touched.

## 3. Security, persistence
Not affected.

## 4. Decisions made
- **Prototype first in the list:** `streetSigns()[1]` stays the approved sign. The prototype's exact-centre assertions are kept.
- **Weak approaches:** as planned, from the grid edge: (−100, −100) from the west, (100, −100) from the east, (−100, 100) from the west. Rendered views show the cross-street name edge-on at 30 studs on those approaches but readable at 60, before the junction.

## 5. Results
All mandatory functional, geometry, regression and rollback checks pass (TEST_EVIDENCE table):
- 4 signs; 328 / 114; 16 sign SurfaceGuis; all signatures unchanged; 216/216 tests.
- No hidden letters in 24 rendered views.
- No bump, touch or query interaction.
- 60 fps in all 12 desktop runs.
- One of each sign after a restart, extra builder calls and a fresh rebuild.
- Exact rollback to 319 / 114, the prototype only, 215 tests.

**Not tested:** PHONE SIMULATOR NOT TESTED (not counted as a pass); real phone NOT TESTED; MULTIPLAYER UNVERIFIED.

## 6. Risks and limitations
- **Memory** is not comparable: the same long Studio session; +134 MB between the before and after sets. It is not attributed to 9 static parts.
- **Text at about 60 studs** is small on desktop.
- **Weak approaches:** the cross-street name is edge-on near the junction (expected; noted in the plan).

## 7. Not done (by instruction)
- Stages B, C and D.
- Connector–highway signs.
- Second signs.
- Renaming.
- Any other change.
