-- Landmarks: remembers the useful people and things you've visited (vendors, repairers, innkeepers,
-- flight masters, mailboxes, banks, trainers) and tells you the nearest one. Read-only: it only
-- listens for the windows you open yourself and reads your map position.

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


-- Shared Forever character identity (the same copy is in every helper that saves per-character data,
-- so each helper still works alone; whichever loads first defines it). On Forever a character has a
-- first name and a surname (UnitName's second return), so the first name alone is not unique.
-- Key = the player GUID ("Player-<server>-<id>"); when that can't be read, "First Surname-Realm".
do
    local function Plain(value)
        if value == nil or (issecretvalue and issecretvalue(value)) or type(value) ~= "string" or value == "" then
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
    -- "First Surname" on Forever, the plain name elsewhere; nil when unreadable.
    ForeverCharacterName = ForeverCharacterName or function()
        local name, surname = Call(UnitName, "player")
        if not name then
            return nil
        end
        if surname then
            return name .. " " .. surname
        end
        return name
    end
    ForeverCharacterGUID = ForeverCharacterGUID or function()
        local guid = Call(UnitGUID, "player")
        if guid and guid:match("^Player%-") then
            return guid
        end
    end
    -- The key older versions used: first name only, "-", realm.
    ForeverCharacterLegacyKey = ForeverCharacterLegacyKey or function()
        local name = Call(UnitName, "player")
        local realm = Call(GetRealmName)
        return (name or "Unknown") .. "-" .. (realm or "Unknown")
    end
    -- "First Surname-Realm": the key when the GUID can't be read.
    ForeverCharacterNameKey = ForeverCharacterNameKey or function()
        local realm = Call(GetRealmName)
        return (ForeverCharacterName() or "Unknown") .. "-" .. (realm or "Unknown")
    end
    ForeverCharacterKey = ForeverCharacterKey or function()
        return ForeverCharacterGUID() or ForeverCharacterNameKey()
    end
    -- Once per login: moves this character's record from an older key to the current one. Only when
    -- nothing is saved under the current key yet (two records are never merged), and never a record
    -- stamped with another character's GUID. The old key's record is moved, not copied, so a second
    -- character with the same first name starts fresh instead of sharing it. Returns the current key.
    -- oldKeys: optional list of this helper's own older key spellings (default: the legacy key).
    ForeverCharacterAdopt = ForeverCharacterAdopt or function(db, oldKeys)
        local key = ForeverCharacterKey()
        if type(db) ~= "table" or db[key] ~= nil then
            return key
        end
        local guid = ForeverCharacterGUID()
        local candidates = { ForeverCharacterNameKey() }
        for _, old in ipairs(oldKeys or { ForeverCharacterLegacyKey() }) do
            candidates[#candidates + 1] = old
        end
        for _, old in ipairs(candidates) do
            local record = old ~= key and db[old]
            if type(record) == "table" and (record.charGUID == nil or record.charGUID == guid) then
                db[key] = record
                db[old] = nil
                record.migratedFrom = old
                break
            end
        end
        return key
    end
    -- Writes who a record belongs to into it, so pages can show a name instead of parsing the key.
    ForeverCharacterStamp = ForeverCharacterStamp or function(record)
        if type(record) ~= "table" then
            return record
        end
        record.charName = ForeverCharacterName() or record.charName
        record.charGUID = ForeverCharacterGUID() or record.charGUID
        return record
    end
end


local MAX_PLACES = 400
local SAME_SPOT_YARDS = 30
local NEAREST_PER_KIND = 1

-- Kinds in the order the page lists them. The word is also what you type to pin the nearest one.
local KINDS = {
    { key = "repair", label = "Repair" },
    { key = "vendor", label = "Vendor" },
    { key = "food", label = "Food and drink" },
    { key = "inn", label = "Innkeeper" },
    { key = "flight", label = "Flight master" },
    { key = "mail", label = "Mailbox" },
    { key = "bank", label = "Bank" },
    { key = "trainer", label = "Class trainer" },
    { key = "profession", label = "Profession trainer" },
}
local KIND_LABEL = {}
for _, kind in ipairs(KINDS) do
    KIND_LABEL[kind.key] = kind.label
end

local CLASS_CONSUMABLE, SUBCLASS_FOOD_DRINK = 0, 5
local BINDER_ICON = 132052  -- the gossip icon on "Make this inn your home"

local db
local lastPinned
local migratedFlights

local function Safe(value)
    if issecretvalue and issecretvalue(value) then
        return nil
    end
    return value
end

local function Print(text)
    if ForeverHub_Receive then
        return ForeverHub_Receive("Landmarks", text)
    end
    -- No hub window to show it in: stay quiet rather than fill the chat.
end

-- Where you are: the map you're on, your place on it, and the same spot in world yards so
-- distances work across maps on one continent.
local function Here()
    if not (C_Map and C_Map.GetBestMapForUnit and C_Map.GetPlayerMapPosition) then
        return nil
    end
    local mapID = Safe(C_Map.GetBestMapForUnit("player"))
    local position = mapID and C_Map.GetPlayerMapPosition(mapID, "player")
    if not position then
        return nil
    end
    local x, y = position:GetXY()
    x, y = Safe(x), Safe(y)
    if not (x and y) then
        return nil
    end
    local spot = { mapID = mapID, x = x, y = y }
    if C_Map.GetWorldPosFromMapPos and CreateVector2D then
        local continent, world = C_Map.GetWorldPosFromMapPos(mapID, CreateVector2D(x, y))
        if continent and world then
            local wx, wy = world:GetXY()
            spot.continent, spot.wx, spot.wy = Safe(continent), Safe(wx), Safe(wy)
        end
    end
    return spot
end

local function PlaceName()
    local sub = GetSubZoneText and Safe(GetSubZoneText())
    local zone = GetZoneText and Safe(GetZoneText())
    if sub and sub ~= "" and sub ~= zone then
        return sub .. ", " .. (zone or "")
    end
    return zone or "somewhere"
end

local function Yards(spot, place)
    if spot.continent and place.continent and spot.continent == place.continent and spot.wx and place.wx then
        return math.sqrt((spot.wx - place.wx) ^ 2 + (spot.wy - place.wy) ^ 2)
    end
    return nil
end

-- The same spot, by world distance, or by map fraction where world positions aren't available (instances).
local function SameSpot(spot, place)
    local yards = Yards(spot, place)
    if yards then
        return yards < SAME_SPOT_YARDS
    end
    -- About 30 yards on a zone map, so a record saved without a world position (an older one, or one
    -- read while it was hidden) still matches the same NPC a few steps away.
    return spot.mapID == place.mapID and math.abs(spot.x - (place.x or 2)) < 0.01 and math.abs(spot.y - (place.y or 2)) < 0.01
end

-- One record per kind and spot: a vendor you visit every day is still one line. Names alone don't
-- merge, since every mailbox is "Mailbox" and two towns can each have an innkeeper of the same name.
-- Nor does the spot alone: three trainers on one terrace are three people. Mailboxes have no name.
local function Remember(kind, name, spot)
    if not (db and spot) then
        return
    end
    for _, place in ipairs(db.places) do
        if place.kind == kind and (kind == "mail" or place.name == name) and SameSpot(spot, place) then
            place.name, place.seen = name, time()
            place.mapID, place.x, place.y = spot.mapID, spot.x, spot.y
            place.continent, place.wx, place.wy = spot.continent, spot.wx, spot.wy
            place.where = PlaceName()
            return place
        end
    end
    local place = {
        kind = kind, name = name, where = PlaceName(), seen = time(),
        mapID = spot.mapID, x = spot.x, y = spot.y, continent = spot.continent, wx = spot.wx, wy = spot.wy,
    }
    db.places[#db.places + 1] = place
    if #db.places > MAX_PLACES then
        table.sort(db.places, function(a, b)
            return (a.seen or 0) > (b.seen or 0)
        end)
        for index = #db.places, MAX_PLACES + 1, -1 do
            db.places[index] = nil
        end
    end
    return place
end

-- Which character this is, as the key for what that character alone knows (flight points):
-- the shared Forever key (GUID, or full name + realm); older versions used "Name-NormalizedRealm".
local function LegacyCharacterKey()
    local name = UnitName and Safe(UnitName("player"))
    local realm = (GetNormalizedRealmName and Safe(GetNormalizedRealmName())) or (GetRealmName and Safe(GetRealmName()))
    if type(name) == "string" and name ~= "" and type(realm) == "string" and realm ~= "" then
        return name .. "-" .. realm
    end
end

local function CharacterKey()
    return ForeverCharacterKey()
end

-- This character's known flight points by node ID, or nil when never read at a flight master.
local function KnownFlights(create)
    local key = CharacterKey()
    if not (key and LandmarksDB) then
        return nil
    end
    LandmarksDB.flightPoints = LandmarksDB.flightPoints or {}
    -- Once: this character's list saved under the old key moves to the new one (see ForeverCharacterAdopt).
    if not migratedFlights then
        migratedFlights = true
        local oldKeys = { ForeverCharacterLegacyKey() }
        if LegacyCharacterKey() then
            table.insert(oldKeys, 1, LegacyCharacterKey())
        end
        ForeverCharacterAdopt(LandmarksDB.flightPoints, oldKeys)
    end
    if create and not LandmarksDB.flightPoints[key] then
        LandmarksDB.flightPoints[key] = { nodes = {} }
    end
    return ForeverCharacterStamp(LandmarksDB.flightPoints[key])
end

-- The map the flight master's map shows: the client's own answer if it has one, else your continent.
local function TaxiMapID()
    local mapID = GetTaxiMapID and Safe(GetTaxiMapID())
    if mapID then
        return mapID
    end
    mapID = C_Map and C_Map.GetBestMapForUnit and Safe(C_Map.GetBestMapForUnit("player"))
    local CONTINENT = (Enum and Enum.UIMapType and Enum.UIMapType.Continent) or 2
    for _ = 1, 10 do
        local info = mapID and C_Map.GetMapInfo and C_Map.GetMapInfo(mapID)
        local mapType, parent = info and Safe(info.mapType), info and Safe(info.parentMapID)
        if not mapType or mapType <= CONTINENT or not parent or parent == 0 then
            return mapType and mapType <= CONTINENT and mapID or nil
        end
        mapID = parent
    end
end

-- Whether a node on the open flight map is one this character has learned, and whether it's where you stand.
-- The slot type the stock flight map draws by ("NONE" = not learned) when the client has it; otherwise the
-- node's documented state, which is less trustworthy on Forever.
local function NodeStatus(node)
    local slot = Safe(node.slotIndex)
    if TaxiNodeGetType and slot then
        local slotType = Safe(TaxiNodeGetType(slot))
        if type(slotType) == "string" then
            return slotType ~= "NONE", slotType == "CURRENT"
        end
    end
    local state = Safe(node.state)
    local states = Enum and Enum.FlightPathState
    local current, reachable = states and states.Current or 0, states and states.Reachable or 1
    return state == current or state == reachable, state == current
end

-- At a flight master: saves which flight points on this map the character knows. Returns the node you're at.
local function SaveFlightPoints()
    if not (C_TaxiMap and C_TaxiMap.GetAllTaxiNodes) then
        return nil
    end
    local mapID = TaxiMapID()
    if not mapID then
        return nil
    end
    local nodes = C_TaxiMap.GetAllTaxiNodes(mapID)
    if type(nodes) ~= "table" or #nodes == 0 then
        return nil
    end
    local saved = KnownFlights(true)
    if not saved then
        return nil
    end
    local here
    for _, node in ipairs(nodes) do
        local nodeID = type(node) == "table" and Safe(node.nodeID)
        if nodeID then
            local known, current = NodeStatus(node)
            if known then
                local x, y
                if node.position and node.position.GetXY then
                    x, y = node.position:GetXY()
                end
                local name = Safe(node.name)
                saved.nodes[nodeID] = { name = type(name) == "string" and name or nil, mapID = mapID, x = Safe(x), y = Safe(y) }
            else
                -- Listed but not learned: forget it if it was ever marked by mistake.
                saved.nodes[nodeID] = nil
            end
            if current then
                here = nodeID
            end
        end
    end
    saved.seen = time()
    return here
end

local function FlightPointsKnown()
    local saved = KnownFlights(false)
    if not saved then
        return nil
    end
    local count = 0
    for _ in pairs(saved.nodes or {}) do
        count = count + 1
    end
    return count
end

-- A line on whether this character knows the flight point at a remembered flight master.
local function FlightKnownLine(place)
    local saved = KnownFlights(false)
    if not (place and place.nodeID) then
        return nil
    end
    if not saved then
        return "|cff999999Open any flight master's map to check which flight points this character knows.|r"
    end
    if saved.nodes and saved.nodes[place.nodeID] then
        return "|cff33ff33This character knows that flight point.|r"
    end
    return "|cffff6633This character hasn't learned that flight point yet: talk to the flight master there.|r"
end

-- Flight times, learned from your own flights (the taxi button can't be watched, and must not be hooked):
-- the flight map says which node you're at; losing control onto a taxi soon after starts the clock;
-- landing stops it, and the known node nearest to where you land is the destination. Kept per realm,
-- since every character flies at the same speed.
local function Now()
    return GetTime and GetTime() or 0
end

local TAXI_START_SECONDS = 120     -- a flight must start this soon after the flight map was open
local LANDING_RANGE = 0.02         -- on the flight map's own (continent) map, about a few hundred yards
local lastTaxi, flight

local function NodeName(node)
    local name = node and node.name
    return type(name) == "string" and (name:match("^([^,]+)") or name) or "?"
end

local function FlightTimes()
    db.flightTimes = type(db.flightTimes) == "table" and db.flightTimes or {}
    return db.flightTimes
end

local function FlightKey(from, to)
    return tostring(from) .. ">" .. tostring(to)
end

local function DurationText(seconds)
    seconds = math.floor(seconds + 0.5)
    return string.format("%dm %02ds", math.floor(seconds / 60), seconds % 60)
end

-- The known node nearest to where you stand on its own map, or nil when none is close enough.
local function LandedAt()
    local saved = KnownFlights(false)
    if not (saved and saved.nodes and C_Map and C_Map.GetPlayerMapPosition) then
        return nil
    end
    local best, bestDistance
    local positions = {}
    for nodeID, node in pairs(saved.nodes) do
        if node.mapID and node.x and node.y then
            if positions[node.mapID] == nil then
                local position = C_Map.GetPlayerMapPosition(node.mapID, "player")
                local x, y
                if position and position.GetXY then
                    x, y = position:GetXY()
                end
                x, y = Safe(x), Safe(y)
                positions[node.mapID] = (x and y) and { x, y } or false
            end
            local here = positions[node.mapID]
            if here then
                local distance = math.sqrt((here[1] - node.x) ^ 2 + (here[2] - node.y) ^ 2)
                if distance <= LANDING_RANGE and (not bestDistance or distance < bestDistance) then
                    best, bestDistance = nodeID, distance
                end
            end
        end
    end
    return best
end

local function OnTaxi()
    return UnitOnTaxi and Safe(UnitOnTaxi("player")) == true
end

local function StartFlight()
    if flight or not lastTaxi or not lastTaxi.node then
        return
    end
    local now = Now()
    if now - lastTaxi.at <= TAXI_START_SECONDS and OnTaxi() then
        flight = { from = lastTaxi.node, start = now }
    end
end

local function EndFlight()
    if not flight or OnTaxi() then
        return
    end
    local seconds = Now() - flight.start
    local to = LandedAt()
    local from = flight.from
    flight, lastTaxi = nil, nil
    if not to or to == from or seconds < 5 then
        return
    end
    local times = FlightTimes()
    local key = FlightKey(from, to)
    local known = times[key]
    if type(known) == "table" and tonumber(known.seconds) then
        -- Average the flights so far, so one odd flight doesn't set it.
        local count = (tonumber(known.count) or 1) + 1
        known.seconds = known.seconds + (seconds - known.seconds) / count
        known.count = count
    else
        times[key] = { seconds = seconds, count = 1 }
        local saved = KnownFlights(false)
        local nodes = saved and saved.nodes or {}
        Print(string.format("Flight time learned: %s to %s, %s.", NodeName(nodes[from]), NodeName(nodes[to]), DurationText(seconds)))
    end
end

-- Known times from one node, fastest first: { name, seconds }.
local function TimesFrom(from)
    local list = {}
    local saved = KnownFlights(false)
    local nodes = saved and saved.nodes or {}
    for key, entry in pairs(db and FlightTimes() or {}) do
        local a, b = key:match("^(%d+)>(%d+)$")
        if tonumber(a) == from and type(entry) == "table" and tonumber(entry.seconds) then
            list[#list + 1] = { name = NodeName(nodes[tonumber(b)]), seconds = entry.seconds }
        end
    end
    table.sort(list, function(x, y) return x.seconds < y.seconds end)
    return list
end

local function TimesText(from)
    local parts = {}
    for _, entry in ipairs(TimesFrom(from)) do
        parts[#parts + 1] = entry.name .. " " .. DurationText(entry.seconds)
    end
    return #parts > 0 and table.concat(parts, ", ") or nil
end

local function NpcName(fallback)
    return (UnitName and Safe(UnitName("npc"))) or fallback
end

-- Whether the merchant window that just opened sells anything to eat or drink.
local function SellsFood()
    if not (GetMerchantNumItems and GetMerchantItemID and C_Item and C_Item.GetItemInfoInstant) then
        return false
    end
    for index = 1, Safe(GetMerchantNumItems()) or 0 do
        local itemID = Safe(GetMerchantItemID(index))
        if itemID then
            local _, _, _, _, _, classID, subClassID = C_Item.GetItemInfoInstant(itemID)
            if Safe(classID) == CLASS_CONSUMABLE and Safe(subClassID) == SUBCLASS_FOOD_DRINK then
                return true
            end
        end
    end
    return false
end

local function Nearest(spot, kind)
    local best, bestYards
    for _, place in ipairs(db.places) do
        if place.kind == kind then
            local yards = Yards(spot, place)
            if yards and (not bestYards or yards < bestYards) then
                best, bestYards = place, yards
            end
        end
    end
    return best, bestYards
end

local function YardsText(yards)
    if yards >= 1000 then
        return string.format("%.1f k yd", yards / 1000)
    end
    return string.format("%d yd", math.floor(yards))
end

-- Pins the place on your map and screen, the same way the game's own map pin works.
local function Pin(place)
    if not (place and place.mapID and place.x and ForeverWaypoint_Set(place.mapID, place.x, place.y, place.name)) then
        return false
    end
    lastPinned = place
    return true
end

local function ShowPage(arg)
    if not db then
        return
    end
    local want = (arg or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
    local spot = Here()
    if want ~= "" then
        local kind
        for _, entry in ipairs(KINDS) do
            if entry.key == want or entry.label:lower() == want then
                kind = entry.key
            end
        end
        if not kind then
            Print("I don't know a place called '" .. want .. "'. Try: repair, vendor, food, inn, flight, mail, bank, trainer, profession.")
        elseif not spot then
            Print("I can't read where you are right now.")
        else
            local place, yards = Nearest(spot, kind)
            if not place then
                Print("No " .. KIND_LABEL[kind]:lower() .. " remembered on this continent yet. Visit one and it's saved.")
            elseif Pin(place) then
                Print(string.format("Pinned %s (%s), %s away.", place.name, place.where or "", YardsText(yards)))
            else
                Print(string.format("Nearest %s: %s (%s), %s away.", KIND_LABEL[kind]:lower(), place.name, place.where or "", YardsText(yards)))
            end
            local known = kind == "flight" and FlightKnownLine(place)
            if known then
                Print(known)
            end
        end
    end
    local flights = FlightPointsKnown()
    local flightLine = flights and string.format("|cff999999Flight points known: %d|r", flights)
        or "|cff999999Flight points known: open a flight master's map to count them.|r"
    if not spot then
        Print("Where you are can't be read right now, so distances are left out.")
        Print(string.format("|cff999999%d places remembered.|r", #db.places))
        Print(flightLine)
        return
    end
    local any = false
    for _, entry in ipairs(KINDS) do
        local place, yards
        if spot then
            place, yards = Nearest(spot, entry.key)
        end
        if place then
            any = true
            Print(string.format("|cffffd100%s:|r %s, %s |cff999999(%s)|r", entry.label, place.name, place.where or "", YardsText(yards)))
        else
            local count = 0
            for _, other in ipairs(db.places) do
                if other.kind == entry.key then
                    count = count + 1
                end
            end
            if count > 0 then
                any = true
                Print(string.format("|cffffd100%s:|r %d remembered, none on this continent", entry.label, count))
            end
        end
    end
    if not any then
        Print("Nothing remembered yet. Talk to vendors, innkeepers, flight masters and trainers, open mailboxes and banks, and they're saved here.")
    end
    Print(string.format("|cff999999%d places remembered.|r", #db.places))
    Print(flightLine)
    -- Flight times: from where this flight started, else from the nearest flight master you know.
    local from = flight and flight.from
    if flight then
        Print(string.format("|cffffd100In flight:|r %s so far.", DurationText(Now() - flight.start)))
    else
        local master = Nearest(spot, "flight")
        from = master and master.nodeID
    end
    local times = from and TimesText(from)
    if times then
        Print("|cffffd100Flight times from " .. NodeName((KnownFlights(false) or { nodes = {} }).nodes[from]) .. ":|r " .. times)
    else
        Print("|cff999999Flight times: learned as you fly, then shown here and at the flight master.|r")
    end
end

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("MERCHANT_SHOW")
events:RegisterEvent("MAIL_SHOW")
events:RegisterEvent("TAXIMAP_OPENED")
events:RegisterEvent("TRAINER_SHOW")
events:RegisterEvent("BANKFRAME_OPENED")
events:RegisterEvent("CONFIRM_BINDER")
events:RegisterEvent("GOSSIP_SHOW")
events:RegisterEvent("PLAYER_CONTROL_LOST")
events:RegisterEvent("PLAYER_CONTROL_GAINED")
events:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_LOGIN" then
        LandmarksDB = LandmarksDB or {}
        local realm = (GetRealmName and Safe(GetRealmName())) or "Unknown"
        LandmarksDB[realm] = LandmarksDB[realm] or { places = {} }
        db = LandmarksDB[realm]
        db.places = db.places or {}
        return
    end
    if not db then
        return
    end
    if event == "PLAYER_CONTROL_LOST" then
        -- The taxi flag can follow a moment after control is lost.
        StartFlight()
        if not flight and C_Timer and C_Timer.After then
            C_Timer.After(1, StartFlight)
        end
        return
    elseif event == "PLAYER_CONTROL_GAINED" then
        EndFlight()
        return
    end
    -- Known flight points don't need your position, so they're saved even when it can't be read.
    local flightNode
    if event == "TAXIMAP_OPENED" then
        local ok, result = pcall(SaveFlightPoints)
        flightNode = ok and result or nil
        -- A problem here still lets the flight master's spot be remembered below.
        if not ok and geterrorhandler then
            geterrorhandler()(result)
        end
        if flightNode then
            lastTaxi = { node = flightNode, at = Now() }
            local times = TimesText(flightNode)
            if times then
                Print("Flight times from here: " .. times .. ".")
            end
        end
    end
    local spot = Here()
    if not spot then
        return
    end
    if event == "MERCHANT_SHOW" then
        local name = NpcName("Vendor")
        Remember("vendor", name, spot)
        if CanMerchantRepair and Safe(CanMerchantRepair()) then
            Remember("repair", name, spot)
        end
        if SellsFood() then
            Remember("food", name, spot)
        end
    elseif event == "MAIL_SHOW" then
        Remember("mail", "Mailbox", spot)
    elseif event == "TAXIMAP_OPENED" then
        local place = Remember("flight", NpcName("Flight master"), spot)
        -- Which flight point this master serves, so "flight" can say whether a character knows it.
        if place and flightNode then
            place.nodeID = flightNode
        end
    elseif event == "TRAINER_SHOW" then
        -- C_Trainer.GetTrainerType is this client's documented answer; the old global is only a fallback.
        local profession
        local tradeskills = Enum and Enum.TrainerType and Enum.TrainerType.Tradeskills
        if C_Trainer and C_Trainer.GetTrainerType and tradeskills then
            profession = Safe(C_Trainer.GetTrainerType()) == tradeskills
        elseif IsTradeskillTrainer then
            profession = Safe(IsTradeskillTrainer())
        end
        Remember(profession and "profession" or "trainer", NpcName("Trainer"), spot)
    elseif event == "BANKFRAME_OPENED" then
        Remember("bank", NpcName("Banker"), spot)
    elseif event == "CONFIRM_BINDER" then
        Remember("inn", NpcName("Innkeeper"), spot)
    elseif event == "GOSSIP_SHOW" then
        -- An innkeeper's menu offers to make the inn your home; that's enough to remember them.
        if C_GossipInfo and C_GossipInfo.GetOptions then
            for _, option in ipairs(C_GossipInfo.GetOptions() or {}) do
                local name, icon = Safe(option.name), Safe(option.icon)
                -- The binder's own icon, or the English wording as a fallback.
                if icon == BINDER_ICON or (type(name) == "string" and name:lower():find("home", 1, true)) then
                    Remember("inn", NpcName("Innkeeper"), spot)
                    break
                end
            end
        end
    end
end)

SLASH_LANDMARKS1 = "/places"
SLASH_LANDMARKS2 = "/landmarks"
SlashCmdList.LANDMARKS = ShowPage

-- Lets other helpers ask: the nearest remembered place of a kind, with its distance in yards.
function Landmarks_Nearest(kind)
    if not db then
        return nil
    end
    local spot = Here()
    if not spot then
        return nil
    end
    return Nearest(spot, kind)
end
