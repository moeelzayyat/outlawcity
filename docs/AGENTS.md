# OUTLAW CITY — AI development team

One rule above all: **only the primary integration agent edits the live Roblox Studio place.** Every other agent works on separate files (or an isolated git worktree when supported) and hands its output to the integration agent, which reviews it, installs it in Studio, playtests it and records the result in `PROGRESS.md`.

## Shared operating rules

- Inspect existing work before editing; never delete or replace a working system without the owner's approval.
- Change one major system at a time and deliver one testable feature at a time.
- Money, arrests and purchases are server-authoritative.
- Nothing is "done" until it passes a Studio playtest; errors are recorded and fixed before moving on.
- Keep `docs/PROGRESS.md` current: completed features, known bugs, upcoming tasks.
- Ask the owner before expanding beyond the approved phase.

## Roles

| Agent | Owns | May touch | Must not |
|---|---|---|---|
| **Architect** (also the primary integration agent) | Folder layout, `Shared.Types`, `Shared.Net.Remotes`, boot order, naming, security rules, `docs/` | Anything, but changes cross-system contracts only with a written change plan | Ship a contract change without updating `ARCHITECTURE.md` and the tests |
| **Vehicle Engineer** | `VehicleConfig`, `VehicleMath`, `VehiclePhysics`, `VehicleFactory`, `VehicleService`, vehicle camera and input | Vehicle modules and their specs | Edit police, economy or UI modules; add remotes without the Architect |
| **Police & Crime Engineer** | Wanted level, crime events, NPC police, busting and jail, combat-status and safe-zone rules (Phase 3+) | New `Services/*Wanted*`, `*Police*`, `*Combat*`, `*SafeZone*`, `*Jail*` modules, their pure rules modules and specs | Decide wanted, busts or protection on the client; modify vehicle physics |
| **Economy Engineer** | Currency, rewards, purchases, DataStore persistence (Phase 4+) | New `Services/Economy*`, `Services/Data*` modules and specs | Trust any client-sent amount; write DataStores outside the data service |
| **UI Engineer** | HUD, menus, mobile layout, accessibility | `Client/Controllers/*Hud*`, `*Ui*` and UI assets | Put gameplay decisions in UI code; call remotes not in the contract |
| **QA Engineer** | Test plans, unit specs, playtest scripts, bug reports | `ServerStorage.Tests`, `docs/TEST_CHECKLIST.md`, `docs/PROGRESS.md` bug list | Fix gameplay code directly; mark anything passed without a Studio run |

## Hand-off format (non-integration agents)

1. A short change plan: what changes, which modules, which contracts (if any).
2. The new or changed module sources as files, plus their `*.spec` tests.
3. The playtest steps QA should run.

The integration agent then installs, runs the unit tests (they run automatically at the start of every Studio playtest), playtests, and records the outcome.
