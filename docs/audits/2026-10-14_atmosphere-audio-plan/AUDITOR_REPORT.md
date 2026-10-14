# Auditor report: 2026-10-14_atmosphere-audio-plan

- Project: OUTLAW CITY (Roblox, place ID 132163592957463)
- Date: 2026-10-14
- Commit range: `dabaf48..5763160` (docs only)
- Prepared by: Claude (primary integration agent)
- Status: **plan only**, awaiting owner review and audit. Nothing was changed in Studio.

## 1. What was asked
A plan-only "City Atmosphere and Audio Audit": the smallest changes that make the city look and sound more exciting. Priorities:
1. lighting;
2. engine audio;
3. police siren and pursuit audio;
4. robbery alarm and payout feedback;
5. road and intersection readability;
6. mobile performance.

For every proposal: what exists now, the exact change, why it helps gameplay, the performance impact, the assets needed, and how to test and roll it back.

Restrictions:
- no gameplay, economy, cooldown, pursuit, price, physics or police AI changes;
- no new content or map expansion;
- vehicle validation stays monitor-only;
- no deletions;
- no unapproved third-party assets;
- Studio stays the source of truth;
- a backup before any implementation.

## 2. What was built
`docs/ATMOSPHERE_AUDIO_PLAN.md` with proposals A1–A6, based on read-only Studio queries and a code search.

## 3. How it works
- **No-asset items:** A1 lighting values; A5 stop lines as `CityLayout` data.
- **Client-only controllers driven by state that already exists:**
  - A2 engine audio: car speed;
  - A3 siren and lights: the `NpcVehicles.PoliceUnit` model existing;
  - A4 alarm and payout: the `City.Store.RobberyBusy` attribute and the `Paid` notice.
- No server rules, remotes or AI change. Each item has its own off switch.

## 4. Security and authority
Display and audio only, on the client. No new remotes. Sounds use only Roblox-owned Creator Store audio, and the owner approves each asset ID before it's inserted.

## 5. Persistence and data safety
None.

## 6. Decisions made
- **Order:** the no-asset items first (A1, A5), then A3, A4 and A2.
- **Hard limits:** at most 4 engine sounds, 1 siren and 1 alarm at a time; no particles; DepthOfField stays off.
- **Not proposed:** day/night, street lamps, props, particles, music, third-party assets.

## 7. Deviations from the request
`Lighting.Technology` can't be read with my tools, so the owner should confirm it. The plan doesn't change it.

## 8. Unresolved risks and known issues
- **Medium:** the audio needs suitable Roblox-owned sounds; the quality of what's available is unknown until candidates are listed.
- **Low:** the lighting look is subjective, and 3D screen captures render white here, so the owner judges it by eye.
- **Low:** extra marking parts. Up to about 104 static parts; shadows, collision and queries off.

## 9. Multiplayer status
Sounds and lights other players hear and see (another player's engine, the store alarm, the siren) are MULTIPLAYER UNVERIFIED.

## 10. Files for the auditor
AUDITOR_REPORT.md, TEST_EVIDENCE.md, AUDITOR_QUESTIONS.md, plus docs ATMOSPHERE_AUDIO_PLAN.md, PROGRESS.md, ROADMAP.md.
