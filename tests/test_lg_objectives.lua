-- Secret-safe objective reading (research\guides_deep_re.md 12.13): when the game keeps an objective's counts
-- (and "finished") secret, the last "N/M" of its text is read instead, if the text itself is readable; an
-- objective named by its label in the route (Obj("Nightsaber Boar")) is matched with the counts stripped
-- (exact, else the shortest label holding it); an empty objective list means "not known", never "done".
-- ADDON_PATH = LevelGuide.
local M = dofile("lg_mock.lua")
LevelGuideDB = { characters = { ["Juan-R"] = { done = {}, skips = {}, visited = {} } } }
M.best, M.pos, M.level = 1438, { [1438] = { 0.5, 0.5 } }, 6
M.load(ADDON_PATH, function()
    local R = { zone = "Teldrassil", min = 1, max = 20, steps = {
        { t = "accept", q = "Q1", npc = "Giver A", x = 50, y = 50, lvl = 5 },
        { t = "do", q = "Q1", obj = 1, note = "Spiders", x = 50.2, y = 50, lvl = 5 },
        { t = "do", q = "Q1", obj = "Nightsaber Boar", note = "Boars", x = 50.4, y = 50, lvl = 5 },
        { t = "turnin", q = "Q1", npc = "Giver A", x = 50, y = 50, lvl = 5 },
    } }
    LevelGuideRoutes.chains.NightElf = { R }
    LevelGuideQuestIDs = { ids = { Q1 = { 801 } }, renamed = {} }
    LevelGuidePrereqs = {}
end)
local SECRET = setmetatable({}, { __tostring = function() return "<secret>" end })
issecretvalue = function(v) return v == SECRET end
M.log = { { questID = 801, title = "Q1" } }
M.obj[801] = {
    { text = "Webwood Spider slain: 8/8", finished = SECRET, numFulfilled = SECRET, numRequired = SECRET },
    { text = "Young Nightsaber slain: 0/4", finished = SECRET, numFulfilled = SECRET, numRequired = SECRET },
    { text = "Nightsaber Boar slain: 3/8", finished = SECRET, numFulfilled = SECRET, numRequired = SECRET },
}
M.fire("QUEST_LOG_UPDATE")
M.update()

-- 1. Spiders 8/8 read from the text: done, so the boars are next, matched by name (not "Young Nightsaber").
assert(M.current.left.text:find("Q1", 1, true) and tostring(M.current.step.detail):find("Boars", 1, true),
    "the boars are next: " .. M.current.left.text .. " / " .. tostring(M.current.step.detail))
assert(tostring(M.current.step.detail):find("3/8", 1, true) and not tostring(M.current.step.detail):find("Young", 1, true),
    "its own objective: " .. tostring(M.current.step.detail))
print("1 ok")

-- 2. Boars 8/8 in the text: that step is done too.
M.obj[801][3].text = "Nightsaber Boar slain: 8/8"
M.fire("QUEST_LOG_UPDATE")
M.update()
assert(not tostring(M.current.step.detail):find("Boars", 1, true), "boars done: " .. tostring(M.current.step.detail))
print("2 ok")

-- 3. A secret text tells nothing; an empty list is "not known": the spiders aren't done then.
M.obj[801][1].text = SECRET
M.fire("QUEST_LOG_UPDATE")
M.update()
assert(tostring(M.current.step.detail):find("Spiders", 1, true), "unknown is not done: " .. tostring(M.current.step.detail))
M.obj[801] = {}
M.fire("QUEST_LOG_UPDATE")
M.update()
assert(tostring(M.current.step.detail):find("Spiders", 1, true), "empty list is not done: " .. tostring(M.current.step.detail))
print("3 ok")

-- 4. The planner's reader on its own.
local P = LevelGuidePlanner
local have, need, label = P.ObjectiveCount("Sanglier : 2/6 tués")
assert(have == 2 and need == 6, "last N/M")
have, need, label = P.ObjectiveCount("Webwood Spider slain: 8/8")
assert(label == "Webwood Spider slain", "label: " .. tostring(label))
local labels = { "Young Nightsaber slain", "Nightsaber Boar slain", "Nightsaber" }
assert(P.MatchObjective(labels, "Nightsaber") == 3, "exact first")
assert(P.MatchObjective(labels, "nightsaber boar") == 2, "containing, any case")
assert(P.MatchObjective({ "Young Nightsaber slain", "Nightsaber slain" }, "Nightsaber") == 2, "shortest containing")
assert(P.MatchObjective(labels, "Wolf") == nil, "no match")
assert(#M.handled == 0, "clean: " .. tostring(M.handled[1]))
print("ALL TESTS PASSED")
