# OUTLAW CITY — Deferred multiplayer tests

Every item here is **MULTIPLAYER UNVERIFIED**: solo playtests cannot confirm it. Run with Test → Clients and Servers (2+ players) or a private server once possible. Required before live monetization or a public beta (owner approval also required).

Mark each item with the date and result when finally run.

## Phase 2 — Vehicles
- [ ] Two players spawn cars at the same time on different pads
- [ ] Each player sees the other's car move smoothly (no rubber-banding at normal speed)
- [ ] Player B enters Player A's parked car with E and drives it normally
- [ ] After B exits, the car stays put and is simulated by A again
- [ ] A player leaving removes their car; a car they were driving falls back to its owner
- [ ] Remote-player car wheels look acceptable (wheel animation is local to the simulating client)

## Phase 3A — Civilian spawning
- [ ] Several players joining at once get different civilian spawns (no stacking)
- [ ] A respawning player never lands on another player's character or parked car
- [ ] Other players see the spawn ForceField; `Status`/`SpawnProtectedUntil` attributes replicate to every client
- [ ] No team UI or team colours appear for anyone

(Removed: Police vs Criminal team tests — teams were dropped from the design.)

## Phase 3B — Wanted level
- [ ] Each player's wanted state is independent (one player's crime/decay/escape never changes another's)
- [ ] Other players can see a wanted player's `WantedLevel` attribute (for future UI), but only the wanted player gets Evading/Escaped banners
- [ ] A player leaving while wanted cleans up with no errors; rejoining starts at 0 stars
- [ ] 4 Hz decay loop cost stays negligible with a full server
- [ ] Reputation from an escape is credited only to the escaping player
