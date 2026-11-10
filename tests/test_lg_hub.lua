-- Exact order inside a hub (research\guides_deep_re.md 12.11): when the stops around the current one (within
-- 100 yd, NPCs within 10 yd counted as one) are 7 groups or fewer, the guide walks them in the shortest order
-- (Held-Karp), not nearest-first, keeping what must come first; it changes nothing that saves 5 yd or less.
-- ADDON_PATH = LevelGuide.
local M = dofile("lg_mock.lua")
LevelGuideDB = { characters = { ["Juan-R"] = { done = {}, skips = {}, visited = {} } } }
-- Teldrassil is 5000 yd wide in the mock: 0.1 map percent = 5 yd.
M.best, M.pos, M.level = 1438, { [1438] = { 0.5, 0.5 } }, 6
local R
M.load(ADDON_PATH, function()
    R = { zone = "Teldrassil", min = 1, max = 20, steps = {
        { t = "accept", q = "Here", npc = "Giver H", x = 50, y = 50, lvl = 5 },
        { t = "accept", q = "East", npc = "Giver E", x = 50.4, y = 50, lvl = 5 },    -- 20 yd east
        { t = "accept", q = "West", npc = "Giver W", x = 49.4, y = 50, lvl = 5 },    -- 30 yd west
        { t = "accept", q = "Far East", npc = "Giver F", x = 51.2, y = 50, lvl = 5 }, -- 60 yd east
    } }
    LevelGuideRoutes.chains.NightElf = { R }
    LevelGuideQuestIDs = { ids = {}, renamed = {} }
    LevelGuidePrereqs = {}
end)
local function order()
    local t = { M.current.left.text }
    for _, b in ipairs(M.buttons) do
        if b ~= M.current and b.shown and b.step and b.left.text:find("^|cff999999%d") then t[#t + 1] = b.left.text end
    end
    return table.concat(t, "\n")
end
M.update()
-- Nearest first would go East (20), Far East (40), back West (90) = 150 yd; West, East, Far East is 120.
local text = order()
local w, e, f = text:find("West", 1, true), text:find("|r East", 1, true), text:find("Far East", 1, true)
assert(M.current.left.text:find("Here", 1, true), "the current stop stays: " .. text)
assert(w and e and f and w < e and e < f, "shortest walk through the hub: " .. text)
print("1 ok")

-- The planner on its own: constraints are kept, groups of NPCs within 10 yd count once, a gain of 5 yd or
-- less changes nothing, and more than 7 groups are left to nearest-first.
local P = LevelGuidePlanner
local function yards(a, b) return math.sqrt((a.x - b.x) ^ 2 + (a.y - b.y) ^ 2) end
local start = { x = 0, y = 0 }
local items = { { x = 20, y = 0 }, { x = -30, y = 0 }, { x = 60, y = 0 } }
local best = P.HubOrder(start, items, yards, {}, { 1, 3, 2 })
assert(best and table.concat(best, ",") == "2,1,3", "exact: " .. tostring(best and table.concat(best, ",")))
-- West (2) must come after Far East (3): then 1, 3, 2 is the best there is, and that's the order given.
assert(P.HubOrder(start, items, yards, { [2] = { [3] = true } }, { 1, 3, 2 }) == nil, "constraint kept, nothing better")
local con = P.HubOrder(start, items, yards, { [1] = { [2] = true } }, { 3, 1, 2 })
assert(con and table.concat(con, ",") == "2,1,3", "after its prerequisite: " .. tostring(con and table.concat(con, ",")))
-- Two NPCs 4 yd apart are one group; the turn-in there goes first.
local pair = { { x = 20, y = 0, kind = "pickup" }, { x = 20, y = 4, kind = "turnin" }, { x = -30, y = 0 } }
local p2 = P.HubOrder(start, pair, yards, {}, { 1, 3, 2 })
assert(p2 and table.concat(p2, ",") == "2,1,3", "grouped, turn-in first: " .. tostring(p2 and table.concat(p2, ",")))
-- A building costs 60 yd to enter and leave: the indoor stop comes last.
local inside = { { x = 10, y = 0, inside = true }, { x = -10, y = 0 }, { x = 20, y = 0 } }
local p3 = P.HubOrder(start, inside, yards, {}, { 1, 2, 3 })
assert(p3 and p3[3] == 1, "indoors last: " .. tostring(p3 and table.concat(p3, ",")))
assert(P.HubOrder(start, { { x = 3, y = 0 }, { x = 6, y = 0 } }, yards, {}, { 2, 1 }) == nil, "5 yd or less: no change")
local many = {}
for i = 1, 8 do many[i] = { x = i * 15, y = (i % 2) * 15 } end
assert(P.HubOrder(start, many, yards, {}, { 1, 2, 3, 4, 5, 6, 7, 8 }) == nil, "8 groups: nearest-first stays")
assert(#M.handled == 0, "clean: " .. tostring(M.handled[1]))
print("ALL TESTS PASSED")
