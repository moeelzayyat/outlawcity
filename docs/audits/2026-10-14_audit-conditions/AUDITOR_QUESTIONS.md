# Questions for the auditor: 2026-10-14_audit-conditions

Answer each by number.

## Conditions
1. Do the FIFO ticket queue and the leave rule in `ProfileSession` close conditions 1 and 2? Can you see any path that stalls the queue (for example an error inside fn: `Serving` is advanced before the error is re-raised)?
2. Does `RewardLedger.validate` close condition 4, or should it also reject unknown fields or cap `At` to a plausible time range?

## Player-experience plan
1. Of P1–P8 in PLAYER_EXPERIENCE_AUDIT.md, which would you approve as-is, which would you change, and which would you drop?
2. Are the proposed targets (one tap to the first car, first robbery started within 90 s, robbery panel ≤ 7% of a phone screen, idle time after a bust ≤ 2 min) sensible and measurable enough?
3. Any risk that P2's world markers or P3's tip conflict with the solo-test policy or the anti-cheat rules?

## Decisions the owner should make
1. Pacing: keep the Muscle at $15,000 (about 21 minutes of robbing) or lower it; and the store cooldown (180 s, or shorter after a failed robbery). What would you advise?
