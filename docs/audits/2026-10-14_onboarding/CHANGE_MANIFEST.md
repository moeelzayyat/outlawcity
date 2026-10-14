# Change manifest: 2026-10-14_onboarding

- Commit range: `7618566..7371eef`
- Commits:
  - `a283809` Onboarding batch: one-car spawn, markers, first-spawn tip, escape hint, store cooldown display, Muscle progress, compact mobile panel, Studio milestones (plus the ±infinity timestamp fix and the 90 s failed-robbery cooldown trial)
  - `7371eef` Docs: onboarding batch (audit 4) results, architecture, checklist, plan status

The `src/` snapshot matches Studio for **all 98 scripts** (length + FNV-1a hash compared after the last change).

## Added
| File | Purpose |
|---|---|
| `src/ReplicatedStorage/Shared/Config/OnboardingConfig.luau` | Guidance values: marker range and height, tip time, compact panel layout, minimum text size, milestone names |
| `src/ReplicatedStorage/Shared/Onboarding/OnboardingRules.luau` | Pure helpers for P1–P8 |
| `src/ServerScriptService/Server/Dev/MilestoneLog.luau` | P8: Studio-only milestone timings |
| `src/StarterPlayer/StarterPlayerScripts/Client/Controllers/WorldMarkerController.luau` | P2 markers, P5 store status, and the register prompt's reopen time |
| `src/StarterPlayer/StarterPlayerScripts/Client/Controllers/OnboardingTipController.luau` | P3 first-spawn tip |
| `src/ServerStorage/Tests/OnboardingRules.spec.luau` | 7 tests for P1–P8 |

## Changed
| File | What changed and why |
|---|---|
| `src/ServerScriptService/Server/Data/RewardLedger.luau` | `validate`: `At` must not be ±infinity (audit 4 follow-up) |
| `src/ReplicatedStorage/Shared/Config/RobberyConfig.luau` | `FailedCooldownSeconds = 90` (P5 trial) |
| `src/ReplicatedStorage/Shared/Robbery/RobberyRules.luau` | `StoreState.LastSession`; `fail` shortens the cooldown after a failure, only for the store's latest session; `fail` takes `config` |
| `src/ServerScriptService/Server/Services/RobberyService.luau` | `publishStore` writes `RobberyCooldownUntil` and `RobberyBusy` on `City.Store`; milestone marks on start and on the robbery escape |
| `src/ServerScriptService/Server/Services/VehicleService.luau` | Milestone mark `FirstCar` after seating |
| `src/StarterPlayer/StarterPlayerScripts/Client/Controllers/GarageController.luau` | `spawnOrChoose` (P1) |
| `src/StarterPlayer/StarterPlayerScripts/Client/Controllers/VehicleHudController.luau` | Spawn Car calls `spawnOrChoose` |
| `src/StarterPlayer/StarterPlayerScripts/Client/Controllers/RobberyHudController.luau` | Compact phone layout and `CoreUISafeInsets` (P7); escape title and hint (P4) |
| `src/StarterPlayer/StarterPlayerScripts/Client/Controllers/DealershipController.luau` | Muscle progress in the message line (P6) |
| `src/StarterPlayer/StarterPlayerScripts/Client/Main.client.luau` | Boots WorldMarkerController and OnboardingTipController |
| `src/ServerStorage/Tests/RewardLedger.spec.luau` | +2 bad timestamp shapes (±infinity) |
| `src/ServerStorage/Tests/RobberyRules.spec.luau` | Default-value check for 90; existing cooldown test reads the failed cooldown; +3 tests (90 s vs 180 s, old behaviour with nil, late failure can't cut a newer cooldown) |

## Removed
| File | Why |
|---|---|
| None | |

## Docs updated
- `docs/PROGRESS.md`: test count 195; 11 result rows; known issues 8h (resolved) and 8p (new); Upcoming.
- `docs/ARCHITECTURE.md`: module list, store attributes, failed-robbery cooldown, escape text, new section *New-player guidance*.
- `docs/PLAYER_EXPERIENCE_AUDIT.md`: status, the 8-robbery correction, section 6 (approved vs built vs measured).
- `docs/TEST_CHECKLIST.md`: new *Onboarding batch* section.
- `docs/ROADMAP.md`: plan reviewed, batch done.

## Studio-only changes (not in src/)
None. The `City.Store` attributes are written at runtime only. No Workspace test attributes remain. During testing the `OwnedVehicles` display attribute was set to `Coupe` to simulate a one-car player, then restored to `Coupe,Muscle`; the profile was never changed.

## Configuration values introduced or changed
| Setting | Old | New | Where |
|---|---|---|---|
| Cooldown after a failed robbery | 180 s (same as success) | 90 s from the start (trial) | `RobberyConfig.FailedCooldownSeconds` |
| Successful-robbery cooldown | 180 s | 180 s (unchanged) | `RobberyConfig.CooldownSeconds` |
| Marker range | none | 35–450 studs | `OnboardingConfig` |
| Tip duration | none | 15 s | `OnboardingConfig.TipSeconds` |
| Phone robbery panel | 300×76 at y 136 | 260×64 at y 92 below 400 px screen height | `OnboardingConfig` |
| Muscle price, police tuning, `DecayDelay` | 15,000 / 130 / 100 / 0.25 / 8 | unchanged | |
