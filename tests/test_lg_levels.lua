-- Server quest levels (research\guides_deep_re.md 4.1 and 12.9): a slow scan of the route's quests, one every
-- 0.5 s from 60 s after login, never in combat: C_QuestLog.RequestLoadQuestByID, then (on QUEST_DATA_LOAD_RESULT
-- or after 5 s) C_QuestLog.GetQuestDifficultyLevel, kept account-wide when it differs from QuestDB and reset on
-- a new client build. A failed load is not "missing": nothing is hidden. The kept level is used for the
-- XP projection and the hard-quest flag. ADDON_PATH = LevelGuide.
local M = dofile("lg_mock.lua")
LevelGuideDB = { characters = { ["Juan-R"] = { done = {}, skips = {}, visited = {} } } }
M.best, M.pos, M.level = 1438, { [1438] = { 0.5, 0.5 } }, 5
local requested, server, build = {}, { [701] = 9, [702] = 5 }, "70532"
C_QuestLog.RequestLoadQuestByID = function(id) requested[#requested + 1] = id end
C_QuestLog.GetQuestDifficultyLevel = function(id) return server[id] end
GetBuildInfo = function() return "1.60.1", build, "Nov 1 2026", 16001 end
LevelGuideQuestFacts = { Quest = function(id) if id >= 701 and id <= 703 then return { id = id, level = 5, objectives = {} } end end }
local R
M.load(ADDON_PATH, function()
    R = { zone = "Teldrassil", min = 1, max = 20, steps = {
        { t = "accept", q = "Q1", npc = "A", x = 51, y = 50, lvl = 5 },
        { t = "accept", q = "Q2", npc = "B", x = 52, y = 50, lvl = 5 },
        { t = "accept", q = "Q3", npc = "C", x = 53, y = 50, lvl = 5 },
        { t = "turnin", q = "Q1", npc = "A", x = 51, y = 50, lvl = 5 },
    } }
    LevelGuideRoutes.chains.NightElf = { R }
    LevelGuideQuestIDs = { ids = { Q1 = { 701 }, Q2 = { 702 }, Q3 = { 703 } }, renamed = {} }
    LevelGuidePrereqs = {}
end)
local function run(seconds, step)
    step = step or 0.5
    for _ = 1, math.floor(seconds / step + 0.5) do
        M.now = M.now + step
        M.update(step)
    end
end
local function rows()
    local t = {}
    for _, b in ipairs(M.buttons) do if b.shown and b.step then t[#t + 1] = b.left.text end end
    return table.concat(t, "\n")
end

-- 1. Nothing in the first minute.
run(59)
assert(#requested == 0, "waits 60 s after login: " .. #requested)
print("1 ok")

-- 2. Then one quest per 0.5 s at most, and never in combat.
UnitAffectingCombat = function() return true end
run(5)
assert(#requested == 0, "never in combat")
UnitAffectingCombat = nil
run(0.5)
assert(#requested == 1 and requested[1] == 701, "first request: " .. tostring(requested[1]))
run(0.5)
assert(#requested == 1, "waits for the answer (up to 5 s)")
M.fire("QUEST_DATA_LOAD_RESULT", 701, true)
run(0.5)
local kept = LevelGuideDB.serverLevels
assert(kept and kept.levels[701] == 9, "differs from QuestDB: kept")
run(0.5)
assert(#requested == 2 and requested[2] == 702, "next: " .. tostring(requested[2]))
M.fire("QUEST_DATA_LOAD_RESULT", 702, true)
run(1)
assert(kept.levels[702] == nil, "same as QuestDB: not kept")
print("2 ok")

-- 3. A failed load: no level, and the quest is not treated as missing (its pick-up still shows).
assert(requested[3] == 703, "third: " .. tostring(requested[3]))
M.fire("QUEST_DATA_LOAD_RESULT", 703, false)
run(1)
assert(kept.levels[703] == nil, "nothing kept")
assert(rows():find("Q3", 1, true), "still on the route: " .. rows())
run(10)
assert(#requested == 3, "each quest once: " .. #requested)
print("3 ok")

-- 4. The kept level is the quest's level: Q1 at 9 is 3+ above level 5... a pick-up 4 above is flagged.
M.log = { { questID = 701, title = "Q1" } }
R.steps[5] = { t = "do", q = "Q1", note = "Work", x = 54, y = 50, lvl = 5 }
M.obj[701] = { { text = "x: 0/5", finished = false, numFulfilled = 0, numRequired = 5 } }
M.update()
assert(rows():find("Do:|r Q1 |cffff4040Hard (level 9)", 1, true), "server level used: " .. rows())
print("4 ok")

-- 5. A new client build starts over (at the next login).
build = "70999"
M = dofile("lg_mock.lua")
requested = {}
C_QuestLog.RequestLoadQuestByID = function(id) requested[#requested + 1] = id end
C_QuestLog.GetQuestDifficultyLevel = function(id) return server[id] end
M.load(ADDON_PATH, function()
    LevelGuideRoutes.chains.NightElf = { R }
    LevelGuideQuestIDs = { ids = { Q1 = { 701 }, Q2 = { 702 }, Q3 = { 703 } }, renamed = {} }
end)
assert(LevelGuideDB.serverLevels.build ~= kept.build and next(LevelGuideDB.serverLevels.levels) == nil, "reset for a new build")
assert(#M.handled == 0, "clean: " .. tostring(M.handled[1]))
print("ALL TESTS PASSED")
