# OUTLAW CITY: city atmosphere and audio audit (PLAN ONLY)

Status: **Batch 1 implemented (2026-10-14), awaiting audit**: P-A lighting, P-C flashing lights (siren off until an asset is approved), P-F guardrails. Results in `PROGRESS.md`. P-B, P-D, P-E not started. The original plan follows. Prepared 2026-10-14. This file supersedes `ATMOSPHERE_AUDIO_PLAN.md` (the earlier draft; its measurements are reused here).

**Constraints:**
- Plan only.
- No change to police AI, pursuit tuning (130 / 100 / 0.25, decay delay 8), vehicle physics, the economy or robbery mechanics.
- No new vehicles, stores, weapons, gangs, properties, monetization or police units.
- Vehicle validation stays monitor-only.
- Studio is the source of truth.
- No third-party assets or scripts.
- Lightweight enough for phones.
- Anything other players would see or hear is **MULTIPLAYER UNVERIFIED**.

## 1. How this was inspected
- Read-only queries in Studio. Every query asserted place 132163592957463; other open Studios were never touched.
- A code search of `src/` (Studio and `src/` match by hash as of the last batch).
- `Lighting.Technology` can't be read with my tools (Roblox capability limit). The owner can check it in Lighting's properties; nothing here changes it.

## 2. What exists in Studio today
| Area | Measured |
|---|---|
| Lighting | Roblox template defaults: `ClockTime 14.5` (fixed; no script changes it), `Brightness 3`, `Ambient`/`OutdoorAmbient` grey (70, 70, 70), `GlobalShadows` on, `FogEnd 100000`, `ExposureCompensation 0` |
| Lighting effects | `Sky` (template), `SunRays` 0.01, `Atmosphere` Density 0.30 / Offset 0.25 / Haze 0 / Glare 0, `Bloom` Intensity 1 / Size 24 / Threshold 2, `DepthOfField` **disabled**. No `ColorCorrection` |
| Audio | **No Sound objects anywhere in the place**; `SoundService` empty, `AmbientReverb = NoReverb` |
| Lights | 3 PointLights (jail, store and dealership roofs, range 24–30); no SpotLights or SurfaceLights |
| Cars | Neon headlight and taillight parts with fixed colours (`VehicleFactory`); taillights don't brighten when braking. Driving physics computes forward and lateral (sliding) speed every frame on the driving client (`VehiclePhysics`); the handbrake/DRIFT lowers lateral grip |
| Police unit | Red/blue Neon `LightBar` parts (`PoliceService`), static: no flashing, no light, no sound. The unit exists only while dispatched or chasing |
| Robbery feedback | Text only: toasts ("Alarm tripped!", "Got the cash!", "Escaped! +$2,000"); panel countdown; markers; cash badge updates |
| Roads | 18 road parts; 120 marking parts: yellow centre lines between intersections (12 east–west segments plus north–south), white highway edges and dashes. **No stop lines, crosswalks or intersection cues** |
| Effects | 0 particle emitters, beams or trails. `StreamingEnabled = true`; 257 parts |

## 3. Findings and proposals
Each proposal lists:
- what exists now and what's weak;
- the exact change;
- why it matters to the player;
- difficulty (S/M/L) and performance impact;
- whether an external asset is needed;
- how to test it and roll it back.

All new code would be **client-only** and read state that already exists. Every item gets an on/off flag in one new `AtmosphereConfig`.

### P-A. City lighting and visual consistency
- **Now / weak:** flat grey template lighting at a fixed 14:30; strong bloom washes out Neon lights; low contrast between road, sidewalk and buildings.
- **Change:**
  - `ClockTime` 16.5 (still fixed);
  - `Ambient` (80, 80, 90), `OutdoorAmbient` (120, 115, 110);
  - `Atmosphere` Density 0.32, Haze 1, Glare 0.2;
  - `Bloom` Intensity 1 → 0.4;
  - add `ColorCorrection` with Contrast +0.08 and Saturation +0.12.
- **Why it matters:** cars, the police light bar, markers and roads stand out, so it's easier to read where to go and what's chasing you, and the city looks finished.
- **Difficulty:** S (property values only). **Performance:** negligible; ColorCorrection is a cheap pass, with no new lights or shadows. **External asset:** no.
- **Test:** the same views before and after (plaza, store, dealership, highway) on PC and the phone simulator; the HUD and markers must stay readable; the owner judges by eye. 3D captures render white on this machine.
- **Rollback:** restore the values in section 2 and delete the ColorCorrection.

