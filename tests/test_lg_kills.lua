-- Kills to level and pace (research\guides_deep_re.md 12.15): each kill's XP is kept (per character, the last
-- 30) as a share of what a mob of your level gives, with the rested bonus taken out; XP that comes with a
-- turn-in (within 1.5 s either way) isn't a kill. The guide says "About N kills to level L" (the median kill,
-- rested-aware) and your XP per hour over the last 15 minutes. ADDON_PATH = LevelGuide.
local M = dofile("lg_mock.lua")
LevelGuideDB = { characters = { ["Juan-R"] = { done = {}, skips = {}, visited = {} } } }
M.best, M.pos, M.level, M.xp = 1438, { [1438] = { 0.5, 0.5 } }, 11, 0
local rested = 0
GetXPExhaustion = function() return rested > 0 and rested or nil end
M.load(ADDON_PATH, function()
    LevelGuideRoutes.chains.NightElf = { { zone = "Teldrassil", min = 1, max = 20, steps = {
        { t = "accept", q = "Far", npc = "Giver", x = 60, y = 60, lvl = 10 },
    } } }
    LevelGuideQuestIDs = { ids = {}, renamed = {} }
    LevelGuidePrereqs = {}
end)
local function line()
    local f = M.font(" to level 12")
    return f and f.text or ""
end
M.fire("PLAYER_XP_UPDATE", "player")
-- Three kills of 100 (a level-11 mob gives 100 at 11), 30 s apart.
for _ = 1, 3 do
    M.now = M.now + 30
    M.xp = M.xp + 100
    M.fire("PLAYER_XP_UPDATE", "player")
end
M.now = M.now + 2
M.update()
assert(#(M.char.killXP or {}) == 3, "three kills kept: " .. #(M.char.killXP or {}))
assert(line():find("About 7 kills to level 12", 1, true), "700 to go at 100 a kill: " .. line())
assert(line():find("XP/h", 1, true), "pace: " .. line())
print("1 ok")

-- A turn-in's XP (the event right after) isn't a kill.
M.now = M.now + 5
M.xp = M.xp + 400
M.fire("PLAYER_XP_UPDATE", "player")
M.now = M.now + 0.5
M.fire("QUEST_TURNED_IN", 999, 400, 0)
M.now = M.now + 2
M.update()
assert(#M.char.killXP == 3, "the quest's XP isn't a kill")
assert(line():find("About 3 kills to level 12", 1, true), "300 to go: " .. line())
print("2 ok")

-- Rested: a kill gives double and the pool pays half; the bonus is taken out of the sample.
rested = 1000
M.fire("PLAYER_XP_UPDATE", "player")
M.now = M.now + 5
M.xp = M.xp + 200
rested = 900
M.fire("PLAYER_XP_UPDATE", "player")
M.now = M.now + 2
M.update()
assert(#M.char.killXP == 4 and math.abs(M.char.killXP[4] - 1) < 0.01, "rested kill counted as one mob: " .. tostring(M.char.killXP[4]))
assert(line():find("About 1 kill to level 12", 1, true), "100 to go, rested: " .. line())
print("3 ok")

-- The planner's arithmetic.
local P = LevelGuidePlanner
assert(P.KillsLeft(700, 0, 100) == 7 and P.KillsLeft(700, 200, 100) == 5 and P.KillsLeft(700, 5000, 100) == 4, "kills left")
assert(P.KillBase(200, 900) == 100 and P.KillBase(100, 0) == 100 and P.KillBase(150, 50) == 100, "rested taken out")
assert(P.Median({ 3, 1, 2 }) == 2 and P.Median({ 1, 2, 3, 4 }) == 2.5 and P.Median({}) == nil, "median")
assert(#M.handled == 0, "clean: " .. tostring(M.handled[1]))
print("ALL TESTS PASSED")
