# Change manifest: 2026-10-14_onboarding-conditions

- Commit range: `fc3e5c3..b58d907`
- Commits:
  - `9bfa55a` Onboarding audit conditions: safe one-car spawn choice, tip closes only on an active robbery, duplicate-failure guard, experimental cooldown label
  - `b58d907` Docs: onboarding audit conditions done; 200/200

Studio matches `src/` for all 8 changed scripts: each push checked the pre-change hash and the result hash.

## Added
| File | Purpose |
|---|---|
| None | |

## Changed
| File | What changed and why |
|---|---|
| `src/ReplicatedStorage/Shared/Onboarding/OnboardingRules.luau` | `spawnChoice` replaces `spawnButtonAction` (condition 1); `isActiveRobbery` (condition 2) |
| `src/StarterPlayer/StarterPlayerScripts/Client/Controllers/GarageController.luau` | `spawnOrChoose` uses `spawnChoice` and sets the selection to the spawned car; sends nothing with no candidates |
| `src/StarterPlayer/StarterPlayerScripts/Client/Controllers/OnboardingTipController.luau` | Closes only on Holding/Escaping; disconnects its listener |
| `src/ReplicatedStorage/Shared/Robbery/RobberyRules.luau` | Comment: a session fails at most once (condition 3) |
| `src/ServerScriptService/Server/Services/RobberyService.luau` | `failSession` returns early for an entry that already ended (condition 3) |
| `src/ReplicatedStorage/Shared/Config/RobberyConfig.luau` | `FailedCooldownSeconds` labelled EXPERIMENTAL (condition 4) |
| `src/ServerStorage/Tests/OnboardingRules.spec.luau` | P1 test rewritten; +3 tests |
| `src/ServerStorage/Tests/RobberyRules.spec.luau` | +2 tests |

## Removed
| File | Why |
|---|---|
| None (only the function `OnboardingRules.spawnButtonAction`, replaced by `spawnChoice`) | |

## Docs updated
- PROGRESS: 200/200, two result rows, known issues 8q and 8r, Upcoming.
- ARCHITECTURE: P1, P3 and the cooldown notes.
- TEST_CHECKLIST: condition checks.
- ROADMAP: status.

## Studio-only changes (not in src/)
None. During tests the `OwnedVehicles` and `RobberyPhase` display attributes were set on the server to create the one-car, not-loaded and tip cases, then restored or cleared. The profile was never changed.

## Configuration values introduced or changed
| Setting | Old | New | Where |
|---|---|---|---|
| None (90 s failed-robbery cooldown unchanged, now labelled EXPERIMENTAL) | | | `RobberyConfig.FailedCooldownSeconds` |
