-- Adds a few lines of information to item and unit tooltips. It only appends lines through
-- Blizzard's tooltip post-call hook; it never shows, hides, moves, or clears a tooltip.

local SECONDS_PER_HOUR, SECONDS_PER_DAY = 3600, 86400
local QUEST_ITEM_CLASS = 12
local LABEL_R, LABEL_G, LABEL_B = 0.6, 0.6, 0.6
local VALUE_R, VALUE_G, VALUE_B = 1, 1, 1

-- The switchable lines, in the order the page lists them.
local LINES = {
    { name = "vendor", label = "Vendor price", default = true,
      about = "What a merchant pays for the item, and for the whole stack when the tooltip shows one." },
    { name = "auction", label = "Auction price", default = true,
      about = "The cheapest auction price you've seen on this realm and faction (from PriceMemory), and for the whole stack. Not shown on bound items; marked (old) after 10 days." },
    { name = "count", label = "Counts", default = true,
      about = "How many you have on every character, in bags, bank, and worn (from ItemFinder)." },
    { name = "profession", label = "Profession guide", default = true,
      about = "Which profession guide steps use the item as a material." },
    { name = "id", label = "Item ID and level", default = false,
      about = "The item's ID number and item level." },
    { name = "npc", label = "NPC ID", default = false,
      about = "The ID number of the creature under your mouse." },
}
local LINE_BY_NAME = {}
for _, line in ipairs(LINES) do
    LINE_BY_NAME[line.name] = line
end

local function Safe(value)
    if issecretvalue and issecretvalue(value) then
        return nil
    end
    return value
end

local function Print(text)
    if ForeverHub_Receive then
        return ForeverHub_Receive("Tooltips", text)
    end
    -- No hub window to show it in: stay quiet rather than fill the chat.
end

-- Only choices you made are saved, so a line you never touched follows its default.
local function IsOn(name)
    local db = TooltipsDB
    if type(db) == "table" and type(db[name]) == "boolean" then
        return db[name]
    end
    return LINE_BY_NAME[name].default
end

----------------------------------------------------------------------------------------------------
-- Formatting

