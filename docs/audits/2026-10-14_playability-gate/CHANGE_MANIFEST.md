# Change manifest: 2026-10-14_playability-gate

- Commit range: `fc3e5c3..3693ab9`
- Commits:
  - `9bfa55a` Onboarding audit conditions (spawnChoice, tip, duplicate-failure guard, experimental label)
  - `b58d907` Docs for the conditions
  - `46283cd` Draft package for the conditions (superseded by this one)
  - `affc166` Fix: replacing a car while driving now seats you in the new car
  - `3693ab9` Docs: playability gate results, 10-minute playtest checklist

## Added
| File | Purpose |
|---|---|
| `docs/PLAYTEST_CHECKLIST.md` | Owner's 10-minute playtest, no dev tools |

## Changed
| File | What changed and why |
|---|---|
| `src/ServerScriptService/Server/Services/VehicleService.luau` | Leave the old seat before the despawn; seat-retry loop (up to 1 s, stops once seated); `SEAT_RETRIES`, `SEAT_RETRY_INTERVAL` |
| `src/StarterPlayer/StarterPlayerScripts/Client/Controllers/VehicleController.luau` | Follow `Humanoid.SeatPart`; clear a removed current car |
| `src/ReplicatedStorage/Shared/Onboarding/OnboardingRules.luau` | `spawnChoice`, `isActiveRobbery` (conditions) |
| `src/StarterPlayer/StarterPlayerScripts/Client/Controllers/GarageController.luau` | Uses `spawnChoice` |
| `src/StarterPlayer/StarterPlayerScripts/Client/Controllers/OnboardingTipController.luau` | Closes only on an active robbery |
| `src/ReplicatedStorage/Shared/Robbery/RobberyRules.luau`, `src/ServerScriptService/Server/Services/RobberyService.luau` | Fail-at-most-once note; `failSession` early return |
| `src/ReplicatedStorage/Shared/Config/RobberyConfig.luau` | EXPERIMENTAL label |
| `src/ServerStorage/Tests/OnboardingRules.spec.luau`, `src/ServerStorage/Tests/RobberyRules.spec.luau` | +3 and +2 tests |
| `docs/PROGRESS.md`, `docs/ARCHITECTURE.md`, `docs/TEST_CHECKLIST.md`, `docs/ROADMAP.md` | Results, fix description, known issues 8q (fixed) and 8s (open), next step |

## Removed
| File | Why |
|---|---|
| None | |

## Studio-only changes (not in src/)
None. Display attributes were set during tests and restored.

## Configuration values introduced or changed
| Setting | Old | New | Where |
|---|---|---|---|
| Seat retries after a spawn | none | 10 × 0.1 s | `VehicleService` |
| Pursuit 130 / 100 / 0.25, DecayDelay 8, 90 s failed-robbery cooldown, $15,000 Muscle | unchanged | unchanged | |
