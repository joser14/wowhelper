-- Round 4 item 7 (research\re_round4.md R7, Glowing Bars' value curves, MIT): DeathNotes' in-combat low-health
-- and low-mana cue. The game's health/mana percent goes through a curve (C_CurveUtil) straight into SetAlpha on
-- our own frames; the result is secret in combat and is never compared, added, concatenated or Safe()d.
-- Hidden out of combat and when DeathNotes is switched off in the hub; no mana cue for a class without mana.
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

-- 1. Curves: linear, full at 0 up to the threshold, nothing above it.
assert(#curves == 2 and curves[1].type == 0, "two linear curves")
assert(curves[1]:Evaluate(0.30) == 1 and curves[1]:Evaluate(0.5) == 0, "health curve: 35 %")
assert(curves[2]:Evaluate(0.15) == 1 and curves[2]:Evaluate(0.3) == 0, "mana curve: 20 %")
print("1 ok")

-- 2. Out of combat: hidden, nothing read.
assert(not edge.shown and not drink.shown, "hidden out of combat")
print("2 ok")

-- 3. In combat: the secret result goes straight into SetAlpha.
inCombat = true
fire("PLAYER_REGEN_DISABLED")
assert(edge.shown, "shown in combat")
assert(issecretvalue(edge.alpha) and alphaOf(edge) == 0, "full health: invisible (secret passed through)")
hp = 0.2
now = now + 1
fire("UNIT_HEALTH", "player")
assert(issecretvalue(edge.alpha) and alphaOf(edge) == 1, "low health: visible")
mana = 0.1
now = now + 1
fire("UNIT_POWER_UPDATE", "player", "MANA")
assert(drink.shown and issecretvalue(drink.alpha) and alphaOf(drink) == 1, "low mana: drink cue")
print("3 ok")

-- 4. Throttled: a burst of events reads at most every 0.1 s, the last change still lands.
local before = calls
hp = 0.9
for _ = 1, 20 do fire("UNIT_HEALTH", "player") end
assert(calls - before <= 2, "throttled: " .. (calls - before))
local updater = frames[1]
now = now + 0.2
assert(updater.scripts.OnUpdate, "one catch-up pending")
updater.scripts.OnUpdate(updater, 0.2)
assert(alphaOf(edge) == 0, "last change applied")
assert(not updater.scripts.OnUpdate, "no OnUpdate left running")
print("4 ok")

-- 5. Leaving combat hides it; the hub's Off switch keeps it hidden in combat.
inCombat = false
fire("PLAYER_REGEN_ENABLED")
assert(not edge.shown and not drink.shown, "hidden after combat")
off = true
inCombat = true
fire("PLAYER_REGEN_DISABLED")
assert(not edge.shown and not drink.shown, "off in the hub")
off = false
inCombat = false
fire("PLAYER_REGEN_ENABLED")
print("5 ok")

-- 6. A class without mana: no drink cue (read out of combat).
maxMana = 0
fire("PLAYER_REGEN_ENABLED")
inCombat = true
fire("PLAYER_REGEN_DISABLED")
assert(edge.shown and not drink.shown, "no mana cue without mana")
print("6 ok")

-- 7. A client where the curve call fails: the cue switches itself off, quietly, once.
UnitHealthPercent = function() error("bad argument #3") end
now = now + 1
fire("UNIT_HEALTH", "player")
now = now + 1
fire("UNIT_HEALTH", "player")
assert(not edge.shown, "switched off")
assert(#handled == 0, "no error spam: " .. tostring(handled[1]))
print("ALL TESTS PASSED")