local function PlainMoney(copper)
    local gold, silver, rest = math.floor(copper / 10000), math.floor(copper / 100) % 100, copper % 100
    local parts = {}
    if gold > 0 then
        parts[#parts + 1] = "|cffffd700" .. gold .. "g|r"
    end
    if silver > 0 then
        parts[#parts + 1] = "|cffc7c7cf" .. silver .. "s|r"
    end
    if rest > 0 or #parts == 0 then
        parts[#parts + 1] = "|cffeda55f" .. rest .. "c|r"
    end
    return table.concat(parts, " ")
end

local function Money(copper)
    copper = math.floor(copper + 0.5)
    local format = (C_CurrencyInfo and C_CurrencyInfo.GetCoinTextureString) or GetCoinTextureString
    if type(format) == "function" then
        local ok, text = pcall(format, copper)
        text = ok and Safe(text)
        if type(text) == "string" and text ~= "" then
            return text
        end
    end
    return PlainMoney(copper)
end

local function Age(seconds)
    if seconds < SECONDS_PER_HOUR then
        return "under an hour ago"
    elseif seconds < SECONDS_PER_DAY then
        return string.format("%dh ago", math.floor(seconds / SECONDS_PER_HOUR))
    end
    local days = math.floor(seconds / SECONDS_PER_DAY)
    return days == 1 and "1 day ago" or string.format("%d days ago", days)
end

local function AddPair(tooltip, label, value)
    tooltip:AddDoubleLine(label, value, LABEL_R, LABEL_G, LABEL_B, VALUE_R, VALUE_G, VALUE_B)
end

----------------------------------------------------------------------------------------------------
-- Item facts, looked up once per item ID

local itemCache = {}

local function ItemFacts(id)
    local facts = itemCache[id]
    if facts then
        return facts
    end
    local getInfo = (C_Item and C_Item.GetItemInfo) or GetItemInfo
    if type(getInfo) ~= "function" then
        return nil
    end
    local ok, name, _, _, level, _, _, _, _, _, _, sellPrice, classID, _, bindType = pcall(getInfo, id)
    if not ok then
        return nil
    end
    name, level, sellPrice, classID, bindType = Safe(name), Safe(level), Safe(sellPrice), Safe(classID), Safe(bindType)
    -- An item the game hasn't loaded yet returns nothing; ask again next time instead of remembering that.
    if type(name) ~= "string" or name == "" then
        return nil
    end
    facts = {
        name = name,
        level = type(level) == "number" and level or nil,
        sellPrice = type(sellPrice) == "number" and sellPrice or nil,
        classID = type(classID) == "number" and classID or nil,
        bindType = type(bindType) == "number" and bindType or nil,
    }
    itemCache[id] = facts
    return facts
end

-- Where the game filled this tooltip from: the documented C_TooltipInfo getter name and its arguments
-- (read only). nil when the tooltip doesn't say.
local function Source(tooltip)
    local getInfo = tooltip.GetProcessingTooltipInfo or tooltip.GetPrimaryTooltipInfo
    local info = type(getInfo) == "function" and getInfo(tooltip)
    if type(info) ~= "table" or type(info.getterArgs) ~= "table" then
        return nil
    end
    return Safe(info.getterName), Safe(info.getterArgs[1]), Safe(info.getterArgs[2])
end

-- The n-th value a function returns, or nil when it is missing or fails.
local function Pick(position, fn, ...)
    if type(fn) ~= "function" then
        return nil
    end
    local results = { pcall(fn, ...) }
    if not results[1] then
        return nil
    end
    return Safe(results[position + 1])
end

-- How many are in the slot this tooltip shows. Unknown sources give nil, and the stack part is left out.
-- Mail, trade and loot-roll counts come from the game's older global functions; they are only used
-- when they exist (they aren't in this client's API documentation).
local function StackCount(tooltip, data)
    local count = Safe(data.stackCount)
    if type(count) == "number" then
        return count
    end
    local getter, a, b = Source(tooltip)
    if not getter then
        return nil
    end
    if getter == "GetBagItem" and type(a) == "number" and type(b) == "number" and C_Container then
        local item = C_Container.GetContainerItemInfo(a, b)
        count = item and Safe(item.stackCount)
    elseif getter == "GetLootItem" and type(a) == "number" and GetLootSlotInfo then
        count = Safe(select(3, GetLootSlotInfo(a)))
    elseif getter == "GetInventoryItem" and type(a) == "string" and type(b) == "number" and GetInventoryItemCount then
        count = Safe(GetInventoryItemCount(a, b))
    elseif getter == "GetBuybackItem" and type(a) == "number" and GetBuybackItemInfo then
        count = Safe(select(4, GetBuybackItemInfo(a)))
    elseif getter == "GetMerchantItem" and type(a) == "number" and C_MerchantFrame and C_MerchantFrame.GetItemInfo then
        -- How many one purchase gives you.
        local ok, item = pcall(C_MerchantFrame.GetItemInfo, a)
        item = ok and Safe(item)
        count = type(item) == "table" and Safe(item.stackCount) or nil
    elseif getter == "GetInboxItem" and type(a) == "number" then
        count = Pick(4, GetInboxItem, a, type(b) == "number" and b or 1)
    elseif getter == "GetSendMailItem" and type(a) == "number" then
        count = Pick(4, GetSendMailItem, a)
    elseif getter == "GetTradePlayerItem" and type(a) == "number" then
        count = Pick(3, GetTradePlayerItemInfo, a)
    elseif getter == "GetTradeTargetItem" and type(a) == "number" then
        count = Pick(3, GetTradeTargetItemInfo, a)
    elseif getter == "GetLootRollItem" and type(a) == "number" then
        count = Pick(3, GetLootRollItemInfo, a)
    end
    return type(count) == "number" and count > 0 and count or nil
end

-- Item binds that can never go on the auction house (Enum.ItemBind): on pickup, quest, account-bound.
local NEVER_TRADED = { [1] = true, [4] = true, [7] = true, [8] = true }

-- A copy that can't be auctioned: bind-on-pickup and quest items, a bag copy the game marks bound, or
-- something you're wearing. A bind-on-equip item still on the market is fine.
local function IsBound(tooltip, facts)
    if facts and facts.bindType and NEVER_TRADED[facts.bindType] then
        return true
    end
    local getter, a, b = Source(tooltip)
    if getter == "GetBagItem" and type(a) == "number" and type(b) == "number" and C_Container then
        local item = C_Container.GetContainerItemInfo(a, b)
        return type(item) == "table" and Safe(item.isBound) == true
    elseif getter == "GetInventoryItem" and a == "player" and type(b) == "number" then
        -- Equipment slots 1-19; worn gear is always bound.
        return b >= 1 and b <= 19
    elseif getter == "GetLootRollItem" and type(a) == "number" then
        return Pick(5, GetLootRollItemInfo, a) == true
    end
    return false
end

-- The game already printing a sell price on this tooltip, so ours would only repeat it.
local function GameShowsSellPrice(data)
    local sellType = Enum and Enum.TooltipDataLineType and Safe(Enum.TooltipDataLineType.SellPrice)
    local lines = Safe(data.lines)
    if type(sellType) ~= "number" or type(lines) ~= "table" then
        return false
    end
    for _, line in ipairs(lines) do
        if type(line) == "table" and Safe(line.type) == sellType then
            return true
        end
    end
    return false
end

-- PriceMemory and ItemFinder can add their own lines; this reads what's already on the tooltip so
-- the same fact isn't shown twice.
local function LinesAlreadyThere(tooltip)
    local found = {}
    local name = tooltip.GetName and Safe(tooltip:GetName())
    local count = tooltip.NumLines and Safe(tooltip:NumLines())
    if type(name) ~= "string" or type(count) ~= "number" then
        return found
    end
    for index = 1, count do
        local fontString = _G[name .. "TextLeft" .. index]
        local text = fontString and fontString.GetText and Safe(fontString:GetText())
        if type(text) == "string" then
            if text:find("^Auction, seen ") then
                found.auction = true
            elseif text:find("^Owned: ") then
                found.count = true
            end
        end
    end
    return found
end

----------------------------------------------------------------------------------------------------
-- The lines

local function AddVendorLine(tooltip, data, facts)
    local price = facts.sellPrice
    if not price or GameShowsSellPrice(data) then
        return
    end
    if price <= 0 then
        -- Quest items can't be sold either, but everyone knows that; saying so would be noise.
        if facts.classID ~= QUEST_ITEM_CLASS then
            tooltip:AddLine("No sell price", LABEL_R, LABEL_G, LABEL_B)
        end
        return
    end
    local text = Money(price)
    local count = StackCount(tooltip, data)
    if count and count > 1 then
        text = text .. "  |cff999999x" .. count .. ":|r " .. Money(price * count)
    end
    AddPair(tooltip, "Sells for", text)
end

-- Only used when PriceMemory isn't loaded: the same "Realm-Faction" key it files prices under.
local function ScopeKey()
    local realm = GetRealmName and Safe(GetRealmName())
    local faction = UnitFactionGroup and Safe(UnitFactionGroup("player"))
    if type(realm) == "string" and realm ~= "" and type(faction) == "string" and faction ~= "" then
        return realm .. "-" .. faction
    end
end

local function ValidPrice(entry)
    return type(entry) == "table" and type(entry.price) == "number" and entry.price > 0 and type(entry.seen) == "number"
end

local STALE_SECONDS = 10 * SECONDS_PER_DAY

-- { price, seen, legacy, stale } from PriceMemory's shared lookup, or read straight from its saved
-- data when that lookup isn't there.
local function AuctionRecord(id)
    if type(PriceMemory_Get) == "function" then
        local ok, record = pcall(PriceMemory_Get, id)
        if ok and type(record) == "table" and ValidPrice(record) then
            return record
        end
        return nil
    end
    local db = PriceMemoryDB
    if type(db) ~= "table" then
        return nil
    end
    local scope = ScopeKey()
    local prices = scope and db[scope]
    local entry = type(prices) == "table" and prices[id]
    local legacy = false
    -- Older saves sit directly under the item ID, with no realm or faction.
    if not ValidPrice(entry) then
        entry, legacy = db[id], true
    end
    if not ValidPrice(entry) then
        return nil
    end
    local now = time and Safe(time())
    local stale = type(now) == "number" and now - entry.seen > STALE_SECONDS
    return { price = entry.price, seen = entry.seen, legacy = legacy, stale = stale }
end

local function AddAuctionLine(tooltip, data, id, facts)
    -- A bound copy can't be sold there, so a price would only mislead.
    if IsBound(tooltip, facts) then
        return
    end
    local record = AuctionRecord(id)
    if not record then
        return
    end
    local now = time and Safe(time())
    local text = Money(record.price)
    if type(now) == "number" then
        text = text .. " |cff999999(" .. Age(math.max(now - record.seen, 0)) .. ")|r"
    end
    if record.legacy then
        text = text .. " |cff999999(older save)|r"
    end
    if record.stale then
        text = text .. " |cffff9933(old)|r"
    end
    local count = StackCount(tooltip, data)
    if count and count > 1 then
        text = text .. "  |cff999999x" .. count .. ":|r " .. Money(record.price * count)
    end
    AddPair(tooltip, "Auction", text)
end

local function ShortName(characterKey)
    return characterKey:match("^[^-]+") or characterKey
end

local function MyKey()
    local name = UnitName and Safe(UnitName("player"))
    local realm = GetRealmName and Safe(GetRealmName())
    return (name or "Unknown") .. "-" .. (realm or "Unknown")
end

local function CountIn(places, name)
    local value = type(places) == "table" and places[name]
    return type(value) == "number" and value or 0
end

local function AddCountLine(tooltip, itemName)
    local db = ItemFinderDB
    if type(db) ~= "table" then
        return
    end
    local myKey = MyKey()
    local total, mine, others = 0, nil, {}
    for key, record in pairs(db) do
        if type(key) == "string" and type(record) == "table" then
            local bags, bank, worn = CountIn(record.bags, itemName), CountIn(record.bank, itemName), CountIn(record.gear, itemName)
            local sum = bags + bank + worn
            if sum > 0 then
                total = total + sum
                if key == myKey then
                    local where = {}
                    if bags > 0 then where[#where + 1] = bags .. " bags" end
                    if bank > 0 then where[#where + 1] = bank .. " bank" end
                    if worn > 0 then where[#where + 1] = worn .. " worn" end
                    mine = ShortName(key) .. " " .. table.concat(where, ", ")
                else
                    others[#others + 1] = ShortName(key) .. " " .. sum
                end
            end
        end
    end
    if total == 0 then
        return
    end
    table.sort(others)
    if mine then
        table.insert(others, 1, mine)
    end
    AddPair(tooltip, "You have", total .. " |cff999999(" .. table.concat(others, "; ") .. ")|r")
end

-- Which profession guide steps use each item, worked out once per guide table.
local professionIndex, indexedGuide

local function StepRange(step, number)
    local low = Safe(step.from) or Safe(step.min) or Safe(step.start)
    local high = Safe(step.to) or Safe(step.max) or Safe(step.stop)
    if low and high then
        return low .. "-" .. high
    end
    local range = Safe(step.range) or Safe(step.skill)
    if range then
        return tostring(range)
    end
    return "#" .. number
end

local function BuildProfessionIndex(guide)
    local index = {}
    for key, profession in pairs(guide) do
        if type(profession) == "table" and type(profession.steps) == "table" then
            local title = Safe(profession.name) or Safe(profession.label) or Safe(profession.profession)
            if type(title) ~= "string" and type(key) == "number" and C_TradeSkillUI and C_TradeSkillUI.GetTradeSkillDisplayName then
                local ok, shown = pcall(C_TradeSkillUI.GetTradeSkillDisplayName, key)
                title = ok and Safe(shown) or nil
            end
            if type(title) ~= "string" or title == "" then
                title = type(key) == "string" and key or "Profession"
            end
            for number, step in ipairs(profession.steps) do
                if type(step) == "table" and type(step.mats) == "table" then
                    local size = #step.mats
                    for matKey, mat in pairs(step.mats) do
                        local id
                        if type(mat) == "table" then
                            id = Safe(mat.itemID) or Safe(mat.id)
                        elseif type(mat) == "number" then
                            -- A plain list holds item IDs; a keyed table maps item ID to amount.
                            id = (type(matKey) == "number" and matKey >= 1 and matKey <= size) and mat or matKey
                        end
                        if type(id) == "number" then
                            local uses = index[id] or {}
                            uses[title .. " guide step " .. StepRange(step, number)] = true
                            index[id] = uses
                        end
                    end
                end
            end
        end
    end
    -- Saved tables have no order; sort so the same item always reads the same.
    for id, uses in pairs(index) do
        local list = {}
        for text in pairs(uses) do
            list[#list + 1] = text
        end
        table.sort(list)
        index[id] = list
    end
    return index
end

local function AddProfessionLine(tooltip, id)
    local guide = ProfessionGuideData
    if type(guide) ~= "table" then
        return
    end
    if guide ~= indexedGuide or not professionIndex then
        indexedGuide = guide
        local ok, index = pcall(BuildProfessionIndex, guide)
        professionIndex = ok and index or {}
    end
    local uses = professionIndex[id]
    if not uses or #uses == 0 then
        return
    end
    local text = uses[1]
    if #uses == 2 then
        text = text .. ", " .. uses[2]
    elseif #uses > 2 then
        text = text .. ", " .. uses[2] .. string.format(" |cff999999+%d more|r", #uses - 2)
    end
    AddPair(tooltip, "Needed", text)
end

local function ShownTooltip(tooltip)
    return tooltip ~= nil and (tooltip == GameTooltip or tooltip == ItemRefTooltip)
end

local function ItemBody(tooltip, data)
    if not ShownTooltip(tooltip) or type(data) ~= "table" then
        return
    end
    local id = Safe(data.id)
    if type(id) ~= "number" and TooltipUtil and TooltipUtil.GetDisplayedItem then
        local _, _, shownID = TooltipUtil.GetDisplayedItem(tooltip)
        id = Safe(shownID)
    end
    if type(id) ~= "number" then
        return
    end
    local facts = ItemFacts(id)
    local already = {}
    if IsOn("auction") or IsOn("count") then
        local ok, found = pcall(LinesAlreadyThere, tooltip)
        already = ok and found or already
    end

    -- Each line on its own, so one helper's odd saved data can't take the other lines with it.
    if facts and IsOn("vendor") then
        pcall(AddVendorLine, tooltip, data, facts)
    end
    if IsOn("auction") and not already.auction then
        pcall(AddAuctionLine, tooltip, data, id, facts)
    end
    if facts and IsOn("count") and not already.count then
        pcall(AddCountLine, tooltip, facts.name)
    end
    if IsOn("profession") then
        pcall(AddProfessionLine, tooltip, id)
    end
    if IsOn("id") then
        AddPair(tooltip, "Item ID", tostring(id))
        if facts and facts.level then
            AddPair(tooltip, "Item level", tostring(facts.level))
        end
    end
end

local function NpcID(guid)
    if type(guid) ~= "string" then
        return nil
    end
    local kind, id = guid:match("^(%a+)%-[^-]*%-[^-]*%-[^-]*%-[^-]*%-(%d+)")
    if kind == "Creature" or kind == "Vehicle" then
        return tonumber(id)
    end
end

local function UnitBody(tooltip, data)
    if not IsOn("npc") or not ShownTooltip(tooltip) or type(data) ~= "table" then
        return
    end
    local guid = Safe(data.guid)
    if type(guid) ~= "string" and tooltip.GetUnit and UnitGUID then
        local _, unit = tooltip:GetUnit()
        unit = Safe(unit)
        guid = type(unit) == "string" and Safe(UnitGUID(unit)) or nil
    end
    local id = NpcID(guid)
    if id then
        AddPair(tooltip, "NPC ID", tostring(id))
    end
end

-- A tooltip error would repeat on every mouse-over, so problems here are swallowed.
-- Switched off on the hub's Manage page: add nothing at all.
local function SwitchedOff()
    return ForeverHub_IsOff and ForeverHub_IsOff("Tooltips") == true
end

local function OnItemTooltip(tooltip, data)
    if not SwitchedOff() then
        pcall(ItemBody, tooltip, data)
    end
end

local function OnUnitTooltip(tooltip, data)
    if not SwitchedOff() then
        pcall(UnitBody, tooltip, data)
    end
end

local function Register()
    local processor = TooltipDataProcessor
    local types = Enum and Enum.TooltipDataType
    if type(processor) ~= "table" or type(processor.AddTooltipPostCall) ~= "function" or type(types) ~= "table" then
        return false
    end
    local any = false
    if types.Item ~= nil then
        any = pcall(processor.AddTooltipPostCall, types.Item, OnItemTooltip) or any
    end
    if types.Unit ~= nil then
        any = pcall(processor.AddTooltipPostCall, types.Unit, OnUnitTooltip) or any
    end
    return any
end

local registered = false

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN")
events:SetScript("OnEvent", function()
    if type(TooltipsDB) ~= "table" then
        TooltipsDB = {}
    end
    if not registered then
        registered = Register()
    end
end)

----------------------------------------------------------------------------------------------------
-- Page

local function NameList()
    local names = {}
    for _, line in ipairs(LINES) do
        names[#names + 1] = line.name
    end
    return table.concat(names, ", ")
end

local function ShowPage()
    if not registered then
        Print("|cffff9933This game version doesn't offer the tooltip hook, so no lines are added.|r")
    end
    Print("Extra lines on item and creature tooltips. They only add information.")
    Print(" ")
    for _, line in ipairs(LINES) do
        local state = IsOn(line.name) and "|cff33ff33on |r" or "|cff999999off|r"
        Print(string.format("%s  |cffffffff%s|r |cff999999(%s)|r - %s", state, line.label, line.name, line.about))
    end
    Print(" ")
    Print("|cff999999The auction and count lines stay out of the way while PriceMemory or ItemFinder already shows the same thing on a tooltip. A vendor price the game shows itself isn't repeated.|r")
    Print("|cff999999Type: off vendor   Or: on id   Or: toggle npc|r")
end

SLASH_TOOLTIPS1 = "/fhtips"
SlashCmdList.TOOLTIPS = function(message)
    local text = type(message) == "string" and message:lower():match("^%s*(.-)%s*$") or ""
    if text == "" then
        ShowPage()
        return
    end
    local verb, name = text:match("^(%a+)%s+(%a+)$")
    if not verb then
        verb, name = "toggle", text
    end
    local line = LINE_BY_NAME[name]
    if not line or not (verb == "on" or verb == "off" or verb == "toggle") then
        Print("Type on, off, or toggle and a line name: " .. NameList() .. ".")
        return
    end
    if type(TooltipsDB) ~= "table" then
        TooltipsDB = {}
    end
    local value
    if verb == "toggle" then
        value = not IsOn(name)
    else
        value = verb == "on"
    end
    TooltipsDB[name] = value
    Print(string.format("%s is now %s.", line.label, value and "|cff33ff33on|r" or "|cff999999off|r"))
end
