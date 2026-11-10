-- PriceMemory: remembers the auction prices your own searches showed, and what merchants charge.
-- Read-only: it only reads results the game already handed to Blizzard's auction house window after a
-- search YOU made. It never sends a search, never asks for more results, and never posts, bids, buys or
-- cancels. It never touches Blizzard's frames.
--
-- Saved layout (PriceMemoryDB, account-wide):
--   ["Realm-Faction"] = { [itemID] = entry }   -- see ScopeKey()
--   [itemID] = entry                           -- older saves, or a moment the realm/faction was hidden
--   __vendor = { [itemID] = { buy = copper per unit, seen = time } }
-- entry = {
--   price = latest lowest unit price, seen = when (these two are all that older versions wrote and read),
--   qty = how many were listed then,
--   days = { [dayNumber] = { min = lowest, max = highest of the lowest prices seen that day, qty = most listed } },
--   suffixes = { [itemSuffix] = { price, seen, qty } }   -- random-suffix variants, from item searches
-- }

local SECONDS_PER_HOUR, SECONDS_PER_DAY = 3600, 86400
local HISTORY_DAYS = 14          -- days of min/max/quantity kept per item
local MAX_SUFFIXES = 20          -- suffix variants kept per item
local KEEP_SECONDS = 30 * SECONDS_PER_DAY   -- items not seen for this long are dropped at login
local STALE_SECONDS = 10 * SECONDS_PER_DAY  -- older than this counts as an old price
local BROWSE_BATCH = 500         -- a browse list longer than this was already read as it grew
local MAX_MERCHANT_ITEMS = 200
local VENDOR_KEY = "__vendor"

local function Safe(value)
    if issecretvalue and issecretvalue(value) then
        return nil
    end
    return value
end

local function Number(value)
    value = Safe(value)
    return type(value) == "number" and value or nil
end

local function Now()
    return Number(time and time()) or 0
end

local function DayNumber(when)
    return math.floor(when / SECONDS_PER_DAY)
end

local function FormatMoney(copper)
    return string.format("%dg %ds %dc", math.floor(copper / 10000), math.floor(copper / 100) % 100, copper % 100)
end

local function FormatAge(seconds)
    if seconds < SECONDS_PER_HOUR then
        return "under an hour ago"
    elseif seconds < SECONDS_PER_DAY then
        return string.format("%dh ago", math.floor(seconds / SECONDS_PER_HOUR))
    end
    return string.format("%dd ago", math.floor(seconds / SECONDS_PER_DAY))
end

----------------------------------------------------------------------------------------------------
-- Which auction house the prices belong to

-- The one place that decides where prices are filed. It is "Realm-Faction", as in every earlier version.
-- NOT VERIFIED on World of Warcraft: Forever:
--   * whether the auction house is shared by both factions (the modern auction house usually is; a
--     Classic-style one is not). Check: search the same commodity on an Alliance and a Horde character
--     a few minutes apart. Same list = shared, and the faction part should go.
--   * whether several realm names share one auction house (connected realms, or one per ruleset).
-- If either check says so, change only this function (for example, drop the faction), and keep reading
-- the old keys as a fallback in Lookup() so nothing saved is lost.
local function ScopeKey()
    local realm = GetRealmName and Safe(GetRealmName())
    local faction = UnitFactionGroup and Safe(UnitFactionGroup("player"))
    if type(realm) == "string" and realm ~= "" and type(faction) == "string" and faction ~= "" then
        return realm .. "-" .. faction
    end
end

-- The table this auction house's prices go in, or the flat table when it can't be told.
local function PriceTable(create)
    local scope = ScopeKey()
    if not scope then
        return PriceMemoryDB, nil
    end
    if type(PriceMemoryDB[scope]) ~= "table" and create then
        PriceMemoryDB[scope] = {}
    end
    return PriceMemoryDB[scope], scope
end

local function ValidEntry(entry)
    return type(entry) == "table" and type(entry.price) == "number" and entry.price > 0 and type(entry.seen) == "number"
end

----------------------------------------------------------------------------------------------------
-- Recording

