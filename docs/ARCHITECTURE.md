# OUTLAW CITY — Architecture

Status: Phase 1 + Phase 2 (driving prototype). Last updated 2026-10-13.

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
  Remotes/                     (runtime) created by the server from Net/Remotes

ServerScriptService
  Server/
    Main                       (Script) server entry point; boots services, runs tests in Studio
    Services/WorldService      owns the test map; exposes vehicle spawn pads
    Services/PlayerStateService  single owner of per-player gameplay state, published as Player attributes
    Services/SpawnService      picks each civilian's next spawn (RespawnLocation) before every spawn
    Services/WantedService     per-player wanted state; reportCrime() entry point; 4 Hz decay loop; notices
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
    Controllers/DevPanelController       STUDIO ONLY dev panel (F8 toggles); absent without DevRemotes
    Vehicle/VehiclePhysics               raycast suspension + arcade handling

Workspace
  City/                        built once in edit mode by CityBuilder (saved in the place)
    Roads, Markings, Sidewalks, Plaza, Buildings, Highway, Barriers, VehicleSpawns
  Vehicles/                    (runtime) spawned vehicles, owned by VehicleService
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

- Server `Main`: `Remotes.createAll()` → `service.init()` for each service in order (World, PlayerState, Spawn, Vehicle, Wanted, DevTools) → `service.start()` for each → sets `Workspace.ServerReady` → in Studio runs unit tests (disable with `Workspace` attribute `RunTestsOnStart = false`).
- Client `Main`: `VehicleInputController.init()` → `VehicleController.init()` → `VehicleCameraController.init()` → `VehicleHudController.init()` → `WantedHudController.init()` and `DevPanelController.init()` (both spawned), then wires input action signals.
- HUD placement: the top-right corner belongs to Roblox's player list; game buttons live in the top-centre row.
- Dev tools (Phase 3+): Studio-only, created only when `RunService:IsStudio()` is true on the server, so they can never activate in published servers.
- Every service exposes `init()` (setup, may yield) and `start()` (connect runtime events). Every controller exposes `init()`.

## Network contract (event contracts)

All remotes live in `ReplicatedStorage.Shared.Net.Remotes.Definitions`. Nothing else may create remotes.

| Remote | Type | Direction | Payload | Server validation |
|---|---|---|---|---|
| `RequestSpawnVehicle` | RemoteFunction | client → server | `(vehicleId: string) -> (ok: boolean, err: SpawnError?)` | string, 1–32 chars, known id, alive, 3 s cooldown, free pad |
| `RequestExitVehicle` | RemoteEvent | client → server | `()` | 0.5 s cooldown, caller must be in a `DriverSeat` under `Workspace.Vehicles` |
| `OnWantedNotice` | RemoteEvent | server → client | `(kind: "Evading" \| "Escaped", payload: { Stars?, FromStars?, Reputation? })` | server-only sender; the server never listens to it |

`SpawnError = "BadRequest" | "UnknownVehicle" | "NotAlive" | "Cooldown" | "NoFreeSpawn"`.

Studio-only (not in the contract; created by `DevToolsService` only when `RunService:IsStudio()`): `ReplicatedStorage.DevRemotes.RequestDevCommand` (RemoteFunction) `(name, value) -> (ok, err)` with commands `SetHeat`, `SetStars`, `ReportCrime`, `ResetWanted`, `SetPoliceSight`, validated by `DevCommandRules` and re-checked against `IsStudio` on every call.

Replicated Player attributes (server-written only, names in `Shared.Player.PlayerAttributes`): `Status` (`"Civilian"`), `SpawnProtectedUntil` (server time), `WantedLevel` (stars), `WantedHeat`, `WantedEvading`, `CriminalReputation` (session only until persistence). Client writes to these never replicate (verified in playtest). Later stages add combat-status and safe-zone attributes here.

## Wanted system

- **Rules engine** (`WantedRules`, pure): crimes add heat (per-crime heat + per-player cooldown), heat maps to stars through `WantedConfig.StarThresholds` (3 entries = 3 stars; adding entries extends to 5 without code changes), heat is capped at `MaxHeat`. Heat decays at `DecayRate`/s only after `DecayDelay` s with no crime **and** no police sighting ("Evading"). Reaching 0 heat is an escape from the episode's peak stars; reputation is awarded for peaks ≥ `EscapeMinStars`.
- **Service** (`WantedService`, server): owns states, runs the 4 Hz step loop, publishes attributes, sends `OnWantedNotice`. Public API: `reportCrime(player, crimeType)` (the only way crimes enter), `resetWanted(player)` (busted/admin, no reward), `getStars(player)`, `setPoliceSightProvider(fn)` (NPC police plug in here in 3D). Wanted level persists through respawn (resetting the character does not clear it).
- **Crime detection is separate**: detectors (3D police sightings/collisions, future robberies) live in their own modules and only call `reportCrime`. As of 3B **no gameplay detector exists**; every crime so far was injected through Studio dev tools.

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
