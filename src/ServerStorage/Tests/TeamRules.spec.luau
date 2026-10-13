local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TeamRules = require(ReplicatedStorage.Shared.Teams.TeamRules)
local TeamConfig = require(ReplicatedStorage.Shared.Config.TeamConfig)
local Assert = require(script.Parent.Assert)

local MAX = TeamConfig.MaxImbalance

local function check(current, target, police, criminal)
	return TeamRules.canJoin(current, target, { Police = police, Criminal = criminal }, MAX)
end

return {
	["solo player can join either team"] = function()
		Assert.equal((check(nil, "Police", 0, 0)), true)
		Assert.equal((check(nil, "Criminal", 0, 0)), true)
	end,
	["unknown team is rejected"] = function()
		local ok, err = check(nil, "Firefighter", 0, 0)
		Assert.equal(ok, false)
		Assert.equal(err, "UnknownTeam")
	end,
	["joining your own team is rejected"] = function()
		local ok, err = check("Police", "Police", 1, 0)
		Assert.equal(ok, false)
		Assert.equal(err, "AlreadyOnTeam")
	end,
	["imbalance limit blocks the bigger team"] = function()
		-- Police 2 vs Criminal 0: a third officer would make it 3-0.
		local ok, err = check(nil, "Police", 2, 0)
		Assert.equal(ok, false)
		Assert.equal(err, "TeamFull")
		Assert.equal((check(nil, "Criminal", 2, 0)), true)
	end,
	["switching counts the team you leave"] = function()
		-- 3 police, 2 criminals; a criminal switching gives 4-1 (diff 3) -> blocked.
		local ok, err = check("Criminal", "Police", 3, 2)
		Assert.equal(ok, false)
		Assert.equal(err, "TeamFull")
		-- An officer switching to criminal gives 2-3 -> allowed.
		Assert.equal((check("Police", "Criminal", 3, 2)), true)
	end,
	["simulated 8-player lobby fills both teams fairly"] = function()
		local counts = { Police = 0, Criminal = 0 }
		-- Everyone tries Police first, falling back to Criminal.
		for _ = 1, 8 do
			local target = if TeamRules.canJoin(nil, "Police", counts, MAX) then "Police" else "Criminal"
			counts[target] += 1
		end
		Assert.truthy(math.abs(counts.Police - counts.Criminal) <= MAX, `unbalanced {counts.Police}-{counts.Criminal}`)
		Assert.equal(counts.Police + counts.Criminal, 8)
	end,
}
