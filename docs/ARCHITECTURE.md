# OUTLAW CITY — Architecture

Status: Phases 1-3 built and solo-tested (driving, civilian spawning, wanted, combat rules, one NPC police unit, safe zones, monitor-only vehicle validation, short jail); Phase 4A (cash + persistence) approved; Phase 4B (one convenience-store robbery) provisionally approved; 4B follow-up fixes (recoverable payouts) done; driving getaway not yet validated (see PROGRESS), so Phase 4C has not started. Last updated 2026-10-14.

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
    Config/RobberyConfig       store robbery tuning (hold 15 s, reward 2000, cooldown 180 s, ranges)
    Robbery/RobberyRules       pure robbery state machine: start checks, holdout, escape, single payout (unit-tested)
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
    Controllers/RobberyHudController     robbery objective panel (countdown / escape) and result toasts
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

- Server `Main`: `Remotes.createAll()` → `service.init()` for each service in order (World, PlayerState, Spawn, Economy, SafeZone, Jail, Wanted, Robbery, Combat, Police, DevTools, Vehicle, VehicleValidation, the order in `Main`) → `service.start()` for each → sets `Workspace.ServerReady` → in Studio runs unit tests (disable with `Workspace` attribute `RunTestsOnStart = false`).
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
| `OnRobberyNotice` | RemoteEvent | server → client | `(kind: "Rejected" \| "Started" \| "Escape" \| "Failed" \| "Paid" \| "PayoutFailed", payload: { Reason?, CooldownLeft?, Id?, HoldEndsAt?, Reward?, Amount? })` | server-only sender; the server never listens to it. There is **no client robbery request remote**: robberies start from the register's ProximityPrompt (`Triggered` on the server) |

`SpawnError = "BadRequest" | "UnknownVehicle" | "NotAlive" | "Cooldown" | "NoFreeSpawn"`.

