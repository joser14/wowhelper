-- Round 5 #11 (research\re_round5.md): MapPins' exploration progress per zone and the nearest unexplored spot.
-- Sampled from C_MapExplorationInfo.GetExploredAreaIDsAtPosition (explored) and the continent map (land), shown on
-- the world map's info line and as one pin of the "explore" layer: our own frames, never the map canvas.
-- Run from the tests folder:  node run.js "<repo root>" test_r5e_mappins_explore.lua
local base = ADDON_PATH
local failures = {}
local function check(cond, why) if not cond then failures[#failures + 1] = why end end

local SECRET = setmetatable({}, { __tostring = function() return "SECRET" end })
issecretvalue = function(v) return v == SECRET end
local out, hubOff = {}, {}
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
UnitLevel = function() return 8 end
GetCVar = function() return "0" end
GetPlayerFacing = function() return 0 end
IsIndoors = function() return false end
SlashCmdList = {}
Enum = { UIMapType = { Continent = 2, Zone = 3 } }
-- The canvas pin pool must never be used.
CreateFromMixins = function() failures[#failures + 1] = "CreateFromMixins called"; return {} end
MapCanvasDataProviderMixin = setmetatable({}, { __index = function(_, k) failures[#failures + 1] = "MapCanvasDataProviderMixin." .. tostring(k) end })
MapCanvasPinMixin = setmetatable({}, { __index = function(_, k) failures[#failures + 1] = "MapCanvasPinMixin." .. tostring(k) end })

local uiScale = 1
local function texture()
    local t = {}
    function t:SetAllPoints() end
    function t:SetTexture(f) self.file = f end
    function t:SetAtlas(a) self.atlas = a end
    function t:SetTexCoord() end
    function t:SetRotation() end
    return t
end
local frames, tooltip = {}, nil
CreateFrame = function(kind, name, parent, template)
    check(not combat, "a frame was made in combat")
    local f = { kind = kind, parent = parent, shown = true, scripts = {}, registered = {}, lines = {} }
    function f:RegisterEvent(e) self.registered[e] = true end
    function f:SetScript(s, fn) self.scripts[s] = fn end
    function f:SetSize(w, h) self.w, self.h = w, h end
    function f:SetPoint(...) self.point = { ... } end
    function f:SetAllPoints() end
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
    function f:CreateFontString()
        local fs = { text = "", shown = true }
        function fs:SetText(t) self.text = t end
        function fs:SetPoint() end
        function fs:ClearAllPoints() end
        function fs:SetJustifyH() end
        function fs:Show() self.shown = true end
        function fs:Hide() self.shown = false end
        self.fonts = self.fonts or {}
        self.fonts[#self.fonts + 1] = fs
        return fs
    end
    function f:SetOwner(o) self.owner = o; self.lines = {} end
    function f:AddLine(t) self.lines[#self.lines + 1] = t end
    frames[#frames + 1] = f
    if template == "GameTooltipTemplate" then tooltip = f end
    return f
end
local function strict(name, extra)
    local f = extra or {}
    for _, method in ipairs({ "Hide", "Show", "SetScript", "HookScript", "SetParent", "SetPoint", "ClearAllPoints", "SetAlpha" }) do
        f[method] = function() failures[#failures + 1] = name .. ":" .. method .. " was called" end
    end
    return f
end
UIParent = strict("UIParent", { GetEffectiveScale = function() return uiScale end })
Minimap = strict("Minimap", { GetZoom = function() return 0 end, GetWidth = function() return 140 end,
    GetHeight = function() return 140 end, GetFrameLevel = function() return 2 end })

-- The world map: reads only. Canvas 800 x 500 at left 100, top 700.
local READS = { IsShown = true, GetMapID = true, GetFrameStrata = true, GetFrameLevel = true, GetLeft = true,
    GetTop = true, GetWidth = true, GetHeight = true, GetEffectiveScale = true, GetCanvas = true }
local function readOnly(name, fields, methods)
    return setmetatable(fields, { __index = function(_, key)
        if READS[key] and methods[key] then return methods[key] end
        failures[#failures + 1] = name .. "." .. tostring(key) .. " was used (only reads allowed)"
        return function() end
    end, __newindex = function(_, key) failures[#failures + 1] = name .. "." .. tostring(key) .. " was written" end })
end
local rect = {
    GetLeft = function() return 100 end, GetTop = function() return 700 end, GetWidth = function() return 800 end,
    GetHeight = function() return 500 end, GetEffectiveScale = function() return uiScale end,
}
local Child = readOnly("Child", {}, rect)
local Scroll = readOnly("ScrollContainer", { Child = Child }, rect)
local canvasMap, mapShown = 1438, false
WorldMapFrame = readOnly("WorldMapFrame", { ScrollContainer = Scroll }, {
    IsShown = function() return mapShown end, GetMapID = function() return canvasMap end,
    GetFrameStrata = function() return "HIGH" end, GetFrameLevel = function() return 5 end,
    GetCanvas = function() return Child end,
})
GetCursorPosition = function() return 0, 0 end

-- Teldrassil (1438) sits at x 0.4-0.6, y 0.1-0.3 of Kalimdor (1414). Its land is x and y 0.1-0.9 of the zone
-- map; the rest is sea. Explored: area 100 (x < 0.5, y < 0.5), area 101 (x < 0.5, y >= 0.5), area 102
-- (0.5 <= x < 0.7, y < 0.5). Unexplored: x >= 0.7 north, x >= 0.5 south.
local function vec(x, y) return { x = x, y = y, GetXY = function(self) return self.x, self.y end } end
CreateVector2D = vec
local playerMap, px, py = 1438, 0.3, 0.5
local waypoints = {}
local southExplored = false
local secretAreas = false
local exploreCalls, exploreCallsInCombat = 0, 0
local function landAt(x, y) return x >= 0.1 and x <= 0.9 and y >= 0.1 and y <= 0.9 end
C_Map = {
    GetMapInfo = function(id)
        if id == 1438 then return { mapID = 1438, name = "Teldrassil", mapType = 3, parentMapID = 1414 } end
        if id == 1414 then return { mapID = 1414, name = "Kalimdor", mapType = 2, parentMapID = 947 } end
    end,
    GetMapRectOnMap = function(id, top) if id == 1438 and top == 1414 then return 0.4, 0.6, 0.1, 0.3 end end,
    GetMapInfoAtPosition = function(id, x, y)
        if id ~= 1414 then return nil end
        local zx, zy = (x - 0.4) / 0.2, (y - 0.1) / 0.2
        if zx >= 0 and zx <= 1 and zy >= 0 and zy <= 1 and landAt(zx, zy) then return { mapID = 1438, name = "Teldrassil" } end
        return { mapID = 1414, name = "Kalimdor" }
    end,
    GetBestMapForUnit = function() return playerMap end,
    GetPlayerMapPosition = function(id) if id == 1438 then return vec(px, py) end end,
    GetWorldPosFromMapPos = function(id, v) if id == 1438 then return 1, vec(10000 - v.y * 4000, 2000 - v.x * 4000) end end,
    CanSetUserWaypointOnMap = function() return true end,
    SetUserWaypoint = function(p) waypoints[#waypoints + 1] = p end,
}
UiMapPoint = { CreateFromCoordinates = function(m, x, y) return { uiMapID = m, x = x, y = y } end }
C_MapExplorationInfo = {
    GetExploredAreaIDsAtPosition = function(id, v)
        exploreCalls = exploreCalls + 1
        if combat then exploreCallsInCombat = exploreCallsInCombat + 1 end
        check(type(v) == "table" and type(v.x) == "number", "a position vector is passed")
        if id ~= 1438 then return nil end
        local x, y = v.x, v.y
        local area
        if x < 0.5 then area = y < 0.5 and 100 or 101
        elseif x < 0.7 and y < 0.5 then area = 102
        elseif y >= 0.5 and southExplored then area = 103 end
        if not area then return nil end
        return { secretAreas and SECRET or area }
    end,
}

---------------------------------------------------------------------------- load
assert(loadfile(base .. "/MapPins/MapPins.lua"))("MapPins", {})
local events, driver, overlay
for _, f in ipairs(frames) do
    if f.registered.PLAYER_LOGIN then events = f end
    if f.scripts.OnUpdate then driver = f end
    if f.kind == "Frame" and f.parent == UIParent and f.fonts then overlay = f end
end
check(events and events.registered.MAP_EXPLORATION_UPDATED, "listens for MAP_EXPLORATION_UPDATED")
local function fire(ev, ...) events.scripts.OnEvent(events, ev, ...) end
local function tick(seconds)
    for _ = 1, math.floor(seconds / 0.1 + 0.5) do clock = clock + 0.1; driver.scripts.OnUpdate(driver, 0.1) end
end
local function page(arg) out = {}; SlashCmdList.MAPPINS(arg); return table.concat(out, "\n") end
local function explorePins()
    local list = {}
    for _, f in ipairs(frames) do
        if f.kind == "Button" and f.parent == overlay and overlay.shown and f.shown and f.record and f.record.layer == "explore" then
            list[#list + 1] = f
        end
    end
    return list
end

-- Expected numbers from the same 32 x 32 cell centres.
local land, open = 0, 0
for row = 0, 31 do
    for col = 0, 31 do
        local x, y = (col + 0.5) / 32, (row + 0.5) / 32
        if landAt(x, y) then
            land = land + 1
            if (x >= 0.7 and y < 0.5) or (x >= 0.5 and y >= 0.5) then open = open + 1 end
        end
    end
end
local share = math.floor((land - open) / land * 100 + 0.5)

fire("PLAYER_LOGIN")
fire("PLAYER_ENTERING_WORLD")
tick(0.5)
local partial = MapPins_Exploration(1438)
check(partial and not partial.done, "sampled over several ticks, not all at once")
tick(2)
local state = MapPins_Exploration(1438)
check(state and state.done, "Teldrassil sampled")
check(state and state.land == land, "land cells: " .. tostring(state and state.land) .. " want " .. land)
check(state and state.open == open, "unexplored cells: " .. tostring(state and state.open) .. " want " .. open)
check(state and state.areas == 3, "three areas named: " .. tostring(state and state.areas))
check(state and state.label == string.format("Explored about %d%% (3 areas)", share), "label: " .. tostring(state and state.label))
-- Nearest unexplored from (0.3, 0.5): just across x = 0.5 in the south half, inland.
check(state and state.x and state.x > 0.5 and state.x < 0.56 and state.y >= 0.5 and state.y < 0.56,
    "nearest spot: " .. tostring(state and state.x) .. ", " .. tostring(state and state.y))

---------------------------------------------------------------------------- world map
mapShown, canvasMap = true, 1438
tick(0.2)
local info = overlay.fonts[1]
check(info.shown and info.text:find("Explored about " .. share .. "% (3 areas)", 1, true), "info line: " .. tostring(info.text))
local pins = explorePins()
check(#pins == 1, "one unexplored-spot pin on our overlay: " .. #pins)
local pin = pins[1]
if pin then
    pin.scripts.OnEnter(pin)
    local tip = table.concat(tooltip.lines, "|")
    check(tip:find("Not explored yet", 1, true) and tip:find("of Teldrassil", 1, true), "tooltip: " .. tip)
    pin.scripts.OnClick(pin, "LeftButton")
    check(#waypoints == 1 and waypoints[1].uiMapID == 1438 and math.abs(waypoints[1].x - state.x) < 1e-9, "click sets the game's map pin")
end
-- Nothing is sampled again while the map stays open and nothing changes.
local before, text = exploreCalls, info.text
tick(2)
check(exploreCalls == before, "no sampling per frame: " .. (exploreCalls - before) .. " calls")
check(info.text == text, "info line steady")
-- A continent: no label, no error.
canvasMap = 1414
tick(0.2)
check(not info.shown or not (info.text or ""):find("Explored", 1, true), "no exploration line on a continent: " .. tostring(info.text))
canvasMap = 1438
tick(0.2)

---------------------------------------------------------------------------- combat
combat = true
fire("MAP_EXPLORATION_UPDATED")
tick(1)
check(exploreCallsInCombat == 0, "nothing sampled in combat: " .. exploreCallsInCombat)
combat = false
fire("PLAYER_REGEN_ENABLED")

---------------------------------------------------------------------------- discovering the south
southExplored = true
fire("MAP_EXPLORATION_UPDATED")
tick(2.5)
state = MapPins_Exploration(1438)
check(state.done and state.areas == 4, "resampled: 4 areas: " .. tostring(state.areas))
check(state.label:find("Explored about", 1, true) and state.open < open, "fewer unexplored cells: " .. state.open)
check(state.x and state.x >= 0.7 and state.y < 0.5, "target moved to the unexplored north-east: " .. tostring(state.x) .. "," .. tostring(state.y))

---------------------------------------------------------------------------- standing on a spot that never reveals
local tx, ty = state.x, state.y
px, py = tx, ty
tick(5)
state = MapPins_Exploration(1438)
check(state.x and not (state.x == tx and state.y == ty), "set aside after a few seconds there: target moved")
local walked = MapPinsDB.walked and MapPinsDB.walked[1438]
check(type(walked) == "table" and walked.n == 1, "one cell set aside")
-- Bounded: never more than 64 per zone.
for _ = 1, 200 do
    local s = MapPins_Exploration(1438)
    if not s or not s.x then break end
    px, py = s.x, s.y
    tick(3.1)
end
check(MapPinsDB.walked[1438].n <= 64, "walked bounded: " .. tostring(MapPinsDB.walked[1438].n))

---------------------------------------------------------------------------- layer off, secret values
local text2 = page("off explore")
check(text2:find("Unexplored spot off", 1, true), "layer switched off: " .. text2)
tick(1.2)
check(#explorePins() == 0, "no pin with the layer off")
page("on explore")
secretAreas = true
fire("MAP_EXPLORATION_UPDATED")
local ok, err = pcall(tick, 2.5)
check(ok, "secret area IDs don't error: " .. tostring(err))
state = MapPins_Exploration(1438)
check(state.areas == 0, "secret area IDs are not counted: " .. tostring(state.areas))

check(chat == 0, "nothing printed to chat")
if #failures > 0 then
    error(#failures .. " failure(s):\n- " .. table.concat(failures, "\n- "), 0)
end
print = nil
io.write("test_r5e_mappins_explore: ALL TESTS PASSED\n")
