-- Lost, abandoned and extra quests (research\guides_deep_re.md 1.5 and 12.10): a route quest dropped without a
-- turn-in shows a "go back or skip" card and the arrow points at its giver until you answer; skipping skips
-- its steps and its follow-ups (later parts, quests that need it), undone in one go; a failed quest that you
-- abandon just goes back. A quest you take that isn't on the route is fitted: its work after the first stop
-- within 250 yd of its camps, its turn-in after the first stop from there within 80 yd of where it's handed
-- in; else it's "not on your route". ADDON_PATH = LevelGuide.
local M = dofile("lg_mock.lua")
LevelGuideDB = { characters = { ["Juan-R"] = { done = {}, skips = {}, visited = {} } } }
M.best, M.pos, M.level = 1438, { [1438] = { 0.5, 0.5 } }, 6
local pois, failed = {}, {}
C_QuestLog.GetQuestsOnMap = function() return pois end
C_QuestLog.IsFailed = function(id) return failed[id] or false end
LevelGuideQuestFacts = {
    Quest = function(id)
        if id == 899 then return { id = 899, level = 6, objectives = { { spots = { { map = 1438, x = 61, y = 61, r = 20, n = 4 } } } } } end
        if id == 898 then return { id = 898, level = 6, objectives = { { spots = { { map = 1438, x = 95, y = 5, r = 20, n = 4 } } } } } end
    end,
    EnderSpot = function(id) if id == 899 then return 1438, 50.2, 50.2, "Giver A" end end,
}
local R
M.load(ADDON_PATH, function()
    R = { zone = "Teldrassil", min = 1, max = 20, steps = {
        { t = "accept", q = "Q1", npc = "Giver A", x = 50, y = 50, lvl = 5 },
        { t = "do", q = "Q1", note = "Work", x = 60, y = 60, lvl = 5 },
        { t = "turnin", q = "Q1", npc = "Giver A", x = 50, y = 50, lvl = 5 },
        { t = "accept", q = "Q2", npc = "Giver A", x = 50, y = 50, lvl = 5 },
        { t = "turnin", q = "Q2", npc = "Giver B", x = 40, y = 40, lvl = 5 },
        { t = "accept", q = "Q3", npc = "Giver B", x = 40, y = 40, lvl = 5 },
        { t = "accept", q = "Q4", npc = "Giver C", x = 30, y = 30, lvl = 5 },
    } }
    LevelGuideRoutes.chains.NightElf = { R }
    LevelGuideQuestIDs = { ids = { Q1 = { 801 }, Q2 = { 802 }, Q3 = { 803 }, Q4 = { 804 } }, renamed = {} }
    LevelGuidePrereqs = { Q2 = { all = { 801 } }, Q3 = { all = { 802 } } }
end)
local function rows()
    local t = {}
    for _, b in ipairs(M.buttons) do if b.shown and b.step then t[#t + 1] = b.left.text end end
    return table.concat(t, "\n")
end
local function card() return LevelGuideLostCard and LevelGuideLostCard.shown and LevelGuideLostCard end
local function cardText() return LevelGuideLostCard and LevelGuideLostCard.message and LevelGuideLostCard.message.text or "" end
M.log = { { questID = 801, title = "Q1" } }
M.obj[801] = { { text = "x: 0/5", finished = false, numFulfilled = 0, numRequired = 5 } }
M.fire("QUEST_LOG_UPDATE")
M.update()
assert(not card(), "no card at first")

-- 1. Dropping Q1 (no turn-in): the card asks, and the arrow points at its giver.
M.log = {}
M.fire("QUEST_REMOVED", 801)
M.update()
assert(card() and cardText():find("Q1", 1, true), "card: " .. cardText())
assert(M.current.left.text:find("Pick up:|r Q1", 1, true), "back to the giver first: " .. M.current.left.text)
print("1 ok")

-- 2. "Go back": the card goes, the pick-up stays first until it's taken.
LevelGuideLostBack.scripts.OnClick(LevelGuideLostBack)
M.update()
assert(not card(), "answered")
assert(M.current.left.text:find("Pick up:|r Q1", 1, true), "go back for it: " .. M.current.left.text)
M.log = { { questID = 801, title = "Q1" } }
M.fire("QUEST_ACCEPTED", 801)
M.update()
print("2 ok")

-- 3. Dropped again; "Skip it" skips Q1 and its follow-ups Q2 and Q3 (not Q4), and one undo brings all back.
M.log = {}
M.fire("QUEST_REMOVED", 801)
M.update()
assert(card(), "card again")
LevelGuideLostSkip.scripts.OnClick(LevelGuideLostSkip)
M.update()
assert(not card(), "answered by skipping")
local skipped = 0
for _ in pairs(M.char.skips) do skipped = skipped + 1 end
assert(skipped == 6, "Q1 (3 steps), Q2 (2), Q3 (1) skipped: " .. skipped)
assert(rows():find("Q4", 1, true) and not rows():find("Q1", 1, true), "Q4 left: " .. rows())
local header
for _, f in ipairs(M.frames) do if f.kind == "Button" and f.scripts.OnDragStart and f.scripts.OnClick and not rawget(f, "left") then header = header or f end end
header.scripts.OnClick(header, "RightButton")
skipped = 0
for _ in pairs(M.char.skips) do skipped = skipped + 1 end
assert(skipped == 0, "one undo brings them all back: " .. skipped)
print("3 ok")

-- 4. Turned in (removed after the turn-in) is not lost; a failed quest abandoned goes back without asking.
M.log = { { questID = 801, title = "Q1" } }
M.update()
M.fire("QUEST_TURNED_IN", 801)
M.log = {}
M.fire("QUEST_REMOVED", 801)
M.update()
assert(not card(), "turned in: no card")
M.flagged[801], M.char.done = nil, {}
M.log = { { questID = 801, title = "Q1" } }
failed[801] = true
M.now = M.now + 20
M.update()
M.log = {}
M.fire("QUEST_REMOVED", 801)
M.update()
assert(not card(), "failed and abandoned: no card")
failed[801] = nil
print("4 ok")

-- 5. A quest off the route is fitted: its work after the route's work step 70 yd from its camp, its turn-in
--    after the turn-in 14 yd from where it's handed in. Until then it waits behind the route.
M.log = { { questID = 801, title = "Q1" }, { questID = 899, title = "Side" } }
M.obj[899] = { { text = "y: 0/5", finished = false, numFulfilled = 0, numRequired = 5 } }
pois = { { questID = 899, x = 0.505, y = 0.505 } }
M.fire("QUEST_ACCEPTED", 899)
M.now = M.now + 2
M.update()
local fit = M.char.extras and M.char.extras[899]
assert(fit and fit.doAfter and fit.doAfter:find("|do|Q1", 1, true), "work fitted after Q1's work: " .. tostring(fit and fit.doAfter))
assert(fit.turnAfter and fit.turnAfter:find("|turnin|Q1", 1, true), "turn-in fitted: " .. tostring(fit.turnAfter))
local side
for _, b in ipairs(M.buttons) do if b.shown and b.step and b.step.id == 899 then side = b.step end end
assert(side and tostring(side.detail):find("Fits your route after", 1, true), "waits: " .. rows())
assert(not M.current.left.text:find("Side", 1, true), "not first although it's right here")
-- Once Q1's work is done, it's in play.
M.log[1].ready = true
M.update()
side = nil
for _, b in ipairs(M.buttons) do if b.shown and b.step and b.step.id == 899 then side = b.step end end
assert(side and not tostring(side.detail):find("Fits your route", 1, true), "in play now: " .. tostring(side and side.detail))
print("5 ok")

-- 6. One that fits nowhere says so.
M.log[3] = { questID = 898, title = "Far Side" }
M.obj[898] = { { text = "z: 0/5", finished = false, numFulfilled = 0, numRequired = 5 } }
pois[2] = { questID = 898, x = 0.51, y = 0.51 }
M.fire("QUEST_ACCEPTED", 898)
M.now = M.now + 2
M.update()
assert(M.char.extras[898] and M.char.extras[898].fits == false, "no fit")
local far
for _, b in ipairs(M.buttons) do if b.shown and b.step and b.step.id == 898 then far = b.step end end
assert(far and tostring(far.detail):find("Not on your route", 1, true), "says so: " .. rows())
-- Removing it forgets the fit.
M.log[3] = nil
M.fire("QUEST_REMOVED", 898)
M.update()
assert(M.char.extras[898] == nil, "forgotten")
assert(#M.handled == 0, "clean: " .. tostring(M.handled[1]))
print("ALL TESTS PASSED")
