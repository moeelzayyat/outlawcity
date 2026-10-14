# Source diffs: 2026-10-14_onboarding

Commit range `7618566..a283809` (code). The `src/` snapshot is byte-identical to the Outlaw City place (all 98 scripts checked by hash).

## `src/ReplicatedStorage/Shared/Config/OnboardingConfig.luau`

```diff
diff --git a/src/ReplicatedStorage/Shared/Config/OnboardingConfig.luau b/src/ReplicatedStorage/Shared/Config/OnboardingConfig.luau
new file mode 100644
index 0000000..1ad8531
--- /dev/null
+++ b/src/ReplicatedStorage/Shared/Config/OnboardingConfig.luau
@@ -0,0 +1,30 @@
+--!strict
+-- New-player guidance tuning (audit 4 onboarding batch). Read-only at runtime; display only.
+-- Nothing here changes rewards, prices, police or cooldown rules.
+local OnboardingConfig = {
+	-- World markers over the 24/7 MART and OUTLAW MOTORS (P2).
+	MarkerMaxDistance = 450, -- studs: beyond this the marker is hidden
+	MarkerHideDistance = 35, -- studs from the building centre: hidden when you're there already
+	MarkerHeight = 8, -- studs above the sign
+	-- First-spawn tip (P3): shown once per session, closes itself or with its X button.
+	TipSeconds = 15,
+	-- Mobile robbery panel (P7): used when the screen is shorter than this many pixels.
+	CompactScreenHeight = 400,
+	CompactPanel = { Y = 92, Width = 260, Height = 64, TitleSize = 17, DetailSize = 14 },
+	FullPanel = { Y = 136, Width = 300, Height = 76, TitleSize = 20, DetailSize = 16 },
+	MinTextSize = 14, -- readability floor for any onboarding text on a phone
+	-- Studio-only milestone log (P8).
+	Milestones = { "FirstCar", "FirstRobbery", "FirstEscape" },
+}
+
+local function deepFreeze(value: any)
+	if type(value) == "table" and not table.isfrozen(value) then
+		for _, child in value do
+			deepFreeze(child)
+		end
+		table.freeze(value)
+	end
+end
+deepFreeze(OnboardingConfig)
+
+return OnboardingConfig
```

## `src/ReplicatedStorage/Shared/Config/RobberyConfig.luau`

```diff
diff --git a/src/ReplicatedStorage/Shared/Config/RobberyConfig.luau b/src/ReplicatedStorage/Shared/Config/RobberyConfig.luau
index 756c7df..af12c52 100644
--- a/src/ReplicatedStorage/Shared/Config/RobberyConfig.luau
+++ b/src/ReplicatedStorage/Shared/Config/RobberyConfig.luau
@@ -5,7 +5,11 @@ local RobberyConfig = {
 	Reward = 2000, -- paid only after a completed holdout AND a successful escape
 	WantedCrime = "StoreRobbery", -- WantedConfig crime reported at the start (70 heat = 2 stars)
 	InProgressCrime = "RobberyInProgress", -- re-reported while holding so heat can't decay early
-	CooldownSeconds = 180, -- per store, from the moment a robbery starts (success or failure)
+	CooldownSeconds = 180, -- per store, from the moment a robbery starts
+	-- Audit 4 trial (P5): after a FAILED robbery the store reopens 90 s after that robbery
+	-- started instead of 180 s. Successful robberies keep 180 s. Set to nil to restore the old
+	-- behaviour (180 s after any robbery).
+	FailedCooldownSeconds = 90,
 	PromptDistance = 10, -- studs from the register to start
 	DistanceSlack = 4, -- extra studs the server allows for latency
 	MaxEscapeSeconds = 300, -- after the holdout, escape within this or the payout is lost
```

## `src/ReplicatedStorage/Shared/Onboarding/OnboardingRules.luau`

```diff
diff --git a/src/ReplicatedStorage/Shared/Onboarding/OnboardingRules.luau b/src/ReplicatedStorage/Shared/Onboarding/OnboardingRules.luau
new file mode 100644
index 0000000..d0f3f47
--- /dev/null
+++ b/src/ReplicatedStorage/Shared/Onboarding/OnboardingRules.luau
@@ -0,0 +1,87 @@
+--!strict
+-- Pure helpers for the new-player guidance (audit 4 onboarding batch): spawn shortcut, markers,
+-- escape hint, store cooldown text, Muscle progress and milestone timing. Display only; the
+-- server stays the authority for everything these describe. Unit-tested in
+-- ServerStorage.Tests.OnboardingRules.spec.
+local OnboardingRules = {}
+
+export type PanelLayout = { Y: number, Width: number, Height: number, TitleSize: number, DetailSize: number }
+export type Milestones = { JoinedAt: number, Done: { [string]: number } }
+
+-- P1: one owned car spawns straight away; the garage window only opens with a choice to make.
+function OnboardingRules.spawnButtonAction(ownedCount: number): "Spawn" | "Choose"
+	return if ownedCount >= 2 then "Choose" else "Spawn"
+end
+
+-- P2: a marker shows between the hide distance (you're already there) and the max distance.
+function OnboardingRules.markerVisible(distance: number, config: { MarkerMaxDistance: number, MarkerHideDistance: number }): boolean
+	return distance == distance and distance >= config.MarkerHideDistance and distance <= config.MarkerMaxDistance
+end
+
+function OnboardingRules.formatDistance(distance: number): string
+	return `{math.floor(distance / 10 + 0.5) * 10} studs`
+end
+
+-- "m:ss" for a positive number of seconds (rounded up, so 0:00 only when it's open).
+function OnboardingRules.formatClock(seconds: number): string
+	local s = math.max(0, math.ceil(seconds))
+	return string.format("%d:%02d", s // 60, s % 60)
+end
+
+-- P5: the store marker's status line. cooldownUntil is server time (nil/-inf = never robbed).
+function OnboardingRules.storeStatus(cooldownUntil: number?, busy: boolean, now: number): string
+	if busy then
+		return "Being robbed"
+	end
+	if type(cooldownUntil) == "number" and cooldownUntil > now then
+		return `Reopens in {OnboardingRules.formatClock(cooldownUntil - now)}`
+	end
+	return "Open: rob the register"
+end
+
+-- P4: the escape panel's second line. Matches WantedRules: heat only decays after DecayDelay
+-- seconds with no police sighting and no new crime, and the escape counts when the stars are gone.
+function OnboardingRules.escapeHint(evading: boolean, stars: number): string
+	if evading and stars > 0 then
+		return "Stars fading: stay out of police sight until they're gone"
+	end
+	return "Break line of sight, then stay hidden until your stars are gone"
+end
+
+-- P6: successful robberies still needed to afford `price` from `cash`.
+function OnboardingRules.robberiesNeeded(cash: number, price: number, reward: number): number
+	if not (reward > 0) or cash >= price then
+		return 0
+	end
+	return math.ceil((price - cash) / reward)
+end
+
+function OnboardingRules.progressText(name: string, cash: number, price: number, reward: number, money: (number) -> string): string
+	local needed = OnboardingRules.robberiesNeeded(cash, price, reward)
+	if needed == 0 then
+		return `You can afford the {name}!`
+	end
+	return `{name}: {money(math.max(0, cash))} of {money(price)}. About {needed} more successful {if needed == 1 then "robbery" else "robberies"}.`
+end
+
+-- P7: compact panel on short (phone landscape) screens.
+function OnboardingRules.robberyPanelLayout(screenHeight: number, config: { CompactScreenHeight: number, CompactPanel: PanelLayout, FullPanel: PanelLayout }): PanelLayout
+	return if screenHeight < config.CompactScreenHeight then config.CompactPanel else config.FullPanel
+end
+
+-- P8: milestone timing, each milestone recorded once per session.
+function OnboardingRules.newMilestones(joinedAt: number): Milestones
+	return { JoinedAt = joinedAt, Done = {} }
+end
+
+-- Returns seconds since join the first time `name` is marked, else nil.
+function OnboardingRules.markMilestone(state: Milestones, name: string, now: number): number?
+	if state.Done[name] ~= nil then
+		return nil
+	end
+	local elapsed = math.max(0, now - state.JoinedAt)
+	state.Done[name] = elapsed
+	return elapsed
+end
+
+return OnboardingRules
```

