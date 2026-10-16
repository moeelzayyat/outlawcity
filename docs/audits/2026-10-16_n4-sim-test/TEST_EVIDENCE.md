# Test evidence: 2026-10-16_n4-sim-test

- **Studio:** `Outlaw City (placeId: 132163592957463)`. The Deadzone and one unnamed Studio instance were open and never touched.
- **Device Simulator:** switched on by the owner (**Test → Device**): first iPhone 7 landscape, then iPhone 13 Pro Max landscape.
- **These are simulator results**, rendered by a desktop GPU with simulated screen sizes. They are **not real-phone measurements**. Real phone: NOT TESTED.
- **No signs were built or changed;** no gameplay, lighting or police changes.
- **Test setup:** the Studio-only dev panel was hidden in the test play sessions only. A bounded helper kept Studio in front for the FPS samples.

## Summary against the plan's provisional pass rule
**Rule:** 30 studs fully legible on both devices, with no clipped letters and no HUD overlap; 60 studs recorded.

| Check | iPhone 7 (666 × 374) | iPhone 13 Pro Max (831 × 427) |
|---|---|---|
| 30-stud views, near-corner approaches (blade ~19 studs away) | Avenue name readable; street name barely readable; **cash badge overlaps the avenue blade** | Avenue name clearly readable; street name readable but small; no overlap |
| 30-stud views, far-corner approaches (blade 55–63 studs away) | **Not readable** (~4–5 px) | **Not readable** (~5–6 px) |
| 60-stud views (42–89 studs) | Not readable (3–6 px) | Near-corner just readable at 42 studs (7 px); far-corner not readable |
| Letters clipped by the post | None | None |
| Chase camera, 25 studs out | "C Ave / 2nd St" readable, right of the cash badge | Readable |
| Chase camera, 45 studs out | Sign behind the cash badge | Sign under the cash badge; not readable |
| Indicative idle FPS (simulator) | 59.9 | 60.0 / 60.0 (one earlier 46.0 sample after a camera move) |

**Result: the 30-stud rule is NOT MET.**
- The far-corner views at the 30-stud positions are unreadable on both simulated phones.
- iPhone 7 shows HUD overlap.

**Stage B gate 3 is therefore not satisfied.**

## Distances
"30" and "60" are studs from the junction centre along the incoming lane, as in the plan and the desktop evidence. Because the sign is on one corner, the straight-line distance to the blade depends on the approach:
- 19 or 42 studs on the near-corner side;
- 55–89 studs on the far-corner side.

## Capture limitation
- **Downscaled images:** the capture tool returns downscaled images (450 × 253 for iPhone 7, 667 × 308 for 13 Pro Max).
- **Pixel sizes:** the projected text sizes below come from the camera on the simulated viewport. They are geometric measurements of the rendered layout, used alongside the images.

