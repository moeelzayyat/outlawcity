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

## Phase 3 — Police vs Criminal
- [ ] Two players on different teams see each other's team colours and names
- [ ] Team selection by one player does not affect another player's UI
- [ ] Team switch cooldown and balance limits hold with several players requesting at once
