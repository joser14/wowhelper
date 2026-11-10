-- RareWatch: reads the same minimap markers, nameplates, target and mouseover the game already shows
-- you, speaks up about rares, remembers where and when you saw each one, and guesses your layer from
-- the IDs of NPCs around you. Read-only: it never targets, marks or sends anything.

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

local REPEAT_SECONDS = 300          -- a new minimap marker for the same rare (a respawn) may alert again after this
local UNIT_REPEAT_SECONDS = 600     -- a rare seen by nameplate, target or mouseover alerts again after this
local NEW_SIGHTING_SECONDS = 600    -- seeing it again after this long counts as another sighting
local RECENT_SECONDS = 86400        -- the page lists rares seen in the last day
local MAX_RARES = 300
local LAYER_SAMPLES = 10           -- the most recent NPCs the layer guess is made from
local LAYER_MIN_FOR_CHANGE = 3      -- a new layer needs this many NPCs behind it before it counts as a change
local LAYER_NOTICE_SECONDS = 300    -- how long the hub shows "Layer changed"
local RARE_ATLAS, TREASURE_ATLAS = "VignetteKill", "VignetteLoot"
local RARE_CLASSES = { rare = true, rareelite = true, worldboss = true }
local DIRECTIONS = { "east", "north-east", "north", "north-west", "west", "south-west", "south", "south-east" }

-- Forever-only rares we checked ourselves (2026-11-10): each NPC ID, name and zone confirmed on
-- wowhead.com/forever, level, rare/rare-elite and one spawn spot (map percent) from warcraft.wiki.gg.
-- Facts only, no third-party table copied. Still to confirm in game. Zephras Isle is uiMapID 2521.
local KNOWN_RARES = {
    [255887] = { name = "Slydris", level = 6, class = "rareelite", mapID = 2521, x = 50.6, y = 51.2 },
    [256028] = { name = "The Lost One", level = 6, class = "rareelite", mapID = 2521, x = 53.2, y = 48.0 },
    [256492] = { name = "Fernfeather", level = 10, class = "rare", mapID = 2521, x = 51.4, y = 82.4 },
    [259398] = { name = "Galemender Delanea", level = 11, class = "rare", mapID = 2521, x = 63.0, y = 61.2 },
    [250936] = { name = "Den'dralass", level = 13, class = "rare", mapID = 2521, x = 60.1, y = 33.5 },
    [259388] = { name = "Mystmane", level = 13, class = "rare", mapID = 2521, x = 60.7, y = 36.1 },
    [259385] = { name = "Tel'daeor the Stormspeaker", level = 13, class = "rare", mapID = 2521, x = 66.0, y = 53.8 },
}
local KNOWN_ZONE_NAMES = { [2521] = "Zephras Isle" }
local NAMEPLATES = 40

local active = {}
local announced = {}
local db
local mapSizes = {}

-- Layer guess: recent NPC GUIDs and the server/zone pair most of them share.
local layer = { samples = {}, current = nil, previous = nil, changedAt = nil, hidden = false }

local function Safe(value)
    if issecretvalue and issecretvalue(value) then
        return nil
    end
    return value
end

local function Now()
    return (time and Safe(time())) or 0
end

-- Pop-ups and page lines go only to the hub window. Without it, stay quiet: no chat, and no
-- writing into the game's own frames.
local function Print(text)
    if ForeverHub_Receive then
        return ForeverHub_Receive("RareWatch", text)
    end
end
local Alert = Print

-- Quiet when RareWatch is switched off on the hub's Manage page, or the hub's Alerts > Sound is off
-- (its own text promises no chime for a rare then). Reads the hub's saved switches; never writes them.
local function SoundAllowed()
    if ForeverHub_IsOff and ForeverHub_IsOff("RareWatch") then
        return false
    end
    local hub = type(ForeverHubDB) == "table" and ForeverHubDB
    local alerts = hub and type(hub.alerts) == "table" and hub.alerts
    return not (alerts and alerts.sound == false)
end

