-- Review 3 (research\review3_levelguide.md, finding 1): a running timed quest whose next spot is on another map
-- goes first, and keeps where it is, so the travel planner can show the way there. Before, PutTimedFirst made a
-- bare step with no map, no goal and no arrow, and it stayed on top until the timer ran out. ADDON_PATH = LevelGuide.
local M = dofile("lg_mock.lua")
LevelGuideDB = { characters = { ["Juan-R"] = { done = {}, skips = {}, visited = {} } } }
local timed = { [777] = { 900, 30 } }
C_QuestLog.GetTimeAllowed = function(id) local t = timed[id] if t then return t[1], t[2] end end
C_QuestLog.GetNextWaypoint = function(id) if id == 777 then return 1439, 0.5, 0.5 end end
M.load(ADDON_PATH, function()
    LevelGuideRoutes.chains.NightElf = { { zone = "Teldrassil", min = 1, max = 20, steps = {
        { t = "accept", q = "Tree Quest", npc = "Npc T", x = 55, y = 60, lvl = 2 },
    } } }
    LevelGuideQuestIDs = { ids = { ["Tree Quest"] = { 9100 } }, renamed = {} }
    LevelGuidePrereqs = {}
end)
M.level = 12
M.log = { { questID = 777, title = "Hurry To Darkshore", level = 12 } }
M.titles[777] = "Hurry To Darkshore"
M.update()
local step = M.current.step
assert(step and step.id == 777, "the timed quest goes first: " .. tostring(step and step.title))
assert(step.goalMap == 1439 and math.abs(step.goalX - 50) < 1e-6 and math.abs(step.goalY - 50) < 1e-6,
    "its goal is where the game says: " .. tostring(step.goalMap))
-- The travel planner takes it from there: the way to Darkshore starts at the portal in Darnassus.
assert(step.leg ~= nil and step.mapID ~= nil, "a travel leg with an arrow: " .. tostring(step.detail))
assert(tostring(step.detail):find("Timed", 1, true), "still says it's timed: " .. tostring(step.detail))
print("1 ok")

-- On its own map, the quest's spot is used as it is.
M.best, M.pos = 1439, { [1439] = { 0.4, 0.4 } }
M.fire("ZONE_CHANGED_NEW_AREA")
M.update()
step = M.current.step
assert(step and step.id == 777 and step.mapID == 1439 and math.abs(step.x - 0.5) < 1e-6, "spot on this map")
assert(#M.handled == 0, "clean: " .. tostring(M.handled[1]))
print("ALL TESTS PASSED")
