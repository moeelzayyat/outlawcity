--!strict
-- City atmosphere Batch 1, client-side presentation only (docs/CITY_ATMOSPHERE_AUDIO_AUDIT.md).
--  * Lighting (P-A): applies the AtmosphereConfig preset to this client's Lighting. The place's
--    own values are untouched, so turning the flag off restores the old look.
--  * PoliceLights (P-C): while the NPC police unit exists, its LightBar parts flash red/blue and
--    one local PointLight flashes with them. Everything created here is local and removed when
--    the unit goes away. The unit itself (server-owned, its AI and pursuit) is not touched.
--    Bars can stream out and back in on their own while the unit stays: the live bar list is
--    rebuilt from what is actually inside the model, a departing bar gets its local modifier
--    reset and never stays a flashing target, and the single light moves (or waits unparented)
--    instead of being duplicated.
--  * Siren (P-C): only with its flag on and an owner-approved sound id.
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local AtmosphereConfig = require(Shared.Config.AtmosphereConfig)
local AtmosphereRules = require(Shared.Atmosphere.AtmosphereRules)

local AtmosphereController = {}

local config = AtmosphereConfig
local LOCAL_TAG = "OutlawAtmosphere" -- name of every instance this controller creates
local DEBUG_ATTRIBUTE = "AtmosphereDebug" -- Studio only: live counts for tests

type Decorated = {
	Model: Model,
	Bars: { BasePart },
	Light: PointLight?,
	Siren: Sound?,
	Connections: { RBXScriptConnection },
}
local decorated: { [Model]: Decorated } = {}

local function applyLighting()
	local preset = config.Lighting
	Lighting.ClockTime = preset.ClockTime
	Lighting.Ambient = preset.Ambient
	Lighting.OutdoorAmbient = preset.OutdoorAmbient
	local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
	if atmosphere then
		atmosphere.Density = preset.AtmosphereDensity
		atmosphere.Haze = preset.AtmosphereHaze
		atmosphere.Glare = preset.AtmosphereGlare
	end
	local bloom = Lighting:FindFirstChildOfClass("BloomEffect")
	if bloom then
		bloom.Intensity = preset.BloomIntensity
	end
	local correction = Lighting:FindFirstChild(LOCAL_TAG)
	if not correction then
		correction = Instance.new("ColorCorrectionEffect")
		correction.Name = LOCAL_TAG
		correction.Parent = Lighting
	end
	(correction :: ColorCorrectionEffect).Contrast = preset.ColorCorrectionContrast;
	(correction :: ColorCorrectionEffect).Saturation = preset.ColorCorrectionSaturation
end

local function publishDebug()
	if not RunService:IsStudio() then
		return
	end
	local units, bars, lights, connections, sirens = 0, 0, 0, 0, 0
	for _, entry in decorated do
		units += 1
		bars += #entry.Bars
		lights += if entry.Light and entry.Light.Parent then 1 else 0
		connections += #entry.Connections
		sirens += if entry.Siren then 1 else 0
	end
	local player = Players.LocalPlayer
	if player then
		player:SetAttribute(DEBUG_ATTRIBUTE, `units={units} bars={bars} lights={lights} connections={connections} sirens={sirens}`)
	end
end

-- The LightBar parts currently inside the model (optionally ignoring one that is leaving), in a
-- stable left-to-right order so the halves alternate.
local function liveBars(model: Model, leaving: Instance?): { BasePart }
	local bars = {}
	for _, d in model:GetDescendants() do
		if d ~= leaving and d.Name == "LightBar" and d:IsA("BasePart") then
			table.insert(bars, d)
		end
	end
	local chassis = model.PrimaryPart
	table.sort(bars, function(a, b)
		if chassis and chassis ~= leaving then
			return chassis.CFrame:PointToObjectSpace(a.Position).X < chassis.CFrame:PointToObjectSpace(b.Position).X
		end
		return a:GetFullName() < b:GetFullName()
	end)
	return bars
end

-- Keeps the one local light attached to a live bar, unparented while there is none, and makes
-- a new one only if the old one was destroyed (it is never duplicated).
local function placeLight(entry: Decorated)
	if not config.Flags.PoliceLights then
		return
	end
	local target = entry.Bars[1]
	local light = entry.Light
	if not target then
		if light then
			light.Parent = nil
		end
		return
	end
	if not light then
		local created = Instance.new("PointLight")
		created.Name = LOCAL_TAG
		created.Range = config.PoliceLightRange
		created.Brightness = config.PoliceLightBrightness
		created.Shadows = false
		created.Destroying:Connect(function()
			if entry.Light == created then
				entry.Light = nil
			end
		end)
		entry.Light = created
		light = created
	end
	if light and not table.find(entry.Bars, light.Parent :: any) then
		light.Parent = target
	end
