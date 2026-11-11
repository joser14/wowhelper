-- Round 4 item 17 (re_round4 R16): TrainerNotes shows the 10 % trainer discount at Honored with a
-- trainer faction, class-quest spells (with the quest's name) and warlock demon tomes (never
-- discounted). Run:  node run.js "<workspace root>" test_r4b_trainer_extras.lua
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
ForeverHub_Receive = function(_, t) out[#out + 1] = t end
SlashCmdList = {}
issecretvalue = function(v) return v == SECRET end
UnitName = function() return "Tester" end
GetRealmName = function() return "Realm" end
local level, class, race = 20, "WARRIOR", 1
UnitLevel = function() return level end
UnitClass = function() return "x", class end
UnitFactionGroup = function() return "Alliance" end
UnitRace = function() return "Human", "Human", race end
GetMoney = function() return 1000000 end
Enum = { TrainerType = { General = 0 }, SpellBookSpellBank = { Player = 0, Pet = 1 }, SpellBookItemType = { Spell = 1 } }
C_Timer = { After = function(_, fn) fn() end }

local known, petKnown = {}, {}
for _, id in ipairs({ 6673, 100, 772, 3127, 6343, 1715, 78, 284, 2687, 6546, 5242, 7384, 72, 1160, 1310185, 285, 694, 8198, 1464 }) do known[id] = true end
C_SpellBook = {
    IsSpellKnown = function(id, bank) if bank == 1 then return petKnown[id] == true end return known[id] == true end,
    GetNumSpellBookSkillLines = function() return 0 end,
}
-- Both Slam ranks carry the game's one name (rank chains only count same-name ranks: review 4, suspicion 6).
local NAMES = { [71] = "Defensive Stance", [6572] = "Revenge", [355] = "Taunt", [7386] = "Sunder Armor", [1240193] = "Slam", [1464] = "Slam" }
C_Spell = { GetSpellName = function(id) return NAMES[id] or ("S" .. id) end, GetSpellSubtext = function() return "" end }
local rep = { [72] = { name = "Stormwind", reaction = 6 }, [47] = { name = "Ironforge", reaction = 5 } }
C_Reputation = { GetFactionDataByID = function(id) return rep[id] end }
LevelGuideQuestDB = { q = { [1665] = "10|10|4294967373|1|n6090|n6089|y1640||i6781|Bartleby's Mug" } }
local items = { [16351] = "Grimoire of Sacrifice (Rank 1)", [16346] = "Grimoire of Consume Shadows (Rank 1)", [16357] = "Grimoire of Consume Shadows (Rank 1)" }
C_Item = { GetItemNameByID = function(id) return items[id] end, GetItemCount = function() return 0 end }

assert(loadfile(base .. "/TrainerNotes/Data.lua"))("TrainerNotes", {})
assert(loadfile(base .. "/TrainerNotes/TrainerNotes.lua"))("TrainerNotes", {})
local tr = frames[#frames]
local function fire(ev, ...) tr.fn(tr, ev, ...) end
local function has(text) for _, t in ipairs(out) do if t:find(text, 1, true) then return true end end return false end
local function need(text, why) check(has(text), why .. ": wanted '" .. text .. "'") end
local function line(text) for _, t in ipairs(out) do if t:find(text, 1, true) then return t end end return "" end
local function page() out = {}; local ok, err = pcall(SlashCmdList.TRAINERNOTES, ""); if not ok then out[#out + 1] = "<<ERROR " .. tostring(err) .. ">>" end end
fire("PLAYER_LOGIN")

-- Honored with Stormwind: 10 % off there. Ready: 5 rows at 34s = 1g 70s; 10 % off = 1g 53s.
page()
need("10% off", "discount line")
check(line("10% off"):find("Stormwind", 1, true), "names the faction from the game: " .. line("10% off"))
check(not line("10% off"):find("Ironforge", 1, true), "Friendly isn't enough")
need("1g 53s 0c", "discounted ready total")
-- Below Honored everywhere: no discount line.
rep[72].reaction = 5
page()
check(not has("10% off"), "no discount below Honored")
rep[72].reaction = SECRET
page()
check(not has("<<ERROR") and not has("10% off"), "secret reaction ignored")
rep[72].reaction = 6

-- Class-quest spells: Defensive Stance, Taunt and Sunder Armor from 'Bartleby's Mug' (humans).
need("From class quests", "quest spell section")
check(line("Defensive Stance"):find("Bartleby's Mug", 1, true), "quest named from QuestDB: " .. line("Defensive Stance"))
check(line("Revenge"):find("class quest", 1, true), "Revenge's need says it's a class quest: " .. line("Revenge"))
known[71] = true
page()
check(not line("From class quests"):find("Defensive", 1, true) and not has("Defensive Stance: "), "known quest spell dropped")
-- Another race's quest isn't offered as such: a dwarf gets 1678's entry instead (no QuestDB title: quest ID).
known[71] = nil
race = 3
page()
check(line("Defensive Stance"):find("1678", 1, true), "dwarf quest by ID when the title is unknown: " .. line("Defensive Stance"))
race = 1

-- Warlock: tomes for demons you have, never discounted; known ones (pet spellbook) skipped.
class, level = "WARLOCK", 20
known = { [688] = true, [697] = true }
petKnown = { [7812] = true }   -- Sacrifice rank 1 known (voidwalker out)
fire("UNIT_PET", "player")
page()
need("Demon tomes", "tome section")
check(not has("Grimoire of Sacrifice (Rank 1)"), "known tome skipped")
need("Grimoire of Consume Shadows (Rank 1)", "unknown tome listed")
check(not has("Succubus") and not line("Demon tomes"):find("Succubus", 1, true), "no tomes for a demon you can't summon")
check(line("Demon tomes"):find("never discounted", 1, true), "tomes never discounted: " .. line("Demon tomes"))
-- A tome learned while the demon was out stays known after it's dismissed.
petKnown = {}
page()
check(not has("Grimoire of Sacrifice (Rank 1)"), "remembered as known")

if #failures > 0 then
    print("FAILURES (" .. #failures .. "):")
    for _, why in ipairs(failures) do print(" - " .. why) end
    os.exit(1)
end
print("test_r4b_trainer_extras: all checks passed")
