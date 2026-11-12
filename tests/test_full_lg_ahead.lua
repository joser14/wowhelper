-- Full review (LevelGuide): "Upgrade ahead" (Ahead.lua, X.AheadQuests) only names rewards the route will
-- really bring you, and doesn't go stale or blank.
--   1. A hand-in the guide passes (a step 4+ levels below you) isn't an upgrade ahead.
--   2. A hand-in whose pick-up you skipped (and don't hold) isn't either.
--   3. When ItemAdvisor can't read your worn gear (every reward comes back nil), the last list stays.
--   4. With no route for you any more, the line and the list are cleared.
-- ADDON_PATH = LevelGuide.
local M = dofile("lg_mock.lua")
LevelGuideDB = { characters = { ["Juan-R"] = { done = {}, skips = {}, visited = {} } } }
M.best, M.pos, M.level = 1438, { [1438] = { 0.5, 0.5 } }, 11

assert(loadfile(ADDON_PATH .. "/Ahead.lua"))("LevelGuide", {})
LevelGuideQuestRewards = { r = { [501] = "9001", [502] = "9002", [503] = "9003" } }
local verdicts = {
    [9001] = { upgrade = true, verdict = "EQUIP", reason = "Upgrade for healer (+5, 10%)", gain = 5, percent = 10 },
    [9002] = { upgrade = true, verdict = "EQUIP", reason = "Upgrade for healer (+6, 12%)", gain = 6, percent = 12 },
    [9003] = { upgrade = true, verdict = "EQUIP", reason = "Upgrade for healer (+7, 14%)", gain = 7, percent = 14 },
}
local hidden = false
ItemAdvisor_Judge = function(id)
    if hidden then return nil end   -- ItemAdvisor: "Can't read your worn gear right now" gives nil
    return verdicts[id]
end
C_Item.GetItemInfo = function(id) return "Item " .. id, "|cff1eff00|Hitem:" .. id .. "|h[Item " .. id .. "]|h|r" end

M.load(ADDON_PATH, function()
    local R = { zone = "Teldrassil", min = 1, max = 20, steps = {
        { t = "accept", q = "Q1", npc = "A", x = 50, y = 49, lvl = 11 },
        { t = "accept", q = "Q2", npc = "B", x = 51, y = 50, lvl = 11 },
        { t = "turnin", q = "Q1", npc = "A", x = 50, y = 49, lvl = 11 },
        { t = "turnin", q = "Q2", npc = "B", x = 51, y = 50, lvl = 11 },
        -- Written for level 6: at 11 the guide passes it (K.OUTLEVELED = 4).
        { t = "turnin", q = "Q3", npc = "C", x = 52, y = 50, lvl = 6 },
    } }
    LevelGuideRoutes.chains.NightElf = { R }
    LevelGuideQuestIDs = { ids = { Q1 = { 501 }, Q2 = { 502 }, Q3 = { 503 } }, renamed = {} }
    LevelGuidePrereqs = {}
end)

local function aheadLine()
    for _, b in ipairs(M.buttons) do
        if b.shown and b.left.text:find("Upgrade ahead:", 1, true) then return b.left.text end
    end
    return nil
end
local function quests()
    local t = {}
    for _, e in ipairs(LevelGuide_UpgradesAhead()) do t[#t + 1] = e.quest end
    return table.concat(t, ",")
end

M.update()
assert(aheadLine() and aheadLine():find("from Q1", 1, true), "first upgrade: " .. tostring(aheadLine()))
-- 1. Q3's hand-in is passed by the guide (6 + 4 <= 11).
assert(quests() == "Q1,Q2", "a passed hand-in isn't ahead: " .. quests())
print("1 ok")

-- 2. Skip Q2's pick-up (Shift+right-click): its hand-in won't happen.
IsShiftKeyDown = function() return true end
local skipped
for _, b in ipairs(M.buttons) do
    if b.shown and b.step and b.step.quest == "Q2" and b.step.stepType == "accept" then
        b.scripts.OnClick(b, "RightButton")
        skipped = true
        break
    end
end
IsShiftKeyDown = function() return false end
assert(skipped, "Q2's pick-up shown")
M.update()
assert(quests() == "Q1", "a hand-in whose pick-up you skipped isn't ahead: " .. quests())
print("2 ok")

-- 3. Worn gear unreadable (ItemAdvisor answers nil for every reward): the last list stays.
hidden = true
M.now = M.now + 10
M.update()
assert(aheadLine() and aheadLine():find("from Q1", 1, true), "hidden gear keeps the line: " .. tostring(aheadLine()))
assert(quests() == "Q1", "hidden gear keeps the list: " .. quests())
hidden = false
M.now = M.now + 10
M.update()
assert(quests() == "Q1", "readable again: " .. quests())
print("3 ok")

-- 4. No route for you any more (well past the route's levels): nothing stale is left.
M.level = 45
M.now = M.now + 10
M.update()
assert(aheadLine() == nil, "no route, no upgrade line: " .. tostring(aheadLine()))
assert(quests() == "", "no route, empty list: " .. quests())
assert(#M.handled == 0, "clean: " .. tostring(M.handled[1]))
print("ALL TESTS PASSED")
