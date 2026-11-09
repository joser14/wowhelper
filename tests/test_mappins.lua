-- MapPins test: a world map data provider is added through WorldMapFrame:AddDataProvider and places
-- each layer's pins on the right map (live IDs for places/deaths/rares, zone names for farms/dungeons),
-- layers toggle, missing or broken sources and secret values never error, the minimap offset maths is
-- right at 0 degrees and rotated, pins outside the minimap circle hide, clicks set the game's waypoint,
-- combat defers canvas work, and Blizzard's own frames are never shown, hidden or scripted.
-- Run from the harness folder:  node run.js "<workspace root>" test_mappins.lua
local base = ADDON_PATH
local failures = {}
local function check(cond, why) if not cond then failures[#failures + 1] = why end end
local function near(a, b, eps) return type(a) == "number" and type(b) == "number" and math.abs(a - b) <= (eps or 0.01) end

local SECRET = setmetatable({}, { __tostring = function() return "SECRET" end })
issecretvalue = function(v) return v == SECRET end

local out = {}
local hubOff = {}
ForeverHub_Receive = function(_, t) out[#out + 1] = t end
ForeverHub_IsOff = function(name) return hubOff[name] == true end
local chat = 0
DEFAULT_CHAT_FRAME = { AddMessage = function() chat = chat + 1 end }
print = function() chat = chat + 1 end
hooksecurefunc = function(name) failures[#failures + 1] = "hooksecurefunc called on " .. tostring(name) end

local clock = 1000
GetTime = function() return clock end
local combat = false
InCombatLockdown = function() return combat end
GetRealmName = function() return "R" end
local level = 10
UnitLevel = function() return level end
local cvars = { rotateMinimap = "0" }
GetCVar = function(k) return cvars[k] end
local facing = 0
GetPlayerFacing = function() return facing end
local indoors = false
IsIndoors = function() return indoors end
SlashCmdList = {}

-- Generic frame for our own frames.
local function texture()
    local t = {}
    function t:SetAllPoints() end
    function t:SetTexture(f) self.file, self.atlas = f, nil end
    function t:SetAtlas(a) self.atlas, self.file = a, nil end
    function t:SetTexCoord(...) self.coords = { ... } end
    return t
end
local frames = {}
local function newFrame(kind, name, parent)
    local f = { kind = kind, name = name, parent = parent, shown = true, scripts = {}, registered = {}, lines = {} }
    function f:RegisterEvent(e) self.registered[e] = true end
    function f:SetScript(s, fn) self.scripts[s] = fn end
    function f:GetScript(s) return self.scripts[s] end
    function f:SetSize(w, h) self.w, self.h = w, h end
    function f:SetPoint(...) self.point = { ... } end
    function f:ClearAllPoints() self.point = nil end
    function f:Show() self.shown = true end
    function f:Hide() self.shown = false end
    function f:IsShown() return self.shown end
    function f:CreateTexture() return texture() end
    function f:RegisterForClicks() end
    function f:SetFrameLevel(l) self.level = l end
    function f:SetFrameStrata(s) self.strata = s end
    function f:SetOwner(o) self.owner = o; self.lines = {} end
    function f:AddLine(t) self.lines[#self.lines + 1] = t end
    frames[#frames + 1] = f
    return f
end
local tooltipTemplate
CreateFrame = function(kind, name, parent, template)
    local f = newFrame(kind, name, parent)
    if name then _G[name] = f end
    if template == "GameTooltipTemplate" then tooltipTemplate = true end
    return f
end

-- Blizzard frames: anything that would change them is a failure.
local function strict(name, extra)
    local f = extra or {}
    for _, method in ipairs({ "Hide", "Show", "SetScript", "HookScript", "SetParent", "SetPoint", "ClearAllPoints", "SetAlpha", "SetScale" }) do
        f[method] = function() failures[#failures + 1] = name .. ":" .. method .. " was called" end
    end
    return f
end
UIParent = strict("UIParent")
local mmZoom, mmWidth = 0, 140
Minimap = strict("Minimap", {
    GetZoom = function() return mmZoom end,
    GetWidth = function() return mmWidth end,
    GetHeight = function() return mmWidth end,
    GetFrameLevel = function() return 2 end,
})

-- Map canvas mixins as Blizzard's map uses them.
CreateFromMixins = function(...)
    local t = {}
    for _, m in ipairs({ ... }) do for k, v in pairs(m) do t[k] = v end end
    return t
end
MapCanvasDataProviderMixin = {
    OnAdded = function(self, map) self.owningMap = map end,
    GetMap = function(self) return self.owningMap end,
    RemoveAllData = function() end,
    RefreshAllData = function() end,
    OnMapChanged = function(self) self:RefreshAllData() end,
}
MapCanvasPinMixin = {
    SetPosition = function(self, x, y) self.nx, self.ny = x, y end,
    UseFrameLevelType = function(self, t) self.levelType = t end,
    SetScalingLimits = function(self, ...) self.limits = { ... } end,
    OnAcquired = function() end,
    OnReleased = function() end,
}
local canvasMap = 1429
local pins, providers, acquires = {}, {}, 0
WorldMapFrame = strict("WorldMapFrame", {})
WorldMapFrame.IsShown = function() return true end
WorldMapFrame.GetMapID = function() return canvasMap end
WorldMapFrame.AddDataProvider = function(self, p) providers[#providers + 1] = p; p:OnAdded(self) end
WorldMapFrame.AcquirePin = function(self, template, ...)
    acquires = acquires + 1
    assert(not combat, "AcquirePin in combat")
    local pin = newFrame("Frame", nil, self)
    for k, v in pairs(MapPinsPinMixin) do pin[k] = v end
    pin.Icon = texture()
    pin.template = template
    pin:OnLoad()
    pin:OnAcquired(...)
    pins[#pins + 1] = pin
    return pin
end
WorldMapFrame.RemoveAllPinsByTemplate = function(self, template)
    assert(not combat, "RemoveAllPinsByTemplate in combat")
    local keep = {}
    for _, pin in ipairs(pins) do
        if pin.template == template then pin:OnReleased() else keep[#keep + 1] = pin end
    end
    pins = keep
end
WorldMapFrame.EnumeratePinsByTemplate = function(self, template)
    local i = 0
    return function()
        repeat i = i + 1 until not pins[i] or pins[i].template == template
        return pins[i]
    end
end

-- Maps: rectangles on continents. World X runs north, world Y west (the game's convention).
local MAPS = {
    [1429] = { name = "Elwynn Forest", c = 0, top = 1000, west = 5000, w = 3000, h = 2000 },
    [1453] = { name = "Stormwind City", c = 0, top = 1500, west = 5500, w = 1000, h = 800 },
    [1413] = { name = "The Barrens", c = 1, top = 0, west = 0, w = 4000, h = 6000 },
    [1454] = { name = "Orgrimmar", c = 1, top = 9000, west = 0, w = 1000, h = 1000 },
    [2521] = { name = "Riverglades", c = 0, top = 9000, west = 9000, w = 1000, h = 1000 },
}
local function vec(x, y) return { x = x, y = y, GetXY = function(self) return self.x, self.y end } end
CreateVector2D = vec
local playerMap, px, py = 1429, 0.5, 0.5
local mapNameSecret = false
local waypoints, tracked = {}, 0
local canSet = true
C_Map = {
    GetBestMapForUnit = function() return playerMap end,
    GetPlayerMapPosition = function(id) if MAPS[id] then return vec(px, py) end end,
    GetMapInfo = function(id)
        local m = MAPS[id]
        if not m then return nil end
        return { name = mapNameSecret and SECRET or m.name }
    end,
    GetWorldPosFromMapPos = function(id, v)
        local m = MAPS[id]
        if not m then return nil end
        return m.c, vec(m.top - v.y * m.h, m.west - v.x * m.w)
    end,
    CanSetUserWaypointOnMap = function() return canSet end,
    SetUserWaypoint = function(p) waypoints[#waypoints + 1] = p end,
}
UiMapPoint = { CreateFromCoordinates = function(m, x, y) return { uiMapID = m, x = x, y = y } end }
C_SuperTrack = { SetSuperTrackedUserWaypoint = function(on) if on then tracked = tracked + 1 end end }
local atlases = { ["Waypoint-MapPin-Tracked"] = true, Dungeon = true }
C_Texture = { GetAtlasInfo = function(a) return atlases[a] and {} or nil end }

-- Other helpers' data.
LandmarksDB = { R = { places = {
    { kind = "repair", name = "Smith", where = "Goldshire", mapID = 1429, x = 0.55, y = 0.5 },
    { kind = "mail", name = "Mailbox", where = "Trade District", mapID = 1453, x = 0.6, y = 0.7 },
    { kind = "bank", name = "Banker", mapID = SECRET, x = 0.1, y = 0.1 },
    { kind = "vendor", name = "Far", mapID = 1429, x = SECRET, y = 0.1 },
} } }
local deaths = {}
for i = 1, 40 do deaths[#deaths + 1] = { mapID = 1413, x = 0.5, y = i / 100, level = 20, killer = "Raptor" } end
deaths[#deaths + 1] = { mapID = 1429, x = 0.5, y = 0.5, level = 7, killer = "Hogger", when = 1 }  -- newest
DeathNotesDB = { R = { deaths = deaths } }
RareWatchDB = { R = { rares = {
    [61] = { name = "Mother Fang", level = 10, mapID = 1429, x = 0.3, y = 0.3 },
    ["name:Ghost"] = { name = "Ghost" },
} } }
GoldGuideData = {
    farms = {
        { minLevel = 10, maxLevel = 14, name = "Kobolds for Linen", zone = "Elwynn Forest", mapID = 37, x = 0.4, y = 0.8, why = "Close by." },
        { minLevel = 30, maxLevel = 35, name = "Silk farm", zone = "The Barrens", mapID = 10, x = 0.4, y = 0.4 },
    },
    zones = { ["Elwynn Forest"] = { 37, 1429 }, ["The Barrens"] = { 10, 1413 } },
}
DungeonsData = {
    { name = "The Stockade", minLevel = 22, maxLevel = 30, entrance = { mapID = 84, zone = "Stormwind City", x = 0.42, y = 0.58 } },
    { name = "Ragefire Chasm", horde = true, entrance = { mapID = 85, zone = "Orgrimmar", x = 0.5, y = 0.5 } },
    { name = "Forever Den", minLevel = 40, maxLevel = 45, entrance = { zone = "Riverglades", x = 0.5, y = 0.5 } },
}
local stops = { { mapID = 1429, x = 0.45, y = 0.55, label = "Hogger", kind = "kill" } }
LevelGuide_UpcomingStops = function() return stops end

---------------------------------------------------------------------------- load
local ok, err = pcall(function() assert(loadfile(base .. "/MapPins/MapPins.lua"))("MapPins", {}) end)
check(ok, "loads: " .. tostring(err))
local events, driver
for _, f in ipairs(frames) do
    if f.registered.PLAYER_LOGIN then events = f end
    if f.scripts.OnUpdate then driver = f end
end
local function fire(ev, ...) events.scripts.OnEvent(events, ev, ...) end
local function tick(seconds)
    local steps = math.floor(seconds / 0.1 + 0.5)
    for _ = 1, steps do clock = clock + 0.1; driver.scripts.OnUpdate(driver, 0.1) end
end
local function page(arg)
    out = {}
    local ok2, e = pcall(SlashCmdList.MAPPINS, arg)
    if not ok2 then out[#out + 1] = "<<ERROR " .. tostring(e) .. ">>" end
end
local function has(text) for _, t in ipairs(out) do if t:find(text, 1, true) then return true end end return false end
local function need(text, why) check(has(text), why .. ": wanted '" .. text .. "' in\n  " .. table.concat(out, "\n  ")) end
local function show(mapID)
    canvasMap = mapID
    providers[1]:OnMapChanged()
    local by = {}
    for _, pin in ipairs(pins) do by[pin.record.layer] = (by[pin.record.layer] or 0) + 1 end
    return by
end

check(SLASH_MAPPINS1 == "/mappins" and SlashCmdList.MAPPINS, "slash command")
for _, e in ipairs({ "PLAYER_LOGIN", "PLAYER_ENTERING_WORLD", "ZONE_CHANGED", "ZONE_CHANGED_NEW_AREA", "PLAYER_REGEN_ENABLED" }) do
    check(events.registered[e], "registers " .. e)
end
page("")
check(#out == 0, "quiet before login")
check(#providers == 0, "no provider before login")

fire("PLAYER_LOGIN")
check(#providers == 1, "provider added once with AddDataProvider")
check(type(MapPinsDB) == "table" and MapPinsDB.minimap == true, "saved settings made")
check(MapPinsPinMixin.SetPosition == MapCanvasPinMixin.SetPosition, "pin mixin takes MapCanvasPinMixin's methods")
fire("ADDON_LOADED", "Blizzard_WorldMap")
check(#providers == 1, "provider not added twice")

---------------------------------------------------------------------------- layers on the world map
local by = show(1429)
check(by.guide == 1, "guide stop on Elwynn")
check(by.places == 1, "one place on Elwynn (secret ones skipped)")
check(by.deaths == 1, "one death on Elwynn")
check(by.rares == 1, "rare with a spot on Elwynn; one without a spot skipped")
check(by.farms == 1, "level-10 farm matched to Elwynn by name, not by Mainline ID 37")
check(by.dungeons == nil, "no dungeon on Elwynn")
for _, pin in ipairs(pins) do
    if pin.record.layer == "guide" then
        check(near(pin.nx, 0.45) and near(pin.ny, 0.55), "guide pin position")
        check(pin.Icon.atlas == "Waypoint-MapPin-Tracked", "atlas used when the client has it")
    elseif pin.record.layer == "places" then
        check(pin.Icon.file == "Interface\\Minimap\\Tracking\\Repair", "repair icon")
    elseif pin.record.layer == "rares" then
        check(pin.Icon.file == "Interface\\TargetingFrame\\UI-RaidTargetingIcon_1", "plain texture when the atlas is missing")
    end
    check(pin.levelType == "PIN_FRAME_LEVEL_AREA_POI", "pin frame level type")
end

by = show(1453)
check(by.places == 1 and by.dungeons == 1, "Stormwind: mailbox and Stockade (Mainline 84 resolved by name)")
by = show(1454)
check(by.dungeons == nil, "Horde dungeon left out")
by = show(1413)
check(by.deaths == 29, "only the newest 30 deaths (29 here, 1 in Elwynn): got " .. tostring(by.deaths))
check(by.farms == nil, "level-30 farm not shown at level 10")
by = show(2521)
check(by.dungeons == 1, "Forever-only zone matched by name on the world map")
by = show(9999)
check(next(by) == nil, "unknown map: no pins")

---------------------------------------------------------------------------- toggles
page("off deaths")
check(MapPinsDB.layers.deaths == false, "off deaths saved")
need("Deaths off.", "off deaths reply")
by = show(1429)
check(by.deaths == nil and by.places == 1, "deaths hidden, others stay")
page("on death")
by = show(1429)
check(by.deaths == 1, "on deaths again (singular word works)")
page("off nonsense")
need("I don't know a layer called 'nonsense'", "unknown layer")
page("minimap off")
check(MapPinsDB.minimap == false, "minimap off saved")
page("minimap on")
check(MapPinsDB.minimap == true, "minimap on saved")
page("")
need("Guide stops:|r on, 1 pin |", "page counts guide")
need("Deaths:|r on, 30 pins |cff999999(1 in this zone)", "page counts deaths and this zone")
need("Minimap:|r on", "page shows minimap")
level = 32
fire("PLAYER_LEVEL_UP")
tick(1.1)
by = show(1413)
check(by.farms == 1, "farm follows your level")
level = 10
fire("PLAYER_LEVEL_UP")
tick(1.1)

---------------------------------------------------------------------------- missing and broken sources
local saved = { LevelGuide_UpcomingStops, DungeonsData, GoldGuideData, RareWatchDB }
LevelGuide_UpcomingStops, DungeonsData, GoldGuideData, RareWatchDB = nil, nil, nil, nil
tick(1.1)
by = show(1429)
check(by.guide == nil and by.farms == nil and by.rares == nil and by.places == 1, "missing helpers: their layers empty, others fine")
page("")
need("Guide stops:|r on |cff999999(LevelGuide has nothing to show yet)", "page explains a missing source")
LevelGuide_UpcomingStops = function() error("boom") end
GoldGuideData = { farms = { "junk", { minLevel = "x" } } }
DungeonsData = { 5, { entrance = "no" } }
RareWatchDB = { R = { rares = "nope" } }
tick(1.1)
by = show(1429)
check(by.places == 1, "broken sources don't break the others")
page("")
check(not has("<<ERROR"), "page survives broken sources")
LevelGuide_UpcomingStops, DungeonsData, GoldGuideData, RareWatchDB = saved[1], saved[2], saved[3], saved[4]
tick(1.1)

-- Secret values from the game.
mapNameSecret = true
playerMap = SECRET
local okSecret, eSecret = pcall(function() tick(1.1); show(1429); page("") end)
check(okSecret and not has("<<ERROR"), "secret map names and player map don't error: " .. tostring(eSecret))
mapNameSecret = false
playerMap = 1429
stops[2] = { mapID = SECRET, x = SECRET, y = 0.5, label = SECRET }
tick(1.1)
by = show(1429)
check(by.guide == 1, "a secret guide stop is skipped")
stops[2] = nil

---------------------------------------------------------------------------- minimap maths
local O = MapPins_MinimapOffset
local x, y, inside = O(100, 0, 200, 70, 70, nil)
check(near(x, 35) and near(y, 0) and inside, "east 100 of 200 yards -> 35 px right")
x, y, inside = O(0, 100, 200, 70, 70, nil)
check(near(x, 0) and near(y, 35) and inside, "north -> up")
x, y = O(-50, -50, 200, 70, 70, nil)
check(near(x, -17.5) and near(y, -17.5), "south-west -> down-left")
x, y, inside = O(-100, 0, 200, 70, 70, math.pi / 2)
check(near(x, 0) and near(y, 35) and inside, "facing west, a point west is straight up")
x, y = O(0, 100, 200, 70, 70, math.pi / 2)
check(near(x, 35) and near(y, 0), "facing west, north is to the right")
x, y = O(0, 100, 200, 70, 70, math.pi)
check(near(x, 0) and near(y, -35), "facing south, north is behind")
x, y = O(100, 0, 200, 70, 70, math.pi / 4)
check(near(x, 70.71 / 200 * 70) and near(y, -70.71 / 200 * 70), "facing north-west, east is down-right")
_, _, inside = O(250, 0, 200, 70, 70, nil)
check(not inside, "beyond the radius is outside")
_, _, inside = O(150, 150, 200, 70, 70, nil, false)
check(not inside, "round minimap: corner point outside")
_, _, inside = O(150, 150, 200, 70, 70, nil, true)
check(inside, "square minimap: corner point inside")
_, _, inside = O(195, 0, 200, 70, 70, nil, false, 0.1)
check(not inside, "edge margin keeps a pin off the rim")
check(near(MapPins_MinimapRadius(), 233.33), "outdoor zoom 0 radius from the table")
mmZoom = 3
check(near(MapPins_MinimapRadius(), 133.33), "outdoor zoom 3 radius")
indoors = true
check(near(MapPins_MinimapRadius(), 60), "indoor zoom 3 radius")
mmZoom, indoors = 0, false
C_Minimap = { GetViewRadius = function() return 300 end }
check(MapPins_MinimapRadius() == 300, "client view radius preferred")
C_Minimap = { GetViewRadius = function() return SECRET end }
check(near(MapPins_MinimapRadius(), 233.33), "secret view radius falls back to the table")
C_Minimap = nil

-- Minimap pins in place. You stand at Elwynn 0.5,0.5; Elwynn is 3000 x 2000 yards.
local function minis()
    local list = {}
    for _, f in ipairs(frames) do
        if f.parent == Minimap and f.shown and f.record then list[f.record.layer .. ":" .. f.record.title] = f end
    end
    return list
end
fire("ZONE_CHANGED")
tick(1.1)
local m = minis()
local smith = m["places:Smith"]           -- 0.05 east of you = 150 yards east
local death = m["deaths:You died here (level 7)"]
check(smith and near(smith.point[4], 150 / 233.333 * 70, 0.1) and near(smith.point[5], 0), "repairer 150 yd east -> 45 px right")
check(death and near(death.point[4], 0) and near(death.point[5], 0), "your death spot at the centre")
check(m["rares:Rare: Mother Fang"] == nil, "a rare 600+ yards away is hidden")
check(m["guide:Guide stop 1: Hogger"] and near(m["guide:Guide stop 1: Hogger"].point[4], -150 / 233.333 * 70, 0.1)
    and near(m["guide:Guide stop 1: Hogger"].point[5], -100 / 233.333 * 70, 0.1), "guide stop south-west")
check(smith and smith.parent == Minimap, "minimap pins are our frames on Minimap")
indoors = true
fire("MINIMAP_UPDATE_ZOOM")
tick(0.2)
check(minis()["places:Smith"] == nil, "indoors (150 yd radius) the repairer is at the rim, so hidden")
indoors = false
cvars.rotateMinimap = "1"
facing = math.pi / 2
tick(0.2)
smith = minis()["places:Smith"]
check(smith and near(smith.point[4], 0, 0.1) and near(smith.point[5], -45, 0.1), "rotated, facing west: east is behind you")
cvars.rotateMinimap = "0"
tick(0.2)
page("minimap off")
tick(0.2)
check(next(minis()) == nil, "minimap off hides every minimap pin")
page("minimap on")
tick(0.2)
check(minis()["places:Smith"] ~= nil, "minimap on shows them again")
playerMap = 9999
tick(0.2)
check(next(minis()) == nil, "no position (instance): no minimap pins")
playerMap = 1429
tick(0.2)

---------------------------------------------------------------------------- clicks and tooltip
show(1429)
local worldPin
for _, pin in ipairs(pins) do if pin.record.layer == "places" then worldPin = pin end end
worldPin:OnMouseEnter()
check(tooltipTemplate and MapPinsTooltip and MapPinsTooltip.shown and MapPinsTooltip.lines[1] == "Smith", "hover shows our own tooltip")
worldPin:OnMouseLeave()
check(not MapPinsTooltip.shown, "leaving hides it")
worldPin:OnMouseUp("LeftButton", true)
worldPin:OnMouseClickAction("LeftButton")
check(#waypoints == 1 and waypoints[1].uiMapID == 1429 and near(waypoints[1].x, 0.55) and tracked == 1, "world pin click sets and tracks the waypoint once")
clock = clock + 1
worldPin:OnMouseUp("RightButton", true)
worldPin:OnMouseUp("LeftButton", false)
check(#waypoints == 1, "right click or a drag off the pin does nothing")
smith = minis()["places:Smith"]
smith.scripts.OnClick(smith, "LeftButton")
check(#waypoints == 2 and waypoints[2].uiMapID == 1429, "minimap pin click sets the waypoint")
canSet = false
clock = clock + 1
worldPin:OnMouseUp("LeftButton", true)
check(#waypoints == 2, "no waypoint on a map that refuses one")
canSet = true
show(1453)
for _, pin in ipairs(pins) do if pin.record.layer == "dungeons" then worldPin = pin end end
clock = clock + 1
worldPin:OnMouseUp("LeftButton", true)
check(waypoints[3] and waypoints[3].uiMapID == 1453, "dungeon pin waypoint on the resolved Classic-era map")

-- Gamepad UI: our canvas pins give the gamepad cursor no centre; a pin with no data stays quiet.
InputUtil = { IsGamepadUIEnabled = function() return true end }
show(1429)
check(pins[1] and pins[1].GetCenter and pins[1].GetCenter(pins[1]) == nil, "gamepad UI: no pin centre for the cursor")
InputUtil = nil
show(1429)
check(pins[1].GetCenter == nil, "mouse UI: the frame's own GetCenter is back")
local bare = newFrame("Frame", nil, WorldMapFrame)
for k, v in pairs(MapPinsPinMixin) do bare[k] = v end
bare.Icon = texture()
local okBare = pcall(function()
    bare:OnAcquired(nil, 1429)
    bare:OnMouseEnter()
    bare:OnMouseUp("LeftButton", true)
    bare:OnMouseClickAction("LeftButton")
end)
check(okBare and not bare.shown and #waypoints == 3, "a pin without data hides and ignores hover and clicks")

---------------------------------------------------------------------------- combat and data changes
show(1429)
local before = acquires
combat = true
local okCombat, eCombat = pcall(show, 1453)
check(okCombat, "map change in combat doesn't touch the canvas pool: " .. tostring(eCombat))
check(acquires == before, "no pins acquired in combat")
local anyShown = false
for _, pin in ipairs(pins) do if pin.shown then anyShown = true end end
check(not anyShown, "our old pins hide in combat")
deaths[#deaths + 1] = { mapID = 1453, x = 0.2, y = 0.2, level = 11, killer = "Guard" }
tick(1.1)
check(acquires == before, "no rebuild in combat")
combat = false
fire("PLAYER_REGEN_ENABLED")
by = {}
for _, pin in ipairs(pins) do by[pin.record.layer] = (by[pin.record.layer] or 0) + 1 end
check(by.places == 1 and by.dungeons == 1, "pins come back after combat")
tick(1.1)
by = {}
for _, pin in ipairs(pins) do by[pin.record.layer] = (by[pin.record.layer] or 0) + 1 end
check(by.deaths == 1, "a new death shows within a second, without reopening the map")

-- Switched off in the hub: no pins anywhere.
hubOff.MapPins = true
by = show(1429)
tick(0.2)
check(next(by) == nil and next(minis()) == nil, "hub Off: no pins")
hubOff.MapPins = nil
hubOff.DeathNotes = true
tick(1.1)
by = show(1429)
check(by.deaths == nil and by.places == 1, "a helper switched off in the hub hides its layer")
hubOff.DeathNotes = nil

check(chat == 0, "nothing printed to chat")

if #failures > 0 then
    error(#failures .. " failure(s):\n- " .. table.concat(failures, "\n- "), 0)
end
io.write("MapPins test passed\n")
