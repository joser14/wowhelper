local SECONDS_PER_HOUR, SECONDS_PER_DAY = 3600, 86400

local function Safe(value)
    if issecretvalue and issecretvalue(value) then
        return nil
    end
    return value
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

-- Auction houses are separate per realm and faction, and the saved data is shared by the whole account,
-- so prices are kept under "Realm-Faction". Entries saved directly under an item ID come from older
-- versions (or a moment the game hid the realm or faction), so their realm and faction are unknown.
local function ScopeKey()
    local realm = GetRealmName and Safe(GetRealmName())
    local faction = UnitFactionGroup and Safe(UnitFactionGroup("player"))
    if type(realm) == "string" and realm ~= "" and type(faction) == "string" and faction ~= "" then
        return realm .. "-" .. faction
    end
end

-- The table this realm and faction's prices go in, or the flat table when they can't be told.
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

-- Reads whatever your own searches returned. This addon never sends a search itself.
local function SaveResults()
    if not (PriceMemoryDB and C_AuctionHouse) then
        return
    end
    local prices = PriceTable(true)
    local now = time()
    local lowest = {}
    for _, result in ipairs(C_AuctionHouse.GetBrowseResults() or {}) do
        local itemKey = Safe(result.itemKey)
        local id, price = itemKey and Safe(itemKey.itemID), Safe(result.minPrice)
        -- Random-suffix versions share one item ID, so one search can list it several times. Keep the cheapest.
        if id and price and price > 0 and not (lowest[id] and lowest[id] <= price) then
            lowest[id] = price
            prices[id] = { price = price, seen = now }
        end
    end
end

local function OnTooltip(tooltip)
    if not PriceMemoryDB or (tooltip ~= GameTooltip and tooltip ~= ItemRefTooltip) then
        return
    end
    local _, _, id = TooltipUtil.GetDisplayedItem(tooltip)
    id = Safe(id)
    if type(id) ~= "number" then
        return
    end
    local prices, scope = PriceTable(false)
    local entry, note = prices and prices[id], ""
    -- An older entry without a realm and faction is still shown, but marked so it isn't taken as local.
    if not entry and scope then
        entry, note = PriceMemoryDB[id], " (older save, realm/faction unknown)"
    end
    if type(entry) == "table" and type(entry.price) == "number" and type(entry.seen) == "number" then
        tooltip:AddLine(string.format("Auction, seen %s: %s each%s", FormatAge(time() - entry.seen), FormatMoney(entry.price), note), 0.9, 0.8, 0.4)
    end
end

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("AUCTION_HOUSE_BROWSE_RESULTS_UPDATED")
events:RegisterEvent("AUCTION_HOUSE_BROWSE_RESULTS_ADDED")
events:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_LOGIN" then
        PriceMemoryDB = PriceMemoryDB or {}
        -- A price from months ago says little, and the file would otherwise only ever grow.
        local cutoff = time() - 30 * 86400
        for scope, prices in pairs(PriceMemoryDB) do
            if type(prices) == "table" then
                if type(prices.seen) == "number" then
                    -- Older saves keep single items at the root.
                    if prices.seen < cutoff then
                        PriceMemoryDB[scope] = nil
                    end
                else
                    for id, entry in pairs(prices) do
                        if type(entry) ~= "table" or (tonumber(entry.seen) or 0) < cutoff then
                            prices[id] = nil
                        end
                    end
                end
            end
        end
        if TooltipDataProcessor and TooltipUtil and Enum and Enum.TooltipDataType then
            TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, OnTooltip)
        end
    else
        SaveResults()
    end
end)
