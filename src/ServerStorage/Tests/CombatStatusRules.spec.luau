local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CombatStatusRules = require(ReplicatedStorage.Shared.Combat.CombatStatusRules)
local CombatConfig = require(ReplicatedStorage.Shared.Config.CombatConfig)
local Remotes = require(ReplicatedStorage.Shared.Net.Remotes)
local Assert = require(script.Parent.Assert)

local C = CombatConfig

return {
	["new players start Peaceful"] = function()
		Assert.equal(CombatStatusRules.new().Status, "Peaceful")
	end,
	["cooldown is 30 seconds by default and configurable"] = function()
		Assert.equal(C.CombatCooldown, 30)
		local state = CombatStatusRules.new()
		CombatStatusRules.requestSwitch(state, "Combat", 0, false, { CombatCooldown = 5 })
		Assert.equal((CombatStatusRules.requestSwitch(state, "Peaceful", 5, false, { CombatCooldown = 5 })), true)
	end,
	["Combat can be enabled at any time, even while wanted"] = function()
		local state = CombatStatusRules.new()
		Assert.equal((CombatStatusRules.requestSwitch(state, "Combat", 0, true, C)), true)
		Assert.equal(state.Status, "Combat")
	end,
	["Peaceful is blocked during the combat cooldown"] = function()
		local state = CombatStatusRules.new()
		CombatStatusRules.requestSwitch(state, "Combat", 0, false, C)
		local ok, err = CombatStatusRules.requestSwitch(state, "Peaceful", C.CombatCooldown - 0.01, false, C)
		Assert.equal(ok, false)
		Assert.equal(err, "Cooldown")
		Assert.equal(state.Status, "Combat")
		Assert.near(CombatStatusRules.secondsUntilPeacefulAllowed(state, 10), C.CombatCooldown - 10, 1e-9)
		Assert.equal((CombatStatusRules.requestSwitch(state, "Peaceful", C.CombatCooldown, false, C)), true)
		Assert.equal(state.Status, "Peaceful")
	end,
	["Peaceful is blocked while wanted, even after the cooldown"] = function()
		local state = CombatStatusRules.new()
		CombatStatusRules.requestSwitch(state, "Combat", 0, false, C)
		local ok, err = CombatStatusRules.requestSwitch(state, "Peaceful", 999, true, C)
		Assert.equal(ok, false)
		Assert.equal(err, "Wanted")
		Assert.equal(state.Status, "Combat")
	end,
	["combat activity restarts the cooldown"] = function()
		local state = CombatStatusRules.new()
		CombatStatusRules.requestSwitch(state, "Combat", 0, false, C)
		CombatStatusRules.noteCombatActivity(state, 25, C)
		Assert.equal((CombatStatusRules.requestSwitch(state, "Peaceful", 31, false, C)), false)
		Assert.equal((CombatStatusRules.requestSwitch(state, "Peaceful", 25 + C.CombatCooldown, false, C)), true)
	end,
	["activity while Peaceful does not force Combat"] = function()
		local state = CombatStatusRules.new()
		CombatStatusRules.noteCombatActivity(state, 10, C)
		Assert.equal(state.Status, "Peaceful")
	end,
	["invalid and redundant requests are rejected without change"] = function()
		local state = CombatStatusRules.new()
		for _, bad in { "combat", "Admin", "", 1, true, {} } do
			local ok, err = CombatStatusRules.requestSwitch(state, bad, 0, false, C)
			Assert.equal(ok, false)
			Assert.equal(err, "InvalidStatus")
		end
		local ok, err = CombatStatusRules.requestSwitch(state, "Peaceful", 0, false, C)
		Assert.equal(ok, false)
		Assert.equal(err, "AlreadyInStatus")
		Assert.equal(state.Status, "Peaceful")
	end,
	["combat remote exists and switching rules never take a wanted level"] = function()
		Assert.equal(Remotes.Definitions.RequestSetCombatStatus, "RemoteFunction")
		-- requestSwitch only receives a read-only isWanted flag; it has no way to clear wanted.
		local state = CombatStatusRules.new()
		CombatStatusRules.requestSwitch(state, "Combat", 0, true, C)
		for key in state do
			Assert.truthy(key == "Status" or key == "CombatCooldownUntil", `unexpected state field {key}`)
		end
	end,
}
