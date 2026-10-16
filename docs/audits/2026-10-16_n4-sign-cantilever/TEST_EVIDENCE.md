# Test evidence: 2026-10-16_n4-sign-cantilever

- **Studio instance used:** `Outlaw City (placeId: 132163592957463)` (Studio process 5692). Every Edit script asserted `game.PlaceId`. The Lighthouse Keepers Studio was open and never touched.
- **Backup:** Studio log `2026-10-16T10:55:01.835Z Place file downloaded to 'G:\Roblox\Outlaw City\backups\OutlawCity_Sign2.rbxl'`. The place was not changed before this.
- **Machine:** PC, Play viewport 2004 × 935, quality Automatic, Batch 1 atmosphere lighting. A bounded helper kept Studio in front during the FPS runs.

## 1. Geometry calculated and checked before editing (read only)
Proposed cantilever: each blade's inner end touches the post face on the side away from the junction (the sign is on the junction's +X/+Z corner).

| Part | Centre | Full box (x / y / z) |
|---|---|---|
| Post (unchanged) | (122, 5.8, 122) | 121.8..122.2 / 0.6..11.0 / 121.8..122.2 |
| Blade_EW "3rd St" | (125.7, 8.6, 122) | 122.2..129.2 / 7.85..9.35 / 121.9..122.1 |
| Blade_NS "C Ave" | (122, 10.2, 125.7) | 121.9..122.1 / 9.45..10.95 / 122.2..129.2 |

Exact output of the clearance query against every City part:
```
Post x 121.8..122.2 y 0.60..11.00 z 121.8..122.2 | on Block_3_3 | nearest: Roads 3.80 (RoadEW_100); Markings 4.84 (StopLine_100_100_S); Buildings 19.55 (Building_3_3_1); Dealership 56.80 (DealerWallWest); VehicleSpawns 103.82 (PlazaSE); CivilianSpawns 129.09; Plaza 56.29
Blade_EW x 122.2..129.2 y 7.85..9.35 z 121.9..122.1 | on Block_3_3 | nearest: Roads 3.90 (RoadEW_100); Markings 5.25 (StopLine_100_100_S); Buildings 14.33 (Building_3_3_1); Dealership 49.80; VehicleSpawns 104.18; Plaza 56.64
Blade_NS x 121.9..122.1 y 9.45..10.95 z 122.2..129.2 | on Block_3_3 | nearest: Roads 3.90 (RoadNS_100_3); Markings 5.00 (StopLine_100_100_S); Buildings 16.83 (Building_3_3_1); Dealership 56.90; VehicleSpawns 104.16; Plaza 56.64
shared volume with post: Blade_EW 0.0000, Blade_NS 0.0000; blade-blade 0.0000
```
- **Result:** everything stays fully over the sidewalk, away from the road, with no new obstruction. The stop condition (leaving the sidewalk or blocking something) wasn't triggered, so I went ahead.
- **Clearance change:** the blades are now 3.9 studs from the road edge (were 0.5) and still 14+ studs from the nearest building.
- **Scan note:** the scan also reported `Workspace.Terrain` as a 3-D overlap; that is the empty terrain object, not a part.

## 2. Sources pushed to Studio
| Script | Old | New |
|---|---|---|
| CityLayout | `77667b94` | `b5f21c41` |
| CityLayout.spec | `01ab8c5f` | `d00b3e6e` |
| CityBuilder | `3c5c8451` | unchanged |
| WorldService | `a91b95db` | unchanged |

## 3. Only `StreetSign_100_100` replaced in Studio
**Method:** the old model was unparented and kept for rollback. Then `CityBuilder.buildStreetSigns` (from fresh module clones) was called twice and built the new model from the new spec. Nothing else was touched; no migration system was added.
```
signs 1; BaseParts 319 CanCollide 114 SurfaceGuis 6; City hash 6527bae1 (263); stop-line sig f958ecfa; sign signature 87d79268 (was ec8b4ca0)
```

