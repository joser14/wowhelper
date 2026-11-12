-- Full review (hub, guides, quests): the "New in Forever" tag. Quest ID 10000 and up also caught the quests
-- Forever took from later Classic releases: Love is in the Air (65602) and Season of Discovery's library books
-- and quests (78088-84402). forever-db has a clean gap after them (nothing from 84403 to 86573); Forever's own
-- quests start at 86574. QuestTracker and QuestCheck now tag only 85000 and up. Harness after
-- test_r6_quests_tracker.lua and test_r6_quests_check.lua.
-- Run from the tests folder:  node run.js "<repo root>" test_full_hub_forever_tag.lua
local base = ADDON_PATH
local realPrint = print
local failures = {}
local function check(cond, why) if not cond then failures[#failures + 1] = why end end
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
GetRealZoneText = function() return "Darkshore" end
MinimapCluster = newRegion("Frame")
function MinimapCluster:GetBottom() return 620 end
function MinimapCluster:GetRight() return 1900 end

local log = {}
local function header(title) log[#log + 1] = { isHeader = true, title = title } end
local function quest(id, title, level)
    log[#log + 1] = { questID = id, title = title, level = level, difficultyLevel = level, suggestedGroup = 0, questLogIndex = #log + 1 }
end
C_QuestLog = {
    GetNumQuestLogEntries = function() return #log, 5 end,
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

header("Darkshore")
quest(87760, "Holy Diver", 20)                 -- Forever's own (Darkshore)
quest(91723, "Delicate Instruments", 10)       -- Forever's own (Elwynn)
quest(176, "Wanted: Hogger", 11)               -- original Classic
quest(78124, "Nar'thalas Almanac", 20)         -- Season of Discovery library book
quest(65602, "What Is Love?", 20)              -- Love is in the Air (Classic Era event)
QuestTrackerDB = {}
assert(loadfile(base .. "/QuestTracker/QuestTracker.lua"))("QuestTracker", {})
local events = frames[1]
events.scripts.OnEvent(events, "PLAYER_LOGIN")
tick()

local function rowFor(title)
    for _, f in ipairs(frames) do
        if f.kind == "Button" and rawget(f, "left") and f.shown and f.left.text:find(title, 1, true) then return f end
    end
end
local function tagged(title)
    local row = rowFor(title)
    check(row ~= nil, "row drawn for " .. title)
    return row and row.right.text:find("Forever", 1, true) ~= nil
end
check(tagged("Holy Diver"), "Forever's own Darkshore quest tagged")
check(tagged("Delicate Instruments"), "Forever's own Elwynn quest tagged")
check(not tagged("Hogger"), "Classic quest not tagged")
check(not tagged("Almanac"), "Season of Discovery library book is not new in Forever")
check(not tagged("What Is Love"), "Love is in the Air quest is not new in Forever")

-- QuestCheck: the same rule on the Quests page.
local out = {}
ForeverHub_Receive = function(_, t) out[#out + 1] = t end
SlashCmdList = SlashCmdList or {}
C_QuestLog.GetAllCompletedQuestIDs = function() return {} end
C_Map = { GetBestMapForUnit = function() return 1439 end }
LevelGuideQuestDB = {
    maps = { [1439] = "Darkshore" },
    n = { [1] = "1439:50,50|Giver" },
    o = {},
    q = {
        [87760] = "20|15|4294967373|0|n1|n1||||Holy Diver",
        [78124] = "10|8|0|0|n1|n1||||Nar'thalas Almanac",
        [65602] = "10|8|0|0|n1|n1||||What Is Love?",
        [4811] = "10|8|0|0|n1|n1||||The Red Crystal",
    },
}
assert(loadfile(base .. "/QuestCheck/QuestCheck.lua"))("QuestCheck", {})
UnitLevel = function() return 20 end
SlashCmdList.QUESTCHECK("")
local s = table.concat(out, "\n")
check(s:find("Holy Diver  |cffc58cffnew in Forever|r", 1, true), "QuestCheck tags Forever's own quest:\n" .. s)
check(not s:find("Almanac  |cffc58cff", 1, true), "QuestCheck doesn't tag the library book:\n" .. s)
check(not s:find("What Is Love?  |cffc58cff", 1, true), "QuestCheck doesn't tag Love is in the Air")
check(s:find("(1 |cffc58cffnew in Forever|r)", 1, true), "zone line counts one new quest:\n" .. s)

-- The real data: the gap the rule stands on (later-Classic IDs end at 84402; Forever's start at 86574).
LevelGuideQuestDB = nil
assert(loadfile(base .. "/LevelGuide/QuestDB.lua"))()
local laterMax, foreverMin, inGap = 0, math.huge, 0
for id in pairs(LevelGuideQuestDB.q) do
    if id >= 10000 and id < 85000 then laterMax = math.max(laterMax, id) end
    if id >= 85000 then foreverMin = math.min(foreverMin, id) end
    if id > 84402 and id < 86574 then inGap = inGap + 1 end
end
check(laterMax <= 84402 and foreverMin >= 86574 and inGap == 0, string.format("gap: later-Classic max %d, Forever min %d, %d between",
    laterMax, foreverMin, inGap))

check(#handled == 0, "clean: " .. tostring(handled[1]))
if #failures > 0 then error(table.concat(failures, "\n")) end
realPrint("test_full_hub_forever_tag: ok")
