local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TeamConfig = require(ReplicatedStorage.Shared.Config.TeamConfig)
local Assert = require(script.Parent.Assert)

return {
	["defines Police and Criminal with distinct colours"] = function()
		local police = TeamConfig.get("Police")
		local criminal = TeamConfig.get("Criminal")
		Assert.truthy(police and criminal, "both teams defined")
		Assert.truthy(police.TeamColor ~= criminal.TeamColor, "distinct team colours")
		Assert.equal(#TeamConfig.Teams, 2)
	end,
	["limits are sane"] = function()
		Assert.truthy(TeamConfig.MaxImbalance >= 1, "imbalance allows at least 1")
		Assert.truthy(TeamConfig.SwitchCooldown > 0, "cooldown positive")
	end,
}
