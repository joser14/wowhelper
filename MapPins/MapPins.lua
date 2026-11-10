-- MapPins: draws our own pins on the world map and the minimap for what the other helpers know:
-- the guide's next stops, remembered places, your deaths, rares, gold farms for your level and
-- dungeon entrances. Read-only: it reads the other helpers' saved data and your map position.
--
-- How it attaches (nothing of Blizzard's is changed, hooked or added to):
--   World map: our own overlay frame, parented to UIParent and drawn one frame strata above the
--     world map, holding a pool of our own pin buttons made when the file loads. Our OnUpdate only
--     READS the map: WorldMapFrame:IsShown(), :GetMapID(), :GetFrameStrata(), :GetFrameLevel(), and the
--     screen rectangle (GetLeft/GetTop/GetWidth/GetHeight/GetEffectiveScale) of
--     WorldMapFrame.ScrollContainer and its canvas child (ScrollContainer.Child). A pin at map point
--     x, y sits at canvas left + x * width, canvas top - y * height (screen pixels), and hides when
--     that falls outside the visible ScrollContainer (the map can be zoomed and panned).
--     Earlier versions put pins into Blizzard's own map canvas pin pool (a data provider); the map
--     then made protected calls on our pins too, and in combat the game blocked them and blamed us
--     ("ForeverWorld has been blocked from an action only available to the Blizzard UI").
--   Minimap: our own small buttons parented to Minimap (not a protected frame), placed by our own
--     throttled OnUpdate.
-- No frames are made in combat: both pin pools are made when the file loads.
--
-- Minimap math. The offset of a pin from the minimap centre is its east/north distance from you in
-- yards, divided by the minimap's view radius in yards, times half the minimap's width/height in
-- pixels. East/north yards come from C_Map.GetWorldPosFromMapPos for you and for the pin (same
-- continent), projected onto the east and north edges of your current zone map, so no assumption
-- about the world axes is needed. The view radius is C_Minimap.GetViewRadius() (in this client's API
-- documentation: "yards"); when that is missing, the diameter tables below are used.
-- Diameter in yards per Minimap:GetZoom() level 0-5. Source: the published tables in the
-- HereBeDragons-Pins-2.0 library (read for understanding, numbers only), which match the in-game
-- minimap: indoor 300, 240, 180, 120, 80, 50; outdoor 466.67, 400, 333.33, 266.67, 200, 133.33.
-- With "Rotate Minimap" on (GetCVar("rotateMinimap") == "1") the view turns so you face up;
-- GetPlayerFacing() is radians counter-clockwise from north, so the offset is turned by -facing.

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


local TICK = 0.1            -- world map shown check and minimap placement, seconds
local WORLD_POOL = 120      -- world map pins made at load; more on one map are left out
local MINI_POOL = 40        -- minimap pins made at load; more are made only out of combat
local DATA_TICK = 1         -- data changes are looked at no more than once a second
local MAX_DEATHS = 30       -- the newest deaths only; older ones crowd the map
local FARM_LEVELS = 3       -- farms within this many levels of their range
local WORLD_SIZE, MINIMAP_SIZE = 16, 12

local MINIMAP_DIAMETER = {
    indoor = { [0] = 300, 240, 180, 120, 80, 50 },
    outdoor = { [0] = 466 + 2 / 3, 400, 333 + 1 / 3, 266 + 2 / 3, 200, 133 + 1 / 3 },
}

-- Classic-era uiMapIDs, which Forever uses. Static data (farms, dungeons) is matched by zone name,
-- and this is the first number tried for that name.
local CLASSIC_ZONE = {
    ["Durotar"] = 1411, ["Mulgore"] = 1412, ["The Barrens"] = 1413, ["Alterac Mountains"] = 1416,
    ["Arathi Highlands"] = 1417, ["Badlands"] = 1418, ["Blasted Lands"] = 1419, ["Tirisfal Glades"] = 1420,
    ["Silverpine Forest"] = 1421, ["Western Plaguelands"] = 1422, ["Eastern Plaguelands"] = 1423,
    ["Hillsbrad Foothills"] = 1424, ["The Hinterlands"] = 1425, ["Dun Morogh"] = 1426, ["Searing Gorge"] = 1427,
    ["Burning Steppes"] = 1428, ["Elwynn Forest"] = 1429, ["Deadwind Pass"] = 1430, ["Duskwood"] = 1431,
    ["Loch Modan"] = 1432, ["Redridge Mountains"] = 1433, ["Stranglethorn Vale"] = 1434,
    ["Swamp of Sorrows"] = 1435, ["Westfall"] = 1436, ["Wetlands"] = 1437, ["Teldrassil"] = 1438,
    ["Darkshore"] = 1439, ["Ashenvale"] = 1440, ["Thousand Needles"] = 1441, ["Stonetalon Mountains"] = 1442,
    ["Desolace"] = 1443, ["Feralas"] = 1444, ["Dustwallow Marsh"] = 1445, ["Tanaris"] = 1446,
    ["Azshara"] = 1447, ["Felwood"] = 1448, ["Un'Goro Crater"] = 1449, ["Moonglade"] = 1450,
    ["Silithus"] = 1451, ["Winterspring"] = 1452, ["Stormwind City"] = 1453, ["Orgrimmar"] = 1454,
    ["Ironforge"] = 1455, ["Thunder Bluff"] = 1456, ["Darnassus"] = 1457, ["Undercity"] = 1458,
}

local LAYERS = {
    { key = "guide", label = "Guide stops", helper = "LevelGuide" },
    { key = "places", label = "Places", helper = "Landmarks" },
    { key = "deaths", label = "Deaths", helper = "DeathNotes" },
    { key = "rares", label = "Rares", helper = "RareWatch" },
    { key = "farms", label = "Gold farms", helper = "GoldGuide" },
    { key = "dungeons", label = "Dungeons", helper = "Dungeons" },
}
local LAYER = {}
for _, layer in ipairs(LAYERS) do
    LAYER[layer.key] = layer
end

-- Icons: an atlas when this client has it, else a plain texture. Icon textures get their border trimmed.
local ICONS = {
    guide = { atlas = "Waypoint-MapPin-Tracked", file = "Interface\\Icons\\INV_Misc_Map_01", size = 20 },
    repair = { file = "Interface\\Minimap\\Tracking\\Repair" },
    vendor = { file = "Interface\\Minimap\\Tracking\\Reagents" },
    food = { file = "Interface\\Minimap\\Tracking\\Food" },
    inn = { file = "Interface\\Minimap\\Tracking\\Innkeeper" },
    flight = { atlas = "TaxiNode_Alliance", file = "Interface\\Minimap\\Tracking\\FlightMaster" },
    mail = { file = "Interface\\Minimap\\Tracking\\Mailbox" },
    bank = { atlas = "banker", file = "Interface\\Minimap\\Tracking\\Banker" },
    trainer = { file = "Interface\\Minimap\\Tracking\\Class" },
    profession = { file = "Interface\\Minimap\\Tracking\\Profession" },
    place = { file = "Interface\\Minimap\\Tracking\\None" },
    deaths = { file = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_8" },
    rares = { atlas = "VignetteKill", file = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_1" },
    farms = { file = "Interface\\Icons\\INV_Misc_Coin_02" },
    dungeons = { atlas = "Dungeon", file = "Interface\\TargetingFrame\\UI-TargetingFrame-Skull" },
}

local PLACE_LABEL = {
    repair = "Repair", vendor = "Vendor", food = "Food and drink", inn = "Innkeeper", flight = "Flight master",
    mail = "Mailbox", bank = "Bank", trainer = "Class trainer", profession = "Profession trainer",
}

local db
local records = {}           -- every pin we know, rebuilt when data changes
local counts = {}            -- layer key -> number of pins
local dirty = true
local signature
local tooltip

local function Safe(value)
    if issecretvalue and issecretvalue(value) then
        return nil
    end
    return value
end

local function Print(text)
    if ForeverHub_Receive then
        return ForeverHub_Receive("MapPins", text)
    end
    -- No hub window to show it in: stay quiet rather than fill the chat.
end

local function InCombat()
    return InCombatLockdown and Safe(InCombatLockdown()) and true or false
end

local function IsOff(name)
    return ForeverHub_IsOff and ForeverHub_IsOff(name) and true or false
end

local function Realm()
    return (GetRealmName and Safe(GetRealmName())) or "Unknown"
end

local function Fraction(value)
    value = Safe(value)
    return type(value) == "number" and value >= 0 and value <= 1 and value or nil
end

local function Text(value)
    value = Safe(value)
    if value == nil then
        return nil
    end
    return tostring(value)
end

---------------------------------------------------------------------------- maps

local mapNames = {}
local function MapName(mapID)
    if not mapID then
        return nil
    end
    if mapNames[mapID] == nil then
        local info = C_Map and C_Map.GetMapInfo and C_Map.GetMapInfo(mapID)
        local name = type(info) == "table" and Safe(info.name) or nil
        mapNames[mapID] = type(name) == "string" and name or false
    end
    return mapNames[mapID] or nil
end

local function SameName(a, b)
    return type(a) == "string" and type(b) == "string" and a:lower() == b:lower()
end

local function PlayerMap()
    return C_Map and C_Map.GetBestMapForUnit and Safe(C_Map.GetBestMapForUnit("player")) or nil
end

-- The map a static point (farm, dungeon) is on, checked by the zone's name: Forever's own number
-- first, then the Classic-era IDs in the data, then any others, then the map you're standing on.
local resolved = {}
local function ResolveMap(zone, ids)
    if type(zone) ~= "string" then
        return ids and ids[1]
    end
    if resolved[zone] then
        return resolved[zone]
    end
    local candidates, seen = {}, {}
    local function Add(id)
        if type(id) == "number" and not seen[id] then
            seen[id] = true
            candidates[#candidates + 1] = id
        end
    end
    Add(CLASSIC_ZONE[zone])
    for _, id in ipairs(ids or {}) do
        if type(id) == "number" and id >= 1400 then
            Add(id)
        end
    end
    for _, id in ipairs(ids or {}) do
        Add(id)
    end
    if not (C_Map and C_Map.GetMapInfo) then
        return candidates[1]
    end
    for _, id in ipairs(candidates) do
        if SameName(MapName(id), zone) then
            resolved[zone] = id
            return id
        end
    end
    local here = PlayerMap()
    if here and SameName(MapName(here), zone) then
        resolved[zone] = here
        return here
    end
    return nil
end

-- Continent and world yards of a point; cached on the record.
local function WorldOf(record)
    if record.world == nil then
        record.world = false
        if record.mapID and C_Map and C_Map.GetWorldPosFromMapPos and CreateVector2D then
            local continent, pos = C_Map.GetWorldPosFromMapPos(record.mapID, CreateVector2D(record.x, record.y))
            continent = Safe(continent)
            if continent and pos then
                local wx, wy = pos:GetXY()
                wx, wy = Safe(wx), Safe(wy)
                if wx and wy then
                    record.world = { continent = continent, x = wx, y = wy }
                end
            end
        end
    end
    return record.world or nil
end

---------------------------------------------------------------------------- data

local function Add(list, layer, fields)
    if not (fields.x and fields.y and (fields.mapID or fields.zone)) then
        return
    end
    fields.layer = layer
    list[#list + 1] = fields
end

local function GuideStops(list)
    if type(LevelGuide_UpcomingStops) ~= "function" then
        return
    end
    local ok, stops = pcall(LevelGuide_UpcomingStops)
    if not ok or type(stops) ~= "table" then
        return
    end
    for index, stop in ipairs(stops) do
        if type(stop) == "table" then
            local zone = Text(stop.zone)
            local mapID = Safe(stop.mapID)
            if zone then
                mapID = ResolveMap(zone, { mapID })
            end
            local label = Text(stop.label) or "Next stop"
            Add(list, "guide", {
                mapID = type(mapID) == "number" and mapID or nil, zone = zone,
                x = Fraction(stop.x), y = Fraction(stop.y), icon = ICONS.guide,
                title = string.format("Guide stop %d: %s", index, label),
                lines = { Text(stop.kind) },
            })
        end
    end
end

local function RealmTable(saved, field)
    if type(saved) ~= "table" then
        return nil
    end
    local mine = saved[Realm()]
    return type(mine) == "table" and type(mine[field]) == "table" and mine[field] or nil
end

local function Places(list)
    for _, place in ipairs(RealmTable(LandmarksDB, "places") or {}) do
        if type(place) == "table" then
            local kind = Text(place.kind)
            Add(list, "places", {
                mapID = Safe(place.mapID), x = Fraction(place.x), y = Fraction(place.y),
                icon = ICONS[kind] or ICONS.place,
                title = Text(place.name) or PLACE_LABEL[kind] or "Place",
                lines = { PLACE_LABEL[kind] or kind, Text(place.where) },
            })
        end
    end
end

local function Deaths(list)
    local deaths = RealmTable(DeathNotesDB, "deaths") or {}
    for index = #deaths, math.max(1, #deaths - MAX_DEATHS + 1), -1 do
        local death = deaths[index]
        if type(death) == "table" then
            local level, killer = Safe(death.level), Text(death.killer)
            Add(list, "deaths", {
                mapID = Safe(death.mapID), x = Fraction(death.x), y = Fraction(death.y), icon = ICONS.deaths,
                title = level and string.format("You died here (level %s)", tostring(level)) or "You died here",
                lines = { killer and ("Killed by " .. killer) or nil, Text(death.where) },
            })
        end
    end
end

local function Rares(list)
    for _, rare in pairs(RealmTable(RareWatchDB, "rares") or {}) do
        if type(rare) == "table" then
            local level = Safe(rare.level)
            Add(list, "rares", {
                mapID = Safe(rare.mapID), x = Fraction(rare.x), y = Fraction(rare.y), icon = ICONS.rares,
                title = "Rare: " .. (Text(rare.name) or "?"),
                lines = { level and ("Level " .. tostring(level)) or nil, Text(rare.where) },
            })
        end
    end
end

local function Farms(list)
    local data = type(GoldGuideData) == "table" and GoldGuideData or nil
    local level = UnitLevel and Safe(UnitLevel("player"))
    if not (data and type(data.farms) == "table" and type(level) == "number") then
        return
    end
    local zones = type(data.zones) == "table" and data.zones or {}
    for _, farm in ipairs(data.farms) do
        if type(farm) == "table" and type(farm.minLevel) == "number" and type(farm.maxLevel) == "number"
            and level >= farm.minLevel - FARM_LEVELS and level <= farm.maxLevel + FARM_LEVELS then
            local zone = Text(farm.zone)
            local ids = {}
            for _, id in ipairs(type(zones[zone]) == "table" and zones[zone] or {}) do
                ids[#ids + 1] = id
            end
            ids[#ids + 1] = farm.mapID
            Add(list, "farms", {
                mapID = ResolveMap(zone, ids), zone = zone, x = Fraction(farm.x), y = Fraction(farm.y),
                icon = ICONS.farms, title = Text(farm.name) or "Gold farm",
                lines = { string.format("Level %d-%d", farm.minLevel, farm.maxLevel), Text(farm.why) },
            })
        end
    end
end

local function Dungeons(list)
    if type(DungeonsData) ~= "table" then
        return
    end
    for _, dungeon in ipairs(DungeonsData) do
        local entrance = type(dungeon) == "table" and dungeon.entrance
        if type(entrance) == "table" and not dungeon.horde then
            local zone = Text(entrance.zone)
            local range = (type(dungeon.minLevel) == "number" and type(dungeon.maxLevel) == "number")
                and string.format("Level %d-%d", dungeon.minLevel, dungeon.maxLevel) or nil
            Add(list, "dungeons", {
                mapID = ResolveMap(zone, { entrance.mapID }), zone = zone,
                x = Fraction(entrance.x), y = Fraction(entrance.y), icon = ICONS.dungeons,
                title = (Text(dungeon.name) or "Dungeon") .. " entrance",
                lines = { range, Text(entrance.note) },
            })
        end
    end
end

local SOURCES = { guide = GuideStops, places = Places, deaths = Deaths, rares = Rares, farms = Farms, dungeons = Dungeons }

local function LayerOn(key)
    return db and db.layers[key] ~= false and not IsOff(LAYER[key].helper)
end

local function Rebuild()
    local list = {}
    for _, layer in ipairs(LAYERS) do
        local before = #list
        if LayerOn(layer.key) then
            local ok = pcall(SOURCES[layer.key], list)
            if not ok then
                for index = #list, before + 1, -1 do
                    list[index] = nil
                end
            end
        end
        counts[layer.key] = #list - before
    end
    records = list
    dirty = false
end

-- A cheap fingerprint of the other helpers' data, so a new death or place shows within a second.
local function Signature()
    local parts = {}
    -- The count, and the newest time stamp: a full list (places, deaths) gains an entry without growing,
    -- and a rare seen again moves in place, so the count alone would miss both.
    local function Count(t, stamp)
        local n, newest = 0, 0
        if type(t) == "table" then
            for _, entry in pairs(t) do
                n = n + 1
                local at = type(entry) == "table" and entry[stamp]
                if type(at) == "number" and at > newest then
                    newest = at
                end
            end
        end
        parts[#parts + 1] = n .. "/" .. newest
    end
    Count(RealmTable(LandmarksDB, "places"), "seen")
    Count(RealmTable(DeathNotesDB, "deaths"), "when")
    Count(RealmTable(RareWatchDB, "rares"), "seen")
    parts[#parts + 1] = UnitLevel and Safe(UnitLevel("player")) or 0
    -- A helper switched on or off in the hub shows or hides its layer.
    for _, layer in ipairs(LAYERS) do
        parts[#parts + 1] = IsOff(layer.helper) and "x" or "o"
    end
    if type(LevelGuide_UpcomingStops) == "function" then
        local ok, stops = pcall(LevelGuide_UpcomingStops)
        local first = ok and type(stops) == "table" and type(stops[1]) == "table" and stops[1] or nil
        parts[#parts + 1] = first and tostring(Text(first.label)) .. tostring(Safe(first.x)) .. tostring(Safe(first.y)) or "-"
    end
    return table.concat(parts, ":")
end

---------------------------------------------------------------------------- tooltip and click

local function Tooltip()
    if not tooltip then
        tooltip = CreateFrame("GameTooltip", "MapPinsTooltip", UIParent, "GameTooltipTemplate")
        if tooltip.SetFrameStrata then
            tooltip:SetFrameStrata("TOOLTIP")
        end
    end
    return tooltip
end

local function ShowTooltip(owner, record)
    if not record then
        return
    end
    local tip = Tooltip()
    tip:SetOwner(owner, "ANCHOR_RIGHT")
    tip:AddLine(record.title, 1, 0.82, 0)
    for index = 1, 4 do
        local line = record.lines and record.lines[index]
        if line then
            tip:AddLine(line, 1, 1, 1, true)
        end
    end
    tip:AddLine(LAYER[record.layer].label .. "  -  click to set a map pin here", 0.6, 0.6, 0.6)
    tip:Show()
end

local function HideTooltip()
    if tooltip then
        tooltip:Hide()
    end
end

Tooltip()  -- made now, never in combat

-- A click on one of our pins sets the game's own map pin there and tracks it.
local function SetWaypoint(mapID, record)
    if not (record and mapID and C_Map and C_Map.SetUserWaypoint and UiMapPoint and UiMapPoint.CreateFromCoordinates) then
        return false
    end
    return (ForeverWaypoint_Set(mapID, record.x, record.y, record.name))
end

local function ApplyIcon(texture, icon, size)
    icon = icon or ICONS.place
    local atlas = icon.atlas and C_Texture and C_Texture.GetAtlasInfo and Safe(C_Texture.GetAtlasInfo(icon.atlas))
    if atlas and texture.SetAtlas then
        texture:SetAtlas(icon.atlas)
    else
        texture:SetTexture(icon.file)
        if icon.file:find("Interface\\Icons\\", 1, true) then
            texture:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        else
            texture:SetTexCoord(0, 1, 0, 1)
        end
    end
    return icon.size and math.floor(size * icon.size / 16 + 0.5) or size
end

---------------------------------------------------------------------------- world map

-- Everything here is our own frames. Blizzard's map frames are only read (see the top of the file).

-- Whether a pin belongs on the map shown: static points by zone name, live ones by ID.
local function OnMap(record, mapID, mapName)
    if record.zone and mapName then
        return SameName(record.zone, mapName)
    end
    return record.mapID == mapID
end

local STRATA_ORDER = { "BACKGROUND", "LOW", "MEDIUM", "HIGH", "DIALOG", "FULLSCREEN", "FULLSCREEN_DIALOG", "TOOLTIP" }
local STRATA_RANK = {}
for rank, name in ipairs(STRATA_ORDER) do
    STRATA_RANK[name] = rank
end

-- One strata above the map's, so our pins draw over the map's canvas and all of its own pins
-- (their frame levels run far above the map frame's own). Never TOOLTIP: tooltips stay on top.
local function StrataAbove(strata)
    local rank = STRATA_RANK[strata] or STRATA_RANK.HIGH
    return STRATA_ORDER[math.min(rank + 1, #STRATA_ORDER - 1)]
end

local function NoCenter()
    return nil
end

local overlay = CreateFrame("Frame", nil, UIParent)
overlay:SetAllPoints(UIParent)
overlay:Hide()

local worldPins = {}
local worldUsed = 0
local worldMapID            -- the map our pins were laid out for
local worldStale = true     -- records changed: pick the pins again
local worldRecords          -- the records list the pins were picked from
local worldGeometry         -- last screen rectangle string; pins move only when it changes
local overlayStrata, overlayLevel

local function WorldPinClick(self, button)
    if button == "LeftButton" and self.record then
        SetWaypoint(self.mapID, self.record)
    end
end

for index = 1, WORLD_POOL do
    local pin = CreateFrame("Button", nil, overlay)
    pin.Icon = pin:CreateTexture(nil, "OVERLAY")
    pin.Icon:SetAllPoints(pin)
    pin:RegisterForClicks("LeftButtonUp")
    pin:SetScript("OnEnter", function(self) ShowTooltip(self, self.record) end)
    pin:SetScript("OnLeave", HideTooltip)
    pin:SetScript("OnClick", WorldPinClick)
    pin:Hide()
    worldPins[index] = pin
end

local function HideWorld()
    if overlay:IsShown() then
        overlay:Hide()
    end
    worldGeometry = nil
end

-- Screen rectangle of a frame in pixels: left, top, width, height. Reads only.
local function ScreenRect(frame)
    if type(frame) ~= "table" or not (frame.GetLeft and frame.GetTop and frame.GetWidth and frame.GetHeight
        and frame.GetEffectiveScale) then
        return nil
    end
    local left, top = Safe(frame:GetLeft()), Safe(frame:GetTop())
    local width, height = Safe(frame:GetWidth()), Safe(frame:GetHeight())
    local scale = Safe(frame:GetEffectiveScale())
    if type(left) ~= "number" or type(top) ~= "number" or type(width) ~= "number" or type(height) ~= "number"
        or type(scale) ~= "number" or width <= 0 or height <= 0 or scale <= 0 then
        return nil
    end
    return left * scale, top * scale, width * scale, height * scale
end

-- The map's canvas (the zoomed, panned picture) and the visible window onto it.
local function MapFrames(map)
    local scroll = map.ScrollContainer
    if type(scroll) ~= "table" then
        return nil
    end
    local canvas = scroll.Child
    if type(canvas) ~= "table" and map.GetCanvas then
        canvas = map:GetCanvas()
    end
    if type(canvas) ~= "table" then
        return nil
    end
    return scroll, canvas
end

-- Pick which records get a pin on this map. Only our own frames are touched.
local function AssignWorld(mapID)
    local used = 0
    if mapID and dirty then
        Rebuild()
    end
    worldMapID, worldStale, worldGeometry, worldRecords = mapID, false, nil, records
    if mapID then
        local mapName = MapName(mapID)
        local gamepad = InputUtil and InputUtil.IsGamepadUIEnabled and Safe(InputUtil.IsGamepadUIEnabled())
        for _, record in ipairs(records) do
            if used >= WORLD_POOL then
                break
            end
            if record.x and record.y and OnMap(record, mapID, mapName) then
                used = used + 1
                local pin = worldPins[used]
                pin.record, pin.mapID = record, mapID
                -- Gamepad guard: Forever's gamepad cursor looks for pin centres; ours give none.
                pin.GetCenter = gamepad and NoCenter or nil
                local size = ApplyIcon(pin.Icon, record.icon, WORLD_SIZE)
                pin:SetSize(size, size)
            end
        end
    end
    for index = used + 1, worldUsed do
        local pin = worldPins[index]
        pin:Hide()
        pin.record, pin.mapID = nil, nil
    end
    worldUsed = used
end

-- Move our pins to where their map points are on screen; hide the ones outside the visible map.
local function LayoutWorld(map)
    local scroll, canvas = MapFrames(map)
    local cl, ct, cw, ch = ScreenRect(canvas)
    local sl, st, sw, sh = ScreenRect(scroll)
    local own = Safe(overlay:GetEffectiveScale())
    if not (cl and sl and type(own) == "number" and own > 0) then
        for index = 1, worldUsed do
            worldPins[index]:Hide()
        end
        worldGeometry = nil
        return
    end
    local geometry = string.format("%.2f:%.2f:%.2f:%.2f:%.2f:%.2f:%.2f:%.2f:%.4f", cl, ct, cw, ch, sl, st, sw, sh, own)
    if geometry == worldGeometry then
        return
    end
    worldGeometry = geometry
    local right, bottom = sl + sw, st - sh
    for index = 1, worldUsed do
        local pin = worldPins[index]
        local record = pin.record
        local x = cl + record.x * cw
        local y = ct - record.y * ch
        if x >= sl and x <= right and y >= bottom and y <= st then
            pin:ClearAllPoints()
            pin:SetPoint("CENTER", overlay, "BOTTOMLEFT", x / own, y / own)
            pin:Show()
        else
            pin:Hide()
        end
    end
end

-- Called from our own OnUpdate. Reads the world map; shows, hides and moves only our frames.
local function UpdateWorld()
    local map = WorldMapFrame
    if not (db and type(map) == "table" and map.IsShown and not IsOff("MapPins")) or not map:IsShown() then
        HideWorld()
        return
    end
    local strata = StrataAbove(Safe(map:GetFrameStrata()))
    local level = (Safe(map:GetFrameLevel()) or 0) + 1
    if strata ~= overlayStrata then
        overlay:SetFrameStrata(strata)
        overlayStrata = strata
    end
    if level ~= overlayLevel then
        overlay:SetFrameLevel(level)
        overlayLevel = level
    end
    local mapID = Safe(map:GetMapID())
    if mapID ~= worldMapID or worldStale or worldRecords ~= records then
        AssignWorld(mapID)
    end
    if not overlay:IsShown() then
        overlay:Show()
    end
    LayoutWorld(map)
end

-- Records changed: pick and place the world map pins again on the next update.
local function RefreshWorldMap()
    worldStale = true
    UpdateWorld()
end

---------------------------------------------------------------------------- minimap

-- Offset of a pin from the minimap centre in pixels. east/north: yards from you; radius: view radius
-- in yards; halfW/halfH: half the minimap's size; facing: radians when the minimap rotates, else nil;
-- margin: fraction of the radius kept clear at the edge. Returns x, y and whether it's inside.
function MapPins_MinimapOffset(east, north, radius, halfW, halfH, facing, square, margin)
    if not (east and north and radius and radius > 0) then
        return nil
    end
    if facing then
        local c, s = math.cos(facing), math.sin(facing)
        east, north = east * c + north * s, north * c - east * s
    end
    local fx, fy = east / radius, north / radius
    local distance
    if square then
        distance = math.max(math.abs(fx), math.abs(fy))
    else
        distance = math.sqrt(fx * fx + fy * fy)
    end
    return fx * halfW, fy * halfH, distance <= 1 - (margin or 0)
end

-- Yards the minimap shows from its centre to its edge.
function MapPins_MinimapRadius()
    if C_Minimap and C_Minimap.GetViewRadius then
        local yards = Safe(C_Minimap.GetViewRadius())
        if type(yards) == "number" and yards > 0 then
            return yards
        end
    end
    local zoom = Minimap and Minimap.GetZoom and Safe(Minimap:GetZoom()) or 0
    local indoors = IsIndoors and Safe(IsIndoors())
    local diameter = MINIMAP_DIAMETER[indoors and "indoor" or "outdoor"][zoom] or MINIMAP_DIAMETER.outdoor[0]
    return diameter / 2
end

local miniPins, miniUsed = {}, 0
local axes = {}
local lastState

-- Pin number index, or nil when it would have to be made in combat (the pool is made at load).
local function MiniPin(index)
    local pin = miniPins[index]
    if not pin then
        if not Minimap or InCombat() then
            return nil
        end
        pin = CreateFrame("Button", nil, Minimap)
        pin:SetFrameLevel((Minimap:GetFrameLevel() or 0) + 5)
        pin.Icon = pin:CreateTexture(nil, "OVERLAY")
        pin.Icon:SetAllPoints(pin)
        pin:RegisterForClicks("LeftButtonUp")
        pin:SetScript("OnEnter", function(self) ShowTooltip(self, self.record) end)
        pin:SetScript("OnLeave", HideTooltip)
        pin:SetScript("OnClick", function(self, button)
            if button == "LeftButton" and self.record then
                SetWaypoint(self.record.mapID, self.record)
            end
        end)
        pin:Hide()
        miniPins[index] = pin
    end
    return pin
end

if Minimap then
    for index = 1, MINI_POOL do
        MiniPin(index)
    end
end

local function HideMiniPins(from)
    for index = from, #miniPins do
        miniPins[index]:Hide()
        miniPins[index].record = nil
    end
    miniUsed = from - 1
end

-- East and north edges of a zone map in world yards, so any world offset can be read as east/north.
local function Axes(mapID)
    if axes[mapID] == nil then
        axes[mapID] = false
        local function World(x, y)
            local continent, pos = C_Map.GetWorldPosFromMapPos(mapID, CreateVector2D(x, y))
            if Safe(continent) and pos then
                local wx, wy = pos:GetXY()
                return Safe(wx), Safe(wy)
            end
        end
        local ox, oy = World(0, 0)
        local ex, ey = World(1, 0)
        local sx, sy = World(0, 1)
        if ox and oy and ex and ey and sx and sy then
            local east = { ex - ox, ey - oy }
            local north = { ox - sx, oy - sy }
            local le = math.sqrt(east[1] ^ 2 + east[2] ^ 2)
            local ln = math.sqrt(north[1] ^ 2 + north[2] ^ 2)
            if le > 0 and ln > 0 then
                axes[mapID] = { east[1] / le, east[2] / le, north[1] / ln, north[2] / ln }
            end
        end
    end
    return axes[mapID] or nil
end

local function UpdateMinimap(force)
    if not (db and db.minimap and Minimap and not IsOff("MapPins")) then
        HideMiniPins(1)
        return
    end
    if not (C_Map and C_Map.GetPlayerMapPosition and C_Map.GetWorldPosFromMapPos and CreateVector2D) then
        HideMiniPins(1)
        return
    end
    local mapID = PlayerMap()
    local position = mapID and C_Map.GetPlayerMapPosition(mapID, "player")
    local px, py
    if position then
        px, py = position:GetXY()
        px, py = Safe(px), Safe(py)
    end
    local me = px and py and WorldOf({ mapID = mapID, x = px, y = py })
    local axis = me and Axes(mapID)
    if not axis then
        -- Instances and unknown places: no position, no pins.
        HideMiniPins(1)
        lastState = nil
        return
    end
    local rotate = GetCVar and Safe(GetCVar("rotateMinimap")) == "1"
    local facing = rotate and GetPlayerFacing and Safe(GetPlayerFacing()) or nil
    if rotate and not facing then
        HideMiniPins(1)
        return
    end
    local radius = MapPins_MinimapRadius()
    local halfW, halfH = (Minimap:GetWidth() or 0) / 2, (Minimap:GetHeight() or 0) / 2
    local state = table.concat({ me.continent, math.floor(me.x * 2), math.floor(me.y * 2), radius, halfW, facing and math.floor(facing * 100) or "-" }, ":")
    if state == lastState and not force then
        return
    end
    lastState = state
    local square = GetMinimapShape and Safe(GetMinimapShape()) == "SQUARE"
    local used = 0
    for _, record in ipairs(records) do
        local spot = WorldOf(record)
        if spot and spot.continent == me.continent then
            local dx, dy = spot.x - me.x, spot.y - me.y
            local east = dx * axis[1] + dy * axis[2]
            local north = dx * axis[3] + dy * axis[4]
            if math.abs(east) <= radius * 1.5 and math.abs(north) <= radius * 1.5 then
                local size = record.icon and record.icon.size and 14 or MINIMAP_SIZE
                local x, y, inside = MapPins_MinimapOffset(east, north, radius, halfW, halfH, facing, square,
                    halfW > 0 and (size / 2) / halfW or 0)
                local pin = inside and MiniPin(used + 1)
                if pin then
                    used = used + 1
                    pin.record = record
                    local shown = ApplyIcon(pin.Icon, record.icon, MINIMAP_SIZE)
                    pin:SetSize(shown, shown)
                    pin:ClearAllPoints()
                    pin:SetPoint("CENTER", Minimap, "CENTER", x, y)
                    pin:Show()
                end
            end
        end
    end
    HideMiniPins(used + 1)
end

---------------------------------------------------------------------------- refresh

local sinceTick, sinceData = 0, 0
local function MarkDirty()
    dirty = true
    sinceData = DATA_TICK  -- look on the next tick, still at most once a second
end

local driver = CreateFrame("Frame")
driver:SetScript("OnUpdate", function(_, elapsed)
    if not db then
        return
    end
    sinceTick = sinceTick + (elapsed or 0)
    sinceData = sinceData + (elapsed or 0)
    if sinceTick < TICK then
        -- Between checks, keep our pins under the map while it pans or zooms (reads only; nothing
        -- moves unless the map's rectangle changed).
        if overlay:IsShown() and WorldMapFrame then
            LayoutWorld(WorldMapFrame)
        end
        return
    end
    sinceTick = 0
    local force = false
    if sinceData >= DATA_TICK then
        sinceData = 0
        if not InCombat() then
            local now = Signature()
            if now ~= signature then
                signature = now
                dirty = true
            end
            if dirty then
                Rebuild()
                force = true
                worldStale = true
            end
        end
    end
    UpdateWorld()
    UpdateMinimap(force)
end)

---------------------------------------------------------------------------- page

local function FindLayer(word)
    word = (word or ""):lower()
    for _, layer in ipairs(LAYERS) do
        if layer.key == word or layer.label:lower() == word or layer.key:sub(1, -2) == word then
            return layer
        end
    end
    return nil
end

local AVAILABLE = {
    guide = function() return type(LevelGuide_UpcomingStops) == "function" end,
    places = function() return LandmarksDB ~= nil end,
    deaths = function() return DeathNotesDB ~= nil end,
    rares = function() return RareWatchDB ~= nil end,
    farms = function() return type(GoldGuideData) == "table" end,
    dungeons = function() return type(DungeonsData) == "table" end,
}

local function ShowPage(arg)
    if not db then
        return
    end
    local words = {}
    for word in (arg or ""):lower():gmatch("%S+") do
        words[#words + 1] = word
    end
    local verb, what = words[1], table.concat(words, " ", 2)
    if verb == "minimap" and (what == "on" or what == "off") then
        db.minimap = what == "on"
        lastState = nil
        UpdateMinimap(true)
        Print("Minimap pins " .. (db.minimap and "on." or "off."))
    elseif (verb == "on" or verb == "off") and what == "minimap" then
        db.minimap = verb == "on"
        lastState = nil
        UpdateMinimap(true)
        Print("Minimap pins " .. (db.minimap and "on." or "off."))
    elseif verb == "on" or verb == "off" then
        local targets = {}
        if what == "all" then
            targets = LAYERS
        else
            targets[1] = FindLayer(what)
        end
        if not targets[1] then
            Print("I don't know a layer called '" .. what .. "'. Try: guide, places, deaths, rares, farms, dungeons, all.")
        else
            for _, layer in ipairs(targets) do
                db.layers[layer.key] = verb == "on"
            end
            Rebuild()
            lastState = nil
            UpdateMinimap(true)
            RefreshWorldMap()
            Print(string.format("%s %s.", what == "all" and "All layers" or targets[1].label, verb))
        end
    elseif verb then
        Print("Type: off deaths   Or: on farms   Or: minimap off")
    end
    if dirty then
        Rebuild()
    end
    local here = PlayerMap()
    local hereName = MapName(here)
    Print("|cffffd100Pins on your world map and minimap|r |cff999999(click a pin to set a map pin there)|r")
    for _, layer in ipairs(LAYERS) do
        local state
        if db.layers[layer.key] == false then
            state = "|cff999999off|r"
        elseif IsOff(layer.helper) then
            state = "|cff999999on, but " .. layer.helper .. " is switched off|r"
        elseif not AVAILABLE[layer.key]() then
            state = "on |cff999999(" .. layer.helper .. " has nothing to show yet)|r"
        else
            local local_ = 0
            for _, record in ipairs(records) do
                if record.layer == layer.key and here and OnMap(record, here, hereName) then
                    local_ = local_ + 1
                end
            end
            local total = counts[layer.key] or 0
            state = string.format("on, %d %s |cff999999(%d in this zone)|r", total, total == 1 and "pin" or "pins", local_)
        end
        Print(string.format("|cffffd100%s:|r %s", layer.label, state))
    end
    Print("|cffffd100Minimap:|r " .. (db.minimap and "on" or "|cff999999off|r"))
end

SLASH_MAPPINS1 = "/mappins"
SlashCmdList.MAPPINS = ShowPage

---------------------------------------------------------------------------- events

local events = CreateFrame("Frame")
for _, event in ipairs({ "PLAYER_LOGIN", "PLAYER_ENTERING_WORLD", "ZONE_CHANGED", "ZONE_CHANGED_INDOORS",
    "ZONE_CHANGED_NEW_AREA", "PLAYER_LEVEL_UP", "PLAYER_REGEN_ENABLED", "MINIMAP_UPDATE_ZOOM" }) do
    events:RegisterEvent(event)
end
events:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_LOGIN" then
        MapPinsDB = type(MapPinsDB) == "table" and MapPinsDB or {}
        db = MapPinsDB
        db.layers = type(db.layers) == "table" and db.layers or {}
        if db.minimap == nil then
            db.minimap = true
        end
        MarkDirty()
        return
    end
    if event == "MINIMAP_UPDATE_ZOOM" then
        lastState = nil
        return
    end
    if event == "PLAYER_REGEN_ENABLED" then
        -- Data changes are not looked at in combat; look on the next tick.
        sinceData = DATA_TICK
        return
    end
    -- Zone changes, entering the world, a new level: the farms and "this zone" counts change.
    lastState = nil
    MarkDirty()
end)
