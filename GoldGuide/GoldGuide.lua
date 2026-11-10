-- GoldGuide: where to farm gold at your level, money tips, and what in your bags is worth more at the
-- auction house than at a vendor. Read-only: it reads your level, professions and bags, and the auction
-- prices PriceMemory saved from your own searches. It never buys, sells, posts or searches.

-- Shared Forever waypoint (the same copy is in every helper that pins places; whichever loads first
-- defines it, so all helpers share one remembered pin). Sets the game's own map pin and tracks it,
-- remembers the point, and clears it once you are within ARRIVE_YARDS of it. It only ever clears a
-- pin that is still exactly the one it set: a pin you placed or moved yourself is never touched.
-- Returns true when the pin was set; false and a reason ("api", "map", "refused") when not.
if not ForeverWaypoint_Set then
    local ARRIVE_YARDS, CHECK_SECONDS, SAME_SPOT = 15, 0.5, 0.0005
    local active, watcher, elapsed, watching = nil, nil, 0, false
    local function Plain(value)
        if value == nil or (issecretvalue and issecretvalue(value)) then
            return nil
        end
        return value
    end
    local function Call(fn, ...)
        if type(fn) ~= "function" then
            return nil
        end
        local ok, a, b = pcall(fn, ...)
        if not ok then
            return nil
        end
        return Plain(a), Plain(b)
    end
    local function XY(vector)
        if type(vector) ~= "table" then
            return nil
        end
        local x, y = Plain(vector.x), Plain(vector.y)
        if type(x) ~= "number" and type(vector.GetXY) == "function" then
            x, y = Call(vector.GetXY, vector)
        end
        if type(x) == "number" and type(y) == "number" then
            return x, y
        end
    end
    local function Vector(x, y)
        if CreateVector2D then
            return CreateVector2D(x, y)
        end
        return { x = x, y = y }
    end
    -- Continent and world yards of a map point, or nil where the client has no world positions.
    local function World(mapID, x, y)
        if not (C_Map and C_Map.GetWorldPosFromMapPos) then
            return nil
        end
        local continent, pos = Call(C_Map.GetWorldPosFromMapPos, mapID, Vector(x, y))
        local wx, wy = XY(pos)
        if continent and wx then
            return continent, wx, wy
        end
    end
    local function Near(ax, ay, bx, by)
        return math.abs(ax - bx) <= SAME_SPOT and math.abs(ay - by) <= SAME_SPOT
    end
    -- True only while the game's pin is still the one we set.
    local function StillOurs()
        if not (active and C_Map) then
            return false
        end
        if C_Map.HasUserWaypoint and Call(C_Map.HasUserWaypoint) == false then
            return false
        end
        local point = C_Map.GetUserWaypoint and Call(C_Map.GetUserWaypoint)
        if type(point) == "table" then
            local px, py = XY(point.position)
            if Plain(point.uiMapID) == active.mapID and px then
                return Near(px, py, active.x, active.y)
            end
        end
        -- The game may keep the pin on another map; ask where it is on ours.
        local pos = C_Map.GetUserWaypointPositionForMap and Call(C_Map.GetUserWaypointPositionForMap, active.mapID)
        local qx, qy = XY(pos)
        return qx ~= nil and Near(qx, qy, active.x, active.y)
    end
    local function Stop()
        active, watching = nil, false
        if watcher then
            watcher:SetScript("OnUpdate", nil)
            if watcher.Hide then
                watcher:Hide()
            end
        end
    end
    -- Yards from the player to our pin, or nil when it can't be measured here (instances, other continent).
    local function YardsAway()
        if not (active and active.continent and C_Map and C_Map.GetBestMapForUnit and C_Map.GetPlayerMapPosition) then
            return nil
        end
        local mapID = Call(C_Map.GetBestMapForUnit, "player")
        if not mapID then
            return nil
        end
        local px, py = XY(Call(C_Map.GetPlayerMapPosition, mapID, "player"))
        if not px then
            return nil
        end
        local continent, wx, wy = World(mapID, px, py)
        if not continent or continent ~= active.continent then
            return nil
        end
        return math.sqrt((wx - active.wx) ^ 2 + (wy - active.wy) ^ 2)
    end
    local function Check()
        if not active then
            return Stop()
        end
        if not StillOurs() then
            -- Replaced or removed by the player (or another addon): forget it, never clear it.
            return Stop()
        end
        local yards = YardsAway()
        if yards and yards <= ARRIVE_YARDS then
            if C_Map.ClearUserWaypoint then
                pcall(C_Map.ClearUserWaypoint)
            end
            Stop()
        end
    end
    local function OnUpdate(_, delta)
        elapsed = elapsed + (tonumber(delta) or 0)
        if elapsed < CHECK_SECONDS then
            return
        end
        elapsed = 0
        local ok, err = pcall(Check)
        if not ok then
            Stop()
            if geterrorhandler then
                geterrorhandler()(err)
            end
        end
    end
    function ForeverWaypoint_Set(mapID, x, y, label)
        mapID, x, y = tonumber(mapID), tonumber(x), tonumber(y)
        if not (mapID and x and y and C_Map and C_Map.SetUserWaypoint and UiMapPoint and UiMapPoint.CreateFromCoordinates) then
            return false, "api"
        end
        if C_Map.CanSetUserWaypointOnMap and not Call(C_Map.CanSetUserWaypointOnMap, mapID) then
            return false, "map"
        end
        local ok, wasSet = pcall(C_Map.SetUserWaypoint, UiMapPoint.CreateFromCoordinates(mapID, x, y))
        if not ok or Plain(wasSet) == false then
            return false, "refused"
        end
        if C_SuperTrack and C_SuperTrack.SetSuperTrackedUserWaypoint then
            pcall(C_SuperTrack.SetSuperTrackedUserWaypoint, true)
        end
        -- Only watch where arrival can be measured; elsewhere the pin simply stays, as before.
        local continent, wx, wy = World(mapID, x, y)
        Stop()
        if continent and CreateFrame then
            active = { mapID = mapID, x = x, y = y, label = label, continent = continent, wx = wx, wy = wy }
            elapsed, watching = 0, true
            watcher = watcher or CreateFrame("Frame")
            watcher:SetScript("OnUpdate", OnUpdate)
            if watcher.Show then
                watcher:Show()
            end
        end
        return true
    end
    -- The pin we set and are still watching, or nil (for pages and tests).
    function ForeverWaypoint_Active()
        return watching and active or nil
    end
