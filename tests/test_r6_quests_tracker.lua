-- Round 6 #19: QuestTracker tags quests that are new in Forever (quest ID 10000 and up) with a short "Forever"
-- in the row's right-hand column and a line in its own row tooltip. Classic quests get neither. Harness after
-- test_r3_questtracker.lua.
-- Run from the tests folder:  node run.js "<repo root>" test_r6_quests_tracker.lua
local path = ADDON_PATH .. "/QuestTracker/QuestTracker.lua"
local realPrint = print
local frames, handled = {}, {}
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
    function r:SetHeight(h) self.height = h end
    function r:SetWidth(w) self.width = w end
    function r:IsMouseOver() return false end
    function r:GetLeft() return 100 end
    function r:GetTop() return 500 end
    function r:GetEffectiveScale() return 1 end
    function r:CreateFontString() return newRegion("font") end
    function r:CreateTexture() return newRegion("texture") end
    return setmetatable(r, { __index = function(_, k)
        if k == "quest" or k == "section" or k == "objectiveIndex" or k == "offer" or k == "link"
            or k == "isTitle" or k == "questID" then return nil end
        return function() end
    end })
end
local tipLines = {}
CreateFrame = function(kind, name, parent, template)
    local f = newRegion(kind, template)
    if kind == "GameTooltip" then
        function f:AddLine(t) tipLines[#tipLines + 1] = t end
        function f:SetText(t) tipLines = { t } end
    end
    frames[#frames + 1] = f
    if name then _G[name] = f end
    return f
end
print = function() handled[#handled + 1] = "print called" end
UIParent = newRegion("Frame")
GameTooltip = newRegion("Frame")
ObjectiveTrackerFrame = newRegion("Frame")
issecretvalue = function() return false end
InCombatLockdown = function() return false end
geterrorhandler = function() return function(e) handled[#handled + 1] = tostring(e) end end
local tick
C_Timer = { NewTicker = function(_, fn) tick = fn end }
GetServerTime = function() return 100000 end
GetTime = function() return 1000 end
UnitLevel = function() return 11 end
UnitXPMax = function() return 1000 end
UnitClass = function() return "Priest", "PRIEST", 5 end
UnitRace = function() return "Night Elf", "NightElf", 4 end
GetRealZoneText = function() return "Elwynn Forest" end
MinimapCluster = newRegion("Frame")
function MinimapCluster:GetBottom() return 620 end
function MinimapCluster:GetRight() return 1900 end

local log, data = {}, {}
local function header(title) log[#log + 1] = { isHeader = true, title = title } end
local function quest(id, title, level)
    log[#log + 1] = { questID = id, title = title, level = level, difficultyLevel = level, suggestedGroup = 0, questLogIndex = #log + 1 }
    data[id] = {}
end
C_QuestLog = {
    GetNumQuestLogEntries = function() return #log, 2 end,
    GetMaxNumQuestsCanAccept = function() return 25 end,
    GetInfo = function(i) return log[i] end,
    IsComplete = function() return false end,
    ReadyForTurnIn = function() return false end,
    IsQuestTrivial = function() return false end,
    GetQuestObjectives = function() return {} end,
    IsOnMap = function() return true, false end,
}
C_SuperTrack = { GetSuperTrackedQuestID = function() return 0 end, SetSuperTrackedQuestID = function() end }
GetQuestLogRewardXP = function() return 0 end

header("Elwynn Forest")
quest(91723, "Delicate Instruments", 10)
quest(176, "Wanted: \"Hogger\"", 11)
QuestTrackerDB = {}
assert(loadfile(path))("QuestTracker", {})
local events = frames[1]
events.scripts.OnEvent(events, "PLAYER_LOGIN")
tick()

local function rowFor(title)
    for _, f in ipairs(frames) do
        if f.kind == "Button" and rawget(f, "left") and f.shown and f.left.text:find(title, 1, true) then return f end
    end
end
local forever, classic = rowFor("Delicate Instruments"), rowFor("Hogger")
assert(forever and classic, "both rows drawn")
assert(forever.right.text:find("Forever", 1, true), "Forever quest tagged: " .. forever.right.text)
assert(not classic.right.text:find("Forever", 1, true), "Classic quest not tagged: " .. classic.right.text)
assert(not forever.left.text:find("Forever", 1, true), "the tag stays off the title")

forever.scripts.OnEnter(forever)
local tip = table.concat(tipLines, "\n")
assert(tip:find("New in Forever", 1, true), "row tooltip says it:\n" .. tip)
classic.scripts.OnEnter(classic)
tip = table.concat(tipLines, "\n")
assert(not tip:find("New in Forever", 1, true), "Classic row tooltip doesn't:\n" .. tip)

-- Blizzard's tracker is left alone (shown) by default.
assert(ObjectiveTrackerFrame.shown, "Blizzard's tracker still visible")
assert(#handled == 0, "clean: " .. tostring(handled[1]))
realPrint("test_r6_quests_tracker: ok")
