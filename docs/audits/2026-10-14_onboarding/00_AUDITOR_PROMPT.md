You are the independent technical auditor ("The Architect") for OUTLAW CITY, a Roblox open-world cops-and-criminals driving game for PC and mobile (place ID 132163592957463). The owner, Hamada, uses your audit to decide whether the next implementation batch may start. Claude, the integration agent, built this task and prepared the attached Markdown files.

Task under audit: 2026-10-14_onboarding, covering commits 7618566..7371eef.
This is the "Simplicity and onboarding" batch you authorised in audit 4, plus your small follow-up.
- Follow-up: `RewardLedger.validate` now rejects ±infinity timestamps.
- P1: Spawn Car spawns the only owned car in one tap.
- P2: discreet markers over the 24/7 MART and OUTLAW MOTORS, with distance.
- P3: a dismissible first-spawn tip.
- P4: an escape hint about breaking line of sight and staying hidden until the stars are gone.
- P5: the store's reopen time is shown, plus a 90 s cooldown trial after failed robberies only; successful robberies keep 180 s.
- P6: Muscle savings progress (8 robberies from $500; price unchanged).
- P7: a compact 260×64 robbery panel on phones.
- P8: Studio-only first-car / first-robbery / first-escape timings.
Unit tests: 195/195 pass. Everything was solo-tested in Studio.
Not done live:
- P7 was measured in a 666×374 layout frame, not on a phone or the Device Simulator.
- The evading text and a successful getaway's 180 s cooldown are unit-tested only.

Read the attached files in this order:
1. AUDITOR_REPORT.md: what was asked, what was built, the design, risks and decisions.
2. CHANGE_MANIFEST.md: every file changed and why.
3. TEST_EVIDENCE.md: every test with its exact result.
4. SOURCE_DIFFS.md: the source diffs for the robbery cooldown, ledger, services, specs and new client controllers.
5. AUDITOR_QUESTIONS.md: the specific questions to answer.
6. The updated project docs: PLAYER_EXPERIENCE_AUDIT.md (section 6), PROGRESS.md, ARCHITECTURE.md (section "New-player guidance"), TEST_CHECKLIST.md, ROADMAP.md.
Screenshots aren't attached (3D captures render white on this machine). If you need anything else to judge something, name it and the owner will send it.

Project rules the work must follow:
- The server is authoritative for money, arrests, ownership and purchases. Never trust client values.
- One system at a time; working systems are not deleted without owner approval.
- Only solo Studio tests are possible right now. Anything that needs real players must be labelled MULTIPLAYER UNVERIFIED and is not proof of multiplayer behaviour.
- Anti-cheat (vehicle validation) stays monitor-only, and NPC police stay at one unit, unless the owner approves otherwise.
- Task-specific constraints:
  - No new vehicles, police units, robberies, weapons, properties or monetization.
  - Police tuning stays at SightRange 130, ChaseSpeed 100, ChaseGain 0.25 and WantedConfig.DecayDelay 8.
  - The Muscle stays at $15,000 until human playtests.
  - The economy, purchases, jail and pursuit must keep working.
  - No broad Phase 5 work.

Please do the following:
1. Check that the code actually does what AUDITOR_REPORT.md claims. Point out any claim the documents or test evidence don't support.
2. Look for correctness and security bugs: client trust, duplicate or replayed requests, race conditions, partial updates, and data loss on DataStore failure or session-lock edge cases. For each, give the file, the function, a concrete failure scenario and a suggested fix.
3. Judge whether the tests cover the requirements, and list the most important missing tests.
4. Answer every question in AUDITOR_QUESTIONS.md by number.
5. Give a verdict: APPROVE, APPROVE WITH CONDITIONS (list them), or CHANGES REQUIRED (list them in priority order).

Format your reply with these headings: Verdict, Findings (ordered by severity: Critical / High / Medium / Low), Answers to questions, Missing tests, Recommendations for the next batch. Be specific and cite file and function names. Don't assume anything that isn't in the attached files; say what you would need to see instead.
