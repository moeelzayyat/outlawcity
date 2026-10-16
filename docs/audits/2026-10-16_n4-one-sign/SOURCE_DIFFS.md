# Source diffs: 2026-10-16_n4-one-sign

Commit range `c81f00f..2354a92` (source). Studio matches `src/` for every changed script (hash-checked: CityLayout `77667b94`, CityBuilder `3c5c8451`, WorldService `a91b95db`, CityLayout.spec `01ab8c5f`).

## `src/ServerScriptService/Server/World/CityLayout.luau`

```diff
diff --git a/src/ServerScriptService/Server/World/CityLayout.luau b/src/ServerScriptService/Server/World/CityLayout.luau
index e441cd0..27bd98f 100644
--- a/src/ServerScriptService/Server/World/CityLayout.luau
+++ b/src/ServerScriptService/Server/World/CityLayout.luau
@@ -327,6 +327,53 @@ function CityLayout.dealership(): DealershipSpec
 	}
 end
 
+-- Street-name signs (N4). Plain names are approved for the one-sign prototype only; a
+-- full-city rollout needs its own approval. East-west streets count from the highway side.
+CityLayout.STREET_NAMES_EW = table.freeze({ [-300] = "1st St", [-100] = "2nd St", [100] = "3rd St", [300] = "4th St" })
+CityLayout.STREET_NAMES_NS = table.freeze({ [-300] = "A Ave", [-100] = "B Ave", [100] = "C Ave", [300] = "D Ave" })
+-- Junction and sidewalk-corner offset of every sign. Prototype: ONE sign, at (100, 100).
+CityLayout.STREET_SIGNS = table.freeze({ { X = 100, Z = 100, CornerX = 22, CornerZ = 22 } })
+CityLayout.STREET_SIGN_POST = Vector3.new(0.4, 10.4, 0.4)
+CityLayout.STREET_SIGN_BLADE_LENGTH = 7
+CityLayout.STREET_SIGN_BLADE_HEIGHT = 1.5
+CityLayout.STREET_SIGN_BLADE_THICKNESS = 0.2
+CityLayout.STREET_SIGN_EW_Y = 8.6 -- centre height of the blade naming the east-west street
+CityLayout.STREET_SIGN_NS_Y = 10.2 -- centre height of the blade naming the north-south street
+
+export type StreetSignLabel = { Part: string, Text: string, Faces: { Enum.NormalId } }
+export type StreetSignSpec = { Name: string, X: number, Z: number, Parts: { PartSpec }, Labels: { StreetSignLabel } }
+
+-- One post and two perpendicular blades on a sidewalk corner. Each blade runs along the street
+-- it names and carries the name on both faces, so drivers read it from both directions. All
+-- parts are visual only (CityBuilder.buildStreetSigns turns off collision, query, touch, shadow).
+function CityLayout.streetSigns(): { StreetSignSpec }
+	local result = {}
+	local post = CityLayout.STREET_SIGN_POST
+	local length, height, thick = CityLayout.STREET_SIGN_BLADE_LENGTH, CityLayout.STREET_SIGN_BLADE_HEIGHT, CityLayout.STREET_SIGN_BLADE_THICKNESS
+	local postColor, bladeColor = Color3.fromRGB(110, 110, 110), Color3.fromRGB(0, 102, 51)
+	for _, sign in CityLayout.STREET_SIGNS do
+		local x, z = sign.X + sign.CornerX, sign.Z + sign.CornerZ
+		local function part(name: string, y: number, size: Vector3, color: Color3): PartSpec
+			return { Name = name, Group = "StreetSigns", Center = Vector3.new(x, y, z), Size = size, Color = color, Material = Enum.Material.SmoothPlastic, CanCollide = false }
+		end
+		table.insert(result, {
+			Name = `StreetSign_{sign.X}_{sign.Z}`,
+			X = sign.X,
+			Z = sign.Z,
+			Parts = {
+				part("Post", CityLayout.CURB_TOP + post.Y / 2, post, postColor),
+				part("Blade_EW", CityLayout.STREET_SIGN_EW_Y, Vector3.new(length, height, thick), bladeColor),
+				part("Blade_NS", CityLayout.STREET_SIGN_NS_Y, Vector3.new(thick, height, length), bladeColor),
+			},
+			Labels = {
+				{ Part = "Blade_EW", Text = CityLayout.STREET_NAMES_EW[sign.Z], Faces = { Enum.NormalId.Front, Enum.NormalId.Back } },
+				{ Part = "Blade_NS", Text = CityLayout.STREET_NAMES_NS[sign.X], Faces = { Enum.NormalId.Right, Enum.NormalId.Left } },
+			},
+		})
+	end
+	return result
+end
+
 function CityLayout.createBlueprint(): Blueprint
 	local parts: { PartSpec } = {}
 	local spawns: { SpawnSpec } = {}
```

