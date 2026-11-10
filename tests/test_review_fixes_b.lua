-- Review fixes B: TrainerNotes per-trainer memory, purchases with filters off, truthy requirements;
-- WeaponSkillWatch dual-wield; ProfessionCap Expert books; SupplyWatch ammo type.
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
UnitName = function() return "T" end
GetRealmName = function() return "R" end
local level, class = 20, "WARRIOR"
UnitLevel = function() return level end
UnitClass = function() return "x", class end
GetMoney = function() return 10000000 end
local function load(name)
    local n = #frames
    assert(loadfile(base .. "/" .. name .. "/" .. name .. ".lua"))(name, {})
    return frames[n + 1]
end
local function fire(f, ev, ...) assert(f.registered[ev], "not registered: " .. ev); f.fn(f, ev, ...) end
local function saw(text) for _, t in ipairs(chat) do if t:find(text, 1, true) then return true end end return false end
local function need(text, why) assert(saw(text), why .. ": wanted '" .. text .. "' in:\n" .. table.concat(chat, "\n")) end
local function never(text, why) assert(not saw(text), why .. ": did not want '" .. text .. "' in:\n" .. table.concat(chat, "\n")) end
local function count(t) local n = 0 for _ in pairs(t) do n = n + 1 end return n end

----- TrainerNotes
Enum = { TrainerType = { General = 0, Tradeskills = 2, Pet = 3 } }
C_Trainer = { GetTrainerType = function() return 0 end }
local filters = { available = true, unavailable = true, used = false }
GetTrainerServiceTypeFilter = function(f) return filters[f] end
local list, abilityReq, skillReq = {}, {}, {}
GetNumTrainerServices = function() return #list end
GetTrainerServiceInfo = function(i) local s = list[i]; return s[1], s[2], nil, s[3], s[4] end
GetTrainerServiceCost = function(i) return list[i][5] or 100 end
GetTrainerServiceNumAbilityReq = function(i) return abilityReq[i] and 1 or 0 end
GetTrainerServiceAbilityReq = function(i) return abilityReq[i][1], abilityReq[i][2] end
GetTrainerServiceSkillReq = function(i) if skillReq[i] then return skillReq[i][1], 5, skillReq[i][2] end end
local npc
UnitGUID = function(unit) if unit == "npc" then return npc end end
local CLASS_TRAINER, WEAPON_MASTER = "Creature-0-1465-0-2105-3043-000043F59F", "Creature-0-1465-0-2105-2704-000043F5A0"

-- An older save: no trainer recorded on anything.
TrainerNotesDB = { ["T-R"] = { services = {
    ["Rend|Rank 3"] = { name = "Rend", rank = "Rank 3", level = 20, cost = 100 },
    ["Old Bought|Rank 1"] = { name = "Old Bought", rank = "Rank 1", level = 10, cost = 100 },
    ["Hamstring|Rank 2"] = { name = "Hamstring", rank = "Rank 2", level = 22, cost = 100 },
} } }
local tr = load("TrainerNotes")
fire(tr, "PLAYER_LOGIN")
local services = TrainerNotesDB["T-R"].services
assert(count(services) == 3, "older entries kept at login")

-- Weapon master first: none of the older class entries overlap, so none are forgotten.
npc = WEAPON_MASTER
local weapons = { { "Swords", "available", 20, "" }, { "Axes", "available", 20, "" }, { "Maces", "available", 20, "" },
    { "Staves", "available", 20, "" }, { "Daggers", "available", 20, "" } }
list = weapons
fire(tr, "TRAINER_SHOW")
assert(services["Swords|"].trainer == 2704, "tagged with the creature ID")
assert(services["Rend|Rank 3"] and services["Old Bought|Rank 1"], "weapon master leaves older entries")
fire(tr, "TRAINER_CLOSED")

-- Class trainer: lists Rend; older bought entries go (the overlap rule for untagged entries),
-- the weapon master's five skills stay.
npc = CLASS_TRAINER
list = { { "Rend", "available", 20, "Rank 3" }, { "Hamstring", "unavailable", 22, "Rank 2" } }
fire(tr, "TRAINER_SHOW")
assert(not services["Old Bought|Rank 1"], "older bought entry migrates out")
for _, w in ipairs(weapons) do assert(services[w[1] .. "|"], "weapon skill survives class trainer: " .. w[1]) end
assert(services["Rend|Rank 3"].trainer == 3043, "older entry adopted by its trainer")
fire(tr, "TRAINER_CLOSED")

