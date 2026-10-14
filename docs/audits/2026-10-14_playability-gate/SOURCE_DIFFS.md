# Source diffs: 2026-10-14_playability-gate

Commit range `fc3e5c3..3693ab9` (source only). Studio matches `src/` for every changed script (hash-checked).

## `src/ReplicatedStorage/Shared/Config/RobberyConfig.luau`

```diff
diff --git a/src/ReplicatedStorage/Shared/Config/RobberyConfig.luau b/src/ReplicatedStorage/Shared/Config/RobberyConfig.luau
index af12c52..5eba759 100644
--- a/src/ReplicatedStorage/Shared/Config/RobberyConfig.luau
+++ b/src/ReplicatedStorage/Shared/Config/RobberyConfig.luau
@@ -6,9 +6,9 @@ local RobberyConfig = {
 	WantedCrime = "StoreRobbery", -- WantedConfig crime reported at the start (70 heat = 2 stars)
 	InProgressCrime = "RobberyInProgress", -- re-reported while holding so heat can't decay early
 	CooldownSeconds = 180, -- per store, from the moment a robbery starts
-	-- Audit 4 trial (P5): after a FAILED robbery the store reopens 90 s after that robbery
-	-- started instead of 180 s. Successful robberies keep 180 s. Set to nil to restore the old
-	-- behaviour (180 s after any robbery).
+	-- EXPERIMENTAL (audit 4 trial, P5; decide after human playtests): after a FAILED robbery
+	-- the store reopens 90 s after that robbery started instead of 180 s. Successful robberies
+	-- keep 180 s. Set to nil to restore the old behaviour (180 s after any robbery).
 	FailedCooldownSeconds = 90,
 	PromptDistance = 10, -- studs from the register to start
 	DistanceSlack = 4, -- extra studs the server allows for latency
```

## `src/ReplicatedStorage/Shared/Onboarding/OnboardingRules.luau`

```diff
diff --git a/src/ReplicatedStorage/Shared/Onboarding/OnboardingRules.luau b/src/ReplicatedStorage/Shared/Onboarding/OnboardingRules.luau
index d0f3f47..8054720 100644
--- a/src/ReplicatedStorage/Shared/Onboarding/OnboardingRules.luau
+++ b/src/ReplicatedStorage/Shared/Onboarding/OnboardingRules.luau
@@ -8,9 +8,24 @@ local OnboardingRules = {}
 export type PanelLayout = { Y: number, Width: number, Height: number, TitleSize: number, DetailSize: number }
 export type Milestones = { JoinedAt: number, Done: { [string]: number } }
 
--- P1: one owned car spawns straight away; the garage window only opens with a choice to make.
-function OnboardingRules.spawnButtonAction(ownedCount: number): "Spawn" | "Choose"
-	return if ownedCount >= 2 then "Choose" else "Spawn"
+-- P1 (audit condition 1): what the Spawn Car button does, and with which car. `owned` comes from
+-- the OwnedVehicles display attribute; while it is empty (data not loaded yet, or unavailable)
+-- only the starter cars count, because the server always accepts those. One candidate spawns
+-- that car, whatever was selected before (so a stale selection is never sent); several open the
+-- garage; none sends nothing.
+function OnboardingRules.spawnChoice(owned: { string }, starters: { string }): ("Spawn" | "Choose" | "None", string?)
+	local candidates = if #owned > 0 then owned else starters
+	if #candidates == 0 then
+		return "None", nil
+	elseif #candidates == 1 then
+		return "Spawn", candidates[1]
+	end
+	return "Choose", nil
+end
+
+-- P3 (audit condition 2): the tip steps aside only for a robbery that is actually running.
+function OnboardingRules.isActiveRobbery(phase: any): boolean
+	return phase == "Holding" or phase == "Escaping"
 end
 
 -- P2: a marker shows between the hide distance (you're already there) and the max distance.
```

## `src/ReplicatedStorage/Shared/Robbery/RobberyRules.luau`

