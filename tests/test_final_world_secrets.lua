-- Final review (ForeverCharacter + ForeverWorld): every helper of both bundles loaded together in combat, with
-- every unit, money, XP, map and zone reading secret. Every registered event is fired (with secret
-- arguments), every ticker, timer and OnUpdate runs, every page and side-panel line is drawn. Nothing may
-- error, print to chat, hook, write Blizzard's tables, put pins into the map canvas or register a
-- CallbackEvent (COMBAT_LOG_*, MINIMAP_PING, ...): the "ForeverWorld blocked" pop-up of 2026-11-09.
-- Run from the tests folder:  node run.js "<repo root>" test_final_world_secrets.lua
local base = ADDON_PATH
local say = print
local SECRET = {}
issecretvalue = function(v) return v == SECRET end
canaccessvalue = function(v) return v ~= SECRET end

local failures, forbidden, errors, chat = {}, {}, {}, {}
local function check(cond, why) if not cond then failures[#failures + 1] = why end end
print = function(...) chat[#chat + 1] = table.concat({ ... }, " ") end
DEFAULT_CHAT_FRAME = { AddMessage = function(_, t) chat[#chat + 1] = tostring(t) end }
geterrorhandler = function() return function(e) errors[#errors + 1] = tostring(e) end end
for _, name in ipairs({ "hooksecurefunc", "TargetUnit", "CastSpellByName", "CastSpellByID", "BuyTrainerService",
    "UseContainerItem", "PickupContainerItem", "AcceptQuest", "CompleteQuest", "GetQuestReward", "RunMacroText" }) do
    _G[name] = function() forbidden[#forbidden + 1] = name end
end

-- CallbackEvent = true in the API docs: registering any of these raises ADDON_ACTION_FORBIDDEN.
local CALLBACK_EVENTS = {}
for _, e in ipairs({ "COMBAT_LOG_EVENT_UNFILTERED", "COMBAT_LOG_EVENT", "COMBAT_LOG_EVENT_INTERNAL_UNFILTERED",
    "COMBAT_LOG_APPLY_FILTER_SETTINGS", "COMBAT_LOG_REFILTER_ENTRIES", "MINIMAP_PING", "ENCOUNTER_STATE_CHANGED",
    "TOOLTIP_SHOW_ITEM_COMPARISON", "CLASS_TALENTS_SWITCH_TO_LOADOUT_BY_INDEX", "CLASS_TALENTS_SWITCH_TO_LOADOUT_BY_NAME",
    "CLASS_TALENTS_SWITCH_TO_SPECIALIZATION_BY_INDEX", "CLASS_TALENTS_SWITCH_TO_SPECIALIZATION_BY_NAME" }) do
    CALLBACK_EVENTS[e] = true
end

-- Frames: every method exists; Get* readings of our own frames are plain numbers.
local frames = {}
local function newFrame(kind, name, parent)
    local f = { kind = kind, name = name, parent = parent, events = {}, scripts = {}, shown = true, text = "" }
    function f:RegisterEvent(e)
        if CALLBACK_EVENTS[e] then forbidden[#forbidden + 1] = "RegisterEvent " .. e end
        self.events[e] = true
    end
    function f:RegisterUnitEvent(e)
        if CALLBACK_EVENTS[e] then forbidden[#forbidden + 1] = "RegisterUnitEvent " .. e end
        self.events[e] = true
    end
    function f:SetScript(s, fn) self.scripts[s] = fn end
    function f:GetScript(s) return self.scripts[s] end
    function f:Show() self.shown = true end
    function f:Hide() self.shown = false end
    function f:SetShown(v) self.shown = v and true or false end
    function f:IsShown() return self.shown end
    function f:IsVisible() return self.shown end
    function f:SetText(t) self.text = t end
    function f:GetText() return self.text end
    function f:GetParent() return self.parent end
    function f:SetAlpha(a) self.alpha = a end
    function f:CreateFontString() return newFrame("FontString", nil, self) end
    function f:CreateTexture() return newFrame("Texture", nil, self) end
    for _, m in ipairs({ "GetLeft", "GetRight", "GetTop", "GetBottom", "GetWidth", "GetHeight", "GetStringHeight",
        "GetStringWidth", "GetFrameLevel", "GetVerticalScroll", "GetZoom" }) do
        f[m] = function() return 100 end
    end
    function f:GetEffectiveScale() return 1 end
    function f:GetScale() return 1 end
    function f:GetFrameStrata() return "MEDIUM" end
    function f:GetPoint() return "CENTER", nil, "CENTER", 0, 0 end
    function f:GetChecked() return false end
    function f:GetNumPoints() return 1 end
    function f:NumLines() return 0 end
    setmetatable(f, { __index = function(_, k)
        if type(k) == "string" and k:match("^%u") then return function() end end
    end })
    frames[#frames + 1] = f
    if name then _G[name] = f end
    return f
end
CreateFrame = function(kind, name, parent) return newFrame(kind, name, parent) end
UIParent = newFrame("Frame", "UIParent")
Minimap = newFrame("Minimap", "Minimap", UIParent)
-- The world map, open. Its own methods only read; anything that would add to it is forbidden.
WorldMapFrame = newFrame("Frame", "WorldMapFrame", UIParent)
WorldMapFrame.AddDataProvider = function() forbidden[#forbidden + 1] = "AddDataProvider" end
WorldMapFrame.AcquirePin = function() forbidden[#forbidden + 1] = "AcquirePin" end
WorldMapFrame.GetMapID = function() return SECRET end
WorldMapFrame.ScrollContainer = newFrame("ScrollFrame", nil, WorldMapFrame)
WorldMapFrame.ScrollContainer.Child = newFrame("Frame", nil, WorldMapFrame.ScrollContainer)
GameTooltip = newFrame("GameTooltip", "GameTooltip", UIParent)
SlashCmdList = {}
UISpecialFrames = {}
local blizzardTables = { SlashCmdList = SlashCmdList, UISpecialFrames = UISpecialFrames }

-- Time and timers.
local now, server = 5000, 86400 * 20500
GetTime = function() return now end
GetServerTime = function() return server end
time = function() return server end
date = os.date
local tickers, afters = {}, {}
C_Timer = {
    NewTicker = function(_, fn) local t = { fn = fn, Cancel = function(self) self.cancelled = true end }; tickers[#tickers + 1] = t; return t end,
    NewTimer = function(_, fn) local t = { fn = fn, Cancel = function(self) self.cancelled = true end }; afters[#afters + 1] = t; return t end,
    After = function(_, fn) afters[#afters + 1] = { fn = fn } end,
}

-- In combat: everything about units, money, XP, zones and positions is secret.
local function Secret() return SECRET end
local function Secret2() return SECRET, SECRET end
InCombatLockdown = function() return true end
for _, name in ipairs({ "UnitLevel", "UnitXP", "UnitXPMax", "GetXPExhaustion", "GetMoney", "UnitHealth", "UnitHealthMax",
    "UnitPower", "UnitPowerMax", "UnitExists", "UnitIsDead", "UnitIsDeadOrGhost", "UnitIsPlayer", "UnitCanAttack",
    "UnitClassification", "UnitAffectingCombat", "UnitOnTaxi", "IsResting", "IsPlayerMoving", "GetRealZoneText",
    "GetZoneText", "GetSubZoneText", "GetMinimapZoneText", "GetBindLocation", "UnitCharacterPoints", "GetUnspentTalentPoints",
    "GetPlayerFacing", "IsIndoors", "GetMirrorTimerProgress", "UnitIsAFK", "GetNumTalentTabs", "UnitRace",
    "UnitFactionGroup", "GetTaxiMapID", "IsInGroup", "IsInRaid", "UnitIsGhost", "GetCursorPosition", "GetMinimapShape",
    "UnitHealthPercent", "UnitPowerPercent", "UnitPowerType", "GetRestState", "IsSpellKnown", "GetSpellInfo",
    "GetInventoryItemLink", "GetInventoryItemID", "GetActiveTalentGroup", "UnitSex" }) do
    _G[name] = Secret
end
UnitName = Secret2
UnitClass = function() return SECRET, SECRET, SECRET end
UnitGUID = Secret
UnitPosition = function() return SECRET, SECRET, SECRET, SECRET end
IsInInstance = Secret2
GetRealmName = Secret
GetCVar = Secret
GetLocale = function() return "enUS" end
GetBuildInfo = function() return "1.60.1", "1", "Nov 2026", 16001 end
PlaySound = function() end
FlashClientIcon = function() end
SOUNDKIT = { RAID_WARNING = 1, ALARM_CLOCK_WARNING_3 = 2 }
Enum = setmetatable({}, { __index = function() return setmetatable({}, { __index = function() return 0 end }) end })
CreateVector2D = function(x, y) return { x = x, y = y, GetXY = function(self) return self.x, self.y end } end

-- C_* namespaces: every call exists and says nothing readable (secret for scalars the game hides).
local function Namespace(secretScalars)
    return setmetatable({}, { __index = function(t, k)
        local fn = secretScalars and secretScalars[k] and Secret or function() return nil end
        rawset(t, k, fn)
        return fn
    end })
end
C_Map = Namespace({ GetBestMapForUnit = true })
C_Map.GetPlayerMapPosition = function() return CreateVector2D(SECRET, SECRET) end
C_Map.GetWorldPosFromMapPos = function() return SECRET, CreateVector2D(SECRET, SECRET) end
C_Map.GetMapInfo = function() return { name = SECRET, mapID = SECRET, mapType = SECRET, parentMapID = SECRET } end
C_Map.GetMapChildrenInfo = function() return {} end
C_Minimap = Namespace({ GetViewRadius = true })
C_Reputation = Namespace({ GetNumFactions = true })
C_Reputation.GetFactionDataByIndex = function() return SECRET end
C_Item = Namespace({ GetItemCount = true })
C_Container = Namespace({ GetContainerNumSlots = true })
C_Container.GetItemCooldown = function() return SECRET, SECRET, SECRET end
C_SkillInfo = Namespace()
C_SkillInfo.GetSkillLineInfoByID = function() return SECRET end
C_ClassTalents = Namespace({ GetActiveConfigID = true })
C_Traits = Namespace()
C_SpecializationInfo = Namespace()
C_Spell = Namespace()
C_SpellBook = Namespace()
C_UnitAuras = Namespace()
C_UnitAuras.GetAuraDataByIndex = function() return SECRET end
C_VignetteInfo = Namespace()
C_VignetteInfo.GetVignettes = function() return { SECRET } end
C_QuestLog = Namespace({ GetNumQuestLogEntries = true })
C_TaxiMap = Namespace()
C_Trainer = Namespace()
C_Texture = Namespace()
C_CurveUtil = { CreateCurve = function() return { AddPoint = function() end, SetType = function() end } end }
C_Secrets = { ShouldAurasBeSecret = function() return true end }
C_SuperTrack = Namespace()
C_GossipInfo = Namespace()
UiMapPoint = { CreateFromCoordinates = function() return {} end }

-- Load both bundles in their .toc order, as build.ps1 lists them.
local MODULES = {
    { "TalentNudge", { "TalentNudge.lua" } }, { "Builds", { "Data.lua", "Builds.lua" } },
    { "TrainerNotes", { "Data.lua", "TrainerNotes.lua" } }, { "WeaponSkillWatch", { "WeaponSkillWatch.lua" } },
    { "RestGuard", { "RestGuard.lua" } }, { "LevelLog", { "LevelLog.lua" } }, { "RepWatch", { "RepWatch.lua" } },
    { "ReadyCheck", { "ReadyCheck.lua" } },
    { "Landmarks", { "Landmarks.lua" } }, { "DeathNotes", { "DeathNotes.lua", "BreathWatch.lua", "LowWarn.lua" } },
    { "RareWatch", { "RareWatch.lua" } }, { "MapPins", { "MapPins.lua", "Way.lua" } },
}
for _, module in ipairs(MODULES) do
    for _, file in ipairs(module[2]) do
        local chunk, err = loadfile(base .. "/" .. module[1] .. "/" .. file)
        assert(chunk, err)
        local ok, loadErr = pcall(chunk, module[1] == "Builds" and "ForeverCharacter" or "ForeverWorld", {})
        check(ok, "load " .. module[1] .. "/" .. file .. ": " .. tostring(loadErr))
    end
end
check(rawequal(SlashCmdList, blizzardTables.SlashCmdList), "SlashCmdList replaced")
check(#UISpecialFrames == 0, "UISpecialFrames written")

local function try(what, fn, ...)
    local ok, err = pcall(fn, ...)
    if not ok then failures[#failures + 1] = what .. ": " .. tostring(err) end
end

-- Login and every registered event, with secret arguments, a few rounds (state builds up between them).
local ORDER = { "ADDON_LOADED", "PLAYER_LOGIN", "PLAYER_ENTERING_WORLD", "PLAYER_REGEN_DISABLED" }
for _, event in ipairs(ORDER) do
    for _, f in ipairs(frames) do
        if f.events[event] and f.scripts.OnEvent then
            try(event, f.scripts.OnEvent, f, event, event == "ADDON_LOADED" and "ForeverWorld" or SECRET)
        end
    end
end
for round = 1, 3 do
    for _, f in ipairs(frames) do
        if f.scripts.OnEvent then
            for event in pairs(f.events) do
                if event ~= "PLAYER_LOGIN" and event ~= "ADDON_LOADED" and event ~= "PLAYER_REGEN_ENABLED" then
                    try(event, f.scripts.OnEvent, f, event, SECRET, SECRET, SECRET, SECRET, SECRET)
                    if event:match("^UNIT_") then
                        try(event .. " player", f.scripts.OnEvent, f, event, "player", SECRET, SECRET)
                    end
                end
            end
        end
    end
    now, server = now + 1.5, server + 2   -- server time is whole seconds
    for _, t in ipairs(tickers) do
        if not t.cancelled then try("ticker", t.fn, t) end
    end
    local pending = afters
    afters = {}
    for _, t in ipairs(pending) do
        if not t.cancelled then try("timer", t.fn, t) end
    end
    for _, f in ipairs(frames) do
        if f.scripts.OnUpdate then try("OnUpdate", f.scripts.OnUpdate, f, 0.5) end
    end
end

-- Every page and side-panel line, in combat.
ForeverHub_Receive = function() end
for key, handler in pairs(SlashCmdList) do
    for _, arg in ipairs({ "", "all", "1", "window" }) do
        try("/" .. key .. " " .. arg, handler, arg)
    end
end
for name, fn in pairs(ForeverHubStatus or {}) do
    try("status " .. name, fn)
end
for _, fn in ipairs({ "Builds_TalentPanelLines", "LevelLog_JourneyLines", "LevelLog_StatsLines", "LevelLog_TimeLines",
    "LevelLog_KillsToLevel", "LevelLog_ToSixty", "LevelLog_TargetXP", "RestGuard_CampLines" }) do
    if type(_G[fn]) == "function" then try(fn, _G[fn]) end
end
-- The end of the fight.
for _, f in ipairs(frames) do
    if f.events.PLAYER_REGEN_ENABLED and f.scripts.OnEvent then
        try("PLAYER_REGEN_ENABLED", f.scripts.OnEvent, f, "PLAYER_REGEN_ENABLED")
    end
end

-- Not a vacuous pass: every helper loaded, logged in and registered its events and pages.
local registered = 0
for _, f in ipairs(frames) do for _ in pairs(f.events) do registered = registered + 1 end end
check(registered >= 60, "events registered: " .. registered)
check(#tickers >= 2, "login tickers started: " .. #tickers)
for _, key in ipairs({ "TALENTNUDGE", "BUILDS", "TRAINERNOTES", "WEAPONSKILLWATCH", "RESTGUARD", "LEVELLOG", "REPWATCH",
    "SPELLREADY", "LANDMARKS", "DEATHNOTES", "RAREWATCH", "MAPPINS", "FOREVERWAY" }) do
    check(type(SlashCmdList[key]) == "function", "page " .. key)
end
check(type(LevelLogDB) == "table" and type(DeathNotesDB) == "table" and type(RareWatchDB) == "table", "saved data set up at login")

check(#forbidden == 0, "forbidden: " .. table.concat(forbidden, ", "))
check(#chat == 0, "chat output: " .. tostring(chat[1]))
check(#errors == 0, "errors handed to the error handler: " .. table.concat(errors, " | "))
if #failures > 0 then
    error("FAILURES (" .. #failures .. "):\n" .. table.concat(failures, "\n"))
end
say("ALL TESTS PASSED")
