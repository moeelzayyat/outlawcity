# Test evidence: 2026-10-16_n4-one-sign

- **Studio instance used:** `Outlaw City (placeId: 132163592957463)` (Studio process 5692). Every Edit script asserted `game.PlaceId`. The Lighthouse Keepers Studio was open and never touched.
- **Backup:** Studio log `2026-10-16T10:30:48.476Z Place file downloaded to 'G:\Roblox\Outlaw City\backups\OutlawCity_Sign1.rbxl'`. No Studio change was made before this.
- **Machine:** PC, Play viewport 2004 × 935, quality Automatic, Batch 1 atmosphere lighting. During the FPS runs a bounded helper kept the Studio window in front.

## 1. Baseline (read only)
```
scripts: CityLayout 0325d9e6 CityBuilder c67028a2 WorldService 6b73b6ac CityLayout.spec 6d2a827f
BaseParts 316 CanCollide 114 SurfaceGuis 2; StreetSigns folder false
City hash (non-stop-line) 6527bae1 (263 parts); stop-line signature f958ecfa (50)
```

## 2. Sources pushed to Studio (old hash asserted before, new after)
| Script | Old | New |
|---|---|---|
| CityLayout | `0325d9e6` | `77667b94` |
| CityBuilder | `c67028a2` | `3c5c8451` |
| WorldService | `6b73b6ac` | `a91b95db` |
| CityLayout.spec | `6d2a827f` | `01ab8c5f` |

Studio matches `src/` at `2354a92` for all four.

## 3. Sign created once (through `CityBuilder.buildStreetSigns`, called twice)
```
signs 1 (StreetSign_100_100); BaseParts 319 CanCollide 114 SurfaceGuis 6 (was 2); City hash excl. signs 6527bae1 (263); stop-line sig f958ecfa
```
**Result:** 1 model, +3 BaseParts, +4 SurfaceGuis. 316 → 319 parts; colliding stays 114. City hash `6527bae1` and stop-line signature `f958ecfa` unchanged. The 186-part signature `8b66ade9` passes (spec).

## 4. Properties read from the place (exact output)
```
Model StreetSign_100_100 class Model ModelStreamingMode Enum.ModelStreamingMode.Atomic PrimaryPart Post children 3; StreetSigns children 1
Post Part pos (122.00, 5.80, 122.00) size (0.40, 10.40, 0.40) rot (-0,0,0) bottom 0.60 top 11.00 | Anchored true CanCollide false CanQuery false CanTouch false CastShadow false | SmoothPlastic rgb 110,110,110 transp 0.0
   footprint fully on Block_3_3 (top 0.60); nearest road edge 3.80; nearest marking 4.84 (StopLine_100_100_S); nearest building/store/dealership/pad 19.55 (Workspace.City.Buildings.Building_3_3_1)
Blade_EW Part pos (122.00, 8.60, 122.00) size (7.00, 1.50, 0.20) rot (-0,0,0) bottom 7.85 top 9.35 | Anchored true CanCollide false CanQuery false CanTouch false CastShadow false | SmoothPlastic rgb 0,102,51 transp 0.0
   footprint fully on Block_3_3 (top 0.60); nearest road edge 0.50; nearest marking 1.66 (StopLine_100_100_S); nearest building/store/dealership/pad 16.96 (Workspace.City.Buildings.Building_3_3_1)
   Label_Front Face Front SizingMode PixelsPerStud PPS 50 LightInfluence 0.0 AlwaysOnTop false MaxDistance 150 | label '3rd St' font GothamBold scaled true rgb 255,255,255 bgT 1 size {0.92,0},{0.84,0} pos {0.04,0},{0.08,0}
   Label_Back Face Back (same properties) | label '3rd St'
Blade_NS Part pos (122.00, 10.20, 122.00) size (0.20, 1.50, 7.00) rot (-0,0,0) bottom 9.45 top 10.95 | Anchored true CanCollide false CanQuery false CanTouch false CastShadow false | SmoothPlastic rgb 0,102,51 transp 0.0
   footprint fully on Block_3_3 (top 0.60); nearest road edge 0.50; nearest marking 4.90 (StopLine_100_100_S); nearest building/store/dealership/pad 18.03 (Workspace.City.Buildings.Building_3_3_1)
   Label_Right Face Right (same properties) | label 'C Ave'
   Label_Left Face Left (same properties) | label 'C Ave'
model descendants 11, scripts 0
```
- **Orientation:** identity rotation. Each blade is long along the street it names: `Blade_EW` is 7 along X and faces ±Z; `Blade_NS` is 7 along Z and faces ±X.
- **Footprints** (full rectangles, not centres): all three are fully on `Block_3_3` and overlap no road or marking. Post face 3.80 from the road edge; blade edges 0.50 (corrections 1 and 2).
- **Client** (Play, player at the plaza): `sign true, parts 3, SurfaceGuis 4, ModelStreamingMode Enum.ModelStreamingMode.Atomic; StreamingEnabled true; viewport 2004x935`.

