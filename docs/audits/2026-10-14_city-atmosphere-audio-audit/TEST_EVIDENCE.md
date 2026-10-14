# Test evidence: 2026-10-14_city-atmosphere-audio-audit

- Studio instance used: `Outlaw City (placeId: 132163592957463)`; every query asserted `game.PlaceId`. Read-only: nothing was changed.
- Automated tests: not run (no code changed). The last run was `[Tests] 200 passed, 0 failed`.

## Automated tests
| Spec | Result |
|---|---|
| None (plan only) | Not run |

## Manual / scripted Studio tests (read-only inspection)
| Query | Exact result |
|---|---|
| Lighting | `ClockTime=14.5 Brightness=3 Ambient=0.27451, 0.27451, 0.27451 OutdoorAmbient=0.27451, 0.27451, 0.27451 EnvDiffuse=1 EnvSpecular=1 GlobalShadows=true FogEnd=100000 Exposure=0` |
| Lighting children | `Sky`, `SunRays Enabled=true Intensity=0.010`, `Atmosphere Density=0.30 Offset=0.25 … Glare=0.00 Haze=0.00`, `Bloom Enabled=true Intensity=1.00 Size=24 Threshold=2.00`, `DepthOfField Enabled=false` |
| Sound | `SoundService: AmbientReverb=Enum.ReverbType.NoReverb … children=0`; `Sounds in place: 0` |
| Instance counts | PointLight 3 (jail, store, dealership roofs), SpotLight 0, ParticleEmitter 0, Beam 0, Trail 0, Part 257, `StreamingEnabled=true` |
| City | `Roads(18), Markings(120), …`; `LineEW segments 12` |
| Technology | `Technology readable: false` (capability limit) |
| Code (braking/tyres) | `VehicleFactory`: fixed-colour Neon `Taillight` parts. `VehiclePhysics`: lateral speed computed each frame; handbrake uses `HandbrakeLateralGrip`. `VehicleInputController`: brake input exists (keyboard, gamepad trigger, touch BRAKE). No brake-light or audio hooks |

## Screenshots
None (3D captures render white on this machine).

## Regression checks
Not applicable (no changes).

## Not tested
Everything in the plan; it is not implemented.
