-- SpellReady (ReadyCheck folder) smoke test: old ranks on bars, ignore/unignore, buff reminders only
-- out of combat and outside rested areas, secret auras, toast throttle, reagents, status rows.
-- Run from the harness folder:  node run.js "<workspace root>" test_readycheck.lua
local base = ADDON_PATH
local out, frames, failures = {}, {}, {}
local SECRET = {}
ForeverHub_Receive = function(_, t) out[#out + 1] = t end
issecretvalue = function(v) return v == SECRET end
CreateFrame = function()
    local f = { registered = {} }
    f.RegisterEvent = function(self, e)
        if e == "LEARNED_SPELL_IN_TAB" then error("unknown event") end
        self.registered[e] = true
    end
    f.SetScript = function(self, _, fn) self.fn = fn end
    frames[#frames + 1] = f
    return f
end
SlashCmdList = {}
Enum = { SpellBookSpellBank = { Player = 0 }, SpellBookItemType = { Spell = 1, FutureSpell = 2 } }

local now = 1000
GetTime = function() return now end
local combat, resting, class = false, false, "MAGE"
InCombatLockdown = function() return combat end
IsResting = function() return resting end
UnitIsDeadOrGhost = function() return false end
UnitClass = function() return "Mage", class end

-- Spells: id -> name, subtext.
local SPELLS = {
    [116] = { "Frostbolt", "Rank 1" }, [205] = { "Frostbolt", "Rank 2" }, [837] = { "Frostbolt", "Rank 3" }, [7322] = { "Frostbolt", "Rank 4" },
    [1459] = { "Arcane Intellect", "Rank 1" }, [168] = { "Frost Armor", "Rank 1" }, [7302] = { "Ice Armor", "Rank 1" },
    [3561] = { "Teleport: Stormwind", "" }, [133] = { "Fireball", "Rank 1" },
}
local book = { 116, 205, 837, 7322, 1459, 168, 7302, 3561, 133 }
C_SpellBook = {
    GetNumSpellBookSkillLines = function() return 1 end,
    GetSpellBookSkillLineInfo = function() return { name = "Frost", itemIndexOffset = 0, numSpellBookItems = #book } end,
    GetSpellBookItemInfo = function(slot)
        local id = book[slot]
        if not id then return nil end
        return { itemType = 1, spellID = id, actionID = id, name = SPELLS[id][1], subName = SPELLS[id][2], isOffSpec = false }
    end,
}
C_Spell = {
    GetSpellName = function(id) return SPELLS[id] and SPELLS[id][1] end,
    GetSpellSubtext = function(id) return SPELLS[id] and SPELLS[id][2] end,
}
local bars = { [14] = 205, [2] = 1459, [3] = 3561, [5] = 133 }
GetActionInfo = function(slot) if bars[slot] then return "spell", bars[slot], "spell" end end

-- Auras: name -> expirationTime (0 = no end).
local auras = {}
local secretAuras = false
C_UnitAuras = {
    GetAuraDataByIndex = function(_, index)
        local i = 0
        for name, expires in pairs(auras) do
            i = i + 1
            if i == index then
                if secretAuras then return { name = SECRET, expirationTime = SECRET } end
                return { name = name, expirationTime = expires }
            end
        end
    end,
}
local itemCounts = { [17031] = 0 }
C_Item = { GetItemCount = function(id) return itemCounts[id] or 0 end, GetItemInfoInstant = function() return nil end }
C_Container = { GetContainerNumSlots = function() return 16 end }
GetInventoryItemLink = function() return nil end

local timers, tickers = {}, {}
C_Timer = {
    After = function(_, fn) timers[#timers + 1] = fn end,
    NewTicker = function(_, fn) tickers[#tickers + 1] = fn end,
}
local function flush()
    while #timers > 0 do
        local list = timers; timers = {}
        for _, fn in ipairs(list) do fn() end
    end
end

local n = #frames
local okLoad, errLoad = pcall(function() assert(loadfile(base .. "/ReadyCheck/ReadyCheck.lua"))("ReadyCheck", {}) end)
assert(okLoad, "loads even when an event is refused: " .. tostring(errLoad))
local f = frames[n + 1]
local function fire(ev, ...) f.fn(f, ev, ...) end
local function has(text) for _, t in ipairs(out) do if t:find(text, 1, true) then return true end end return false end
local function dump() return "\n  output was:\n  " .. table.concat(out, "\n  ") end
local function check(cond, why) if not cond then failures[#failures + 1] = why .. dump() end end
local function need(text, why) check(has(text), why .. ": wanted '" .. text .. "'") end
local function page(arg)
    out = {}
    local ok, err = pcall(SlashCmdList.SPELLREADY, arg)
    if not ok then out[#out + 1] = "<<ERROR: " .. tostring(err) .. ">>" end
end
local function status()
    local rows = ForeverHubStatus.SpellReady() or {}
    local texts = {}
    for _, r in ipairs(rows) do texts[#texts + 1] = r.text end
    return rows, table.concat(texts, " | ")
end

check(SlashCmdList.READYCHECK == nil, "does not take Blizzard's READYCHECK key")
check(SLASH_SPELLREADY1 == "/rcheck", "slash command")
check(f.registered.UNIT_AURA and f.registered.ACTIONBAR_SLOT_CHANGED, "events registered")

-- Login: everything checked after a short delay. AI is up, armor missing; not resting.
auras = { ["Arcane Intellect"] = now + 1800 }
out = {}
fire("PLAYER_LOGIN")
check(#tickers == 1, "a buff ticker is started")
flush()
need("Ice Armor or Frost Armor is missing", "login toast for missing armor")
local toastCount = #out
check(toastCount == 1, "exactly one pop-up line at login, got " .. toastCount)

-- Old rank.
page("")
need("Frostbolt on Action bar 1 (page 2), button 2 is Rank 2; you know Rank 4.", "old rank listed")
check(not has("Fireball on "), "best rank not listed")
need("Ice Armor or Frost Armor is missing.", "missing buff on page")
need("Rune of Teleportation: 0 left (for Teleport: Stormwind)", "reagent for a bar spell")
need("set a target on the Supplies page", "points to Supplies")
check(not has("Arcane Powder"), "no reagent for spells not on bars")
local rows, text = status()
check(#rows == 2, "two status rows, got " .. #rows)
check(text:find("Frostbolt on your bars is old", 1, true), "rank status row: " .. text)
check(text:find("Ice Armor or Frost Armor is missing", 1, true), "buff status row: " .. text)
check(rows[1].page == "Ready check", "row page")

-- Ignore / unignore.
page("ignore frostbolt")
need("Ignoring Frostbolt", "ignore confirms with proper name")
check(ReadyCheckDB.ignored.frostbolt == "Frostbolt", "saved per character")
page("")
check(not has("Frostbolt on Action bar"), "ignored spell not listed")
need("1 spell(s) ignored", "ignored count shown")
page("ignored")
need("Ranks not checked: Frostbolt.", "ignored list")
page("unignore Frostbolt")
need("Frostbolt is checked again", "unignore")
page("")
need("Frostbolt on Action bar 1 (page 2), button 2", "listed again after unignore")
page("unignore Fireball")
need("Fireball wasn't ignored", "unignore unknown")
page("bogus")
need("Type: ignore Frostbolt", "help")

-- Bar change re-scans, throttled to one run.
bars[14] = 7322
fire("ACTIONBAR_SLOT_CHANGED", 14); fire("ACTIONBAR_SLOT_CHANGED", 14); fire("SPELLS_CHANGED")
check(#timers == 1, "events throttled into one scan, got " .. #timers)
flush()
rows, text = status()
check(not text:find("Rank", 1, true), "rank row gone after fixing the bar: " .. text)

-- Toast throttle: buff stays missing -> no repeat; recast and lose again within 5 min -> no repeat.
out = {}
fire("UNIT_AURA", "player"); fire("UNIT_AURA", "player")
check(#timers == 1, "UNIT_AURA throttled")
flush()
check(#out == 0, "no repeat while still missing")
auras["Ice Armor"] = 0
now = now + 10
fire("UNIT_AURA", "player"); flush()
auras["Ice Armor"] = nil
now = now + 60
out = {}
fire("UNIT_AURA", "player"); flush()
check(#out == 0, "no new pop-up within 5 minutes for the same buff")
auras["Ice Armor"] = 0; fire("UNIT_AURA", "player"); flush()
now = now + 400
auras["Ice Armor"] = nil
out = {}
fire("UNIT_AURA", "player"); flush()
need("Ice Armor or Frost Armor is missing", "pop-up again after 5 minutes")

-- Running low (< 60 s).
auras["Ice Armor"] = 0
auras["Arcane Intellect"] = now + 30
out = {}
fire("UNIT_AURA", "player"); flush()
need("Arcane Intellect runs out in 30 s", "low buff pop-up")

-- In combat: nothing evaluated, no pop-ups, no buff row.
auras["Arcane Intellect"] = nil
combat = true
fire("PLAYER_REGEN_DISABLED")
out = {}
fire("UNIT_AURA", "player"); flush()
for _, t in ipairs(tickers) do t() end; flush()
check(#out == 0, "no pop-up in combat")
rows, text = status()
check(not text:find("Buff", 1, true), "no buff row in combat: " .. text)
page("")
need("Checked again when combat ends", "page in combat")
-- Combat ends: now it's missing.
combat = false
now = now + 400
out = {}
fire("PLAYER_REGEN_ENABLED"); flush()
need("Arcane Intellect is missing", "pop-up after combat")

-- Resting: no pop-ups, no status row; page still informs.
resting = true
now = now + 400
auras["Arcane Intellect"] = now + 1800; fire("UNIT_AURA", "player"); flush()
auras["Arcane Intellect"] = nil
out = {}
fire("PLAYER_UPDATE_RESTING"); flush()
check(#out == 0, "no pop-up while resting")
rows, text = status()
check(not text:find("Buff", 1, true), "no buff row while resting: " .. text)
page("")
need("No pop-ups in towns and inns", "page notes resting")
resting = false
out = {}
fire("PLAYER_UPDATE_RESTING"); flush()
need("Arcane Intellect is missing", "pop-up after leaving town")

-- Secret aura values: no error, nothing claimed missing.
secretAuras = true
auras["Ice Armor"] = 0
now = now + 400
out = {}
local ok = pcall(function() fire("UNIT_AURA", "player"); flush() end)
check(ok, "secret auras don't error")
check(#out == 0, "secret auras don't produce pop-ups")
page("")
need("isn't showing your buffs", "page says buffs unreadable")
rows, text = status()
check(not text:find("Buff", 1, true), "no buff row when unreadable")
secretAuras = false

-- Secret action/spell values don't error either.
GetActionInfo = function(slot) if slot == 14 then return SECRET, SECRET end end
page("")
check(not has("<<ERROR"), "secret action info is fine")

-- Warrior: nothing to keep up; Rogue poison checked by weapon enchant.
class = "WARRIOR"
page("")
need("Nothing to keep up for your class", "warrior has no buffs")
class = "ROGUE"
book[#book + 1] = 2842; SPELLS[2842] = { "Poisons", "" }
GetInventoryItemLink = function(_, slot) if slot == 16 then return "item:1" end end
GetWeaponEnchantInfo = function() return false, 0, 0, 0, false, 0, 0, 0 end
page("")
need("Main-hand poison is missing.", "rogue poison missing")
check(not has("Off-hand poison"), "no off-hand weapon, no off-hand reminder")
GetWeaponEnchantInfo = function() return true, 1800000, 20, 7, false end
page("")
check(not has("Main-hand poison"), "poison present")

if #failures > 0 then
    print("FAILURES (" .. #failures .. "):")
    for _, why in ipairs(failures) do print(" - " .. why) end
    os.exit(1)
end
print("test_readycheck: all checks passed")
