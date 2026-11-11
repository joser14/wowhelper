-- Cross-addon review (player's side): Blizzard's quest tracker is visible by default now, and it sits
-- under the minimap at the right edge, where our panel's default spot was. Our panel goes to its left
-- then; nothing is ever written to Blizzard's frame for it.
local base = ADDON_PATH
local frames, handled = {}, {}
local tick
local function newRegion(kind, template)
    local r = { kind = kind, template = template, shown = true, scripts = {}, attrs = {}, text = "" }
    function r:SetText(t) self.text = t end
    function r:GetText() return self.text end
    function r:SetScript(s, f) self.scripts[s] = f end
    function r:Show() self.shown = true end
    function r:Hide() self.shown = false end
    function r:SetShown(v) self.shown = v and true or false end
    function r:IsShown() return self.shown end
    function r:SetAttribute(k, v) self.attrs[k] = v end
    function r:SetPoint(...) self.point = { ... } end
    function r:IsMouseOver() return false end
    function r:GetEffectiveScale() return 1 end
    function r:CreateFontString() return newRegion("font") end
    function r:CreateTexture() return newRegion("texture") end
    return setmetatable(r, { __index = function(_, k)
        if k == "quest" or k == "section" or k == "objectiveIndex" or k == "offer" or k == "link" or k == "isTitle" or k == "questID" then return nil end
        return function() end
    end })
end
CreateFrame = function(kind, name, parent, template)
    local f = newRegion(kind, template)
    frames[#frames + 1] = f
    if name then _G[name] = f end
    return f
end
UIParent = newRegion("Frame")
GameTooltip = newRegion("Frame")
issecretvalue = function() return false end
InCombatLockdown = function() return false end
geterrorhandler = function() return function(e) handled[#handled + 1] = tostring(e) end end
C_Timer = { NewTicker = function(_, fn) tick = fn end, After = function(_, fn) fn() end }
GetServerTime = function() return 100000 end
GetTime = function() return 1000 end
UnitLevel = function() return 11 end
UnitXPMax = function() return 1000 end
UnitClass = function() return "Priest", "PRIEST", 5 end
UnitRace = function() return "Night Elf", "NightElf", 4 end
GetRealZoneText = function() return "Teldrassil" end

MinimapCluster = newRegion("Frame")
function MinimapCluster:GetBottom() return 620 end
function MinimapCluster:GetRight() return 1900 end

-- Blizzard's tracker: visible at the right edge under the minimap. Every write to it is recorded.
local trackerWrites = {}
ObjectiveTrackerFrame = setmetatable({ shown = true, left = 1640, right = 1900, alpha = 1 }, { __index = function(_, k)
    return function() trackerWrites[#trackerWrites + 1] = k end
end })
function ObjectiveTrackerFrame:IsShown() return self.shown end
function ObjectiveTrackerFrame:GetAlpha() return self.alpha end
function ObjectiveTrackerFrame:GetLeft() return self.left end
function ObjectiveTrackerFrame:GetRight() return self.right end
function ObjectiveTrackerFrame:GetEffectiveScale() return 1 end
function ObjectiveTrackerFrame:SetAlpha(a) trackerWrites[#trackerWrites + 1] = "SetAlpha"; self.alpha = a end

local log = { { isHeader = true, title = "Teldrassil" },
    { questID = 1, title = "The Woodland Protector", level = 6, difficultyLevel = 6, suggestedGroup = 0, questLogIndex = 2 } }
C_QuestLog = {
    GetNumQuestLogEntries = function() return #log, 1 end,
    GetMaxNumQuestsCanAccept = function() return 25 end,
    GetInfo = function(i) return log[i] end,
    IsComplete = function() return false end,
    ReadyForTurnIn = function() return false end,
    IsQuestTrivial = function() return false end,
    GetQuestObjectives = function() return { { text = "Grells: 1/8", numFulfilled = 1, numRequired = 8, finished = false } } end,
    IsOnMap = function() return true, false end,
    GetDistanceSqToQuest = function() return 1600, true end,
    GetLogIndexForQuestID = function() return 2 end,
}
C_SuperTrack = { GetSuperTrackedQuestID = function() return 0 end, SetSuperTrackedQuestID = function() end }
GetQuestLogRewardXP = function() return 450 end

QuestTrackerDB = {}
assert(loadfile(base .. "/QuestTracker/QuestTracker.lua"))("QuestTracker", {})
local events = frames[1]
events.scripts.OnEvent(events, "PLAYER_LOGIN")
tick()

local failures = {}
local function check(cond, why) if not cond then failures[#failures + 1] = why end end
local function spot()
    local p = QuestTrackerPanel.point
    return p[1], p[3], p[4], p[5]
end
local function update()
    events.scripts.OnEvent(events, "QUEST_LOG_UPDATE"); tick()
end

-- 1. Default: Blizzard's tracker visible, so our panel's right edge sits left of it, under the minimap.
check(QuestTrackerDB.keepBlizzard == true, "Blizzard's tracker kept visible by default")
local point, relative, x, y = spot()
check(point == "TOPRIGHT" and relative == "BOTTOMLEFT" and x == 1640 - 8 and y == 620 - 22,
    "left of Blizzard's tracker: " .. tostring(x) .. ", " .. tostring(y))

-- 2. Blizzard's tracker hidden (no quests watched): back under the minimap.
ObjectiveTrackerFrame.shown = false
update()
point, relative, x = spot()
check(x == 1896, "tracker hidden: under the minimap (" .. tostring(x) .. ")")
ObjectiveTrackerFrame.shown = true

-- 3. Moved elsewhere in Edit Mode (not under our spot): our default spot is left alone.
ObjectiveTrackerFrame.left, ObjectiveTrackerFrame.right = 200, 460
update()
point, relative, x = spot()
check(x == 1896, "tracker elsewhere: under the minimap (" .. tostring(x) .. ")")
ObjectiveTrackerFrame.left, ObjectiveTrackerFrame.right = 1640, 1900

-- 4. Unreadable (secret) edges: the old spot, no error.
local SECRET = {}
ObjectiveTrackerFrame.left = SECRET
issecretvalue = function(v) return v == SECRET end
update()
point, relative, x = spot()
check(x == 1896, "secret edge: under the minimap (" .. tostring(x) .. ")")
issecretvalue = function() return false end
ObjectiveTrackerFrame.left = 1640

-- 5. Nothing written to Blizzard's frame while it's kept visible.
check(#trackerWrites == 0, "no writes to Blizzard's tracker: " .. table.concat(trackerWrites, ","))

-- 6. Right-click "make Blizzard's tracker clear": back under the minimap.
QuestTrackerDB.keepBlizzard = false
update()
point, relative, x = spot()
check(x == 1896, "Blizzard's tracker made clear: under the minimap (" .. tostring(x) .. ")")

-- 7. A spot you dragged to is kept either way.
QuestTrackerDB.keepBlizzard = true
QuestTrackerDB.position = { 300, 700 }
QuestTrackerPanel.point = { "TOPLEFT", UIParent, "BOTTOMLEFT", 300, 700 }
update()
check(QuestTrackerPanel.point[1] == "TOPLEFT" and QuestTrackerPanel.point[4] == 300, "saved position kept")

check(#handled == 0, "clean: " .. tostring(handled[1]))
if #failures > 0 then
    print("FAILURES (" .. #failures .. "):")
    for _, why in ipairs(failures) do print(" - " .. why) end
    os.exit(1)
end
print("test_xreview_ui_tracker: all checks passed")
