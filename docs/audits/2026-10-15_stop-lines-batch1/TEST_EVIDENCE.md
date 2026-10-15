# Test evidence: 2026-10-15_stop-lines-batch1

- **Studio instance used:** `Outlaw City (placeId: 132163592957463)` (id `06960279-…`). Every write script asserted `game.PlaceId == 132163592957463`.
- **Lighthouse Keepers:** the Studios were open and never touched.
- **Backup:** `OutlawCity_StopLines1.rbxl`, saved by the owner; Studio log "Place file downloaded" 2026-10-15T19:02:01Z.
- **Machine:** PC 2004×935, quality Automatic, Batch 1 atmosphere lighting on (client).

## 1. Baseline (read only, before any change)
```
scripts: CityLayout 2c85f303 CityLayout.spec 85bce837 CityBuilder c67028a2
BaseParts 266 CanCollide 114; Markings 120; StopLine_ parts 0
City full hash 6527bae1 (263 parts); geometry hash without Building_3_3_1 18af160c
Baseplate colour 62,66,58 texture transparency 1.00
```

## 2. Sources pushed to Studio
Hash-checked: the old hash was asserted before editing, the new one after.
- `CityLayout`: `2c85f303` → `0325d9e6`.
- `CityLayout.spec`: `85bce837` → `4ed480af` → `a5bf549b` → `6d2a827f` (float tolerances).
- `CityBuilder` unchanged (`c67028a2`).
- Studio matches `src/` at `0b4919b` for all three.

## 3. Parts created and counts
Exact output:
```
created 50; BaseParts 316 CanCollide 114; Markings 170; City full hash excl. stop lines 6527bae1 (263 parts, baseline 6527bae1/263); geometry hash 18af160c (baseline 18af160c)
```
- **50 `StopLine_*`, 316 BaseParts, 114 colliding.**
- Every existing City part is unchanged: the full hash covers name, position, size, colour, material and CanCollide.

## 4. Properties and placement, read from the place
Exact output (rows abridged to the summary plus 4 sample rows; all 50 rows had the same gap, inner, outer and clearance values):
```
stop lines 50, props ok 50, issues 0
per intersection: -100,-100:NSWE -100,-300:NSWE -100,100:NSWE -100,300:NWE -300,-100:NSE -300,-300:SE -300,100:NSE -300,300:NE 100,-100:NSWE 100,-300:NSWE 100,100:NSWE 100,300:NWE 300,-100:NSW 300,-300:SW 300,100:NSW 300,300:NW
StopLine_100_100_E c(120.6,91.2) s(1.2,16.4) gap 2.00 inner 0.60 outer 17.00 lineClear 0.20
StopLine_100_100_N c(91.2,79.4) s(16.4,1.2) gap 2.00 inner 0.60 outer 17.00 lineClear 0.20
StopLine_100_100_S c(108.8,120.6) s(16.4,1.2) gap 2.00 inner 0.60 outer 17.00 lineClear 0.20
StopLine_100_100_W c(79.4,108.8) s(1.2,16.4) gap 2.00 inner 0.60 outer 17.00 lineClear 0.20
```
**"props ok"** means each line is:
- Anchored; CanCollide, CanQuery, CanTouch and CastShadow all false;
- top 0.25, thickness 0.05, 16.4 × 1.2;
- colour 235,235,235, SmoothPlastic, Smooth top surface, Transparency 0;
- a plain Part with no children.

**Other checks:**
- Each line lies fully on a road part whose top is 0.2.
- It overlaps no `Line*` marking; the nearest yellow-line edge is 0.20 studs away.
- The near edge is 2.00 studs before the square, on the correct incoming half.
- Inner edge 0.60 from the road axis; outer edge 17.00 (1 stud inside the curb).
- No duplicate names.

**The per-intersection sides match the plan's measured list exactly** (`2026-10-15_markings-signs-plan/TEST_EVIDENCE.md`): 6 four-arm, 6 three-arm, 4 two-arm.

## 5. Automated tests
| Run | Result |
|---|---|
| First playtest after the change | `[Tests] 210 passed, 1 failed`: `StopLine_-300_-300_S length: expected 16.4, got 16.399999618530273` (exact float compare in the new spec) |
| Second | `[Tests] 210 passed, 1 failed`: `StopLine_-300_-300_S: expected 20 ± 0.000001, got 20.000006103515624` |
| After the new spec tests got 1e-4 tolerances | **`[Tests] 211 passed, 0 failed`** |
| Rollback state (old code) | `[Tests] 209 passed, 0 failed` |
| After restore | **`[Tests] 211 passed, 0 failed`** |

The 186-part signature test (`8b66ade9`) passed in every run.

## 6. Drive-over (no bump)
Muscle, real `VehiclePhysics`, scripted waypoint driver at full throttle in the incoming lane. Each window covers ±8 studs along the road around the line.
- **"Plain-road cruise"** is every frame above 30 studs/s outside those windows.
- **"No lines"** is the same drive in the rollback state.

