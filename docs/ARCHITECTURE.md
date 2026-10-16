# OUTLAW CITY — Architecture

Status: Phases 1-3 built and solo-tested (driving, civilian spawning, wanted, combat rules, one NPC police unit, safe zones, monitor-only vehicle validation, short jail); Phase 4A (cash + persistence) approved; Phase 4B (one convenience-store robbery) provisionally approved; 4B follow-up fixes (recoverable payouts) done; police sent at holdout end; driving getaway still open. Phase 4C (dealership + second vehicle) built and solo-tested. Audit remediation (write-through economy, durable reward ledger, experimental police tuning, HTTP off) done. The final targeted fixes were APPROVED WITH CONDITIONS; the six conditions are done (FIFO profile queue, leave-safe saves, reward validation, extra tests, limitations tracked). The five-minute player-experience plan (`docs/PLAYER_EXPERIENCE_AUDIT.md`) was reviewed (audit 4: APPROVE on Part A) and its approved onboarding changes are built and solo-tested (see *New-player guidance*). No broad Phase 5 work. Last updated 2026-10-14.

## Source of truth and workflow

- **The Roblox Studio place is the source of truth.** Code is written directly in Studio through the Studio MCP. Rojo is intentionally not used.
- `src/` in this repo is a **read-only snapshot** exported from Studio after each tested milestone, so changes can be reviewed and diffed in git. Never edit `src/` and expect it to reach Studio.
- Only the primary integration agent edits the live Studio place (see `AGENTS.md`).
- Roblox's own place version history is the rollback mechanism for the live place; git tracks docs and source snapshots.

## DataModel layout

```
ReplicatedStorage
  Shared/                      (Folder) code required by both server and client
    Types                      shared Luau types (VehicleStats, VehicleInput, SpawnError)
    Config/VehicleConfig       frozen tuning data per vehicle
    Net/Remotes                the network contract (all remotes declared here)
    Util/Signal                tiny same-side event helper
    Vehicle/VehicleMath        pure vehicle maths (unit-tested)
    Config/GameplayConfig      open-world tuning (spawn protection, spawn clearance)
    Player/PlayerAttributes    names of server-published Player attributes (Status, SpawnProtectedUntil, ...)
    Player/SpawnRules          pure civilian spawn selection (unit-tested)
    Config/WantedConfig        star thresholds (3 now; add entries for 5), decay, escape rewards, crime catalogue
    Wanted/WantedRules         pure wanted rules engine: heat, stars, cooldowns, decay, escape (unit-tested)
    Config/CombatConfig        combat cooldown (30 s) and request rate limit (1 s)
    Combat/CombatRules         THE harm gate: canHarm(attacker, victim, context) (unit-tested)
    Combat/CombatStatusRules   pure Peaceful/Combat switching rules (unit-tested)
    Zones/SafeZoneRules        pure safe-zone geometry with exit hysteresis (unit-tested)
    Config/RobberyConfig       store robbery tuning (hold 15 s, reward 2000, cooldown 180 s, 90 s after a failed robbery (trial), ranges)
    Config/OnboardingConfig    new-player guidance: marker range, tip time, compact phone panel, milestones (display only)
    Onboarding/OnboardingRules pure helpers: spawn shortcut, marker range, store status, escape hint, Muscle progress, milestones (unit-tested)
    Robbery/RobberyRules       pure robbery state machine: start checks, holdout, escape, single payout (unit-tested)
    Config/DealershipConfig    dealership catalogue and prices (Muscle $15,000), desk range, request interval
    Config/JailConfig          sentence 12 s (clamped 10-15), release-check cadence
    Jail/JailRules             pure sentencing, duplicate guard, release timing, restricted actions, slots (unit-tested)
    Config/EconomyConfig       starting cash 500, caps, DataStore name, retry/lock/autosave timings
    Economy/EconomyRules       pure amount/tx validation, grant/deduct, duplicate guard, saved-data checks, session locks (unit-tested)
    Vehicle/VehiclePhysics     raycast suspension + arcade handling (moved from Client in 3D; used by player cars on the client and NPC cars on the server)
  Remotes/                     (runtime) created by the server from Net/Remotes

ServerScriptService
  Server/
    Main                       (Script) server entry point; boots services, runs tests in Studio
    Services/WorldService      owns the test map; exposes vehicle spawn pads
    Services/PlayerStateService  single owner of per-player gameplay state, published as Player attributes
    Services/SpawnService      picks each civilian's next spawn (RespawnLocation) before every spawn
    Services/WantedService     per-player wanted state; reportCrime() entry point; 4 Hz decay loop; notices
    Services/CombatService     per-player combat status; RequestSetCombatStatus; canPlayerHarm / canPoliceBust
    Services/SafeZoneService   4 Hz position check; publishes InSafeZone
    Services/JailService       busts -> jail cell; server-timed release; gates spawn/drive/combat
    Services/EconomyService    THE only place cash changes; DataStore load/save, autosave, failed-load lockout
    Services/RobberyService    owns store robbery sessions: register prompt, server checks, holdout, escape payout
    Services/DealershipService RequestPurchaseVehicle: server-checked purchases through EconomyService.purchaseVehicle
    Data/ProfileStore          load (atomic lock claim) / save (owner-only) over any UpdateAsync store (unit-tested with a fake)
    Data/DataStoreAdapter      real DataStore ("_Studio" suffix in Studio) + Studio-only failure simulation
    Services/VehicleValidationService  5 Hz monitor-only checks of player vehicles; diagnostics in ServerStorage.Diagnostics
    Validation/VehicleValidationConfig  limits, tolerances, scoring (Mode = "Monitor")
    Validation/VehicleValidationRules   pure checks: speed, displacement, finite values, ownership, scoring (unit-tested)
    Services/PoliceService     NPC police orchestration (ONE unit): dispatch, sighting -> WantedService, bust, termination, logs
    Police/PoliceConfig        NPC police tuning (MaxUnits = 1, sight, speeds, stuck, bust)
    Police/RoadNetwork         waypoint graph from CityLayout + A* (path planning, pure)
    Police/PolicePathPlanner   route from position to target over the road network (pure)
    Police/PoliceDriveRules    steering, corner speed, chase speed, stuck state machine (pure)
    Police/PoliceDriver        movement: drives an NPC car via VehiclePhysics, whisker avoidance, recovery
    Police/PoliceDispatchRules dispatch counts, spawn-node choice, bust timing (pure)
    Crime/PoliceCollisionDetector  gameplay crime detector: player car rams police -> reportCrime("RammingPolice")
    Dev/DevToolsService        STUDIO ONLY: creates ReplicatedStorage.DevRemotes + handlers; inert elsewhere
    Dev/DevCommandRules        pure validation of dev commands (unit-tested)
    Services/VehicleService    spawning, seating, exit, network ownership, cleanup
    World/CityLayout           data-only blueprint of the test city (unit-tested)
    World/CityBuilder          turns the blueprint into parts under Workspace.City
    Vehicle/VehicleFactory     builds a vehicle Model from VehicleStats
    Util/RateLimiter           per-key cooldowns for remote requests (unit-tested)

ServerStorage
  Tests/                       TestRunner, Assert, *.spec modules (never replicated)

StarterPlayer.StarterPlayerScripts
  Client/
    Main                       (LocalScript) client entry point; boots controllers
    Controllers/VehicleInputController   keyboard / gamepad / touch -> VehicleInput
    Controllers/VehicleController        runs physics for vehicles this client simulates
    Controllers/VehicleCameraController  chase camera while driving
    Controllers/VehicleHudController     spawn button, speedometer, touch driving buttons
    Controllers/WantedHudController      wanted stars, evading blink, Evading / Escaped banners
    Controllers/CombatStatusController   Peaceful/Combat toggle (top-centre row, left of Spawn Car)
    Controllers/SafeZoneHudController    SAFE ZONE badge under the Combat button (amber while wanted)
    Controllers/JailHudController        IN JAIL panel with countdown from the server's release time
    Controllers/RobberyHudController     robbery objective panel (countdown / escape hint; compact on phones) and result toasts
    Controllers/GarageController         garage window (owned vehicles); Spawn Car spawns the only car or opens it with 2+, V spawns the last chosen car
    Controllers/WorldMarkerController    floating markers over the 24/7 MART and OUTLAW MOTORS (distance, store status)
    Controllers/OnboardingTipController  one-time first-spawn tip (15 s, X to close)
    Controllers/DealershipController     dealership window opened by the showroom prompt; sends RequestPurchaseVehicle
    Controllers/UiKit                    shared touch-sized window/button builders for the 4C windows
    Controllers/CashHudController        $ balance (server attribute) right of the stars; "$ offline" if data didn't load
    Controllers/DevPanelController       STUDIO ONLY dev panel (F8 toggles); absent without DevRemotes

Workspace
  City/                        built once in edit mode by CityBuilder (saved in the place)
    Roads, Markings, Sidewalks, Plaza, Buildings, Highway, Barriers, VehicleSpawns
  Vehicles/                    (runtime) spawned vehicles, owned by VehicleService
  NpcVehicles/                 (runtime) server-simulated NPC police car(s); EventLog attribute holds recent police events
```

