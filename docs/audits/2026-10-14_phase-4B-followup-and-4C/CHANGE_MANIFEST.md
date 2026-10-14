# Change manifest: 2026-10-14_phase-4B-followup-and-4C

- Commit range: `4ed77f3..5bdb1c9`
- Commits:
  - `69f5957` 4B follow-up: recoverable robbery payouts and orphan profile saves
  - `ace6d9d` 4B follow-up: police dispatched when the robbery holdout ends
  - `5bdb1c9` Phase 4C: dealership, $15,000 Muscle, persistent vehicle ownership

Studio is the source of truth. `src/` is a snapshot exported from Studio after testing; the export matched Studio byte for byte (90/90 scripts). Each diff below is that snapshot's change.

## Added
| File | Purpose |
|---|---|
| `src/ReplicatedStorage/Shared/Config/DealershipConfig.luau` | Catalogue and prices (Muscle 15000), desk range 14 + 6 slack, 1 s request interval; read-only |
| `src/ServerScriptService/Server/Services/DealershipService.luau` | `RequestPurchaseVehicle` handler with all server checks |
| `src/ServerStorage/Tests/Dealership.spec.luau` | Catalogue, Muscle handling, read-only prices, remote contract, showroom placement |
| `src/StarterPlayer/StarterPlayerScripts/Client/Controllers/DealershipController.luau` | Dealership window (display + request only) |
| `src/StarterPlayer/StarterPlayerScripts/Client/Controllers/GarageController.luau` | Garage window listing owned cars; V spawns the last pick |
| `src/StarterPlayer/StarterPlayerScripts/Client/Controllers/UiKit.luau` | Shared touch-sized UI builders |

## Changed
| File | What changed and why |
|---|---|
| `src/ReplicatedStorage/Shared/Types.luau` | Profile.OwnedVehicles; EconomyError + InvalidVehicle/AlreadyOwned/TooManyVehicles; SpawnError + NotOwned; PurchaseError; PayoutOutcome; RobberyStartError + CashUnavailable |
| `src/ReplicatedStorage/Shared/Config/EconomyConfig.luau` | ProfileVersion 2, StarterVehicles {"Coupe"}, MaxOwnedVehicles 50, VehicleIdMaxLength 32, orphan-save retry settings |
| `src/ReplicatedStorage/Shared/Config/RobberyConfig.luau` | `PoliceDispatchAtHoldEnd = true` (owner option 1) |
| `src/ReplicatedStorage/Shared/Config/VehicleConfig.luau` | New `Muscle` stats |
| `src/ReplicatedStorage/Shared/Economy/EconomyRules.luau` | v2 profile, migration in `validateSaved`, `ownsVehicle`, atomic `purchaseVehicle` |
| `src/ReplicatedStorage/Shared/Net/Remotes.luau` | `RequestPurchaseVehicle` (RemoteFunction) |
| `src/ReplicatedStorage/Shared/Player/PlayerAttributes.luau` | `OwnedVehicles` attribute; `RobberyPhase` adds `PayoutPending` |
| `src/ReplicatedStorage/Shared/Robbery/RobberyRules.luau` | `CashReady` start check; `payoutOutcome` classification |
| `src/ServerScriptService/Server/Data/DataStoreAdapter.luau` | Studio-only Workspace switch `SimulateDataStoreFailure` (testing without a player) |
| `src/ServerScriptService/Server/Data/ProfileStore.luau` | Saves OwnedVehicles; "Migrated" load result |
| `src/ServerScriptService/Server/Dev/DevCommandRules.luau` | Studio-only `SetCashUnavailable`, `TryRobStore`, `WriteLegacyProfile` |
| `src/ServerScriptService/Server/Dev/DevToolsService.luau` | Handlers for the above |
| `src/ServerScriptService/Server/Main.server.luau` | Boots `DealershipService` after `RobberyService` |
| `src/ServerScriptService/Server/Services/EconomyService.luau` | Orphan saves after a failed leave-save; `ownsVehicle`; `purchaseVehicle` with immediate save; publishes OwnedVehicles; Studio test hooks |
| `src/ServerScriptService/Server/Services/PoliceService.luau` | `setDispatchHold(player, held)`: no new dispatch to a held player |
| `src/ServerScriptService/Server/Services/RobberyService.luau` | Pending payouts with retry; cash-ready start check; dispatch hold during the holdout |
| `src/ServerScriptService/Server/Services/VehicleService.luau` | Ownership check before spawning (`NotOwned`) |
| `src/ServerScriptService/Server/Services/WorldService.luau` | Builds the dealership if missing; `getDealership()` |
| `src/ServerScriptService/Server/World/CityBuilder.luau` | `buildDealership` (showroom, prompt, anchored display car, sign) |
| `src/ServerScriptService/Server/World/CityLayout.luau` | `dealership()` layout data |
| `src/ServerStorage/Tests/EconomyRules.spec.luau` | Migration, ownership and purchase tests |
| `src/ServerStorage/Tests/ProfileStore.spec.luau` | Migration write-back; purchase saved together / failed save leaves the record unchanged |
| `src/ServerStorage/Tests/RobberyRules.spec.luau` | CashUnavailable; payout outcomes |
| `src/StarterPlayer/StarterPlayerScripts/Client/Controllers/RobberyHudController.luau` | REWARD PENDING state and messages |
| `src/StarterPlayer/StarterPlayerScripts/Client/Controllers/VehicleHudController.luau` | Spawn Car opens the garage; NotOwned message |
| `src/StarterPlayer/StarterPlayerScripts/Client/Main.client.luau` | Inits garage and dealership controllers; V spawns the garage pick |

## Removed
| File | Why |
|---|---|
| None | |

## Docs updated
`docs/ARCHITECTURE.md` (Store robbery recoverable payouts and police response, NPC storefront issue + roadside-stop proposal, Dealership and vehicle ownership), `docs/PROGRESS.md`, `docs/ROADMAP.md`, `docs/TEST_CHECKLIST.md`, `docs/MULTIPLAYER_TESTS.md`. After this range, this audit workflow was added (`docs/audits/`).

## Studio-only changes (not in src/)
- `Workspace.City.Dealership` (showroom parts, ShopPrompt, anchored display Muscle, sign) built in the edit place; the server also builds it if missing.
- The 4B store prompt attachment fix lives in `CityBuilder` (in src) and in the edit place.
- No place settings were changed.

## Configuration values introduced or changed
| Setting | Old | New | Where |
|---|---|---|---|
| ProfileVersion | 1 | 2 | EconomyConfig |
| StarterVehicles | n/a | {"Coupe"} | EconomyConfig |
| MaxOwnedVehicles | n/a | 50 | EconomyConfig |
| OrphanRetryInterval / OrphanRetryLimit | n/a | 10 s / 900 s | EconomyConfig |
| Muscle price | n/a | 15000 | DealershipConfig |
| InteractDistance + DistanceSlack | n/a | 14 + 6 studs | DealershipConfig |
| RequestInterval | n/a | 1 s | DealershipConfig |
| PoliceDispatchAtHoldEnd | n/a | true | RobberyConfig |
| Payout retry | n/a | every 2 s | RobberyService |
