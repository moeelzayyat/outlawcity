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

## Phase 3E — Safe zones
- [ ] Each player's `InSafeZone` replicates correctly to every client
- [ ] Two Combat players: no harm when either stands in the plaza; harm allowed once both are outside (needs real PvP damage first)
- [ ] A wanted player in the plaza is protected from Combat players but still busted by NPC police
- [ ] Spawn camping: players arriving at plaza spawns can't be attacked from outside the zone

## Phase 3G — Vehicle movement validation (monitor-only)
- [ ] Real network latency and packet loss don't cause Teleport or Overspeed false positives (laggy clients, varied ping)
- [ ] Ownership handover when a second player enters someone else's car stays within the 1.5 s grace
- [ ] Two cars colliding head-on at top speed between two clients produce no sustained alerts
- [ ] The 5 Hz loop cost stays negligible with a full server of cars

## Short jail
- [ ] Two players busted at once get different cell slots and don't overlap
- [ ] Other players see the jailed player in the cell; nobody can harm or seat them
- [ ] A jailed player's parked car can be used by another player (ownership rules) without freeing the prisoner
- [ ] Leaving and rejoining mid-sentence (currently ends the sentence: session-only) — decide the desired behaviour with persistence

## Phase 4A — Cash and persistence
- [ ] Two servers: a player who rejoins quickly onto another server while the first is still saving waits for or takes over the lock correctly (no lost or doubled cash)
- [ ] Other players can't see or change anyone else's balance through any remote
- [ ] Autosave under many players stays within DataStore request budgets (no throttling errors)
- [ ] Published game uses the live store (no `_Studio` suffix) and Studio tests never touch it

## Phase 4B — Store robbery
- [ ] Two players at the register: only one session starts; the other sees "Someone is already robbing this store", then the cooldown message
- [ ] Other players see the robber's wanted stars / police chase normally; nobody else is paid
- [ ] A robber who leaves the game mid-robbery gets nothing and the store frees up for others
- [ ] Holdout area check under real latency (no false "left the store" for a player standing inside)
- [ ] Exploit attempts (fake position, spamming the prompt, firing remotes) don't start, finish or pay a robbery

## Phase 4C — Dealership and second vehicle
- [ ] Two players buy at the same time: each is charged once and owns the car; neither affects the other's balance or garage
- [ ] Another player can't spawn, buy for, or see into someone else's garage; spawning someone else's car id is refused (`NotOwned`)
- [ ] A player who rejoins onto another server right after buying keeps the car (session lock hand-over between two real servers)
- [ ] Other players see the display car and a player's Muscle correctly (models, wheels, colour)

## Audit remediation (economy durability, police tuning)
- [ ] Two real servers: buy on server A, rejoin onto server B right away -> the car and the charge are there (write-through; the lock hand-over waits for A's release or expiry)
- [ ] A robbery reward recorded in the ledger on server A is paid on server B after A shuts down mid-outage
- [ ] DataStore request budgets with many players (one write per cash change + 60 s heartbeat each)
- [ ] Police tuning with real human drivers and latency: escapes are possible but not trivial

## Final audit fixes
- [ ] Player leaves mid-purchase on a live server: nothing queued runs after the release-save; rejoin elsewhere shows a consistent profile
- [ ] Two real servers: server B takes the lock while server A has a queued grant -> A refuses it (SessionClosed); B's data untouched
- [ ] Ledger reward paid exactly once when two servers both try to claim it around a hand-over