## `src/ReplicatedStorage/Shared/Robbery/RobberyRules.luau`

```diff
diff --git a/src/ReplicatedStorage/Shared/Robbery/RobberyRules.luau b/src/ReplicatedStorage/Shared/Robbery/RobberyRules.luau
index 0ea7195..08e1336 100644
--- a/src/ReplicatedStorage/Shared/Robbery/RobberyRules.luau
+++ b/src/ReplicatedStorage/Shared/Robbery/RobberyRules.luau
@@ -10,7 +10,7 @@ local Types = require(script.Parent.Parent.Types)
 
 local RobberyRules = {}
 
-export type StoreState = { CooldownUntil: number, ActiveSession: string? }
+export type StoreState = { CooldownUntil: number, ActiveSession: string?, LastSession: string? }
 export type Session = {
 	Id: string,
 	UserId: number,
@@ -36,13 +36,14 @@ type Config = {
 	HoldSeconds: number,
 	Reward: number,
 	CooldownSeconds: number,
+	FailedCooldownSeconds: number?, -- shorter cooldown after a failed robbery (nil = same as CooldownSeconds)
 	PromptDistance: number,
 	DistanceSlack: number,
 	MaxEscapeSeconds: number,
 }
 
 function RobberyRules.newStore(): StoreState
-	return { CooldownUntil = -math.huge, ActiveSession = nil }
+	return { CooldownUntil = -math.huge, ActiveSession = nil, LastSession = nil }
 end
 
 function RobberyRules.canStart(store: StoreState, facts: StartFacts, now: number, config: Config): (boolean, Types.RobberyStartError?)
@@ -79,6 +80,7 @@ end
 -- Opens a session (call only after canStart). The store cools down from now.
 function RobberyRules.start(store: StoreState, sessionId: string, userId: number, storeId: string, now: number, config: Config): Session
 	store.ActiveSession = sessionId
+	store.LastSession = sessionId
 	store.CooldownUntil = now + config.CooldownSeconds
 	return {
 		Id = sessionId,
@@ -93,12 +95,19 @@ function RobberyRules.start(store: StoreState, sessionId: string, userId: number
 	}
 end
 
-local function fail(session: Session, store: StoreState?, reason: Types.RobberyFailReason): (string, Types.RobberyFailReason)
+-- A failed robbery may shorten the store's cooldown (FailedCooldownSeconds, counted from the
+-- start), but only while this session is still the store's latest: a late failure of an old
+-- getaway never cuts the cooldown of a newer robbery.
+local function fail(session: Session, store: StoreState?, reason: Types.RobberyFailReason, config: Config): (string, Types.RobberyFailReason)
 	session.Phase = "Failed"
 	session.FailReason = reason
 	if store and store.ActiveSession == session.Id then
 		store.ActiveSession = nil
 	end
+	local failed = config.FailedCooldownSeconds
+	if store and failed ~= nil and store.LastSession == session.Id then
+		store.CooldownUntil = math.min(store.CooldownUntil, session.StartedAt + failed)
+	end
 	return "Failed", reason
 end
 
@@ -106,13 +115,13 @@ end
 function RobberyRules.tick(session: Session, store: StoreState?, facts: TickFacts, now: number, config: Config): (string?, Types.RobberyFailReason?)
 	if session.Phase == "Holding" then
 		if not facts.Connected then
-			return fail(session, store, "Disconnected")
+			return fail(session, store, "Disconnected", config)
 		elseif not facts.Alive then
-			return fail(session, store, "Died")
+			return fail(session, store, "Died", config)
 		elseif facts.Jailed then
-			return fail(session, store, "Busted")
+			return fail(session, store, "Busted", config)
 		elseif not facts.InArea then
-			return fail(session, store, "LeftArea")
+			return fail(session, store, "LeftArea", config)
 		elseif now >= session.HoldEndsAt then
 			session.Phase = "Escaping"
 			session.EscapeDeadline = now + config.MaxEscapeSeconds
@@ -123,13 +132,13 @@ function RobberyRules.tick(session: Session, store: StoreState?, facts: TickFact
 		end
 	elseif session.Phase == "Escaping" then
 		if not facts.Connected then
-			return fail(session, store, "Disconnected")
+			return fail(session, store, "Disconnected", config)
 		elseif facts.Jailed then
-			return fail(session, store, "Busted")
+			return fail(session, store, "Busted", config)
 		elseif not facts.Alive then
-			return fail(session, store, "Died")
+			return fail(session, store, "Died", config)
 		elseif now > session.EscapeDeadline then
-			return fail(session, store, "EscapeTimedOut")
+			return fail(session, store, "EscapeTimedOut", config)
 		end
 	end
 	return nil, nil
```

## `src/ServerScriptService/Server/Data/RewardLedger.luau`

```diff
diff --git a/src/ServerScriptService/Server/Data/RewardLedger.luau b/src/ServerScriptService/Server/Data/RewardLedger.luau
index 309a59d..00d0267 100644
--- a/src/ServerScriptService/Server/Data/RewardLedger.luau
+++ b/src/ServerScriptService/Server/Data/RewardLedger.luau
@@ -90,7 +90,7 @@ function RewardLedger.validate(reward: any): (boolean, string?)
 	if type(reward.Reason) ~= "string" or #reward.Reason > MAX_REASON then
 		return false, "InvalidReason"
 	end
-	if type(reward.At) ~= "number" or reward.At ~= reward.At then
+	if type(reward.At) ~= "number" or reward.At ~= reward.At or reward.At == math.huge or reward.At == -math.huge then
 		return false, "InvalidTime"
 	end
 	return true, nil
```

