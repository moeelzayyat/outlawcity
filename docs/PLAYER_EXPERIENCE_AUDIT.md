# OUTLAW CITY: five-minute player-experience audit (plan for owner review)

Status: **reviewed; approved items built (solo).** Prepared 2026-10-14 after the auditor's APPROVE WITH CONDITIONS. Audit 4 approved P1, P7 and P8, modified P2–P4, and scoped P5 and P6 (section 6). Results are in `PROGRESS.md`. Police stay at one unit, vehicle validation stays monitor-only, and the experimental pursuit tuning (130 / 100 / 0.25, 8 s decay delay) stays until human playtests.

## How this was measured
- Solo Studio, place 132163592957463 only, on PC and in the iPhone 7 simulator (666×374).
- **Distances and lines of sight:** measured from the 6 civilian spawn pads in Edit mode.
- **HUD counts:** a client script counted the visible, non-transparent HUD elements in the player's screen GUIs (the Studio-only dev panel excluded).
- **Mobile interactions:** counted by clicking through the real HUD with the simulator.
- **Robbery and escape timings:** from the earlier logged runs (config values plus the 10 scripted getaways in PROGRESS.md).
- **Not measured:** real first-time players. That needs the owner's human playtest (section 4).

## 1. What a new player's first five minutes look like now
| Time (solo, player already knows where to go) | What happens |
|---|---|
| 0:00–0:02 | Join; cash data loaded after ~2.0 s (Studio). Spawn in the plaza safe zone. |
| ~0:05 | First car: PC 1 input (V or the button); mobile **2 taps** (Spawn Car → garage → Coupe). |
| ~0:15 | Drive ~150 studs west to the 24/7 MART. **Nothing in the game says it exists or where it is.** |
| ~0:30 | Hold E (or tap) at the register; 2★ + alarm; 15 s holdout standing inside. |
| ~0:50 | Walk out to the car; police dispatched now, from 160–450 studs away. |
| ~1:10–1:30 | Escape: scripted getaways with the tuned police paid in 18–35 s (5/5). +$2,000. |
| 3:00 after the first robbery started | Store cooldown ends (180 s from start, also after a failed robbery). Second robbery possible. |
| 5:00 | At most 2 robberies → about $4,500 from a $500 start. The Muscle ($15,000) is **8 successful robberies** away ($500 + 7 × $2,000 = $14,500 is still short), about 24 minutes at one robbery per 3-minute cooldown. (The first version of this plan said 7; corrected in audit 4.) |

## 2. Findings by area
| Area | Measured now | Problem |
|---|---|---|
| Time to first vehicle | PC: 1 input. Mobile: 2 taps (the garage window opens even when the player owns only the Coupe). Server answers within one round-trip; 3 s spawn cooldown. | Mobile gained a tap in 4C for players with one car. |
| Discovering the first robbery | Store 150 studs (straight line) from the spawns. Its sign (20×4 studs) is in line of sight from all 6 spawns, but small at that distance. The prompt only appears within 10 studs of the register inside. No hint text, marker or objective anywhere. | A new player may never find robberies in 5 minutes. **Biggest gap.** |
| Escaping police | Panel says "ESCAPE THE POLICE / Lose your wanted stars to keep $2,000"; stars blink while evading. Rule underneath: 8 s unseen, then heat decays (70 heat ≈ 11 s). | The panel never says *how* to lose the stars (break line of sight). Scripted runs escape 18–35 s; human data missing. |
| Robbery waiting time | 15 s standing still inside; police arrive 2–5 s after you leave. | 15 s of nothing to do; no feedback besides the countdown. Acceptable but flat. |
| Jail and cooldown frustration | Jail 12 s (+ ~5 s respawn) at the plaza. Store cooldown 180 s from the START, also after a failed robbery. Only one store. | After a bust there is nothing to rob for up to ~2.5 minutes, and the store doesn't show when it reopens (only a rejection message after trying). |
| Finding and understanding the Muscle | Dealership 237 studs from the spawns; its sign is in sight from 4 of 6 spawns. Prompt "Browse cars" at the desk. Buying takes walk + 2 inputs; spawning it later takes 2 taps. Price 7.5× a robbery. | No pointer. The goal ($15,000) is out of reach in a first session and the player isn't shown progress toward it. |
| Mobile HUD clutter | On foot: 5 elements (~8% of the screen). Driving: 9 elements; touch controls ≈ 12% (bottom right); speedometer 3%. Robbery panel adds 300×76 (~9%) at y 136, in the upper middle of a 374-px screen. | Driving view is OK. During a robbery on a phone the panel sits over the upper-centre of the view. |

## 3. Proposed small adjustments (none implemented)
Each change is small, can be undone, and comes with a measurable target.

