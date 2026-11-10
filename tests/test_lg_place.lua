-- Placement from live state (research\guides_deep_re.md 12.2): the guide places you from your quest log and
-- completed quests. The anchor is the last route step with real progress (turned in, or objectives under
-- way); holding a quest is not progress. Behind the anchor, utility steps (hearth, training, items) are
-- passed; before the first quest you hold, only moves and unverifiable pick-ups are. A move before a doable
-- pick-up passes only when you stand within 150 yd of it. Skipped steps never count as done, and the
-- anchor holds for the session once the log has loaded. ADDON_PATH = LevelGuide.
local M = dofile("lg_mock.lua")
LevelGuideDB = { characters = { ["Juan-R"] = { done = {}, skips = {}, visited = {} } } }
M.best, M.pos, M.level = 1438, { [1438] = { 0.2, 0.2 } }, 5
local R
M.load(ADDON_PATH, function()
    R = { zone = "Teldrassil", min = 1, max = 20, steps = {
        { t = "accept", q = "Q1", npc = "Giver A", x = 20, y = 20, lvl = 4 },
        { t = "home", text = "Rut'theran", place = "Rut'theran", npc = "Innkeeper", x = 21, y = 21, lvl = 4 },
        { t = "train", text = "Smite", spells = { 999 }, npc = "Trainer", x = 22, y = 22, lvl = 4 },
        { t = "go", text = "Go to the glade", x = 60, y = 60, lvl = 4 },
        { t = "accept", q = "Q2", npc = "Giver B", x = 61, y = 61, lvl = 4 },
        { t = "do", q = "Q2", note = "Kill wolves", x = 62, y = 62, lvl = 4 },
        { t = "turnin", q = "Q2", npc = "Giver B", x = 61, y = 61, lvl = 4 },
        { t = "accept", q = "Q3", npc = "Giver C", x = 63, y = 63, lvl = 4 },
        { t = "do", q = "Q3", note = "Collect", x = 64, y = 64, lvl = 4 },
        { t = "turnin", q = "Q3", npc = "Giver C", x = 63, y = 63, lvl = 4 },
    } }
    LevelGuideRoutes.chains.NightElf = { R }
    LevelGuideQuestIDs = { ids = { Q1 = { 101 }, Q2 = { 102 }, Q3 = { 103 } }, renamed = {} }
    LevelGuidePrereqs = { Q3 = { all = { 102 } } }
end)
assert(LevelGuidePlanner, "Planner.lua is loaded before LevelGuide.lua")
local function rows()
    local t = {}
    for _, b in ipairs(M.buttons) do if b.shown and b.step then t[#t + 1] = b.left.text end end
    return table.concat(t, "\n")
end
local function reset() M.log, M.obj, M.flagged = {}, {}, {}; M.char.skips = {}; M.char.visited = {}; M.char.marks = {} end

-- 1. Holding a later quest (taken out of order, no progress) is not progress: the hearth and training
--    before it are still yours to do. The move before it is passed (you were at its giver).
reset()
M.log = { { questID = 103, title = "Q3" } }
M.obj[103] = { { text = "Thing: 0/5", finished = false, numFulfilled = 0, numRequired = 5 } }
M.update()
assert(rows():find("Set hearth", 1, true), "hearth not passed by a held quest: " .. rows())
assert(rows():find("Train", 1, true), "training not passed by a held quest: " .. rows())
assert(not rows():find("Go to the glade", 1, true), "the move before a held quest's pick-up is passed: " .. rows())
print("1 ok")

-- 2. Real progress anchors: objectives under way on Q2 pass the hearth, training and move before it.
reset()
M.flagged[101] = true
M.log = { { questID = 102, title = "Q2" } }
M.obj[102] = { { text = "Wolves: 3/10", finished = false, numFulfilled = 3, numRequired = 10 } }
M.update()
assert(not rows():find("Set hearth", 1, true) and not rows():find("Train", 1, true), "behind the anchor: " .. rows())
assert(rows():find("Do:|r Q2", 1, true), "work shown: " .. rows())
print("2 ok")

-- 3. The anchor holds for the session once the log has loaded: dropping Q2 doesn't bring the hearth back.
M.fire("QUEST_LOG_UPDATE")
M.update()
M.log, M.obj = {}, {}
M.fire("QUEST_LOG_UPDATE")
M.update()
assert(not rows():find("Set hearth", 1, true), "anchor latched: " .. rows())
print("3 ok")

-- 4. Before the log has loaded nothing latches (a fresh session of the same file: reload the guide).
--    A move before a doable pick-up passes only within 150 yd of that pick-up.
M = dofile("lg_mock.lua")
LevelGuideDB = { characters = { ["Juan-R"] = { done = {}, skips = {}, visited = {} } } }
M.best, M.pos, M.level = 1438, { [1438] = { 0.2, 0.2 } }, 5
M.load(ADDON_PATH, function()
    LevelGuideRoutes.chains.NightElf = { R }
    LevelGuideQuestIDs = { ids = { Q1 = { 101 }, Q2 = { 102 }, Q3 = { 103 } }, renamed = {} }
    LevelGuidePrereqs = { Q3 = { all = { 102 } } }
end)
M.flagged[101] = true
M.char.marks["Teldrassil|home|Rut'theran||Innkeeper"] = true
M.spells[999] = true
M.update()
assert(rows():find("Go to the glade", 1, true), "far from the next pick-up: the move stays: " .. rows())
M.pos[1438] = { 0.605, 0.605 }
M.update()
assert(not rows():find("Go to the glade", 1, true) and rows():find("Q2", 1, true), "within 150 yd of the pick-up: passed: " .. rows())
print("4 ok")

-- 5. Skipped never counts as done: skipping Q2's steps doesn't open Q3 (its prerequisite).
M.pos[1438] = { 0.61, 0.61 }
for _, b in ipairs(M.buttons) do
    if b.shown and b.step and b.step.quest == "Q2" then
        M.char.skips[b.step.routeKey] = true
    end
end
M.update()
assert(not rows():find("Q3", 1, true), "Q3 needs Q2 turned in, not skipped: " .. rows())
assert(#M.handled == 0, "clean: " .. tostring(M.handled[1]))
print("ALL TESTS PASSED")
