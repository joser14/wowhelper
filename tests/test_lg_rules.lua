-- Quest rules (research\re_round3.md rank 2, LevelGuide\QuestRules.lua): the route never sends you for a quest
-- another one shuts out. Exclusive groups (one done or held: the others go), next in chain, disabled by a quest in
-- the log, removed quests, breadcrumbs (dropped once the target is done or held; the target waits while the
-- breadcrumb is in your log), and an exclusive partner counts for an "all" prerequisite. Generated routes keep
-- one quest of an exclusive group. ADDON_PATH = LevelGuide.
local M = dofile("lg_mock.lua")
LevelGuideDB = { characters = { ["Juan-R"] = { done = {}, skips = {}, visited = {} } } }
local function A(q, x, lvl) return { t = "accept", q = q, npc = "Npc " .. q, x = x, y = 50, lvl = lvl or 9 } end
M.load(ADDON_PATH, function()
    LevelGuideRoutes.chains.NightElf = { { zone = "Teldrassil", min = 1, max = 20, steps = {
        A("Alpha", 10), A("Beta", 15), A("Gamma", 20), A("Crumb", 25), A("Target", 30), A("Old", 35),
        A("Blocked", 40), A("Gone", 45), A("Plain", 50),
    } } }
    LevelGuideQuestIDs = { ids = { Alpha = { 101 }, Beta = { 102 }, Gamma = { 103 }, Crumb = { 110 }, Target = { 111 },
        Old = { 120 }, Blocked = { 130 }, Gone = { 140 }, Plain = { 150 } }, renamed = {} }
    LevelGuidePrereqs = { Gamma = { all = { 101 } } }
end)
-- QuestDB: Target (111) has Crumb (110) as its breadcrumb (capital A).
LevelGuideQuestDB = { q = { [111] = "5|1|0|0|n1|n1|A110|||Target", [110] = "5|1|0|0|n2|n1||||Crumb" } }
assert(loadfile(ADDON_PATH .. "/QuestLookup.lua"))()
local R = LevelGuideQuestRules
assert(R, "QuestRules.lua loads")
R.exclusive = { { 101, 102 } }
R.next = { [120] = 121 }
R.disabledBy = { [130] = 131 }
R.removed = { [140] = true }
R.Reset()
M.level = 10
local function givers()
    local set = {}
    for _, g in ipairs((LevelGuide_QuestGivers())) do
        if g.kind == "accept" then set[g.title] = true end
    end
    return set
end

-- 1. Nothing done: all open except the removed one and Gamma (needs Alpha).
M.update()
local g = givers()
assert(g.Alpha and g.Beta and g.Crumb and g.Target and g.Old and g.Blocked and g.Plain, "open pick-ups")
assert(not g.Gone, "a removed quest is never offered")
assert(not g.Gamma, "Gamma needs Alpha")
print("1 ok")

-- 2. Beta done: Alpha is shut out, and Beta stands in for Alpha in Gamma's prerequisites.
M.flagged[102] = true
M.update()
g = givers()
assert(not g.Alpha, "exclusive partner done: Alpha hidden")
assert(g.Gamma, "exclusive partner counts for an 'all' prerequisite")
-- The route itself doesn't send you to Alpha either.
assert(M.current.step and M.current.step.title ~= "Alpha", "not the current step: " .. tostring(M.current.step.title))
print("2 ok")

-- 3. The follow-up of Old done, the quest that disables Blocked in your log, the breadcrumb in your log.
M.flagged[121] = true
M.log = { { questID = 131, title = "Blocker", level = 10 }, { questID = 110, title = "Crumb", level = 5 } }
M.update()
g = givers()
assert(not g.Old, "follow-up done: Old is behind you")
assert(not g.Blocked, "disabled while 131 is in the log")
assert(not g.Target, "the target waits while its breadcrumb is in your log")
print("3 ok")

-- 4. Target taken (breadcrumb turned in): a breadcrumb not yet taken is dropped once its target is held.
M.log = { { questID = 111, title = "Target", level = 5 } }
M.update()
g = givers()
assert(not g.Crumb, "breadcrumb dropped once the target is in the log")
assert(g.Blocked, "Blocked back once 131 left the log")
print("4 ok")

-- 5. Generated routes keep one quest of an exclusive group.
local pool = { [101] = true, [102] = true, [140] = true, [150] = true }
R.Prune(pool)
assert(pool[101] and not pool[102] and not pool[140] and pool[150], "pruned pool")
print("5 ok")

-- 6. Groups from QuestDB itself: a quest that takes "one of" same-title, same-level quests (Forever's "The Great
-- Outdoors" at each start zone) makes them one quest. Repeatables and different titles don't.
LevelGuideQuestDB = { q = {
    [95998] = "6|4|4294967373|0|n1|n1||||The Great Outdoors", [96101] = "6|4|0|0|n2|n2||||The Great Outdoors",
    [96626] = "6|4|4294967373|0|n1|n3|y95998,y96101|||Camping 101: Cooking",
    [201] = "5|1|0|0|n1|n1||R||Bounty", [202] = "5|1|0|0|n1|n1||R||Bounty", [203] = "5|1|0|0|n1|n1|y201,y202|||After",
    [301] = "5|1|0|0|n1|n1||||One", [302] = "5|1|0|0|n1|n1||||Two", [303] = "5|1|0|0|n1|n1|y301,y302|||Either",
} }
R.exclusive = {}
R.Reset()
assert(R.Partners(95998)[1] == 96101 and R.Partners(96101)[1] == 95998, "Great Outdoors variants are one quest")
assert(#R.Partners(201) == 0 and #R.Partners(301) == 0, "repeatables and different quests are not grouped")
assert(#M.handled == 0, "clean: " .. tostring(M.handled[1]))
print("ALL TESTS PASSED")
