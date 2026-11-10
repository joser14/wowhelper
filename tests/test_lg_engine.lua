-- Engine additions: objective counts, loop and nearest points, XP gates by amount, guards that hide
-- (not complete), hearth steps, Reach, and the game's next leg for a quest in another zone.
-- ADDON_PATH = LevelGuide.
local M = dofile("lg_mock.lua")
LevelGuideDB = { characters = { ["Juan-R"] = { done = {}, skips = {}, visited = {} } } }
M.best, M.pos, M.level = 1438, { [1438] = { 0.5, 0.5 } }, 6
local R
M.load(ADDON_PATH, function()
    R = { zone = "Teldrassil", min = 1, max = 20, steps = {} }
    LevelGuideRoutes.chains.NightElf = { R }
    LevelGuideQuestIDs, LevelGuidePrereqs = { ids = {}, renamed = {} }, nil
end)
local function D(q, note, x, y, lvl) return { t = "do", q = q, note = note, x = x, y = y, lvl = lvl } end
local function A(q, npc, x, y, lvl) return { t = "accept", q = q, npc = npc, x = x, y = y, lvl = lvl } end
local function set(steps) R.steps = steps; M.update() end
local function rows()
    local t = {}
    for _, b in ipairs(M.buttons) do if b.shown and b.step then t[#t + 1] = b.left.text end end
    return table.concat(t, "\n")
end
local function at(x, y) M.pos[1438] = { x, y }; M.update(0.06); M.update(0.06); M.update(0.2) end

-- 1. Count: objective 1 counts as done at 8 of 10.
local part = D("Wolves", "Kill 8 here, the rest later", 50, 50, 5); part.obj, part.objMax = 1, 8
M.log = { { questID = 20, title = "Wolves" } }
M.obj[20] = { { text = "Wolves: 7/10", finished = false, numFulfilled = 7, numRequired = 10 } }
set({ part, A("Next", "Npc", 52, 52, 5) })
assert(rows():find("Do:|r Wolves", 1, true), "7/10: still to do")
M.obj[20][1].numFulfilled = 8; M.update()
assert(not rows():find("Do:|r Wolves", 1, true), "8/10 is enough here: " .. rows())
M.log, M.obj = {}, {}
print("1 ok")

-- 2. Loop points go round; Nearest picks the closest spot not just checked.
local circuit = { t = "go", text = "Circuit", x = 40, y = 40, lvl = 5, pts = { { 40, 40 }, { 60, 40 }, { 60, 60 } }, mode = "loop" }
set({ circuit })
assert(M.current.step.pointIndex == 1 and M.current.step.pointMode == "loop", "loop starts at 1")
at(0.4, 0.4); assert(M.current.step.pointIndex == 2, "then 2")
at(0.6, 0.4); assert(M.current.step.pointIndex == 3, "then 3")
at(0.6, 0.6); assert(M.current.step.pointIndex == 1, "wraps to 1, not done: " .. tostring(M.current.step.pointIndex))
assert(rows():find("Circuit", 1, true), "a loop never completes by walking")
local spots = { t = "go", text = "Find her", x = 10, y = 10, lvl = 5, pts = { { 10, 10 }, { 52, 50 }, { 90, 90 } }, mode = "nearest" }
M.pos[1438] = { 0.5, 0.5 }
set({ spots })
assert(M.current.step.pointIndex == 2, "nearest: " .. tostring(M.current.step.pointIndex))
at(0.52, 0.5)
assert(M.current.step.pointIndex ~= 2, "checked spot is passed over: " .. tostring(M.current.step.pointIndex))
local stops = LevelGuide_UpcomingStops()
assert(#stops == 3, "every spot on the map: " .. #stops)
print("2 ok")

-- 3. XP gates by amount.
-- (UnitXPMax is 1000 in the mock.)
local short = { t = "xp", text = "300 XP short of level 13", level = 13, short = 300, lvl = 12 }
M.level, M.xp = 12, 0
set({ short, A("After", "Npc", 52, 52, 12) })
assert(M.current.left.text:find("300 XP short of level 13", 1, true), "gate shown: " .. M.current.left.text)
assert(tostring(M.current.step.detail):find("(need 700)", 1, true), "live need: " .. tostring(M.current.step.detail))
M.xp = 699; M.update()
assert(rows():find("short of", 1, true), "699 < 700")
M.xp = 700; M.update()
assert(not rows():find("short of", 1, true), "met at 700")
M.level, M.xp = 11, 999; M.update()
assert(rows():find("short of", 1, true), "a level lower: not met")
M.level = 13; M.update()
assert(not rows():find("short of", 1, true), "at 13: met")
M.level = 12
local into = { t = "xp", text = "300 XP into level 12", level = 12, into = 300, lvl = 12 }
M.xp = 100
set({ into, A("After", "Npc", 52, 52, 12) })
assert(rows():find("300 XP into level 12", 1, true), "into gate shown")
M.xp = 300; M.update()
assert(not rows():find("into level", 1, true) and rows():find("After", 1, true), "into gate met")
M.xp = 0
print("3 ok")

-- 4. Guards hide without completing: the step comes back when the guard holds.
local wand = { t = "buy", text = "Wand", items = 11287, count = 1, where = "ah", side = "later", lvl = 12, when = { lacksItem = { { 11287, 11288, 5240 }, 1 } } }
local onq = A("Needs Q", "Npc", 53, 53, 12); onq.when = { onQuest = "Other" }
set({ wand, onq, A("Filler", "Npc", 55, 55, 12) })
assert(rows():find("Wand", 1, true) and not rows():find("Needs Q", 1, true), "guards: " .. rows())
M.items[5240] = 1; M.update()
assert(not rows():find("Wand", 1, true), "already have a wand: hidden")
M.items[5240] = nil; M.update()
assert(rows():find("Wand", 1, true), "back once the guard holds again (not marked done)")
M.log = { { questID = 30, title = "Other" } }; M.update()
assert(rows():find("Needs Q", 1, true), "onQuest guard holds")
M.log = {}
print("4 ok")

-- 5. Hearth step: done on arrival; what follows waits behind it. Reach: a go step done by being there.
local hearth = { t = "hearth", text = "Auberdine", place = "Auberdine", lvl = 12 }
set({ hearth, A("In Auberdine", "Npc", 40, 40, 12) })
assert(M.current.left.text:find("Hearth to:|r Auberdine", 1, true), "hearth step: " .. M.current.left.text)
assert(tostring(M.current.step.detail):find("hearthstone", 1, true), "says how: " .. tostring(M.current.step.detail))
M.subzone = "Auberdine"; M.update()
assert(not rows():find("Hearth to", 1, true), "arrived")
M.subzone = nil
local enter = { t = "go", text = "Enter Darnassus", x = 36.5, y = 52.5, lvl = 12, reach = "Darnassus" }
set({ enter, A("City Quest", "Someone, Darnassus", 40, 50, 12) })
assert(M.current.left.text:find("Enter Darnassus", 1, true), "go shown")
M.best, M.pos = 1457, { [1457] = { 0.5, 0.5 } }; M.update()
assert(not rows():find("Enter Darnassus", 1, true), "in the city: done")
M.best, M.pos = 1438, { [1438] = { 0.5, 0.5 } }
print("5 ok")

-- 6. A quest for another zone: the trip points at the game's next leg on this map when it knows it.
set({})
M.info[1453] = { mapID = 1453, name = "Stormwind City", mapType = 3, parentMapID = 1415 }
M.log = { { questID = 40, title = "Far Trip" } }
C_QuestLog.GetNextWaypoint = function(id) if id == 40 then return 1453, 0.5, 0.5 end end
C_QuestLog.GetNextWaypointForMap = function(id, map) if id == 40 and map == 1438 then return 0.58, 0.94 end end
M.update()
local trip
for _, b in ipairs(M.buttons) do if b.shown and b.step and b.step.kind == "travel" then trip = b.step end end
assert(trip and trip.mapID == 1438 and math.abs(trip.x - 0.58) < 1e-9, "next leg on this map: " .. rows())
C_QuestLog.GetNextWaypoint, C_QuestLog.GetNextWaypointForMap = nil, nil
M.log = {}
assert(#M.handled == 0, "clean: " .. tostring(M.handled[1]))
print("ALL TESTS PASSED")