-- A low-level character's few class spells survive a weapon master with many skills.
TrainerNotesDB = nil
level = 4
fire(tr, "PLAYER_LOGIN")
services = TrainerNotesDB["T-R"].services
npc = CLASS_TRAINER
list = { { "Rend", "available", 4, "Rank 1" }, { "Thunder Clap", "unavailable", 6, "Rank 1" }, { "Hamstring", "unavailable", 8, "Rank 1" } }
fire(tr, "TRAINER_SHOW"); fire(tr, "TRAINER_CLOSED")
npc = WEAPON_MASTER
list = weapons
fire(tr, "TRAINER_SHOW"); fire(tr, "TRAINER_CLOSED")
assert(services["Rend|Rank 1"] and services["Thunder Clap|Rank 1"] and services["Hamstring|Rank 1"], "class spells survive weapon master")
-- Back at the class trainer, Rend was bought elsewhere in between: only that trainer forgets it.
npc = CLASS_TRAINER
list = { { "Thunder Clap", "unavailable", 6, "Rank 1" }, { "Hamstring", "unavailable", 8, "Rank 1" } }
fire(tr, "TRAINER_SHOW")
assert(not services["Rend|Rank 1"], "this trainer's missing entry forgotten")
assert(services["Swords|"], "weapon master's entries untouched")
fire(tr, "TRAINER_CLOSED")

-- Fix 2: unavailable filter off, then buy a spell: it leaves the list straight away.
level = 8
filters.unavailable = false
list = { { "Battle Shout", "available", 8, "Rank 1" }, { "Charge", "available", 8, "Rank 1" } }
fire(tr, "TRAINER_SHOW")
local function readyCount() return tonumber(ForeverHubStatus.TrainerNotes()[1].text:match("Train|r (%d+) spell")) end
local before = readyCount()
list = { { "Charge", "available", 8, "Rank 1" } }
fire(tr, "TRAINER_UPDATE")
assert(not services["Battle Shout|Rank 1"], "bought with a filter off still clears")
assert(readyCount() == before - 1, "count drops")
assert(services["Thunder Clap|Rank 1"], "hidden by the filter isn't bought")
-- Turning the available filter off mid-window hides spells without buying them.
filters.available = false
list = {}
GetNumTrainerServices = function() return 1 end
list = { { "Header", "header", 0, "" } }
fire(tr, "TRAINER_UPDATE")
assert(services["Charge|Rank 1"], "filtered out isn't bought")
GetNumTrainerServices = function() return #list end
filters.available, filters.unavailable = true, true
fire(tr, "TRAINER_CLOSED")

-- Fix 3: requirement values are tested for truthiness; secret says nothing.
list = { { "A", "available", 8, "" }, { "B", "available", 8, "" }, { "C", "available", 8, "" },
    { "D", "unavailable", 6, "" }, { "E", "unavailable", 6, "" }, { "Thunder Clap", "unavailable", 6, "Rank 1" },
    { "Hamstring", "unavailable", 8, "Rank 1" }, { "Charge", "available", 8, "Rank 1" } }
abilityReq = { [1] = { "Talent A", nil }, [2] = { "Talent B", 1 }, [3] = { "Talent C", SECRET } }
skillReq = { [4] = { "Defense", nil }, [5] = { "Defense", 1 } }
fire(tr, "TRAINER_SHOW")
assert(services["A|"].needs == "Talent A", "nil means missing")
assert(not services["B|"].needs, "1 means met")
assert(not services["C|"].needs, "secret isn't counted as missing")
assert(services["D|"].needs == "Defense 5", "nil skill req missing")
assert(services["E|"].needs == "something else first", "met skill req falls through")
abilityReq, skillReq = {}, {}
fire(tr, "TRAINER_CLOSED")

-- No readable GUID: secret GUID behaves like none.
npc = SECRET
list = { { "Charge", "available", 8, "Rank 1" } }
fire(tr, "TRAINER_SHOW")
assert(services["Charge|Rank 1"].trainer == nil, "secret GUID not stored")
assert(services["Swords|"], "unknown trainer forgets no tagged entries")
fire(tr, "TRAINER_CLOSED")

