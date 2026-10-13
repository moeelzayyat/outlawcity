local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Remotes = require(ReplicatedStorage.Shared.Net.Remotes)
local Assert = require(script.Parent.Assert)

return {
	["definitions use valid classes and naming"] = function()
		for name, className in Remotes.Definitions do
			Assert.truthy(className == "RemoteEvent" or className == "RemoteFunction", `{name} class`)
			Assert.truthy(name:match("^Request") or name:match("^On"), `{name} must start with Request or On`)
		end
	end,
	["server created every remote"] = function()
		local folder = ReplicatedStorage:FindFirstChild("Remotes")
		Assert.truthy(folder, "Remotes folder")
		for name, className in Remotes.Definitions do
			local remote = folder:FindFirstChild(name)
			Assert.truthy(remote and remote.ClassName == className, `{name} exists as {className}`)
		end
	end,
	["lookups reject unknown names"] = function()
		Assert.throws(function()
			Remotes.getEvent("RequestSpawnVehicle")
		end, "wrong class must fail")
	end,
}
