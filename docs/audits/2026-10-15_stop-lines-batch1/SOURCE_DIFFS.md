# Source diffs: 2026-10-15_stop-lines-batch1

Commit range `52cf1ca..0b4919b` (source). Studio matches `src/` for every changed script (hash-checked: CityLayout `0325d9e6`, CityLayout.spec `6d2a827f`).

## `src/ServerScriptService/Server/World/CityLayout.luau`

```diff
diff --git a/src/ServerScriptService/Server/World/CityLayout.luau b/src/ServerScriptService/Server/World/CityLayout.luau
index 2b1c18d..e441cd0 100644
--- a/src/ServerScriptService/Server/World/CityLayout.luau
+++ b/src/ServerScriptService/Server/World/CityLayout.luau
@@ -120,6 +120,48 @@ function CityLayout.stretches(): { { number } }
 	return result
 end
 
+CityLayout.STOP_LINE_GAP = 2 -- studs between the stop line and the intersection square
+CityLayout.STOP_LINE_DEPTH = 1.2 -- along the road
+CityLayout.STOP_LINE_INNER = 0.6 -- clearance from the centre of the road (the yellow line is 0.8 wide)
+CityLayout.STOP_LINE_CURB = 1 -- clearance from the curb
+
+export type StopLineArm = { Name: string, Center: Vector3, SizeX: number, SizeZ: number, Side: string, X: number, Z: number }
+
+-- The road arms entering each grid intersection: north (-Z), south (+Z), west (-X), east (+X).
+-- An arm exists where a road continues past the intersection square: inside the grid, plus the
+-- connector roads north of the z = -300 line. The connector-highway joins are not included.
+function CityLayout.stopLineApproaches(): { StopLineArm }
+	local half = CityLayout.ROAD_WIDTH / 2
+	local lines = CityLayout.GRID_LINES
+	local first, last = lines[1], lines[#lines]
+	local offset = half + CityLayout.STOP_LINE_GAP + CityLayout.STOP_LINE_DEPTH / 2
+	local across = half - CityLayout.STOP_LINE_INNER - CityLayout.STOP_LINE_CURB
+	local lateral = CityLayout.STOP_LINE_INNER + across / 2
+	local arms = {}
+	for _, X in lines do
+		for _, Z in lines do
+			local function arm(side: string, dx: number, dz: number, sizeX: number, sizeZ: number)
+				table.insert(arms, { Name = `StopLine_{X}_{Z}_{side}`, Center = Vector3.new(X + dx, 0, Z + dz), SizeX = sizeX, SizeZ = sizeZ, Side = side, X = X, Z = Z })
+			end
+			-- Right-hand traffic: a car heading +Z keeps to -X, heading -Z to +X, heading +X to +Z,
+			-- heading -X to -Z (Roblox right vectors).
+			if Z > first or table.find(CityLayout.CONNECTOR_XS, X) then
+				arm("N", -lateral, -offset, across, CityLayout.STOP_LINE_DEPTH) -- arriving northbound side, heading +Z
+			end
+			if Z < last then
+				arm("S", lateral, offset, across, CityLayout.STOP_LINE_DEPTH) -- heading -Z
+			end
+			if X > first then
+				arm("W", -offset, lateral, CityLayout.STOP_LINE_DEPTH, across) -- heading +X
+			end
+			if X < last then
+				arm("E", offset, -lateral, CityLayout.STOP_LINE_DEPTH, across) -- heading -X
+			end
+		end
+	end
+	return arms
+end
+
 -- Splits [from, to] into pieces that skip the given openings ({centre, halfWidth}).
 local function withOpenings(from: number, to: number, openings: { { number } }): { { number } }
 	local pieces = {}
@@ -320,6 +362,14 @@ function CityLayout.createBlueprint(): Blueprint
 		end
 	end
 
+	-- Stop lines (N5, stop-line Batch 1): one per road arm entering a grid intersection, 2 studs
+	-- before the 36x36 intersection square, across the incoming half of the arm only (right-hand
+	-- traffic), from 0.6 studs off the centre line to 1 stud inside the curb. Visual only: built
+	-- non-colliding (CityBuilder then also turns off query, touch and shadow).
+	for _, arm in CityLayout.stopLineApproaches() do
+		add(slab(arm.Name, "Markings", arm.Center.X, arm.Center.Z, arm.SizeX, arm.SizeZ, MARK_TOP, MARK_THICKNESS, COLORS.White, Enum.Material.SmoothPlastic, false))
+	end
+
 	-- City blocks: the centre block is a flat plaza with vehicle spawns, the rest are raised sidewalks.
 	local rng = Random.new(BUILDING_SEED)
 	for bi, sx in stretches do
```

## `src/ServerStorage/Tests/CityLayout.spec.luau`

