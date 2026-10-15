# Change manifest: 2026-10-15_world-polish-batch1

- Commit range: `96cce64..` package commit
- Commits:
  - `ea579b9` World polish Batch 1: district looks (N1), dealership clipping fix (N3); RNG sequence and collision physics preserved
  - the docs + package commit (hash in the owner's handoff)

Studio = `src/` (hash-checked on push): CityLayout `2c85f303`, CityBuilder `c67028a2`, CityLayout.spec `85bce837`.

## Added
| File | Purpose |
|---|---|
| None | |

## Changed
| File | What changed and why |
|---|---|
| `src/ServerScriptService/Server/World/CityLayout.luau` | `DISTRICTS` (N1); the colour roll is kept for the RNG sequence; `BUILDING_EAST_INSET` (N3); `PartSpec.PhysicsMaterial` |
| `src/ServerScriptService/Server/World/CityBuilder.luau` | Applies `PhysicsMaterial` as `CustomPhysicalProperties` |
| `src/ServerStorage/Tests/CityLayout.spec.luau` | +3 tests (geometry signature, the Building_3_3_1 exception and clearance, districts and physics) |
| `docs/PROGRESS.md`, `docs/ARCHITECTURE.md`, `docs/CITY_NAVIGATION_WORLD_AUDIT.md` | Results, design, status |

## Removed
| File | Why |
|---|---|
| None | |

## Docs updated
See above.

## Studio-only changes (not in src/)
| Object | Before | After |
|---|---|---|
| `Workspace.Baseplate` Color | 91, 91, 91 | 62, 66, 58 |
| `Workspace.Baseplate.Texture` (`rbxassetid://6372755229`) Transparency | 0.80 | 1.00 (disabled, not deleted) |
| `Workspace.City.Buildings.*` (24) | SmoothPlastic, 5 random colours, no CustomPhysicalProperties | Brick / Concrete / Slate by column, district colours, CustomPhysicalProperties = SmoothPlastic |
| `Workspace.City.Buildings.Building_3_3_1` | Size 41×46×52 at (159, 23.6, 159) | Size 38.5×46×52 at (157.75, 23.6, 159) |

The Baseplate's size, position, material, CanCollide and physics are unchanged.

## Configuration values introduced or changed
| Setting | Old | New | Where |
|---|---|---|---|
| District palettes / materials | none | Old Town Brick, Civic Concrete, Downtown Slate | `CityLayout.DISTRICTS` |
| Building_3_3_1 east inset | 0 | 2.5 studs | `CityLayout.BUILDING_EAST_INSET` |
