# Change manifest: 2026-10-14_atmosphere-batch1

- Commit range: `9b52d54..af8ae97` (+ package commit)
- Commits:
  - `b3ebb00` Atmosphere Batch 1: client lighting preset, flashing police lights, feature flags (siren off pending asset approval)
  - `af8ae97` Docs: atmosphere Batch 1 results

Studio = `src/` for every changed script (hash-checked on push): AtmosphereRules `2e885e2b`, AtmosphereConfig `ae1b5df6` (restored after the flag tests), AtmosphereRules.spec `8482d0e3`, AtmosphereController `42c4ce71`, Main `39c05c61`.

## Added
| File | Purpose |
|---|---|
| `src/ReplicatedStorage/Shared/Config/AtmosphereConfig.luau` | Flags, preset, original values, police light parameters |
| `src/ReplicatedStorage/Shared/Atmosphere/AtmosphereRules.luau` | Pure helpers |
| `src/StarterPlayer/StarterPlayerScripts/Client/Controllers/AtmosphereController.luau` | Client lighting and police lights (siren gated) |
| `src/ServerStorage/Tests/AtmosphereRules.spec.luau` | 5 tests |

## Changed
| File | What changed and why |
|---|---|
| `src/StarterPlayer/StarterPlayerScripts/Client/Main.client.luau` | Boots `AtmosphereController` |
| `docs/PROGRESS.md`, `docs/ARCHITECTURE.md`, `docs/CITY_ATMOSPHERE_AUDIO_AUDIT.md`, `docs/TEST_CHECKLIST.md` | Results, design, status, checks |

## Removed
| File | Why |
|---|---|
| None | |

## Docs updated
See above.

## Studio-only changes (not in src/)
None. The place's Lighting service is unchanged. `AtmosphereConfig` was temporarily edited for the flag tests and restored to the committed version (hash `ae1b5df6`).

## Configuration values introduced or changed
| Setting | Old | New | Where |
|---|---|---|---|
| Client ClockTime / Ambient / OutdoorAmbient | 14.5 / (70,70,70) / (70,70,70) | 16.5 / (80,80,90) / (120,115,110) | `AtmosphereConfig.Lighting` (client only) |
| Atmosphere Density / Haze / Glare | 0.30 / 0 / 0 | 0.32 / 1 / 0.2 | client only |
| Bloom Intensity | 1 | 0.4 | client only |
| ColorCorrection | none | Contrast 0.08, Saturation 0.12 | client only |
| Police light flash | static | 0.25 s alternation, 1 PointLight range 14 | `AtmosphereConfig` |
| Siren | none | off (`Siren = false`, no ID) | `AtmosphereConfig` |
