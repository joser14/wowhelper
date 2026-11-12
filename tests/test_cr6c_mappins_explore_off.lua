-- Review 6c: MapPins' exploration sampling must not run when the "explore" layer is switched off (or MapPins is
-- Off on the hub): no GetExploredAreaIDsAtPosition calls on zone entry, MAP_EXPLORATION_UPDATED or the tick, and no
-- "Explored about" on the world map's info line. Harness copied from test_r5e_mappins_explore.lua.
-- Run from the tests folder:  node run.js "<repo root>" test_cr6c_mappins_explore_off.lua
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

fire("PLAYER_LOGIN")
page("off explore")
fire("PLAYER_ENTERING_WORLD")
tick(3)
check(exploreCalls == 0, "layer off: nothing sampled on entering the zone: " .. exploreCalls .. " calls")
fire("MAP_EXPLORATION_UPDATED")
tick(3)
check(exploreCalls == 0, "layer off: nothing sampled on MAP_EXPLORATION_UPDATED: " .. exploreCalls .. " calls")
mapShown, canvasMap = true, 1438
tick(0.5)
check(exploreCalls == 0, "layer off: the open world map samples nothing: " .. exploreCalls .. " calls")
local info = overlay.fonts[1]
check(not (info.text or ""):find("Explored", 1, true), "layer off: no exploration on the info line: " .. tostring(info.text))
mapShown = false
tick(0.2)

-- Switched on: sampled as before.
page("on explore")
tick(3)
local state = MapPins_Exploration(1438)
check(state and state.done and exploreCalls > 0, "layer on: Teldrassil sampled")
check(state and state.x, "layer on: a target")

-- MapPins Off on the hub: the sampling stops too.
local before = exploreCalls
hubOff.MapPins = true
fire("MAP_EXPLORATION_UPDATED")
tick(3)
check(exploreCalls == before, "MapPins Off on the hub: nothing sampled: " .. (exploreCalls - before) .. " calls")
hubOff.MapPins = nil

check(chat == 0, "nothing printed to chat")
if #failures > 0 then
    error(#failures .. " failure(s):\n- " .. table.concat(failures, "\n- "), 0)
end
print = nil
io.write("test_cr6c_mappins_explore_off: ALL TESTS PASSED\n")