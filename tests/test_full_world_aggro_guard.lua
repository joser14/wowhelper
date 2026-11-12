-- Full review (research\full_review_world.md): AggroWatch's range reads (C_Item.IsItemInRange, CheckInteractDistance)
-- on hostile units are restricted in combat on this client. Every range call must be guarded by its own combat check,
-- not only by the scan's check at the top: AggroWatch_Measure is a global anyone can call, and the in-combat read must
-- be refused even before PLAYER_REGEN_DISABLED has been seen, or when InCombatLockdown can't be read.
-- Run from the tests folder:  node run.js "<repo root>" test_full_world_aggro_guard.lua
local base = ADDON_PATH
local say = print
local failures = {}
local function check(cond, why) if not cond then failures[#failures + 1] = why end end

local frames = {}
local function newRegion(kind)
    local r = { kind = kind, shown = true, scripts = {}, text = "" }
    function r:SetScript(s, f) self.scripts[s] = f end
    function r:Show() self.shown = true end
    function r:Hide() self.shown = false end
    function r:IsShown() return self.shown end
    function r:SetText(t) self.text = t end
    function r:CreateTexture() return newRegion("texture") end
    function r:CreateFontString() local f = newRegion("font"); r.font = f; return f end
    return setmetatable(r, { __index = function() return function() end end })
end
CreateFrame = function(kind) local f = newRegion(kind); frames[#frames + 1] = f; return f end
UIParent = newRegion("Frame")
geterrorhandler = function() return function(e) failures[#failures + 1] = "error: " .. tostring(e) end end
GetTime = function() return 100 end

local units = { nameplate1 = { name = "Webwood Spider", distance = 23 } }
local lockdown, playerCombat = false, false
local lockdownErrors = false
local rangeCalls = 0
UnitExists = function(t) return t == "player" or units[t] ~= nil end
UnitCanAttack = function(_, t) return units[t] ~= nil end
UnitReaction = function(t) return units[t] and 2 end
UnitIsPlayer = function() return false end
UnitIsDead = function() return false end
UnitAffectingCombat = function(t) if t == "player" then return playerCombat end return false end
UnitLevel = function(t) return 11 end
UnitName = function(t) return units[t] and units[t].name end
UnitCreatureType = function() return "Beast", 1 end
UnitRace = function() return "Night Elf", "NightElf" end
InCombatLockdown = function()
    if lockdownErrors then error("refused") end
    return lockdown
end
local ITEM_YARDS = { [8149] = 5, [15826] = 5, [9606] = 10, [9618] = 10, [4559] = 15, [1191] = 20, [10645] = 20,
    [13289] = 25, [835] = 30, [7734] = 30, [1258] = 35, [18904] = 35, [4945] = 40, [8348] = 40 }
C_Item = {
    IsItemInRange = function(item, t)
        rangeCalls = rangeCalls + 1
        local u, yards = units[t], ITEM_YARDS[item]
        if not (u and yards) then return nil end
        return u.distance <= yards
    end,
    RequestLoadItemDataByID = function() end,
}
CheckInteractDistance = function(t, index)
    rangeCalls = rangeCalls + 1
    local u = units[t]
    return u ~= nil and u.distance <= (index == 3 and 8 or 28)
end
ForeverHub_IsOff = function() return false end
SlashCmdList = {}

assert(loadfile(base .. "/AggroWatch/AggroWatch.lua"))()
local events = frames[1]
local function fire(...) events.scripts.OnEvent(events, ...) end
fire("PLAYER_LOGIN")
fire("PLAYER_ENTERING_WORLD")
fire("NAME_PLATE_UNIT_ADDED", "nameplate1")

-- 1. Out of combat the global measures as before (band 20-25 for a mob at 23 yd).
local low, high = AggroWatch_Measure("nameplate1", 30)
check(low == 20 and high == 25, "out of combat: measured " .. tostring(low) .. "-" .. tostring(high))
check(rangeCalls > 0, "out of combat: range read")

-- 2. Combat lockdown already on, before PLAYER_REGEN_DISABLED reached AggroWatch: no range call at all.
lockdown = true
rangeCalls = 0
low, high = AggroWatch_Measure("nameplate1", 30)
check(rangeCalls == 0, "lockdown: range calls made: " .. rangeCalls)
check(high == nil, "lockdown: no band")
lockdown = false
say("1 ok: lockdown guard on the global")

-- 3. The player flagged in combat (UnitAffectingCombat) without lockdown yet: refused too.
playerCombat = true
rangeCalls = 0
AggroWatch_Measure("nameplate1", 30)
check(rangeCalls == 0, "player in combat: range calls made: " .. rangeCalls)
playerCombat = false

-- 4. InCombatLockdown can't be read (refused): treated as in combat, never as out of it.
lockdownErrors = true
rangeCalls = 0
AggroWatch_Measure("nameplate1", 30)
check(rangeCalls == 0, "unreadable lockdown: range calls made: " .. rangeCalls)
lockdownErrors = false
say("2 ok: unknown combat state refuses")

-- 5. The scan tick itself with lockdown on and no event: nothing read, warning hidden.
local function tick(dt) if events.scripts.OnUpdate then events.scripts.OnUpdate(events, dt) end end
tick(0.3)
check(frames[2] and frames[2].shown, "scan shows the warning out of combat")
lockdown = true
rangeCalls = 0
tick(0.3)
check(rangeCalls == 0, "scan in lockdown read ranges: " .. rangeCalls)
check(not frames[2].shown, "scan in lockdown: hidden")
lockdown = false
say("3 ok: scan tick")

if #failures > 0 then
    error("FAILURES (" .. #failures .. "):\n" .. table.concat(failures, "\n"))
end
say("ALL TESTS PASSED")
