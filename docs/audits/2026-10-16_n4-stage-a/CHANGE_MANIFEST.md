# Change manifest: 2026-10-16_n4-stage-a

- Commit range: `6031627..87b6198` (+ package commit)
- Commits: `87b6198` N4 Stage A: three plaza-ring street signs

## Added
| File | Purpose |
|---|---|
| `docs/audits/2026-10-16_n4-stage-a/` | This audit package (reports, diffs, 24 rendered views) |

## Changed
| File | What changed and why |
|---|---|
| `src/ServerScriptService/Server/World/CityLayout.luau` | `STREET_SIGNS`: the prototype plus three Stage A entries |
| `src/ServerStorage/Tests/CityLayout.spec.luau` | Street-sign tests cover all signs; new exact post and name test |
| `docs/PROGRESS.md` | Stage A rows, test count 216, N4 entry |
| `docs/ARCHITECTURE.md` | "Street-name signs" data bullet lists the four signs |
| `docs/N4_STREET_SIGN_ROLLOUT_PLAN.md` | Status: Stage A approved and built; B–D not authorized |

## Removed
| File | Why |
|---|---|
| None | |

## Docs updated
See above.

## Studio-only changes (not in src/)
- `City.StreetSigns.StreetSign_-100_-100`, `StreetSign_100_-100` and `StreetSign_-100_100` were added by `CityBuilder.buildStreetSigns`, the same code that runs at server start.

## Configuration values introduced or changed
| Setting | Old | New | Where |
|---|---|---|---|
| `STREET_SIGNS` | 1 entry | 4 entries (prototype + Stage A) | `CityLayout` |
