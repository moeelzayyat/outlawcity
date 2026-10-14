# Change manifest: 2026-10-14_atmosphere-batch1-closeout

- Commit range: `ad37ecd..` package commit
- Commits:
  - `dbceb57` Atmosphere Batch 1 closeout: police lights handle single light-bar parts streaming out and back in
  - the docs + package commit (hash in the owner's handoff)

Studio = `src/` for the changed scripts (hash-checked on push): AtmosphereController `cad4d631`, AtmosphereRules `2c719bee`, AtmosphereRules.spec `2471aff4`. AtmosphereConfig unchanged at `ae1b5df6`; it was edited temporarily for the baseline run and restored.

## Added
| File | Purpose |
|---|---|
| None | |

## Changed
| File | What changed and why |
|---|---|
| `src/StarterPlayer/StarterPlayerScripts/Client/Controllers/AtmosphereController.luau` | Bar removal/reinsertion handling, single light kept or moved or unparented, live-list flashing, Studio debug counts |
| `src/ReplicatedStorage/Shared/Atmosphere/AtmosphereRules.luau` | `litIndex` for 0/1/2+ bars |
| `src/ServerStorage/Tests/AtmosphereRules.spec.luau` | +1 test |
| `docs/PROGRESS.md`, `docs/ARCHITECTURE.md` | Closeout results, design note |

## Removed
| File | Why |
|---|---|
| None | |

## Docs updated
See above.

## Studio-only changes (not in src/)
None.

## Configuration values introduced or changed
| Setting | Old | New | Where |
|---|---|---|---|
| None | | | |
