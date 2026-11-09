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
function tip:GetUnit() return "Mob", unitToken end
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
    return i[1], "link", 1, i[2], 1, "t", "s", 20, "", 1, i[3], i[4]
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
need("You have = 15 |cff999999(Juan 5 bags, 7 bank; Alt 3)|r", "counts on every character")
need("Needed = Alchemy guide step 60-110, Profession guide step 1-75", "profession guide uses")
lack("Item ID", "id line off by default")

-- Loot window stack; unknown source leaves the stack part out.
tipInfo = { getterName = "GetLootItem", getterArgs = { 2 } }
hover(2589)
need("x3:", "loot stack count")
tipInfo = { getterName = "GetMerchantItem", getterArgs = { 1 } }
hover(2589)
lack("|cff999999x", "no stack part from an unknown source")
tipInfo = nil

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
needPage("Type: off vendor", "page hint")

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
