# Test evidence: 2026-10-14_city-navigation-world-audit

- Studio instance used: `Outlaw City (placeId: 132163592957463)`, in Edit mode. Every query asserted `game.PlaceId`. **Read-only: nothing was changed.**
- Automated tests: not run (no code changed). The last run was `[Tests] 206 passed, 0 failed`.

## Automated tests
| Spec | Result |
|---|---|
| None (plan only) | Not run |

## Read-only Studio queries (exact output)
**Totals**
```
workspace BaseParts=266 CanCollide=114 semi-transparent=17 CastShadow=134 glass=5 neon=4
```

**City folders**
```
City.Roads: parts=18 collide=18 X -318..318 Y -0.2..0.2 Z -492..318
City.Markings: parts=120 collide=0 X -700..700 Y 0.2..0.2 Z -547..300
City.Sidewalks: parts=8 collide=8 X -282..282 Y 0.0..0.6 Z -282..282
City.Buildings: parts=24 collide=24 X -270..270 Y 0.6..93.6 Z -270..270
City.Plaza: parts=1 collide=1 X -82..82 Y -0.2..0.2 Z -82..82
City.Highway: parts=3 collide=3 X -820..820 Y -0.2..0.2 Z -580..-460
City.Barriers: parts=13 collide=13 X -822..822 Y 0.2..2.8 Z -582..-458
City.VehicleSpawns: parts=6 collide=0 X -764..764 Y 0.2..0.3 Z -528..52
City.CivilianSpawns: parts=6 collide=0 X -69..69 Y 0.2..0.3 Z -24..24
City.Jail: parts=24 collide=20 X -15..15 Y -0.2..13.2 Z 405..435
City.Store: parts=14 collide=13 X -145..-118 Y -1.2..17.3 Z -76..-44
City.Dealership: parts=26 collide=11 X 179..221 Y 0.4..19.8 Z 120..152
```

**Roads**
```
Connector_100 36x174 @(100,-405); RoadEW_100 636x36 @(0,100); RoadEW_300 636x36 @(0,300); RoadNS_-100_1 36x164 @(-100,-200); RoadNS_100_2 36x164 @(100,0); RoadNS_-100_3 36x164 @(-100,200); RoadNS_300_2 36x164 @(300,0); RoadEW_-100 636x36 @(0,-100); RoadNS_300_3 36x164 @(300,200); RoadNS_100_1 36x164 @(100,-200); Connector_-100 36x174 @(-100,-405); RoadNS_-300_2 36x164 @(-300,0); RoadNS_300_1 36x164 @(300,-200); RoadNS_-300_1 36x164 @(-300,-200); RoadNS_-100_2 36x164 @(-100,0); RoadNS_100_3 36x164 @(100,200); RoadNS_-300_3 36x164 @(-300,200); RoadEW_-300 636x36 @(0,-300)
```

**Buildings**
```
Buildings: 24, distinct sizes 24, colours [120,110,100x6 150,130,105x6 175,170,160x2 105,85,80x7 90,100,115x3], materials [SmoothPlasticx24]
```

**World signs**
```
World text signs: "24/7 MART" on Workspace.City.Store.StoreSign; "OUTLAW MOTORS" on Workspace.City.Dealership.DealerSign
```

**Markings**
```
Marking kinds: LaneDash=92, LineEW=12, HighwayEdge=2, LineConnector=2, LineNS=12
Markings CastShadow 0 of 120
```

**Sidewalks**
```
Sidewalks: 8 blocks of 164x164 h0.6
```

**Ground and spawns**
```
Baseplate 2048x2048 top 0.0 material Plastic colour Dark grey metallic texture rbxassetid://6372755229
SpawnLocation enabled=false
```

**Floating-part check**
```
unsupported parts (bottom > 1 stud, nothing directly below): 13 -> Jail.Slots.Slot1..4@y2.7, Jail.JailRoof@y12.2, Store.StoreFrontHeader@y9.8, Store.StoreRoof@y12.8, Store.StoreSign@y13.3, Dealership.DealerRoof@y14.8, Dealership.DealerFrontHeader@y10.8, Dealership.DisplayCar.Chassis@y2.3, Dealership.DisplayCar.Roof@y5.5, Dealership.DealerSign@y15.8
```
These are all roofs and headers on walls, signs, jail slot markers and the display car on its wheels; no true floaters.

**Overlap check**
```
building overlaps with buildings/roads/store/dealership: 3 Building_3_3_1xDealerWallWest, Building_3_3_1xDealerRoof, Building_3_3_1xDealerWallBack
Building_3_3_1 X 138.5..179.5 Z 133.0..185.0 Y 0.6..46.6
DealerWallWest X 179.0..180.0 Z 121.0..151.0 | overlap 0.5 x 18.0 studs
DealerRoof X 179.0..221.0 Z 120.0..152.0 | overlap 0.5 x 19.0 studs
DealerWallBack X 179.0..221.0 Z 151.0..152.0 | overlap 0.5 x 1.0 studs
```

## Screenshots
None new; the plan used read-only property queries. The highway checkerboard ground is visible in `docs/audits/2026-10-14_atmosphere-batch1-closeout/screenshots/highway_batch1_lighting.jpg`.

## Regression checks
Not applicable (no changes).

## Not tested
Everything in the plan; it is not implemented.
