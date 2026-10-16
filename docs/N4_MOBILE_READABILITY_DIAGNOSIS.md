# OUTLAW CITY: N4 mobile readability diagnosis (PLAN ONLY)

**Status:** PLAN AWAITING ARCHITECT REVIEW. No Studio, code, UI or sign changes.
- **Inputs:** the Device Simulator evidence (`docs/audits/2026-10-16_n4-sim-test/`), the HUD controller source, and one read-only Studio query (`docs/audits/2026-10-16_n4-mobile-diagnosis/TEST_EVIDENCE.md`).
- **Not tested:** real phone NOT TESTED; multiplayer MULTIPLAYER UNVERIFIED.

## 1. Who owns the cash badge, and where it sits
- **Owner:** `CashHudController` (`StarterPlayerScripts/Client/Controllers/CashHudController.luau`) creates the ScreenGui `CashHud`, with a TextLabel `Cash`.
  - `AnchorPoint (1, 0)`, `Position UDim2.new(0.5, 164, 0, 58)`, `Size 108 × 26` px, `TextSize 15`.
  - It uses fixed pixel offsets from screen centre, so it is the same physical size on every screen and doesn't scale for phones.
- **The top-centre cluster (all fixed pixel offsets around the centre line):**
  - row 1 (y 8–52): Combat button 160 × 44 at centre − 84, and Spawn Car 160 × 44 at centre + 84;
  - row 2 (y 58–92): SafeZone badge 108 × 26 (centre − 164 … − 56), wanted stars (centre, 34 px each), cash badge (centre + 56 … + 164);
  - below: the wanted banner at y 96 and the robbery panel at y 136 (compact on phones).
- **Measured on screen from the simulator captures:**

  | Device | Viewport | Cash badge |
  |---|---|---|
  | iPhone 7 | 666 × 374 | x 389–497, y 118–142 |
  | iPhone 13 Pro Max | 831 × 427 | x 467–563, y 106–127 |

  The y values include the Roblox top-bar inset.
- **Why it matters:** on phones this row lands roughly 30–38% down the screen, the same band where a road sign appears in the chase camera (screen y ≈ 140–180).

## 2. Would moving or shrinking the cash badge conflict with other HUD?
**Yes, every option conflicts with something:**
- **Left or right along row 2:** the badge sits beside the wanted stars and mirrors the SafeZone badge. Moving it outward still leaves it in the same horizontal band, so it doesn't fix the overlap.
- **Up into row 1:** collides with the Spawn Car button.
- **Down:** collides with the wanted banner (y 96) and the compact robbery panel (y 136).
- **Bottom-right:** occupied by the touch driving controls (GAS / BRAKE / DRIFT / EXIT up to about 172 px from the bottom).
- **Top-right corner:** used by Roblox core UI.
- **Shrinking (e.g. 80 × 20, TextSize 12):** saves about 28 px of width but still sits in the sign band.

Any HUD change also affects every device and every player state (wanted, robbery, safe zone). That is a larger UI change with its own regression surface. **Not recommended as the first correction.**

## 3. How much larger the lettering must be
**Readability threshold, from the simulator evidence:**
- cap height ≥ 12 px: clearly readable;
- about 7 px: "just readable";
- ≤ 6 px: unreadable.

**Target:** at least 8 px at the worst 30-stud view, where the blade is 55–63 studs away.

**Current worst case:**
- iPhone 7: 4.3 px at 63 studs, 4.9 px at 55;
- 13 Pro Max: 4.9 px and 5.6 px.

Reaching 8 px on iPhone 7 needs **about 1.9× the letter height**; 2× gives margin. Letter height scales with blade height (TextScaled, with 84% of the blade height used for text).

| Blade | Letter height | iPhone 7 at 63 / 55 studs | 13 Pro Max at 63 / 55 studs |
|---|---|---|---|
| 7 × 1.5 (now) | 1.0× | 4.3 / 4.9 px | 4.9 / 5.6 px |
| 10 × 2.4 | 1.6× | 6.9 / 7.8 px | 7.8 / 9.0 px |
| **12 × 3** | **2.0×** | **8.6 / 9.8 px** | **9.8 / 11.2 px** |

**Blade length:** the blade must lengthen with its height, or the names would be width-limited and wouldn't grow. "2nd St" in GothamBold needs about 3.7 × the letter-band height in width, so a 3.0-tall blade (2.52 band) needs about 9.3 studs of text width, i.e. at least a 10.1-stud blade; 12 gives margin.

**60-stud views** (blade 84–89 studs away) would rise to about 6–7.4 px, which is borderline. It is recorded, not promised.

## 4. Would larger blades break clearances?
**No.** Read-only check on all 4 existing signs, keeping the cantilever rule (each blade starts at the post face and extends away from the junction):

| Blade | All blades fully on a sidewalk | Min road gap | Min marking gap | Min building / store / dealership gap |
|---|---|---|---|---|
| 7 × 1.5 (now) | yes | 3.90 | 5.00 | 10.90 |
| 10 × 2.4 | yes | 3.90 | 5.00 | 9.49 |
| **12 × 3** | **yes** | **3.90** | **5.00** | **8.99** |

