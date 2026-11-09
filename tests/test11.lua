local path = ADDON_PATH
local frames, toasts, handled, blocked = {}, {}, {}, {}
local combat, tick = false, nil
local mouseOver = false
local function newRegion(kind, template)
    local r = { kind = kind, template = template, shown = true, scripts = {}, hooks = {}, attrs = {}, text = "" }
    function r:SetText(t) self.text = t end
    function r:GetText() return self.text end
    function r:SetScript(s, f) self.scripts[s] = f end
    function r:HookScript(s, f) self.hooks[s] = f end
    function r:Show() self.shown = true end
    function r:Hide() self.shown = false end
    function r:SetShown(v) self.shown = v and true or false end
    function r:IsShown() return self.shown end
    function r:SetAttribute(k, v)
        if combat then blocked[#blocked + 1] = "SetAttribute" end
        self.attrs[k] = v
    end
    function r:ClearAllPoints() if combat and self.watchCombat then blocked[#blocked + 1] = "ClearAllPoints" end end
    function r:SetPoint(...) if combat and self.watchCombat then blocked[#blocked + 1] = "SetPoint" end self.point = { ... } end
    function r:SetHeight(h) if combat and self.watchCombat then blocked[#blocked + 1] = "SetHeight" end self.height = h end
    function r:SetWidth(w) self.width = w end
    function r:IsMouseOver() return mouseOver end
    function r:GetLeft() return 100 end
    function r:GetTop() return 500 end
    function r:CreateFontString() return newRegion("font") end
    function r:CreateTexture() return newRegion("texture") end
    return setmetatable(r, { __index = function(_, k)
        if k == "quest" or k == "section" or k == "objectiveIndex" or k == "offer" or k == "link" or k == "watchCombat" then return nil end
        return function() end
    end })
end
CreateFrame = function(kind, name, parent, template)
    local f = newRegion(kind, template)
    f.watchCombat = kind ~= "Frame" or name == "QuestTrackerPanel"
    if name == "QuestTrackerPanel" then f.isPanel = true end
    frames[#frames + 1] = f
    if name then _G[name] = f end
    return f
end
UIParent = newRegion("Frame")
GameTooltip = newRegion("Frame")
local tipLines = {}
function GameTooltip:AddLine(t) tipLines[#tipLines + 1] = t end
function GameTooltip:SetText(t) tipLines = { t } end
ObjectiveTrackerFrame = newRegion("Frame")
-- Blizzard's tracker is only made clear (SetAlpha); Hide/Show from addon code would taint it.
ObjectiveTrackerFrame.alpha = 1
function ObjectiveTrackerFrame:SetAlpha(a) self.alpha = a end
function ObjectiveTrackerFrame:Show() error("ObjectiveTrackerFrame:Show called") end
function ObjectiveTrackerFrame:Hide() error("ObjectiveTrackerFrame:Hide called") end
issecretvalue = function() return false end
InCombatLockdown = function() return combat end
geterrorhandler = function() return function(e) handled[#handled + 1] = tostring(e) end end
ForeverHub_Receive = function(_, t) toasts[#toasts + 1] = t end
C_Timer = { NewTicker = function(_, fn) tick = fn end }
local serverTime = 100000
GetServerTime = function() return serverTime end
UnitLevel = function() return 10 end
UnitXPMax = function() return 1000 end
local zone = "Dun Morogh"
GetRealZoneText = function() return zone end

local log, data, watches = {}, {}, {}
local function header(title) log[#log + 1] = { isHeader = true, title = title } end
local function quest(id, title, level, o)
    o = o or {}
    log[#log + 1] = { questID = id, title = title, level = level, difficultyLevel = level, suggestedGroup = o.group or 0, questLogIndex = #log + 1 }
    data[id] = o
end
C_QuestLog = {
    GetNumQuestLogEntries = function() return #log, 7 end,
    GetMaxNumQuestsCanAccept = function() return 25 end,
    GetInfo = function(i) return log[i] end,
    IsComplete = function(id) return data[id].ready end,
    ReadyForTurnIn = function() return false end,
    IsFailed = function() return false end,
    IsQuestTrivial = function(id) return data[id].trivial or false end,
    GetQuestObjectives = function(id) return data[id].objectives or {} end,
    IsOnMap = function(id) return data[id].onMap or false, false end,
    GetDistanceSqToQuest = function(id) local d = data[id].distance; if d then return d * d, true end end,
    GetNumQuestWatches = function() return #watches end,
    GetQuestIDForQuestWatchIndex = function(i) return watches[i] end,
    GetLogIndexForQuestID = function() return nil end,
}
local focus = 0
C_SuperTrack = { GetSuperTrackedQuestID = function() return focus end, SetSuperTrackedQuestID = function(id) focus = id end }
GetQuestLogRewardXP = function(id) return data[id].xp or 0 end
GetQuestLogRewardMoney = function(id) return data[id].money or 0 end
HaveQuestRewardData = function() return true end
GetQuestLogSpecialItemInfo = function(i)
    local e = log[i]
    local o = e and data[e.questID]
    if o and o.item then return "|Hitem:" .. o.item .. ":|h[Rod]|h", 123, 1, false end
end
local opened
QuestMapFrame_OpenToQuestDetails = function(id) opened = id end

local function obj(text, have, need) return { text = text, numFulfilled = have, numRequired = need, finished = have >= need } end
header("Dun Morogh")
quest(1, "Far Bears", 10, { onMap = true, distance = 500, xp = 300, objectives = { obj("Bears: 2/8", 2, 8) } })
quest(2, "Near Boars", 11, { onMap = true, distance = 50, xp = 250, item = 77, objectives = { obj("Boars: 0/5", 0, 5), obj("Tusks: 3/3", 3, 3) } })
quest(3, "Old Errand", 3, { onMap = true, distance = 10, trivial = true, objectives = { obj("Wolves: 1/2", 1, 2) } })
quest(4, "Done Deal", 10, { ready = true, onMap = true, xp = 400, money = 12345 })
header("Elwynn Forest")
quest(5, "Far Away", 9, { xp = 200, group = 3, objectives = { obj("Letter: 0/1", 0, 1) } })
header("Mage")
quest(6, "Class Trip", 10, { onMap = false, ready = true, xp = 100 })

assert(loadfile(path))("QuestTracker", {})
local events = frames[1]
events.scripts.OnEvent(events, "PLAYER_LOGIN")
assert(#handled == 0, "login clean: " .. tostring(handled[1]))

local function shownRows()
    local out = {}
    for _, f in ipairs(frames) do
        if f.kind == "Button" and f.left and rawget(f, "left") and f.shown then out[#out + 1] = f end
    end
    table.sort(out, function(a, b) return a.point[5] > b.point[5] end)
    return out
end
local function texts()
    local t = {}
    for _, r in ipairs(shownRows()) do t[#t + 1] = r.left.text .. " ~ " .. r.right.text end
    return table.concat(t, "\n")
end
local function find(text)
    for _, r in ipairs(shownRows()) do if r.left.text:find(text, 1, true) then return r end end
end
local function before(a, b)
    local s = texts()
    return s:find(a, 1, true) < s:find(b, 1, true)
end
assert(ObjectiveTrackerFrame.alpha == 0, "Blizzard's tracker goes clear")
assert(QuestTrackerPanel.shown, "panel shows by itself")

-- Order: turn-ins, then your zone nearest first with gray last, others folded.
assert(texts():find("Ready to turn in (2)", 1, true), "ready section: " .. texts())
assert(texts():find("+50% of a level", 1, true), "turn-ins show level share: " .. texts())
assert(before("Done Deal", "Near Boars"), "turn-ins on top")
assert(before("Near Boars", "Far Bears"), "nearest first")
assert(before("Far Bears", "Old Errand"), "gray last even if closest")
assert(texts():find("+ Elwynn Forest (1)", 1, true), "other zones fold: " .. texts())
assert(not texts():find("Far Away", 1, true), "folded quest hidden")
assert(texts():find("250 xp", 1, true), "xp on row")
assert(texts():find("Boars: 0/5", 1, true), "objectives")
assert(find("Tusks").left.text:find("33ff33", 1, true), "finished objective green")
assert(find("Boars: 0/5").left.text:find("999999", 1, true), "untouched objective dim")
assert(find("[11] Near Boars").left.text:find("ffd100", 1, true), "level+1 yellow")
assert(find("[3] Old Errand").left.text:find("999999", 1, true), "gray quest")

-- Quest item button you click yourself.
local item
for _, f in ipairs(frames) do if f.template == "SecureActionButtonTemplate" then item = f end end
assert(item and item.shown and item.attrs.type == "item" and item.attrs.item == "item:77", "item button")

-- Clicking.
find("Near Boars").scripts.OnClick(find("Near Boars"), "LeftButton")
assert(focus == 2, "left click focuses")
tick()
assert(find("Near Boars").left.text:find("> ", 1, true), "focus shown")
find("Near Boars").scripts.OnClick(find("Near Boars"), "LeftButton")
assert(focus == 0, "second click clears")
find("Far Bears").scripts.OnClick(find("Far Bears"), "RightButton")
assert(opened == 1, "right click opens")

-- Unfold, and remember.
local elwynn = find("Elwynn Forest")
GameTooltip.shown = false
elwynn.scripts.OnEnter(elwynn)
assert(table.concat(tipLines, "\n"):find("Far Away", 1, true), "folded zone previews on hover")
elwynn.scripts.OnClick(elwynn, "LeftButton")
tick()
assert(texts():find("Far Away", 1, true) and QuestTrackerDB.zones["Elwynn Forest"] == true, "unfold saved")
assert(find("Far Away").right.text:find("G3", 1, true), "group tag")
find("Far Away").scripts.OnEnter(find("Far Away"))
assert(table.concat(tipLines, "\n"):find("20% of a level", 1, true), "tooltip xp share")

-- Moving: reorders, but not under the mouse.
data[1].distance = 5
mouseOver = true
for _ = 1, 4 do tick() end
assert(before("Near Boars", "Far Bears"), "no jump under the mouse")
mouseOver = false
for _ = 1, 4 do tick() end
assert(before("Far Bears", "Near Boars"), "follows you")
data[1].distance = 500

-- Zone change: your new zone leads and opens.
QuestTrackerDB.zones["Elwynn Forest"] = nil
zone = "Elwynn Forest"
data[1].onMap, data[2].onMap, data[3].onMap = false, false, false
events.scripts.OnEvent(events, "ZONE_CHANGED_NEW_AREA")
tick()
assert(before("Elwynn Forest", "Dun Morogh") and texts():find("Far Away", 1, true) and not texts():find("Near Boars", 1, true), "zone change: " .. texts())
zone = "Dun Morogh"
data[1].onMap, data[2].onMap, data[3].onMap = true, true, true
events.scripts.OnEvent(events, "ZONE_CHANGED_NEW_AREA")
tick()

-- Combat: counts update, nothing moves.
combat = true
data[1].objectives = { obj("Bears: 5/8", 5, 8) }
events.scripts.OnEvent(events, "QUEST_LOG_UPDATE")
tick()
assert(#blocked == 0, "nothing blocked in combat: " .. table.concat(blocked, ","))
assert(find("Bears: 5/8"), "count updates in combat")
ObjectiveTrackerFrame.hooks.OnShow(ObjectiveTrackerFrame)
assert(#blocked == 0, "tracker show in combat")
-- Drag and collapse are refused in combat.
local dragger
for _, f in ipairs(frames) do if f.scripts.OnDragStart then dragger = f end end
dragger.scripts.OnDragStart(dragger)
combat = false
events.scripts.OnEvent(events, "PLAYER_REGEN_ENABLED")
tick()
assert(#handled == 0, "combat clean: " .. tostring(handled[1]))

-- A quest finishing pops up once and moves to the top.
toasts = {}
data[1].ready = true
events.scripts.OnEvent(events, "QUEST_LOG_UPDATE")
tick(); events.scripts.OnEvent(events, "QUEST_LOG_UPDATE"); tick()
assert(#toasts == 1 and toasts[1]:find("Far Bears", 1, true), "ready pop-up once: " .. tostring(toasts[1]))
assert(before("Far Bears", "Near Boars"), "moves up")
data[1].ready = false
events.scripts.OnEvent(events, "QUEST_LOG_UPDATE"); tick()

-- NEW tag fades after an hour.
events.scripts.OnEvent(events, "QUEST_ACCEPTED", 2)
tick()
assert(find("Near Boars").right.text:find("NEW", 1, true), "new tag")
serverTime = serverTime + 3700
events.scripts.OnEvent(events, "QUEST_LOG_UPDATE"); tick()
assert(not find("Near Boars").right.text:find("NEW", 1, true), "new fades")

-- Collapse.
local collapse
for _, f in ipairs(frames) do if f.text == "-" and f.kind == "Button" then collapse = f end end
collapse.scripts.OnClick(collapse); tick()
assert(#shownRows() == 0 and not item.shown and QuestTrackerDB.collapsed == true, "collapse hides rows")
assert(QuestTrackerPanel.height == 26, "collapses small: " .. tostring(QuestTrackerPanel.height))
collapse.scripts.OnClick(collapse); tick()
assert(#shownRows() > 0 and item.shown, "expand")

-- Turn-in rows say where to go, in Blizzard's order.
GetQuestLogCompletionText = function(i) if log[i] and log[i].questID == 4 then return "Return to Rigger." end end
C_QuestLog.GetNextWaypointText = function(id) if id == 6 then return "Go to Ironforge" end end
events.scripts.OnEvent(events, "QUEST_LOG_UPDATE"); tick()
assert(find("Return to Rigger."), "completion text: " .. texts())
assert(find("Go to Ironforge"), "falls back to the waypoint: " .. texts())
assert(before("Done Deal", "Return to Rigger."), "under its quest")

-- A quest that finishes by clicking it finishes from this tracker too.
local completed
ShowQuestComplete = function(id) completed = id end
log[#log + 1] = { questID = 7, title = "Auto Done", level = 10, difficultyLevel = 10, suggestedGroup = 0, questLogIndex = #log + 1, isAutoComplete = true }
data[7] = { ready = true, onMap = true }
events.scripts.OnEvent(events, "QUEST_LOG_UPDATE"); tick()
assert(find("Click to complete"), "says so: " .. texts())
find("Auto Done").scripts.OnClick(find("Auto Done"), "LeftButton")
assert(completed == 7, "click completes")
assert(focus == 0, "and doesn't mark it")
find("Done Deal").scripts.OnClick(find("Done Deal"), "LeftButton")
assert(completed == 7 and focus == 4, "a normal turn-in still marks")
find("Done Deal").scripts.OnClick(find("Done Deal"), "LeftButton")
log[#log] = nil
data[7] = nil
events.scripts.OnEvent(events, "QUEST_LOG_UPDATE"); tick()

-- A drag still going when combat starts ends just before the lock.
local moved, stopped = false, false
QuestTrackerPanel.StartMoving = function() moved = true end
QuestTrackerPanel.StopMovingOrSizing = function() stopped = true end
dragger.scripts.OnDragStart(dragger)
assert(moved, "drag starts")
events.scripts.OnEvent(events, "PLAYER_REGEN_DISABLED")
assert(stopped and QuestTrackerDB.position, "drag ends before combat")
combat = true
stopped = false
blocked = {}
dragger.scripts.OnDragStop(dragger)
assert(not stopped and #blocked == 0, "letting go in combat touches nothing: " .. table.concat(blocked, ","))
combat = false
events.scripts.OnEvent(events, "PLAYER_REGEN_ENABLED"); tick()
QuestTrackerPanel.StartMoving = function() end
QuestTrackerPanel.StopMovingOrSizing = function() end

-- Bring Blizzard's back.
dragger.scripts.OnClick(dragger)
assert(ObjectiveTrackerFrame.alpha == 1 and QuestTrackerDB.keepBlizzard, "right-click restores Blizzard's")
ObjectiveTrackerFrame.hooks.OnShow(ObjectiveTrackerFrame)
assert(ObjectiveTrackerFrame.alpha == 1, "stays when asked")
dragger.scripts.OnClick(dragger)
assert(ObjectiveTrackerFrame.alpha == 0, "clear again")

-- A reward ItemAdvisor would equip shows on the quest, and survives until gear changes.
local asks = 0
ItemAdvisor_IsUpgrade = function(link) asks = asks + 1; return link == "LINK77", "Upgrade for mage" end
GetNumQuestLogChoices = function(id) return id == 2 and 2 or 0 end
GetNumQuestLogRewards = function() return 0 end
GetQuestLogChoiceInfo = function(i) return "n", 1, 1, 1, true, i == 1 and 76 or 77 end
GetQuestLogRewardInfo = function() end
local itemsLoaded = false
C_Item = { GetItemInfo = function(id) if itemsLoaded then return "n", "LINK" .. id end end, RequestLoadItemDataByID = function() end }
events.scripts.OnEvent(events, "QUEST_LOG_UPDATE"); tick()
assert(not find("Near Boars").right.text:find("Upg", 1, true), "not loaded yet, so no claim")
itemsLoaded = true
events.scripts.OnEvent(events, "GET_ITEM_INFO_RECEIVED", 77, true); tick()
assert(find("Near Boars").right.text:find("Upg", 1, true), "upgrade tag: " .. texts())
assert(not find("Far Bears").right.text:find("Upg", 1, true), "others untagged")
find("Near Boars").scripts.OnEnter(find("Near Boars"))
assert(table.concat(tipLines, "\n"):find("Upgrade: LINK77", 1, true), "tooltip names it")
local before_asks = asks
for _ = 1, 4 do tick() end
assert(asks == before_asks, "results kept, not asked again")
ItemAdvisor_IsUpgrade = function() return false end
events.scripts.OnEvent(events, "PLAYER_EQUIPMENT_CHANGED"); tick()
assert(not find("Near Boars").right.text:find("Upg", 1, true), "wearing it clears the tag")
ItemAdvisor_IsUpgrade = nil

-- Quests you haven't picked up, nearest first, and a click marks one.
local waypoint, tracked
local vec = function(x, y) return { GetXY = function() return x, y end } end
CreateVector2D = vec
C_Map = {
    GetBestMapForUnit = function() return 27 end,
    GetPlayerMapPosition = function() return vec(0.5, 0.5) end,
    GetWorldPosFromMapPos = function(_, p) local x, y = p:GetXY(); return 0, vec(x * 1000, y * 1000) end,
    SetUserWaypoint = function(p) waypoint = p end,
}
UiMapPoint = { CreateFromCoordinates = function(m, x, y) return { m = m, x = x, y = y } end }
C_SuperTrack.SetSuperTrackedUserWaypoint = function(v) tracked = v end
local mapAsks = 0
C_QuestLine = {
    RequestQuestLinesForMap = function() mapAsks = mapAsks + 1 end,
    GetAvailableQuestLines = function() return {
        { questID = 901, questName = "Faraway Offer", x = 0.9, y = 0.9, startMapID = 27 },
        { questID = 902, questName = "Close Offer", x = 0.5, y = 0.6, startMapID = 27 },
        { questID = 903, questName = "Second", x = 0.6, y = 0.6, startMapID = 27 },
        { questID = 904, questName = "Third", x = 0.7, y = 0.7, startMapID = 27 },
        { questID = 905, questName = "Gray Offer", x = 0.5, y = 0.5, startMapID = 27, isHidden = true },
        { questID = 906, questName = "Other Map", x = 0.5, y = 0.5, startMapID = 99 },
        { questID = 907, questName = "Already On", x = 0.5, y = 0.5, startMapID = 27, inProgress = true },
    } end,
}
events.scripts.OnEvent(events, "QUEST_LOG_UPDATE"); tick()
assert(texts():find("Quests nearby (3)", 1, true), "section: " .. texts())
assert(mapAsks == 1, "asks once per map")
assert(before("Close Offer", "Second") and before("Second", "Third"), "nearest first: " .. texts())
assert(not texts():find("Faraway Offer", 1, true), "only the nearest few")
for _, hidden in ipairs({ "Gray Offer", "Other Map", "Already On" }) do
    assert(not texts():find(hidden, 1, true), "filtered: " .. hidden)
end
assert(find("Close Offer").right.text:find("100 yd", 1, true), "distance: " .. find("Close Offer").right.text)
assert(before("Near Boars", "Close Offer"), "after your active quests here")
find("Close Offer").scripts.OnClick(find("Close Offer"), "LeftButton")
assert(waypoint and waypoint.y == 0.6 and tracked == true, "click marks it")
find("Quests nearby").scripts.OnClick(find("Quests nearby"), "LeftButton"); tick()
assert(not texts():find("Close Offer", 1, true), "folds")
find("Quests nearby").scripts.OnClick(find("Quests nearby"), "LeftButton"); tick()
for _ = 1, 4 do tick() end
assert(mapAsks == 1, "still once")
C_QuestLine.GetAvailableQuestLines = function() return {} end
events.scripts.OnEvent(events, "QUEST_LOG_UPDATE"); tick()
assert(not texts():find("Quests nearby", 1, true), "no offers, no section")
C_QuestLine, C_Map = nil, nil

-- Long logs don't overflow the screen.
for i = 100, 140 do
    log[#log + 1] = { questID = i, title = "Q" .. i, level = 10, difficultyLevel = 10, suggestedGroup = 0, questLogIndex = #log + 1 }
    data[i] = { onMap = true, objectives = { obj("o: 0/1", 0, 1), obj("p: 0/1", 0, 1) } }
end
log[#log + 1] = nil
events.scripts.OnEvent(events, "QUEST_LOG_UPDATE"); tick()
assert(#shownRows() <= 40, "row cap: " .. #shownRows())
assert(texts():find("more lines", 1, true), "says more")
assert(QuestTrackerPanel.height <= 500 - 12, "stops at the bottom of the screen: " .. QuestTrackerPanel.height)
local overflow = find("more lines")
assert(not rawget(overflow, "quest") and not rawget(overflow, "section"), "overflow row is plain")
for _, f in ipairs(frames) do
    if f.template == "SecureActionButtonTemplate" and f.shown then
        local owner = f.point[2]
        assert(owner ~= overflow, "no item button on the overflow row")
    end
end
-- A short screen shows less, not an overflowing panel.
QuestTrackerPanel.GetTop = function() return 200 end
events.scripts.OnEvent(events, "QUEST_LOG_UPDATE"); tick()
assert(QuestTrackerPanel.height <= 200 - 12, "short screen: " .. QuestTrackerPanel.height)
QuestTrackerPanel.GetTop = function() return nil end
events.scripts.OnEvent(events, "QUEST_LOG_UPDATE"); tick()
QuestTrackerPanel.GetTop = function() return 500 end
tick()
assert(QuestTrackerPanel.height > 150, "measures again once the game has placed it: " .. QuestTrackerPanel.height)

-- Bonus objectives stay out, as in Blizzard's log.
log[#log + 1] = { questID = 900, title = "Bonus Task", level = 10, difficultyLevel = 10, suggestedGroup = 0, questLogIndex = #log + 1, isTask = true }
data[900] = { onMap = true }
events.scripts.OnEvent(events, "QUEST_LOG_UPDATE"); tick()
assert(not texts():find("Bonus Task", 1, true), "task hidden")

-- Empty log and hidden values.
log, data = {}, {}
events.scripts.OnEvent(events, "QUEST_LOG_UPDATE"); tick()
assert(texts():find("No quests", 1, true), "empty")
header("Dun Morogh")
quest(1, "A", 10, {})
issecretvalue = function() return true end
events.scripts.OnEvent(events, "QUEST_LOG_UPDATE"); tick()
for _ = 1, 4 do tick() end
assert(#handled == 0, "clean: " .. tostring(handled[1]))
print("ALL TESTS PASSED")