**With stop lines (exact):**
```
eastbound z=100 (5.7 s): plain-road cruise frames 295, chassis Y 1.934..1.981 (range 0.047), max |vY| 2.28
  line at X=-120.6 (car z=108.9): frames 8, speed in 113.7 out 116.0 studs/s, chassis Y 1.957..1.971 (range 0.013), max |vY| 1.81
  line at X=79.4 (car z=108.6): frames 7, speed in 132.2 out 132.7 studs/s, chassis Y 1.958..1.977 (range 0.019), max |vY| 2.01
  line at X=279.4 (car z=108.6): frames 7, speed in 136.2 out 136.3 studs/s, chassis Y 1.969..1.974 (range 0.006), max |vY| 1.78
heading +Z on x=100 (6.6 s): plain-road cruise frames 339, chassis Y 1.940..1.983 (range 0.043), max |vY| 2.18
  line at Z=-320.6 (car x=91.1): frames 10, speed in 95.2 out 100.2 studs/s, chassis Y 1.961..1.969 (range 0.007), max |vY| 1.41
  line at Z=-120.6 (car x=91.4): frames 8, speed in 128.6 out 129.5 studs/s, chassis Y 1.964..1.975 (range 0.011), max |vY| 1.48
  line at Z=79.4 (car x=91.6): frames 7, speed in 135.4 out 135.6 studs/s, chassis Y 1.964..1.975 (range 0.011), max |vY| 1.34
  line at Z=279.4 (car x=91.5): frames 7, speed in 137.0 out 137.0 studs/s, chassis Y 1.971..1.973 (range 0.002), max |vY| 1.30
```
**Without stop lines, same spots (exact):**
```
eastbound z=100 (NO lines) (5.7 s): plain-road cruise frames 295, chassis Y 1.938..1.981 (range 0.043), max |vY| 2.22
  same spot X=-120.6 (car z=108.9): frames 8, speed in 113.6 out 116.0 studs/s, chassis Y 1.966..1.975 (range 0.009), max |vY| 2.05
  same spot X=79.4 (car z=108.6): frames 7, speed in 132.2 out 132.7 studs/s, chassis Y 1.972..1.979 (range 0.008), max |vY| 1.98
  same spot X=279.4 (car z=108.6): frames 7, speed in 136.2 out 136.3 studs/s, chassis Y 1.960..1.968 (range 0.007), max |vY| 1.40
heading +Z on x=100 (NO lines) (6.7 s): plain-road cruise frames 343, chassis Y 1.939..1.981 (range 0.042), max |vY| 2.10
  same spot Z=-320.6 (car x=91.1): frames 10, speed in 95.1 out 100.1 studs/s, chassis Y 1.955..1.969 (range 0.014), max |vY| 1.88
  same spot Z=-120.6 (car x=91.4): frames 7, speed in 128.7 out 129.5 studs/s, chassis Y 1.957..1.971 (range 0.014), max |vY| 1.89
  same spot Z=79.4 (car x=91.6): frames 7, speed in 135.4 out 135.6 studs/s, chassis Y 1.955..1.971 (range 0.016), max |vY| 2.15
  same spot Z=279.4 (car x=91.5): frames 7, speed in 137.0 out 137.0 studs/s, chassis Y 1.973..1.978 (range 0.005), max |vY| 1.41
```
**Result: PASS.**
- Speeds match to 0.1 studs/s with and without lines.
- Height range over a line (0.002–0.019) is within the plain-road range (0.042–0.047) and the no-line range (0.005–0.016).

## 7. Pursuit regression (comparable A/B)
Player on foot at (−60, 4, −100), dev `SetStars 2`, timed until `Busted`. The previous unit had despawned before each run. The dispatch node is chosen by the game.

| Run | With stop lines | Without (rollback state) |
|---|---|---|
| 1 | busted 10.8 s; unit 256 studs away (node G_100_100); closest 14; recoveries 0/0 | busted 12.1 s; 160 studs (G_100_-100); closest 14; 0/0 |
| 2 | 11.1 s; 240 studs (G_-300_-100); 14; 0/0 | 11.3 s; 204 studs (G_-100_-300); 14; 0/0 |
| 3 | 15.7 s; 312 studs (G_-300_100); 14; 0/0 | 14.7 s; 312 studs (G_-300_-300); 14; 0/0 |

**Result: comparable.**
- Bust times track the dispatch distance in both sets (same 312-stud distance: 15.7 s vs 14.7 s, different nodes).
- No soft or hard recoveries in any run.
- Server log for each run: `[Jail] Lighthouse8282 jailed for 12 s in slot 1`, `[Police] BUSTED Lighthouse8282 -> jail`, `[Police] despawn (busted): … softRecoveries=0 hardRecoveries=0 respawns=0`, `[Jail] Lighthouse8282 released`.