The tightest case is `StreetSign_100_-100` next to Building_3_2_1, still well above the 3-stud minimum.

## 5. Does a bigger sign help in the normal chase camera?
**Yes, for the near-corner approach.** Projected with the game's chase camera: `VehicleCameraController` places the camera 20 studs behind and 6 up, looking 6 ahead.

| Approach | Car distance from junction | Now (iPhone 7 / Pro Max) | 12 × 3 (iPhone 7 / Pro Max) |
|---|---|---|---|
| Near corner | 45 studs out | 6.4 / 7.3 px | 12.8 / 14.6 px |
| Near corner | 25 studs out | 11.9 / 13.5 px | 23.9 / 27.3 px |
| Far corner | 45 studs out | 3.1 / 3.6 px | 6.3 / 7.2 px |
| Far corner | 25 studs out | 4.1 / 4.7 px | 8.2 / 9.4 px |

- **Near corner:** at 45 studs it goes from unreadable to clear, and at 25 it is very clear.
- **Far corner:** it becomes readable at about 25 studs, but stays marginal at 45.
- **HUD overlap:** the projected text sits 0–10 px below the cash badge's lower edge. In the iPhone 7 capture it touched the badge, because the real camera eases its position. A taller blade extends upward by about 7 px, so partial overlap with the badge can remain at some distances. Because the text is larger, the uncovered part still carries the name.

## 6. Recommendation (one correction, lowest risk)
**Enlarge the blades of the four existing signs to 12 × 3 × 0.2**, keeping the cantilever rule and the existing text settings.
- **Why this is the lowest risk:** it is world geometry only. No HUD, no scripts, no gameplay. Only constants change in `CityLayout`, plus a one-off replacement of the four models, which is the method already approved for the cantilever fix.

**Exact proposed values (`CityLayout`):**

| Constant | Now | Proposed |
|---|---|---|
| `STREET_SIGN_BLADE_LENGTH` | 7 | **12** |
| `STREET_SIGN_BLADE_HEIGHT` | 1.5 | **3** |
| `STREET_SIGN_BLADE_THICKNESS` | 0.2 | 0.2 (unchanged) |
| `STREET_SIGN_EW_Y` (blade centre) | 8.6 | **9.1** (blade 7.6–10.6) |
| `STREET_SIGN_NS_Y` | 10.2 | **12.2** (blade 10.7–13.7; 0.1 gap above EW) |
| `STREET_SIGN_POST` | 0.4 × 10.4 × 0.4 | **0.4 × 13.1 × 0.4** (0.6 → 13.7) |

- **Lowest blade edge:** 7.0 studs above the sidewalk; characters are about 5.
- **Unchanged:** text font, PPS 50, LightInfluence 0, MaxDistance 150, TextScaled with 92% × 84% label; names; positions of the posts; Atomic streaming; all collision, query, touch and shadow flags off.
- **Counts unchanged:** 4 signs, 328 BaseParts, 114 colliding, 16 sign GUIs.

**Steps (if approved):**
1. Owner backup.
2. Change the constants, and update the spec's size, height and post assertions (footprint and cantilever tests already loop over every sign).
3. Replace the four models in Studio: unparent each old model (kept for rollback), call `buildStreetSigns`, verify against the spec.
4. Tests.

**Acceptance (measured):**
1. **Geometry:** all blades fully on sidewalks; road ≥ 3.9; markings ≥ 5.0; buildings ≥ 3 (expected 8.99); no shared volume; City, stop-line and building signatures unchanged; 328 / 114 / 16; all tests pass; one of each sign after a restart and a rebuild.
2. **Device Simulator** (iPhone 7 and 13 Pro Max, landscape; the owner switches it on), using the same 16 positions as the simulator test:
   - projected cap height ≥ 8 px at every 30-stud position on both devices;
   - all names legible in the captures, with no letter clipped by the post;
   - 60-stud results recorded.
3. **Chase camera** (C Ave toward (100, −100) and toward (100, 100), car 45 and 25 studs out):
   - near corner legible at 45 and 25;
   - far corner legible at 25;
   - any cash-badge overlap recorded, and the name still legible.
4. **Desktop:** the 8 reading views of the prototype are still legible, and the blades don't block other signs or prompts.
5. **Regressions:** drives past all signs (no bump), walk-throughs (no touch), police/jail/robbery/vehicle/dealership, FPS 3 + 3.

**Before/after positions:** as in `docs/audits/2026-10-16_n4-sim-test/` (16 views per device plus the chase positions above). Only the after-set needs capturing; the before-set exists.

**Rollback:**
- Restore the five constants and the spec, and put the four old models back (kept unparented during the session; otherwise rebuilt from the restored constants).
- Must return exactly to the Stage A signatures: prototype `87d79268`, Stage A `18eef2d0`, 328 / 114, and 216 tests.

**Residual risks:**
- Larger boards are more visually prominent.
- Far-corner reading at 45+ studs stays marginal on phones.
- Some cash-badge overlap may remain; a HUD change would be a separate approval.
- Real phone NOT TESTED.

## 7. Not done
No changes of any kind. No new signs, corners, stages or renaming.
