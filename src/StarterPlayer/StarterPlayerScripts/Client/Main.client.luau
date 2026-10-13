--!strict
-- Client entry point. Boots controllers in dependency order and wires input actions.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local VehicleConfig = require(ReplicatedStorage.Shared.Config.VehicleConfig)
local Controllers = script.Parent.Controllers
local VehicleInputController = require(Controllers.VehicleInputController)
local VehicleController = require(Controllers.VehicleController)
local VehicleCameraController = require(Controllers.VehicleCameraController)
local VehicleHudController = require(Controllers.VehicleHudController)
local TeamSelectController = require(Controllers.TeamSelectController)

VehicleInputController.init()
VehicleController.init()
VehicleCameraController.init()
VehicleHudController.init()
task.spawn(TeamSelectController.init)

VehicleInputController.ExitRequested:Connect(VehicleController.requestExit)
VehicleInputController.SpawnRequested:Connect(function()
	VehicleController.requestSpawn(VehicleConfig.DefaultVehicleId)
end)