## 4. The place matches the committed spec (exact output)
```
Model StreetSign_100_100 ModelStreamingMode Enum.ModelStreamingMode.Atomic PrimaryPart Post children 3; StreetSigns children 1
Post pos (122.00, 5.80, 122.00) size (0.40, 10.40, 0.40) rot (0,0,0) box x 121.80..122.20 y 0.60..11.00 z 121.80..122.20 | matches spec true | Anchored true CanCollide false CanQuery false CanTouch false CastShadow false | SmoothPlastic rgb 110,110,110
   footprint fully on Block_3_3; nearest road edge 3.80; nearest marking 4.84 (StopLine_100_100_S); nearest other City part 19.55 (Building_3_3_1)
Blade_EW pos (125.70, 8.60, 122.00) size (7.00, 1.50, 0.20) rot (0,0,0) box x 122.20..129.20 y 7.85..9.35 z 121.90..122.10 | matches spec true | (same flags) | SmoothPlastic rgb 0,102,51
   footprint fully on Block_3_3; nearest road edge 3.90; nearest marking 5.25 (StopLine_100_100_S); nearest other City part 14.33 (Building_3_3_1)
   Label_Front / Label_Back: PPS 50 LightInfluence 0.0 MaxDistance 150 | '3rd St' GothamBold scaled true size {0.92,0},{0.84,0}
Blade_NS pos (122.00, 10.20, 125.70) size (0.20, 1.50, 7.00) rot (0,0,0) box x 121.90..122.10 y 9.45..10.95 z 122.20..129.20 | matches spec true | (same flags) | SmoothPlastic rgb 0,102,51
   footprint fully on Block_3_3; nearest road edge 3.90; nearest marking 5.00 (StopLine_100_100_S); nearest other City part 16.83 (Building_3_3_1)
   Label_Right / Label_Left: same | 'C Ave'
shared volume with post: Blade_EW 0.0000, Blade_NS 0.0000; between blades 0.0000
```
**Result:**
- 1 sign: 3 BaseParts, 4 SurfaceGuis, Atomic.
- 319 BaseParts, 114 colliding.
- City `6527bae1`, stop-line `f958ecfa` and 186-part `8b66ade9` (spec) unchanged.
- Text, blade sizes and materials unchanged.

## 5. Tests, restart and builder calls
```
PLAY (restart): [Tests] 215 passed, 0 failed
server after WorldService.init (restart): StreetSigns children 1; Blade_EW at (125.70, 122.00)
after 2 more buildStreetSigns calls on the live city: 1
fresh rebuild + buildStreetSigns x3: signs 1, parts 3, Blade_EW (125.70, 122.00), Blade_NS (122.00, 125.70) [live: EW (125.70, 122.00) NS (122.00, 125.70)]
Post->Block_3_3 inPart 0; Blade_EW->Block_3_3 inPart 0; Blade_NS->Block_3_3 inPart 0
```
- **New spec** (`street signs: blades are cantilevered off the post, so the post covers no text`):
  - no shared volume between post and blades, or between the blades;
  - each blade starts exactly at the post's +X / +Z face and stays within the post's depth or width;
  - the post position and the blade centres are checked.
- **Updated footprint spec:** blades 3.9 from the road edge.
- **Duplicate and query checks:** a fresh rebuild builds the same cantilever geometry. Rays pass through all three parts.

## 6. Readability (desktop), same 8 + 4 views
Two captures per view after the fix. Capture "a" can be taken before the text has drawn, so "b" is assessed.
- **Before:** the first prototype's "after" captures from audit `2026-10-16_n4-one-sign`.
- **Side by side:** `compare_before_vs_after_P1-P8.png` shows the old sign on the left and the fixed one on the right.

**Result: the post covers no letter on any of the four faces in any view.** "C Ave" and "3rd St" are complete everywhere.

Measured glyph-row heights on the "b" captures (rendered pixels, not estimates):

| View | Distance | Before | After | Note |
|---|---|---|---|---|
| P1 C Ave from W | 33 | 15 / 14 px, post over "A" | 14 px, clear | "3rd St" oblique |
| P2 C Ave from W | 62 | small, post over "A" | small, clear | Readable but small |
| P3 C Ave from E | 43 | 10 / 11 px, post over "A" | 8 / 12 px, clear | |
| P4 C Ave from E | 68 | 5 px | ~5 px, clear | Barely readable, as before |
| P5 3rd St from N | 43 | 9 / 9 px, post over "d" | 8 px, clear | |
| P6 3rd St from N | 68 | 7 px | ~6 px, clear | "C Ave" is edge-on from here |
| P7 3rd St from S | 33 | 12 / 15 px, post over "d" | 13 / 14 px, clear | |
| P8 3rd St from S | 62 | 7 px | 6 px, clear | |

**Approach views** (eye at the stop line, looking down the lane):
- **From W (A1):** "C Ave" readable on the far-right corner, clear of the post.
- **From N (A3):** "3rd St" readable on the far-left corner.
- **From S (A4):** the sign is at the near right edge. The "3rd St" blade now extends further right, so only the "3" is in frame at this distance; it reads earlier from 30–60 studs back (P7/P8).
- **From E (A2):** the sign is outside the field of view, as before (read from 30–60 studs back, P3/P4).

**Legibility:** the same as the first prototype (unchanged text and blade size): legible at about 30 studs, small at about 60. The difference is that no letter is cut.

**Phone simulator:** NOT TESTED (Device Simulator not available to me). A real phone is NOT TESTED.

