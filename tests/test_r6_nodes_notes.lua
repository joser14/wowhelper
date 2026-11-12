-- Round 6 #17: your own notes on the map, in MapPins. "+ Note" on our world map overlay opens a dialog (text,
-- coordinates prefilled with your position); the note is our own pin on the world map and minimap; the "Notes"
-- panel lists this map's notes and deletes them; the Map pins page adds ("note <text>"), lists and deletes.
-- Bounded (200 notes, 60 letters, no escape codes), cleaned at login, closed with the map, hidden on hub Off.
-- Nothing of Blizzard's map is written; no chat; no frames made in combat.
-- Run from the tests folder:  node run.js "<repo root>" test_r6_nodes_notes.lua
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
time = function() return 1800000000 end
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
C_Minimap = { GetViewRadius = function() return 200 end }

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
    local f = { kind = kind, parent = parent, template = template, shown = true, scripts = {}, registered = {}, lines = {} }
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
    function f:SetText(t) self.text = t end
    function f:GetText() return self.text end
    function f:SetFocus() self.focus = true end
    function f:ClearFocus() self.focus = false end
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

local function vec(x, y) return { x = x, y = y, GetXY = function(self) return self.x, self.y end } end
CreateVector2D = vec
local playerMap, px, py = 1438, 0.3, 0.5
local waypoints = {}
C_Map = {
    GetMapInfo = function(id)
        if id == 1438 then return { mapID = 1438, name = "Teldrassil", mapType = 3, parentMapID = 1414 } end
        if id == 1439 then return { mapID = 1439, name = "Darkshore", mapType = 3, parentMapID = 1414 } end
    end,
    GetBestMapForUnit = function() return playerMap end,
    GetPlayerMapPosition = function(id) if id == playerMap and px then return vec(px, py) end end,
    GetWorldPosFromMapPos = function(id, v) if id == 1438 then return 1, vec(10000 - v.y * 4000, 2000 - v.x * 4000) end end,
    CanSetUserWaypointOnMap = function() return true end,
    SetUserWaypoint = function(p) waypoints[#waypoints + 1] = p end,
}
UiMapPoint = { CreateFromCoordinates = function(m, x, y) return { uiMapID = m, x = x, y = y } end }

---------------------------------------------------------------------------- load
-- Saved notes in an odd shape: the bad ones are dropped at login.
MapPinsDB = { notes = {
    { mapID = 1439, x = 0.5, y = 0.5, text = "Old note" },
    { mapID = 1439, x = 2, y = 0.5, text = "Off the map" },
    { mapID = 1439, x = 0.5, y = 0.5, text = "   " },
    "junk",
} }
assert(loadfile(base .. "/MapPins/MapPins.lua"))("MapPins", {})
local events, driver, overlay
for _, f in ipairs(frames) do
    if f.registered.PLAYER_LOGIN then events = f end
    if f.scripts.OnUpdate then driver = f end
    if f.kind == "Frame" and f.parent == UIParent and f.fonts then overlay = f end
end
local bar
for _, f in ipairs(frames) do
    if f.kind == "Frame" and f.parent == overlay then bar = f end
end
check(events and driver and overlay and bar, "frames found")
local addButton, listButton, dialog, panel
local boxes, rows, deletes = {}, {}, {}
for _, f in ipairs(frames) do
    if f.parent == bar and f.kind == "Button" and f.text == "+ Note" then addButton = f end
    if f.parent == bar and f.kind == "Button" and f.text == "Notes" then listButton = f end
    if f.parent == bar and f.kind == "Frame" then
        if not dialog then dialog = f else panel = f end
    end
end
for _, f in ipairs(frames) do
    if f.kind == "EditBox" and f.parent == dialog then boxes[#boxes + 1] = f end
    if f.kind == "Button" and f.parent == panel and f.template == nil then rows[#rows + 1] = f end
    if f.kind == "Button" and f.parent == panel and f.text == "Delete" then deletes[#deletes + 1] = f end
end
check(addButton and listButton and dialog and panel and #boxes == 3 and #rows == 8 and #deletes == 8, "notes UI made at load")
local textBox, xBox, yBox = boxes[1], boxes[2], boxes[3]
local function button(parent, label)
    for _, f in ipairs(frames) do
        if f.parent == parent and f.kind == "Button" and f.text == label then return f end
    end
end
local function click(f) f.scripts.OnClick(f, "LeftButton") end
local function fire(ev, ...) events.scripts.OnEvent(events, ev, ...) end
local function tick(seconds)
    for _ = 1, math.floor(seconds / 0.1 + 0.5) do clock = clock + 0.1; driver.scripts.OnUpdate(driver, 0.1) end
end
local function page(arg) out = {}; SlashCmdList.MAPPINS(arg); return table.concat(out, "\n") end
local function notePins(onMinimap)
    local list = {}
    for _, f in ipairs(frames) do
        local parentOk = onMinimap and f.parent == Minimap or (not onMinimap and f.parent == overlay and overlay.shown)
        if f.kind == "Button" and parentOk and f.shown and f.record and f.record.layer == "notes" then list[#list + 1] = f end
    end
    return list
end

fire("PLAYER_LOGIN")
fire("PLAYER_ENTERING_WORLD")
check(#MapPinsDB.notes == 1 and MapPinsDB.notes[1].text == "Old note", "bad saved notes dropped: " .. #MapPinsDB.notes)

-- The bar shows only with the map.
tick(1.2)
check(not overlay.shown, "map closed: no overlay")
mapShown, canvasMap = true, 1438
tick(0.2)
check(overlay.shown and bar.shown and bar.point, "the notes bar shows on the open map")
check(bar.point[1] == "BOTTOMRIGHT" and bar.point[4] == 892 and bar.point[5] == 208, "in the visible map's bottom-right corner")
check(listButton.text == "Notes (0)", "the Notes button counts this map's notes: " .. tostring(listButton.text))

-- + Note: the dialog, prefilled with your position.
click(addButton)
check(dialog.shown and textBox.focus, "the dialog opens with the text box focused")
check(xBox.text == "30.0" and yBox.text == "50.0", "prefilled with your position: " .. tostring(xBox.text) .. "," .. tostring(yBox.text))
textBox.text = ""
click(button(dialog, "Save"))
check(dialog.shown and #MapPinsDB.notes == 1, "an empty note isn't saved")
textBox.text = "Moonwell |cffff0000here|r and a long tail that goes on past the sixty letter limit for sure"
textBox.scripts.OnEnterPressed(textBox)
check(not dialog.shown and #MapPinsDB.notes == 2, "Enter saves and closes")
local note = MapPinsDB.notes[2]
check(note.mapID == 1438 and note.x == 0.3 and note.y == 0.5, "saved at your position on the map shown")
check(not note.text:find("|", 1, true) and #note.text <= 60, "no escape codes, at most 60 letters: " .. note.text)
tick(0.2)
local shown = notePins()
check(#shown == 1 and shown[1].record.title == note.text, "the note is a pin on the world map")
check(shown[1].point and shown[1].point[4] == 100 + 0.3 * 800 and shown[1].point[5] == 700 - 0.5 * 500, "at its map point")
check(#notePins(true) == 1, "and on the minimap")
check(listButton.text == "Notes (1)", "the count follows")

-- Typed coordinates; out of range is refused.
click(addButton)
textBox.text, xBox.text, yBox.text = "Cave", "70", "20,5"
click(button(dialog, "Save"))
check(#MapPinsDB.notes == 3 and MapPinsDB.notes[3].x == 0.7 and MapPinsDB.notes[3].y == 0.205, "typed coordinates (comma too)")
click(addButton)
textBox.text, xBox.text, yBox.text = "Bad", "150", "20"
click(button(dialog, "Save"))
check(#MapPinsDB.notes == 3 and dialog.shown, "coordinates past 100 refused")
local hint
for _, fs in ipairs(dialog.fonts) do if fs.text:find("0 to 100", 1, true) then hint = fs end end
check(hint, "the dialog says why")
dialog.scripts = dialog.scripts
textBox.scripts.OnEscapePressed(textBox)
check(not dialog.shown, "Escape closes the dialog")

-- The panel: this map's notes, click for a map pin, Delete removes.
click(listButton)
check(panel.shown and rows[1].shown and rows[2].shown and not rows[3].shown, "the panel lists this map's 2 notes")
check(rows[2].Text.text:find("Cave", 1, true) and rows[2].Text.text:find("70.0, 20.5", 1, true), "with text and coordinates")
click(rows[2])
check(#waypoints == 1 and waypoints[1].x == 0.7, "a click on a note sets a map pin there")
click(deletes[2])
check(#MapPinsDB.notes == 2 and not rows[2].shown, "Delete removes the note")
tick(0.2)
check(#notePins() == 1, "its pin goes")
-- Another map: the panel follows it.
canvasMap = 1439
tick(0.2)
check(panel.shown and rows[1].Text.text:find("Old note", 1, true) and not rows[2].shown, "the panel shows the map shown")
canvasMap = 1438
tick(0.2)
-- Closing the map closes the panel and dialog.
mapShown = false
tick(0.2)
check(not overlay.shown and not panel.shown and not dialog.shown, "closing the map closes the panel")

-- The page: add with the text as typed, list, delete.
local text = page("note Hidden Chest")
check(text:find("Note added at your position.", 1, true) and text:find("Hidden Chest", 1, true), "note <text> keeps its case")
check(text:find("3. Hidden Chest", 1, true) and text:find("Teldrassil 30.0, 50.0", 1, true), "the notes list")
text = page("delete note 1")
check(text:find("Deleted note 1: Old note", 1, true) and #MapPinsDB.notes == 2, "delete note 1")
check(page("delete note 9"):find("There's no note 9.", 1, true), "no such note")
px = nil
check(page("note Somewhere"):find("can't be read here", 1, true) and #MapPinsDB.notes == 2, "no position: not added")
px = 0.3
check(page(""):find("Your notes:|r on, 2 pins", 1, true), "the layer list counts the notes")
page("off notes")
tick(1.2)
mapShown = true
tick(0.2)
check(#notePins() == 0, "the notes layer switches off")
page("on notes")
tick(0.2)
local on = notePins()
check(#on == 1 and #on[1].covered == 1, "and on (two notes on one spot: one pin, the other named in its tooltip)")

-- Bounded: 200 notes.
for i = #MapPinsDB.notes + 1, 200 do
    MapPinsDB.notes[i] = { mapID = 1439, x = 0.5, y = 0.5, text = "n" .. i }
end
click(addButton)
textBox.text = "One too many"
click(button(dialog, "Save"))
check(#MapPinsDB.notes == 200, "no more than 200 notes")
textBox.scripts.OnEscapePressed(textBox)

-- In combat the buttons still work, and no frame is made.
combat = true
click(listButton)
click(listButton)
click(addButton)
textBox.scripts.OnEscapePressed(textBox)
combat = false

-- Hub Off: the panel closes and every pin goes at once.
click(listButton)
hubOff.MapPins = true
ForeverHubOnSwitch.MapPins(true)
check(not overlay.shown and not panel.shown and #notePins(true) == 0, "Off: overlay, panel and minimap pins hidden")
hubOff.MapPins = nil
ForeverHubOnSwitch.MapPins(false)
tick(0.2)
check(overlay.shown and #notePins() == 1, "On: back")

check(chat == 0, "nothing printed to chat")
if #failures > 0 then
    error(#failures .. " failure(s):\n- " .. table.concat(failures, "\n- "), 0)
end
print = nil
io.write("test_r6_nodes_notes: ALL TESTS PASSED\n")
