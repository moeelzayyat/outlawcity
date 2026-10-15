# Test evidence: 2026-10-15_markings-signs-plan

- Studio instance used: `Outlaw City (placeId: 132163592957463)`, Edit mode; the query asserted `game.PlaceId`. **Read-only: nothing was changed.**
- Automated tests: not run (no code changed). The last run was `[Tests] 209 passed, 0 failed`.

## Automated tests
| Spec | Result |
|---|---|
| None (plan only) | Not run |

## Read-only query: arms per intersection and sign corners (exact output)
```
arms total 50
(-300,-300) 2: S(+Z) E(+X)
(-300,-100) 3: N(-Z) S(+Z) E(+X)
(-300,100) 3: N(-Z) S(+Z) E(+X)
(-300,300) 2: N(-Z) E(+X)
(-100,-300) 4: N(-Z) S(+Z) W(-X) E(+X)
(-100,-100) 4: N(-Z) S(+Z) W(-X) E(+X)
(-100,100) 4: N(-Z) S(+Z) W(-X) E(+X)
(-100,300) 3: N(-Z) W(-X) E(+X)
(100,-300) 4: N(-Z) S(+Z) W(-X) E(+X)
(100,-100) 4: N(-Z) S(+Z) W(-X) E(+X)
(100,100) 4: N(-Z) S(+Z) W(-X) E(+X)
(100,300) 3: N(-Z) W(-X) E(+X)
(300,-300) 2: S(+Z) W(-X)
(300,-100) 3: N(-Z) S(+Z) W(-X)
(300,100) 3: N(-Z) S(+Z) W(-X)
(300,300) 2: N(-Z) W(-X)
SIGN CORNERS
(-300,-300) -> (-278,-278) on Block_1_1
(-300,-100) -> (-278,-78) on Block_1_2
(-300,100) -> (-278,122) on Block_1_3
(-300,300) -> (-278,278) on Block_1_3
(-100,-300) -> (-78,-278) on Block_2_1
(-100,-100) -> (-78,-122) on Block_2_1
(-100,100) -> (-78,122) on Block_2_3
(-100,300) -> (-78,278) on Block_2_3
(100,-300) -> (122,-278) on Block_3_1
(100,-100) -> (122,-78) on Block_3_2
(100,100) -> (122,122) on Block_3_3
(100,300) -> (122,278) on Block_3_3
(300,-300) -> (278,-278) on Block_3_1
(300,-100) -> (278,-78) on Block_3_2
(300,100) -> (278,122) on Block_3_3
(300,300) -> (278,278) on Block_3_3
connector x=-100 meets highway at z=-492
connector x=100 meets highway at z=-492
```
**Method:**
- An arm counts if a road part continues 10 studs beyond the 36×36 intersection square on that side.
- A sign corner is the first of the 4 quadrants, 22 studs from the centre, that is on a `Sidewalks` block, not on a road, and at least 3 studs from `Buildings`, `Store`, `Dealership` and `VehicleSpawns` parts.

## Screenshots
None (plan).

## Regression checks
Not applicable.

## Not tested
Everything in the plan; it is not implemented.