local function PlayAlertSound()
    if not SoundAllowed() then
        return
    end
    if PlaySound and SOUNDKIT and SOUNDKIT.RAID_WARNING then
        pcall(PlaySound, SOUNDKIT.RAID_WARNING)
    end
end

-- Where you are: the map you're on, your place on it, and the same spot in world yards so
-- distances work across maps on one continent.
local function WorldSpot(mapID, x, y)
    local spot = { mapID = mapID, x = x, y = y }
    if C_Map.GetWorldPosFromMapPos and CreateVector2D then
        local continent, world = C_Map.GetWorldPosFromMapPos(mapID, CreateVector2D(x, y))
        continent, world = Safe(continent), Safe(world)
        if continent and world then
            local wx, wy = world:GetXY()
            spot.continent, spot.wx, spot.wy = continent, Safe(wx), Safe(wy)
        end
    end
    return spot
end

local function Here()
    if not (C_Map and C_Map.GetBestMapForUnit and C_Map.GetPlayerMapPosition) then
        return nil
    end
    local mapID = Safe(C_Map.GetBestMapForUnit("player"))
    local position = mapID and Safe(C_Map.GetPlayerMapPosition(mapID, "player"))
    if not position then
        return nil
    end
    local x, y = position:GetXY()
    x, y = Safe(x), Safe(y)
    if not (x and y) then
        return nil
    end
    return WorldSpot(mapID, x, y)
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
    if spot and place and spot.continent and place.continent and spot.continent == place.continent and spot.wx and place.wx then
        return math.sqrt((spot.wx - place.wx) ^ 2 + (spot.wy - place.wy) ^ 2)
    end
    return nil
end

local function YardsText(yards)
    if yards >= 1000 then
        return string.format("%.1f k yd", yards / 1000)
    end
    return string.format("%d yd", math.floor(yards))
end

local function AgoText(when)
    local seconds = Now() - (when or 0)
    if seconds < 60 then
        return "just now"
    elseif seconds < 3600 then
        return string.format("%d min ago", math.floor(seconds / 60))
    elseif seconds < 86400 then
        return string.format("%d h ago", math.floor(seconds / 3600))
    end
    return string.format("%d day(s) ago", math.floor(seconds / 86400))
end

-- How many yards wide and tall a map is, from where its corners sit in the world.
local function MapSize(mapID)
    if mapSizes[mapID] ~= nil then
        return mapSizes[mapID] or nil
    end
    local size = false
    local corner, right, bottom = WorldSpot(mapID, 0, 0), WorldSpot(mapID, 1, 0), WorldSpot(mapID, 0, 1)
    local width, height = Yards(corner, right), Yards(corner, bottom)
    if width and height and width > 0 and height > 0 then
        size = { width = width, height = height }
    end
    mapSizes[mapID] = size
    return size or nil
end

-- "120 yd north-east" from your spot to another spot on the same map, or nil if it can't be worked out.
local function Bearing(from, to)
    if not (from and to and from.mapID == to.mapID) then
        return nil
    end
    local size = MapSize(from.mapID)
    if not size then
        return nil
    end
    local east = (to.x - from.x) * size.width
    local north = (from.y - to.y) * size.height
    local yards = math.sqrt(east * east + north * north)
    if yards < 30 then
        return "right by you"
    end
    local atan2 = math.atan2 or math.atan
    local angle = math.deg(atan2(north, east)) % 360
    local index = math.floor((angle + 22.5) / 45) % 8 + 1
    return YardsText(yards) .. " " .. DIRECTIONS[index]
end

-- Creature-0-<server>-<instance>-<zone>-<npcID>-<spawn>
local function ParseGUID(guid)
    if type(guid) ~= "string" then
        return nil
    end
    local kind, _, server, _, zone, npcID = guid:match("^([^-]+)-([^-]+)-([^-]+)-([^-]+)-([^-]+)-([^-]+)-([^-]+)$")
    if kind ~= "Creature" and kind ~= "Vehicle" then
        return nil
    end
    return { server = server, zone = zone, npcID = tonumber(npcID) }
