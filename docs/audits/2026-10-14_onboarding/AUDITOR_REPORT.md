# Auditor report: 2026-10-14_onboarding

- Project: OUTLAW CITY (Roblox, place ID 132163592957463)
- Date: 2026-10-14
- Commit range: `7618566..7371eef` (code `a283809`, docs `7371eef`)
- Prepared by: Claude (primary integration agent)
- Status: awaiting owner approval

## 1. What was asked
Audit 4 verdict: **APPROVE (Part A)**. Then:
- **Small technical follow-up:** `RewardLedger.validate` must reject +infinity and -infinity timestamps as well as NaN. No economy rewrite.
- **Authorized batch, "Simplicity and onboarding":**
  - Implement P1 (one-car direct spawn), P7 (smaller mobile robbery panel with readability and safe-area checks) and P8 (Studio-only first-car / first-robbery / first-escape timings).
  - Then the modified P2 (discreet, distance-aware markers for 24/7 MART and OUTLAW MOTORS), P3 (dismissible first-spawn tip that doesn't block driving) and P4 (an escape hint that accurately explains breaking line of sight and staying hidden until the stars disappear).
  - P5: display the store cooldown; test a 90 s cooldown after failed robberies against the existing behaviour; don't change the successful-robbery cooldown yet.
  - P6: show cash progress toward the $15,000 Muscle; correctly compute the 8 successful robberies needed from $500; don't change the price until human playtests.
- **Constraints:** no new vehicles, police units, robberies, weapons, properties or monetization; one NPC unit; monitor-only vehicle validation; pursuit tuning 130 / 100 / 0.25 and `DecayDelay` 8 unchanged; multiplayer stays MULTIPLAYER UNVERIFIED; preserve economy, purchases, jail and pursuit. Test each change in Studio, record exact results, stop for owner review.

## 2. What was built
- **Ledger:** `RewardLedger.validate` refuses `At = ±math.huge` (`InvalidTime`), with two new test shapes.
- **P1:** the Spawn Car button spawns the car directly when the player owns one; with 2+ cars it opens the garage window. First car is now 1 tap on mobile (was 2).
- **P2:** two small floating labels (190×46 px) over the 24/7 MART and OUTLAW MOTORS signs: name, distance ("150 studs") and a status line. Shown from 35 to 450 studs; hidden when you're already there.
- **P3:** a one-time (per session) tip card at the left under the HUD row: "Rob the 24/7 MART for cash, then escape the police. Buy faster cars at OUTLAW MOTORS. Follow the markers." It closes after 15 s, with its X button, or when a robbery starts. Only the X takes input.
- **P4:** the escape panel now reads "ESCAPE TO KEEP $2,000 / Break line of sight, then stay hidden until your stars are gone", and "Stars fading: stay out of police sight until they're gone" while the server says the player is evading.
- **P5:** the store marker shows "Open: rob the register", "Being robbed" or "Reopens in m:ss"; the register prompt shows "Reopens in m:ss" while cooling down. Trial setting `RobberyConfig.FailedCooldownSeconds = 90`: after a failed robbery the store reopens 90 s after that robbery started; successful robberies keep 180 s.
- **P6:** the dealership window's message line shows "Muscle: $X of $15,000. About N more successful robberies." (8 from $500). Price unchanged.
- **P7:** on screens under 400 px tall the robbery panel is 260×64 at y 92 (title 17 px, detail 14 px) instead of 300×76 at y 136; the HUD uses `CoreUISafeInsets`.
- **P8:** Studio-only `[Milestone] <player> FirstCar|FirstRobbery|FirstEscape <s>s after join`, once each per session.

## 3. How it works
- **Pure logic:** `ReplicatedStorage.Shared.Onboarding.OnboardingRules` holds every new rule: `spawnButtonAction`, `markerVisible`, `formatDistance`, `formatClock`, `storeStatus`, `escapeHint`, `robberiesNeeded`, `progressText`, `robberyPanelLayout`, `newMilestones` and `markMilestone`. The values live in `Shared.Config.OnboardingConfig`. Both are covered by the new `OnboardingRules.spec`.
- **Robbery cooldown:** `RobberyRules.StoreState` gains `LastSession`. `fail(...)` now gets `config`; if `FailedCooldownSeconds` is set and the failing session is still the store's latest, it sets `CooldownUntil = min(CooldownUntil, StartedAt + FailedCooldownSeconds)`. A late failure of an old getaway can't shorten a newer robbery's cooldown.
- **Store status for the client:** `RobberyService.publishStore` writes `RobberyCooldownUntil` (server time; 0 if never robbed) and `RobberyBusy` on the `City.Store` folder. It runs at init, at each start, every 0.25 s robbery tick and when the dev command clears cooldowns. These attributes are display only.
- **Client:**
  - `GarageController.spawnOrChoose` is called by the Spawn Car button in `VehicleHudController`.
  - `WorldMarkerController` (new) draws the markers and sets the register prompt's text locally.
  - `OnboardingTipController` (new) shows the tip.
  - `RobberyHudController` applies the layout and the hint.
  - `DealershipController` shows the progress.
  - `Main.client` boots the two new controllers.
- **Milestones:** `Server.Dev.MilestoneLog.mark(player, name)` is called by `VehicleService` (after seating in a spawned car) and by `RobberyService` (on start and on the robbery escape). It is a no-op unless `RunService:IsStudio()`.

## 4. Security and authority
- No remotes were added or changed, and the client still can't start, finish or pay a robbery, or set a price.
- The spawn shortcut only changes which client request is sent. The server still checks ownership (`NotOwned`), jail, alive state and its rate limit on every `RequestSpawnVehicle`.
- The store attributes are written only by the server. A client changing them locally only changes its own display; `RobberyRules.canStart` on the server decides.
- The prompt's text is changed locally on each client and never replicates.
- MilestoneLog keeps no state and prints nothing outside Studio.

## 5. Persistence and data safety
- No profile, ledger or schema changes, and no migrations.
- The only economy-side code change is the stricter timestamp validation, which refuses malformed rewards before anything is written.

## 6. Decisions made
- **Owner/auditor:** 90 s failed-robbery cooldown as a trial; successful robberies keep 180 s; Muscle price stays $15,000; markers must be discreet; the tip must not block driving.
- **My defaults:**
  - Marker range 35–450 studs. The spawns are 150 and about 240 studs from the store and dealership; 35 hides each marker once you're at the building.
  - Markers draw through buildings (`AlwaysOnTop`) so they point the way. The dealership sign is out of direct sight from 2 of 6 spawns.
  - The tip lasts 15 s and appears once per session, not saved.
  - The compact panel is used below 400 px of screen height.
  - The tip also closes when a robbery starts, so it never overlaps the robbery panel on phones. A layout check found the two would overlap by about 59 px horizontally at y 92.
  - When the store is being robbed, the register prompt keeps its normal text; the server's `StoreBusy` rejection message still explains it.
  - The cooldown trial applies to every failure reason (died, busted, left the store, disconnected, escape timed out).

## 7. Deviations from the request
- **P7 "safe-area check":** I couldn't switch on Studio's Device Simulator from my tools in this session. I cloned the real HUD elements into a 666×374 frame (iPhone 7 landscape inside Roblox's safe area) with the compact layout and measured them, and set `ScreenInsets = CoreUISafeInsets` explicitly. A real-phone check is listed for the owner.
- **P4 evading text:** this wasn't seen live because the single NPC unit kept sight and busted the robber. It is covered by a unit test, and its fit on the phone panel was measured.
- **P5 "successful robbery keeps 180 s":** shown by unit tests and by the live start setting a 180 s cooldown. No successful getaway was run in this batch.

## 8. Unresolved risks and known issues
- **Medium:** first-time-player effect is unmeasured (discovery under 90 s, understanding the escape). It needs the owner's human playtest; the P8 timings now print automatically in Studio.
- **Low:** `AlwaysOnTop` markers show through walls by design. If they feel like clutter in playtests, lower `MarkerMaxDistance` or turn off `AlwaysOnTop`.
- **Low:** the 90 s failed-robbery cooldown could be farmed: deliberately failing early resets the store sooner. A failure still costs 2★ and the police, and pays nothing. Decide after playtests.
- **Low:** milestone times are measured from when the server first saw the player (`os.clock`), not from the client's first frame.
- **Low:** the tip is per session, so a rejoining player sees it again.

## 9. Multiplayer status
MULTIPLAYER UNVERIFIED:
- several players seeing the store marker status at the same time;
- the cooldown trial with different robbers;
- markers and the tip on real phones and other devices.
No cross-server behaviour is involved or claimed.

## 10. Files for the auditor
- AUDITOR_REPORT.md (this file)
- CHANGE_MANIFEST.md
- TEST_EVIDENCE.md
- SOURCE_DIFFS.md (all source diffs in one Markdown file)
- AUDITOR_QUESTIONS.md
- docs: PROGRESS.md, PLAYER_EXPERIENCE_AUDIT.md, ARCHITECTURE.md, TEST_CHECKLIST.md, ROADMAP.md
