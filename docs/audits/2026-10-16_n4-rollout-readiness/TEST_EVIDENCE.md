# Test evidence: 2026-10-16_n4-rollout-readiness

- **Studio instance used:** `Outlaw City (placeId: 132163592957463)`, Edit mode. The query asserted `game.PlaceId`. **Read only: nothing was changed, and no sign was built.** The Lighthouse Keepers Studio was open and never touched.
- **Automated tests:** not run (no code changed). The last run was `[Tests] 215 passed, 0 failed` (cantilever audit).
- **Screenshots:** none (plan). The sightline screen was cross-checked against the approved sign's recorded captures (section 3).

## 1. What the query did
- **Geometry per junction:** for each of the 16 junctions and 4 corners: post at (X ± 22, Z ± 22) and the two 7 × 1.5 × 0.2 blades cantilevered away from the junction (the approved geometry).
- **Footprints and clearances:**
  - "walk": the sidewalk block holding each part's full rectangle, or NONE;
  - "road": nearest road, highway or plaza edge;
  - "mark": nearest marking (stop or centre line);
  - "solid": nearest building, store, dealership, jail or barrier part, with its name;
  - "spawn": nearest vehicle or civilian spawn.
- **Issues:** the corner is rejected if any part isn't fully on one sidewalk, overlaps road or plaza, or is within 3 studs of a solid.
- **Arms:** a road part continues 28 studs from the junction centre on that side.
- **Sightlines ("vis"):** for each incoming approach, the driver's eye is at y 5 in the incoming lane, 30, 45, 60 and 75 studs out. The target is the cross-street blade's centre. A point passes if all three hold:
  - the angle to the driving direction is 40° or less;
  - the face is turned at least 0.3 towards the driver;
  - an unobstructed ray reaches the blade (existing signs excluded).

  Failures are listed as `distance:reason`.

