You are the independent technical auditor ("The Architect") for OUTLAW CITY, a Roblox open-world cops-and-criminals driving game for PC and mobile (place ID 132163592957463). The owner, Hamada, uses your audit to decide whether the next implementation batch may start. Claude, the integration agent, built this task and prepared the attached Markdown files.

Task under audit: 2026-10-14_phase-4B-followup-and-4C, covering commits 4ed77f3..5bdb1c9.

The task has two parts.

The first is a follow-up to the store robbery:
- Robbery rewards are recoverable. A robbery can't start unless cash data is loaded. A reward that fails temporarily stays pending under a fixed transaction id and is paid once later. A profile whose save on leave fails is kept and retried.
- The single NPC police unit is now only sent when the 15 s holdout ends.
- The driving-getaway test did not pass: 0 paid escapes in 13 attempts.

The second is Phase 4C:
- One dealership.
- A second car, the Muscle, for $15,000.
- A server-authoritative purchase remote.
- Vehicle ownership persisted in a version-2 player profile, with in-load migration from cash-only version-1 records.
- A garage menu, and spawning restricted to owned cars.

Read the attached files in this order:
1. AUDITOR_REPORT.md: what was asked, what was built, the design, risks and decisions.
2. CHANGE_MANIFEST.md: every file changed and why.
3. TEST_EVIDENCE.md: every test with its exact result.
4. AUDITOR_QUESTIONS.md: the specific questions to answer.
5. The updated project docs: ARCHITECTURE.md, PROGRESS.md, ROADMAP.md, TEST_CHECKLIST.md and MULTIPLAYER_TESTS.md.
Source diffs and screenshots aren't attached. If you need a specific file's code or a screenshot to judge something, name it and the owner will send it.

Project rules the work must follow:
- The server is authoritative for money, arrests, ownership and purchases. Never trust client values.
- One system at a time; working systems are not deleted without owner approval.
- Only solo Studio tests are possible right now. Anything that needs real players must be labelled MULTIPLAYER UNVERIFIED and is not proof of multiplayer behaviour.
- Anti-cheat (vehicle validation) stays monitor-only, and NPC police stay at one unit, unless the owner approves otherwise.
- For this task, the owner also required:
  - purchases validated on the server, with client prices and ownership never trusted;
  - duplicate purchase requests rejected;
  - cash deduction and ownership updated atomically in the player profile, so cash is never lost without the car and the car never granted without payment;
  - DataStore failures, session locks and disconnections handled safely;
  - safe migration from the cash-only profile;
  - no additional vehicles, banks, property, gangs, weapons or monetization.

Please do the following:
1. Check that the code actually does what AUDITOR_REPORT.md claims. Point out any claim the documents or test evidence don't support.
2. Look for correctness and security bugs: client trust, duplicate or replayed requests, race conditions, partial updates, and data loss on DataStore failure or session-lock edge cases. Pay special attention to EconomyRules.purchaseVehicle, EconomyRules.validateSaved (the migration), ProfileStore, the orphan saves in EconomyService, DealershipService, the ownership check in VehicleService, and the pending payouts in RobberyService. For each problem, give the file, the function, a concrete failure scenario and a suggested fix.
3. Judge whether the tests cover the requirements, and list the most important missing tests.
4. Answer every question in AUDITOR_QUESTIONS.md by number, including the police pursuit tuning recommendation for the failed getaway test.
5. Give a verdict: APPROVE, APPROVE WITH CONDITIONS (list them), or CHANGES REQUIRED (list them in priority order).

Format your reply with these headings: Verdict, Findings (ordered by severity: Critical / High / Medium / Low), Answers to questions, Missing tests, Recommendations for the next batch. Be specific and cite file and function names. Don't assume anything that isn't in the attached files; say what you would need to see instead.
