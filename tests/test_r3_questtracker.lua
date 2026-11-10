-- Round 3 #12: QuestTracker shows Forever's unfinished 1/1 rows as 0/1, and sorts quests by their nearest
-- unfinished objective camp (LevelGuide's QuestDB through LevelGuideQuestFacts) when the game gives no distance.
-- New QuestTracker behavior: default spot under the minimap, tags off the title, class/race quests,
-- timers, item cooldown and range, combat reload, focus in combat, NEW-stamp pruning.
local path = ADDON_PATH
if not path:find("%.lua$") then path = path .. "/QuestTracker/QuestTracker.lua" end
local frames, handled, blocked = {}, {}, {}
local combat, tick = true, nil
local function newRegion(kind, template)
    local r = { kind = kind, template = template, shown = true, scripts = {}, hooks = {}, attrs = {}, text = "" }
    function r:SetText(t) self.text = t end
    function r:GetText() return self.text end
    function r:SetScript(s, f) self.scripts[s] = f end
    function r:HookScript(s, f) self.hooks[s] = f end
    function r:Show() if combat and self.watchCombat then blocked[#blocked + 1] = "Show" end self.shown = true end
    function r:Hide() if combat and self.watchCombat then blocked[#blocked + 1] = "Hide" end self.shown = false end
    function r:SetShown(v) if combat and self.watchCombat and (v and true or false) ~= self.shown then blocked[#blocked + 1] = "SetShown" end self.shown = v and true or false end
    function r:IsShown() return self.shown end
    function r:SetAttribute(k, v)
        if combat then blocked[#blocked + 1] = "SetAttribute" end
        self.attrs[k] = v
    end
    function r:ClearAllPoints() if combat and self.watchCombat then blocked[#blocked + 1] = "ClearAllPoints" end end
    function r:SetPoint(...) if combat and self.watchCombat then blocked[#blocked + 1] = "SetPoint" end self.point = { ... } end
    function r:SetHeight(h) if combat and self.watchCombat then blocked[#blocked + 1] = "SetHeight" end self.height = h end
    function r:SetWidth(w) self.width = w end
    function r:SetVertexColor(red, g, b) self.vertex = { red, g, b } end
    function r:IsMouseOver() return false end
    function r:GetLeft() return 100 end
    function r:GetTop() return 500 end
    function r:GetEffectiveScale() return 1 end
    function r:CreateFontString() return newRegion("font") end
    function r:CreateTexture() return newRegion("texture") end
    return setmetatable(r, { __index = function(_, k)
        if k == "quest" or k == "section" or k == "objectiveIndex" or k == "offer" or k == "link" or k == "watchCombat"
            or k == "isTitle" or k == "questID" then return nil end
        return function() end
    end })
end
local tipLines = {}
CreateFrame = function(kind, name, parent, template)
    local f = newRegion(kind, template)
    if kind == "GameTooltip" then
        -- The addon's own tooltip: capture what it writes.
        function f:AddLine(t) tipLines[#tipLines + 1] = t end
        function f:SetText(t) tipLines = { t } end
    end
    -- Only the panel and the secure buttons are locked in combat; plain rows aren't protected.
    f.watchCombat = template == "SecureActionButtonTemplate" or name == "QuestTrackerPanel"
    frames[#frames + 1] = f
    if name then _G[name] = f end
    return f
end
UIParent = newRegion("Frame")
GameTooltip = newRegion("Frame")
ObjectiveTrackerFrame = newRegion("Frame")
issecretvalue = function() return false end
InCombatLockdown = function() return combat end
geterrorhandler = function() return function(e) handled[#handled + 1] = tostring(e) end end
C_Timer = { NewTicker = function(_, fn) tick = fn end }
local serverTime, now = 100000, 1000
GetServerTime = function() return serverTime end
GetTime = function() return now end
UnitLevel = function() return 10 end
UnitXPMax = function() return 1000 end
UnitClass = function() return "Hunter", "HUNTER", 3 end
UnitRace = function() return "Night Elf", "NightElf", 4 end
local zone = "Teldrassil"
GetRealZoneText = function() return zone end
C_Texture = { GetAtlasInfo = function(name) if name == "bags-greenarrow" then return { width = 16 } end end }

local minimapBottom = 620
MinimapCluster = newRegion("Frame")
function MinimapCluster:GetBottom() return minimapBottom end
function MinimapCluster:GetRight() return 1900 end

local log, data = {}, {}
local function header(title) log[#log + 1] = { isHeader = true, title = title } end
local function quest(id, title, level, o)
    o = o or {}
    log[#log + 1] = { questID = id, title = title, level = level, difficultyLevel = level, suggestedGroup = o.group or 0, questLogIndex = #log + 1 }
    data[id] = o
end
local function indexOf(id) for i, e in ipairs(log) do if e.questID == id then return i end end end
C_QuestLog = {
    GetNumQuestLogEntries = function() return #log, 23 end,
    GetMaxNumQuestsCanAccept = function() return 25 end,
    GetInfo = function(i) return log[i] end,
    IsComplete = function(id) return data[id].ready end,
    ReadyForTurnIn = function() return false end,
    IsQuestTrivial = function() return false end,
    GetQuestObjectives = function(id) return data[id].objectives or {} end,
    IsOnMap = function(id) return data[id].onMap or false, false end,
    GetDistanceSqToQuest = function(id) local d = data[id].distance; if d then return d * d, true end end,
    GetLogIndexForQuestID = function(id) return indexOf(id) end,
    GetTimeAllowed = function(id) local t = data[id].timer; if t then return t[1], t[2] end end,
}
local focus = 0
C_SuperTrack = { GetSuperTrackedQuestID = function() return focus end, SetSuperTrackedQuestID = function(id) focus = id end }
GetQuestLogRewardXP = function(id) return data[id].xp or 0 end
GetQuestLogSpecialItemInfo = function(i)
    local e = log[i]
    local o = e and data[e.questID]
    if o and o.item then return "|Hitem:" .. o.item .. ":|h[Rod]|h", 123, 1, false end
end
local cooldowns, inRange = {}, 1
GetQuestLogSpecialItemCooldown = function() return 950, 120, 1 end
CooldownFrame_Set = function(frame, start, duration, enable) cooldowns[#cooldowns + 1] = { frame = frame, start = start, duration = duration } end
IsQuestLogSpecialItemInRange = function() return inRange end
ItemAdvisor_IsUpgrade = function() return true, "Better" end
GetNumQuestLogChoices = function(id) return id == 1 and 1 or 0 end
GetNumQuestLogRewards = function() return 0 end
GetQuestLogChoiceInfo = function() return "n", 1, 1, 1, true, 55 end
C_Item = { GetItemInfo = function(id) return "n", "LINK" .. id end, RequestLoadItemDataByID = function() end }


local function obj(text, have, need) return { text = text, numFulfilled = have, numRequired = need, finished = have >= need } end
-- Map and world positions for the proximity fallback: the player stands at 50,50 on Teldrassil (1438).
local function vec(x, y) return { x = x, y = y, GetXY = function(self) return self.x, self.y end } end
CreateVector2D = vec
C_Map = {
    GetBestMapForUnit = function() return 1438 end,
    GetPlayerMapPosition = function() return vec(0.5, 0.5) end,
    GetWorldPosFromMapPos = function(map, v) return 1, vec(v.x * 1000, v.y * 1000) end,
}
-- LevelGuide's public lookup (QuestLookup.lua), read only.
local camps = {
    [10] = { { map = 1438, x = 80, y = 80 } },                                  -- far
    [11] = { { map = 1438, x = 52, y = 52 } },                                  -- near
    [14] = { { map = 1438, x = 51, y = 50 } }, [14.2] = { { map = 1438, x = 90, y = 90 } },
    [15] = { { map = 1438, x = 60, y = 60 } },
}
LevelGuideQuestFacts = {
    Quest = function(id)
        if id == 14 then return { id = 14, objectives = { { spots = camps[14] }, { spots = camps[14.2] } } } end
        if camps[id] then return { id = id, objectives = { { spots = camps[id] } } } end
    end,
    EnderSpot = function(id) if id == 13 then return 1438, 49, 49, "Ender" end end,
    Project = function(from, x, y, to) if from == to then return x, y end end,
}

header("Teldrassil")
quest(10, "Far Wolves", 3, { onMap = true, objectives = { obj("Wolves: 0/5", 0, 5) } })
quest(11, "Near Boars", 5, { onMap = true, objectives = { obj("Boars: 2/5", 2, 5) } })
quest(12, "Criteria Quest", 6, { onMap = true, objectives = { { text = "Find the cave: 1/1", numFulfilled = 1, numRequired = 1, finished = false } } })
quest(14, "Half Done", 4, { onMap = true, objectives = { obj("Near thing: 1/1", 1, 1), obj("Far thing: 0/3", 0, 3) } })
quest(15, "Middle", 4, { onMap = true, objectives = { obj("Middle: 0/3", 0, 3) } })
QuestTrackerDB = {}
combat = false
assert(loadfile(path))("QuestTracker", {})
local events = frames[1]
events.scripts.OnEvent(events, "PLAYER_LOGIN")
tick()
local function shownRows()
    local out = {}
    for _, f in ipairs(frames) do
        if f.kind == "Button" and rawget(f, "left") and f.shown then out[#out + 1] = f end
    end
    table.sort(out, function(a, b) return a.point[5] > b.point[5] end)
    return out
end
local function texts()
    local t = {}
    for _, r in ipairs(shownRows()) do t[#t + 1] = r.left.text end
    return table.concat(t, "\n")
end
local function before(a, b)
    local s = texts()
    local i, j = s:find(a, 1, true), s:find(b, 1, true)
    assert(i and j, "both shown: " .. a .. " / " .. b .. "\n" .. s)
    return i < j
end
assert(#handled == 0, "clean: " .. tostring(handled[1]))

-- 1. A 1/1 row the game hasn't finished (Forever criteria objectives) shows as 0/1, not done.
local s = texts()
assert(s:find("Find the cave: 0/1", 1, true), "1/1 unfinished shown as 0/1:\n" .. s)
assert(not s:find("Find the cave: 1/1", 1, true), "no 1/1 for an unfinished row")
for _, r in ipairs(shownRows()) do
    if r.left.text:find("Find the cave", 1, true) then
        assert(not r.left.text:find("|A:", 1, true) and not r.left.text:find("33ff33", 1, true), "not drawn as done: " .. r.left.text)
    end
end

-- 2. Without the game's distance, quests sort by their nearest unfinished objective camp.
assert(before("Near Boars", "Far Wolves"), "near camp first:\n" .. s)
assert(before("Middle", "Half Done"), "a finished objective's camp doesn't count:\n" .. s)
assert(#handled == 0, "clean after: " .. tostring(handled[1]))
print("test_r3_questtracker: ok")