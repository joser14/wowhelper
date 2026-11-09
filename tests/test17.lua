IsShiftKeyDown = function() return true end -- skips need Shift now
-- Under-leveled handling (FindRoute moves on / LevelStep). ADDON_PATH is the LevelGuide folder.
local base = ADDON_PATH
local frames, handled = {}, {}
FONTS = {}
local function newRegion(kind)
    local r = { kind = kind, shown = true, scripts = {}, text = "", rotation = 0 }
    function r:SetText(t) self.text = t end
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
        if k == "step" or k == "tex" then return nil end
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
GameTooltip = newRegion("Frame")
issecretvalue = function() return false end
geterrorhandler = function() return function(e) handled[#handled + 1] = tostring(e) end end
local level = 1
UnitLevel = function() return level end
UnitXP = function() return 0 end
UnitXPMax = function() return 400 end
UnitName = function() return "Juan" end
GetRealmName = function() return "R" end
local race = "NightElf"
UnitRace = function() return "Night Elf", race end
local zone = "Teldrassil"
local px, py = 0.587, 0.443
local function vec(x, y) return { GetXY = function() return x, y end } end
CreateVector2D = vec
C_Map = {
    GetBestMapForUnit = function() return 101 end,
    GetMapInfo = function(id)
        if id == 101 then return { name = "Shadowthread Cave", mapType = 5, parentMapID = 57 } end
        if id == 57 then return { name = zone, mapType = 3, parentMapID = 12 } end
        if id == 12 then return { name = "Kalimdor", mapType = 2, parentMapID = 0 } end
    end,
    GetPlayerMapPosition = function(id) if id == 57 then return vec(px, py) end end,
    GetWorldPosFromMapPos = function(_, p) local x, y = p:GetXY(); return 0, vec(x * 3000, y * 3000) end,
}
local waypoint
C_Map.SetUserWaypoint = function(p) waypoint = p end
UiMapPoint = { CreateFromCoordinates = function(m, x, y) return { m = m, x = x, y = y } end }
local superTracked
C_SuperTrack = { SetSuperTrackedQuestID = function(id) superTracked = id end, SetSuperTrackedUserWaypoint = function() end }
GetPlayerFacing = function() return 0 end
local log = {}
C_QuestLog = {
    GetNumQuestLogEntries = function() return #log end,
    GetInfo = function(i) return log[i] end,
    IsComplete = function(id) for _, q in ipairs(log) do if q.questID == id then return q.ready end end end,
    ReadyForTurnIn = function() return false end,
    GetQuestObjectives = function() return {} end,
    GetTitleForQuestID = function() return nil end,
    IsQuestTrivial = function() return false end,
    GetQuestsOnMap = function() return QUESTS_ON_MAP or {} end,
    IsQuestFlaggedCompleted = function(id) return FLAGGED and FLAGGED[id] or false end,
}

assert(loadfile(base .. "/Routes.lua"))("LevelGuide", {})
assert(loadfile(base .. "/LevelGuide.lua"))("LevelGuide", {})
local events = frames[1]
events.scripts.OnEvent(events, "PLAYER_LOGIN")
local frame = LevelGuideFrame
local function update(t) frame.scripts.OnUpdate(frame, t or 2.1) end
update()
assert(#handled == 0, "clean: " .. tostring(handled[1]))
local buttons = {}
for _, f in ipairs(frames) do if f.kind == "Button" and rawget(f, "left") then buttons[#buttons + 1] = f end end
local current = buttons[1]
local function all() local t = { current.left.text }; for i = 2, 4 do if buttons[i].shown then t[#t + 1] = buttons[i].left.text end end; return table.concat(t, "\n") end
local function header() for _, f in ipairs(FONTS) do if f.text:find("Route:", 1, true) or f.text:find("Guide", 1, true) then return f.text end end end
local function findFont(pattern) for _, f in ipairs(FONTS) do if f.text:find(pattern, 1, true) then return f.text end end end
local function A(q, npc, x, y, lvl, part) return { t = "accept", q = q, npc = npc, x = x, y = y, lvl = lvl, part = part } end
local function T(q, npc, x, y, lvl, part) return { t = "turnin", q = q, npc = npc, x = x, y = y, lvl = lvl, part = part } end
local ASH = { zone = "Ashenvale", min = 20, max = 30, steps = {
    A("Q1", "Giver One", 50, 50, 20), T("Q1", "Giver One", 50, 50, 20),
    A("Q2", "Giver Two", 60, 60, 25), T("Q2", "Giver Two", 60, 60, 25),
} }
local WET = { zone = "Wetlands", min = 20, max = 30, steps = {
    A("W1", "Wet Giver", 10, 60, 21), T("W1", "Wet Giver", 10, 60, 21),
} }
LevelGuideRoutes.chains.NightElf = { ASH, WET }
LevelGuideQuestIDs, LevelGuidePrereqs = nil, nil
local char = LevelGuideDB.characters["Juan-R"]
log, QUESTS_ON_MAP, FLAGGED = {}, {}, {}
level, zone = 21, "Ashenvale"
char.done["Q1"] = 1

-- 1. Ashenvale has only Q2 left (needs 24): Wetlands has W1 for you now, and the guide says why.
update(); update()
print(all())
assert(header():find("Route: Wetlands", 1, true), "moved on: " .. tostring(header()))
assert(current.left.text:find("Go to", 1, true) and current.left.text:find("Wetlands", 1, true), "travel: " .. current.left.text)
assert(findFont("Ashenvale's next quests need level 24, you're 21. Wetlands has quests for you now"), "why")
assert(#handled == 0, "clean 1: " .. tostring(handled[1]))

-- 2. Wetlands done too: nothing anywhere at 21, so Ashenvale says plainly what it waits for.
char.done["W1"] = 1
update(); update()
print(all())
assert(header():find("Route: Ashenvale", 1, true), "back: " .. tostring(header()))
assert(current.left.text:find("Reach level:", 1, true) and current.left.text:find("24 for Q2", 1, true), "level step: " .. current.left.text)
assert(findFont("Needs level 24, you're 21."), "needs text")
assert(findFont("Then pick it up from Giver Two."), "giver text")
assert(findFont("Shadowfang Keep suits 22-30"), "plan dungeon note")
-- Left-click puts the waypoint on the giver.
current.scripts.OnClick(current, "LeftButton")
assert(waypoint and math.abs(waypoint.x - 0.6) < 1e-9 and waypoint.y == 0.6 and waypoint.m == 57, "waypoint on giver")

-- 3. The game's own minimum level is higher than the route's: that one is quoted.
LevelGuidePrereqs = { Q2 = { level = 26 } }
update(); update()
assert(current.left.text:find("26 for Q2", 1, true), "prereq level: " .. current.left.text)
assert(findFont("Needs level 26, you're 21."), "needs 26")

-- 4. With a quest in your log here, it comes first and the level line follows it.
log = { { questID = 777, title = "Some Log Quest" } }
QUESTS_ON_MAP = { { questID = 777, x = 0.4, y = 0.4 } }
update(); update()
print(all())
assert(current.left.text:find("Some Log Quest", 1, true), "log quest first: " .. current.left.text)
assert(buttons[2].shown and buttons[2].left.text:find("Reach level:", 1, true), "level second: " .. buttons[2].left.text)
log, QUESTS_ON_MAP = {}, {}

-- 5. Not in the route's zone: the travel line, then the level line.
zone = "Darkshore"
update(); update()
print(all())
assert(all():find("Go to:|r Ashenvale", 1, true), "travel to ashenvale")
assert(all():find("26 for Q2", 1, true), "level line away")

-- 6. At the level, the pick-up shows and the level line is gone.
zone, level = "Ashenvale", 26
LevelGuidePrereqs = nil
update(); update()
print(all())
assert(current.left.text:find("Pick up:", 1, true) and current.left.text:find("Q2", 1, true), "pickup: " .. current.left.text)
assert(not all():find("Reach level", 1, true), "no level line")

-- 7. A pick-up blocked by an unfinished earlier quest (not level) gives no level line.
level = 21
LevelGuidePrereqs = { Q2 = { all = { 424242 } } }
update(); update()
assert(not all():find("Reach level", 1, true), "prereq quest is not a level problem")
assert(#handled == 0, "clean: " .. tostring(handled[1]))
print("ALL TESTS PASSED")
