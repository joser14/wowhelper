-- Round 4 item 18 (research\re_round4.md R19): MapPins' world-map info line (zone under the cursor with its
-- level range coloured for you, cursor and player coordinates) on our own overlay, and a minimap edge arrow:
-- when the /way point or the guide's next stop is beyond the minimap, one arrow on the rim points at it.
-- Leatrix Maps / TomTom ideas only. Mock and load copied from test_r3_mappins.lua.
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

-- The old canvas-pool route must be gone: these globals exist but must never be used.
CreateFromMixins = function() failures[#failures + 1] = "CreateFromMixins called"; return {} end
MapCanvasDataProviderMixin = setmetatable({}, { __index = function(_, k) failures[#failures + 1] = "MapCanvasDataProviderMixin." .. tostring(k) .. " read" end })
MapCanvasPinMixin = setmetatable({}, { __index = function(_, k) failures[#failures + 1] = "MapCanvasPinMixin." .. tostring(k) .. " read" end,
    __pairs = function() failures[#failures + 1] = "MapCanvasPinMixin copied"; return next, {}, nil end })

-- Generic frame for our own frames.
local uiScale = 0.8
local function texture()
    local t = {}
    function t:SetAllPoints() end
    function t:SetTexture(f) self.file, self.atlas = f, nil end
    function t:SetAtlas(a) self.atlas, self.file = a, nil end
    function t:SetTexCoord(...) self.coords = { ... } end
    function t:SetRotation(a) self.rotation = a end
    function t:SetVertexColor() end
    function t:SetSize() end
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
    function f:SetAllPoints(rel) self.allPoints = rel end
    function f:ClearAllPoints() self.point = nil end
    function f:Show() self.shown = true end
    function f:Hide() self.shown = false end
    function f:IsShown() return self.shown end
    function f:CreateTexture() return texture() end
    function f:RegisterForClicks() end
    function f:SetFrameLevel(l) self.level = l end
    function f:SetAlpha(a) self.alpha = a end
    function f:SetFrameStrata(s) self.strata = s end
    function f:GetEffectiveScale() return uiScale end
    function f:EnableMouse() end
    function f:CreateFontString() local fs = { text = "", shown = true }; function fs:SetText(t) self.text = t end; function fs:SetPoint(...) self.point = { ... } end; function fs:ClearAllPoints() end; function fs:SetJustifyH() end; function fs:Show() self.shown = true end; function fs:Hide() self.shown = false end; function fs:SetShown(v) self.shown = v and true or false end; self.fonts = self.fonts or {}; self.fonts[#self.fonts + 1] = fs; return fs end
    function f:SetOwner(o) self.owner = o; self.lines = {} end
    function f:AddLine(t) self.lines[#self.lines + 1] = t end
    frames[#frames + 1] = f
    return f
end
local tooltipTemplate
CreateFrame = function(kind, name, parent, template)
    check(not combat, "a frame was made in combat")
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
UIParent = strict("UIParent", { GetEffectiveScale = function() return uiScale end })
local mmZoom, mmWidth = 0, 140
Minimap = strict("Minimap", {
    GetZoom = function() return mmZoom end,
    GetWidth = function() return mmWidth end,
    GetHeight = function() return mmWidth end,
    GetFrameLevel = function() return 2 end,
})

-- World map frames: read-only. Any key other than the allowed reads (and the two child fields) fails.
local READS = { IsShown = true, GetMapID = true, GetFrameStrata = true, GetFrameLevel = true, GetLeft = true,
    GetTop = true, GetWidth = true, GetHeight = true, GetEffectiveScale = true, GetRect = true, GetCanvas = true }
local touched = {}
local function readOnly(name, fields, methods)
    return setmetatable(fields, { __index = function(_, key)
        if READS[key] and methods[key] then
            return function(self, ...)
                touched[#touched + 1] = name .. ":" .. key
                return methods[key](self, ...)
            end
        end
        failures[#failures + 1] = name .. "." .. tostring(key) .. " was used (only reads allowed)"
        return function() failures[#failures + 1] = name .. ":" .. tostring(key) .. " was called" end
    end, __newindex = function(_, key) failures[#failures + 1] = name .. "." .. tostring(key) .. " was written" end })
end
-- Rectangles in each frame's own units (scale = effective scale), like the game reports them.
local view = { left = 100, top = 700, w = 800, h = 500, scale = uiScale }       -- ScrollContainer
local canvas = { left = 100, top = 700, w = 800, h = 500, scale = uiScale }     -- its Child (the map picture)
local function rectMethods(r)
    return {
        GetLeft = function() return r.left end, GetTop = function() return r.top end,
        GetWidth = function() return r.w end, GetHeight = function() return r.h end,
        GetEffectiveScale = function() return r.scale end,
        GetRect = function() return r.left, r.top - r.h, r.w, r.h end,
    }
end
local Child = readOnly("ScrollContainer.Child", {}, rectMethods(canvas))
local ScrollContainer = readOnly("WorldMapFrame.ScrollContainer", { Child = Child }, rectMethods(view))
local canvasMap, mapShown, mapStrata = 1429, true, "HIGH"
WorldMapFrame = readOnly("WorldMapFrame", { ScrollContainer = ScrollContainer }, {
    IsShown = function() return mapShown end,
    GetMapID = function() return canvasMap end,
    GetFrameStrata = function() return mapStrata end,
    GetFrameLevel = function() return 5 end,
    GetCanvas = function() return Child end,
})

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
    GetMapInfoAtPosition = function(id, x, y) if id == 1429 and x > 0.8 and y < 0.2 then return { mapID = 1453, name = "Stormwind City" } end if id == 1429 then return { mapID = 1429, name = "Elwynn Forest" } end end,
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



-- Other helpers' data for round 3: clustered places, a hand-in on top of a pick-up, quest log + QuestDB camps.
LandmarksDB = { R = { places = {
    { kind = "repair", name = "Smith A", mapID = 1429, x = 0.30, y = 0.30 },
    { kind = "repair", name = "Smith B", mapID = 1429, x = 0.305, y = 0.30 },    -- on top of Smith A
    { kind = "inn", name = "Inn", mapID = 1429, x = 0.60, y = 0.60 },
    { kind = "repair", name = "Near Me", mapID = 1429, x = 0.51, y = 0.50 },     -- 30 yd east of you
} } }
local givers = {
    { kind = "accept", title = "Pick Me Up", npc = "Marshal", level = 2, zone = "Elwynn Forest", x = 0.701, y = 0.70 },
    { kind = "turnin", title = "Hand Me In", npc = "Marshal", level = 2, zone = "Elwynn Forest", x = 0.70, y = 0.70 },
}
LevelGuide_QuestGivers = function() return givers, "k" end

-- Quest log: 100 (two objectives, the first finished), 101 complete, 102 with many camps.
local log = {
    { isHeader = true, title = "Elwynn Forest" },
    { questID = 100, title = "Wolves and Bears" },
    { questID = 101, title = "All Done" },
    { questID = 102, title = "Kobolds Everywhere" },
}
local rows = {
    [100] = { { text = "Wolf: 5/5", finished = true }, { text = "Bear: 1/4", finished = false } },
    [101] = { { text = "Thing: 1/1", finished = true } },
    [102] = { { text = "Kobold: 0/10", finished = false } },
}
local complete = { [101] = true }
C_QuestLog = {
    GetNumQuestLogEntries = function() return #log end,
    GetInfo = function(i) return log[i] end,
    GetQuestObjectives = function(id) return rows[id] end,
    IsComplete = function(id) return complete[id] or false end,
}
local manyCamps = {}
for i = 1, 12 do manyCamps[i] = { map = 1429, x = 10 + i * 5, y = 90, r = 20, n = 3 } end
local QDB = {
    [100] = { id = 100, title = "Wolves and Bears", objectives = {
        { kind = "kill", spots = { { map = 1429, x = 20, y = 80, r = 30, n = 8 } } },
        { kind = "kill", spots = { { map = 1429, x = 80, y = 20, r = 30, n = 6 } } } } },
    [101] = { id = 101, title = "All Done", objectives = { { kind = "item", spots = { { map = 1429, x = 50, y = 10 } } } } },
    [102] = { id = 102, title = "Kobolds Everywhere", objectives = { { kind = "kill", spots = manyCamps } } },
}
local factsReads = 0
LevelGuideQuestFacts = setmetatable({}, {
    __index = function(_, k)
        if k == "Quest" then return function(id) factsReads = factsReads + 1; return QDB[id] end end
    end,
    __newindex = function(_, k) failures[#failures + 1] = "wrote LevelGuideQuestFacts." .. tostring(k) end,
})

-- Round 4 additions to the mock: cursor, zone under the cursor, level ranges, guide stops, /way point.
local cursorX, cursorY = 0, 0
GetCursorPosition = function() return cursorX, cursorY end
local gamepadUI = false
InputUtil = { IsGamepadUIEnabled = function() return gamepadUI end }
ForeverZoneLevels = function(id) if id == 1429 then return 1, 10, "Elwynn Forest" end if id == 1453 then return 30, 40, "Stormwind City" end end
local guideStops = { { kind = "go", label = "Far north", zone = "Elwynn Forest", x = 0.5, y = 0.1 } }
LevelGuide_UpcomingStops = function() return guideStops end
local wayPoint
ForeverWaypoint_Active = function() return wayPoint end
---------------------------------------------------------------------------- load
local ok, err = pcall(function() assert(loadfile(base .. "/MapPins/MapPins.lua"))("MapPins", {}) end)
assert(ok, "loads: " .. tostring(err))
ForeverWaypoint_Active = function() return wayPoint end   -- after load: the shared snippet defines its own
local events, driver, overlay
for _, f in ipairs(frames) do
    if f.registered.PLAYER_LOGIN then events = f end
    if f.scripts.OnUpdate then driver = f end
    if f.kind == "Frame" and f.parent == UIParent then overlay = f end
end
local function fire(ev, ...) events.scripts.OnEvent(events, ev, ...) end
local function tick(seconds)
    for _ = 1, math.floor(seconds / 0.1 + 0.5) do clock = clock + 0.1; driver.scripts.OnUpdate(driver, 0.1) end
end
local function page(arg) out = {}; SlashCmdList.MAPPINS(arg) end
local worldPool = {}
for _, f in ipairs(frames) do
    if f.kind == "Button" and overlay and f.parent == overlay then worldPool[#worldPool + 1] = f end
end
local function shownPins()
    local list = {}
    for _, pin in ipairs(worldPool) do if overlay.shown and pin.shown and pin.record then list[#list + 1] = pin end end
    return list
end
local function pinTitled(title)
    for _, pin in ipairs(shownPins()) do if pin.record.title == title then return pin end end
end
local function count(layer)
    local n = 0
    for _, pin in ipairs(shownPins()) do if pin.record.layer == layer then n = n + 1 end end
    return n
end
local function show(mapID) canvasMap, mapShown = mapID, true; tick(0.1) end

check(events.registered.QUEST_LOG_UPDATE, "listens for quest log changes (objective camps)")
fire("PLAYER_LOGIN")
tick(1.1)
show(1429)

---------------------------------------------------------------------------- info line
-- The canvas is 800 x 500 at left 100, top 700 in its own units at scale 0.8: on screen 80..720 x 560..160.
local info = overlay.fonts and overlay.fonts[1]
check(info, "an info line on our overlay")
local function infoText() tick(0.1); return info and info.shown and info.text or "" end
cursorX, cursorY = 80 + 0.25 * 640, 560 - 0.5 * 400
local t = infoText()
check(t:find("Elwynn Forest (1-10)", 1, true), "zone under the cursor with its levels: " .. t)
check(t:find("Cursor 25.0, 50.0", 1, true), "cursor coordinates: " .. t)
check(t:find("You 50.0, 50.0", 1, true), "player coordinates: " .. t)
-- Over Stormwind (30-40) at level 10: red.
cursorX, cursorY = 80 + 0.9 * 640, 560 - 0.1 * 400
t = infoText()
check(t:find("|cffff4040Stormwind City (30-40)|r", 1, true), "too high: red: " .. t)
-- Off the map: only your position.
cursorX, cursorY = 10, 10
t = infoText()
check(not t:find("Cursor", 1, true) and t:find("You 50.0, 50.0", 1, true), "cursor off the map: " .. t)
-- Gamepad mode: no cursor part.
cursorX, cursorY = 80 + 0.25 * 640, 560 - 0.5 * 400
gamepadUI = true
t = infoText()
check(not t:find("Cursor", 1, true), "no cursor in gamepad mode: " .. t)
gamepadUI = false
mapShown = false
tick(0.1)
check(not overlay.shown, "gone with the map")

---------------------------------------------------------------------------- minimap edge arrow
local edge
for _, f in ipairs(frames) do if f.parent == Minimap and f.kind == "Frame" then edge = f end end
check(edge and edge.Arrow, "edge arrow made at load on the minimap")
local function near(a, b, eps) return type(a) == "number" and math.abs(a - b) <= (eps or 0.01) end
fire("ZONE_CHANGED")
tick(1.1)
-- The guide's next stop is 800 yd north: arrow at the top of the rim, pointing up.
check(edge.shown, "shown for a far target")
local p = edge.point or {}
check(near(p[4], 0, 0.5) and p[5] and p[5] > 50 and p[5] <= 70, "at the top rim: " .. tostring(p[4]) .. "," .. tostring(p[5]))
check(near(edge.Arrow.rotation, 0), "points up: " .. tostring(edge.Arrow.rotation))
-- Rotating minimap, facing west (pi/2): north is to your right.
cvars.rotateMinimap, facing = "1", math.pi / 2
tick(0.2)
p = edge.point or {}
check(p[4] and p[4] > 50 and near(p[5], 0, 0.5), "right rim when facing west: " .. tostring(p[4]) .. "," .. tostring(p[5]))
check(near(edge.Arrow.rotation, -math.pi / 2), "points right: " .. tostring(edge.Arrow.rotation))
cvars.rotateMinimap, facing = "0", 0
-- A /way point wins over the guide: 1200 yd west.
wayPoint = { mapID = 1429, x = 0.1, y = 0.5, label = "west" }
tick(0.2)
p = edge.point or {}
check(p[4] and p[4] < -50 and near(edge.Arrow.rotation, math.pi / 2), "/way point to the west: " .. tostring(p[4]))
-- Inside the minimap: no arrow (the pin itself shows).
wayPoint = { mapID = 1429, x = 0.5, y = 0.45, label = "close" }
tick(0.2)
check(not edge.shown, "no arrow for a target on the minimap")
-- MapPins off: hidden.
wayPoint = { mapID = 1429, x = 0.1, y = 0.5, label = "west" }
tick(0.2)
check(edge.shown, "back")
hubOff.MapPins = true
tick(0.2)
check(not edge.shown, "off with MapPins")
hubOff.MapPins = nil

check(chat == 0, "nothing printed to chat")
if #failures > 0 then
    error(#failures .. " failure(s):\n- " .. table.concat(failures, "\n- "), 0)
end
io.write("ALL TESTS PASSED\n")