| # | Change | Size | Target / how to measure |
|---|---|---|---|
| P1 | **One-car shortcut:** if the player owns only one car, Spawn Car spawns it directly. The garage window opens only with 2+ cars. | S | Mobile taps to first car: 2 → **1** (simulator click count). |
| P2 | **Two world markers:** a small floating label above the 24/7 MART ("ROB · 24/7 MART") and above OUTLAW MOTORS ("CARS"), with the distance. Visible up to ~400 studs; hidden inside each building. | S | Playtest: time from spawn to first robbery start **< 90 s** for a first-time player; both labels readable from every spawn (line-of-sight check). |
| P3 | **One-time first-spawn tip (6 s):** "Rob the 24/7 MART for cash · Buy cars at OUTLAW MOTORS". Shown once per session. | S | Playtest: player can say what to do after 30 s (yes/no). |
| P4 | **Escape hint:** the escape panel's second line becomes "Break line of sight: hide 8 s to lose the police", and while evading it shows "Evading…" (the WantedEvading attribute already exists). | S | Playtest: player can explain how escaping works; scripted A/B escape rate unchanged (5/5). |
| P5 | **Store reopen time on the sign:** "Restocking 2:41" under 24/7 MART while cooling down. Owner choice: cooldown 180 s → 120 s, or a shorter cooldown after a *failed* robbery (e.g. 90 s). | S | Idle time after a bust ≤ 2 min; rejections for "robbed recently" drop in playtests. |
| P6 | **Show progress to the Muscle:** the dealership window shows "$4,500 / $15,000" and how many robberies are left. Owner choice on pacing: keep $15,000 (about 21 minutes), or $10,000 (about 13 minutes). | S | First-session player knows their next goal. Owner decides the price. |
| P7 | **Mobile robbery panel position:** move it to just below the top row (y 92, like the garage and dealership windows) and shrink it to 260×60 on screens under 400 px tall. | S | Panel ≤ 7% of the iPhone 7 screen and clear of the screen's centre band. |
| P8 | **Measurement hooks (Studio-only):** log time-to-first-car, time-to-first-robbery and time-to-first-escape per session, so every human playtest produces numbers. | S | Each playtest prints the three timings. |

**Not proposed:**
- more stores or content;
- changes to police count, anti-cheat or the pursuit tuning;
- monetization.

## 4. What the owner's human playtest should check (≈10 minutes)
1. Fresh join on PC and on a phone. How long until you're driving? Did you need help?
2. Without being told: did you notice the store or the dealership? How long did it take?
3. Rob the store and try to escape by driving. Did you understand what to do? How long did it take? Did you get away?
4. Get busted once. How did jail and the store cooldown feel?
5. On the phone: anything covering the view or hard to tap?

## 5. Recommended order (after approval)
1. P1, P7 and P8: mobile fixes and measurement.
2. P2 and P3: discovery.
3. P4: escape clarity.
4. P5 and P6: pacing; needs the owner's numbers.

Then run the owner's human playtest, followed by an audit package.

## 6. What audit 4 approved, and what was built (2026-10-14, solo)
| # | Approved form | Built | Measured |
|---|---|---|---|
| P1 | as proposed | Spawn Car spawns the only owned car; 2+ open the garage | 1 click/tap to the first car (was 2 on mobile) |
| P2 | discreet, distance-aware markers | 190×46 px labels over both signs, 35–450 studs, with distance and status | both shown from the spawn (150 / 220 studs) |
| P3 | dismissible, doesn't block driving | 15 s card at the left under the HUD row; X closes it; also closes when a robbery starts | text fits; only X takes input |
| P4 | accurate line-of-sight explanation | "Break line of sight, then stay hidden until your stars are gone"; "Stars fading…" while evading | matches `WantedRules` (8 s delay, escape at 0 stars) |
| P5 | show the cooldown; trial 90 s after **failed** robberies; success unchanged | marker and register prompt show "Reopens in m:ss"; `FailedCooldownSeconds = 90` | a bust and a walk-out both reopened at start + 90 s; a start still sets 180 s |
| P6 | show progress; 8 robberies from $500; price unchanged | dealership message "Muscle: $X of $15,000. About N more successful robberies." | $11,400 → "About 2"; $500 → 8 (unit test) |
| P7 | smaller panel with readability and safe-area checks | 260×64 at y 92 on screens under 400 px tall; `CoreUISafeInsets`; text ≥ 14 px | 6.7% of 666×374, all texts fit, no overlaps (layout frame, not a real phone) |
| P8 | Studio-only milestones | `[Milestone]` lines for FirstCar, FirstRobbery, FirstEscape | printed once each in Studio |

Still open: the owner's human playtest (section 4) and a real-phone check. The 90 s failed-robbery cooldown and the $15,000 price are decided after that.
