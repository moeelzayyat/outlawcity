# Auditor report: 2026-10-16_n4-sign-cantilever

- Project: OUTLAW CITY (Roblox, place ID 132163592957463)
- Date: 2026-10-16
- Commit range: `b8c27cf..` the package commit (code and docs `bb7cb55`); GitHub `moeelzayyat/outlawcity`, branch `main`
- Prepared by: Claude (sole implementation agent)
- Status: **APPROVED by the Architect (2026-10-16, reviewed `dc32b76`).** Full N4 rollout not authorized. Originally: the fix to the one sign is done (solo) and awaiting audit. **No other signs.**

## 1. What was asked
Correct only `City.StreetSigns.StreetSign_100_100` with option B, cantilevered blades, so both faces are unobstructed.

**Keep:**
- the post (position, height, properties);
- exactly two blades and four SurfaceGuis;
- "3rd St" / "C Ave";
- Atomic streaming;
- the materials, text size and blade size.

**Process:**
- Calculate the blade centres and full 3-D footprints and check clearances **before** editing.
- STOP and propose other geometry if it leaves the sidewalk or obstructs anything.
- Update `streetSigns()` and the tests.
- Back up the place.
- Replace only this sign in Studio (the builder skips existing models); no migration system.
- Verify that Studio matches the spec and that one sign remains after a restart and repeated builder calls.

**Evidence:** counts and hashes; no occlusion; footprints; the same 8 + 4 views; rendered legibility at about 30 and 60 studs; 3 + 3 FPS and memory runs; no collision, touch or query; tests and regressions; exact rollback to the previous sign.

## 2. What was built
- **`CityLayout.streetSigns()`:** each blade's centre is offset from the post by half the post plus half the blade (0.2 + 3.5 = 3.7 studs), away from the junction (the sign of the corner offset). This gives `Blade_EW` at (125.7, 8.6, 122) and `Blade_NS` at (122, 10.2, 125.7). The post, sizes, heights, labels and colours are unchanged.
- **`CityLayout.spec`:**
  - the blades' road-edge distance is now 3.9 (was 0.5);
  - a new test checks no shared volume (post/blades, blade/blade), that each blade starts at the post's outer face, and the exact centres.
- **Studio:** only `StreetSign_100_100` was replaced. The old model was unparented and kept for the rollback test, then destroyed after restore. `buildStreetSigns` built the new one. `CityBuilder` and `WorldService` are unchanged.

## 3. How it works
See `docs/ARCHITECTURE.md`, "Street-name signs" (cantilevered blades; changing an existing sign).

## 4. Security and authority
Not affected. No remotes, police, pursuit (130 / 100 / 0.25 / 8), vehicle physics, robbery, economy, dealership, jail or anti-cheat changes. No assets.

## 5. Persistence and data safety
None.

## 6. Decisions made
- **Blades extend away from the junction** (+X and +Z from a +X/+Z corner), over the sidewalk. Towards the junction they would overhang the road.
- **Clearance:** the blades moved from 0.5 to 3.9 studs from the road edge. The nearest building is still 14.33 studs away. The stop condition wasn't triggered.
- **Replacement mechanism:** a one-off Edit script: unparent the old model, call the existing builder, verify against the spec. No general migration code, as instructed.

## 7. Results summary
- 1 sign: 3 parts, 4 SurfaceGuis, Atomic; 319 / 114; all old hashes unchanged; sign signature `ec8b4ca0` → `87d79268`; 215/215 tests.
- **No letter hidden on any face from any of the 8 reading views.** Legibility is otherwise the same: about 30 studs legible, about 60 small.
- Footprints fully on the sidewalk: post 3.80 and blades 3.90 from the road; nearest marking 4.84; 0 shared volume.
- One sign after a restart, two extra builder calls and a fresh rebuild.
- No bump in all 4 lanes; 0 touches; rays pass through.
- Regressions normal.
- 60 fps in all 12 FPS runs. Memory not comparable (same long session).
- Exact rollback to the previous sign and its 214-test state.

## 8. Risks and limitations
- **South approach (A4):** at the stop line, the "3rd St" blade now extends out of frame to the right. It reads earlier, from 30–60 studs back. East approach (A2): out of view at the stop line, as before.
- **Small text at about 60 studs** (5–7 px on desktop); phone very likely unreadable at 60 (not tested).
- **Phone simulator** NOT TESTED; real phone NOT TESTED; MULTIPLAYER UNVERIFIED.
- **Memory:** inconclusive.

## 9. Not done (by instruction)
- The other 15 signs.
- Connector–highway signs.
- Any new markings, streets, buildings or gameplay.
- Text or blade size changes.
