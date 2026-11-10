-- Round 3 #13: MapPins declutters overlapping pins (kept pin's tooltip names the rest), draws hand-ins above
-- pick-ups above the rest, fades far minimap pins, and offers optional objective-camp pins from LevelGuide's
-- QuestDB (read through LevelGuideQuestFacts) for unfinished objectives only.
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

---------------------------------------------------------------------------- load
local ok, err = pcall(function() assert(loadfile(base .. "/MapPins/MapPins.lua"))("MapPins", {}) end)
check(ok, "loads: " .. tostring(err))
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

---------------------------------------------------------------------------- declutter
check(pinTitled("Smith A") and not pinTitled("Smith B"), "a pin right on top of another of its kind is left out")
check(pinTitled("Inn") and pinTitled("Near Me"), "pins with room stay")
local smith = pinTitled("Smith A")
smith.scripts.OnEnter(smith)
local tip = table.concat(MapPinsTooltip.lines, "\n")
check(tip:find("Smith B", 1, true), "the left-out pin is named in the kept pin's tooltip: " .. tip)
smith.scripts.OnLeave(smith)
local handIn, pickUp = pinTitled("Hand in: Hand Me In"), pinTitled("Quest: Pick Me Up")
check(handIn and not pickUp, "a hand-in wins over a pick-up on the same spot")
local inn = pinTitled("Inn")
check(handIn and inn and handIn.level and inn.level and handIn.level > inn.level, "hand-ins draw above places: "
    .. tostring(handIn and handIn.level) .. " vs " .. tostring(inn and inn.level))

---------------------------------------------------------------------------- objective camps
check(count("camps") == 0, "objective camps are off until switched on")
page("on camps")
check(MapPinsDB.layers.camps == true, "on camps saved")
tick(1.1)
show(1429)
local campTitles = {}
for _, pin in ipairs(shownPins()) do
    if pin.record.layer == "camps" then campTitles[#campTitles + 1] = pin.record.title .. "@" .. pin.record.x end
end
local s = table.concat(campTitles, ", ")
check(s:find("Wolves and Bears@0.8", 1, true), "unfinished objective's camp shown: " .. s)
check(not s:find("Wolves and Bears@0.2", 1, true), "finished objective's camp not shown: " .. s)
check(not s:find("All Done", 1, true), "a complete quest has no camps: " .. s)
local kobolds = 0
for _, t in ipairs(campTitles) do if t:find("Kobolds", 1, true) then kobolds = kobolds + 1 end end
check(kobolds > 0 and kobolds <= 6, "camps per quest capped: " .. kobolds)
-- The bear objective finishes: its camp goes on the next quest log update.
rows[100][2].finished = true
fire("QUEST_LOG_UPDATE")
tick(1.1)
show(1429)
s = ""
for _, pin in ipairs(shownPins()) do if pin.record.layer == "camps" then s = s .. pin.record.title .. ";" end end
check(not s:find("Wolves and Bears", 1, true), "finished objective's camp removed: " .. s)
page("off camps")
tick(1.1)
show(1429)
check(count("camps") == 0, "off camps hides them")

---------------------------------------------------------------------------- minimap fade
local A = MapPins_FadeAlpha
check(type(A) == "function", "fade function")
if A then
    check(A(100, 230) == 1, "near pins fully visible")
    check(A(229, 230) < 0.5, "pins at the minimap edge fade: " .. A(229, 230))
    local mid = A(185, 230)
    check(mid < 1 and mid > A(229, 230), "fade is gradual: " .. mid)
    check(A(3, 230) == 0.5, "a pin sitting on you is half visible")
end
fire("ZONE_CHANGED")
tick(1.1)
local near
for _, f in ipairs(frames) do
    if f.parent == Minimap and f.shown and f.record and f.record.title == "Near Me" then near = f end
end
check(near and near.alpha == 1, "minimap pin alpha set: " .. tostring(near and near.alpha))

---------------------------------------------------------------------------- RareWatch's verified rares
RareWatch_KnownRares = function() return { { npcID = 777, name = "Known One", level = 8, mapID = 1429, x = 0.9, y = 0.1 } } end
RareWatchDB = { R = { rares = {} } }
fire("ZONE_CHANGED")
tick(1.1)
show(1429)
check(pinTitled("Rare: Known One"), "a verified rare not yet seen gets a pin at its known spawn")
RareWatchDB.R.rares[777] = { name = "Known One", mapID = 1429, x = 0.2, y = 0.9, seen = 5 }
fire("ZONE_CHANGED")
tick(1.1)
show(1429)
local knownPins = 0
for _, pin in ipairs(shownPins()) do if pin.record.title == "Rare: Known One" then knownPins = knownPins + 1 end end
check(knownPins == 1, "once seen, only your own sighting is pinned: " .. knownPins)

check(chat == 0, "nothing printed to chat")
if #failures > 0 then
    error(#failures .. " failure(s):\n- " .. table.concat(failures, "\n- "), 0)
end
io.write("test_r3_mappins: ok\n")