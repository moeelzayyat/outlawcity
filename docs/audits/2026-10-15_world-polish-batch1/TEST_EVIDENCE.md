# Test evidence: 2026-10-15_world-polish-batch1

- Studio instance used: `Outlaw City (placeId: 132163592957463)`. Every Edit/Server call asserted the place ID; the other open Studios were never touched.
  - Studio reconnected once during the work (new instance ID). The reopened place matched the baseline exactly before any change: City full hash `b7ebb879`, scripts at HEAD.
- Backup: `G:\Roblox\Outlaw City\backups\OutlawCity_World1.rbxl` (218,964 bytes); Studio log `2026-10-15T16:40:14.714Z … Place file downloaded to 'G:\Roblox\Outlaw City\backups\OutlawCity_World1.rbxl'`.
- Automated tests: `[Tests] 209 passed, 0 failed`.
- Solo Studio only. **Not multiplayer validation.**

## Baseline (before any change)
```
script hashes: CityLayout d1037bbc CityBuilder 8665eb62 CityLayout.spec 0b275e9e
blueprint: 187 parts total, 186 rows without exception, hash 8b66ade9
Building_3_3_1 blueprint centre (159.000, 23.600, 159.000) size (41.000, 46.000, 52.000)
place: BaseParts 266, CanCollide 114; City parts 263; geometry hash without Building_3_3_1 18af160c; full hash b7ebb879
Baseplate: pos 0, -8, 0 size 2048, 16, 2048 colour 91,91,91 material Plastic CanCollide true Anchored true CustomPhysicalProperties nil Transparency 0.00 | Texture rbxassetid://6372755229 Transparency 0.80 StudsPerTileU 8
Buildings before: all SmoothPlastic, phys=nil, colours (120,110,100) (150,130,105) (90,100,115) (175,170,160) (105,85,80)
```

## After applying (Edit mode)
```
written: CityLayout 2c85f303 CityBuilder c67028a2 spec 85bce837; 24 buildings updated; Building_3_3_1 now 38.5, 46, 52 @ 157.75, 23.6, 159; Baseplate texture transparency 1
BaseParts 266 (baseline 266), CanCollide 114 (baseline 114)
City geometry hash without Building_3_3_1: 18af160c (baseline 18af160c); buildings 24
Building_3_3_1 X 138.50..177.00 (west edge baseline 138.50); min gap to dealership parts 2.00 studs
building materials: Concretex7, Brickx7, Slatex10; CanCollide 24/24; SmoothPlastic physics 24/24
Baseplate pos 0, -8, 0 size 2048, 16, 2048 material Plastic colour 62,66,58 CanCollide true CustomPhysicalProperties nil | Texture transparency 1.00 (was 0.80)
buildings vs current CityLayout blueprint: mismatches 0
```

## Automated tests
| Spec | Test | Result |
|---|---|---|
| `CityLayout.spec` | every generated part keeps its baseline geometry except Building_3_3_1 (186 rows, `8b66ade9`) | PASS |
| `CityLayout.spec` | Building_3_3_1 west edge 138.5, east 177, height 46, ≥1 stud from every dealership part; 24 buildings | PASS |
| `CityLayout.spec` | districts by column, built-in materials, SmoothPlastic physics, no glass | PASS |
| All | `[Tests] 209 passed, 0 failed` | PASS |

## Rollback test
The recorded pre-batch values were put back (colours, SmoothPlastic, physics nil, Building_3_3_1 41×46×52 at (159, 23.6, 159), Baseplate 91,91,91, texture 0.80):
```
ROLLED BACK: City full hash b7ebb879 (baseline b7ebb879); Baseplate colour 91,91,91 texture transparency 0.80 (baseline 91,91,91 / 0.80)
```
The new look was then re-applied (City full hash after: `6527bae1`; buildings vs blueprint: 0 mismatches). Script rollback is a git revert of `ea579b9`.

## Visual evidence (atmosphere Batch 1 lighting on, Play mode)
| View | Before | After |
|---|---|---|
| Plaza | `screenshots/before_plaza.jpg` | `screenshots/after_plaza.jpg`: Civic concrete and Downtown slate visible |
| 24/7 MART | `screenshots/before_store.jpg` | `screenshots/after_store.jpg`: Old Town brick; the sign readable |
| OUTLAW MOTORS | `screenshots/before_dealership.jpg` | `screenshots/after_dealership.jpg`: slate; the sign readable |
| Highway | `screenshots/before_highway.jpg` (checkerboard) | `screenshots/after_highway.jpg`: plain ground, no checkerboard |

The HUD, the tip and the sign text are readable in the after captures. Destination markers aren't in these views (camera positions are within 35 studs or the markers face away); they are unchanged code.

## Regressions (exact Output excerpts)
```
[Police] dispatched to Lighthouse8282 from node G_-300_-100 (240 studs away)
[Police] BUSTED Lighthouse8282 -> jail
[Jail] Lighthouse8282 released
[Police] dispatched to Lighthouse8282 from node G_300_-100 (316 studs away)
[Police] BUSTED Lighthouse8282 -> jail
[Jail] Lighthouse8282 released
[Robbery] Lighthouse8282 started 07737027-… at Store1
[Robbery] … holdout complete; escaping
[Police] dispatched to Lighthouse8282 from node G_-100_-300 (245 studs away)
[Economy] Lighthouse8282: purchase Muscle for 15000 (tx buy:Muscle:f56b3669-…) refused: AlreadyOwned
```
- Client: `spawn Muscle true nil seated Muscle_11752219158`; `buy Muscle at desk: false AlreadyOwned; cash 11400`.
- During the robbery the unit stood 23 studs from the storefront (`dist=23 … speed=1`, the known storefront stall, PROGRESS 8g), so that robbery didn't end in a bust within 50 s. Not new.
- Vehicle validation: `samples=0 observations=0 alerts=0` throughout.
- The `UIBlox - Warning - FoundationProvider not found` lines come from Roblox CorePackages, not game code.

## Performance
- **Device:** Windows PC, Studio Play.
- **Viewport:** 2004×935.
- **Graphics:** `SavedQualityLevel Automatic`.
- **Flags:** atmosphere Lighting=true, PoliceLights=true, Siren=false.
- **Samples:** 8 s idle, 6–8 s pursuit; after-runs used a guard that waits for 1 s at 55+ fps first.

| | Run | Idle | Pursuit |
|---|---|---|---|
| **Before** | 1 | 60.0 fps / worst 18.2 ms / 2707 MB | 60.0 fps / worst 19.3 ms / 2715 MB (unit 240 studs) |
| | 2 | 60.0 / 18.3 ms / 2707 MB | 50.0 / 67.8 ms (throttling began) |
| | 3 | 60.0 / 18.4 ms / 2710 MB | 14.7 / 201.5 ms (throttled; invalid) |
| **After** | 1 | 60.0 / 32.1 ms / 2812 MB | 15.0 / 68.5 ms (throttled; invalid) |
| | 2 | 60.0 / 18.3 ms / 2812 MB | 15.0 (throttled; invalid) |
| | 3 | 60.0 / 18.3 ms / 2813 MB | 15.0 (throttled; invalid) |

**Idle:** no measurable difference (60 fps cap). **Pursuit: PARTIAL.** Only 1 valid "before" run and no valid "after" run, because Studio was in the background. Memory differs between sessions (Studio was restarted in between); the batch adds no parts or instances.

## Not tested
- **Pursuit FPS:** PARTIAL.
- **Phone / Device Simulator:** NOT TESTED.
- **Multiplayer:** MULTIPLAYER UNVERIFIED.
