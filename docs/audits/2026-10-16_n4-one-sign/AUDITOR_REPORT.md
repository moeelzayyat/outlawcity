# Auditor report: 2026-10-16_n4-one-sign

- Project: OUTLAW CITY (Roblox, place ID 132163592957463)
- Date: 2026-10-16
- Commit range: `c81f00f..` the package commit (code and docs `2354a92`); GitHub `moeelzayyat/outlawcity`, branch `main`
- Prepared by: Claude (sole implementation agent)
- Status: the one-sign prototype is built (solo) and awaiting audit. **The other 15 signs and connector–highway signs are not built.**

## 1. What was asked
Implement exactly ONE street-name sign, `City.StreetSigns.StreetSign_100_100`, at junction (100, 100), following `STREET_SIGN_PROTOTYPE_PLAN.md`:
- the sidewalk corner (122, 0.6, 122);
- a 0.4 × 10.4 × 0.4 post and two perpendicular 7 × 1.5 × 0.2 blades along their streets;
- 4 SurfaceGuis with "3rd St" / "C Ave";
- no collision, query, touch or shadow; Atomic streaming;
- through CityLayout/CityBuilder with no new runtime script;
- created exactly once, with rebuilds unable to duplicate it.

**Corrections:**
1. The post is 3.8 studs from the road edge.
2. The blades' closest edge is about 0.5 stud from the road edge.
3. Tests check full footprints.
4. Approach views on all incoming routes.
5. Text sizes are estimates only.
6. Phone at 30 studs is the minimum; 60 studs is recorded.
7. Plain names are for the prototype only.

**Required tests:** counts and hashes; properties; legibility at 30 and 60 studs; the phone simulator where available; no overlap; no bump or interaction; regressions; 3 + 3 FPS and memory runs; no duplicates on rebuild or reload; exact rollback.

## 2. What was built
- **`CityLayout`:**
  - `STREET_NAMES_EW` / `STREET_NAMES_NS` (plain names);
  - `STREET_SIGNS` (one entry: X 100, Z 100, corner +22/+22);
  - the size and height constants;
  - `streetSigns()` returning the sign's 3 part specs (group `StreetSigns`, non-colliding SmoothPlastic) and its 2 label specs.
  - Signs are **not** in `createBlueprint`, so the existing blueprint, signature and stop lines are untouched.
- **`CityBuilder.buildStreetSigns(city)`:** creates `City.StreetSigns` if needed and adds only missing sign models. Each model is Atomic-streamed with PrimaryPart `Post`. Parts are anchored with collision, query, touch and shadow off. Each blade face gets one SurfaceGui + TextLabel. No scripts.
- **`WorldService.init`:** calls `buildStreetSigns(city)` on every server start. That covers a fresh rebuild, and it adds nothing when the sign exists.
- **`CityLayout.spec`:** +3 tests (section 5 of TEST_EVIDENCE).
- **Studio place:** the sign was created once by calling `buildStreetSigns` (from fresh module clones) against the existing `Workspace.City`, called twice to prove idempotence.

## 3. How it works
See `docs/ARCHITECTURE.md`, "City look", bullet "Street-name signs".

## 4. Security and authority
Not affected. No remotes, police AI, pursuit (130 / 100 / 0.25 / 8), vehicle physics, robbery, economy, dealership, jail or anti-cheat changes. Built-in font and material only; no assets.

## 5. Persistence and data safety
None.

## 6. Decisions made
- **Signs outside the blueprint, built by an idempotent builder called at server start.** This keeps the 186-part signature and stop-line signature exact. It also meets "exactly once": the place holds the sign, and every later call (server start, rebuild) adds only what's missing.
- **Geometry exactly as approved, although testing found a defect.** The post (0.4 thick) runs through the blades' centre (0.2 thick) and hides about one glyph on every face. I didn't change the approved geometry. The possible fixes are in AUDITOR_QUESTIONS.
- **Text layout:** label 92% × 84% of the blade with 4%/8% margins (the plan's padding), GothamBold, TextScaled.

## 7. Results summary
- 1 sign, 319 / 114, +4 SurfaceGuis; all old hashes unchanged; 214/214 tests.
- Every part's full footprint is on the sidewalk: post 3.80 and blades 0.50 from the road edge, nearest marking 1.66, nearest building 16.96.
- No duplicate after a reload or a full rebuild with three builder calls.
- No bump in all four lanes; 0 Touched events walking through the post; rays pass through.
- **Desktop legibility:** names legible at ~33 studs (~15 px glyphs) and readable but small at 62–68 studs (5–7 px). The plan's estimates (27 / 13 px) were about 2× too high.
- **Phone simulator:** NOT TESTED.
- **FPS:** one after-set had two hitches (57.8 / 50.7 fps); the repeat set was 60.0 ×6. Memory +33 MB within session drift (inconclusive).
- Rollback exact: 316 / 114, all hashes, 211 tests.

## 8. Risks and limitations
- **Post occludes about one letter per face** (the main finding).
- **Small text at 60 studs:** 5–7 px on desktop, so a phone at 60 studs is very likely unreadable (not tested).
- **East approach:** from the stop line the sign is outside the field of view; it's read earlier, 30–60 studs back.
- **FPS hitches** in one set, not reproduced.
- **Memory** inconclusive.
- **Multiplayer:** MULTIPLAYER UNVERIFIED.

## 9. Not done (by instruction)
- The other 15 signs.
- Connector–highway signs.
- Any markings, streets, buildings or gameplay.
