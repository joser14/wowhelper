-- ForeverHub navigation: Home page, Manage page (on/off, addon toggles, reload), grouped sidebar.
local base = ADDON_PATH
local chat, timers, frames, handled = {}, {}, {}, {}
ALLFONTS = {}
local tipLines, tipTitle = {}, nil
local function newRegion(kind, name)
    local r = { kind = kind, name = name, shown = true, scripts = {}, text = "", height = 0, points = {} }
    function r:SetText(t) self.text = t; if self.fs then self.fs.text = t end end
    function r:GetText() return self.text end
    function r:SetScript(s, f) self.scripts[s] = f end
    function r:Show() self.shown = true; if self.scripts.OnShow then self.scripts.OnShow(self) end end
    function r:Hide() self.shown = false end
    function r:SetShown(v) if v then self:Show() else self:Hide() end end
    function r:IsShown() return self.shown end
    function r:GetStringHeight() return self.strHeight or 14 end
    function r:SetHeight(h) self.height = h end
    function r:GetHeight() return self.height end
    function r:ClearAllPoints() self.points = {} end
    function r:SetPoint(...) self.points[#self.points + 1] = { ... } end
    function r:GetPoint() return "CENTER", nil, "CENTER", 1, 2 end
    function r:CreateFontString() local fs = newRegion("font"); ALLFONTS[#ALLFONTS + 1] = fs; return fs end
    function r:CreateTexture() return newRegion("texture") end
    function r:GetFontString()
        if not self.fs then self.fs = newRegion("font"); self.fs.text = self.text end
        return self.fs
    end
    return setmetatable(r, { __index = function(_, k)
        if type(k) == "string" and k:match("^%u") then return function() end end
    end })
end
CreateFrame = function(kind, name)
    local f = newRegion(kind, name)
    frames[#frames + 1] = f
    if name then _G[name] = f end
    if kind == "GameTooltip" then
        f.shown = false
        function f:SetOwner() tipLines = {}; tipTitle = nil end
        function f:SetText(t) tipTitle = t end
        function f:AddLine(t) tipLines[#tipLines + 1] = t end
    end
    return f
end
DEFAULT_CHAT_FRAME = { AddMessage = function(_, t) chat[#chat + 1] = t end }
UIParent = newRegion("Frame"); Minimap = newRegion("Frame")
GameTooltip = setmetatable({}, { __index = function(_, k) error("GameTooltip." .. tostring(k) .. " used") end })
UISpecialFrames = {}
SlashCmdList = {}
local now = 1000
GetTime = function() return now end
local tick
C_Timer = { After = function(_, fn) timers[#timers + 1] = fn end, NewTicker = function(_, fn) tick = fn end }
issecretvalue = function() return false end
geterrorhandler = function() return function(e) handled[#handled + 1] = tostring(e) end end
InCombatLockdown = function() return false end
UnitLevel = function() return 10 end
UnitXP = function() return 100 end
UnitXPMax = function() return 1000 end
UnitName = function() return "Tester" end
GetXPExhaustion = function() return 0 end
GetMoney = function() return 100 end
local reloads = 0
ReloadUI = function() reloads = reloads + 1 end
local enabled = { ["!ForeverHub"] = true, ForeverGuides = true, ForeverQuests = true, ForeverBags = true, ForeverCharacter = true, ForeverWorld = true }
local addonCalls = {}
C_AddOns = {
    IsAddOnLoaded = function(n) return n ~= "ForeverQuests", n ~= "ForeverQuests" end,
    DoesAddOnExist = function(n) return enabled[n] ~= nil end,
    GetAddOnEnableState = function(n) return enabled[n] and 2 or 0 end,
    DisableAddOn = function(n, c) addonCalls[#addonCalls + 1] = "off " .. n .. " " .. tostring(c); enabled[n] = false end,
    EnableAddOn = function(n, c) addonCalls[#addonCalls + 1] = "on " .. n .. " " .. tostring(c); enabled[n] = true end,
}

-- Blizzard's own /readycheck must stay untouched; the helper uses SPELLREADY.
local blizzardReadyCheck = function() end
SlashCmdList.READYCHECK = blizzardReadyCheck
SlashCmdList.SPELLREADY = function() ForeverHub_Receive("SpellReady", "spells page") end
SlashCmdList.LANDMARKS = function() ForeverHub_Receive("Landmarks", "places page") end
local deathRows = { { text = "Died here before", page = "Deaths" } }
ForeverHubStatus = { DeathNotes = function() return deathRows end }

local hub
do
    local n = #frames
    assert(loadfile(base .. "/ForeverHub/ForeverHub.lua"))("ForeverHub", {})
    hub = frames[n + 1]
end
assert(ForeverHub_IsOff("Landmarks") == false, "nothing off before login")
hub.scripts.OnEvent(hub, "PLAYER_LOGIN")
for _, fn in ipairs(timers) do fn() end
timers = {}
assert(SlashCmdList.READYCHECK == blizzardReadyCheck, "Blizzard's /readycheck not wrapped")
assert(SlashCmdList.SPELLREADY ~= nil, "Ready check command still there")

local function buttons(text)
    local out = {}
    for _, f in ipairs(frames) do
        if f.kind == "Button" and f.text == text then out[#out + 1] = f end
    end
    return out
end
local function nav(text) return buttons(text)[1] end
local function click(b) b.scripts.OnClick(b) end
local function fonts()
    local out = {}
    for _, fs in ipairs(ALLFONTS) do out[#out + 1] = tostring(fs.text) end
    return table.concat(out, "\n")
end
local function has(text) return fonts():find(text, 1, true) ~= nil end
local function rowShown(text)
    for _, f in ipairs(frames) do
        if f.kind == "Button" and f.shown and rawget(f, "fullText") and f.text:find(text, 1, true) then return true end
    end
end

-- 1. Home is first and lists every helper, grouped.
ForeverHubFrame:Show()
assert(has("How to use the hub"), "home shown on open")
local helpers = { "LevelGuide", "ProfessionCap", "ProfessionGuide", "GoldGoal", "GoldGuide", "Dungeons", "QuestTracker", "QuestCheck",
    "ZoneLevels", "ItemAdvisor", "BagCheck", "ItemFinder", "PriceMemory", "FoodCheck", "SupplyWatch", "DurabilityWatch", "TalentNudge",
    "TrainerNotes", "WeaponSkillWatch", "RestGuard", "RepWatch", "LevelLog", "SpellReady", "Landmarks", "DeathNotes", "RareWatch",
    "MapPins", "ForeverHelper", "ErrorLog", "QuestMobs", "WindowBadges", "Builds" }
for _, name in ipairs(helpers) do
    assert(has("|cffffffff" .. name .. "|r"), "home lists " .. name)
end
assert(has("Page: Places") and has("Page: Ready check"), "home says which page")
assert(has("Page: Map pins") and nav("Map pins"), "MapPins has its page in World")
for _, title in ipairs({ "Guides", "Quests", "Bags & items", "Character", "World", "Hub" }) do
    assert(nav("- " .. title), "sidebar group " .. title)
end

-- 2. Sidebar tooltip says what a page does, in the hub's own tooltip.
nav("Places").scripts.OnEnter(nav("Places"))
assert(tipTitle == "Places" and tipLines[1]:find("vendors", 1, true), "page tooltip: " .. tostring(tipLines[1]))

-- 3. Manage page: switching a helper off.
click(nav("Manage"))
local function switchFor(name)
    for _, f in ipairs(frames) do
        if f.kind == "Button" and (f.text:find("On|r", 1, true) or f.text:find("Off|r", 1, true)) then
            f.scripts.OnEnter(f)
            if tipTitle == name then return f end
        end
    end
end
local function openAfter(switch)
    local seen = false
    for _, f in ipairs(frames) do
        if f == switch then seen = true elseif seen and f.text == "Open" then return f end
    end
end
local landmarks = switchFor("Landmarks")
assert(landmarks and landmarks.text:find("On", 1, true), "Landmarks switch starts On")
assert(switchFor("LevelGuide") == nil, "no switch for a helper with its own window")
click(landmarks)
assert(ForeverHub_IsOff("Landmarks") and ForeverHubDB.off.Landmarks == true, "saved as off")
assert(landmarks.text:find("Off", 1, true), "switch reads Off")
assert(not nav("Places").shown, "its page leaves the sidebar")
assert(not openAfter(landmarks).shown, "no Open button while off")
-- Its pop-ups are dropped: no toast, no history.
local toastsBefore = 0
for _, f in ipairs(frames) do if f.message then toastsBefore = toastsBefore + 1 end end
ForeverHub_Receive("Landmarks", "landmark pop-up")
ForeverHub_Receive("Quests", "tracker pop-up")
local toastsAfter = 0
for _, f in ipairs(frames) do if f.message then toastsAfter = toastsAfter + 1 end end
assert(toastsAfter == toastsBefore + 1, "only the tracker pop-up shows")
click(switchFor("QuestTracker"))
ForeverHub_Receive("Quests", "second tracker pop-up")
click(nav("Pop-up history"))
assert(has("tracker pop-up") and not has("landmark pop-up") and not has("second tracker pop-up"), "off pop-ups dropped by source name")
-- Its page still draws when asked for directly (typed command), so nothing breaks.
SlashCmdList.LANDMARKS("")
assert(has("places page"), "page still renders")
-- Status rows are skipped.
hub.scripts.OnEvent(hub, "BAG_UPDATE_DELAYED"); tick()
assert(rowShown("Died here before"), "status row while on")
click(nav("Manage"))
click(switchFor("DeathNotes"))
tick()
assert(not rowShown("Died here before"), "status row skipped while off")
click(switchFor("DeathNotes"))
tick()
assert(rowShown("Died here before"), "status row back when on")
-- Builds' "take X next" row replaces TalentNudge's unspent-points row; TalentNudge's shows when Builds has none.
local buildsRows
ForeverHubStatus.TalentNudge = function() return { { text = "Spend 2 talent point(s)", page = "Talents" } } end
ForeverHubStatus.Builds = function() return buildsRows end
hub.scripts.OnEvent(hub, "BAG_UPDATE_DELAYED"); tick()
assert(rowShown("Spend 2 talent"), "TalentNudge row when Builds has none")
buildsRows = { { text = "|cff88bbeeTalent|r take Deflection next", page = "Builds" } }
hub.scripts.OnEvent(hub, "BAG_UPDATE_DELAYED"); tick()
assert(rowShown("take Deflection next") and not rowShown("Spend 2 talent"), "Builds row replaces TalentNudge's")
click(switchFor("Builds"))
hub.scripts.OnEvent(hub, "BAG_UPDATE_DELAYED"); tick()
assert(rowShown("Spend 2 talent") and not rowShown("take Deflection next"), "Builds off: TalentNudge row back")
click(switchFor("Builds"))
ForeverHubStatus.TalentNudge, ForeverHubStatus.Builds = nil, nil
hub.scripts.OnEvent(hub, "BAG_UPDATE_DELAYED"); tick()
-- Back on.
click(switchFor("Landmarks"))
assert(not ForeverHub_IsOff("Landmarks") and nav("Places").shown, "on again shows the page")
-- Open jumps to the helper's page.
click(openAfter(switchFor("Landmarks")))
assert(has("Type a kind to pin the nearest"), "Open goes to Places")
-- The Rares page sits in World.
assert(nav("Rares") and nav("Rares").shown, "Rares page in the sidebar")

-- 4. Folding a group hides its pages and is saved.
click(nav("- World"))
assert(ForeverHubDB.collapsed.world == true, "fold saved")
assert(not nav("Places").shown and not nav("Deaths").shown and not nav("Rares").shown, "folded pages hidden")
assert(nav("Quests").shown, "other groups untouched")
local worldHeader
for _, f in ipairs(frames) do if f.kind == "Button" and f.text:find("^%+ World") then worldHeader = f end end
assert(worldHeader, "header shows it's folded")
click(worldHeader)
assert(ForeverHubDB.collapsed.world == nil and nav("Places").shown, "unfolded")

-- 5. Reload needs a second click within five seconds.
click(nav("Manage"))
local reload = nav("Reload now")
click(reload)
assert(reloads == 0 and reload.text == "Click again to reload", "first click only asks")
now = now + 2
click(reload)
assert(reloads == 1, "second click reloads")
click(reload)
now = now + 6
for _, fn in ipairs(timers) do fn() end
timers = {}
assert(reload.text == "Reload now", "asks again after the wait")
click(reload)
assert(reloads == 1, "a late second click doesn't reload")

-- 6. Whole-addon toggles: never for the hub's own addon.
local toggles = buttons("Turn off whole addon (after reload)")
local shownToggles = 0
for _, b in ipairs(toggles) do if b.shown then shownToggles = shownToggles + 1 end end
assert(shownToggles == 5, "five addons can be switched, not the hub: " .. shownToggles)
assert(has("Not loaded; turns on after you reload"), "ForeverQuests shows as not loaded")
local worldToggle
for _, b in ipairs(toggles) do b.scripts.OnEnter(b); if tipTitle == "ForeverWorld" then worldToggle = b end end
click(worldToggle)
assert(addonCalls[1] == "off ForeverWorld Tester", "disabled for this character: " .. tostring(addonCalls[1]))
assert(worldToggle.text == "Turn on whole addon (after reload)", "button flips")
assert(has("Loaded now; off after you reload"), "status says off after reload")
click(worldToggle)
assert(addonCalls[2] == "on ForeverWorld Tester", "enabled again")

-- 7. Without C_AddOns the controls hide and nothing errors.
C_AddOns = nil
click(nav("Home"))
click(nav("Manage"))
for _, b in ipairs(frames) do
    if b.kind == "Button" and b.text:find("whole addon", 1, true) then assert(not b.shown, "toggle hidden") end
end
assert(reload.shown, "reload still offered")

assert(#chat == 0, "no chat")
assert(#handled == 0, "no errors: " .. table.concat(handled, "|"))
print("ALL TESTS PASSED")
