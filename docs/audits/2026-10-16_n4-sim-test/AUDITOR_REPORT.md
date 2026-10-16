# Auditor report: 2026-10-16_n4-sim-test

- Project: OUTLAW CITY (Roblox, place ID 132163592957463)
- Date: 2026-10-16
- Commit range: `03420cb..` the package commit (docs `b836f4c`); GitHub `moeelzayyat/outlawcity`, branch `main`
- Prepared by: Claude (sole implementation agent)
- Status: measurement and documentation only. **No signs built or changed.** Stage B NOT AUTHORIZED.

## 1. What was asked
1. Record the conditional approval of the Stage B plan.
2. Correct the stale PROGRESS date.
3. Connect to the place.
4. Run the Device Simulator test on the four existing signs, on both phone landscape configurations: the documented 30- and 60-stud views plus chase-camera approaches.
5. Report readability, clipped letters, HUD obstruction and indicative FPS, keeping simulator results separate from real-phone results.
6. Recheck the two Stage B corners, read only.

## 2. What was done
- **PROGRESS:**
  - "Last updated 2026-10-14" corrected to 2026-10-16;
  - the conditional approval recorded;
  - the recheck and simulator results recorded, with gate 3 marked NOT MET.
- **`N4_STAGE_B_PLAN.md`:** status updated.
- **Recheck:** both Stage B junctions measured identically to `6031627`, so the clearances remain valid.
- **Simulator test** (the owner switched devices; I ran Play and captured):
  - 16 planned views on each phone;
  - two chase-camera approaches each, plus a third on iPhone 7;
  - indicative FPS.

## 3. Findings
- **Corner geometry:** the readable distance on phones is about 20 studs. The 30-stud-from-centre positions on the far-corner side put the blade 55–63 studs away, where text is 4–6 px tall. This affects every sign, because each junction has one sign on one corner.
- **HUD:** on iPhone 7 the cash badge ($11,400) overlaps the avenue blade in all three readable near-corner views. In the chase camera at 45 studs the sign sits behind it on both phones.
- **Post:** no clipping in any view, so the cantilever works on phones.
- **FPS:** about 60 in the simulator. This is indicative only.

## 4. What this means for Stage B (no change made)
Gate 3 is not met. Plausible next steps, for the owner and the Architect to choose (none started):
1. Larger blades or text, e.g. 10 × 2 studs.
2. A second sign on the opposite corner so every approach has a near-corner sign. This doubles the parts.
3. A HUD change: move or shrink the cash badge on small screens. That touches UI, so it's a separate approval.
4. Accept phone readability only at close range and rely on desktop.

## 5. Not done
- No signs built or changed.
- No UI, lighting, gameplay or police changes.
- Real phone NOT TESTED.
- Multiplayer MULTIPLAYER UNVERIFIED.
