# Questions for the auditor: 2026-10-14_atmosphere-batch1

Answer each by number.

## Correctness
1. The lighting is applied on each client and the place's own Lighting is left untouched. Is that an acceptable way to meet "reversible, original appearance recoverable"?
2. Police lights use `LocalTransparencyModifier` on the server-owned `LightBar` parts plus one local `PointLight`, with cleanup on ChildRemoved, AncestryChanged and a per-frame parent check. Do you see a leak or a duplicate path (for example streaming the model out and back in)?

## Evidence gaps
1. The after-FPS numbers were taken while Studio throttled itself to about 15 fps for every configuration. Is the same-session A/B (14.9 vs 15.2 vs 15.3 fps) enough for now, or must an unthrottled re-measurement come before approval?
2. One capture showed the OUTLAW MOTORS sign text missing with the new lighting (it has `LightInfluence = 0`). Do you want a re-check before approval?

## Owner decisions
1. The siren: approve one of the Roblox-licensed Pro Sound Effects IDs (9117810961, 9117810647), or keep it off?
2. Is Haze 1 / Glare 0.2 too hazy? Lower to Haze 0.5 if the owner thinks so.