end

---------------------------------------------------------------------------- layer

local function LayerCounts()
    local counts = {}
    for _, sample in ipairs(layer.samples) do
        counts[sample.key] = (counts[sample.key] or 0) + 1
    end
    return counts
end

local function NoteLayer(guid, parsed)
    for _, sample in ipairs(layer.samples) do
        if sample.guid == guid then
            return
        end
    end
    table.insert(layer.samples, { guid = guid, key = parsed.server .. "-" .. parsed.zone })
    while #layer.samples > LAYER_SAMPLES do
        table.remove(layer.samples, 1)
    end
    local counts = LayerCounts()
    -- Ties keep the current guess, so one stray NPC can't flip it.
    local best = layer.current and counts[layer.current] and layer.current
    for key, count in pairs(counts) do
        if not best or count > counts[best] then
            best = key
        end
    end
    if not layer.current then
        layer.current = best
    elseif best ~= layer.current and counts[best] >= LAYER_MIN_FOR_CHANGE then
        layer.previous, layer.current = layer.current, best
        layer.changedAt = GetTime and Safe(GetTime())
    end
end

-- A new zone has its own IDs, so the guess starts over and the change notice doesn't carry across.
local function ResetLayer()
    layer.samples, layer.current, layer.previous, layer.changedAt, layer.hidden = {}, nil, nil, nil, false
end

local function LayerChangedRecently()
    local now = GetTime and Safe(GetTime())
    return layer.changedAt and now and now - layer.changedAt < LAYER_NOTICE_SECONDS
end

---------------------------------------------------------------------------- remembering rares

local function LevelText(rare)
    local level = tonumber(rare.level)
    local text = (level and level > 0) and ("level " .. level) or "level ??"
    if rare.class == "rareelite" then
        text = text .. " elite"
    elseif rare.class == "worldboss" then
        text = text .. " world boss"
    end
    return text
end

local function Trim()
    local count, oldestKey, oldest = 0, nil, nil
    for key, rare in pairs(db.rares) do
        count = count + 1
        if not oldest or (rare.seen or 0) < oldest then
            oldestKey, oldest = key, rare.seen or 0
        end
    end
    if count > MAX_RARES then
        db.rares[oldestKey] = nil
        return Trim()
    end
end

-- One record per NPC. A marker whose creature ID can't be read is kept by name until it's seen up close.
local function Record(npcID, name, info)
    if not (db and type(name) == "string" and name ~= "") then
        return nil
    end
    local now = Now()
    local nameKey = "name:" .. name
    local key = npcID or nameKey
    local rare = db.rares[key]
    if npcID and db.rares[nameKey] then
        -- Seen first by name only: that record is this NPC. Keep one, never both.
        rare = rare or db.rares[nameKey]
        db.rares[nameKey] = nil
    elseif not npcID and not rare then
        -- No ID this time (hidden in combat, say): a record already kept under its ID is this one.
        for id, other in pairs(db.rares) do
            if type(id) == "number" and type(other) == "table" and other.name == name then
                key, rare = id, other
                break
            end
        end
    end
    if not rare then
        rare = { first = now, count = 0 }
    end
    db.rares[key] = rare
    rare.name = name
    rare.level = info.level or rare.level
    rare.class = info.class or rare.class
    local spot = info.spot
    if info.dead then
        -- The first time it's seen dead since it was last seen alive is when it was killed.
        if not (rare.killed and rare.seen and rare.killed >= rare.seen) then
            rare.killed = now
        end
        if rare.seen then
            spot = nil
        else
            rare.seen, rare.count = now, 1
        end
    else
        if not rare.seen or now - rare.seen >= NEW_SIGHTING_SECONDS then
            rare.count = (rare.count or 0) + 1
        end
        rare.seen = now
    end
    -- Your own spot doesn't replace the rare's real spot read from the minimap a moment ago.
    if spot and (info.exact or not (rare.exact and rare.placed and now - rare.placed < 60)) then
        rare.mapID, rare.x, rare.y = spot.mapID, spot.x, spot.y
        rare.continent, rare.wx, rare.wy = spot.continent, spot.wx, spot.wy
        rare.exact, rare.placed = info.exact or false, now
        rare.where = PlaceName()
    end
    Trim()
    return rare
