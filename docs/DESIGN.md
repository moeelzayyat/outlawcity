# OUTLAW CITY — Game design (revised 2026-10-13)

**Direction change:** there are no permanent Police and Criminal teams. OUTLAW CITY is a GTA-inspired shared open world. Everyone joins as a civilian and chooses what to do.

## Core rules

1. All players spawn as **civilians**.
2. Players can drive, explore, race, socialize and take part in criminal activity.
3. Illegal actions raise a **dynamic wanted level**.
4. Wanted levels trigger **NPC police** responses.
5. Escaping the police lowers the wanted level and can reward successful crime.
6. PvP is opt-in through a **Peaceful / Combat status**.
7. Peaceful players are protected from unwanted PvP.
8. **Safe zones** block attacks and spawn camping.
9. Progression covers driving, criminal reputation, wealth, vehicle ownership and customization.
10. Player-controlled police or bounty hunters may come later. They are not part of the MVP.

## Kept from earlier phases

- Vehicle physics, the city and highway map, driving controls (keyboard, gamepad, touch) and the chase camera.
- Vehicle ownership and customization (the "garage") stay planned for the progression phase. Nothing for the garage has been built yet.
- The architecture: Shared / Server / Client split, `init`/`start` services and controllers, one network contract (`Shared.Net.Remotes`), server validation and rate limits on every remote, and unit tests that run on every Studio playtest.

## Not in the MVP without further approval

Complex NPC pathfinding, weapons, PvP combat, robberies, player-controlled police, bounty hunters.

## Server authority

The server alone decides wanted level, crimes, combat status, safe-zone protection, police spawns and arrests ("busted"). Clients only send requests (for example "switch to Combat") and display state. Per-player state is published as attributes the server sets on each `Player`, so clients can read it but cannot change what others see.

## Rules engine shape (for testability)

Decisions live in pure modules that take plain tables, not `Player` instances, so they can be unit-tested with mock players in solo Studio runs:
- `WantedRules`: heat from crimes, star thresholds, decay, escape detection
- `CombatRules`: `canHarm(attacker, victim, context)`. Every future damage source must call this.
- `SafeZoneRules`: point-in-zone tests and protection exceptions
- `PoliceDispatchRules`: how many units each wanted level gets, and where they spawn

## Owner-approved rules (2026-10-13)

- Wanted: 3 stars for the MVP, extensible to 5. Heat decays only when no new crime and no police sighting for a while; reaching zero heat is an escape (reputation for 2★+). Wanted level survives respawn.
- Busted: short jail of ~10–15 s, no fine (built after NPC busting works).
- Peaceful / Combat:
  - Everyone starts Peaceful; Combat is opt-in.
  - Peaceful players can't attack anyone and can't be attacked by players — **unless they are wanted**, in which case Combat players may attack them outside safe zones.
  - Wanted players can't switch to Peaceful; switching to Peaceful also waits out a 30 s combat cooldown.
  - Toggling status never changes the wanted level.
- Safe zones block all player-vs-player harm (wanted players included) but never cancel wanted levels and never protect wanted players from NPC police.
- Spawn protection (5 s) blocks player-vs-player harm.
- NPC police may pursue and bust any wanted player regardless of combat status.
- Phase 3 has no weapons and no real PvP damage: combat rules are implemented and unit-tested only.
