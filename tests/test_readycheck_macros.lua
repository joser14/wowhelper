-- SpellReady (ReadyCheck folder): spells inside macros, readable bar and button names (stance and
-- form bars too), and spell data loaded before it is read (request, SPELL_DATA_LOAD_RESULT, retries).
-- Run from the harness folder:  node run.js "<workspace root>" test_readycheck_macros.lua
local base = ADDON_PATH
local out, frames, failures = {}, {}, {}
local SECRET = {}
ForeverHub_Receive = function(_, t) out[#out + 1] = t end
issecretvalue = function(v) return v == SECRET end
CreateFrame = function()
    local f = { registered = {} }
    f.RegisterEvent = function(self, e) self.registered[e] = true end
    f.SetScript = function(self, _, fn) self.fn = fn end
    frames[#frames + 1] = f
    return f
end
SlashCmdList = {}
Enum = { SpellBookSpellBank = { Player = 0 }, SpellBookItemType = { Spell = 1 } }
GetTime = function() return 1000 end
InCombatLockdown = function() return false end
IsResting = function() return true end
UnitIsDeadOrGhost = function() return false end
local class = "WARRIOR"
UnitClass = function() return "x", class end

local SPELLS = {
    [1] = { "Heroic Strike", "Rank 1" }, [2] = { "Heroic Strike", "Rank 2" }, [3] = { "Heroic Strike", "Rank 3" },
    [10] = { "Rend", "Rank 1" }, [11] = { "Rend", "Rank 2" },
    [20] = { "Hamstring", "Rank 1" }, [21] = { "Hamstring", "Rank 2" },
    [30] = { "Shield Bash", "Rank 1" }, [31] = { "Shield Bash", "Rank 2" },
}
local book = { 3, 11, 21, 31 }
C_SpellBook = {
    GetNumSpellBookSkillLines = function() return 1 end,
    GetSpellBookSkillLineInfo = function() return { name = "Arms", itemIndexOffset = 0, numSpellBookItems = #book } end,
    GetSpellBookItemInfo = function(slot)
        local id = book[slot]
        return id and { itemType = 1, spellID = id, name = SPELLS[id][1], subName = SPELLS[id][2] } or nil
    end,
}
local cached = {}
local requested = {}
C_Spell = {
    GetSpellName = function(id) return SPELLS[id] and SPELLS[id][1] end,
    GetSpellSubtext = function(id) return SPELLS[id] and SPELLS[id][2] end,
    IsSpellDataCached = function(id) return cached[id] ~= false end,
    RequestLoadSpellData = function(id) requested[id] = (requested[id] or 0) + 1 end,
}
-- Bars: slot -> { kind, id, subType }.
local bars = {
    [3] = { "spell", 1, "spell" },          -- Action bar 1, button 3
    [65] = { "spell", 10, "spell" },        -- Bottom left bar, button 5
    [86] = { "spell", 20, "spell" },        -- Defensive Stance bar, button 2
    [7] = { "macro", 4 },                   -- macro index 4 casts Shield Bash rank 1
    [30] = { "macro", 2, "spell" },         -- "spell" macro: the id is the spell
}
GetActionInfo = function(slot) local b = bars[slot]; if b then return b[1], b[2], b[3] end end
local macroSpells = { [4] = 30 }
GetMacroSpell = function(index) return macroSpells[index] end
C_ActionBar = {
    GetActionText = function(slot) if slot == 7 then return "Bash" elseif slot == 30 then return "Strike" end end,
    GetSpell = function(slot) if slot == 50 then return 10 end return 0 end,
}
C_Item = { GetItemCount = function() return 0 end }
C_Container = { GetContainerNumSlots = function() return 16 end }
GetInventoryItemLink = function() return nil end
local timers = {}
C_Timer = { After = function(delay, fn) timers[#timers + 1] = { delay = delay, fn = fn } end, NewTicker = function() end }
local function flush(limit)
    local runs = 0
    while #timers > 0 do
        runs = runs + 1
        assert(runs < (limit or 100), "timers never stop")
        local list = timers; timers = {}
        for _, t in ipairs(list) do t.fn() end
    end
    return runs
end

assert(loadfile(base .. "/ReadyCheck/ReadyCheck.lua"))("ReadyCheck", {})
local f = frames[#frames]
local function fire(ev, ...) f.fn(f, ev, ...) end
local function has(text) for _, t in ipairs(out) do if t:find(text, 1, true) then return true end end return false end
local function dump() return "\n  output was:\n  " .. table.concat(out, "\n  ") end
local function check(cond, why) if not cond then failures[#failures + 1] = why .. dump() end end
local function need(text, why) check(has(text), why .. ": wanted '" .. text .. "'") end
local function page(arg)
    out = {}
    local ok, err = pcall(SlashCmdList.SPELLREADY, arg or "")
    if not ok then out[#out + 1] = "<<ERROR: " .. tostring(err) .. ">>" end
end

check(f.registered.SPELL_DATA_LOAD_RESULT, "listens for spell data")
check(f.registered.UPDATE_MACROS, "listens for macro edits")
fire("PLAYER_LOGIN"); flush()

-- 1. Readable names, macros included.
page("")
need("Heroic Strike on Action bar 1, button 3 is Rank 1; you know Rank 3.", "main bar")
need("Rend on Bottom left bar, button 5 is Rank 1; you know Rank 2.", "bottom left bar")
need("Hamstring on Defensive Stance bar, button 2 is Rank 1; you know Rank 2.", "warrior stance bar")
need("Shield Bash on Action bar 1, button 7 (in macro \"Bash\") is Rank 1; you know Rank 2.", "macro via GetMacroSpell")
need("Heroic Strike on Right bar, button 6 (in macro \"Strike\") is Rank 2; you know Rank 3.", "macro whose id is the spell")
-- Without GetMacroSpell, C_ActionBar.GetSpell answers for the slot.
GetMacroSpell = nil
bars[7] = nil
bars[50] = { "macro", 9 }
page("")
need("Rend on Bottom right bar, button 2 (in macro", "macro via C_ActionBar.GetSpell")
-- A macro the game can't resolve is skipped quietly.
bars[50] = { "macro", 12 }
C_ActionBar.GetSpell = function() return 0 end
page("")
check(not has("<<ERROR"), "unresolved macro is fine")
check(not has("Bottom right bar"), "unresolved macro not listed")
-- Secret macro data never errors.
bars[50] = { "macro", SECRET, SECRET }
C_ActionBar.GetActionText = function() return SECRET end
page("")
check(not has("<<ERROR"), "secret macro data is fine")
bars[50] = nil

-- 2. Other classes' form bars, and the generic names.
class = "DRUID"
bars[3], bars[65], bars[86], bars[30] = nil, nil, nil, nil
bars[73] = { "spell", 1, "spell" }
bars[110] = { "spell", 10, "spell" }
bars[87] = { "spell", 20, "spell" }
bars[150] = { "spell", 30, "spell" }
page("")
need("Heroic Strike on Cat Form bar, button 1", "druid cat bar")
need("Rend on Moonkin Form bar, button 2", "druid moonkin bar")
need("Hamstring on Stance or form bar 2, button 3", "unnamed form page")
need("Shield Bash on Action bar 6, button 6", "extra bar 6")
class = "MAGE"
page("")
need("Heroic Strike on Stance or form bar 1, button 1", "class without form bars")
bars = { [3] = { "spell", 1, "spell" } }
GetActionInfo = function(slot) local b = bars[slot]; if b then return b[1], b[2], b[3] end end

-- 3. Spell data that isn't loaded yet is requested, and the list updates when it arrives.
class = "WARRIOR"
cached[1] = false
page("")
check(not has("Heroic Strike on"), "not read before it loads")
need("still loading", "page says spells are loading")
check((requested[1] or 0) >= 1, "load requested")
-- The game answers: one quiet rescan, then it's listed.
flush()
cached[1] = nil
out = {}
fire("SPELL_DATA_LOAD_RESULT", 1, true)
check(#timers == 1 and timers[1].delay == 0.5, "one rescan after the data arrives")
flush()
check(#out == 0, "a rescan makes no pop-ups")
local rows = ForeverHubStatus.SpellReady() or {}
check(rows[1] and rows[1].text:find("Heroic Strike on your bars is old", 1, true), "status after load")
-- A spell this addon didn't ask for changes nothing.
fire("SPELL_DATA_LOAD_RESULT", 999, true)
check(#timers == 0, "unrelated spell data ignored")
-- Data that never arrives: a few retries, then it stops.
cached[1] = false
requested[1] = 0
fire("ACTIONBAR_SLOT_CHANGED", 3)
local runs = flush()
check(requested[1] >= 2 and requested[1] <= 5, "retried a few times: " .. tostring(requested[1]))
check(#timers == 0, "retries stop")
-- A secret cache answer reads what's there.
cached[1] = nil
C_Spell.IsSpellDataCached = function() return SECRET end
page("")
need("Heroic Strike on Action bar 1, button 3", "secret cache state is read anyway")

if #failures > 0 then
    print("FAILURES (" .. #failures .. "):")
    for _, why in ipairs(failures) do print(" - " .. why) end
    os.exit(1)
end
print("test_readycheck_macros: all checks passed")
