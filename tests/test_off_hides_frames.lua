-- The owner's decision (research\xreview_ui.md, "Not fixed"): a helper switched Off on the hub's Manage page
-- hides its own frames too, and shows them again when switched On, without a reload. Each helper is switched
-- through the hub's real SetHelperOff (the Manage page's and Options page's button):
--  * QuestTracker: panel and quest sounds; its panel holds secure item buttons, so in combat the change waits
--    for PLAYER_REGEN_ENABLED and no protected frame is ever shown or hidden in combat;
--  * QuestMobs: nameplate markers and the list window (and its list window no longer sits on our tracker);
--  * ItemAdvisor: its overlay (bag badges, reward marks) and its tooltip line;
--  * WindowBadges: its badge overlay;
--  * ZoneLevels: no warning sent;
--  * LevelLog and ForeverHelper: their windows, keeping whether you had them open.
-- Without the hub nothing changes: the helper is On.
-- Run from the tests folder:  node run.js "<repo root>" test_off_hides_frames.lua
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

------------------------------------------------------------------------------------------------ 0. no hub
-- ForeverHub isn't loaded (its saved Off list may still be there): nothing changes, the helper is On.
do
    ForeverHubDB = { off = { ForeverHelper = true } }
    ForeverHelperDB = { characters = {}, shown = true }
    assert(loadfile(base .. "/ForeverHelper/ForeverHelper.lua"))("!ForeverHub", {})
    Fire("ForeverHelper", "ADDON_LOADED", "!ForeverHub")
    Fire("ForeverHelper", "PLAYER_LOGIN")
    check(ForeverHub_IsOff == nil, "the hub really isn't loaded")
    check(ForeverHelperFrame:IsVisible(), "without the hub the helper is On: its window shows")
    check(#handled == 0, "no hub: clean: " .. tostring(handled[1]))
    ForeverHubDB = nil
    Retire("ForeverHelper")
    tickers = {}
end

------------------------------------------------------------------------------------------------ load
local ns = {}
assert(loadfile(base .. "/ForeverHub/ForeverHub.lua"))("!ForeverHub", ns)
assert(loadfile(base .. "/ForeverHub/ForeverHubExtras.lua"))("!ForeverHub", ns)
local hub = ns.ForeverHub
local received = {}
do
    local realReceive = ForeverHub_Receive
    ForeverHub_Receive = function(source, text)
        received[#received + 1] = source
        return realReceive(source, text)
    end
end

ForeverHelperDB = { characters = {}, shown = true }
QuestTrackerDB = {}
QuestMobsDB = { enabled = true, size = "medium", list = true }
assert(loadfile(base .. "/ForeverHelper/ForeverHelper.lua"))("!ForeverHub", {})
assert(loadfile(base .. "/QuestTracker/QuestTracker.lua"))("ForeverQuests", {})
assert(loadfile(base .. "/ZoneLevels/ZoneLevels.lua"))("ForeverQuests", {})
assert(loadfile(base .. "/QuestMobs/QuestMobs.lua"))("ForeverQuests", {})
assert(loadfile(base .. "/ItemAdvisor/ItemAdvisor.lua"))("ForeverBags", {})
assert(loadfile(base .. "/WindowBadges/WindowBadges.lua"))("ForeverBags", {})
assert(loadfile(base .. "/LevelLog/LevelLog.lua"))("ForeverCharacter", {})

Fire("ForeverHub.lua", "PLAYER_LOGIN")
Fire("ForeverHelper", "ADDON_LOADED", "!ForeverHub")
for _, owner in ipairs({ "ForeverHelper", "QuestTracker", "ZoneLevels", "QuestMobs", "ItemAdvisor", "WindowBadges", "LevelLog" }) do
    Fire(owner, "PLAYER_LOGIN")
end
Flush()
Second()
check(#handled == 0, "login clean: " .. table.concat(handled, " | "))

local HELPER = {}
for _, helper in ipairs(hub.HELPERS) do HELPER[helper.name] = helper end
local function Switch(name, off)
    hub.SetHelperOff(HELPER[name], off)
    Flush()
end

------------------------------------------------------------------------------------------------ 1. QuestTracker
do
    local secureButtons = 0
    for _, r in ipairs(regions) do
        if r.secure and r.owner:find("QuestTracker", 1, true) then secureButtons = secureButtons + 1 end
    end
    check(secureButtons > 0, "QuestTracker built its secure item button")
    check(QuestTrackerPanel:IsVisible(), "tracker shown while On")

    Switch("QuestTracker", true)
    check(not QuestTrackerPanel:IsShown(), "Off hides the tracker panel at once")
    check(Visible("QuestTracker") == 0, "nothing of QuestTracker on screen while Off: " .. Visible("QuestTracker"))
    Second(); Second()
    check(not QuestTrackerPanel:IsShown(), "and the tick doesn't bring it back")

    -- Sounds: a quest completes while Off. Nothing plays (the quiet seconds after login are long over).
    now = now + 30
    local before = #sounds
    complete = true
    Fire("QuestTracker", "QUEST_LOG_UPDATE"); Flush(); Second()
    local trackerSounds = 0
    for i = before + 1, #sounds do
        if sounds[i].from:find("QuestTracker", 1, true) then trackerSounds = trackerSounds + 1 end
    end
    check(trackerSounds == 0, "Off: no quest sound")

    Switch("QuestTracker", false)
    check(QuestTrackerPanel:IsShown(), "On shows the tracker again without a reload")
    Second()
    check(Visible("QuestTracker") > 0, "its rows are drawn again")

    -- Back On, a real change plays its sound again.
    complete = false
    Fire("QuestTracker", "QUEST_LOG_UPDATE"); Flush(); Second()
    before = #sounds
    complete = true
    Fire("QuestTracker", "QUEST_LOG_UPDATE"); Flush(); Second()
    trackerSounds = 0
    for i = before + 1, #sounds do
        if sounds[i].from:find("QuestTracker", 1, true) then trackerSounds = trackerSounds + 1 end
    end
    check(trackerSounds == 1, "On: the quest complete sound plays again (" .. trackerSounds .. ")")

    -- In combat: the panel holds secure buttons, so the switch waits for combat to end.
    combat = true
    Switch("QuestTracker", true)
    Second()
    check(#protectedInCombat == 0, "nothing protected shown or hidden in combat: " .. table.concat(protectedInCombat, ", "))
    check(QuestTrackerPanel:IsShown(), "in combat the panel stays until combat ends")
    combat = false
    Fire("QuestTracker", "PLAYER_REGEN_ENABLED"); Flush()
    check(not QuestTrackerPanel:IsShown(), "combat over: the panel hides")

    combat = true
    Switch("QuestTracker", false)
    Second()
    check(not QuestTrackerPanel:IsShown(), "On in combat: still hidden until combat ends")
    check(#protectedInCombat == 0, "still nothing protected toggled in combat: " .. table.concat(protectedInCombat, ", "))
    combat = false
    Fire("QuestTracker", "PLAYER_REGEN_ENABLED"); Flush(); Second()
    check(QuestTrackerPanel:IsShown(), "combat over: the panel is back")
end

------------------------------------------------------------------------------------------------ 2. QuestMobs
do
    Fire("QuestMobs", "NAME_PLATE_UNIT_ADDED", "nameplate1")
    Second(); Second()
    check(Visible("QuestMobs") > 0, "QuestMobs shows a marker and its list window while On")
    local markers = 0
    for _, r in ipairs(regions) do
        if r.owner:find("QuestMobs", 1, true) and r.kind == "Frame" and r.points[1] and r.points[1][2] == nameplate and r:IsVisible() then
            markers = markers + 1
        end
    end
    check(markers == 1, "one marker beside the quest mob's nameplate: " .. markers)

    Switch("QuestMobs", true)
    check(Visible("QuestMobs") == 0, "Off hides QuestMobs' markers and list window at once: " .. Visible("QuestMobs"))
    Fire("QuestMobs", "NAME_PLATE_UNIT_ADDED", "nameplate1")
    Second(); Second()
    check(Visible("QuestMobs") == 0, "and a new nameplate gets no marker while Off")

    Switch("QuestMobs", false)
    Second(); Second()
    check(Visible("QuestMobs") > 0, "On shows them again without a reload")
end

-- 2b. Its list window's default spot sits left of our tracker panel, not on it; a dragged spot is kept.
do
    local window
    for _, r in ipairs(regions) do
        if r.owner:find("QuestMobs", 1, true) and r.kind == "Frame" and r.parent == UIParent and r.scripts.OnDragStop then window = r end
    end
    check(window ~= nil, "QuestMobs list window found")
    if window then
        function QuestTrackerPanel:GetLeft() return 1600 end
        function QuestTrackerPanel:GetTop() return 800 end
        -- Shown again: it takes the tracker's current spot.
        SlashCmdList.QUESTMOBS("list off"); Second()
        SlashCmdList.QUESTMOBS("list on"); Second()
        local p = window.points[1] or {}
        check(p[1] == "TOPRIGHT" and p[2] == UIParent and p[3] == "BOTTOMLEFT" and p[4] == 1592 and p[5] == 800,
            "default spot: just left of the tracker, same top: " .. tostring(p[1]) .. " " .. tostring(p[4]) .. "," .. tostring(p[5]))
        -- No tracker: a fixed spot clear of the tracker's column at the right edge.
        local panel = QuestTrackerPanel
        QuestTrackerPanel = nil
        SlashCmdList.QUESTMOBS("list off"); Second()
        SlashCmdList.QUESTMOBS("list on"); Second()
        p = window.points[1] or {}
        check(p[1] == "TOPRIGHT" and p[3] == "TOPRIGHT" and type(p[4]) == "number" and p[4] <= -300,
            "without the tracker: clear of its column (" .. tostring(p[4]) .. ")")
        QuestTrackerPanel = panel
        -- A spot you dragged to stays.
        QuestMobsDB.spot = { "CENTER", "CENTER", 10, 20 }
        SlashCmdList.QUESTMOBS("list off"); Second()
        SlashCmdList.QUESTMOBS("list on"); Second()
        p = window.points[1] or {}
        check(p[1] == "CENTER" and p[4] == 10 and p[5] == 20, "a dragged spot is kept: " .. tostring(p[1]))
    end
end

------------------------------------------------------------------------------------------------ 3. ItemAdvisor
do
    local advisorTip
    for _, call in ipairs(postCalls) do
        if call.from:find("ItemAdvisor", 1, true) then advisorTip = call.fn end
    end
    check(advisorTip ~= nil, "ItemAdvisor registered its tooltip line")
    local function TipLine()
        tipLines, shownLink = {}, RAG
        if advisorTip then advisorTip(GameTooltip) end
        return #tipLines
    end
    check(ItemAdvisorOverlay:IsVisible(), "ItemAdvisor's overlay shows while On")
    check(TipLine() == 1, "ItemAdvisor adds its tooltip line while On")

    Switch("ItemAdvisor", true)
    check(Visible("ItemAdvisor") == 0, "Off hides ItemAdvisor's overlay (badges and reward marks)")
    check(TipLine() == 0, "Off: no tooltip line")
    Fire("ItemAdvisor", "BAG_UPDATE_DELAYED"); Flush(); Second()
    check(Visible("ItemAdvisor") == 0, "a bag update doesn't bring it back")

    Switch("ItemAdvisor", false)
    check(ItemAdvisorOverlay:IsVisible(), "On shows the overlay again")
    check(TipLine() == 1, "On: the tooltip line is back")
end

------------------------------------------------------------------------------------------------ 4. WindowBadges
do
    check(WindowBadgesOverlay:IsVisible(), "WindowBadges' overlay shows while On")
    Switch("WindowBadges", true)
    check(Visible("WindowBadges") == 0, "Off hides every badge")
    Fire("WindowBadges", "MERCHANT_SHOW"); Flush(); Second()
    check(Visible("WindowBadges") == 0, "a vendor window opened while Off gets no badges")
    Fire("WindowBadges", "MERCHANT_CLOSED")
    Switch("WindowBadges", false)
    check(WindowBadgesOverlay:IsVisible(), "On shows the badges again")
end

------------------------------------------------------------------------------------------------ 5. ZoneLevels
do
    local function Sent()
        local n = 0
        for _, source in ipairs(received) do if source == "ZoneLevels" then n = n + 1 end end
        return n
    end
    Fire("ZoneLevels", "ZONE_CHANGED_NEW_AREA")
    local first = Sent()
    check(first == 1, "ZoneLevels warns while On (" .. first .. ")")
    Fire("ZoneLevels", "PLAYER_ENTERING_WORLD")   -- same zone: no repeat
    Switch("ZoneLevels", true)
    C_Map.GetBestMapForUnit = function() return 1439 end
    C_Map.GetMapInfo = function(id) return { mapID = id, name = "Darkshore", mapType = 3, parentMapID = 1414 } end
    UnitLevel = function() return 5 end
    Fire("ZoneLevels", "ZONE_CHANGED_NEW_AREA")
    check(Sent() == first, "Off: no zone warning")
    check(Visible("ZoneLevels") == 0, "Off: no note on screen")
    Switch("ZoneLevels", false)
    C_Map.GetBestMapForUnit = function() return 1440 end
    C_Map.GetMapInfo = function(id) return { mapID = id, name = "Ashenvale", mapType = 3, parentMapID = 1414 } end
    Fire("ZoneLevels", "ZONE_CHANGED_NEW_AREA")
    check(Sent() == first + 1, "On: warnings again")
    UnitLevel = function() return 11 end
end

------------------------------------------------------------------------------------------------ 6. LevelLog
do
    LevelLog_OpenWindow(false)
    check(LevelLogWindow:IsVisible(), "LevelLog window opens while On")
    Switch("LevelLog", true)
    check(not LevelLogWindow:IsShown(), "Off hides the open window")
    LevelLog_OpenWindow(true)
    check(not LevelLogWindow:IsShown(), "Off: the window can't be opened")
    Switch("LevelLog", false)
    check(LevelLogWindow:IsShown(), "On: the window you had open comes back")
    -- Closed by you: it stays closed through Off and On.
    LevelLogWindow:Hide()
    Switch("LevelLog", true)
    Switch("LevelLog", false)
    check(not LevelLogWindow:IsShown(), "a window you closed stays closed")
end

------------------------------------------------------------------------------------------------ 7. ForeverHelper
do
    check(ForeverHelperFrame:IsVisible(), "ForeverHelper window open (its save says shown)")
    Switch("ForeverHelper", true)
    check(not ForeverHelperFrame:IsShown(), "Off hides the window")
    Fire("ForeverHelper", "PLAYER_LOGOUT")
    check(ForeverHelperDB.shown == true, "logging out while Off keeps your choice: open")
    Switch("ForeverHelper", false)
    check(ForeverHelperFrame:IsShown(), "On shows it again")
    ForeverHelperFrame:Hide()
    Switch("ForeverHelper", true)
    Switch("ForeverHelper", false)
    check(not ForeverHelperFrame:IsShown(), "a window you closed stays closed")

    -- Off already at login: starts hidden, and On brings it back (the save says open).
    Switch("ForeverHelper", true)
    Retire("ForeverHelper")
    ForeverHelperDB = { characters = {}, shown = true }
    assert(loadfile(base .. "/ForeverHelper/ForeverHelper.lua"))("!ForeverHub", {})
    Fire("ForeverHelper", "ADDON_LOADED", "!ForeverHub")
    Fire("ForeverHelper", "PLAYER_LOGIN")
    check(not ForeverHelperFrame:IsShown(), "Off at login: the window starts hidden")
    Switch("ForeverHelper", false)
    check(ForeverHelperFrame:IsShown(), "and On shows it")
end

------------------------------------------------------------------------------------------------ manage page text
do
    local text = ""
    for _, r in ipairs(regions) do
        if r.owner:find("ForeverHub", 1, true) and type(r.text) == "string" then text = text .. "\n" .. r.text end
    end
    ForeverHubFrame:Show()
    hub.OpenPage(hub.PAGE_BY_LABEL.Manage)
    Flush()
    for _, r in ipairs(regions) do
        if r.owner:find("ForeverHub", 1, true) and type(r.text) == "string" then text = text .. "\n" .. r.text end
    end
    check(text:find("own windows, markers, badges and sounds", 1, true), "the Manage page says Off hides the helper's own frames")
    check(not text:find("It keeps running quietly", 1, true), "old text gone")
end

check(#protectedInCombat == 0, "no protected frame toggled in combat: " .. table.concat(protectedInCombat, ", "))
check(#handled == 0, "clean: " .. table.concat(handled, " | "))
check(#chat == 0, "nothing in chat: " .. tostring(chat[1]))

if #failures > 0 then
    realPrint("FAILURES (" .. #failures .. "):")
    for _, why in ipairs(failures) do realPrint(" - " .. why) end
    os.exit(1)
end
realPrint("test_off_hides_frames: all checks passed")
