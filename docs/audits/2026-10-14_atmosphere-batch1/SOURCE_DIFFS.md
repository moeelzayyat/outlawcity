# Source diffs: 2026-10-14_atmosphere-batch1

Commit range `9b52d54..b3ebb00` (source). Studio matches `src/` for every changed script (hash-checked).

## `src/ReplicatedStorage/Shared/Atmosphere/AtmosphereRules.luau`

```diff
diff --git a/src/ReplicatedStorage/Shared/Atmosphere/AtmosphereRules.luau b/src/ReplicatedStorage/Shared/Atmosphere/AtmosphereRules.luau
new file mode 100644
index 0000000..e5ce662
--- /dev/null
+++ b/src/ReplicatedStorage/Shared/Atmosphere/AtmosphereRules.luau
@@ -0,0 +1,23 @@
+--!strict
+-- Pure helpers for atmosphere Batch 1 (unit-tested in ServerStorage.Tests.AtmosphereRules.spec).
+local AtmosphereRules = {}
+
+-- Which light bar side is lit at time `t` (seconds): 1 or 2, alternating every `interval`.
+function AtmosphereRules.flashPhase(t: number, interval: number): number
+	if not (interval > 0) or t ~= t then
+		return 1
+	end
+	return if math.floor(t / interval) % 2 == 0 then 1 else 2
+end
+
+-- The siren may play only with its flag on AND an approved sound id set.
+function AtmosphereRules.sirenEnabled(flags: { Siren: boolean }, soundId: string?): boolean
+	return flags.Siren == true and type(soundId) == "string" and soundId:match("^rbxassetid://%d+$") ~= nil
+end
+
+-- A model is the police unit we decorate (by name, inside the NPC vehicle folder).
+function AtmosphereRules.isPoliceUnit(name: string, parentName: string?, config: { PoliceFolderName: string, PoliceUnitName: string }): boolean
+	return name == config.PoliceUnitName and parentName == config.PoliceFolderName
+end
+
+return AtmosphereRules
```

## `src/ReplicatedStorage/Shared/Config/AtmosphereConfig.luau`

```diff
diff --git a/src/ReplicatedStorage/Shared/Config/AtmosphereConfig.luau b/src/ReplicatedStorage/Shared/Config/AtmosphereConfig.luau
new file mode 100644
index 0000000..d55ac77
--- /dev/null
+++ b/src/ReplicatedStorage/Shared/Config/AtmosphereConfig.luau
@@ -0,0 +1,57 @@
+--!strict
+-- City atmosphere Batch 1 (docs/CITY_ATMOSPHERE_AUDIO_AUDIT.md: P-A, P-C, P-F). Presentation only:
+-- applied on each client, never on the server, so the place's own Lighting stays as it was and
+-- turning a flag off restores the old look on the next join. Each flag works on its own.
+local AtmosphereConfig = {
+	Flags = {
+		Lighting = true, -- P-A lighting preset
+		PoliceLights = true, -- P-C flashing light bar + one flashing light on the police unit
+		Siren = false, -- P-C siren: stays off until the owner approves an exact sound asset id
+	},
+	SirenSoundId = nil :: string?, -- e.g. "rbxassetid://<approved id>"; required for the siren to play
+
+	-- P-A: values applied to Lighting on the client.
+	Lighting = {
+		ClockTime = 16.5,
+		Ambient = Color3.fromRGB(80, 80, 90),
+		OutdoorAmbient = Color3.fromRGB(120, 115, 110),
+		AtmosphereDensity = 0.32,
+		AtmosphereHaze = 1,
+		AtmosphereGlare = 0.2,
+		BloomIntensity = 0.4,
+		ColorCorrectionContrast = 0.08,
+		ColorCorrectionSaturation = 0.12,
+	},
+	-- The place's values before Batch 1 (measured 2026-10-14), kept for the record and rollback.
+	OriginalLighting = {
+		ClockTime = 14.5,
+		Ambient = Color3.fromRGB(70, 70, 70),
+		OutdoorAmbient = Color3.fromRGB(70, 70, 70),
+		AtmosphereDensity = 0.30,
+		AtmosphereHaze = 0,
+		AtmosphereGlare = 0,
+		BloomIntensity = 1,
+	},
+
+	-- P-C
+	PoliceFolderName = "NpcVehicles",
+	PoliceUnitName = "PoliceUnit",
+	FlashInterval = 0.25, -- seconds per red/blue phase
+	DimTransparency = 0.65, -- the light bar half that is "off" in a phase
+	PoliceLightRange = 14,
+	PoliceLightBrightness = 2,
+	SirenRollOffMaxDistance = 250,
+	SirenVolume = 0.6,
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
+deepFreeze(AtmosphereConfig)
+
+return AtmosphereConfig
```

