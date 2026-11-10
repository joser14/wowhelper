-- TrainerNotes, TalentNudge, ProfessionCap, WeaponSkillWatch: the later fixes.
local base = ADDON_PATH
local chat, frames = {}, {}
local SECRET = {}
local function reset() chat = {} end
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
local level, class = 9, "MAGE"
UnitLevel = function() return level end
UnitClass = function() return "x", class end
GetMoney = function() return 100000 end
local function load(name)
    local n = #frames
    assert(loadfile(base .. "/" .. name .. "/" .. name .. ".lua"))(name, {})
    return frames[n + 1]
end
local function fire(f, ev, ...) assert(f.registered[ev], "not registered: " .. ev); f.fn(f, ev, ...) end
local function saw(text) for _, t in ipairs(chat) do if t:find(text, 1, true) then return true end end return false end
local function need(text, why) assert(saw(text), why .. ": wanted '" .. text .. "' in:\n" .. table.concat(chat, "\n")) end
local function never(text, why) assert(not saw(text), why .. ": did not want '" .. text .. "' in:\n" .. table.concat(chat, "\n")) end

----- TrainerNotes
Enum = { TrainerType = { General = 0, Tradeskills = 2, Pet = 3 } }
C_Trainer = { GetTrainerType = function() return 0 end }
GetTrainerServiceTypeFilter = function(f) return f ~= "used" end
local list, abilityReq, skillReq = {}, {}, {}
GetNumTrainerServices = function() return #list end
GetTrainerServiceInfo = function(i) local s = list[i]; return s[1], s[2], nil, s[3], s[4] end
GetTrainerServiceCost = function(i) return list[i][5] or 100 end
GetTrainerServiceNumAbilityReq = function(i) return abilityReq[i] and 1 or 0 end
GetTrainerServiceAbilityReq = function(i) return abilityReq[i], false end
GetTrainerServiceSkillReq = function(i) if skillReq[i] then return skillReq[i], 5, false end end
local tr = load("TrainerNotes")
fire(tr, "PLAYER_LOGIN")
local services = TrainerNotesDB["Tester-Realm"].services
list = {
    { "Frostbolt", "available", 8, "Rank 2", 200 },
    { "Arcane Missiles", "available", 8, "Rank 1", 300 },
    { "Pyroblast", "available", 8, "Rank 2", 900 },     -- talent rank, talent not taken
    { "Odd Thing", "unavailable", 6, "", 50 },           -- greyed at a level already reached
    { "Blizzard", "unavailable", 12, "Rank 1", 1000 },
}
abilityReq[3] = "Pyroblast"
fire(tr, "TRAINER_SHOW")
assert(services["Pyroblast|Rank 2"].needs == "Pyroblast", "talent requirement saved")
assert(services["Odd Thing|"].needs, "greyed at level is blocked")
assert(not services["Blizzard|Rank 1"].needs, "a level gate alone isn't a block")
assert(ForeverHubStatus.TrainerNotes()[1].text:find("Train|r 2 spell", 1, true), "blocked spells not counted")
reset(); SlashCmdList.TRAINERNOTES("")
need("Ready to train, 0g 5s 0c in total", "ready total skips blocked")
need("Not counted until", "blocked section")
need("Pyroblast (Rank 2), 0g 9s 0c, needs Pyroblast", "blocked line says why")
-- A name still loading must not make the rest look bought.
list = { { "Frostbolt", "available", 8, "Rank 2", 200 }, { nil, "available", 8, "Rank 1", 300 },
    { "Blizzard", "unavailable", 12, "Rank 1", 1000 } }
abilityReq = {}
fire(tr, "TRAINER_UPDATE")
assert(services["Arcane Missiles|Rank 1"], "pending name forgets nothing")
list[2][1] = "Arcane Missiles"
fire(tr, "TRAINER_SERVICE_INFO_NAME_UPDATE")
assert(not services["Pyroblast|Rank 2"], "once names load, missing entries go")
-- Skill requirement text.
list = { { "Frostbolt", "available", 8, "Rank 2", 200 }, { "Arcane Missiles", "unavailable", 8, "Rank 1", 300 },
    { "Blizzard", "unavailable", 12, "Rank 1", 1000 } }
skillReq[2] = "Arcane"
fire(tr, "TRAINER_UPDATE")
assert(services["Arcane Missiles|Rank 1"].needs == "Arcane 5", "skill requirement: " .. tostring(services["Arcane Missiles|Rank 1"].needs))
skillReq = {}
fire(tr, "TRAINER_CLOSED")
-- Name updates after closing read nothing.
list = {}
fire(tr, "TRAINER_SERVICE_INFO_NAME_UPDATE")
assert(services["Frostbolt|Rank 2"], "closed trainer untouched")
-- Level 0 from a spell trainer is stored as level 1, so login doesn't purge it.
list = { { "Zero", "available", 0, "", 10 }, { "Frostbolt", "available", 8, "Rank 2", 200 },
    { "Arcane Missiles", "unavailable", 8, "Rank 1", 300 }, { "Blizzard", "unavailable", 12, "Rank 1", 1000 } }