### P-B. Driving feedback: engine, acceleration, braking and tyres
- **Now / weak:** cars are silent; you can't hear speed, acceleration, braking or sliding; taillights don't react to braking.
- **Change:**
  - **(B1) Engine loop** on each nearby car. Pitch about 0.8 → 1.6 with speed against the car's `MaxForwardSpeed`; the Muscle sounds lower and a bit louder.
  - **(B2) Tyre screech** that fades in while the car is sliding sideways (the chassis's sideways speed over about 15 studs/s) or the handbrake is on. This reads the chassis velocity only and doesn't touch `VehiclePhysics`.
  - **(B3) Brake lights** brighten on the player's own car while braking or reversing. Driven by the local input, so only the driver sees it; showing it to others would need a replicated attribute and is MULTIPLAYER UNVERIFIED, so it isn't proposed now.
- **Why it matters:** speed and grip can be heard, so drivers judge corners better and getaways feel faster. The two cars feel different.
- **Difficulty:** M (one client controller plus tuning). **Performance:** at most 4 cars with sound (own + 3 nearest within 150 studs), with 2 looping sounds each; low.
- **External asset:** yes. One engine loop and one tyre screech, **Roblox-owned Creator Store audio only, each ID approved by the owner**.
- **Test:** drive both cars: the pitch rises with speed; drifting screeches; braking lights the taillights; a parked car goes quiet; FPS is checked on the phone simulator with several cars.
- **Rollback:** the `EngineAudio`, `TyreAudio` and `BrakeLights` flags off, or remove the controller.

### P-C. Police pursuit: siren and chase feedback
- **Now / weak:** a static, silent light bar. The player can't hear how close the police are, which matters because escaping depends on staying out of sight.
- **Change:**
  - The light bar flashes red/blue every 0.25 s.
  - One flashing PointLight (range 14) on the unit.
  - A looping siren (roll-off about 250 studs) while the `NpcVehicles.PoliceUnit` model exists.
  - All client-side; no police AI or server change.
- **Why it matters:** distance can be heard: louder means they're closing, fading means you're getting away. That makes "break line of sight, stay hidden" easy to follow, and the chase becomes the exciting moment.
- **Difficulty:** S. **Performance:** one sound, one flashing light, one unit; low.
- **External asset:** one siren loop, Roblox-owned only, approved by the owner.
- **Test:** rob and get chased; the siren gets louder as the unit closes and fades as it drops back; it stops when the unit despawns (bust or escape); the lights flash.
- **Rollback:** the `Siren` and `PoliceLights` flags off; the server `LightBar` is unchanged.

### P-D. Store robbery: alarm, holdout and payout
- **Now / weak:** text toasts only; the 15 s holdout is silent; the payout is just a number changing.
- **Change:**
  - An alarm bell loops at the register while the store's server attribute `RobberyBusy` is true, so nearby players hear it too (MULTIPLAYER UNVERIFIED).
  - A soft tick each second of the holdout countdown.
  - A "cash" sound plus a short green pulse on the cash badge on the server's `Paid` notice.
  - A short sting on bust (jail).
  - No timing, reward or rule changes.
- **Why it matters:** the robbery becomes an event and the wait feels tense; success and failure are clear without reading.
- **Difficulty:** S. **Performance:** one loop during a holdout plus short one-shots; negligible.
- **External asset:** an alarm loop, a cash sound and a bust sting (the tick can reuse one of them), Roblox-owned only, approved by the owner.
- **Test:** the alarm plays only while holding and stops on hold end or failure; the cash sound plays once per payout; the sting plays on jail.
- **Rollback:** the `RobberyAudio` flag off.

### P-E. Road visibility, intersections and navigation
> **Merged:** stop lines are now planned once, in `STREET_MARKINGS_SIGNS_PLAN.md` (as N5). Crosswalks aren't proposed for now.

- **Now / weak:** centre lines stop at each junction but nothing marks the junction itself; the markers point to the store and dealership, but junctions come up suddenly at speed.
- **Change:**
  - In `CityLayout` (data only), white stop lines on each approach to the 16 grid intersections: up to 64 thin `Markings` slabs, no collision, no queries, no shadows, on the existing road surface.
  - Optional zebra crosswalks at the 4 plaza junctions (about 40 more).
  - No map expansion.
- **Why it matters:** players see junctions coming, turn in time and crash less during chases; the grid reads as a city.
- **Difficulty:** S–M (data plus a `CityLayout.spec` check that markings stay on roads). **Performance:** up to about 104 static anchored parts with shadows off; low.
- **External asset:** no.
- **Test:** `CityLayout.spec` passes; drive the grid on PC and phone, checking visibility and no z-fighting flicker; the police unit's routes are unchanged (markings have no collision or queries).
- **Rollback:** remove the new marking specs; the city is rebuilt from `CityLayout`.

### P-F. Mobile performance guardrails (applies to everything above)
- **Now:** no particles and no sounds; DepthOfField already off; streaming on.
- **Rules:**
  - no particles, beams, trails or extra shadow-casting lights in these batches;
  - DepthOfField stays off;
  - at most 4 cars with audio, 1 siren and 1 alarm at a time;
  - every sound has a roll-off distance;
  - every feature has an off flag.
- **Measurement:** client FPS and the Stats panel on PC and the phone simulator before and after each batch. Turn a feature off if it costs more than about 5% FPS on the phone. The owner checks a real phone.
- **Difficulty:** S. **External asset:** no.

## 4. Top five: highest impact, lowest risk
| Rank | Item | Impact | Risk | Difficulty | Asset |
|---|---|---|---|---|---|
| 1 | **P-C** siren + flashing police lights | High: the escape becomes readable and exciting | Low: client-only, one unit | S | 1 Roblox-owned sound |
| 2 | **P-A** lighting preset | Medium–High: the whole city looks better at once | Very low: property values, instantly reversible | S | none |
| 3 | **P-D** robbery alarm + payout sounds | High: the core loop gets feedback | Low: client-only, existing state | S | 3 Roblox-owned sounds |
| 4 | **P-E** stop lines at intersections | Medium: fewer crashes, clearer navigation | Low: static, non-colliding parts; spec-checked | S–M | none |
| 5 | **P-B** engine/tyre audio + local brake lights | High for driving feel | Medium: tuning, the most sounds, needs FPS checks | M | 2 Roblox-owned sounds |

P-F applies throughout.

## 5. Recommended first batch (small)
**Batch 1 = P-A (lighting preset) + P-C (police lights and siren).**

It's the smallest change that is noticeable in every session. It needs at most one external sound, touches no gameplay, and both parts are quick to undo. If the owner hasn't approved a siren sound ID, Batch 1 ships the flashing lights only, and the siren waits.

**Before starting:** the owner saves a backup (cloud + `OutlawCity_<stage>.rbxl`, checked in the Studio log). The owner approves one Roblox-owned siren asset ID from a short list I provide.

**Acceptance criteria:**
1. **Lighting:**
   - The new values are applied exactly as listed in P-A.
   - The old values are recorded in this file for rollback.
   - The HUD, markers and text are readable on PC and in the 666×374 phone view.
2. **Police lights:** the unit's light bar visibly alternates red/blue about every 0.25 s while the unit exists. No police AI, pursuit values (130 / 100 / 0.25, 8) or server code changed; the unit stays at one.
3. **Siren:**
   - It plays only while the unit exists.
   - It gets louder as the unit approaches and fades with distance (roll-off about 250 studs).
   - It stops within 1 s of the unit despawning.
4. **Off switches:** each part has an off flag in `AtmosphereConfig`. With all flags off, the game looks and plays exactly as before.
5. **Performance:** client FPS on the phone simulator during a chase within about 5% of the pre-batch value (measured both ways and recorded).
6. **Regression:** `[Tests] N passed, 0 failed`; a robbery, chase, bust/jail and payout still behave as before; vehicle validation stays monitor-only.
7. **Records:** results recorded in `PROGRESS.md`, plus an audit package; everything other players see or hear is marked MULTIPLAYER UNVERIFIED.

**Later batches (after review):** P-D, then P-E, then P-B.

## 6. Not proposed
- day/night cycle or weather;
- street lamps across the map;
- new buildings or props;
- particle smoke, skid marks or dust;
- music;
- third-party or paid assets;
- any police, physics, economy or robbery-rule change.