Studio-only (not in the contract; created by `DevToolsService` only when `RunService:IsStudio()`): `ReplicatedStorage.DevRemotes.RequestDevCommand` (RemoteFunction) `(name, value) -> (ok, err)` with commands `SetHeat`, `SetStars`, `ReportCrime`, `ResetWanted`, `SetPoliceSight`, validated by `DevCommandRules` and re-checked against `IsStudio` on every call. Later stages added `SimulateBust`, cash commands (4A), `ClearRobberyCooldown` and `TryRobStore` (4B: runs the same server checks as the register prompt without the prompt's own range limit, so rejections can be tested).

Replicated Player attributes (server-written only, names in `Shared.Player.PlayerAttributes`): `Status` (`"Civilian"`), `SpawnProtectedUntil` (server time), `WantedLevel` (stars), `WantedHeat`, `WantedEvading`, `CriminalReputation` (session only until persistence), `CombatStatus`, `CombatCooldownUntil` (server time, 0 = none), `InSafeZone` (SafeZoneService, 4 Hz), `Jailed`, `JailReleaseAt` (JailService), `Cash`, `CashStatus` (EconomyService), `RobberyPhase` (`Holding`/`Escaping`, else nil), `RobberyHoldEndsAt` (server time), `RobberyReward` (display only) (RobberyService). Client writes to these never replicate (verified in playtest). Later stages add combat-status and safe-zone attributes here.

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
- **Profile record** (DataStore `OutlawCity_PlayerData_v1`, key `player_<UserId>`): `{ Profile = { Version, Cash, RecentTransactions }, Lock = { Id = serverSession, At = unixTime }? }`. In Studio the store name gets a `_Studio` suffix, so tests never touch live player data.
- **Load** (`ProfileStore.load`, one `UpdateAsync`):
  - No record -> new profile with starting cash 500.
  - A valid record is used exactly as stored (never reset).
  - A malformed record -> `Corrupt`: the load is refused and the record left untouched.
  - Another server's lock less than 180 s old -> `SessionLocked`.
  - Any store error -> `StoreError`.
- **Retries:** 3 attempts per round with 1/2/4 s backoff. If they all fail, the player is `Unavailable`: grants and deductions return `DataNotLoaded`, nothing is ever saved for them, and loading is retried every 30 s until it succeeds.
- **Save** (`ProfileStore.save`): writes only while this server still owns the lock (`LockLost` otherwise). Autosave runs every 60 s for changed profiles. Saves happen on leave (releasing the lock) and on shutdown (`BindToClose`, up to 25 s). Each save makes 3 attempts with backoff, and failures are logged and kept for the next save.
- **Future use:** robbery rewards and vehicle purchases will call grant/deduct with their own unique ids (e.g. `robbery:<id>`, `buy:<vehicle>:<id>`). `Profile.Version` allows adding owned vehicles later via a migration.
- **Studio-only tools:** dev commands `GrantCash`, `DeductCash` (raw values, so the server-side validation is what gets tested), `GrantCashTx` (fixed transaction id), `SetDataStoreFailure`, `SaveNow`. A Workspace attribute `SimulateDataStoreFailureOnStart` tests outages during load. All are gated by `RunService:IsStudio()`.

## Store robbery (Phase 4B)

- **Place:** one convenience store, `Workspace.City.Store` ("24/7 MART", `StoreId = "Store1"`), on the east edge of block (-200, 0) facing the x = -100 road (`CityLayout.store()`, built by `CityBuilder.buildStore` from `WorldService` if missing). It has an open doorway, a register with a `RobPrompt` ProximityPrompt (hold 1 s, 10 studs, key E / tap on mobile) and an invisible `Area` box covering the interior (the holdout zone).
- **Owner:** `RobberyService` owns every session. `RobberyRules` (pure, `RobberyRules.spec`) decides; the service supplies server facts (clock, positions, jail, safe zone, alive) and does the side effects.
- **Start** (prompt `Triggered`, on the server): alive, not jailed, not in a safe zone, on foot, within 10 + 4 studs of the register (server-measured), no live session for this player, the store isn't being robbed and isn't cooling down. Rejections go back as `OnRobberyNotice("Rejected", { Reason })` with a clear message on the HUD.
- **Session:** id = `HttpService:GenerateGUID()` made on the server. Start reports `StoreRobbery` (70 heat = 2★) through `WantedService.reportCrime`; while holding it re-reports `RobberyInProgress` (0 heat) once a second so heat can't decay before the holdout ends. The store's 180 s cooldown starts when the robbery starts (success or failure).
- **Holdout (15 s, server clock):** fails with no cash on `Died` (death, reset or any character change), `Busted` (jailed), `LeftArea` (outside the store box), `Disconnected`.
- **Escape:** after the holdout the session becomes `Escaping` and the store frees up. The player must lose their wanted level (`WantedService.Escaped`, fired only when heat decays to zero, never for a bust or a reset). Fails with no cash on `Busted`, `Died`, `Disconnected`, or no escape within 300 s (`EscapeTimedOut`). Leaving the store is fine once escaping.
- **Payout:** `RobberyRules.onEscaped` moves `Escaping -> Paid` exactly once; then the reward becomes a *pending payout* with a stable transaction id `robbery:<sessionId>` and `EconomyService.grant` is tried. Three guards stop a second payout: the phase transition, a per-server paid-id set, and EconomyService's persisted duplicate-transaction check (a retry that hits `DuplicateTransaction` counts as already paid). An ordinary escape with no robbery session pays nothing.
- **Recoverable payout (4B follow-up):**
  - A robbery can't start unless the player's cash data is `Loaded` (`CashUnavailable`), so a reward is never earned when it couldn't be recorded.
  - If the grant fails temporarily (`DataNotLoaded`), `RobberyRules.payoutOutcome` says `Retry`: the reward stays pending (same tx id), `RobberyPhase = "PayoutPending"`, the HUD shows "REWARD PENDING", and it is retried every 2 s until it is paid. Other errors are final (`PayoutFailed`).
  - Pending rewards survive death, respawn and jail (they belong to the player, not the character). Leaving the game while still pending is the one case that drops it; it is logged with a warning and the player was told to stay.
  - Once granted, the cash lives in the profile. If saves then fail, autosave keeps retrying; if the save on leave fails, EconomyService keeps the profile as an *orphan* on this server and retries every 10 s for up to 15 min (stopping if another server takes the lock), plus once more at shutdown. A player who rejoins the same server before it saves gets the newer in-memory profile back.
- **Client:** `RobberyHudController` shows "ROBBING THE STORE Ns / Stay inside" while holding, "ESCAPE THE POLICE / Lose your wanted stars to keep $2,000" while escaping (from server attributes), and toasts for the alarm, rejections, failure reasons and the cash reward. It can't start, finish or pay anything.
- **Tuning:** `RobberyConfig` (hold, reward, cooldown, ranges, escape limit) and `WantedConfig.Crimes.StoreRobbery` are the only places to change values.
- **Not built (by owner decision):** banks, more stores, gangs, weapons, new vehicles, monetization. Police stay at one NPC unit.

### NPC police at the storefront (recorded issue + proposal, not built)

- **Issue:** the single NPC unit is dispatched the moment the robbery starts and reaches the store in about 3-10 s, well inside the 15 s holdout. It drives at the player, so at the storefront it stalls against the building (`hard recovery: stalled repeatedly at (-113, -57..-64)`), pushes or blocks parked cars, and waits within bust range of the door. In 10 solo getaway attempts none succeeded: 5 busts at or near the door, 4 busts after crashing while the unit followed, and 1 death off the map edge.
- **Proposal: roadside stop (simple, no new pathfinding):** when the target is on foot and off the road network, the unit drives to the road node nearest the target, then to the closest point on that road's curb line, stops there with the handbrake on and stays put while the target remains within ~60 studs. It resumes normal pursuit as soon as the target enters a vehicle or moves more than ~60 studs away. It never drives off the road towards a building. Busting stays as now (within 18 studs, target slower than 5 studs/s for 2.5 s). Building it needs owner approval.
