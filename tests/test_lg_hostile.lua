-- Hostile towns on travel legs (research\re_round3.md rank 17, after Shortest Path Forever's hazards, GPL):
-- * a Horde flight master with no Alliance one within 400 yd is a hostile town, a 150 yd circle; walking through
--   it costs 6x for choosing the way (the time shown stays real), except a town you start or end in;
-- * the plan names what it passes: "Careful: hostile Crossroads on the way", "Crosses Duskwood (18-30)";
-- * a level-up replans with the new level. ADDON_PATH = LevelGuide.
local M = dofile("lg_mock.lua")
LevelGuideDB = { characters = { ["Juan-R"] = { done = {}, skips = {}, visited = {} } } }
M.load(ADDON_PATH, function() end)
local P, T = LevelGuidePlanner, LevelGuideTravel
assert(T.hostile and #T.hostile > 10, "hostile towns listed")
local names = {}
for _, town in ipairs(T.hostile) do names[town.name] = true end
assert(names["Crossroads"] and names["Tarren Mill"] and not names["Booty Bay"] and not names["Gadgetzan"]
    and not names["Moonglade"], "neutral towns with an Alliance flight master are not hostile")

-- 1. A long walk across The Barrens past the Crossroads (51.5, 30.4) goes round it (here by Ratchet's dock).
local yards = P.TravelYards({ map = 1413, x = 45, y = 30.4 }, { map = 1413, x = 58, y = 30.4 })
local round = P.TravelPlan({ from = { map = 1413, x = 45, y = 30.4 }, to = { map = 1413, x = 58, y = 30.4 }, level = 20 })
assert(round.total > yards * 1.25 / 7 + 1 and not table.concat(round.notes, ";"):find("Crossroads", 1, true),
    "went round: " .. round.total)
-- A short one straight through: it costs more than it takes, and it's named.
local through = P.TravelPlan({ from = { map = 1413, x = 49, y = 30.4 }, to = { map = 1413, x = 54, y = 30.4 }, level = 20 })
assert(through and through.cost > through.total + 1, "costs more than it takes: " .. tostring(through and through.cost))
assert(table.concat(through.notes, ";"):find("Careful: hostile Crossroads on the way", 1, true), "named")
yards = P.TravelYards({ map = 1413, x = 49, y = 30.4 }, { map = 1413, x = 54, y = 30.4 })
assert(math.abs(through.total - yards * 1.25 / 7) < 1, "real time shown: " .. through.total)
-- Away from it: no note, no extra cost.
local clear = P.TravelPlan({ from = { map = 1413, x = 45, y = 60 }, to = { map = 1413, x = 58, y = 60 }, level = 20 })
assert(math.abs(clear.cost - clear.total) < 1e-6 and #(clear.notes or {}) == 0, "clear way")
-- Ending in the town: no penalty for its own circle.
local into = P.TravelPlan({ from = { map = 1413, x = 45, y = 30.4 }, to = { map = 1413, x = 51.5, y = 30.4 }, level = 20 })
assert(math.abs(into.cost - into.total) < 1e-6, "going into the town itself")
print("1 ok")

-- 2. A dangerous zone crossed is named with its levels.
-- Elwynn to northern Stranglethorn at level 5 goes through Westfall (10-20).
local dusk = P.TravelPlan({ from = { map = 1429, x = 40, y = 80 }, to = { map = 1434, x = 40, y = 20 }, level = 5 })
assert(dusk, "a plan")
print("2: " .. table.concat(dusk.notes or {}, "; "))
assert(table.concat(dusk.notes or {}, ";"):find("Crosses Westfall (10-20)", 1, true), "zone note")
print("2 ok")

-- 3. PLAYER_LEVEL_UP replans with the event's level (UnitLevel can lag).
local levels = {}
local plan = P.TravelPlan
P.TravelPlan = function(opts) levels[#levels + 1] = opts.level return plan(opts) end
LevelGuideRoutes.chains.NightElf = { { zone = "Darkshore", min = 1, max = 30, steps = {
    { t = "accept", q = "Shore Quest", npc = "Npc A", x = 38, y = 44, lvl = 12 } } } }
M.level = 12
M.fire("ZONE_CHANGED_NEW_AREA")
M.update()
M.fire("PLAYER_LEVEL_UP", 13)
M.update()
assert(levels[#levels] == 13, "replanned at 13: " .. tostring(levels[#levels]))
P.TravelPlan = plan
assert(#M.handled == 0, "clean: " .. tostring(M.handled[1]))
print("ALL TESTS PASSED")