```diff
diff --git a/src/ServerStorage/Tests/CityLayout.spec.luau b/src/ServerStorage/Tests/CityLayout.spec.luau
index 9123eca..a5353ff 100644
--- a/src/ServerStorage/Tests/CityLayout.spec.luau
+++ b/src/ServerStorage/Tests/CityLayout.spec.luau
@@ -94,10 +94,11 @@ return {
 	end,
 	["world polish: every generated part keeps its baseline geometry except Building_3_3_1"] = function()
 		-- Signature of all generated parts (name, group, centre, size, collision) except the one
-		-- approved exception, recorded from the place before World Polish Batch 1.
+		-- approved exception, recorded from the place before World Polish Batch 1. The stop lines
+		-- (stop-line Batch 1) are new parts and are checked by their own tests below.
 		local rows = {}
 		for _, spec in blueprint.Parts do
-			if spec.Name ~= "Building_3_3_1" then
+			if spec.Name ~= "Building_3_3_1" and spec.Name:sub(1, 9) ~= "StopLine_" then
 				table.insert(rows, string.format("%s|%s|%.3f,%.3f,%.3f|%.3f,%.3f,%.3f|%s", spec.Name, spec.Group, spec.Center.X, spec.Center.Y, spec.Center.Z, spec.Size.X, spec.Size.Y, spec.Size.Z, tostring(spec.CanCollide)))
 			end
 		end
@@ -149,4 +150,82 @@ return {
 			end
 		end
 	end,
+	["stop lines: exactly 50, one per approach (6 four-arm, 6 three-arm, 4 two-arm intersections)"] = function()
+		local lines, names, perIntersection = {}, {}, {}
+		for _, spec in blueprint.Parts do
+			if spec.Name:sub(1, 9) == "StopLine_" then
+				table.insert(lines, spec)
+				Assert.truthy(not names[spec.Name], `duplicate {spec.Name}`)
+				names[spec.Name] = true
+				local x, z = spec.Name:match("^StopLine_(%-?%d+)_(%-?%d+)_")
+				local key = `{x},{z}`
+				perIntersection[key] = (perIntersection[key] or 0) + 1
+			end
+		end
+		Assert.equal(#lines, 50)
+		local histogram = { [2] = 0, [3] = 0, [4] = 0 }
+		for _, n in perIntersection do
+			histogram[n] += 1
+		end
+		Assert.equal(histogram[4], 6)
+		Assert.equal(histogram[3], 6)
+		Assert.equal(histogram[2], 4)
+	end,
+	["stop lines: on the road, incoming half, 2 studs before the square, clear of centre lines"] = function()
+		local function inside(a, b) -- rect a fully inside rect b
+			local ax1, ax2, az1, az2 = rect(a)
+			local bx1, bx2, bz1, bz2 = rect(b)
+			return ax1 >= bx1 - 1e-4 and ax2 <= bx2 + 1e-4 and az1 >= bz1 - 1e-4 and az2 <= bz2 + 1e-4
+		end
+		local function overlaps(a, b)
+			local ax1, ax2, az1, az2 = rect(a)
+			local bx1, bx2, bz1, bz2 = rect(b)
+			return ax1 < bx2 and bx1 < ax2 and az1 < bz2 and bz1 < az2
+		end
+		local half = CityLayout.ROAD_WIDTH / 2
+		for _, arm in CityLayout.stopLineApproaches() do
+			local spec
+			for _, s in blueprint.Parts do
+				if s.Name == arm.Name then
+					spec = s
+				end
+			end
+			Assert.truthy(spec ~= nil, arm.Name)
+			Assert.near(spec.Center.Y + spec.Size.Y / 2, 0.25, 1e-4, `{arm.Name} top`)
+			Assert.near(spec.Size.Y, 0.05, 1e-4, `{arm.Name} thickness`)
+			Assert.near(math.max(spec.Size.X, spec.Size.Z), 16.4, 1e-4, `{arm.Name} length`) -- Vector3 is single precision
+			Assert.near(math.min(spec.Size.X, spec.Size.Z), 1.2, 1e-4, `{arm.Name} depth`)
+			Assert.equal(spec.CanCollide, false)
+			Assert.equal(spec.Color, Color3.fromRGB(235, 235, 235))
+			Assert.equal(spec.Material, Enum.Material.SmoothPlastic)
+			local onRoad = false
+			for _, r in blueprint.Parts do
+				if r.Group == "Roads" and inside(spec, r) then
+					onRoad = true
+				end
+			end
+			Assert.truthy(onRoad, `{arm.Name} not fully on one road part`)
+			for _, m in blueprint.Parts do
+				if m.Name:match("^Line") then
+					Assert.truthy(not overlaps(spec, m), `{arm.Name} overlaps {m.Name}`)
+				end
+			end
+			-- 2 studs before the square, on the incoming (right-hand) half
+			local dx, dz = spec.Center.X - arm.X, spec.Center.Z - arm.Z
+			local near = half + 2
+			if arm.Side == "N" then
+				Assert.near(dz + 0.6, -near, 1e-4, arm.Name)
+				Assert.truthy(dx < 0, `{arm.Name} wrong half`)
+			elseif arm.Side == "S" then
+				Assert.near(dz - 0.6, near, 1e-4, arm.Name)
+				Assert.truthy(dx > 0, `{arm.Name} wrong half`)
+			elseif arm.Side == "W" then
+				Assert.near(dx + 0.6, -near, 1e-4, arm.Name)
+				Assert.truthy(dz > 0, `{arm.Name} wrong half`)
+			else
+				Assert.near(dx - 0.6, near, 1e-4, arm.Name)
+				Assert.truthy(dz < 0, `{arm.Name} wrong half`)
+			end
+		end
+	end,
 }
```
