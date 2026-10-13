local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PlayerAttributes = require(ReplicatedStorage.Shared.Player.PlayerAttributes)
local GameplayConfig = require(ReplicatedStorage.Shared.Config.GameplayConfig)
local Assert = require(script.Parent.Assert)

return {
	["attribute names are unique and match their keys"] = function()
		local seen = {}
		for key, name in PlayerAttributes do
			Assert.equal(key, name, "key/name mismatch")
			Assert.truthy(not seen[name], `duplicate {name}`)
			seen[name] = true
		end
	end,
	["gameplay config is frozen and sane"] = function()
		Assert.truthy(GameplayConfig.SpawnProtectionSeconds > 0, "spawn protection")
		Assert.truthy(GameplayConfig.SpawnClearance > 0, "clearance")
		Assert.throws(function()
			(GameplayConfig :: any).SpawnProtectionSeconds = 0
		end, "config frozen")
	end,
	["no team system remains"] = function()
		Assert.equal(ReplicatedStorage.Shared:FindFirstChild("Teams"), nil)
		Assert.equal(ReplicatedStorage.Shared.Config:FindFirstChild("TeamConfig"), nil)
		Assert.equal(#game:GetService("Teams"):GetChildren(), 0)
	end,
}
