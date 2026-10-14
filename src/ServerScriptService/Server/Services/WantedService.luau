--!strict
-- Server authority for wanted levels. Owns one WantedRules state per player, publishes
-- WantedLevel / WantedHeat / WantedEvading / CriminalReputation as Player attributes and
-- tells the player's client when evading starts and when they escape.
-- Crime detection lives elsewhere and calls WantedService.reportCrime. No client request
-- can change wanted state or reputation (Studio-only dev tools excepted).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local Types = require(Shared.Types)
local Remotes = require(Shared.Net.Remotes)
local WantedConfig = require(Shared.Config.WantedConfig)
local WantedRules = require(Shared.Wanted.WantedRules)
local PlayerAttributes = require(Shared.Player.PlayerAttributes)
local Signal = require(Shared.Util.Signal)

local WantedService = {}

-- Fired (player, fromStars) when a wanted episode ends by escaping (heat decayed to zero).
-- Never fired for busts or resets.
WantedService.Escaped = Signal.new()

local STEP_INTERVAL = 0.25

local states: { [Player]: Types.WantedState } = {}
local devPoliceSight: { [Player]: boolean } = {}
local policeSightProvider: (Player) -> boolean = function()
	return false
end
local noticeRemote: RemoteEvent

local function now(): number
	return Workspace:GetServerTimeNow()
end

local function publish(player: Player, state: Types.WantedState)
	player:SetAttribute(PlayerAttributes.WantedLevel, state.Stars)
	player:SetAttribute(PlayerAttributes.WantedHeat, math.floor(state.Heat * 10 + 0.5) / 10)
	player:SetAttribute(PlayerAttributes.WantedEvading, state.Evading)
end

local function notify(player: Player, kind: Types.WantedNoticeKind, payload: { [string]: any })
	noticeRemote:FireClient(player, kind, payload)
end

local function addReputation(player: Player, amount: number)
	if amount <= 0 then
		return
	end
	local current = player:GetAttribute(PlayerAttributes.CriminalReputation)
	player:SetAttribute(PlayerAttributes.CriminalReputation, (if type(current) == "number" then current else 0) + amount)
end

local function isSeenByPolice(player: Player): boolean
	if devPoliceSight[player] then
		return true
	end
	local ok, seen = pcall(policeSightProvider, player)
	return ok and seen == true
end

local function step(dt: number)
	local t = now()
	for player, state in states do
		local before = state.Heat
		local result = WantedRules.step(state, t, dt, isSeenByPolice(player), WantedConfig)
		if result.EvadingStarted then
			notify(player, "Evading", { Stars = result.EvadingStars })
		end
		if result.Escaped then
			addReputation(player, result.Reputation)
			notify(player, "Escaped", { FromStars = result.EscapedFromStars, Reputation = result.Reputation })
			WantedService.Escaped:Fire(player, result.EscapedFromStars)
		end
		if state.Heat ~= before or result.EvadingStarted or player:GetAttribute(PlayerAttributes.WantedEvading) ~= state.Evading then
			publish(player, state)
		end
	end
end

-- The single entry point for crimes. Detectors (police sightings, collisions, future robberies)
-- call this; it never trusts client input. Returns (accepted, error).
function WantedService.reportCrime(player: Player, crimeType: string): (boolean, Types.CrimeError?)
	local state = states[player]
	if not state or player.Parent ~= Players then
		return false, "NotInGame"
	end
	local ok, err = WantedRules.applyCrime(state, crimeType, now(), WantedConfig)
	if ok then
		publish(player, state)
	end
	return ok, err
end

-- Clears the wanted level with no reward (busted, admin).
function WantedService.resetWanted(player: Player)
	local state = states[player]
	if state then
		WantedRules.reset(state)
		publish(player, state)
	end
end

-- Police bust: clears the wanted level with no reward and tells the player.
function WantedService.bust(player: Player)
	local state = states[player]
	if state then
		local stars = state.Stars
		WantedRules.reset(state)
		publish(player, state)
		notify(player, "Busted", { Stars = stars })
	end
end

function WantedService.getStars(player: Player): number
	local state = states[player]
	return if state then state.Stars else 0
end

-- NPC police (3D) plug in here: provider(player) returns true while any unit can see them.
function WantedService.setPoliceSightProvider(provider: (Player) -> boolean)
	policeSightProvider = provider
end

-- Studio-only test hooks used by DevToolsService.
function WantedService.setHeatForTesting(player: Player, heat: number): boolean
	assert(RunService:IsStudio(), "setHeatForTesting is Studio-only")
	local state = states[player]
	if not state then
		return false
	end
	local ok = WantedRules.setHeat(state, heat, now(), WantedConfig)
	if ok then
		publish(player, state)
	end
	return ok
end

function WantedService.setPoliceSightForTesting(player: Player, seen: boolean)
	assert(RunService:IsStudio(), "setPoliceSightForTesting is Studio-only")
	devPoliceSight[player] = seen or nil
end

local function onPlayerAdded(player: Player)
	local state = WantedRules.new()
	states[player] = state
	if player:GetAttribute(PlayerAttributes.CriminalReputation) == nil then
		player:SetAttribute(PlayerAttributes.CriminalReputation, 0)
	end
	publish(player, state)
end

function WantedService.init()
	noticeRemote = Remotes.getEvent("OnWantedNotice")
end

function WantedService.start()
	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in Players:GetPlayers() do
		if not states[player] then
			onPlayerAdded(player)
		end
	end
	Players.PlayerRemoving:Connect(function(player)
		states[player] = nil
		devPoliceSight[player] = nil
	end)
	task.spawn(function()
		while true do
			step(task.wait(STEP_INTERVAL))
		end
	end)
end

return WantedService