## `src/ServerScriptService/Server/World/CityBuilder.luau`

```diff
diff --git a/src/ServerScriptService/Server/World/CityBuilder.luau b/src/ServerScriptService/Server/World/CityBuilder.luau
index 38f7661..848d0c6 100644
--- a/src/ServerScriptService/Server/World/CityBuilder.luau
+++ b/src/ServerScriptService/Server/World/CityBuilder.luau
@@ -338,4 +338,69 @@ function CityBuilder.buildDealership(city: Instance): Folder
 	return folder
 end
 
+-- Adds every missing street-name sign under City.StreetSigns and leaves existing ones alone, so
+-- calling it again (at every server start, or after a rebuild) never creates duplicates.
+-- Each sign is an Atomic-streamed model: the post, both blades and their text arrive together.
+function CityBuilder.buildStreetSigns(city: Instance): Folder
+	local folder = city:FindFirstChild("StreetSigns")
+	if not (folder and folder:IsA("Folder")) then
+		folder = Instance.new("Folder")
+		folder.Name = "StreetSigns"
+		folder.Parent = city
+	end
+	local signsFolder = folder :: Folder
+	for _, spec in CityLayout.streetSigns() do
+		if signsFolder:FindFirstChild(spec.Name) then
+			continue
+		end
+		local model = Instance.new("Model")
+		model.Name = spec.Name
+		model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
+		local parts: { [string]: BasePart } = {}
+		for _, partSpec in spec.Parts do
+			local part = Instance.new("Part")
+			part.Name = partSpec.Name
+			part.Anchored = true
+			part.CanCollide = false
+			part.CanQuery = false
+			part.CanTouch = false
+			part.CastShadow = false
+			part.Size = partSpec.Size
+			part.CFrame = CFrame.new(partSpec.Center)
+			part.Color = partSpec.Color
+			part.Material = partSpec.Material
+			part.TopSurface = Enum.SurfaceType.Smooth
+			part.BottomSurface = Enum.SurfaceType.Smooth
+			part.Parent = model
+			parts[partSpec.Name] = part
+		end
+		model.PrimaryPart = parts.Post
+		for _, labelSpec in spec.Labels do
+			for _, face in labelSpec.Faces do
+				local gui = Instance.new("SurfaceGui")
+				gui.Name = `Label_{face.Name}`
+				gui.Face = face
+				gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
+				gui.PixelsPerStud = 50
+				gui.LightInfluence = 0
+				gui.AlwaysOnTop = false
+				gui.MaxDistance = 150
+				local label = Instance.new("TextLabel")
+				label.Name = "Name"
+				label.Size = UDim2.fromScale(0.92, 0.84)
+				label.Position = UDim2.fromScale(0.04, 0.08)
+				label.BackgroundTransparency = 1
+				label.Text = labelSpec.Text
+				label.TextScaled = true
+				label.Font = Enum.Font.GothamBold
+				label.TextColor3 = Color3.fromRGB(255, 255, 255)
+				label.Parent = gui
+				gui.Parent = parts[labelSpec.Part]
+			end
+		end
+		model.Parent = signsFolder
+	end
+	return signsFolder
+end
+
 return CityBuilder
```

