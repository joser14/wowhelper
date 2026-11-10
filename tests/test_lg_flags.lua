-- Timed, group and elite quests (research\guides_deep_re.md 12.12), from QuestDB's flags (t timed, g group,
-- e group/elite) and QuestXP's elite kills:
-- * a group quest you haven't answered for isn't the next step: a card asks "do it or skip it" once it can be
--   taken, the answer is kept per character; "skip" skips it and its follow-ups (undo with the header);
-- * group, elite and timed pick-ups carry a tag;
-- * a timed quest in your log goes first even when the game gives no timer, and while-you're-here pauses.
-- ADDON_PATH = LevelGuide.
local M = dofile("lg_mock.lua")
LevelGuideDB = { characters = { ["Juan-R"] = { done = {}, skips = {}, visited = {} } } }
M.best, M.pos, M.level = 1438, { [1438] = { 0.5, 0.5 } }, 6
local FLAGS = { [701] = { g = true }, [703] = { t = true } }
LevelGuideQuestFacts = {
    Quest = function(id) return { id = id, level = 6, flags = FLAGS[id] or {}, objectives = {} } end,
    Title = function() return nil end,
}
LevelGuideQuestXP = { q = { [705] = "500|8:6:e" } }
M.load(ADDON_PATH, function()
    local R = { zone = "Teldrassil", min = 1, max = 20, steps = {
        { t = "accept", q = "Group One", npc = "Giver G", x = 50, y = 50, lvl = 5 },
        { t = "accept", q = "Plain", npc = "Giver P", x = 50.4, y = 50, lvl = 5 },
        { t = "accept", q = "Hurry", npc = "Giver T", x = 50.8, y = 50, lvl = 5 },
        { t = "accept", q = "Brutes", npc = "Giver B", x = 51, y = 50, lvl = 5 },
        { t = "do", q = "Hurry", note = "Run", x = 56, y = 50, lvl = 5 },
        { t = "turnin", q = "Hurry", npc = "Giver T", x = 50.8, y = 50, lvl = 5 },
        { t = "accept", q = "Group One", part = 2, npc = "Giver G", x = 50, y = 50, lvl = 5 },
    } }
    LevelGuideRoutes.chains.NightElf = { R }
    LevelGuideQuestIDs = { ids = { ["Group One"] = { 701, 706 }, Plain = { 702 }, Hurry = { 703 }, Brutes = { 705 } }, renamed = {} }
    LevelGuidePrereqs = {}
end)
local function rows()
    local t = {}
    for _, b in ipairs(M.buttons) do if b.shown and b.step then t[#t + 1] = b.left.text end end
    return table.concat(t, "\n")
end
local function row(name)
    for _, b in ipairs(M.buttons) do if b.shown and b.step and b.left.text:find(name, 1, true) then return b.left.text end end
end
local function card() return LevelGuideGroupCard and LevelGuideGroupCard.shown and LevelGuideGroupCard end
M.update()

-- 1. The group quest right here isn't first; the card asks; tags show.
assert(not M.current.left.text:find("Group One", 1, true), "not first while unanswered: " .. M.current.left.text)
assert(card() and LevelGuideGroupCard.message.text:find("Group One", 1, true), "card asks")
assert(not (row("Group One") or ""):find("Pick up", 1, true) or not M.current.left.text:find("Group One", 1, true), "waits behind: " .. rows())
assert((row("Hurry") or ""):find("Timed", 1, true), "timed tag: " .. rows())
assert((row("Brutes") or ""):find("Elite", 1, true), "elite tag: " .. rows())
print("1 ok")

-- 2. "I'll do it": kept per character; now it's the nearest stop again, still tagged.
LevelGuideGroupDo.scripts.OnClick(LevelGuideGroupDo)
M.update()
assert(M.char.groupAnswers and M.char.groupAnswers[701] == "do", "answer kept")
assert(not card(), "card gone")
-- (The current stop holds against one less than 40 yd nearer, so it comes right after.)
assert((row("Group One") or ""):find("|cffff8040Group|r", 1, true), "in the steps now, tagged: " .. rows())
print("2 ok")

-- 3. "Skip it": the quest and its later part are skipped, undone in one go from the header.
M.char.groupAnswers = {}
M.update()
assert(card(), "asks again")
LevelGuideGroupSkip.scripts.OnClick(LevelGuideGroupSkip)
M.update()
assert(M.char.groupAnswers[701] == "skip", "skip kept")
assert(not rows():find("Group One", 1, true), "gone: " .. rows())
local skipped = 0
for _ in pairs(M.char.skips) do skipped = skipped + 1 end
assert(skipped == 2, "both parts skipped: " .. skipped)
local header
for _, f in ipairs(M.frames) do if f.kind == "Button" and f.scripts.OnDragStart and f.scripts.OnClick and not rawget(f, "left") then header = header or f end end
header.scripts.OnClick(header, "RightButton")
skipped = 0
for _ in pairs(M.char.skips) do skipped = skipped + 1 end
assert(skipped == 0, "undone: " .. skipped)
M.update()
assert(not card(), "answered, so no card after the undo")
print("3 ok")

-- 4. A timed quest in your log goes first even with no timer from the game, and while-you're-here pauses.
M.log = { { questID = 703, title = "Hurry" } }
M.obj[703] = { { text = "Run: 0/1", finished = false, numFulfilled = 0, numRequired = 1 } }
M.fire("QUEST_ACCEPTED", 703)
M.now = M.now + 3
M.update()
assert(M.current.left.text:find("Hurry", 1, true), "timed first: " .. M.current.left.text)
assert(M.current.step.timed and tostring(M.current.step.detail):find("Timed", 1, true), "says so: " .. tostring(M.current.step.detail))
assert(#M.handled == 0, "clean: " .. tostring(M.handled[1]))
print("ALL TESTS PASSED")