```diff
diff --git a/src/ReplicatedStorage/Shared/Robbery/RobberyRules.luau b/src/ReplicatedStorage/Shared/Robbery/RobberyRules.luau
index 08e1336..55412bb 100644
--- a/src/ReplicatedStorage/Shared/Robbery/RobberyRules.luau
+++ b/src/ReplicatedStorage/Shared/Robbery/RobberyRules.luau
@@ -97,7 +97,9 @@ end
 
 -- A failed robbery may shorten the store's cooldown (FailedCooldownSeconds, counted from the
 -- start), but only while this session is still the store's latest: a late failure of an old
--- getaway never cuts the cooldown of a newer robbery.
+-- getaway never cuts the cooldown of a newer robbery. Only reached from a live phase (tick
+-- returns nothing once a session is Failed or Paid), so a session fails, and changes the
+-- cooldown, at most once.
 local function fail(session: Session, store: StoreState?, reason: Types.RobberyFailReason, config: Config): (string, Types.RobberyFailReason)
 	session.Phase = "Failed"
 	session.FailReason = reason
```

## `src/ServerScriptService/Server/Services/RobberyService.luau`

```diff
diff --git a/src/ServerScriptService/Server/Services/RobberyService.luau b/src/ServerScriptService/Server/Services/RobberyService.luau
index 76ac919..41cd2bc 100644
--- a/src/ServerScriptService/Server/Services/RobberyService.luau
+++ b/src/ServerScriptService/Server/Services/RobberyService.luau
@@ -100,6 +100,9 @@ local function endSession(player: Player, entry: Live)
 end
 
 local function failSession(player: Player, entry: Live, reason: Types.RobberyFailReason)
+	if live[player] ~= entry then
+		return -- already ended: a duplicate failure never notifies or changes anything twice
+	end
 	endSession(player, entry)
 	notify(player, "Failed", { Reason = reason, Id = entry.Session.Id })
 	print(`[Robbery] {player.Name} {entry.Session.Id} failed: {reason}`)
```

## `src/ServerScriptService/Server/Services/VehicleService.luau`

```diff
diff --git a/src/ServerScriptService/Server/Services/VehicleService.luau b/src/ServerScriptService/Server/Services/VehicleService.luau
index fafc94b..f7727f6 100644
--- a/src/ServerScriptService/Server/Services/VehicleService.luau
+++ b/src/ServerScriptService/Server/Services/VehicleService.luau
@@ -26,6 +26,8 @@ local MAX_VEHICLE_ID_LENGTH = 32
 local PROMPT_SLACK = 6 -- extra studs allowed beyond the prompt range for latency
 local SPAWN_CLEARANCE = Vector3.new(10, 8, 16)
 local SPAWN_DROP = 0.5
+local SEAT_RETRIES = 10 -- re-seat attempts after a spawn (covers a client still leaving its old seat)
+local SEAT_RETRY_INTERVAL = 0.1
 
 local vehiclesFolder: Folder
 local vehicleByOwner: { [number]: Model } = {}
@@ -135,6 +137,15 @@ local function spawnVehicle(player: Player, vehicleId: string): (boolean, Types.
 		return false, "Cooldown"
 	end
 
+	-- Replacing a car while sitting in one: leave the old seat cleanly first (as exitVehicle
+	-- does), so the character isn't still "seated" in a destroyed seat when the new one sits it.
+	if humanoid.SeatPart then
+		local weld = humanoid.SeatPart:FindFirstChild("SeatWeld")
+		if weld then
+			weld:Destroy()
+		end
+		humanoid.Sit = false
+	end
 	despawnOwnedVehicle(player.UserId)
 	local spawnCFrame = findFreeSpawn(root.Position)
 	if not spawnCFrame then
@@ -161,7 +172,32 @@ local function spawnVehicle(player: Player, vehicleId: string): (boolean, Types.
 		end)
 	end
 	updateSimulation(vehicle)
+	-- The character is simulated by its client, which can take a moment to leave its old seat;
+	-- until it has sat in the new car once, retry briefly. Stops for good once it was seated (so
+	-- a player who gets straight out isn't pulled back in), or the seat is taken, the car is
+	-- gone, or the player may no longer drive.
+	local seatedOnce = false
+	local seatedConnection = seat:GetPropertyChangedSignal("Occupant"):Connect(function()
+		if seat.Occupant == humanoid then
+			seatedOnce = true
+		end
+	end)
 	seat:Sit(humanoid)
+	task.spawn(function()
+		for _ = 1, SEAT_RETRIES do
+			task.wait(SEAT_RETRY_INTERVAL)
+			if seatedOnce or seat.Occupant ~= nil or not seat:IsDescendantOf(Workspace) then
+				break
+			end
+			if humanoid.Health <= 0 or humanoid.Parent ~= player.Character or not JailService.allows(player, "Drive") then
+				break
+			end
+			if humanoid.SeatPart == nil then
+				seat:Sit(humanoid)
+			end
+		end
+		seatedConnection:Disconnect()
+	end)
 	MilestoneLog.mark(player, "FirstCar")
 	return true, nil
 end
```