## 8. Gameplay regressions (with stop lines)
```
cash 11400
robbery phase Holding
after holdout Escaping; stars 2
outcome after 50 s: jailed=false phase=Escaping cash 11400
spawn Muscle true nil seated Muscle_11752219158
buy Muscle at desk: false AlreadyOwned; cash 11400
```
**Server log:**
- `[Robbery] Lighthouse8282 … started … at Store1`, then `holdout complete; escaping`.
- `[Police] dispatched to Lighthouse8282 from node G_100_300 (428 studs away)`, then `sighted Lighthouse8282 at 71 studs`.
- Then `status: dist=23 … speed=1` repeated: the known storefront stall (PROGRESS 8g, also seen in World Polish Batch 1). It later moved (`dist=64 … speed=20 soft=1`).
- The player was busted and jailed after the 50 s window.

**Jail:** 12 s, then released (4 times, section 7). **Vehicle spawn:** seated. **Dealership:** the desk purchase returned `AlreadyOwned`, cash unchanged.

**Vehicle validation:**
- `observation Teleport (Lighthouse8282, Muscle_11752219158): moved 257 studs in 0.20 s (allowed 69)` and `moved 566 studs in 0.22 s (allowed 74)`, plus 2 `ALERT [monitor-only, no action taken]`.
- Both are my drive test calling `PivotTo` to reach the start positions, not stop lines. Final summary `samples=978 observations=2 alerts=2`.
- No console errors.

## 9. Performance (Studio in front)
Each sample is 8 s idle or 6 s pursuit. The guard waits for a 1 s sample at 55+ fps first; no waits were needed in any run.

| | Before (no stop lines) | After (stop lines) |
|---|---|---|
| Idle 1 | 60.0 fps, worst 24.2 ms, 2771 MB | 60.0 fps, worst 18.6 ms, 2956 MB |
| Idle 2 | 60.0, 18.2 ms, 2771 MB | 60.0, 18.7 ms, 2953 MB |
| Idle 3 | 60.0, 19.6 ms, 2770 MB | 60.0, 19.5 ms, 2953 MB |
| Pursuit 1 | 60.0, 19.0 ms (unit 134 studs) | 60.0, 18.4 ms (unit 150 studs) |
| Pursuit 2 | 60.0, 18.2 ms (347) | 60.0, 19.0 ms (310) |
| Pursuit 3 | 60.0, 18.1 ms (255) | 60.0, 18.8 ms (345) |

- **FPS: PASS on desktop** (all 12 runs at the 60 fps cap).
- **Memory is not comparable:** the same Studio session, several playtests later. The total grows across playtests, so +180 MB isn't attributed to 50 parts.
- **Phone: NOT TESTED.**

## 10. Rollback
I removed the stop-line code from both scripts (asserted to give the exact HEAD hashes) and unparented the 50 parts. Exact output:
```
ROLLED BACK: removed 50 parts; scripts CityLayout 2c85f303 CityLayout.spec 85bce837 CityBuilder c67028a2
BaseParts 266 CanCollide 114; Markings 120
City full hash 6527bae1 (263 parts); geometry hash without Building_3_3_1 18af160c
```
- **This equals the baseline exactly.** `[Tests] 209 passed, 0 failed`; the drive and pursuit "without" data came from this state.
- **Restored:**
  ```
  RESTORED: scripts CityLayout 0325d9e6 spec 6d2a827f; BaseParts 316 CanCollide 114; Markings 170; stop lines 50, stop-line signature f958ecfa; rest of City hash 6527bae1
  ```
  Then `[Tests] 211 passed, 0 failed`.

## Screenshots
Instance `Outlaw City (placeId: 132163592957463)`, Play mode, player at the plaza, Batch 1 atmosphere lighting. Each view was captured twice.

| View (camera → look at) | Before | After |
|---|---|---|
| Plaza crossroads (−60, 40, −60) → (60, 10, 60) | `before_1_plaza_a/b.jpg` | `after_1_plaza_a/b.jpg` |
| 4-arm junction (100, 12, 60) → (100, 0, 100) | `before_2_junction_100_100_a/b.jpg` | `after_2_junction_100_100_a/b.jpg` |
| Corner (−300, 12, −250) → (−300, 0, −300) | `before_3_corner_-300_-300_a/b.jpg` | `after_3_corner_-300_-300_a/b.jpg` |
| Connector junction (100, 12, −420) → (100, 0, −300) | `before_4_connector_100_-300_a/b.jpg` | `after_4_connector_100_-300_a/b.jpg` |

**After captures:**
- A white bar sits on the incoming half of every arm in view: all 4 at (100, 100), 2 at the corner, and the connector junction's arms.
- No flicker against the road or the yellow line (both captures identical). The HUD is readable.
- At the connector view (~100 studs) the lines are thin.

## Not tested
- Phone readability and performance (Device Simulator or a real phone).
- Other players seeing the lines (MULTIPLAYER UNVERIFIED).
- Human driving over the lines (scripted driver only).
