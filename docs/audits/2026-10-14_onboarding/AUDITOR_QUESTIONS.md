# Questions for the auditor: 2026-10-14_onboarding

Answer each by number.

## Correctness and security
1. `RobberyRules.fail` shortens the cooldown only when `store.LastSession == session.Id`. Is that enough to stop an old robbery's late failure from shortening a newer robbery's cooldown? Do you see any other ordering problem?
2. The store's cooldown and busy state are published as `City.Store` attributes for display, and the server still decides in `canStart`. Any concern with exposing them?

## Data safety and persistence
1. Does the ±infinity check close the `RewardLedger.validate` follow-up?

## Design and maintainability
1. Is putting all the guidance rules in one pure module (`OnboardingRules`) with one config (`OnboardingConfig`) the right size, or would you split it?
2. Markers draw through buildings (`AlwaysOnTop`) and show from 35 to 450 studs. Does that meet "discreet"?

## Testing gaps
1. P7 was measured in a 666×374 layout frame, not the Device Simulator or a real phone. Is that acceptable evidence until the owner's real-phone check?
2. The evading text and a successful getaway's 180 s cooldown were covered by unit tests, not seen live. Do you want live evidence before approval?

## Decisions the owner should make
1. After human playtests: keep the 90 s failed-robbery cooldown, or go back to 180 s? Note that failing on purpose resets the store sooner, at the price of 2★, the police and no cash.
2. After human playtests: keep the Muscle at $15,000 (8 successful robberies from $500)?