end


local COPPER_PER_GOLD = 10000
local SECONDS_PER_DAY = 86400
local LEVEL_BELOW, LEVEL_ABOVE = 2, 3   -- farms shown when your level is this close to their range
local MAX_FARMS, MIN_FARMS = 5, 3
local TIPS_SHOWN = 3
local TOP_AUCTION = 5
local STATUS_MIN_GAIN = COPPER_PER_GOLD  -- the panel row needs at least 1g more per stack at auction
local RESCAN_SECONDS = 5
local GATHERING_BY_NAME = { Mining = 186, Herbalism = 182, Skinning = 393, Fishing = 356 }
local PROFESSION_NAME = { [186] = "Mining", [182] = "Herbalism", [393] = "Skinning", [356] = "Fishing" }
local MAX_PROFESSION_SLOTS = 5

local loggedIn = false
local cache = { dirty = true, at = nil }

local function Safe(value)
    if issecretvalue and issecretvalue(value) then
        return nil
    end
    return value
end

local function Print(text)
    if ForeverHub_Receive then
        return ForeverHub_Receive("GoldGuide", text)
    end
    -- No hub window to show it in: stay quiet rather than fill the chat.
end

local function Data()
    local data = type(GoldGuideData) == "table" and GoldGuideData or {}
    return data.farms or {}, data.methods or {}, data.zones or {}
end

