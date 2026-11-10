-- The travel planner in the guide (research\guides_deep_re.md 12.7): a step on another map shows the next leg
-- of the quickest way there ("Take the portal ...", "Fly Rut'theran Village to Auberdine", "Use your hearthstone
-- to Auberdine", "Take the boat at ...") with the arrow on that leg's spot, and moves on by itself as you
-- arrive, fly or ride. A Way() written in Routes.lua still wins. It never acts: it only says what to do.
-- ADDON_PATH = LevelGuide.
local M = dofile("lg_mock.lua")
LevelGuideDB = { characters = { ["Juan-R"] = { done = {}, skips = {}, visited = {} } } }
M.info[1415] = { mapID = 1415, name = "Eastern Kingdoms", mapType = 2, parentMapID = 947 }
M.info[1453] = { mapID = 1453, name = "Stormwind City", mapType = 3, parentMapID = 1415 }
M.rects[1453] = { 20000, 20000, 1700, 1150 }
local onTaxi, cooldown = false, { 0, 0 }
UnitOnTaxi = function() return onTaxi end
C_Container.GetItemCooldown = function(id) if id == 6948 then return cooldown[1], cooldown[2], 1 end end
local function A(q, npc, x, y, lvl) return { t = "accept", q = q, npc = npc, x = x, y = y, lvl = lvl } end
local TEL, DSH
M.load(ADDON_PATH, function()
    TEL = { zone = "Teldrassil", min = 1, max = 12, steps = { A("Tree Quest", "Npc T", 55, 60, 2) } }
    DSH = { zone = "Darkshore", min = 12, max = 20, steps = { A("Shore Quest", "Npc A", 38, 44, 12) } }
    LevelGuideRoutes.chains.NightElf = { TEL, DSH }
    LevelGuideQuestIDs = { ids = { ["Tree Quest"] = { 9100 }, ["Shore Quest"] = { 9101 } }, renamed = {} }
    LevelGuidePrereqs = nil
end)
M.flagged[9100] = true
local function step() return M.current.step end
local function title() return tostring(step() and step().title) end
local function detail() return tostring(step() and step().detail) end
local function at(map, x, y)
    M.best, M.pos = map, { [map] = { x, y } }
    M.fire("ZONE_CHANGED_NEW_AREA")
    M.update()
end

-- 1. Level 13 in Dolanaar, the route goes on in Darkshore: the portal in Darnassus first, arrow on it.
M.level = 13
at(1438, 0.556, 0.598)
print("1: " .. title() .. " / " .. detail())
assert(title() == "Take the portal in Darnassus to Rut'theran Village", "portal: " .. title())
assert(step().mapID == 1457 and math.abs(step().x - 0.285) < 1e-6, "arrow on the portal")
assert(detail():find("min to Darkshore", 1, true), "how long: " .. detail())
M.update(0.06)
assert(M.arrowShown(), "arrow shown")
print("1 ok")

-- 2. Down in Rut'theran with both flight points known: the flight, arrow on Vesprystus.
M.char.flights = { ["Rut'theran Village, Teldrassil"] = true, ["Auberdine, Darkshore"] = true }
at(1438, 0.559, 0.897)
print("2: " .. title())
assert(title():find("^Fly Rut'theran Village to Auberdine, ~%d min$"), "flight: " .. title())
assert(step().mapID == 1438 and math.abs(step().x - 0.584) < 1e-6, "arrow on the flight master")
print("2 ok")

-- 3. On the flight: the step says so and the arrow rests; nothing is replanned mid-air.
onTaxi = true
M.update()
assert(title() == "Flying to Auberdine", "flying: " .. title())
M.update(0.06)
assert(not M.arrowShown(), "no arrow while flying")
print("3 ok")

-- 4. Landed in Darkshore: the route's own step, no travel leg.
onTaxi = false
at(1439, 0.363, 0.456)
assert(title() == "Shore Quest" and not step().leg, "Darkshore quest: " .. title())
print("4 ok")

-- 5. In Stormwind with the hearthstone ready and bound in Auberdine: hearth, no arrow.
M.bind, M.items[6948] = "Auberdine", 1
at(1453, 0.6, 0.7)
print("5: " .. title())
assert(title() == "Use your hearthstone to Auberdine", "hearth: " .. title())
assert(not step().mapID, "no spot to walk to")
-- On cooldown: the boat home from Stormwind Harbor.
cooldown = { M.now - 60, 3600 }
M.now = M.now + 31; M.update()
print("5b: " .. title())
assert(title():find("^Take the boat at Stormwind Harbor to Auberdine pier, ~%d min$"), "boat: " .. title())
assert(step().mapID == 1453 and math.abs(step().x - 0.225) < 1e-6, "arrow on the harbour")
print("5 ok")

-- 6. At the harbour, then off on the boat: "On the boat to ..." until you land.
at(1453, 0.225, 0.56)
assert(title():find("^Take the boat", 1), "at the dock: " .. title())
M.pos[1453] = { 0.15, 0.56 }   -- leaving at boat speed (walking off isn't riding: test_lg_boats.lua)
M.now = M.now + 3; M.update()
assert(title() == "On the boat to Auberdine pier", "riding: " .. title())
M.now = M.now + 40; M.update()
assert(title() == "On the boat to Auberdine pier", "still riding: " .. title())
at(1439, 0.307, 0.41)
assert(title() == "Shore Quest", "landed: " .. title())
print("6 ok")

-- 7. A way written in Routes.lua (Way()) for the map you're on wins over the planner.
DSH.ways = { { from = "Stormwind City", text = "Written way home", x = 40, y = 40 } }
at(1453, 0.6, 0.7)
assert(title() == "Written way home", "written way: " .. title())
DSH.ways = nil
print("7 ok")

-- 8. Plans are cached: standing still they aren't worked out again on every rebuild.
local calls, plan = 0, LevelGuidePlanner.TravelPlan
LevelGuidePlanner.TravelPlan = function(...) calls = calls + 1 return plan(...) end
cooldown = { 0, 0 }
at(1453, 0.6, 0.7)
local first = calls
for _ = 1, 4 do M.update() end
assert(calls == first, "cached: " .. calls .. " vs " .. first)
LevelGuidePlanner.TravelPlan = plan
assert(#M.handled == 0, "clean: " .. tostring(M.handled[1]))
print("ALL TESTS PASSED")
