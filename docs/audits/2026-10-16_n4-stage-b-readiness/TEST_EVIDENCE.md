# Test evidence: 2026-10-16_n4-stage-b-readiness

- **Studio:** none used. A read-only re-check was attempted, but `list_roblox_studios` returned no connected instances (`{"studios":[]}`). **Nothing was changed.**
- **Automated tests:** not run (no code changed). The last run was `[Tests] 216 passed, 0 failed` (Stage A).

## Recorded inspection used (from `docs/audits/2026-10-16_n4-rollout-readiness/TEST_EVIDENCE.md`, exact lines)
```
== (-100,-300) arms NSWE
  corner (+1,+1) post (-78,-278) walk Block_2_1/Block_2_1/Block_2_1 road 3.80 mark 4.84 solid 60.68 (Buildings/Building_1_1_2) spawn 220.8 | OK | vis N 4/4  S 3/4 [30:angle64]  W 4/4  E 1/4 [30:angle76 edge,45:angle56,60:angle42]
  corner (+1,-1) post (-78,-322) walk NONE/NONE/NONE road 3.80 mark 4.84 solid 82.84 (Buildings/Building_1_1_2) spawn 270.7 | ISSUES: Post not on one sidewalk; EW not on one sidewalk; NS not on one sidewalk | vis N 1/4 [30:angle76 edge,45:angle56,60:angle42]  S 4/4  W 4/4  E 3/4 [30:angle64]
  corner (-1,+1) post (-122,-278) walk Block_1_1/Block_1_1/Block_1_1 road 3.80 mark 4.84 solid 15.90 (Buildings/Building_1_1_2) spawn 231.6 | OK | vis N 4/4  S 1/4 [30:angle76 edge,45:angle56,60:angle42]  W 3/4 [30:angle64]  E 4/4
  corner (-1,-1) post (-122,-322) walk NONE/NONE/NONE road 3.80 mark 4.84 solid 57.66 (Buildings/Building_1_1_2) spawn 280.2 | ISSUES: Post not on one sidewalk; EW not on one sidewalk; NS not on one sidewalk | vis N 3/4 [30:angle64]  S 4/4  W 1/4 [30:angle76 edge,45:angle56,60:angle42]  E 4/4
== (100,-300) arms NSWE
  corner (+1,+1) post (122,-278) walk Block_3_1/Block_3_1/Block_3_1 road 3.80 mark 4.84 solid 62.99 (Buildings/Building_2_1_2) spawn 231.6 | OK | vis N 4/4  S 3/4 [30:angle64]  W 4/4  E 1/4 [30:angle76 edge,45:angle56,60:angle42]
  corner (+1,-1) post (122,-322) walk NONE/NONE/NONE road 3.80 mark 4.84 solid 83.02 (Buildings/Building_2_1_2) spawn 280.2 | ISSUES: Post not on one sidewalk; EW not on one sidewalk; NS not on one sidewalk | vis N 1/4 [30:angle76 edge,45:angle56,60:angle42]  S 4/4  W 4/4  E 3/4 [30:angle64]
  corner (-1,+1) post (78,-278) walk Block_2_1/Block_2_1/Block_2_1 road 3.80 mark 4.84 solid 15.73 (Buildings/Building_2_1_2) spawn 220.8 | OK | vis N 4/4  S 1/4 [30:angle76 edge,45:angle56,60:angle42]  W 3/4 [30:angle64]  E 4/4
  corner (-1,-1) post (78,-322) walk NONE/NONE/NONE road 3.80 mark 4.84 solid 55.67 (Buildings/Building_2_1_2) spawn 270.7 | ISSUES: Post not on one sidewalk; EW not on one sidewalk; NS not on one sidewalk | vis N 3/4 [30:angle64]  S 4/4  W 1/4 [30:angle76 edge,45:angle56,60:angle42]  E 4/4
```
**Validity of the screen:** in Stage A the same geometric screen predicted the weak approach correctly at all three new junctions; rendered views confirmed it.

## Screenshots
None (plan).

## Not tested
- Everything in the plan.
- A fresh Studio re-check (no instance connected).
- Phone simulator.
- Real phone.
- Multiplayer.
