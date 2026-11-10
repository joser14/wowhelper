-- Review 3 (research\review3_levelguide.md, finding 2): "a move before the start is passed when you stand within
-- 150 yd of the start" must measure to where the start really is. A start written "Name, Darnassus" uses
-- Darnassus's own map; before, its numbers were read on Teldrassil's map, so standing at the same numbers on
-- Teldrassil (far from the city) passed the move. ADDON_PATH = LevelGuide.
local M = dofile("lg_mock.lua")
LevelGuideDB = { characters = { ["Juan-R"] = { done = {}, skips = {}, visited = {} } } }
M.load(ADDON_PATH, function()
    LevelGuideRoutes.chains.NightElf = { { zone = "Teldrassil", min = 1, max = 20, steps = {
        { t = "go", text = "Go up to Darnassus", x = 30, y = 50 },
        { t = "accept", q = "City Quest", npc = "Sentinel, Darnassus", x = 40, y = 50, lvl = 5 },
    } } }
    LevelGuideQuestIDs = { ids = { ["City Quest"] = { 9200 } }, renamed = {} }
    LevelGuidePrereqs = {}
end)
M.level = 8
-- Teldrassil 40, 50 is about 450 yd from Darnassus 40, 50 (Teldrassil 31, 52.5 in the mock).
M.best, M.pos = 1438, { [1438] = { 0.40, 0.50 } }
M.update()
local step = M.current.step
assert(step and step.title == "Go up to Darnassus", "the move stays: " .. tostring(step and step.title))
print("1 ok")

-- Standing by the giver (Teldrassil 31, 52.5 is Darnassus 40, 50): the move is behind you.
M.pos = { [1438] = { 0.31, 0.525 } }
M.update()
step = M.current.step
assert(step and step.title == "City Quest", "near the real start: " .. tostring(step and step.title))
assert(#M.handled == 0, "clean: " .. tostring(M.handled[1]))
print("ALL TESTS PASSED")