## Server / client responsibilities

| Concern | Server | Client |
|---|---|---|
| Vehicle spawn | Validates request, cooldown, picks free pad, builds model, seats player | Asks via `RequestSpawnVehicle`, shows result |
| Who simulates a car | Sets network owner + `SimulatedBy` attribute (driver, else owner, else server) | Runs `VehiclePhysics` only for cars where `SimulatedBy == LocalPlayer.UserId` |
| Driving physics | — (future: speed/teleport sanity checks) | Suspension, drive, grip, yaw, flip recovery |
| Seating / exit | `Seat:Sit`, prompt range check, unseat + safe exit position | Sends `RequestExitVehicle`, disables jump while driving |
| Camera, HUD, input | — | All of it |
| Money, arrests, purchases (later) | **Always server-authoritative** | Display and requests only |

## Boot order

- Server `Main`: `Remotes.createAll()` → `service.init()` for each service in order (World, PlayerState, Spawn, Economy, SafeZone, Jail, Wanted, Robbery, Dealership, Combat, Police, DevTools, Vehicle, VehicleValidation, the order in `Main`) → `service.start()` for each → sets `Workspace.ServerReady` → in Studio runs unit tests (disable with `Workspace` attribute `RunTestsOnStart = false`).
- Client `Main`: `VehicleInputController.init()` → `VehicleController.init()` → `VehicleCameraController.init()` → `VehicleHudController.init()` → `WantedHudController.init()`, `DevPanelController.init()` and `CombatStatusController.init()` (all spawned), then wires input action signals.
- HUD placement: the top-right corner belongs to Roblox's player list; game buttons live in the top-centre row.
- Dev tools (Phase 3+): Studio-only, created only when `RunService:IsStudio()` is true on the server, so they can never activate in published servers.
- Every service exposes `init()` (setup, may yield) and `start()` (connect runtime events). Every controller exposes `init()`.

## Network contract (event contracts)

All remotes live in `ReplicatedStorage.Shared.Net.Remotes.Definitions`. Nothing else may create remotes.

| Remote | Type | Direction | Payload | Server validation |
|---|---|---|---|---|
| `RequestSpawnVehicle` | RemoteFunction | client → server | `(vehicleId: string) -> (ok: boolean, err: SpawnError?)` | string, 1–32 chars, known id, alive, 3 s cooldown, free pad |
| `RequestExitVehicle` | RemoteEvent | client → server | `()` | 0.5 s cooldown, caller must be in a `DriverSeat` under `Workspace.Vehicles` |
| `RequestSetCombatStatus` | RemoteFunction | client → server | `(target: "Peaceful" \| "Combat") -> (ok, err: CombatSwitchError?, secondsUntilPeacefulAllowed)` | 1 s per-player rate limit, string ≤ 16 chars, exact status names; Peaceful refused while wanted or during the 30 s combat cooldown |
| `OnWantedNotice` | RemoteEvent | server → client | `(kind: "Evading" \| "Escaped" \| "Busted", payload: { Stars?, FromStars?, Reputation? })` | server-only sender; the server never listens to it |
| `RequestPurchaseVehicle` | RemoteFunction | client → server | `(vehicleId: string) -> (ok, err: PurchaseError?)` | string 1-32 chars; in `DealershipConfig.Catalog` (price from server config only; extra client arguments ignored); one in flight + 1 s per player; alive; not jailed; within 14 + 6 studs of the sales desk; then `EconomyService.purchaseVehicle` (cash data loaded, not owned, enough cash, fresh server tx id) |
| `OnRobberyNotice` | RemoteEvent | server → client | `(kind: "Rejected" \| "Started" \| "Escape" \| "Failed" \| "Paid" \| "PayoutFailed", payload: { Reason?, CooldownLeft?, Id?, HoldEndsAt?, Reward?, Amount? })` | server-only sender; the server never listens to it. There is **no client robbery request remote**: robberies start from the register's ProximityPrompt (`Triggered` on the server) |

`SpawnError = "BadRequest" | "UnknownVehicle" | "NotAlive" | "Cooldown" | "NoFreeSpawn" | "Jailed" | "NotOwned"`. Spawning checks `EconomyService.ownsVehicle` on the server: the starter Coupe always, anything else only from a loaded profile that owns it.

