-- Review 6a (research\review6_a.md): QuestTracker switched Off on the hub's Manage page.
--  1. With Blizzard's tracker made clear (right-click on our header), Off left it at alpha 0: no quest
--     tracker on screen at all until a /reload. Off now gives it back its alpha; On makes it clear again.
--  2. Off in combat waits for combat to end before hiding the panel (secure item buttons), but quest sounds
--     must stop at once: the hub already says the helper is Off.
-- The harness is the one from test_off_hides_frames.lua.
-- Run from the tests folder:  node run.js "<repo root>" test_cr6a_tracker_off.lua
local base = ADDON_PATH
local realPrint = print
local failures = {}
local function check(cond, why) if not cond then failures[#failures + 1] = why end end

local regions, handled, chat, sounds, tickers, timers, postCalls = {}, {}, {}, {}, {}, {}, {}
local protectedInCombat = {}
local combat = false
local now = 1000

-- The file that asked (the helper's own source), so each region knows its owner.
-- Skips C functions such as pcall, so a call made through pcall still names the helper.
local function Caller(level)
    level = level + 1
    while true do
        local info = debug.getinfo(level, "S")
        if not info then return "?" end
        -- fengari names its built-ins "=[JS]" (the game's would be "=[C]").
        if info.what ~= "C" and not (info.source or ""):find("^=") then return info.source or "?" end
        level = level + 1
    end
end

local newRegion
local function MarkSecure(region)
    local parent = region.parent
    while parent do
        parent.hasSecure = true
        parent = parent.parent
    end
end

newRegion = function(kind, name, parent, template, owner)
    local r = { kind = kind, name = name, parent = parent, template = template, owner = owner or "?", shown = true,
        scripts = {}, events = {}, text = "", height = 0, points = {}, attrs = {} }
    r.secure = type(template) == "string" and template:find("Secure", 1, true) ~= nil
    local function Toggle(self, value)
        -- The game blocks showing or hiding a protected frame (or one holding protected children) in combat.
        if combat and (self.secure or self.hasSecure) then
            protectedInCombat[#protectedInCombat + 1] = tostring(self.name or self.kind) .. " from " .. Caller(3)
            return
        end
        local was = self.shown
        self.shown = value and true or false
        if self.shown and not was and self.scripts.OnShow then self.scripts.OnShow(self) end
    end
    function r:Show() Toggle(self, true) end
    function r:Hide() Toggle(self, false) end
    function r:SetShown(v) Toggle(self, v) end
    function r:IsShown() return self.shown end
    function r:IsVisible()
        if not self.shown then return false end
        if self == UIParent then return true end
        return self.parent ~= nil and self.parent:IsVisible()
    end
    function r:GetParent() return self.parent end
    function r:SetParent(p) self.parent = p end
    function r:SetText(t) self.text = t end
    function r:GetText() return self.text end
    function r:SetScript(s, f) self.scripts[s] = f end
    function r:GetScript(s) return self.scripts[s] end
    function r:HookScript() end
    function r:RegisterEvent(e) self.events[e] = true end
    function r:UnregisterEvent(e) self.events[e] = nil end
    function r:SetAttribute(k, v) self.attrs[k] = v end
    function r:SetHeight(h) self.height = h end
    function r:GetHeight() return self.height end
    function r:GetStringHeight() return 14 end
    function r:GetStringWidth() return 40 end
    function r:ClearAllPoints() self.points = {} end
    function r:SetPoint(...) self.points[#self.points + 1] = { ... } end
    function r:GetPoint() local p = self.points[1]; if p then return p[1], p[2], p[3], p[4], p[5] end end
    function r:SetChecked(v) self.checked = v end
    function r:GetChecked() return self.checked end
    function r:IsMouseOver() return false end
    function r:GetEffectiveScale() return 1 end
    function r:CreateFontString() local fs = newRegion("font", nil, self, nil, Caller(2)); regions[#regions + 1] = fs; return fs end
    function r:CreateTexture() local tx = newRegion("texture", nil, self, nil, Caller(2)); regions[#regions + 1] = tx; return tx end
    return setmetatable(r, { __index = function(_, k)
        if type(k) == "string" and k:match("^%u") then return function() end end
    end })
end

CreateFrame = function(kind, name, parent, template)
    local f = newRegion(kind, name, parent, template, Caller(2))
    regions[#regions + 1] = f
    if f.secure then MarkSecure(f) end
    if name then _G[name] = f end
    return f
end

-- Regions of one helper that the player can see.
local function Visible(owner)
    local count = 0
    for _, r in ipairs(regions) do
        if r.owner:find(owner, 1, true) and r:IsVisible() then count = count + 1 end
    end
    return count
end

-- Sends an event to every frame of one helper that registered it.
local function Fire(owner, event, ...)
    for _, r in ipairs(regions) do
        if r.owner:find(owner, 1, true) and r.events[event] and r.scripts.OnEvent then
            r.scripts.OnEvent(r, event, ...)
        end
    end
end

-- A helper loaded again (a new session in the same test): its old frames stop getting events and go away.
local function Retire(owner)
    for _, r in ipairs(regions) do
        if r.owner:find(owner, 1, true) then
            r.events, r.shown = {}, false
        end
    end
end

local function Flush()
    local guard = 0
    while #timers > 0 and guard < 500 do
        guard = guard + 1
        table.remove(timers, 1)()
    end
end

-- One second of game time: tickers, then OnUpdate on frames the game would run it for (shown, visible parent).
local function Second()
    now = now + 1
    for _, t in ipairs(tickers) do t() end
    for _, r in ipairs(regions) do
        local runs = r.shown and (r.parent == nil or r.parent:IsVisible())
        if runs and r.scripts.OnUpdate then r.scripts.OnUpdate(r, 1) end
    end
    Flush()
end

------------------------------------------------------------------------------------------------ game API
UIParent = newRegion("Frame", "UIParent", nil, nil, "game")
Minimap = newRegion("Frame", "Minimap", UIParent, nil, "game")
GameTooltip = newRegion("GameTooltip", "GameTooltip", UIParent, nil, "game")
local tipLines = {}
function GameTooltip:AddLine(text) tipLines[#tipLines + 1] = text end
ItemRefTooltip = newRegion("GameTooltip", "ItemRefTooltip", UIParent, nil, "game")
UISpecialFrames = {}
SlashCmdList = {}
print = function(...) chat[#chat + 1] = table.concat({ ... }, " ") end
DEFAULT_CHAT_FRAME = { AddMessage = function(_, t) chat[#chat + 1] = t end }
issecretvalue = function() return false end
geterrorhandler = function() return function(e) handled[#handled + 1] = tostring(e) end end
InCombatLockdown = function() return combat end
GetTime = function() return now end
GetServerTime = function() return 100000 + now end
C_Timer = {
    After = function(_, fn) timers[#timers + 1] = fn end,
    NewTicker = function(_, fn) tickers[#tickers + 1] = fn; return { Cancel = function() end } end,
}
SOUNDKIT = { TELL_MESSAGE = 3081 }
PlaySound = function(id) sounds[#sounds + 1] = { id = id, from = Caller(2) } end
FlashClientIcon = function() end
Enum = { TooltipDataType = { Item = 0, Unit = 2 } }
TooltipDataProcessor = { AddTooltipPostCall = function(kind, fn) postCalls[#postCalls + 1] = { kind = kind, fn = fn, from = Caller(2) } end }
local shownLink
TooltipUtil = { GetDisplayedItem = function() return "Linen Scrap", shownLink end }

UnitName = function(unit) if unit == "player" then return "Tester" end return "Grell" end
UnitGUID = function(unit) if unit == "player" then return "Player-1-0001" end return "Creature-0-1-0-1-2152-0000ABCD" end
GetRealmName = function() return "Realm" end
UnitClass = function() return "Priest", "PRIEST", 5 end
UnitRace = function() return "Night Elf", "NightElf", 4 end
UnitFactionGroup = function() return "Alliance" end
UnitLevel = function() return 11 end
UnitXP = function() return 100 end
UnitXPMax = function() return 1000 end
GetXPExhaustion = function() return 0 end
GetMoney = function() return 100 end
UnitExists = function() return true end
UnitCanAttack = function() return true end
UnitIsPlayer = function(unit) return unit == "player" end
UnitIsDeadOrGhost = function() return false end
UnitOnTaxi = function() return false end
UnitAffectingCombat = function() return combat end
IsPlayerMoving = function() return false end
IsResting = function() return false end
IsInInstance = function() return false, "none" end
GetRealZoneText = function() return "Teldrassil" end
GetInventoryItemLink = function() return nil end
NUM_TOTAL_EQUIPPED_BAG_SLOTS = 0
C_Container = {
    GetContainerNumSlots = function() return 0 end,
    GetContainerItemInfo = function() return nil end,
    GetItemCooldown = function() return 0, 0, 1 end,
}
local RAG = "|cff9d9d9d|Hitem:2934::::::::11:::::::|h[Ruined Leather Scraps]|h|r"
C_Item = {
    GetItemCount = function() return 0 end,
    GetItemInfo = function(link)
        if link == RAG then return "Ruined Leather Scraps", RAG, 0, 1, 1, "Trade Goods", "Leather", 20, "", 0, 4, 7, 6 end
    end,
    GetItemStats = function() return {} end,
    RequestLoadItemDataByID = function() end,
    GetItemNameByID = function() return nil end,
}
C_Map = {
    GetBestMapForUnit = function() return 1440 end,
    GetMapInfo = function(id) return { mapID = id, name = "Ashenvale", mapType = 3, parentMapID = 1414 } end,
    GetPlayerMapPosition = function() return nil end,
}

-- One quest, with a quest item, for QuestTracker and QuestMobs.
local complete = false
local log = { { isHeader = true, title = "Teldrassil" },
    { questID = 1, title = "The Woodland Protector", level = 6, difficultyLevel = 6, suggestedGroup = 0, questLogIndex = 2 } }
C_QuestLog = {
    GetNumQuestLogEntries = function() return #log, 1 end,
    GetMaxNumQuestsCanAccept = function() return 25 end,
    GetInfo = function(i) return log[i] end,
    IsComplete = function() return complete end,
    ReadyForTurnIn = function() return complete end,
    IsQuestTrivial = function() return false end,
    GetQuestObjectives = function()
        return { { text = "Grells slain: 1/8", numFulfilled = complete and 8 or 1, numRequired = 8, finished = complete } }
    end,
    IsOnMap = function() return true, false end,
    GetDistanceSqToQuest = function() return 1600, true end,
    GetLogIndexForQuestID = function() return 2 end,
}
C_SuperTrack = { GetSuperTrackedQuestID = function() return 0 end, SetSuperTrackedQuestID = function() end }
GetQuestLogRewardXP = function() return 450 end
GetQuestLogSpecialItemInfo = function(index) if index == 2 then return "|Hitem:5475::|h[Wooden Key]|h", 134400, nil, true end end

-- A quest mob's nameplate and tooltip.
local nameplate = newRegion("Frame", "NamePlate1", UIParent, nil, "game")
C_NamePlate = { GetNamePlateForUnit = function(unit) if unit == "nameplate1" then return nameplate end end }
C_TooltipInfo = {
    GetUnit = function()
        return { lines = {
            { type = 0, leftText = "Grell" },
            { type = 17, leftText = "The Woodland Protector" },
            { type = 8, leftText = " - Grells slain: 1/8", completed = false },
        } }
    end,
    GetHyperlink = function() return { lines = { { leftText = "x" } } } end,
}


-- Blizzard's tracker: only its alpha is ever touched (SetAlpha runs none of Blizzard's Lua).
ObjectiveTrackerFrame = newRegion("Frame", "ObjectiveTrackerFrame", UIParent, nil, "game")
ObjectiveTrackerFrame.alpha = 1
function ObjectiveTrackerFrame:SetAlpha(a) self.alpha = a end
function ObjectiveTrackerFrame:GetAlpha() return self.alpha end

local ns = {}
assert(loadfile(base .. "/ForeverHub/ForeverHub.lua"))("!ForeverHub", ns)
assert(loadfile(base .. "/ForeverHub/ForeverHubExtras.lua"))("!ForeverHub", ns)
local hub = ns.ForeverHub
-- The player made Blizzard's tracker clear (saves past the one-time "shown by default" move).
QuestTrackerDB = { blizzardShownDefault = true, keepBlizzard = false }
assert(loadfile(base .. "/QuestTracker/QuestTracker.lua"))("ForeverQuests", {})
Fire("ForeverHub.lua", "PLAYER_LOGIN")
Fire("QuestTracker", "PLAYER_LOGIN")
Flush(); Second()
check(#handled == 0, "login clean: " .. table.concat(handled, " | "))

local HELPER = {}
for _, helper in ipairs(hub.HELPERS) do HELPER[helper.name] = helper end
local function Switch(name, off)
    hub.SetHelperOff(HELPER[name], off)
    Flush()
end
local function TrackerSounds(from)
    local n = 0
    for i = from + 1, #sounds do
        if sounds[i].from:find("QuestTracker", 1, true) then n = n + 1 end
    end
    return n
end

-- 1. Blizzard's tracker comes back with Off, goes clear again with On.
check(ObjectiveTrackerFrame.alpha == 0, "On: Blizzard's tracker is clear, as the player chose")
Switch("QuestTracker", true)
check(not QuestTrackerPanel:IsShown(), "Off hides our panel")
check(ObjectiveTrackerFrame.alpha == 1, "Off: Blizzard's tracker is visible again, so a quest tracker stays on screen ("
    .. tostring(ObjectiveTrackerFrame.alpha) .. ")")
Second(); Second()
check(ObjectiveTrackerFrame.alpha == 1, "and our tick leaves it visible while Off")
Switch("QuestTracker", false)
Second()
check(QuestTrackerPanel:IsShown(), "On shows our panel")
check(ObjectiveTrackerFrame.alpha == 0, "On: Blizzard's tracker is clear again")

-- 2. Off in combat: the panel waits for combat to end, the sounds don't.
now = now + 60
Fire("QuestTracker", "QUEST_LOG_UPDATE"); Flush(); Second()   -- a reading to compare with
combat = true
Switch("QuestTracker", true)
check(QuestTrackerPanel:IsShown(), "in combat the panel stays until combat ends (secure item buttons)")
local before = #sounds
complete = true
Fire("QuestTracker", "QUEST_LOG_UPDATE"); Flush(); Second()
check(TrackerSounds(before) == 0, "switched Off in combat: no quest sound (" .. TrackerSounds(before) .. ")")
check(#protectedInCombat == 0, "nothing protected toggled in combat: " .. table.concat(protectedInCombat, ", "))
combat = false
Fire("QuestTracker", "PLAYER_REGEN_ENABLED"); Flush(); Second()
check(not QuestTrackerPanel:IsShown(), "combat over: the panel hides")
check(ObjectiveTrackerFrame.alpha == 1, "and Blizzard's tracker is visible")
check(TrackerSounds(before) == 0, "still no sound for what happened while Off")

-- With Blizzard's tracker kept visible (the default), Off writes nothing to it.
Switch("QuestTracker", false); Second()
QuestTrackerDB.keepBlizzard = true
ObjectiveTrackerFrame.alpha = 0.5
Switch("QuestTracker", true)
check(ObjectiveTrackerFrame.alpha == 0.5, "keepBlizzard: Off doesn't touch Blizzard's frame")

check(#handled == 0, "clean: " .. table.concat(handled, " | "))
check(#chat == 0, "nothing in chat: " .. tostring(chat[1]))

if #failures > 0 then
    realPrint("FAILURES (" .. #failures .. "):")
    for _, why in ipairs(failures) do realPrint(" - " .. why) end
    os.exit(1)
end
realPrint("test_cr6a_tracker_off: all checks passed")