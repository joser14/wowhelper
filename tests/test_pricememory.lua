-- PriceMemory: daily history (roll-over and bound), legacy data, browse/commodity/item results (only new
-- rows read), merchant buy prices, PriceMemory_Get fields and staleness, and never sending anything to
-- the auction house.
-- Run from the harness folder:  node run.js "<workspace root>" test_pricememory.lua
local base = ADDON_PATH
local frames, failures = {}, {}
local SECRET = {}
local DAY = 86400
local function check(cond, why) if not cond then failures[#failures + 1] = why end end

issecretvalue = function(v) return v == SECRET end
CreateFrame = function()
    local f = { registered = {} }
    f.RegisterEvent = function(self, e) self.registered[e] = true end
    f.SetScript = function(self, _, fn) self.fn = fn end
    frames[#frames + 1] = f
    return f
end
SlashCmdList = { TOOLTIPS = function() end }  -- Tooltips present: PriceMemory adds no line of its own
local clock = 100 * DAY + 3600
time = function() return clock end
GetRealmName = function() return "R" end
local faction = "Alliance"
UnitFactionGroup = function() return faction end

-- The auction house: only reading getters are allowed. Touching anything else fails the test.
local browseRows, commodity, itemRows = {}, {}, {}
local calls = { commodityInfo = 0, itemInfo = 0 }
local GETTERS = {
    GetBrowseResults = function() return browseRows end,
    GetNumCommoditySearchResults = function(id) return #(commodity[id] or {}) end,
    GetCommoditySearchResultInfo = function(id, i) calls.commodityInfo = calls.commodityInfo + 1; return (commodity[id] or {})[i] end,
    GetCommoditySearchResultsQuantity = function(id) local n = 0; for _, r in ipairs(commodity[id] or {}) do n = n + r.quantity end; return n end,
    GetNumItemSearchResults = function(key) return #(itemRows[key.itemSuffix] or {}) end,
    GetItemSearchResultInfo = function(key, i) calls.itemInfo = calls.itemInfo + 1; return (itemRows[key.itemSuffix] or {})[i] end,
    GetItemSearchResultsQuantity = function(key) local n = 0; for _, r in ipairs(itemRows[key.itemSuffix] or {}) do n = n + r.quantity end; return n end,
}
C_AuctionHouse = setmetatable({}, { __index = function(_, k)
    if GETTERS[k] then return GETTERS[k] end
    failures[#failures + 1] = "C_AuctionHouse." .. tostring(k) .. " touched (only result getters are allowed)"
    return function() failures[#failures + 1] = "C_AuctionHouse." .. tostring(k) .. " CALLED" end
end })

----- Saved data from an older version
PriceMemoryDB = {
    ["R-Alliance"] = {
        [2589] = { price = 40, seen = clock - 2 * DAY },
        [9000] = { price = 5, seen = clock - 40 * DAY },       -- too old: pruned at login
        [9001] = "garbage",
    },
    [118] = { price = 150, seen = clock - 5 * 3600 },          -- flat older save, realm unknown
    [119] = { price = 150, seen = clock - 31 * DAY },          -- flat and too old
    ["Other-Horde"] = { [2592] = { price = 99, seen = clock } },
}

assert(loadfile(base .. "/PriceMemory/PriceMemory.lua"))("PriceMemory", {})
local f = frames[#frames]
for _, e in ipairs({ "PLAYER_LOGIN", "AUCTION_HOUSE_BROWSE_RESULTS_UPDATED", "AUCTION_HOUSE_BROWSE_RESULTS_ADDED",
    "COMMODITY_SEARCH_RESULTS_UPDATED", "COMMODITY_SEARCH_RESULTS_ADDED", "ITEM_SEARCH_RESULTS_UPDATED",
    "ITEM_SEARCH_RESULTS_ADDED", "MERCHANT_SHOW", "MERCHANT_UPDATE" }) do
    check(f.registered[e], "registers " .. e)
end
check(type(PriceMemory_Get) == "function", "PriceMemory_Get is global")
check(PriceMemory_Get(2589) == nil or true, "lookup before login doesn't error")
local function fire(event, ...) f.fn(f, event, ...) end
fire("PLAYER_LOGIN")

local scope = PriceMemoryDB["R-Alliance"]
check(scope[9000] == nil and scope[9001] == nil, "old and garbage entries pruned at login")
check(PriceMemoryDB[119] == nil, "old flat entry pruned")
check(PriceMemoryDB[118] and PriceMemoryDB["Other-Horde"][2592], "recent data kept")

----- Legacy data reads
local r = PriceMemory_Get(2589)
check(r and r.price == 40 and r.seen == clock - 2 * DAY and r.ageDays == 2 and r.stale == false and r.legacy == false,
    "legacy scoped entry read")
check(r and r.min == 40 and r.max == 40 and r.quantity == nil and r.days == 0, "no history yet: min/max fall back to the price")
r = PriceMemory_Get(118)
check(r and r.price == 150 and r.legacy == true and r.ageDays == 0, "flat older save read, marked legacy")
check(PriceMemory_Get(2592) == nil, "another realm/faction isn't read")
check(PriceMemory_Get(424242) == nil, "unknown item: nil")
check(PriceMemory_Get(SECRET) == nil and PriceMemory_Get("x") == nil, "bad ids: nil")

----- Browse results: cheapest per ID, quantity summed, zero-quantity rows skipped
browseRows = {
    { itemKey = { itemID = 2589, itemSuffix = 0 }, minPrice = 50, totalQuantity = 100 },
    { itemKey = { itemID = 5000, itemSuffix = 1 }, minPrice = 900, totalQuantity = 1 },
    { itemKey = { itemID = 5000, itemSuffix = 2 }, minPrice = 700, totalQuantity = 2 },
    { itemKey = { itemID = 5001 }, minPrice = 10, totalQuantity = 0 },
    { itemKey = SECRET, minPrice = 1, totalQuantity = 1 },
    { itemKey = { itemID = 5002 }, minPrice = SECRET, totalQuantity = 1 },
}
fire("AUCTION_HOUSE_BROWSE_RESULTS_UPDATED")
local e = scope[2589]
check(e.price == 50 and e.seen == clock and e.qty == 100, "browse price and quantity saved")
check(type(e.price) == "number" and type(e.seen) == "number", "old {price, seen} fields still filled")
check(scope[5000].price == 700 and scope[5000].qty == 3, "suffix variants: cheapest kept, quantities summed")
check(scope[5001] == nil, "nothing listed: no price")
check(scope[5002] == nil, "secret price skipped")
-- More pages arrive in ADDED, with only the new rows.
fire("AUCTION_HOUSE_BROWSE_RESULTS_ADDED", { { itemKey = { itemID = 5000, itemSuffix = 3 }, minPrice = 650, totalQuantity = 4 },
    { itemKey = { itemID = 5003 }, minPrice = 20, totalQuantity = 5 } })
check(scope[5000].price == 650 and scope[5000].qty == 7, "added rows lower the price and add to the quantity")
check(scope[5003].price == 20, "added row saved")
fire("AUCTION_HOUSE_BROWSE_RESULTS_ADDED", SECRET)
fire("AUCTION_HOUSE_BROWSE_RESULTS_ADDED", nil)
-- A refresh of a long list is not re-read.
local long = {}
for i = 1, 501 do long[i] = { itemKey = { itemID = 6000 + i }, minPrice = 1, totalQuantity = 1 } end
browseRows = long
fire("AUCTION_HOUSE_BROWSE_RESULTS_UPDATED")
check(scope[6001] == nil, "a refresh of a list past one batch isn't re-read")
-- A new search replaces the latest price.
browseRows = { { itemKey = { itemID = 2589 }, minPrice = 70, totalQuantity = 80 } }
fire("AUCTION_HOUSE_BROWSE_RESULTS_UPDATED")
check(scope[2589].price == 70 and scope[2589].qty == 80, "a newer search replaces the latest price")
local today = math.floor(clock / DAY)
local d = scope[2589].days[today]
check(d and d.min == 50 and d.max == 70 and d.qty == 100, "today's min, max and most listed")

----- Daily history: roll-over and the 14-day bound
for day = 1, 20 do
    clock = clock + DAY
    browseRows = { { itemKey = { itemID = 2589 }, minPrice = 100 + day, totalQuantity = day } }
    fire("AUCTION_HOUSE_BROWSE_RESULTS_UPDATED")
end
local n, oldest = 0, nil
for k in pairs(scope[2589].days) do n = n + 1; oldest = math.min(oldest or k, k) end
today = math.floor(clock / DAY)
check(n == 14, "history kept to 14 days, got " .. n)
check(oldest == today - 13, "the newest 14 days are kept")
check(scope[2589].days[today].min == 120, "new day rolls over")
r = PriceMemory_Get(2589)
check(r.price == 120 and r.min == 107 and r.max == 120 and r.quantity == 20 and r.days == 14,
    "lookup: latest, min/max over the kept days, quantity: " .. tostring(r.min) .. "/" .. tostring(r.max))
-- History far in the future (a clock jump) is still bounded.
for k = 1, 20 do scope[2589].days[today + 100 + k] = { min = 1, max = 1, qty = 1 } end
browseRows = { { itemKey = { itemID = 2589 }, minPrice = 120, totalQuantity = 20 } }
fire("AUCTION_HOUSE_BROWSE_RESULTS_UPDATED")
n = 0
for _ in pairs(scope[2589].days) do n = n + 1 end
check(n <= 14, "history bounded even with odd day numbers, got " .. n)

----- Commodity results: lowest unit price, total quantity, only new rows read
commodity[2592] = {
    { itemID = 2592, quantity = 20, unitPrice = 300 },
    { itemID = 2592, quantity = 40, unitPrice = 350 },
}
calls.commodityInfo = 0
fire("COMMODITY_SEARCH_RESULTS_UPDATED", 2592)
check(scope[2592].price == 300 and scope[2592].qty == 60, "commodity price and total quantity")
check(calls.commodityInfo == 2, "two rows read")
commodity[2592][3] = { itemID = 2592, quantity = 10, unitPrice = 400 }
calls.commodityInfo = 0
fire("COMMODITY_SEARCH_RESULTS_ADDED", 2592)
check(calls.commodityInfo == 1, "ADDED reads only the new row, read " .. calls.commodityInfo)
check(scope[2592].price == 300 and scope[2592].qty == 70, "added rows keep the lowest, update the total")
commodity[2592] = { { itemID = 2592, quantity = 5, unitPrice = 380 } }
calls.commodityInfo = 0
fire("COMMODITY_SEARCH_RESULTS_UPDATED", 2592)
check(calls.commodityInfo == 1 and scope[2592].price == 380, "UPDATED starts over")
commodity[2593] = { { itemID = 2593, quantity = 1, unitPrice = SECRET } }
fire("COMMODITY_SEARCH_RESULTS_UPDATED", 2593)
check(scope[2593] == nil, "secret unit price skipped")
fire("COMMODITY_SEARCH_RESULTS_UPDATED", SECRET)
fire("COMMODITY_SEARCH_RESULTS_ADDED", nil)

----- Item results: buyout per unit, bid-only skipped, suffix variants kept apart
itemRows[0] = {
    { itemKey = { itemID = 7000 }, quantity = 1, buyoutAmount = 5000 },
    { itemKey = { itemID = 7000 }, quantity = 1, bidAmount = 100 },     -- bid only
    { itemKey = { itemID = 7000 }, quantity = 1, buyoutAmount = 4000 },  -- the list may be sorted another way
}
calls.itemInfo = 0
fire("ITEM_SEARCH_RESULTS_UPDATED", { itemID = 7000, itemLevel = 20, itemSuffix = 0, battlePetSpeciesID = 0 }, nil)
check(scope[7000].price == 4000 and scope[7000].qty == 3, "item price is the lowest buyout, total quantity saved")
check(calls.itemInfo == 3, "three rows read")
itemRows[0][4] = { itemKey = { itemID = 7000 }, quantity = 2, buyoutAmount = 6000 }
calls.itemInfo = 0
fire("ITEM_SEARCH_RESULTS_ADDED", { itemID = 7000, itemLevel = 20, itemSuffix = 0, battlePetSpeciesID = 0 })
check(calls.itemInfo == 1, "ADDED reads only the new row")
check(scope[7000].price == 3000, "a stack's buyout is split per unit")
itemRows[1185] = { { itemKey = { itemID = 7000, itemSuffix = 1185 }, quantity = 1, buyoutAmount = 9000 } }
fire("ITEM_SEARCH_RESULTS_UPDATED", { itemID = 7000, itemLevel = 20, itemSuffix = 1185, battlePetSpeciesID = 0 })
check(scope[7000].suffixes[1185].price == 9000, "suffix variant saved on its own")
check(scope[7000].price == 3000, "a dearer suffix variant doesn't raise today's item price")
r = PriceMemory_Get(7000, 1185)
check(r.suffixPrice == 9000 and r.price == 3000, "lookup gives the suffix price when asked")
itemRows[1186] = { { itemKey = { itemID = 7000, itemSuffix = 1186 }, quantity = 1, buyoutAmount = 2000 } }
fire("ITEM_SEARCH_RESULTS_UPDATED", { itemID = 7000, itemSuffix = 1186 })
check(scope[7000].price == 2000, "a cheaper suffix variant lowers the item price")
for s = 1, 25 do
    itemRows[s] = { { itemKey = { itemID = 7000, itemSuffix = s }, quantity = 1, buyoutAmount = 9000 + s } }
    clock = clock + 1
    fire("ITEM_SEARCH_RESULTS_UPDATED", { itemID = 7000, itemSuffix = s })
end
n = 0
for _ in pairs(scope[7000].suffixes) do n = n + 1 end
check(n <= 20, "suffix variants bounded, got " .. n)
fire("ITEM_SEARCH_RESULTS_UPDATED", SECRET)
fire("ITEM_SEARCH_RESULTS_UPDATED", nil)

----- Merchant buy prices: unlimited stock only, per unit
local merchant = {
    { id = 2320, info = { price = 10, stackCount = 1, numAvailable = -1 } },          -- Coarse Thread
    { id = 3371, info = { price = 20, stackCount = 5, numAvailable = -1 } },          -- 5 per purchase: 4c each
    { id = 4000, info = { price = 500, stackCount = 1, numAvailable = 3 } },           -- limited stock
    { id = 4001, info = { price = 0, stackCount = 1, numAvailable = -1, hasExtendedCost = true } }, -- tokens
    { id = 4002, info = { price = SECRET, stackCount = 1, numAvailable = -1 } },
}
C_MerchantFrame = { GetItemInfo = function(i) return merchant[i] and merchant[i].info end }
GetMerchantNumItems = function() return #merchant end
GetMerchantItemID = function(i) return merchant[i] and merchant[i].id end
fire("MERCHANT_SHOW")
local vendor = PriceMemoryDB.__vendor
check(vendor and vendor[2320].buy == 10 and vendor[3371].buy == 4, "unlimited merchant items saved per unit")
check(vendor[4000] == nil and vendor[4001] == nil and vendor[4002] == nil, "limited, token and secret items skipped")
r = PriceMemory_Get(3371)
check(r and r.price == nil and r.vendorBuy == 4, "merchant-only item: vendorBuy, no auction price")
check(PriceMemory_Get(2589).vendorBuy == nil, "no vendorBuy when no merchant sells it")
-- Without the undocumented globals: item IDs from the tooltip data, read until a slot is empty.
GetMerchantNumItems, GetMerchantItemID = nil, nil
merchant[1].info = { price = 12, stackCount = 1, numAvailable = -1 }
C_TooltipInfo = { GetMerchantItem = function(i) return merchant[i] and { id = merchant[i].id } end }
fire("MERCHANT_UPDATE")
check(vendor[2320].buy == 12, "merchant item ID from the tooltip data")
C_MerchantFrame = nil
fire("MERCHANT_SHOW")

----- Staleness
clock = clock + 11 * DAY
r = PriceMemory_Get(2592)
check(r.stale == true and r.ageDays == 11, "older than 10 days is stale")
clock = clock - 2 * DAY
r = PriceMemory_Get(2592)
check(r.stale == false and r.ageDays == 9, "9 days is not stale")

----- The faction is part of the key (until an in-game check says otherwise)
faction = "Horde"
check(PriceMemory_Get(2592) == nil, "the other faction's prices aren't read")
faction = SECRET
r = PriceMemory_Get(118)
check(r and r.price == 150, "with the faction hidden, the flat table is read")
faction = "Alliance"

----- Missing auction house API is quiet
local saved = C_AuctionHouse
C_AuctionHouse = nil
fire("AUCTION_HOUSE_BROWSE_RESULTS_UPDATED")
fire("COMMODITY_SEARCH_RESULTS_UPDATED", 2592)
fire("ITEM_SEARCH_RESULTS_UPDATED", { itemID = 7000 })
C_AuctionHouse = saved

----- Getters that throw don't lose saved data
GETTERS.GetBrowseResults = function() error("boom") end
fire("AUCTION_HOUSE_BROWSE_RESULTS_UPDATED")
check(scope[2589].price == 120, "saved data intact after a throwing getter")

----- Own tooltip line only when Tooltips isn't loaded
do
    SlashCmdList = {}
    local hook
    Enum = { TooltipDataType = { Item = 0 } }
    TooltipDataProcessor = { AddTooltipPostCall = function(_, fn) hook = fn end }
    local shown
    TooltipUtil = { GetDisplayedItem = function() return nil, nil, shown end }
    local lines = {}
    GameTooltip = { AddLine = function(_, t) lines[#lines + 1] = t end }
    assert(loadfile(base .. "/PriceMemory/PriceMemory.lua"))("PriceMemory", {})
    local g = frames[#frames]
    g.fn(g, "PLAYER_LOGIN")
    check(type(hook) == "function", "own tooltip line registered without Tooltips")
    shown = 2592
    hook(GameTooltip)
    check(lines[1] and lines[1]:find("^Auction, seen 9d ago: 0g 3s 80c each"), "own line: " .. tostring(lines[1]))
    shown = 118
    hook(GameTooltip)
    check(lines[2] and lines[2]:find("(older save, realm/faction unknown)", 1, true), "own line marks older saves")
    shown = SECRET
    hook(GameTooltip)
    check(#lines == 2, "secret item: no line")
    check(PriceMemoryDB["R-Alliance"][2589].price == 120, "reload keeps the saved data")
end

if #failures > 0 then
    print("FAILURES (" .. #failures .. "):")
    for _, why in ipairs(failures) do print(" - " .. why) end
    os.exit(1)
end
print("test_pricememory: all checks passed")