local function Now()
    return (time and time()) or 0
end

local function Clock()
    return (GetTime and GetTime()) or Now()
end

local function FormatMoney(copper)
    copper = math.floor(copper + 0.5)
    local gold, silver, rest = math.floor(copper / COPPER_PER_GOLD), math.floor(copper / 100) % 100, copper % 100
    if gold > 0 then
        return string.format("%dg %ds", gold, silver)
    elseif silver > 0 then
        return string.format("%ds %dc", silver, rest)
    end
    return string.format("%dc", rest)
end

local function FormatAge(seconds)
    local days = math.floor(math.max(seconds, 0) / SECONDS_PER_DAY)
    if days == 0 then
        return "today"
    elseif days == 1 then
        return "1 day ago"
    end
    return string.format("%d days ago", days)
end

----- Your character

local function PlayerLevel()
    local level = UnitLevel and Safe(UnitLevel("player"))
    return type(level) == "number" and level > 0 and level or nil
end

-- The gathering professions you have, as a set of skill lines.
local function Professions()
    local have = {}
    if not (GetProfessions and GetProfessionInfo) then
        return have
    end
    local slots = { GetProfessions() }
    for position = 1, MAX_PROFESSION_SLOTS do
        local index = Safe(slots[position])
        if index then
            local name, _, rank, _, _, _, skillLine = GetProfessionInfo(index)
            name, rank, skillLine = Safe(name), Safe(rank), Safe(skillLine)
            local line = PROFESSION_NAME[skillLine] and skillLine or GATHERING_BY_NAME[name]
            if line then
                -- Your skill when the game says, else just "you have it".
                have[line] = type(rank) == "number" and rank or true
            end
        end
    end
    return have
end

----- Auction prices PriceMemory saved (read only)

local function ScopeKey()
    local realm = GetRealmName and Safe(GetRealmName())
    local faction = UnitFactionGroup and Safe(UnitFactionGroup("player"))
    if type(realm) == "string" and realm ~= "" and type(faction) == "string" and faction ~= "" then
        return realm .. "-" .. faction
    end
end

local AH_CUT = 0.95                         -- what you keep after the auction house's 5% cut
local STALE_SECONDS = 10 * SECONDS_PER_DAY  -- a price older than this is shown as an old price

local function ValidPrice(entry)
    return type(entry) == "table" and type(entry.price) == "number" and entry.price > 0 and type(entry.seen) == "number"
end

-- { price, seen, old, stale } for an item, or nil. "old" marks an entry saved without a realm and faction;
-- "stale" a price older than 10 days. Uses PriceMemory's shared lookup, or reads its saved data directly
-- when that lookup isn't loaded.
local function AuctionPrice(itemID)
    if type(itemID) ~= "number" then
        return nil
    end
    if type(PriceMemory_Get) == "function" then
        local ok, record = pcall(PriceMemory_Get, itemID)
        if ok and ValidPrice(record) then
            return { price = record.price, seen = record.seen, old = record.legacy == true, stale = record.stale == true }
        end
        return nil
    end
    if type(PriceMemoryDB) ~= "table" then
        return nil
    end
    local scope = ScopeKey()
    local prices = scope and PriceMemoryDB[scope]
    local entry, old = type(prices) == "table" and prices[itemID] or nil, false
    if type(entry) ~= "table" then
        entry, old = PriceMemoryDB[itemID], true
    end
    if ValidPrice(entry) then
        return { price = entry.price, seen = entry.seen, old = old, stale = Now() - entry.seen > STALE_SECONDS }
    end
    return nil
end

local function AuctionText(itemID)
    local auction = AuctionPrice(itemID)
    if not auction then
        return nil
    end
    return string.format("last AH price %s (%s%s%s)", FormatMoney(auction.price), FormatAge(Now() - auction.seen),
        auction.old and ", older save" or "", auction.stale and ", old price" or "")
end

----- Your bags

local function LastBag()
    return NUM_TOTAL_EQUIPPED_BAG_SLOTS or NUM_BAG_SLOTS or 4
