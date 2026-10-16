# Test evidence: 2026-10-16_n4-mobile-diagnosis

- **Studio instance:** `Outlaw City (placeId: 132163592957463)`, Edit mode; the query asserted `game.PlaceId`. **Read only: nothing changed.**
- **Simulator:** not re-run. The existing simulator evidence (`2026-10-16_n4-sim-test`) is reused.
- **Tests:** not run (no code changed); the last run was 216/216.

## HUD layout (from source, not changed)
| GUI | Element | Position | Size |
|---|---|---|---|
| `CashHud` | Cash label, anchor (1, 0) | `UDim2.new(0.5, 164, 0, 58)` | 108 x 26, TextSize 15 |
| `SafeZoneHud` | Badge | `UDim2.new(0.5, -164, 0, 58)` | 108 x 26 |
| `WantedHud` | Star row, anchor (0.5, 0) | `UDim2.new(0.5, 0, 0, 58)`; banner at y 96 | 34 px per star; banner 320 x 36 |
| `CombatStatus` | Combat button | `UDim2.new(0.5, -84, 0, 8)` | 160 x 44 |
| `OutlawHud` | Spawn Car button | `UDim2.new(0.5, 84, 0, 8)` | 160 x 44 |
| `RobberyHud` | Panel | y 136 (compact on phones) | 300 x 76 |
| `OutlawHud` | Touch controls | GAS 100 x 100 at (1, -20, 1, -20); BRAKE 90 x 90; DRIFT 90 x 50; EXIT 100 x 44, up to about 172 px from the bottom | - |
| `VehicleCameraController` | Chase camera | 20 behind (+8 at speed), 6 up, focus 2.5 up + 6 ahead, FOV 70 (+12 at speed) | - |

**Cash badge measured from the simulator captures:**
- iPhone 7 (666 x 374): x 389-497, y 118-142.
- iPhone 13 Pro Max (831 x 427): x 467-563, y 106-127.

## Read-only query output (exact)
- **Clearances:** the candidate blade sizes on the four existing signs, with the cantilever rule.
- **Projections:** chase-camera projections on the two simulated viewports (a geometric model of the game camera at rest; the real camera eases).

```
current 7x1.5: blades off sidewalk 0; min road 3.90; min marking 5.00; min building/store/dealer 10.90 (StreetSign_100_-100->Building_3_2_1)
10x2.4: blades off sidewalk 0; min road 3.90; min marking 5.00; min building/store/dealer 9.49 (StreetSign_100_-100->Building_3_2_1)
12x3: blades off sidewalk 0; min road 3.90; min marking 5.00; min building/store/dealer 8.99 (StreetSign_100_-100->Building_3_2_1)
chase C Ave -Z to (100,-100), near corner, car 45 out, current 7x1.5, iPhone7: text cap 6.4 px; text box x 419..459 y 150..157; covered by cash badge 0%
chase C Ave -Z to (100,-100), near corner, car 45 out, current 7x1.5, 13ProMax: text cap 7.3 px; text box x 513..559 y 172..179; covered by cash badge 0%
chase C Ave -Z to (100,-100), near corner, car 45 out, 10x2.4, iPhone7: text cap 10.2 px; text box x 419..477 y 146..156; covered by cash badge 0%
chase C Ave -Z to (100,-100), near corner, car 45 out, 10x2.4, 13ProMax: text cap 11.6 px; text box x 514..580 y 166..178; covered by cash badge 0%
chase C Ave -Z to (100,-100), near corner, car 45 out, 12x3, iPhone7: text cap 12.8 px; text box x 420..489 y 142..155; covered by cash badge 0%
chase C Ave -Z to (100,-100), near corner, car 45 out, 12x3, 13ProMax: text cap 14.6 px; text box x 515..594 y 163..177; covered by cash badge 0%
chase C Ave -Z to (100,-100), near corner, car 25 out, current 7x1.5, iPhone7: text cap 11.9 px; text box x 493..568 y 150..162; covered by cash badge 0%
chase C Ave -Z to (100,-100), near corner, car 25 out, current 7x1.5, 13ProMax: text cap 13.5 px; text box x 598..684 y 171..185; covered by cash badge 0%
chase C Ave -Z to (100,-100), near corner, car 25 out, 10x2.4, iPhone7: text cap 19.1 px; text box x 495..603 y 141..160; covered by cash badge 0%
chase C Ave -Z to (100,-100), near corner, car 25 out, 10x2.4, 13ProMax: text cap 21.8 px; text box x 600..723 y 161..183; covered by cash badge 0%
chase C Ave -Z to (100,-100), near corner, car 25 out, 12x3, iPhone7: text cap 23.9 px; text box x 496..626 y 135..159; covered by cash badge 0%
chase C Ave -Z to (100,-100), near corner, car 25 out, 12x3, 13ProMax: text cap 27.3 px; text box x 602..750 y 154..181; covered by cash badge 0%
chase C Ave +Z to (100,100), far corner, car 45 out, current 7x1.5, iPhone7: text cap 3.1 px; text box x 216..236 y 151..154; covered by cash badge 0%
chase C Ave +Z to (100,100), far corner, car 45 out, current 7x1.5, 13ProMax: text cap 3.6 px; text box x 282..305 y 172..176; covered by cash badge 0%
chase C Ave +Z to (100,100), far corner, car 45 out, 10x2.4, iPhone7: text cap 5.0 px; text box x 207..236 y 148..153
chase C Ave +Z to (100,100), far corner, car 45 out, 10x2.4, 13ProMax: text cap 5.8 px
chase C Ave +Z to (100,100), far corner, car 45 out, 12x3, iPhone7: text cap 6.3 px; text box x 201..235 y 147..153
chase C Ave +Z to (100,100), far corner, car 45 out, 12x3, 13ProMax: text cap 7.2 px
chase C Ave +Z to (100,100), far corner, car 25 out, current 7x1.5, iPhone7: text cap 4.1 px; 13ProMax 4.7 px
chase C Ave +Z to (100,100), far corner, car 25 out, 10x2.4, iPhone7: text cap 6.5 px; 13ProMax 7.5 px
chase C Ave +Z to (100,100), far corner, car 25 out, 12x3, iPhone7: text cap 8.2 px; text box x 162..206 y 146..154; 13ProMax 9.4 px
```

## Not tested
- Any change (none made).
- Real phone.
- Multiplayer.