## 5. Automated tests
| Run | Result |
|---|---|
| After the change | `[Tests] 214 passed, 0 failed` (211 + 3 new street-sign specs) |
| Rollback state | `[Tests] 211 passed, 0 failed` |
| After restore | `[Tests] 214 passed, 0 failed` |

**New specs:**
- exactly one sign, 3 parts, 4 labels;
- sizes, heights, orientation and the names "3rd St" / "C Ave";
- every part's full footprint fully on one sidewalk, overlapping no road, highway, plaza or marking (stop lines included);
- at least 3 studs from buildings, store and dealership parts, and at least 12 from vehicle pad centres;
- nearest road edge exactly 3.8 (post) and 0.5 (blades).

## 6. Duplicate check (server, Play)
```
server after WorldService.init: StreetSigns children 1 (StreetSign_100_100)
fresh rebuild + buildStreetSigns x3: StreetSigns children 1, sign parts 3
```
- **Reload:** WorldService calls `buildStreetSigns` on every server start; it found the sign and added nothing.
- **Rebuild:** a complete fresh city was built into a scratch folder (`CityBuilder.build`) and `buildStreetSigns` was called three times. Result: one sign. The scratch folder was deleted.

## 7. Query and touch (no unintended interaction)
```
Post->Workspace.City.Sidewalks.Block_3_3; Post GetPartsInPart 0; Blade_EW->Workspace.City.Sidewalks.Block_3_3; Blade_EW GetPartsInPart 0; Blade_NS->Workspace.City.Sidewalks.Block_3_3; Blade_NS GetPartsInPart 0
walk through post: reached (122.0, 126.9) in 0.7 s; Touched events 0
```
- **Raycasts:** a downward ray through each part hits the sidewalk, never the sign.
- **Walking:** the character walked straight through the post with 0 Touched events.

## 8. Driving past the sign (all four lanes)
Muscle, real `VehiclePhysics`, scripted full-throttle driver. Results are taken within ±10 studs of the sign's position along the road.
```
3rd St heading +X (lane z=108.8): frames 10, speed in 116.2 out 119.0, chassis Y 1.960..1.968 (range 0.008), max |vY| 1.42, closest approach to post 13.7 studs | plain road: frames 185, Y range 0.040, max |vY| 2.15
3rd St heading -X (lane z=91.2): frames 11, speed in 107.0 out 111.1, chassis Y 1.960..1.973 (range 0.013), max |vY| 1.64, closest approach to post 30.2 studs | plain road: frames 184, Y range 0.038, max |vY| 2.03
C Ave heading +Z (lane x=91.2): frames 10, speed in 116.2 out 118.9, chassis Y 1.958..1.977 (range 0.019), max |vY| 1.87, closest approach to post 30.3 studs | plain road: frames 183, Y range 0.041, max |vY| 2.31
C Ave heading -Z (lane x=108.8): frames 11, speed in 107.0 out 111.2, chassis Y 1.955..1.973 (range 0.018), max |vY| 1.74, closest approach to post 13.8 studs | plain road: frames 180, Y range 0.041, max |vY| 2.28
sign after drives: parts 3, still at (122.0, 122.0)
```
**Result:** no bump. Speed rises smoothly, and the height range near the sign (0.008–0.019) is within the plain-road range (0.038–0.041).

