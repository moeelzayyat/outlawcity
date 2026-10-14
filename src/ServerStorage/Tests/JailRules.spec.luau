-- Short jail rules (pure) and how jail interacts with the combat gate.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local JailRules = require(ReplicatedStorage.Shared.Jail.JailRules)
local JailConfig = require(ReplicatedStorage.Shared.Config.JailConfig)
local CombatRules = require(ReplicatedStorage.Shared.Combat.CombatRules)
local Remotes = require(ReplicatedStorage.Shared.Net.Remotes)
local CityLayout = require(ServerScriptService.Server.World.CityLayout)
local Assert = require(script.Parent.Assert)

local SECONDS = JailRules.clampSeconds(JailConfig.Seconds, JailConfig)

return {
	["sentence is 12 s by default and always within 10-15 s"] = function()
		Assert.equal(SECONDS, 12)
		Assert.equal(JailRules.clampSeconds(3, JailConfig), 10)
		Assert.equal(JailRules.clampSeconds(99, JailConfig), 15)
		Assert.equal(JailRules.clampSeconds(0 / 0, JailConfig), 12)
		Assert.equal(JailRules.clampSeconds("20", JailConfig), 12)
	end,
	["a wanted player is jailed until the server releases them"] = function()
		local state = JailRules.new()
		Assert.equal((JailRules.sentence(state, 100, SECONDS, true)), true)
		Assert.equal(JailRules.isJailed(state), true)
		Assert.equal(JailRules.dueForRelease(state, 100 + SECONDS - 0.01), false)
		Assert.equal(JailRules.dueForRelease(state, 100 + SECONDS), true)
		Assert.equal(JailRules.isJailed(state), true, "still jailed until released, even past the deadline")
		JailRules.release(state)
		Assert.equal(JailRules.isJailed(state), false)
	end,
	["a player with zero wanted level cannot be jailed"] = function()
		local state = JailRules.new()
		local ok, err = JailRules.sentence(state, 0, SECONDS, false)
		Assert.equal(ok, false)
		Assert.equal(err, "NotWanted")
		Assert.equal(JailRules.isJailed(state), false)
	end,
	["duplicate busts never stack or extend a sentence"] = function()
		local state = JailRules.new()
		JailRules.sentence(state, 100, SECONDS, true)
		local ok, err = JailRules.sentence(state, 105, SECONDS, true)
		Assert.equal(ok, false)
		Assert.equal(err, "AlreadyJailed")
		Assert.equal(state.ReleaseAt, 100 + SECONDS)
	end,
	["countdown matches the release time"] = function()
		Assert.equal(JailRules.secondsLeft(112, 100), 12)
		Assert.equal(JailRules.secondsLeft(112, 100.2), 12)
		Assert.equal(JailRules.secondsLeft(112, 111.01), 1)
		Assert.equal(JailRules.secondsLeft(112, 112), 0)
		Assert.equal(JailRules.secondsLeft(112, 130), 0)
	end,
	["jailed players can't spawn, drive, fight or rob"] = function()
		local state = JailRules.new()
		for _, action in { "SpawnVehicle", "Drive", "Combat", "Robbery" } do
			Assert.equal(JailRules.allows(state, action), true, `{action} before jail`)
		end
		JailRules.sentence(state, 0, SECONDS, true)
		for _, action in { "SpawnVehicle", "Drive", "Combat", "Robbery" } do
			Assert.equal(JailRules.allows(state, action), false, `{action} in jail`)
		end
		JailRules.release(state)
		Assert.equal(JailRules.allows(state, "Drive"), true)
	end,
	["cell slots don't overlap until all are taken"] = function()
		Assert.equal(JailRules.pickSlot({}, 4), 1)
		Assert.equal(JailRules.pickSlot({ [1] = true }, 4), 2)
		Assert.equal(JailRules.pickSlot({ [1] = true, [2] = true, [4] = true }, 4), 3)
		local full = JailRules.pickSlot({ [1] = true, [2] = true, [3] = true, [4] = true }, 4)
		Assert.truthy(full >= 1 and full <= 4, "falls back to a valid slot")
	end,
	["jailed players are out of play in the combat rules"] = function()
		local police = { Kind = "NpcPolice", WantedStars = 0, InSafeZone = false, SpawnProtectedUntil = 0 }
		local inmate = { Kind = "Player", UserId = 2, Status = "Combat", WantedStars = 3, InSafeZone = false, SpawnProtectedUntil = 0, Jailed = true }
		local free = { Kind = "Player", UserId = 1, Status = "Combat", WantedStars = 0, InSafeZone = false, SpawnProtectedUntil = 0 }
		local ctx = { Now = 0, Action = "Attack" }
		Assert.equal(select(2, CombatRules.canHarm(police, inmate, { Now = 0, Action = "Bust" })), "Jailed")
		Assert.equal(select(2, CombatRules.canHarm(free, inmate, ctx)), "Jailed")
		Assert.equal(select(2, CombatRules.canHarm(inmate, free, ctx)), "Jailed")
	end,
	["no client remote can end a sentence"] = function()
		for name in Remotes.Definitions do
			Assert.truthy(not name:find("Jail") and not name:find("Release"), `remote {name} must not touch jail`)
		end
	end,
	["the jail cell sits off the road network, with separate slots inside it"] = function()
		local jail = CityLayout.jail()
		Assert.equal(#jail.Slots, CityLayout.JAIL_SLOT_COUNT)
		local half = CityLayout.JAIL_SIZE / 2
		for i, slot in jail.Slots do
			local p = slot.Position - CityLayout.JAIL_CENTER
			Assert.truthy(math.abs(p.X) < half - 2 and math.abs(p.Z) < half - 2, `slot {i} inside the cell`)
			for j = i + 1, #jail.Slots do
				Assert.truthy((jail.Slots[j].Position - slot.Position).Magnitude >= 6, `slots {i},{j} apart`)
			end
		end
		Assert.truthy(CityLayout.JAIL_CENTER.Z - half > CityLayout.GRID_EXTENT + 20, "south of the grid, off-road")
	end,
}
