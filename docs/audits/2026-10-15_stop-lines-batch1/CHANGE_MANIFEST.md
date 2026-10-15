# Change manifest: 2026-10-15_stop-lines-batch1

- Commit range: `52cf1ca..0b4919b` (+ package commit)
- Commits: `0b4919b` Stop-line Batch 1 (N5): 50 static stop lines on grid intersection approaches

## Added
| File | Purpose |
|---|---|
| `docs/audits/2026-10-15_stop-lines-batch1/` | This audit package (reports, diffs, 16 screenshots) |

## Changed
| File | What changed and why |
|---|---|
| `src/ServerScriptService/Server/World/CityLayout.luau` | `STOP_LINE_*` constants, `StopLineArm` type, `stopLineApproaches()`, one loop in `createBlueprint` adding the 50 non-colliding `Markings` slabs |
| `src/ServerStorage/Tests/CityLayout.spec.luau` | The signature test skips `StopLine_*` (new parts); +2 tests (count and 6/6/4 split; placement, properties, side and centre-line clearance) |
| `docs/STREET_MARKINGS_SIGNS_PLAN.md` | Arm breakdown corrected to 6 four-arm / 6 three-arm / 4 two-arm (Architect correction 1); status set to Batch 1 implemented, N4 not started |
| `docs/PROGRESS.md` | 3 rows (Batch 1, drive/pursuit/regression, visuals/perf/rollback); test count 211; Upcoming entry |
| `docs/ARCHITECTURE.md` | "Stop lines" bullet under "City look" |

## Removed
| File | Why |
|---|---|
| None | |

## Docs updated
See above.

## Studio-only changes (not in src/)
- 50 `StopLine_*` Parts added to `Workspace.City.Markings`, matching what `CityBuilder` builds from the blueprint. CityBuilder only builds the City when it's missing, so the existing place needed them added once. Removing them is the rollback.

## Configuration values introduced or changed
| Setting | Old | New | Where |
|---|---|---|---|
| `STOP_LINE_GAP` | — | 2 | `CityLayout` |
| `STOP_LINE_DEPTH` | — | 1.2 | `CityLayout` |
| `STOP_LINE_INNER` | — | 0.6 | `CityLayout` |
| `STOP_LINE_CURB` | — | 1 | `CityLayout` |