## `src/ServerScriptService/Server/Services/WorldService.luau`

```diff
diff --git a/src/ServerScriptService/Server/Services/WorldService.luau b/src/ServerScriptService/Server/Services/WorldService.luau
index 28aac38..c6dea4f 100644
--- a/src/ServerScriptService/Server/Services/WorldService.luau
+++ b/src/ServerScriptService/Server/Services/WorldService.luau
@@ -27,6 +27,9 @@ function WorldService.init()
 	if city and not city:FindFirstChild("Dealership") then
 		CityBuilder.buildDealership(city)
 	end
+	if city then
+		CityBuilder.buildStreetSigns(city) -- adds only missing signs
+	end
 end
 
 -- The dealership folder (City.Dealership), if built.
```

## `src/ServerStorage/Tests/CityLayout.spec.luau`

```diff
diff --git a/src/ServerStorage/Tests/CityLayout.spec.luau b/src/ServerStorage/Tests/CityLayout.spec.luau
index a5353ff..6af5de3 100644
--- a/src/ServerStorage/Tests/CityLayout.spec.luau
+++ b/src/ServerStorage/Tests/CityLayout.spec.luau
@@ -228,4 +228,113 @@ return {
 			end
 		end
 	end,
+	["street signs: exactly one prototype sign, 3 parts, 4 labels (N4 one-sign prototype)"] = function()
+		local signs = CityLayout.streetSigns()
+		Assert.equal(#signs, 1)
+		local sign = signs[1]
+		Assert.equal(sign.Name, "StreetSign_100_100")
+		Assert.equal(#sign.Parts, 3)
+		local names = {}
+		for _, part in sign.Parts do
+			names[part.Name] = true
+			Assert.equal(part.CanCollide, false, `{part.Name} collides`)
+			Assert.equal(part.Material, Enum.Material.SmoothPlastic)
+		end
+		Assert.truthy(names.Post and names.Blade_EW and names.Blade_NS, "part names")
+		local faces = 0
+		for _, label in sign.Labels do
+			faces += #label.Faces
+		end
+		Assert.equal(faces, 4)
+	end,
+	["street signs: sizes, heights, orientation and plain names"] = function()
+		local sign = CityLayout.streetSigns()[1]
+		local parts = {}
+		for _, part in sign.Parts do
+			parts[part.Name] = part
+		end
+		local post, ew, ns = parts.Post, parts.Blade_EW, parts.Blade_NS
+		Assert.near(post.Center.X, 122, 1e-4, "post x")
+		Assert.near(post.Center.Z, 122, 1e-4, "post z")
+		Assert.near(post.Size.X, 0.4, 1e-4, "post width")
+		Assert.near(post.Size.Y, 10.4, 1e-4, "post height")
+		Assert.near(post.Center.Y - post.Size.Y / 2, CityLayout.CURB_TOP, 1e-4, "post stands on the sidewalk")
+		-- Each blade runs along the street it names: EW along X (faces +-Z), NS along Z (faces +-X).
+		Assert.near(ew.Size.X, 7, 1e-4, "EW length")
+		Assert.near(ew.Size.Y, 1.5, 1e-4, "EW height")
+		Assert.near(ew.Size.Z, 0.2, 1e-4, "EW thickness")
+		Assert.near(ns.Size.Z, 7, 1e-4, "NS length")
+		Assert.near(ns.Size.Y, 1.5, 1e-4, "NS height")
+		Assert.near(ns.Size.X, 0.2, 1e-4, "NS thickness")
+		Assert.near(ew.Center.Y, 8.6, 1e-4, "EW height")
+		Assert.near(ns.Center.Y, 10.2, 1e-4, "NS height")
+		Assert.truthy(ns.Center.Y - ns.Size.Y / 2 > ew.Center.Y + ew.Size.Y / 2, "blades don't intersect")
+		Assert.truthy(ns.Center.Y + ns.Size.Y / 2 <= post.Center.Y + post.Size.Y / 2 + 1e-4, "post reaches the top blade")
+		for _, label in sign.Labels do
+			if label.Part == "Blade_EW" then
+				Assert.equal(label.Text, "3rd St")
+				Assert.truthy(table.find(label.Faces, Enum.NormalId.Front) and table.find(label.Faces, Enum.NormalId.Back), "EW faces")
+			else
+				Assert.equal(label.Part, "Blade_NS")
+				Assert.equal(label.Text, "C Ave")
+				Assert.truthy(table.find(label.Faces, Enum.NormalId.Right) and table.find(label.Faces, Enum.NormalId.Left), "NS faces")
+			end
+		end
+	end,
+	["street signs: full footprints on the sidewalk, clear of roads, markings, buildings and pads"] = function()
+		local sign = CityLayout.streetSigns()[1]
+		local function inside(a, b)
+			local ax1, ax2, az1, az2 = rect(a)
+			local bx1, bx2, bz1, bz2 = rect(b)
+			return ax1 >= bx1 - 1e-4 and ax2 <= bx2 + 1e-4 and az1 >= bz1 - 1e-4 and az2 <= bz2 + 1e-4
+		end
+		local function gap(a, b) -- horizontal gap between two footprints (negative or 0 = touching/overlap)
+			local ax1, ax2, az1, az2 = rect(a)
+			local bx1, bx2, bz1, bz2 = rect(b)
+			local dx = math.max(bx1 - ax2, ax1 - bx2, 0)
+			local dz = math.max(bz1 - az2, az1 - bz2, 0)
+			if dx == 0 and dz == 0 then
+				return -1
+			end
+			return math.sqrt(dx * dx + dz * dz)
+		end
+		local others = {}
+		for _, spec in blueprint.Parts do
+			table.insert(others, spec)
+		end
+		for _, spec in CityLayout.store().Parts do
+			table.insert(others, spec)
+		end
+		for _, spec in CityLayout.dealership().Parts do
+			table.insert(others, spec)
+		end
+		for _, part in sign.Parts do
+			local onSidewalk = false
+			for _, spec in blueprint.Parts do
+				if spec.Group == "Sidewalks" and inside(part, spec) then
+					onSidewalk = true
+				end
+			end
+			Assert.truthy(onSidewalk, `{part.Name} footprint not fully on one sidewalk`)
+			local nearestRoad = math.huge
+			for _, spec in others do
+				local g = gap(part, spec)
+				if spec.Group == "Roads" or spec.Group == "Highway" or spec.Group == "Plaza" or spec.Group == "Markings" then
+					Assert.truthy(g > 0, `{part.Name} overlaps {spec.Name}`)
+					if spec.Group == "Roads" then
+						nearestRoad = math.min(nearestRoad, g)
+					end
+				elseif spec.Group == "Buildings" or spec.Group == "Store" or spec.Group == "Dealership" then
+					Assert.truthy(g >= 3, `{part.Name} within 3 studs of {spec.Name}`)
+				end
+			end
+			-- Measured face to road edge: the post 3.8 studs, the blades 0.5 stud (overhead).
+			Assert.near(nearestRoad, if part.Name == "Post" then 3.8 else 0.5, 1e-4, `{part.Name} distance to the nearest road edge`)
+		end
+		local post = sign.Parts[1]
+		for _, spawn in blueprint.Spawns do
+			local d = (Vector3.new(spawn.CFrame.X, 0, spawn.CFrame.Z) - Vector3.new(post.Center.X, 0, post.Center.Z)).Magnitude
+			Assert.truthy(d >= 3 + 9, `sign within reach of vehicle pad {spawn.Name}`) -- pad half-diagonal < 9
+		end
+	end,
 }
```
