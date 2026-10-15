# Auditor report: 2026-10-15_stop-lines-batch1

- Project: OUTLAW CITY (Roblox, place ID 132163592957463)
- Date: 2026-10-15
- Commit range: `52cf1ca..` the package commit (code and docs `0b4919b`); GitHub `moeelzayyat/outlawcity`, branch `main`
- Prepared by: Claude (sole implementation agent)
- Status: Stop-line Batch 1 done (solo), awaiting audit. **N4 street signs and the two connector–highway joins are not started.**

## 1. What was asked
Implement only N5: 50 static stop lines on the existing grid-intersection approaches.

Corrections:
1. Fix the plan text to "6 four-arm, 6 three-arm, 4 two-arm intersections = 50 approaches".
2. Use exactly the 50 approaches recorded in the plan's TEST_EVIDENCE, one uniquely named line each.
3. Each line covers only the incoming half of its 36-stud road, stops 2 studs before the intersection square, and stays clear of the yellow centre line.

Implementation:
- backup and baseline first;
- build through the CityLayout/CityBuilder pipeline;
- 16.4 × 1.2 × 0.05, oriented for the approach, top 0.25, RGB (235, 235, 235) SmoothPlastic;
- CanCollide, CanQuery, CanTouch and CastShadow all false;
- no existing part changes;
- no new runtime scripts, textures, sounds or gameplay.

Required evidence (10 items): counts 50 / 316 / 114; placement checks; the 186-part signature `8b66ade9`; properties read in Studio; drive-over with speed and height; a comparable pursuit regression; the four views twice each; 3 + 3 FPS runs before and after; full tests and gameplay regressions; rollback to the exact baseline.

## 2. What was built
- **`CityLayout`:**
  - Constants `STOP_LINE_GAP = 2`, `STOP_LINE_DEPTH = 1.2`, `STOP_LINE_INNER = 0.6`, `STOP_LINE_CURB = 1`.
  - `stopLineApproaches()` returns the 50 arms. An arm exists where a road continues past the square: inside the grid, plus the connector roads north of z = −300.
  - One loop in `createBlueprint`, after the centre lines, adds one non-colliding `Markings` slab per arm through the existing `slab()` helper.
- **`CityLayout.spec`:** +2 tests.
  - Count 50, unique names, 6 / 6 / 4 split.
  - For every line: top 0.25, thickness 0.05, 16.4 × 1.2, non-colliding, colour and material, fully on one `Roads` part, no overlap with any `Line*` marking, 2 studs before the square, correct (right-hand) side.
  - The existing signature test now skips `StopLine_*` (new parts), so it still locks the 186 old parts to `8b66ade9`.
- **The Studio place:** 50 `StopLine_*` parts created in `Workspace.City.Markings` from a fresh blueprint, with exactly the properties `CityBuilder` sets. CityBuilder only builds the City when it is missing, so the parts had to be added to the existing place once. Nothing else was touched.
- **Docs:** the plan's arm breakdown (6 / 6 / 4) and status; PROGRESS (rows, test count, upcoming); ARCHITECTURE (stop-line note under "City look").

## 3. How it works
See `docs/ARCHITECTURE.md`, section "City look (World polish Batch 1)", bullet "Stop lines".
- Right-hand traffic, using Roblox right vectors: a car heading +Z keeps to −X, −Z to +X, +X to +Z, −X to −Z.
- The line sits on the half a car uses to enter the junction.
- Each line runs from 0.6 studs off the road axis (the 0.8-wide yellow line ends 0.4 off it, so there is a 0.2-stud gap) to 17 studs off it (1 stud inside the 18-stud half road).
- **Orientation:** the parts are axis-aligned, with X and Z sizes swapped for W/E arms (1.2 × 16.4) instead of a rotated CFrame. The result is identical, and it keeps the existing `slab()` helper and rectangle checks.

## 4. Security and authority
Not affected. No scripts, remotes, police AI or pursuit values (130 / 100 / 0.25 / 8), vehicle physics, cash, jail, robbery, dealership or anti-cheat changes. Vehicle validation stays monitor-only. No assets; built-in material only.

## 5. Persistence and data safety
None.

## 6. Decisions made
- **Axis-aligned sizes instead of rotation** (section 3).
- **Spec tolerances 1e-4:** `Vector3` is single precision. The first run failed on exact comparisons (16.4 read back as 16.3999996). Only the new tests were changed; the old signature is untouched.
- **Pursuit comparison by A/B in the rollback state:** the same on-foot pursuit was run 3 times with the lines and 3 times with them removed. No route timings were recorded before this batch.
- **Drive-over control:** the same scripted drive was repeated in the rollback state, so "no bump" is compared at the same spots without lines.

## 7. Risks and limitations
- **Readability at distance:** at the connector view (~100 studs) the lines are thin; up close and at junctions they read clearly. Phone readability is NOT TESTED.
- **Phone performance:** NOT TESTED. Desktop is 60 fps in all 12 runs.
- **Memory:** the after runs report about 180 MB more. They ran in the same Studio session after many playtests, so this isn't a valid comparison and isn't attributed to the 50 parts.
- **Vehicle validation:** 2 Teleport observations in the regression session. Both came from my test moving the car to the drive start (257 and 566 studs in about 0.2 s). Monitor-only, no action taken.
- **Storefront stall (PROGRESS 8g):** the police unit stalled at the storefront again during the robbery chase. This is known and unchanged.
- **Multiplayer:** other players seeing the lines is MULTIPLAYER UNVERIFIED (static anchored parts, streaming on).

## 8. Not done (by instruction)
- N4 street-name signs.
- Stop lines at the two connector–highway joins (±100, −492).
- Plaza edges.
