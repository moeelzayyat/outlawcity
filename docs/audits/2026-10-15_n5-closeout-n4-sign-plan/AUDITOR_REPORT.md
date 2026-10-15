# Auditor report: 2026-10-15_n5-closeout-n4-sign-plan

- Project: OUTLAW CITY (Roblox, place ID 132163592957463)
- Date: 2026-10-15
- Commit range: `832711b..` the package commit (docs `567c07f`); GitHub `moeelzayyat/outlawcity`, branch `main`
- Prepared by: Claude (sole implementation agent)
- Status: documentation and measurement only. **No code, gameplay or geometry changed. No street sign was created.**

## 1. What was asked
The Architect approved N5 with conditions (reviewed `832711b`) and asked for three things:
1. Record the N5 approval in `PROGRESS.md`, without modifying N5.
2. A memory closeout, measurement only:
   - N5 vs the rollback baseline in fresh Studio play sessions, 3 runs each;
   - the same viewport, settings, duration and player state, with a fixed warm-up;
   - client and process memory separately where available, Studio in front;
   - variability explained; PARTIAL if inconclusive.
3. A documentation-only plan for ONE street-name sign. It must cover the location, naming, parts, dimensions, materials, SurfaceGuis, camera views from both directions, readability at 30 and 60 studs, collision, query, touch, shadow and streaming, desktop and phone-simulator acceptance, and rollback.

## 2. What was done
- **PROGRESS.md:** the N5 entry now records APPROVED WITH CONDITIONS with every point the Architect listed:
  - 50 lines; 316 / 114; 211/211;
  - the drive-over and police A/B accepted; desktop FPS accepted;
  - memory PARTIAL (~183 MB, not attributed); phone NOT TESTED; MULTIPLAYER UNVERIFIED.
  - A new N4 entry says the one-sign plan awaits review and nothing is built.
- **Memory closeout:** 5 valid fresh-session runs (3 baseline, 2 N5) alternating B, A, B, A, B, plus 4 excluded attempts with the reasons. **Result PARTIAL:** no measurable N5 effect (−5 MB mean, inside a 27–71 MB within-configuration spread). The third N5 run couldn't be taken because Studio's game view stopped rendering (viewport 1 × 1, 0 fps).
- **`docs/STREET_SIGN_PROTOTYPE_PLAN.md`:** one sign `StreetSign_100_100` at (122, 0.6, 122) on the south-east corner of junction (100, 100), reading "3rd St" / "C Ave".
  - 3 parts (post 0.4 × 10.4 × 0.4, two 7 × 1.5 × 0.2 blades) and 4 SurfaceGuis;
  - all non-colliding, no query, touch or shadow; Atomic model streaming;
  - 8 driver views (2 directions per blade, at 30 and 60 studs);
  - 7 acceptance criteria and rollback.

## 3. How it works
Memory method: `TEST_EVIDENCE.md` §1. Sign design: the plan.

## 4. Security and authority
Not affected.

## 5. Persistence and data safety
None.

## 6. Decisions made
- **Alternating run order (B, A, B, A, …):** the Studio process grows across Play sessions, so alternating spreads that drift across both configurations instead of loading it onto one.
- **Bringing Studio to the front automatically during runs:** the first two attempts lost focus (15 fps), so a bounded helper re-activated the Studio window every 2 s for each run's 100 s. The foreground window was checked after each run.
- **Blade 7 × 1.5 instead of 6 × 1.2:** the readability estimate (plan §5) shows 1.2-stud blades give ~8 px text at 60 studs on desktop. With 1.5, the cap height is about 13 px.
- **Junction (100, 100):** it's next to spawn, on the dealership route, and already an N5 camera view. Its corner is 4 studs from both roads, and no building, store, dealership or spawn pad is within 12 studs (read-only query).

## 7. Risks and limitations
- **Memory stays PARTIAL:**
  - n = 2 for N5;
  - all runs used one long-running Studio process, so a fresh-process comparison wasn't possible (I can't restart Studio);
  - a small effect (a few MB) can't be measured against GC-driven noise of tens of MB.
- **Phone readability at 60 studs** is expected to fail at any sidewalk-sized blade (~5 px on the iPhone 7 simulator). The plan reports it rather than promising it.
- **Phone-simulator measurements** need the owner to switch on Device Simulator.
- **Multiplayer:** MULTIPLAYER UNVERIFIED (streaming of the sign to other players).

## 8. Not done (by instruction)
- No sign was created.
- No other signs, connector–highway joins or new markings.