end

---------------------------------------------------------------------------- minimap markers

local function KindOf(info)
    local atlas = Safe(info.atlasName)
    if type(atlas) ~= "string" then
        return nil
    elseif atlas:find(RARE_ATLAS, 1, true) then
        return "rare"
    elseif atlas:find(TREASURE_ATLAS, 1, true) then
        return "treasure"
    end
end

-- Respawns get a new marker, so repeats are judged by name and time.
local function AnnounceRare(name, bearing)
    local now = GetTime()
    if announced[name] and now - announced[name] < REPEAT_SECONDS then
        return
    end
    announced[name] = now
    Alert("Rare nearby: " .. name .. (bearing and (", " .. bearing) or "") .. ". Look for it on your minimap.")
    PlayAlertSound()
end

-- Where the marker is, read from the map you're on.
local function MarkerSpot(guid, here)
    if not (here and C_VignetteInfo.GetVignettePosition) then
        return nil
    end
    local position = Safe(C_VignetteInfo.GetVignettePosition(guid, here.mapID))
    if not position then
        return nil
    end
    local x, y = position:GetXY()
    x, y = Safe(x), Safe(y)
    if not (x and y) then
        return nil
    end
    return WorldSpot(here.mapID, x, y)
end

---------------------------------------------------------------------------- watch list
-- Your own watch list (research\re_round4.md R20): NPCs by name or NPC ID, account-wide, any classification.
-- A name match stores the NPC ID, so the entry keeps matching when the name changes (another client language,
-- a renamed Forever mob). The idea is from MobSpot by Archydude (MIT, see NOTICE.md); our own code. Only what
-- the game shows you is read (nameplates, target, mouseover, minimap markers); never TargetUnit, which Forever
-- refuses from addons anyway.
local Watch = { MAX = 50, markers = {}, alerted = {} }

function Watch.List()
    RareWatchDB = type(RareWatchDB) == "table" and RareWatchDB or {}
    RareWatchDB.watch = type(RareWatchDB.watch) == "table" and RareWatchDB.watch or {}
    return RareWatchDB.watch
end

function Watch.Label(entry)
    return entry.name or ("NPC " .. tostring(entry.id))
end

-- The entry for this NPC (by ID first, then by name, learning the ID), or nil.
function Watch.Match(npcID, name)
    local list = Watch.List()
    if #list == 0 then
        return nil
    end
    local lower = type(name) == "string" and name:lower() or nil
    for _, entry in ipairs(list) do
        if npcID and entry.id == npcID then
            if name and not entry.name then
                entry.name = name
            end
            return entry
        end
    end
    for _, entry in ipairs(list) do
        if lower and not entry.id and type(entry.name) == "string" and entry.name:lower() == lower then
            entry.id = npcID
            return entry
        end
    end
end

function Watch.Alert(entry, text)
    local key = tostring(entry.id or entry.name)
    local now = GetTime()
    if Watch.alerted[key] and now - Watch.alerted[key] < UNIT_REPEAT_SECONDS then
        return
    end
    Watch.alerted[key] = now
    Alert("Watched: " .. text)
    PlayAlertSound()
end

