-- Boat departures (research\re_round3.md rank 5; LevelGuide\Boats.lua from Shortest Path Forever, GPL):
-- * each ship's period and stop times; without a known departure the wait is half a period ("~"), the ride the
--   time between leaving one stop and reaching the next;
-- * a departure learned from your own boarding (at the pier, then off it at 12 yd/s or more) or landing makes the
--   wait exact for 6 hours ("leaves in 1:10"), kept per realm;
-- * walking off the pier on foot is not "On the boat" (review 3, finding 4). ADDON_PATH = LevelGuide.
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
local P = LevelGuidePlanner
assert(LevelGuideBoats, "Boats.lua loads")

-- 1. Unanchored: half a period to wait, the ride from Stormwind's departure to Auberdine's arrival.
local wait, ride, anchored = P.BoatTimes("boat-auberdine-stormwind", true, server, {})
assert(math.abs(wait - 247.096 / 2) < 1e-6 and not anchored, "half a period: " .. wait)
assert(math.abs(ride - ((34.804 - 222.116) % 247.096)) < 1e-6, "ride: " .. ride)
-- 2. Anchored 10 s after the ship reached Stormwind: docked, leaves in 50 s.
local anchors = { [11616] = { epoch = server - 162.089 - 10, seen = server } }
wait, ride, anchored = P.BoatTimes("boat-auberdine-stormwind", true, server, anchors)
assert(anchored and math.abs(wait - (222.116 - 162.089 - 10)) < 1e-6, "docked: " .. wait)
-- Just after it left: nearly a whole period.
anchors[11616].epoch = server - 222.116 - 1
wait = P.BoatTimes("boat-auberdine-stormwind", true, server, anchors)
assert(math.abs(wait - (247.096 - 1)) < 1e-6, "missed it: " .. wait)
-- Stale after 6 hours.
anchors[11616].seen = server - 6 * 3600 - 1
assert(not select(3, P.BoatTimes("boat-auberdine-stormwind", true, server, anchors)), "expired")
print("1-2 ok")

-- 3. Learning: a departure seen from Stormwind, then a landing 8 s off is averaged in.
anchors = {}
P.BoatLearn(anchors, "boat-auberdine-stormwind", true, "depart", server)
assert(math.abs(anchors[11616].epoch - (server - 222.116)) < 1e-6, "epoch from a departure")
P.BoatLearn(anchors, "boat-auberdine-stormwind", true, "arrive", server + ride + 4)
assert(math.abs(anchors[11616].epoch - (server - 222.116 + 2)) < 1e-6, "averaged: " .. anchors[11616].epoch)
print("3 ok")

-- 4. In the guide: in Stormwind, the boat leg says when it leaves (from now, after the walk to the pier) once a
-- departure is known.
M.level = 13
M.best, M.pos = 1453, { [1453] = { 0.6, 0.7 } }
M.fire("ZONE_CHANGED_NEW_AREA")
M.update()
local step = M.current.step
assert(step and tostring(step.title):find("^Take the boat at Stormwind Harbor"), "boat leg: " .. tostring(step and step.title))
assert(tostring(step.title):find("~", 1, true), "estimated without a departure: " .. step.title)
LevelGuideDB.boats = { ["R"] = { [11616] = { epoch = server - 162.089 - 10, seen = server } } }
M.now = M.now + 31
M.fire("ZONE_CHANGED_NEW_AREA")
M.update()
step = M.current.step
assert(tostring(step.title):find("leaves in %d+:%d%d$"), "exact: " .. tostring(step.title))
print("4 ok")

-- 5. Walking off the pier is not riding the boat; leaving it at boat speed is, and teaches the departure.
LevelGuideDB.boats = {}
M.pos[1453] = { 0.225, 0.56 }
M.now = M.now + 31; M.update()
assert(tostring(M.current.step.title):find("^Take the boat"), "at the pier")
M.pos[1453] = { 0.20, 0.56 }   -- about 43 yd in 6 s: walking
M.now = M.now + 6; M.update()
assert(not tostring(M.current.step.title):find("^On the boat"), "walking: " .. tostring(M.current.step.title))
M.pos[1453] = { 0.225, 0.56 }
M.now = M.now + 31; M.update()
M.pos[1453] = { 0.15, 0.56 }   -- about 130 yd in 3 s: on the boat
M.now = M.now + 3; server = server + 3; M.update()
assert(M.current.step.title == "On the boat to Auberdine pier", "riding: " .. tostring(M.current.step.title))
local learned = LevelGuideDB.boats and LevelGuideDB.boats.R and LevelGuideDB.boats.R[11616]
assert(learned and math.abs(learned.epoch - (server - 222.116)) < 5, "departure learned: " .. tostring(learned and learned.epoch))
assert(#M.handled == 0, "clean: " .. tostring(M.handled[1]))
print("ALL TESTS PASSED")
