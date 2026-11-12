-- Round 6 #4: Nodes remembers where you gathered (herb, ore, fishing) and MapPins draws the spots on its own
-- overlay and minimap buttons, one switchable layer per kind. Checks: detection from your own gathering casts
-- (spell ID or name), the SENT target as the name (secret in combat: left out), fishing only with a fishing loot
-- window, secret/nil positions skipped, merging, bounds, the layers on the world map and minimap, the switches
-- (Nodes page and Map pins page share one), hub Off, no chat, no hooks, no canvas pins, no frames in combat,
-- no CallbackEvents, globals in Nodes' own names.
-- Run from the tests folder:  node run.js "<repo root>" test_r6_nodes.lua
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
time = function() return 1800000000 + clock end
date = function(_, t) return "D" .. tostring(t) end
local combat = false
InCombatLockdown = function() return combat end
GetRealmName = function() return "R" end
UnitLevel = function() return 11 end
GetCVar = function() return "0" end
GetPlayerFacing = function() return 0 end
IsIndoors = function() return false end
SlashCmdList = {}
Enum = { UIMapType = { Continent = 2, Zone = 3 } }
CreateFromMixins = function() failures[#failures + 1] = "CreateFromMixins called"; return {} end
MapCanvasDataProviderMixin = setmetatable({}, { __index = function(_, k) failures[#failures + 1] = "MapCanvasDataProviderMixin." .. tostring(k) end })
MapCanvasPinMixin = setmetatable({}, { __index = function(_, k) failures[#failures + 1] = "MapCanvasPinMixin." .. tostring(k) end })
CastSpellByName = function() failures[#failures + 1] = "CastSpellByName called" end
CastSpellByID = function() failures[#failures + 1] = "CastSpellByID called" end
C_Minimap = { SetTracking = function() failures[#failures + 1] = "SetTracking called" end,
    GetViewRadius = function() return 200 end }

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
local frames = {}
CreateFrame = function(kind, name, parent, template)
    check(not combat, "a frame was made in combat")
    local f = { kind = kind, parent = parent, shown = true, scripts = {}, registered = {}, lines = {} }
    function f:RegisterEvent(e) self.registered[e] = true end
    function f:RegisterUnitEvent(e, unit) self.registered[e] = unit end
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
    function f:SetText(t) self.text = t end
    function f:GetText() return self.text end
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

-- Teldrassil 1438 is 4000 x 4000 yards; other maps (2000+) for the zone bound are the same size.
local function vec(x, y) return { x = x, y = y, GetXY = function(self) return self.x, self.y end } end
CreateVector2D = vec
local playerMap, px, py = 1438, 0.3, 0.5
local secretPos = false
C_Map = {
    GetMapInfo = function(id)
        if id == 1438 then return { mapID = 1438, name = "Teldrassil", mapType = 3, parentMapID = 1414 } end
        return { mapID = id, name = "Zone" .. id, mapType = 3, parentMapID = 1414 }
    end,
    GetBestMapForUnit = function() return playerMap end,
    GetPlayerMapPosition = function(id)
        if id ~= playerMap or not px then return nil end
        if secretPos then return vec(SECRET, SECRET) end
        return vec(px, py)
    end,
    GetWorldPosFromMapPos = function(id, v) return 1, vec(10000 - v.y * 4000, 2000 - v.x * 4000) end,
    GetMapWorldSize = function() return 4000, 4000 end,
    CanSetUserWaypointOnMap = function() return true end,
    SetUserWaypoint = function() end,
}
UiMapPoint = { CreateFromCoordinates = function(m, x, y) return { uiMapID = m, x = x, y = y } end }
C_Spell = { GetSpellName = function(id)
    if id == 2366 or id == 999001 then return "Herb Gathering" end
    if id == 2575 then return "Mining" end
    if id == 7620 then return "Fishing" end
    if id == 585 then return "Smite" end
end }
local fishingLoot = true
IsFishingLoot = function() return fishingLoot end

---------------------------------------------------------------------------- load
local before = {}
for k in pairs(_G) do before[k] = true end
assert(loadfile(base .. "/MapPins/MapPins.lua"))("MapPins", {})
local afterMapPins = {}
for k in pairs(_G) do afterMapPins[k] = true end
assert(loadfile(base .. "/Nodes/Nodes.lua"))("Nodes", {})
for k in pairs(_G) do
    if not afterMapPins[k] then
        check(k:sub(1, 5) == "Nodes" or k:sub(1, 11) == "SLASH_NODES" or k:sub(1, 7) == "Forever",
            "Nodes writes global " .. tostring(k) .. " outside its names")
    end
end
check(SlashCmdList.NODES ~= nil, "the Nodes page command exists")

local mpEvents, nodeEvents, driver, overlay
for _, f in ipairs(frames) do
    if f.registered.PLAYER_LOGIN and f.registered.MAP_EXPLORATION_UPDATED then mpEvents = f end
    if f.registered.PLAYER_LOGIN and f.registered.LOOT_OPENED then nodeEvents = f end
    if f.scripts.OnUpdate then driver = f end
    if f.kind == "Frame" and f.parent == UIParent and f.fonts then overlay = f end
end
check(mpEvents and nodeEvents and driver and overlay, "frames found")
check(nodeEvents.registered.UNIT_SPELLCAST_SUCCEEDED == "player" and nodeEvents.registered.UNIT_SPELLCAST_SENT == "player",
    "cast events are registered for the player only")
for event in pairs(nodeEvents.registered) do
    check(not event:find("COMBAT_LOG", 1, true), "registers a CallbackEvent: " .. event)
end
local function mp(ev, ...) mpEvents.scripts.OnEvent(mpEvents, ev, ...) end
local function nodes(ev, ...) nodeEvents.scripts.OnEvent(nodeEvents, ev, ...) end
local function tick(seconds)
    for _ = 1, math.floor(seconds / 0.1 + 0.5) do clock = clock + 0.1; driver.scripts.OnUpdate(driver, 0.1) end
end
local function page(arg) out = {}; SlashCmdList.NODES(arg); return table.concat(out, "\n") end
local function mappage(arg) out = {}; SlashCmdList.MAPPINS(arg); return table.concat(out, "\n") end
local function gather(spell, target, unit)
    nodes("UNIT_SPELLCAST_SENT", unit or "player", target, "guid", spell)
    nodes("UNIT_SPELLCAST_SUCCEEDED", unit or "player", "guid", spell)
end
local function pins(layer, onMinimap)
    local n = 0
    for _, f in ipairs(frames) do
        local parentOk = onMinimap and f.parent == Minimap or (not onMinimap and f.parent == overlay and overlay.shown)
        if f.kind == "Button" and parentOk and f.shown and f.record and f.record.layer == layer then n = n + 1 end
    end
    return n
end

mp("PLAYER_LOGIN")
nodes("PLAYER_LOGIN")
mp("PLAYER_ENTERING_WORLD")
check(type(NodesDB) == "table" and type(NodesDB.zones) == "table", "NodesDB made at login")

---------------------------------------------------------------------------- detection
gather(2366, "Peacebloom")
local herbs = NodesDB.zones[1438] and NodesDB.zones[1438].herb
check(herbs and #herbs == 1 and herbs[1].name == "Peacebloom" and herbs[1].x == 0.3, "an herb gathered is kept with its name")
-- 4 yards away: the same spot, counted again.
px = 0.301
gather(2366, "Peacebloom")
check(#herbs == 1 and herbs[1].n == 2, "a spot a few yards away is merged: " .. #herbs)
-- 200 yards away: a new spot.
px = 0.35
gather(2366, "Silverleaf")
check(#herbs == 2 and herbs[2].name == "Silverleaf", "a far spot is new")
-- A gathering spell this client numbers differently is found by its name.
px = 0.4
gather(999001, "Earthroot")
check(#herbs == 3, "matched by the spell's name")
-- Not gathering: nothing.
px = 0.45
gather(585, "Mob")
check(#herbs == 3 and not NodesDB.zones[1438].ore, "other spells are ignored")
-- Someone else's cast (all-units fallback is not used here, the token is "player" only), and a secret unit token.
gather(2575, "Copper Vein", SECRET)
local ore = NodesDB.zones[1438].ore
check(ore and #ore == 1 and ore[1].name == "Copper Vein", "registered for the player: a secret unit token is still your cast")
-- In combat the SENT target is secret: the spot is kept without a name.
px = 0.6
combat = true
gather(2575, SECRET)
combat = false
check(#ore == 2 and ore[2].name == nil, "a secret node name is left out, the spot kept")
-- Secret or missing position: skipped.
px = 0.7
secretPos = true
gather(2575, "Tin Vein")
secretPos = false
playerMap = SECRET
gather(2575, "Tin Vein")
playerMap = 1438
local savedPx = px
px = nil
gather(2575, "Tin Vein")
px = savedPx
check(#ore == 2, "secret or nil positions are skipped: " .. #ore)
-- A name from an old SENT isn't used for a later cast.
nodes("UNIT_SPELLCAST_SENT", "player", "Old Name", "g", 2575)
clock = clock + 30
px = 0.8
nodes("UNIT_SPELLCAST_SUCCEEDED", "player", "g", 2575)
check(#ore == 3 and ore[3].name == nil, "a stale target isn't used")

-- Fishing: only with a fishing loot window soon after.
px, py = 0.2, 0.2
gather(7620, "")
check(not NodesDB.zones[1438].fish, "a fishing cast alone keeps nothing")
nodes("LOOT_OPENED", false, false)
local fish = NodesDB.zones[1438].fish
check(fish and #fish == 1 and fish[1].x == 0.2, "fishing loot keeps the spot")
px = 0.25
gather(7620, "")
fishingLoot = false
nodes("LOOT_OPENED", false, false)
check(#fish == 1, "loot that isn't fishing loot keeps nothing")
fishingLoot = true
gather(7620, "")
clock = clock + 60
nodes("LOOT_OPENED", false, false)
check(#fish == 1, "loot long after the cast keeps nothing")
nodes("LOOT_OPENED", false, false)
check(#fish == 1, "a later loot window isn't fishing")

---------------------------------------------------------------------------- bounds
playerMap, py = 1439, 0.5
for i = 1, 45 do
    px = i / 50
    gather(2366, "Herb" .. i)
end
check(#NodesDB.zones[1439].herb == 40, "at most 40 spots per kind per map: " .. #NodesDB.zones[1439].herb)
check(NodesDB.zones[1439].herb[40].name == "Herb45", "the newest is kept")
playerMap, px, py = 1438, 0.3, 0.5

---------------------------------------------------------------------------- drawing through MapPins
tick(1.5)
mapShown, canvasMap = true, 1438
tick(0.3)
check(pins("herbs") == 3, "3 herb spots on Teldrassil's world map: " .. pins("herbs"))
check(pins("ore") == 3 and pins("fishing") == 1, "ore and fishing on the world map: " .. pins("ore") .. "/" .. pins("fishing"))
local tip
for _, f in ipairs(frames) do
    if f.kind == "Button" and f.parent == overlay and f.shown and f.record and f.record.title == "Peacebloom" then tip = f end
end
check(tip and tip.record.lines[1]:find("2 times", 1, true), "the tooltip says how often you gathered there")
check(pins("herbs", true) >= 1, "herb spots near you on the minimap: " .. pins("herbs", true))
check(mappage(""):find("Herbs:|r on, ", 1, true), "the Map pins page lists the Herbs layer")

-- Switches: Nodes' page and the Map pins page share one switch (NodesDB.layers).
check(page("off herbs"):find("Herbs on your maps: off", 1, true), "Nodes page switches herbs off")
tick(0.2)
check(pins("herbs") == 0 and pins("herbs", true) == 0 and pins("ore") == 3, "herbs off: herbs gone, ore stays")
check(mappage(""):find("Herbs:|r |cff999999off", 1, true), "the Map pins page shows it off")
mappage("on herbs")
tick(0.2)
check(NodesDB.layers.herb == true and pins("herbs") == 3, "the Map pins page switches it back on, through Nodes")
page("toggle fishing")
tick(0.2)
check(NodesDB.layers.fish == false and pins("fishing") == 0, "toggle fishing")
page("toggle fishing")

-- Pages.
local text = page("")
check(text:find("Teldrassil:|r 3 herb, 3 ore and 1 fishing spot", 1, true), "this zone's summary: " .. text)
check(text:find("Peacebloom x2", 1, true), "most gathered names")
check(page("all"):find("Zone1439:|r 40 herb, 0 ore", 1, true), "all zones")

-- Hub Off: every spot leaves the maps at once, nothing is recorded; On brings them back.
hubOff.Nodes = true
ForeverHubOnSwitch.Nodes(true)
check(pins("herbs") == 0 and pins("ore") == 0 and pins("fishing") == 0, "Off: no spots on the world map")
check(pins("herbs", true) == 0 and pins("ore", true) == 0, "Off: no spots on the minimap")
px = 0.9
gather(2366, "Off Herb")
check(#NodesDB.zones[1438].herb == 3, "Off: nothing recorded")
hubOff.Nodes = nil
ForeverHubOnSwitch.Nodes(false)
check(pins("herbs") == 3, "On: the spots come back")

-- Data saved in an odd shape is cleaned at login.
NodesDB.zones.bad = { herb = {} }
NodesDB.zones[1438].herb[#NodesDB.zones[1438].herb + 1] = { x = 5, y = 0.1 }
NodesDB.zones[1438].junk = { 1, 2 }
nodes("PLAYER_LOGIN")
check(NodesDB.zones.bad == nil and #NodesDB.zones[1438].herb == 3 and NodesDB.zones[1438].junk == nil, "bad saved data dropped")

-- Zones are bounded: the map you gathered on longest ago makes room.
for id = 2000, 2045 do
    playerMap, px = id, 0.5
    clock = clock + 1
    gather(2575, "Vein")
end
local zones = 0
for _ in pairs(NodesDB.zones) do zones = zones + 1 end
check(zones <= 40, "at most 40 maps: " .. zones)
check(NodesDB.zones[2045] ~= nil, "the newest map is kept")
check(chat == 0, "nothing printed to chat")
if #failures > 0 then
    error(#failures .. " failure(s):\n- " .. table.concat(failures, "\n- "), 0)
end
print = nil
io.write("test_r6_nodes: ALL TESTS PASSED\n")
