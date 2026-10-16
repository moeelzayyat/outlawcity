--!strict
-- Turns a CityLayout blueprint into anchored parts under Workspace.City.
-- Yields between chunks so it is safe to run in Studio edit mode or at server boot.
local CityLayout = require(script.Parent.CityLayout)
local VehicleConfig = require(game:GetService("ReplicatedStorage").Shared.Config.VehicleConfig)
local VehicleFactory = require(script.Parent.Parent.Vehicle.VehicleFactory)

local CityBuilder = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameplayConfig = require(ReplicatedStorage.Shared.Config.GameplayConfig)

local CHUNK_SIZE = 60
local SPAWN_PAD_SIZE = Vector3.new(9, 0.05, 15)
local CIVILIAN_SPAWN_SIZE = Vector3.new(8, 0.1, 8)

function CityBuilder.build(blueprint: CityLayout.Blueprint, parent: Instance): Folder
	local city = Instance.new("Folder")
	city.Name = "City"
	city:SetAttribute("GeneratedBy", "CityBuilder")
	city.Parent = parent

	local groups: { [string]: Folder } = {}
	local function groupFolder(name: string): Folder
		local existing = groups[name]
		if existing then
			return existing
		end
		local folder = Instance.new("Folder")
		folder.Name = name
		folder.Parent = city
		groups[name] = folder
		return folder
	end

	for i, spec in blueprint.Parts do
		local part = Instance.new("Part")
		part.Name = spec.Name
		part.Anchored = true
		part.Size = spec.Size
		part.CFrame = CFrame.new(spec.Center)
		part.Color = spec.Color
		part.Material = spec.Material
		part.CanCollide = spec.CanCollide
		if spec.PhysicsMaterial then
			part.CustomPhysicalProperties = PhysicalProperties.new(spec.PhysicsMaterial)
		end
		part.TopSurface = Enum.SurfaceType.Smooth
		part.BottomSurface = Enum.SurfaceType.Smooth
		if not spec.CanCollide then
			part.CanQuery = false
			part.CanTouch = false
			part.CastShadow = false
		end
		part.Parent = groupFolder(spec.Group)
		if i % CHUNK_SIZE == 0 then
			task.wait()
		end
	end

	local spawnFolder = groupFolder("VehicleSpawns")
	for _, spawn in blueprint.Spawns do
		local pad = Instance.new("Part")
		pad.Name = spawn.Name
		pad.Anchored = true
		pad.CanCollide = false
		pad.CanQuery = false
		pad.CanTouch = false
		pad.CastShadow = false
		pad.Size = SPAWN_PAD_SIZE
		pad.CFrame = spawn.CFrame + Vector3.new(0, SPAWN_PAD_SIZE.Y / 2 + 0.03, 0)
		pad.Color = Color3.fromRGB(255, 200, 0)
		pad.Material = Enum.Material.SmoothPlastic
		pad.Transparency = 0.5
		pad.Parent = spawnFolder
	end

	CityBuilder.buildCivilianSpawns(blueprint, city)
	return city
end

-- Adds City.CivilianSpawns if missing (safe to call on an existing city). Returns the folder.
-- Thin, non-colliding SpawnLocations; Duration gives the built-in spawn ForceField.
function CityBuilder.buildCivilianSpawns(blueprint: CityLayout.Blueprint, city: Instance): Folder
	local existing = city:FindFirstChild("CivilianSpawns")
	if existing and existing:IsA("Folder") then
		return existing
	end
	local folder = Instance.new("Folder")
	folder.Name = "CivilianSpawns"
	for _, spawn in blueprint.CivilianSpawns do
		local location = Instance.new("SpawnLocation")
		location.Name = spawn.Name
		location.Anchored = true
		location.CanCollide = false
		location.CanQuery = false
		location.CastShadow = false
		location.Size = CIVILIAN_SPAWN_SIZE
		location.CFrame = spawn.CFrame + Vector3.new(0, CIVILIAN_SPAWN_SIZE.Y / 2, 0)
		location.Color = Color3.fromRGB(90, 200, 255)
		location.Material = Enum.Material.SmoothPlastic
		location.Transparency = 0.4
		location.Neutral = true
		location.AllowTeamChangeOnTouch = false
		location.Duration = GameplayConfig.SpawnProtectionSeconds
		location.Parent = folder
	end
	folder.Parent = city
	return folder
end