## 2. Exact output
```
== (-300,-300) arms SE
  corner (+1,+1) post (-278,-278) walk Block_1_1/Block_1_1/Block_1_1 road 3.80 mark 4.84 solid 92.21 (Buildings/Building_1_1_2) spawn 319.4 | OK | vis S 3/4 [30:angle64]  E 1/4 [30:angle76 edge,45:angle56,60:angle42]
  corner (+1,-1) post (-278,-322) walk NONE/NONE/NONE road 3.80 mark 4.84 solid 107.58 (Buildings/Building_1_1_2) spawn 351.8 | ISSUES: Post not on one sidewalk; EW not on one sidewalk; NS not on one sidewalk | vis S 4/4  E 3/4 [30:angle64]
  corner (-1,+1) post (-322,-278) walk NONE/NONE/NONE road 3.80 mark 21.40 solid 142.52 (Buildings/Building_1_1_2) spawn 353.0 | ISSUES: Post not on one sidewalk; EW not on one sidewalk; NS not on one sidewalk | vis S 1/4 [30:angle76 edge,45:angle56,60:angle42]  E 4/4
  corner (-1,-1) post (-322,-322) walk NONE/NONE/NONE road 5.37 mark 42.07 solid 153.22 (Buildings/Building_1_1_2) spawn 386.5 | ISSUES: Post not on one sidewalk; EW not on one sidewalk; NS not on one sidewalk | vis S 4/4  E 4/4
== (-300,-100) arms NSE
  corner (+1,+1) post (-278,-78) walk Block_1_2/Block_1_2/Block_1_2 road 3.80 mark 4.84 solid 13.79 (Buildings/Building_1_2_1) spawn 214.9 | OK | vis N 4/4  S 3/4 [30:angle64]  E 1/4 [30:angle76 edge,45:angle56,60:angle42]
  corner (+1,-1) post (-278,-122) walk Block_1_1/Block_1_1/Block_1_1 road 3.80 mark 4.84 solid 62.41 (Buildings/Building_1_2_1) spawn 233.7 | OK | vis N 1/4 [30:angle76 edge,45:angle56,60:angle42]  S 4/4  E 3/4 [30:angle64]
  corner (-1,+1) post (-322,-78) walk NONE/NONE/NONE road 3.80 mark 21.40 solid 53.12 (Buildings/Building_1_2_1) spawn 261.6 | ISSUES: Post not on one sidewalk; EW not on one sidewalk; NS not on one sidewalk | vis N 4/4  S 1/4 [30:angle76 edge,45:angle56,60:angle42]  E 4/4
  corner (-1,-1) post (-322,-122) walk NONE/NONE/NONE road 3.80 mark 4.84 solid 81.02 (Buildings/Building_1_2_1) spawn 278.9 | ISSUES: Post not on one sidewalk; EW not on one sidewalk; NS not on one sidewalk | vis N 3/4 [30:angle64]  S 4/4  E 4/4
== (-300,100) arms NSE
  corner (+1,+1) post (-278,122) walk Block_1_3/Block_1_3/Block_1_3 road 3.80 mark 4.84 solid 11.00 (Buildings/Building_1_3_1) spawn 233.7 | OK | vis N 4/4  S 3/4 [30:angle64]  E 1/4 [30:angle76 edge,45:angle56,60:angle42]
  corner (+1,-1) post (-278,78) walk Block_1_2/Block_1_2/Block_1_2 road 3.80 mark 4.84 solid 54.11 (Buildings/Building_1_3_1) spawn 214.9 | OK | vis N 1/4 [30:angle76 edge,45:angle56,60:angle42]  S 4/4  E 3/4 [30:angle64]
  corner (-1,+1) post (-322,122) walk NONE/NONE/NONE road 3.80 mark 21.40 solid 55.97 (Buildings/Building_1_3_1) spawn 278.9 | ISSUES: Post not on one sidewalk; EW not on one sidewalk; NS not on one sidewalk | vis N 4/4  S 1/4 [30:angle76 edge,45:angle56,60:angle42]  E 4/4
  corner (-1,-1) post (-322,78) walk NONE/NONE/NONE road 3.80 mark 4.84 solid 77.51 (Buildings/Building_1_3_1) spawn 261.6 | ISSUES: Post not on one sidewalk; EW not on one sidewalk; NS not on one sidewalk | vis N 3/4 [30:angle64]  S 4/4  E 4/4
== (-300,300) arms NE
  corner (+1,+1) post (-278,322) walk NONE/NONE/NONE road 3.80 mark 21.40 solid 59.91 (Buildings/Building_1_3_3) spawn 351.8 | ISSUES: Post not on one sidewalk; EW not on one sidewalk; NS not on one sidewalk | vis N 4/4  E 1/4 [30:angle76 edge,45:angle56,60:angle42]
  corner (+1,-1) post (-278,278) walk Block_1_3/Block_1_3/Block_1_3 road 3.80 mark 4.84 solid 17.06 (Buildings/Building_1_3_3) spawn 319.4 | OK | vis N 1/4 [30:angle76 edge,45:angle56,60:angle42]  E 3/4 [30:angle64]
  corner (-1,+1) post (-322,322) walk NONE/NONE/NONE road 5.37 mark 42.07 solid 83.51 (Buildings/Building_1_3_3) spawn 386.5 | ISSUES: Post not on one sidewalk; EW not on one sidewalk; NS not on one sidewalk | vis N 4/4  E 4/4
  corner (-1,-1) post (-322,278) walk NONE/NONE/NONE road 3.80 mark 4.84 solid 59.48 (Buildings/Building_1_3_3) spawn 353.0 | ISSUES: Post not on one sidewalk; EW not on one sidewalk; NS not on one sidewalk | vis N 3/4 [30:angle64]  E 4/4
== (-100,-300) arms NSWE
  corner (+1,+1) post (-78,-278) walk Block_2_1/Block_2_1/Block_2_1 road 3.80 mark 4.84 solid 60.68 (Buildings/Building_1_1_2) spawn 220.8 | OK | vis N 4/4  S 3/4 [30:angle64]  W 4/4  E 1/4 [30:angle76 edge,45:angle56,60:angle42]
  corner (+1,-1) post (-78,-322) walk NONE/NONE/NONE road 3.80 mark 4.84 solid 82.84 (Buildings/Building_1_1_2) spawn 270.7 | ISSUES: Post not on one sidewalk; EW not on one sidewalk; NS not on one sidewalk | vis N 1/4 [30:angle76 edge,45:angle56,60:angle42]  S 4/4  W 4/4  E 3/4 [30:angle64]
  corner (-1,+1) post (-122,-278) walk Block_1_1/Block_1_1/Block_1_1 road 3.80 mark 4.84 solid 15.90 (Buildings/Building_1_1_2) spawn 231.6 | OK | vis N 4/4  S 1/4 [30:angle76 edge,45:angle56,60:angle42]  W 3/4 [30:angle64]  E 4/4
  corner (-1,-1) post (-122,-322) walk NONE/NONE/NONE road 3.80 mark 4.84 solid 57.66 (Buildings/Building_1_1_2) spawn 280.2 | ISSUES: Post not on one sidewalk; EW not on one sidewalk; NS not on one sidewalk | vis N 3/4 [30:angle64]  S 4/4  W 1/4 [30:angle76 edge,45:angle56,60:angle42]  E 4/4
== (-100,-100) arms NSWE
  corner (+1,+1) post (-78,-78) walk NONE/NONE/NONE road -1.00 mark 4.84 solid 39.90 (Store/Area) spawn 36.6 | ISSUES: Post over Plaza; Post not on one sidewalk; EW over Plaza; EW not on one sidewalk; NS over Plaza; NS not on one sidewalk | vis N 4/4  S 3/4 [30:angle64]  W 4/4  E 1/4 [30:angle76 edge,45:angle56,60:angle42]
  corner (+1,-1) post (-78,-122) walk Block_2_1/Block_2_1/Block_2_1 road 3.80 mark 4.84 solid 11.44 (Buildings/Building_2_1_3) spawn 74.2 | OK | vis N 1/4 [30:angle76 edge,45:angle56,60:angle42]  S 4/4  W 4/4  E 3/4 [30:angle64]
  corner (-1,+1) post (-122,-78) walk Block_1_2/Block_1_2/Block_1_2 road 3.80 mark 4.84 solid -1.00 (Store/StoreWallNorth) spawn 79.5 | ISSUES: within 3 of Store/StoreWallNorth (-1.00) | vis N 4/4  S 0/4 [30:angle76 edge,45:angle56 blocked(StoreFrontNorth),60:angle42 blocked(StoreFrontNorth),75: blocked(StoreFrontNorth)]  W 0/4 [30:angle64 blocked(StoreWallNorth),45: blocked(StoreWallNorth),60: blocked(StoreWallNorth),75: blocked(StoreWallNorth)]  E 0/4 [30: blocked(StoreWallNorth),45: blocked(StoreWallNorth),60: blocked(StoreWallNorth),75: blocked(StoreWallNorth)]
  corner (-1,-1) post (-122,-122) walk Block_1_1/Block_1_1/Block_1_1 road 3.80 mark 4.84 solid 14.29 (Buildings/Building_1_1_4) spawn 103.8 | OK | vis N 3/4 [30:angle64]  S 4/4  W 1/4 [30:angle76 edge,45:angle56,60:angle42]  E 4/4
== (-100,100) arms NSWE
  corner (+1,+1) post (-78,122) walk Block_2_3/Block_2_3/Block_2_3 road 3.80 mark 4.84 solid 9.80 (Buildings/Building_2_3_1) spawn 74.2 | OK | vis N 4/4  S 3/4 [30:angle64]  W 4/4  E 1/4 [30:angle76 edge,45:angle56,60:angle42]
  corner (+1,-1) post (-78,78) walk NONE/NONE/NONE road -1.00 mark 4.84 solid 56.15 (Buildings/Building_1_2_4) spawn 36.6 | ISSUES: Post over Plaza; Post not on one sidewalk; EW over Plaza; EW not on one sidewalk; NS over Plaza; NS not on one sidewalk | vis N 1/4 [30:angle76 edge,45:angle56,60:angle42]  S 4/4  W 4/4  E 3/4 [30:angle64]
  corner (-1,+1) post (-122,122) walk Block_1_3/Block_1_3/Block_1_3 road 3.80 mark 4.84 solid 15.73 (Buildings/Building_1_3_2) spawn 103.8 | OK | vis N 4/4  S 1/4 [30:angle76 edge,45:angle56,60:angle42]  W 3/4 [30:angle64]  E 4/4
  corner (-1,-1) post (-122,78) walk Block_1_2/Block_1_2/Block_1_2 road 3.80 mark 4.84 solid 13.03 (Buildings/Building_1_2_4) spawn 79.5 | OK | vis N 3/4 [30:angle64]  S 4/4  W 1/4 [30:angle76 edge,45:angle56,60:angle42]  E 4/4
== (-100,300) arms NWE
  corner (+1,+1) post (-78,322) walk NONE/NONE/NONE road 3.80 mark 21.40 solid 61.76 (Buildings/Building_2_3_3) spawn 270.7 | ISSUES: Post not on one sidewalk; EW not on one sidewalk; NS not on one sidewalk | vis N 4/4  W 4/4  E 1/4 [30:angle76 edge,45:angle56,60:angle42]
  corner (+1,-1) post (-78,278) walk Block_2_3/Block_2_3/Block_2_3 road 3.80 mark 4.84 solid 19.79 (Buildings/Building_2_3_3) spawn 220.8 | OK | vis N 1/4 [30:angle76 edge,45:angle56,60:angle42]  W 4/4  E 3/4 [30:angle64]
  corner (-1,+1) post (-122,322) walk NONE/NONE/NONE road 3.80 mark 4.84 solid 86.34 (Buildings/Building_2_3_3) spawn 280.2 | ISSUES: Post not on one sidewalk; EW not on one sidewalk; NS not on one sidewalk | vis N 4/4  W 3/4 [30:angle64]  E 4/4
  corner (-1,-1) post (-122,278) walk Block_1_3/Block_1_3/Block_1_3 road 3.80 mark 4.84 solid 62.18 (Buildings/Building_2_3_3) spawn 231.6 | OK | vis N 3/4 [30:angle64]  W 1/4 [30:angle76 edge,45:angle56,60:angle42]  E 4/4
== (100,-300) arms NSWE
  corner (+1,+1) post (122,-278) walk Block_3_1/Block_3_1/Block_3_1 road 3.80 mark 4.84 solid 62.99 (Buildings/Building_2_1_2) spawn 231.6 | OK | vis N 4/4  S 3/4 [30:angle64]  W 4/4  E 1/4 [30:angle76 edge,45:angle56,60:angle42]
  corner (+1,-1) post (122,-322) walk NONE/NONE/NONE road 3.80 mark 4.84 solid 83.02 (Buildings/Building_2_1_2) spawn 280.2 | ISSUES: Post not on one sidewalk; EW not on one sidewalk; NS not on one sidewalk | vis N 1/4 [30:angle76 edge,45:angle56,60:angle42]  S 4/4  W 4/4  E 3/4 [30:angle64]
  corner (-1,+1) post (78,-278) walk Block_2_1/Block_2_1/Block_2_1 road 3.80 mark 4.84 solid 15.73 (Buildings/Building_2_1_2) spawn 220.8 | OK | vis N 4/4  S 1/4 [30:angle76 edge,45:angle56,60:angle42]  W 3/4 [30:angle64]  E 4/4
  corner (-1,-1) post (78,-322) walk NONE/NONE/NONE road 3.80 mark 4.84 solid 55.67 (Buildings/Building_2_1_2) spawn 270.7 | ISSUES: Post not on one sidewalk; EW not on one sidewalk; NS not on one sidewalk | vis N 3/4 [30:angle64]  S 4/4  W 1/4 [30:angle76 edge,45:angle56,60:angle42]  E 4/4
== (100,-100) arms NSWE
  corner (+1,+1) post (122,-78) walk Block_3_2/Block_3_2/Block_3_2 road 3.80 mark 4.84 solid 10.90 (Buildings/Building_3_2_1) spawn 79.5 | OK | vis N 4/4  S 3/4 [30:angle64]  W 4/4  E 1/4 [30:angle76 edge,45:angle56,60:angle42]
  corner (+1,-1) post (122,-122) walk Block_3_1/Block_3_1/Block_3_1 road 3.80 mark 4.84 solid 17.53 (Buildings/Building_3_1_3) spawn 103.8 | OK | vis N 1/4 [30:angle76 edge,45:angle56,60:angle42]  S 4/4  W 4/4  E 3/4 [30:angle64]
  corner (-1,+1) post (78,-78) walk NONE/NONE/NONE road -1.00 mark 4.84 solid 51.29 (Buildings/Building_2_1_4) spawn 36.6 | ISSUES: Post over Plaza; Post not on one sidewalk; EW over Plaza; EW not on one sidewalk; NS over Plaza; NS not on one sidewalk | vis N 4/4  S 1/4 [30:angle76 edge,45:angle56,60:angle42]  W 3/4 [30:angle64]  E 4/4
  corner (-1,-1) post (78,-122) walk Block_2_1/Block_2_1/Block_2_1 road 3.80 mark 4.84 solid 9.34 (Buildings/Building_2_1_4) spawn 74.2 | OK | vis N 3/4 [30:angle64]  S 4/4  W 1/4 [30:angle76 edge,45:angle56,60:angle42]  E 4/4
== (100,100) arms NSWE
  corner (+1,+1) post (122,122) walk Block_3_3/Block_3_3/Block_3_3 road 3.80 mark 4.84 solid 14.33 (Buildings/Building_3_3_1) spawn 103.8 | OK | vis N 4/4  S 3/4 [30:angle64]  W 4/4  E 1/4 [30:angle76 edge,45:angle56,60:angle42]
  corner (+1,-1) post (122,78) walk Block_3_2/Block_3_2/Block_3_2 road 3.80 mark 4.84 solid 6.40 (Buildings/Building_3_2_3) spawn 79.5 | OK | vis N 1/4 [30:angle76 edge,45:angle56,60:angle42]  S 4/4  W 4/4  E 3/4 [30:angle64]
  corner (-1,+1) post (78,122) walk Block_2_3/Block_2_3/Block_2_3 road 3.80 mark 4.84 solid 10.05 (Buildings/Building_2_3_2) spawn 74.2 | OK | vis N 4/4  S 1/4 [30:angle76 edge,45:angle56,60:angle42]  W 3/4 [30:angle64]  E 4/4
  corner (-1,-1) post (78,78) walk NONE/NONE/NONE road -1.00 mark 4.84 solid 50.40 (Buildings/Building_3_2_3) spawn 36.6 | ISSUES: Post over Plaza; Post not on one sidewalk; EW over Plaza; EW not on one sidewalk; NS over Plaza; NS not on one sidewalk | vis N 3/4 [30:angle64]  S 4/4  W 1/4 [30:angle76 edge,45:angle56,60:angle42]  E 4/4
== (100,300) arms NWE
  corner (+1,+1) post (122,322) walk NONE/NONE/NONE road 3.80 mark 21.40 solid 51.90 (Buildings/Building_3_3_3) spawn 280.2 | ISSUES: Post not on one sidewalk; EW not on one sidewalk; NS not on one sidewalk | vis N 4/4  W 4/4  E 1/4 [30:angle76 edge,45:angle56,60:angle42]
  corner (+1,-1) post (122,278) walk Block_3_3/Block_3_3/Block_3_3 road 3.80 mark 4.84 solid 6.45 (Buildings/Building_3_3_3) spawn 231.6 | OK | vis N 1/4 [30:angle76 edge,45:angle56,60:angle42]  W 4/4  E 3/4 [30:angle64]
  corner (-1,+1) post (78,322) walk NONE/NONE/NONE road 3.80 mark 4.84 solid 61.46 (Buildings/Building_2_3_4) spawn 270.7 | ISSUES: Post not on one sidewalk; EW not on one sidewalk; NS not on one sidewalk | vis N 4/4  W 3/4 [30:angle64]  E 4/4
  corner (-1,-1) post (78,278) walk Block_2_3/Block_2_3/Block_2_3 road 3.80 mark 4.84 solid 18.25 (Buildings/Building_2_3_4) spawn 220.8 | OK | vis N 3/4 [30:angle64]  W 1/4 [30:angle76 edge,45:angle56,60:angle42]  E 4/4
== (300,-300) arms SW
  corner (+1,+1) post (322,-278) walk NONE/NONE/NONE road 3.80 mark 4.84 solid 52.41 (Buildings/Building_3_1_2) spawn 353.0 | ISSUES: Post not on one sidewalk; EW not on one sidewalk; NS not on one sidewalk | vis S 3/4 [30:angle64]  W 4/4
  corner (+1,-1) post (322,-322) walk NONE/NONE/NONE road 5.37 mark 42.07 solid 73.61 (Buildings/Building_3_1_2) spawn 386.5 | ISSUES: Post not on one sidewalk; EW not on one sidewalk; NS not on one sidewalk | vis S 4/4  W 4/4
  corner (-1,+1) post (278,-278) walk Block_3_1/Block_3_1/Block_3_1 road 3.80 mark 4.84 solid 8.01 (Buildings/Building_3_1_2) spawn 319.4 | OK | vis S 1/4 [30:angle76 edge,45:angle56,60:angle42]  W 3/4 [30:angle64]
  corner (-1,-1) post (278,-322) walk NONE/NONE/NONE road 3.80 mark 21.40 solid 51.92 (Buildings/Building_3_1_2) spawn 351.8 | ISSUES: Post not on one sidewalk; EW not on one sidewalk; NS not on one sidewalk | vis S 4/4  W 1/4 [30:angle76 edge,45:angle56,60:angle42]
== (300,-100) arms NSW
  corner (+1,+1) post (322,-78) walk NONE/NONE/NONE road 3.80 mark 4.84 solid 54.47 (Buildings/Building_3_2_2) spawn 261.6 | ISSUES: Post not on one sidewalk; EW not on one sidewalk; NS not on one sidewalk | vis N 4/4  S 3/4 [30:angle64]  W 4/4
  corner (+1,-1) post (322,-122) walk NONE/NONE/NONE road 3.80 mark 21.40 solid 51.45 (Buildings/Building_3_1_4) spawn 278.9 | ISSUES: Post not on one sidewalk; EW not on one sidewalk; NS not on one sidewalk | vis N 1/4 [30:angle76 edge,45:angle56,60:angle42]  S 4/4  W 4/4
  corner (-1,+1) post (278,-78) walk Block_3_2/Block_3_2/Block_3_2 road 3.80 mark 4.84 solid 10.44 (Buildings/Building_3_2_2) spawn 214.9 | OK | vis N 4/4  S 1/4 [30:angle76 edge,45:angle56,60:angle42]  W 3/4 [30:angle64]
  corner (-1,-1) post (278,-122) walk Block_3_1/Block_3_1/Block_3_1 road 3.80 mark 4.84 solid 7.75 (Buildings/Building_3_1_4) spawn 233.7 | OK | vis N 3/4 [30:angle64]  S 4/4  W 1/4 [30:angle76 edge,45:angle56,60:angle42]
== (300,100) arms NSW
  corner (+1,+1) post (322,122) walk NONE/NONE/NONE road 3.80 mark 4.84 solid 75.75 (Buildings/Building_3_2_4) spawn 278.9 | ISSUES: Post not on one sidewalk; EW not on one sidewalk; NS not on one sidewalk | vis N 4/4  S 3/4 [30:angle64]  W 4/4
  corner (+1,-1) post (322,78) walk NONE/NONE/NONE road 3.80 mark 21.40 solid 52.54 (Buildings/Building_3_2_4) spawn 261.6 | ISSUES: Post not on one sidewalk; EW not on one sidewalk; NS not on one sidewalk | vis N 1/4 [30:angle76 edge,45:angle56,60:angle42]  S 4/4  W 4/4
  corner (-1,+1) post (278,122) walk Block_3_3/Block_3_3/Block_3_3 road 3.80 mark 4.84 solid 49.80 (Dealership/DealerWallEast) spawn 233.7 | OK | vis N 4/4  S 1/4 [30:angle76 edge,45:angle56,60:angle42]  W 3/4 [30:angle64]
  corner (-1,-1) post (278,78) walk Block_3_2/Block_3_2/Block_3_2 road 3.80 mark 4.84 solid 9.22 (Buildings/Building_3_2_4) spawn 214.9 | OK | vis N 3/4 [30:angle64]  S 4/4  W 1/4 [30:angle76 edge,45:angle56,60:angle42]
== (300,300) arms NW
  corner (+1,+1) post (322,322) walk NONE/NONE/NONE road 5.37 mark 42.07 solid 80.01 (Buildings/Building_3_3_4) spawn 386.5 | ISSUES: Post not on one sidewalk; EW not on one sidewalk; NS not on one sidewalk | vis N 4/4  W 4/4
  corner (+1,-1) post (322,278) walk NONE/NONE/NONE road 3.80 mark 21.40 solid 58.52 (Buildings/Building_3_3_4) spawn 353.0 | ISSUES: Post not on one sidewalk; EW not on one sidewalk; NS not on one sidewalk | vis N 1/4 [30:angle76 edge,45:angle56,60:angle42]  W 4/4
  corner (-1,+1) post (278,322) walk NONE/NONE/NONE road 3.80 mark 4.84 solid 55.38 (Buildings/Building_3_3_4) spawn 351.8 | ISSUES: Post not on one sidewalk; EW not on one sidewalk; NS not on one sidewalk | vis N 4/4  W 3/4 [30:angle64]
  corner (-1,-1) post (278,278) walk Block_3_3/Block_3_3/Block_3_3 road 3.80 mark 4.84 solid 13.12 (Buildings/Building_3_3_4) spawn 319.4 | OK | vis N 3/4 [30:angle64]  W 1/4 [30:angle76 edge,45:angle56,60:angle42]
```
**Notes:**
- `road -1.00` means the footprint overlaps the plaza or road.
- `solid -1.00` means it overlaps the store.
- The arm list totals 50 approaches and matches the N5 measurement.

## 3. Cross-check of the sightline screen
For the approved sign (100, 100) corner (+,+) the screen gives `N 4/4 S 3/4 W 4/4 E 1/4`. That agrees with the recorded captures in `2026-10-16_n4-sign-cantilever`:
- **From the north:** readable (P5, P6, A3).
- **From the south:** readable at 30 and 60 (P7, P8). At the stop line the blade is partly out of frame (A4), which matches 3/4.
- **From the west:** readable (P1, P2, A1).
- **From the east:** the sign is out of view at the stop line (A2) and only readable from 30–60 studs back at an angle (P3, P4). That matches the low score.

## 4. Summary counts
- **Corners:** 64 checked; 31 fit; 33 rejected (28 off-grid, 4 on the plaza, 1 overlapping the 24/7 MART).
- **Junctions:** every one has at least one fitting corner. The four 2-arm grid corners have only one each.

## Not tested
- Everything in the plan (nothing is built).
- Rendered captures of candidate positions; the sightline screen is geometric.
- Phone readability.
- Multiplayer.