## `src/ServerScriptService/Server/Dev/MilestoneLog.luau`

```diff
diff --git a/src/ServerScriptService/Server/Dev/MilestoneLog.luau b/src/ServerScriptService/Server/Dev/MilestoneLog.luau
new file mode 100644
index 0000000..6bb95c3
--- /dev/null
+++ b/src/ServerScriptService/Server/Dev/MilestoneLog.luau
@@ -0,0 +1,44 @@
+--!strict
+-- Studio-only playtest timing (audit 4, P8). Prints the seconds from join to each player's first
+-- car, first robbery start and first robbery escape, once per session:
+--   [Milestone] <name> FirstCar 6.4s after join
+-- Outside Studio mark() does nothing, so published servers log nothing and keep no state.
+local Players = game:GetService("Players")
+local ReplicatedStorage = game:GetService("ReplicatedStorage")
+local RunService = game:GetService("RunService")
+
+local OnboardingRules = require(ReplicatedStorage.Shared.Onboarding.OnboardingRules)
+
+local MilestoneLog = {}
+
+local enabled = RunService:IsStudio()
+local states: { [Player]: OnboardingRules.Milestones } = {}
+
+local function track(player: Player)
+	if not states[player] then
+		states[player] = OnboardingRules.newMilestones(os.clock())
+	end
+end
+
+function MilestoneLog.mark(player: Player, name: string)
+	if not enabled then
+		return
+	end
+	track(player)
+	local elapsed = OnboardingRules.markMilestone(states[player], name, os.clock())
+	if elapsed then
+		print(string.format("[Milestone] %s %s %.1fs after join", player.Name, name, elapsed))
+	end
+end
+
+if enabled then
+	Players.PlayerAdded:Connect(track)
+	for _, player in Players:GetPlayers() do
+		track(player)
+	end
+	Players.PlayerRemoving:Connect(function(player)
+		states[player] = nil
+	end)
+end
+
+return MilestoneLog
```

## `src/ServerScriptService/Server/Services/RobberyService.luau`

```diff
diff --git a/src/ServerScriptService/Server/Services/RobberyService.luau b/src/ServerScriptService/Server/Services/RobberyService.luau
index 48e92ba..76ac919 100644
--- a/src/ServerScriptService/Server/Services/RobberyService.luau
+++ b/src/ServerScriptService/Server/Services/RobberyService.luau
@@ -29,6 +29,7 @@ local WantedService = require(Services.WantedService)
 local JailService = require(Services.JailService)
 local EconomyService = require(Services.EconomyService)
 local PoliceService = require(Services.PoliceService)
+local MilestoneLog = require(script.Parent.Parent.Dev.MilestoneLog)
 
 local RobberyService = {}
 
@@ -37,6 +38,7 @@ type Store = {
 	State: RobberyRules.StoreState,
 	Register: BasePart,
 	Area: BasePart,
+	Folder: Instance,
 }
 type Live = { Session: RobberyRules.Session, Character: Model, LastInProgressReport: number }
 type Pending = { TxId: string, Amount: number, SessionId: string, StoreId: string, NextTry: number, InFlight: boolean, Recorded: boolean }
@@ -58,6 +60,14 @@ local function notify(player: Player, kind: string, payload: { [string]: any })
 	end
 end
 
+-- Display only: the store's cooldown and busy state for the client's marker (P5). The server
+-- still decides every start in RobberyRules.canStart.
+local function publishStore(store: Store)
+	local cooldownUntil = store.State.CooldownUntil
+	store.Folder:SetAttribute("RobberyCooldownUntil", if cooldownUntil == -math.huge then 0 else cooldownUntil)
+	store.Folder:SetAttribute("RobberyBusy", store.State.ActiveSession ~= nil)
+end
+
 local function publish(player: Player, session: RobberyRules.Session?)
 	local isLive = session ~= nil and RobberyRules.isLive(session)
 	player:SetAttribute(PlayerAttributes.RobberyPhase, if isLive then (session :: any).Phase else nil)
@@ -130,8 +140,10 @@ function RobberyService.tryStart(player: Player, storeId: string): (boolean, Typ
 	end
 	WantedService.reportCrime(player, RobberyConfig.WantedCrime)
 	publish(player, session)
+	publishStore(store)
 	notify(player, "Started", { Id = session.Id, HoldEndsAt = session.HoldEndsAt, Reward = session.Reward })
 	print(`[Robbery] {player.Name} started {session.Id} at {storeId}`)
+	MilestoneLog.mark(player, "FirstRobbery")
 	return true, nil
 end
 
@@ -163,6 +175,9 @@ local function tick()
 			WantedService.reportCrime(player, RobberyConfig.InProgressCrime)
 		end
 	end
+	for _, store in stores do
+		publishStore(store)
+	end
 end
 
 local function onEscaped(player: Player)
@@ -175,6 +190,7 @@ local function onEscaped(player: Player)
 		return -- still holding (or already settled): never pays
 	end
 	endSession(player, entry)
+	MilestoneLog.mark(player, "FirstEscape")
 	if paidIds[session.Id] then
 		return
 	end
@@ -231,6 +247,7 @@ end
 function RobberyService.clearCooldownsForTesting()
 	for _, store in stores do
 		store.State.CooldownUntil = -math.huge
+		publishStore(store)
 	end
 end
 
@@ -253,7 +270,8 @@ function RobberyService.init()
 		warn("[Robbery] City.Store is incomplete; robberies disabled")
 		return
 	end
-	stores[id] = { Id = id, State = RobberyRules.newStore(), Register = register, Area = area }
+	stores[id] = { Id = id, State = RobberyRules.newStore(), Register = register, Area = area, Folder = folder }
+	publishStore(stores[id])
 	local prompt = register:FindFirstChild("RobPrompt", true)
 	if prompt and prompt:IsA("ProximityPrompt") then
 		prompt.Triggered:Connect(function(player)
```

## `src/ServerScriptService/Server/Services/VehicleService.luau`

```diff
diff --git a/src/ServerScriptService/Server/Services/VehicleService.luau b/src/ServerScriptService/Server/Services/VehicleService.luau
index 973d11b..fafc94b 100644
--- a/src/ServerScriptService/Server/Services/VehicleService.luau
+++ b/src/ServerScriptService/Server/Services/VehicleService.luau
@@ -16,6 +16,7 @@ local RateLimiter = require(Server.Util.RateLimiter)
 local WorldService = require(script.Parent.WorldService)
 local JailService = require(script.Parent.JailService)
 local EconomyService = require(script.Parent.EconomyService)
+local MilestoneLog = require(Server.Dev.MilestoneLog)
 
 local VehicleService = {}
 
@@ -161,6 +162,7 @@ local function spawnVehicle(player: Player, vehicleId: string): (boolean, Types.
 	end
 	updateSimulation(vehicle)
 	seat:Sit(humanoid)
+	MilestoneLog.mark(player, "FirstCar")
 	return true, nil
 end
 
```

