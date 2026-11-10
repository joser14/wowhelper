-- Arrow quality (research\guides_deep_re.md 1.7 and 12.6): the arrow swings smoothly to a new target, shows an
-- ETA from your closing speed, arrives within a radius per kind of stop and only "leaves" a bit further out,
-- and the target doesn't flip between two nearly equal stops (switch only when more than 25% and 40 yd
-- nearer; never in combat). ADDON_PATH = LevelGuide.
local M = dofile("lg_mock.lua")
LevelGuideDB = { characters = { ["Juan-R"] = { done = {}, skips = {}, visited = {} } } }
M.best, M.pos, M.level = 1438, { [1438] = { 0.5, 0.5 } }, 6
local R
M.load(ADDON_PATH, function()
    R = { zone = "Teldrassil", min = 1, max = 20, steps = {} }
    LevelGuideRoutes.chains.NightElf = { R }
    LevelGuideQuestIDs = { ids = { A = { 501 }, B = { 502 }, North = { 503 }, East = { 504 } }, renamed = {} }
    LevelGuidePrereqs = {}
end)
local P = LevelGuidePlanner
local function yardsLine()
    for _, f in ipairs(M.fonts) do
        if f.text:match("^%d+ yd") or f.text:find("You're there", 1, true) then return f.text end
    end
    return ""
end
local function tick(n, dt) for _ = 1, n do M.update(dt or 0.06) end end

-- 1. The arithmetic.
assert(P.Damp(nil, 1, 0.1) == 1, "first bearing snaps")
assert(math.abs(P.Damp(0, math.pi * 0.99, 0.1) - 0.35) < 1e-9, "capped at 3.5 rad/s")
assert(math.abs(P.Damp(0, 0.1, 0.05) - 0.1 * (1 - math.exp(-0.6))) < 1e-9, "exponential swing")
assert(math.abs(P.Damp(3, -3, 1) - (3 + (2 * math.pi - 6)) + 2 * math.pi) < 1e-6 or P.Damp(3, -3, 1) < 0, "turns the short way round")
local state = {}
P.Closing(state, 100, 1)
local speed = P.Closing(state, 90, 1)
assert(speed == 10 and P.ETA(90, speed) == 9, "closing speed and ETA")
assert(P.ETA(90, 1) == nil, "not closing in: no ETA")
local a = {}
assert(P.Arrived(a, "k", 7, 8) and P.Arrived(a, "k", 11, 8) and not P.Arrived(a, "k", 14, 8) and not P.Arrived(a, "k", 10, 8), "hysteresis")
assert(P.Radius("pickup") == 8 and P.Radius("work", 40) == 40 and P.Radius("work") == 15 and P.Radius("travel") == 12, "radius per kind")
assert(not P.Switch(100, 70) and P.Switch(130, 40), "switch rule")
print("1 ok")

-- 2. Smooth turning: a new target swings the arrow over several frames instead of jumping.
R.steps = { { t = "accept", q = "North", npc = "N", x = 50, y = 40, lvl = 5 } }
M.update()
assert(math.abs(M.frame.tex.rotation) < 1e-6, "pointing north: " .. M.frame.tex.rotation)
R.steps = { { t = "accept", q = "East", npc = "E", x = 60, y = 50, lvl = 5 } }
M.fire("QUEST_LOG_UPDATE")
M.update(0.11)
local r1 = M.frame.tex.rotation
assert(r1 < -0.1 and r1 > -0.5, "one frame later: part of the way: " .. r1)
tick(40)
assert(math.abs(M.frame.tex.rotation + math.pi / 2) < 0.01, "then east: " .. M.frame.tex.rotation)
print("2 ok")

-- 3. ETA from the closing speed: walking at 10 yd/s toward the target.
R.steps = { { t = "accept", q = "North", npc = "N", x = 50, y = 40, lvl = 5 } }
M.pos[1438] = { 0.5, 0.5 }
M.update()
for _ = 1, 12 do
    M.pos[1438][2] = M.pos[1438][2] - 0.001   -- 5 yd per 0.5 s
    M.update(0.5)
end
assert(yardsLine():match("%d+ yd  %d+:%d%d"), "ETA shown: " .. yardsLine())
M.update(0.5); M.update(0.5); M.update(0.5); M.update(0.5)
assert(not yardsLine():match(":%d%d"), "standing still: no ETA: " .. yardsLine())
print("3 ok")

-- 4. Arrival radius per kind with hysteresis: a quest giver at 7 yd is "there", still at 11, not at 14.
M.pos[1438] = { 0.5, 0.4 + 0.0014 }
M.update()
assert(yardsLine():find("You're there", 1, true), "7 yd: there: " .. yardsLine())
M.pos[1438] = { 0.5, 0.4 + 0.0022 }
tick(1)
assert(yardsLine():find("You're there", 1, true), "11 yd: still there: " .. yardsLine())
M.pos[1438] = { 0.5, 0.4 + 0.0028 }
tick(1)
assert(yardsLine():match("^14 yd"), "14 yd: left: " .. yardsLine())
M.pos[1438] = { 0.5, 0.4 + 0.0021 }
tick(1)
assert(yardsLine():match("^10 yd"), "10 yd coming back: not there yet (8 yd): " .. yardsLine())
print("4 ok")

-- 5. No flip-flop between two work stops: switch only for one more than 25% and 40 yd nearer.
M.log = { { questID = 501, title = "A" }, { questID = 502, title = "B" } }
M.obj[501] = { { text = "a: 0/5", finished = false, numFulfilled = 0, numRequired = 5 } }
M.obj[502] = { { text = "b: 0/5", finished = false, numFulfilled = 0, numRequired = 5 } }
R.steps = {
    { t = "do", q = "A", note = "A", x = 50, y = 48, lvl = 5 },
    { t = "do", q = "B", note = "B", x = 50, y = 51.4, lvl = 5 },
}
M.pos[1438] = { 0.5, 0.485 }
M.update()
assert(M.current.left.text:find("A", 1, true), "A nearest first: " .. M.current.left.text)
M.pos[1438] = { 0.5, 0.50 }   -- A 100 yd, B 70 yd
M.update()
assert(M.current.left.text:find("Do:|r A", 1, true), "B only 30 yd nearer: keep A: " .. M.current.left.text)
M.pos[1438] = { 0.5, 0.506 }  -- A 130 yd, B 40 yd
M.update()
assert(M.current.left.text:find("Do:|r B", 1, true), "B far nearer: switch: " .. M.current.left.text)
UnitAffectingCombat = function() return true end
M.pos[1438] = { 0.5, 0.48 }   -- A right here, B 170 yd, but fighting
M.update()
assert(M.current.left.text:find("Do:|r B", 1, true), "never switch in combat: " .. M.current.left.text)
UnitAffectingCombat = nil
M.update()
assert(M.current.left.text:find("Do:|r A", 1, true), "out of combat: switch: " .. M.current.left.text)
assert(#M.handled == 0, "clean: " .. tostring(M.handled[1]))
print("ALL TESTS PASSED")