## `src/ServerStorage/Tests/AtmosphereRules.spec.luau`

```diff
diff --git a/src/ServerStorage/Tests/AtmosphereRules.spec.luau b/src/ServerStorage/Tests/AtmosphereRules.spec.luau
new file mode 100644
index 0000000..c923fbe
--- /dev/null
+++ b/src/ServerStorage/Tests/AtmosphereRules.spec.luau
@@ -0,0 +1,53 @@
+-- City atmosphere Batch 1: config values and pure helpers.
+local ReplicatedStorage = game:GetService("ReplicatedStorage")
+local AtmosphereConfig = require(ReplicatedStorage.Shared.Config.AtmosphereConfig)
+local AtmosphereRules = require(ReplicatedStorage.Shared.Atmosphere.AtmosphereRules)
+local Assert = require(script.Parent.Assert)
+
+local C = AtmosphereConfig
+
+return {
+	["P-A lighting values match the approved plan"] = function()
+		local L = C.Lighting
+		Assert.equal(L.ClockTime, 16.5)
+		Assert.equal(L.Ambient, Color3.fromRGB(80, 80, 90))
+		Assert.equal(L.OutdoorAmbient, Color3.fromRGB(120, 115, 110))
+		Assert.equal(L.AtmosphereDensity, 0.32)
+		Assert.equal(L.AtmosphereHaze, 1)
+		Assert.equal(L.AtmosphereGlare, 0.2)
+		Assert.equal(L.BloomIntensity, 0.4)
+		Assert.equal(L.ColorCorrectionContrast, 0.08)
+		Assert.equal(L.ColorCorrectionSaturation, 0.12)
+		Assert.equal(C.OriginalLighting.ClockTime, 14.5, "original values kept for rollback")
+		Assert.equal(C.OriginalLighting.BloomIntensity, 1)
+	end,
+	["flags are separate; the siren is off until an asset is approved"] = function()
+		Assert.equal(type(C.Flags.Lighting), "boolean")
+		Assert.equal(type(C.Flags.PoliceLights), "boolean")
+		Assert.equal(C.Flags.Siren, false)
+		Assert.equal(C.SirenSoundId, nil)
+		Assert.equal(AtmosphereRules.sirenEnabled(C.Flags, C.SirenSoundId), false)
+		Assert.equal(AtmosphereRules.sirenEnabled({ Siren = true }, nil), false, "flag alone is not enough")
+		Assert.equal(AtmosphereRules.sirenEnabled({ Siren = false }, "rbxassetid://123"), false, "id alone is not enough")
+		Assert.equal(AtmosphereRules.sirenEnabled({ Siren = true }, "rbxassetid://123"), true)
+		Assert.equal(AtmosphereRules.sirenEnabled({ Siren = true }, "http://example.com/x"), false, "only Roblox asset ids")
+	end,
+	["police lights alternate about every 0.25 s"] = function()
+		Assert.equal(C.FlashInterval, 0.25)
+		Assert.equal(AtmosphereRules.flashPhase(0, 0.25), 1)
+		Assert.equal(AtmosphereRules.flashPhase(0.24, 0.25), 1)
+		Assert.equal(AtmosphereRules.flashPhase(0.25, 0.25), 2)
+		Assert.equal(AtmosphereRules.flashPhase(0.5, 0.25), 1)
+		Assert.equal(AtmosphereRules.flashPhase(1, 0), 1, "bad interval never errors")
+		Assert.equal(AtmosphereRules.flashPhase(0 / 0, 0.25), 1)
+	end,
+	["only the NPC police unit is decorated"] = function()
+		Assert.equal(AtmosphereRules.isPoliceUnit("PoliceUnit", "NpcVehicles", C), true)
+		Assert.equal(AtmosphereRules.isPoliceUnit("PoliceUnit", "Vehicles", C), false, "never a player's car")
+		Assert.equal(AtmosphereRules.isPoliceUnit("Coupe_1", "NpcVehicles", C), false)
+	end,
+	["mobile guardrails: one light, no shadows budget, bounded siren"] = function()
+		Assert.truthy(C.PoliceLightRange <= 16, "small light range")
+		Assert.truthy(C.SirenRollOffMaxDistance <= 300, "siren fades with distance")
+	end,
+}
```

## `src/StarterPlayer/StarterPlayerScripts/Client/Controllers/AtmosphereController.luau`

