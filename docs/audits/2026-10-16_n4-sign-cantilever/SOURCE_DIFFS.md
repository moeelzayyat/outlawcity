# Source diffs: 2026-10-16_n4-sign-cantilever

Commit range `b8c27cf..bb7cb55` (source). Studio matches `src/` for every changed script (hash-checked: CityLayout `b5f21c41`, CityLayout.spec `d00b3e6e`; CityBuilder `3c5c8451` and WorldService `a91b95db` unchanged).

## `src/ServerScriptService/Server/World/CityLayout.luau`

```diff
diff --git a/src/ServerScriptService/Server/World/CityLayout.luau b/src/ServerScriptService/Server/World/CityLayout.luau
index 27bd98f..ce2b5f1 100644
--- a/src/ServerScriptService/Server/World/CityLayout.luau
+++ b/src/ServerScriptService/Server/World/CityLayout.luau
@@ -344,8 +344,10 @@ export type StreetSignLabel = { Part: string, Text: string, Faces: { Enum.Normal
 export type StreetSignSpec = { Name: string, X: number, Z: number, Parts: { PartSpec }, Labels: { StreetSignLabel } }
 
 -- One post and two perpendicular blades on a sidewalk corner. Each blade runs along the street
--- it names and carries the name on both faces, so drivers read it from both directions. All
--- parts are visual only (CityBuilder.buildStreetSigns turns off collision, query, touch, shadow).
+-- it names and carries the name on both faces, so drivers read it from both directions. The
+-- blades are cantilevered: each starts at a post face and extends away from the junction, so the
+-- post never covers the text. All parts are visual only (CityBuilder.buildStreetSigns turns off
+-- collision, query, touch, shadow).
 function CityLayout.streetSigns(): { StreetSignSpec }
 	local result = {}
 	local post = CityLayout.STREET_SIGN_POST
@@ -353,17 +355,20 @@ function CityLayout.streetSigns(): { StreetSignSpec }
 	local postColor, bladeColor = Color3.fromRGB(110, 110, 110), Color3.fromRGB(0, 102, 51)
 	for _, sign in CityLayout.STREET_SIGNS do
 		local x, z = sign.X + sign.CornerX, sign.Z + sign.CornerZ
-		local function part(name: string, y: number, size: Vector3, color: Color3): PartSpec
-			return { Name = name, Group = "StreetSigns", Center = Vector3.new(x, y, z), Size = size, Color = color, Material = Enum.Material.SmoothPlastic, CanCollide = false }
+		-- Away from the junction (towards the inside of the block).
+		local reachX = math.sign(sign.CornerX) * (post.X / 2 + length / 2)
+		local reachZ = math.sign(sign.CornerZ) * (post.Z / 2 + length / 2)
+		local function part(name: string, px: number, y: number, pz: number, size: Vector3, color: Color3): PartSpec
+			return { Name = name, Group = "StreetSigns", Center = Vector3.new(px, y, pz), Size = size, Color = color, Material = Enum.Material.SmoothPlastic, CanCollide = false }
 		end
 		table.insert(result, {
 			Name = `StreetSign_{sign.X}_{sign.Z}`,
 			X = sign.X,
 			Z = sign.Z,
 			Parts = {
-				part("Post", CityLayout.CURB_TOP + post.Y / 2, post, postColor),
-				part("Blade_EW", CityLayout.STREET_SIGN_EW_Y, Vector3.new(length, height, thick), bladeColor),
-				part("Blade_NS", CityLayout.STREET_SIGN_NS_Y, Vector3.new(thick, height, length), bladeColor),
+				part("Post", x, CityLayout.CURB_TOP + post.Y / 2, z, post, postColor),
+				part("Blade_EW", x + reachX, CityLayout.STREET_SIGN_EW_Y, z, Vector3.new(length, height, thick), bladeColor),
+				part("Blade_NS", x, CityLayout.STREET_SIGN_NS_Y, z + reachZ, Vector3.new(thick, height, length), bladeColor),
 			},
 			Labels = {
 				{ Part = "Blade_EW", Text = CityLayout.STREET_NAMES_EW[sign.Z], Faces = { Enum.NormalId.Front, Enum.NormalId.Back } },
```

