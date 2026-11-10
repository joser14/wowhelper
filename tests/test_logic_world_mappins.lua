-- MapPins logic review: between the 0.1 s checks the driver only re-placed the pins it already had.
-- So for up to 0.1 s after you close the world map our pins stayed on screen where the map was
-- (the overlay is on UIParent, not the map), and after you switch the map to another zone the
-- previous zone's pins were drawn over the new map. Both are now caught on the very next frame.
-- Run from the tests folder:  node run.js "<repo root>" test_logic_world_mappins.lua
local base = ADDON_PATH
local failures = {}
local function check(cond, why) if not cond then failures[#failures + 1] = why end end

issecretvalue = function() return false end
ForeverHub_Receive = function() end
ForeverHub_IsOff = function() return false end
GetTime = function() return 0 end
InCombatLockdown = function() return false end
GetRealmName = function() return "R" end
UnitLevel = function() return 10 end
GetCVar = function() return "0" end
SlashCmdList = {}

local frames = {}
local function texture()
    local t = {}
    function t:SetAllPoints() end
    function t:SetTexture(f) self.file = f end
    function t:SetAtlas(a) self.atlas = a end
    function t:SetTexCoord() end
    return t
end
local function newFrame(kind, parent)
    local f = { kind = kind, parent = parent, shown = true, scripts = {}, registered = {} }
    function f:RegisterEvent(e) self.registered[e] = true end
    function f:SetScript(s, fn) self.scripts[s] = fn end
    function f:SetSize() end
    function f:SetPoint(...) self.point = { ... } end
    function f:SetAllPoints() end
    function f:ClearAllPoints() self.point = nil end
    function f:Show() self.shown = true end
    function f:Hide() self.shown = false end
    function f:IsShown() return self.shown end
    function f:CreateTexture() return texture() end
    function f:RegisterForClicks() end
    function f:SetFrameLevel() end
    function f:SetFrameStrata() end
    function f:GetEffectiveScale() return 1 end
    function f:SetOwner() end
    function f:AddLine() end
    frames[#frames + 1] = f
    return f
end
CreateFrame = function(kind, name, parent)
    local f = newFrame(kind, parent)
    if name then _G[name] = f end
    return f
end
UIParent = { GetEffectiveScale = function() return 1 end }

local rect = { GetLeft = function() return 100 end, GetTop = function() return 700 end,
    GetWidth = function() return 800 end, GetHeight = function() return 500 end,
    GetEffectiveScale = function() return 1 end }
local Child = setmetatable({}, { __index = rect })
local mapShown, canvasMap = true, 1429
WorldMapFrame = {
    ScrollContainer = setmetatable({ Child = Child }, { __index = rect }),
    IsShown = function() return mapShown end,
    GetMapID = function() return canvasMap end,
    GetFrameStrata = function() return "HIGH" end,
    GetFrameLevel = function() return 5 end,
}
local NAMES = { [1429] = "Elwynn Forest", [1436] = "Westfall" }
C_Map = {
    GetBestMapForUnit = function() return nil end,
    GetMapInfo = function(id) return NAMES[id] and { name = NAMES[id] } or nil end,
}
LandmarksDB = { R = { places = {
    { kind = "repair", name = "Smith", mapID = 1429, x = 0.5, y = 0.5, seen = 1 },
} } }

assert(loadfile(base .. "/MapPins/MapPins.lua"))("MapPins", {})
local events, driver, overlay
for _, f in ipairs(frames) do
    if f.registered.PLAYER_LOGIN then events = f end
    if f.scripts.OnUpdate then driver = f end
    if f.kind == "Frame" and f.parent == UIParent and not f.registered.PLAYER_LOGIN then overlay = overlay or f end
end
local function frame(seconds) driver.scripts.OnUpdate(driver, seconds) end
local function visiblePins()
    local n = 0
    if not overlay.shown then return 0 end
    for _, f in ipairs(frames) do
        if f.kind == "Button" and f.parent == overlay and f.shown and f.record then n = n + 1 end
    end
    return n
end

events.scripts.OnEvent(events, "PLAYER_LOGIN")
frame(1.1)   -- one full check: data read, pins placed
frame(0.1)
check(overlay.shown and visiblePins() == 1, "Elwynn: the repairer's pin is on the open map: " .. visiblePins())

-- Map closed: the very next frame (well before the next 0.1 s check) has no pins left on screen.
mapShown = false
frame(0.01)
check(not overlay.shown, "map closed: our overlay hides on the next frame, not up to 0.1 s later")
mapShown = true
frame(0.1)
check(overlay.shown and visiblePins() == 1, "map open again: pin back")

-- Map switched to another zone: Elwynn's pin is not drawn over Westfall, not even for one frame.
frame(0.05)
canvasMap = 1436
frame(0.01)
check(visiblePins() == 0, "switched to Westfall: Elwynn's pin gone on the next frame: " .. visiblePins())
canvasMap = 1429
frame(0.01)
check(visiblePins() == 1, "back to Elwynn: pin back on the next frame")

if #failures > 0 then
    error(#failures .. " failure(s):\n- " .. table.concat(failures, "\n- "), 0)
end
io.write("MapPins logic test passed\n")
