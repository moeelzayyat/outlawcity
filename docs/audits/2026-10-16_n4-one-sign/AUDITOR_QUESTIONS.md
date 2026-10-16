# Questions for the auditor: 2026-10-16_n4-one-sign

Answer each by number.

## Finding: the post hides about one letter per face
1. The approved geometry puts the 0.4-thick post through the centre of each 0.2-thick blade, so it hides about 0.4 stud of text on all four faces. Which fix should the next step use?
   - (a) Mount each blade beside the post rather than through it. Shift each blade 0.3 stud across, so one face clears the post; the back face is still partly hidden.
   - (b) Cantilever each blade from the post: its inner end touches the post face and the blade extends away from the road. This clears the text completely but moves the blades about 3.7 studs further from the road edge.
   - (c) Keep the geometry and split each label into two text halves either side of the post.
   - (d) Accept as is.

## Evidence
1. Desktop text measured ~15 px at ~33 studs and 5–7 px at 62–68 studs. Is "readable but small at 60" acceptable, or should the blade or text be larger before any rollout?
2. One after-FPS set had two hitches (57.8 / 50.7 fps); the immediate repeat set was 60 fps ×6. Is that acceptable as not attributable to 3 static parts?
3. Phone-simulator readability is NOT TESTED (Device Simulator isn't available to me). Should the owner run it before the next step, or does it wait for a later phone pass?
4. Is the east-approach result acceptable (the sign is out of view at the stop line and read from 30–60 studs back)?

## Architecture
1. Is building signs outside `createBlueprint` through an idempotent `buildStreetSigns` called at server start acceptable as the pattern for any future signs?
