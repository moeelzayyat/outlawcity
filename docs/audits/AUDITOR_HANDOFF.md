# OUTLAW CITY: handoff to a new independent auditor

**Purpose:** everything a new auditor needs to take over the independent review of OUTLAW CITY. Prepared 2026-10-16 by Claude, the sole implementation agent, at the owner's request.

**Repository:** https://github.com/moeelzayyat/outlawcity, branch `main`. This file is committed in the commit given in the owner's message.

## 1. The project in one paragraph
OUTLAW CITY is a Roblox open-world cops-and-criminals driving game for PC and mobile (Studio place ID **132163592957463**).
- **Players:** everyone spawns as a civilian. They can drive, rob a store, raise a wanted level and be chased by one NPC police car; if caught, they serve a short jail sentence.
- **Economy:** players earn cash and buy a second car at the dealership.
- **People:** the owner (Hamada) decides scope. Claude builds everything in Roblox Studio and documents it. An independent auditor ("the Architect") reviews every substantial step before the next one starts.

## 2. Ground rules the auditor enforces
**Source of truth:**
- The live Studio place is the source of truth; `src/` in the repo is a snapshot exported after tested work.
- There is no Rojo. Claude edits Studio through the Studio MCP and keeps `src/` in sync, hash-checked.
- Nothing counts as working until a Studio playtest passes.

**Testing policy:**
- Solo Studio tests only.
- Anything needing real players is labelled **MULTIPLAYER UNVERIFIED** (tracked in `docs/MULTIPLAYER_TESTS.md`).
- Real-phone checks are **NOT TESTED** unless the owner runs them. Device Simulator results are reported separately from real-phone results.

