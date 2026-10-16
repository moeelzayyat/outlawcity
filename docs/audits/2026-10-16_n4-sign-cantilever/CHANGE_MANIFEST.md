# Change manifest: 2026-10-16_n4-sign-cantilever

- Commit range: `b8c27cf..bb7cb55` (+ package commit)
- Commits: `bb7cb55` N4 sign fix: cantilevered blades on StreetSign_100_100 (option B)

## Added
| File | Purpose |
|---|---|
| `docs/audits/2026-10-16_n4-sign-cantilever/` | This audit package (reports, diffs, 48 screenshots plus the before/after crop sheet) |

## Changed
| File | What changed and why |
|---|---|
| `src/ServerScriptService/Server/World/CityLayout.luau` | `streetSigns()`: blades cantilevered from the post faces, away from the junction (centres (125.7, 8.6, 122) and (122, 10.2, 125.7)) |
| `src/ServerStorage/Tests/CityLayout.spec.luau` | Blade road-edge distance 0.5 → 3.9; new cantilever test (no shared volume, blades start at the post faces, exact centres) |
| `docs/PROGRESS.md` | 2 rows for the fix; test count 215; N4 entry |
| `docs/ARCHITECTURE.md` | "Street-name signs": cantilevered blades, and how an existing sign is changed |
| `docs/STREET_SIGN_PROTOTYPE_PLAN.md` | Status: fix applied; superseded centre and clearance values |

## Removed
| File | Why |
|---|---|
| None | |

## Docs updated
See above.

## Studio-only changes (not in src/)
- `Workspace.City.StreetSigns.StreetSign_100_100` was replaced once: the old model removed and a new one built by `CityBuilder.buildStreetSigns` from the new spec. `CityBuilder` and `WorldService` are unchanged.

## Configuration values introduced or changed
| Setting | Old | New | Where |
|---|---|---|---|
| Blade_EW centre | (122, 8.6, 122) | (125.7, 8.6, 122) | `CityLayout.streetSigns()` (derived) |
| Blade_NS centre | (122, 10.2, 122) | (122, 10.2, 125.7) | `CityLayout.streetSigns()` (derived) |