## 9. Readability (desktop)
- **Method:** 2 captures per view after the change. Capture "a" is often taken before the SurfaceGui text has drawn (the known first-capture warm-up); "b" is the one assessed.
- **Measured text height:** the height of the white glyph rows on each "b" capture, in px. This is a measurement; the plan's section 5 numbers were estimates only.

| View | Camera (eye y 5) → target | Straight-line distance | Blade read | Measured glyph height | Legible? |
|---|---|---|---|---|---|
| P1 from W | (92, 5, 108.8) → "C Ave" | 33 | C Ave face-on | 15 px | Yes, but the post hides part of the "A" ("C /ve") |
| P2 from W | (62, 5, 108.8) | 62 | C Ave | ~6 px (small) | Readable but small; post over the "A" |
| P3 from E | (152, 5, 91.2) | 43 | C Ave back face | 10 px | Yes ("C /ve"); "3rd St" oblique 11 px |
| P4 from E | (182, 5, 91.2) | 68 | C Ave back face | 5 px | Barely ("C Ave") |
| P5 from N | (91.2, 5, 92) → "3rd St" | 43 | 3rd St | 9 px | Yes ("3r\| St") |
| P6 from N | (91.2, 5, 62) | 68 | 3rd St | 7 px | Yes, small |
| P7 from S | (108.8, 5, 152) | 33 | 3rd St face-on | 15 px | Yes ("3r\| St") |
| P8 from S | (108.8, 5, 182) | 62 | 3rd St | 7 px | Yes, small |

**Defect found:** the 0.4 × 0.4 post runs through the centre of each 0.2-thick blade and sticks out 0.1 stud past both faces. It hides about 0.4 stud of text in the middle of every face. This is visible in every view and clearest in `after_A4_approach_fromS_*`, which shows "3r| St" and "C /ve" close up. The names stay recognisable, but one glyph is cut. The geometry was kept exactly as approved; a fix is proposed in AUDITOR_QUESTIONS.

**Approach views** (eye at the stop line, 12 studs before it, looking straight down the lane):
- **From W (A1):** "C Ave" readable on the far-right corner.
- **From N (A3):** "3rd St" readable on the far-left corner.
- **From S (A4):** the sign is very close at the right edge of the view.
- **From E (A2):** the sign is outside the field of view, because the corner is near-left of that driver. That route reads it from 30–60 studs back (P3/P4).

**Desktop result:** both names legible at about 30 studs and readable but small at about 60. The post-occlusion defect affects every view.

## 10. Phone-simulator readability: NOT TESTED
Device Simulator wasn't available to me (I can't toggle it from my tools), and no desktop screenshot is substituted. A real phone is NOT TESTED.

