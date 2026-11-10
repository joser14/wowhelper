-- Routes and the fallback plan are Alliance only. Skyborne (Forever's new race, starting on Zephras Isle,
-- uiMapID 2521) get their own plan entry and, at about 13, the Human route from Westfall reached by the
-- zeppelin; a Horde character gets no directions into Alliance zones.
-- ADDON_PATH = LevelGuide.
local M = dofile("lg_mock.lua")
LevelGuideDB = { characters = {} }
M.info[2521] = { mapID = 2521, name = "Zephras Isle", mapType = 3, parentMapID = 947 }
M.rects[2521] = { 20000, 20000, 3000, 3000 }
M.best, M.pos, M.level = 2521, { [2521] = { 0.43, 0.24 } }, 3
local race, faction = "Skyborne", "Alliance"
UnitRace = function() return race, race end
UnitFactionGroup = function() return faction, faction end
M.load(ADDON_PATH)

local function rows()
    local t = {}
    for _, b in ipairs(M.buttons) do if b.shown and b.step then t[#t + 1] = b.left.text end end
    return table.concat(t, "\n")
end
local function current() return M.current.shown and M.current.step end

-- 1. A new Skyborne on Zephras Isle: the isle is where the plan wants you, so no trip elsewhere.
M.update()
assert(not rows():find("Teldrassil", 1, true) and not rows():find("Dun Morogh", 1, true), "not sent to another start: " .. rows())

-- 2. A Skyborne under 13 away from the isle is pointed back to it, not to the other races' starts.
M.best, M.pos = 1438, { [1438] = { 0.5, 0.5 } }
M.update()
local step = current()
assert(step and step.kind == "travel" and step.title == "Zephras Isle", "plan for Skyborne: " .. rows())
M.best, M.pos = 2521, { [2521] = { 0.43, 0.24 } }
print("1 ok")

-- 3. At 13 on the isle: the Human chain's Westfall route, reached by the zeppelin on the isle.
M.level = 13
M.update()
step = current()
assert(step and step.kind == "travel" and step.title == "Zeppelin to Dalaran", "way off the isle: " .. rows())
assert(step.mapID == 2521 and math.abs(step.x - 0.658) < 1e-9 and math.abs(step.y - 0.834) < 1e-9, "zeppelin spot")
print("2 ok")

-- 4. Horde (a Horde Skyborne, or any Horde race): no Alliance route and no Alliance plan.
faction = "Horde"
M.update()
assert(not rows():find("Zeppelin to Dalaran", 1, true) and not rows():find("Westfall", 1, true), "Horde Skyborne: " .. rows())
race, M.level = "Orc", 5
M.best, M.pos = 1438, { [1438] = { 0.5, 0.5 } }
M.update()
for _, b in ipairs(M.buttons) do
    assert(not (b.shown and b.step and b.step.kind == "travel"), "Horde gets no trip into Alliance zones: " .. rows())
end
print("3 ok")

-- 5. When the game won't say your faction, the routes are used as before.
faction, race = nil, "NightElf"
M.update()
step = current()
assert(step and step.title ~= nil, "unknown faction: guide still works")
assert(#M.handled == 0, "clean: " .. tostring(M.handled[1]))
print("ALL TESTS PASSED")
