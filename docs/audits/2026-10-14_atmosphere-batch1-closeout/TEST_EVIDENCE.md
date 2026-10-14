# Test evidence: 2026-10-14_atmosphere-batch1-closeout

- Studio instance used: `Outlaw City (placeId: 132163592957463)`. Every Edit/Server call asserted the place ID. The other open Studios were never touched.
- Backup: `backups\OutlawCity_Atmosphere1.rbxl` (Studio log 20:20:50Z), from the start of Batch 1. The closeout only changed client presentation.
- Automated tests: `[Tests] 206 passed, 0 failed` on every playtest after the push.
- Solo Studio only. **Not multiplayer validation.**

## Automated tests
| Spec | New/changed | Result |
|---|---|---|
| `AtmosphereRules.spec` | +"zero, one or two live bars are handled safely" (`litIndex` 0 → nil; 1 bar blinks; 2 bars alternate; never past the list) | PASS |
| All | `[Tests] 206 passed, 0 failed` | PASS |

## 1. Partial streaming: single bars removed and reinserted
Unit present (`SetStars 2`); bars un-parented locally (as streaming would) and re-parented. `AtmosphereDebug` and modifiers sampled 4 × 0.13 s:
```
two bars | units=1 bars=2 lights=1 connections=3 sirens=0 | PointLights in game: 1 (in workspace: LightBar on) | modifiers 0.00/0.65 0.65/0.00 0.65/0.00 0.00/0.65
removed bar keeps modifier 0.00
one bar left | units=1 bars=1 lights=1 connections=3 sirens=0 | PointLights in game: 1 (in workspace: LightBar on) | modifiers 0.00 0.00 0.65 0.65
zero bars | units=1 bars=0 lights=0 connections=3 sirens=0 | PointLights in game: 0 (in workspace: ?) | modifiers
one bar back | units=1 bars=1 lights=1 connections=3 sirens=0 | PointLights in game: 1 (in workspace: LightBar on) | modifiers 0.00 0.65 0.65 0.00
both back | units=1 bars=2 lights=1 connections=3 sirens=0 | PointLights in game: 1 (in workspace: LightBar on) | modifiers 0.00/0.65 0.00/0.65 0.65/0.00 0.65/0.00
after despawn | units=0 bars=0 lights=0 connections=0 sirens=0 | PointLights in game: 0
```
With zero bars the light is kept unparented (not counted), and it reattaches with no duplicate. Output had no errors (`[Tests] 206 passed, 0 failed`, normal police dispatch/despawn lines only).

## 2. Dealership sign and highway
Same camera (200, 25, 70) → (200, 6, 136); player at the plaza. Client state: `Dealership loaded true | DealerSign true | SurfaceGui true Enabled=true Face=Front … label true visible=true text="OUTLAW MOTORS"`.

| Configuration | Capture | Sign text | File |
|---|---|---|---|
| Original lighting (both flags off) | 1 | missing | `screenshots/dealership_original_lighting_capture1.jpg` |
| Original lighting | 2 | visible | `screenshots/dealership_original_lighting_capture2.jpg` |
| Batch 1 lighting | 1 | missing | `screenshots/dealership_batch1_lighting_capture1.jpg` |
| Batch 1 lighting | 2 | (capture timed out) | none |
| Batch 1 lighting | 3 | visible | `screenshots/dealership_batch1_lighting_capture3.jpg` |

**Conclusion:** the first capture after a camera jump misses the SurfaceGui text in **both** configurations, and the next capture shows it. It isn't caused by the lighting preset, so no fix was made.

Highway with Batch 1 lighting: `screenshots/highway_batch1_lighting.jpg`. Lane dashes, edge lines and the grid centre lines are clearly visible.

## 3. Performance (unthrottled)
- **Device:** Windows PC, Roblox Studio Play (solo).
- **Viewport:** 2004×935.
- **Graphics:** `SavedQualityLevel Automatic`, `Rendering.QualityLevel Automatic`.
- **Studio foregrounded:** yes. The check before the runs read `59.7 fps`, against about 15 fps when backgrounded earlier.
- **Samples:** 8 s each, `RenderStepped`; memory is `Stats:GetTotalMemoryUsageMb()` (the whole Studio process).
- **Idle:** player at the plaza.
- **Pursuit:** `SetStars 2`, unit dispatched and approaching (runs 1–2 with the unit present; in run 3 the unit despawned partway through, in both configurations).

| Config | Flags | Run | Idle | Pursuit |
|---|---|---|---|---|
| **Batch 1 ON** | Lighting=true, PoliceLights=true, Siren=false | 1 | 60.0 fps / worst 29.7 ms / 2630 MB | 60.0 fps / worst 18.7 ms / 2647 MB (unit 436 studs at start) |
| | | 2 | 59.7 fps / worst 67.3 ms / 2633 MB | 60.0 fps / worst 19.0 ms / 2647 MB (unit 37 studs) |
| | | 3 | 60.0 fps / worst 21.7 ms / 2646 MB | 60.0 fps / worst 21.2 ms / 2629 MB |
| **Baseline** | Lighting=false, PoliceLights=false, Siren=false | 1 | 59.8 fps / worst 67.7 ms / 2639 MB | 59.9 fps / worst 49.4 ms / 2634 MB (unit 312 studs) |
| | | 2 | 60.0 fps / worst 18.5 ms / 2638 MB | 60.0 fps / worst 21.6 ms / 2635 MB (unit 34 studs) |
| | | 3 | 60.0 fps / worst 25.9 ms / 2638 MB | 60.0 fps / worst 19.0 ms / 2633 MB |

**Result:** no measurable difference at the 60 fps cap. Occasional single worst frames (about 67 ms) occur in both configurations. The baseline config was set temporarily and restored to the committed version (hash `ae1b5df6`).

## Regression checks
```
[Robbery] Lighthouse8282 started 5f1cbfd2-… at Store1
[Robbery] … holdout complete; escaping
[Police] dispatched to Lighthouse8282 from node G_-100_300 (360 studs away)
[Police] BUSTED Lighthouse8282 -> jail
[Robbery] … failed: Busted
[Jail] Lighthouse8282 released
```
- During the chase: `units=1 bars=2 lights=1 connections=3 sirens=0`. Afterwards: `units=0 … lights=0`; leftover PointLights `0`.
- Coupe spawn → `seated Coupe_11752219158`; cash 11,400 unchanged.
- Vehicle validation 0 observations; one NPC unit at all times.

## Not tested
- **Device Simulator and real phone:** NOT TESTED.
- **Siren:** off, no sound ID.
- **Real network streaming / other players:** MULTIPLAYER UNVERIFIED.