## `src/ServerStorage/Tests/OnboardingRules.spec.luau`

```diff
diff --git a/src/ServerStorage/Tests/OnboardingRules.spec.luau b/src/ServerStorage/Tests/OnboardingRules.spec.luau
index 69fef5a..32c80dd 100644
--- a/src/ServerStorage/Tests/OnboardingRules.spec.luau
+++ b/src/ServerStorage/Tests/OnboardingRules.spec.luau
@@ -14,10 +14,37 @@ end
 
 return {
 	["P1: one owned car spawns directly; two or more open the garage"] = function()
-		Assert.equal(OnboardingRules.spawnButtonAction(0), "Spawn")
-		Assert.equal(OnboardingRules.spawnButtonAction(1), "Spawn")
-		Assert.equal(OnboardingRules.spawnButtonAction(2), "Choose")
-		Assert.equal(OnboardingRules.spawnButtonAction(5), "Choose")
+		local starters = EconomyConfig.StarterVehicles
+		local action, id = OnboardingRules.spawnChoice({ "Coupe" }, starters)
+		Assert.equal(action, "Spawn")
+		Assert.equal(id, "Coupe")
+		action, id = OnboardingRules.spawnChoice({ "Coupe", "Muscle" }, starters)
+		Assert.equal(action, "Choose")
+		Assert.equal(id, nil)
+	end,
+	["P1: a stale selection is never sent; the only owned car is"] = function()
+		-- e.g. "Muscle" was selected earlier but the list now holds one other car
+		local action, id = OnboardingRules.spawnChoice({ "Coupe" }, {})
+		Assert.equal(action, "Spawn")
+		Assert.equal(id, "Coupe")
+		action, id = OnboardingRules.spawnChoice({ "Muscle" }, { "Coupe" })
+		Assert.equal(id, "Muscle", "owned list wins over the starter list")
+	end,
+	["P1: not loaded yet uses only the starter car; nothing at all sends nothing"] = function()
+		local action, id = OnboardingRules.spawnChoice({}, EconomyConfig.StarterVehicles)
+		Assert.equal(action, "Spawn")
+		Assert.equal(id, "Coupe", "the server always accepts starter cars")
+		action, id = OnboardingRules.spawnChoice({}, {})
+		Assert.equal(action, "None")
+		Assert.equal(id, nil)
+	end,
+	["P3: the tip closes only for a running robbery"] = function()
+		Assert.equal(OnboardingRules.isActiveRobbery("Holding"), true)
+		Assert.equal(OnboardingRules.isActiveRobbery("Escaping"), true)
+		Assert.equal(OnboardingRules.isActiveRobbery(nil), false)
+		Assert.equal(OnboardingRules.isActiveRobbery("PayoutPending"), false)
+		Assert.equal(OnboardingRules.isActiveRobbery("Failed"), false)
+		Assert.equal(OnboardingRules.isActiveRobbery(5), false)
 	end,
 	["P2: markers show between the hide and max distance only"] = function()
 		local c = OnboardingConfig
```

## `src/ServerStorage/Tests/RobberyRules.spec.luau`

