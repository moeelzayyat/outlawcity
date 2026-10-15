# OUTLAW CITY: city navigation and world polish audit (PLAN ONLY)

Status: **Batch 1 (N3 + N2 + N1) implemented 2026-10-15 under the Architect's APPROVE WITH CONDITIONS, awaiting audit.** The only geometry exception is `Building_3_3_1`. N4 and N5 are not started. Results are in `PROGRESS.md`. The original plan follows. Prepared 2026-10-14 from read-only Studio inspection of place 132163592957463 (every query asserted the place ID) and the `src/` snapshot.

**Boundaries:**
- No map expansion or new districts.
- No new stores, robbery locations, vehicles, weapons, gangs, properties, NPCs or police units.
- No changes to driving physics, pursuit tuning (130 / 100 / 0.25 / 8), robbery, economy, jail or anti-cheat (monitor-only).
- Vehicle and pedestrian routes are preserved.
- No third-party assets or scripts. The siren stays disabled; there is one police unit.
- Mobile performance first. Multiplayer is MULTIPLAYER UNVERIFIED.

## 1. What is in Studio today (read-only inspection)

### Totals
- 266 BaseParts in the workspace.
- 114 CanCollide.
- 17 semi-transparent.
- 134 CastShadow.
- 5 glass, 4 neon.
- `StreamingEnabled = true`.

The city is generated from `ServerScriptService.Server.World.CityLayout` (data) by `CityBuilder`.

### City folders
| Group | Parts | Collide | Extent |
|---|---|---|---|
| Roads | 18 | 18 | X −318..318, Z −492..318 |
| Markings | 120 | 0 (CastShadow 0) | centre lines, highway edges and dashes |
| Sidewalks | 8 | 8 | 164×164 block slabs, 0.6 high |
| Buildings | 24 | 24 | X −270..270, height 24–93 |
| Plaza | 1 | 1 | 164×164 at the centre |
| Highway | 3 | 3 | Z −580..−460, X −820..820 |
| Barriers | 13 | 13 | highway walls, median, end-plaza walls |
| Store | 14 | 13 | (−145..−118, −76..−44) |
| Dealership | 26 | 11 | (179..221, 120..152) |
| Jail | 24 | 20 | (−15..15, 405..435), **outside the road grid** |
| VehicleSpawns / CivilianSpawns | 6 / 6 | 0 | plaza and highway ends / plaza |

### Road layout
- A 4×4 grid of lines at x/z = −300, −100, 100, 300.
- 4 east–west roads, each 636×36.
- 12 north–south segments, each 36×164.
- 2 connectors (x = ±100, 36×174) north to a 1,400×56 highway at z = −520, with 120×120 end plazas behind walls.
- The east–west roads overhang the outer north–south roads by 18 studs at each end (x ±300 → ±318), leaving short stubs at the map edge.
- There are no other dead ends; every block is reachable.

### Buildings
- 24 plain boxes, all `SmoothPlastic`.
- 24 distinct sizes.
- Only 5 muted colours: (120,110,100)×6, (150,130,105)×6, (175,170,160)×2, (105,85,80)×7, (90,100,115)×3.
- No windows, roofs or detail. Blocks don't differ in style, so **there are no districts**.

### World signs
Only two: `"24/7 MART"` on `City.Store.StoreSign` and `"OUTLAW MOTORS"` on `City.Dealership.DealerSign`. Batch P2 added floating markers for these two.

### Other observations
- **No police station building.** The jail (cells) sits north of the grid with no road; players only arrive there by being jailed.
- **Street detail:**
  - flat 0.6-stud sidewalk slabs, whose edge works as a curb;
  - yellow centre lines between intersections only;
  - no stop lines, crosswalks, street-name signs, streetlights or traffic signals.
- **Ground outside the city:** the template `Baseplate` (2048×2048, Plastic, "Dark grey metallic", with the template grid `Texture` `rbxassetid://6372755229`). The checkerboard is visible all around the city and in the highway screenshot from the Batch 1 closeout.
- **Clipping:**
  - `Buildings.Building_3_3_1` (X 138.5..179.5, Z 133..185, height 46) runs **0.5 stud into OUTLAW MOTORS**: overlap 0.5×18 with `DealerWallWest`, 0.5×19 with `DealerRoof`, 0.5×1 with `DealerWallBack`.
  - No other building overlaps a building, road, store or dealership.
