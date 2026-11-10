-- Corpse run and death skip (research\re_round3.md rank 10):
-- * the death-skip hint up to level 20 with MacQuest's seconds (45 s + 21 s per level above 10 + the walk from
--   the spirit healer you'd come back at), shown only when it saves 75 s (to 10) or 135 s (11-20);
-- * a ghost's arrow shows the time to the corpse at run speed even standing still;
-- * dead or a ghost: how far the nearest spirit healer is from your body. ADDON_PATH = LevelGuide.
local M = dofile("lg_mock.lua")
LevelGuideDB = { characters = { ["Juan-R"] = { done = {}, skips = {}, visited = {} } } }
local dead = false
UnitIsDeadOrGhost = function() return dead or M.ghost end
GetUnitSpeed = function() return 0, 7 end
M.best, M.pos, M.level = 1438, { [1438] = { 0.20, 0.20 } }, 6
M.load(ADDON_PATH, function()
    LevelGuideRoutes.chains.NightElf = { { zone = "Teldrassil", min = 1, max = 60, steps = {
        { t = "accept", q = "Far Away", npc = "Giver", x = 62, y = 62, lvl = 5 },
    } } }
    LevelGuideQuestIDs = { ids = {}, renamed = {} }
    LevelGuidePrereqs = {}
end)
LevelGuideTravel.healers = { { map = 1438, x = 60, y = 60 }, { map = 1438, x = 95, y = 5 } }
local function also() local f = M.font("Also: ") return f and f.shown ~= false and f.text or "" end

-- 1. The maths: about 2570 yd (459 s) on foot against 45 s and a 122 yd walk from the healer at 60, 60.
local P = LevelGuidePlanner
local here, goal = { map = 1438, x = 20, y = 20 }, { map = 1438, x = 62, y = 62 }
local healer, saved = P.DeathSkip(here, goal, 6, 7)
assert(healer and healer.x == 60 and saved > 380 and saved < 400, "saves about 392 s: " .. tostring(saved))
local _, saved15 = P.DeathSkip(here, goal, 15, 7)
assert(saved15 and math.abs((saved - saved15) - 105) < 1e-6, "21 s per level above 10")
assert(not P.DeathSkip(here, goal, 21, 7), "never above 20")
-- Close by: 76 s on foot is not worth 45 s plus the walk.
assert(not P.DeathSkip({ map = 1438, x = 55, y = 55 }, goal, 6, 7), "too little saved")
print("1 ok")

-- 2. In the guide, at 15 now too, with the seconds.
M.level = 15
M.update()
assert(also():find("die and come back at the spirit healer", 1, true), "level 15 hint: " .. also())
assert(also():find("saves about %d+ min") or also():find("saves about %d+ s"), "says how much: " .. also())
M.level = 21
M.update()
assert(not also():find("die and come back", 1, true), "not above 20: " .. also())
print("2 ok")

-- 3. A ghost standing still: the time to the corpse at run speed (707 yd at 7 yd/s, 1:41).
M.level = 15
M.ghost, M.corpse = true, { map = 1438, x = 0.5, y = 0.5 }
M.pos = { [1438] = { 0.4, 0.4 } }
M.update()
M.update(0.06)
local f = M.font("Corpse ")
assert(f and f.text:find("1:41", 1, true), "ETA at run speed: " .. tostring(f and f.text))
-- And how far the nearest spirit healer is from the body (60, 60 on Travel.lua's Teldrassil, about 612 yd).
assert(also():find("Spirit healer about 6%d%d yd from your body"), "healer line: " .. also())
assert(not also():find("die and come back", 1, true), "no death skip while dead: " .. also())
print("3 ok")

-- 4. Dead, not yet released: the healer is measured from where you lie.
M.ghost, M.corpse, dead = false, nil, true
M.pos = { [1438] = { 0.5, 0.5 } }
M.update()
assert(also():find("Spirit healer about 6%d%d yd from your body"), "dead: " .. also())
dead = false
M.update()
assert(not also():find("Spirit healer about", 1, true), "alive: no healer line")
assert(#M.handled == 0, "clean: " .. tostring(M.handled[1]))
print("ALL TESTS PASSED")
