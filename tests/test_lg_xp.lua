-- XP model and projection (research\guides_deep_re.md 1.8 and 12.4): Polestar's formulas in Planner.lua, the
-- route simulated in order ("route ends at about level X"), "+N XP waiting" for ready turn-ins, quests 3+
-- levels above where the route has you flagged, and XP per second breaking distance ties. ADDON_PATH = LevelGuide.
local M = dofile("lg_mock.lua")
LevelGuideDB = { characters = { ["Juan-R"] = { done = {}, skips = {}, visited = {} } } }
M.best, M.pos, M.level, M.xp = 1438, { [1438] = { 0.5, 0.5 } }, 5, 0
local rewardXP = {}
GetQuestLogRewardXP = function(id) return rewardXP[id] or 0 end
LevelGuideQuestXP = { q = { [302] = "1000|5:10", [303] = "2000", [304] = "100", [305] = "2000" } }
local R
M.load(ADDON_PATH, function()
    R = { zone = "Teldrassil", min = 1, max = 20, steps = {
        { t = "turnin", q = "Q1", npc = "Giver A", x = 50, y = 49, lvl = 5 },
        { t = "accept", q = "Q2", npc = "Giver A", x = 50, y = 49, lvl = 5 },
        { t = "do", q = "Q2", note = "Boars", x = 55, y = 55, lvl = 5 },
        { t = "turnin", q = "Q2", npc = "Giver A", x = 50, y = 49, lvl = 5 },
        { t = "accept", q = "Q3", npc = "Giver C", x = 60, y = 60, lvl = 6 },
    } }
    LevelGuideRoutes.chains.NightElf = { R }
    LevelGuideQuestIDs = { ids = { Q1 = { 301 }, Q2 = { 302 }, Q3 = { 303 }, Q4 = { 304 }, Q5 = { 305 } }, renamed = {} }
    LevelGuidePrereqs = {}
end)
local P = LevelGuidePlanner
local function rows()
    local t = {}
    for _, b in ipairs(M.buttons) do if b.shown and b.step then t[#t + 1] = b.left.text end end
    return table.concat(t, "\n")
end

-- 1. The formulas (Polestar Core\Levels.lua).
assert(P.Share(10, 10) == 1 and P.Share(10, 5) == 1 and P.Share(10, 4) == 0.8 and P.Share(10, 0) == 0.1, "share")
assert(P.GreyLevel(5) == 0 and P.GreyLevel(10) == 4 and P.GreyLevel(40) == 31 and P.GreyLevel(60) == 51, "grey level")
assert(P.ZeroDiff(10) == 7 and P.ZeroDiff(25) == 11, "zero diff")
assert(P.MobXP(10, 10) == 95 and P.MobXP(10, 12) == 105 and P.MobXP(10, 4) == 0 and P.MobXP(10, 8) == 68, "mob xp")
assert(P.MobXP(10, 10, true) == 190, "elite x2")
assert(P.Trivial(20, 12, 5) == true and P.Trivial(20, 15, 5) == false and P.Trivial(10, 4) == true, "trivial")
local xp, kills = P.QuestXP(302)
assert(xp == 1000 and kills[1].mob == 5 and kills[1].n == 10, "QuestXP decoded")
local s = P.Run({ { kind = "quest", xp = 3000, level = 5 } }, { level = 5, xp = 0, xpMax = 2800 })
assert(s.level == 6 and s.xp == 200, "level-up carries over: " .. s.level .. " " .. s.xp)
local reduced = P.Run({ { kind = "quest", xp = 1000, level = 1 } }, { level = 10, xp = 0, xpMax = 7600 })
assert(reduced.questXP == 200, "share applied at the simulated level: " .. reduced.questXP)
print("1 ok")

-- 2. The guide: "+N XP waiting" for ready turn-ins, the route's end level, a quest far above flagged.
M.log = { { questID = 301, title = "Q1" } }
M.log[1].ready = true
rewardXP[301] = 850
M.update()
local header = M.font("XP waiting")
assert(header and header.text:find("+850 XP waiting", 1, true), "XP waiting in the header: " .. tostring(header and header.text))
local plan = M.font("Route ends at about level")
assert(plan, "projection line")
local level = tonumber(plan.text:match("level (%d+%.%d)"))
-- From 5 (0/1000): Q1 850, ten boars (70 each at 5, 60 at 6), Q2 1000 -> about 6.4 (Q3 has no turn-in here).
assert(level and level > 6.3 and level < 6.5, "projected end level: " .. plan.text)
print("2 ok")

-- 3. Work on a quest 3+ levels above where the route has you is flagged.
R.steps[6] = { t = "do", q = "Q3", note = "Ogres", x = 52, y = 52, lvl = 12 }
M.log[2] = { questID = 303, title = "Q3", difficultyLevel = 12 }
M.obj[303] = { { text = "Ogres: 0/5", finished = false, numFulfilled = 0, numRequired = 5 } }
M.update()
assert(rows():find("Do:|r Q3 |cffff4040Hard (level 12)", 1, true), "hard quest flagged: " .. rows())
assert(not rows():find("Q1 |cffff4040", 1, true), "Q1 not flagged")
R.steps[6] = nil
M.log[2] = nil
print("3 ok")

-- 4. XP per second breaks a distance tie: two pick-ups 100 yd away, the richer one first.
M.log = {}
R.steps = {
    { t = "accept", q = "Q4", npc = "Poor", x = 52, y = 50, lvl = 5 },
    { t = "accept", q = "Q5", npc = "Rich", x = 50, y = 52, lvl = 5 },
}
M.update()
assert(M.current.left.text:find("Q5", 1, true), "richer pick-up first at equal distance: " .. rows())
assert(#M.handled == 0, "clean: " .. tostring(M.handled[1]))
print("ALL TESTS PASSED")