## `src/ServerStorage/Tests/OnboardingRules.spec.luau`

```diff
diff --git a/src/ServerStorage/Tests/OnboardingRules.spec.luau b/src/ServerStorage/Tests/OnboardingRules.spec.luau
new file mode 100644
index 0000000..69fef5a
--- /dev/null
+++ b/src/ServerStorage/Tests/OnboardingRules.spec.luau
@@ -0,0 +1,82 @@
+-- New-player guidance helpers (audit 4 onboarding batch).
+local ReplicatedStorage = game:GetService("ReplicatedStorage")
+local OnboardingRules = require(ReplicatedStorage.Shared.Onboarding.OnboardingRules)
+local OnboardingConfig = require(ReplicatedStorage.Shared.Config.OnboardingConfig)
+local RobberyConfig = require(ReplicatedStorage.Shared.Config.RobberyConfig)
+local DealershipConfig = require(ReplicatedStorage.Shared.Config.DealershipConfig)
+local EconomyConfig = require(ReplicatedStorage.Shared.Config.EconomyConfig)
+local WantedConfig = require(ReplicatedStorage.Shared.Config.WantedConfig)
+local Assert = require(script.Parent.Assert)
+
+local function money(n: number): string
+	return "$" .. tostring(n)
+end
+
+return {
+	["P1: one owned car spawns directly; two or more open the garage"] = function()
+		Assert.equal(OnboardingRules.spawnButtonAction(0), "Spawn")
+		Assert.equal(OnboardingRules.spawnButtonAction(1), "Spawn")
+		Assert.equal(OnboardingRules.spawnButtonAction(2), "Choose")
+		Assert.equal(OnboardingRules.spawnButtonAction(5), "Choose")
+	end,
+	["P2: markers show between the hide and max distance only"] = function()
+		local c = OnboardingConfig
+		Assert.equal(OnboardingRules.markerVisible(c.MarkerHideDistance - 1, c), false, "already there")
+		Assert.equal(OnboardingRules.markerVisible(c.MarkerHideDistance, c), true)
+		Assert.equal(OnboardingRules.markerVisible(150, c), true, "spawn to store is ~150 studs")
+		Assert.equal(OnboardingRules.markerVisible(240, c), true, "spawn to dealership is ~240 studs")
+		Assert.equal(OnboardingRules.markerVisible(c.MarkerMaxDistance + 1, c), false)
+		Assert.equal(OnboardingRules.markerVisible(0 / 0, c), false)
+		Assert.equal(OnboardingRules.formatDistance(151), "150 studs")
+		Assert.equal(OnboardingRules.formatDistance(237), "240 studs")
+	end,
+	["P4: the escape hint matches the wanted rules"] = function()
+		-- Heat only decays after DecayDelay unseen seconds; the escape counts when stars reach 0.
+		Assert.equal(WantedConfig.DecayDelay, 8, "pursuit tuning unchanged")
+		local before = OnboardingRules.escapeHint(false, 2)
+		Assert.truthy(before:find("line of sight", 1, true) ~= nil, before)
+		Assert.truthy(before:find("stars are gone", 1, true) ~= nil, before)
+		local evading = OnboardingRules.escapeHint(true, 1)
+		Assert.truthy(evading:find("fading", 1, true) ~= nil, evading)
+		Assert.equal(OnboardingRules.escapeHint(true, 0), before, "no stars: no 'fading' claim")
+	end,
+	["P5: store status and reopen clock"] = function()
+		Assert.equal(OnboardingRules.formatClock(90), "1:30")
+		Assert.equal(OnboardingRules.formatClock(0.2), "0:01")
+		Assert.equal(OnboardingRules.formatClock(-5), "0:00")
+		Assert.equal(OnboardingRules.storeStatus(nil, false, 100), "Open: rob the register")
+		Assert.equal(OnboardingRules.storeStatus(0, false, 100), "Open: rob the register")
+		Assert.equal(OnboardingRules.storeStatus(190, false, 100), "Reopens in 1:30")
+		Assert.equal(OnboardingRules.storeStatus(190, true, 100), "Being robbed")
+	end,
+	["P6: eight successful robberies buy the Muscle from the $500 start"] = function()
+		local price = DealershipConfig.priceOf("Muscle") :: number
+		Assert.equal(price, 15000, "price unchanged until human playtests")
+		Assert.equal(EconomyConfig.StartingCash, 500)
+		Assert.equal(RobberyConfig.Reward, 2000)
+		Assert.equal(OnboardingRules.robberiesNeeded(500, price, 2000), 8) -- 7 leaves you at $14,500
+		Assert.equal(OnboardingRules.robberiesNeeded(500 + 7 * 2000, price, 2000), 1)
+		Assert.equal(OnboardingRules.robberiesNeeded(15000, price, 2000), 0)
+		Assert.equal(OnboardingRules.robberiesNeeded(20000, price, 2000), 0)
+		Assert.equal(OnboardingRules.robberiesNeeded(500, price, 0), 0, "no reward: no division by zero")
+		Assert.equal(OnboardingRules.progressText("Muscle", 500, price, 2000, money), "Muscle: $500 of $15000. About 8 more successful robberies.")
+		Assert.equal(OnboardingRules.progressText("Muscle", 13500, price, 2000, money), "Muscle: $13500 of $15000. About 1 more successful robbery.")
+		Assert.equal(OnboardingRules.progressText("Muscle", 15000, price, 2000, money), "You can afford the Muscle!")
+	end,
+	["P7: compact robbery panel on phone screens stays within 7% and readable"] = function()
+		local c = OnboardingConfig
+		local phone = OnboardingRules.robberyPanelLayout(374, c) -- iPhone 7 landscape (666 x 374)
+		Assert.equal(phone, c.CompactPanel)
+		Assert.truthy(phone.Width * phone.Height / (666 * 374) <= 0.07, "panel <= 7% of the screen")
+		Assert.truthy(phone.Y >= 92, "below the top HUD row (buttons 8-52, stars/cash 58-84)")
+		Assert.truthy(phone.DetailSize >= c.MinTextSize and phone.TitleSize >= c.MinTextSize, "text >= 14 px")
+		Assert.equal(OnboardingRules.robberyPanelLayout(720, c), c.FullPanel)
+	end,
+	["P8: each milestone is recorded once, from the join time"] = function()
+		local m = OnboardingRules.newMilestones(10)
+		Assert.equal(OnboardingRules.markMilestone(m, "FirstCar", 16.5), 6.5)
+		Assert.equal(OnboardingRules.markMilestone(m, "FirstCar", 30), nil, "only the first time")
+		Assert.equal(OnboardingRules.markMilestone(m, "FirstRobbery", 40), 30)
+		Assert.equal(#OnboardingConfig.Milestones, 3)
+	end,
+}
```

## `src/ServerStorage/Tests/RewardLedger.spec.luau`

