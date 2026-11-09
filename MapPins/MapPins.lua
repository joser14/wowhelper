-- MapPins: draws our own pins on the world map and the minimap for what the other helpers know:
-- the guide's next stops, remembered places, your deaths, rares, gold farms for your level and
-- dungeon entrances. Read-only: it reads the other helpers' saved data and your map position.
--
-- How it attaches (Blizzard's documented extension points, nothing of theirs is changed):
--   World map: a data provider made with CreateFromMixins(MapCanvasDataProviderMixin) and added with
--     WorldMapFrame:AddDataProvider(provider). The map calls our RefreshAllData / OnMapChanged /
--     RemoveAllData itself; we place pins with map:AcquirePin("MapPinsPinTemplate", record) and clear
--     them with map:RemoveAllPinsByTemplate("MapPinsPinTemplate"). The template is a virtual frame in
--     MapPins.xml whose mixin (MapPinsPinMixin) takes MapCanvasPinMixin's methods.
--   Minimap: our own small buttons parented to Minimap, placed by our own throttled OnUpdate.
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

local TEMPLATE = "MapPinsPinTemplate"
local TICK = 0.1            -- minimap placement, seconds
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
local provider               -- our world map data provider
local worldPending = false   -- a world map refresh waits for combat to end
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
    local function Count(t)
        local n = 0
        if type(t) == "table" then
            for _ in pairs(t) do
                n = n + 1
            end
        end
        parts[#parts + 1] = n
    end
    Count(RealmTable(LandmarksDB, "places"))
    Count(RealmTable(DeathNotesDB, "deaths"))
    Count(RealmTable(RareWatchDB, "rares"))
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

-- A click on one of our pins sets the game's own map pin there and tracks it.
local function SetWaypoint(mapID, record)
    if not (record and mapID and C_Map and C_Map.SetUserWaypoint and UiMapPoint and UiMapPoint.CreateFromCoordinates) then
        return false
    end
    if C_Map.CanSetUserWaypointOnMap and not Safe(C_Map.CanSetUserWaypointOnMap(mapID)) then
        return false
    end
    local wasSet = C_Map.SetUserWaypoint(UiMapPoint.CreateFromCoordinates(mapID, record.x, record.y))
    if Safe(wasSet) == false then
        return false
    end
    if C_SuperTrack and C_SuperTrack.SetSuperTrackedUserWaypoint then
        C_SuperTrack.SetSuperTrackedUserWaypoint(true)
    end
    return true
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

-- The pin template's mixin. MapCanvasPinMixin's methods are copied in when the map is ready, so this
-- works whether Blizzard's map code loads before or after us.
MapPinsPinMixin = {}

function MapPinsPinMixin:OnLoad()
    if self.UseFrameLevelType then
        self:UseFrameLevelType("PIN_FRAME_LEVEL_AREA_POI")
    end
    if self.SetScalingLimits then
        self:SetScalingLimits(1, 1.0, 1.2)
    end
    self.mapPinsReady = true
end

local function NoCenter()
    return nil
end

function MapPinsPinMixin:OnAcquired(record, mapID)
    if not self.mapPinsReady then
        self:OnLoad()
    end
    self.record, self.mapID = record, mapID
    if type(record) ~= "table" or not (record.x and record.y) then
        self:Hide()
        return
    end
    -- Forever's gamepad cursor reads every canvas pin's centre, and reading an addon pin's centre
    -- taints its protected target update when the map closes. With the gamepad UI on, our pins (our
    -- own objects) give it no centre; the mouse still hovers and clicks them as usual.
    if InputUtil and InputUtil.IsGamepadUIEnabled and Safe(InputUtil.IsGamepadUIEnabled()) then
        self.GetCenter = NoCenter
    else
        self.GetCenter = nil  -- back to the frame's own method
    end
    local size = ApplyIcon(self.Icon, record and record.icon, WORLD_SIZE)
    self:SetSize(size, size)
    self:SetPosition(record.x, record.y)
end

function MapPinsPinMixin:OnReleased()
    self.record, self.mapID = nil, nil
end

function MapPinsPinMixin:OnMouseEnter()
    ShowTooltip(self, self.record)
end

function MapPinsPinMixin:OnMouseLeave()
    HideTooltip()
end

-- The canvas reports a click through OnMouseUp (upInside is false when the button left the pin) and,
-- on newer maps, OnMouseClickAction as well; one click sets the waypoint once.
function MapPinsPinMixin:MapPinsClick(button)
    if button ~= "LeftButton" or not self.record then
        return
    end
    local now = GetTime and GetTime() or 0
    if self.clickedAt == now then
        return
    end
    self.clickedAt = now
    SetWaypoint(self.mapID, self.record)
end

function MapPinsPinMixin:OnMouseUp(button, upInside)
    if upInside ~= false then
        self:MapPinsClick(button)
    end
end

function MapPinsPinMixin:OnMouseClickAction(button)
    self:MapPinsClick(button)
end

-- Whether a pin belongs on the map the canvas shows: static points by zone name, live ones by ID.
local function OnMap(record, mapID, mapName)
    if record.zone and mapName then
        return SameName(record.zone, mapName)
    end
    return record.mapID == mapID
end

local function WorldRefresh(map)
    if not map then
        return
    end
    if InCombat() then
        -- Adding and removing canvas pins isn't done in combat; ours just hide until it ends.
        if map.EnumeratePinsByTemplate then
            for pin in map:EnumeratePinsByTemplate(TEMPLATE) do
                pin:Hide()
            end
        end
        worldPending = true
        return
    end
    worldPending = false
    map:RemoveAllPinsByTemplate(TEMPLATE)
    if not db or IsOff("MapPins") then
        return
    end
    local mapID = Safe(map:GetMapID())
    if not mapID then
        return
    end
    if dirty then
        Rebuild()
    end
    local mapName = MapName(mapID)
    for _, record in ipairs(records) do
        if OnMap(record, mapID, mapName) then
            map:AcquirePin(TEMPLATE, record, mapID)
        end
    end
end

local function SetupWorldMap()
    if provider or not (WorldMapFrame and WorldMapFrame.AddDataProvider and CreateFromMixins
        and MapCanvasDataProviderMixin and MapCanvasPinMixin) then
        return
    end
    for key, value in pairs(MapCanvasPinMixin) do
        if MapPinsPinMixin[key] == nil then
            MapPinsPinMixin[key] = value
        end
    end
    provider = CreateFromMixins(MapCanvasDataProviderMixin)
    function provider:RemoveAllData()
        local map = self:GetMap()
        if map and not InCombat() then
            map:RemoveAllPinsByTemplate(TEMPLATE)
        end
    end
    function provider:RefreshAllData()
        WorldRefresh(self:GetMap())
    end
    function provider:OnMapChanged()
        self:RefreshAllData()
    end
    WorldMapFrame:AddDataProvider(provider)
end

local function RefreshWorldMap()
    if provider and provider.GetMap and provider:GetMap() and WorldMapFrame and WorldMapFrame:IsShown() then
        provider:RefreshAllData()
    end
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

local function MiniPin(index)
    local pin = miniPins[index]
    if not pin then
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
        miniPins[index] = pin
    end
    return pin
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
                if inside then
                    used = used + 1
                    local pin = MiniPin(used)
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
                RefreshWorldMap()
            elseif worldPending then
                RefreshWorldMap()
            end
        end
    end
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
for _, event in ipairs({ "PLAYER_LOGIN", "ADDON_LOADED", "PLAYER_ENTERING_WORLD", "ZONE_CHANGED", "ZONE_CHANGED_INDOORS",
    "ZONE_CHANGED_NEW_AREA", "PLAYER_LEVEL_UP", "PLAYER_REGEN_ENABLED", "MINIMAP_UPDATE_ZOOM" }) do
    events:RegisterEvent(event)
end
events:SetScript("OnEvent", function(_, event, name)
    if event == "PLAYER_LOGIN" then
        MapPinsDB = type(MapPinsDB) == "table" and MapPinsDB or {}
        db = MapPinsDB
        db.layers = type(db.layers) == "table" and db.layers or {}
        if db.minimap == nil then
            db.minimap = true
        end
        SetupWorldMap()
        MarkDirty()
        return
    end
    if event == "ADDON_LOADED" then
        if name == "Blizzard_WorldMap" or name == "Blizzard_MapCanvas" then
            SetupWorldMap()
        end
        return
    end
    if event == "MINIMAP_UPDATE_ZOOM" then
        lastState = nil
        return
    end
    if event == "PLAYER_REGEN_ENABLED" then
        if worldPending then
            RefreshWorldMap()
        end
        return
    end
    -- Zone changes, entering the world, a new level: the farms and "this zone" counts change.
    lastState = nil
    MarkDirty()
end)