## `src/ServerStorage/Tests/CityLayout.spec.luau`

```diff
diff --git a/src/ServerStorage/Tests/CityLayout.spec.luau b/src/ServerStorage/Tests/CityLayout.spec.luau
index 6af5de3..bc8fb88 100644
--- a/src/ServerStorage/Tests/CityLayout.spec.luau
+++ b/src/ServerStorage/Tests/CityLayout.spec.luau
@@ -328,8 +328,8 @@ return {
 					Assert.truthy(g >= 3, `{part.Name} within 3 studs of {spec.Name}`)
 				end
 			end
-			-- Measured face to road edge: the post 3.8 studs, the blades 0.5 stud (overhead).
-			Assert.near(nearestRoad, if part.Name == "Post" then 3.8 else 0.5, 1e-4, `{part.Name} distance to the nearest road edge`)
+			-- Measured face to road edge: the post 3.8 studs, the cantilevered blades 3.9 studs.
+			Assert.near(nearestRoad, if part.Name == "Post" then 3.8 else 3.9, 1e-4, `{part.Name} distance to the nearest road edge`)
 		end
 		local post = sign.Parts[1]
 		for _, spawn in blueprint.Spawns do
@@ -337,4 +337,39 @@ return {
 			Assert.truthy(d >= 3 + 9, `sign within reach of vehicle pad {spawn.Name}`) -- pad half-diagonal < 9
 		end
 	end,
+	["street signs: blades are cantilevered off the post, so the post covers no text"] = function()
+		local sign = CityLayout.streetSigns()[1]
+		local parts = {}
+		for _, part in sign.Parts do
+			parts[part.Name] = part
+		end
+		local post, ew, ns = parts.Post, parts.Blade_EW, parts.Blade_NS
+		local function box(p)
+			local c, s = p.Center, p.Size
+			return c.X - s.X / 2, c.X + s.X / 2, c.Y - s.Y / 2, c.Y + s.Y / 2, c.Z - s.Z / 2, c.Z + s.Z / 2
+		end
+		local function sharedVolume(a, b)
+			local ax1, ax2, ay1, ay2, az1, az2 = box(a)
+			local bx1, bx2, by1, by2, bz1, bz2 = box(b)
+			return math.max(0, math.min(ax2, bx2) - math.max(ax1, bx1)) * math.max(0, math.min(ay2, by2) - math.max(ay1, by1)) * math.max(0, math.min(az2, bz2) - math.max(az1, bz1))
+		end
+		Assert.near(sharedVolume(ew, post), 0, 1e-6, "EW blade passes through the post")
+		Assert.near(sharedVolume(ns, post), 0, 1e-6, "NS blade passes through the post")
+		Assert.near(sharedVolume(ew, ns), 0, 1e-6, "blades intersect")
+		-- Each blade starts at the post face on the side away from the junction (the corner is +X/+Z).
+		local px1, px2, _, _, pz1, pz2 = box(post)
+		local ex1, _, _, _, ez1, ez2 = box(ew)
+		local nx1, nx2, _, _, nz1 = box(ns)
+		Assert.near(ex1, px2, 1e-4, "EW blade starts at the post's +X face")
+		Assert.near(nz1, pz2, 1e-4, "NS blade starts at the post's +Z face")
+		Assert.truthy(ez1 >= pz1 - 1e-4 and ez2 <= pz2 + 1e-4, "EW blade stays within the post's depth")
+		Assert.truthy(nx1 >= px1 - 1e-4 and nx2 <= px2 + 1e-4, "NS blade stays within the post's width")
+		-- Unchanged from the approved prototype: post position, blade and text sizes.
+		Assert.near(post.Center.X, 122, 1e-4, "post x")
+		Assert.near(post.Center.Z, 122, 1e-4, "post z")
+		Assert.near(ew.Center.X, 125.7, 1e-4, "EW centre x")
+		Assert.near(ew.Center.Z, 122, 1e-4, "EW centre z")
+		Assert.near(ns.Center.X, 122, 1e-4, "NS centre x")
+		Assert.near(ns.Center.Z, 125.7, 1e-4, "NS centre z")
+	end,
 }
```
