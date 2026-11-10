-- Death-skip and riding-money hints (research\guides_deep_re.md 12.18), text only, in the guide's "Also" line:
-- * up to level 20, when the spirit healer you'd come back at (the nearest to you) saves enough seconds
-- * from level 38 without riding: "Riding at 40: about 120 g with a mount; you have X g" (paladins and warlocks
--   get theirs from a class quest), marked as not checked in game. ADDON_PATH = LevelGuide.
local M = dofile("lg_mock.lua")
LevelGuideDB = { characters = { ["Juan-R"] = { done = {}, skips = {}, visited = {} } } }
M.best, M.pos, M.level = 1438, { [1438] = { 0.20, 0.20 } }, 6
local money, riding = 500000, nil
GetMoney = function() return money end
C_SkillInfo = { GetSkillLineInfoByID = function(id) if id == 762 and riding then return { rank = riding } end end }
M.load(ADDON_PATH, function()
    LevelGuideRoutes.chains.NightElf = { { zone = "Teldrassil", min = 1, max = 60, steps = {
        { t = "accept", q = "Far Away", npc = "Giver", x = 62, y = 62, lvl = 5 },
    } } }
    LevelGuideQuestIDs = { ids = {}, renamed = {} }
    LevelGuidePrereqs = {}
end)
LevelGuideTravel.healers = { { map = 1438, x = 60, y = 60 }, { map = 1438, x = 95, y = 5 } }
local function also() local f = M.font("Also: ") return f and f.shown ~= false and f.text or "" end
M.update()

-- 1. The healer you'd come back at (60, 60) is by the stop: worth dying (seconds model: test_lg_corpse.lua).
assert(also():find("die and come back at the spirit healer", 1, true), "death-skip: " .. also())
-- Not when the healer nearest you is elsewhere.
M.pos = { [1438] = { 0.55, 0.55 } }
M.update()
assert(not also():find("spirit healer", 1, true), "nearest healer far from the stop: " .. also())
-- Not above level 20.
M.pos, M.level = { [1438] = { 0.20, 0.20 } }, 21
M.update()
assert(not also():find("spirit healer", 1, true), "level 21: " .. also())
print("1 ok")

-- 2. Riding money from 38.
M.level = 38
M.update()
assert(also():find("Riding at 40: about 120 g", 1, true) and also():find("you have 50 g", 1, true), "riding: " .. also())
assert(also():find("not checked in game", 1, true), "marked unverified: " .. also())
M.class = "PALADIN"
M.update()
assert(also():find("class quest", 1, true), "paladin: " .. also())
M.class = "PRIEST"
riding = 75
M.update()
assert(not also():find("Riding at 40", 1, true), "already riding: " .. also())
riding = nil
M.level = 37
M.update()
assert(not also():find("Riding at 40", 1, true), "not yet at 37: " .. also())
assert(#M.handled == 0, "clean: " .. tostring(M.handled[1]))
print("ALL TESTS PASSED")
