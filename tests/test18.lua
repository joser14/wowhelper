IsShiftKeyDown = function() return SHIFT end
SHIFT = true
-- New engine features: stable step keys + migration, accept/turn-in grace, per-objective "do" steps,
-- several waypoints per step, utility steps (hearth, flight path, item, train, zone), XP gates and the
-- outlevel override, corpse arrow, missing-prerequisite names, the route list window and
-- LevelGuide_UpcomingStops. ADDON_PATH is the LevelGuide folder.
local base = ADDON_PATH
local frames, handled = {}, {}
FONTS = {}
TIPLINES = {}
local function newRegion(kind)
    local r = { kind = kind, shown = true, scripts = {}, text = "", rotation = 0 }
    function r:SetText(t) self.text = t; if kind == "GameTooltip" then TIPLINES = { t } end end
    function r:AddLine(t) if kind == "GameTooltip" then TIPLINES[#TIPLINES + 1] = t end end
    function r:SetScript(s, f) self.scripts[s] = f end
    function r:Show() self.shown = true end
    function r:Hide() self.shown = false end
    function r:SetShown(v) self.shown = v and true or false end
    function r:IsShown() return self.shown end
    function r:SetRotation(a) self.rotation = a end
    function r:GetStringHeight() return 12 end
    function r:CreateFontString() local f = newRegion("font"); FONTS[#FONTS + 1] = f; return f end
    function r:CreateTexture() local t = newRegion("texture"); rawset(r, "tex", t); return t end
    return setmetatable(r, { __index = function(_, k)
        if k == "step" or k == "tex" or k == "routeIndex" or k == "why" or k == "state" then return nil end
        return function() end
    end })
end
CreateFrame = function(kind, name)
    local f = newRegion(kind)
    frames[#frames + 1] = f
    if name then _G[name] = f end
    return f
end
UIParent = newRegion("Frame")
issecretvalue = function() return false end
geterrorhandler = function() return function(e) handled[#handled + 1] = tostring(e) end end
local now = 100
GetTime = function() return now end
local level = 2
UnitLevel = function() return level end
local xp = 0
UnitXP = function() return xp end
UnitXPMax = function() return 400 end
UnitName = function() return "Juan" end
GetRealmName = function() return "R" end
UnitRace = function() return "Night Elf", "NightElf" end
local zone = "Testzone"
local px, py = 0.5, 0.5
local function vec(x, y) return { GetXY = function() return x, y end } end
CreateVector2D = vec
C_Map = {
    GetBestMapForUnit = function() return 101 end,
    GetMapInfo = function(id)
        if id == 101 then return { name = "A Cave", mapType = 5, parentMapID = 1438 } end
        if id == 1438 then return { name = zone, mapType = 3, parentMapID = 12 } end
        if id == 12 then return { name = "Kalimdor", mapType = 2, parentMapID = 0 } end
    end,
    GetPlayerMapPosition = function(id) if id == 1438 then return vec(px, py) end end,
    GetWorldPosFromMapPos = function(_, p) local x, y = p:GetXY(); return 0, vec(x * 3000, y * 3000) end,
}
local waypoint
C_Map.SetUserWaypoint = function(p) waypoint = p end
UiMapPoint = { CreateFromCoordinates = function(m, x, y) return { m = m, x = x, y = y } end }
C_SuperTrack = { SetSuperTrackedQuestID = function() end, SetSuperTrackedUserWaypoint = function() end }
GetPlayerFacing = function() return 0 end
local bind = "Somewhere Else"
GetBindLocation = function() return bind end
local items, spells = {}, {}
C_Item = { GetItemCount = function(id) return items[id] or 0 end }
C_SpellBook = { IsSpellKnown = function(id) return spells[id] or false end }
local subzone = ""
GetSubZoneText = function() return subzone end
local taxiNodes = {}
C_TaxiMap = { GetAllTaxiNodes = function(map) return map == 1438 and taxiNodes or {} end }
Enum = { FlightPathState = { Current = 0, Reachable = 1, Unreachable = 2 } }
ERR_NEWTAXIPATH = "New flight path discovered!"
local ghost, corpsePos = false, nil
UnitIsGhost = function() return ghost end
C_DeathInfo = { GetCorpseMapPosition = function(m) if m == 1438 and corpsePos then return vec(corpsePos[1], corpsePos[2]) end end }
local valid = {}
C_EventUtils = { IsEventValid = function(name) valid[name] = true; return name ~= "PLAYER_UNGHOST" end }
local log, OBJ, TITLES = {}, {}, {}
C_QuestLog = {
    GetNumQuestLogEntries = function() return #log end,
    GetInfo = function(i) return log[i] end,
    IsComplete = function(id) for _, q in ipairs(log) do if q.questID == id then return q.ready end end end,
    ReadyForTurnIn = function() return false end,
    GetQuestObjectives = function(id) return OBJ[id] or {} end,
    GetTitleForQuestID = function(id) return TITLES[id] end,
    IsQuestTrivial = function() return false end,
    GetQuestsOnMap = function() return QUESTS_ON_MAP or {} end,
    IsQuestFlaggedCompleted = function(id) return FLAGGED and FLAGGED[id] or false end,
}

-- Route-building helpers, as in Routes.lua.
local function A(q, npc, x, y, lvl, part) return { t = "accept", q = q, npc = npc, x = x, y = y, lvl = lvl, part = part } end
local function D(q, note, x, y, lvl, part) return { t = "do", q = q, note = note, x = x, y = y, lvl = lvl, part = part } end
local function T(q, npc, x, y, lvl, part) return { t = "turnin", q = q, npc = npc, x = x, y = y, lvl = lvl, part = part } end
local function G(text, x, y, lvl, note) return { t = "go", text = text, x = x, y = y, lvl = lvl, note = note } end
local function New(step) step.since = 2 return step end

-- 1. Saved skips under old "Zone#index" keys, before this version: index 2 was Q2. This version
-- inserted a step at the top (New), which used to move the skip onto Q1.
LevelGuideDB = { characters = { ["Juan-R"] = { done = {}, skips = { ["Testzone#2"] = true, ["Testzone#9"] = true },
    visited = { ["Testzone#3"] = true } } } }
assert(loadfile(base .. "/QuestIDs.lua"))("LevelGuide", {})
assert(loadfile(base .. "/Prereqs.lua"))("LevelGuide", {})
assert(loadfile(base .. "/Routes.lua"))("LevelGuide", {})
LevelGuideQuestIDs, LevelGuidePrereqs = { ids = {}, renamed = {} }, nil
-- The real data uses the new step types.
local REAL = LevelGuideRoutes.chains.NightElf
local found = {}
for _, route in ipairs(REAL) do
    for _, s in ipairs(route.steps) do
        if s.t == "home" then found["home " .. s.place] = s.since end
        if s.t == "fp" then found["fp " .. s.place] = s.since end
        if s.obj then found["obj " .. s.q .. " " .. (type(s.obj) == "table" and table.concat(s.obj, ",") or s.obj)] = true end
        if s.pts then found["pts " .. s.q] = #s.pts end
    end
end
for _, want in ipairs({ "home Dolanaar", "home Auberdine", "fp Rut'theran Village", "fp Auberdine",
    "obj Iverron's Antidote 2,3", "obj Iverron's Antidote 1", "obj The Fall of Ameth'Aran 1", "obj The Fall of Ameth'Aran 2",
    "pts Deep Ocean, Vast Sea" }) do
    assert(found[want], "real data: " .. want)
end
assert(found["home Dolanaar"] == 2 and found["fp Auberdine"] == 2, "added steps are marked New()")
local Z1 = { zone = "Testzone", min = 1, max = 10, steps = {
    New(A("Inserted", "Npc New", 50, 50, 1)),
    A("Q1", "Giver One", 50, 50, 1),
    A("Q2", "Giver Two", 51, 50, 1),
    G("Walk on", 70, 70, 1),
} }
LevelGuideRoutes.chains.NightElf = { Z1 }
assert(loadfile(base .. "/LevelGuide.lua"))("LevelGuide", {})
local events = frames[1]
for _, name in ipairs({ "TAXIMAP_OPENED", "HEARTHSTONE_BOUND", "PLAYER_DEAD" }) do
    assert(valid[name], "registered through IsEventValid: " .. name)
end
events.scripts.OnEvent(events, "PLAYER_LOGIN")
local frame = LevelGuideFrame
local function update(t) frame.scripts.OnUpdate(frame, t or 2.1) end
local function fire(...) events.scripts.OnEvent(events, ...) end
update()
assert(#handled == 0, "clean: " .. tostring(handled[1]))
local buttons = {}
for _, f in ipairs(frames) do if f.kind == "Button" and rawget(f, "left") then buttons[#buttons + 1] = f end end
local current = buttons[1]
local function all() local t = { current.left.text }; for i = 2, 4 do if buttons[i].shown then t[#t + 1] = buttons[i].left.text end end; return table.concat(t, "\n") end
local function findFont(pattern) for _, f in ipairs(FONTS) do if f.text:find(pattern, 1, true) then return f end end end
local char = LevelGuideDB.characters["Juan-R"]
local skipKeys, visitKeys = {}, {}
for k in pairs(char.skips) do skipKeys[#skipKeys + 1] = k end
for k in pairs(char.visited) do visitKeys[#visitKeys + 1] = k end
print("migrated skips: " .. table.concat(skipKeys, ", ") .. " / visited: " .. table.concat(visitKeys, ", "))
assert(#skipKeys == 1 and skipKeys[1]:find("|accept|Q2|", 1, true), "old index 2 -> Q2 (index 9 dropped)")
assert(#visitKeys == 1 and visitKeys[1]:find("|go|Walk on|", 1, true), "old index 3 -> the go step")
assert(LevelGuideDB.stepKeys == 2, "migration runs once")
print(all())
assert(all():find("Q1", 1, true) and all():find("Inserted", 1, true) and not all():find("Q2", 1, true), "skip stays on Q2")
-- A later edit inserts another step before them: the content key keeps the skip on Q2.
table.insert(Z1.steps, 1, A("Another New One", "Npc Other", 52, 50, 1))
update()
assert(all():find("Q1", 1, true) and not all():find("Q2", 1, true), "still on Q2 after an insert: " .. all())
-- An old key written mid-session (older saved data) is moved too.
char.skips["Testzone#1"] = true
update()
assert(not char.skips["Testzone#1"], "old key moved")
-- (index 1 among the steps without New() is now "Another New One", which wasn't marked New)
assert(not all():find("Another New One", 1, true) and all():find("Inserted", 1, true), "moved by the old layout: " .. all())
print("1 ok")

-- 2. Grace windows: right after an accept the log may lag; right after a turn-in it may still list the quest.
char.skips, char.visited = {}, {}
LevelGuideRoutes.chains.NightElf = { { zone = "Testzone", min = 1, max = 10, steps = { A("Q1", "Giver One", 50, 50, 1) } } }
TITLES[501] = "Q1"
update()
assert(current.left.text:find("Pick up:|r Q1", 1, true), "pick-up: " .. current.left.text)
fire("QUEST_ACCEPTED", 501)
update()
assert(not all():find("Q1", 1, true), "no flicker back right after accepting: " .. all())
now = now + 3
update()
assert(all():find("Q1", 1, true), "after the grace, the log is the truth again")
log = { { questID = 777, title = "Extra", ready = true } }
QUESTS_ON_MAP = { { questID = 777, x = 0.3, y = 0.3 } }
update()
assert(all():find("Turn in:|r Extra", 1, true), "log turn-in shown: " .. all())
fire("QUEST_TURNED_IN", 777)
update()
assert(not all():find("Extra", 1, true), "turned in: not shown while the log catches up: " .. all())
now = now + 6
update()
assert(all():find("Extra", 1, true), "grace is only 5 s")
log, QUESTS_ON_MAP = {}, {}
print("2 ok")

-- 3. Per-objective "do" steps.
local kill, collect = D("Q3", "Kill wolves", 40, 40, 1), D("Q3", "Collect pelts", 60, 60, 1)
kill.obj, collect.obj = 1, 2
LevelGuideRoutes.chains.NightElf = { { zone = "Testzone", min = 1, max = 10, steps = {
    A("Q3", "Giver", 50, 50, 1), kill, collect, T("Q3", "Giver", 50, 50, 1) } } }
log = { { questID = 503, title = "Q3" } }
OBJ[503] = { { text = "Wolves: 2/5", finished = false }, { text = "Pelts: 0/3", finished = false } }
update()
print(all())
assert(all():find("Do:|r Q3", 1, true), "do steps")
local details = {}
for i = 1, 4 do if buttons[i].shown and buttons[i].step then details[#details + 1] = tostring(buttons[i].step.detail) end end
local d = table.concat(details, " | ")
assert(d:find("Kill wolves. Now: Wolves: 2/5", 1, true) and d:find("Collect pelts. Now: Pelts: 0/3", 1, true), "each shows its objective: " .. d)
OBJ[503][1].finished = true
update()
details = {}
for i = 1, 4 do if buttons[i].shown and buttons[i].step then details[#details + 1] = tostring(buttons[i].step.detail) end end
d = table.concat(details, " | ")
assert(not d:find("Kill wolves", 1, true) and d:find("Collect pelts", 1, true), "objective 1 done, its step goes: " .. d)
log, OBJ = {}, {}
print("3 ok")

-- 4. Several waypoints: in order, auto-advancing, remembered per step; LevelGuide_UpcomingStops shows them.
local walk = G("Around the cliff", 50, 50, 1)
walk.pts = { { 50, 50 }, { 60, 50 }, { 70, 50 } }
LevelGuideRoutes.chains.NightElf = { { zone = "Testzone", min = 1, max = 10, steps = { walk, A("After", "Giver", 80, 50, 1) } } }
px, py = 0.4, 0.5
update()
assert(current.left.text:find("Around the cliff", 1, true) and current.step.pointIndex == 1 and current.step.x == 0.5, "point 1")
local stops = LevelGuide_UpcomingStops()
assert(#stops >= 3 and stops[1].current == true and stops[1].kind == "go" and stops[1].mapID == 1438, "stops")
assert(math.abs(stops[2].x - 0.6) < 1e-9 and stops[2].label:find("point 2 of 3", 1, true) and stops[2].current == false, "remaining points")
assert(stops[4] and stops[4].kind == "accept" and stops[4].label == "Pick up: After (Giver)", "next step: " .. tostring(stops[4] and stops[4].label))
px = 0.5
update(0.06)
update(0.2)
assert(current.step.pointIndex == 2 and math.abs(current.step.x - 0.6) < 1e-9, "advanced to point 2")
local key = current.step.routeKey
assert(char.points[key] == 2, "remembered")
px = 0.6; update(0.06); update(0.2)
px = 0.7; update(0.06); update(0.2)
assert(char.visited[key], "last point completes the go step")
assert(current.left.text:find("After", 1, true), "moved on: " .. current.left.text)
print("4 ok")

-- 5. Utility steps, completed by watching only.
local function U(t, fields) fields.t = t; return fields end
local home = U("home", { text = "Testville", place = "Testville", npc = "Innkeeper Test", x = 50, y = 50, lvl = 1 })
local fp = U("fp", { text = "Testville", place = "Testville", npc = "Bird Master", x = 50.2, y = 50, lvl = 1 })
local item = U("item", { text = "Bones", item = 1234, count = 3, x = 50.4, y = 50, lvl = 1 })
local train = U("train", { text = "Fire Spell", spells = { 5554, 5555 }, npc = "Trainer", x = 50.6, y = 50, lvl = 1 })
local reach = U("zone", { text = "The Grove", reach = "The Grove", x = 90, y = 90, lvl = 1 })
LevelGuideRoutes.chains.NightElf = { { zone = "Testzone", min = 1, max = 10, steps = { home, fp, item, train, reach } } }
char.visited, char.marks = {}, {}
px, py = 0.5, 0.5
update()
print(all())
assert(all():find("Set hearth:|r Testville", 1, true) and all():find("Flight path:|r Testville", 1, true)
    and all():find("Get:|r Bones", 1, true) and all():find("Train:|r Fire Spell", 1, true), "all four shown")
bind = "Testville"
update()
assert(not all():find("Set hearth", 1, true), "bound")
bind = "Elsewhere"; update()
assert(not all():find("Set hearth", 1, true), "a later bind elsewhere doesn't reopen it")
taxiNodes = { { name = "Testville, Testzone", state = 2 } }
fire("TAXIMAP_OPENED", 1); update()
assert(all():find("Flight path", 1, true), "unreachable node isn't known")
taxiNodes = { { name = "Testville, Testzone", state = 1 } }
fire("TAXIMAP_OPENED", 1); update()
assert(not all():find("Flight path", 1, true), "known at the flight master")
items[1234] = 2; update()
assert(all():find("Get:|r Bones", 1, true) and findFont("Have 2/3"), "item progress")
items[1234] = 3; update()
assert(not all():find("Bones", 1, true), "have them")
items[1234] = 0; update()
assert(not all():find("Bones", 1, true), "used up later: stays done")
spells[5555] = true; update()
assert(not all():find("Fire Spell", 1, true), "trained (any rank)")
assert(current.left.text:find("Go to:|r The Grove", 1, true), "zone step: " .. current.left.text)
subzone = "The Grove"; update()
assert(not all():find("The Grove", 1, true), "reached")
-- The "new flight path" message counts for a flight step you're standing at.
local fp2 = U("fp", { text = "Other Perch", place = "Other Perch", npc = "Bird", x = 50, y = 50, lvl = 1 })
LevelGuideRoutes.chains.NightElf = { { zone = "Testzone", min = 1, max = 10, steps = { fp2 } } }
update()
assert(all():find("Other Perch", 1, true), "fp2 shown")
fire("UI_INFO_MESSAGE", 0, "Something else"); update()
assert(all():find("Other Perch", 1, true), "other messages ignored")
fire("UI_INFO_MESSAGE", 0, "New flight path discovered!"); update()
assert(not all():find("Other Perch", 1, true), "learned")
print("5 ok")

-- 6. XP gate, with live progress; what follows waits behind it. Outlevel override.
local gate = U("xp", { text = "50% into level 2", level = 2, frac = 0.5, note = "Boars by the lake", x = 55, y = 55, lvl = 2 })
local old = A("Old One", "Giver", 45, 45, 1)
old.outlevel = 1
LevelGuideRoutes.chains.NightElf = { { zone = "Testzone", min = 1, max = 10, steps = {
    old, A("Before", "Giver", 50, 50, 1), gate, A("After Gate", "Giver", 51, 51, 2) } } }
level, xp = 2, 100
update()
print(all())
assert(not all():find("Old One", 1, true), "outlevel = 1: done one level above")
assert(all():find("Before", 1, true) and not all():find("After Gate", 1, true), "gate holds what follows")
log = { { questID = 600, title = "Before" } }
update()
assert(current.left.text:find("Grind:|r 50% into level 2", 1, true), "grind step: " .. current.left.text)
assert(findFont("You're level 2 at 25%."), "live progress")
xp = 200
update()
assert(not all():find("Grind", 1, true) and all():find("After Gate", 1, true), "gate passed")
log = {}
print("6 ok")

-- 7. Corpse arrow: takes over while you're a ghost, then hands back.
LevelGuideRoutes.chains.NightElf = { { zone = "Testzone", min = 1, max = 10, steps = { A("Far", "Giver", 90, 50, 1) } } }
px, py = 0.5, 0.5
ghost, corpsePos = true, { 0.5, 0.6 }
update()
local yards = findFont("Corpse")
assert(yards and (yards.text == "Corpse 300 yd" or yards.text == "Corpse 299 yd"),"corpse distance: " .. tostring(yards and yards.text))
assert(math.abs(frame.tex.rotation - math.pi) < 1e-6 or math.abs(frame.tex.rotation + math.pi) < 1e-6, "points south: " .. frame.tex.rotation)
ghost = false
update(0.06)
assert(not findFont("Corpse"), "back to the step")
assert(findFont("1200 yd"), "step distance again")
print("7 ok")

-- 8. Missing prerequisites by name, in the tooltip and the route list; 9. the route list window.
LevelGuideQuestIDs = { ids = { ["First Quest"] = { 9001 } }, renamed = {} }
LevelGuidePrereqs = { Locked = { all = { 9001 } }, ["Too High"] = { level = 5 } }
local R9 = { zone = "Testzone", min = 1, max = 10, steps = {
    A("Locked", "Giver", 50, 50, 1), A("Too High", "Giver", 50, 50, 1), A("Open", "Giver B", 52, 50, 1),
    A("Open Two", "Giver C", 54, 50, 1) } }
LevelGuideRoutes.chains.NightElf = { R9 }
level = 2
update()
print(all())
-- Level step tooltip names what's missing.
current.scripts.OnEnter(current)
local tip = table.concat(TIPLINES, "\n")
assert(not current.left.text:find("Reach level", 1, true) or tip:find("Needs first: level 5", 1, true), "tooltip: " .. tip)
local listButton
for _, f in ipairs(frames) do if f.kind == "Button" and f.text == "List" then listButton = f end end
assert(listButton, "list button on the header")
listButton.scripts.OnClick(listButton)
local list = LevelGuideRouteList
assert(list and list.shown, "list open")
local rows = {}
local seenList = false
for _, f in ipairs(frames) do
    if f == list then seenList = true end
    if seenList and f.kind == "Button" and rawget(f, "left") then rows[#rows + 1] = f end
end
for i = 1, 4 do print(rows[i].left.text .. "  " .. rows[i].right.text .. "  " .. tostring(rawget(rows[i], "why"))) end
assert(rows[1].right.text:find("blocked", 1, true) and rawget(rows[1], "why") == "needs First Quest", "blocked by name")
assert(rows[2].right.text:find("blocked", 1, true) and rawget(rows[2], "why") == "needs level 5", "blocked by level")
assert(rows[3].right.text:find("now", 1, true) or rows[3].right.text:find("to do", 1, true), "open")
assert(not rows[5].shown, "only the route's 4 steps")
rows[1].scripts.OnEnter(rows[1])
assert(table.concat(TIPLINES, "\n"):find("needs First Quest", 1, true), "row tooltip names it")
-- Click: the arrow points at that step.
rows[4].scripts.OnClick(rows[4], "LeftButton")
update(0.2)
assert(current.left.text:find("Open Two", 1, true) and current.left.text:find("(picked)", 1, true), "picked first: " .. current.left.text)
assert(waypoint and math.abs(waypoint.x - 0.54) < 1e-9, "map waypoint on it")
-- Shift+right-click: skip, and again: unskip.
rows[3].scripts.OnClick(rows[3], "RightButton")
assert(rows[3].right.text:find("skipped", 1, true), "skipped in the list")
update(0.2)
assert(not all():find("Pick up:|r Open\n", 1, true) and not (all() .. "\n"):find("Pick up:|r Open\n", 1, true), "skipped in the guide: " .. all())
rows[3].scripts.OnClick(rows[3], "RightButton")
assert(not rows[3].right.text:find("skipped", 1, true), "unskipped")
SHIFT = false
rows[2].scripts.OnClick(rows[2], "RightButton")
assert(not rows[2].right.text:find("skipped", 1, true), "plain right-click does nothing")
SHIFT = true
-- Header left-click toggles the list too; right-click still undoes skips.
local header
for _, f in ipairs(frames) do if f.scripts.OnDragStart and f ~= list then header = f; break end end
header.scripts.OnClick(header, "LeftButton")
assert(not list.shown, "header click closes it")
-- Once the picked step is done, the pick clears.
log = { { questID = 700, title = "Open Two" } }
update(0.2)
assert(not current.left.text:find("(picked)", 1, true), "pick cleared")
log = {}
-- The level step's tooltip names the missing prerequisites too.
LevelGuideRoutes.chains.NightElf = { { zone = "Testzone", min = 1, max = 10, steps = { A("Too High", "Giver", 50, 50, 1) } } }
update()
assert(current.left.text:find("Reach level:|r 5 for Too High", 1, true), "level step: " .. current.left.text)
current.scripts.OnEnter(current)
tip = table.concat(TIPLINES, "\n")
assert(tip:find("Needs first: level 5", 1, true), "tooltip names it: " .. tip)
print("8/9 ok")

-- 10a. Completed quests come from the game's full list too (and QUEST_TURNED_IN tops it up).
LevelGuidePrereqs = { Locked = { all = { 9001 } }, ["Next"] = { all = { 9002 } } }
LevelGuideRoutes.chains.NightElf = { { zone = "Testzone", min = 1, max = 10, steps = {
    A("Locked", "Giver", 50, 50, 1), A("Next", "Giver D", 55, 50, 1) } } }
FLAGGED = {}
update()
assert(not all():find("Locked", 1, true), "blocked without the list")
C_QuestLog.GetAllCompletedQuestIDs = function() return { 9001 } end
update()
assert(all():find("Pick up:|r Locked", 1, true), "the full completed list opens it: " .. all())
assert(not all():find("Next", 1, true), "Next still blocked")
fire("QUEST_TURNED_IN", 9002)
update()
assert(all():find("Pick up:|r Next", 1, true), "turned in this session counts at once: " .. all())

-- 10. Nothing known: an empty list.
LevelGuideRoutes.chains.NightElf = {}
update()
local empty = LevelGuide_UpcomingStops()
assert(type(empty) == "table", "always a table")
assert(#handled == 0, "clean: " .. tostring(handled[1]))
print("ALL TESTS PASSED")
