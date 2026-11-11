-- Round 5 #13: PriceMemory estimates sell speed from two of YOUR full searches of the same item: auctions gone
-- before they could expire count as bought, relists and your own auctions don't, partial commodity buys do.
-- It never starts a search. Shown on tooltips once 10 minutes were watched.
-- Run from the harness folder:  node run.js "<workspace root>" test_r5b_pricememory_speed.lua
local frames, failures = {}, {}
local realPrint = print
local function check(cond, why) if not cond then failures[#failures + 1] = why end end
local SECRET = {}
issecretvalue = function(v) return v == SECRET end
CreateFrame = function()
    local f = { registered = {} }
    f.RegisterEvent = function(self, e) self.registered[e] = true end
    f.SetScript = function(self, _, fn) self.fn = fn end
    frames[#frames + 1] = f
    return f
end
SlashCmdList = { TOOLTIPS = function() end }    -- Tooltips loaded: PriceMemory adds only the speed line
local clock = 200 * 86400
time = function() return clock end
GetRealmName = function() return "R" end
UnitFactionGroup = function() return "Alliance" end

local commodity, itemRows = {}, {}
local GETTERS = {
    GetBrowseResults = function() return {} end,
    GetNumCommoditySearchResults = function(id) return #(commodity[id] or {}) end,
    GetCommoditySearchResultInfo = function(id, i) return (commodity[id] or {})[i] end,
    GetCommoditySearchResultsQuantity = function(id) local n = 0; for _, r in ipairs(commodity[id] or {}) do n = n + r.quantity end; return n end,
    GetNumItemSearchResults = function() return #itemRows end,
    GetItemSearchResultInfo = function(_, i) return itemRows[i] end,
    GetItemSearchResultsQuantity = function() local n = 0; for _, r in ipairs(itemRows) do n = n + r.quantity end; return n end,
}
C_AuctionHouse = setmetatable({}, { __index = function(_, k)
    if GETTERS[k] then return GETTERS[k] end
    failures[#failures + 1] = "C_AuctionHouse." .. tostring(k) .. " touched (only result getters are allowed)"
    return function() end
end })
local hook
Enum = { TooltipDataType = { Item = 0 } }
TooltipDataProcessor = { AddTooltipPostCall = function(_, fn) hook = fn end }
local shown
TooltipUtil = { GetDisplayedItem = function() return nil, nil, shown end }
local lines = {}
GameTooltip = { AddLine = function(_, t) lines[#lines + 1] = t end }

assert(loadfile(ADDON_PATH .. "/PriceMemory/PriceMemory.lua"))("PriceMemory", {})
local f = frames[#frames]
local function fire(e, ...) f.fn(f, e, ...) end
fire("PLAYER_LOGIN")
check(type(hook) == "function", "speed line registered even with Tooltips loaded")

local function row(id, auctionID, quantity, price, left, own)
    return { itemID = 2589, auctionID = auctionID, quantity = quantity, unitPrice = price, timeLeftSeconds = left,
        containsOwnerItem = own or false, numOwnerItems = own and 1 or 0 }
end
local H = 3600

----- First search: nothing to compare yet
commodity[2589] = {
    row(2589, 1, 20, 100, 10 * H), row(2589, 2, 20, 110, 10 * H), row(2589, 3, 10, 120, 300),  -- 3 ends within 5 min
    row(2589, 4, 5, 130, 10 * H, true),                                                       -- your own
    row(2589, 5, 20, 140, 10 * H),
}
fire("COMMODITY_SEARCH_RESULTS_UPDATED", 2589)
check(PriceMemory_Get(2589).soldPerHour == nil, "no speed from one search")

----- Second search 8 minutes later
clock = clock + 8 * 60
commodity[2589] = {
    -- 1 bought outright; 2 partly bought (20 -> 15); 3 expired (time left was below the gap);
    -- 4 (yours) gone: not counted; 5 relisted as 6 (same quantity and price): not counted.
    row(2589, 2, 15, 110, 10 * H), row(2589, 6, 20, 140, 48 * H),
}
fire("COMMODITY_SEARCH_RESULTS_UPDATED", 2589)
local entry = PriceMemoryDB["R-Alliance"][2589]
check(entry.speed and entry.speed.sold == 25 and entry.speed.watched == 8 * 60, "25 bought in 8 min, got " .. tostring(entry.speed and entry.speed.sold))
check(PriceMemory_Get(2589).soldPerHour == nil, "under 10 minutes watched: not shown yet")

----- A list that arrives in parts is compared only once it's full
clock = clock + 5 * 60
commodity[2589] = { row(2589, 2, 15, 110, 10 * H) }
local full = { row(2589, 2, 15, 110, 10 * H), row(2589, 6, 10, 140, 48 * H) }
GETTERS.GetCommoditySearchResultsQuantity = function() return 25 end
fire("COMMODITY_SEARCH_RESULTS_UPDATED", 2589)
check(entry.speed.watched == 8 * 60, "a partial list isn't compared")
commodity[2589] = full
fire("COMMODITY_SEARCH_RESULTS_ADDED", 2589)
check(entry.speed.watched == 13 * 60 and entry.speed.sold == 35, "full list compared: 10 more bought, got " .. tostring(entry.speed.sold))
GETTERS.GetCommoditySearchResultsQuantity = function(id) local n = 0; for _, r in ipairs(commodity[id] or {}) do n = n + r.quantity end; return n end

local r = PriceMemory_Get(2589)
check(r.soldPerHour and math.abs(r.soldPerHour - 35 * 60 / 13) < 0.01, "sold per hour: " .. tostring(r.soldPerHour))
check(r.soldPrice and r.soldPrice == math.floor((20 * 100 + 5 * 110 + 10 * 140) / 35 + 0.5), "average price of what sold: " .. tostring(r.soldPrice))
check(r.watchedSeconds == 13 * 60, "watched time")

----- Tooltip: the speed line only (Tooltips shows the price)
shown = 2589
hook(GameTooltip)
check(#lines == 1 and lines[1]:find("^Auction: about 161%.5 bought per hour near 0g 1s 13c %(at least; 13 min watched%)"), "speed line: " .. tostring(lines[1]))

----- Searches too far apart aren't compared
clock = clock + 20 * 60
commodity[2589] = { row(2589, 7, 1, 100, 10 * H) }
fire("COMMODITY_SEARCH_RESULTS_UPDATED", 2589)
check(entry.speed.watched == 13 * 60, "gap over 15 minutes: no comparison")

----- Item searches use the time-left band; bid-only rows count without a price
local key = { itemID = 7000, itemLevel = 20, itemSuffix = 0, battlePetSpeciesID = 0 }
itemRows = {
    { itemKey = key, auctionID = 10, quantity = 1, buyoutAmount = 5000, timeLeft = 3 },   -- 12 h+ left
    { itemKey = key, auctionID = 11, quantity = 1, bidAmount = 100, timeLeft = 2 },       -- 2 h+ left, bid only
    { itemKey = key, auctionID = 12, quantity = 1, buyoutAmount = 6000, timeLeft = 0 },   -- may expire any time
}
fire("ITEM_SEARCH_RESULTS_UPDATED", key)
clock = clock + 11 * 60
itemRows = {}
GETTERS.GetItemSearchResultsQuantity = function() return 0 end
fire("ITEM_SEARCH_RESULTS_UPDATED", key)
local item = PriceMemoryDB["R-Alliance"][7000]
check(item.speed and item.speed.sold == 2 and item.speed.valued == 1 and item.speed.value == 5000, "item speed from bands: " .. tostring(item.speed and item.speed.sold))
r = PriceMemory_Get(7000)
check(r.soldPerHour and math.abs(r.soldPerHour - 2 * 60 / 11) < 0.01, "item sold per hour")

----- Rows without an auction ID can't be matched: no comparison
commodity[3000] = { { itemID = 3000, quantity = 5, unitPrice = 10 } }
fire("COMMODITY_SEARCH_RESULTS_UPDATED", 3000)
clock = clock + 11 * 60
commodity[3000] = {}
fire("COMMODITY_SEARCH_RESULTS_UPDATED", 3000)
check(not (PriceMemoryDB["R-Alliance"][3000] or {}).speed, "no auction IDs: no speed")

----- Secret rows are skipped quietly
commodity[3001] = { SECRET, { itemID = 3001, auctionID = SECRET, quantity = 1, unitPrice = 5 } }
fire("COMMODITY_SEARCH_RESULTS_UPDATED", 3001)

----- None bought: says so
for i = 1, 2 do
    commodity[3002] = { row(3002, 50, 3, 10, 10 * H) }
    fire("COMMODITY_SEARCH_RESULTS_UPDATED", 3002)
    clock = clock + 12 * 60
end
lines = {}
shown = 3002
hook(GameTooltip)
check(lines[1] and lines[1]:find("none bought in 12 min", 1, true), "none bought: " .. tostring(lines[1]))

----- A speed older than a week starts over; the saved shape stays small
clock = clock + 8 * 86400
check(PriceMemory_Get(2589) == nil or PriceMemory_Get(2589).soldPerHour == nil, "a week-old speed isn't shown")

----- Memory bound: many items searched
for id = 10000, 10060 do
    commodity[id] = { { itemID = id, auctionID = id, quantity = 1, unitPrice = 5, timeLeftSeconds = 10 * H } }
    fire("COMMODITY_SEARCH_RESULTS_UPDATED", id)
end

if #failures > 0 then
    realPrint("FAILURES (" .. #failures .. "):")
    for _, why in ipairs(failures) do realPrint(" - " .. why) end
    os.exit(1)
end
realPrint("test_r5b_pricememory_speed: all checks passed")