- **Floating objects:** none found. The parts with nothing directly beneath them are roofs and headers resting on walls, signs, jail slot markers, and the display car on its wheels.
- **Driving sightlines:** buildings stand on the sidewalk blocks about 19 studs back from road edges, so corners are open. The plaza is flush with the roads.

## 2. Proposals
Each lists the exact object, its current state, the change, the benefit, the risk to driving and robbery, the part and performance impact, difficulty, and test and rollback.

### N1. District look for the existing 24 buildings (no new parts)
- **Object:** `City.Buildings.*`, colour and material choice in `CityLayout` (`BUILDING_COLORS`, the building loop).
- **Now:** all SmoothPlastic in 5 muted colours, assigned at random, so the city reads as one grey mass.
- **Change:** colour and material by grid column, giving three districts without moving or resizing anything. Only built-in Roblox materials, no textures or assets.
  - **West, "Old Town"** (around the 24/7 MART): brick reds and browns, `Brick`.
  - **Centre, "Civic"** (around the plaza): light stone, `Concrete`.
  - **East, "Downtown"** (around OUTLAW MOTORS): blue-grey and steel, `Slate`.
- **Benefit:** players can tell where they are ("the red part of town is where the store is"), and the store and dealership sit in districts that look different.
- **Risk:** none to driving or robbery. Same sizes, positions and collisions.
- **Parts and performance:** 0 new parts. Built-in materials are cheap on phones. Glass and transparency are avoided.
- **Difficulty:** S. Data in `CityLayout`, applied to the existing parts in the edit place.
- **Test:** `CityLayout.spec` passes. Views from the plaza, store, dealership and highway on PC and in the phone view. Building count, sizes and positions unchanged (hash of positions and sizes before vs after).
- **Rollback:** restore `BUILDING_COLORS` and the material in `CityLayout`, and re-apply to the parts. The backup holds the old values.

### N2. Plain ground around the city (no new parts)
- **Object:** `Workspace.Baseplate` (template) and its child `Texture` (`rbxassetid://6372755229`).
- **Now:** the Roblox template grid checkerboard surrounds the city and the highway.
- **Change:**
  - Remove (or set fully transparent) the template grid texture.
  - Set the Baseplate to a plain dark ground colour with a built-in material (for example `Ground` or `Concrete`).
  - Size, position and collision unchanged.
- **Benefit:** the city stops looking like a template, and the roads and highway contrast with plain ground.
- **Risk:** none. Same collision surface; the roads sit on top.
- **Parts and performance:** 0 parts. One fewer texture.
- **Difficulty:** S.
- **Test:** the highway and city-edge views; driving off-road on the baseplate behaves the same; vehicle validation still shows 0 observations.
- **Rollback:** restore the texture ID and colour/material, recorded in the evidence.

### N3. Remove the dealership clipping (no new parts)
- **Object:** `City.Buildings.Building_3_3_1` (generated in `CityLayout`).
- **Now:** it overlaps OUTLAW MOTORS by 0.5 stud along an 18–19 stud stretch of the west wall and roof.
- **Change:** in `CityLayout`, shrink that one building's east edge by about 2 studs (or exclude the dealership footprint when placing buildings), so there is a gap of at least 1 stud. The dealership itself is unchanged.
- **Benefit:** removes the wall and roof overlap next to the main shop.
- **Risk:** none. The building is off-road, and the dealership desk and prompt are untouched.
- **Parts and performance:** 0.
- **Difficulty:** S.
- **Test:** a new `CityLayout.spec` check that no building overlaps the dealership or store footprint; the dealership window and purchase flow still work (`AlreadyOwned`/`TooFar` checks).
- **Rollback:** revert the `CityLayout` change.

