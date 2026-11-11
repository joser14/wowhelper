-- Review 4, suspicion 4: releasing your spirit fires PLAYER_ALIVE too, and UnitIsGhost may still read false
-- during that event. The saved death spot must survive the release: PLAYER_ALIVE only clears it when, a moment
-- later, you are neither a ghost nor dead (a resurrection). PLAYER_UNGHOST still clears it at once.
-- ADDON_PATH = LevelGuide.
local M = dofile("lg_mock.lua")
LevelGuideDB = { characters = { ["Juan-R"] = { done = {}, skips = {}, visited = {} } } }
IsInInstance = function() return false end
GetCorpseRecoveryDelay = function() return 0 end
GetUnitSpeed = function() return 0, 7 end
local dead = false
UnitIsDeadOrGhost = function() return dead or M.ghost end
M.best, M.pos, M.level = 1438, { [1438] = { 0.30, 0.30 } }, 6
M.load(ADDON_PATH, function()
    LevelGuideRoutes.chains.NightElf = { { zone = "Teldrassil", min = 1, max = 60, steps = {
        { t = "accept", q = "Far Away", npc = "Giver", x = 90, y = 90, lvl = 5 },
    } } }
    LevelGuideQuestIDs = { ids = {}, renamed = {} }
    LevelGuidePrereqs = {}
end)
-- Timers from now on (the mock has none at load): run only when flushed.
local timers = {}
C_Timer = { After = function(_, fn) timers[#timers + 1] = fn end, NewTicker = function() end }
local function flush() local n = 0 while #timers > 0 and n < 100 do n = n + 1; table.remove(timers, 1)() end end

-- 1. Die, then release: during PLAYER_ALIVE the game still says "not a ghost" (and not dead).
dead = true
M.fire("PLAYER_DEAD")
assert(M.char.deathSpot, "spot saved")
dead, M.ghost = false, false
M.fire("PLAYER_ALIVE")
assert(M.char.deathSpot, "kept through the release event")
M.ghost = true
flush()
assert(M.char.deathSpot, "kept: you are a ghost a moment later")
-- 2. Back to your body.
M.ghost = false
M.fire("PLAYER_UNGHOST")
assert(not M.char.deathSpot, "cleared on PLAYER_UNGHOST")
-- 3. A resurrection where you lay (PLAYER_ALIVE, never a ghost): cleared a moment later.
dead = true
M.fire("PLAYER_DEAD")
dead = false
M.fire("PLAYER_ALIVE")
flush()
assert(not M.char.deathSpot, "cleared by a resurrection")
-- 4. Dying again before the check runs keeps the new spot.
dead = true
M.fire("PLAYER_DEAD")
dead = false
M.fire("PLAYER_ALIVE")
dead = true
M.fire("PLAYER_DEAD")
flush()
assert(M.char.deathSpot, "a new death's spot isn't cleared by the old check")
M.update(0.06)
assert(#M.handled == 0, "clean: " .. tostring(M.handled[1]))
print("ALL TESTS PASSED")
