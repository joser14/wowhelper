-- Review 3 (2026-11-10), BreathWatch (DeathNotes): a paused breath timer that resumes keeps being watched.
-- The game sends MIRROR_TIMER_PAUSE with paused > 0, then MIRROR_TIMER_PAUSE with 0 to resume (no new
-- MIRROR_TIMER_START), so dropping the timer on pause lost every warning after the resume.
-- Run from the harness folder:  node run.js "<workspace root>" test_review3_breathwatch.lua
local base = ADDON_PATH
local frames, popups = {}, {}
local function newRegion()
    local r = { shown = true, scripts = {}, text = "" }
    function r:SetScript(s, f) self.scripts[s] = f end
    function r:Show() self.shown = true end
    function r:Hide() self.shown = false end
    function r:IsShown() return self.shown end
    function r:SetText(t) self.text = t end
    function r:CreateFontString() return newRegion() end
    return setmetatable(r, { __index = function() return function() end end })
end
CreateFrame = function() local f = newRegion(); frames[#frames + 1] = f; return f end
UIParent = newRegion()
issecretvalue = function() return false end
local now = 100
GetTime = function() return now end
local tick
C_Timer = { NewTicker = function(_, fn) tick = fn; return { Cancel = function() tick = nil end } end }
ForeverHub_Receive = function(_, text) popups[#popups + 1] = text end
local left = {}
GetMirrorTimerProgress = function(name) return left[name] end

assert(loadfile(base .. "/DeathNotes/BreathWatch.lua"))("DeathNotes", {})
local events = frames[1]
local function fire(...) events.scripts.OnEvent(events, ...) end

-- Under water, draining.
fire("MIRROR_TIMER_START", "BREATH", 60000, 60000, -1, 0, "Breath")
left.BREATH = 40000
if tick then tick() end
-- Paused (the bar freezes), then resumed: still draining, still the same dive.
fire("MIRROR_TIMER_PAUSE", "BREATH", 1)
fire("MIRROR_TIMER_PAUSE", "BREATH", 0)
assert(BreathWatch_IsWatching("BREATH"), "watched again after the timer resumes")
left.BREATH = 12000
if tick then tick() end
assert(#popups == 1 and popups[1]:find("Low breath", 1, true), "warning after a resume: " .. tostring(popups[1]))
-- Another pause and resume in the same dive: the early warning isn't repeated.
fire("MIRROR_TIMER_PAUSE", "BREATH", 1)
fire("MIRROR_TIMER_PAUSE", "BREATH", 0)
left.BREATH = 11000
if tick then tick() end
assert(#popups == 1, "early warning given once per dive")

-- A timer that starts paused and then resumes is watched too.
fire("MIRROR_TIMER_STOP", "BREATH")
popups = {}
left.BREATH = 60000
fire("MIRROR_TIMER_START", "BREATH", 60000, 60000, -1, 1, "Breath")
fire("MIRROR_TIMER_PAUSE", "BREATH", 0)
assert(BreathWatch_IsWatching("BREATH"), "started paused, then resumed: watched")
left.BREATH = 4000
if tick then tick() end
assert(#popups == 1 and popups[1]:find("Out of breath", 1, true), "urgent warning: " .. tostring(popups[1]))

-- A refilling bar (positive scale) is still not watched, paused or not.
fire("MIRROR_TIMER_START", "BREATH", 4000, 60000, 10, 0, "Breath")
fire("MIRROR_TIMER_PAUSE", "BREATH", 0)
assert(not BreathWatch_IsWatching("BREATH"), "refilling isn't watched after a resume")
-- Stopped is stopped.
fire("MIRROR_TIMER_START", "BREATH", 60000, 60000, -1, 0, "Breath")
fire("MIRROR_TIMER_STOP", "BREATH")
fire("MIRROR_TIMER_PAUSE", "BREATH", 0)
assert(not BreathWatch_IsWatching("BREATH"), "a stopped timer isn't brought back by a resume")

print("ALL TESTS PASSED")
