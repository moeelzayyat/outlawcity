# Auditor report: 2026-10-15_world-polish-batch1

- Project: OUTLAW CITY (Roblox, place ID 132163592957463)
- Date: 2026-10-15
- Commit range: `96cce64..` the package commit (code `ea579b9`); GitHub `moeelzayyat/outlawcity`, branch `main`
- Prepared by: Claude (sole implementation agent)
- Status: Batch 1 done (solo), awaiting audit. Pursuit FPS is PARTIAL (see section 7).

## 1. What was asked
Implement only N3 (dealership overlap), N2 (template ground) and N1 (district colours and materials), with **one documented geometry exception, `Building_3_3_1`**.

Requirements:
- a verified backup;
- a baseline of names, positions, sizes, colours, materials, Baseplate and collision counts;
- N3: move the east edge in, keep the west edge, at least 1 stud of clearance, dealership not moved;
- N2: disable only the grid texture; Baseplate size, position and physics unchanged;
- N1: column colours and built-in materials, with no change to count, locations, roads or collision;
- keep the seeded RNG sequence;
- apply to the place and export the source.

Acceptance tests:
- 266 parts and 114 colliding;
- geometry equal to the baseline except the exception;
- at least 1 stud of clearance;
- no checkerboard;
- visuals at four views;
- HUD and markers readable;
- 3 + 3 FPS runs before and after;
- tests including a geometry check;
- regressions;
- exact rollback;
- phone NOT TESTED, MULTIPLAYER UNVERIFIED.

## 2. What was built
- **`CityLayout`:**
  - `DISTRICTS`: Brick / Concrete / Slate palettes by block column.
  - The original `rng:NextInteger(1, #BUILDING_COLORS)` roll is still drawn and indexes the district palette, so the RNG sequence is unchanged.
  - `BUILDING_EAST_INSET = { Building_3_3_1 = 2.5 }`.
  - New optional `PartSpec.PhysicsMaterial = SmoothPlastic` for buildings.
- **`CityBuilder`:** applies `PhysicsMaterial` as `CustomPhysicalProperties`.
- **`CityLayout.spec`:** +3 tests.
  - The geometry signature of 186 generated parts is locked to the pre-batch value `8b66ade9`.
  - `Building_3_3_1` has its west edge at 138.5, east edge at 177, height 46, and is at least 1 stud from every dealership part; there are still 24 buildings.
  - District materials and colours; SmoothPlastic physics.
- **The Studio place:** the 24 existing buildings got the new colours, materials and physics, and `Building_3_3_1` got its new size and position. On the Baseplate, only the grid `Texture` was disabled (Transparency 1) and its colour changed.

## 3. How it works
See `docs/ARCHITECTURE.md`, section "City look (World polish Batch 1)".

## 4. Security and authority
Not affected. No scripts, remotes, police, pursuit (130 / 100 / 0.25 / 8), vehicles, physics, cash, jail, robbery, dealership mechanics or anti-cheat changes. No assets; only built-in materials.

## 5. Persistence and data safety
None.

## 6. Decisions made
- **Inset of 2.5 studs** (east edge 179.5 → 177.0). It gives a 2.00-stud minimum gap, above the required 1.
- **Building physics pinned to SmoothPlastic.** Changing `Material` would otherwise change the default friction and elasticity of walls that cars hit.
- **The Baseplate keeps its material (Plastic) and physics;** only its colour changed. The texture is disabled rather than deleted, so rollback is one property.
- **Ground colour (62, 66, 58).** It's a dark plain ground; see the risks.

## 7. Deviations from the request
- **FPS, three comparable pursuit runs before and after:** PARTIAL.
  - The owner's Studio window went to the background repeatedly, and Studio then throttles to about 15 fps.
  - Valid samples: before idle 3/3 (60.0 fps) and pursuit 1/3 (60.0); after idle 3/3 (60.0).
  - Pursuit after: 0/3 valid (all throttled), even with a guard that waits for 55+ fps.
  - A repeat "before" set, taken after the rollback test, was also throttled and is not used.
- **Phone:** NOT TESTED.

## 8. Unresolved risks and known issues
- **Low:** the dark ground (62, 66, 58) is close to the road colour (48, 48, 54), so distant grid roads contrast less against the ground in the highway view. Lane markings and centre lines stay visible. If the owner prefers more contrast, the colour can be lighter with no other change.
- **Low:** on the first capture after a camera jump, SurfaceGui signs sometimes render without text (known; see the previous closeout). The second capture shows them.

## 9. Multiplayer status
MULTIPLAYER UNVERIFIED (what other players see).

## 10. Files for the auditor
This folder: AUDITOR_REPORT, CHANGE_MANIFEST, TEST_EVIDENCE, SOURCE_DIFFS, AUDITOR_QUESTIONS, screenshots/. Plus:
- `docs/PROGRESS.md`
- `docs/ARCHITECTURE.md`
- `docs/CITY_NAVIGATION_WORLD_AUDIT.md`
- `src/ServerScriptService/Server/World/CityLayout.luau`
- `src/ServerScriptService/Server/World/CityBuilder.luau`
- `src/ServerStorage/Tests/CityLayout.spec.luau`
