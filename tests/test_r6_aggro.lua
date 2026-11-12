-- Round 6 item 2 (research\re_round6.md): AggroWatch. Out of combat, a line of our own warns before you walk into
-- a hostile mob's aggro range (Classic rule as Olfato models it, distance in bands as LibRangeCheck measures it).
-- Checks: the radius and grey rules; the warning's colour band and text; neutral, grey, dead, player, busy and
-- secret units skipped; quiet and stopped in combat; the hub's Off switch hides it; 4 scans a second at most and
-- one range check for a far mob; sound off by default; bounded SavedVariables; its globals stay in its own names;
-- no targeting, casting, CVar, hook or chat call anywhere in the file.
-- Run from the tests folder:  node run.js "<repo root>" test_r6_aggro.lua
local base = ADDON_PATH
local say = print
local failures = {}
local function check(cond, why) if not cond then failures[#failures + 1] = why end end

-- Frames: our own regions only.
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

local secretMeta = {}
for _, m in ipairs({ "__lt", "__le", "__eq", "__add", "__sub", "__mul", "__div", "__concat", "__len", "__unm", "__mod", "__pow" }) do
    secretMeta[m] = function() error("secret value used in " .. m) end
end
local function Secret(v) return setmetatable({ v = v }, secretMeta) end
issecretvalue = function(v) return type(v) == "table" and getmetatable(v) == secretMeta end

local handled = {}
geterrorhandler = function() return function(e) handled[#handled + 1] = tostring(e) end end
local now = 100
GetTime = function() return now end

-- The world: units by token. distance in yards; nil fields default to an idle hostile level-11 mob.
local units = {}
local playerLevel, combat = 11, false
local rangeCalls = 0
local function U(token) return units[token] end
UnitExists = function(t) return t == "player" or U(t) ~= nil end
UnitCanAttack = function(_, t) local u = U(t); return u ~= nil and u.reaction ~= 5 end
UnitReaction = function(t) local u = U(t); return u and (u.reaction or 2) end
UnitIsPlayer = function(t) local u = U(t); return u and u.player or false end
UnitIsDead = function(t) local u = U(t); return u and u.dead or false end
UnitAffectingCombat = function(t) if t == "player" then return combat end local u = U(t); return u and u.busy or false end
UnitLevel = function(t) if t == "player" then return playerLevel end local u = U(t); return u and u.level or 11 end
UnitName = function(t) local u = U(t); return u and u.name end
UnitCreatureType = function(t) local u = U(t); return "Beast", u and u.ctype or 1 end
UnitRace = function() return "Night Elf", "NightElf" end
InCombatLockdown = function() return combat end

-- Item yards from LibRangeCheck's Classic Era list (the bands the helper uses).
local ITEM_YARDS = { [8149] = 5, [15826] = 5, [9606] = 10, [9618] = 10, [4559] = 15, [1191] = 20, [10645] = 20,
    [13289] = 25, [835] = 30, [7734] = 30, [1258] = 35, [18904] = 35, [4945] = 40, [8348] = 40 }
local itemsSecret, loaded = false, {}
C_Item = {
    IsItemInRange = function(item, t)
        rangeCalls = rangeCalls + 1
        local u, yards = U(t), ITEM_YARDS[item]
        if not (u and yards) then return nil end
        local r = u.distance <= yards
        return itemsSecret and Secret(r) or r
    end,
    RequestLoadItemDataByID = function(id) loaded[#loaded + 1] = id end,
}
CheckInteractDistance = function(t, index)
    rangeCalls = rangeCalls + 1
    local u = U(t)
    if not u then return false end
    return u.distance <= (index == 3 and 8 or index == 4 and 28 or 0)
end
local sounds = 0
SOUNDKIT = { RAID_WARNING = 8959 }
PlaySound = function() sounds = sounds + 1 end
local hubLines = {}
ForeverHub_Receive = function(src, text) check(src == "AggroWatch", "page source"); hubLines[#hubLines + 1] = text end
local off = false
ForeverHub_IsOff = function(name) return off and name == "AggroWatch" end
C_CVar = { GetCVarBool = function() return false end }
SlashCmdList = {}

-- Forbidden calls: any use fails the test.
for _, name in ipairs({ "TargetUnit", "CastSpellByName", "CastSpellByID", "SetCVar", "hooksecurefunc", "MoveForwardStart", "print" }) do
    local n = name
    _G[n] = function() check(false, n .. " called") end
end
C_CVar.SetCVar = function() check(false, "C_CVar.SetCVar called") end

-- Record every global the file writes.
local before = {}
for k in pairs(_G) do before[k] = true end
AggroWatchDB = { sound = "yes", junk = { 1, 2, 3 }, history = {} }
before.AggroWatchDB = true

-- The compiled file (fengari has no io.open): its string constants and names, comments left out.
local source = string.dump(assert(loadfile(base .. "/AggroWatch/AggroWatch.lua")))
assert(loadfile(base .. "/AggroWatch/AggroWatch.lua"))()
for k in pairs(_G) do
    if not before[k] then
        check(k:sub(1, 10) == "AggroWatch" or k:sub(1, 7) == "Forever" or k == "SLASH_AGGROWATCH1", "global written: " .. k)
    end
end
for k in pairs(SlashCmdList) do check(k == "AGGROWATCH", "slash key " .. k) end
for _, bad in ipairs({ "COMBAT_LOG", "TargetUnit", "CastSpell", "SetCVar", "hooksecurefunc", "AddDataProvider", "AcquirePin",
    "DEFAULT_CHAT_FRAME", "SetParent", "GetNamePlateForUnit", "GetNamePlates", "SetCVar", "print", "SendChatMessage" }) do
    check(not source:find("%f[%w_]" .. bad .. "%f[^%w_]"), "source uses " .. bad)
end
check(source:find("%f[%w_]IsItemInRange%f[^%w_]") and source:find("%f[%w_]CheckInteractDistance%f[^%w_]"), "the scan reads were found")
say("1 ok: globals and calls")

-- 2. The rules.
check(AggroWatch_Radius(11, 11) == 20, "equal level: 20")
check(AggroWatch_Radius(14, 11) == 23, "3 above: 23")
check(AggroWatch_Radius(1, 30) == 5, "far below: 5")
check(AggroWatch_Radius(80, 11) == 45, "far above: 45")
check(AggroWatch_Radius(-1, 11) == 30, "?? mob: 10 above")
check(AggroWatch_GreyLevel(11) == 5 and AggroWatch_GreyLevel(5) == 0 and AggroWatch_GreyLevel(60) == 51
    and AggroWatch_GreyLevel(45) == 35, "grey levels")
say("2 ok: radius and grey")

local events = frames[1]
local function fire(...) events.scripts.OnEvent(events, ...) end
local function tick(dt) now = now + dt; if events.scripts.OnUpdate then events.scripts.OnUpdate(events, dt) end end
fire("PLAYER_LOGIN")
fire("PLAYER_ENTERING_WORLD")
local frame = AggroWatch_Frame()
local label = frame.font
check(AggroWatchDB.junk == nil and AggroWatchDB.history == nil and AggroWatchDB.sound == false, "saved variables bounded, sound off")
check(#loaded >= 10, "range items asked to load")
check(not events.scripts.OnUpdate, "nothing in view: no scan running")

-- 3. A level-11 mob at 23 yd (band 20-25): ~3 yd left, orange.
units.nameplate1 = { name = "Webwood Spider", distance = 23 }
fire("NAME_PLATE_UNIT_ADDED", "nameplate1")
check(events.scripts.OnUpdate, "scan running")
tick(0.3)
check(frame.shown, "warning shown")
check(label.text:find("Careful: Webwood Spider (11) aggro in ~3 yd", 1, true) and label.text:find("ff8c1a", 1, true), "orange text: " .. label.text)
local name, level, gap, radius, inside = AggroWatch_Current()
check(name == "Webwood Spider" and level == 11 and gap == 3 and radius == 20 and inside == false, "current")
say("3 ok: orange")

-- 4. Closer: inside (band 15-20).
units.nameplate1.distance = 18
tick(0.3)
check(label.text:find("in its aggro range (~20 yd)", 1, true) and label.text:find("ff3030", 1, true), "red: " .. label.text)
-- Farther: 28-30 band -> gap 9, yellow.
units.nameplate1.distance = 29
tick(0.3)
check(label.text:find("aggro in ~9 yd", 1, true) and label.text:find("ffd100", 1, true), "yellow: " .. label.text)
say("4 ok: red and yellow")

-- 5. Throttle: frames between scans read nothing; a far mob costs one range check.
units.nameplate1.distance = 60
rangeCalls = 0
for _ = 1, 3 do tick(0.05) end
check(rangeCalls == 0, "no read between scans: " .. rangeCalls)
tick(0.2)
check(rangeCalls == 1, "far mob, one check: " .. rangeCalls)
check(not frame.shown, "far: hidden")
say("5 ok: throttle")

-- 6. Skipped: neutral, grey, dead, a player, busy, a critter, secret level; the nearest of two wins.
units.nameplate1.distance = 23
for _, case in ipairs({ { reaction = 4 }, { level = 5 }, { dead = true }, { player = true }, { busy = true }, { ctype = 8 },
    { level = Secret(11) } }) do
    for k, v in pairs(case) do units.nameplate1[k] = v end
    tick(0.3)
    local what = next(case)
    check(not frame.shown, "skipped: " .. what)
    units.nameplate1 = { name = "Webwood Spider", distance = 23 }
end
units.nameplate2 = { name = "Gnarlpine Ursa", distance = 12, level = 12 }
fire("NAME_PLATE_UNIT_ADDED", "nameplate2")
tick(0.3)
check(label.text:find("Gnarlpine Ursa (12)", 1, true) and label.text:find("in its aggro range (~21 yd)", 1, true), "nearest: " .. label.text)
fire("NAME_PLATE_UNIT_REMOVED", "nameplate2")
units.nameplate2 = nil
say("6 ok: skips")

-- 7. Secret range answers: the items are skipped, the interact checks still band it (8 < 23 <= 28).
itemsSecret = true
tick(0.3)
check(#handled == 0, "no error with secret ranges: " .. tostring(handled[1]))
check(frame.shown and label.text:find("Webwood Spider", 1, true), "interact bands still work: " .. label.text)
itemsSecret = false
say("7 ok: secrets")

-- 8. Combat: hidden at once, scan stopped; after combat it comes back.
fire("PLAYER_REGEN_DISABLED")
check(not frame.shown and not events.scripts.OnUpdate, "combat: hidden and stopped")
combat = true
rangeCalls = 0
tick(1)
check(rangeCalls == 0, "nothing read in combat")
combat = false
fire("PLAYER_REGEN_ENABLED")
tick(0.3)
check(frame.shown, "back after combat")
say("8 ok: combat")

-- 9. The hub's Off switch.
off = true
ForeverHubOnSwitch.AggroWatch(true)
check(not frame.shown and not events.scripts.OnUpdate, "off: hidden and stopped")
fire("NAME_PLATE_UNIT_ADDED", "nameplate1")
check(not events.scripts.OnUpdate, "off: stays stopped")
off = false
ForeverHubOnSwitch.AggroWatch(false)
tick(0.3)
check(frame.shown, "on again")
say("9 ok: off switch")

-- 10. Sound: off by default; on, once per mob, not every scan; the hub's Alerts > Sound off silences it.
units.nameplate1.distance = 18
tick(0.3)
check(sounds == 0, "no sound by default")
AggroWatch_SetSound(true)
now = now + 60
tick(0.3); tick(0.3); tick(0.3)
check(sounds == 1, "one sound: " .. sounds)
ForeverHubDB = { alerts = { sound = false } }
now = now + 60
tick(0.3)
check(sounds == 1, "hub sound off")
ForeverHubDB = nil
AggroWatch_SetSound(false)
say("10 ok: sound")

-- 11. Page: lines go to the hub; sound on/off typed there; nameplates hint.
SlashCmdList.AGGROWATCH("sound on")
check(AggroWatch_SoundOn() and AggroWatchDB.sound == true, "sound on from the page")
local all = table.concat(hubLines, "\n")
check(all:find("Enemy nameplates are off", 1, true) and all:find("Sound: on", 1, true), "page lines")
SlashCmdList.AGGROWATCH("sound off")
check(not AggroWatch_SoundOn(), "sound off from the page")
say("11 ok: page")

-- 12. Mouseover only, then it leaves without an event: the scan stops by itself.
fire("NAME_PLATE_UNIT_REMOVED", "nameplate1")
units.nameplate1 = nil
units.mouseover = { name = "Timberling", distance = 23 }
fire("UPDATE_MOUSEOVER_UNIT")
tick(0.3)
check(frame.shown and label.text:find("Timberling", 1, true), "mouseover read")
units.mouseover = nil
tick(0.3)
check(not frame.shown and not events.scripts.OnUpdate, "mouseover gone: stopped")
say("12 ok: mouseover")

check(#handled == 0, "errors: " .. tostring(handled[1]))
if #failures > 0 then
    error("FAILURES (" .. #failures .. "):\n" .. table.concat(failures, "\n"))
end
say("ALL TESTS PASSED")