end

local function ItemInfo(itemID)
    local getInfo = (C_Item and C_Item.GetItemInfo) or GetItemInfo
    if not getInfo then
        return nil, nil
    end
    local name, _, _, _, _, _, _, _, _, _, sellPrice = getInfo(itemID)
    return Safe(name), Safe(sellPrice)
end

local function RequestLoad(itemID)
    if C_Item and C_Item.RequestLoadItemDataByID then
        C_Item.RequestLoadItemDataByID(itemID)
    end
end

-- Everything in your bags: total vendor value, items still loading, and per item what auction pays more for.
local function ScanBags()
    local result = { vendor = 0, pending = 0, readable = false, items = {} }
    if not (C_Container and C_Container.GetContainerNumSlots and C_Container.GetContainerItemInfo) then
        return result
    end
    local byID = {}
    for bag = 0, LastBag() do
        for slot = 1, Safe(C_Container.GetContainerNumSlots(bag)) or 0 do
            result.readable = true
            local info = C_Container.GetContainerItemInfo(bag, slot)
            local itemID = type(info) == "table" and Safe(info.itemID)
            if itemID then
                local count = Safe(info.stackCount) or 1
                local name, sellPrice = ItemInfo(itemID)
                if sellPrice then
                    result.vendor = result.vendor + sellPrice * count
                else
                    result.pending = result.pending + 1
                    RequestLoad(itemID)
                end
                local entry = byID[itemID]
                if not entry then
                    entry = { itemID = itemID, count = 0, name = name or Safe(info.itemName), sellPrice = sellPrice, bound = false }
                    byID[itemID] = entry
                end
                entry.count = entry.count + count
                -- A bound copy can't be auctioned; only count copies you could post.
                if Safe(info.isBound) then
                    entry.bound = true
                    entry.boundCount = (entry.boundCount or 0) + count
                end
            end
        end
    end
    for itemID, entry in pairs(byID) do
        local sellable = entry.count - (entry.boundCount or 0)
        local auction = sellable > 0 and AuctionPrice(itemID)
        -- Compare what you'd actually keep from a sale, after the auction house's cut.
        local net = auction and auction.price * AH_CUT
        if net and net > (entry.sellPrice or 0) then
            entry.sellable = sellable
            entry.auction = auction
            entry.net = net
            entry.gain = (net - (entry.sellPrice or 0)) * sellable
            result.items[#result.items + 1] = entry
        end
    end
    table.sort(result.items, function(a, b)
        if a.gain ~= b.gain then
            return a.gain > b.gain
        end
        return a.itemID < b.itemID
    end)
    return result
end

-- The bag scan the panel row uses: redone only after the bags change, and at most every few seconds.
local function CachedScan()
    local now = Clock()
    if cache.result and (not cache.dirty or (cache.at and now - cache.at < RESCAN_SECONDS)) then
        return cache.result
    end
    cache.result, cache.at, cache.dirty = ScanBags(), now, false
    return cache.result
end

----- Farms

local function Matches(farm, level)
    return level >= farm.minLevel - LEVEL_BELOW and level <= farm.maxLevel + LEVEL_ABOVE
end

-- Up to five farms for your level: ones for gathering professions you have first, then cloth and
-- elemental farms, closest to your level first. Gathering routes you can't use only fill an empty list.
local function BestFarms(level)
    local farms = Data()
    local have = Professions()
    local mine, open, other = {}, {}, {}
    for _, farm in ipairs(farms) do
        if Matches(farm, level) then
            local skill = farm.profession and have[farm.profession]
            -- A vein or herb your skill can't gather yet is no farm for you (yet).
            local tooLow = type(skill) == "number" and farm.minSkill and skill < farm.minSkill
            if skill and not tooLow then
                mine[#mine + 1] = farm
            elseif tooLow then
                other[#other + 1] = farm
            elseif not farm.profession then
                open[#open + 1] = farm
            else
                other[#other + 1] = farm
            end
        end
    end
    local function Distance(farm)
        if level < farm.minLevel then
            return farm.minLevel - level
        elseif level > farm.maxLevel then
            return level - farm.maxLevel
        end
        return 0
    end
    local function ByDistance(a, b)
        local da, db = Distance(a), Distance(b)
        if da ~= db then
            return da < db
        end
        -- Then the farm whose range is centred nearest your level.
        local ca, cb = math.abs((a.minLevel + a.maxLevel) / 2 - level), math.abs((b.minLevel + b.maxLevel) / 2 - level)
        if ca ~= cb then
            return ca < cb
        end
        return a.name < b.name
    end
    table.sort(mine, ByDistance)
    table.sort(open, ByDistance)
    table.sort(other, ByDistance)
    local list = {}
    -- Your professions get up to three places so a cloth or elemental farm still shows.
    for index = 1, math.min(#mine, MAX_FARMS - 2) do
        list[#list + 1] = mine[index]
    end
    for _, farm in ipairs(open) do
        if #list >= MAX_FARMS then
            break
        end
        list[#list + 1] = farm
    end
    for index = MAX_FARMS - 1, #mine do
        if #list >= MAX_FARMS then
            break
        end
        list[#list + 1] = mine[index]
    end
    for _, farm in ipairs(other) do
        if #list >= MIN_FARMS then
            break
        end
        list[#list + 1] = farm
    end
    return list
end

local BANDS = { { 10, 19 }, { 20, 29 }, { 30, 39 }, { 40, 49 }, { 50, 60 } }

-- Every farm in the "all" order (by band, then level, then name). A farm's number is its place here,
-- the same on every list: the hub redraws the best-for-you list right under an "all" list, so a number
-- typed after either one must name the same farm.
local function AllFarms()
    local farms = Data()
    local ordered = {}
    for _, band in ipairs(BANDS) do
        local inBand = {}
        for _, farm in ipairs(farms) do
            -- Each farm sits in the band its range starts in.
            if farm.minLevel >= band[1] and farm.minLevel <= band[2] then
                inBand[#inBand + 1] = farm
            end
        end
        table.sort(inBand, function(a, b)
            if a.minLevel ~= b.minLevel then
                return a.minLevel < b.minLevel
            end
            return a.name < b.name
        end)
        for _, farm in ipairs(inBand) do
            ordered[#ordered + 1] = farm
        end
    end
    return ordered
end

local function FarmNumbers()
    local numbers = {}
    for number, farm in ipairs(AllFarms()) do
        numbers[farm] = number
    end
    return numbers
end

local function DropsText(farm)
    local parts = {}
    for _, drop in ipairs(farm.drops or {}) do
        local price = AuctionText(drop.itemID)
        parts[#parts + 1] = price and string.format("%s (%s)", drop.name, price) or drop.name
    end
    return table.concat(parts, ", ")
end

local function FarmLine(number, farm, mine)
    local tag = ""
    if farm.profession then
        local why = ""
        if not mine then
            why = ", you don't have it"
        elseif type(mine) == "number" and farm.minSkill and mine < farm.minSkill then
            why = string.format(", needs skill %d (you have %d)", farm.minSkill, mine)
        end
        tag = string.format(" |cff88bbee[%s%s]|r", PROFESSION_NAME[farm.profession] or "Gathering", why)
    end
    return string.format("|cffffd100%d.|r %s |cff999999- %s, level %d-%d|r%s", number, farm.name, farm.zone, farm.minLevel, farm.maxLevel, tag)
end

local function ShowFarm(number, farm, have)
    Print(FarmLine(number, farm, have[farm.profession]))
    Print("    Drops: " .. DropsText(farm))
    if farm.why then
        Print("    |cff999999" .. farm.why .. "|r")
    end
end

----- Map pin

local function MapName(mapID)
    local info = C_Map and C_Map.GetMapInfo and C_Map.GetMapInfo(mapID)
    return type(info) == "table" and Safe(info.name) or nil
end

-- Zone names in the data are English.
local function EnglishClient()
    local locale = GetLocale and Safe(GetLocale())
    return locale == nil or locale == "enUS" or locale == "enGB"
end

-- The map to pin on: the first of the zone's map IDs the game takes a waypoint on, preferring one whose
-- name is the zone's. Classic-era and Mainline map IDs differ, so a wrong guess isn't pinned.
local function PinMap(farm)
    local _, _, zones = Data()
    local candidates = { farm.mapID }
    for _, id in ipairs(zones[farm.zone] or {}) do
        if id ~= farm.mapID then
            candidates[#candidates + 1] = id
        end
    end
    local fallback
    for _, id in ipairs(candidates) do
        local can = true
        if C_Map.CanSetUserWaypointOnMap then
            can = Safe(C_Map.CanSetUserWaypointOnMap(id)) and true or false
        end
        if can then
            local name = MapName(id)
            if name and name:lower() == farm.zone:lower() then
                return id
            end
            -- With no name to compare, take the first map that accepts a waypoint. On a client in
            -- another language the names never match, so the farm's own (Classic) map is used.
            if not fallback and (not name or not EnglishClient()) then
                fallback = id
            end
        end
    end
    return fallback
end

local function Pin(farm)
    if not (farm and C_Map and C_Map.SetUserWaypoint and UiMapPoint and UiMapPoint.CreateFromCoordinates) then
        return false
    end
    local mapID = PinMap(farm)
    if not mapID then
        return false
    end
    return (ForeverWaypoint_Set(mapID, farm.x, farm.y, farm.name or farm.zone))
end

----- Page sections

local function ShowTips(level)
    local _, methods = Data()
    local fit = {}
    for index, tip in ipairs(methods) do
        if (tip.minLevel or 1) <= level then
            fit[#fit + 1] = { tip = tip, index = index }
        end
    end
    -- The tips that started mattering most recently are the ones you're least likely to know.
    table.sort(fit, function(a, b)
        if (a.tip.minLevel or 1) ~= (b.tip.minLevel or 1) then
            return (a.tip.minLevel or 1) > (b.tip.minLevel or 1)
        end
        return a.index < b.index
    end)
    if #fit == 0 then
        return
    end
    Print(" ")
    Print("|cffeecc55Tips for your level|r")
    for index = 1, math.min(TIPS_SHOWN, #fit) do
        Print(string.format("|cffffd100%s:|r %s", fit[index].tip.title, fit[index].tip.text))
    end
end

local function ShowBags()
    Print(" ")
    Print("|cffeecc55Your bags|r")
    local scan = ScanBags()
    cache.result, cache.at, cache.dirty = scan, Clock(), false
    if not scan.readable then
        Print("The game didn't report your bags.")
        return
    end
    local loading = ""
    if scan.pending > 0 then
        loading = string.format(" %d item(s) are still loading, so it may be more; open this page again in a moment.", scan.pending)
    end
    Print(string.format("Everything in your bags sells to a vendor for %s.%s", FormatMoney(scan.vendor), loading))
    if type(PriceMemoryDB) ~= "table" then
        Print("|cff999999Auction prices show up here once PriceMemory has seen your own auction house searches.|r")
        return
    end
    if #scan.items == 0 then
        Print("|cff999999Nothing in your bags has a saved auction price above its vendor price.|r")
        return
    end
    Print("Worth more at the auction house than at a vendor (what you keep after the auction house's 5% cut):")
    for index = 1, math.min(TOP_AUCTION, #scan.items) do
        local item = scan.items[index]
        Print(string.format("  %s x%d: AH %s vs vendor %s |cff999999(price seen %s%s)|r%s",
            item.name or ("item " .. item.itemID), item.sellable,
            FormatMoney(item.net * item.sellable), FormatMoney((item.sellPrice or 0) * item.sellable),
            FormatAge(Now() - item.auction.seen), item.auction.old and ", older save" or "",
            item.auction.stale and " |cffff9933old price, search again before selling|r" or ""))
    end
end

local function ShowBest()
    local level = PlayerLevel()
    if not level then
        Print("Your level can't be read right now. Type: all, to see every farm.")
        ShowBags()
        return
    end
    local have = Professions()
    local best = BestFarms(level)
    local numbers = FarmNumbers()
    Print(string.format("|cffeecc55Best for you now|r |cff999999(level %d)|r", level))
    if #best == 0 then
        Print("No farm in this guide fits your level yet; they start at level 10. Questing and selling greys is the best money now.")
    end
    for _, farm in ipairs(best) do
        ShowFarm(numbers[farm], farm, have)
    end
    if #best > 0 then
        Print("|cff999999Type a farm's number to pin it on your map.|r")
    end
    ShowTips(level)
    ShowBags()
    Print("|cff999999Saving for riding? See the Gold goal page.|r")
end

local function ShowAll()
    local have = Professions()
    local band
    for number, farm in ipairs(AllFarms()) do
        for _, candidate in ipairs(BANDS) do
            if farm.minLevel >= candidate[1] and farm.minLevel <= candidate[2] and candidate ~= band then
                band = candidate
                Print(string.format("|cffeecc55Levels %d-%d|r", band[1], band[2]))
            end
        end
        Print(FarmLine(number, farm, have[farm.profession]) .. "  " .. DropsText(farm))
    end
    Print("|cff999999Type a farm's number to pin it on your map.|r")
end

local function ShowAllTips()
    local _, methods = Data()
    for _, tip in ipairs(methods) do
        Print(string.format("|cffffd100%s|r |cff999999(level %d+)|r: %s", tip.title, tip.minLevel or 1, tip.text))
    end
end

local function PinNumber(number)
    local farm = AllFarms()[number]
    if not farm then
        Print(string.format("There's no farm number %d. Type all to see every farm and its number.", number))
        return
    end
    local where = string.format("%s (%.1f, %.1f)", farm.zone, farm.x * 100, farm.y * 100)
    if Pin(farm) then
        Print(string.format("Pinned %s: %s.", farm.name, where))
    else
        Print(string.format("Couldn't pin it on this map. %s is at %s.", farm.name, where))
    end
end

local function ShowPage(arg)
    if not loggedIn then
        return
    end
    local want = (arg or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
    local number = tonumber(want:match("^(%d+)$") or "")
    if number then
        PinNumber(number)
    elseif want == "all" then
        ShowAll()
    elseif want == "tips" then
        ShowAllTips()
    else
        if want ~= "" then
            Print("Type a farm's number to pin it, or: all, or: tips.")
        end
        ShowBest()
    end
end

if CreateFrame then
    local events = CreateFrame("Frame")
    events:RegisterEvent("PLAYER_LOGIN")
    events:RegisterEvent("BAG_UPDATE_DELAYED")
    events:RegisterEvent("GET_ITEM_INFO_RECEIVED")
    events:SetScript("OnEvent", function(_, event)
        if event == "PLAYER_LOGIN" then
            loggedIn = true
        end
        -- Only mark the scan stale; it's redone when something asks for it.
        cache.dirty = true
    end)
end

SLASH_GOLDGUIDE1 = "/goldguide"
SlashCmdList.GOLDGUIDE = ShowPage

ForeverHubStatus = ForeverHubStatus or {}
ForeverHubStatus.GoldGuide = function()
    if not loggedIn or type(PriceMemoryDB) ~= "table" then
        return nil
    end
    local count = 0
    for _, item in ipairs(CachedScan().items) do
        if item.gain >= STATUS_MIN_GAIN then
            count = count + 1
        end
    end
    if count == 0 then
        return nil
    end
    return { { text = string.format("|cffeecc55AH|r %d item%s worth more at auction", count, count == 1 and "" or "s"), page = "Gold guide" } }
end
