local ReplicatedStorage = game:GetService("ReplicatedStorage")
local VehicleConfig = require(ReplicatedStorage.Shared.Config.VehicleConfig)
local Assert = require(script.Parent.Assert)

return {
	["default vehicle exists"] = function()
		Assert.truthy(VehicleConfig.get(VehicleConfig.DefaultVehicleId), "default vehicle")
		Assert.equal(VehicleConfig.get("DoesNotExist"), nil)
	end,
	["every vehicle has sane stats"] = function()
		for _, id in VehicleConfig.getIds() do
			local s = assert(VehicleConfig.get(id))
			Assert.equal(#s.WheelOffsets, 4, `{id} wheel count`)
			Assert.truthy(s.WheelOffsets[1].Z < 0 and s.WheelOffsets[2].Z < 0, `{id} front wheels at -Z`)
			Assert.truthy(s.WheelOffsets[3].Z > 0 and s.WheelOffsets[4].Z > 0, `{id} rear wheels at +Z`)
			Assert.truthy(s.StaticCompressionRatio > 0 and s.StaticCompressionRatio < 1, `{id} compression ratio`)
			Assert.truthy(s.MaxForwardSpeed > s.MaxReverseSpeed, `{id} speeds`)
			Assert.truthy(s.WheelRadius > 0 and s.SuspensionRestLength > 0, `{id} wheel geometry`)
		end
	end,
	["config is read-only"] = function()
		local s = assert(VehicleConfig.get(VehicleConfig.DefaultVehicleId))
		Assert.throws(function()
			(s :: any).MaxForwardSpeed = 9999
		end, "stats should be frozen")
	end,
}
