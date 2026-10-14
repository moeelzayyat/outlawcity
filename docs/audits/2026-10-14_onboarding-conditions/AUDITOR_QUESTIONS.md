# Questions for the auditor: 2026-10-14_onboarding-conditions

Answer each by number.

## Correctness and security
1. Does `OnboardingRules.spawnChoice` close condition 1? It sends the starter Coupe while the owned list is empty (not loaded). The server always accepts starter cars, so this is a valid request rather than an invalid one. Do you agree, or should it send nothing until the list loads?
2. Do the phase guard in `RobberyRules.tick`, the `LastSession` check and the early return in `RobberyService.failSession` close condition 3?

## Design and maintainability
1. The tip closes on Holding/Escaping only (not PayoutPending). Is that the "meaningful active robbery state" you meant?

## Testing gaps
1. A live successful getaway wasn't achieved this round (0/2 scripted), so "success keeps 180 s" rests on unit tests plus the live start setting 180 s. Is that enough until the owner's playtest?

## Decisions the owner should make
1. Should "Spawn Car while driving leaves you standing" (PROGRESS 8q, not new) be fixed in the next small batch?
2. After the human playtest: keep the experimental 90 s failed-robbery cooldown and the $15,000 Muscle?