```diff
diff --git a/src/ServerStorage/Tests/RobberyRules.spec.luau b/src/ServerStorage/Tests/RobberyRules.spec.luau
index c04a0db..b61f475 100644
--- a/src/ServerStorage/Tests/RobberyRules.spec.luau
+++ b/src/ServerStorage/Tests/RobberyRules.spec.luau
@@ -187,4 +187,37 @@ return {
 		Assert.equal(store.CooldownUntil, 200 + C.CooldownSeconds, "B's cooldown untouched")
 		Assert.equal(store.ActiveSession, b.Id)
 	end,
+	["a failure is final: repeated or overlapping failure facts change nothing"] = function()
+		-- Overlapping causes in one tick (dead AND jailed): one failure, one reason.
+		local store, a = started(100)
+		local event, reason = RobberyRules.tick(a, store, tickFacts({ Alive = false, Jailed = true }), 105, C)
+		Assert.equal(event, "Failed")
+		Assert.equal(reason, "Died")
+		Assert.equal(store.CooldownUntil, 190)
+		-- Later failure callbacks for the same session: no event, no change.
+		for _, f in { { Jailed = true }, { Connected = false }, { Alive = false }, { InArea = false } } do
+			Assert.equal((RobberyRules.tick(a, store, tickFacts(f), 106, C)), nil)
+		end
+		Assert.equal(a.Phase, "Failed")
+		Assert.equal(a.FailReason, "Died")
+		Assert.equal(store.CooldownUntil, 190, "cooldown changed once")
+		Assert.equal(RobberyRules.onEscaped(a), false, "a failed robbery never pays")
+		-- A newer robbery B: more failure callbacks for A don't touch B.
+		local b = RobberyRules.start(store, "id-2", 2, "Store1", 200, C)
+		Assert.equal((RobberyRules.tick(a, store, tickFacts({ Connected = false }), 210, C)), nil)
+		Assert.equal(store.CooldownUntil, 200 + C.CooldownSeconds)
+		Assert.equal(store.ActiveSession, b.Id)
+		Assert.equal(b.Phase, "Holding")
+	end,
+	["successful robbery: cooldown stays 180 s from the start"] = function()
+		local store, session = started(100)
+		RobberyRules.tick(session, store, OK_TICK, 100 + C.HoldSeconds, C)
+		Assert.equal(session.Phase, "Escaping")
+		Assert.equal(RobberyRules.onEscaped(session), true)
+		Assert.equal(session.Phase, "Paid")
+		Assert.equal((RobberyRules.tick(session, store, tickFacts({ Jailed = true }), 150, C)), nil, "busted after paying: nothing")
+		Assert.equal(store.CooldownUntil, 100 + C.CooldownSeconds)
+		Assert.equal((RobberyRules.canStart(store, facts(), 279.9, C)), false)
+		Assert.equal((RobberyRules.canStart(store, facts(), 280, C)), true)
+	end,
 }
```

## `src/StarterPlayer/StarterPlayerScripts/Client/Controllers/GarageController.luau`

```diff
diff --git a/src/StarterPlayer/StarterPlayerScripts/Client/Controllers/GarageController.luau b/src/StarterPlayer/StarterPlayerScripts/Client/Controllers/GarageController.luau
index 48d6304..9ab3e2a 100644
--- a/src/StarterPlayer/StarterPlayerScripts/Client/Controllers/GarageController.luau
+++ b/src/StarterPlayer/StarterPlayerScripts/Client/Controllers/GarageController.luau
@@ -7,6 +7,7 @@ local Players = game:GetService("Players")
 local ReplicatedStorage = game:GetService("ReplicatedStorage")
 
 local VehicleConfig = require(ReplicatedStorage.Shared.Config.VehicleConfig)
+local EconomyConfig = require(ReplicatedStorage.Shared.Config.EconomyConfig)
 local PlayerAttributes = require(ReplicatedStorage.Shared.Player.PlayerAttributes)
 local OnboardingRules = require(ReplicatedStorage.Shared.Onboarding.OnboardingRules)
 local VehicleController = require(script.Parent.VehicleController)
@@ -27,14 +28,17 @@ function GarageController.spawnSelected()
 	VehicleController.requestSpawn(selected)
 end
 
--- The Spawn Car button (P1): one owned car spawns straight away, 2+ open the garage.
+-- The Spawn Car button (P1): one owned car spawns straight away (and becomes the selection, so
+-- a stale earlier pick is never sent), 2+ open the garage, none sends nothing.
 function GarageController.spawnOrChoose()
-	if OnboardingRules.spawnButtonAction(#UiKit.ownedVehicles(player)) == "Spawn" then
+	local action, vehicleId = OnboardingRules.spawnChoice(UiKit.ownedVehicles(player), EconomyConfig.StarterVehicles)
+	if action == "Spawn" and vehicleId then
+		selected = vehicleId
 		if panel then
 			panel.Visible = false
 		end
-		VehicleController.requestSpawn(selected)
-	else
+		VehicleController.requestSpawn(vehicleId)
+	elseif action == "Choose" then
 		GarageController.toggle()
 	end
 end
```

