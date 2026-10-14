# Test evidence: 2026-10-14_playability-gate

- Studio instance used: `Outlaw City (placeId: 132163592957463)`. Confirmed with the Studio instance list. Every Edit/Server call asserted `game.PlaceId == 132163592957463`. The Lighthouse Keepers Studios that were also open were never touched.
- Backup: `backups\OutlawCity_Approved1.rbxl` (owner, Studio log 16:54:48Z). This was a small bug fix within the approved stage.
- Automated tests: `[Tests] 200 passed, 0 failed` on every playtest after the fix.
- Solo Studio only. **Not multiplayer validation.**
- Studio = `src/` for the changed scripts: VehicleService `1c11aaa9`, VehicleController `e94cebbd`. The conditions fixes were hash-checked earlier (see the onboarding-conditions draft).

## The fix
| # | Test | Exact result |
|---|---|---|
| 1 | Before the fix: driving the Muscle, one click on Spawn Car (one-car view) | `Coupe_11752219158` spawned; player `seated nil` |
| 2 | After the server-only part: Coupe → garage → Muscle while driving | `seated Muscle_11752219158`, camera `Scriptable`. But W gave `speed=2` for 3 s: the client was still driving the old car. This led to the client part |
| 3 | After both parts: Coupe → Muscle while driving, then hold W | `seated Muscle_11752219158`; speed every 0.5 s `17, 49, 76, 97, 111`; camera `Scriptable` |
| 4 | V while driving, then V again 0.5 s later | Seated in the Muscle afterwards; second V → toast `Wait a moment before spawning again.` (I didn't confirm the first V made a new car instance) |
| 5 | F to exit after a replacement | `seated nil \| speedometer visible false \| camera Enum.CameraType.Custom` |
| 6 | Ownership | `RequestSpawnVehicle("Police")` → `false UnknownVehicle` |
| 7 | Jail | `SetStars 2`, `SimulateBust` → `jailed=true`; spawn → `false Jailed` |
| 8 | From on foot (old path) | V then W: seated, moving (`speed 27` at the reading) |

## Regression
| Area | Exact result |
|---|---|
| Robbery + pursuit + jail | `[Robbery] … started c476690f-…`, `holdout complete; escaping`, `[Police] dispatched … from node G_-100_300 (360 studs away)`, `sighted … at 33 studs`, `lost sight`, `sighted … at 62 studs`, `BUSTED Lighthouse8282 -> jail`, `failed: Busted`, `[Jail] … released` |
| Dealership | At the desk the window opened, Muscle button `Owned`; buying it → `false AlreadyOwned` (Output `purchase Muscle … refused: AlreadyOwned`); from the plaza → `TooFar`; `Coupe` → `NotForSale`; cash 11,400 unchanged |
| Cash persistence | Stop → Play: `[Economy] Lighthouse8282: loaded (Existing) cash=11400`. Earlier in the owner's session: `saved on leave (cash=11400)` |
| Vehicle validation | 0 observations in normal play (monitor-only) |
| Errors | None from game code |

## Owner's own session (found in the Output before this fix; not a structured playtest)
`[Milestone] Lighthouse8282 FirstCar 26.5s after join` · `FirstRobbery 76.9s after join` · police dispatched 449 studs away · sighted at 106 · `lost sight` (gap 389–400 studs) · sighted again at 119 · `BUSTED` · `failed: Busted`. No FirstEscape. Owner feedback not received yet. I stopped this idle session to install the fix.

## From the onboarding conditions (included in this range)
- `[Tests] 200 passed, 0 failed`. New specs: `spawnChoice` (stale selection, not loaded, none); `isActiveRobbery`; repeated or overlapping failures change the cooldown once; success keeps start + 180.
- **Live checks:**
  - stale selection, then one-car spawn → Coupe;
  - not loaded → `seated Coupe_…`;
  - tip `PayoutPending tip=true`, `nil tip=true`, `Holding tip=false`;
  - evading HUD `… evading=true | Stars fading: stay out of police sight until they're gone`;
  - the store reopened at start + 90 s after busts.

## Not tested
- **Human playtest with the new checklist:** the owner's, next step.
- **Real phone:** the owner's.
- **Multiplayer:** MULTIPLAYER UNVERIFIED.
- **`NoFreeSpawn` while driving:** unchanged.