-- Keeps at most HISTORY_DAYS days, the newest ones.
local function PruneDays(days, today)
    local keys = {}
    for day in pairs(days) do
        if type(day) ~= "number" or type(days[day]) ~= "table" or day <= today - HISTORY_DAYS then
            days[day] = nil
        else
            keys[#keys + 1] = day
        end
    end
    if #keys > HISTORY_DAYS then
        table.sort(keys)
        for index = 1, #keys - HISTORY_DAYS do
            days[keys[index]] = nil
        end
    end
end

local function EntryFor(prices, id)
    local entry = prices[id]
    if type(entry) ~= "table" then
        entry = {}
        prices[id] = entry
    end
    return entry
end

-- One observation: the lowest unit price a search showed for an item, and how many were listed.
local function Record(prices, id, price, quantity, now)
    local entry = EntryFor(prices, id)
    entry.price, entry.seen = price, now
    if quantity then
        entry.qty = quantity
    end
    if type(entry.days) ~= "table" then
        entry.days = {}
    end
    local today = DayNumber(now)
    local day = entry.days[today]
    if type(day) ~= "table" then
        day = {}
        entry.days[today] = day
    end
    day.min = (type(day.min) == "number" and day.min < price) and day.min or price
    day.max = (type(day.max) == "number" and day.max > price) and day.max or price
    if quantity and not (type(day.qty) == "number" and day.qty >= quantity) then
        day.qty = quantity
    end
    PruneDays(entry.days, today)
end

-- A random-suffix variant ("of the Bear") gets its own price, and lowers the item's price if cheaper.
local function RecordSuffix(prices, id, suffix, price, quantity, now)
    local entry = EntryFor(prices, id)
    if type(entry.suffixes) ~= "table" then
        entry.suffixes = {}
    end
    entry.suffixes[suffix] = { price = price, seen = now, qty = quantity }
    local count, oldestKey, oldestSeen = 0, nil, nil
    for key, value in pairs(entry.suffixes) do
        count = count + 1
        local seen = type(value) == "table" and type(value.seen) == "number" and value.seen or 0
        if not oldestSeen or seen < oldestSeen then
            oldestKey, oldestSeen = key, seen
        end
    end
    if count > MAX_SUFFIXES and oldestKey ~= nil then
        entry.suffixes[oldestKey] = nil
    end
    local seenToday = ValidEntry(entry) and DayNumber(entry.seen) == DayNumber(now)
    if not seenToday or price <= entry.price then
        Record(prices, id, price, nil, now)
    end
end

----------------------------------------------------------------------------------------------------
-- Browse results (the list after you press Search)

-- Lowest price and quantity per item for the browse list now on screen. A new search starts it again;
-- rows added later (more pages) only lower it or add to the quantity.
local browse = {}

local function ReadBrowseRows(rows)
    if type(rows) ~= "table" or not PriceMemoryDB then
        return
    end
    local prices = PriceTable(true)
    local now = Now()
    local changed = {}
    for _, row in ipairs(rows) do
        row = Safe(row)
        local itemKey = type(row) == "table" and Safe(row.itemKey)
        local id = type(itemKey) == "table" and Number(itemKey.itemID)
        local price = type(row) == "table" and Number(row.minPrice)
        local quantity = type(row) == "table" and Number(row.totalQuantity)
        -- A row with nothing listed has no real price.
        if id and price and price > 0 and quantity ~= 0 then
            -- Random-suffix versions share one item ID, so one search can list it several times. Keep the cheapest.
            local seen = browse[id]
            if not seen then
                seen = {}
                browse[id] = seen
            end
            if not seen.price or price < seen.price then
                seen.price = price
                changed[id] = true
            end
            if quantity then
                seen.qty = (seen.qty or 0) + quantity
                changed[id] = true
            end
        end
    end
    for id in pairs(changed) do
        Record(prices, id, browse[id].price, browse[id].qty, now)
    end
end

local function OnBrowseUpdated()
    if not (C_AuctionHouse and C_AuctionHouse.GetBrowseResults) then
        return
    end
    local rows = C_AuctionHouse.GetBrowseResults()
    rows = Safe(rows)
    if type(rows) ~= "table" then
        return
    end
    -- Past one batch, the rows were already read as they were added; this is only a refresh.
    if #rows > BROWSE_BATCH then
        return
    end
    browse = {}
    ReadBrowseRows(rows)
end

----------------------------------------------------------------------------------------------------
-- Commodity results (you clicked a stackable item such as cloth or herbs)

-- How many rows of each search were already read, so added rows are read only once.
local commodityRead, commodityLow = {}, {}

local function ReadCommodity(itemID, fresh)
    local api = C_AuctionHouse
    if not (PriceMemoryDB and api and api.GetNumCommoditySearchResults and api.GetCommoditySearchResultInfo) then
        return
    end
    itemID = Number(itemID)
    if not itemID then
        return
    end
    if fresh then
        commodityRead[itemID], commodityLow[itemID] = 0, nil
    end
    local total = Number(api.GetNumCommoditySearchResults(itemID)) or 0
    local low = commodityLow[itemID]
    for index = (commodityRead[itemID] or 0) + 1, total do
        local row = Safe(api.GetCommoditySearchResultInfo(itemID, index))
        local price = type(row) == "table" and Number(row.unitPrice)
        local quantity = type(row) == "table" and Number(row.quantity)
        if price and price > 0 and quantity ~= 0 and not (low and low <= price) then
            low = price
        end
    end
    commodityRead[itemID] = math.max(total, commodityRead[itemID] or 0)
    commodityLow[itemID] = low
    if low then
        local quantity = api.GetCommoditySearchResultsQuantity and Number(api.GetCommoditySearchResultsQuantity(itemID))
        Record(PriceTable(true), itemID, low, quantity, Now())
    end
end

----------------------------------------------------------------------------------------------------
-- Item results (you clicked gear or another non-stackable item)

local itemRead, itemLow = {}, {}

local function KeyText(itemKey)
    return string.format("%d:%d:%d:%d", Number(itemKey.itemID) or 0, Number(itemKey.itemLevel) or 0,
        Number(itemKey.itemSuffix) or 0, Number(itemKey.battlePetSpeciesID) or 0)
end

local function ReadItems(itemKey, fresh)
    local api = C_AuctionHouse
    if not (PriceMemoryDB and api and api.GetNumItemSearchResults and api.GetItemSearchResultInfo) then
        return
    end
    itemKey = Safe(itemKey)
    local id = type(itemKey) == "table" and Number(itemKey.itemID)
    if not id then
        return
    end
    local text = KeyText(itemKey)
    if fresh then
        itemRead[text], itemLow[text] = 0, nil
    end
    local total = Number(api.GetNumItemSearchResults(itemKey)) or 0
    local low = itemLow[text]
    for index = (itemRead[text] or 0) + 1, total do
        local row = Safe(api.GetItemSearchResultInfo(itemKey, index))
        local buyout = type(row) == "table" and Number(row.buyoutAmount)
        local quantity = type(row) == "table" and Number(row.quantity) or 1
        -- Bid-only auctions have no buyout and say nothing firm about the price.
        -- Assumed: buyoutAmount covers the whole auction, so it is split by its quantity (almost always 1).
        if buyout and buyout > 0 and quantity > 0 then
            local unit = math.floor(buyout / quantity + 0.5)
            if not (low and low <= unit) then
                low = unit
            end
        end
    end
    itemRead[text] = math.max(total, itemRead[text] or 0)
    itemLow[text] = low
    if not low then
        return
    end
    local quantity = api.GetItemSearchResultsQuantity and Number(api.GetItemSearchResultsQuantity(itemKey))
    local suffix = Number(itemKey.itemSuffix) or 0
    local prices, now = PriceTable(true), Now()
    if suffix ~= 0 then
        RecordSuffix(prices, id, suffix, low, quantity, now)
    else
        Record(prices, id, low, quantity, now)
    end
end

----------------------------------------------------------------------------------------------------
-- Merchant buy prices (only items a merchant always has: unlimited stock)

local function MerchantItemID(index)
    if GetMerchantItemID then
        local ok, id = pcall(GetMerchantItemID, index)
        id = ok and Number(id)
        if id then
            return id
        end
    end
    if C_TooltipInfo and C_TooltipInfo.GetMerchantItem then
        local ok, data = pcall(C_TooltipInfo.GetMerchantItem, index)
        data = ok and Safe(data)
        return type(data) == "table" and Number(data.id) or nil
    end
end

local function ReadMerchant()
    if not (PriceMemoryDB and C_MerchantFrame and C_MerchantFrame.GetItemInfo) then
        return
    end
    -- GetMerchantNumItems isn't in this client's API documentation; without it, read until a slot is empty.
    local count, known = MAX_MERCHANT_ITEMS, false
    if GetMerchantNumItems then
        local ok, n = pcall(GetMerchantNumItems)
        n = ok and Number(n)
        if n then
            count, known = math.min(n, MAX_MERCHANT_ITEMS), true
        end
    end
    if type(PriceMemoryDB[VENDOR_KEY]) ~= "table" then
        PriceMemoryDB[VENDOR_KEY] = {}
    end
    local vendor, now = PriceMemoryDB[VENDOR_KEY], Now()
    for index = 1, count do
        local ok, info = pcall(C_MerchantFrame.GetItemInfo, index)
        info = ok and Safe(info)
        if type(info) ~= "table" and not known then
            break
        end
        info = type(info) == "table" and info or {}
        local price, stack, available = Number(info.price), Number(info.stackCount), Number(info.numAvailable)
        local extended = Safe(info.hasExtendedCost)
        -- -1 available means the merchant never runs out. Items that also cost tokens aren't plain gold.
        if available == -1 and price and price > 0 and not extended then
            local id = MerchantItemID(index)
            if id then
                vendor[id] = { buy = price / ((stack and stack > 0) and stack or 1), seen = now }
            end
        end
    end
end

----------------------------------------------------------------------------------------------------
-- The shared lookup

local function Lookup(id)
    if type(PriceMemoryDB) ~= "table" then
        return nil
    end
    local prices = PriceTable(false)
    local entry = type(prices) == "table" and prices[id] or nil
    local legacy = false
    -- An older entry without a realm and faction is still used, but marked so it isn't taken as local.
    if not ValidEntry(entry) and prices ~= PriceMemoryDB then
        local flat = PriceMemoryDB[id]
        if ValidEntry(flat) then
            entry, legacy = flat, true
        end
    end
    return entry, legacy
end

-- PriceMemory_Get(itemID [, itemSuffix]) -> table or nil
--   price = latest lowest unit price in copper (nil if only a merchant price is known), seen = when,
--   ageDays = whole days since, stale = older than 10 days, legacy = from an older save without a realm,
--   min / max = lowest and highest of the daily lowest prices over the kept days (the price itself when
--   there is no history yet), quantity = how many were listed the last time, days = days with history,
--   vendorBuy = what a merchant charges per unit (unlimited stock only),
--   suffixPrice / suffixSeen = the price of that random-suffix variant, when asked for and known.
function PriceMemory_Get(itemID, itemSuffix)
    itemID = Number(itemID)
    if not itemID or type(PriceMemoryDB) ~= "table" then
        return nil
    end
    local result
    local entry, legacy = Lookup(itemID)
    if ValidEntry(entry) then
        local now = Now()
        local age = math.max(now - entry.seen, 0)
        result = {
            price = entry.price, seen = entry.seen, ageDays = math.floor(age / SECONDS_PER_DAY),
            stale = age > STALE_SECONDS, legacy = legacy,
            quantity = type(entry.qty) == "number" and entry.qty or nil, days = 0,
        }
        if type(entry.days) == "table" then
            for _, day in pairs(entry.days) do
                if type(day) == "table" then
                    local low, high = Number(day.min), Number(day.max)
                    if low then
                        result.min = math.min(result.min or low, low)
                        result.days = result.days + 1
                    end
                    if high then
                        result.max = math.max(result.max or high, high)
                    end
                end
            end
        end
        result.min, result.max = result.min or entry.price, result.max or entry.price
        local suffix = Number(itemSuffix)
        local variant = suffix and type(entry.suffixes) == "table" and entry.suffixes[suffix]
        if ValidEntry(variant) then
            result.suffixPrice, result.suffixSeen = variant.price, variant.seen
        end
    end
    local vendor = type(PriceMemoryDB[VENDOR_KEY]) == "table" and PriceMemoryDB[VENDOR_KEY][itemID]
    if type(vendor) == "table" and type(vendor.buy) == "number" and vendor.buy > 0 then
        result = result or {}
        result.vendorBuy = vendor.buy
    end
    return result
end

----------------------------------------------------------------------------------------------------
-- Own tooltip line, only when the Tooltips helper isn't there to show it

local function OnTooltip(tooltip)
    if not PriceMemoryDB or (tooltip ~= GameTooltip and tooltip ~= ItemRefTooltip) then
        return
    end
    local _, _, id = TooltipUtil.GetDisplayedItem(tooltip)
    local record = PriceMemory_Get(id)
    if record and record.price then
        local note = record.legacy and " (older save, realm/faction unknown)" or ""
        if record.stale then
            note = note .. " (old)"
        end
        tooltip:AddLine(string.format("Auction, seen %s: %s each%s", FormatAge(Now() - record.seen), FormatMoney(record.price), note), 0.9, 0.8, 0.4)
    end
end

-- A price from months ago says little, and the file would otherwise only ever grow.
local function Prune()
    local now = Now()
    local cutoff, today = now - KEEP_SECONDS, DayNumber(now)
    local function PruneTable(prices)
        for id, entry in pairs(prices) do
            if type(entry) ~= "table" or (tonumber(entry.seen) or 0) < cutoff then
                prices[id] = nil
            elseif type(entry.days) == "table" then
                PruneDays(entry.days, today)
            end
        end
    end
    for key, value in pairs(PriceMemoryDB) do
        if key == VENDOR_KEY then
            if type(value) ~= "table" then
                PriceMemoryDB[key] = nil
            else
                -- Vendor prices you haven't seen for a month go too, as auction prices do.
                for id, entry in pairs(value) do
                    if type(entry) ~= "table" or (tonumber(entry.seen) or 0) < cutoff then
                        value[id] = nil
                    end
                end
            end
        elseif type(value) == "table" then
            if type(value.seen) == "number" then
                -- Older saves keep single items at the root.
                if value.seen < cutoff then
                    PriceMemoryDB[key] = nil
                elseif type(value.days) == "table" then
                    PruneDays(value.days, today)
                end
            else
                PruneTable(value)
            end
        end
    end
end

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("AUCTION_HOUSE_BROWSE_RESULTS_UPDATED")
events:RegisterEvent("AUCTION_HOUSE_BROWSE_RESULTS_ADDED")
events:RegisterEvent("COMMODITY_SEARCH_RESULTS_UPDATED")
events:RegisterEvent("COMMODITY_SEARCH_RESULTS_ADDED")
events:RegisterEvent("ITEM_SEARCH_RESULTS_UPDATED")
events:RegisterEvent("ITEM_SEARCH_RESULTS_ADDED")
events:RegisterEvent("MERCHANT_SHOW")
events:RegisterEvent("MERCHANT_UPDATE")
events:SetScript("OnEvent", function(_, event, ...)
    if event == "PLAYER_LOGIN" then
        PriceMemoryDB = type(PriceMemoryDB) == "table" and PriceMemoryDB or {}
        pcall(Prune)
        -- The Tooltips helper shows this price (and can switch it off); only add our own line without it.
        if not (SlashCmdList and SlashCmdList.TOOLTIPS) and TooltipDataProcessor and TooltipUtil and Enum and Enum.TooltipDataType then
            TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tooltip)
                pcall(OnTooltip, tooltip)
            end)
        end
        return
    end
    if type(PriceMemoryDB) ~= "table" then
        return
    end
    -- Saved prices must never be lost to an odd value from the game, so each read is guarded.
    if event == "AUCTION_HOUSE_BROWSE_RESULTS_UPDATED" then
        pcall(OnBrowseUpdated)
    elseif event == "AUCTION_HOUSE_BROWSE_RESULTS_ADDED" then
        pcall(ReadBrowseRows, Safe((...)))
    elseif event == "COMMODITY_SEARCH_RESULTS_UPDATED" then
        pcall(ReadCommodity, ..., true)
    elseif event == "COMMODITY_SEARCH_RESULTS_ADDED" then
        pcall(ReadCommodity, ..., false)
    elseif event == "ITEM_SEARCH_RESULTS_UPDATED" then
        pcall(ReadItems, (...), true)
    elseif event == "ITEM_SEARCH_RESULTS_ADDED" then
        pcall(ReadItems, ..., false)
    elseif event == "MERCHANT_SHOW" or event == "MERCHANT_UPDATE" then
        pcall(ReadMerchant)
    end
end)