```diff
diff --git a/src/StarterPlayer/StarterPlayerScripts/Client/Controllers/AtmosphereController.luau b/src/StarterPlayer/StarterPlayerScripts/Client/Controllers/AtmosphereController.luau
new file mode 100644
index 0000000..419c69a
--- /dev/null
+++ b/src/StarterPlayer/StarterPlayerScripts/Client/Controllers/AtmosphereController.luau
@@ -0,0 +1,188 @@
+--!strict
+-- City atmosphere Batch 1, client-side presentation only (docs/CITY_ATMOSPHERE_AUDIO_AUDIT.md).
+--  * Lighting (P-A): applies the AtmosphereConfig preset to this client's Lighting. The place's
+--    own values are untouched, so turning the flag off restores the old look.
+--  * PoliceLights (P-C): while the NPC police unit exists, its two LightBar parts flash red/blue
+--    and one local PointLight flashes with them. Everything created here is local and removed
+--    when the unit goes away. The unit itself (server-owned, its AI and pursuit) is not touched.
+--  * Siren (P-C): only with its flag on and an owner-approved sound id.
+local Lighting = game:GetService("Lighting")
+local ReplicatedStorage = game:GetService("ReplicatedStorage")
+local RunService = game:GetService("RunService")
+local Workspace = game:GetService("Workspace")
+
+local Shared = ReplicatedStorage.Shared
+local AtmosphereConfig = require(Shared.Config.AtmosphereConfig)
+local AtmosphereRules = require(Shared.Atmosphere.AtmosphereRules)
+
+local AtmosphereController = {}
+
+local config = AtmosphereConfig
+local LOCAL_TAG = "OutlawAtmosphere" -- name of every instance this controller creates
+
+type Decorated = { Model: Model, Bars: { BasePart }, Light: PointLight?, Siren: Sound?, Connections: { RBXScriptConnection } }
+local decorated: { [Model]: Decorated } = {}
+
+local function applyLighting()
+	local preset = config.Lighting
+	Lighting.ClockTime = preset.ClockTime
+	Lighting.Ambient = preset.Ambient
+	Lighting.OutdoorAmbient = preset.OutdoorAmbient
+	local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
+	if atmosphere then
+		atmosphere.Density = preset.AtmosphereDensity
+		atmosphere.Haze = preset.AtmosphereHaze
+		atmosphere.Glare = preset.AtmosphereGlare
+	end
+	local bloom = Lighting:FindFirstChildOfClass("BloomEffect")
+	if bloom then
+		bloom.Intensity = preset.BloomIntensity
+	end
+	local correction = Lighting:FindFirstChild(LOCAL_TAG)
+	if not correction then
+		correction = Instance.new("ColorCorrectionEffect")
+		correction.Name = LOCAL_TAG
+		correction.Parent = Lighting
+	end
+	(correction :: ColorCorrectionEffect).Contrast = preset.ColorCorrectionContrast;
+	(correction :: ColorCorrectionEffect).Saturation = preset.ColorCorrectionSaturation
+end
+
+local function lightBars(model: Model): { BasePart }
+	local bars = {}
+	for _, d in model:GetDescendants() do
+		if d.Name == "LightBar" and d:IsA("BasePart") then
+			table.insert(bars, d)
+		end
+	end
+	-- Stable order (left, right) so the two halves alternate.
+	table.sort(bars, function(a, b)
+		local chassis = model.PrimaryPart
+		if not chassis then
+			return a:GetFullName() < b:GetFullName()
+		end
+		return chassis.CFrame:PointToObjectSpace(a.Position).X < chassis.CFrame:PointToObjectSpace(b.Position).X
+	end)
+	return bars
+end
+
+local function undecorate(model: Model)
+	local entry = decorated[model]
+	if not entry then
+		return
+	end
+	decorated[model] = nil
+	for _, connection in entry.Connections do
+		connection:Disconnect()
+	end
+	if entry.Light then
+		entry.Light:Destroy()
+	end
+	if entry.Siren then
+		entry.Siren:Stop()
+		entry.Siren:Destroy()
+	end
+	for _, bar in entry.Bars do
+		if bar.Parent then
+			bar.LocalTransparencyModifier = 0
+		end
+	end
+end
+
+local function decorate(model: Model)
+	if decorated[model] then
+		return -- never twice: no duplicate lights or sounds
+	end
+	local entry: Decorated = { Model = model, Bars = {}, Light = nil, Siren = nil, Connections = {} }
+	decorated[model] = entry
+	local function refreshBars()
+		entry.Bars = lightBars(model)
+		if config.Flags.PoliceLights and not entry.Light and #entry.Bars > 0 then
+			local light = Instance.new("PointLight")
+			light.Name = LOCAL_TAG
+			light.Range = config.PoliceLightRange
+			light.Brightness = config.PoliceLightBrightness
+			light.Shadows = false
+			light.Parent = entry.Bars[1]
+			entry.Light = light
+		end
+		local chassis = model.PrimaryPart
+		if AtmosphereRules.sirenEnabled(config.Flags, config.SirenSoundId) and not entry.Siren and chassis then
+			local siren = Instance.new("Sound")
+			siren.Name = LOCAL_TAG
+			siren.SoundId = config.SirenSoundId :: string
+			siren.Looped = true
+			siren.Volume = config.SirenVolume
+			siren.RollOffMode = Enum.RollOffMode.InverseTapered
+			siren.RollOffMaxDistance = config.SirenRollOffMaxDistance
+			siren.Parent = chassis
+			siren:Play()
+			entry.Siren = siren
+		end
+	end
+	refreshBars()
+	-- With streaming, parts can arrive after the model; pick them up when they do.
+	table.insert(entry.Connections, model.DescendantAdded:Connect(function(d)
+		if d.Name == "LightBar" or d == model.PrimaryPart then
+			refreshBars()
+		end
+	end))
+	table.insert(entry.Connections, model.AncestryChanged:Connect(function()
+		if not model:IsDescendantOf(Workspace) then
+			undecorate(model)
+		end
+	end))
+end
+
+local function onFlashStep()
+	if not config.Flags.PoliceLights then
+		return
+	end
+	local phase = AtmosphereRules.flashPhase(os.clock(), config.FlashInterval)
+	for model, entry in decorated do
+		if not model.Parent then
+			undecorate(model)
+			continue
+		end
+		for index, bar in entry.Bars do
+			bar.LocalTransparencyModifier = if index == phase then 0 else config.DimTransparency
+		end
+		local lit = entry.Bars[phase]
+		if entry.Light and lit then
+			entry.Light.Color = lit.Color
+			if entry.Light.Parent ~= lit then
+				entry.Light.Parent = lit
+			end
+		end
+	end
+end
+
+function AtmosphereController.init()
+	if config.Flags.Lighting then
+		applyLighting()
+	end
+	if not (config.Flags.PoliceLights or AtmosphereRules.sirenEnabled(config.Flags, config.SirenSoundId)) then
+		return
+	end
+	local folder = Workspace:WaitForChild(config.PoliceFolderName, 30)
+	if not folder then
+		return
+	end
+	local function consider(child: Instance)
+		if child:IsA("Model") and AtmosphereRules.isPoliceUnit(child.Name, folder.Name, config) then
+			decorate(child)
+		end
+	end
+	folder.ChildAdded:Connect(consider)
+	folder.ChildRemoved:Connect(function(child)
+		if child:IsA("Model") then
+			undecorate(child)
+		end
+	end)
+	for _, child in folder:GetChildren() do
+		consider(child)
+	end
+	RunService.Heartbeat:Connect(onFlashStep)
+end
+
+return AtmosphereController
```

