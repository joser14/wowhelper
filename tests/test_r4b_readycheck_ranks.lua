-- Round 4 item 6: SpellReady (ReadyCheck) finds old ranks on your bars by spell ID, from the rank
-- groups in TrainerNotesData (What's Training, MIT): works where Forever renumbers ranks or the
-- spellbook shows no rank text; the two spells' names must agree; other spells keep the name check.
-- Run:  node run.js "<workspace root>" test_r4b_readycheck_ranks.lua
local base = ADDON_PATH
local out, frames, failures = {}, {}, {}
local SECRET = {}
local function check(cond, why) if not cond then failures[#failures + 1] = why .. "\n  output was:\n  " .. table.concat(out, "\n  ") end end
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
GetTime = function() return 100 end
InCombatLockdown = function() return false end
IsResting = function() return true end
UnitIsDeadOrGhost = function() return false end
UnitClass = function() return "Warrior", "WARRIOR" end
C_Item = { GetItemCount = function() return 10 end }
C_Container = { GetContainerNumSlots = function() return 16 end }
C_UnitAuras = { GetAuraDataByIndex = function() return nil end }

TrainerNotesData = { classes = { WARRIOR = { ranks = {
    { 1240193, 1464, 8820, 11604, 11605 },   -- Slam, renumbered on Forever
    { 772, 6546, 6547 },                     -- Rend
    { 900001, 900002 },                      -- a group whose names don't agree (bad data): never flagged
} } } }

local SPELLS = {
    [1240193] = { "Slam", "" }, [1464] = { "Slam", "" }, [8820] = { "Slam", "" },
    [772] = { "Rend", "Rank 1" }, [6546] = { "Rend", "Rank 2" }, [6547] = { "Rend", "Rank 3" },
    [900001] = { "Charge", "" }, [900002] = { "Something Else", "" },
    [78] = { "Heroic Strike", "Rank 1" }, [284] = { "Heroic Strike", "Rank 2" },
}
local known = { [1464] = true, [6546] = true, [900002] = true, [284] = true }
local secretKnown = false
-- The spellbook shows only the top rank of each, with no rank text for Slam (as on Forever).
local book = { 1464, 6546, 900002, 284 }
C_SpellBook = {
    IsSpellKnown = function(id) if secretKnown then return SECRET end return known[id] == true end,
    GetNumSpellBookSkillLines = function() return 1 end,
    GetSpellBookSkillLineInfo = function() return { name = "Arms", itemIndexOffset = 0, numSpellBookItems = #book } end,
    GetSpellBookItemInfo = function(slot)
        local id = book[slot]
        if not id then return nil end
        return { itemType = 1, spellID = id, name = SPELLS[id][1], subName = SPELLS[id][2] }
    end,
}
C_Spell = {
    GetSpellName = function(id) return SPELLS[id] and SPELLS[id][1] end,
    GetSpellSubtext = function(id) return SPELLS[id] and SPELLS[id][2] end,
}
local bars = { [1] = 1240193, [2] = 772, [3] = 900001, [4] = 78 }
GetActionInfo = function(slot) if bars[slot] then return "spell", bars[slot], "spell" end end
local timers = {}
C_Timer = { After = function(_, fn) timers[#timers + 1] = fn end, NewTicker = function() end }
local function flush() local n = 0 while #timers > 0 and n < 10000 do n = n + 1; table.remove(timers, 1)() end end

assert(loadfile(base .. "/ReadyCheck/ReadyCheck.lua"))("ReadyCheck", {})
local f = frames[#frames]
local function fire(ev, ...) f.fn(f, ev, ...) end
local function has(text) for _, t in ipairs(out) do if t:find(text, 1, true) then return true end end return false end
local function need(text, why) check(has(text), why .. ": wanted '" .. text .. "'") end
local function page(arg) out = {}; local ok, err = pcall(SlashCmdList.SPELLREADY, arg or ""); if not ok then out[#out + 1] = "<<ERROR " .. tostring(err) .. ">>" end end

fire("PLAYER_LOGIN"); flush()
page()
need("Slam on Action bar 1, button 1 is Rank 1; you know Rank 2.", "renumbered Slam with no rank text, by spell ID")
need("Rend on Action bar 1, button 2 is Rank 1; you know Rank 2.", "Rend by ID")
check(not has("Charge"), "names that don't agree are never flagged")
need("Heroic Strike on Action bar 1, button 4 is Rank 1; you know Rank 2.", "spell in no group: name check still works")
-- Status row too.
local rows = ForeverHubStatus.SpellReady()
check(rows[1] and rows[1].text:find("Slam", 1, true), "status row names Slam")

-- The best rank on the bar: nothing to say.
bars[1] = 1464
fire("ACTIONBAR_SLOT_CHANGED", 1); flush()
page()
check(not has("Slam on"), "best rank on the bar is fine")

-- Ignored spells stay quiet.
bars[1] = 1240193
page("ignore Slam")
page()
check(not has("Slam on"), "ignored")
page("unignore Slam")

-- Secret known answers never error and claim nothing.
secretKnown = true
page()
check(not has("<<ERROR"), "secret IsSpellKnown doesn't error")
check(not has("Slam on"), "secret: no claim")
secretKnown = false

-- No rank data at all: back to the name check only.
TrainerNotesData = nil
page()
need("Rend on", "no data: Rend's name check finds rank 1 vs 2 in the book")
check(not has("Slam on"), "no data: Slam without rank text can't be told")
need("Heroic Strike on", "name check unaffected")

if #failures > 0 then
    print("FAILURES (" .. #failures .. "):")
    for _, why in ipairs(failures) do print(" - " .. why) end
    os.exit(1)
end
print("test_r4b_readycheck_ranks: all checks passed")
