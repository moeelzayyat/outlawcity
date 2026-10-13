local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local DevCommandRules = require(ServerScriptService.Server.Dev.DevCommandRules)
local Remotes = require(ReplicatedStorage.Shared.Net.Remotes)
local WantedConfig = require(ReplicatedStorage.Shared.Config.WantedConfig)
local Assert = require(script.Parent.Assert)

return {
	["valid commands parse"] = function()
		Assert.truthy(DevCommandRules.parse("SetHeat", 50), "SetHeat")
		Assert.truthy(DevCommandRules.parse("SetStars", 3), "SetStars")
		Assert.truthy(DevCommandRules.parse("ReportCrime", "RammingPolice"), "ReportCrime")
		Assert.truthy(DevCommandRules.parse("ResetWanted", nil), "ResetWanted")
		Assert.truthy(DevCommandRules.parse("SetPoliceSight", true), "SetPoliceSight")
	end,
	["invalid commands are rejected"] = function()
		local bad = {
			{ "SetHeat", -1 },
			{ "SetHeat", WantedConfig.MaxHeat + 1 },
			{ "SetHeat", 0 / 0 },
			{ "SetHeat", "10" },
			{ "SetStars", 1.5 },
			{ "SetStars", #WantedConfig.StarThresholds + 1 },
			{ "ReportCrime", "Jaywalking" },
			{ "ReportCrime", 7 },
			{ "SetPoliceSight", "yes" },
			{ "GiveReputation", 1000 },
			{ 123, 1 },
		}
		for _, case in bad do
			local command, err = DevCommandRules.parse(case[1], case[2])
			Assert.equal(command, nil, `{tostring(case[1])}({tostring(case[2])}) should fail`)
			Assert.truthy(type(err) == "string", "reason given")
		end
	end,
	["SetStars lands mid-band, strictly above the threshold"] = function()
		local WantedRules = require(ReplicatedStorage.Shared.Wanted.WantedRules)
		Assert.equal(DevCommandRules.heatForStars(0), 0)
		for stars, threshold in WantedConfig.StarThresholds do
			local heat = DevCommandRules.heatForStars(stars)
			Assert.truthy(heat > threshold, `{stars} stars: heat {heat} above threshold {threshold}`)
			Assert.equal(WantedRules.starsForHeat(heat, WantedConfig), stars)
		end
	end,
	["no public remote can touch wanted state or reputation"] = function()
		for name in Remotes.Definitions do
			if name:match("^Request") then
				for _, word in { "Wanted", "Heat", "Crime", "Reputation", "Dev" } do
					Assert.truthy(not name:find(word), `client remote {name} must not expose {word}`)
				end
			end
		end
	end,
	["dev remotes exist only in Studio"] = function()
		local folder = ReplicatedStorage:FindFirstChild("DevRemotes")
		local isStudio = game:GetService("RunService"):IsStudio()
		Assert.equal(folder ~= nil, isStudio, "DevRemotes presence must equal IsStudio")
	end,
}
