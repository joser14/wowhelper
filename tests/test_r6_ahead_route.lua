-- Round 6 #12: "Upgrade ahead: <item> from <quest> (step N)" in the guide, and the list window, from the
-- rewards of the route's next turn-ins (QuestRewards.lua, generated from ATT's Forever data) judged by
-- ItemAdvisor_Judge. ADDON_PATH = LevelGuide.
local M = dofile("lg_mock.lua")
LevelGuideDB = { characters = { ["Juan-R"] = { done = {}, skips = {}, visited = {} } } }
M.best, M.pos, M.level = 1438, { [1438] = { 0.5, 0.5 } }, 6

----- 1. The generated data file: loads, credits ATT, and covers the Night Elf route's quests.
assert(loadfile(ADDON_PATH .. "/QuestRewards.lua"))("LevelGuide", {})
local real = LevelGuideQuestRewards
assert(type(real) == "table" and type(real.r) == "table", "QuestRewards.lua defines LevelGuideQuestRewards.r")
local count = 0
for id, list in pairs(real.r) do
    count = count + 1
    assert(type(id) == "number" and list:match("^%d+[%d,]*$"), "record format: " .. tostring(id) .. "=" .. tostring(list))
end
assert(count > 300, "quests with rewards: " .. count)
assert(real.source == "ATT db/Camelot", "source named: " .. tostring(real.source))
-- Teldrassil: Mist (938) gives a choice of three greens; Gnarlpine Corruption (941) its item.
assert(real.r[938] == "5590,5593,5618" and real.r[941] == "5218", "known Teldrassil rewards: " .. tostring(real.r[938]))
-- Ahead.lua makes no frame while loading (lg_mock takes the first frame made as LevelGuide's events frame).
assert(loadfile(ADDON_PATH .. "/Ahead.lua"))("LevelGuide", {})
assert(#M.frames == 0, "Ahead.lua made a frame on load")
print("1 ok")

----- 2. The guide line, from a test route and test rewards.
LevelGuideQuestRewards = { r = { [401] = "9001,9002", [402] = "9003", [403] = "9004", [404] = "9005" } }
local verdicts = {
    [9001] = { upgrade = false, verdict = "SELL", reason = "Not an upgrade" },
    [9002] = { upgrade = true, verdict = "EQUIP", reason = "Upgrade for healer (+5, 10%)", gain = 5, percent = 10 },
    [9003] = { upgrade = false, verdict = "SELL", reason = "A priest can't wear this" },
    [9004] = { upgrade = true, verdict = "KEEP", reason = "Upgrade at level 14 (+9)", gain = 9, level = 14 },
    [9005] = { upgrade = true, verdict = "EQUIP", reason = "Upgrade for healer (+20, 40%)", gain = 20, percent = 40 },
}
local judged = 0
ItemAdvisor_Judge = function(id) judged = judged + 1; return verdicts[id] end
C_Item.GetItemInfo = function(id)
    if id == 9002 then return "Sapling Robe", "|cff1eff00|Hitem:9002|h[Sapling Robe]|h|r" end
    if id == 9004 then return "Moonlit Cord", "|cff1eff00|Hitem:9004|h[Moonlit Cord]|h|r" end
    if id == 9005 then return "Far Boots", nil end
end
local R
M.load(ADDON_PATH, function()
    R = { zone = "Teldrassil", min = 1, max = 20, steps = {
        { t = "accept", q = "Q1", npc = "A", x = 50, y = 49, lvl = 5 },
        { t = "turnin", q = "Q1", npc = "A", x = 50, y = 49, lvl = 5 },
        { t = "accept", q = "Q2", npc = "B", x = 52, y = 50, lvl = 6 },
        { t = "turnin", q = "Q2", npc = "B", x = 52, y = 50, lvl = 6 },
        { t = "accept", q = "Q3", npc = "C", x = 54, y = 50, lvl = 7 },
        { t = "turnin", q = "Q3", npc = "C", x = 54, y = 50, lvl = 7 },
        { t = "accept", q = "Q4", npc = "D", x = 56, y = 50, lvl = 7, cls = "WARRIOR" },
        { t = "turnin", q = "Q4", npc = "D", x = 56, y = 50, lvl = 7, cls = "WARRIOR" },
    } }
    LevelGuideRoutes.chains.NightElf = { R }
    LevelGuideQuestIDs = { ids = { Q1 = { 401 }, Q2 = { 402 }, Q3 = { 403 }, Q4 = { 404 } }, renamed = {} }
    LevelGuidePrereqs = {}
end)
local function aheadLine()
    for _, b in ipairs(M.buttons) do
        if b.shown and b.left.text:find("Upgrade ahead:", 1, true) then return b.left.text end
    end
end
M.update()
local line = aheadLine()
assert(line and line:find("[Sapling Robe]", 1, true) and line:find("from Q1 (step 2)", 1, true), "first upgrade: " .. tostring(line))
assert(line:find("+10%", 1, true), "its gain: " .. line)
assert(not line:find("Far Boots", 1, true), "a class-only step (another class) isn't looked at")
local list = LevelGuide_UpgradesAhead()
assert(#list == 2 and list[1].step == 2 and list[2].step == 6, "two upgrades, in route order: " .. #list)
assert(list[2].level == 14 and list[2].itemText:find("Moonlit Cord", 1, true), "an upgrade for a later level")
-- A copy: changing it doesn't change the guide's list.
list[1].quest = "changed"
assert(LevelGuide_UpgradesAhead()[1].quest == "Q1", "callers get copies")
print("2 ok")

----- 3. Throttled: the same route isn't judged again for REFRESH seconds; a handed-in quest drops out at once.
local before = judged
M.update(0.2)
assert(judged == before, "judged again within REFRESH: " .. judged - before)
M.flagged[401] = true
M.char.done = M.char.done or {}
M.update()
line = aheadLine()
assert(line and line:find("from Q3 (step 6)", 1, true), "Q1 handed in, next upgrade: " .. tostring(line))
print("3 ok")

----- 4. Still loading: nothing shown, asked again soon; in combat the last list stays.
verdicts[9004] = nil
M.now = M.now + 10
M.update()
assert(aheadLine() == nil or not aheadLine():find("Moonlit", 1, true), "loading item not shown")
verdicts[9004] = { upgrade = true, verdict = "KEEP", reason = "Upgrade at level 14 (+9)", gain = 9, level = 14 }
M.now = M.now + 1.5
M.update()
assert(aheadLine() and aheadLine():find("Moonlit", 1, true), "judged again once loaded")
UnitAffectingCombat = function() return true end
verdicts[9004] = nil
M.now = M.now + 10
M.update()
assert(aheadLine() and aheadLine():find("Moonlit", 1, true), "combat keeps the last list")
UnitAffectingCombat = function() return false end
verdicts[9004] = { upgrade = true, verdict = "KEEP", reason = "Upgrade at level 14 (+9)", gain = 9, level = 14 }
print("4 ok")

----- 5. The window: our own frame, made on the first click of the line.
local row
for _, b in ipairs(M.buttons) do
    if b.shown and b.left.text:find("Upgrade ahead:", 1, true) then row = b end
end
assert(row, "the line is a button")
local framesBefore = #M.frames
row.scripts.OnClick(row, "LeftButton")
assert(LevelGuideAheadFrame and LevelGuideAheadFrame.shown, "the window opens")
assert(#M.frames > framesBefore, "window built on demand")
local shownRows = 0
for _, f in ipairs(LevelGuideAheadFrame.rows) do
    if f.shown then shownRows = shownRows + 1 end
end
assert(shownRows == 1 and LevelGuideAheadFrame.rows[1].left.text:find("Moonlit Cord", 1, true), "window rows: " .. shownRows)
row.scripts.OnClick(row, "LeftButton")
assert(not LevelGuideAheadFrame.shown, "a second click closes it")
print("5 ok")

----- 6. Without ItemAdvisor: no line, no error.
ItemAdvisor_Judge = nil
M.now = M.now + 10
M.update()
assert(aheadLine() == nil, "no ItemAdvisor: no line")
assert(#M.handled == 0, "clean: " .. tostring(M.handled[1]))
print("ALL TESTS PASSED")