```diff
diff --git a/src/ServerStorage/Tests/RewardLedger.spec.luau b/src/ServerStorage/Tests/RewardLedger.spec.luau
index 765c15d..6abeacb 100644
--- a/src/ServerStorage/Tests/RewardLedger.spec.luau
+++ b/src/ServerStorage/Tests/RewardLedger.spec.luau
@@ -200,6 +200,8 @@ return {
 			{ TxId = "t", Amount = C.MaxTransaction + 1, Reason = "x", At = 1 },
 			{ TxId = "t", Amount = 10, Reason = string.rep("r", 101), At = 1 },
 			{ TxId = "t", Amount = 10, Reason = "x", At = 0 / 0 },
+			{ TxId = "t", Amount = 10, Reason = "x", At = math.huge },
+			{ TxId = "t", Amount = 10, Reason = "x", At = -math.huge },
 		}
 		for i, r in bad do
 			local ok, err = RewardLedger.record(rewards, "r", r :: any)
```

## `src/ServerStorage/Tests/RobberyRules.spec.luau`

```diff
diff --git a/src/ServerStorage/Tests/RobberyRules.spec.luau b/src/ServerStorage/Tests/RobberyRules.spec.luau
index 0062704..c04a0db 100644
--- a/src/ServerStorage/Tests/RobberyRules.spec.luau
+++ b/src/ServerStorage/Tests/RobberyRules.spec.luau
@@ -37,6 +37,7 @@ return {
 		Assert.equal(C.HoldSeconds, 15)
 		Assert.equal(C.Reward, 2000)
 		Assert.equal(C.CooldownSeconds, 180)
+		Assert.equal(C.FailedCooldownSeconds, 90, "audit 4 trial: 90 s after a failed robbery")
 		local crime = WantedConfig.Crimes[C.WantedCrime]
 		Assert.equal(WantedRules.starsForHeat(crime.Heat, WantedConfig), 2, "the robbery alarm gives 2 stars")
 		Assert.equal(WantedConfig.Crimes[C.InProgressCrime].Heat, 0)
@@ -69,8 +70,9 @@ return {
 		RobberyRules.tick(session, store, tickFacts({ InArea = false }), 102, C)
 		ok, err = RobberyRules.canStart(store, facts(), 102, C)
 		Assert.equal(err, "StoreCooldown", "a failed robbery still cools the store down")
-		Assert.equal((RobberyRules.canStart(store, facts(), 100 + C.CooldownSeconds - 0.01, C)), false)
-		Assert.equal((RobberyRules.canStart(store, facts(), 100 + C.CooldownSeconds, C)), true)
+		local cooldown = C.FailedCooldownSeconds or C.CooldownSeconds
+		Assert.equal((RobberyRules.canStart(store, facts(), 100 + cooldown - 0.01, C)), false)
+		Assert.equal((RobberyRules.canStart(store, facts(), 100 + cooldown, C)), true)
 	end,
 	["holdout completes only after the full server time"] = function()
 		local store, session = started(100)
@@ -148,4 +150,41 @@ return {
 		local register = spec.Register.Position
 		Assert.equal(math.abs(register.X - c.X) < size.X / 2 and math.abs(register.Z - c.Z) < size.Z / 2, true, "register inside the holdout area")
 	end,
+	["a failed robbery reopens the store after 90 s; a successful one keeps 180 s"] = function()
+		-- Trial setting (FailedCooldownSeconds = 90).
+		local store, session = started(100)
+		RobberyRules.tick(session, store, tickFacts({ Alive = false }), 105, C)
+		Assert.equal(session.Phase, "Failed")
+		Assert.equal(store.CooldownUntil, 100 + C.FailedCooldownSeconds)
+		Assert.equal((RobberyRules.canStart(store, facts(), 189.9, C)), false)
+		Assert.equal((RobberyRules.canStart(store, facts(), 190, C)), true)
+		-- Busted during the getaway: also 90 s from the start.
+		local store2, session2 = started(100)
+		RobberyRules.tick(session2, store2, OK_TICK, 100 + C.HoldSeconds, C)
+		RobberyRules.tick(session2, store2, tickFacts({ Jailed = true }), 140, C)
+		Assert.equal(store2.CooldownUntil, 190)
+		-- A successful robbery keeps the full cooldown.
+		local store3, session3 = started(100)
+		RobberyRules.tick(session3, store3, OK_TICK, 100 + C.HoldSeconds, C)
+		Assert.equal(RobberyRules.onEscaped(session3), true)
+		Assert.equal(store3.CooldownUntil, 100 + C.CooldownSeconds)
+	end,
+	["existing behaviour: without FailedCooldownSeconds a failure keeps 180 s"] = function()
+		local old = table.clone(C) :: any
+		old.FailedCooldownSeconds = nil
+		local store = RobberyRules.newStore()
+		local session = RobberyRules.start(store, "id-1", 1, "Store1", 100, old)
+		RobberyRules.tick(session, store, tickFacts({ InArea = false }), 103, old)
+		Assert.equal(session.Phase, "Failed")
+		Assert.equal(store.CooldownUntil, 100 + C.CooldownSeconds)
+	end,
+	["a late failure of an old getaway never shortens a newer robbery's cooldown"] = function()
+		local store, a = started(0)
+		RobberyRules.tick(a, store, OK_TICK, C.HoldSeconds, C) -- A escaping until 15 + 300
+		local b = RobberyRules.start(store, "id-2", 2, "Store1", 200, C) -- after A's 180 s cooldown
+		RobberyRules.tick(a, store, OK_TICK, C.HoldSeconds + C.MaxEscapeSeconds + 1, C)
+		Assert.equal(a.FailReason, "EscapeTimedOut")
+		Assert.equal(store.CooldownUntil, 200 + C.CooldownSeconds, "B's cooldown untouched")
+		Assert.equal(store.ActiveSession, b.Id)
+	end,
 }
```

## `src/StarterPlayer/StarterPlayerScripts/Client/Controllers/DealershipController.luau`

