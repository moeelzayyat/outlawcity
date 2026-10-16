# Test evidence: 2026-10-16_n4-stage-a

- **Studio instance used:** `Outlaw City (placeId: 132163592957463)` (Studio process 5692). Every Edit script asserted `game.PlaceId`. The Lighthouse Keepers Studio was open and never touched.
- **Backup:** Studio log `2026-10-16T13:29:50.625Z Place file downloaded to 'G:\Roblox\Outlaw Cityackups\OutlawCity_SignsA.rbxl'`. The place was not changed before this.
- **Machine:** PC, Play viewport 2004 × 935, quality Automatic, Batch 1 atmosphere lighting. A bounded helper kept Studio in front during the FPS runs.
- **Code:** only the three `STREET_SIGNS` entries and the spec changed. `CityBuilder` and `WorldService` are unchanged (no new scripts, networking or dependencies).

## Results summary
| Required check | Result |
|---|---|
| Exactly 4 signs including the prototype | **PASS** (4) |
| BaseParts 328, colliding 114, sign SurfaceGuis 16 | **PASS** |
| City `6527bae1`, stop lines `f958ecfa`, buildings `8b66ade9` (spec), prototype `87d79268` unchanged | **PASS** |
| Each new sign: 3 parts, 4 SurfaceGuis, Atomic, flags off | **PASS** |
| Full footprints, road and marking clearance, no post/blade intersection | **PASS** (post 3.80, blades 3.90, markings ≥ 4.84, shared volume 0) |
| Rendered views from every incoming approach at 30 and 60 | **PASS** (24 views) |
| Weak approach identified; name readable before the junction | **PASS** (W, E, W; readable at 60, edge-on at 30) |
| No letter hidden on any face | **PASS** |
| No bump, touch or query interaction | **PASS** |
| 3 + 3 FPS before and after, Studio in front | **PASS** (60.0 ×12). Memory INCONCLUSIVE (same long session) |
| Atomic completeness and duplicates across restart, builder calls and rebuild | **PASS** |
| Full suite and regressions | **PASS** (216/216; police, jail, robbery, vehicle, dealership) |
| Rollback to 319 / 114, prototype only, 215 tests | **PASS** |
| Phone simulator | **PHONE SIMULATOR NOT TESTED** (Device Simulator not available to me) |
| Real phone | NOT TESTED |
| Multiplayer | MULTIPLAYER UNVERIFIED |

