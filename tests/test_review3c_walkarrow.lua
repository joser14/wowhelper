-- Review 3 (research\review3_levelguide.md, finding 3): a step on a neighbouring map (Routes.lua On()) that you
-- reach quickest on foot gets an arrow straight at it across the border. Before, the travel planner found "walk"
-- and left the step with no spot on your map, so the arrow was hidden ("other zone"). ADDON_PATH = LevelGuide.
local M = dofile("lg_mock.lua")
LevelGuideDB = { characters = { ["Juan-R"] = { done = {}, skips = {}, visited = {} } } }
M.info[1415] = { mapID = 1415, name = "Eastern Kingdoms", mapType = 2, parentMapID = 947 }
M.info[1429] = { mapID = 1429, name = "Elwynn Forest", mapType = 3, parentMapID = 1415 }
M.info[1453] = { mapID = 1453, name = "Stormwind City", mapType = 3, parentMapID = 1415 }
M.rects[1429] = { 20000, 20000, 3500, 2300 }
M.load(ADDON_PATH, function()
    LevelGuideRoutes.chains.NightElf = { { zone = "Elwynn Forest", min = 1, max = 20, steps = {
        { t = "go", text = "Enter Stormwind", map = "Stormwind City", x = 60, y = 75 },
    } } }
    LevelGuideQuestIDs = { ids = {}, renamed = {} }
    LevelGuidePrereqs = {}
end)
M.level = 8
M.best, M.pos = 1429, { [1429] = { 0.42, 0.65 } }
M.fire("ZONE_CHANGED_NEW_AREA")
M.update()
local step = M.current.step
assert(step and step.title == "Enter Stormwind", "the move: " .. tostring(step and step.title))
assert(step.mapID == 1429, "a spot on the map you're on: " .. tostring(step.mapID))
-- Where Stormwind 60, 75 is on Elwynn's map, from Travel.lua's world frames.
local T = LevelGuideTravel
local c, wx, wy = LevelGuidePlanner.TravelWorld(1453, 60, 75)
local f = T.frames[1429]
local ex, ey = (wy - f[2]) / (f[3] - f[2]), (wx - f[4]) / (f[5] - f[4])
assert(c == f[1] and math.abs(step.x - ex) < 1e-6 and math.abs(step.y - ey) < 1e-6,
    string.format("projected: %.3f,%.3f vs %.3f,%.3f", step.x, step.y, ex, ey))
M.update(0.06)
assert(M.arrowShown(), "the arrow points at it")
assert(#M.handled == 0, "clean: " .. tostring(M.handled[1]))
print("ALL TESTS PASSED")
