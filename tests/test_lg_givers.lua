-- LevelGuide_QuestGivers (for MapPins' "Quest givers" layer): pick-ups you can take now, by level,
-- log, chain part, prerequisites and class; hand-ins for finished quests; city spots; Horde gets none.
-- ADDON_PATH = LevelGuide.
local M = dofile("lg_mock.lua")
LevelGuideDB = { characters = {} }
M.best, M.pos, M.level = 1438, { [1438] = { 0.5, 0.5 } }, 10
UnitFactionGroup = function() return M.faction or "Alliance" end
local R
M.load(ADDON_PATH, function()
    local function A(q, npc, x, y, lvl, part) return { t = "accept", q = q, npc = npc, x = x, y = y, lvl = lvl, part = part } end
    local function T(q, npc, x, y, lvl, part) return { t = "turnin", q = q, npc = npc, x = x, y = y, lvl = lvl, part = part } end
    R = { zone = "Teldrassil", min = 1, max = 20, steps = {
        A("Now", "Giver One", 40, 40, 10),
        A("Too High", "Giver Two", 41, 41, 12),
        A("Gray", "Giver Three", 42, 42, 2),
        A("Held", "Giver Four", 43, 43, 10),
        T("Held", "Giver Four", 43, 43, 10),
        A("Chain", "Chain Giver", 44, 44, 9, 1), A("Chain", "Chain Giver", 44, 44, 10, 2),
        A("Needs Prereq", "Giver Five", 45, 45, 10),
        A("City Quest", "Sentinel, Darnassus", 40.6, 89.6, 10),
        { t = "accept", q = "Priests Only", npc = "Priestess", x = 46, y = 46, lvl = 10, cls = "PRIEST" },
        { t = "accept", q = "Mages Only", npc = "Mage", x = 47, y = 47, lvl = 10, cls = "MAGE" },
        A("Encrypted Letter", "Magistrate", 48, 48, 10),
    } }
    LevelGuideRoutes.chains = { NightElf = { R } }
    LevelGuideQuestIDs = { ids = { Chain = { 501, 502 }, Gate = { 600 } }, renamed = {}, unrelated = { [3102] = true } }
    LevelGuidePrereqs = { ["Needs Prereq"] = { all = { 600 } } }
end)
M.update()

local function givers()
    local list = LevelGuide_QuestGivers()
    local byTitle = {}
    for _, g in ipairs(list) do byTitle[g.kind .. ":" .. g.title] = g end
    return byTitle, list
end

-- 1. Level 10, nothing done: in range only, class-filtered, chain part 1 only, prerequisite missing.
M.log = { { questID = 77, title = "Held" } }
M.update()
local g = givers()
assert(g["accept:Now"] and g["accept:Now"].zone == "Teldrassil" and math.abs(g["accept:Now"].x - 0.4) < 1e-9, "in range")
assert(not g["accept:Too High"], "two levels above: not yet")
assert(not g["accept:Gray"], "eight levels below: gray, left out")
assert(not g["accept:Held"], "in your log: not offered")
assert(not g["turnin:Held"], "not finished: no hand-in yet")
assert(g["accept:Chain"] and g["accept:Chain"].level == 9, "chain: part 1")
assert(not g["accept:Needs Prereq"], "prerequisite not done")
assert(g["accept:City Quest"] and g["accept:City Quest"].zone == "Darnassus", "city giver on the city's map")
assert(g["accept:Priests Only"] and not g["accept:Mages Only"], "class filter")
print("1 ok")

-- 2. Finished quest in the log: a hand-in marker. Part 1 of the chain done: part 2 offered. Prereq done.
M.log = { { questID = 77, title = "Held", ready = true } }
M.flagged[501], M.flagged[600] = true, true
M.update()
g = givers()
assert(g["turnin:Held"], "ready to hand in")
assert(g["accept:Chain"] and g["accept:Chain"].level == 10, "chain: part 2 now")
assert(g["accept:Needs Prereq"], "prerequisite done")
print("2 ok")

-- 2b. Review 2026-11-10: turning in an unrelated quest with the same title (the Elwynn Encrypted Letter,
-- 3102) doesn't count as the route's.
M.titles[3102] = "Encrypted Letter"
M.fire("QUEST_TURNED_IN", 3102)
M.update()
g = givers()
assert(g["accept:Encrypted Letter"], "unrelated turn-in didn't count")
M.titles[3200] = "Encrypted Letter"
M.fire("QUEST_TURNED_IN", 3200)
M.update()
g = givers()
assert(not g["accept:Encrypted Letter"], "the route's own turn-in counts")

-- 3. A level later: the level 12 quest shows. Horde: nothing.
M.level = 11
M.update()
g = givers()
assert(g["accept:Too High"], "one level below the quest: shown")
M.faction = "Horde"
local _, list = givers()
assert(#list == 0, "Horde: no Alliance givers")
assert(#M.handled == 0, "clean: " .. tostring(M.handled[1]))
print("ALL TESTS PASSED")