## 11. Gameplay regressions (with the sign)
```
cash 11400
robbery phase Holding
after holdout Escaping; stars 2
outcome after 60 s: jailed=false phase=Escaping cash 11400
spawn Muscle true nil seated Muscle_11752219158
buy Muscle at desk: false AlreadyOwned; cash 11400
pursuit 1: busted=true at 14.6 s; unit 412 studs away at first sight; closest 14; jailed=true; released; stars 0
pursuit 2: busted=true at 13.0 s; unit 256 studs away at first sight; closest 14; jailed=true; released; stars 0
```
**Server log:**
- `[Jail] Lighthouse8282 jailed for 12 s in slot 1`, `[Police] BUSTED Lighthouse8282 -> jail`, `[Jail] Lighthouse8282 released`, twice.
- 8 dispatches, one from node `G_100_100` (the sign's junction).
- Police despawn lines show `hardRecoveries=0`. The one `softRecoveries=1` is the robbery chase's storefront stall (known, PROGRESS 8g); that chase didn't end in a bust within 60 s.
- `[VehicleValidation] observation Teleport … moved 118 / 109 / 89 studs in 0.22 s` and 1 `ALERT [monitor-only, no action taken]`. These come from the drive test placing the car at the four lane starts (`PivotTo`), not from the sign.
- No console errors.

## 12. FPS and memory (desktop)
- **Idle:** player at (91.2, 4, 50), camera held at (91.2, 5, 62) looking at the sign.
- **Pursuit:** on foot at (−60, 4, −100), dev `SetStars 2`.
- **Samples:** 8 s idle, 6 s pursuit. The guard waits for 55+ fps first; no waits were needed.

| | Before (no sign) | After, set 1 | After, set 2 (repeat) |
|---|---|---|---|
| Idle 1 | 60.0 fps, worst 18.2 ms, 2950 MB | **57.8 fps, worst 67.3 ms**, 2984 MB | 60.0, 18.6 ms, 2986 MB |
| Idle 2 | 60.0, 18.1 ms, 2949 MB | 60.0, 18.7 ms, 2984 MB | 60.0, 18.6 ms, 2986 MB |
| Idle 3 | 60.0, 19.1 ms, 2951 MB | 60.0, 18.4 ms, 2984 MB | 60.0, 18.8 ms, 2986 MB |
| Pursuit 1 | 60.0, 18.7 ms (unit 102) | 60.0, 18.3 ms (105) | 60.0, 18.5 ms (240) |
| Pursuit 2 | 60.0, 18.6 ms (245) | **50.7 fps, 69.6 ms** (182) | 60.0, 18.5 ms (102) |
| Pursuit 3 | 60.0, 18.6 ms (104) | 60.0, 19.8 ms (327) | 60.0, 18.2 ms (330) |

**FPS:**
- After set 1 had two single-frame hitches (67–70 ms). The identical repeat set was clean at 60 fps in all 6 runs.
- The hitches didn't recur and can't be attributed to 3 static parts. They are recorded, not hidden.

**Memory: inconclusive.**
- 2949–2954 MB before vs 2984–2988 MB after: +33 MB, in the same Studio session after more playtests.
- The N5 closeout showed 27–71 MB of session drift, so this isn't attributed to the sign.
- Process memory after the before set was 2,953 MB working set / 3,820 MB private.

## 13. Rollback
I removed the sign code from all four scripts (each asserted to give the exact pre-change hash) and unparented `City.StreetSigns`:
```
ROLLED BACK: scripts CityLayout 0325d9e6 CityBuilder c67028a2 WorldService 6b73b6ac spec 6d2a827f
BaseParts 316 CanCollide 114 SurfaceGuis 2; StreetSigns false
City hash 6527bae1 (263); stop-line sig f958ecfa (50)
```
Play: `[Tests] 211 passed, 0 failed`, no StreetSigns created (old WorldService).

Restored:
```
RESTORED: scripts 77667b94 3c5c8451 a91b95db 01ab8c5f; BaseParts 319 CanCollide 114 SurfaceGuis 6; signs 1; City hash 6527bae1; stop-line sig f958ecfa; sign signature ec8b4ca0 (3 parts)
```
Play: `[Tests] 214 passed, 0 failed`, 1 sign.

## Screenshots
Instance `Outlaw City (placeId: 132163592957463)`, Play, Batch 1 atmosphere lighting. All are in `screenshots/`.
- **Before:**
  - `before_P1_*_a/b` and `before_P2…P8_*_a`: the 8 planned views;
  - `before_A1…A4_approach_*_a`: the 4 approach views.
  - One capture per view (no SurfaceGui to warm up), except P1, which has two.
- **After:** `after_P1…P8_*_a/b` and `after_A1…A4_*_a/b`. These are the 8 planned views plus the 4 approach views, 2 captures each.
- **`after_readability_crops_P1-P8.png`:** 3× crops of the sign from each "b" capture, P1 at the top to P8 at the bottom.

## Not tested
- Phone-simulator readability and performance.
- A real phone.
- Other players seeing the sign (MULTIPLAYER UNVERIFIED).
- Human driving.
