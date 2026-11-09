-- Tooltips smoke test: each extra line, toggles, de-duplication, secret values, missing APIs,
-- and a throwing data source not breaking the tooltip.
-- Run from the harness folder:  node run.js "<workspace root>" test_tooltips.lua
local base = ADDON_PATH
local out, frames, failures = {}, {}, {}
local SECRET = {}
issecretvalue = function(v) return v == SECRET end
ForeverHub_Receive = function(_, t) out[#out + 1] = t end
CreateFrame = function()
    local f = { registered = {} }
    f.RegisterEvent = function(self, e) self.registered[e] = true end
    f.SetScript = function(self, _, fn) self.fn = fn end
    frames[#frames + 1] = f
    return f
end
SlashCmdList = {}
UnitName = function(u) if u == "player" then return "Juan" end end
GetRealmName = function() return "R" end
UnitFactionGroup = function() return "Alliance" end
local clock = 1000000
time = function() return clock end

-- Tooltip processor mock: captures callbacks.
local callbacks = {}
Enum = { TooltipDataType = { Item = 0, Unit = 2 }, TooltipDataLineType = { SellPrice = 11 } }
TooltipDataProcessor = { AddTooltipPostCall = function(kind, fn) callbacks[kind] = fn end }
TooltipUtil = { GetDisplayedItem = function() return nil end }

-- Fake tooltip collecting lines; it also exposes its existing lines like a real GameTooltip.
local tip = { lines = {} }
GameTooltip = tip
ItemRefTooltip = { lines = {} }
local function existing(texts)
    tip.lines = {}
    for i = 1, 30 do _G["GameTooltipTextLeft" .. i] = nil end
    for i, t in ipairs(texts or {}) do
        _G["GameTooltipTextLeft" .. i] = { GetText = function() return t end }
        tip.lines[#tip.lines + 1] = t
    end
end
function tip:AddLine(t) self.lines[#self.lines + 1] = t end
function tip:AddDoubleLine(l, r) self.lines[#self.lines + 1] = l .. " = " .. r end
function tip:GetName() return "GameTooltip" end
function tip:NumLines() return #self.lines end
local tipInfo
function tip:GetProcessingTooltipInfo() return tipInfo end
local unitToken
local unitName = "Mob"
function tip:GetUnit() return unitName, unitToken end
-- Anything else the addon tries to call on the tooltip is a failure.
setmetatable(tip, { __index = function(_, k) failures[#failures + 1] = "tooltip method used: " .. tostring(k) end })

local items = {
    [2589] = { "Linen Cloth", 5, 130, 7 },
    [118] = { "Minor Healing Potion", 5, 5, 0 },
    [5000] = { "Quest Thing", 1, 0, 12 },
    [6948] = { "Hearthstone", 1, 0, 15 },
    [9999] = { "Big Sword", 30, 12345, 2 },
}
local infoCalls = 0
C_Item = { GetItemInfo = function(id)
    infoCalls = infoCalls + 1
    local i = items[id]
    if not i then return end
    return i[1], "link", 1, i[2], 1, "t", "s", 20, "", 1, i[3], i[4], 0, i[5]
end }
C_CurrencyInfo = nil
GetCoinTextureString = nil
C_Container = { GetContainerItemInfo = function(bag, slot) if bag == 0 and slot == 1 then return { stackCount = 20 } end end }
GetLootSlotInfo = function(slot) return "tex", "Linen Cloth", 3 end

PriceMemoryDB = {
    ["R-Alliance"] = { [2589] = { price = 31000, seen = clock - 2 * 86400 } },
    [118] = { price = 150, seen = clock - 3600 * 5 },
}
ItemFinderDB = {
    ["Juan-R"] = { bags = { ["Linen Cloth"] = 5 }, bank = { ["Linen Cloth"] = 7 }, gear = {} },
    ["Alt-R"] = { bags = { ["Linen Cloth"] = 3 } },
    ["Zed-R"] = { bank = { ["Big Sword"] = 1 } },
}
ProfessionGuideData = {
    [171] = { name = "Alchemy", steps = {
        { from = 1, to = 60, mats = { { itemID = 765, count = 1 } } },
        { from = 60, to = 110, mats = { { itemID = 2589, count = 2 } } },
    } },
    [197] = { steps = { { range = "1-75", mats = { [2589] = 40 } } } },
}

local function has(list, text) for _, t in ipairs(list) do if tostring(t):find(text, 1, true) then return true end end return false end
local function dump(list) return "\n  lines were:\n  " .. table.concat(list, "\n  ") end
local function check(cond, why) if not cond then failures[#failures + 1] = why .. dump(tip.lines) .. dump(out) end end
local function need(text, why) check(has(tip.lines, text), why .. ": wanted '" .. text .. "'") end
local function lack(text, why) check(not has(tip.lines, text), why .. ": did not want '" .. text .. "'") end
local function hover(id, data, pre, onTip)
    existing(pre)
    data = data or {}
    data.id = data.id or id
    local ok, err = pcall(callbacks[0], onTip or tip, data)
    check(ok, "item callback must not error: " .. tostring(err))
end
local function hoverUnit(data)
    existing({})
    local ok, err = pcall(callbacks[2], tip, data)
    check(ok, "unit callback must not error: " .. tostring(err))
end
local function page(arg)
    out = {}
    local ok, err = pcall(SlashCmdList.TOOLTIPS, arg)
    if not ok then out[#out + 1] = "<<ERROR: " .. tostring(err) .. ">>" end
end
local function needPage(text, why) check(has(out, text), why .. ": wanted '" .. text .. "'") end

assert(loadfile(base .. "/Tooltips/Tooltips.lua"))("Tooltips", {})
local f = frames[#frames]
check(callbacks[0] == nil, "nothing registered before login")
f.fn(f, "PLAYER_LOGIN")
check(type(callbacks[0]) == "function" and type(callbacks[2]) == "function", "item and unit callbacks registered")
check(type(TooltipsDB) == "table" and next(TooltipsDB) == nil, "TooltipsDB created empty")
check(SLASH_TOOLTIPS1 == "/fhtips", "slash command")

-- Vendor price, stack from a bag slot, auction, counts, profession.
tipInfo = { getterName = "GetBagItem", getterArgs = { 0, 1 } }
hover(2589)
need("Sells for = |cffc7c7cf1s|r |cffeda55f30c|r", "vendor price")
need("x20:|r |cffc7c7cf26s|r", "stack price for 20")
need("Auction = |cffffd7003g|r |cffc7c7cf10s|r |cff999999(2 days ago)|r", "auction price with age")
need("(2 days ago)|r  |cff999999x20:|r |cffffd70062g|r", "auction price for the whole stack")
lack("(old)", "a 2-day-old price isn't old")
need("You have = 15 |cff999999(Juan 5 bags, 7 bank; Alt 3)|r", "counts on every character")
need("Needed = Alchemy guide step 60-110, Profession guide step 1-75", "profession guide uses")
lack("Item ID", "id line off by default")

-- Loot window stack; unknown source leaves the stack part out.
tipInfo = { getterName = "GetLootItem", getterArgs = { 2 } }
hover(2589)
need("x3:", "loot stack count")
tipInfo = { getterName = "GetHyperlink", getterArgs = { "item:2589" } }
hover(2589)
lack("|cff999999x", "no stack part from an unknown source")
-- Merchant without the merchant API: no stack part, no error.
tipInfo = { getterName = "GetMerchantItem", getterArgs = { 1 } }
hover(2589)
lack("|cff999999x", "no stack part when the merchant API is missing")
-- Merchant, mail, trade and loot roll stacks.
C_MerchantFrame = { GetItemInfo = function(i) if i == 1 then return { price = 100, stackCount = 5, numAvailable = -1 } end end }
hover(2589)
need("Sells for = |cffc7c7cf1s|r |cffeda55f30c|r  |cff999999x5:|r", "merchant purchase stack")
need("x5:|r |cffffd70015g|r |cffc7c7cf50s|r", "merchant auction stack total")
GetInboxItem = function(m, a) if m == 2 and a == 3 then return "Linen Cloth", 2589, "tex", 7, 1, true end end
tipInfo = { getterName = "GetInboxItem", getterArgs = { 2, 3 } }
hover(2589)
need("x7:", "inbox attachment stack")
GetSendMailItem = function(i) if i == 1 then return "Linen Cloth", 2589, "tex", 4, 1 end end
tipInfo = { getterName = "GetSendMailItem", getterArgs = { 1 } }
hover(2589)
need("x4:", "send-mail attachment stack")
GetTradePlayerItemInfo = function(i) return "Linen Cloth", "tex", 6, 1, true, nil end
GetTradeTargetItemInfo = function(i) return "Linen Cloth", "tex", 9, 1, true, nil end
tipInfo = { getterName = "GetTradePlayerItem", getterArgs = { 1 } }
hover(2589)
need("x6:", "trade (yours) stack")
tipInfo = { getterName = "GetTradeTargetItem", getterArgs = { 1 } }
hover(2589)
need("x9:", "trade (theirs) stack")
local rollBop = false
GetLootRollItemInfo = function(id) return "tex", "Linen Cloth", 2, 1, rollBop end
tipInfo = { getterName = "GetLootRollItem", getterArgs = { 44 } }
hover(2589)
need("x2:", "loot roll stack")
need("Auction =", "loot roll item that doesn't bind shows its auction price")
rollBop = true
hover(2589)
lack("Auction", "bind-on-pickup loot roll hides the auction line")
GetTradePlayerItemInfo = function() error("boom") end
tipInfo = { getterName = "GetTradePlayerItem", getterArgs = { 1 } }
hover(2589)
need("Sells for", "a failing count lookup only drops the stack part")
lack("|cff999999x", "no stack part when the count lookup fails")
tipInfo = nil

-- Bound items get no auction line; bind-on-equip ones still do.
items[2590] = { "Soul Thing", 5, 100, 4, 1 }
items[2591] = { "BoE Thing", 5, 100, 4, 2 }
PriceMemoryDB["R-Alliance"][2590] = { price = 500, seen = clock }
PriceMemoryDB["R-Alliance"][2591] = { price = 500, seen = clock }
hover(2590)
lack("Auction", "bind-on-pickup item: no auction line")
need("Sells for", "bound item still shows its vendor price")
hover(2591)
need("Auction =", "bind-on-equip item keeps its auction line")
local boundSlot = { stackCount = 1, isBound = true }
local savedContainer = C_Container.GetContainerItemInfo
C_Container.GetContainerItemInfo = function(bag, slot) if bag == 1 and slot == 2 then return boundSlot end end
tipInfo = { getterName = "GetBagItem", getterArgs = { 1, 2 } }
hover(2591)
lack("Auction", "a bag copy the game marks bound: no auction line")
boundSlot.isBound = SECRET
hover(2591)
need("Auction =", "secret bind state is not taken as bound")
tipInfo = { getterName = "GetInventoryItem", getterArgs = { "player", 5 } }
hover(2591)
lack("Auction", "worn gear: no auction line")
C_Container.GetContainerItemInfo = savedContainer
tipInfo = nil

-- Old prices are marked.
PriceMemoryDB["R-Alliance"][2591] = { price = 500, seen = clock - 11 * 86400 }
hover(2591)
need("(11 days ago)|r |cffff9933(old)|r", "stale price marked old")

-- PriceMemory's shared lookup is used when it's loaded, instead of reading its saved data.
do
    local asked
    PriceMemory_Get = function(id)
        asked = id
        if id == 2589 then return { price = 777, seen = clock - 3600, stale = false, legacy = false } end
        if id == 118 then return { vendorBuy = 25 } end
    end
    hover(2589)
    check(asked == 2589, "shared lookup asked for the item")
    need("Auction = |cffc7c7cf7s|r |cffeda55f77c|r |cff999999(1h ago)|r", "price from the shared lookup")
    hover(118)
    lack("Auction", "a merchant-only record has no auction line")
    PriceMemory_Get = function() return { price = 900, seen = clock - 20 * 86400, stale = true, legacy = true } end
    hover(2589)
    need("(20 days ago)|r |cff999999(older save)|r |cffff9933(old)|r", "legacy and stale from the shared lookup")
    PriceMemory_Get = function() error("boom") end
    hover(2589)
    lack("Auction", "a failing lookup adds no auction line")
    need("Sells for", "and doesn't take the other lines with it")
    PriceMemory_Get = nil
end

-- Legacy flat price entry, and hours ago.
hover(118)
need("Auction = |cffc7c7cf1s|r |cffeda55f50c|r", "legacy price shown")
need("5h ago", "hours age")
need("(older save)", "legacy marked")
lack("You have", "no count line when nobody has it")
lack("Needed", "no profession line when not a mat")

-- No sell price: shown for normal items, not for quest items.
hover(6948)
need("No sell price", "unsellable item noted")
hover(5000)
lack("No sell price", "quest item stays quiet")

-- The game's own sell price line is not repeated.
hover(2589, { lines = { { type = 11 } } })
lack("Sells for", "game sell price not duplicated")

-- PriceMemory / ItemFinder lines already present are not duplicated.
hover(2589, nil, { "Linen Cloth", "Auction, seen 2d ago: 3g 10s 0c each", "Owned: bags 5, bank 7, Alt 3" })
lack("Auction =", "auction not duplicated")
lack("You have", "count not duplicated")

-- Only GameTooltip and ItemRefTooltip.
local other = { lines = {}, AddLine = function(self, t) self.lines[#self.lines + 1] = t end, AddDoubleLine = function(self, l) self.lines[#self.lines + 1] = l end }
pcall(callbacks[0], other, { id = 2589 })
check(#other.lines == 0, "comparison/other tooltips left alone")

-- Cache: item info asked once per item.
local before = infoCalls
hover(2589); hover(2589)
check(infoCalls == before, "item info cached per item ID")
-- Uncached items (nil info) are retried.
hover(4242)
items[4242] = { "Late Item", 3, 7, 0 }
hover(4242)
need("Sells for = |cffeda55f7c|r", "item info retried until it loads")

-- Toggles.
page("off vendor")
needPage("Vendor price is now", "off message")
check(TooltipsDB.vendor == false, "vendor saved off")
hover(2589)
lack("Sells for", "vendor off")
page("on id")
check(TooltipsDB.id == true, "id saved on")
hover(9999)
need("Item ID = 9999", "item id line")
need("Item level = 30", "item level line")
need("You have = 1 |cff999999(Zed 1)|r", "other character only")
page("toggle vendor")
check(TooltipsDB.vendor == true, "toggle back on")
page("auction")
check(TooltipsDB.auction == false, "bare name toggles")
hover(2589)
lack("Auction", "auction off")
page("on auction")
page("off count"); hover(2589); lack("You have", "count off"); page("on count")
page("off profession"); hover(2589); lack("Needed", "profession off"); page("on profession")
page("off bogus")
needPage("Type on, off, or toggle", "unknown name")
page("")
needPage("Vendor price", "page lists lines")
needPage("(npc)", "page lists npc")
needPage("(drop)", "page lists drop")
needPage("(questitem)", "page lists questitem")
needPage("(giver)", "page lists giver")
needPage("(upgrade)", "page lists upgrade")
needPage("Type: off vendor", "page hint")
check(f.registered.QUEST_LOG_UPDATE, "quest log updates watched")

-- NPC ID.
hoverUnit({ guid = "Creature-0-3783-0-12-299-0000A1B2C3" })
lack("NPC ID", "npc off by default")
page("on npc")
hoverUnit({ guid = "Creature-0-3783-0-12-299-0000A1B2C3" })
need("NPC ID = 299", "npc id from guid")
hoverUnit({ guid = "Player-1-ABC" })
lack("NPC ID", "players have no npc id")
hoverUnit({ guid = SECRET })
lack("NPC ID", "secret guid skipped")
unitToken = "mouseover"
UnitGUID = function() return "Vehicle-0-1-0-1-777-00" end
hoverUnit({})
need("NPC ID = 777", "guid from the tooltip's unit when data has none")
UnitGUID = function() return SECRET end
hoverUnit({})
lack("NPC ID", "secret UnitGUID skipped")

----------------------------------------------------------------------------------------------------
-- Dungeon drops.
items[14149] = { "Subterranean Cape", 20, 500, 4, 1 }
items[2042] = { "Staff of Westfall", 25, 900, 2, 1 }
items[6463] = { "Deep Fathom Ring", 25, 900, 4, 1 }
hover(14149)
lack("Drops from", "no drop line without DungeonsData")
DungeonsData = {
    { name = "Ragefire Chasm", loot = { { 14149, "Subterranean Cape", "Taragaman the Hungerer", "Back" } } },
    { name = "The Deadmines", loot = { { 2042, "Staff of Westfall", "quest: The Defias Brotherhood", "Two-Hand" } } },
    { name = "Wailing Caverns", loot = { { 6463, "Deep Fathom Ring", "Mutanus the Devourer", "Finger" } } },
    { name = "Blackfathom Deeps", loot = { { itemID = 6463, boss = "Aku'mai" } } },
    "junk", { name = "No Loot" }, { loot = { { 1, "x", "y" } } }, { name = "Bad", loot = { "x", { "id", "n", "b" }, { 5, "n", SECRET } } },
}
hover(14149)
need("Drops from = Taragaman the Hungerer in Ragefire Chasm", "drop line")
hover(2042)
need("Quest reward = The Defias Brotherhood (The Deadmines)", "dungeon quest reward line")
lack("Drops from", "a quest reward isn't a drop")
hover(6463)
need("Drops from = Mutanus the Devourer in Wailing Caverns |cff999999+1 more|r", "several sources: first plus count")
-- Indexed once: adding loot to the same table isn't seen; a new table is.
items[6911] = { "Moss Cinch", 25, 900, 4, 1 }
DungeonsData[1].loot[2] = { 6911, "Moss Cinch", "Aku'mai", "Waist" }
hover(6911)
lack("Drops from", "the drop index is built once per table")
DungeonsData = { { name = "Blackfathom Deeps", loot = { { 6911, "Moss Cinch", "Aku'mai", "Waist" } } } }
hover(6911)
need("Drops from = Aku'mai in Blackfathom Deeps", "a new Dungeons table is indexed again")
page("off drop"); hover(6911); lack("Drops from", "drop off"); page("on drop")
DungeonsData = setmetatable({}, { __index = function() error("boom") end })
hover(6911)
lack("Drops from", "a throwing Dungeons table adds no drop line")
need("Sells for", "and doesn't take the other lines with it")
DungeonsData = nil

----------------------------------------------------------------------------------------------------
-- Quest items from your log.
local log, logCalls = {}, 0
local completed = {}
local function questLogApi()
    C_QuestLog = {
        GetNumQuestLogEntries = function() return #log end,
        GetInfo = function(i) logCalls = logCalls + 1 return log[i] and log[i].info end,
        GetQuestObjectives = function(id) for _, e in ipairs(log) do if e.info.questID == id then return e.objectives end end end,
        IsComplete = function(id) for _, e in ipairs(log) do if e.info.questID == id then return e.complete end end end,
        IsQuestFlaggedCompleted = function(id) return completed[id] end,
    }
end
local function setLog(entries) log = entries f.fn(f, "QUEST_LOG_UPDATE") end
hover(2589)
lack("Needed for:", "no quest log API: no quest line")
questLogApi()
setLog({
    { info = { title = "Elwynn Forest", isHeader = true } },
    { info = { title = "Linen Run", questID = 100 }, objectives = { { text = "Linen Cloth: 3/8", type = "item", numFulfilled = 3, numRequired = 8, finished = false } } },
    { info = { title = "Kill Things", questID = 101 }, objectives = { { text = "Kobold slain: 1/10", type = "monster", numFulfilled = 1, numRequired = 10, finished = false } } },
})
hover(2589)
need("Needed for: Linen Run (3/8)", "quest item line with count")
lack("Kill Things", "other quests left out")
hover(118)
lack("Needed for:", "an item no quest needs")
-- Cached until the quest log changes.
local calls = logCalls
hover(2589); hover(2589)
check(logCalls == calls, "quest log read once per update")
log[2].objectives[1] = { text = "Linen Cloth: 5/8", type = "item", numFulfilled = 5, numRequired = 8, finished = false }
hover(2589)
need("(3/8)", "old count until QUEST_LOG_UPDATE")
f.fn(f, "QUEST_LOG_UPDATE")
hover(2589)
need("Needed for: Linen Run (5/8)", "new count after QUEST_LOG_UPDATE")
-- The game (or ItemAdvisor) already naming the quest.
hover(2589, nil, { "Linen Cloth", "Linen Run" })
lack("Needed for:", "quest already on the tooltip isn't repeated")
hover(2589, nil, { "Linen Cloth", "KEEP: Needed for Linen Run" })
lack("Needed for:", "ItemAdvisor's quest line isn't repeated")
-- Finished objectives, counts only in the text, secret parts.
setLog({
    { info = { title = "Done Gathering", questID = 102 }, objectives = { { text = "Linen Cloth: 8/8", type = "item", numFulfilled = 8, numRequired = 8, finished = true } } },
    { info = { title = "Text Count", questID = 103 }, objectives = { { text = "linen cloth: 2/4", type = "item", numFulfilled = SECRET, numRequired = SECRET } } },
    { info = { title = "Secret Text", questID = 104 }, objectives = { { text = SECRET, type = "item" } } },
    { info = SECRET },
    { info = { title = SECRET, questID = 105 } },
})
hover(2589)
lack("Done Gathering", "finished objective left out")
need("Needed for: Text Count (2/4)", "count read from the text when the numbers are secret; case ignored")
lack("Secret Text", "secret objective text skipped")
-- Cap at 3.
local many = {}
for i = 1, 5 do many[i] = { info = { title = "Cloth Quest " .. i, questID = 200 + i }, objectives = { { text = "Linen Cloth: 0/2", type = "item", numFulfilled = 0, numRequired = 2 } } } end
setLog(many)
hover(2589)
need("Cloth Quest 3", "three quests shown")
lack("Cloth Quest 4", "fourth quest capped")
need("+2 more", "more count")
page("off questitem"); hover(2589); lack("Needed for:", "questitem off"); page("on questitem")
-- A throwing quest log API.
C_QuestLog.GetInfo = function() error("boom") end
f.fn(f, "QUEST_LOG_UPDATE")
hover(2589)
lack("Needed for:", "throwing quest log: no quest line")
need("Sells for", "throwing quest log keeps the other lines")
questLogApi()
setLog({})

----------------------------------------------------------------------------------------------------
-- Quest givers from the leveling guide.
local CREATURE = "Creature-0-3783-0-12-240-0000A1B2C3"
unitName = "Marshal Dughan"
hoverUnit({ guid = CREATURE })
lack("Starts:", "no giver line without routes")
local route = { zone = "Elwynn Forest", steps = {
    { t = "accept", q = "Quest One", npc = "Marshal Dughan (in Goldshire)" },
    { t = "turnin", q = "Quest Two", npc = "Marshal Dughan, Goldshire" },
    { t = "accept", q = "Quest Three", npc = "<Town Crier> MARSHAL  dughan" },
    { t = "turnin", q = "Done Quest", npc = "Marshal Dughan" },
    { t = "accept", q = "Log Quest", npc = "Marshal Dughan at 42.1, 65.3" },
    { t = "turnin", q = "Ready Quest", npc = "Marshal Dughan 42.1, 65.3" },
    { t = "do", q = "Quest One", note = "kill" },
    { t = "accept", q = "Other Quest", npc = "Someone Else" },
    { t = "accept", npc = "Marshal Dughan" }, "junk",
} }
LevelGuideRoutes = { chains = { Human = { route }, Dwarf = { route, "junk" }, Bad = "x" } }
LevelGuideQuestIDs = { ids = { ["Done Quest"] = { 500 } }, renamed = {} }
completed[500] = true
setLog({
    { info = { title = "Log Quest", questID = 600 }, complete = false },
    { info = { title = "Ready Quest", questID = 601 }, complete = true },
    { info = { title = "Quest Two", questID = 602 }, complete = false },
})
hoverUnit({ guid = CREATURE })
-- Line 1 is the NPC ID (switched on above).
check(tip.lines[1] == "NPC ID = 240", "npc id first")
check(tip.lines[2] == "Turn in: Ready Quest |cff33ff33(ready)|r", "ready turn-in first")
check(tip.lines[3] == "Turn in: Quest Two", "held turn-in next")
check(tip.lines[4] == "Starts: Quest One", "then new quests")
check(tip.lines[5] == "+1 more", "capped at 3 with +N more")
check(#tip.lines == 5, "no duplicates from a route used by two chains")
lack("Done Quest", "completed quest left out")
lack("Log Quest", "a quest in your log isn't offered again")
lack("Other Quest", "another NPC's quest left out")
-- Without the cap: drop the ready one and see the rest.
completed[500] = nil
setLog({})
hoverUnit({ guid = CREATURE })
need("Starts: Quest One", "start shown")
need("Starts: Quest Three", "<title>, case and spacing ignored")
need("Starts: Log Quest", "coordinates text stripped")
need("+3 more", "six rows: three plus three more")
check(tip.lines[2] == "Starts: Quest One", "new quests before turn-ins you don't hold")
-- Not completed per the game when the flag is secret; renamed titles found under the new name.
LevelGuideQuestIDs = { ids = { ["Quest Uno"] = { 700 }, ["Quest Two"] = { 701 }, ["Quest Three"] = { 702 }, ["Done Quest"] = { 703 }, ["Log Quest"] = { 704 } }, renamed = { ["Quest One"] = "Quest Uno" } }
completed[700] = true; completed[701] = true; completed[702] = SECRET; completed[703] = true; completed[704] = true
hoverUnit({ guid = CREATURE })
lack("Quest One", "completed under its renamed title")
need("Starts: Quest Three", "secret completion flag counts as not done")
need("Turn in: Ready Quest", "turn-in for a quest you don't hold, without ready")
lack("(ready)", "not ready when not in the log")
lack("more", "no more line under the cap")
-- Chain parts: part 2 waits for part 1 when the IDs are known.
do
    local savedRoutes, savedIDs = LevelGuideRoutes, LevelGuideQuestIDs
    LevelGuideRoutes = { chains = { Human = { { steps = {
        { t = "accept", q = "Chain", npc = "Marshal Dughan", part = 2 },
        { t = "accept", q = "Unknown Chain", npc = "Marshal Dughan", part = 2 },
    } } } } }
    LevelGuideQuestIDs = { ids = { Chain = { 800, 801 } }, renamed = {} }
    hoverUnit({ guid = CREATURE })
    lack("Starts: Chain", "part 2 hidden while part 1 isn't done")
    need("Starts: Unknown Chain", "part 2 shown when part 1's ID is unknown")
    completed[800] = true
    hoverUnit({ guid = CREATURE })
    need("Starts: Chain", "part 2 shown once part 1 is done")
    completed[800] = nil
    LevelGuideRoutes, LevelGuideQuestIDs = savedRoutes, savedIDs
end
-- Players, instances, secrets, toggle.
hoverUnit({ guid = "Player-1-ABC" })
lack("Starts:", "a player with the same name gets nothing")
IsInInstance = function() return true, "party" end
hoverUnit({ guid = CREATURE })
check(#tip.lines == 0, "nothing on units inside an instance (npc id included)")
IsInInstance = function() return SECRET end
hoverUnit({ guid = CREATURE })
check(#tip.lines == 0, "a secret instance answer counts as inside")
IsInInstance = function() error("boom") end
hoverUnit({ guid = CREATURE })
need("Starts: Quest Three", "a failing instance check doesn't hide lines")
IsInInstance = function() return false, "none" end
hoverUnit({ guid = CREATURE })
need("NPC ID = 240", "npc id outside instances")
need("Starts: Quest Three", "giver outside instances")
unitName = SECRET
hoverUnit({ guid = CREATURE })
lack("Starts:", "secret unit name skipped")
need("NPC ID = 240", "npc id still shown with a secret name")
unitName = "Marshal Dughan"
page("off giver"); hoverUnit({ guid = CREATURE }); lack("Starts:", "giver off"); page("on giver")
page("off npc")
hoverUnit({ guid = CREATURE })
need("Starts: Quest Three", "giver works with the npc id line off")
LevelGuideQuestIDs = nil
completed = {}
hoverUnit({ guid = CREATURE })
need("Starts: Quest One", "no quest ID data: quests shown")
LevelGuideRoutes = setmetatable({}, { __index = function() error("boom") end })
hoverUnit({ guid = CREATURE })
lack("Starts:", "throwing routes add nothing")
LevelGuideRoutes = nil
C_QuestLog = nil
hoverUnit({ guid = CREATURE })
check(#tip.lines == 0, "missing routes and quest API add nothing")
unitName = "Mob"
IsInInstance = nil

----------------------------------------------------------------------------------------------------
-- Upgrade (ItemAdvisor).
local savedDisplayed = TooltipUtil.GetDisplayedItem
TooltipUtil.GetDisplayedItem = function() return "Big Sword", "|Hitem:9999|h[Big Sword]|h", 9999 end
ItemAdvisor_IsUpgrade = function(link) return link:find("item:9999", 1, true) ~= nil, "reason" end
hover(9999)
lack("Upgrade for you", "upgrade off by default")
page("on upgrade")
hover(9999)
need("Upgrade for you", "upgrade line")
hover(9999, nil, { "Big Sword", "EQUIP: Upgrade for main hand (+12)" })
lack("Upgrade for you", "ItemAdvisor's own verdict isn't repeated")
hover(9999, nil, { "Big Sword", "SELL: Not an upgrade" })
lack("Upgrade for you", "any ItemAdvisor verdict line means it's there")
hover(9999, nil, { "Big Sword", "NOTE: something" })
need("Upgrade for you", "an unrelated capitalised line doesn't block it")
ItemAdvisor_IsUpgrade = function() return false end
hover(9999)
lack("Upgrade for you", "not an upgrade")
ItemAdvisor_IsUpgrade = function() error("boom") end
hover(9999)
lack("Upgrade for you", "throwing ItemAdvisor adds nothing")
need("Item ID = 9999", "and keeps the other lines")
ItemAdvisor_IsUpgrade = function() return SECRET end
hover(9999)
lack("Upgrade for you", "secret answer skipped")
ItemAdvisor_IsUpgrade = function() return true end
TooltipUtil.GetDisplayedItem = function() return nil, SECRET end
hover(9999)
lack("Upgrade for you", "secret link skipped")
ItemAdvisor_IsUpgrade = nil
TooltipUtil.GetDisplayedItem = savedDisplayed
hover(9999)
lack("Upgrade for you", "no ItemAdvisor: nothing")
page("off upgrade")
page("on npc")

-- Secret values in item data.
hover(nil, { id = SECRET })
check(#tip.lines == 0, "secret item id adds nothing")
C_Item.GetItemInfo = function() return SECRET, nil, nil, SECRET, nil, nil, nil, nil, nil, nil, SECRET, SECRET end
hover(7777)
lack("Sells for", "secret item info adds no vendor line")
PriceMemoryDB["R-Alliance"][7777] = { price = 99, seen = clock }
hover(7777)
need("Auction", "auction line still works when item info is secret")
GetRealmName = function() return SECRET end
hover(7777)
lack("Auction", "secret realm: only legacy prices consulted")
GetRealmName = function() return "R" end

-- Throwing data sources don't break the tooltip.
setmetatable(ItemFinderDB, { __pairs = function() error("boom") end })
ProfessionGuideData = setmetatable({}, { __index = function() error("boom") end, __pairs = function() error("boom") end })
C_Container.GetContainerItemInfo = function() error("boom") end
tipInfo = { getterName = "GetBagItem", getterArgs = { 0, 1 } }
hover(2589)
need("Item ID = 2589", "id line still added after other data sources throw")
lack("Sells for", "the throwing stack lookup drops only its own line")
tipInfo = nil
GameTooltip = nil

-- Missing APIs: loading and login don't error and register nothing.
do
    local savedProcessor = TooltipDataProcessor
    callbacks = {}
    TooltipDataProcessor = nil
    local ok, err = pcall(function()
        assert(loadfile(base .. "/Tooltips/Tooltips.lua"))("Tooltips", {})
        local g = frames[#frames]
        g.fn(g, "PLAYER_LOGIN")
    end)
    check(ok, "loads without TooltipDataProcessor: " .. tostring(err))
    check(next(callbacks) == nil, "nothing registered without the API")
    page("")
    needPage("doesn't offer the tooltip hook", "page says the hook is missing")
    TooltipDataProcessor = savedProcessor
    Enum = nil
    ok, err = pcall(function()
        assert(loadfile(base .. "/Tooltips/Tooltips.lua"))("Tooltips", {})
        local g = frames[#frames]
        g.fn(g, "PLAYER_LOGIN")
    end)
    check(ok, "loads without Enum: " .. tostring(err))
    check(next(callbacks) == nil, "nothing registered without Enum.TooltipDataType")
    -- Registration itself throwing.
    Enum = { TooltipDataType = { Item = 0, Unit = 2 } }
    TooltipDataProcessor = { AddTooltipPostCall = function() error("refused") end }
    ok, err = pcall(function()
        assert(loadfile(base .. "/Tooltips/Tooltips.lua"))("Tooltips", {})
        local g = frames[#frames]
        g.fn(g, "PLAYER_LOGIN")
    end)
    check(ok, "a refused registration is swallowed: " .. tostring(err))
end

if #failures > 0 then
    print("FAILURES (" .. #failures .. "):")
    for _, why in ipairs(failures) do print(" - " .. why) end
    os.exit(1)
end
print("test_tooltips: all checks passed")
