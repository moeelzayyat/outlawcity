# Auditor report: 2026-10-14_onboarding-conditions

- Project: OUTLAW CITY (Roblox, place ID 132163592957463)
- Date: 2026-10-14
- Commit range: `fc3e5c3..b58d907` (code `9bfa55a`, docs `b58d907`)
- Prepared by: Claude (primary integration agent)
- Status: **SUPERSEDED** by `docs/audits/2026-10-14_playability-gate/` (submitted together with the seating fix); kept for the record. Was: conditions done (solo); owner's human playtest pending. Its results will be added to TEST_EVIDENCE.md section "Human playtest" before this goes to the auditor.

## 1. What was asked
The onboarding audit was **APPROVE WITH CONDITIONS**. It asked for four small corrections:
1. `GarageController.spawnOrChoose` must select the sole owned car explicitly and handle zero or not-yet-loaded ownership without an invalid spawn request.
2. The tip should be dismissed only on a meaningful active robbery state.
3. Verify that duplicate robbery failure callbacks can't repeatedly change the cooldown or disrupt a newer session.
4. Keep the 90 s failed-robbery cooldown configurable and experimental.

It also asked for focused tests:
- stale selection;
- zero or not-loaded ownership;
- overlapping failures;
- success keeps 180 s;
- live `WantedEvading` HUD;
- phone with real touch controls, if a device is available.

Then the owner's human playtest and a short test report. Same constraints as before.

## 2. What was built
1. **`OnboardingRules.spawnChoice(owned, starters)`.**
   - One candidate: spawn it, and it becomes the selection.
   - 2+: open the garage.
   - Empty owned list (data not loaded or unavailable): only the starter Coupe counts, which the server always accepts (`EconomyService.ownsVehicle`).
   - No candidates: nothing is sent.
   - `GarageController.spawnOrChoose` uses it. The old `spawnButtonAction` was removed.
2. **`OnboardingRules.isActiveRobbery(phase)`** (Holding/Escaping). `OnboardingTipController` closes the tip only then, and disconnects its listener.
3. **Duplicate failures.**
   - `RobberyRules.tick` only acts in Holding/Escaping, so once a session is Failed (or Paid) every later failure fact returns nothing. A session fails, and changes the cooldown, at most once; `min()` would make a repeat harmless anyway.
   - Overlapping causes in one tick produce one failure with one reason.
   - The `LastSession` check (previous batch) protects a newer robbery.
   - `RobberyService.failSession` now also returns early for an entry that already ended.
4. **Experimental cooldown.** `RobberyConfig.FailedCooldownSeconds = 90` is labelled EXPERIMENTAL; `nil` restores 180 s.

## 3. How it works
Pure logic is in `OnboardingRules` and `RobberyRules`, covered by specs. The client controllers only call it. No remotes, profile fields or server authority changed.

## 4. Security and authority
- Unchanged. The spawn choice only decides which request the client sends; the server checks ownership, jail, alive state and the rate limit on every spawn.
- The not-loaded case only sends the starter Coupe, which the server accepts for everyone.

## 5. Persistence and data safety
None changed.

## 6. Decisions made
- **Not-loaded state:** send the starter Coupe rather than nothing. The server accepts it, and blocking it would break spawning for players whose data is slow or unavailable (PROGRESS 8k).
- **`PayoutPending` doesn't count as "active"** for the tip: the robbery panel is shown then, but the tip is 15 s long and a payout-pending state that early isn't realistic. Only Holding and Escaping close it, as the audit asked.

## 7. Deviations from the request
- **Phone with real touch controls:** no device or Device Simulator was available to me; it stays on the owner's playtest list.
- **Successful getaway with 180 s live:** both scripted getaways this round were busted, so it is covered by unit tests plus the live start setting 180 s.

## 8. Unresolved risks and known issues
- **Low (found while testing, not new):** pressing Spawn Car while already driving replaces the car but leaves the player standing (PROGRESS 8q). Needs owner approval to fix.
- **Medium:** escape difficulty. The scripted getaways went 0/2 this round (5/5 earlier, different routes), so human playtest data is needed (PROGRESS 8r).
- Previous risks unchanged (marker clutter, cooldown farming, per-session tip).

## 9. Multiplayer status
MULTIPLAYER UNVERIFIED: everything in this batch with more than one player. Nothing cross-server.

## 10. Files for the auditor
AUDITOR_REPORT.md, CHANGE_MANIFEST.md, TEST_EVIDENCE.md, SOURCE_DIFFS.md, AUDITOR_QUESTIONS.md, plus docs PROGRESS.md, ARCHITECTURE.md, TEST_CHECKLIST.md, ROADMAP.md.