fire(tr, "TRAINER_SHOW")
assert(services["Zero|"].level == 1, "level 0 normalised")
fire(tr, "TRAINER_CLOSED")

----- TalentNudge
reset()
local staged = {}
C_ClassTalents = { GetActiveConfigID = function() return 9 end }
C_Traits = {
    GetConfigInfo = function() return { treeIDs = { 1 } } end,
    GetTreeCurrencyInfo = function(_, _, excludeStaged)
        staged[#staged + 1] = excludeStaged
        return { { traitCurrencyID = 1, quantity = excludeStaged and 1 or 0 } }
    end,
}
local tn = load("TalentNudge")
fire(tn, "TRAIT_TREE_CURRENCY_INFO_UPDATED", 1)
need("You have 1 unspent", "applied state counts, staged points don't hide it")
assert(staged[1] == true, "staged changes excluded")
assert(tn.registered.TRAIT_CONFIG_LIST_UPDATED, "late config load watched")
-- Three trees sharing one currency: counted once. A malformed entry is skipped, never an error.
C_Traits.GetConfigInfo = function() return { treeIDs = { 1, 2, 3 } } end
C_Traits.GetTreeCurrencyInfo = function() return { "junk", { traitCurrencyID = 1, quantity = 4 } } end
local rows = ForeverHubStatus.TalentNudge()
assert(rows and rows[1].text:find("Spend|r 4 talent", 1, true), "shared currency counted once, junk skipped")

----- ProfessionCap
reset()
local slots, profs = {}, {}
GetProfessions = function() return slots[1], slots[2], slots[3], slots[4], slots[5] end
GetProfessionInfo = function(i) local p = profs[i]; return p[1], 0, p[2], p[3] end
local firstAid
C_SkillInfo = { GetSkillLineInfoByID = function(id) if id == 129 then return firstAid end end }
local pc = load("ProfessionCap")
slots = { 1, 2, nil, nil, 5 }
profs = { [1] = { "Herbalism", 60, 75 }, [2] = { "Alchemy", 75, 75 }, [5] = { "Cooking", 225, 225 } }
firstAid = { name = "First Aid", rank = 40, maxRank = 75 }
level = 9
fire(pc, "PLAYER_LOGIN")
need("Alchemy is capped at 75/75. Visit a trainer for Journeyman. You may need level 10 first.", "capped, too low")
need("Cooking is capped at 225/225. Artisan comes from a quest", "secondary artisan")
assert(ForeverHubStatus.ProfessionCap()[1].text:find("Alchemy capped|r, Journeyman at level 10", 1, true), "row says when")
reset(); fire(pc, "PLAYER_LEVEL_UP", 10)
need("Alchemy is capped at 75/75. Visit a trainer for Journeyman.", "reaching the level says so again")
never("may need level", "level now fine")
never("Cooking", "unchanged cap isn't repeated")
level = 10
assert(ForeverHubStatus.ProfessionCap()[1].text:find("Train|r Journeyman Alchemy", 1, true), "row says train")
reset(); SlashCmdList.PROFESSIONCAP("")
need("Herbalism 60/75. Journeyman can be learned now.", "early training noted")
need("First Aid 40/75", "first aid listed")
firstAid = { name = "First Aid", rank = SECRET, maxRank = 75 }
reset(); SlashCmdList.PROFESSIONCAP("")
never("First Aid", "secret first aid skipped")

----- WeaponSkillWatch
reset()
class = "WARRIOR"
local inHand = { [16] = "sword", [17] = "sword", [18] = "bow" }
GetInventoryItemLink = function(_, slot) return inHand[slot] end
C_Item = { GetItemInfoInstant = function(link)
    if link == "secret" then return 1, "", "", "", 0, SECRET, SECRET end
    return 1, "", "", "", 0, 2, link == "sword" and 7 or 2
end }
C_SkillInfo = { GetSkillLineInfoByID = function(line)
    if line == 43 then return { name = "Swords", rank = 10, maxRank = 45 } end
    if line == 45 then return { name = "Bows", rank = 10, maxRank = 45 } end
end }
local ws = load("WeaponSkillWatch")
fire(ws, "PLAYER_LOGIN")
need("Swords is only 10/45", "melee warned")
need("Expect more misses and glancing blows", "melee text")
need("Bows is only 10/45 (ranged). Expect more misses until", "ranged has no glancing")
local rows = ForeverHubStatus.WeaponSkillWatch()
assert(#rows == 2, "two swords, one row: " .. #rows)
inHand[16], inHand[17], inHand[18] = "secret", nil, nil
reset(); fire(ws, "PLAYER_EQUIPMENT_CHANGED", 16)
assert(#chat == 0, "secret item info ignored")
fire(ws, "PLAYER_EQUIPMENT_CHANGED", SECRET)
assert(#ForeverHubStatus.WeaponSkillWatch() == 0, "no rows")

print("ALL TESTS PASSED")
