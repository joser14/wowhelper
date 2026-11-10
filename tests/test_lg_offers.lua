-- The NPC's own window decides availability (research\guides_deep_re.md 12.3): a route pick-up its giver
-- doesn't list in GOSSIP_SHOW / QUEST_GREETING is "not offered at level L", saved per character, and the
-- mark clears on a level-up, after 30 minutes, on a turn-in at that NPC or within 100 yd (or of the quest's
-- prerequisite), when the quest is accepted, or when it's seen offered. A window with an unreadable entry
-- judges nothing, nor does one within 3 s of a turn-in. An empty GetAvailableQuestLines is no answer.
-- ADDON_PATH = LevelGuide.
local M = dofile("lg_mock.lua")
LevelGuideDB = { characters = { ["Juan-R"] = { done = {}, skips = {}, visited = {} } } }
M.best, M.pos, M.level = 1438, { [1438] = { 0.5, 0.5 } }, 5
local gossip, active = {}, {}
C_GossipInfo = { GetAvailableQuests = function() return gossip end, GetActiveQuests = function() return active end }
C_QuestLine = { RequestQuestLinesForMap = function() end, GetAvailableQuestLines = function() return {} end }
M.load(ADDON_PATH, function()
    local R = { zone = "Teldrassil", min = 1, max = 20, steps = {
        { t = "accept", q = "Q1", npc = "Giver A", x = 50, y = 50, lvl = 4 },
        { t = "accept", q = "Q2", npc = "Giver A", x = 50, y = 50, lvl = 4 },
        { t = "accept", q = "Q3", npc = "Giver B", x = 80, y = 80, lvl = 4 },
    } }
    LevelGuideRoutes.chains.NightElf = { R }
    LevelGuideQuestIDs = { ids = { Q1 = { 201 }, Q2 = { 202 }, Q3 = { 203 }, Q0 = { 200 } }, renamed = {} }
    LevelGuidePrereqs = {}
end)
local function rows()
    local t = {}
    for _, b in ipairs(M.buttons) do if b.shown and b.step then t[#t + 1] = b.left.text end end
    return table.concat(t, "\n")
end
local function talk(npc, list)
    M.npcName = npc
    gossip = list
    M.fire("GOSSIP_SHOW")
    M.npcName = nil
    M.update()
end
local function marked() return M.char.notOffered and M.char.notOffered[202] end

-- 1. Empty quest lines on the map are no answer: every pick-up shows.
M.update()
assert(rows():find("Q1", 1, true) and rows():find("Q2", 1, true), "an empty map list hides nothing: " .. rows())
print("1 ok")

-- 2. The giver lists Q1 only: Q2 is "not offered at level 5", saved, and hidden; the list says why.
talk("Giver A", { { title = "Q1", questID = 201 } })
assert(marked() and marked().level == 5, "marked at level 5")
assert(rows():find("Q1", 1, true) and not rows():find("Q2", 1, true), "Q2 hidden: " .. rows())
assert(rows():find("Q3", 1, true), "another giver's pick-up untouched")
print("2 ok")

-- 3. Level-up clears it.
M.level = 6
M.update()
assert(rows():find("Q2", 1, true), "back after a level-up: " .. rows())
print("3 ok")

-- 4. 30 minutes clear it.
talk("Giver A", { { title = "Q1", questID = 201 } })
assert(not rows():find("Q2", 1, true), "marked again at 6")
M.now = M.now + 1801
M.update()
assert(rows():find("Q2", 1, true), "back after 30 min: " .. rows())
print("4 ok")

-- 5. Accepting it clears it; so does seeing it offered.
talk("Giver A", { { title = "Q1", questID = 201 } })
M.fire("QUEST_ACCEPTED", 202)
assert(not marked(), "accept clears")
talk("Giver A", { { title = "Q1", questID = 201 } })
talk("Giver A", { { title = "Q1", questID = 201 }, { title = "Q2", questID = 202 } })
assert(not marked(), "offered clears")
print("5 ok")

-- 6. A turn-in far away at another NPC keeps it; within 100 yd of where it was judged clears it.
M.now = M.now + 10
talk("Giver A", { { title = "Q1", questID = 201 } })
M.pos[1438] = { 0.9, 0.9 }
M.npcName = "Someone Else"
M.now = M.now + 10
M.fire("QUEST_TURNED_IN", 199)
assert(marked(), "far turn-in keeps the mark")
M.pos[1438] = { 0.505, 0.505 }
M.now = M.now + 10
M.fire("QUEST_TURNED_IN", 198)
M.npcName = nil
assert(not marked(), "turn-in within 100 yd clears")
-- A turn-in of the quest's prerequisite clears it too.
LevelGuidePrereqs.Q2 = { all = { 200 } }
M.pos[1438] = { 0.9, 0.9 }
M.now = M.now + 10
talk("Giver A", { { title = "Q1", questID = 201 } })
M.now = M.now + 10
M.fire("QUEST_TURNED_IN", 200)
assert(not marked(), "prerequisite turned in clears")
LevelGuidePrereqs.Q2 = nil
M.pos[1438] = { 0.5, 0.5 }
print("6 ok")

-- 7. An unreadable entry judges nothing; neither does a window within 3 s of a turn-in.
M.now = M.now + 10
talk("Giver A", { { title = "Q1", questID = 201 }, { title = nil, questID = nil } })
assert(not marked(), "unreadable entry: no judgement")
M.fire("QUEST_TURNED_IN", 197)
M.now = M.now + 1
talk("Giver A", { { title = "Q1", questID = 201 } })
assert(not marked(), "just after a turn-in: no judgement")
print("7 ok")

-- 8. The greeting window (QUEST_GREETING) reads quest IDs the same way.
M.now = M.now + 10
local avail = { { "Q1", 201 } }
GetNumAvailableQuests = function() return #avail end
GetAvailableTitle = function(i) return avail[i][1] end
GetAvailableQuestInfo = function(i) return false, 0, false, false, avail[i][2] end
GetNumActiveQuests = function() return 0 end
M.npcName = "Giver A"
M.fire("QUEST_GREETING")
M.npcName = nil
M.update()
assert(marked() and not rows():find("Q2", 1, true), "greeting judged: " .. rows())
-- Saved per character: a reload keeps it (the mark is in the character's saved data).
assert(LevelGuideDB.characters and M.char.notOffered[202].level == 6, "saved")
assert(#M.handled == 0, "clean: " .. tostring(M.handled[1]))
print("ALL TESTS PASSED")
