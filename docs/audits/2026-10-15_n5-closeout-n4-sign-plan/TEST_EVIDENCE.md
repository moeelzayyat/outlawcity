# Test evidence: 2026-10-15_n5-closeout-n4-sign-plan

- **Studio instance used:** `Outlaw City (placeId: 132163592957463)` (Studio process id 5692, window "Outlaw City - Roblox Studio"). Every Edit script asserted `game.PlaceId`.
- **Lighthouse Keepers Studio** (another process): open and never touched.
- **Code:** no code or gameplay was changed. The only Studio edits were the N5-on/N5-off toggles for the memory test (the same rollback and restore as in the N5 audit, hash-checked). The place was left in the approved N5 state.

## 1. Memory closeout (N5 vs rollback baseline)

### Method
- **Configurations:**
  - **A (N5):** CityLayout `0325d9e6`, spec `6d2a827f`, 50 stop lines, 316 BaseParts / 114 colliding;
  - **B (baseline):** CityLayout `2c85f303`, spec `85bce837`, 0 stop lines, 266 / 114.
  - The City hash of all non-stop-line parts was `6527bae1` in both, checked at every toggle.
- **Fresh play session per run:** Stop → toggle in Edit → Play. Runs alternated B, A, B, A, B, A so slow drift in the Studio process spreads evenly over both configurations.
- **Same state every run:**
  - viewport 2004 × 935, quality Automatic, Batch 1 atmosphere lighting;
  - player teleported to (0, 4, 0) on foot, no car, no wanted level;
  - camera held every frame at (−60, 40, −60) looking at (60, 10, 60), the N5 plaza view;
  - fixed **60 s warm-up**, then 10 one-second samples.
- **What was recorded:**
  - **Client:** `Stats:GetTotalMemoryUsageMb()` (mean, min, max) and `GetMemoryUsageMbForTag` for Instances, PhysicsParts, GraphicsParts, Gui, LuaHeap and Script.
  - **Process:** Studio's working set and private bytes (Windows) right after each sample window.
- **Studio is one process:** in Studio Play the server and client run inside the Studio process, so the "client" total and the process figures both include the server, the edit place and Studio itself. A separate client-only process figure isn't available in Studio.
- **Foreground:** a bounded helper re-activated the Studio window every 2 s during each run, and the foreground window was checked after each run. FPS was recorded for the warm-up and the sample window; a run counts only if both were about 60 fps.

### Valid runs (exact values)
| Run | Config | Client total MB (min–max) | Instances | PhysicsParts | GraphicsParts | Gui | LuaHeap | Script | Process WS / private MB | FPS warm-up / sample |
|---|---|---|---|---|---|---|---|---|---|---|
| 1 | B | 2936 (2936–2936) | 102.8 | 9.3 | 0.9 | 42.2 | 829.7 | 266.8 | 2,934 / 3,810 | 60.0 / 60.0 |
| 2 | A | 2979 (2978–2979) | 102.9 | 9.9 | 0.9 | 39.2 | 849.8 | 266.9 | 2,979 / 3,852 | 60.0 / 60.0 |
| 3 | B | 2963 (2959–2971) | 103.1 | 10.1 | 0.9 | 43.3 | 831.2 | 266.8 | 2,958 / 3,835 | 60.0 / 60.0 |
| 4 | A | 2908 (2907–2909) | 103.0 | 10.7 | 0.9 | 40.5 | 787.8 | 266.8 | 2,908 / 3,779 | 60.0 / 60.0 |
| 5 | B | 2948 (2948–2948) | 103.2 | 11.0 | 0.9 | 41.4 | 830.3 | 266.8 | 2,948 / 3,821 | 60.0 / 60.0 |

