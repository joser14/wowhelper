-- Character keys on Forever: first name + surname, keyed by the player GUID, one-time migration of the
-- old "Name-Realm" keys, never merging two characters, GUID fallback, and names shown from the record.
-- Run from the harness folder:  node run.js "<workspace root>" test_charkeys.lua
local base = ADDON_PATH
local SECRET = {}
local out, frames, failures = {}, {}, {}
issecretvalue = function(v) return v == SECRET end
ForeverHub_Receive = function(_, t) out[#out + 1] = t end

-- A frame answers any method; scripts and events are kept so the test can fire them.
local function newFrame()
    local f = { registered = {}, scripts = {}, shown = true }
    return setmetatable(f, { __index = function(_, k)
        if k == "RegisterEvent" then return function(self, e) self.registered[e] = true end end
        if k == "SetScript" then return function(self, s, fn) self.scripts[s] = fn end end
        if k == "Show" then return function(self) self.shown = true end end
        if k == "Hide" then return function(self) self.shown = false end end
        if k == "IsShown" then return function(self) return self.shown end end
        if k == "SetShown" then return function(self, v) self.shown = v and true or false end end
        if k == "CreateFontString" or k == "CreateTexture" then return function() return newFrame() end end
        return function() end
    end })
end
CreateFrame = function() local f = newFrame(); frames[#frames + 1] = f; return f end
UIParent = newFrame()
UISpecialFrames = {}
tinsert = table.insert
SlashCmdList = {}
C_Timer = { After = function() end, NewTicker = function() end }
GetTime = function() return 1000 end
time = function() return 1000000 end
GetMoney = function() return 12345 end
UnitLevel = function() return 10 end
UnitXP = function() return 0 end
UnitXPMax = function() return 100 end
GetXPExhaustion = function() return 0 end
NUM_TOTAL_EQUIPPED_BAG_SLOTS = 0
Enum = { BagIndex = {}, TooltipDataType = { Item = 0, Unit = 2 } }
C_Container = { GetContainerNumSlots = function() return 0 end, GetContainerItemInfo = function() end }
GetInventoryItemLink = function() end

-- Who is logged in. surname = UnitName's second return on Forever.
local me = { first = "Joe", surname = "Smith", guid = "Player-4321-0000AAAA", realm = "R" }
UnitName = function(unit) if unit == "player" then return me.first, me.surname end end
UnitGUID = function(unit) if unit == "player" then return me.guid end end
GetRealmName = function() return me.realm end

local function check(cond, why) if not cond then failures[#failures + 1] = why end end
local function load(folder)
    local n = #frames
    assert(loadfile(base .. "/" .. folder .. "/" .. folder .. ".lua"))(folder, {})
    return frames[n + 1]
end
local function fire(f, ev, ...) f.scripts.OnEvent(f, ev, ...) end
local function has(text) for _, t in ipairs(out) do if tostring(t):find(text, 1, true) then return true end end return false end

----- 1. The key itself
load("ItemFinder")
check(type(ForeverCharacterKey) == "function", "shared key function defined")
check(ForeverCharacterKey() == "Player-4321-0000AAAA", "GUID is the key: " .. tostring(ForeverCharacterKey()))
check(ForeverCharacterName() == "Joe Smith", "display name is first name + surname")
check(ForeverCharacterLegacyKey() == "Joe-R", "old key is first name + realm")
me.guid = SECRET
check(ForeverCharacterKey() == "Joe Smith-R", "secret GUID falls back to full name + realm: " .. tostring(ForeverCharacterKey()))
me.guid = nil
check(ForeverCharacterKey() == "Joe Smith-R", "missing GUID falls back to full name + realm")
me.guid = "Creature-0-1-2-3-4-5"
check(ForeverCharacterKey() == "Joe Smith-R", "a non-player GUID is not used")
me.surname = nil
check(ForeverCharacterKey() == "Joe-R" and ForeverCharacterName() == "Joe", "no surname (stock client): same as the old key")
me.surname = "Smith"
local savedUnitGUID = UnitGUID
UnitGUID = function() error("boom") end
check(ForeverCharacterKey() == "Joe Smith-R", "a throwing UnitGUID falls back")
UnitGUID = savedUnitGUID
me.guid = "Player-4321-0000AAAA"

----- 2. ItemFinder: the old record moves to the GUID key once, with a note and the name
ItemFinderDB = { ["Joe-R"] = { bank = { ["Linen Cloth"] = 4 } }, ["Ann-R"] = { bags = { ["Linen Cloth"] = 1 }, lastSeen = 999999 } }
local finder = load("ItemFinder")
fire(finder, "PLAYER_LOGIN")
local rec = ItemFinderDB["Player-4321-0000AAAA"]
check(rec and rec.bank and rec.bank["Linen Cloth"] == 4, "Joe Smith's old bank moved to the GUID key")
check(ItemFinderDB["Joe-R"] == nil, "old key removed after the move")
check(rec and rec.migratedFrom == "Joe-R", "migratedFrom noted")
check(rec and rec.charName == "Joe Smith" and rec.charGUID == "Player-4321-0000AAAA", "name and GUID stamped")
check(ItemFinderDB["Ann-R"] and ItemFinderDB["Ann-R"].bags["Linen Cloth"] == 1, "other characters untouched")

----- 3. A second character with the same first name starts fresh: nothing merged, nothing taken
me.guid, me.surname = "Player-4321-0000BBBB", "Brown"
local finder2 = load("ItemFinder")
fire(finder2, "PLAYER_LOGIN")
local brown = ItemFinderDB["Player-4321-0000BBBB"]
check(brown and brown.charName == "Joe Brown" and brown.migratedFrom == nil, "Joe Brown gets his own record")
check(ItemFinderDB["Player-4321-0000AAAA"].bank["Linen Cloth"] == 4, "Joe Smith's record untouched")

----- 4. Both old and new keys exist: keep both, leave the old one in place
me.guid, me.surname = "Player-4321-0000AAAA", "Smith"
GoldGoalDB = { ["Joe-R"] = { goal = { name = "Old", gold = 500 } }, ["Player-4321-0000AAAA"] = { goal = { name = "New", gold = 100 } } }
local goal = load("GoldGoal")
fire(goal, "PLAYER_LOGIN")
check(GoldGoalDB["Player-4321-0000AAAA"].goal.name == "New", "the new record is kept as it is")
check(GoldGoalDB["Joe-R"] and GoldGoalDB["Joe-R"].goal.name == "Old", "the old record is left in place, not merged")
check(GoldGoalDB["Player-4321-0000AAAA"].migratedFrom == nil, "no migration note when nothing moved")

----- 5. GUID fallback: unreadable GUID keys by full name; the old record still moves
me.guid = SECRET
LevelLogDB = { ["Joe-R"] = { [5] = { seconds = 60, deaths = 1 } } }
local log = load("LevelLog")
fire(log, "PLAYER_LOGIN")
check(LevelLogDB["Joe Smith-R"] and LevelLogDB["Joe Smith-R"][5].seconds == 60, "moved to the full-name key")
check(LevelLogDB["Joe Smith-R"].migratedFrom == "Joe-R" and LevelLogDB["Joe-R"] == nil, "noted and old key removed")
-- Next login the GUID is readable: the full-name record moves on to the GUID key.
me.guid = "Player-4321-0000AAAA"
local log2 = load("LevelLog")
fire(log2, "PLAYER_LOGIN")
check(LevelLogDB["Player-4321-0000AAAA"] and LevelLogDB["Player-4321-0000AAAA"][5].seconds == 60, "full-name record moved to the GUID")
check(LevelLogDB["Joe Smith-R"] == nil, "full-name key removed")

----- 6. A record stamped with another character's GUID is never taken
SupplyWatchDB = { ["Joe Smith-R"] = { items = { { id = 1 } }, charGUID = "Player-4321-0000CCCC" } }
local supply = load("SupplyWatch")
fire(supply, "PLAYER_LOGIN")
check(SupplyWatchDB["Joe Smith-R"] and SupplyWatchDB["Joe Smith-R"].charGUID == "Player-4321-0000CCCC", "someone else's record stays")
check(#SupplyWatchDB["Player-4321-0000AAAA"].items == 0, "this character starts with an empty list")

----- 7. TrainerNotes uses the shared key too
TrainerNotesDB = { ["Joe-R"] = { services = { ["Rend|Rank 2"] = { name = "Rend", level = 12, cost = 1 } } } }
local trainer = load("TrainerNotes")
fire(trainer, "PLAYER_LOGIN")
check(TrainerNotesDB["Player-4321-0000AAAA"] and TrainerNotesDB["Player-4321-0000AAAA"].services["Rend|Rank 2"], "trainer list moved")

----- 8. Tooltips: "You have" shows the saved names, not the GUID keys
local callbacks = {}
TooltipDataProcessor = { AddTooltipPostCall = function(kind, fn) callbacks[kind] = fn end }
TooltipUtil = { GetDisplayedItem = function() return nil end }
C_Item = { GetItemInfo = function(id) if id == 2589 then return "Linen Cloth", "link", 1, 5, 1, "t", "s", 20, "", 1, 130, 7 end end }
local lines = {}
local tip = { AddLine = function(_, t) lines[#lines + 1] = t end, AddDoubleLine = function(_, l, r) lines[#lines + 1] = l .. " = " .. r end,
    GetName = function() return "GameTooltip" end, NumLines = function() return #lines end, GetProcessingTooltipInfo = function() end }
GameTooltip, ItemRefTooltip = tip, { lines = {} }
ItemFinderDB = {
    ["Player-4321-0000AAAA"] = { bags = { ["Linen Cloth"] = 5 }, charName = "Joe Smith" },
    ["Player-4321-0000BBBB"] = { bags = { ["Linen Cloth"] = 3 }, charName = "Joe Brown" },
    ["Old-R"] = { bank = { ["Linen Cloth"] = 2 } },
}
local tips = load("Tooltips")
fire(tips, "PLAYER_LOGIN")
lines = {}
local ok, err = pcall(callbacks[0], tip, { id = 2589 })
check(ok, "tooltip callback ran: " .. tostring(err))
local text = table.concat(lines, "\n")
check(text:find("Joe Smith 5 bags", 1, true), "own line uses the saved name:\n" .. text)
check(text:find("Joe Brown 3", 1, true), "other character by saved name:\n" .. text)
check(text:find("Old 2", 1, true), "an older record falls back to the key's name part:\n" .. text)
check(not text:find("Player", 1, true), "no GUID shown:\n" .. text)

----- 9. ForeverHelper: the character list shows saved names; the old record moves to the GUID key
ForeverHelperDB = { characters = { ["Joe-R"] = { tasks = { { text = "Train" } }, level = 9, money = 100 },
    ["Player-4321-0000BBBB"] = { tasks = {}, level = 12, money = 200, charName = "Joe Brown" } }, shown = true }
local helper = load("ForeverHelper")
fire(helper, "ADDON_LOADED", "ForeverHelper")
fire(helper, "PLAYER_LOGIN")
local smith = ForeverHelperDB.characters["Player-4321-0000AAAA"]
check(smith and smith.tasks[1].text == "Train" and smith.charName == "Joe Smith", "to-do list moved with the name")
check(ForeverHelperDB.characters["Joe-R"] == nil, "old key gone")
out = {}
SlashCmdList.FOREVERHELPER("chars")
check(has("Joe Brown: level 12") and has("Joe Smith: level 10"), "names listed:\n" .. table.concat(out, "\n"))
check(not has("Player-"), "no GUID listed:\n" .. table.concat(out, "\n"))

if #failures > 0 then
    error("FAILURES:\n" .. table.concat(failures, "\n"))
end
print("ALL TESTS PASSED")
