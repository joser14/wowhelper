-- Spawn camps for "do" steps (research\guides_deep_re.md 1.7 and 12.8): with QuestDB camps for the quest on
-- this map, the arrow points at the nearest camp not yet checked (switching only for one more than 25% and
-- 40 yd nearer). A camp is checked once you've been in it and left it, or stood still 7 s in it with no
-- objective progress and no fight; checked camps are skipped for 300 s, and when all are checked the
-- circuit starts again. ADDON_PATH = LevelGuide.
local M = dofile("lg_mock.lua")
LevelGuideDB = { characters = { ["Juan-R"] = { done = {}, skips = {}, visited = {} } } }
M.best, M.pos, M.level = 1438, { [1438] = { 0.5, 0.47 } }, 6
LevelGuideQuestFacts = { Quest = function(id)
    if id == 601 then
        return { id = 601, level = 5, objectives = { { kind = "kill", spots = {
            { map = 1438, x = 50, y = 40, r = 20, n = 5 },
            { map = 1438, x = 50, y = 60, r = 20, n = 5 },
            { map = 1438, x = 30, y = 40, r = 20, n = 3 },
            { map = 1439, x = 50, y = 50, r = 20, n = 9 },   -- another map: not used here
        } } } }
    end
end }
M.load(ADDON_PATH, function()
    LevelGuideRoutes.chains.NightElf = { { zone = "Teldrassil", min = 1, max = 20, steps = {
        { t = "do", q = "Boars", note = "Kill boars", x = 45, y = 45, lvl = 5 },
    } } }
    LevelGuideQuestIDs = { ids = { Boars = { 601 } }, renamed = {} }
    LevelGuidePrereqs = {}
end)
M.log = { { questID = 601, title = "Boars" } }
M.obj[601] = { { text = "Boar: 0/8", finished = false, numFulfilled = 0, numRequired = 8 } }
M.fire("QUEST_LOG_UPDATE")   -- the log has loaded (as at login)
local function step() return M.current.step end
local function at(x, y, seconds)
    M.pos[1438] = { x, y }
    M.now = M.now + (seconds or 0)
    M.update()
end
local P = LevelGuidePlanner

-- 1. The nearest camp, not the hand-written spot; the detail says which.
M.update()
assert(step().campIndex == 1 and math.abs(step().x - 0.5) < 1e-9 and math.abs(step().y - 0.4) < 1e-9, "camp 1: " .. tostring(step().campIndex))
assert(step().campCount == 3 and tostring(step().detail):find("camp 1 of 3", 1, true), "detail: " .. tostring(step().detail))
assert(step().campRadius == 20, "arrival radius is the camp's")
print("1 ok")

-- 2. Hysteresis: camp 2 only 50 yd nearer (under 25%): stay; far nearer: switch.
at(0.5, 0.505)
assert(step().campIndex == 1, "keep camp 1 (525 vs 475 yd)")
at(0.5, 0.53)
assert(step().campIndex == 2, "switch to camp 2 (650 vs 350 yd)")
at(0.5, 0.47)
assert(step().campIndex == 1, "back to 1 when far nearer")
print("2 ok")

-- 3. Dwell: 7 s standing in camp 1 with no progress checks it; the arrow moves on to camp 2.
at(0.5, 0.40)
assert(step().campIndex == 1, "in camp 1")
at(0.5, 0.40, 4)
assert(step().campIndex == 1, "4 s: still here")
-- Progress resets the clock.
M.obj[601][1].numFulfilled = 1
M.fire("QUEST_LOG_UPDATE")
at(0.5, 0.40, 4)
assert(step().campIndex == 1, "progress: stay")
at(0.5, 0.40, 8)
assert(step().campIndex == 2, "8 s without progress: on to camp 2: " .. tostring(step().campIndex))
print("3 ok")

-- 4. Leaving a camp you were in checks it too: camp 2 entered then left; the next is camp 3 (1 and 2 checked).
at(0.5, 0.60, 1)
assert(step().campIndex == 2, "in camp 2")
at(0.5, 0.65, 1)
assert(step().campIndex == 3, "left camp 2: camp 3 (1 is checked): " .. tostring(step().campIndex))
print("4 ok")

-- 5. Checked camps come back after 300 s.
at(0.5, 0.47, 301)
assert(step().campIndex == 1, "camp 1 forgotten after 300 s: " .. tostring(step().campIndex))
print("5 ok")

-- 6. Without camps on this map the written spot is used.
LevelGuideQuestFacts.Quest = function() return nil end
M.update()
assert(not step().campIndex and math.abs(step().x - 0.45) < 1e-9, "written spot")
assert(P.CAMP.dwellSeconds == 7, "planner constants")
assert(#M.handled == 0, "clean: " .. tostring(M.handled[1]))
print("ALL TESTS PASSED")