----- WeaponSkillWatch
reset()
class = "ROGUE"
local inHand = { [16] = "sword", [17] = "sword" }
GetInventoryItemLink = function(_, slot) return inHand[slot] end
C_Item = { GetItemInfoInstant = function(link)
    if link == "gun" then return 1, "", "", "", 0, 2, 3 end
    if link == "bow" then return 1, "", "", "", 0, 2, 2 end
    if link == "xbow" then return 1, "", "", "", 0, 2, 18 end
    return 1, "", "", "", 0, 2, 7
end }
C_SkillInfo = { GetSkillLineInfoByID = function(line)
    if line == 43 then return { name = "Swords", rank = 10, maxRank = 100 } end
end }
local ws = load("WeaponSkillWatch")
fire(ws, "PLAYER_LOGIN")
local n = 0
for _, t in ipairs(chat) do if t:find("Swords is only", 1, true) then n = n + 1 end end
assert(n == 1, "dual-wielded swords warn once, got " .. n)
reset(); fire(ws, "PLAYER_EQUIPMENT_CHANGED", 17)
assert(#chat == 0, "no repeat")

----- ProfessionCap
reset()
local slots, profs = {}, {}
GetProfessions = function() return slots[1], slots[2], slots[3], slots[4], slots[5] end
GetProfessionInfo = function(i) local p = profs[i]; return p[1], 0, p[2], p[3], 0, 0, p[4] end
local firstAid
C_SkillInfo = { GetSkillLineInfoByID = function(id) if id == 129 then return firstAid end end }
local pc = load("ProfessionCap")
slots = { 1, nil, nil, 4, 5 }
-- Cooking by skill line under another name; Fishing by English name only.
profs = { [1] = { "Mining", 150, 150, 186 }, [4] = { "Pesca", 150, 150, 356 }, [5] = { "Cooking", 150, 150, 0 } }
firstAid = { name = "First Aid", rank = 150, maxRank = 150 }
level = 25
fire(pc, "PLAYER_LOGIN")
need("Mining is capped at 150/150. Visit a trainer for Expert.", "mining still trainer")
need("Pesca is capped at 150/150. Expert comes from a book: Expert Fishing - The Bass and You", "fishing book by skill line")
need("Cooking is capped at 150/150. Expert comes from a book: the Expert Cookbook", "cooking book by name")
need("First Aid is capped at 150/150. Expert comes from a book: Expert First Aid - Under Wraps", "first aid book")
for _, t in ipairs(chat) do
    if t:find("Cooking", 1, true) or t:find("First Aid", 1, true) or t:find("Pesca", 1, true) then
        assert(not t:find("Visit a trainer", 1, true), "book professions don't send to a trainer: " .. t)
    end
end
local rows = ForeverHubStatus.ProfessionCap()
local text = {}
for _, r in ipairs(rows) do text[#text + 1] = r.text end
text = table.concat(text, "\n")
assert(text:find("Train|r Expert Mining", 1, true), "mining row: " .. text)
assert(text:find("Buy|r the Expert Cooking book", 1, true), "cooking row: " .. text)
-- Artisan for a secondary is still the quest.
profs[5] = { "Cooking", 225, 225, 185 }
reset(); fire(pc, "SKILL_LINES_CHANGED")
need("Cooking is capped at 225/225. Artisan comes from a quest", "artisan unchanged")
-- Under the cap but ready: the book is mentioned.
profs[5] = { "Cooking", 130, 150, 185 }
reset(); SlashCmdList.PROFESSIONCAP("")
need("Cooking 130/150. Expert can be learned now from its book.", "early book")

----- SupplyWatch
-- Ammo is for hunters only (round 3, rank 8).
class = "HUNTER"
reset()
C_Container = { GetContainerNumSlots = function() return 16 end }
C_Item.GetItemCount = function() return 0 end
-- 2512 arrows (projectile subclass 2), 2516 bullets (3).
local ranged = "gun"
GetInventoryItemLink = function(_, slot)
    if slot == 0 then return "ammo" end
    if slot == 18 then return ranged end
end
C_Item.GetItemInfoInstant = function(id)
    if id == 2512 then return id, "", "", "", 0, 6, 2 end
    if id == 2516 then return id, "", "", "", 0, 6, 3 end
    if id == "gun" then return 1, "", "", "", 0, 2, 3 end
    if id == "bow" then return 1, "", "", "", 0, 2, 2 end
    if id == "xbow" then return 1, "", "", "", 0, 2, 18 end
    return 1, "", "", "", 0, 0, 0
end
UnitUsesAmmo = function() return true end
GetInventoryItemCount = function() return 10 end
SupplyWatchDB = nil
local sw = load("SupplyWatch")
fire(sw, "PLAYER_LOGIN")
local merchant = { 2512 }
GetMerchantNumItems = function() return #merchant end
GetMerchantItemID = function(i) return merchant[i] end
reset(); fire(sw, "MERCHANT_SHOW")
never("Restock Ammo here", "gun user at an arrow-only vendor")
merchant = { 2512, 2516 }
reset(); fire(sw, "MERCHANT_SHOW")
need("Restock Ammo here", "bullets sold")
ranged = "bow"; merchant = { 2516 }
reset(); fire(sw, "MERCHANT_SHOW")
never("Restock Ammo here", "bow user at a bullet-only vendor")
ranged = "xbow"; merchant = { 2512 }
reset(); fire(sw, "MERCHANT_SHOW")
need("Restock Ammo here", "crossbows take arrows")
ranged = SECRET; merchant = { 2516 }
reset(); fire(sw, "MERCHANT_SHOW")
need("Restock Ammo here", "unreadable weapon: any ammo counts")

print("ALL TESTS PASSED")