## `src/StarterPlayer/StarterPlayerScripts/Client/Main.client.luau`

```diff
diff --git a/src/StarterPlayer/StarterPlayerScripts/Client/Main.client.luau b/src/StarterPlayer/StarterPlayerScripts/Client/Main.client.luau
index 471def1..efdcb82 100644
--- a/src/StarterPlayer/StarterPlayerScripts/Client/Main.client.luau
+++ b/src/StarterPlayer/StarterPlayerScripts/Client/Main.client.luau
@@ -19,6 +19,7 @@ local DealershipController = require(Controllers.DealershipController)
 local RobberyHudController = require(Controllers.RobberyHudController)
 local WorldMarkerController = require(Controllers.WorldMarkerController)
 local OnboardingTipController = require(Controllers.OnboardingTipController)
+local AtmosphereController = require(Controllers.AtmosphereController)
 
 VehicleInputController.init()
 VehicleController.init()
@@ -35,6 +36,7 @@ task.spawn(DealershipController.init)
 task.spawn(RobberyHudController.init)
 task.spawn(WorldMarkerController.init)
 task.spawn(OnboardingTipController.init)
+task.spawn(AtmosphereController.init)
 
 VehicleInputController.ExitRequested:Connect(VehicleController.requestExit)
 VehicleInputController.SpawnRequested:Connect(function()
```