-- Adds City.Jail (walls, bars, roof and invisible Slot markers) if missing. Returns the folder.
function CityBuilder.buildJail(city: Instance): Folder
	local existing = city:FindFirstChild("Jail")
	if existing and existing:IsA("Folder") then
		return existing
	end
	local spec = CityLayout.jail()
	local folder = Instance.new("Folder")
	folder.Name = "Jail"
	for _, partSpec in spec.Parts do
		local part = Instance.new("Part")
		part.Name = partSpec.Name
		part.Anchored = true
		part.Size = partSpec.Size
		part.CFrame = CFrame.new(partSpec.Center)
		part.Color = partSpec.Color
		part.Material = partSpec.Material
		part.TopSurface = Enum.SurfaceType.Smooth
		part.BottomSurface = Enum.SurfaceType.Smooth
		part.Parent = folder
	end
	local roof = folder:FindFirstChild("JailRoof")
	if roof then
		local light = Instance.new("PointLight")
		light.Range = 24
		light.Brightness = 1.5
		light.Parent = roof
	end
	local slots = Instance.new("Folder")
	slots.Name = "Slots"
	for index, cframe in spec.Slots do
		local marker = Instance.new("Part")
		marker.Name = `Slot{index}`
		marker.Anchored = true
		marker.CanCollide = false
		marker.CanQuery = false
		marker.CanTouch = false
		marker.Transparency = 1
		marker.Size = Vector3.new(2, 1, 2)
		marker.CFrame = cframe
		marker.Parent = slots
	end
	slots.Parent = folder
	folder.Parent = city
	return folder
end

-- Adds City.Store (building, register ProximityPrompt, invisible holdout Area, sign) if
-- missing. The prompt is only a trigger: RobberyService re-validates everything on the server.
function CityBuilder.buildStore(city: Instance): Folder
	local existing = city:FindFirstChild("Store")
	if existing and existing:IsA("Folder") then
		return existing
	end
	local spec = CityLayout.store()
	local folder = Instance.new("Folder")
	folder.Name = "Store"
	folder:SetAttribute("StoreId", spec.Id)
	for _, partSpec in spec.Parts do
		local part = Instance.new("Part")
		part.Name = partSpec.Name
		part.Anchored = true
		part.CanCollide = partSpec.CanCollide
		part.Size = partSpec.Size
		part.CFrame = CFrame.new(partSpec.Center)
		part.Color = partSpec.Color
		part.Material = partSpec.Material
		part.TopSurface = Enum.SurfaceType.Smooth
		part.BottomSurface = Enum.SurfaceType.Smooth
		if partSpec.Material == Enum.Material.Glass then
			part.Transparency = 0.6
		end
		part.Parent = folder
	end
	local roof = folder:FindFirstChild("StoreRoof")
	if roof then
		local light = Instance.new("PointLight")
		light.Range = 26
		light.Brightness = 1.2
		light.Parent = roof
	end
	local register = folder:FindFirstChild("StoreRegister") :: BasePart?
	if register then
		local attachment = Instance.new("Attachment")
		attachment.Name = "PromptAttachment"
		attachment.Parent = register -- parent first: WorldCFrame is relative to the parent part
		attachment.WorldCFrame = spec.Register
		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "RobPrompt"
		prompt.ActionText = "Rob store"
		prompt.ObjectText = "Register"
		prompt.HoldDuration = 1
		prompt.MaxActivationDistance = 10
		prompt.RequiresLineOfSight = false
		prompt.KeyboardKeyCode = Enum.KeyCode.E
		prompt.Parent = attachment
	end
	local area = Instance.new("Part")
	area.Name = "Area"
	area.Anchored = true
	area.CanCollide = false
	area.CanQuery = false
	area.CanTouch = false
	area.Transparency = 1
	area.Size = spec.Area.Size
	area.CFrame = CFrame.new(spec.Area.Center)
	area.Parent = folder
	local sign = Instance.new("Part")
	sign.Name = "StoreSign"
	sign.Anchored = true
	sign.Size = spec.Sign.Size
	sign.CFrame = CFrame.new(spec.Sign.Center)
	sign.Color = Color3.fromRGB(40, 120, 70)
	sign.Material = Enum.Material.SmoothPlastic
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Right
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 25
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = "24/7 MART"
	label.TextScaled = true
	label.Font = Enum.Font.GothamBlack
	label.TextColor3 = Color3.fromRGB(255, 230, 120)
	label.Parent = gui
	gui.Parent = sign
	sign.Parent = folder
	folder.Parent = city
	return folder
end

