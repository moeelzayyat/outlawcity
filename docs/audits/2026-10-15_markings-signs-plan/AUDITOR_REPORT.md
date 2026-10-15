# Auditor report: 2026-10-15_markings-signs-plan

- Project: OUTLAW CITY (Roblox, place ID 132163592957463)
- Date: 2026-10-15
- Commit range: `be0e1f3..2e84281` (docs only) + this package commit; GitHub `moeelzayyat/outlawcity`, branch `main`
- Prepared by: Claude (sole implementation agent)
- Status: **PLAN AWAITING ARCHITECT REVIEW.** Nothing changed in Studio.

## 1. What was asked
1. Record the World Polish Batch 1 approval and its open items in `PROGRESS.md`.
2. Write a PLAN-ONLY proposal for N5 (stop lines, the same task as atmosphere P-E) and N4 (street-name signs), with markings first.

For each: exact locations and part counts, geometry and safe placement, collision/query/touch/shadow, mobile readability, performance, repeatable visual acceptance, rollback, deduplication, and a narrow first batch.

## 2. What was built
- **`docs/STREET_MARKINGS_SIGNS_PLAN.md`:**
  - **N5:** 50 stop lines, one per measured approach. Exact rule, size 16.4 × 1.2 × 0.05, top 0.25, white, no collision/query/touch/shadow.
  - **N4:** 16 signs at exact sidewalk corners (48 parts, 64 SurfaceGuis), with plain names 1st–4th St and A–D Ave.
  - Visual acceptance with fixed camera positions.
  - Rollback for each.
  - **Batch 1 = N5 only**, with 8 acceptance criteria.
- **`PROGRESS.md`:** the Batch 1 approval and open items recorded.
- **Deduplication:** `CITY_ATMOSPHERE_AUDIO_AUDIT.md` P-E and `CITY_NAVIGATION_WORLD_AUDIT.md` N5 now point to the new plan.

## 3. How it works
Both features would be data in `CityLayout`, built by the existing `CityBuilder`, which already makes non-colliding specs non-queryable, non-touching and shadowless. No scripts at runtime.

## 4. Security and authority
Not affected.

## 5. Persistence and data safety
None.

## 6. Decisions made
- **Stop lines cover only the incoming half** of each arm (right-hand traffic), 0.6 from the centre line, so they never overlap the yellow line.
- **The two connector–highway T-joins are excluded.**
- **Crosswalks are not proposed now.**
- **N4 is deferred to its own batch**, because 64 SurfaceGuis are its main phone cost.

## 7. Deviations from the request
None.

## 8. Unresolved risks and known issues
- **Low:** a half-width stop line implies lanes that the game doesn't enforce. The owner may prefer full-width lines; the count is unchanged either way.
- **Low:** N4 SurfaceGuis on phones are untested.

## 9. Multiplayer status
Not applicable to a plan.

## 10. Files for the auditor
- This folder: AUDITOR_REPORT, CHANGE_MANIFEST, TEST_EVIDENCE, AUDITOR_QUESTIONS.
- `docs/STREET_MARKINGS_SIGNS_PLAN.md`
- `docs/PROGRESS.md`
- `src/ServerScriptService/Server/World/CityLayout.luau`
