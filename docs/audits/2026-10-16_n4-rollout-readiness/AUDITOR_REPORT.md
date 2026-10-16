# Auditor report: 2026-10-16_n4-rollout-readiness

- Project: OUTLAW CITY (Roblox, place ID 132163592957463)
- Date: 2026-10-16
- Commit range: `dc32b76..` the package commit (docs `df57f04`); GitHub `moeelzayyat/outlawcity`, branch `main`
- Prepared by: Claude (sole implementation agent)
- Status: PLAN ONLY, awaiting audit. **No Studio edits; no sign built.**

## 1. What was asked
1. Record the cantilever approval. The approved prototype must not change.
2. A read-only rollout-readiness audit of the 15 remaining junctions. For each:
   - the exact corner;
   - full post and blade footprints;
   - distances to roads, markings, buildings, the dealership, the store, spawns and other structures;
   - rejection of obstructing positions or poor sightlines;
   - whether the cantilever direction should vary;
   - visibility from realistic incoming approaches;
   - where the design may not work;
   - the expected part and SurfaceGui counts.
3. Naming: plain versus themed alternatives, without changing the prototype; and whether every junction needs a sign.
4. A staged rollout: a first batch, desktop performance criteria, a mobile-simulator plan, streaming, duplication and rebuild checks, rollback, and a go/no-go gate.

## 2. What was done
- **Approval recorded:**
  - `PROGRESS.md` lists every point the Architect gave;
  - the cantilever AUDITOR_REPORT status is set to APPROVED;
  - the prototype plan's status is updated.
- **One read-only Studio query:**
  - all 16 junctions × 4 corners with the approved geometry;
  - footprints and clearances against every City part;
  - the arms;
  - a geometric sightline screen (driver eye in the incoming lane at 30, 45, 60 and 75 studs; angle, face incidence and an unobstructed ray).

  The screen agrees with the approved sign's recorded captures.
- **`docs/N4_STREET_SIGN_ROLLOUT_PLAN.md`:**
  - results for all corners (31 fit, 33 rejected);
  - the sightline pattern (one sign serves 3 of 4 approaches) and the corner rule;
  - the ranked candidates with exact posts;
  - the counts per stage;
  - the navigation argument for fewer signs;
  - the two naming schemes;
  - Stage A (3 signs) with acceptance, the phone plan, streaming and duplicate checks, rollback and a 7-point go/no-go gate.

## 3. Key findings
- **Every junction has at least one fitting corner.** Every fitting corner keeps the post 3.80 and blades 3.90 from the road, at least 4.84 from markings and at least 6.40 from solids.
- **Each sign leaves one weak approach:** the lane passing right beside the corner. Choosing the corner whose weak approach comes from the grid edge or the perimeter serves all interior and destination traffic. This matches the approved sign, whose weak approach is from the east edge.
- **Rejected corners:**
  - 28 off-grid (no sidewalk);
  - 4 on the plaza;
  - (−100, −100) corner (−, +), which overlaps the 24/7 MART wall and is blocked by it.
- **The four 2-arm grid corners** have one fitting corner each, which serves one of their two approaches. The design underperforms there; not recommended.
- **Navigation:** the plaza ring (A, 3 more signs) plus the two highway connectors (B, 2 signs) cover every route between spawn, the store, the dealership and the highway. I recommend stopping at 6 signs unless playtests show edge confusion.

## 4. Recommended first batch (Stage A, not built)
| Junction | Corner → post | Names |
|---|---|---|
| (−100, −100) | (−,−) → (−122, −122) | 2nd St / B Ave |
| (100, −100) | (+,+) → (122, −78) | 2nd St / C Ave |
| (−100, 100) | (−,−) → (−122, 78) | 3rd St / B Ave |

**Result:** 4 signs in total; BaseParts 319 → 328; colliding 114; 16 sign SurfaceGuis.

## 5. Security, persistence
Not affected.

## 6. Risks and limitations
- **The sightline screen is geometric, not rendered.** Stage A acceptance requires real captures.
- **Readability:** text is small at about 60 studs on desktop; phone readability is untested.
- **Memory** measurements in this long Studio session are noisy (see the N5 closeout).
- **Multiplayer:** MULTIPLAYER UNVERIFIED (streaming to other players).

## 7. Not done (by instruction)
- No signs built.
- No Studio edits.
- No renaming of the prototype.
