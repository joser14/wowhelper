-- Skyborne ley lines (research\re_round3.md rank 16; LevelGuide\SkyborneSpots.lua, spots by tr0tsky, MIT): a
-- Skyborne within 400 yd of a ley line on the map they're on is told where it is, in the "Also" line. Others
-- never see it. ADDON_PATH = LevelGuide.
local M = dofile("lg_mock.lua")
LevelGuideDB = { characters = { ["Juan-R"] = { done = {}, skips = {}, visited = {} } } }
local race = "Skyborne"
UnitRace = function() return race, race end
M.load(ADDON_PATH, function() end)
assert(LevelGuideSkyborne and #LevelGuideSkyborne.ley > 100, "ley line spots load")
LevelGuideSkyborne.ley = { { 1438, 50, 50 }, { 1438, 90, 90 }, { 1439, 50, 50 } }
local function also() local f = M.font("Also: ") return f and f.shown ~= false and f.text or "" end

-- Teldrassil 46, 50 (Travel.lua frame): 4% of 5091 yd = about 204 yd west of the ley line at 50, 50.
M.level, M.best, M.pos = 8, 1438, { [1438] = { 0.46, 0.50 } }
M.update()
assert(also():find("Ley line about 20%d yd", 1, false), "nearest ley line: " .. also())
-- Too far (40, 20): nothing.
M.pos = { [1438] = { 0.20, 0.20 } }
M.update()
assert(not also():find("Ley line", 1, true), "far: " .. also())
-- Not a Skyborne: nothing.
race = "NightElf"
M.pos = { [1438] = { 0.46, 0.50 } }
M.update()
assert(not also():find("Ley line", 1, true), "night elf: " .. also())
assert(#M.handled == 0, "clean: " .. tostring(M.handled[1]))
print("ALL TESTS PASSED")
