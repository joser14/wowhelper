-- Final review of LevelGuide (research\final_review_levelguide.md): a boat leg with a known departure
-- ("leaves in 0:58") counts down while you wait at the pier, instead of keeping the same time until the
-- plan's 30 s refresh. ADDON_PATH = LevelGuide.
local M = dofile("lg_mock.lua")
LevelGuideDB = { characters = { ["Juan-R"] = { done = {}, skips = {}, visited = {} } } }
M.info[1415] = { mapID = 1415, name = "Eastern Kingdoms", mapType = 2, parentMapID = 947 }
M.info[1453] = { mapID = 1453, name = "Stormwind City", mapType = 3, parentMapID = 1415 }
M.rects[1453] = { 20000, 20000, 1700, 1150 }
local server = 1000000
GetServerTime = function() return server end
M.load(ADDON_PATH, function()
    LevelGuideRoutes.chains.NightElf = { { zone = "Darkshore", min = 1, max = 20, steps = {
        { t = "accept", q = "Shore Quest", npc = "Npc A", x = 38, y = 44, lvl = 12 } } } }
    LevelGuideQuestIDs = { ids = { ["Shore Quest"] = { 9101 } }, renamed = {} }
    LevelGuidePrereqs = nil
end)

M.level = 13
M.best, M.pos = 1453, { [1453] = { 0.225, 0.56 } }   -- at the Stormwind pier
-- The ship reached Stormwind 10 s ago: it leaves in about 50 s.
LevelGuideDB.boats = { ["R"] = { [11616] = { epoch = server - 162.089 - 10, seen = server } } }
M.fire("ZONE_CHANGED_NEW_AREA")
M.update()
local function left()
    local title = tostring(M.current.step and M.current.step.title)
    local m, s = title:match("leaves in (%d+):(%d%d)$")
    assert(m, "a departure time: " .. title)
    return tonumber(m) * 60 + tonumber(s)
end
local first = left()
assert(first > 20, "time to wait: " .. first)
-- Ten seconds later, standing still on the pier.
M.now, server = M.now + 10, server + 10
M.update()
local later = left()
assert(math.abs(first - 10 - later) <= 1, string.format("counts down: %d then %d", first, later))
assert(#M.handled == 0, "clean: " .. tostring(M.handled[1]))
print("ALL TESTS PASSED")
