# Change manifest: 2026-10-16_n4-one-sign

- Commit range: `c81f00f..2354a92` (+ package commit)
- Commits: `2354a92` N4 one-sign prototype: StreetSign_100_100 (3rd St / C Ave)

## Added
| File | Purpose |
|---|---|
| `docs/audits/2026-10-16_n4-one-sign/` | This audit package (reports, diffs, 38 screenshots and crops) |

## Changed
| File | What changed and why |
|---|---|
| `src/ServerScriptService/Server/World/CityLayout.luau` | Street names, `STREET_SIGNS` (one entry), size constants, `StreetSignSpec` types, `streetSigns()` |
| `src/ServerScriptService/Server/World/CityBuilder.luau` | `buildStreetSigns(city)`: idempotent; Atomic model, 3 non-colliding parts, 4 SurfaceGuis |
| `src/ServerScriptService/Server/Services/WorldService.luau` | Calls `buildStreetSigns` at every server start (adds only missing signs) |
| `src/ServerStorage/Tests/CityLayout.spec.luau` | +3 tests: count, sizes/orientation/names, full footprints and road-edge distances |
| `docs/PROGRESS.md` | 2 rows, test count 214, N4 entry (prototype awaiting review; rest not authorized) |
| `docs/ARCHITECTURE.md` | "Street-name signs" bullet under "City look" |
| `docs/STREET_SIGN_PROTOTYPE_PLAN.md` | Status: approved with conditions and implemented; the 7 corrections; post-occlusion finding |

## Removed
| File | Why |
|---|---|
| None | |

## Docs updated
See above.

## Studio-only changes (not in src/)
- `Workspace.City.StreetSigns.StreetSign_100_100` was created once in the place by `CityBuilder.buildStreetSigns`. The same function recreates it if missing at server start.

## Configuration values introduced or changed
| Setting | Old | New | Where |
|---|---|---|---|
| `STREET_SIGNS` | — | `{ {X=100, Z=100, CornerX=22, CornerZ=22} }` | `CityLayout` |
| `STREET_SIGN_POST` | — | 0.4 × 10.4 × 0.4 | `CityLayout` |
| Blade length / height / thickness | — | 7 / 1.5 / 0.2 | `CityLayout` |
| Blade centre heights | — | EW 8.6, NS 10.2 | `CityLayout` |
| `STREET_NAMES_EW` / `_NS` | — | 1st–4th St / A–D Ave (prototype only) | `CityLayout` |