### N4. Street-name signs at the 16 grid intersections (small new parts)
- **Object:** new `City.StreetSigns` (data in `CityLayout`, built by `CityBuilder`), placed on sidewalk corners.
- **Now:** no street names, so directions and markers can only say "store" or "dealership".
- **Change:** one thin post plus one sign plate per intersection. Each shows the two street names with a `SurfaceGui` (text, no images): for example east–west "1st St" to "4th St" and north–south "A Ave" to "D Ave". All `CanCollide = false`, `CanQuery = false`, `CastShadow = false`, on the sidewalk 2+ studs from the road edge.
- **Benefit:** players can navigate and talk about places ("the store is at A Ave & 2nd St"). Later hints can use the names.
- **Risk:** low. The parts don't collide or query, so they can't block cars, police routing or the robbery prompt. They must stay clear of the store and dealership entrances.
- **Parts and performance:** +32 static anchored parts and 16 small SurfaceGuis. Low.
- **Difficulty:** M (data, builder and spec).
- **Test:** a spec that signs sit on sidewalks and clear of roads; drive every intersection; check the police unit's path and stuck counts are unchanged in a chase; readability in the phone view.
- **Rollback:** remove `StreetSigns` from `CityLayout`; the builder skips it.

### N5. Intersection stop lines (same item as atmosphere P-E)
> **Superseded by `STREET_MARKINGS_SIGNS_PLAN.md`**, which details N5 (stop lines) and N4 (street-name signs).

- **Object:** `City.Markings` (new `StopLine_*` slabs).
- **Now:** centre lines stop at junctions; nothing marks the junction itself.
- **Change and details:** as in `CITY_ATMOSPHERE_AUDIO_AUDIT.md` P-E: up to 64 non-colliding, non-shadow slabs on the existing roads.
- **Benefit:** junctions are visible at speed.
- **Risk:** none (no collision or queries).
- **Parts and performance:** up to +64.
- **Difficulty:** S–M.
- **Test and rollback:** as P-E.
- **Note:** listed here for navigation, but it should be approved once, under whichever batch the Architect prefers.

### Considered, not proposed
These are excluded because they would expand the map, add NPCs or systems, or cost too much on phones:
- streetlights across the map (each with a light: costly on phones);
- traffic signals (meaningless without traffic);
- a police station building or a road to the jail;
- props, trees and benches;
- windows or decals (would need textures or assets);
- new districts;
- moving roads.

## 3. Ranking: top five by player benefit, low risk and low cost
| Rank | Item | Player benefit | Risk | Cost |
|---|---|---|---|---|
| 1 | **N1** district look | High: the city gains identity, and destinations sit in recognisable areas | None | 0 parts, S |
| 2 | **N2** plain ground | Medium–High: the template look disappears everywhere | None | 0 parts, S |
| 3 | **N4** street-name signs | High for navigation and directions | Low (non-colliding) | +32 parts, M |
| 4 | **N5** stop lines | Medium: junctions are readable at speed | None | up to +64 parts, S–M |
| 5 | **N3** dealership clipping fix | Low–Medium: a visible flaw next to the main shop | None | 0 parts, S |

## 4. Proposed Batch 1 (small, reviewable on its own)
**Batch 1 = N1 + N2 + N3.** All three change existing properties or data only: **0 new parts, no new collisions, no assets.**

**Before starting:** the owner saves a backup (`OutlawCity_World1.rbxl`, checked in the Studio log). I record the current building colours and materials, the Baseplate properties and the `Building_3_3_1` size.

**Acceptance criteria:**
1. **Districts:** the 24 buildings keep their exact sizes and positions (checked by a position/size hash before and after), the part count stays 266, and the CanCollide count stays 114. West, centre and east columns use the agreed palettes and built-in materials. No Glass, no transparency, no textures.
2. **Ground:** the Baseplate has no template texture and uses the plain ground look. Its size, position and CanCollide are unchanged, and driving off-road still works.
3. **Clipping:** `Building_3_3_1` no longer overlaps any dealership part (gap at least 1 stud), and a new `CityLayout.spec` check passes that no building overlaps the store or dealership footprints.
4. **Unchanged gameplay:** `[Tests] N passed, 0 failed`. Robbery (prompt, holdout, dispatch, bust or escape), dealership (window, `AlreadyOwned`), car spawn and driving, jail, and cash reload all behave as before. One police unit; vehicle validation monitor-only.
5. **Visual review:** before and after captures from the plaza, store, dealership and highway. The HUD, markers and signs stay readable.
6. **Performance:** idle and pursuit FPS with Studio in front, 3 runs before and after, plus memory. A phone stays NOT TESTED unless actually tested.
7. **Rollback:** the old values are recorded, and one revert of the `CityLayout` and Baseplate changes restores the original look exactly.

**Later (separate approval):** N4 street signs, then N5 stop lines.
