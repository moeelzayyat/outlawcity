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

## Phase 3C — Peaceful / Combat (needs real PvP damage to exist first)
- [ ] Two Combat players outside safe zones can harm each other; either being Peaceful (and not wanted) blocks it
- [ ] A Peaceful player cannot harm a wanted player
- [ ] A Combat player can harm a wanted player who is in Peaceful mode, outside safe zones only
- [ ] Spawn protection blocks harm in both directions for 5 s
- [ ] Other players see each player's `CombatStatus` correctly (for future nameplate/UI)
- [ ] Rate limit and cooldown hold per player with several players toggling at once

## Phase 3D — NPC police (single unit)
- [ ] With two wanted players, the unit chases the most-wanted one and the other's heat behaves per sightings
- [ ] Other players see the police car move smoothly (server-simulated; replication not tested)
- [ ] Another player's car in the road doesn't trap the unit (whiskers ignore vehicles; relies on stuck recovery)
- [ ] A second player ramming the unit gets the RammingPolice crime, not the target
- [ ] Busting one player never affects another's wanted level or position
- [ ] A human driver (not the scripted test car) can be chased, lose the unit and escape