## Exact outputs
```
STUDIO: Outlaw City (placeId: 132163592957463) id dbcb9667-...; other open: Deadzone, one unnamed instance (never touched)
STAGE B RECHECK (read only):
place now: signs 4, BaseParts 328, CanCollide 114, sign GUIs 16; CityLayout 81f2c85a spec 0443bbeb
== (-100,-300) arms NSWE
  corner (+1,+1) post (-78,-278) walk Block_2_1/Block_2_1/Block_2_1 road 3.80 mark 4.84 solid 60.68 (Building_1_1_2) | OK | vis N 4/4 S 3/4 W 4/4 E 1/4
  corner (+1,-1) post (-78,-322) walk NONE/NONE/NONE road 3.80 mark 4.84 solid 82.84 (Building_1_1_2) | Post off sidewalk; EW off sidewalk; NS off sidewalk | vis N 1/4 S 4/4 W 4/4 E 3/4
  corner (-1,+1) post (-122,-278) walk Block_1_1/Block_1_1/Block_1_1 road 3.80 mark 4.84 solid 15.90 (Building_1_1_2) | OK | vis N 4/4 S 1/4 W 3/4 E 4/4
  corner (-1,-1) post (-122,-322) walk NONE/NONE/NONE road 3.80 mark 4.84 solid 57.66 (Building_1_1_2) | Post off sidewalk; EW off sidewalk; NS off sidewalk | vis N 3/4 S 4/4 W 1/4 E 4/4
== (100,-300) arms NSWE
  corner (+1,+1) post (122,-278) walk Block_3_1/Block_3_1/Block_3_1 road 3.80 mark 4.84 solid 62.99 (Building_2_1_2) | OK | vis N 4/4 S 3/4 W 4/4 E 1/4
  corner (+1,-1) post (122,-322) walk NONE/NONE/NONE road 3.80 mark 4.84 solid 83.02 (Building_2_1_2) | Post off sidewalk; EW off sidewalk; NS off sidewalk | vis N 1/4 S 4/4 W 4/4 E 3/4
  corner (-1,+1) post (78,-278) walk Block_2_1/Block_2_1/Block_2_1 road 3.80 mark 4.84 solid 15.73 (Building_2_1_2) | OK | vis N 4/4 S 1/4 W 3/4 E 4/4
  corner (-1,-1) post (78,-322) walk NONE/NONE/NONE road 3.80 mark 4.84 solid 55.67 (Building_2_1_2) | Post off sidewalk; EW off sidewalk; NS off sidewalk | vis N 3/4 S 4/4 W 1/4 E 4/4
RESULT: identical to the 6031627 measurements (all values match); prior clearance measurements remain valid.
SIMULATOR CHECK 1 (Play, 15:4xZ): viewport 2004x557; TouchEnabled false KeyboardEnabled true MouseEnabled true; 15.4 fps (Studio in background) -> Device Simulator NOT active; no captures taken
SIMULATOR iPhone 7 landscape (owner switched on Test > Device): viewport 666x374; TouchEnabled true; TouchGui true; 60.0 fps at spawn
Test setup in that play session only: DevPanel (Studio-only, never in published servers) disabled for clean captures; first-spawn tip was showing in capture a (covers left-centre) and then closed.
CAPTURE NOTE: screen_capture returns 450x253 images for the 666x374 viewport (downscaled x0.676 by the capture tool), so images understate on-device sharpness; projected sizes below are on the real 666x374 viewport.
PROJECTED TEXT SIZE on the simulated viewport (camera at plan position aimed at the cross-street blade; cap height = 80% of the 1.26-stud text band):
100_100 from N 30: dist 63; text cap height 4.3 px; blade text width 22.9 px
100_100 from N 60: dist 89; text cap height 3.0 px; blade text width 17.8 px
100_100 from W 30: dist 55; text cap height 4.9 px; blade text width 29.8 px
100_100 from W 60: dist 84; text cap height 3.2 px; blade text width 20.1 px
-100_-100 from N 30: dist 19; text cap height 13.9 px; blade text width 39.5 px
-100_-100 from N 60: dist 42; text cap height 6.4 px; blade text width 37.7 px
-100_-100 from E 30: dist 55; text cap height 4.9 px; blade text width 29.8 px
-100_-100 from E 60: dist 84; text cap height 3.2 px; blade text width 20.1 px
100_-100 from S 30: dist 19; text cap height 13.9 px; blade text width 39.5 px
100_-100 from S 60: dist 42; text cap height 6.4 px; blade text width 37.7 px
100_-100 from W 30: dist 55; text cap height 4.9 px; blade text width 29.8 px
100_-100 from W 60: dist 84; text cap height 3.2 px; blade text width 20.1 px
-100_100 from N 30: dist 19; text cap height 13.9 px; blade text width 39.5 px
-100_100 from N 60: dist 42; text cap height 6.4 px; blade text width 37.7 px
-100_100 from E 30: dist 55; text cap height 4.9 px; blade text width 29.8 px
-100_100 from E 60: dist 84; text cap height 3.2 px; blade text width 20.1 px
("30"/"60" = studs from the junction centre along the lane, as in the desktop evidence; "dist" = straight-line to the blade.)
iPhone 7 READ-OUT FROM CAPTURES (450x253 images):
- 100_100 from N 30 (63 studs to blade): sign tiny, names not readable. N60: not readable.
- 100_100 from W 30 (55): "C Ave" a few px, not readable. W60: not readable.
- -100_-100 from N 30 (19): "B Ave" readable; "2nd St" small/angled, barely; the cash badge ($11,400) overlaps the right end of the B Ave blade. N60 (42): names visible as blobs, not readable.
- -100_-100 from E 30 (55): not readable. E60: not readable.
- 100_-100 from S 30 (19): "C Ave" readable but the cash badge covers "e"; "2nd St" small, barely. S60 (42): not readable.
- 100_-100 from W 30 (55): not readable. W60: not readable.
- -100_100 from N 30 (19): "B Ave" readable, cash badge overlaps right end; "3rd St" barely. N60 (42): not readable.
- -100_100 from E 30 (55): not readable. E60: not readable.
- No letter clipped by the post in any view.
CHASE CAMERA (player seated in Muscle, game vehicle camera ~20 behind / ~7 above, car stationary in the incoming lane):
- C Ave heading -Z toward (100,-100), car 45 studs from junction centre: sign at the right edge behind the cash badge; not readable (blob 1792165606854-siqlmp)
- same, car 25 studs out: "C Ave" / "2nd St" readable, right of the cash badge, above the DRIFT button (1792165618587-aqdqlr)
- C Ave heading +Z toward (100,100) (sign on far corner), car 25 studs out: blade projects at (289,131) of 666x374, in the HUD button row (PEACEFUL / SAFE ZONE); not readable (1792165630120-n9vx5o)
iPhone 7 sim idle facing plaza ring (first try, Studio backgrounded): 15.0 fps, worst 68.9 ms -> invalid
iPhone 7 sim idle facing plaza ring (Studio in front): 59.9 fps, worst 48.1 ms, 2597 MB, viewport 666x374  (simulator on a desktop GPU: indicative only)
SIMULATOR iPhone 13 Pro Max landscape (owner switched device): viewport 831x427; TouchEnabled true; captures returned at 667x308
PROJECTED TEXT CAP HEIGHT (831x427):
100_100 from N 30: dist 63; 4.9 px | N 60: dist 89; 3.4 px | W 30: dist 55; 5.6 px | W 60: dist 84; 3.7 px
-100_-100 from N 30: dist 19; 15.9 px | N 60: dist 42; 7.3 px | E 30: dist 55; 5.6 px | E 60: dist 84; 3.7 px
100_-100 from S 30: dist 19; 15.9 px | S 60: dist 42; 7.3 px | W 30: dist 55; 5.6 px | W 60: dist 84; 3.7 px
-100_100 from N 30: dist 19; 15.9 px | N 60: dist 42; 7.3 px | E 30: dist 55; 5.6 px | E 60: dist 84; 3.7 px
13 Pro Max READ-OUT FROM CAPTURES:
- near-corner views at 30 (19 studs to the blade: -100_-100 from N, 100_-100 from S, -100_100 from N): avenue name ("B Ave"/"C Ave") clearly readable; street name ("2nd St"/"3rd St") readable but small; the cash badge sits just below-right of the avenue blade and no longer covers letters.
- near-corner views at 60 (42 studs): "2nd St"/"3rd St" just readable; the avenue blade is edge-on/tiny.
- far-corner views (55-89 studs): not readable.
- No letter clipped by the post.
- Chase camera, C Ave heading -Z toward (100,-100), car 25 studs out: "C Ave" / "2nd St" readable, right of the cash badge, above the DRIFT button. Car 45 studs out: the sign sits directly under the cash badge; "2nd St" tiny, not readable.
13 Pro Max sim idle facing plaza ring (Studio in front): 46.0 fps, worst 68.4 ms, 2737 MB (first sample after a camera move)
repeat 1: 60.0 fps, worst 19.0 ms, 2733 MB
repeat 2: 60.0 fps, worst 18.7 ms, 2733 MB  (simulator on a desktop GPU: indicative only)
```

## Screenshots
- **Files:** `screenshots/i7_*` (iPhone 7) and `screenshots/pm_*` (13 Pro Max).
- **Naming:** `s<junction>_from<approach>_<30|60>` for the planned views, and `chase_*` for the vehicle chase camera.
- **First-spawn tip:** `i7_tipvisible_*` shows it covering the left-centre of the iPhone 7 screen on first spawn.

## Not tested
- A real phone.
- Driving at speed with a human on touch controls.
- Multiplayer.
