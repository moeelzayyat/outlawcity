# Questions for the auditor: 2026-10-15_stop-lines-batch1

Answer each by number.

## Implementation
1. The lines are axis-aligned parts with X and Z sizes swapped for W/E arms (1.2 × 16.4) instead of a rotated 16.4 × 1.2 part. Is that acceptable as "rotated for the approach direction"?
2. The new spec tests use a 1e-4 tolerance because `Vector3` is single precision; the old 186-part signature is unchanged. Acceptable?

## Evidence
1. Is the pursuit A/B (3 runs with lines, 3 in the rollback state, on-foot target, random dispatch node) "comparable" enough, given that no route timings existed before this batch?
2. Is the drive-over with/without comparison at the same 7 spots sufficient for "no bump"?
3. The after memory figures are ~180 MB higher, from the same Studio session after many playtests. Should memory be re-measured in a fresh session, or is it accepted as not attributable?
4. The 2 vehicle-validation Teleport observations came from the test moving the car to its start. Accept as test-induced?

## Next steps (owner decisions)
1. The lines are thin at ~100 studs. Leave as approved (1.2 deep), or plan a deeper line after a phone check?
2. N4 street-name signs: proceed to its own batch, or wait for the phone readability and performance check first?