-- Adds City.Dealership (showroom, sales-desk ShopPrompt, anchored display car, sign) if
-- missing. The prompt only opens the client's shop window; purchases are validated by
-- DealershipService on the server.
function CityBuilder.buildDealership(city: Instance): Folder
	local existing = city:FindFirstChild("Dealership")
	if existing and existing:IsA("Folder") then
		return existing
	end
	local spec = CityLayout.dealership()
	local folder = Instance.new("Folder")
	folder.Name = "Dealership"
	for _, partSpec in spec.Parts do
		local part = Instance.new("Part")
		part.Name = partSpec.Name
		part.Anchored = true
		part.CanCollide = partSpec.CanCollide
		part.Size = partSpec.Size
		part.CFrame = CFrame.new(partSpec.Center)
		part.Color = partSpec.Color
		part.Material = partSpec.Material
		part.TopSurface = Enum.SurfaceType.Smooth
		part.BottomSurface = Enum.SurfaceType.Smooth
		if partSpec.Material == Enum.Material.Glass then
			part.Transparency = 0.6
		end
		part.Parent = folder
	end
	local roof = folder:FindFirstChild("DealerRoof")
	if roof then
		local light = Instance.new("PointLight")
		light.Range = 30
		light.Brightness = 1.3
		light.Parent = roof
	end
	local desk = folder:FindFirstChild("DealerDesk") :: BasePart?
	if desk then
		local attachment = Instance.new("Attachment")
		attachment.Name = "PromptAttachment"
		attachment.Parent = desk -- parent first: WorldCFrame is relative to the parent part
		attachment.WorldCFrame = spec.Desk
		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "ShopPrompt"
		prompt.ActionText = "Browse cars"
		prompt.ObjectText = "Dealership"
		prompt.HoldDuration = 0
		prompt.MaxActivationDistance = 14
		prompt.RequiresLineOfSight = false
		prompt.KeyboardKeyCode = Enum.KeyCode.E
		prompt.Parent = attachment
	end
	-- Display car: a real model of the first catalogue car, anchored and not drivable.
	local ok, display = pcall(function()
		local stats = VehicleConfig.get("Muscle")
		return stats and VehicleFactory.build("Muscle", stats)
	end)
	if ok and display then
		display.Name = "DisplayCar"
		for _, d in display:GetDescendants() do
			if d:IsA("BasePart") then
				d.Anchored = true
			elseif d:IsA("ProximityPrompt") or d:IsA("Constraint") or d:IsA("Script") then
				d:Destroy()
			end
		end
		local seat = display:FindFirstChildWhichIsA("Seat", true)
		if seat then
			seat.Disabled = true
		end
		local _, size = display:GetBoundingBox()
		display:PivotTo(spec.Display * CFrame.new(0, size.Y / 2 + 0.05, 0))
		display.Parent = folder
	end
	local sign = Instance.new("Part")
	sign.Name = "DealerSign"
	sign.Anchored = true
	sign.Size = spec.Sign.Size
	sign.CFrame = CFrame.new(spec.Sign.Center)
	sign.Color = Color3.fromRGB(30, 60, 120)
	sign.Material = Enum.Material.SmoothPlastic
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front -- faces -Z, towards the road
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 25
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = "OUTLAW MOTORS"
	label.TextScaled = true
	label.Font = Enum.Font.GothamBlack
	label.TextColor3 = Color3.fromRGB(255, 255, 255)
	label.Parent = gui
	gui.Parent = sign
	sign.Parent = folder
	folder.Parent = city
	return folder
end

-- Adds every missing street-name sign under City.StreetSigns and leaves existing ones alone, so
-- calling it again (at every server start, or after a rebuild) never creates duplicates.
-- Each sign is an Atomic-streamed model: the post, both blades and their text arrive together.
function CityBuilder.buildStreetSigns(city: Instance): Folder
	local folder = city:FindFirstChild("StreetSigns")
	if not (folder and folder:IsA("Folder")) then
		folder = Instance.new("Folder")
		folder.Name = "StreetSigns"
		folder.Parent = city
	end
	local signsFolder = folder :: Folder
	for _, spec in CityLayout.streetSigns() do
		if signsFolder:FindFirstChild(spec.Name) then
			continue
		end
		local model = Instance.new("Model")
		model.Name = spec.Name
		model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
		local parts: { [string]: BasePart } = {}
		for _, partSpec in spec.Parts do
			local part = Instance.new("Part")
			part.Name = partSpec.Name
			part.Anchored = true
			part.CanCollide = false
			part.CanQuery = false
			part.CanTouch = false
			part.CastShadow = false
			part.Size = partSpec.Size
			part.CFrame = CFrame.new(partSpec.Center)
			part.Color = partSpec.Color
			part.Material = partSpec.Material
			part.TopSurface = Enum.SurfaceType.Smooth
			part.BottomSurface = Enum.SurfaceType.Smooth
			part.Parent = model
			parts[partSpec.Name] = part
		end
		model.PrimaryPart = parts.Post
		for _, labelSpec in spec.Labels do
			for _, face in labelSpec.Faces do
				local gui = Instance.new("SurfaceGui")
				gui.Name = `Label_{face.Name}`
				gui.Face = face
				gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
				gui.PixelsPerStud = 50
				gui.LightInfluence = 0
				gui.AlwaysOnTop = false
				gui.MaxDistance = 150
				local label = Instance.new("TextLabel")
				label.Name = "Name"
				label.Size = UDim2.fromScale(0.92, 0.84)
				label.Position = UDim2.fromScale(0.04, 0.08)
				label.BackgroundTransparency = 1
				label.Text = labelSpec.Text
				label.TextScaled = true
				label.Font = Enum.Font.GothamBold
				label.TextColor3 = Color3.fromRGB(255, 255, 255)
				label.Parent = gui
				gui.Parent = parts[labelSpec.Part]
			end
		end
		model.Parent = signsFolder
	end
	return signsFolder
end

return CityBuilder