-- "watch <name or NPC ID>" / "unwatch <name or NPC ID>" from the page.
function Watch.Command(verb, rest)
    local list = Watch.List()
    local id = tonumber(rest:match("^(%d+)$"))
    local lower = rest:lower()
    local found
    for index, entry in ipairs(list) do
        if (id and entry.id == id) or (not id and type(entry.name) == "string" and entry.name:lower() == lower) then
            found = index
            break
        end
    end
    if verb == "unwatch" then
        if found then
            local entry = table.remove(list, found)
            Print("Stopped watching " .. Watch.Label(entry) .. ".")
        else
            Print("Not on your watch list: " .. rest .. ".")
        end
        return
    end
    if found then
        Print("Already watching " .. Watch.Label(list[found]) .. ".")
    elseif #list >= Watch.MAX then
        Print(string.format("Your watch list is full (%d). Type unwatch <name> to make room.", Watch.MAX))
    else
        list[#list + 1] = id and { id = id } or { name = rest }
        Print("Watching " .. Watch.Label(list[#list]) .. ". You'll get a pop-up and a sound when it's near.")
    end
end

-- A minimap marker of a watched NPC (that isn't a rare's, which alerts on its own), once per marker.
function Watch.Marker(guid, info, name, kind)
    if kind == "rare" or Watch.markers[guid] or Safe(info.isDead) or Safe(info.onMinimap) == false then
        return
    end
    local parsed = ParseGUID(Safe(info.objectGUID))
    local entry = Watch.Match(parsed and parsed.npcID, name)
    if not entry then
        return
    end
    Watch.markers[guid] = true
    local here = Here()
    local yards = Yards(MarkerSpot(guid, here), here)
    local distance = ""
    if yards then
        distance = yards >= 1000 and (", about " .. YardsText(yards)) or string.format(", about %d yd", math.floor(yards + 0.5))
    end
    Watch.Alert(entry, name .. " on your minimap" .. distance .. ".")
end

local function ReadMarker(guid)
    local info = C_VignetteInfo.GetVignetteInfo(guid)
    local name = info and Safe(info.name)
    local kind = info and KindOf(info)
    local dead = info and Safe(info.isDead)
    local bearing
    if db and name then
        Watch.Marker(guid, info, name, kind)
    end
    if db and name and kind == "rare" and (dead or Safe(info.onMinimap) ~= false) then
        local parsed = ParseGUID(Safe(info.objectGUID))
        local here = Here()
        local spot = not dead and MarkerSpot(guid, here)
        bearing = spot and Bearing(here, spot)
        Record(parsed and parsed.npcID, name, { dead = dead, spot = spot, exact = spot and true })
    end
    if not (name and kind) or dead or Safe(info.onMinimap) == false then
        active[guid] = nil
        return
    end
    -- Markers are re-read on every update, so only a newly appeared one may alert; one you're
    -- standing next to would otherwise sound again every few minutes.
    local isNew = not active[guid]
    active[guid] = { name = name, kind = kind }
    if kind == "rare" and isNew then
        AnnounceRare(name, bearing)
    end
end

local function ReadAllMarkers()
    local listed = {}
    for _, guid in ipairs(C_VignetteInfo.GetVignettes() or {}) do
        guid = Safe(guid)
        if guid then
            listed[guid] = true
            ReadMarker(guid)
        end
    end
    for guid in pairs(active) do
        if not listed[guid] then
            active[guid] = nil
        end
    end
    for guid in pairs(Watch.markers) do
        if not listed[guid] then
            Watch.markers[guid] = nil
        end
    end
end

---------------------------------------------------------------------------- nameplates, target, mouseover

-- You can only see a unit's own position as your own, so the alert says "near you" and your spot is saved.
local function AnnounceUnit(rare)
    local now = GetTime()
    if announced[rare.name] and now - announced[rare.name] < UNIT_REPEAT_SECONDS then
        return
    end
    announced[rare.name] = now
    Alert(string.format("Rare: %s (%s), near you.", rare.name, LevelText(rare)))
    PlayAlertSound()
end

-- deathOnly: just check whether a rare you're looking at has died (health updates), without
-- counting it toward the layer guess or alerting.
local function SeeUnit(unit, deathOnly)
    if not (UnitGUID and type(unit) == "string") then
        return
    end
    if UnitExists and not Safe(UnitExists(unit)) then
        return
    end
    local raw = UnitGUID(unit)
    local guid = Safe(raw)
    if raw ~= nil and guid == nil then
        layer.hidden = true
        return
    end
    local parsed = ParseGUID(guid)
    if not parsed then
        return
    end
    if not deathOnly then
        NoteLayer(guid, parsed)
    end
    local class = UnitClassification and Safe(UnitClassification(unit))
    local known = KNOWN_RARES[parsed.npcID]
    -- A verified Forever rare counts even when the game hides its classification.
    if known and class == nil then
        class = known.class
    end
    -- Your watch list: any classification, never a player; a rare's own alert covers a watched rare.
    if not deathOnly and not RARE_CLASSES[class] and not (UnitIsPlayer and Safe(UnitIsPlayer(unit))) then
        local name = UnitName and Safe(UnitName(unit))
        local entry = Watch.Match(parsed.npcID, name)
        if entry and not (UnitIsDead and Safe(UnitIsDead(unit))) then
            local level = UnitLevel and Safe(UnitLevel(unit))
            Watch.Alert(entry, string.format("%s%s, near you.", name or Watch.Label(entry),
                type(level) == "number" and level > 0 and (" (" .. level .. ")") or ""))
        end
    end
    if not RARE_CLASSES[class] or (UnitIsPlayer and Safe(UnitIsPlayer(unit))) then
        return
    end
    local dead = UnitIsDead and Safe(UnitIsDead(unit))
    if deathOnly and not dead then
        return
    end
    local name = UnitName and Safe(UnitName(unit)) or (known and known.name)
    local level = UnitLevel and Safe(UnitLevel(unit)) or (known and known.level)
    local rare = Record(parsed.npcID, name, {
        level = tonumber(level), class = class, dead = dead, spot = not dead and Here() or nil, exact = false,
    })
    if rare and not dead then
        AnnounceUnit(rare)
    end
end

-- In combat the game hides unit IDs and names (and marker names), so rares seen then were skipped.
-- Once combat ends, look again at every nameplate, the target, the mouseover and the minimap markers.
local function Rescan()
    for index = 1, NAMEPLATES do
        local unit = "nameplate" .. index
        if UnitExists and Safe(UnitExists(unit)) then
            pcall(SeeUnit, unit)
        end
    end
    pcall(SeeUnit, "target")
    pcall(SeeUnit, "mouseover")
    if C_VignetteInfo and C_VignetteInfo.GetVignettes then
        pcall(ReadAllMarkers)
    end
end

-- The verified rares of a map (by ID, or by the zone's name for a map numbered differently).
local function KnownOn(mapID)
    local list = {}
    if not mapID then
        return list
    end
    local info = C_Map and C_Map.GetMapInfo and C_Map.GetMapInfo(mapID)
    local name = type(info) == "table" and Safe(info.name) or nil
    for npcID, rare in pairs(KNOWN_RARES) do
        if rare.mapID == mapID or (name and KNOWN_ZONE_NAMES[rare.mapID] == name) then
            list[#list + 1] = { npcID = npcID, rare = rare }
        end
    end
    table.sort(list, function(a, b)
        if a.rare.level ~= b.rare.level then
            return a.rare.level < b.rare.level
        end
        return a.rare.name < b.rare.name
    end)
    return list
end

-- For MapPins: the verified Forever rares, { npcID, name, level, class, mapID, x, y (0-1) }.
function RareWatch_KnownRares()
    local list = {}
    for npcID, rare in pairs(KNOWN_RARES) do
        list[#list + 1] = { npcID = npcID, name = rare.name, level = rare.level, class = rare.class,
            mapID = rare.mapID, x = rare.x / 100, y = rare.y / 100 }
    end
    table.sort(list, function(a, b) return a.npcID < b.npcID end)
    return list
end

---------------------------------------------------------------------------- page

-- Most recently seen first. The recent list is the start of the full list, so numbers match on both.
local function Ordered()
    local list = {}
    for _, rare in pairs(db.rares) do
        list[#list + 1] = rare
    end
    table.sort(list, function(a, b)
        if (a.seen or 0) ~= (b.seen or 0) then
            return (a.seen or 0) > (b.seen or 0)
        end
        return (a.name or "") < (b.name or "")
    end)
    return list
end

local function RareLine(index, rare, spot)
    local text = string.format("|cffffd100%d.|r %s (%s), %s", index, rare.name or "?", LevelText(rare), rare.where or "unknown spot")
    local tail = { "seen " .. AgoText(rare.seen) }
    if rare.killed then
        tail[#tail + 1] = "killed " .. AgoText(rare.killed)
    end
    if (rare.count or 0) > 1 then
        tail[#tail + 1] = rare.count .. " sightings"
    end
    local yards = Yards(spot, rare)
    if yards then
        tail[#tail + 1] = YardsText(yards) .. " away"
    end
    return text .. " |cff999999" .. table.concat(tail, ", ") .. "|r"
end

local function Pin(rare)
    if not (rare and rare.mapID and rare.x and C_Map and C_Map.SetUserWaypoint and UiMapPoint and UiMapPoint.CreateFromCoordinates) then
        return false
    end
    return (ForeverWaypoint_Set(rare.mapID, rare.x, rare.y, rare.name))
end

local function ShowLayer()
    if layer.current then
        local counts = LayerCounts()
        Print(string.format("|cffffd100Layer:|r %s |cff999999(from %d of the last %d NPCs near you)|r",
            layer.current, counts[layer.current] or 0, #layer.samples))
    elseif layer.hidden then
        Print("|cffffd100Layer:|r unknown |cff999999(the game is hiding NPC IDs right now)|r")
    else
        Print("|cffffd100Layer:|r unknown |cff999999(no NPCs seen in this zone yet)|r")
    end
    if LayerChangedRecently() and layer.previous then
        Print(string.format("|cff88bbeeLayer changed|r from %s to %s.", layer.previous, layer.current))
    end
    Print("|cff999999The layer is an estimate, read from the IDs of NPCs near you. It can be off just after a zone change or in busy cities.|r")
end

local function ShowPage(arg)
    if not db then
        return
    end
    local want = (arg or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
    -- "watch <name or NPC ID>" / "unwatch ...": the name keeps the case you typed.
    local raw = (arg or ""):gsub("^%s+", ""):gsub("%s+$", "")
    local verb, rest = raw:match("^(%a+)%s+(.+)$")
    verb = verb and verb:lower()
    if verb == "watch" or verb == "unwatch" then
        Watch.Command(verb, rest)
        want = ""
    end
    local list = Ordered()
    local showAll = false
    if want == "forget all" or want == "forget everything" then
        Print(string.format("Forgot %d rare(s).", #list))
        db.rares = {}
        list = {}
    elseif want == "all" then
        showAll = true
    elseif tonumber(want:match("^(%d+)$")) then
        local index = tonumber(want)
        local rare = list[index]
        if not rare then
            Print("There's no rare with that number.")
        elseif not rare.mapID then
            Print("That rare has no map position saved, so it can't be pinned.")
        elseif Pin(rare) then
            Print(string.format("Pinned %s: %s%s.", rare.name, rare.where or "?",
                rare.exact and "" or " (where you stood when you saw it)"))
        else
            Print("That spot can't be pinned from this map.")
        end
    elseif want ~= "" then
        Print("Type a number to pin that rare on your map, or: all, or: forget all, or: watch <name or NPC ID>.")
    end
    ShowLayer()
    local watched = {}
    for _, entry in ipairs(Watch.List()) do
        watched[#watched + 1] = Watch.Label(entry)
    end
    if #watched > 0 then
        Print("|cffffd100Watch list:|r " .. table.concat(watched, ", ") .. " |cff999999(unwatch <name> to remove)|r")
    else
        Print("|cff999999Watch list: empty. Type watch <name or NPC ID> to be told when any NPC is near.|r")
    end
    local spot = Here()
    local now = Now()
    local shown = 0
    for index, rare in ipairs(list) do
        if not showAll and now - (rare.seen or 0) > RECENT_SECONDS then
            break
        end
        if shown == 0 then
            Print(showAll and "|cffffd100Every rare remembered:|r" or "|cffffd100Rares seen in the last day:|r")
        end
        shown = shown + 1
        Print(RareLine(index, rare, spot))
    end
    if shown == 0 then
        Print(#list == 0 and "No rares remembered yet. Ones you see on your minimap, nameplates, target or mouseover are saved here."
            or "No rares seen in the last day.")
    end
    if #list > 0 then
        Print(string.format("|cff999999%d rare(s) remembered.%s|r", #list, showAll and "" or " Type all to see every one."))
    end
    -- Known rares of the zone you're in that you haven't seen in the last day.
    local missing = {}
    for _, entry in ipairs(KnownOn(spot and spot.mapID or (C_Map and C_Map.GetBestMapForUnit and Safe(C_Map.GetBestMapForUnit("player"))))) do
        local seen = db.rares[entry.npcID]
        if not (seen and now - (seen.seen or 0) <= RECENT_SECONDS) then
            missing[#missing + 1] = string.format("%s (%s, %.0f, %.0f)", entry.rare.name, LevelText(entry.rare), entry.rare.x, entry.rare.y)
        end
    end
    if #missing > 0 then
        Print("|cffffd100Known rares here, not seen today:|r " .. table.concat(missing, "; "))
    end
end

---------------------------------------------------------------------------- events

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:RegisterEvent("VIGNETTES_UPDATED")
events:RegisterEvent("VIGNETTE_MINIMAP_UPDATED")
-- Unit events are optional: if one is refused, the minimap alerts keep working.
for _, name in ipairs({ "NAME_PLATE_UNIT_ADDED", "PLAYER_TARGET_CHANGED", "UPDATE_MOUSEOVER_UNIT", "UNIT_HEALTH", "ZONE_CHANGED_NEW_AREA",
    "PLAYER_REGEN_ENABLED" }) do
    pcall(events.RegisterEvent, events, name)
end
events:SetScript("OnEvent", function(_, event, guid, onMinimap)
    if event == "PLAYER_LOGIN" then
        RareWatchDB = type(RareWatchDB) == "table" and RareWatchDB or {}
        local realm = (GetRealmName and Safe(GetRealmName())) or "Unknown"
        RareWatchDB[realm] = type(RareWatchDB[realm]) == "table" and RareWatchDB[realm] or {}
        db = RareWatchDB[realm]
        db.rares = type(db.rares) == "table" and db.rares or {}
        return
    elseif event == "NAME_PLATE_UNIT_ADDED" then
        return SeeUnit(Safe(guid))
    elseif event == "PLAYER_TARGET_CHANGED" then
        return SeeUnit("target")
    elseif event == "UPDATE_MOUSEOVER_UNIT" then
        return SeeUnit("mouseover")
    elseif event == "UNIT_HEALTH" then
        if Safe(guid) == "target" then
            SeeUnit("target", true)
        end
        return
    elseif event == "ZONE_CHANGED_NEW_AREA" then
        return ResetLayer()
    elseif event == "PLAYER_REGEN_ENABLED" then
        if db then
            Rescan()
        end
        return
    end
    if not C_VignetteInfo then
        return
    end
    guid = Safe(guid)
    if event == "VIGNETTE_MINIMAP_UPDATED" and guid then
        if Safe(onMinimap) then
            ReadMarker(guid)
        else
            active[guid] = nil
        end
    else
        ReadAllMarkers()
    end
end)

SLASH_RAREWATCH1 = "/rares"
SLASH_RAREWATCH2 = "/rarewatch"
SlashCmdList.RAREWATCH = ShowPage

ForeverHubStatus = ForeverHubStatus or {}
ForeverHubStatus.RareWatch = function()
    local items = {}
    for _, marker in pairs(active) do
        local color = marker.kind == "rare" and "|cffff8040Rare|r " or "|cffffd933Treasure|r "
        items[#items + 1] = { text = color .. marker.name }
    end
    table.sort(items, function(a, b)
        return a.text < b.text
    end)
    if LayerChangedRecently() then
        items[#items + 1] = { text = "|cff88bbeeLayer|r changed", page = "Rares" }
    end
    return items
end
