-- Travel planner (LevelGuide\TravelPlan.lua, research\guides_deep_re.md 12.7): the shortest time over walking
-- (straight yards at run speed, winding 1.25, a penalty per zone crossed and for zones well above you), the
-- flights you know (an unknown one only as a start, learned on the spot), boats, tram, portals and zeppelin
-- with wait + ride, and the hearthstone when it's ready and saves real time. Pure arithmetic: no game calls.
-- ADDON_PATH = LevelGuide.
assert(loadfile(ADDON_PATH .. "/Travel.lua"))("LevelGuide", {})
assert(loadfile(ADDON_PATH .. "/Planner.lua"))("LevelGuide", {})
assert(loadfile(ADDON_PATH .. "/TravelPlan.lua"))("LevelGuide", {})
local P = LevelGuidePlanner
assert(type(P.TravelPlan) == "function", "TravelPlan")

local function known(list)
    local set = {}
    for _, name in ipairs(list or {}) do set[name] = true end
    return function(name) return set[name] or false end
end
local function kinds(plan)
    local t = {}
    for _, leg in ipairs(plan.legs) do t[#t + 1] = leg.kind end
    return table.concat(t, ",")
end
local function texts(plan)
    local t = {}
    for _, leg in ipairs(plan.legs) do t[#t + 1] = leg.text end
    return table.concat(t, " | ")
end
local function find(plan, kind)
    for _, leg in ipairs(plan.legs) do if leg.kind == kind then return leg end end
end

local DOLANAAR = { map = 1438, x = 55.6, y = 59.8 }
local AUBERDINE = { map = 1439, x = 38.0, y = 44.0 }

-- 1. The pieces: world yards from map percent, danger by zone level, the zone under a point.
local c, wx, wy = P.TravelWorld(1439, 36.3, 45.6)
assert(c == 1 and math.abs(wx - 6343) < 15 and math.abs(wy - 561.5) < 15, "Caylais in world yards: " .. tostring(wx) .. "," .. tostring(wy))
assert(P.TravelDanger(1440, 10) == 3 and P.TravelDanger(1440, 18) == 1 and P.TravelDanger(1444, 20) == 20 and P.TravelDanger(1453, 1) == 1, "danger")
assert(P.TravelZoneAt(P.TravelWorld(1439, 50, 50)) == 1439, "Darkshore under its middle")
local yards = P.TravelYards({ map = 1439, x = 36.3, y = 45.6 }, { map = 1438, x = 58.4, y = 94.0 })
assert(yards and yards > 2000 and yards < 2700, "Auberdine to Rut'theran in yards: " .. tostring(yards))
assert(P.TravelYards({ map = 1439, x = 36, y = 45 }, { map = 1453, x = 50, y = 50 }) == nil, "no yards across continents")
print("1 ok")

-- 2. Dolanaar to Auberdine at 12 with no flight known: the portal down, then the boat. Never a walk across the sea.
local plan = P.TravelPlan({ from = DOLANAAR, to = AUBERDINE, level = 12, known = known() })
print("2: " .. kinds(plan) .. " | " .. texts(plan) .. " | " .. math.floor(plan.total))
assert(kinds(plan) == "walk,portal,walk,boat,walk", "portal then boat: " .. kinds(plan))
assert(plan.legs[2].text == "Take the portal in Darnassus to Rut'theran Village", plan.legs[2].text)
assert(plan.legs[1].to.map == 1457 and math.abs(plan.legs[1].to.x - 28.5) < 0.01, "walk to the portal in Darnassus")
local boat = find(plan, "boat")
assert(boat.text:find("^Take the boat at Rut'theran Village dock to Auberdine north pier, ~%d+ min$"), boat.text)
assert(boat.seconds == 250, "wait + ride: " .. boat.seconds)
assert(plan.total > 300 and plan.total < 1200, "total " .. plan.total)
print("2 ok")

-- 3. Both flight points known: the flight instead of the boat.
plan = P.TravelPlan({ from = DOLANAAR, to = AUBERDINE, level = 12, known = known({ "Rut'theran Village", "Auberdine" }) })
print("3: " .. texts(plan))
assert(kinds(plan) == "walk,portal,walk,fly,walk", kinds(plan))
local fly = find(plan, "fly")
assert(fly.text:find("^Fly Rut'theran Village to Auberdine, ~%d+ min$"), fly.text)
assert(fly.from.map == 1438 and math.abs(fly.from.x - 58.4) < 0.01, "boards at Vesprystus")
print("3 ok")

-- 4. Rut'theran unknown, Auberdine known: learned on the spot, then flown. Auberdine unknown: no flight there.
plan = P.TravelPlan({ from = DOLANAAR, to = AUBERDINE, level = 12, known = known({ "Auberdine" }) })
fly = find(plan, "fly")
assert(fly and fly.learn and fly.text:find("^Learn the flight path at Rut'theran Village, then fly to Auberdine"), "learn first: " .. texts(plan))
plan = P.TravelPlan({ from = DOLANAAR, to = AUBERDINE, level = 12, known = known({ "Rut'theran Village" }) })
assert(not find(plan, "fly") and find(plan, "boat"), "can't fly to a flight point you don't know: " .. texts(plan))
print("4 ok")

-- 5. A flight time you've learned replaces the estimate (a slow one makes the boat better).
plan = P.TravelPlan({ from = DOLANAAR, to = AUBERDINE, level = 12, known = known({ "Rut'theran Village", "Auberdine" }),
    learned = { ["Rut'theran Village>Auberdine"] = 600 } })
assert(find(plan, "boat") and not find(plan, "fly"), "learned slow flight: " .. texts(plan))
print("5 ok")

-- 6. Auberdine to Stormwind at 14: the Forever boat to Stormwind Harbor.
local STORMWIND = { map = 1453, x = 60, y = 70 }
plan = P.TravelPlan({ from = { map = 1439, x = 37, y = 44 }, to = STORMWIND, level = 14, known = known({ "Auberdine" }) })
print("6: " .. texts(plan))
boat = find(plan, "boat")
assert(boat and boat.text:find("^Take the boat at Auberdine pier to Stormwind Harbor, ~3 min$"), "boat to Stormwind: " .. texts(plan))
assert(plan.legs[1].kind == "walk" and plan.legs[1].to.name == "Auberdine pier", "walk to the pier first")
print("6 ok")

-- 7. Stormwind to Ironforge without flights: the Deeprun Tram.
plan = P.TravelPlan({ from = STORMWIND, to = { map = 1455, x = 40, y = 50 }, level = 14, known = known() })
local tram = find(plan, "tram")
assert(tram and tram.text:find("^Take the Deeprun Tram to Ironforge, ~%d+ min$"), "tram: " .. texts(plan))
print("7 ok")

-- 8. The hearthstone: from Stormwind back to Auberdine with the hearth bound there; not for a short trip.
local INN = { map = 1439, x = 37.0, y = 44.1, name = "Auberdine" }
plan = P.TravelPlan({ from = STORMWIND, to = AUBERDINE, level = 15, known = known(), hearth = INN })
print("8: " .. texts(plan))
assert(plan.legs[1].kind == "hearth" and plan.legs[1].text == "Use your hearthstone to Auberdine", "hearth: " .. texts(plan))
assert(plan.total < 200, "hearth is quick: " .. plan.total)
plan = P.TravelPlan({ from = { map = 1439, x = 37, y = 47 }, to = AUBERDINE, level = 15, known = known(), hearth = INN })
assert(kinds(plan) == "walk", "short trip: walk: " .. kinds(plan))
-- Saves under two minutes: kept for later. Darkshore south (about 3 min walk) to Auberdine.
plan = P.TravelPlan({ from = { map = 1439, x = 41, y = 62 }, to = AUBERDINE, level = 15, known = known(), hearth = INN })
assert(not find(plan, "hearth"), "saves too little: " .. texts(plan) .. " " .. plan.total)
print("8 ok")

-- 9. Zones well above you are avoided: Thelsamar to Menethil at 12 walks round by Dun Morogh, through the
-- Wetlands (goal zone, exempt), rather than pricing a straight line over higher ground as if it were safe.
local slow = P.TravelPlan({ from = { map = 1432, x = 34, y = 50 }, to = { map = 1437, x = 10, y = 60 }, level = 12, known = known() })
local fast = P.TravelPlan({ from = { map = 1432, x = 34, y = 50 }, to = { map = 1437, x = 10, y = 60 }, level = 40, known = known() })
assert(slow.total >= fast.total, "danger costs time: " .. slow.total .. " vs " .. fast.total)
-- Known flights there: fly.
plan = P.TravelPlan({ from = { map = 1432, x = 34, y = 50 }, to = { map = 1437, x = 10, y = 60 }, level = 12,
    known = known({ "Thelsamar", "Menethil Harbor" }) })
assert(find(plan, "fly") and find(plan, "fly").text:find("^Fly Thelsamar to Menethil Harbor"), "fly: " .. texts(plan))
print("9 ok")

-- 10. Hops are merged into one flight; Ironforge to Darkshore crosses by boat from Menethil.
plan = P.TravelPlan({ from = { map = 1455, x = 50, y = 50 }, to = { map = 1437, x = 10, y = 60 }, level = 30,
    known = known({ "Ironforge", "Thelsamar", "Menethil Harbor" }) })
local flights = 0
for _, leg in ipairs(plan.legs) do if leg.kind == "fly" then flights = flights + 1 end end
assert(flights == 1, "one flight leg: " .. texts(plan))
plan = P.TravelPlan({ from = { map = 1455, x = 50, y = 50 }, to = AUBERDINE, level = 30, known = known() })
boat = find(plan, "boat")
assert(boat and boat.to.map == 1439, "a boat to Darkshore: " .. texts(plan))
print("10 ok")

-- 11. Zephras Isle leaves by zeppelin; nothing at all where no way is known (an unknown map).
plan = P.TravelPlan({ from = { map = 2521, x = 50, y = 50 }, to = { map = 1424, x = 50, y = 55 }, level = 13, known = known() })
assert(plan and find(plan, "zeppelin"), "zeppelin: " .. (plan and texts(plan) or "nil"))
assert(P.TravelPlan({ from = { map = 9999, x = 50, y = 50 }, to = AUBERDINE, level = 13, known = known() }) == nil, "unknown map: no plan")
print("11 ok")

-- 12. Fast enough to run on every step change: 200 plans well under a second here.
local t0 = os.clock()
for i = 1, 200 do
    P.TravelPlan({ from = { map = 1438, x = 50 + i % 7, y = 60 }, to = AUBERDINE, level = 12, known = known({ "Auberdine" }) })
end
print(string.format("12 ok: %.1f ms a plan", (os.clock() - t0) * 1000 / 200))
print("ALL TESTS PASSED")
