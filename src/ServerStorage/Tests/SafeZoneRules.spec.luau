-- Safe-zone geometry and how zones combine with the combat rules (mock players).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local SafeZoneRules = require(ReplicatedStorage.Shared.Zones.SafeZoneRules)
local CombatRules = require(ReplicatedStorage.Shared.Combat.CombatRules)
local CombatStatusRules = require(ReplicatedStorage.Shared.Combat.CombatStatusRules)
local CombatConfig = require(ReplicatedStorage.Shared.Config.CombatConfig)
local WantedRules = require(ReplicatedStorage.Shared.Wanted.WantedRules)
local WantedConfig = require(ReplicatedStorage.Shared.Config.WantedConfig)
local CityLayout = require(ServerScriptService.Server.World.CityLayout)
local Assert = require(script.Parent.Assert)

local zones = CityLayout.safeZones()
local plaza = zones[1]
local INSIDE = Vector3.new(0, 3, 20)
local OUTSIDE = Vector3.new(200, 3, 200)
local NOW = 100

-- Builds a mock combatant whose InSafeZone comes from the real zone geometry.
local function at(userId: number, position: Vector3, overrides: { [string]: any }?)
	local c = {
		Kind = "Player",
		UserId = userId,
		Status = "Combat",
		WantedStars = 0,
		InSafeZone = SafeZoneRules.zoneAt(zones, position) ~= nil,
		SpawnProtectedUntil = 0,
	}
	for k, v in overrides or {} do
		c[k] = v
	end
	return c
end
local POLICE = { Kind = "NpcPolice", WantedStars = 0, InSafeZone = false, SpawnProtectedUntil = 0 }
local ATTACK = { Now = NOW, Action = "Attack" }

return {
	["the plaza is the first safe zone and matches the plaza block"] = function()
		Assert.equal(plaza.Name, "Plaza")
		local found = false
		for _, spec in CityLayout.createBlueprint().Parts do
			if spec.Group == "Plaza" then
				found = true
				Assert.near(plaza.Min.X, spec.Center.X - spec.Size.X / 2, 1e-6)
				Assert.near(plaza.Max.X, spec.Center.X + spec.Size.X / 2, 1e-6)
				Assert.near(plaza.Min.Z, spec.Center.Z - spec.Size.Z / 2, 1e-6)
				Assert.near(plaza.Max.Z, spec.Center.Z + spec.Size.Z / 2, 1e-6)
			end
		end
		Assert.truthy(found, "plaza part exists")
	end,
	["every civilian spawn is inside the safe zone"] = function()
		for _, spawn in CityLayout.createBlueprint().CivilianSpawns do
			Assert.truthy(SafeZoneRules.zoneAt(zones, spawn.CFrame.Position + Vector3.new(0, 3, 0)), `{spawn.Name} outside safe zone`)
		end
	end,
	["inside, outside, edges and height"] = function()
		Assert.equal(SafeZoneRules.zoneAt(zones, INSIDE), "Plaza")
		Assert.equal(SafeZoneRules.zoneAt(zones, OUTSIDE), nil)
		Assert.truthy(SafeZoneRules.contains(plaza, Vector3.new(plaza.Max.X, 3, 0)), "edge counts as inside")
		Assert.equal(SafeZoneRules.contains(plaza, Vector3.new(plaza.Max.X + 0.01, 3, 0)), false)
		Assert.equal(SafeZoneRules.contains(plaza, Vector3.new(0, plaza.Max.Y + 1, 0)), false)
	end,
	["hysteresis: enter at the edge, leave only beyond the margin"] = function()
		local justOutside = Vector3.new(plaza.Max.X + 1, 3, 0)
		Assert.equal((SafeZoneRules.update(false, zones, justOutside, 2)), false, "not entered from outside")
		Assert.equal((SafeZoneRules.update(true, zones, justOutside, 2)), true, "still inside within margin")
		Assert.equal((SafeZoneRules.update(true, zones, Vector3.new(plaza.Max.X + 3, 3, 0), 2)), false, "left beyond margin")
	end,
	["PvP is blocked when either side is in a safe zone, wanted or not"] = function()
		local ok1, why1 = CombatRules.canHarm(at(1, OUTSIDE), at(2, INSIDE), ATTACK)
		local ok2, why2 = CombatRules.canHarm(at(1, INSIDE), at(2, OUTSIDE), ATTACK)
		local ok3, why3 = CombatRules.canHarm(at(1, OUTSIDE), at(2, INSIDE, { WantedStars = 3 }), ATTACK)
		local ok4, why4 = CombatRules.canHarm(at(1, INSIDE), at(2, INSIDE, { WantedStars = 2, Status = "Peaceful" }), ATTACK)
		Assert.truthy(not ok1 and why1 == "SafeZone", "victim inside")
		Assert.truthy(not ok2 and why2 == "SafeZone", "attacker inside")
		Assert.truthy(not ok3 and why3 == "SafeZone", "wanted victim inside")
		Assert.truthy(not ok4 and why4 == "SafeZone", "both inside, wanted peaceful victim")
		Assert.equal((CombatRules.canHarm(at(1, OUTSIDE), at(2, OUTSIDE), ATTACK)), true, "both outside, both Combat")
	end,
	["combat status changes cannot bypass a safe zone"] = function()
		-- Whatever the attacker and victim switch to, an in-zone participant is never harmable.
		for _, attackerStatus in { "Peaceful", "Combat" } do
			for _, victimStatus in { "Peaceful", "Combat" } do
				local ok = CombatRules.canHarm(at(1, OUTSIDE, { Status = attackerStatus }), at(2, INSIDE, { Status = victimStatus, WantedStars = 1 }), ATTACK)
				Assert.equal(ok, false, `{attackerStatus} vs {victimStatus} in zone`)
			end
		end
		-- And being in a zone doesn't change the status rules: still no Peaceful during cooldown.
		local state = CombatStatusRules.new()
		CombatStatusRules.requestSwitch(state, "Combat", 0, false, CombatConfig)
		Assert.equal((CombatStatusRules.requestSwitch(state, "Peaceful", 5, false, CombatConfig)), false)
	end,
	["NPC police can still bust wanted players inside a safe zone"] = function()
		Assert.equal((CombatRules.canHarm(POLICE, at(2, INSIDE, { WantedStars = 1, Status = "Peaceful" }), { Now = NOW, Action = "Bust" })), true)
		Assert.equal((CombatRules.canHarm(POLICE, at(2, INSIDE, { WantedStars = 0 }), { Now = NOW, Action = "Bust" })), false)
	end,
	["safe zones have no say in wanted rules"] = function()
		-- The wanted engine has no zone input at all: same heat, decay and escape inside or out.
		local inside, outside = WantedRules.new(), WantedRules.new()
		WantedRules.setHeat(inside, 70, 0, WantedConfig)
		WantedRules.setHeat(outside, 70, 0, WantedConfig)
		for t = 0.25, 30, 0.25 do
			WantedRules.step(inside, t, 0.25, false, WantedConfig)
			WantedRules.step(outside, t, 0.25, false, WantedConfig)
		end
		Assert.equal(inside.Heat, outside.Heat)
	end,
}
