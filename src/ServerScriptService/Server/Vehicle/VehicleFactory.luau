--!strict
-- Builds a vehicle Model from VehicleStats. Only the chassis collides and carries mass;
-- body panels, seat and wheels are massless visuals. Wheels hang off Motor6Ds so the
-- simulating client can animate suspension travel, steering and spin locally.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Types = require(ReplicatedStorage.Shared.Types)

local VehicleFactory = {}

local TRIM_COLOR = Color3.fromRGB(25, 25, 28)
local GLASS_COLOR = Color3.fromRGB(150, 190, 220)

local function weldedPart(
	model: Model,
	chassis: BasePart,
	name: string,
	size: Vector3,
	offset: CFrame,
	color: Color3,
	material: Enum.Material
): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = chassis.CFrame * offset
	part.Color = color
	part.Material = material
	part.Massless = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = chassis
	weld.Part1 = part
	weld.Parent = part
	part.Parent = model
	return part
end

-- Spring length at rest, measured from the suspension anchor to the wheel centre.
function VehicleFactory.getStaticSpringLength(stats: Types.VehicleStats): number
	return stats.SuspensionRestLength * (1 - stats.StaticCompressionRatio)
end

-- Height of the chassis centre above flat ground when the car rests on its springs.
function VehicleFactory.getRideHeight(stats: Types.VehicleStats): number
	return stats.WheelRadius + VehicleFactory.getStaticSpringLength(stats) - stats.WheelOffsets[1].Y
end

function VehicleFactory.build(vehicleId: string, stats: Types.VehicleStats): Model
	local model = Instance.new("Model")
	model.Name = vehicleId
	model:SetAttribute("VehicleId", vehicleId)

	local size = stats.ChassisSize
	local chassis = Instance.new("Part")
	chassis.Name = "Chassis"
	chassis.Size = size
	chassis.CFrame = CFrame.identity
	chassis.Color = stats.BodyColor
	chassis.Material = Enum.Material.SmoothPlastic
	chassis.CustomPhysicalProperties = PhysicalProperties.new(0.7, 0.3, 0, 1, 1)
	chassis.RootPriority = 10
	chassis.TopSurface = Enum.SurfaceType.Smooth
	chassis.BottomSurface = Enum.SurfaceType.Smooth
	chassis.Parent = model
	model.PrimaryPart = chassis

	local halfY, halfZ = size.Y / 2, size.Z / 2
	local plastic = Enum.Material.SmoothPlastic
	weldedPart(model, chassis, "Hood", Vector3.new(size.X - 0.2, 0.5, 4.2), CFrame.new(0, halfY + 0.25, -halfZ + 2.3), stats.BodyColor, plastic)
	weldedPart(model, chassis, "Trunk", Vector3.new(size.X - 0.2, 0.5, 2.6), CFrame.new(0, halfY + 0.25, halfZ - 1.5), stats.BodyColor, plastic)
	weldedPart(model, chassis, "Cabin", Vector3.new(size.X - 0.8, 1.7, 5.6), CFrame.new(0, halfY + 0.85, 0.8), GLASS_COLOR, Enum.Material.Glass).Transparency = 0.55
	weldedPart(model, chassis, "Roof", Vector3.new(size.X - 0.6, 0.3, 4.4), CFrame.new(0, halfY + 1.85, 1.0), stats.BodyColor, plastic)
	weldedPart(model, chassis, "BumperFront", Vector3.new(size.X + 0.2, 0.7, 0.6), CFrame.new(0, -0.1, -halfZ - 0.2), TRIM_COLOR, plastic)
	weldedPart(model, chassis, "BumperRear", Vector3.new(size.X + 0.2, 0.7, 0.6), CFrame.new(0, -0.1, halfZ + 0.2), TRIM_COLOR, plastic)
	for _, side in { -1, 1 } do
		weldedPart(model, chassis, "Headlight", Vector3.new(1.4, 0.4, 0.2), CFrame.new(side * 2.4, 0.4, -halfZ - 0.05), Color3.fromRGB(255, 250, 225), Enum.Material.Neon)
		weldedPart(model, chassis, "Taillight", Vector3.new(1.4, 0.4, 0.2), CFrame.new(side * 2.4, 0.4, halfZ + 0.05), Color3.fromRGB(200, 20, 20), Enum.Material.Neon)
	end

	-- Driver seat (left-hand drive). The server seats players through Seat:Sit or the prompt.
	local seat = Instance.new("Seat")
	seat.Name = "DriverSeat"
	seat.Size = Vector3.new(2, 0.3, 2)
	seat.CFrame = chassis.CFrame * CFrame.new(-1.4, halfY + 0.15, 1.2)
	seat.Color = TRIM_COLOR
	seat.Massless = true
	seat.CanCollide = false
	seat.TopSurface = Enum.SurfaceType.Smooth
	seat.BottomSurface = Enum.SurfaceType.Smooth
	local seatWeld = Instance.new("WeldConstraint")
	seatWeld.Part0 = chassis
	seatWeld.Part1 = seat
	seatWeld.Parent = seat
	seat.Parent = model

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "DrivePrompt"
	prompt.ActionText = "Drive"
	prompt.ObjectText = stats.DisplayName
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.GamepadKeyCode = Enum.KeyCode.ButtonY
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Parent = seat

	-- Wheels: visual only, positioned at static ride height; clients animate Motor6D.Transform.
	local staticLength = VehicleFactory.getStaticSpringLength(stats)
	for index, offset in stats.WheelOffsets do
		local wheel = Instance.new("Part")
		wheel.Name = `Wheel{index}`
		wheel.Shape = Enum.PartType.Cylinder
		wheel.Size = Vector3.new(stats.WheelWidth, stats.WheelRadius * 2, stats.WheelRadius * 2)
		wheel.Color = TRIM_COLOR
		wheel.Material = plastic
		wheel.Massless = true
		wheel.CanCollide = false
		wheel.CanQuery = false
		wheel.CanTouch = false
		local c0 = CFrame.new(offset - Vector3.yAxis * staticLength)
		wheel.CFrame = chassis.CFrame * c0
		local motor = Instance.new("Motor6D")
		motor.Name = `WheelMotor{index}`
		motor.Part0 = chassis
		motor.Part1 = wheel
		motor.C0 = c0
		motor.Parent = chassis
		wheel.Parent = model
	end

	return model
end

return VehicleFactory
