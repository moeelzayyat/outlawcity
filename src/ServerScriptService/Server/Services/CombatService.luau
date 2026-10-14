--!strict
-- Server authority for Peaceful / Combat status and for every harm decision.
-- Publishes CombatStatus and CombatCooldownUntil as Player attributes; handles the
-- rate-limited RequestSetCombatStatus remote. No weapons or damage exist yet: future damage
-- code must ask CombatService.canPlayerHarm / CombatRules.canHarm before applying anything.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local Types = require(Shared.Types)
local Remotes = require(Shared.Net.Remotes)
local CombatConfig = require(Shared.Config.CombatConfig)
local CombatRules = require(Shared.Combat.CombatRules)
local CombatStatusRules = require(Shared.Combat.CombatStatusRules)
local PlayerAttributes = require(Shared.Player.PlayerAttributes)
local RateLimiter = require(script.Parent.Parent.Util.RateLimiter)
local WantedService = require(script.Parent.WantedService)
local JailService = require(script.Parent.JailService)

local CombatService = {}

local states: { [Player]: CombatStatusRules.State } = {}
local requestLimiter = RateLimiter.new(CombatConfig.RequestInterval)

local function now(): number
	return Workspace:GetServerTimeNow()
end

local function publish(player: Player, state: CombatStatusRules.State)
	player:SetAttribute(PlayerAttributes.CombatStatus, state.Status)
	player:SetAttribute(PlayerAttributes.CombatCooldownUntil, if state.CombatCooldownUntil == -math.huge then 0 else state.CombatCooldownUntil)
end

-- Validates and applies a status change. Returns (accepted, error, secondsUntilPeacefulAllowed).
function CombatService.requestStatus(player: Player, target: unknown): (boolean, Types.CombatSwitchError?, number)
	local state = states[player]
	if not state then
		return false, "NotInGame", 0
	end
	if not JailService.allows(player, "Combat") then
		return false, "Jailed", 0
	end
	local t = now()
	local ok, err = CombatStatusRules.requestSwitch(state, target, t, WantedService.getStars(player) > 0, CombatConfig)
	if ok then
		publish(player, state)
	end
	return ok, err, CombatStatusRules.secondsUntilPeacefulAllowed(state, t)
end

function CombatService.getStatus(player: Player): Types.CombatStatus
	local state = states[player]
	return if state then state.Status else "Peaceful"
end

-- Builds the plain combatant view CombatRules expects.
function CombatService.getCombatant(player: Player): Types.Combatant
	local spawnUntil = player:GetAttribute(PlayerAttributes.SpawnProtectedUntil)
	return {
		Kind = "Player",
		UserId = player.UserId,
		Status = CombatService.getStatus(player),
		WantedStars = WantedService.getStars(player),
		InSafeZone = player:GetAttribute(PlayerAttributes.InSafeZone) == true,
		SpawnProtectedUntil = if type(spawnUntil) == "number" then spawnUntil else 0,
		Jailed = JailService.isJailed(player),
	}
end

-- The entry point future PvP damage must use.
function CombatService.canPlayerHarm(attacker: Player, victim: Player): (boolean, Types.HarmDenial?)
	return CombatRules.canHarm(CombatService.getCombatant(attacker), CombatService.getCombatant(victim), { Now = now(), Action = "Attack" })
end

-- The entry point NPC police (3D) must use before busting.
function CombatService.canPoliceBust(victim: Player): (boolean, Types.HarmDenial?)
	local police: Types.Combatant = { Kind = "NpcPolice", WantedStars = 0, InSafeZone = false, SpawnProtectedUntil = 0 }
	return CombatRules.canHarm(police, CombatService.getCombatant(victim), { Now = now(), Action = "Bust" })
end

-- Future damage code calls this for attacker and victim to keep them in Combat for the cooldown.
function CombatService.noteCombatActivity(player: Player)
	local state = states[player]
	if state then
		CombatStatusRules.noteCombatActivity(state, now(), CombatConfig)
		publish(player, state)
	end
end

local function onPlayerAdded(player: Player)
	local state = CombatStatusRules.new()
	states[player] = state
	publish(player, state)
end

function CombatService.init()
	Remotes.getFunction("RequestSetCombatStatus").OnServerInvoke = function(player: Player, target: unknown)
		if not requestLimiter:tryConsume(player.UserId) then
			return false, "RateLimited", 0
		end
		if type(target) ~= "string" or #target > 16 then
			return false, "InvalidStatus", 0
		end
		return CombatService.requestStatus(player, target)
	end
end

function CombatService.start()
	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in Players:GetPlayers() do
		if not states[player] then
			onPlayerAdded(player)
		end
	end
	Players.PlayerRemoving:Connect(function(player)
		states[player] = nil
		requestLimiter:reset(player.UserId)
	end)
end

return CombatService
