--!strict
-- Client entry point. Boots controllers in dependency order and wires input actions.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local VehicleConfig = require(ReplicatedStorage.Shared.Config.VehicleConfig)
local Controllers = script.Parent.Controllers
local VehicleInputController = require(Controllers.VehicleInputController)
local VehicleController = require(Controllers.VehicleController)
local VehicleCameraController = require(Controllers.VehicleCameraController)
local VehicleHudController = require(Controllers.VehicleHudController)
local WantedHudController = require(Controllers.WantedHudController)
local DevPanelController = require(Controllers.DevPanelController)
local CombatStatusController = require(Controllers.CombatStatusController)
local SafeZoneHudController = require(Controllers.SafeZoneHudController)
local JailHudController = require(Controllers.JailHudController)

VehicleInputController.init()
VehicleController.init()
VehicleCameraController.init()
VehicleHudController.init()
task.spawn(WantedHudController.init)
task.spawn(DevPanelController.init)
task.spawn(CombatStatusController.init)
task.spawn(SafeZoneHudController.init)
task.spawn(JailHudController.init)

VehicleInputController.ExitRequested:Connect(VehicleController.requestExit)
VehicleInputController.SpawnRequested:Connect(function()
	VehicleController.requestSpawn(VehicleConfig.DefaultVehicleId)
end)
