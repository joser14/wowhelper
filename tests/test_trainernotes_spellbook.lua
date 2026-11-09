-- TrainerNotes: spells already in the spellbook (learned elsewhere, or known all along) leave the
-- "to train" list without a trainer visit. Run:  node run.js "<workspace root>" test_trainernotes_spellbook.lua
local base = ADDON_PATH
local chat, frames = {}, {}
local SECRET = {}
CreateFrame = function()
    local f = { registered = {} }
    f.RegisterEvent = function(self, e) self.registered[e] = true end
    f.SetScript = function(self, _, fn) self.fn = fn end
    frames[#frames + 1] = f
    return f
end
ForeverHub_Receive = function(_, t) chat[#chat + 1] = t end
SlashCmdList = {}
issecretvalue = function(v) return v == SECRET end
UnitName = function() return "Tester" end
GetRealmName = function() return "Realm" end
UnitLevel = function() return 20 end
UnitClass = function() return "x", "MAGE" end
GetMoney = function() return 100000 end
Enum = { TrainerType = { General = 0 }, SpellBookSpellBank = { Player = 0 }, SpellBookItemType = { Spell = 1, FutureSpell = 2 } }
local timers = {}
C_Timer = { After = function(_, fn) timers[#timers + 1] = fn end }
local function flush() while #timers > 0 do table.remove(timers, 1)() end end

-- Saved notes from an earlier trainer visit.
TrainerNotesDB = { ["Tester-Realm"] = { services = {
    ["Frostbolt|Rank 3"] = { name = "Frostbolt", rank = "Rank 3", level = 14, cost = 100 },
    ["Frostbolt|Rank 4"] = { name = "Frostbolt", rank = "Rank 4", level = 20, cost = 200 },
    ["Arcane Missiles|Rank 2"] = { name = "Arcane Missiles", rank = "Rank 2", level = 16, cost = 150 },
    ["Slow Fall|"] = { name = "Slow Fall", rank = "", level = 12, cost = 50 },
    ["Blink|"] = { name = "Blink", rank = "", level = 20, cost = 300 },
    ["Fire Ward|Rank 1"] = { name = "Fire Ward", rank = "Rank 1", level = 20, cost = 120 },
    ["Dampen Magic|Rank 2"] = { name = "Dampen Magic", rank = "Rank 2", level = 18, cost = 90 },
} } }

-- Spellbook: name, subName, itemType, isOffSpec.
local book = {
    { "Frostbolt", "Rank 3", 1 },            -- rank 3 known, rank 4 not
    { "Slow Fall", "", 1 },                  -- unranked, known
    { "Blink", "", 2 },                      -- a future spell: not known yet
    { "Arcane Missiles", "", 1, false, 99 }, -- rank unreadable here; read from C_Spell below
    { "Dampen Magic", "", 1 },               -- rank unreadable anywhere: kept
}
local subtexts = { [99] = "Rank 2" }
C_SpellBook = {
    GetNumSpellBookSkillLines = function() return 1 end,
    GetSpellBookSkillLineInfo = function() return { name = "Arcane", itemIndexOffset = 0, numSpellBookItems = #book } end,
    GetSpellBookItemInfo = function(slot)
        local b = book[slot]
        if not b then return nil end
        return { name = b[1], subName = b[2], itemType = b[3], isOffSpec = b[4], spellID = b[5] }
    end,
}
C_Spell = { GetSpellSubtext = function(id) return subtexts[id] end }

local n = #frames
assert(loadfile(base .. "/TrainerNotes/TrainerNotes.lua"))("TrainerNotes", {})
local tr = frames[n + 1]
local function fire(ev, ...) assert(tr.registered[ev], "not registered: " .. ev); tr.fn(tr, ev, ...) end
local services = TrainerNotesDB["Tester-Realm"].services

fire("PLAYER_LOGIN")
assert(#timers == 1, "login checks the spellbook once, a moment later")
flush()
assert(not services["Frostbolt|Rank 3"], "known rank dropped")
assert(services["Frostbolt|Rank 4"], "higher rank kept")
assert(not services["Slow Fall|"], "known unranked spell dropped")
assert(services["Blink|"], "future spell isn't known")
assert(not services["Arcane Missiles|Rank 2"], "rank read through C_Spell")
assert(services["Fire Ward|Rank 1"], "not in the book at all: kept")
assert(services["Dampen Magic|Rank 2"], "unreadable rank: kept rather than guessed")

-- Learned elsewhere (a quest, a book): a burst of events is one check.
book[#book + 1] = { "Fire Ward", "Rank 1", 1 }
assert(tr.registered.SPELLS_CHANGED and tr.registered.LEARNED_SPELL_IN_SKILL_LINE, "spellbook events registered")
fire("LEARNED_SPELL_IN_SKILL_LINE"); fire("SPELLS_CHANGED"); fire("SPELLS_CHANGED")
assert(#timers == 1, "throttled to one check, got " .. #timers)
flush()
assert(not services["Fire Ward|Rank 1"], "learned elsewhere: dropped")

-- The page reads fresh too.
book[1][2] = "Rank 4"
chat = {}
SlashCmdList.TRAINERNOTES("")
local text = table.concat(chat, "\n")
assert(not text:find("Frostbolt", 1, true), "page drops Frostbolt once rank 4 is known: " .. text)
assert(text:find("Blink", 1, true), "page still lists Blink: " .. text)

-- Status row counts only what's left: Blink and Dampen Magic.
local row = ForeverHubStatus.TrainerNotes()
assert(row and row[1].text:find("Train|r 2 spell", 1, true), "status counts the rest: " .. tostring(row and row[1].text))

-- Secret or broken spellbook data never errors and drops nothing.
book[#book + 1] = { SECRET, SECRET, SECRET }
C_SpellBook.GetSpellBookSkillLineInfo = function() return { itemIndexOffset = SECRET, numSpellBookItems = SECRET } end
fire("SPELLS_CHANGED"); flush()
assert(services["Blink|"], "secret skill line drops nothing")
C_SpellBook.GetNumSpellBookSkillLines = function() error("boom") end
fire("SPELLS_CHANGED"); flush()
assert(services["Blink|"], "failing spellbook drops nothing")
C_SpellBook = nil
fire("SPELLS_CHANGED"); flush()
SlashCmdList.TRAINERNOTES("")
assert(services["Blink|"], "no spellbook API drops nothing")

-- Without C_Timer the check runs right away.
C_Timer = nil
C_SpellBook = {
    GetNumSpellBookSkillLines = function() return 1 end,
    GetSpellBookSkillLineInfo = function() return { itemIndexOffset = 0, numSpellBookItems = 1 } end,
    GetSpellBookItemInfo = function() return { name = "Blink", subName = "", itemType = 1 } end,
}
fire("SPELLS_CHANGED")
assert(not services["Blink|"], "no timer: checked at once")

print("ALL TESTS PASSED")