end

local function rebuild(entry: Decorated, leaving: Instance?)
	entry.Bars = liveBars(entry.Model, leaving)
	placeLight(entry)
	local chassis = entry.Model.PrimaryPart
	if chassis == leaving then
		chassis = nil
	end
	if AtmosphereRules.sirenEnabled(config.Flags, config.SirenSoundId) then
		if entry.Siren and chassis and entry.Siren.Parent ~= chassis then
			entry.Siren.Parent = chassis
		elseif not entry.Siren and chassis then
			local siren = Instance.new("Sound")
			siren.Name = LOCAL_TAG
			siren.SoundId = config.SirenSoundId :: string
			siren.Looped = true
			siren.Volume = config.SirenVolume
			siren.RollOffMode = Enum.RollOffMode.InverseTapered
			siren.RollOffMaxDistance = config.SirenRollOffMaxDistance
			siren.Parent = chassis
			siren:Play()
			entry.Siren = siren
		end
	end
	publishDebug()
end

local function undecorate(model: Model)
	local entry = decorated[model]
	if not entry then
		return
	end
	decorated[model] = nil
	for _, connection in entry.Connections do
		connection:Disconnect()
	end
	table.clear(entry.Connections)
	if entry.Light then
		entry.Light:Destroy()
		entry.Light = nil
	end
	if entry.Siren then
		entry.Siren:Stop()
		entry.Siren:Destroy()
		entry.Siren = nil
	end
	for _, bar in entry.Bars do
		bar.LocalTransparencyModifier = 0
	end
	table.clear(entry.Bars)
	publishDebug()
end

local function decorate(model: Model)
	if decorated[model] then
		return -- never twice: no duplicate lights or sounds
	end
	local entry: Decorated = { Model = model, Bars = {}, Light = nil, Siren = nil, Connections = {} }
	decorated[model] = entry
	rebuild(entry, nil)
	-- With streaming, parts arrive and leave on their own while the model stays.
	table.insert(entry.Connections, model.DescendantAdded:Connect(function(d)
		if d.Name == "LightBar" or d == model.PrimaryPart then
			rebuild(entry, nil)
		end
	end))
	table.insert(entry.Connections, model.DescendantRemoving:Connect(function(d)
		if d.Name == "LightBar" and d:IsA("BasePart") then
			d.LocalTransparencyModifier = 0 -- the departing bar keeps no local dimming
			if entry.Light and entry.Light.Parent == d then
				entry.Light.Parent = nil -- keep the light, don't let it leave with the bar
			end
			rebuild(entry, d)
		elseif d == model.PrimaryPart then
			if entry.Siren and entry.Siren.Parent == d then
				entry.Siren.Parent = nil
			end
			rebuild(entry, d)
		end
	end))
	table.insert(entry.Connections, model.AncestryChanged:Connect(function()
		if not model:IsDescendantOf(Workspace) then
			undecorate(model)
		end
	end))
	publishDebug()
end

local function onFlashStep()
	if not config.Flags.PoliceLights then
		return
	end
	local phase = AtmosphereRules.flashPhase(os.clock(), config.FlashInterval)
	for model, entry in decorated do
		if not model.Parent then
			undecorate(model)
			continue
		end
		local litIndex = AtmosphereRules.litIndex(phase, #entry.Bars)
		for index, bar in entry.Bars do
			bar.LocalTransparencyModifier = if index == litIndex then 0 else config.DimTransparency
		end
		local light = entry.Light
		if light then
			local lit = if litIndex then entry.Bars[litIndex] else nil
			light.Enabled = lit ~= nil
			if lit then
				light.Color = lit.Color
				if light.Parent ~= lit then
					light.Parent = lit
				end
			end
		end
	end
end

function AtmosphereController.init()
	if config.Flags.Lighting then
		applyLighting()
	end
	if not (config.Flags.PoliceLights or AtmosphereRules.sirenEnabled(config.Flags, config.SirenSoundId)) then
		return
	end
	local folder = Workspace:WaitForChild(config.PoliceFolderName, 30)
	if not folder then
		return
	end
	local function consider(child: Instance)
		if child:IsA("Model") and AtmosphereRules.isPoliceUnit(child.Name, folder.Name, config) then
			decorate(child)
		end
	end
	folder.ChildAdded:Connect(consider)
	folder.ChildRemoved:Connect(function(child)
		if child:IsA("Model") then
			undecorate(child)
		end
	end)
	for _, child in folder:GetChildren() do
		consider(child)
	end
	RunService.Heartbeat:Connect(onFlashStep)
end

return AtmosphereController
