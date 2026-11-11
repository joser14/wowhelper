-- Final review of LevelGuide (research\final_review_levelguide.md):
-- 1. "Skip it" on a lost quest whose steps are all skipped already skips nothing, so it must not leave an
--    empty entry on the undo list: one right-click on the header still brings back the earlier skip.
-- 2. A quest greeting window whose quest counts can't be read (secret) judges nothing: no route pick-up of
--    that NPC is marked "not offered".
-- ADDON_PATH = LevelGuide.
local M = dofile("lg_mock.lua")
LevelGuideDB = { characters = { ["Juan-R"] = { done = {}, skips = {}, visited = {} } } }
M.best, M.pos, M.level = 1438, { [1438] = { 0.5, 0.5 } }, 6
M.load(ADDON_PATH, function()
    LevelGuideRoutes.chains.NightElf = { { zone = "Teldrassil", min = 1, max = 20, steps = {
        { t = "accept", q = "Lost One", npc = "Giver L", x = 50, y = 50, lvl = 5 },
        { t = "do", q = "Lost One", note = "Kill things", x = 52, y = 52, lvl = 5 },
        { t = "turnin", q = "Lost One", npc = "Giver L", x = 50, y = 50, lvl = 5 },
        { t = "accept", q = "Greeted", npc = "Giver G", x = 51, y = 50, lvl = 5 },
    } } }
    LevelGuideQuestIDs = { ids = { ["Lost One"] = { 9001 }, ["Greeted"] = { 9002 } }, renamed = {} }
    LevelGuidePrereqs = {}
end)

local header
for _, f in ipairs(M.frames) do
    if f.kind == "Button" and f.scripts.OnDragStart and f.scripts.OnClick and not rawget(f, "left") then
        header = f
    end
end
assert(header, "the guide's header button")

local function count(set)
    local n = 0
    for _ in pairs(set or {}) do
        n = n + 1
    end
    return n
end

-- Holding the quest, then abandoning it: the lost card, "Skip it".
local function holdThenDrop()
    M.log = { { questID = 9001, title = "Lost One", ready = false } }
    M.titles[9001] = "Lost One"
    M.fire("QUEST_ACCEPTED", 9001)
    M.now = M.now + 10
    M.update()
    M.log = {}
    M.fire("QUEST_REMOVED", 9001)
    M.now = M.now + 10
    M.update()
    assert(LevelGuideLostCard and LevelGuideLostCard.shown, "the lost card shows")
    LevelGuideLostSkip.scripts.OnClick(LevelGuideLostSkip)
    M.update()
end

holdThenDrop()
local skipped = count(M.char.skips)
assert(skipped == 3, "the quest's three steps are skipped: " .. skipped)
-- Dropped again: every step is skipped already, so this skip changes nothing.
holdThenDrop()
assert(count(M.char.skips) == 3, "still three")
-- One right-click on the header undoes the last real skip.
header.scripts.OnClick(header, "RightButton")
M.update()
assert(count(M.char.skips) == 0, "undone in one click: " .. count(M.char.skips) .. " still skipped")
print("1 ok")

-- 2. Secret counts at a quest greeting: nothing is judged.
local SECRET = {}
issecretvalue = function(v) return v == SECRET end
GetNumAvailableQuests = function() return SECRET end
GetNumActiveQuests = function() return SECRET end
GetAvailableTitle = function() return nil end
GetActiveTitle = function() return nil end
M.npcName = "Giver G"
M.now = M.now + 10
M.update()
M.fire("QUEST_GREETING")
assert(count(M.char.notOffered) == 0, "unreadable window, nothing marked: " .. count(M.char.notOffered))
-- Readable and empty: the giver doesn't offer it, so it is marked.
GetNumAvailableQuests = function() return 0 end
GetNumActiveQuests = function() return 0 end
M.fire("QUEST_GREETING")
assert(M.char.notOffered[9002], "readable empty window marks the pick-up")
print("2 ok")

assert(#M.handled == 0, "clean: " .. tostring(M.handled[1]))
print("ALL TESTS PASSED")
