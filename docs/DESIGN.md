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

## NPC police (Phase 3D prototype)

- One server-controlled police cruiser is dispatched when a player becomes wanted; more units only after owner approval.
- It drives the road network (no free-form pathfinding), slows for corners, avoids walls, and recovers when blocked by re-entering the road network out of the player's sight.
- Seeing the player (within 160 studs, clear line of sight) stops wanted heat from decaying. Breaking line of sight long enough lets heat decay to an escape.
- Busted: the player is stopped near the cruiser for 2.5 s while wanted. The wanted level is cleared with no reward and the player respawns on a plaza pad (the 10–15 s jail comes later).
- Ramming the cruiser with a car is a crime (+heat). Police never pursue or bust players with zero stars.

## Safe zones (Phase 3E)

- The central plaza, where everyone spawns, is the first safe zone. Inside it no player can harm another, whatever their combat status and even if the target is wanted.
- Safe zones don't help you escape: wanted levels, heat decay and police pursuit and busting work exactly as outside.
- A small SAFE ZONE badge shows while you're inside. It turns amber when you're wanted, as a reminder that police can still get you.

## Short jail

- When the police bust you, you go to a jail cell south of the city for 12 seconds (configurable 10-15). Your wanted level is cleared with no reward.
- While jailed you can't spawn or drive cars or use combat, and resetting your character doesn't get you out.
- When your time is up you respawn in the plaza with normal spawn protection. Your car, reputation and (future) cash are untouched.
- No escapes, jailbreak missions or bail in this version.

## Cash (Phase 4A foundation)

- Every player has a cash balance saved between sessions. New players start with $500.
- Only the server changes cash. Each reward or purchase has a unique transaction id, so the same event can never pay twice.
- If saved data can't be loaded, the game shows "$ offline", blocks cash changes and never overwrites the saved balance; it keeps retrying in the background.
- Nothing earns or spends cash yet. Robbery rewards and vehicle purchases come in later phases.
