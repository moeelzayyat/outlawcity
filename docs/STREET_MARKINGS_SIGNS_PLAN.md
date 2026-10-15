# OUTLAW CITY: stop lines (N5) and street-name signs (N4), PLAN ONLY

Status: **Batch 1 (N5 stop lines) IMPLEMENTED 2026-10-15, awaiting Architect review** (`docs/audits/2026-10-15_stop-lines-batch1/`). The Architect approved N5 only; **N4 and the connector-highway joins are not started.** Originally: Prepared 2026-10-15 from `src/ServerScriptService/Server/World/CityLayout.luau` and read-only Studio queries (place 132163592957463; evidence in `docs/audits/2026-10-15_markings-signs-plan/TEST_EVIDENCE.md`).

**Deduplication:** this is the single plan for intersection stop lines. It **replaces** atmosphere proposal **P-E** (`CITY_ATMOSPHERE_AUDIO_AUDIT.md`) and navigation proposal **N5** (`CITY_NAVIGATION_WORLD_AUDIT.md`), which both point here. Street-name signs are navigation **N4**. Crosswalks (mentioned as optional in P-E) are **not** proposed now.

**Boundaries:**
- No new roads, buildings, districts, destinations or gameplay.
- No changes to vehicle physics, pursuit (130 / 100 / 0.25 / 8), robbery, economy, jail, dealership or anti-cheat (monitor-only).
- Siren off; one police NPC; no external assets or scripts.
- Studio is the source of truth. Multiplayer is MULTIPLAYER UNVERIFIED.

**Priority:** road markings (N5) come before street names (N4).

## 1. What the roads look like now (measured)
- **Grid lines** x and z ∈ {−300, −100, 100, 300}; roads 36 wide (`ROAD_WIDTH`), top at y = 0.2 (`ROAD_TOP`).
  - 16 intersections, each a 36×36 square owned by the east–west road.
  - North–south roads are split between intersections, so the yellow centre lines (`LineEW_*` / `LineNS_*`, 0.8 wide, top 0.25) stop at each square's edge.
- **Approaches (road arms entering an intersection):** **50** in total.
  - **6 four-arm intersections:** (±100, −300), (±100, −100), (±100, 100). The two at z = −300 get their fourth arm from the connector road north to the highway.
  - **6 three-arm intersections:** (±300, −100), (±300, 100), (±100, 300).
  - **4 two-arm corners:** (±300, ±300).
  - 6 × 4 + 6 × 3 + 4 × 2 = 50.
  - Corrected 2026-10-15 per the Architect: the earlier text wrongly said eight four-arm intersections.
- **No stop lines, crosswalks or street names exist.**
- **Markings today:** 120 parts, all `CanCollide = false`, `CanQuery = false`, `CanTouch = false`, `CastShadow = false` (CityBuilder sets these for every non-colliding spec).

## 2. N5: stop lines (recommended first)

### Exact locations and count
- **One stop line per approach: 50 parts.**
  - For an intersection at (X, Z) and an arm on side s (north −Z, south +Z, west −X, east +X), the line sits on that arm, **2 studs before the intersection square** (its near edge 18 + 2 = 20 studs from the intersection centre).
  - It spans the **incoming half** of the road, from 0.6 studs off the centre line to 1 stud inside the curb.
  - Incoming half means right-hand traffic, so it's the half a car uses to *enter* the junction.