## 7. Driving and touch
```
3rd St +X (z=108.8): near sign frames 12, speed in 116.5 out 119.7, chassis Y range 0.008, max |vY| 1.80, closest to a sign part centre 13.7 | plain road Y range 0.032
3rd St -X (z=91.2): near sign frames 13, speed in 105.7 out 110.8, chassis Y range 0.018, max |vY| 1.50, closest to a sign part centre 30.2 | plain road Y range 0.038
C Ave +Z (x=91.2): near sign frames 12, speed in 116.5 out 119.8, chassis Y range 0.013, max |vY| 1.58, closest to a sign part centre 30.3 | plain road Y range 0.045
C Ave -Z (x=108.8): near sign frames 13, speed in 105.7 out 110.9, chassis Y range 0.009, max |vY| 1.64, closest to a sign part centre 13.8 | plain road Y range 0.039
walks under/through the sign along both axes: end gaps 2.0 / 1.7 studs; Touched events 0
```
**Result:**
- No vehicle bump in any lane.
- Walking under both blades and through the post, along both axes, caused no touch event.

## 8. Gameplay regressions
```
pursuit 1: busted=true at 14.8 s; unit 312 studs away; jailed=true; released, stars 0
pursuit 2: busted=true at 10.5 s; unit 240 studs away; jailed=true; released, stars 0
robbery phase Holding
after holdout Escaping; stars 2   (then dev ResetWanted)
spawn Muscle true nil seated Muscle_11752219158
buy Muscle at desk: false AlreadyOwned; cash 11400
```
**Server log:**
- `[Jail] … jailed for 12 s`, `[Police] BUSTED … -> jail`, `despawn (busted) … softRecoveries=0 hardRecoveries=0`, `[Jail] … released`, twice.
- `[Robbery] … started … at Store1`, then `holdout complete; escaping`.
- 1 `[VehicleValidation] observation Teleport … moved 200 studs in 0.22 s` plus 1 `ALERT [monitor-only, no action taken]`, from the drive test placing the car.
- No console errors.

## 9. FPS and memory (desktop)
**Setup:** the same harness as the first prototype.
- **Idle:** camera held at (91.2, 5, 62) looking at the sign.
- **Pursuit:** on foot at (−60, −100), `SetStars 2`.

| | Before (first prototype sign) | After (cantilever) |
|---|---|---|
| Idle 1 | 60.0 fps, worst 18.2 ms, 3018 MB | 60.0, 18.5 ms, 3111 MB (1 s focus wait) |
| Idle 2 | 60.0, 18.8 ms, 3020 MB | 60.0, 18.4 ms, 3111 MB |
| Idle 3 | 60.0, 18.7 ms, 3021 MB | 60.0, 18.4 ms, 3111 MB |
| Pursuit 1 | 60.0, 18.4 ms (unit 130) | 60.0, 18.2 ms (344) |
| Pursuit 2 | 60.0, 18.3 ms (60) | 60.0, 18.5 ms (65) |
| Pursuit 3 | 60.0, 18.4 ms (221) | 60.0, 18.3 ms (330) |

- **FPS:** 60 in all 12 runs.
- **Memory:** inconclusive. The figures come from the same long Studio session, later and after more playtests; the part and GUI counts are identical. Not attributed.

## 10. Rollback to the previous one-sign geometry
```
ROLLED BACK: CityLayout 77667b94 spec 01ab8c5f CityBuilder 3c5c8451 WorldService a91b95db; signs 1; BaseParts 319 CanCollide 114 SurfaceGuis 6; City hash 6527bae1; stop-line sig f958ecfa; sign signature ec8b4ca0 (previous prototype ec8b4ca0)
Play: [Tests] 214 passed, 0 failed; signs 1; Blade_EW at (122.00, 122.00)
RESTORED: CityLayout b5f21c41 spec d00b3e6e; signs 1; BaseParts 319 CanCollide 114 SurfaceGuis 6; City hash 6527bae1; stop-line sig f958ecfa; sign signature 87d79268
Play: [Tests] 215 passed, 0 failed; signs 1; Blade_EW at (125.70, 122.00)
```
**Result:** exact. The scripts, the sign signature `ec8b4ca0` and the 214-test baseline all came back.

## Screenshots
Instance `Outlaw City (placeId: 132163592957463)`, Play, Batch 1 atmosphere lighting. All are in `screenshots/`.
- **`before_*_a/b`:** the first prototype (centred blades), the 8 reading and 4 approach views. These are the "after" captures of audit `2026-10-16_n4-one-sign`.
- **`after_*_a/b`:** the cantilever fix, the same 12 views, 2 captures each.
- **`compare_before_vs_after_P1-P8.png`:** 2× crops of the sign, before (left) and after (right), P1 at the top to P8 at the bottom.

## Not tested
- Phone-simulator readability and performance.
- A real phone.
- Other players seeing the sign (MULTIPLAYER UNVERIFIED).
- Human driving.
