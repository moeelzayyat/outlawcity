-- New-player guidance helpers (audit 4 onboarding batch).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local OnboardingRules = require(ReplicatedStorage.Shared.Onboarding.OnboardingRules)
local OnboardingConfig = require(ReplicatedStorage.Shared.Config.OnboardingConfig)
local RobberyConfig = require(ReplicatedStorage.Shared.Config.RobberyConfig)
local DealershipConfig = require(ReplicatedStorage.Shared.Config.DealershipConfig)
local EconomyConfig = require(ReplicatedStorage.Shared.Config.EconomyConfig)
local WantedConfig = require(ReplicatedStorage.Shared.Config.WantedConfig)
local Assert = require(script.Parent.Assert)

local function money(n: number): string
	return "$" .. tostring(n)
end

return {
	["P1: one owned car spawns directly; two or more open the garage"] = function()
		local starters = EconomyConfig.StarterVehicles
		local action, id = OnboardingRules.spawnChoice({ "Coupe" }, starters)
		Assert.equal(action, "Spawn")
		Assert.equal(id, "Coupe")
		action, id = OnboardingRules.spawnChoice({ "Coupe", "Muscle" }, starters)
		Assert.equal(action, "Choose")
		Assert.equal(id, nil)
	end,
	["P1: a stale selection is never sent; the only owned car is"] = function()
		-- e.g. "Muscle" was selected earlier but the list now holds one other car
		local action, id = OnboardingRules.spawnChoice({ "Coupe" }, {})
		Assert.equal(action, "Spawn")
		Assert.equal(id, "Coupe")
		action, id = OnboardingRules.spawnChoice({ "Muscle" }, { "Coupe" })
		Assert.equal(id, "Muscle", "owned list wins over the starter list")
	end,
	["P1: not loaded yet uses only the starter car; nothing at all sends nothing"] = function()
		local action, id = OnboardingRules.spawnChoice({}, EconomyConfig.StarterVehicles)
		Assert.equal(action, "Spawn")
		Assert.equal(id, "Coupe", "the server always accepts starter cars")
		action, id = OnboardingRules.spawnChoice({}, {})
		Assert.equal(action, "None")
		Assert.equal(id, nil)
	end,
	["P3: the tip closes only for a running robbery"] = function()
		Assert.equal(OnboardingRules.isActiveRobbery("Holding"), true)
		Assert.equal(OnboardingRules.isActiveRobbery("Escaping"), true)
		Assert.equal(OnboardingRules.isActiveRobbery(nil), false)
		Assert.equal(OnboardingRules.isActiveRobbery("PayoutPending"), false)
		Assert.equal(OnboardingRules.isActiveRobbery("Failed"), false)
		Assert.equal(OnboardingRules.isActiveRobbery(5), false)
	end,
	["P2: markers show between the hide and max distance only"] = function()
		local c = OnboardingConfig
		Assert.equal(OnboardingRules.markerVisible(c.MarkerHideDistance - 1, c), false, "already there")
		Assert.equal(OnboardingRules.markerVisible(c.MarkerHideDistance, c), true)
		Assert.equal(OnboardingRules.markerVisible(150, c), true, "spawn to store is ~150 studs")
		Assert.equal(OnboardingRules.markerVisible(240, c), true, "spawn to dealership is ~240 studs")
		Assert.equal(OnboardingRules.markerVisible(c.MarkerMaxDistance + 1, c), false)
		Assert.equal(OnboardingRules.markerVisible(0 / 0, c), false)
		Assert.equal(OnboardingRules.formatDistance(151), "150 studs")
		Assert.equal(OnboardingRules.formatDistance(237), "240 studs")
	end,
	["P4: the escape hint matches the wanted rules"] = function()
		-- Heat only decays after DecayDelay unseen seconds; the escape counts when stars reach 0.
		Assert.equal(WantedConfig.DecayDelay, 8, "pursuit tuning unchanged")
		local before = OnboardingRules.escapeHint(false, 2)
		Assert.truthy(before:find("line of sight", 1, true) ~= nil, before)
		Assert.truthy(before:find("stars are gone", 1, true) ~= nil, before)
		local evading = OnboardingRules.escapeHint(true, 1)
		Assert.truthy(evading:find("fading", 1, true) ~= nil, evading)
		Assert.equal(OnboardingRules.escapeHint(true, 0), before, "no stars: no 'fading' claim")
	end,
	["P5: store status and reopen clock"] = function()
		Assert.equal(OnboardingRules.formatClock(90), "1:30")
		Assert.equal(OnboardingRules.formatClock(0.2), "0:01")
		Assert.equal(OnboardingRules.formatClock(-5), "0:00")
		Assert.equal(OnboardingRules.storeStatus(nil, false, 100), "Open: rob the register")
		Assert.equal(OnboardingRules.storeStatus(0, false, 100), "Open: rob the register")
		Assert.equal(OnboardingRules.storeStatus(190, false, 100), "Reopens in 1:30")
		Assert.equal(OnboardingRules.storeStatus(190, true, 100), "Being robbed")
	end,
	["P6: eight successful robberies buy the Muscle from the $500 start"] = function()
		local price = DealershipConfig.priceOf("Muscle") :: number
		Assert.equal(price, 15000, "price unchanged until human playtests")
		Assert.equal(EconomyConfig.StartingCash, 500)
		Assert.equal(RobberyConfig.Reward, 2000)
		Assert.equal(OnboardingRules.robberiesNeeded(500, price, 2000), 8) -- 7 leaves you at $14,500
		Assert.equal(OnboardingRules.robberiesNeeded(500 + 7 * 2000, price, 2000), 1)
		Assert.equal(OnboardingRules.robberiesNeeded(15000, price, 2000), 0)
		Assert.equal(OnboardingRules.robberiesNeeded(20000, price, 2000), 0)
		Assert.equal(OnboardingRules.robberiesNeeded(500, price, 0), 0, "no reward: no division by zero")
		Assert.equal(OnboardingRules.progressText("Muscle", 500, price, 2000, money), "Muscle: $500 of $15000. About 8 more successful robberies.")
		Assert.equal(OnboardingRules.progressText("Muscle", 13500, price, 2000, money), "Muscle: $13500 of $15000. About 1 more successful robbery.")
		Assert.equal(OnboardingRules.progressText("Muscle", 15000, price, 2000, money), "You can afford the Muscle!")
	end,
	["P7: compact robbery panel on phone screens stays within 7% and readable"] = function()
		local c = OnboardingConfig
		local phone = OnboardingRules.robberyPanelLayout(374, c) -- iPhone 7 landscape (666 x 374)
		Assert.equal(phone, c.CompactPanel)
		Assert.truthy(phone.Width * phone.Height / (666 * 374) <= 0.07, "panel <= 7% of the screen")
		Assert.truthy(phone.Y >= 92, "below the top HUD row (buttons 8-52, stars/cash 58-84)")
		Assert.truthy(phone.DetailSize >= c.MinTextSize and phone.TitleSize >= c.MinTextSize, "text >= 14 px")
		Assert.equal(OnboardingRules.robberyPanelLayout(720, c), c.FullPanel)
	end,
	["P8: each milestone is recorded once, from the join time"] = function()
		local m = OnboardingRules.newMilestones(10)
		Assert.equal(OnboardingRules.markMilestone(m, "FirstCar", 16.5), 6.5)
		Assert.equal(OnboardingRules.markMilestone(m, "FirstCar", 30), nil, "only the first time")
		Assert.equal(OnboardingRules.markMilestone(m, "FirstRobbery", 40), 30)
		Assert.equal(#OnboardingConfig.Milestones, 3)
	end,
}
