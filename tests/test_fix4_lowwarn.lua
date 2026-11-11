-- Review 4, suspicion 1: LowWarn's cue at the start of a fight. PLAYER_REGEN_DISABLED is commonly dispatched
-- before InCombatLockdown() turns true; the cue must show at once (from the regen events), not wait for the
-- next health or mana event. Leaving combat hides it even if the lockdown flag lags behind.
-- Mocks copied from test_r4c_lowwarn.lua.
local base = ADDON_PATH
local frames, handled = {}, {}
local function newRegion(kind)
    local r = { kind = kind, shown = true, scripts = {}, alpha = 1 }
    function r:SetScript(s, f) self.scripts[s] = f end
    function r:Show() self.shown = true end
    function r:Hide() self.shown = false end
    function r:IsShown() return self.shown end
    function r:SetAlpha(a) self.alpha = a end
    function r:CreateTexture() local t = newRegion("texture"); return t end
    return setmetatable(r, { __index = function() return function() end end })
end
CreateFrame = function(kind) local f = newRegion(kind); frames[#frames + 1] = f; return f end
UIParent = newRegion("Frame")
-- A secret value: any comparison, arithmetic, concatenation or length errors, like the game's.
local secretMeta = {}
for _, m in ipairs({ "__lt", "__le", "__add", "__sub", "__mul", "__div", "__concat", "__len", "__unm", "__mod", "__pow" }) do
    secretMeta[m] = function() error("secret value used in " .. m) end
end
local function Secret(v) return setmetatable({ v = v }, secretMeta) end
issecretvalue = function(v) return type(v) == "table" and getmetatable(v) == secretMeta end
geterrorhandler = function() return function(e) handled[#handled + 1] = tostring(e) end end
local now = 100
GetTime = function() return now end
Enum = { LuaCurveType = { Linear = 0 }, PowerType = { Mana = 0 } }
local curves = {}
C_CurveUtil = { CreateCurve = function()
    local c = { points = {} }
    function c:SetType(t) self.type = t end
    function c:AddPoint(x, y) self.points[#self.points + 1] = { x, y } end
    -- Like the game: linear between points, clamped at the ends.
    function c:Evaluate(x)
        local p = self.points
        if x <= p[1][1] then return p[1][2] end
        for i = 2, #p do
            if x <= p[i][1] then
                local a, b = p[i - 1], p[i]
                return a[2] + (b[2] - a[2]) * (x - a[1]) / (b[1] - a[1])
            end
        end
        return p[#p][2]
    end
    curves[#curves + 1] = c
    return c
end }
local hp, mana, maxMana = 1, 1, 1000
local inCombat = false
local calls = 0
UnitHealthPercent = function(unit, predicted, curve)
    calls = calls + 1
    assert(unit == "player" and curve, "player with a curve")
    local v = curve:Evaluate(hp)
    return inCombat and Secret(v) or v
end
UnitPowerPercent = function(unit, powerType, unmodified, curve)
    calls = calls + 1
    assert(unit == "player" and powerType == 0 and curve, "player mana with a curve")
    local v = curve:Evaluate(mana)
    return inCombat and Secret(v) or v
end
UnitPowerMax = function(_, powerType) return powerType == 0 and maxMana or 100 end
InCombatLockdown = function() return inCombat end
local off = false
ForeverHub_IsOff = function(name) return off and name == "DeathNotes" end

assert(loadfile(base .. "/DeathNotes/LowWarn.lua"))("DeathNotes", {})
local events = frames[1]
local function fire(...) events.scripts.OnEvent(events, ...) end
local edge, drink = LowWarn_Frames()
assert(edge and drink, "our own two cues")
local function alphaOf(region) local a = region.alpha; return issecretvalue(a) and a.v or a end
fire("PLAYER_LOGIN")
-- A. Low health, the fight starts: the regen event arrives while InCombatLockdown() still says false.
hp = 0.2
inCombat = false
fire("PLAYER_REGEN_DISABLED")
assert(edge.shown and alphaOf(edge) == 1, "cue shown at the start of the fight, before any health event")
-- No mana cue needed at full mana, but it is placed (alpha 0).
assert(alphaOf(drink) == 0, "full mana: drink cue invisible")
-- A health event before the lockdown flag turns on still updates the cue.
now = now + 1
hp = 0.9
fire("UNIT_HEALTH", "player")
assert(edge.shown and alphaOf(edge) == 0, "health event during the gap updates: " .. tostring(alphaOf(edge)))
print("A ok")

-- B. Combat ends while InCombatLockdown() still says true: hidden, and later unit events don't bring it back.
inCombat = true
fire("PLAYER_REGEN_ENABLED")
assert(not edge.shown and not drink.shown, "hidden when the fight ends")
now = now + 1
hp = 0.1
fire("UNIT_HEALTH", "player")
assert(not edge.shown, "out of combat: a health event doesn't show it")
inCombat = false
print("B ok")

-- C. A /reload in the middle of a fight: in combat from login.
inCombat = true
fire("PLAYER_LOGIN")
now = now + 1
fire("UNIT_HEALTH", "player")
assert(edge.shown and alphaOf(edge) == 1, "reload in combat: cue works")
inCombat = false
fire("PLAYER_REGEN_ENABLED")
assert(not edge.shown, "hidden after")
assert(#handled == 0, "no errors: " .. tostring(handled[1]))
print("ALL TESTS PASSED")
