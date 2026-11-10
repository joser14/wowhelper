-- XP for quests not yet taken and the grind-vs-quest check (research\re_round3.md rank 11):
-- * a "!" quest from the map gets its XP at your level (QuestXP.lua, reduced by the level gap), so ordering by XP
--   per second no longer scores it as 0;
-- * a pick-up whose XP per second (reward, plus 0.6 of its kills' XP, over the walk, 6 s of talking and 20 s per
--   kill; MacQuest's maths, GPL-3.0) is under 0.65 x what grinding gives you (a same-level kill every 20 s, at your
--   measured kill XP) is tagged "Slow". ADDON_PATH = LevelGuide.
local M = dofile("lg_mock.lua")
LevelGuideDB = { characters = { ["Juan-R"] = { done = {}, skips = {}, visited = {} } } }
local lines = {}
C_QuestLine = {
    GetAvailableQuestLines = function() return lines end,
    RequestQuestLinesForMap = function() end,
}
LevelGuideQuestXP = { q = { [500] = "800", [601] = "50|12:10", [602] = "2000|12:10" } }
M.load(ADDON_PATH, function()
    LevelGuideRoutes.chains.NightElf = {}
    LevelGuideRoutes.plan = {}
end)
M.level = 12
M.pos = { [1438] = { 0.50, 0.50 } }

-- 1. A map offer has its XP.
lines = { { questID = 500, questName = "Map Quest", x = 0.52, y = 0.5 } }
M.update()
local step = M.current.step
assert(step and step.id == 500, "the offer: " .. tostring(step and step.title))
assert(step.xpValue == 800, "its XP: " .. tostring(step.xpValue))
local P = LevelGuidePlanner
assert(P.QuestRate and X == nil, "maths in the planner")
print("1 ok")

-- 2. The maths.
local grind = P.GrindRate(12, 1)
assert(math.abs(grind - 105 / 20) < 1e-9, "grind: a same-level kill every 20 s: " .. grind)
local rate = P.QuestRate(50, { { mob = 12, n = 10 } }, 12, 30)
assert(math.abs(rate - (50 + 10 * 105 * 0.6) / (30 + 6 + 200)) < 1e-9, "quest rate: " .. rate)
assert(P.Slow(rate, grind), "under 0.65 x grind is slow")
assert(not P.Slow(P.QuestRate(2000, { { mob = 12, n = 10 } }, 12, 30), grind), "a big reward isn't")
print("2 ok")

-- 3. In the list: the poor pick-up is tagged, the good one isn't.
lines = { { questID = 601, questName = "Poor Quest", x = 0.51, y = 0.5 }, { questID = 602, questName = "Good Quest", x = 0.53, y = 0.5 } }
M.update()
local seen = {}
for _, b in ipairs(M.buttons) do
    local s = rawget(b, "step")
    if s then seen[s.title] = { slow = s.slow, line = b.left.text } end
end
assert(seen["Poor Quest"] and seen["Poor Quest"].slow, "poor quest tagged")
assert(seen["Poor Quest"].line:find("Slow", 1, true), "shown: " .. seen["Poor Quest"].line)
assert(seen["Good Quest"] and not seen["Good Quest"].slow, "good quest not tagged")
assert(#M.handled == 0, "clean: " .. tostring(M.handled[1]))
print("ALL TESTS PASSED")
