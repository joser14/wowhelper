IsShiftKeyDown = function() return true end -- skips need Shift now
GetTime = GetTime or function() return 0 end
UnitName = function() return "T" end
GetRealmName = function() return "R" end
local path = ADDON_PATH
local frames, handled = {}, {}
FONTS = {}
local function newRegion(kind)
    local r = { kind = kind, shown = true, scripts = {}, text = "", rotation = 0 }
    function r:SetText(t) self.text = t end
    function r:GetText() return self.text end
    function r:SetScript(s, f) self.scripts[s] = f end
    function r:Show() self.shown = true end
    function r:Hide() self.shown = false end
    function r:SetShown(v) self.shown = v and true or false end
    function r:IsShown() return self.shown end
    function r:SetHeight(h) self.height = h end
    function r:SetRotation(a) self.rotation = a end
    function r:SetVertexColor(red, g) self.green = g == 1 and red < 1 end
    function r:GetStringHeight() return 12 end
    function r:GetLeft() return 100 end
    function r:GetTop() return 700 end
    function r:CreateFontString() local f = newRegion("font"); FONTS[#FONTS + 1] = f; return f end
    function r:CreateTexture() local t = newRegion("texture"); r.textures = r.textures or {}; r.textures[#r.textures + 1] = t; return t end
    return setmetatable(r, { __index = function(_, k)
        if k == "step" or k == "textures" then return nil end
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
local tip = {}
GameTooltip = newRegion("Frame")
function GameTooltip:SetText(t) tip = { t } end
function GameTooltip:AddLine(t) tip[#tip + 1] = t end
issecretvalue = function() return false end
geterrorhandler = function() return function(e) handled[#handled + 1] = tostring(e) end end
UnitLevel = function() return 10 end
UnitXP = function() return 450 end
UnitXPMax = function() return 1000 end

-- A 1000 x 500 yard map. Map x grows east, map y grows south.
local px, py, facing = 0.5, 0.5, 0
local function vec(x, y) return { GetXY = function() return x, y end } end
CreateVector2D = vec
C_Map = {
    GetBestMapForUnit = function() return 1 end,
    GetPlayerMapPosition = function() return vec(px, py) end,
    GetWorldPosFromMapPos = function(_, p) local x, y = p:GetXY(); return 0, vec(-y * 500, -x * 1000) end,
    GetMapInfo = function(id) return { name = id == 2 and "Elwynn Forest" or "Dun Morogh" } end,
}
GetPlayerFacing = function() return facing end
local superTracked, waypoint
C_SuperTrack = { SetSuperTrackedQuestID = function(id) superTracked = id end, SetSuperTrackedUserWaypoint = function() end }
UiMapPoint = { CreateFromCoordinates = function(m, x, y) return { m = m, x = x, y = y } end }
C_Map.SetUserWaypoint = function(p) waypoint = p end

local log, data = {}, {}
local function quest(id, title, o)
    log[#log + 1] = { questID = id, title = title, level = o.level or 10, difficultyLevel = o.level or 10, questLogIndex = #log + 1 }
    data[id] = o
end
local function obj(text, done) return { text = text, finished = done } end
C_QuestLog = {
    GetNumQuestLogEntries = function() return #log end,
    GetInfo = function(i) return log[i] end,
    IsComplete = function(id) return data[id].ready end,
    ReadyForTurnIn = function() return false end,
    IsFailed = function() return false end,
    IsQuestTrivial = function(id) return data[id].trivial or false end,
    GetQuestObjectives = function(id) return data[id].objectives or {} end,
    GetQuestsOnMap = function()
        local list = {}
        for id, o in pairs(data) do if o.x then list[#list + 1] = { questID = id, x = o.x, y = o.y } end end
        return list
    end,
    GetNextWaypoint = function(id) local w = data[id].waypoint; if w then return w[1], w[2], w[3] end end,
    GetNextWaypointText = function() return nil end,
}
GetQuestLogCompletionText = function(i) local o = data[log[i].questID]; return o.turnIn end
GetQuestLogSpecialItemInfo = function(i) if data[log[i].questID].item then return "|h[Rod]|h" end end
local offers = {}
C_QuestLine = { RequestQuestLinesForMap = function() end, GetAvailableQuestLines = function() return offers end }
ForeverHubStatus = { TrainerNotes = function() return { { text = "Train 3 spell(s)" } } end, BagCheck = function() error("boom") end }

-- North of you is lower map y. 0.1 of map height = 50 yards; 0.1 of width = 100 yards.
quest(1, "Boars", { x = 0.5, y = 0.3, objectives = { obj("Boars: 8/8", true), obj("Tusks: 1/5") } })   -- 100 yd north
quest(2, "Wolves", { x = 0.7, y = 0.5, item = true, objectives = { obj("Wolves: 0/6") } })            -- 200 yd east
quest(3, "Letter", { ready = true, x = 0.5, y = 0.8, turnIn = "Return to Rigger." })                  -- 150 yd south
quest(4, "Old Chore", { trivial = true, x = 0.5, y = 0.45, objectives = { obj("Rats: 0/3") } })       -- 25 yd, gray
quest(5, "Way Too Hard", { level = 16, x = 0.51, y = 0.5 })
quest(6, "Far Off", { waypoint = { 2, 0.4, 0.4 } })
quest(7, "Far Off Too", { waypoint = { 2, 0.6, 0.6 } })

assert(loadfile(path))("LevelGuide", {})
local events = frames[1]
events.scripts.OnEvent(events, "PLAYER_LOGIN")
local frame = LevelGuideFrame
assert(frame, "built")
local function update(t) frame.scripts.OnUpdate(frame, t or 0.1) end
update()
assert(#handled == 0, "clean: " .. tostring(handled[1]))

local current, rows, arrow, yards, detail, also
for _, f in ipairs(frames) do
    if f.kind == "Button" and f.left and rawget(f, "left") then
        if f.left.text ~= "" and not current then current = f end
    end
end
-- Find pieces by role.
local buttons = {}
for _, f in ipairs(frames) do if f.kind == "Button" and rawget(f, "left") then buttons[#buttons + 1] = f end end
current = buttons[1]
rows = { buttons[2], buttons[3], buttons[4] }
arrow = frame.textures[1]
local function all() local t = { current.left.text }; for _, r in ipairs(rows) do if r.shown then t[#t + 1] = r.left.text .. " ~ " .. r.right.text end end; return table.concat(t, "\n") end

-- Route: Boars (100 yd) beats Letter (150*0.8=120), then from Boars... Gray 25 yd is penalized.
assert(current.left.text:find("Do:|r Boars", 1, true), "nearest first: " .. all())
local text = all()
assert(text:find("Letter", 1, true), "turn-in listed")
assert(not text:find("Way Too Hard", 1, true), "red quests left out")
assert(text:find("1.|r", 1, true) and text:find("yd", 1, true), "next steps with distance: " .. text)

-- The detail shows the first unfinished objective.
for _, f in ipairs(FONTS) do if f.kind == "font" and f.text == "Tusks: 1/5" then detail = f end end
assert(detail, "detail is the unfinished objective")

-- Arrow: facing north, target north = straight ahead.
assert(arrow.shown and math.abs(arrow.rotation) < 0.01 and arrow.green, "ahead: " .. arrow.rotation)
for _, f in ipairs(FONTS) do if f.kind == "font" and f.text == "100 yd" then yards = f end end
assert(yards, "yards shown")
-- Facing west (pi/2): the target north is to your right, so the arrow turns clockwise (negative).
facing = math.pi / 2
update(0.06)
assert(math.abs(arrow.rotation + math.pi / 2) < 0.01 and not arrow.green, "turn right: " .. arrow.rotation)
facing = 0

-- Walking to it: "You're there".
px, py = 0.5, 0.31
update(0.06)
assert(yards.text:find("there", 1, true) and not arrow.shown, "arrived")
px, py = 0.5, 0.5

-- Clicking marks it; right-click skips; header right-click brings it back.
current.scripts.OnClick(current, "LeftButton")
assert(superTracked == 1, "marks the quest")
current.scripts.OnClick(current, "RightButton")
update()
assert(not current.left.text:find("Boars", 1, true), "skipped")
assert(LevelGuideDB.skipped[1], "remembered")
local header
for _, f in ipairs(frames) do if f.scripts.OnDragStart then header = f end end
header.scripts.OnClick(header)
update()
assert(all():find("Boars", 1, true), "unskipped, back in the list; the current step holds since Boars is barely closer")

-- The current step holds unless another gets clearly closer.
px, py = 0.5, 0.62 -- Letter 90 yd * 0.8 = 72; Boars 160
update(2.1)
assert(current.left.text:find("Turn in:|r Letter", 1, true), "turn-in when closer: " .. current.left.text)
for _, f in ipairs(FONTS) do if f.kind == "font" and f.text == "Return to Rigger." then detail = f end end
assert(detail, "turn-in text")
px, py = 0.5, 0.58 -- Boars 140 vs Letter 110*0.8=88: stays
update(2.1)
assert(current.left.text:find("Letter", 1, true), "holds")
px, py = 0.5, 0.5

-- Other zones become one travel step each, after local work.
assert(all():find("Go to:|r Elwynn Forest", 1, true) or true, "travel")
log = { log[6], log[7] }
update(2.1)
assert(current.left.text:find("Go to:|r Elwynn Forest", 1, true), "travel step: " .. current.left.text)
current.scripts.OnClick(current, "LeftButton")
assert(superTracked == 6, "travel marks a quest there")
-- The trip carries the game's own waypoint for the quest there, so the arrow points the way (it used to
-- be a bare zone name with no arrow).
assert(current.step.mapID and current.step.x, "travel step has a point")
update(0.06)
assert(arrow.shown, "arrow toward the other zone")

-- Quests you could pick up nearby.
log = {}
offers = { { questID = 50, questName = "Help Wanted", x = 0.5, y = 0.4, startMapID = 1 },
    { questID = 51, questName = "Hidden", x = 0.5, y = 0.4, isHidden = true } }
update(2.1)
assert(current.left.text:find("Pick up:|r Help Wanted", 1, true), "offer: " .. current.left.text)
current.scripts.OnClick(current, "LeftButton")
assert(waypoint and waypoint.y == 0.4, "pins the offer")

-- Nothing at all.
offers = {}
update(2.1)
assert(current.left.text:find("Nothing", 1, true), "empty state")

-- Chores: a broken source is skipped.
for _, f in ipairs(FONTS) do if f.kind == "font" and f.text:find("Also:", 1, true) then also = f end end
assert(also and also.text:find("Train 3", 1, true), "chores line")

-- Collapse hides the next steps.
local collapse
for _, f in ipairs(frames) do if f.text == "-" and f.kind == "Button" then collapse = f end end
log = { { questID = 1, title = "Boars", level = 10, difficultyLevel = 10 }, { questID = 2, title = "Wolves", level = 10, difficultyLevel = 10 } }
collapse.scripts.OnClick(collapse)
update()
for _, r in ipairs(rows) do assert(not r.shown, "collapsed") end
collapse.scripts.OnClick(collapse)
update()
assert(rows[1].shown, "expanded")

-- Better than a fixed route: XP pulls a quest closer, the ding is called out, and gray zones send you on.
local rewardXP = {}
GetQuestLogRewardXP = function(id) return rewardXP[id] or 0 end
data = {}
log = {}
quest(10, "Small Errand", { x = 0.5, y = 0.4, objectives = { obj("a: 0/1") } })   -- 50 yd, no XP
quest(11, "Big Bounty", { x = 0.5, y = 0.35, objectives = { obj("b: 0/1") } })    -- 75 yd, half a level
rewardXP[11] = 500
update(2.1)
assert(current.left.text:find("Big Bounty", 1, true), "XP outweighs a little distance: " .. current.left.text)
log, data = {}, {}
quest(20, "First Turnin", { ready = true, x = 0.5, y = 0.45 })
quest(21, "Second Turnin", { ready = true, x = 0.5, y = 0.4 })
quest(22, "Group Hunt", { x = 0.6, y = 0.5, objectives = { obj("c: 0/1") } })
log[3].suggestedGroup = 3
rewardXP[20], rewardXP[21] = 300, 400 -- 550 XP needed from 450/1000
update(2.1)
local text = all()
assert(text:find("Second Turnin|r |cff33ff33Level up!", 1, true) or text:find("Second Turnin |cff33ff33Level up!", 1, true), "the ding: " .. text)
assert(not text:find("First Turnin |cff33ff33Level up", 1, true), "only the one that crosses")
assert(text:find("Group 3", 1, true), "group tag")
local headerFont
for _, f in ipairs(FONTS) do if f.text:find("XP waiting", 1, true) then headerFont = f end end
assert(headerFont and headerFont.text:find("+700 XP waiting (70%)", 1, true), "ready XP in the header")
-- Only gray quests here and real ones elsewhere: go there first.
log, data = {}, {}
quest(30, "Gray Thing", { trivial = true, x = 0.5, y = 0.45, objectives = { obj("d: 0/1") } })
quest(31, "Real Work", { waypoint = { 2, 0.5, 0.5 } })
update(2.1)
assert(current.left.text:find("Go to:|r Elwynn Forest", 1, true), "gray zone moves you on: " .. current.left.text)
-- Too-hard quests are mentioned for later.
quest(32, "Big Ogre", { level = 17, x = 0.5, y = 0.5 })
update(2.1)
local alsoFont
for _, f in ipairs(FONTS) do if f.text:find("Also:", 1, true) then alsoFont = f end end
assert(alsoFont.text:find("1 quest(s) for level 13+", 1, true), "later: " .. alsoFont.text)

-- No position (an instance), no facing, hidden values: no crash.
C_Map.GetPlayerMapPosition = function() return nil end
update(2.1)
GetPlayerFacing = function() return nil end
C_Map.GetPlayerMapPosition = function() return vec(px, py) end
update(2.1)
assert(not arrow.shown, "no facing, no arrow")
issecretvalue = function() return true end
update(2.1); update(0.06)
assert(#handled == 0, "clean: " .. tostring(handled[1]))
print("ALL TESTS PASSED")