```diff
diff --git a/src/StarterPlayer/StarterPlayerScripts/Client/Controllers/DealershipController.luau b/src/StarterPlayer/StarterPlayerScripts/Client/Controllers/DealershipController.luau
index 9ec3e43..b07a18f 100644
--- a/src/StarterPlayer/StarterPlayerScripts/Client/Controllers/DealershipController.luau
+++ b/src/StarterPlayer/StarterPlayerScripts/Client/Controllers/DealershipController.luau
@@ -12,6 +12,8 @@ local Remotes = require(Shared.Net.Remotes)
 local VehicleConfig = require(Shared.Config.VehicleConfig)
 local DealershipConfig = require(Shared.Config.DealershipConfig)
 local PlayerAttributes = require(Shared.Player.PlayerAttributes)
+local RobberyConfig = require(Shared.Config.RobberyConfig)
+local OnboardingRules = require(Shared.Onboarding.OnboardingRules)
 local UiKit = require(script.Parent.UiKit)
 
 local DealershipController = {}
@@ -52,10 +54,31 @@ function DealershipController.init()
 
 	type Row = { VehicleId: string, Price: number, Button: TextButton, Pending: boolean }
 	local rows: { Row } = {}
+	-- Savings progress (P6) fills the message line until a purchase result replaces it.
+	local showProgress = false
+
+	local function progressText(): string
+		local cash = player:GetAttribute(PlayerAttributes.Cash)
+		if type(cash) ~= "number" then
+			return ""
+		end
+		local owned = UiKit.ownedVehicles(player)
+		for _, row in rows do
+			if not table.find(owned, row.VehicleId) then
+				local stats = VehicleConfig.get(row.VehicleId)
+				return OnboardingRules.progressText(if stats then stats.DisplayName else row.VehicleId, cash, row.Price, RobberyConfig.Reward, UiKit.money)
+			end
+		end
+		return ""
+	end
 
 	local function refresh()
 		local owned = UiKit.ownedVehicles(player)
 		local cash = player:GetAttribute(PlayerAttributes.Cash)
+		if showProgress then
+			message.TextColor3 = Color3.fromRGB(255, 220, 110)
+			message.Text = progressText()
+		end
 		for _, row in rows do
 			if row.Pending then
 				continue
@@ -104,6 +127,7 @@ function DealershipController.init()
 			end
 			row.Pending = true
 			buy.Text = "Buying..."
+			showProgress = false
 			message.Text = ""
 			task.spawn(function()
 				local ok, result, err = pcall(function()
@@ -144,6 +168,7 @@ function DealershipController.init()
 		end
 		prompt.Triggered:Connect(function()
 			message.Text = ""
+			showProgress = true
 			refresh()
 			window.Visible = true
 		end)
```

## `src/StarterPlayer/StarterPlayerScripts/Client/Controllers/GarageController.luau`

```diff
diff --git a/src/StarterPlayer/StarterPlayerScripts/Client/Controllers/GarageController.luau b/src/StarterPlayer/StarterPlayerScripts/Client/Controllers/GarageController.luau
index 533b2bf..48d6304 100644
--- a/src/StarterPlayer/StarterPlayerScripts/Client/Controllers/GarageController.luau
+++ b/src/StarterPlayer/StarterPlayerScripts/Client/Controllers/GarageController.luau
@@ -2,11 +2,13 @@
 -- Garage window: lists the vehicles the server says this player owns (OwnedVehicles
 -- attribute) and spawns the chosen one. The server re-checks ownership on every spawn
 -- request, so this list is display only. V (or DPad up) spawns the last chosen car.
+-- Spawn Car spawns directly while the player owns one car; the window opens only with a choice.
 local Players = game:GetService("Players")
 local ReplicatedStorage = game:GetService("ReplicatedStorage")
 
 local VehicleConfig = require(ReplicatedStorage.Shared.Config.VehicleConfig)
 local PlayerAttributes = require(ReplicatedStorage.Shared.Player.PlayerAttributes)
+local OnboardingRules = require(ReplicatedStorage.Shared.Onboarding.OnboardingRules)
 local VehicleController = require(script.Parent.VehicleController)
 local UiKit = require(script.Parent.UiKit)
 
@@ -25,6 +27,18 @@ function GarageController.spawnSelected()
 	VehicleController.requestSpawn(selected)
 end
 
+-- The Spawn Car button (P1): one owned car spawns straight away, 2+ open the garage.
+function GarageController.spawnOrChoose()
+	if OnboardingRules.spawnButtonAction(#UiKit.ownedVehicles(player)) == "Spawn" then
+		if panel then
+			panel.Visible = false
+		end
+		VehicleController.requestSpawn(selected)
+	else
+		GarageController.toggle()
+	end
+end
+
 function GarageController.toggle()
 	if panel then
 		panel.Visible = not panel.Visible
```

## `src/StarterPlayer/StarterPlayerScripts/Client/Controllers/OnboardingTipController.luau`

```diff
diff --git a/src/StarterPlayer/StarterPlayerScripts/Client/Controllers/OnboardingTipController.luau b/src/StarterPlayer/StarterPlayerScripts/Client/Controllers/OnboardingTipController.luau
new file mode 100644
index 0000000..6f727c1
--- /dev/null
+++ b/src/StarterPlayer/StarterPlayerScripts/Client/Controllers/OnboardingTipController.luau
@@ -0,0 +1,60 @@
+--!strict
+-- One-time first-spawn tip (audit 4, P3). A small card on the left, under the top HUD row, that
+-- tells a new player what to do. It never blocks driving: only its X button takes input, it
+-- stays clear of the touch controls (bottom right) and the speedometer (bottom centre), and it
+-- closes itself after OnboardingConfig.TipSeconds. Shown once per session.
+local Players = game:GetService("Players")
+local ReplicatedStorage = game:GetService("ReplicatedStorage")
+
+local Shared = ReplicatedStorage.Shared
+local OnboardingConfig = require(Shared.Config.OnboardingConfig)
+local PlayerAttributes = require(Shared.Player.PlayerAttributes)
+local UiKit = require(script.Parent.UiKit)
+
+local OnboardingTipController = {}
+
+local player = Players.LocalPlayer
+
+local TIP_TEXT = "Rob the 24/7 MART for cash, then escape the police. Buy faster cars at OUTLAW MOTORS. Follow the markers."
+
+function OnboardingTipController.init()
+	if not player.Character then
+		player.CharacterAdded:Wait()
+	end
+	local gui = Instance.new("ScreenGui")
+	gui.Name = "OnboardingTip"
+	gui.ResetOnSpawn = false
+	gui.DisplayOrder = 4
+	gui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
+	gui.Parent = player:WaitForChild("PlayerGui")
+
+	local card = Instance.new("Frame")
+	card.Name = "Tip"
+	card.Active = false -- touches and clicks outside the X pass through to the game
+	card.Position = UDim2.fromOffset(12, 92)
+	card.Size = UDim2.fromOffset(250, 84)
+	card.BackgroundColor3 = Color3.fromRGB(22, 24, 30)
+	card.BackgroundTransparency = 0.2
+	card.Parent = gui
+	UiKit.corner(card, 12)
+	local text = UiKit.text(card, "Text", TIP_TEXT, UDim2.new(1, -56, 1, -12), UDim2.fromOffset(10, 6), OnboardingConfig.MinTextSize)
+	text.TextXAlignment = Enum.TextXAlignment.Left
+	text.TextYAlignment = Enum.TextYAlignment.Center
+	local close = UiKit.button(card, "Close", "X", UDim2.fromOffset(44, 44), UDim2.new(1, -48, 0, 4), Color3.fromRGB(70, 70, 80))
+	close.Activated:Connect(function()
+		gui:Destroy()
+	end)
+	task.delay(OnboardingConfig.TipSeconds, function()
+		if gui.Parent then
+			gui:Destroy()
+		end
+	end)
+	-- A robbery's objective panel takes over the top of the screen, so the tip steps aside.
+	player:GetAttributeChangedSignal(PlayerAttributes.RobberyPhase):Connect(function()
+		if gui.Parent then
+			gui:Destroy()
+		end
+	end)
+end
+
+return OnboardingTipController
```

