-- Review 4, suspicions 6, 7 and 13 (TrainerNotes):
-- 6. A rank chain only counts a later rank as knowing an earlier one when both have the same spell name
--    (as ReadyCheck does); a chain that links two different spells doesn't hide the earlier one.
-- 7. Warlock tomes: a known higher rank of the same pet spell means the older tomes aren't listed again.
-- 13. A tome shared by Succubus and Incubus is listed once.
-- Run:  node run.js "<workspace root>" test_fix4_trainer.lua
local base = ADDON_PATH
local out, frames, failures = {}, {}, {}
local function check(cond, why) if not cond then failures[#failures + 1] = why .. "\n  output was:\n  " .. table.concat(out, "\n  ") end end
CreateFrame = function()
    local f = { registered = {} }
    f.RegisterEvent = function(self, e) self.registered[e] = true end
    f.SetScript = function(self, _, fn) self.fn = fn end
    frames[#frames + 1] = f
    return f
end
ForeverHub_Receive = function(_, t) out[#out + 1] = t end
SlashCmdList = {}
issecretvalue = function() return false end
UnitName = function() return "Tester" end
GetRealmName = function() return "Realm" end
local level, class = 20, "WARRIOR"
UnitLevel = function() return level end
UnitClass = function() return "x", class end
UnitFactionGroup = function() return "Alliance" end
UnitRace = function() return "Human", "Human", 1 end
GetMoney = function() return 1000000 end
Enum = { TrainerType = { General = 0 }, SpellBookSpellBank = { Player = 0, Pet = 1 }, SpellBookItemType = { Spell = 1 } }
C_Timer = { After = function(_, fn) fn() end }

local known, petKnown = {}, {}
C_SpellBook = {
    IsSpellKnown = function(id, bank) if bank == 1 then return petKnown[id] == true end return known[id] == true end,
    GetNumSpellBookSkillLines = function() return 0 end,
}
local NAMES = {
    [9001] = { "Heroic Strike", "Rank 1" }, [9002] = { "Cleave", "Rank 1" },
    [9003] = { "Hamstring", "Rank 1" }, [9004] = { "Hamstring", "Rank 2" },
    [9005] = { "Rend", "Rank 1" }, [9006] = { "Rend", "Rank 2" },
    [7799] = { "Firebolt", "Rank 2" }, [7800] = { "Firebolt", "Rank 3" }, [6360] = { "Soothing Kiss", "Rank 1" },
}
local unloaded = { [9006] = true }
C_Spell = {
    IsSpellDataCached = function(id) return not unloaded[id] end,
    RequestLoadSpellData = function() end,
    GetSpellName = function(id) return not unloaded[id] and NAMES[id] and NAMES[id][1] or nil end,
    GetSpellSubtext = function(id) return not unloaded[id] and NAMES[id] and NAMES[id][2] or nil end,
}
local items = { [16302] = "Grimoire of Firebolt (Rank 2)", [16316] = "Grimoire of Firebolt (Rank 3)", [16375] = "Grimoire of Soothing Kiss (Rank 1)" }
C_Item = { GetItemNameByID = function(id) return items[id] end, GetItemCount = function() return 0 end }
TrainerNotesData = {
    classes = {
        WARRIOR = {
            spells = { { 10, 9001, 100 }, { 20, 9002, 200 }, { 10, 9003, 100 }, { 20, 9004, 200 }, { 10, 9005, 100 }, { 20, 9006, 200 } },
            -- A generated chain that wrongly links Heroic Strike to Cleave, and two real ones.
            ranks = { { 9001, 9002 }, { 9003, 9004 }, { 9005, 9006 } },
        },
        WARLOCK = { spells = {}, ranks = {} },
    },
    tomes = {
        { 8, 16302, 100, "Imp", 7799 },
        { 18, 16316, 1500, "Imp", 7800 },
        { 22, 16375, 2500, "Succubus", 6360 },
        { 22, 16375, 2500, "Incubus", 6360 },
    },
    trainerFactions = {},
}
assert(loadfile(base .. "/TrainerNotes/TrainerNotes.lua"))("TrainerNotes", {})
local tr = frames[#frames]
local function fire(ev, ...) tr.fn(tr, ev, ...) end
local function count(text) local n = 0 for _, t in ipairs(out) do if t:find(text, 1, true) then n = n + 1 end end return n end
local function has(text) return count(text) > 0 end
local function page() out = {}; local ok, err = pcall(SlashCmdList.TRAINERNOTES, ""); if not ok then out[#out + 1] = "<<ERROR " .. tostring(err) .. ">>" end end
fire("PLAYER_LOGIN")

-- 6. Cleave known (a different spell, wrongly chained): Heroic Strike rank 1 is still to train.
known = { [9002] = true, [9004] = true, [9006] = true }
fire("SPELLS_CHANGED")
page()
check(not has("<<ERROR"), "no error")
check(has("Heroic Strike (Rank 1)"), "different name: the earlier spell isn't hidden")
check(not has("Hamstring (Rank 1)"), "same name: a later rank known still counts")
-- A later rank whose name hasn't loaded yet: counted as before (the page is drawn again when it loads).
check(not has("Rend (Rank 1)"), "unloaded later rank: chain trusted")

-- 7 and 13. Warlock with an Imp and a Succubus and Incubus; the Imp knows Firebolt rank 3 only.
class, level = "WARLOCK", 20
known = { [688] = true, [712] = true, [713] = true }
petKnown = { [7800] = true }
fire("UNIT_PET", "player")
page()
check(has("Demon tomes"), "tome section")
check(not has("Grimoire of Firebolt (Rank 3)"), "known tome skipped")
check(not has("Grimoire of Firebolt (Rank 2)"), "older rank of a known pet spell not listed again")
check(count("Grimoire of Soothing Kiss (Rank 1)") == 1, "shared Succubus/Incubus tome listed once (" .. count("Grimoire of Soothing Kiss") .. ")")
-- The higher rank stays remembered after the Imp is dismissed: still not listed.
petKnown = {}
page()
check(not has("Grimoire of Firebolt (Rank 2)"), "still skipped with the Imp dismissed")

if #failures > 0 then
    print("FAILURES (" .. #failures .. "):")
    for _, why in ipairs(failures) do print(" - " .. why) end
    os.exit(1)
end
print("test_fix4_trainer: all checks passed")
