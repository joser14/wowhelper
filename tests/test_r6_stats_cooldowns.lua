-- Round 6 #15 (research\re_round6.md): ForeverHelper's profession cooldowns per character, read out of combat
-- from C_Spell.GetSpellCooldown (known spells) and C_Container.GetItemCooldown (items you carry), saved as the
-- clock time they end; "ready" or time left on the Characters page and "cooldowns"; one pop-up when ready on
-- this character (not while the hub has the helper Off); secret values never used; nothing cast or used.
-- Run from the tests folder:  node run.js "<repo root>" test_r6_stats_cooldowns.lua
local base = ADDON_PATH
local out, frames, failures = {}, {}, {}
local function check(cond, why) if not cond then failures[#failures + 1] = why end end

local function NewFrame(kind, name)
    local f = { kind = kind, name = name, registered = {}, scripts = {}, shown = true, text = "" }
    function f:RegisterEvent(e) self.registered[e] = true end
    function f:SetScript(what, fn) self.scripts[what] = fn end
    function f:Show() self.shown = true end
    function f:Hide() self.shown = false end
    function f:SetShown(v) self.shown = v and true or false end
    function f:IsShown() return self.shown end
    function f:SetText(t) self.text = t end
    function f:CreateFontString() return NewFrame("FontString") end
    function f:GetPoint() return "CENTER", nil, "CENTER", 0, 0 end
    return setmetatable(f, { __index = function() return function() end end })
end
CreateFrame = function(kind, name)
    local f = NewFrame(kind, name)
    frames[#frames + 1] = f
    return f
end
UIParent = NewFrame("Frame")
UISpecialFrames = {}
SlashCmdList = {}
ForeverHub_Receive = function(_, t) out[#out + 1] = t end
local off = false
ForeverHub_IsOff = function() return off end
local SECRET = setmetatable({}, { __lt = function() error("compared a secret") end, __le = function() error("compared a secret") end,
    __add = function() error("arithmetic on a secret") end, __sub = function() error("arithmetic on a secret") end })
issecretvalue = function(v) return v == SECRET end

local mono, clock = 5000, 1700000000
GetTime = function() return mono end
time = function() return clock end
local timers, ticker = {}, nil
C_Timer = { After = function(_, fn) timers[#timers + 1] = fn end, NewTicker = function(_, fn) ticker = fn end }
local function flush() local list = timers; timers = {}; for _, fn in ipairs(list) do fn() end end
UnitName = function() return "Ann", "Leaf" end
UnitGUID = function() return "Player-1-0001" end
GetRealmName = function() return "R" end
UnitLevel = function() return 11 end
UnitXP = function() return 0 end
UnitXPMax = function() return 8800 end
GetXPExhaustion = function() return 0 end
GetMoney = function() return 100 end
local lockdown = false
InCombatLockdown = function() return lockdown end

-- Known: Mooncloth and one transmute. Cooldowns by spell; the Salt Shaker in the bags.
local known = { [18560] = true, [11479] = true }
local spellCD = { [18560] = { startTime = 4000, duration = 3 * 86400 }, [11479] = { startTime = 0, duration = 0 } }
C_SpellBook = { IsSpellKnown = function(id) return known[id] == true end }
local cast = {}
C_Spell = { GetSpellCooldown = function(id) return spellCD[id] or { startTime = 0, duration = 0 } end,
    CastSpell = function() cast[#cast + 1] = "cast" end }
local bags = { [15846] = 1 }
C_Item = { GetItemCount = function(id) return bags[id] or 0 end }
local itemCD = { [15846] = { 4900, 1.5 } }
C_Container = { GetItemCooldown = function(id) local c = itemCD[id] or { 0, 0 }; return c[1], c[2], 1 end,
    UseContainerItem = function() cast[#cast + 1] = "use" end }

ForeverHelperDB = { characters = {
    ["Player-1-0002"] = { charName = "Bea Stone", level = 50, money = 0, tasks = {},
        cooldowns = { transmute = { ends = clock - 10 }, saltshaker = { ends = clock + 7200 } } },
} }
assert(loadfile(base .. "/ForeverHelper/ForeverHelper.lua"))("ForeverHelper", {})
local events = frames[1]
local function fire(ev, ...) events.scripts.OnEvent(events, ev, ...) end
local function page(arg) out = {}; local ok, err = pcall(SlashCmdList.FOREVERHELPER, arg); if not ok then out[#out + 1] = "<<ERROR " .. tostring(err) .. ">>" end end
local function has(text) for _, t in ipairs(out) do if t:find(text, 1, true) then return t end end end

fire("ADDON_LOADED", "ForeverHelper")
fire("PLAYER_LOGIN")
check(events.registered.SPELL_UPDATE_COOLDOWN and events.registered.BAG_UPDATE_COOLDOWN, "cooldown events registered")
for name in pairs(events.registered) do check(not name:find("^COMBAT_LOG"), "no combat log: " .. name) end
flush()
local char = ForeverHelperDB.characters["Player-1-0001"]
local cds = char and char.cooldowns or {}
-- Mooncloth started at GetTime 4000 (1000 s ago), 3 days long.
check(cds.mooncloth and cds.mooncloth.ends == clock - 1000 + 3 * 86400, "Mooncloth end time saved: " .. tostring(cds.mooncloth and cds.mooncloth.ends))
check(cds.transmute and cds.transmute.ends == 0, "known transmute, ready")
check(cds.saltshaker and cds.saltshaker.ends == 0, "Salt Shaker: a 1.5 s cooldown is the GCD, so ready")
check(cds.snowmaster == nil, "no Snowmaster without the item")

page("cooldowns")
check(has("Profession cooldowns"), "cooldowns page")
check((has("Ann Leaf:") or ""):find("Mooncloth in 2d 23h", 1, true), "time left: " .. tostring(has("Ann Leaf:")))
check((has("Ann Leaf:") or ""):find("Transmute |cff33ff33ready", 1, true), "ready shown")
check((has("Bea Stone:") or ""):find("Salt Shaker in 2h 0m", 1, true), "other character: " .. tostring(has("Bea Stone:")))
page("chars")
check(has("Cooldowns:") and has("Bea Stone: level 50"), "Characters page lists cooldowns")

-- In combat nothing is read; secret values are never used.
lockdown = true
spellCD[18560] = { startTime = SECRET, duration = SECRET }
fire("SPELL_UPDATE_COOLDOWN")
flush()
check(cds.mooncloth.ends == clock - 1000 + 3 * 86400, "not read in combat")
lockdown = false
fire("PLAYER_REGEN_ENABLED")
local ok = pcall(flush)
check(ok and cds.mooncloth.ends == clock - 1000 + 3 * 86400, "secret cooldown ignored")

-- Ready: one pop-up on this character; none while Off.
spellCD[18560] = { startTime = 0, duration = 0 }
clock = clock + 3 * 86400
mono = mono + 3 * 86400
off = true
out = {}
ticker()
check(not has("Mooncloth is ready"), "no pop-up while Off")
off = false
mono = mono + 31
out = {}
ticker()
check(has("Mooncloth is ready on this character."), "pop-up when ready")
mono = mono + 31
out = {}
ticker()
check(not has("Mooncloth is ready"), "only once")
-- Cast again: a new end time, told again later.
spellCD[18560] = { startTime = mono, duration = 86400 }
fire("SPELL_UPDATE_COOLDOWN")
flush()
check(cds.mooncloth.ends == clock + 86400 and not cds.mooncloth.told, "new cooldown read")
-- The Salt Shaker leaves the bags: its line goes.
bags[15846] = 0
fire("BAG_UPDATE_COOLDOWN")
flush()
check(cds.saltshaker == nil, "item gone: line removed")
check(#cast == 0, "never casts or uses anything")

-- Static: no chat output, hooks or forbidden events.
local src = string.dump(assert(loadfile(base .. "/ForeverHelper/ForeverHelper.lua")))
for _, bad in ipairs({ "AddMessage", "hooksecurefunc", "SendChatMessage", "COMBAT_LOG", "CastSpell", "UseContainerItem" }) do
    check(not src:find(bad, 1, true), "source has no " .. bad)
end
check(not has("<<ERROR"), "no errors")

if #failures > 0 then
    error("FAILURES (" .. #failures .. "):\n" .. table.concat(failures, "\n"))
end
print("test_r6_stats_cooldowns: all checks passed")
