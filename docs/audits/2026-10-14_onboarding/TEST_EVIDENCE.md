# Test evidence: 2026-10-14_onboarding

- Studio instance used: `Outlaw City (placeId: 132163592957463)`. Confirmed with the Studio instance list before testing. Every Edit/Server call asserted `game.PlaceId == 132163592957463`. The two Lighthouse Keepers Studios that were also open were never touched.
- Backup before the work: `G:\Roblox\Outlaw City\backups\OutlawCity_Approved1.rbxl` (Studio log 16:54:48Z, owner).
- Automated tests: `[Tests] 195 passed, 0 failed`, quoted exactly from the Output (first run after the changes; no failures).
- Solo Studio only. **Not multiplayer validation.**
- Code was pushed to Studio with hash checks: each changed script had to match its pre-change hash first, and each result had to match the local file's hash.

## Automated tests
| Spec | New/changed tests | Result |
|---|---|---|
| `OnboardingRules.spec` (new, 7) | P1 spawn action 0/1 → Spawn, 2/5 → Choose; P2 marker range (34 hidden, 35/150/240 shown, 451 and NaN hidden), "150 studs" / "240 studs"; P4 hint wording + `DecayDelay` 8; P5 clock and status texts; P6 `robberiesNeeded(500, 15000, 2000) = 8`, 1 at $14,500, 0 at $15,000/$20,000, 0 with reward 0, progress texts; P7 compact panel = 6.7% of 666×374, y ≥ 92, text ≥ 14 px, full panel on 720 px; P8 milestones once each | PASS |
| `RobberyRules.spec` (+3, 1 changed) | Died while holding → cooldown = start + 90, can't start at 189.9, can at 190; busted while escaping → start + 90; success → start + 180. With `FailedCooldownSeconds = nil`: failure keeps start + 180 (old behaviour). Robbery A fails late (EscapeTimedOut at 316) after robbery B started at 200 → B's cooldown stays 380 and B stays active. The existing "cooldown" test now reads the failed cooldown | PASS |
| `RewardLedger.spec` (changed) | "invalid rewards are refused before they reach the ledger": now 12 shapes incl. `At = math.huge` and `At = -math.huge`, all `InvalidReward…`, nothing written | PASS |
| All specs | `[Tests] 195 passed, 0 failed` | PASS |

## Manual / scripted Studio tests
| # | Test | Steps | Exact result |
|---|---|---|---|
| 1 | P1, two cars | Profile owns Coupe + Muscle; one click on Spawn Car (mouse tool, instance path) | `garage visible true \| seated nil` |
| 2 | P1, one car | `OwnedVehicles` display attribute set to `Coupe` on the server (profile untouched); garage closed; one click on Spawn Car | `garage visible false \| seated Coupe_11752219158`; Output `[Milestone] Lighthouse8282 FirstCar 31.8s after join` |
| 3 | P2 markers + P3 tip on spawn | Read the player's GUIs right after join (PC, viewport 2004×935) | `tip 12,92 250, 84 fits=true`; `Marker_StoreSign true \| 24/7 MART · 150 studs \| Open: rob the register`; `Marker_DealerSign true \| OUTLAW MOTORS · 220 studs \| Buy cars here`; `store attrs 0 busy false` |
| 4 | Robbery start (real prompt, E held) | At the register | `phase Holding`; `panel true pos 852, 136 size 300, 76` (PC: full panel); `ROBBING THE STORE  9s \| Stay inside until the timer ends`; `store busy true cd 173.96…`; store marker `enabled false` (within 35 studs). Output `[Milestone] Lighthouse8282 FirstRobbery 83.0s after join` |
| 5 | P4 escape panel | After the holdout | `phase Escaping \| ESCAPE TO KEEP $2,000 \| Break line of sight, then stay hidden until your stars are gone \| stars 2 evading false` |
| 6 | P5, failed robbery 1 (busted) | Stayed near the store | Output: `[Police] dispatched to Lighthouse8282 from node G_-300_100 (228 studs away)` … `[Police] BUSTED Lighthouse8282 -> jail` … `[Robbery] Lighthouse8282 1d52afc2-… failed: Busted`. After release: `cd left 5.5 \| marker enabled true \| 24/7 MART · 140 studs / Reopens in 0:06` |
| 7 | Store reopened | Walked back to the register | `cd left -19.0` (open for 19 s already, i.e. well before the old 180 s) |
| 8 | P5, failed robbery 2 (left the store) | Started again, walked out mid-holdout | `phase Holding; just after start the store cooldown is 169.4 s` (the start sets 180 s) → `phase now nil after 2.0 s; store cooldown now 77.4 s (start + 90.0)` |
| 9 | P6 dealership progress | One-car view ($11,400), opened at the desk | `window true \| message: Muscle: $11,400 of $15,000. About 2 more successful robberies. \| fits true` |
| 10 | P7 phone layout | Real HUD elements cloned into a 666×374 frame with the compact layout (see *Not tested*) | All four panel texts fit (`title true detail true` for holding, escaping, evading, reward pending); `RobberyPanel at 203,92 size 260x64 = 6.7% of 666x374`; no overlaps with `OutlawHud.SpawnButton 337,8 160x44`, `CashHud.Cash 389,58 108x26`, `CombatStatus.CombatButton 169,8 160x44`, `SafeZoneHud.Badge 169,58 108x26`; nothing off-screen |
| 11 | P3 tip text on a phone | Same label (250×84 card, GothamBold 14) | `fits true bounds 191, 56 area 194, 72` |
| 12 | Snapshot | Hashed all scripts in Studio and in `src/` | 98 / 98 identical (length + FNV-1a) |

## Screenshots
None. 3D captures render white on this machine (known MCP issue), so evidence is the exact Output and GUI readings above.

## Regression checks
- Robbery start, holdout, police dispatch at the end of the holdout, sighting, bust, jail 12 s and release behaved as before (test 6 Output).
- Spawning and driving the Coupe worked (test 2).
- Safe-zone enter/leave was logged.
- Vehicle validation stayed at 0 observations (`[VehicleValidation] summary: samples=422 observations=0 alerts=0 …`).
- No console errors.
- Cash stayed 11,400 throughout: no payout and no purchase happened.
- The `OwnedVehicles` attribute was restored to `Coupe,Muscle` both times.

## Not tested
- **Real phone / Device Simulator.** I couldn't turn on the Device Simulator from my tools in this session. The P7 measurement used a 666×374 layout frame, not the simulator, and the touch controls (TouchGui) weren't in that frame. Owner check on a real phone.
- **Evading text live.** The police unit kept sight and busted the robber; the text is unit-tested and fits.
- **A successful getaway with the 180 s cooldown.** Unit-tested; the live start set 180 s (test 8).
- **First-time players** (discovery time, understanding the escape): the owner's human playtest.
- **Multiplayer:** several players and the shared store status. MULTIPLAYER UNVERIFIED.
