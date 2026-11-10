-- BreathWatch (DeathNotes): warns as breath or fatigue runs out, once early and once urgent, stops when you
-- surface, ignores other timers, hidden values and the hub's Off switch.
local base = ADDON_PATH
local frames, popups, sounds, handled = {}, {}, {}, {}
local function newRegion()
    local r = { shown = true, scripts = {}, text = "" }
    function r:SetScript(s, f) self.scripts[s] = f end
    function r:Show() self.shown = true end
    function r:Hide() self.shown = false end
    function r:IsShown() return self.shown end
    function r:SetText(t) self.text = t end
    function r:CreateFontString() local f = newRegion(); rawset(r, "font", f); return f end
    return setmetatable(r, { __index = function() return function() end end })
end
CreateFrame = function() local f = newRegion(); frames[#frames + 1] = f; return f end
UIParent = newRegion()
local SECRET = {}
issecretvalue = function(v) return v == SECRET end
geterrorhandler = function() return function(e) handled[#handled + 1] = tostring(e) end end
local now = 100
GetTime = function() return now end
local tick
C_Timer = { NewTicker = function(_, fn) tick = fn; return { Cancel = function() tick = nil end } end }
SOUNDKIT = { RAID_WARNING = 8959, ALARM_CLOCK_WARNING_3 = 12889 }
PlaySound = function(id) sounds[#sounds + 1] = id end
FlashClientIcon = function() end
ForeverHub_Receive = function(_, text) popups[#popups + 1] = text end
local off = false
ForeverHub_IsOff = function(name) return off and name == "DeathNotes" end
local left = {}
GetMirrorTimerProgress = function(name) return left[name] end

assert(loadfile(base .. "/DeathNotes/BreathWatch.lua"))("DeathNotes", {})
local events = frames[1]
local function fire(...) events.scripts.OnEvent(events, ...) end

-- 1. Under water: breath drains (scale -1). Nothing at 30 s, a warning at 15, an urgent one at 5.
fire("MIRROR_TIMER_START", "BREATH", 60000, 60000, -1, 0, "Breath")
assert(BreathWatch_IsWatching("BREATH") and tick, "watching breath")
left.BREATH = 30000; tick()
assert(#popups == 0, "no warning with 30 s left")
left.BREATH = 14000; tick()
assert(#popups == 1 and popups[1]:find("Low breath: 14 seconds", 1, true), "early warning: " .. tostring(popups[1]))
left.BREATH = 12000; tick()
assert(#popups == 1, "warned once")
left.BREATH = 4500; tick()
assert(#popups == 2 and popups[2]:find("Out of breath in 5 seconds", 1, true), "urgent: " .. tostring(popups[2]))
assert(#sounds == 2, "a sound each time")
print("1 ok")

-- 2. Surfacing: the bar refills (positive scale) or stops; no more warnings.
fire("MIRROR_TIMER_START", "BREATH", 4000, 60000, 10, 0, "Breath")
assert(not BreathWatch_IsWatching("BREATH"), "refilling isn't watched")
fire("MIRROR_TIMER_START", "BREATH", 60000, 60000, -1, 0, "Breath")
fire("MIRROR_TIMER_STOP", "BREATH")
assert(not BreathWatch_IsWatching("BREATH"), "stopped")
print("2 ok")

-- 3. Fatigue (deep water) is watched the same way; feign death (FEIGNDEATH) and other timers aren't.
popups = {}
fire("MIRROR_TIMER_START", "EXHAUSTION", 60000, 60000, -1, 0, "Fatigue")
left.EXHAUSTION = 10000; tick()
assert(popups[1] and popups[1]:find("Low fatigue", 1, true), "fatigue: " .. tostring(popups[1]))
fire("MIRROR_TIMER_START", "FEIGNDEATH", 60000, 60000, -1, 0, "Feign Death")
assert(not BreathWatch_IsWatching("FEIGNDEATH"), "other timers ignored")
fire("MIRROR_TIMER_STOP", "EXHAUSTION")
print("3 ok")

-- 4. Hidden values and a paused timer: nothing breaks, nothing is said.
popups = {}
fire("MIRROR_TIMER_START", SECRET, SECRET, SECRET, SECRET, SECRET, SECRET)
left.BREATH = SECRET
fire("MIRROR_TIMER_START", "BREATH", 60000, 60000, -1, 0, "Breath")
tick()
assert(#popups == 0, "hidden progress: quiet")
fire("MIRROR_TIMER_PAUSE", "BREATH", 1)
assert(not BreathWatch_IsWatching("BREATH"), "paused isn't running out")
print("4 ok")

-- 5. Switched off in the hub: no warning.
off = true
left.BREATH = 3000
fire("MIRROR_TIMER_START", "BREATH", 60000, 60000, -1, 0, "Breath")
tick()
assert(#popups == 0, "off: quiet")
assert(#handled == 0, "clean: " .. tostring(handled[1]))
print("ALL TESTS PASSED")
