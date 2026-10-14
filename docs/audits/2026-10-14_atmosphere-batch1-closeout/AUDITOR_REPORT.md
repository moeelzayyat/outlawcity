# Auditor report: 2026-10-14_atmosphere-batch1-closeout

- Project: OUTLAW CITY (Roblox, place ID 132163592957463)
- Date: 2026-10-14
- Commit range: `ad37ecd..` the package commit (code `dbceb57`); GitHub `moeelzayyat/outlawcity`, branch `main`
- Prepared by: Claude (sole implementation agent)
- Status: closeout done (solo), awaiting audit. Batch 2 not started.

## 1. What was asked
The Batch 1 closeout (APPROVE WITH CONDITIONS, reference `ad37ecd`):
1. Fix the handling of single `LightBar` parts being removed while `PoliceUnit` stays:
   - no stale flashing target;
   - safe with 0, 1 or 2 bars;
   - at most one PointLight and no duplicate sirens;
   - modifiers restored;
   - model-removal cleanup kept;
   - tested with removal and reinsertion.
2. Resolve the dealership-sign observation (same camera, both lighting configs, repeated captures, loaded/enabled state) and capture a valid highway view.
3. Finish the performance evidence:
   - unthrottled, repeated, both configurations;
   - idle and pursuit FPS, worst frame, memory;
   - resolution, graphics, device, foreground and flags recorded.
4. Keep the scope: siren off, no assets, no police/physics/economy/robbery/jail/anti-cheat changes.
5. Full tests, regressions, commit, push, then stop.

## 2. What was built
- **`AtmosphereController`:**
  - The live bar list is rebuilt from the model on every bar arrival **and removal** (`DescendantRemoving`, which ignores the departing part).
  - A departing bar's `LocalTransparencyModifier` is reset.
  - The single PointLight moves to a live bar, or waits unparented when there are none. It is recreated only if destroyed (tracked with `Destroying`), never duplicated.
  - The siren (if ever enabled) moves with the chassis and is never duplicated.
  - Each frame flashes only bars in the live list.
  - Model-removal cleanup is unchanged, and now also clears the lists.
  - A Studio-only `AtmosphereDebug` attribute on the local player reports units, bars, lights, connections and sirens.
- **`AtmosphereRules.litIndex(phase, barCount)`:** none for 0 bars; one bar blinks; with 2+ bars the phase picks. Tested.

## 3. How it works
See `docs/ARCHITECTURE.md`, section "City atmosphere (Batch 1)". It is client-only; the server-owned unit is untouched.

## 4. Security and authority
No server code, remotes, police AI, pursuit values (130 / 100 / 0.25 / 8), vehicles, physics, robbery, economy, jail or anti-cheat changes. No assets.

## 5. Persistence and data safety
None.

## 6. Decisions made
- **The dealership sign needs no fix.** The missing text reproduces with the **original** lighting on the first capture after a camera jump, and it appears on the next capture in both configurations. The sign is loaded and its SurfaceGui is enabled, so this is a render/capture warm-up, not a Batch 1 regression.
- **Bar streaming was simulated** by un-parenting `LightBar` parts on the client, the same local effect streaming has.

## 7. Deviations from the request
- **Device Simulator / real phone:** NOT TESTED; I can't switch on the simulator from my tools.
- **Pursuit FPS run 3:** in both configurations the unit had despawned partway through that run (busted, or no longer near). Runs 1–2 had the unit present.

## 8. Unresolved risks and known issues
- **Low:** at the 60 fps cap, small cost differences can't be measured. A phone test is still needed.
- **Siren:** still off with no sound ID.
- **Other players seeing the lights:** MULTIPLAYER UNVERIFIED.

## 9. Multiplayer status
Lights as seen by other players and real network streaming of the bars: MULTIPLAYER UNVERIFIED.

## 10. Files for the auditor
This folder: AUDITOR_REPORT, CHANGE_MANIFEST, TEST_EVIDENCE, SOURCE_DIFFS, AUDITOR_QUESTIONS, screenshots/. Plus `docs/PROGRESS.md`, `docs/ARCHITECTURE.md`, and the source under `src/`.
