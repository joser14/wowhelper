-- Round 5 #2 (research\re_round5.md, research\fight_summary_feasibility.md): LevelLog's Fights card. Read from
-- C_DamageMeter a moment after PLAYER_REGEN_ENABLED, only out of combat; secret numbers are never used (the read
-- is retried, then dropped); the newest 20 fights kept; session totals; never ResetAllCombatSessions; no
-- combat-log or CallbackEvent registration; hidden with the window when the hub switches LevelLog Off.
local base = ADDON_PATH
local out, chat, frames, handled, registered = {}, {}, {}, {}, {}
local function newRegion(kind, name, template)
    local r = { kind = kind, name = name, template = template, shown = true, scripts = {}, text = "", height = 0 }
    function r:SetText(t) self.text = t end
    function r:GetText() return self.text end
    function r:SetScript(s, f) self.scripts[s] = f end
    function r:Show() self.shown = true; if self.scripts.OnShow then self.scripts.OnShow(self) end end
    function r:Hide() self.shown = false end
    function r:SetShown(v) if v then self:Show() else self:Hide() end end
    function r:IsShown() return self.shown end
    function r:GetStringHeight() return 14 end
    function r:SetHeight(h) self.height = h end
    function r:SetChecked(v) self.checked = v end
    function r:GetChecked() return self.checked end
    function r:RegisterEvent(e) registered[#registered + 1] = e end
    function r:CreateFontString() return newRegion("font") end
    function r:CreateTexture() return newRegion("texture") end
    function r:GetPoint() return "CENTER", nil, "CENTER", 5, 6 end
    return setmetatable(r, { __index = function(_, k)
        if type(k) == "string" and k:match("^%u") then return function() end end
    end })
end
CreateFrame = function(kind, name, parent, template)
    local f = newRegion(kind, name, template)
    frames[#frames + 1] = f
    if name then _G[name] = f end
    return f
end
UIParent = newRegion("Frame")
SlashCmdList = {}
DEFAULT_CHAT_FRAME = { AddMessage = function(_, t) chat[#chat + 1] = t end }
local say = print
print = function(...) chat[#chat + 1] = table.concat({ ... }, " ") end
ForeverHub_Receive = function(_, t) out[#out + 1] = t end
local SECRET = setmetatable({}, { __lt = function() error("compared a secret") end, __le = function() error("compared a secret") end,
    __add = function() error("added a secret") end, __sub = function() error("arithmetic on a secret") end,
    __mul = function() error("arithmetic on a secret") end, __div = function() error("arithmetic on a secret") end,
    __concat = function() error("concatenated a secret") end })
issecretvalue = function(v) return v == SECRET end
geterrorhandler = function() return function(e) handled[#handled + 1] = tostring(e) end end

local now, server = 1000, 86400 * 20000 + 3600 * 10
GetTime = function() return now end
GetServerTime = function() return server end
date = function(fmt) return fmt == "%H:%M" and "12:00" or "D" end
-- Timers wait until run() so the delay is visible.
local timers, tick = {}, nil
C_Timer = { NewTicker = function(_, fn) tick = fn end, After = function(d, fn) timers[#timers + 1] = { d = d, fn = fn } end }
local function run()
    local list = timers; timers = {}
    for _, t in ipairs(list) do t.fn() end
    return #list
end

UnitName = function(unit) if unit == "player" then return "Ann" end end
GetRealmName = function() return "R" end
UnitLevel = function() return 12 end
UnitXP = function() return 0 end
UnitXPMax = function() return 8800 end
GetXPExhaustion = function() return 0 end
GetRealZoneText = function() return "Darkshore" end
IsInInstance = function() return false, "none" end
GetMoney = function() return 0 end
local lockdown = false
InCombatLockdown = function() return lockdown end

-- The client's meter, as DamageMeterDocumentation describes it.
local meterAvailable, meterReason = true, ""
local current = {}      -- [type] = session table
local byID = {}         -- [id] = { [type] = session }
local available = {}
local resetCalled, readsInLockdown = false, 0
local function Session(duration, mine, others)
    local sources = { { isLocalPlayer = true, totalAmount = mine[1], amountPerSecond = mine[2], name = "Ann" } }
    for _, o in ipairs(others or {}) do sources[#sources + 1] = { isLocalPlayer = false, totalAmount = o, amountPerSecond = 1 } end
    return { combatSources = sources, durationSeconds = duration, totalAmount = 0, maxAmount = 0 }
end
local function SetFight(duration, dmg, dps, heal, hps, taken)
    current[0] = Session(duration, { dmg, dps }, { 999 })
    current[2] = Session(duration, { heal, hps })
    current[7] = Session(duration, { taken, 0 })
end
C_DamageMeter = {
    IsDamageMeterAvailable = function() return meterAvailable, meterReason end,
    GetCombatSessionFromType = function(sessionType, kind)
        assert(sessionType == 1, "reads the Current session")
        if lockdown then readsInLockdown = readsInLockdown + 1 end
        return current[kind] or { combatSources = {}, totalAmount = 0, maxAmount = 0 }
    end,
    GetCombatSessionFromID = function(id, kind)
        return byID[id] and byID[id][kind] or { combatSources = {}, totalAmount = 0, maxAmount = 0 }
    end,
    GetAvailableCombatSessions = function() return available end,
    GetSessionDurationSeconds = function() return nil end,
    ResetAllCombatSessions = function() resetCalled = true end,
}
Enum = { DamageMeterType = { DamageDone = 0, Dps = 1, HealingDone = 2, Hps = 3, DamageTaken = 7 } }

assert(loadfile(base .. "/LevelLog/LevelLog.lua"))("LevelLog", {})
local ev = frames[#frames]
local function fire(...) ev.scripts.OnEvent(ev, ...) end
fire("PLAYER_LOGIN")
local rec = LevelLogDB["Ann-R"]
assert(rec, "own record")
local function endFight() fire("PLAYER_REGEN_DISABLED"); fire("PLAYER_REGEN_ENABLED") end

-- 1. Before any fight: an empty card, nothing read.
local text = table.concat(LevelLog_FightLines(), "\n")
assert(text:find("No fight recorded yet", 1, true) and text:find("No fights yet this session", 1, true), "empty card:\n" .. text)
say("1 ok")

-- 2. A fight: read a moment after combat ends (not at the event itself), only your own line.
SetFight(20, 400, 20, 120, 6, 380)
endFight()
assert(rec.fights == nil or #rec.fights == 0, "not read at the event itself")
assert(#timers == 1 and timers[1].d >= 0.5, "read after a delay")
run()
assert(rec.fights and #rec.fights == 1, "one fight")
local f = rec.fights[1]
assert(f.d == 400 and f.h == 120 and f.tk == 380 and f.s == 20 and f.dps == 20 and f.hps == 6 and f.l == 12 and f.z == "Darkshore",
    "fight fields: " .. tostring(f.d) .. " " .. tostring(f.h) .. " " .. tostring(f.tk))
text = table.concat(LevelLog_FightLines(), "\n")
assert(text:find("Damage done: 400 (20.0 per second)", 1, true), "last fight damage:\n" .. text)
assert(text:find("Healing done: 120 (6.0 per second)", 1, true) and text:find("Damage taken: 380", 1, true), "heal and taken")
-- The same session seen again (a second REGEN_ENABLED with no new fight): kept once.
endFight(); run()
assert(#rec.fights == 1, "same fight not doubled")
say("2 ok")

-- 3. Back in combat by the time the read runs: nothing is read at all.
SetFight(10, 100, 10, 0, 0, 50)
endFight()
lockdown = true
run()
lockdown = false
assert(#rec.fights == 1 and readsInLockdown == 0, "no read while in combat")
say("3 ok")

-- 4. Secret numbers: never used; tried again a little later, then given up.
SetFight(10, SECRET, SECRET, 0, 0, 50)
endFight()
assert(run() == 1 and #timers == 1 and timers[1].d >= 1, "retry scheduled")
current[0] = Session(10, { 100, 10 })
run()
assert(#rec.fights == 2 and rec.fights[2].d == 100, "read on retry")
SetFight(11, SECRET, SECRET, SECRET, SECRET, SECRET)
endFight()
local rounds = 0
while #timers > 0 do run(); rounds = rounds + 1; assert(rounds < 10, "retries end") end
assert(#rec.fights == 2, "secret fight dropped")
-- A secret source table or a secret session: also dropped, no error.
current[0] = SECRET
endFight(); while #timers > 0 do run() end
current[0] = { combatSources = SECRET }
endFight(); while #timers > 0 do run() end
assert(#rec.fights == 2, "secret tables dropped")
say("4 ok")

-- 5. "Current" already empty: the newest tracked session is read instead.
current = {}
available = { { sessionID = 3, name = "a" }, { sessionID = 7, name = "b" }, { sessionID = SECRET, name = "c" } }
byID[7] = { [0] = Session(30, { 600, 20 }), [2] = Session(30, { 0, 0 }), [7] = Session(30, { 90, 0 }) }
endFight(); run()
assert(#rec.fights == 3 and rec.fights[3].d == 600 and rec.fights[3].tk == 90 and rec.fights[3].s == 30, "newest session by ID")
available = {}
say("5 ok")

-- 6. Meter unavailable: nothing recorded, the reason shown.
meterAvailable, meterReason = false, "Disabled in this zone"
SetFight(5, 50, 10, 0, 0, 0)
endFight(); run()
assert(#rec.fights == 3, "nothing while unavailable")
text = table.concat(LevelLog_FightLines(), "\n")
assert(text:find("Disabled in this zone", 1, true), "reason shown:\n" .. text)
meterAvailable = true
say("6 ok")

-- 7. Session totals and the cap of 20 fights.
for i = 1, 25 do
    SetFight(10, 100 + i, 10, 10, 1, 20)
    endFight(); run()
end
assert(#rec.fights == 20, "capped at 20: " .. #rec.fights)
assert(rec.fights[20].d == 125 and rec.fights[1].d == 106, "newest kept")
text = table.concat(LevelLog_FightLines(), "\n")
assert(text:find("28 fight(s)", 1, true), "session count:\n" .. text)
assert(text:find("Last 20 fight(s)", 1, true), "history header")
local sessionDamage = 400 + 100 + 600
for i = 1, 25 do sessionDamage = sessionDamage + 100 + i end
-- 310 s in combat: 20 + 10 + 30 + 25 x 10.
assert(text:find(string.format("Damage done: %d (%.1f per second in combat)", sessionDamage, sessionDamage / 310), 1, true),
    "session damage " .. sessionDamage .. ":\n" .. text)
assert(text:find("5m in combat", 1, true), "combat time")
-- Older saves with more than 20 are trimmed when read.
for i = 1, 10 do rec.fights[#rec.fights + 1] = { d = 1, h = 0, tk = 0 } end
LevelLog_FightLines()
assert(#rec.fights == 20, "old save trimmed")
say("7 ok")

-- 8. The window's Fights tab; hidden when the hub switches LevelLog Off, back when On.
SlashCmdList.LEVELLOG("window")
local win = LevelLogWindow
assert(win and win.shown, "window open")
local function button(label) for _, b in ipairs(frames) do if b.kind == "Button" and b.text == label then return b end end end
button("Fights").scripts.OnClick()
assert(win.text.text:find("Last fight", 1, true) and win.text.text:find("This session", 1, true), "Fights tab:\n" .. win.text.text)
ForeverHubOnSwitch.LevelLog(true)
assert(not win.shown, "hidden when Off")
ForeverHub_IsOff = function(name) return name == "LevelLog" end
SlashCmdList.LEVELLOG("window")
assert(not win.shown, "can't be opened while Off")
ForeverHub_IsOff = nil
ForeverHubOnSwitch.LevelLog(false)
assert(win.shown, "back when On")
say("8 ok")

-- 9. Rules: no reset of the player's meter, no combat-log or CallbackEvent registration, no chat, no errors.
assert(not resetCalled, "never ResetAllCombatSessions")
for _, e in ipairs(registered) do
    assert(not e:find("^COMBAT_LOG") and not e:find("^DAMAGE_METER"), "registered " .. e)
end
assert(#chat == 0, "no chat: " .. tostring(chat[1]))
assert(#handled == 0, "no errors: " .. table.concat(handled, " | "))
say("ALL TESTS PASSED")
