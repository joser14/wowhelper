-- Drowning and fatigue warning: when your breath or the deep-water fatigue bar is running out, a large
-- warning of our own in the middle of the screen, a sound and a taskbar flash. Reads the game's mirror
-- timers (MIRROR_TIMER_* events, GetMirrorTimerProgress); it changes nothing in Blizzard's own bars.

local WATCHED = { BREATH = "breath", EXHAUSTION = "fatigue" }
-- Seconds left at which to warn: once early, once urgent.
local WARN_SECONDS, URGENT_SECONDS = 15, 5
local CHECK_SECONDS = 0.25
local SHOW_SECONDS = 3

local running = {}   -- timer name -> { warned = bool, urgent = bool }
local ticker
local banner

local function Safe(value)
    if issecretvalue and issecretvalue(value) then
        return nil
    end
    return value
end

local function IsOff()
    return ForeverHub_IsOff and ForeverHub_IsOff("DeathNotes") or false
end

local function Banner()
    if not banner then
        banner = CreateFrame("Frame", nil, UIParent)
        banner:SetSize(600, 60)
        banner:SetPoint("TOP", UIParent, "TOP", 0, -180)
        banner:SetFrameStrata("HIGH")
        banner.text = banner:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
        banner.text:SetAllPoints(banner)
        banner:Hide()
    end
    return banner
end

local function Alert(text, urgent)
    local frame = Banner()
    frame.text:SetText(text)
    if urgent then
        frame.text:SetTextColor(1, 0.2, 0.2)
    else
        frame.text:SetTextColor(1, 0.82, 0)
    end
    frame:Show()
    frame.hideAt = (GetTime and GetTime() or 0) + SHOW_SECONDS
    if PlaySound and SOUNDKIT then
        pcall(PlaySound, urgent and SOUNDKIT.RAID_WARNING or SOUNDKIT.ALARM_CLOCK_WARNING_3 or SOUNDKIT.RAID_WARNING)
    end
    if FlashClientIcon then
        pcall(FlashClientIcon)
    end
    if ForeverHub_Receive then
        ForeverHub_Receive("DeathNotes", text)
    end
end

-- Seconds left on a draining timer, or nil when the game doesn't say.
local function SecondsLeft(name)
    if not GetMirrorTimerProgress then
        return nil
    end
    local ok, progress = pcall(GetMirrorTimerProgress, name)
    progress = ok and Safe(progress)
    return type(progress) == "number" and progress / 1000 or nil
end

local function Check()
    local now = GetTime and GetTime() or 0
    if banner and banner:IsShown() and banner.hideAt and now >= banner.hideAt then
        banner:Hide()
    end
    local any = false
    for name, state in pairs(running) do
        any = true
        local left = SecondsLeft(name)
        if left and not IsOff() then
            local what = WATCHED[name]
            if left <= URGENT_SECONDS and not state.urgent then
                state.urgent, state.warned = true, true
                Alert(string.format("Out of %s in %d seconds! Get out now.", what, math.max(math.ceil(left), 0)), true)
            elseif left <= WARN_SECONDS and not state.warned then
                state.warned = true
                Alert(string.format("Low %s: %d seconds left", what, math.ceil(left)), false)
            end
        end
    end
    if not any and not (banner and banner:IsShown()) and ticker then
        ticker:Cancel()
        ticker = nil
    end
end

local function Watch()
    if not ticker and C_Timer and C_Timer.NewTicker then
        ticker = C_Timer.NewTicker(CHECK_SECONDS, Check)
    end
end

local events = CreateFrame("Frame")
events:RegisterEvent("MIRROR_TIMER_START")
events:RegisterEvent("MIRROR_TIMER_STOP")
events:RegisterEvent("MIRROR_TIMER_PAUSE")
events:SetScript("OnEvent", function(_, event, name, a, _, scale, paused)
    name = Safe(name)
    if not (type(name) == "string" and WATCHED[name]) then
        return
    end
    if event == "MIRROR_TIMER_START" then
        scale, paused = Safe(scale), Safe(paused)
        -- A negative scale drains (you're under water); a positive one refills (you came up).
        if type(scale) == "number" and scale < 0 and not (type(paused) == "number" and paused > 0) then
            running[name] = running[name] or { warned = false, urgent = false }
            Watch()
            Check()
        else
            running[name] = nil
        end
    elseif event == "MIRROR_TIMER_STOP" then
        running[name] = nil
    elseif event == "MIRROR_TIMER_PAUSE" then
        local isPaused = Safe(a)
        if type(isPaused) == "number" and isPaused > 0 then
            running[name] = nil
        end
    end
end)

-- For tests and other helpers: whether a timer is being watched now.
function BreathWatch_IsWatching(name)
    return running[name] ~= nil
end
