-- Round 4 item 3: TrainerNotes knows every Forever class-trainer spell 1-60 (TrainerNotes\Data.lua,
-- generated from What's Training, MIT) before any trainer visit: ready now, next 2 levels, needs a
-- talent, needs something first; known by spell ID (a later rank counts); race and faction rows.
-- Run:  node run.js "<workspace root>" test_r4b_trainer_full.lua
local base = ADDON_PATH
local out, frames, failures = {}, {}, {}
local SECRET = {}
local function check(cond, why) if not cond then failures[#failures + 1] = why .. "\n  output was:\n  " .. table.concat(out, "\n  ") end end
CreateFrame = function()
    local f = { registered = {} }
    f.RegisterEvent = function(self, e) self.registered[e] = true end
    f.SetScript = function(self, _, fn) self.fn = fn end
    frames[#frames + 1] = f
    return f
end
print = function(...) failures[#failures + 1] = "chat output: " .. tostring((...)) end
ForeverHub_Receive = function(_, t) out[#out + 1] = t end
SlashCmdList = {}
issecretvalue = function(v) return v == SECRET end
UnitName = function() return "Tester" end
GetRealmName = function() return "Realm" end
local level, class, faction, race = 20, "WARRIOR", "Alliance", 1
UnitLevel = function() return level end
UnitClass = function() return "x", class end
UnitFactionGroup = function() return faction end
UnitRace = function() return "Human", "Human", race end
GetMoney = function() return 1000000 end
Enum = { TrainerType = { General = 0 }, SpellBookSpellBank = { Player = 0, Pet = 1 }, SpellBookItemType = { Spell = 1 } }
local timers = {}
C_Timer = { After = function(_, fn) timers[#timers + 1] = fn end }
local function flush() local n = 0 while #timers > 0 and n < 10000 do n = n + 1; table.remove(timers, 1)() end end

local known = {}
for _, id in ipairs({ 6673, 100, 772, 3127, 6343, 1715, 78, 284, 2687, 6546, 5242, 7384, 72, 1160, 1310185, 285, 694, 8198 }) do known[id] = true end
local secretKnown = false
C_SpellBook = {
    IsSpellKnown = function(id) if secretKnown then return SECRET end return known[id] == true end,
    IsSpellInSpellBook = function() return false end,
    GetNumSpellBookSkillLines = function() return 0 end,
}
local NAMES = {
    [845] = { "Cleave", "Rank 1" }, [674] = { "Dual Wield", "" }, [6547] = { "Rend", "Rank 3" }, [20230] = { "Retaliation", "" },
    [1240193] = { "Slam", "Rank 1" }, [402927] = { "Victory Rush", "" }, [6572] = { "Revenge", "Rank 1" }, [71] = { "Defensive Stance", "" },
    [6192] = { "Battle Shout", "Rank 3" }, [5246] = { "Intimidating Shout", "" }, [7405] = { "Sunder Armor", "Rank 2" }, [7386] = { "Sunder Armor", "Rank 1" },
    [23892] = { "Bloodthirst", "Rank 2" }, [3561] = { "Teleport: Stormwind", "" }, [3563] = { "Teleport: Undercity", "" },
}
local loaded, requested = {}, {}
for id in pairs(NAMES) do loaded[id] = true end
loaded[5246] = false
C_Spell = {
    IsSpellDataCached = function(id) return loaded[id] ~= false end,
    RequestLoadSpellData = function(id) requested[id] = true end,
    GetSpellName = function(id) return loaded[id] ~= false and NAMES[id] and NAMES[id][1] or nil end,
    GetSpellSubtext = function(id) return loaded[id] ~= false and NAMES[id] and NAMES[id][2] or nil end,
}

assert(loadfile(base .. "/TrainerNotes/Data.lua"))("TrainerNotes", {})
check(type(TrainerNotesData) == "table" and TrainerNotesData.classes.WARRIOR, "generated data loads")
local n = #frames
assert(loadfile(base .. "/TrainerNotes/TrainerNotes.lua"))("TrainerNotes", {})
local tr = frames[n + 1]
local function fire(ev, ...) tr.fn(tr, ev, ...) end
local function has(text) for _, t in ipairs(out) do if t:find(text, 1, true) then return true end end return false end
local function need(text, why) check(has(text), why .. ": wanted '" .. text .. "'") end
local function page() out = {}; local ok, err = pcall(SlashCmdList.TRAINERNOTES, ""); if not ok then out[#out + 1] = "<<ERROR " .. tostring(err) .. ">>" end end
local function line(text) for _, t in ipairs(out) do if t:find(text, 1, true) then return t end end return "" end

fire("PLAYER_LOGIN"); flush()

-- Before any trainer visit: the full list.
page()
check(not has("Nothing noted yet"), "no 'visit a trainer first' with the full list")
need("Ready to train", "ready section")
need("Cleave", "Cleave ready at 20")
need("Victory Rush", "Forever-new spell at 20")
need("Rend (Rank 3)", "rank shown")
check(line("Slam"):find("Ready", 1, true) == nil, "sanity")
need("Slam (Rank 1)", "Slam rank 1 still to train")
check(not has("Battle Stance"), "nothing known is listed")
-- Needs a quest spell first.
need("Revenge", "Revenge listed")
check(line("Revenge"):find("Defensive Stance", 1, true), "Revenge needs Defensive Stance: " .. line("Revenge"))
-- Next two levels.
need("Next 2 levels", "next section")
need("Battle Shout (Rank 3)", "level-22 rank")
check(line("Sunder Armor (Rank 2)"):find("needs Sunder Armor", 1, true), "Sunder rank 2 needs rank 1: " .. line("Sunder Armor (Rank 2)"))
-- A name still loading is asked for, and the page shows a placeholder.
check(requested[5246], "unloaded spell name requested")
need("spell 5246", "placeholder while loading")
loaded[5246] = true
fire("SPELL_DATA_LOAD_RESULT", 5246, true); flush()
page()
need("Intimidating Shout", "name after load")
-- Total for ready rows: 845, 674, 6547, 20230, 1240193, 402927 at 34s each = 2g 4s.
need("2g 4s 0c", "ready total")
local row = ForeverHubStatus.TrainerNotes()
check(row and row[1].text:find("Train|r 6 spell", 1, true), "status row from the full list: " .. tostring(row and row[1].text))

-- A later rank known means the earlier one is known (Forever renumbered Slam: 1240193 then 1464).
known[1464] = true
fire("SPELLS_CHANGED"); flush()
page()
check(not has("Slam (Rank 1)"), "Slam rank 1 known through rank 2")
need("1g 70s 0c", "ready total without Slam")

-- Talent-gated ranks are listed apart.
level = 48
page()
need("Needs a talent", "talent section")
check(line("Bloodthirst"):find("Bloodthirst", 1, true), "Bloodthirst rank 2 under talents")

-- Faction rows: an Alliance mage gets Teleport: Stormwind, not Undercity.
class, level = "MAGE", 20
page()
need("Teleport: Stormwind", "Alliance teleport")
check(not has("Teleport: Undercity"), "no Horde teleport for the Alliance")

-- Secret answers are 'not known', never an error.
secretKnown = true
page()
check(not has("<<ERROR"), "secret known check doesn't error")
secretKnown = false

-- No known-check API: the full list stays off (old trainer notes only).
C_SpellBook, IsSpellKnown, IsPlayerSpell = nil, nil, nil
page()
check(not has("Teleport: Stormwind"), "no full list without a way to tell what you know")

if #failures > 0 then
    print = nil
    io.write("FAILURES (" .. #failures .. "):\n")
    for _, why in ipairs(failures) do io.write(" - " .. why .. "\n") end
    os.exit(1)
end
io.write("test_r4b_trainer_full: all checks passed\n")