- Named `StopLine_<X>_<Z>_<side>`, in the existing `City.Markings` folder.
- **Not included:**
  - the two connector–highway joins at (±100, −492) (T-joins onto the highway, not grid intersections);
  - the plaza edges (the plaza isn't a road arm).

### Geometry and safe placement
- **Size:** 16.4 studs long (across the half road) × 1.2 studs deep (along the road) × 0.05 thick.
- **Height:** top at `MARK_TOP` (0.25), the same plane as the centre lines, so no new height level.
- **Spacing:** 0.6 studs from the centre line, which keeps the yellow line clear.
- **Footprint:** entirely on the road part (checked by spec: inside a `Roads` rectangle, not on sidewalks or the plaza).
- **Generated in `CityLayout`** next to the centre lines, using the same `slab(..., canCollide = false)` helper.

### Collision, query, touch, shadow
- `CanCollide = false`, `CanQuery = false`, `CanTouch = false`, `CastShadow = false`.
- These are the existing CityBuilder settings for non-colliding specs, so cars, the police unit's raycasts and the vehicle validation can't see them.

### Mobile readability
- White (235, 235, 235) SmoothPlastic, the same as the highway lane dashes, which read clearly in the Batch 1 closeout highway capture.
- 1.2 studs deep reads as a bar at driving distance.

### Performance
- +50 static anchored parts with no collision, queries, touch or shadows: 266 → 316 BaseParts.
- No scripts and no textures. Streaming is already on. Negligible.

### Repeatable visual acceptance
Same camera positions every time, in Play with the atmosphere lighting, 2 captures each (the first after a camera jump can be incomplete):
- (−60, 40, −60) looking at (60, 10, 60): plaza crossroads;
- (100, 12, 60) looking at (100, 0, 100): one 4-arm junction close-up;
- (−300, 12, −250) looking at (−300, 0, −300): a corner;
- (100, 12, −420) looking at (100, 0, −300): a connector junction.

**Pass:** a white bar is visible on every arm in view, with no flicker against the road or the yellow line, and the HUD is readable.

### Rollback
Remove the stop-line loop from `CityLayout` and delete `City.Markings.StopLine_*` in the place (all 50 are named, so a single query finds them). The CityLayout.spec geometry signature (existing parts unchanged) must still pass.

## 3. N4: street-name signs (second, later batch)

### Names
- **East–west streets** (z = −300, −100, 100, 300, from the highway side): **1st St, 2nd St, 3rd St, 4th St**.
- **North–south avenues** (x = −300, −100, 100, 300, west to east): **A Ave, B Ave, C Ave, D Ave**.
- Plain names, as suggested. Themed names are the owner's choice.

### Exact locations and count
**16 signs**, one per intersection, on a sidewalk corner 22 studs from the intersection centre (4 studs inside the sidewalk). Each corner was chosen as the first quadrant that is on a sidewalk block, off the road, and at least 3 studs from buildings, the store, the dealership and spawn pads. Read-only check result:

| Intersection | Sign at | Block |
|---|---|---|
| (−300, −300) | (−278, −278) | Block_1_1 |
| (−300, −100) | (−278, −78) | Block_1_2 |
| (−300, 100) | (−278, 122) | Block_1_3 |
| (−300, 300) | (−278, 278) | Block_1_3 |
| (−100, −300) | (−78, −278) | Block_2_1 |
| (−100, −100) | (−78, −122) | Block_2_1 |
| (−100, 100) | (−78, 122) | Block_2_3 |
| (−100, 300) | (−78, 278) | Block_2_3 |
| (100, −300) | (122, −278) | Block_3_1 |
| (100, −100) | (122, −78) | Block_3_2 |
| (100, 100) | (122, 122) | Block_3_3 |
| (100, 300) | (122, 278) | Block_3_3 |
| (300, −300) | (278, −278) | Block_3_1 |
| (300, −100) | (278, −78) | Block_3_2 |
| (300, 100) | (278, 122) | Block_3_3 |
| (300, 300) | (278, 278) | Block_3_3 |

Each sign has 3 parts, **48 parts in total**:
- a post, 0.4 × 9 × 0.4;
- two blades, 6 × 1.2 × 0.2, at 8 and 9.4 studs high, one facing along each street.

Each blade carries 2 `SurfaceGui`s (front and back) with the street name as text only: **64 SurfaceGuis**.

### Collision, query, touch, shadow
- All `CanCollide = false`, `CanQuery = false`, `CanTouch = false`, `CastShadow = false`.
- Placed on sidewalk corners, 4+ studs from the road edge, so they can't block cars, police routes or prompts.

### Mobile readability
- White bold text on a dark green blade, `TextScaled` with a size limit, `LightInfluence = 0`.
- The blades are 6 studs wide: readable from about 40–60 studs.
- **Risk:** 64 SurfaceGuis is the main mobile cost of N4; that's why N4 is a separate later batch with its own FPS check.

### Performance
+48 static parts and 64 small text SurfaceGuis. Low on desktop; to be measured on phones.

### Repeatable visual acceptance
- At 3 junctions (one interior, one edge, one corner), captures from 30 and 60 studs away along each street: the right street name is readable and faces the road.
- No sign overlaps a building, the store, the dealership or a spawn pad (spec-checked).

### Rollback
Remove `CityLayout.STREET_SIGNS` and delete the `City.StreetSigns` folder.

## 4. Recommended first batch (narrow)
**Batch 1 = N5 stop lines only (50 parts). N4 waits for its own approval.**

**Before starting:** the owner saves a backup (checked in the Studio log). I record the baseline: part count (266), collision count (114) and the geometry hashes.

**Acceptance criteria:**
1. **Parts:** exactly 50 new `StopLine_*` parts in `City.Markings`. BaseParts 266 → 316; CanCollide stays 114.
2. **Properties:** every stop line has `CanCollide`, `CanQuery`, `CanTouch` and `CastShadow` = false, top at 0.25, 16.4 × 1.2, white SmoothPlastic.
3. **Placement (`CityLayout.spec`):**
   - every stop line lies fully on a road part and 2 studs before its intersection square;
   - at most one per approach;
   - none overlaps a centre line;
   - count = 50.
4. **Unchanged geometry:** the existing geometry signature test (`8b66ade9`, 186 parts) still passes. No existing part moves or changes.
5. **Gameplay:**
   - driving across stop lines at speed shows no bump (the car's speed and height don't change);
   - the police unit's route timings in one chase are similar to before;
   - vehicle validation stays at 0 observations;
   - all tests pass.
6. **Visuals:** the four camera views in section 2, before and after, 2 captures each.
7. **Performance:** idle and pursuit FPS and memory, 3 runs each, with Studio in front. If Studio can't stay in front, mark it PARTIAL.
8. **Rollback:** removing the loop and the 50 parts restores the baseline hashes exactly.
