# Test evidence: 2026-10-14_atmosphere-batch1

- Studio instance used: `Outlaw City (placeId: 132163592957463)`. Every Edit/Server call asserted the place ID. The other open Studios were never touched.
- Backup: `G:\Roblox\Outlaw City\backups\OutlawCity_Atmosphere1.rbxl`; Studio log `2026-10-14T20:20:50.171Z … Place file downloaded to 'G:\Roblox\Outlaw City\backups\OutlawCity_Atmosphere1.rbxl'`.
- Automated tests: `[Tests] 205 passed, 0 failed` (every playtest after the push).
- Solo Studio only. **Not multiplayer validation.**

## Automated tests
| Spec | Asserts | Result |
|---|---|---|
| `AtmosphereRules.spec` (new, 5) | Preset values exactly as the plan; original values recorded; Siren off with no ID; `sirenEnabled` needs flag + `rbxassetid://<digits>`; flash phase alternates at 0.25 s and never errors on bad input; only `NpcVehicles.PoliceUnit` is decorated; light range ≤ 16, siren roll-off ≤ 300 | PASS |
| All | `[Tests] 205 passed, 0 failed` | PASS |

## Manual / scripted Studio tests
| # | Test | Exact result |
|---|---|---|
| 1 | Exact lighting values (client) | `client Lighting: ClockTime=16.50 Ambient=0.313726, 0.313726, 0.352941 OutdoorAmbient=0.470588, 0.45098, 0.431373` · `Atmosphere Density=0.32 Haze=1.00 Glare=0.20` · `Bloom Intensity=0.40 Size=24 Threshold=2.00` · `ColorCorrection Contrast=0.08 Saturation=0.12 Brightness=0.00` · `ColorCorrection count 1` |
| 2 | Place Lighting untouched (server during play) | `SERVER Lighting (place values, unchanged): ClockTime=14.50 Ambient=0.27451, 0.27451, 0.27451 Density=0.30 Bloom=1.00 CC=false` |
| 3 | Visual review | Captures in `screenshots/`: plaza_after, store_after, dealership_after, dealership_before. The HUD is readable in all of them. The highway capture timed out, and later captures rendered white (known Studio MCP issue). In `dealership_after` the OUTLAW MOTORS sign text is missing; it shows in `dealership_before` (see the report, section 8) |
| 4 | Static vs flashing in a real pursuit | Robbery by the real prompt: `unit during holdout: false`; after the holdout the unit spawned: `bars 2; local OutlawAtmosphere instances in workspace: 1`; samples `t+0.12 red:0.65 blue:0.00 light=on blue` · `t+0.38 red:0.00 blue:0.65 light=on red` · `t+0.62 red:0.65 blue:0.00 light=on blue` · `t+0.75 red:0.00 blue:0.65 light=on red` … With `PoliceLights=false`: modifiers `0.00` throughout, `local light 0` (static, as before) |
| 5 | Spawn/despawn cycles | 5 cycles (`SetStars 2` → unit → `ResetWanted` → despawn): every cycle `with unit: 1 local instances (1 PointLight); after despawn (3.6–3.9 s): 0`. Output: 5 × `dispatched` / `despawn (target no longer wanted …)`, one unit at a time, no errors |
| 6 | Flag Lighting=false | `ClockTime=14.5 Ambient=0.27451, 0.27451, 0.27451 Density=0.30 Haze=0 Bloom=1.0 ColorCorrection=false` while police lights still flashed (`0.00,0.65,0.65,0.00,…`, `local light 1`) |
| 7 | Flag PoliceLights=false | Lighting still applied (`ClockTime=16.5 … ColorCorrection=true`); light bar static, no local light |
| 8 | Full rollback | Lighting=false gives the place's original values (test 6), and PoliceLights=false gives the original static bar (test 7). With both off nothing from Batch 1 is applied. Config restored afterwards (`restored ae1b5df6`) |
| 9 | Siren | Not added: no owner-approved sound ID. `Siren=false`, `SirenSoundId=nil` (spec-checked) |

## Performance
| Measurement | Before Batch 1 | After Batch 1 |
|---|---|---|
| Idle, plaza (8 s, PC Studio 2004×935) | `avg 60.0 fps, worst frame 18.4 ms, memory 2714 MB` | `avg 15.0 fps, worst frame 67.9 ms, memory 2712 MB`, **Studio throttled** |
| Chase, police unit within 20 studs (8 s / 6 s) | `avg 60.0 fps, worst frame 34.0 ms, memory 2716 MB` | `avg 15.1 fps, worst frame 68.9 ms, memory 2711 MB`, **Studio throttled** |
| Same-session A/B while throttled | | Lighting original `14.9 fps` vs preset `15.2 fps`; police lights off `15.3 fps` |

**Interpretation:** Studio dropped to about 15 fps for every configuration, including the original lighting, so Batch 1 isn't the cause. A fair 60 fps after-number needs the Studio window in front: **PARTIAL / to be re-measured.** Memory is unchanged within about 5 MB (Studio total).

## Regression checks
- Robbery start/holdout/dispatch; Coupe spawn → seated; `SetStars 2` → dispatch → `SimulateBust` → jailed 12 s → released; cash 11,400 unchanged.
- The police unit stalled at the storefront once (known PROGRESS 8g, unchanged).
- Vehicle validation 0 observations; no console errors.

## Not tested
- **Device Simulator / real phone:** NOT TESTED.
- **Siren:** no approved asset.
- **Highway visual:** capture timed out.
- **FPS after at an unthrottled 60 fps:** pending.
- **Multiplayer:** MULTIPLAYER UNVERIFIED.
