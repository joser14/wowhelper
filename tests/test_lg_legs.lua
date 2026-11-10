-- Cross-zone legs: a race chain of ordered legs that revisit zones (Darkshore, a Stormwind/Loch Modan
-- trip, Darkshore again). The guide follows the leg order with level gates, recognises a leg by any of
-- its zones, and doesn't drag you back to an earlier leg once a later one is under way.
-- ADDON_PATH = LevelGuide.
local M = dofile("lg_mock.lua")
LevelGuideDB = { characters = { ["Juan-R"] = { done = {}, skips = {}, visited = {} } } }
M.info[1415] = { mapID = 1415, name = "Eastern Kingdoms", mapType = 2, parentMapID = 947 }
M.info[1453] = { mapID = 1453, name = "Stormwind City", mapType = 3, parentMapID = 1415 }
M.info[1432] = { mapID = 1432, name = "Loch Modan", mapType = 3, parentMapID = 1415 }
local function A(q, npc, x, y, lvl) return { t = "accept", q = q, npc = npc, x = x, y = y, lvl = lvl } end
local function Travel(text, zone, x, y, lvl) return { t = "zone", text = text, reach = zone, x = x, y = y, lvl = lvl } end
local function On(zone, step) step.map = zone return step end
local DA, EK, DB
M.load(ADDON_PATH, function()
    DA = { zone = "Darkshore", min = 11, max = 15, leg = true, steps = {
        A("Shore Quest", "Npc A", 40, 40, 11),
        Travel("Boat to Stormwind", "Stormwind City", 30.7, 41.0, 14),
    } }
    EK = { zone = "Loch Modan", key = "EK", name = "Loch Modan trip", zones = { "Stormwind City", "Loch Modan" },
        min = 14, max = 16, leg = true, steps = {
            On("Stormwind City", A("City Quest", "Clerk", 50, 50, 14)),
            A("Loch Quest", "Npc L", 35, 47, 14),
            { t = "hearth", text = "Auberdine", place = "Auberdine", lvl = 16 },
        },
        ways = { { from = "Darkshore", text = "Boat to Stormwind (dock)", x = 30.7, y = 41.0 } } }
    DB = { zone = "Darkshore", min = 15, max = 19, leg = true, steps = {
        A("North Quest", "Npc B", 45, 30, 15),
    } }
    LevelGuideRoutes.chains.NightElf = { DA, EK, DB }
    LevelGuideQuestIDs = { ids = { ["Shore Quest"] = { 9001 }, ["City Quest"] = { 9002 } }, renamed = {} }
    LevelGuidePrereqs = nil
end)
local function rows()
    local t = {}
    for _, b in ipairs(M.buttons) do if b.shown and b.step then t[#t + 1] = b.left.text end end
    return table.concat(t, "\n")
end
local function header() local f = M.font("Route:") return f and f.text or "" end
local function inDarkshore() M.best, M.pos = 1439, { [1439] = { 0.37, 0.44 } } end

-- 1. Level 12 in Darkshore: the first Darkshore leg.
inDarkshore(); M.level = 12; M.update()
assert(header():find("Route: Darkshore", 1, true), "first leg: " .. header())
assert(rows():find("Shore Quest", 1, true), "its quest: " .. rows())
print("1 ok")

-- 2. Level 14, its quest done: the boat is next.
M.flagged[9001] = true; M.level = 14; M.update()
assert(M.current.left.text:find("Boat to Stormwind", 1, true), "boat: " .. rows())
M.flagged[9001] = nil
print("2 ok")

-- 3. Off the boat in Stormwind at 14 with a Darkshore quest left behind: the trip leg (one of its zones),
-- not "go back to Darkshore". Its key is the leg's own.
M.best, M.pos = 1453, { [1453] = { 0.5, 0.5 } }; M.update()
assert(header():find("Route: Loch Modan trip", 1, true), "trip leg by its zones: " .. header() .. "\n" .. rows())
assert(M.current.left.text:find("City Quest", 1, true) and M.current.step.mapID == 1453, "city step placed: " .. rows())
assert(tostring(M.current.step.routeKey):find("^EK|"), "leg key: " .. tostring(M.current.step.routeKey))
print("3 ok")

-- 4. Hearth back to Auberdine at 15 with the trip under way (City Quest taken) and the old Darkshore quest
-- still undone: the next Darkshore leg, not the first one again.
M.log = { { questID = 9002, title = "City Quest" } }
inDarkshore(); M.level = 15; M.update()
assert(header():find("Route: Darkshore", 1, true) and rows():find("North Quest", 1, true)
    and not rows():find("Shore Quest", 1, true), "later leg, earlier one passed: " .. rows())
M.log = {}
print("4 ok")

-- 5. Level 14 in Darkshore, the first leg finished (boat skipped) and the trip not started: the trip's way
-- from Darkshore (the dock) is the stop, with an arrow, before the later Darkshore leg (level 15).
M.flagged[9001] = true
M.char.skips["Darkshore|zone|Boat to Stormwind||"] = true
M.level = 14; M.update()
assert(M.current.left.text:find("Boat to Stormwind (dock)", 1, true) and M.current.step.mapID == 1439
    and math.abs(M.current.step.x - 0.307) < 1e-6, "way to the trip: " .. rows())
print("5 ok")

-- 6. Off-plan: level 17 in Darkshore with the trip never done: the trip is outleveled by its band, the
-- later Darkshore leg runs.
M.level = 17; M.update()
assert(rows():find("North Quest", 1, true), "recovers at 17: " .. rows())
assert(#M.handled == 0, "clean: " .. tostring(M.handled[1]))
print("ALL TESTS PASSED")