Studio-only (not in the contract; created by `DevToolsService` only when `RunService:IsStudio()`): `ReplicatedStorage.DevRemotes.RequestDevCommand` (RemoteFunction) `(name, value) -> (ok, err)` with commands `SetHeat`, `SetStars`, `ReportCrime`, `ResetWanted`, `SetPoliceSight`, validated by `DevCommandRules` and re-checked against `IsStudio` on every call. Later stages added `SimulateBust`, cash commands (4A), `ClearRobberyCooldown` and `TryRobStore` (4B: runs the same server checks as the register prompt without the prompt's own range limit, so rejections can be tested).

Replicated Player attributes (server-written only, names in `Shared.Player.PlayerAttributes`): `Status` (`"Civilian"`), `SpawnProtectedUntil` (server time), `WantedLevel` (stars), `WantedHeat`, `WantedEvading`, `CriminalReputation` (session only until persistence), `CombatStatus`, `CombatCooldownUntil` (server time, 0 = none), `InSafeZone` (SafeZoneService, 4 Hz), `Jailed`, `JailReleaseAt` (JailService), `Cash`, `CashStatus` (EconomyService), `RobberyPhase` (`Holding`/`Escaping`, else nil), `RobberyHoldEndsAt` (server time), `RobberyReward` (display only) (RobberyService), `OwnedVehicles` (comma-separated ids from the profile; display only) (EconomyService). Client writes to these never replicate (verified in playtest). Later stages add combat-status and safe-zone attributes here. Store folder attributes (server-written, display only): `City.Store.RobberyCooldownUntil` (server time, 0 = never robbed) and `RobberyBusy` (RobberyService).

## Wanted system

- **Rules engine** (`WantedRules`, pure): crimes add heat (per-crime heat + per-player cooldown), heat maps to stars through `WantedConfig.StarThresholds` (3 entries = 3 stars; adding entries extends to 5 without code changes), heat is capped at `MaxHeat`. Heat decays at `DecayRate`/s only after `DecayDelay` s with no crime **and** no police sighting ("Evading"). Reaching 0 heat is an escape from the episode's peak stars; reputation is awarded for peaks ≥ `EscapeMinStars`.
- **Service** (`WantedService`, server): owns states, runs the 4 Hz step loop, publishes attributes, sends `OnWantedNotice`. Public API: `reportCrime(player, crimeType)` (the only way crimes enter), `resetWanted(player)` (busted/admin, no reward), `getStars(player)`, `setPoliceSightProvider(fn)` (NPC police plug in here in 3D). Wanted level persists through respawn (resetting the character does not clear it).
- **Star threshold rule**: a star is held while heat ≥ its threshold and lost the instant heat drops below it. Heat sitting exactly on a threshold therefore loses that star on the first decay tick; the Evading notice reports the stars held *before* that tick. Dev "Set N stars" places heat mid-band so it doesn't drop immediately.
- **Crime detection is separate**: detectors (3D police sightings/collisions, future robberies) live in their own modules and only call `reportCrime`. **Implemented detectors: one** — `Crime/PoliceCollisionDetector` reports `RammingPolice` when a player-driven car hits an NPC police car at ≥ 25 studs/s toward it (3D). `SpeedingNearPolice` and `Evading` exist only as entries in `WantedConfig.Crimes`, with **no detector**; no other crimes exist. Everything else in testing is injected through Studio dev tools.

There are no Teams: everyone is a civilian (`DESIGN.md`). The superseded team system lives only in git (tag `teams-superseded`).

Replicated attributes on each vehicle Model: `VehicleId`, `OwnerUserId`, `SimulatedBy`, `DriverUserId`.

Rules:
- Client → server remotes are named `Request<Verb><Noun>`; server → client pushes will be `On<Noun><Event>`.
- The server never invokes a RemoteFunction on a client.
- Every server handler type-checks every argument and rate-limits per player.

## Naming conventions

- Modules and instances: `PascalCase`. Server modules end in `Service`, client modules in `Controller`.
- Locals and functions: `camelCase`; module-level constants: `UPPER_SNAKE_CASE`.
- Types: `PascalCase`, exported from `Shared.Types` when shared.
- All modules start with `--!strict` and a one-line header comment saying what they own.
- Units: studs and seconds; speeds in studs/s (HUD converts to MPH with 1 stud = 0.28 m).

## Security rules

1. Treat every remote argument as hostile: check `typeof`, length and range before use.
2. Rate-limit every remote per player (`RateLimiter`).
3. Money, arrests, inventory and purchases are decided only on the server, never trusted from a client.
4. Clients may simulate only vehicles the server assigned to them (network ownership + `SimulatedBy`).
5. Known gap for Phase 3+: the simulating client controls its car's velocity, so a server-side speed and teleport sanity check is needed before any gameplay rewards depend on driving.
6. Tests and server code live outside `ReplicatedStorage` so clients cannot read them.

## Vehicle model

- One collidable, massed part (`Chassis`) carries physics; body panels, seat and wheels are massless, non-colliding visuals.
- Four raycast springs (anchor points in `VehicleStats.WheelOffsets`) push the chassis up; spring stiffness is derived from the live assembly mass so the car always rests at the configured compression, including with a driver.
- Throttle, braking, reverse, lateral grip and yaw are applied as velocity changes, which keeps handling responsive and independent of part friction. All of that maths lives in `VehicleMath` and is unit-tested.
- Wheels hang from `Motor6D`s; the simulating client animates suspension travel, steering and spin.
- A car on its roof for 2 s at low speed is flipped upright automatically.

## Combat status and harm rules (Phase 3C)

- Every player starts **Peaceful**. Switching to **Combat** is allowed at any time; switching back to Peaceful is refused while wanted (`Wanted`) or within `CombatConfig.CombatCooldown` (30 s) of entering Combat or of the last combat activity (`Cooldown`). Status survives respawn. Switching status never reads or writes the wanted level.
- **`CombatRules.canHarm(attacker, victim, context)` is the only harm gate.** Inputs are plain `Combatant` tables (`Kind`, `UserId`, `Status`, `WantedStars`, `InSafeZone`, `SpawnProtectedUntil`) so tests use mocks. Order of checks: malformed → `Invalid`; self → `Self`; NPC police → allowed iff victim wanted (ignores status, safe zone and spawn protection), else `NotWanted`; peaceful attacker → `AttackerPeaceful` (wanted victims included); peaceful, non-wanted victim → `VictimPeaceful` (a wanted player in Peaceful mode is *not* protected from Combat players); either side in a safe zone → `SafeZone` (wanted victims included); either side spawn-protected → `SpawnProtected`; otherwise allowed.
- Server wrappers: `CombatService.canPlayerHarm(a, b)` for future PvP damage, `CombatService.canPoliceBust(victim)` for NPC police (3D), `CombatService.noteCombatActivity(player)` to refresh the cooldown when damage is dealt/taken. **No weapons or damage exist yet**; any future damage source must go through these.

## NPC police (Phase 3D prototype — single unit)

- **Separation:** path planning (`RoadNetwork`, `PolicePathPlanner`), movement (`PoliceDriver` + `PoliceDriveRules`) and dispatch (`PoliceDispatchRules`) are separate modules; `PoliceService` only wires them and owns the unit's lifecycle.
- **Vehicle:** `VehicleConfig.Police` (Coupe handling, top speed 125, `PlayerSpawnable = false` so `RequestSpawnVehicle` refuses it). Built by the normal `VehicleFactory`; seat disabled and prompt removed; parented to `Workspace.NpcVehicles`; network owner = server. The server runs the same `VehiclePhysics` the client uses for player cars, on `RunService.PreSimulation`.
- **Road network:** 23 nodes — the 16 grid intersections, the plaza centre (joined diagonally to its four corner intersections), four highway nodes in the south carriageway (clear of the median) and the two end plazas; the two connectors are edges. A* re-planned every 1 s.
- **Dispatch:** every 0.25 s; one unit for the most-wanted player when nobody is being chased. Spawn node chosen 160–450 studs from the target (else the nearest beyond 450).
- **Driving:** follow waypoints; corner speed from the turn angle (30 studs/s for 90°, cruise 95); within 90 studs *and* in sight → direct chase of the target's position + 0.5 s of its velocity, matching its speed plus a closing term (follow gap ≈ 10 + lead); three forward whisker rays steer away from walls and brake for obstacles.
- **Stuck handling:** "wants progress" (desired speed before obstacle braking > 6) with speed < 3 for 1.5 s → reverse 1.2 s with opposite steer; 3 such stalls within 20 s → **hard recovery**: re-enter the network at a dispatch-style node out of the target's sight. Far behind (>650 studs for 10 s) → respawn closer the same way.
- **Perception:** sees the target within 160 studs with a clear raycast (buildings block, vehicles/characters don't). `WantedService.setPoliceSightProvider` uses this, so heat cannot decay while seen.
- **Busting:** target within 18 studs and slower than 5 studs/s for 2.5 s continuously **and** `CombatService.canPoliceBust` (i.e. `CombatRules.canHarm(NpcPolice, …)`, which requires a wanted level) → `WantedService.bust` (wanted cleared, no reward, "Busted" notice) and the player is respawned at a civilian spawn. The short jail replaces the respawn later.
- **Termination:** escape/clear (stars 0), bust, or the target leaving → unit stops, despawns after 3 s.
- **Diagnostics:** `[Police]` output lines and `Workspace.NpcVehicles.EventLog`: dispatch, sighting changes, crimes detected, recoveries, bust, despawn, and every 5 s a status line with per-frame step cost.

## Safe zones (Phase 3E)

- **Data:** `CityLayout.safeZones()` returns axis-aligned boxes (`Types.SafeZone`). The first is `Plaza`, the central block (x and z from −82 to 82, y −20 to 80), which contains all six civilian spawns and the plaza vehicle pads. Future garages add entries there (none built).
- **Rules:** `SafeZoneRules` (shared, pure). `contains`, `zoneAt`, and `update(wasInside, zones, point, exitMargin)` with 2 studs of exit hysteresis, so standing on the edge doesn't flicker.
- **Service:** `SafeZoneService` checks every player's HumanoidRootPart 4 times per second (when seated, that's the car's position) and sets `InSafeZone`. On-screen latency was 0.4–0.6 s in playtests. Transitions print `[SafeZone]` lines.
- **Effect:** only through `CombatRules.canHarm`. Either participant in a zone means `SafeZone` denial for player-vs-player harm, wanted or not, whatever their combat status. NPC police ignore zones by rule. WantedService, the heat decay and escape rewards don't read zone state at all, so a zone never clears, freezes or rewards a wanted level. Combat status rules are also zone-independent, so the cooldown and wanted lock still apply inside.

## Vehicle movement validation (Phase 3G, MONITOR-ONLY)

- **Scope:** only player cars in `Workspace.Vehicles`, which are client-simulated. NPC police in `Workspace.NpcVehicles` are server-simulated and never judged, and anything with the `Npc` attribute is skipped.
- **Trust:** the server only reads the replicated chassis position, velocity and network owner. No client message can mark movement as legitimate.
- **Sampling:** each player vehicle is sampled 5 times a second (`SampleInterval = 0.2`).
- **Checks** (`VehicleValidationRules`, pure). Each vehicle's limit comes from its own stats: `MaxSpeed = MaxForwardSpeed x 1.3 + 10` (Coupe 166, Police 172.5 studs/s).
  - *Non-finite* position or velocity -> `InvalidState`. The last good baseline is kept.
  - *Displacement* between samples (horizontal) above `MaxSpeed x dt x 1.5 + 12` -> `Teleport`. Above 150 studs it scores as extreme.
  - *Horizontal speed* above `MaxSpeed` continuously for 1.0 s or more -> `SustainedOverspeed`. Single-frame collision spikes and falling are ignored.
  - Network owner differing from `SimulatedBy` for 1.5 s or more -> `OwnershipMismatch`. Brief handovers are ignored.
- **Scoring:** points per observation (Teleport 1, extreme Teleport 2, SustainedOverspeed 2, InvalidState 2, OwnershipMismatch 1). An **alert** needs 2 points within 10 s, so medium anomalies must repeat. Alerts and observations only print `[VehicleValidation]` lines and update `ServerStorage.Diagnostics` (attributes `Samples`, `Observations`, `Alerts`, `Loops`, `LoopSeconds`, `MaxLoopMs`, `ValidationLog`). These are server-only, never replicated. A 30 s summary line includes the loop cost.
- **Authorized moves:**
  - New vehicles get a 1 s grace period, which covers spawning.
  - `VehicleValidationService.authorizeReposition(vehicle, seconds)` gives a grace window and a fresh baseline for any future server-side move. No current server code moves player cars.
  - The client's own flip recovery lifts the car 4 studs vertically, which the horizontal checks ignore.
- **No enforcement:** there are no resets, kicks or bans, and none are implemented. Turning on corrections needs owner approval after more normal-driving data. Future rewards for driving, escapes or arrests must come from server-validated gameplay events.

## Short jail

- **Trigger:** `PoliceService` bust -> `JailService.jailForBust(player)`, which is the only way in. The Studio-only dev command `SimulateBust` calls the same function. It re-checks the shared combat gate (`CombatRules.canHarm(NpcPolice, ...)`, so the player must be wanted and not already jailed). It then uses `JailRules.sentence` to refuse duplicates (`AlreadyJailed`) and players who aren't wanted (`NotWanted`).
- **On a valid bust:** the sentence is `JailConfig.Seconds` (12, clamped to 10-15). `WantedService.bust` clears the wanted level with no escape reward. The player is pulled out of any seat and placed on a free cell slot (`JailRules.pickSlot`, 4 slots). `Jailed`/`JailReleaseAt` attributes are published. Their car, reputation and anything else are untouched.
- **Cell:** `Workspace.City.Jail`, built from `CityLayout.jail()` by `CityBuilder.buildJail`. It sits south of the grid at (0, 0, 420), off the road network, with solid walls, a barred front (1.4-stud gaps), a roof with a light, and 4 invisible slot markers.
- **Server-owned timer:** a 4 Hz loop releases players whose time is up. `JailRules.isJailed` stays true until the server releases them, so nothing slips through between the deadline and the release. On release: `SpawnService.assignSpawn` + `LoadCharacter`, so the player gets a civilian pad with normal spawn protection. No remote can end or shorten a sentence (spec-checked).
- **Bypass guards:**
  - A character reset or death mid-sentence puts the new character back in the cell, and the timer is unchanged.
  - `VehicleService` refuses spawns (`Jailed`), refuses prompt seating, and ejects a jailed player from any driver seat.
  - `CombatService` refuses status requests (`Jailed`).
  - `CombatRules` treats a jailed player as out of play: no harm or bust either way (`Jailed`).
  - The `Robbery` action is already gated in `JailRules` for later.
- **Client:** `JailHudController` shows IN JAIL + "Release in Ns". It's computed from `JailReleaseAt` and the server clock, so it follows the real release.
- **Not built (by owner decision):** prison escapes, jailbreak missions, bail. Leaving the game mid-sentence ends it, because jail state is session-only until persistence exists.

## Cash and persistence (Phase 4A)

- **One writer:** `EconomyService.grant/deduct(player, amount, txId, reason)` is the only way cash changes. There is no client remote for cash (spec-checked). The client sees the balance only through the `Cash` and `CashStatus` attributes. A client editing its own attribute changes only its local display; the server value stays, and the next server change overwrites the display.
- **Rules** (`EconomyRules`, pure):
  - Amounts must be whole, finite, positive and at most 1,000,000 (`InvalidAmount`). Balances are capped at 1e9 (`BalanceCap`).
  - Transaction ids are strings of 1-64 characters. The last 200 ids per player are stored *with the profile*, so a repeated id is refused (`DuplicateTransaction`), even after a rejoin.
  - A deduction larger than the balance is refused (`InsufficientFunds`).
- **Profile record** (DataStore `OutlawCity_PlayerData_v1`, key `player_<UserId>`): `{ Profile = { Version = 3, Cash, RecentTransactions, OwnedVehicles, PaidRewards }, Lock = { Id = serverSession, At = unixTime }? }`. v1 (cash only) and v2 (+ OwnedVehicles) records migrate on load; `PaidRewards` arrived in v3. In Studio the store name gets a `_Studio` suffix, so tests never touch live player data.
- **Load** (`ProfileStore.load`, one `UpdateAsync`):
  - No record -> new profile with starting cash 500.
  - A valid record is used exactly as stored (never reset).
  - A malformed record -> `Corrupt`: the load is refused and the record left untouched.
  - Another server's lock less than 180 s old -> `SessionLocked`.
  - Any store error -> `StoreError`.
- **Retries:** 3 attempts per round with 1/2/4 s backoff. If they all fail, the player is `Unavailable`: grants and deductions return `DataNotLoaded`, nothing is ever saved for them, and loading is retried every 30 s until it succeeds.
- **Write-through changes (audit remediation):** every grant, deduction and purchase goes through `ProfileStore.commit`. The change is applied to a copy of the profile, the copy is written in one `UpdateAsync` while this server owns the lock, and only then is it copied into the live profile. If the rule refuses or the write fails (2 attempts), nothing changes and the caller gets `SaveFailed`. So anything `EconomyService` reports as done is already stored. It survives a server crash, a failed leave-save, and another server taking the lock later.
- **ProfileSession (final audit fixes):** every write for one player goes through their `ProfileSession` (`Server/Data/ProfileSession`).
  - Commits and saves run one at a time, **strictly in arrival order** (ticketed FIFO queue; a refused ticket still passes the turn on).
  - **Ambiguous writes:** a write that errors may still have been stored. The session is then marked Stale, and nothing is written from memory until the stored profile has been read back (`ProfileStore.read`, our lock only) and adopted. A retried commit is re-applied to that stored state. If the stored state already contains it (its transaction id), it reports success (`AlreadyApplied`) without applying it twice. If the store can't even be read, the caller gets `SaveUnconfirmed` and the next operation reconciles first. Heartbeat and leave saves also reconcile first, so a stale copy never overwrites a stored change.
  - **Leaving / lock loss:** when the player leaves (`beginLeave`), any commit still queued or started later is refused with `SessionClosed`; only the final release-save runs. A heartbeat save that is queued or started after `beginLeave` is refused too, so nothing can interleave with or follow the release. When the lock is lost (another server took ownership), the session closes and every queued operation is refused.
- **Save / lock heartbeat** (`ProfileStore.save`): writes only while this server still owns the lock (`LockLost` otherwise). Every loaded profile is re-saved every 60 s, even with no changes, to keep its lock fresh. Before the remediation only changed profiles were saved, so a quiet player's lock could go stale while they were still in the game. Saves happen on leave (releasing the lock) and on shutdown (`BindToClose`, up to 25 s), with 3 attempts and backoff. A failed leave-save is retried in the background; it only releases the lock now, because every change was already stored when it happened.
- **Reward ledger (audit remediation):** earned rewards (robbery payouts, `EconomyService.grantReward`) are first written to a separate DataStore (`OutlawCity_PendingRewards_v1`, key `rewards_player_<UserId>`, `RewardLedger`), then granted write-through, then cleared from the ledger. If the grant can't be stored, `claimRewards` pays the ledger entry later. It runs right after each load (on any server) and then periodically during the session: every 300 s when nothing is outstanding, 30 s when something is, and on failure with backoff doubling from 30 s up to 900 s. A reward is lost only if the ledger write AND every grant retry fail and the player then leaves; that case is logged.
- **Durable reward dedupe (final audit fixes):** paying a ledger reward also records its id in the profile's `PaidRewards`, in the same write. The id stays there until a claim sees the ledger no longer lists it, then it is pruned. A reward can't pay twice however many other transactions follow; the 200-id `RecentTransactions` limit no longer matters for rewards.
- **Ledger invalid states (final audit fixes):**
  - a record that isn't the expected shape is `LedgerCorrupt`: never overwritten, reported, claims back off;
  - malformed entries are kept untouched and counted;
  - a reward is validated before it may enter the ledger (`RewardLedger.validate`: transaction id and amount by the profile's own rules, reason ≤ 100 characters, numeric time); anything else is refused as `InvalidReward` and nothing is written;
  - a full ledger (50 entries) refuses with `LedgerFull` (the reward is still paid directly if possible, otherwise it is retried in-session and logged);
  - lasting refusals (`BalanceCap`, `RewardHistoryFull`, invalid amount or id) mark the entry `Blocked` with the reason. It is kept, retried at the claim pace and paid once it fits.
- **Transaction ids:** robbery rewards use `robbery:<sessionGUID>` and purchases `buy:<vehicle>:<GUID>`. The last 200 ids are kept in the profile.
- **Studio-only tools:** dev commands `GrantCash`, `DeductCash` (raw values, so the server-side validation is what gets tested), `GrantCashTx` (fixed transaction id), `SetDataStoreFailure`, `SaveNow`. A Workspace attribute `SimulateDataStoreFailureOnStart` tests outages during load. All are gated by `RunService:IsStudio()`.

## Store robbery (Phase 4B)

- **Place:** one convenience store, `Workspace.City.Store` ("24/7 MART", `StoreId = "Store1"`), on the east edge of block (-200, 0) facing the x = -100 road (`CityLayout.store()`, built by `CityBuilder.buildStore` from `WorldService` if missing). It has an open doorway, a register with a `RobPrompt` ProximityPrompt (hold 1 s, 10 studs, key E / tap on mobile) and an invisible `Area` box covering the interior (the holdout zone).
- **Owner:** `RobberyService` owns every session. `RobberyRules` (pure, `RobberyRules.spec`) decides; the service supplies server facts (clock, positions, jail, safe zone, alive) and does the side effects.
- **Start** (prompt `Triggered`, on the server): alive, not jailed, not in a safe zone, on foot, within 10 + 4 studs of the register (server-measured), no live session for this player, the store isn't being robbed and isn't cooling down. Rejections go back as `OnRobberyNotice("Rejected", { Reason })` with a clear message on the HUD.
- **Police response (owner decision, option 1):** the 2★ and the police alert come at the start, but `PoliceService.setDispatchHold(player, true)` keeps the NPC unit from being dispatched to the robber until the holdout ends (or the robbery fails). A unit already chasing the player keeps chasing. Switch: `RobberyConfig.PoliceDispatchAtHoldEnd`.
- **Session:** id = `HttpService:GenerateGUID()` made on the server. Start reports `StoreRobbery` (70 heat = 2★) through `WantedService.reportCrime`; while holding it re-reports `RobberyInProgress` (0 heat) once a second so heat can't decay before the holdout ends. The store's 180 s cooldown starts when the robbery starts (success or failure).
- **Holdout (15 s, server clock):** fails with no cash on `Died` (death, reset or any character change), `Busted` (jailed), `LeftArea` (outside the store box), `Disconnected`.
- **Escape:** after the holdout the session becomes `Escaping` and the store frees up. The player must lose their wanted level (`WantedService.Escaped`, fired only when heat decays to zero, never for a bust or a reset). Fails with no cash on `Busted`, `Died`, `Disconnected`, or no escape within 300 s (`EscapeTimedOut`). Leaving the store is fine once escaping.
- **Payout:** `RobberyRules.onEscaped` moves `Escaping -> Paid` exactly once; then the reward becomes a *pending payout* with a stable transaction id `robbery:<sessionId>` and `EconomyService.grantReward` records it in the reward ledger and then grants it write-through. Three guards stop a second payout: the phase transition, a per-server paid-id set, and EconomyService's persisted duplicate-transaction check (a retry that hits `DuplicateTransaction` counts as already paid). An ordinary escape with no robbery session pays nothing.
- **Recoverable payout (4B follow-up):**
  - A robbery can't start unless the player's cash data is `Loaded` (`CashUnavailable`), so a reward is never earned when it couldn't be recorded.
  - If the grant can't be stored (`DataNotLoaded` or `SaveFailed`), `RobberyRules.payoutOutcome` says `Retry`. The reward stays pending (same tx id) and `RobberyPhase = "PayoutPending"`. The HUD says the reward is safely recorded (or, if even the ledger failed, to stay in the game). Payment is retried every 2 s without blocking the robbery tick loop. Other errors are final (`PayoutFailed`).
  - Pending rewards survive death, respawn and jail (they belong to the player, not the character). If recorded in the ledger, they also survive leaving and server crashes: they are paid on the next join.
  - Granted cash is stored at the moment it is granted (write-through).
- **Client:** `RobberyHudController` shows "ROBBING THE STORE Ns / Stay inside" while holding, "ESCAPE TO KEEP $2,000 / Break line of sight, then stay hidden until your stars are gone" while escaping ("Stars fading..." while `WantedEvading`) (from server attributes), and toasts for the alarm, rejections, failure reasons and the cash reward. It can't start, finish or pay anything.
- **Tuning:** `RobberyConfig` (hold, reward, cooldown, ranges, escape limit) and `WantedConfig.Crimes.StoreRobbery` are the only places to change values.
- **Failed-robbery cooldown (EXPERIMENTAL, audit 4 trial):** a session fails at most once: `RobberyRules.tick` does nothing once a session is Failed or Paid, and `RobberyService.failSession` ignores an entry that already ended. `RobberyConfig.FailedCooldownSeconds = 90`. A robbery that fails (died, busted, left, disconnected, timed out) shortens the store's cooldown to its start + 90 s, but only while it is still the store's latest robbery (`StoreState.LastSession`), so an old getaway failing late never cuts a newer robbery's cooldown. Successful robberies keep 180 s. `nil` restores the old behaviour.
- **Not built (by owner decision):** banks, more stores, gangs, weapons, new vehicles, monetization. Police stay at one NPC unit.

### Police pursuit tuning (audit remediation, EXPERIMENTAL; owner/auditor review pending)

`PoliceConfig`: `SightRange` 160 → 130, `ChaseSpeed` 110 → 100, `ChaseGain` 1.0 → 0.25. `WantedConfig.DecayDelay` stays 8 s. `PoliceDriveRules` is unchanged; the tuning is config only. In a solo A/B with the same scripted getaway (real `VehiclePhysics`):
- baseline: 3 of 5 runs paid;
- tuned: 5 of 5 runs paid, in 18–35 s.

See PROGRESS.md for the details. It's a small solo sample, so human playtests should decide the final values.

### NPC police at the storefront (recorded issue + proposal, not built)

- **Issue:** the single NPC unit is dispatched the moment the robbery starts and reaches the store in about 3-10 s, well inside the 15 s holdout. It drives at the player, so at the storefront it stalls against the building (`hard recovery: stalled repeatedly at (-113, -57..-64)`), pushes or blocks parked cars, and waits within bust range of the door. In 10 solo getaway attempts none succeeded: 5 busts at or near the door, 4 busts after crashing while the unit followed, and 1 death off the map edge.
- **Proposal: roadside stop (simple, no new pathfinding):** when the target is on foot and off the road network, the unit drives to the road node nearest the target, then to the closest point on that road's curb line, stops there with the handbrake on and stays put while the target remains within ~60 studs. It resumes normal pursuit as soon as the target enters a vehicle or moves more than ~60 studs away. It never drives off the road towards a building. Busting stays as now (within 18 studs, target slower than 5 studs/s for 2.5 s). Building it needs owner approval.

## Dealership and vehicle ownership (Phase 4C)

- **Profile v2:** `{ Version = 2, Cash, RecentTransactions, OwnedVehicles = { "Coupe", ... } }`. Every profile owns the starters (`EconomyConfig.StarterVehicles = { "Coupe" }`).
- **Migration** (`EconomyRules.validateSaved`, inside the load's `UpdateAsync`): a v1 (cash-only) record keeps its cash and transaction history exactly, gains `OwnedVehicles = { "Coupe" }`, and is written back as v2 in the same atomic update that claims the session lock (`loaded (Migrated)`). A record from a newer version, or a v2 record without its ownership list, is refused untouched (`Corrupt`), so an older server can never downgrade or wipe it.
- **Purchase (atomic):** `EconomyRules.purchaseVehicle(profile, vehicleId, price, txId)` checks the id, amount, duplicate transaction, not already owned, garage limit and funds, then takes the price, adds the car and remembers the transaction in one step on the same profile. Nothing yields in between. `EconomyService.purchaseVehicle` commits it write-through, so cash and ownership are stored together in one write BEFORE the purchase is acknowledged. A failed write returns `SaveFailed`: nothing is charged, there is no car, and the transaction id isn't used, so the player can simply retry.
- **Server API:** `DealershipService` handles `RequestPurchaseVehicle` (see the network table). Prices live only in `DealershipConfig` (Muscle: 15000). A second request for an owned car returns `AlreadyOwned` without charging.
- **Place:** `Workspace.City.Dealership` ("OUTLAW MOTORS") on the north edge of block (200, 200), facing the z = 100 road. It has a sales desk with `ShopPrompt` (opens the client window) and an anchored, non-drivable display Muscle.
- **Second vehicle:** `Muscle` (VehicleConfig): top speed 138 (Coupe 120), acceleration 68 (55), and heavier handling. It has less grip (9 vs 12), slower turning (yaw 1.85 vs 2.2), steering response 8 (10) and longer braking (100 vs 120).
- **Client:** the Spawn Car button opens the garage window (owned cars from `OwnedVehicles`); V spawns the last car chosen there (Coupe at first). The dealership window shows each car's price, its stats and Owned/Buy, plus a clear success or failure message. Both windows sit top-centre below the HUD row and use 44-48 px touch targets.
- **Studio-only test hooks:** dev `WriteLegacyProfile` rewrites the stored record as v1 and stops saving that session (rejoin to migrate). Workspace `SimulateDataStoreFailure` makes every store call fail; `SimulateStoreFailure_<storeName>` fails only that store (for example only the profile store while the reward ledger works).
- **Dealership handler safety:** `DealershipService` calls the economy through `pcall` and always clears the player's in-flight flag. An error returns `SaveUnconfirmed`, and the next operation reconciles from the store.
- **HTTP:** the place's "Allow HTTP Requests" (`HttpService.HttpEnabled`) is OFF. Game code only uses `GenerateGUID` and JSON helpers, which don't need it.
- **Not built (by owner decision):** more vehicles, banks, garages as buildings, property, gangs, weapons, monetization.

## New-player guidance (audit 4 onboarding batch)

Display only: nothing here changes rewards, prices, police, validation or who decides a robbery start or purchase. Values live in `OnboardingConfig`; logic in `OnboardingRules` (`OnboardingRules.spec`).
- **Re-spawn while driving (playability gate):** `VehicleService.spawnVehicle` leaves the player's current seat cleanly before the old car is removed, then sits them in the new car and retries for up to 1 s (10 × 0.1 s) until seated once. On the client, `VehicleController` follows `Humanoid.SeatPart` as well as `Seated`, and drops a current car that was removed.
- **P1 spawn shortcut:** `OnboardingRules.spawnChoice(owned, StarterVehicles)`. One candidate: Spawn Car (and its tap on phones) spawns that car and makes it the selection, so a stale earlier pick is never sent. 2+ cars: the garage window opens. While the owned list is empty (data not loaded or unavailable) only the starter Coupe counts, which the server always accepts. No candidates: nothing is sent. The server still checks ownership on every spawn.
- **P2 markers:** client `BillboardGui`s over `StoreSign` and `DealerSign`, 190x46 px, drawn through buildings, shown 35-450 studs from the sign, with the distance and a status line.
- **P3 tip:** once per session after the first spawn, at the left under the HUD row (12, 92), 250x84. Closes after 15 s, with X, or when `RobberyPhase` becomes `Holding` or `Escaping` (`OnboardingRules.isActiveRobbery`); other phase changes leave it. Only X takes input.
- **P4 escape hint:** matches `WantedRules`: heat decays only after `DecayDelay` (8 s) with no sighting and no new crime; the escape counts when the stars reach 0.
- **P5 store status:** the store marker shows Open / Being robbed / Reopens in m:ss from the server's store attributes; the register prompt shows "Reopens in m:ss" while cooling down.
- **P6 Muscle progress:** the dealership window's message line shows "Muscle: $X of $15,000. About N more successful robberies." (`ceil((price - cash) / RobberyConfig.Reward)`: 8 from the $500 start).
- **P7 compact robbery panel:** screens under 400 px tall get a 260x64 panel at y 92 (text 17/14 px) instead of 300x76 at y 136; `ScreenInsets = CoreUISafeInsets`.
- **P8 milestones (Studio only):** `Server.Dev.MilestoneLog` prints `[Milestone] <player> FirstCar|FirstRobbery|FirstEscape <s>s after join` once per session; a no-op outside Studio.

## City atmosphere (Batch 1)

Presentation only, all on the client (`Client.Controllers.AtmosphereController`), configured by `Shared.Config.AtmosphereConfig` and backed by the pure `Shared.Atmosphere.AtmosphereRules` (`AtmosphereRules.spec`).
- **Lighting flag:** applies the preset to this client's `Lighting`: ClockTime 16.5, warmer ambient, Atmosphere 0.32 / Haze 1 / Glare 0.2, Bloom 0.4, plus a local `ColorCorrectionEffect` named `OutlawAtmosphere`. The place's own Lighting (what the server and Studio hold) is never changed, so turning the flag off restores the original look on the next join. The original values are recorded in `AtmosphereConfig.OriginalLighting`.
- **PoliceLights flag:** while `Workspace.NpcVehicles.PoliceUnit` exists, the two `LightBar` parts alternate via `LocalTransparencyModifier` every 0.25 s, and one local `PointLight` (range 14, no shadows) follows the lit side. Everything is created once per unit and removed when the unit leaves. If single bars stream out and back in while the unit stays, the live bar list is rebuilt (`DescendantAdded`/`DescendantRemoving`), a departing bar gets its modifier reset, one bar blinks, no bars means the light waits unparented, and the light is never duplicated (`AtmosphereRules.litIndex`). In Studio the controller publishes live counts in the local player attribute `AtmosphereDebug`. The police unit, its AI and the pursuit values are untouched.
- **Siren flag:** off. It plays only with `Siren = true` and an owner-approved `SirenSoundId` (`rbxassetid://<digits>`); it would be a looped Sound on the unit's chassis with roll-off 250 studs, removed with the unit.

## City look (World polish Batch 1)

- **Districts:** `CityLayout.DISTRICTS` gives each block column a built-in material and a 3-colour palette: column 1 (west, 24/7 MART) "Old Town" Brick, column 2 "Civic" Concrete, column 3 (east, OUTLAW MOTORS) "Downtown" Slate. The original seeded colour roll is still drawn and only used to pick within the palette, so the RNG sequence, and therefore every building's size and position, is unchanged. Buildings carry `PartSpec.PhysicsMaterial = SmoothPlastic`, which `CityBuilder` applies as `CustomPhysicalProperties`, so collisions feel exactly as before.
- **One geometry exception:** `CityLayout.BUILDING_EAST_INSET = { Building_3_3_1 = 2.5 }` moves only that building's east edge, leaving a 2-stud gap to the dealership. `CityLayout.spec` locks every other generated part to a recorded signature.
- **Ground:** the template Baseplate keeps its size, position, material and physics. Its grid `Texture` is disabled (Transparency 1, not deleted) and the colour is a plain dark ground (62, 66, 58). This is a Studio-only change (the Baseplate isn't generated by code); rollback is Transparency 0.8 and colour 91, 91, 91.

- **Stop lines (N5, stop-line Batch 1):** `CityLayout.stopLineApproaches()` lists the 50 road arms entering the 16 grid intersections (6 four-arm, 6 three-arm, 4 two-arm; the four-arm ones at z = -300 get their north arm from the highway connectors). Each gets one `Markings.StopLine_<X>_<Z>_<side>` part (side N = -Z, S = +Z, W = -X, E = +X): white (235, 235, 235) SmoothPlastic, 16.4 x 1.2 x 0.05, top at `MARK_TOP` 0.25, its near edge 2 studs before the 36x36 intersection square. It covers only the incoming (right-hand) half of the road, from 0.6 studs off the centre of the road (0.2 studs clear of the yellow line) to 1 stud inside the curb. The parts are axis-aligned with the size swapped for W/E arms instead of rotated. They are built non-colliding, so `CityBuilder` also turns off CanQuery, CanTouch and CastShadow; cars, police raycasts and vehicle validation can't see them. The connector-highway joins and the plaza edges have none. `CityLayout.spec` checks the count, the 6/6/4 split, the footprint, the side and the centre-line clearance. Rollback: remove the loop in `createBlueprint` and delete `City.Markings.StopLine_*`.
- **Street-name signs (N4, one-sign prototype):**
  - **Data:** `CityLayout.streetSigns()` builds one spec per entry in `CityLayout.STREET_SIGNS`: the approved prototype (100, 100) corner (+22, +22), then Stage A (−100, −100) and (−100, 100) at corner (−22, −22) and (100, −100) at (+22, +22). Each corner puts the sign's one weak approach on the grid-edge side (`N4_STREET_SIGN_ROLLOUT_PLAN.md`). Names come from `STREET_NAMES_EW` (z → "1st St"…"4th St", counted from the highway side) and `STREET_NAMES_NS` (x → "A Ave"…"D Ave"). Plain names are approved for this prototype only.
  - **Build:** signs are not part of `createBlueprint`, so the 186-part signature and the stop lines are untouched. `CityBuilder.buildStreetSigns(city)` creates `City.StreetSigns` if needed and adds only signs whose model is missing, so calling it again never duplicates. `WorldService.init` calls it at every server start, which also covers a full rebuild of a missing City.
  - **Model `StreetSign_<X>_<Z>`:** `ModelStreamingMode = Atomic`, PrimaryPart `Post`. `Post` is 0.4 × 10.4 × 0.4, standing on the sidewalk top (0.6). Two blades sit on the post's axis, each running along the street it names: `Blade_EW` 7 × 1.5 × 0.2 at y 8.6 (faces ±Z) and `Blade_NS` 0.2 × 1.5 × 7 at y 10.2 (faces ±X).
  - **Text:** each blade has a `SurfaceGui` on both faces (`Label_<Face>`: PixelsPerStud 50, LightInfluence 0, MaxDistance 150), each with one white GothamBold `TextScaled` label.
  - **Collision:** all parts are anchored, with CanCollide, CanQuery, CanTouch and CastShadow false.
  - **Cantilevered blades (Architect option B, 2026-10-16):** each blade starts at a post face and extends 7 studs away from the junction (`Blade_EW` centre (125.7, 8.6, 122), `Blade_NS` centre (122, 10.2, 125.7)). No blade shares volume with the post or the other blade, so the post covers no text; the blades sit 3.9 studs from the road edge. This replaced the first prototype, whose blades ran through the post.
  - **Changing an existing sign:** `buildStreetSigns` skips a sign whose model already exists, so changing the spec doesn't change the place. A geometry change needs that one model replaced in Studio (as done for this fix); there's no general migration.
  - **Rollback:** remove `streetSigns`, `buildStreetSigns` and the WorldService call, and delete `City.StreetSigns`.

