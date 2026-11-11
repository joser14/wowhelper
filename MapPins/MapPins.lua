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
-- Declutter (spacing rule after Questie's, idea only): on the world map a pin is left out when one of the
-- same kind is already placed within SPACING of it, or one of any kind within OVERLAP; distances in map
-- heights, with x weighted 1.5 because maps are about that much wider than tall. Higher-ranked pins are
-- placed first and drawn on top; the kept pin's tooltip names what it covers.
local SPACING, OVERLAP, X_WEIGHT = 0.018, 0.009, 1.5
local RANK = { guide = 1, turnin = 2, accept = 3, rares = 4, deaths = 5, dungeons = 6, places = 7, farms = 8, camps = 9 }
-- Minimap fade (after Questie's minimap fade, idea only): full alpha out to FADE_FROM of the view
-- radius, then down to FADE_MIN at the rim; half alpha for a pin sitting on you.
local FADE_FROM, FADE_MIN, ON_YOU_YARDS = 0.6, 0.35, 10
-- Objective camps from LevelGuide's quest data: biggest camps first, a few per objective and quest.
local CAMPS_PER_OBJECTIVE, CAMPS_PER_QUEST, MAX_CAMPS = 3, 6, 80

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
    -- Forever-only zones (research\forever_improvements, Adventure Guide Forever's map table).
    ["Zephras Isle"] = 2521, ["Riverglades"] = 2548,
}

local LAYERS = {
    { key = "guide", label = "Guide stops", helper = "LevelGuide" },
    { key = "givers", label = "Quest givers", helper = "LevelGuide" },
    { key = "places", label = "Places", helper = "Landmarks" },
    { key = "deaths", label = "Deaths", helper = "DeathNotes" },
    { key = "rares", label = "Rares", helper = "RareWatch" },
    { key = "farms", label = "Gold farms", helper = "GoldGuide" },
    { key = "dungeons", label = "Dungeons", helper = "Dungeons" },
    -- Off until switched on: where to go for each unfinished objective of the quests in your log.
    { key = "camps", label = "Objective camps", helper = "LevelGuide", defaultOff = true },
}
local LAYER = {}
for _, layer in ipairs(LAYERS) do
    LAYER[layer.key] = layer
end

-- Icons: an atlas when this client has it, else a plain texture. Icon textures get their border trimmed.
local ICONS = {
    guide = { atlas = "Waypoint-MapPin-Tracked", file = "Interface\\Icons\\INV_Misc_Map_01", size = 20 },
    accept = { atlas = "QuestNormal", file = "Interface\\GossipFrame\\AvailableQuestIcon" },
    turnin = { atlas = "QuestTurnin", file = "Interface\\GossipFrame\\ActiveQuestIcon" },
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
    camps = { file = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_3", size = 12 },
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
                first = index == 1 or nil,   -- the guide's current stop: the minimap edge arrow's target
            })
        end
    end
end

-- Quest givers from LevelGuide's routes: "!" for a quest you can pick up now, "?" for one to hand in.
local function Givers(list)
    if type(LevelGuide_QuestGivers) ~= "function" then
        return
    end
    local ok, givers = pcall(LevelGuide_QuestGivers)
    if not ok or type(givers) ~= "table" then
        return
    end
    for _, giver in ipairs(givers) do
        if type(giver) == "table" then
            local zone = Text(giver.zone)
            local turnin = giver.kind == "turnin"
            local level = Safe(giver.level)
            Add(list, "givers", {
                mapID = ResolveMap(zone, {}), zone = zone, x = Fraction(giver.x), y = Fraction(giver.y),
                icon = turnin and ICONS.turnin or ICONS.accept, kind = turnin and "turnin" or "accept",
                title = (turnin and "Hand in: " or "Quest: ") .. (Text(giver.title) or "?"),
                lines = { Text(giver.npc), (not turnin and level) and ("Level " .. tostring(level)) or nil },
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
    local seen = RealmTable(RareWatchDB, "rares") or {}
    -- RareWatch's verified Forever rares you haven't seen yet, at their known spawn spot.
    if type(RareWatch_KnownRares) == "function" then
        local ok, known = pcall(RareWatch_KnownRares)
        for _, rare in ipairs(ok and type(known) == "table" and known or {}) do
            if type(rare) == "table" and not (rare.npcID and seen[rare.npcID]) then
                local level = Safe(rare.level)
                Add(list, "rares", {
                    mapID = Safe(rare.mapID), x = Fraction(rare.x), y = Fraction(rare.y), icon = ICONS.rares,
                    title = "Rare: " .. (Text(rare.name) or "?"),
                    lines = { level and ("Level " .. tostring(level)) or nil, "Known spawn; not seen by you yet" },
                })
            end
        end
    end
    for _, rare in pairs(seen) do
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

-- Spawn camps for the unfinished objectives of the quests in your log, from LevelGuide's quest data
-- through its public lookup (LevelGuideQuestFacts.Quest; read only, LevelGuide is never changed).
-- Objectives are matched to the log's rows by position; a row the game calls finished drops its camps.
local function Camps(list)
    local facts = LevelGuideQuestFacts
    if not (type(facts) == "table" and type(facts.Quest) == "function" and C_QuestLog
        and C_QuestLog.GetNumQuestLogEntries and C_QuestLog.GetInfo and C_QuestLog.GetQuestObjectives) then
        return
    end
    local total = 0
    for index = 1, Safe(C_QuestLog.GetNumQuestLogEntries()) or 0 do
        if total >= MAX_CAMPS then
            break
        end
        local info = C_QuestLog.GetInfo(index)
        local questID = type(info) == "table" and not Safe(info.isHeader) and Safe(info.questID)
        local complete = questID and C_QuestLog.IsComplete and Safe(C_QuestLog.IsComplete(questID))
        local q = questID and not complete and facts.Quest(questID)
        if type(q) == "table" then
            local rows = C_QuestLog.GetQuestObjectives(questID)
            rows = type(rows) == "table" and rows or {}
            local title = Text(info.title) or Text(q.title) or "Quest"
            local perQuest = 0
            for objectiveIndex, objective in ipairs(type(q.objectives) == "table" and q.objectives or {}) do
                local row = type(rows[objectiveIndex]) == "table" and rows[objectiveIndex] or nil
                if not (row and Safe(row.finished) == true) then
                    for spotIndex, spot in ipairs(type(objective.spots) == "table" and objective.spots or {}) do
                        if spotIndex > CAMPS_PER_OBJECTIVE or perQuest >= CAMPS_PER_QUEST or total >= MAX_CAMPS then
                            break
                        end
                        local x, y = tonumber(spot.x), tonumber(spot.y)
                        if type(spot.map) == "number" and x and y then
                            local before = #list
                            Add(list, "camps", {
                                mapID = spot.map, x = Fraction(x / 100), y = Fraction(y / 100), icon = ICONS.camps,
                                title = "Objective: " .. title, group = questID,
                                lines = { row and Text(row.text) or nil, tonumber(spot.n) and (tostring(spot.n) .. " spawns here") or nil },
                            })
                            if #list > before then
                                perQuest, total = perQuest + 1, total + 1
                            end
                        end
                    end
                end
            end
        end
    end
end

local SOURCES = { guide = GuideStops, givers = Givers, places = Places, deaths = Deaths, rares = Rares, farms = Farms,
    dungeons = Dungeons, camps = Camps }

-- Whether you want a layer: most are on unless switched off; some are off unless switched on.
local function LayerWanted(key)
    local saved = db and db.layers[key]
    if LAYER[key].defaultOff then
        return saved == true
    end
    return saved ~= false
end

local function LayerOn(key)
    return db and LayerWanted(key) and not IsOff(LAYER[key].helper)
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
    if type(LevelGuide_QuestGivers) == "function" then
        local ok, _, key = pcall(LevelGuide_QuestGivers)
        parts[#parts + 1] = ok and tostring(key) or "-"
    end
    if type(LevelGuide_UpcomingStops) == "function" then
        -- Every stop, not just the first: finishing point 2 of 3 changes only a later one.
        local ok, stops = pcall(LevelGuide_UpcomingStops)
        if ok and type(stops) == "table" then
            parts[#parts + 1] = #stops
            for _, stop in ipairs(stops) do
                if type(stop) == "table" then
                    parts[#parts + 1] = tostring(Text(stop.label)) .. tostring(Safe(stop.mapID)) .. tostring(Safe(stop.x)) .. tostring(Safe(stop.y))
                end
            end
        else
            parts[#parts + 1] = "-"
        end
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
    -- Pins left out because they sat on this one.
    local covered = type(owner) == "table" and rawget(owner, "covered")
    if type(covered) == "table" and #covered > 0 then
        tip:AddLine(string.format("Also here (%d):", #covered), 0.6, 0.8, 1)
        for index = 1, math.min(#covered, 5) do
            tip:AddLine("  " .. tostring(covered[index].title), 0.8, 0.8, 0.8)
        end
        if #covered > 5 then
            tip:AddLine(string.format("  ...and %d more", #covered - 5), 0.6, 0.6, 0.6)
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
    return (ForeverWaypoint_Set(mapID, record.x, record.y, record.title))
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

local function RankOf(record)
    return RANK[record.kind or ""] or RANK[record.layer] or #LAYERS + 1
end

-- Pins of one group thin each other out more than pins of different kinds.
local function GroupOf(record)
    return record.layer .. ":" .. tostring(record.kind or record.group or "")
end

-- The placed pin this record would sit on, or nil when there's room for it.
local function Covering(placed, record)
    local group = GroupOf(record)
    for _, other in ipairs(placed) do
        local dx = (record.x - other.record.x) * X_WEIGHT
        local dy = record.y - other.record.y
        local limit = other.group == group and SPACING or OVERLAP
        if dx * dx + dy * dy < limit * limit then
            return other
        end
    end
    return nil
end

-- Minimap pin alpha for a pin this many yards from you, with the minimap showing radius yards.
function MapPins_FadeAlpha(yards, radius)
    if type(yards) ~= "number" or type(radius) ~= "number" or radius <= 0 then
        return 1
    end
    if yards <= ON_YOU_YARDS then
        return 0.5
    end
    local from = radius * FADE_FROM
    if yards <= from then
        return 1
    end
    local share = math.min((yards - from) / (radius - from), 1)
    return 1 - share * (1 - FADE_MIN)
end

local overlay = CreateFrame("Frame", nil, UIParent)
overlay:SetAllPoints(UIParent)
overlay:Hide()

local worldPins = {}
local worldUsed = 0
local worldMapID            -- the map our pins were laid out for
local worldStale = true     -- records changed: pick the pins again
local worldRecords          -- the records list the pins were picked from
local worldGeometry         -- true while worldGeo holds the last laid-out screen rectangle; pins move only when it changes
local worldGeo = {}         -- that rectangle, rounded (canvas and scroll left/top/width/height, overlay scale)
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
        local candidates = {}
        for order, record in ipairs(records) do
            if record.x and record.y and OnMap(record, mapID, mapName) then
                candidates[#candidates + 1] = { record = record, rank = RankOf(record), order = order }
            end
        end
        table.sort(candidates, function(a, b)
            if a.rank ~= b.rank then
                return a.rank < b.rank
            end
            return a.order < b.order
        end)
        local placed = {}
        for _, candidate in ipairs(candidates) do
            local record = candidate.record
            local cover = Covering(placed, record)
            if cover then
                cover.pin.covered[#cover.pin.covered + 1] = record
            elseif used < WORLD_POOL then
                used = used + 1
                local pin = worldPins[used]
                pin.record, pin.mapID, pin.covered = record, mapID, {}
                placed[#placed + 1] = { record = record, pin = pin, group = GroupOf(record) }
                -- Gamepad guard: Forever's gamepad cursor looks for pin centres; ours give none.
                pin.GetCenter = gamepad and NoCenter or nil
                local size = ApplyIcon(pin.Icon, record.icon, WORLD_SIZE)
                pin:SetSize(size, size)
                -- Higher-ranked pins on top (turn-ins over pick-ups over the rest).
                pin:SetFrameLevel((overlayLevel or 1) + 1 + #LAYERS + 2 - candidate.rank)
            end
        end
    end
    for index = used + 1, worldUsed do
        local pin = worldPins[index]
        pin:Hide()
        pin.record, pin.mapID, pin.covered = nil, nil, nil
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
    -- Runs every frame while the map is open: compared as rounded numbers (the same precision as the old
    -- "%.2f:...:%.4f" string), so an unchanged map makes no garbage (perf audit).
    local g = worldGeo
    local r1, r2, r3, r4 = math.floor(cl * 100 + 0.5), math.floor(ct * 100 + 0.5), math.floor(cw * 100 + 0.5), math.floor(ch * 100 + 0.5)
    local r5, r6, r7, r8 = math.floor(sl * 100 + 0.5), math.floor(st * 100 + 0.5), math.floor(sw * 100 + 0.5), math.floor(sh * 100 + 0.5)
    local r9 = math.floor(own * 10000 + 0.5)
    if worldGeometry and g[1] == r1 and g[2] == r2 and g[3] == r3 and g[4] == r4 and g[5] == r5 and g[6] == r6
        and g[7] == r7 and g[8] == r8 and g[9] == r9 then
        return
    end
    g[1], g[2], g[3], g[4], g[5], g[6], g[7], g[8], g[9] = r1, r2, r3, r4, r5, r6, r7, r8, r9
    worldGeometry = true
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

-- The info line (round 4 item 18, research\re_round4.md R19; Leatrix Maps' idea, our own code): along the
-- bottom of the map, the zone under the cursor with its level range coloured for you (ZoneLevels'
-- ForeverZoneLevels), the cursor's and your coordinates. A font string on our own overlay; reads only.
-- The cursor part is left out in gamepad mode and when the cursor isn't over the visible map.
local Info = {}
do
    -- (Some test stand-ins have no font strings: then there is simply no info line.)
    Info.text = overlay.CreateFontString and overlay:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    if Info.text then
        Info.text:SetJustifyH("LEFT")
        Info.text:Hide()
    end
    Info.zones = {}   -- cache: map and cursor cell -> label (C_Map.GetMapInfoAtPosition only when it moves)
    Info.parts = {}   -- the line's pieces, reused by Info.Update

    function Info.Zone(mapID, cx, cy)
        local key = mapID .. ":" .. math.floor(cx * 200) .. ":" .. math.floor(cy * 200)
        -- Your level is part of the answer (the colour): a level-up redraws it in the same cell (review 4, note 12).
        local level = Safe(UnitLevel("player"))
        if Info.zones.key == key and Info.zones.level == level then
            return Info.zones.label
        end
        local label
        local details = C_Map.GetMapInfoAtPosition and C_Map.GetMapInfoAtPosition(mapID, cx, cy)
        local name = type(details) == "table" and Text(details.name)
        if name then
            label = name
            local zoneID = Safe(details.mapID)
            local low, high
            if zoneID and type(ForeverZoneLevels) == "function" then
                local ok, a, b = pcall(ForeverZoneLevels, zoneID)
                if ok and type(a) == "number" and type(b) == "number" then
                    low, high = a, b
                end
            end
            if low then
                local colour = "|cffffd100"
                if type(level) == "number" and level < low then
                    colour = "|cffff4040"       -- above you
                elseif type(level) == "number" and level > high then
                    colour = "|cff999999"       -- below you
                end
                label = string.format("%s%s (%d-%d)|r", colour, name, low, high)
            end
        end
        Info.zones.key, Info.zones.label, Info.zones.level = key, label, level
        return label
    end

    function Info.Update(map, mapID)
        if not Info.text then
            return
        end
        local scroll, canvas = MapFrames(map)
        local cl, ct, cw, ch = ScreenRect(canvas)
        local sl, st, sw, sh = ScreenRect(scroll)
        local own = Safe(overlay:GetEffectiveScale())
        if not (mapID and cl and sl and type(own) == "number" and own > 0) then
            Info.text:Hide()
            return
        end
        -- One list reused every frame the map is open (perf audit), emptied first.
        local parts = Info.parts
        for index = #parts, 1, -1 do
            parts[index] = nil
        end
        local gamepad = InputUtil and InputUtil.IsGamepadUIEnabled and Safe(InputUtil.IsGamepadUIEnabled())
        if not gamepad and GetCursorPosition then
            local x, y = GetCursorPosition()
            x, y = Safe(x), Safe(y)
            if type(x) == "number" and type(y) == "number" and x >= sl and x <= sl + sw and y <= st and y >= st - sh then
                local cx, cy = (x - cl) / cw, (ct - y) / ch
                if cx >= 0 and cx <= 1 and cy >= 0 and cy <= 1 then
                    parts[#parts + 1] = Info.Zone(mapID, cx, cy)
                    parts[#parts + 1] = string.format("Cursor %.1f, %.1f", cx * 100, cy * 100)
                end
            end
        end
        local position = C_Map.GetPlayerMapPosition and C_Map.GetPlayerMapPosition(mapID, "player")
        if position then
            local px, py = position:GetXY()
            px, py = Safe(px), Safe(py)
            if type(px) == "number" and type(py) == "number" and (px > 0 or py > 0) then
                parts[#parts + 1] = string.format("You %.1f, %.1f", px * 100, py * 100)
            end
        end
        local text = table.concat(parts, "    ")
        if text == "" then
            Info.text:Hide()
            return
        end
        if text ~= Info.shownText then
            Info.text:SetText(text)
            Info.shownText = text
        end
        local ax, ay = (sl + 8) / own, (st - sh + 8) / own
        if ax ~= Info.ax or ay ~= Info.ay then
            Info.ax, Info.ay = ax, ay
            Info.text:ClearAllPoints()
            Info.text:SetPoint("BOTTOMLEFT", overlay, "BOTTOMLEFT", ax, ay)
        end
        Info.text:Show()
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
        -- The pins' own levels sit above the overlay's: place them again.
        worldStale = true
    end
    local mapID = Safe(map:GetMapID())
    if mapID ~= worldMapID or worldStale or worldRecords ~= records then
        AssignWorld(mapID)
    end
    if not overlay:IsShown() then
        overlay:Show()
    end
    LayoutWorld(map)
    Info.Update(map, mapID)
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
-- Reused ten times a second by UpdateMinimap (perf audit): where you stand, and the parts of its state key.
local miniScratch = { here = {}, state = {} }

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

-- Minimap edge arrow (round 4 item 18, research\re_round4.md R19; TomTom's idea, our own code and Blizzard's
-- own quest-arrow art): when the /way point (ForeverWaypoint_Active) or else the guide's current stop is beyond
-- the minimap, one arrow on the rim points at it instead of nothing. Our own frame on the minimap, made at
-- load (the accepted minimap exception in STATUS.md); never on the map canvas.
local Edge = {}
do
    local atan2 = math.atan2 or math.atan
    local SIZE = 18
    if Minimap then
        Edge.frame = CreateFrame("Frame", nil, Minimap)
        Edge.frame:SetSize(SIZE, SIZE)
        Edge.frame:SetFrameLevel((Minimap:GetFrameLevel() or 0) + 6)
        Edge.frame.Arrow = Edge.frame:CreateTexture(nil, "OVERLAY")
        Edge.frame.Arrow:SetAllPoints(Edge.frame)
        Edge.frame.Arrow:SetTexture("Interface\\MINIMAP\\MiniMap-QuestArrow")
        Edge.frame:Hide()
    end
    Edge.ways = {}   -- our own copy of the /way point (never written into the shared waypoint table)

    function Edge.Hide()
        if Edge.frame then
            Edge.frame:Hide()
        end
    end

    -- The target record and a key that changes with it, or nil.
    function Edge.Target()
        local active = type(ForeverWaypoint_Active) == "function" and ForeverWaypoint_Active()
        if type(active) == "table" then
            local mapID, x, y = Safe(active.mapID), Safe(active.x), Safe(active.y)
            if type(mapID) == "number" and type(x) == "number" and type(y) == "number" then
                local key = string.format("way:%d:%.4f:%.4f", mapID, x, y)
                if not Edge.ways[key] then
                    Edge.ways = { [key] = { mapID = mapID, x = x, y = y } }
                end
                return Edge.ways[key], key
            end
        end
        for index, record in ipairs(records) do
            if record.layer == "guide" and record.first and record.mapID then
                return record, "guide:" .. index .. ":" .. record.mapID .. ":" .. record.x .. ":" .. record.y
            end
        end
    end

    -- Places the arrow on the rim for a target outside the minimap; hides it otherwise.
    function Edge.Place(target, me, axis, radius, halfW, halfH, facing, square)
        local spot = target and Edge.frame and WorldOf(target)
        if not (spot and spot.continent == me.continent and halfW > 0 and halfH > 0) then
            Edge.Hide()
            return
        end
        local dx, dy = spot.x - me.x, spot.y - me.y
        local east = dx * axis[1] + dy * axis[2]
        local north = dx * axis[3] + dy * axis[4]
        local margin = (SIZE / 2) / halfW
        local x, y, inside = MapPins_MinimapOffset(east, north, radius, halfW, halfH, facing, square, margin)
        if not x or inside then
            Edge.Hide()
            return
        end
        local fx, fy = x / halfW, y / halfH
        local distance = square and math.max(math.abs(fx), math.abs(fy)) or math.sqrt(fx * fx + fy * fy)
        if distance <= 0 then
            Edge.Hide()
            return
        end
        local scale = (1 - margin) / distance
        x, y = x * scale, y * scale
        Edge.frame:ClearAllPoints()
        Edge.frame:SetPoint("CENTER", Minimap, "CENTER", x, y)
        -- The art points up; rotation counts counterclockwise.
        if Edge.frame.Arrow.SetRotation then
            Edge.frame.Arrow:SetRotation(atan2(-x, y))
        end
        Edge.frame:Show()
    end
end

local function HideMiniPins(from)
    if from == 1 then
        Edge.Hide()
    end
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
    -- Every way out that hides the pins also forgets the last state, so they come back as soon as
    -- they may, not only once you move.
    if not (db and db.minimap and Minimap and not IsOff("MapPins")) then
        HideMiniPins(1)
        lastState = nil
        return
    end
    if not (C_Map and C_Map.GetPlayerMapPosition and C_Map.GetWorldPosFromMapPos and CreateVector2D) then
        HideMiniPins(1)
        lastState = nil
        return
    end
    local mapID = PlayerMap()
    local position = mapID and C_Map.GetPlayerMapPosition(mapID, "player")
    local px, py
    if position then
        px, py = position:GetXY()
        px, py = Safe(px), Safe(py)
    end
    local here = miniScratch.here
    here.mapID, here.x, here.y, here.world = mapID, px, py, nil
    local me = px and py and WorldOf(here)
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
        lastState = nil
        return
    end
    local radius = MapPins_MinimapRadius()
    local halfW, halfH = (Minimap:GetWidth() or 0) / 2, (Minimap:GetHeight() or 0) / 2
    local target, targetKey = Edge.Target()
    local parts = miniScratch.state
    parts[1], parts[2], parts[3], parts[4] = me.continent, math.floor(me.x * 2), math.floor(me.y * 2), radius
    parts[5], parts[6], parts[7] = halfW, facing and math.floor(facing * 100) or "-", targetKey or "-"
    local state = table.concat(parts, ":", 1, 7)
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
                    if pin.SetAlpha then
                        pin:SetAlpha(MapPins_FadeAlpha(math.sqrt(east * east + north * north), radius))
                    end
                    pin:Show()
                end
            end
        end
    end
    HideMiniPins(used + 1)
    Edge.Place(target, me, axis, radius, halfW, halfH, facing, square)
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
        -- Between checks, keep our pins under the map while it pans or zooms, and drop them the
        -- moment it closes or shows another zone (the overlay is on UIParent, so it would otherwise
        -- stay on screen, or show the last zone's pins, until the next check). Reads only; nothing
        -- moves unless the map, its zone or its rectangle changed.
        if overlay:IsShown() then
            UpdateWorld()
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
    givers = function() return type(LevelGuide_QuestGivers) == "function" end,
    places = function() return LandmarksDB ~= nil end,
    deaths = function() return DeathNotesDB ~= nil end,
    rares = function() return RareWatchDB ~= nil end,
    farms = function() return type(GoldGuideData) == "table" end,
    dungeons = function() return type(DungeonsData) == "table" end,
    camps = function() return type(LevelGuideQuestFacts) == "table" end,
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
            Print("I don't know a layer called '" .. what .. "'. Try: guide, givers, places, deaths, rares, farms, dungeons, camps, all.")
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
        Print("Type: off deaths   Or: on camps   Or: minimap off")
    end
    if dirty then
        Rebuild()
    end
    local here = PlayerMap()
    local hereName = MapName(here)
    Print("|cffffd100Pins on your world map and minimap|r |cff999999(click a pin to set a map pin there)|r")
    for _, layer in ipairs(LAYERS) do
        local state
        if not LayerWanted(layer.key) then
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
    "ZONE_CHANGED_NEW_AREA", "PLAYER_LEVEL_UP", "PLAYER_REGEN_ENABLED", "MINIMAP_UPDATE_ZOOM", "QUEST_LOG_UPDATE" }) do
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
    if event == "QUEST_LOG_UPDATE" then
        -- Only the objective camps follow the quest log; still at most one rebuild a second.
        if LayerOn("camps") then
            lastState = nil
            MarkDirty()
        end
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
