# Auditor report: 2026-10-14_atmosphere-batch1

- Project: OUTLAW CITY (Roblox, place ID 132163592957463)
- Date: 2026-10-14
- Commit range: `9b52d54..af8ae97`, plus the package commit (code `b3ebb00`, docs `af8ae97`); on GitHub `moeelzayyat/outlawcity`, branch `main`
- Prepared by: Claude (sole implementation agent)
- Status: Batch 1 done (solo), awaiting audit. The siren is waiting for owner approval of a sound ID. The FPS after-measurement is partial (see section 8).

## 1. What was asked
The Architect gave APPROVE WITH CONDITIONS, and the owner authorized only Batch 1 of `docs/CITY_ATMOSPHERE_AUDIO_AUDIT.md`:
- P-A: the lighting preset.
- P-C: flashing police lights, with the siren only after the owner approves an exact Roblox-owned sound ID.
- P-F: mobile guardrails.

Required:
- confirm the place ID;
- a recoverable backup, with the old Lighting recorded;
- the lighting reversible;
- P-C client-only, detecting the unit appearing and disappearing, flashing about every 0.25 s, and cleaning up;
- if no siren is approved, list exact IDs and stop for approval;
- independent flags for Lighting, PoliceLights and Siren;
- nothing that hurts phone readability or performance.

Acceptance tests: exact values, a visual review, static vs flashing in a pursuit, siren (if approved), spawn/despawn cycles, flags, FPS/memory before and after, NOT TESTED markings, regressions, constraints.

## 2. What was built
- **`Shared.Config.AtmosphereConfig`:** the flags (`Lighting = true`, `PoliceLights = true`, `Siren = false`), `SirenSoundId = nil`, the preset values, the original values (for the record and rollback), and the police light parameters.
- **`Shared.Atmosphere.AtmosphereRules`** (pure): `flashPhase`, `sirenEnabled` (needs the flag **and** a `rbxassetid://<digits>` ID), and `isPoliceUnit`.
- **`Client.Controllers.AtmosphereController`:** applies the preset to the client's `Lighting` and decorates `NpcVehicles.PoliceUnit`.
- **`Main.client`** boots the controller.
- **`ServerStorage.Tests.AtmosphereRules.spec`:** 5 tests.

## 3. How it works
- **Lighting:**
  - Set on each client only. The place's own Lighting (server and Studio) is unchanged; I checked this on the server during play.
  - Flag off means nothing is applied, which is the original look.
  - The ColorCorrection is a local instance named `OutlawAtmosphere`.
- **Police lights:**
  - When `PoliceUnit` appears in `NpcVehicles`, the controller finds the two `LightBar` parts (and any that stream in later).
  - It alternates them with `LocalTransparencyModifier` every 0.25 s and adds one local `PointLight` (range 14, no shadows) that follows the lit side.
  - On removal (ChildRemoved, ancestry change, or the per-frame parent check), it disconnects everything, destroys the light and resets the modifiers.
  - A model is decorated once at most.
- **Siren:** the code path exists but is gated off. It would be a looped Sound on the chassis with roll-off 250 studs, removed with the unit.

## 4. Security and authority
Client presentation only. No server code, remotes, police AI, pursuit values (130 / 100 / 0.25, decay delay 8), physics, cash, purchases, robbery or jail changes. No assets were inserted.

## 5. Persistence and data safety
None.

## 6. Decisions made
- **Client-side lighting** instead of editing the place's Lighting: the original stays in the place, and rollback is just the flag.
- **The siren is left off.** No sound uploaded by the Roblox account itself was found. The candidates are Roblox's licensed Pro Sound Effects library (9117810961, 9117810647); player uploads were excluded as third-party. The owner hasn't picked one yet.

## 7. Deviations from the request
- **FPS/memory after the change:**
  - The baseline is 60.0 fps idle and in a chase, about 2,714 MB.
  - During the after-tests Studio throttled itself to about 15 fps for everything, including with the lighting set back to the original (14.9 vs 15.2 fps in the same session) and with police lights off (15.3). So the throttle isn't caused by this batch, but a fair after-number at 60 fps still needs Studio in front.
  - Memory was 2,711–2,716 MB both ways.
- **The highway view:** the capture timed out, and some later captures rendered white.

## 8. Unresolved risks and known issues
- **Medium:** the after-FPS comparison is incomplete (see section 7).
- **Low:**
  - In one capture the OUTLAW MOTORS sign text didn't show with the new lighting, but it did in the "before" capture. The sign's SurfaceGui has `LightInfluence = 0`, so lighting shouldn't hide it; streaming or capture timing is more likely. Owner eyeball check.
  - Haze 1 plus Glare 0.2 brightens the horizon. The owner should judge whether it's too hazy.
  - The Device Simulator and a real phone: NOT TESTED.

## 9. Multiplayer status
Other players seeing the flashing lights (each client runs its own controller): MULTIPLAYER UNVERIFIED.

## 10. Files for the auditor
On GitHub at the package commit:
- this folder: AUDITOR_REPORT, CHANGE_MANIFEST, TEST_EVIDENCE, SOURCE_DIFFS, AUDITOR_QUESTIONS, screenshots/;
- `docs/PROGRESS.md`, `docs/ARCHITECTURE.md`, `docs/CITY_ATMOSPHERE_AUDIO_AUDIT.md`, `docs/TEST_CHECKLIST.md`;
- the source under `src/`.