## `src/StarterPlayer/StarterPlayerScripts/Client/Controllers/RobberyHudController.luau`

```diff
diff --git a/src/StarterPlayer/StarterPlayerScripts/Client/Controllers/RobberyHudController.luau b/src/StarterPlayer/StarterPlayerScripts/Client/Controllers/RobberyHudController.luau
index c9f79eb..10b9d04 100644
--- a/src/StarterPlayer/StarterPlayerScripts/Client/Controllers/RobberyHudController.luau
+++ b/src/StarterPlayer/StarterPlayerScripts/Client/Controllers/RobberyHudController.luau
@@ -2,6 +2,8 @@
 -- Store robbery HUD (display only). The objective panel follows the server-written
 -- RobberyPhase / RobberyHoldEndsAt / RobberyReward attributes; short messages come from the
 -- server's OnRobberyNotice. Nothing here can start, finish or pay a robbery.
+-- On short (phone) screens the panel is compact and sits just under the top HUD row (P7); while
+-- escaping it explains how escaping works, matching WantedRules (P4).
 local Players = game:GetService("Players")
 local ReplicatedStorage = game:GetService("ReplicatedStorage")
 local RunService = game:GetService("RunService")
@@ -10,6 +12,8 @@ local Workspace = game:GetService("Workspace")
 local Shared = ReplicatedStorage.Shared
 local Remotes = require(Shared.Net.Remotes)
 local PlayerAttributes = require(Shared.Player.PlayerAttributes)
+local OnboardingConfig = require(Shared.Config.OnboardingConfig)
+local OnboardingRules = require(Shared.Onboarding.OnboardingRules)
 
 local RobberyHudController = {}
 
@@ -45,6 +49,7 @@ function RobberyHudController.init()
 	gui.Name = "RobberyHud"
 	gui.ResetOnSpawn = false
 	gui.DisplayOrder = 5
+	gui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets -- clear of notches and Roblox's top bar
 	gui.Parent = player:WaitForChild("PlayerGui")
 
 	-- Objective panel: same slot as the jail panel (y 136); the two can't be shown together.
@@ -83,6 +88,27 @@ function RobberyHudController.init()
 	detail.TextWrapped = true
 	detail.Parent = panel
 
+	-- Full panel on PC/tablet; compact one under the top HUD row on short phone screens.
+	local layoutHeight = -1
+	local function applyLayout()
+		local camera = Workspace.CurrentCamera
+		local height = if camera then camera.ViewportSize.Y else 0
+		if height == layoutHeight then
+			return
+		end
+		layoutHeight = height
+		local layout = OnboardingRules.robberyPanelLayout(height, OnboardingConfig)
+		panel.Position = UDim2.new(0.5, 0, 0, layout.Y)
+		panel.Size = UDim2.fromOffset(layout.Width, layout.Height)
+		local titleHeight = layout.TitleSize + 6
+		title.TextSize = layout.TitleSize
+		title.Size = UDim2.new(1, -12, 0, titleHeight)
+		title.Position = UDim2.fromOffset(6, 4)
+		detail.TextSize = layout.DetailSize
+		detail.Size = UDim2.new(1, -12, 0, layout.Height - titleHeight - 8)
+		detail.Position = UDim2.fromOffset(6, 4 + titleHeight)
+	end
+
 	-- Toast for one-off messages (alarm, rejection reason, success, failure).
 	local toast = Instance.new("TextLabel")
 	toast.Name = "Toast"
@@ -151,6 +177,9 @@ function RobberyHudController.init()
 		local phase = player:GetAttribute(PlayerAttributes.RobberyPhase)
 		local jailed = player:GetAttribute(PlayerAttributes.Jailed) == true
 		panel.Visible = (phase == "Holding" or phase == "Escaping" or phase == "PayoutPending") and not jailed
+		if panel.Visible then
+			applyLayout()
+		end
 		if phase == "Holding" then
 			local endsAt = player:GetAttribute(PlayerAttributes.RobberyHoldEndsAt)
 			local left = if type(endsAt) == "number" then math.max(0, math.ceil(endsAt - Workspace:GetServerTimeNow())) else 0
@@ -158,8 +187,9 @@ function RobberyHudController.init()
 			detail.Text = "Stay inside until the timer ends"
 		elseif phase == "Escaping" then
 			local reward = player:GetAttribute(PlayerAttributes.RobberyReward)
-			title.Text = "ESCAPE THE POLICE"
-			detail.Text = `Lose your wanted stars to keep {if type(reward) == "number" then money(reward) else "the cash"}`
+			title.Text = `ESCAPE TO KEEP {if type(reward) == "number" then money(reward) else "THE CASH"}`
+			local stars = player:GetAttribute(PlayerAttributes.WantedLevel)
+			detail.Text = OnboardingRules.escapeHint(player:GetAttribute(PlayerAttributes.WantedEvading) == true, if type(stars) == "number" then stars else 0)
 		elseif phase == "PayoutPending" then
 			local reward = player:GetAttribute(PlayerAttributes.RobberyReward)
 			title.Text = "REWARD PENDING"
```

## `src/StarterPlayer/StarterPlayerScripts/Client/Controllers/VehicleHudController.luau`

```diff
diff --git a/src/StarterPlayer/StarterPlayerScripts/Client/Controllers/VehicleHudController.luau b/src/StarterPlayer/StarterPlayerScripts/Client/Controllers/VehicleHudController.luau
index 53c248b..ead7078 100644
--- a/src/StarterPlayer/StarterPlayerScripts/Client/Controllers/VehicleHudController.luau
+++ b/src/StarterPlayer/StarterPlayerScripts/Client/Controllers/VehicleHudController.luau
@@ -109,7 +109,7 @@ function VehicleHudController.init()
 	spawnButton.Parent = gui
 	corner(spawnButton, 10)
 	spawnButton.Activated:Connect(function()
-		GarageController.toggle() -- choose which owned car to spawn
+		GarageController.spawnOrChoose() -- one car: spawn it; 2+: choose in the garage
 	end)
 
 	local toast = label(gui, "Toast", UDim2.fromOffset(380, 36), UDim2.new(0.5, 0, 0, 140), Vector2.new(0.5, 0), 16)
```

## `src/StarterPlayer/StarterPlayerScripts/Client/Controllers/WorldMarkerController.luau`

