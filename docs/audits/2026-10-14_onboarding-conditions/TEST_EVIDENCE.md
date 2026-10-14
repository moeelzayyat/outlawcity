# Test evidence: 2026-10-14_onboarding-conditions

- Studio instance used: `Outlaw City (placeId: 132163592957463)`. Confirmed with the Studio instance list. Every Edit/Server call asserted `game.PlaceId == 132163592957463`. The two Lighthouse Keepers Studios that were also open were never touched.
- Backup: `backups\OutlawCity_Approved1.rbxl` (owner, Studio log 16:54:48Z). This round only made small corrections inside the approved batch.
- Automated tests: `[Tests] 200 passed, 0 failed` (first run after the changes).
- Solo Studio only. **Not multiplayer validation.**

## Automated tests
| Spec | Test | Result |
|---|---|---|
| `OnboardingRules.spec` | P1: `{Coupe}` → Spawn Coupe; `{Coupe, Muscle}` → Choose | PASS |
| `OnboardingRules.spec` | P1 stale selection: one owned car is always the one sent; the owned list wins over the starter list | PASS |
| `OnboardingRules.spec` | P1 not loaded: `{}` + starters → Spawn Coupe; `{}` + `{}` → None, nothing sent | PASS |
| `OnboardingRules.spec` | P3: Holding/Escaping active; nil, PayoutPending, Failed and 5 not | PASS |
| `RobberyRules.spec` | Dead + jailed in one tick → one failure (`Died`), cooldown 190 once. Later jailed/disconnected/dead/left facts → nil, phase and reason unchanged, cooldown still 190, no payout. A newer robbery B: further A callbacks leave B's cooldown (380) and B active | PASS |
| `RobberyRules.spec` | Success: escaping → Paid, a later bust does nothing, cooldown stays start + 180 (279.9 refused, 280 allowed) | PASS |
| All | `[Tests] 200 passed, 0 failed` | PASS |

## Manual / scripted Studio tests
| # | Test | Exact result |
|---|---|---|
| 1 | Stale selection: Muscle chosen in the garage, then the one-car view (`OwnedVehicles = Coupe`, display only); one click on Spawn Car | `Coupe_11752219158` spawned, garage closed. The player was driving the Muscle when clicking and ended up standing (see PROGRESS 8q, not new) |
| 2 | Not loaded: `OwnedVehicles` attribute removed; one click | `owned attr nil \| seated Coupe_11752219158 \| garage open false` |
| 3 | Tip (fresh session, server sets the display-only `RobberyPhase`) | `t+0.4 phase=PayoutPending tip=true`, `t+1.4 phase=nil tip=true`, `t+2.4 phase=Holding tip=false` |
| 4 | Live WantedEvading HUD (scripted getaway, Muscle, real register prompt) | `974.3 phase=Escaping stars=2 evading=false \| Break line of sight, then stay hidden until your stars are gone` → `978.7 … evading=true \| Stars fading: stay out of police sight until they're gone` → `980.6 … evading=false \| Break line of sight, …` (sighted again) → busted at 988.1 |
| 5 | Getaway 1 (Coupe) | Unit dispatched from 239 studs north; `rammed police at 30 studs/s`; `BUSTED`; `failed: Busted` |
| 6 | Cooldowns | Just after each start: `store cooldown 179.3 s` (180 s set at the start). After the busts the store reopened at start + 89.8 s (90 s) |
| 7 | Hash check | 8 changed scripts: Studio result hashes `5be03973, 2c7eb3f1, 027e4d2a, 616a1708, cf20b402, 82ebe509, 0c6effc2, f119e9fc` = local files |

Vehicle validation logged my test's car moves as `observation Teleport … moved 163 studs in 0.22 s` and one monitor-only `ALERT`. These were caused by the test script placing the car outside the store; it is monitor-only and no action was taken.

## Human playtest (owner)
Pending: the owner's results go here before this package goes to the auditor.

## Regression checks
- Robbery start/holdout/dispatch/bust/jail/release normal.
- Coupe and Muscle spawn and drive.
- Safe-zone log normal.
- No console errors from game code. The only error was from my own test snippet: `WorldPosition is not a valid member of ProximityPrompt`, fixed and re-run.

## Not tested
- **Phone with real touch controls:** no device or Device Simulator available to me; owner.
- **A successful getaway (180 s after success live):** 0/2 scripted getaways this round; covered by unit tests.
- **Multiplayer:** MULTIPLAYER UNVERIFIED.