## `src/StarterPlayer/StarterPlayerScripts/Client/Controllers/OnboardingTipController.luau`

```diff
diff --git a/src/StarterPlayer/StarterPlayerScripts/Client/Controllers/OnboardingTipController.luau b/src/StarterPlayer/StarterPlayerScripts/Client/Controllers/OnboardingTipController.luau
index 6f727c1..8e7d45f 100644
--- a/src/StarterPlayer/StarterPlayerScripts/Client/Controllers/OnboardingTipController.luau
+++ b/src/StarterPlayer/StarterPlayerScripts/Client/Controllers/OnboardingTipController.luau
@@ -9,6 +9,7 @@ local ReplicatedStorage = game:GetService("ReplicatedStorage")
 local Shared = ReplicatedStorage.Shared
 local OnboardingConfig = require(Shared.Config.OnboardingConfig)
 local PlayerAttributes = require(Shared.Player.PlayerAttributes)
+local OnboardingRules = require(Shared.Onboarding.OnboardingRules)
 local UiKit = require(script.Parent.UiKit)
 
 local OnboardingTipController = {}
@@ -49,12 +50,20 @@ function OnboardingTipController.init()
 			gui:Destroy()
 		end
 	end)
-	-- A robbery's objective panel takes over the top of the screen, so the tip steps aside.
-	player:GetAttributeChangedSignal(PlayerAttributes.RobberyPhase):Connect(function()
-		if gui.Parent then
-			gui:Destroy()
+	-- A running robbery's objective panel takes over the top of the screen, so the tip steps aside.
+	-- Other RobberyPhase changes (cleared, payout pending) leave it alone.
+	local connection: RBXScriptConnection
+	connection = player:GetAttributeChangedSignal(PlayerAttributes.RobberyPhase):Connect(function()
+		if OnboardingRules.isActiveRobbery(player:GetAttribute(PlayerAttributes.RobberyPhase)) then
+			connection:Disconnect()
+			if gui.Parent then
+				gui:Destroy()
+			end
 		end
 	end)
+	gui.Destroying:Connect(function()
+		connection:Disconnect()
+	end)
 end
 
 return OnboardingTipController
```

## `src/StarterPlayer/StarterPlayerScripts/Client/Controllers/VehicleController.luau`

```diff
diff --git a/src/StarterPlayer/StarterPlayerScripts/Client/Controllers/VehicleController.luau b/src/StarterPlayer/StarterPlayerScripts/Client/Controllers/VehicleController.luau
index 2415aa4..4346ce5 100644
--- a/src/StarterPlayer/StarterPlayerScripts/Client/Controllers/VehicleController.luau
+++ b/src/StarterPlayer/StarterPlayerScripts/Client/Controllers/VehicleController.luau
@@ -113,6 +113,12 @@ local function onCharacter(character: Model)
 	humanoid.Seated:Connect(function(active, seat)
 		onSeated(humanoid, active, seat)
 	end)
+	-- Moving straight from one seat to another (a car replaced while driving) may not fire
+	-- Seated again, so also follow SeatPart itself.
+	humanoid:GetPropertyChangedSignal("SeatPart"):Connect(function()
+		local seat = humanoid.SeatPart
+		onSeated(humanoid, seat ~= nil, seat)
+	end)
 	if humanoid.SeatPart then
 		onSeated(humanoid, true, humanoid.SeatPart)
 	end
@@ -145,6 +151,15 @@ function VehicleController.init()
 		vehiclesFolder = folder
 		folder.ChildAdded:Connect(watchVehicle)
 		folder.ChildRemoved:Connect(function(vehicle)
+			if vehicle == currentVehicle then
+				-- The car we were driving is gone (replaced or removed): stop driving it.
+				local character = player.Character
+				local humanoid = character and character:FindFirstChildOfClass("Humanoid")
+				setCurrentVehicle(nil, humanoid)
+				if humanoid and humanoid.SeatPart then
+					onSeated(humanoid, true, humanoid.SeatPart)
+				end
+			end
 			if vehicle:IsA("Model") then
 				local physics = simulated[vehicle]
 				if physics then
```