```diff
diff --git a/src/StarterPlayer/StarterPlayerScripts/Client/Controllers/WorldMarkerController.luau b/src/StarterPlayer/StarterPlayerScripts/Client/Controllers/WorldMarkerController.luau
new file mode 100644
index 0000000..84a701f
--- /dev/null
+++ b/src/StarterPlayer/StarterPlayerScripts/Client/Controllers/WorldMarkerController.luau
@@ -0,0 +1,107 @@
+--!strict
+-- Discreet floating markers over the 24/7 MART and OUTLAW MOTORS (audit 4, P2), with the
+-- distance, plus the store's status (open / being robbed / reopens in m:ss, P5). Shown between
+-- OnboardingConfig.MarkerHideDistance and MarkerMaxDistance from each sign. Display only: the
+-- store's cooldown comes from server-written attributes on City.Store, and the server still
+-- checks every robbery start.
+local Players = game:GetService("Players")
+local ReplicatedStorage = game:GetService("ReplicatedStorage")
+local Workspace = game:GetService("Workspace")
+
+local Shared = ReplicatedStorage.Shared
+local OnboardingConfig = require(Shared.Config.OnboardingConfig)
+local OnboardingRules = require(Shared.Onboarding.OnboardingRules)
+
+local WorldMarkerController = {}
+
+local player = Players.LocalPlayer
+local UPDATE_SECONDS = 0.25
+
+type Marker = { Gui: BillboardGui, Anchor: BasePart, Name: string, Top: TextLabel, Bottom: TextLabel, Status: () -> string }
+
+local function makeMarker(anchor: BasePart, name: string, color: Color3, status: () -> string): Marker
+	local gui = Instance.new("BillboardGui")
+	gui.Name = `Marker_{anchor.Name}`
+	gui.Adornee = anchor
+	gui.AlwaysOnTop = true -- readable through buildings, so it points the way
+	gui.LightInfluence = 0
+	gui.Size = UDim2.fromOffset(190, 46)
+	gui.StudsOffsetWorldSpace = Vector3.new(0, OnboardingConfig.MarkerHeight, 0)
+	gui.ResetOnSpawn = false
+	gui.Enabled = false
+	local frame = Instance.new("Frame")
+	frame.Size = UDim2.fromScale(1, 1)
+	frame.BackgroundColor3 = Color3.fromRGB(20, 22, 28)
+	frame.BackgroundTransparency = 0.35
+	frame.Parent = gui
+	local corner = Instance.new("UICorner")
+	corner.CornerRadius = UDim.new(0, 8)
+	corner.Parent = frame
+	local function line(y: number, textColor: Color3, font: Enum.Font): TextLabel
+		local l = Instance.new("TextLabel")
+		l.BackgroundTransparency = 1
+		l.Size = UDim2.new(1, -8, 0, 20)
+		l.Position = UDim2.fromOffset(4, y)
+		l.Font = font
+		l.TextSize = OnboardingConfig.MinTextSize
+		l.TextColor3 = textColor
+		l.Parent = frame
+		return l
+	end
+	local top = line(3, color, Enum.Font.GothamBlack)
+	local bottom = line(23, Color3.new(1, 1, 1), Enum.Font.GothamBold)
+	gui.Parent = player:WaitForChild("PlayerGui")
+	return { Gui = gui, Anchor = anchor, Name = name, Top = top, Bottom = bottom, Status = status }
+end
+
+function WorldMarkerController.init()
+	local city = Workspace:WaitForChild("City", 30)
+	local store = city and city:WaitForChild("Store", 30)
+	local storeSign = store and store:WaitForChild("StoreSign", 30)
+	local dealership = city and city:WaitForChild("Dealership", 30)
+	local dealerSign = dealership and dealership:WaitForChild("DealerSign", 30)
+	local markers: { Marker } = {}
+
+	if store and storeSign and storeSign:IsA("BasePart") then
+		local storeFolder = store :: Instance
+		local function status(): string
+			local cooldownUntil = storeFolder:GetAttribute("RobberyCooldownUntil")
+			return OnboardingRules.storeStatus(if type(cooldownUntil) == "number" then cooldownUntil else nil, storeFolder:GetAttribute("RobberyBusy") == true, Workspace:GetServerTimeNow())
+		end
+		table.insert(markers, makeMarker(storeSign, "24/7 MART", Color3.fromRGB(255, 220, 110), status))
+		-- The register's prompt also says when the store reopens (local display only).
+		local prompt = store:FindFirstChild("RobPrompt", true)
+		if prompt and prompt:IsA("ProximityPrompt") then
+			local actionText = prompt.ActionText
+			task.spawn(function()
+				while prompt.Parent do
+					local text = status()
+					prompt.ActionText = if text:find("Reopens", 1, true) then text else actionText
+					task.wait(0.5)
+				end
+			end)
+		end
+	end
+	if dealerSign and dealerSign:IsA("BasePart") then
+		table.insert(markers, makeMarker(dealerSign, "OUTLAW MOTORS", Color3.fromRGB(130, 190, 255), function()
+			return "Buy cars here"
+		end))
+	end
+
+	while true do
+		local character = player.Character
+		local root = character and character:FindFirstChild("HumanoidRootPart")
+		for _, marker in markers do
+			local distance = if root and root:IsA("BasePart") then (root.Position - marker.Anchor.Position).Magnitude else math.huge
+			local visible = OnboardingRules.markerVisible(distance, OnboardingConfig)
+			marker.Gui.Enabled = visible
+			if visible then
+				marker.Top.Text = `{marker.Name} · {OnboardingRules.formatDistance(distance)}`
+				marker.Bottom.Text = marker.Status()
+			end
+		end
+		task.wait(UPDATE_SECONDS)
+	end
+end
+
+return WorldMarkerController
```

## `src/StarterPlayer/StarterPlayerScripts/Client/Main.client.luau`

```diff
diff --git a/src/StarterPlayer/StarterPlayerScripts/Client/Main.client.luau b/src/StarterPlayer/StarterPlayerScripts/Client/Main.client.luau
index c07c347..471def1 100644
--- a/src/StarterPlayer/StarterPlayerScripts/Client/Main.client.luau
+++ b/src/StarterPlayer/StarterPlayerScripts/Client/Main.client.luau
@@ -17,6 +17,8 @@ local CashHudController = require(Controllers.CashHudController)
 local GarageController = require(Controllers.GarageController)
 local DealershipController = require(Controllers.DealershipController)
 local RobberyHudController = require(Controllers.RobberyHudController)
+local WorldMarkerController = require(Controllers.WorldMarkerController)
+local OnboardingTipController = require(Controllers.OnboardingTipController)
 
 VehicleInputController.init()
 VehicleController.init()
@@ -31,6 +33,8 @@ task.spawn(JailHudController.init)
 task.spawn(CashHudController.init)
 task.spawn(DealershipController.init)
 task.spawn(RobberyHudController.init)
+task.spawn(WorldMarkerController.init)
+task.spawn(OnboardingTipController.init)
 
 VehicleInputController.ExitRequested:Connect(VehicleController.requestExit)
 VehicleInputController.SpawnRequested:Connect(function()
```