### Invalid or incomplete runs (excluded, listed for transparency)
| Attempt | Config | Why excluded | Total MB |
|---|---|---|---|
| a | B | Sample window at 15.0 fps: Studio was in the background (the Claude app was in front) | 2880 |
| b | B | Warm-up 54.5 fps, sample 15.0 fps: focus lost, foreground window "" | 2898 |
| c | A | Warm-up 4.2 fps, sample 0.0 fps: rendering stopped | 3026 |
| d | A | Viewport 1 × 1, 0.0 fps: the Studio game view wasn't rendering. A third Play session also showed 1 × 1 at 0 fps, so the third A run couldn't be taken | 2979 |

### Result: **PARTIAL** (3 valid B runs, 2 valid A runs; a third A run wasn't possible)
| | B (baseline), n = 3 | A (N5), n = 2 |
|---|---|---|
| Client total, mean (range) | 2949 MB (2936–2963) | 2944 MB (2908–2979) |
| LuaHeap, mean (range) | 830.4 (829.7–831.2) | 818.8 (787.8–849.8) |
| Instances tag | 102.8–103.2 | 102.9–103.0 |
| GraphicsParts tag | 0.9 | 0.9 |
| Process working set | 2,934–2,958 MB | 2,908–2,979 MB |

**Interpretation:**
- **No measurable N5 effect.** The mean totals differ by −5 MB (N5 lower). The spread inside each configuration is 27 MB (B) and 71 MB (A), so the difference is well inside run-to-run noise.
- **The Instances tag doesn't separate the configurations.** It rises about 0.1 MB per session in both (102.8 → 103.2), more than any A–B difference. GraphicsParts reads 0.9 in all runs.
- **The variability comes from:**
  - LuaHeap, which swings by up to 62 MB between sessions (787.8–849.8 in A) depending on garbage-collection timing;
  - slow growth of the Studio process across Play sessions (PhysicsParts 9.3 → 11.0 over runs 1–5 in both configurations).
- **The earlier +183 MB** came from comparing a "before" set early in a long session with an "after" set many sessions later. That fits this drift, not the 50 parts.
- **Why it stays PARTIAL:** with n = 2 for N5 and a ±35 MB noise band, this test can rule out a large effect (about ≥ 70 MB) but can't measure a small one. It is not a pass.

## 2. Read-only query for the N4 plan (exact output)
```
StreamingEnabled true TargetRadius n/a MinRadius n/a Integrity n/a ModelStreamingBehavior n/a
Workspace.City.Sidewalks.Block_3_3 gap 0.00 top 0.60 bottom 0.00 collide true
Workspace.City.Roads.RoadNS_100_3 gap 4.00 top 0.20 bottom -0.20 collide true
Workspace.City.Roads.RoadEW_100 gap 4.00 top 0.20 bottom -0.20 collide true
Workspace.City.Markings.StopLine_100_100_S gap 5.06 top 0.25 bottom 0.20 collide false
Rendering QualityLevel Enum.QualityLevel.Automatic EditQualityLevel Enum.QualityLevel.Automatic
Edit viewport 2004 x 935 FOV 70
```
- **Query:** every City part within 12 studs of (122, 122).
- **"n/a":** those streaming properties aren't readable from a script in this Studio build.

## 3. Final state check (after the memory runs)
```
CityLayout 0325d9e6 spec 6d2a827f; BaseParts 316 CanCollide 114 stop lines 50; City hash 6527bae1 | saved state pending: false
```
Play: `[Tests] 211 passed, 0 failed`, `StopLines in play: 50`.

## Automated tests
| Spec | Result |
|---|---|
| Full suite (N5 state, after the memory runs) | `[Tests] 211 passed, 0 failed` |
| Full suite (baseline state) | Not re-run in this task (it was run in the N5 audit: 209 passed) |

## Screenshots
None. No visual change; N4 is a plan.

## Regression checks
Not applicable: no code or gameplay changed. N5 state verified above.

## Not tested
- The third N5 memory run (the Studio game view stopped rendering).
- A memory figure in a brand-new Studio process (I can't restart Studio).
- Phone memory and performance.
- Everything in the N4 plan; nothing was built.