**Fixed settings (don't change without explicit approval):**
- **Police:** exactly **one** NPC unit; pursuit tuning **130 / 100 / 0.25 / 8** (sight range / chase speed / chase gain / bust distance).
- **Siren:** **OFF**.
- **Anti-cheat** (vehicle validation): **MONITOR-ONLY**, logs only with no corrections or kicks.

**Scope limits:**
- No new content (vehicles, stores, police units, weapons, gangs, properties, monetization or map expansion) without owner approval.
- No external or third-party assets or scripts.

**Safety and evidence:**
- Before each implementation stage the owner saves a Studio backup, and Claude verifies it in the Studio log ("Place file downloaded").
- Evidence must come only from the Outlaw City place; other Roblox games may be open on the owner's PC.
- Every stage has an **exact rollback**, demonstrated in Studio before sign-off.

## 3. How the audit loop works
The full description is in `docs/audits/README.md`.
1. The owner relays the auditor's verdict and next task to Claude.
2. Claude does the task and builds an audit package in `docs/audits/<YYYY-MM-DD_task>/`.
3. The package contains `AUDITOR_REPORT.md`, `TEST_EVIDENCE.md`, `CHANGE_MANIFEST.md`, `AUDITOR_QUESTIONS.md`, `SOURCE_DIFFS.md` (for code changes), `diffs/`, `screenshots/` and `00_AUDITOR_PROMPT.md`.
4. Claude commits and pushes, then gives the owner a ready-to-paste prompt with the commit hash and GitHub links.
5. The auditor answers using the requested headings (always including a verdict: **APPROVE / APPROVE WITH CONDITIONS / CHANGES REQUIRED**) and states exactly what the next step may include.
6. Claude records each verdict in `docs/PROGRESS.md` before doing anything else, and waits for the next approval.

## 4. Where things stand (2026-10-16)
- **Tests:** `[Tests] 216 passed, 0 failed` (unit tests run at the start of every Studio playtest).
- **City:** 328 BaseParts, 114 colliding. Signatures:
  - City `6527bae1`;
  - stop lines `f958ecfa`;
  - buildings `8b66ade9` (186 rows);
  - prototype sign `87d79268`;
  - Stage A signs `18eef2d0`.
- **World:** 50 stop lines (N5) and 4 street-name signs (N4: the prototype plus Stage A).
  - Signs at (100, 100) "3rd St / C Ave", (−100, −100) "2nd St / B Ave", (100, −100) "2nd St / C Ave" and (−100, 100) "3rd St / B Ave".
  - Design: cantilevered blades 7 × 1.5, Atomic streaming, no collision, query, touch or shadow.
- **Pending your review:** `2026-10-16_n4-mobile-diagnosis` (commit `c4bebb5`), PLAN ONLY. It recommends enlarging the four blades to 12 × 3 (post 13.1) to fix phone readability. Nothing has been implemented.
- **Open gates and blocks:**
  - **N4 Stage B** (signs at (100, −300) and (−100, −300)) is a conditionally approved design but **not authorized**. It is blocked until all four hold:
    1. owner authorization;
    2. Architect review;
    3. a **phone-simulator readability pass**, currently **NOT MET**;
    4. owner navigation feedback.
  - Stages C and D, connector–highway signs, second signs and renaming are not authorized.
  - Real phone NOT TESTED; multiplayer MULTIPLAYER UNVERIFIED; memory comparisons INCONCLUSIVE (one long Studio session).
  - Owner playtest feedback is still outstanding (`docs/PLAYTEST_CHECKLIST.md`).
  - Must fix before public release: jail-reset spawn flash (PROGRESS, known issue 6).

## 5. Verdict history (oldest first)
| Audit package | What was reviewed | Verdict as recorded |
|---|---|---|
| `2026-10-14_phase-4B-followup-and-4C` | Robbery follow-up, dealership and second car, profile v2 | CHANGES REQUIRED |
| `2026-10-14_audit-remediation` | Write-through economy, locks, reward ledger | Accepted in principle; 6 targeted fixes requested |
| `2026-10-14_final-audit-fixes` | Ambiguous-write reconciliation, ledger states | APPROVE WITH CONDITIONS |
| `2026-10-14_audit-conditions` | The 6 conditions | Approved (closed) |
| `2026-10-14_onboarding` | Five-minute onboarding batch (P1–P8) | APPROVE WITH CONDITIONS |
| `2026-10-14_onboarding-conditions` | The 4 conditions | Superseded by the playability gate |
| `2026-10-14_playability-gate` | Re-spawn-while-driving fix | APPROVE WITH CONDITIONS (follow-ups tracked) |
| `2026-10-14_city-atmosphere-audio-audit`, `_atmosphere-audio-plan` | Atmosphere and audio plan | Batch 1 approved |
| `2026-10-14_atmosphere-batch1` | Client lighting preset and police lights | APPROVE WITH CONDITIONS |
| `2026-10-14_atmosphere-batch1-closeout` | Light-bar streaming fix; FPS | APPROVE |
| `2026-10-14_city-navigation-world-audit` | World polish plan (N1–N5) | Batch 1 (N3, N2, N1) approved |
| `2026-10-15_world-polish-batch1` | Districts, Baseplate, dealership clearance | APPROVE WITH CONDITIONS |
| `2026-10-15_markings-signs-plan` | N5 stop lines and N4 signs plan | Approved N5 only |
| `2026-10-15_stop-lines-batch1` | 50 stop lines | APPROVE WITH CONDITIONS |
| `2026-10-15_n5-closeout-n4-sign-plan` | Memory closeout; one-sign plan | APPROVE WITH CONDITIONS (memory PARTIAL) |
| `2026-10-16_n4-one-sign` | Prototype sign | APPROVE WITH CONDITIONS (post-occlusion defect) |
| `2026-10-16_n4-sign-cantilever` | Cantilever fix | APPROVE |
| `2026-10-16_n4-rollout-readiness` | Rollout plan (all corners) | APPROVE WITH CONDITIONS, Stage A only |
| `2026-10-16_n4-stage-a` | 3 plaza-ring signs | APPROVE |
| `2026-10-16_n4-stage-b-readiness` | Stage B plan; simulator test plan | APPROVE WITH CONDITIONS, plan only |
| `2026-10-16_n4-sim-test` | Device Simulator test; Stage B recheck | APPROVE (task closed); gate 3 NOT MET |
| `2026-10-16_n4-mobile-diagnosis` | Mobile readability diagnosis | **PENDING** |

`docs/PROGRESS.md` holds the authoritative wording of each recorded decision.

## 6. Reading order for the new auditor
**Start here:**
1. `docs/audits/AUDITOR_HANDOFF.md` (this file)
2. `docs/audits/README.md`: the audit workflow and evidence rules
3. `docs/PROGRESS.md`: completed work, every recorded decision, known issues, upcoming and open gates
4. `docs/ROADMAP.md`: phases, budget and testing policy
5. `docs/DESIGN.md`: the game design (civilian open world)
6. `docs/ARCHITECTURE.md`: folders, boot order, network contract, security rules, systems (including "City look")
7. `docs/AGENTS.md`: roles and the one-integration-agent rule
8. `docs/MULTIPLAYER_TESTS.md`: deferred multiplayer checks
9. `docs/TEST_CHECKLIST.md` and `docs/PLAYTEST_CHECKLIST.md`

**Current workstream (world polish and navigation):**

10. `docs/CITY_NAVIGATION_WORLD_AUDIT.md`
11. `docs/STREET_MARKINGS_SIGNS_PLAN.md`
12. `docs/STREET_SIGN_PROTOTYPE_PLAN.md`
13. `docs/N4_STREET_SIGN_ROLLOUT_PLAN.md`
14. `docs/N4_STAGE_B_PLAN.md`
15. `docs/N4_MOBILE_READABILITY_DIAGNOSIS.md` (pending review)

**Recent audit packages (newest first):**

16. `docs/audits/2026-10-16_n4-mobile-diagnosis/` (pending)
17. `docs/audits/2026-10-16_n4-sim-test/`
18. `docs/audits/2026-10-16_n4-stage-a/`
19. `docs/audits/2026-10-16_n4-rollout-readiness/`
20. `docs/audits/2026-10-15_stop-lines-batch1/`

**Background, as needed:**
- `docs/CITY_ATMOSPHERE_AUDIO_AUDIT.md`
- `docs/ATMOSPHERE_AUDIO_PLAN.md`
- `docs/PLAYER_EXPERIENCE_AUDIT.md`
- `docs/PHASE3_PLAN.md`
- the older audit folders in section 5

**Key source for the current workstream:**
- `src/ServerScriptService/Server/World/CityLayout.luau` (city data, stop lines, `streetSigns()`)
- `src/ServerScriptService/Server/World/CityBuilder.luau` (`buildStreetSigns`)
- `src/ServerScriptService/Server/Services/WorldService.luau`
- `src/ServerStorage/Tests/CityLayout.spec.luau`

## 7. What the new auditor is asked to do first
- Review the pending `2026-10-16_n4-mobile-diagnosis` package and give a verdict with the next authorized step.
- Earlier verdicts stand unless you explicitly revisit them. If you disagree with a past decision, say which one and why, and the owner will decide.