## Exact outputs, in order
```
BASELINE: scripts CityLayout b5f21c41 spec d00b3e6e CityBuilder 3c5c8451 WorldService a91b95db; signs 1; BaseParts 319 CanCollide 114 sign SurfaceGuis 4; City 6527bae1; stop-line f958ecfa; prototype 87d79268
BEFORE FPS (1 sign; idle player (0,4,0) camera (0,40,0)->(-100,5,-100); pursuit on foot (-60,-100) SetStars 2; keep-foreground helper):
idle 1: 60.0 fps / worst 18.9 ms / 2983 MB
idle 2: 60.0 fps / worst 18.4 ms / 2982 MB
idle 3: 60.0 fps / worst 18.4 ms / 2982 MB
pursuit 1 (unit 335 studs at start): 60.0 fps / worst 19.0 ms / 2985 MB
pursuit 2 (unit 64 studs at start): 60.0 fps / worst 19.2 ms / 2987 MB
pursuit 3 (unit 69 studs at start): 60.0 fps / worst 18.8 ms / 2991 MB
PUSH: CityLayout b5f21c41->81f2c85a; spec d00b3e6e->0443bbeb; CityBuilder 3c5c8451, WorldService a91b95db unchanged
ADD (buildStreetSigns x2 from fresh clones): signs 4 (StreetSign_-100_-100, StreetSign_-100_100, StreetSign_100_-100, StreetSign_100_100); BaseParts 328 CanCollide 114 sign SurfaceGuis 16; City 6527bae1; stop-line f958ecfa; prototype 87d79268; Stage A signature 18eef2d0 (9 parts)
VERIFY (place vs spec):
== StreetSign_100_100 Atomic true PrimaryPart Post parts 3 SurfaceGuis 4 scripts 0
  Post pos (122.00,5.80,122.00) size (0.40,10.40,0.40) rot (0,0,0) box x 121.80..122.20 z 121.80..122.20 | spec true | Atrue Cfalse Qfalse Tfalse Sfalse SmoothPlastic 110,110,110 | on Block_3_3; road 3.80; marking 4.84 (StopLine_100_100_S); other 19.55 (Buildings.Building_3_3_1)
  Blade_EW pos (125.70,8.60,122.00) size (7.00,1.50,0.20) box x 122.20..129.20 z 121.90..122.10 | spec true | (flags same) | on Block_3_3; road 3.90; marking 5.25 (StopLine_100_100_S); other 14.33 (Buildings.Building_3_3_1) | Front/Back '3rd St' GothamBold PPS50 LI0 MD150
  Blade_NS pos (122.00,10.20,125.70) size (0.20,1.50,7.00) box x 121.90..122.10 z 122.20..129.20 | spec true | on Block_3_3; road 3.90; marking 5.00 (StopLine_100_100_S); other 16.83 | Right/Left 'C Ave'
  shared volume: EW/post 0.0000 NS/post 0.0000 EW/NS 0.0000
== StreetSign_-100_-100 Atomic true PrimaryPart Post parts 3 SurfaceGuis 4 scripts 0
  Post pos (-122.00,5.80,-122.00) size (0.40,10.40,0.40) rot (0,0,0) box x -122.20..-121.80 z -122.20..-121.80 | spec true | Atrue Cfalse Qfalse Tfalse Sfalse SmoothPlastic 110,110,110 | on Block_1_1; road 3.80; marking 4.84 (StopLine_-100_-100_N); other 19.88 (Buildings.Building_1_1_4)
  Blade_EW pos (-125.70,8.60,-122.00) size (7.00,1.50,0.20) box x -129.20..-122.20 z -122.10..-121.90 | spec true | on Block_1_1; road 3.90; marking 5.25 (StopLine_-100_-100_N); other 14.29 (Buildings.Building_1_1_4) | Front/Back '2nd St' GothamBold PPS50 LI0 MD150
  Blade_NS pos (-122.00,10.20,-125.70) size (0.20,1.50,7.00) box x -122.10..-121.90 z -129.20..-122.20 | spec true | on Block_1_1; road 3.90; marking 5.00 (StopLine_-100_-100_N); other 17.62 (Buildings.Building_1_1_4) | Right/Left 'B Ave'
  shared volume: EW/post 0.0000 NS/post 0.0000 EW/NS 0.0000
== StreetSign_100_-100 Atomic true PrimaryPart Post parts 3 SurfaceGuis 4 scripts 0
  Post pos (122.00,5.80,-78.00) size (0.40,10.40,0.40) rot (0,0,0) box x 121.80..122.20 z -78.20..-77.80 | spec true | Atrue Cfalse Qfalse Tfalse Sfalse SmoothPlastic 110,110,110 | on Block_3_2; road 3.80; marking 4.84 (StopLine_100_-100_S); other 15.95 (Buildings.Building_3_2_1)
  Blade_EW pos (125.70,8.60,-78.00) size (7.00,1.50,0.20) box x 122.20..129.20 z -78.10..-77.90 | spec true | on Block_3_2; road 3.90; marking 5.25 (StopLine_100_-100_S); other 10.90 (Buildings.Building_3_2_1) | Front/Back '2nd St'
  Blade_NS pos (122.00,10.20,-74.30) size (0.20,1.50,7.00) box x 121.90..122.10 z -77.80..-70.80 | spec true | on Block_3_2; road 3.90; marking 5.00 (StopLine_100_-100_S); other 13.52 (Buildings.Building_3_2_1) | Right/Left 'C Ave'
  shared volume: EW/post 0.0000 NS/post 0.0000 EW/NS 0.0000
== StreetSign_-100_100 Atomic true PrimaryPart Post parts 3 SurfaceGuis 4 scripts 0
  Post pos (-122.00,5.80,78.00) size (0.40,10.40,0.40) rot (0,0,0) box x -122.20..-121.80 z 77.80..78.20 | spec true | Atrue Cfalse Qfalse Tfalse Sfalse SmoothPlastic 110,110,110 | on Block_1_2; road 3.80; marking 4.84 (StopLine_-100_100_N); other 17.04 (Buildings.Building_1_2_4)
  Blade_EW pos (-125.70,8.60,78.00) size (7.00,1.50,0.20) box x -129.20..-122.20 z 77.90..78.10 | spec true | on Block_1_2; road 3.90; marking 5.25 (StopLine_-100_100_N); other 13.30 (Buildings.Building_1_2_4) | Front/Back '3rd St'
  Blade_NS pos (-122.00,10.20,74.30) size (0.20,1.50,7.00) box x -122.10..-121.90 z 70.80..77.80 | spec true | on Block_1_2; road 3.90; marking 5.00 (StopLine_-100_100_N); other 13.03 (Buildings.Building_1_2_4) | Right/Left 'B Ave'
  shared volume: EW/post 0.0000 NS/post 0.0000 EW/NS 0.0000
PLAY: [Tests] 216 passed, 0 failed
server after WorldService.init (restart): 4 signs: StreetSign_-100_-100(3) StreetSign_-100_100(3) StreetSign_100_-100(3) StreetSign_100_100(3)
after 2 more buildStreetSigns calls on the live city: 4
fresh rebuild + buildStreetSigns x3: 4 signs: StreetSign_-100_-100(3) StreetSign_-100_100(3) StreetSign_100_-100(3) StreetSign_100_100(3); identical to live: 4
StreetSign_100_100 ray/overlap hits on sign 0; StreetSign_-100_-100 ray/overlap hits on sign 0; StreetSign_100_-100 ray/overlap hits on sign 0; StreetSign_-100_100 ray/overlap hits on sign 0
CLIENT (player at plaza): client sees 4 signs
StreetSign_-100_-100: parts 3, SurfaceGuis 4, texts 2nd St/2nd St/B Ave/B Ave, Atomic true
StreetSign_-100_100: parts 3, SurfaceGuis 4, texts 3rd St/3rd St/B Ave/B Ave, Atomic true
StreetSign_100_-100: parts 3, SurfaceGuis 4, texts 2nd St/2nd St/C Ave/C Ave, Atomic true
StreetSign_100_100: parts 3, SurfaceGuis 4, texts 3rd St/3rd St/C Ave/C Ave, Atomic true
RENDERED VIEWS (driver eye y5 in incoming lane, 30 and 60 studs from junction centre, camera aimed at the cross-street blade; 2nd capture after SurfaceGui warm-up):
S1 (-100,-100) 2nd St/B Ave: N30 B Ave large + 2nd St readable; N60 both readable small; S30 2nd St + B Ave small readable; S60 small readable; W30 "2nd St" large, B Ave edge-on (WEAK); W60 B Ave + 2nd St readable small; E30 B Ave readable, 2nd St edge-on; E60 B Ave small readable.
S2 (100,-100) 2nd St/C Ave: N30 2nd St + C Ave small readable; N60 small readable; S30 C Ave large + 2nd St readable; S60 both readable; W30 C Ave readable; W60 C Ave small; E30 "2nd St" large, C Ave edge-on (WEAK); E60 C Ave + 2nd St readable small.
S3 (-100,100) 3rd St/B Ave: N30 B Ave large + 3rd St readable; N60 both readable; S30 3rd St + B Ave small; S60 small readable; W30 "3rd St" large, B Ave edge-on (WEAK); W60 B Ave + 3rd St readable; E30 B Ave readable; E60 B Ave small.
No letter hidden by the post in any view. Weak approaches (W, E, W) match the plan; at 60 studs the cross-street name is readable on all three weak approaches, i.e. before entering the intersection.
DRIVES (Muscle, real VehiclePhysics, full throttle, full-length runs along the four signed roads):
2nd St +X (z=-91.2): frames within 30 studs of a sign post 24 (signs StreetSign_100_-100), closest 13.8, chassis Y range 0.019, max |vY| 2.24 | elsewhere Y range 0.057
2nd St -X (z=-108.8): frames within 30 studs of a sign post 24 (signs StreetSign_-100_-100), closest 13.8, chassis Y range 0.022, max |vY| 2.01 | elsewhere Y range 0.047
B Ave +Z (x=-108.8): frames within 30 studs of a sign post 55 (signs StreetSign_-100_-100,StreetSign_-100_100), closest 13.8, chassis Y range 0.027, max |vY| 2.05 | elsewhere Y range 0.049
B Ave -Z (x=-91.2): frames within 30 studs of a sign post 0 (far lane: 30.8 studs from the posts, outside the 30-stud window) | elsewhere Y range 0.045
3rd St +X (z=108.8): frames within 30 studs of a sign post 24 (signs StreetSign_100_100), closest 13.8, chassis Y range 0.020, max |vY| 1.92 | elsewhere Y range 0.047
C Ave -Z (x=108.8): frames within 30 studs of a sign post 54 (signs StreetSign_100_-100,StreetSign_100_100), closest 13.8, chassis Y range 0.021, max |vY| 2.05 | elsewhere Y range 0.040
walks through all 4 posts (both axes): end gaps 1.4/2.0/2.0/1.7/1.9/1.4/1.7/1.4 studs; Touched events 0
REGRESSION:
pursuit 1: busted=true at 10.9 s; unit 240 studs away; jailed=true; released, stars 0
pursuit 2: busted=true at 12.8 s; unit 360 studs away; jailed=true; released, stars 0
robbery phase Holding
after holdout Escaping; stars 2   (then dev ResetWanted)
spawn Muscle true nil seated Muscle_11752219158
buy Muscle at desk: false AlreadyOwned; cash 11400
SERVER LOG: [Jail] jailed for 12 s / [Police] BUSTED -> jail / despawn (busted) softRecoveries=0 hardRecoveries=0 / [Jail] released (x2); [Robbery] started d1147082-... at Store1 / holdout complete; escaping; police despawn soft 0 hard 0
[VehicleValidation] observation Teleport ... moved 329 / 125 / 387 / 202 studs in 0.22 s (the drive test's PivotTo to six start positions); 3 ALERT [monitor-only, no action taken]; no console errors
AFTER FPS (4 signs; same harness):
idle 1: 60.0 fps / worst 19.2 ms / 3125 MB
idle 2: 60.0 fps / worst 18.3 ms / 3126 MB
idle 3: 60.0 fps / worst 18.4 ms / 3126 MB
pursuit 1 (unit 114 studs at start): 60.0 fps / worst 19.1 ms / 3126 MB
pursuit 2 (unit 324 studs at start): 60.0 fps / worst 18.5 ms / 3126 MB
pursuit 3 (unit 345 studs at start): 60.0 fps / worst 18.4 ms / 3126 MB
ROLLBACK (3 entries removed, 3 models unparented, spec back to the one-sign version):
ROLLED BACK: CityLayout b5f21c41 spec d00b3e6e CityBuilder 3c5c8451 WorldService a91b95db; signs 1; BaseParts 319 CanCollide 114; City 6527bae1; stop-line f958ecfa; prototype 87d79268
Play: [Tests] 215 passed, 0 failed; signs in play: 1
RESTORED: CityLayout 81f2c85a spec 0443bbeb; signs 4; BaseParts 328 CanCollide 114 sign GUIs 16; prototype 87d79268; Stage A 18eef2d0
Play: [Tests] 216 passed, 0 failed; signs in play: 4
```

## Screenshots
Instance `Outlaw City (placeId: 132163592957463)`, Play, Batch 1 atmosphere lighting.
- **Files:** `screenshots/sign_<junction>_<names>_from<N|S|W|E>_<30|60>.jpg`, one per incoming approach and distance: 24 in all.
- **Camera:** the driver's eye at y 5 in the incoming lane, 30 or 60 studs from the junction centre, aimed at the cross-street blade.
- **Warm-up:** where the first capture after a camera jump hadn't drawn the SurfaceGui text yet, the second capture is the one kept.

## Not tested
- Phone simulator and real phone.
- Other players' view (MULTIPLAYER UNVERIFIED).
- Human driving.
