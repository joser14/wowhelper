-- The logic review's fixes outside the quest tracker. ADDON_PATH is the folder holding every addon.
local base = ADDON_PATH
local toasts = {}
ForeverHub_Receive = function(_, t) toasts[#toasts + 1] = t end
issecretvalue = function() return false end
local eventFrame
CreateFrame = function()
    eventFrame = { RegisterEvent = function() end, SetScript = function(self, _, fn) self.fn = fn end }
    return eventFrame
end
SlashCmdList = {}
UnitName = function() return "T" end
GetRealmName = function() return "R" end
local level = 8
UnitLevel = function() return level end
local class = "MAGE"
UnitClass = function() return "x", class end
local function load(name)
    assert(loadfile(base .. "/" .. name .. "/" .. name .. ".lua"))(name, {})
    return eventFrame
end
local function fire(f, ...) f.fn(f, ...) end

----- TrainerNotes
TrainerNotesDB = { ["T-R"] = { services = {
    ["Spider Sausage|"] = { name = "Spider Sausage", level = 0, cost = 4000 },
    ["Frostbolt|Rank 1"] = { name = "Frostbolt", rank = "Rank 1", level = 4, cost = 100 },
    ["Fireball|Rank 2"] = { name = "Fireball", rank = "Rank 2", level = 6, cost = 100 },
    ["Polymorph|Rank 1"] = { name = "Polymorph", rank = "Rank 1", level = 8, cost = 200 },
    ["Blizzard|Rank 2"] = { name = "Blizzard", rank = "Rank 2", level = 28, cost = 5500 },
    ["Staves|"] = { name = "Staves", level = 8, cost = 1000 },
} } }
Enum = { TrainerType = { General = 0, Tradeskills = 2, Pet = 3 } }
local trainerType = 0
C_Trainer = { GetTrainerType = function() return trainerType end }
local filters = { available = true, unavailable = true, used = false }
GetTrainerServiceTypeFilter = function(f) return filters[f] end
local list = {}
GetNumTrainerServices = function() return #list end
GetTrainerServiceInfo = function(i) local s = list[i]; return s[1], s[2], nil, s[3], s[4] end
GetTrainerServiceCost = function(i) return list[i][5] or 100 end
local tn = load("TrainerNotes")
fire(tn, "PLAYER_LOGIN")
local services = TrainerNotesDB["T-R"].services
assert(not services["Spider Sausage|"], "old recipes purged at login")
assert(services["Frostbolt|Rank 1"], "spells kept")

-- A profession trainer records nothing.
trainerType = 2
list = { { "Fishing", "available", 0, "" } }
fire(tn, "TRAINER_SHOW")
assert(not services["Fishing|"], "recipes not recorded")
fire(tn, "TRAINER_CLOSED")

-- A weapon master barely overlaps, so class spells survive.
trainerType = 0
list = { { "Staves", "available", 8, "", 1000 }, { "Daggers", "available", 8, "", 1000 } }
fire(tn, "TRAINER_SHOW")
assert(services["Frostbolt|Rank 1"] and services["Polymorph|Rank 1"], "weapon master forgets nothing")
-- Buying there leaves its list.
list = { { "Daggers", "available", 8, "", 1000 } }
fire(tn, "TRAINER_UPDATE")
assert(not services["Staves|"], "bought from weapon master")
fire(tn, "TRAINER_CLOSED")

-- A class trainer: Frostbolt 1 and Fireball 2 were bought earlier, so they aren't listed.
list = { { "Polymorph", "available", 8, "Rank 1", 200 }, { "Blizzard", "unavailable", 28, "Rank 2", 5500 },
    { "Daggers", "available", 8, "", 1000 } }
fire(tn, "TRAINER_SHOW")
assert(not services["Frostbolt|Rank 1"] and not services["Fireball|Rank 2"], "bought earlier cleared")
assert(services["Blizzard|Rank 2"], "future spell kept")
local row = ForeverHubStatus.TrainerNotes()[1].text
assert(row:find("Train|r 2 spell", 1, true), "panel count: " .. row)
-- Buying one in the same window.
list = { { "Blizzard", "unavailable", 28, "Rank 2", 5500 }, { "Daggers", "available", 8, "", 1000 } }
fire(tn, "TRAINER_UPDATE")
assert(not services["Polymorph|Rank 1"], "purchase leaves the note")
-- A filtered list never forgets.
filters.unavailable = false
list = { { "Daggers", "available", 8, "", 1000 } }
fire(tn, "TRAINER_UPDATE")
assert(services["Blizzard|Rank 2"], "filter off forgets nothing")
filters.unavailable = true
-- An empty moment as the window opens forgets nothing.
list = {}
fire(tn, "TRAINER_SHOW")
assert(services["Blizzard|Rank 2"], "empty list forgets nothing")
fire(tn, "TRAINER_CLOSED")

----- BagCheck
toasts = {}
local slots, free = 0, 0
NUM_TOTAL_EQUIPPED_BAG_SLOTS = 0
C_Container = {
    GetContainerNumSlots = function() return slots end,
    GetContainerNumFreeSlots = function() return free, 0 end,
    GetContainerItemInfo = function() return nil end,
}
C_Item = {}
local saved = ForeverHubStatus.ItemAdvisor
local bc = load("BagCheck")
fire(bc, "PLAYER_ENTERING_WORLD")
assert(#toasts == 0, "unread bags aren't full")
assert(not ForeverHubStatus.BagCheck(), "no panel row while unread")
slots = 16
fire(bc, "BAG_UPDATE_DELAYED")
assert(toasts[1] and toasts[1]:find("nearly full", 1, true), "full bags still warn")
-- Vendor: ItemAdvisor speaks for junk when it's there.
C_Container.GetContainerItemInfo = function() return { quality = 0, stackCount = 2, itemID = 5 } end
C_Item.GetItemInfo = function() return "n", nil, nil, nil, nil, nil, nil, nil, nil, nil, 10 end
toasts = {}
ForeverHubStatus.ItemAdvisor = function() end
fire(bc, "MERCHANT_SHOW")
assert(#toasts == 0, "no second vendor pop-up")
ForeverHubStatus.ItemAdvisor = nil
fire(bc, "MERCHANT_SHOW")
assert(toasts[1] and toasts[1]:find("junk", 1, true), "alone it still reports junk")
ForeverHubStatus.ItemAdvisor = saved

----- ItemFinder
Enum.BagIndex = { Backpack = 0, Characterbanktab = -2, CharacterBankTab_1 = 6, Accountbanktab = -3, AccountBankTab_1 = 15 }
local banks = {}
C_Container.GetContainerNumSlots = function(bag) if bag == 0 then return 1 end return banks[bag] and 1 or 0 end
C_Container.GetContainerItemInfo = function(bag)
    if bag == 0 then return { hyperlink = "|h[Apple]|h", stackCount = 1 } end
    local name = banks[bag]
    return name and { hyperlink = "|h[" .. name .. "]|h", stackCount = 1 }
end
GetInventoryItemLink = function() end
local fi = load("ItemFinder")
fire(fi, "PLAYER_LOGIN")
local me = ItemFinderDB["T-R"]
banks[6] = "Old Sword"
fire(fi, "BAG_UPDATE_DELAYED")
assert(me.bank == nil, "bank unread while closed")
fire(fi, "BANKFRAME_OPENED")
assert(me.bank["Old Sword"], "character bank tab found by its real name")
-- Depositing during the visit counts.
banks[6] = "New Ring"
fire(fi, "BAG_UPDATE_DELAYED")
assert(me.bank["New Ring"] and not me.bank["Old Sword"], "deposit while open is saved")
fire(fi, "BANKFRAME_CLOSED")
banks[6] = nil
fire(fi, "BAG_UPDATE_DELAYED")
assert(me.bank["New Ring"], "closing keeps the record")
banks[15] = "Account Thing"
fire(fi, "BANKFRAME_OPENED")
assert(me.bank["New Ring"], "an unread bank doesn't wipe the record")
fire(fi, "BANKFRAME_CLOSED")

----- WeaponSkillWatch
toasts = {}
local inHand = { [16] = "staff", [18] = "wand" }
GetInventoryItemLink = function(_, slot) return inHand[slot] end
C_Item.GetItemInfoInstant = function(link)
    return 1, "", "", "", 0, 2, link == "staff" and 10 or 19
end
C_SkillInfo = { GetSkillLineInfoByID = function(line)
    if line == 136 then return { name = "Staves", rank = 1, maxRank = 40 } end
    if line == 228 then return { name = "Wands", rank = 30, maxRank = 40 } end
end }
local ws = load("WeaponSkillWatch")
fire(ws, "PLAYER_LOGIN")
assert(#toasts == 0, "a mage isn't nagged about staff skill: " .. tostring(toasts[1]))
assert(#ForeverHubStatus.WeaponSkillWatch() == 0, "no panel row")
class = "WARRIOR"
fire(ws, "SKILL_LINES_CHANGED")
assert(toasts[1] and toasts[1]:find("Staves", 1, true), "a warrior is")
class = "MAGE"
inHand[18] = "wand"
C_SkillInfo.GetSkillLineInfoByID = function(line)
    if line == 228 then return { name = "Wands", rank = 1, maxRank = 40 } end
end
assert(ForeverHubStatus.WeaponSkillWatch()[1].text:find("Wands", 1, true), "a mage's wand still counts")

----- GoldGoal
local money = 1200000
GetMoney = function() return money end
GetTime = function() return 100 end
local gg = load("GoldGoal")
fire(gg, "PLAYER_LOGIN")
level = 8
assert(ForeverHubStatus.GoldGoal()[1].text:find("Saving", 1, true), "too low a level keeps saving")
level = 40
assert(ForeverHubStatus.GoldGoal()[1].text:find("Buy|r riding", 1, true), "ready says buy")

----- ErrorLog
local handler
geterrorhandler = function() return function() end end
seterrorhandler = function(fn) handler = fn end
debugstack = function() return "" end
date = function() return "now" end
DEFAULT_CHAT_FRAME = {}
local el = load("!ErrorLog")
fire(el, "ADDON_LOADED", "!ErrorLog")
for i = 1, 51 do handler("problem " .. i) end
assert(#ErrorLogDB.entries == 50, "cap holds")
assert(ErrorLogDB.entries[50].message == "problem 51", "newest kept")
assert(ErrorLogDB.entries[1].message == "problem 2", "oldest dropped")

----- ForeverHelper: logging out must not overwrite good saved values.
ForeverHelperDB = { characters = { ["T-R"] = { tasks = {}, level = 7, money = 500 } }, shown = false }
UIParent = {}
UISpecialFrames = {}
local function stub()
    return setmetatable({}, { __index = function(_, k)
        if k == "IsShown" then return function() return false end end
        return function() return stub() end
    end })
end
CreateFrame = function()
    local f = stub()
    rawset(f, "RegisterEvent", function() end)
    rawset(f, "SetScript", function(self, _, fn) self.fn = fn end)
    if not eventFrame or eventFrame.helperDone then end
    return f
end
UnitXP = function() return 1 end
UnitXPMax = function() return 100 end
GetXPExhaustion = function() return 0 end
C_Timer = { NewTicker = function() end }
local chunk = assert(loadfile(base .. "/ForeverHelper/ForeverHelper.lua"))
local frames = {}
local make = CreateFrame
CreateFrame = function(...) local f = make(...); frames[#frames + 1] = f; return f end
chunk("ForeverHelper", {})
local fh = frames[1]
fh.fn(fh, "ADDON_LOADED", "ForeverHelper")
fh.fn(fh, "PLAYER_LOGIN")
level, money = 7, 500
fh.fn(fh, "PLAYER_MONEY")
level, money = 4, 0
fh.fn(fh, "PLAYER_LOGOUT")
assert(ForeverHelperDB.characters["T-R"].level == 7 and ForeverHelperDB.characters["T-R"].money == 500, "logout keeps real values")
print("ALL TESTS PASSED")
