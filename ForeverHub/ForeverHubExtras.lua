-- Conveniences around the hub window, all through Blizzard's own extension points:
--   * key bindings (Bindings.xml in the addon's folder calls the ForeverHub_* functions below);
--   * the game's AddOns menu by the minimap (the AddonCompartment lines in the .toc);
--   * a "Forever Hub" page in the game's Options window (Settings, canvas layout);
--   * a sound and taskbar flash for a few important pop-ups;
--   * a Hearthstone button by the side panel, which the player clicks to use the stone.
-- Nothing here acts on its own: every action starts with a key press or a click by the player.
-- No Blizzard function is replaced or hooked, and nothing is written to chat.

local _, ns = ...
local hub = type(ns) == "table" and ns.ForeverHub
if type(hub) ~= "table" or type(hub.Safe) ~= "function" then
    return
end
local Safe = hub.Safe

local GOLD, GRAY, GREEN, ORANGE = "|cffffd100", "|cff999999", "|cff33ff33", "|cffffaa66"
local HEARTHSTONE_ID = 6948
local HEARTH_SIZE = 22
-- At most one sound (and one flash) this often, however many pop-ups arrive.
local ALERT_GAP_SECONDS = 10
-- The whisper chime: short, and familiar as "something wants you".
local ALERT_SOUND_FALLBACK = 3081

local function InCombat()
    return type(InCombatLockdown) == "function" and Safe(InCombatLockdown()) == true
end

local function Attempt(fn, ...)
    local ok, err = pcall(fn, ...)
    if not ok then
        geterrorhandler()(err)
    end
    return ok
end

--------------------------------------------------------------------------------------------------
-- Key bindings. Names shown in the game's Key Bindings window, under AddOns.
--------------------------------------------------------------------------------------------------

BINDING_HEADER_FOREVERHUB = "Forever Hub"
BINDING_NAME_FOREVERHUB_TOGGLE = "Show or hide the hub window"
BINDING_NAME_FOREVERHUB_HOME = "Open the hub: Home"
BINDING_NAME_FOREVERHUB_PLACES = "Open the hub: Places"
BINDING_NAME_FOREVERHUB_REPAIR = "Pin the nearest repair vendor"
BINDING_NAME_FOREVERHUB_INN = "Pin the nearest innkeeper"
BINDING_NAME_FOREVERHUB_FLIGHT = "Pin the nearest flight master"

function ForeverHub_ToggleWindow()
    local frame = hub.GetFrame()
    if frame then
        frame:SetShown(not frame:IsShown())
    end
end

-- A page whose helper is switched off on the Manage page opens Home with a note instead.
local function OpenOrExplain(tab, prefixLines)
    if not hub.TabVisible(tab) then
        hub.OpenPage(hub.PAGE_BY_LABEL.Home,
            { ORANGE .. tostring(tab.helper) .. " is switched off. Switch it on again on the Manage page.|r" })
        return false
    end
    hub.OpenPage(tab, prefixLines)
    return true
end

function ForeverHub_OpenPage(label)
    local tab = hub.PAGE_BY_LABEL[label]
    if tab then
        OpenOrExplain(tab)
    end
end

-- Only the kinds the bindings use; Landmarks pins the nearest one it remembers and says which.
local PLACE_KINDS = { repair = true, inn = true, flight = true }

function ForeverHub_PinNearest(kind)
    local tab = hub.PAGE_BY_KEY.LANDMARKS
    if not (PLACE_KINDS[kind] and tab) then
        return
    end
    if hub.TabVisible(tab) then
        -- Same path as typing the kind on the Places page, so the answer shows in the window.
        hub.OpenPage(tab, hub.RunCommand("LANDMARKS", kind))
    else
        OpenOrExplain(tab)
    end
end

--------------------------------------------------------------------------------------------------
-- The game's AddOns menu by the minimap. The .toc names these three functions.
--------------------------------------------------------------------------------------------------

function ForeverHub_OnAddonCompartmentClick()
    ForeverHub_ToggleWindow()
end

function ForeverHub_OnAddonCompartmentEnter(_, menuButton)
    local tip = hub.Tip()
    if type(menuButton) == "table" and type(menuButton.IsObjectType) == "function" then
        tip:SetOwner(menuButton, "ANCHOR_LEFT")
    else
        tip:SetOwner(UIParent, "ANCHOR_CURSOR")
    end
    tip:SetText("Forever Hub")
    tip:AddLine("One window for all your Forever helpers: guides, quests, bags, places, pop-up history and on/off switches.", 1, 1, 1, true)
    tip:AddLine("Click to show or hide it.", 0.6, 0.6, 0.6, true)
    tip:Show()
end

function ForeverHub_OnAddonCompartmentLeave()
    hub.HideTip()
end

--------------------------------------------------------------------------------------------------
-- Alerts: a sound and a taskbar flash for the pop-ups worth looking up for.
--------------------------------------------------------------------------------------------------

local lastSoundAt, lastFlashAt
local manageAlertRows = {}
local RefreshCanvas

-- Saved as ForeverHubDB.alerts = { sound = bool, flash = bool }; both on until you switch them off.
local function AlertOption(key)
    local db = hub.GetDB()
    if type(db) ~= "table" or type(db.alerts) ~= "table" then
        return true
    end
    return db.alerts[key] ~= false
end

local function SetAlertOption(key, on)
    local db = hub.GetDB()
    if type(db) ~= "table" then
        return
    end
    if type(db.alerts) ~= "table" then
        db.alerts = {}
    end
    db.alerts[key] = on and true or false
    if hub.RefreshManage then
        hub.RefreshManage()
    end
    if RefreshCanvas then
        RefreshCanvas()
    end
end

local ALERT_OPTIONS = {
    { key = "sound", label = "Sound",
        about = "A short chime for a rare nearby, a quest ready to turn in, a spot where you died, or a zone above your level. At most one every 10 seconds." },
    { key = "flash", label = "Taskbar flash",
        about = "Flashes the game's taskbar icon for the same pop-ups, so you notice them while the game is in the background." },
}

-- QuestTracker's own "Quest complete" sound (on unless switched off on its Snd pop-up) already marks the
-- moment a quest is ready; its saved switch is only read here.
local function TrackerPlaysCompleteSound()
    if type(QuestTracker_SoundScan) ~= "function" then
        return false
    end
    local sounds = type(QuestTrackerDB) == "table" and QuestTrackerDB.sounds
    local entry = type(sounds) == "table" and sounds.complete
    if type(entry) == "table" and type(entry.on) == "boolean" then
        return entry.on
    end
    return true
end

-- Which pop-ups count. RareWatch already plays its own sound, so it only gets the flash; so does a
-- quest ready to turn in while QuestTracker plays its own sound for it.
local function AlertKind(source, text)
    local plain = text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    if source == "RareWatch" and plain:match("^Rare[%s:]") then
        return "rare", true
    elseif source == "Quests" and plain:find("Ready to turn in:", 1, true) then
        return "quest", TrackerPlaysCompleteSound()
    elseif source == "DeathNotes" and plain:match("^Careful:") then
        return "death"
    elseif source == "ZoneLevels" and plain:find("Careful!", 1, true) then
        return "zone"
    end
end

local function PlayAlertSound()
    local id = type(SOUNDKIT) == "table" and Safe(SOUNDKIT.TELL_MESSAGE) or ALERT_SOUND_FALLBACK
    local play = PlaySound or (C_Sound and C_Sound.PlaySound)
    if type(play) == "function" then
        pcall(play, id)
    end
end

-- Called by the hub for every pop-up it shows (not for page text, nor for repeats it holds back).
function hub.OnPopup(source, text)
    if type(source) ~= "string" or type(text) ~= "string" then
        return
    end
    local kind, playsOwnSound = AlertKind(source, text)
    if not kind then
        return
    end
    local now = GetTime()
    if AlertOption("flash") and type(FlashClientIcon) == "function" and not (lastFlashAt and now - lastFlashAt < ALERT_GAP_SECONDS) then
        lastFlashAt = now
        pcall(FlashClientIcon)
    end
    if AlertOption("sound") and not (lastSoundAt and now - lastSoundAt < ALERT_GAP_SECONDS) then
        lastSoundAt = now
        -- A rare's own sound still counts, so another chime doesn't follow right after it.
        if not playsOwnSound then
            PlayAlertSound()
        end
    end
end

-- The Alerts group at the bottom of the Manage page; same look as the helper rows above it.
function hub.BuildManageAlerts(parent, y)
    local title = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, y - 4)
    title:SetText("Alerts  " .. GRAY .. "(sound and taskbar flash)|r")
    y = y - 28
    for _, option in ipairs(ALERT_OPTIONS) do
        local row = { option = option }
        row.name = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        row.name:SetPoint("TOPLEFT", parent, "TOPLEFT", 12, y)
        row.name:SetText(option.label)
        row.about = parent:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        row.about:SetPoint("TOPLEFT", parent, "TOPLEFT", 12, y - 15)
        row.about:SetPoint("RIGHT", parent, "RIGHT", -130, 0)
        row.about:SetJustifyH("LEFT")
        row.about:SetWordWrap(false)
        row.about:SetText(option.about)
        row.switch = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
        row.switch:SetSize(56, 20)
        row.switch:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -66, y - 4)
        row.switch:SetScript("OnClick", function()
            SetAlertOption(option.key, not AlertOption(option.key))
        end)
        row.switch:SetScript("OnEnter", function(self)
            hub.ShowButtonTip(self, option.label, option.about)
        end)
        row.switch:SetScript("OnLeave", hub.HideTip)
        manageAlertRows[#manageAlertRows + 1] = row
        y = y - 36
    end
    return y - 6
end

function hub.RefreshManageAlerts()
    for _, row in ipairs(manageAlertRows) do
        local on = AlertOption(row.option.key)
        row.switch:SetText(on and (GREEN .. "On|r") or (GRAY .. "Off|r"))
    end
end

--------------------------------------------------------------------------------------------------
-- A "Forever Hub" page in the game's Options window (AddOns tab). Our own frame on a canvas
-- layout: a button to open the hub, the alert switches, and the same helper switches as Manage.
--------------------------------------------------------------------------------------------------

local canvas
local canvasRows = {}
local SETTINGS_ROW_HEIGHT, SETTINGS_COLUMN_WIDTH = 20, 300

local function SwitchText(on)
    return on and (GREEN .. "On|r") or (GRAY .. "Off|r")
end

RefreshCanvas = function()
    for _, row in ipairs(canvasRows) do
        local on
        if row.helper then
            on = not ForeverHub_IsOff(row.helper.name)
        elseif row.get then
            local ok, value = pcall(row.get)
            on = ok and value == true
        else
            on = AlertOption(row.option.key)
        end
        row.button:SetText(SwitchText(on))
        row.label:SetText((on and "|cffffffff" or GRAY) .. row.text .. "|r")
    end
end

function hub.OnHelperSwitched()
    RefreshCanvas()
end

local function CanvasRow(x, y, text, about, onClick)
    local row = { text = text }
    row.button = CreateFrame("Button", nil, canvas, "UIPanelButtonTemplate")
    row.button:SetSize(46, 18)
    row.button:SetPoint("TOPLEFT", canvas, "TOPLEFT", x, y)
    row.button:SetScript("OnClick", onClick)
    row.button:SetScript("OnEnter", function(self)
        hub.ShowButtonTip(self, text, about)
    end)
    row.button:SetScript("OnLeave", hub.HideTip)
    row.label = canvas:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.label:SetPoint("LEFT", row.button, "RIGHT", 6, 0)
    row.label:SetJustifyH("LEFT")
    canvasRows[#canvasRows + 1] = row
    return row
end

local function BuildCanvas()
    -- No parent: the Options window takes it over and shows it only on its own page.
    canvas = CreateFrame("Frame", "ForeverHubSettingsCanvas")
    canvas:Hide()
    canvas.name = "Forever Hub"

    local title = canvas:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", canvas, "TOPLEFT", 16, -16)
    title:SetText("Forever Hub")
    local about = canvas:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    about:SetPoint("TOPLEFT", canvas, "TOPLEFT", 16, -42)
    about:SetWidth(SETTINGS_COLUMN_WIDTH * 2 - 20)
    about:SetJustifyH("LEFT")
    about:SetWordWrap(true)
    about:SetText("One window and on-screen pop-ups for all your Forever helpers, so nothing goes through chat. "
        .. "The switches here are the same as on the hub's Manage page.")

    local open = CreateFrame("Button", nil, canvas, "UIPanelButtonTemplate")
    open:SetSize(180, 24)
    open:SetPoint("TOPLEFT", canvas, "TOPLEFT", 16, -84)
    open:SetText("Open Forever Hub")
    open:SetScript("OnClick", function()
        local frame = hub.GetFrame()
        if frame then
            frame:Show()
            frame:Raise()
        end
    end)

    local y = -122
    local alertsTitle = canvas:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    alertsTitle:SetPoint("TOPLEFT", canvas, "TOPLEFT", 16, y)
    alertsTitle:SetText("Alerts")
    y = y - 20
    for index, option in ipairs(ALERT_OPTIONS) do
        local row = CanvasRow(16 + (index - 1) * SETTINGS_COLUMN_WIDTH, y, option.label, option.about, function()
            SetAlertOption(option.key, not AlertOption(option.key))
        end)
        row.option = option
    end
    y = y - SETTINGS_ROW_HEIGHT - 14

    local helpersTitle = canvas:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    helpersTitle:SetPoint("TOPLEFT", canvas, "TOPLEFT", 16, y)
    helpersTitle:SetText("Helpers  " .. GRAY .. "(Off hides a helper's pages, panel lines, pop-ups and its own frames)|r")
    y = y - 20
    -- Two columns, in the Manage page's order.
    local switchable = {}
    for _, helper in ipairs(hub.HELPERS) do
        if not helper.noSwitch then
            switchable[#switchable + 1] = helper
        end
    end
    local perColumn = math.ceil(#switchable / 2)
    for index, helper in ipairs(switchable) do
        local column = index > perColumn and 1 or 0
        local line = column == 1 and index - perColumn - 1 or index - 1
        local row = CanvasRow(16 + column * SETTINGS_COLUMN_WIDTH, y - line * SETTINGS_ROW_HEIGHT, helper.name, helper.about, function()
            hub.SetHelperOff(helper, not ForeverHub_IsOff(helper.name))
        end)
        row.helper = helper
    end
    y = y - perColumn * SETTINGS_ROW_HEIGHT - 14

    -- A helper's own switches, when it offers some (ForeverHubOptions[name] = { title, rows = { label,
    -- about, get, set } }). Only helpers that are loaded have an entry; listed by name.
    local names = {}
    for name, options in pairs(type(ForeverHubOptions) == "table" and ForeverHubOptions or {}) do
        if type(name) == "string" and type(options) == "table" and type(options.rows) == "table" then
            names[#names + 1] = name
        end
    end
    table.sort(names)
    for _, name in ipairs(names) do
        local options = ForeverHubOptions[name]
        local heading = canvas:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        heading:SetPoint("TOPLEFT", canvas, "TOPLEFT", 16, y)
        heading:SetText(tostring(options.title or name) .. "  " .. GRAY .. "(also on its page in the hub)|r")
        y = y - 20
        local count = 0
        for _, option in ipairs(options.rows) do
            if type(option) == "table" and type(option.get) == "function" and type(option.set) == "function" then
                local column = count % 2
                local line = math.floor(count / 2)
                local row = CanvasRow(16 + column * SETTINGS_COLUMN_WIDTH, y - line * SETTINGS_ROW_HEIGHT,
                    tostring(option.label), tostring(option.about or ""), function()
                        local ok, on = pcall(option.get)
                        Attempt(option.set, not (ok and on == true))
                        RefreshCanvas()
                    end)
                row.get = option.get
                count = count + 1
            end
        end
        y = y - math.ceil(count / 2) * SETTINGS_ROW_HEIGHT - 14
    end
    canvas:SetScript("OnShow", RefreshCanvas)
    RefreshCanvas()
end

-- True once the page is in the Options window. Any missing piece of the Settings API leaves it out.
-- Only out of combat: a /reload in combat waits for combat to end, so the Options window's own code
-- never meets our category while the game is locked down.
local settingsCategory, settingsPending
local function RegisterSettings()
    if settingsCategory then
        return true
    end
    if InCombat() then
        settingsPending = true
        return false
    end
    settingsPending = false
    if not (type(Settings) == "table" and type(Settings.RegisterCanvasLayoutCategory) == "function"
        and type(Settings.RegisterAddOnCategory) == "function") then
        return false
    end
    if not canvas then
        BuildCanvas()
    end
    local ok, category = pcall(Settings.RegisterCanvasLayoutCategory, canvas, "Forever Hub")
    if not ok then
        geterrorhandler()(category)
        return false
    end
    if not category then
        return false
    end
    local added, err = pcall(Settings.RegisterAddOnCategory, category)
    if not added then
        geterrorhandler()(err)
        return false
    end
    settingsCategory = category
    return true
end

--------------------------------------------------------------------------------------------------
-- Hearthstone button: our own secure button, placed at the side panel's top right. Its attributes
-- are set once, when it's made out of combat; showing, hiding and moving it also wait for the end of
-- combat. It isn't a child of the panel, so the panel itself stays free to move and close in combat.
--------------------------------------------------------------------------------------------------

local hearth, hearthPending

-- The first of these functions that exists and answers; the list may have gaps where one is missing.
local function CallFirst(candidates, ...)
    for index = 1, 3 do
        local fn = candidates[index]
        if type(fn) == "function" then
            local ok, a, b, c = pcall(fn, ...)
            if ok then
                return true, Safe(a), Safe(b), Safe(c)
            end
        end
    end
    return false
end

local function HearthCount()
    local ok, count = CallFirst({ C_Item and C_Item.GetItemCount, GetItemCount }, HEARTHSTONE_ID)
    return ok and tonumber(count) or 0
end

-- Seconds until the stone is ready: 0 when ready, nil when the game won't say.
local function HearthCooldown()
    local ok, start, duration = CallFirst({ C_Container and C_Container.GetItemCooldown, C_Item and C_Item.GetItemCooldown,
        GetItemCooldown }, HEARTHSTONE_ID)
    if not ok or type(start) ~= "number" or type(duration) ~= "number" then
        return nil
    end
    -- A global cooldown of a second or so isn't worth mentioning.
    if start <= 0 or duration <= 2 then
        return 0
    end
    return math.max(start + duration - GetTime(), 0)
end

local function FormatWait(seconds)
    local minutes = math.ceil(seconds / 60)
    if minutes >= 60 then
        return string.format("%dh %dm", math.floor(minutes / 60), minutes % 60)
    end
    return string.format("%dm", math.max(minutes, 1))
end

local function HearthTooltip(self)
    local tip = hub.Tip()
    tip:SetOwner(self, "ANCHOR_RIGHT")
    tip:SetText("Hearthstone")
    local home = type(GetBindLocation) == "function" and Safe(GetBindLocation())
    tip:AddLine("Home: " .. (type(home) == "string" and home ~= "" and home or "unknown"), 1, 1, 1)
    local wait = HearthCooldown()
    if wait == nil then
        tip:AddLine(GRAY .. "Cooldown unknown.|r", 1, 1, 1)
    elseif wait > 0 then
        tip:AddLine(ORANGE .. "Ready in " .. FormatWait(wait) .. "|r", 1, 1, 1)
    else
        tip:AddLine(GREEN .. "Ready|r", 1, 1, 1)
    end
    tip:AddLine("Click to use your Hearthstone.", 0.6, 0.6, 0.6, true)
    tip:Show()
end

local function CreateHearth()
    if hearth or InCombat() then
        return
    end
    hearth = CreateFrame("Button", "ForeverHubHearthButton", UIParent, "SecureActionButtonTemplate")
    hearth:SetSize(HEARTH_SIZE, HEARTH_SIZE)
    hearth:RegisterForClicks("AnyUp", "AnyDown")
    hearth:SetAttribute("type", "item")
    hearth:SetAttribute("item", "item:" .. HEARTHSTONE_ID)
    local icon = hearth:CreateTexture(nil, "ARTWORK")
    icon:SetAllPoints(hearth)
    local _, texture = CallFirst({ C_Item and C_Item.GetItemIconByID }, HEARTHSTONE_ID)
    icon:SetTexture(texture or "Interface\\Icons\\INV_Misc_Rune_01")
    hearth:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
    hearth:SetScript("OnEnter", HearthTooltip)
    hearth:SetScript("OnLeave", hub.HideTip)
    hearth:Hide()
end

-- Shows the button by the panel when you have a stone; in combat it waits for combat to end.
local function SyncHearth()
    if InCombat() then
        hearthPending = true
        return
    end
    hearthPending = false
    CreateHearth()
    if not hearth then
        return
    end
    local panel = hub.GetPanel()
    local show = panel ~= nil and panel:IsShown() and HearthCount() > 0
    if show then
        local right, top = Safe(panel:GetRight()), Safe(panel:GetTop())
        if type(right) == "number" and type(top) == "number" then
            hearth:ClearAllPoints()
            -- Right edge, under the Details button and above Restart.
            hearth:SetPoint("TOPRIGHT", UIParent, "BOTTOMLEFT", right - 8, top - 26)
            hearth:SetFrameStrata(panel:GetFrameStrata() or "MEDIUM")
            hearth:SetFrameLevel((Safe(panel:GetFrameLevel()) or 1) + 5)
        else
            show = false
        end
    end
    hearth:SetShown(show)
end
hub.SyncHearth = SyncHearth

local hookedPanel
local function FollowPanel()
    local panel = hub.GetPanel()
    if not panel or hookedPanel == panel or type(panel.HookScript) ~= "function" then
        return
    end
    hookedPanel = panel
    -- The panel is the hub's own frame; these only watch it.
    for _, script in ipairs({ "OnShow", "OnHide", "OnDragStop" }) do
        panel:HookScript(script, function()
            Attempt(SyncHearth)
        end)
    end
end

--------------------------------------------------------------------------------------------------
-- Start-up and events.
--------------------------------------------------------------------------------------------------

function hub.OnStart()
    Attempt(RegisterSettings)
    Attempt(FollowPanel)
    Attempt(SyncHearth)
end

local events = CreateFrame("Frame")
for _, name in ipairs({ "PLAYER_REGEN_ENABLED", "BAG_UPDATE_DELAYED", "PLAYER_ENTERING_WORLD" }) do
    events:RegisterEvent(name)
end
events:SetScript("OnEvent", function(_, event)
    if not hub.GetDB() then
        return
    end
    if event == "PLAYER_REGEN_ENABLED" then
        if settingsPending then
            Attempt(RegisterSettings)
        end
        if hearthPending or not hearth then
            Attempt(SyncHearth)
        end
    else
        Attempt(SyncHearth)
    end
end)

-- For the tests: what was registered and the hearth button.
hub.extrasState = function()
    return { settingsCategory = settingsCategory, settingsPending = settingsPending, canvas = canvas, hearth = hearth, hearthPending = hearthPending,
        canvasRows = canvasRows, manageAlertRows = manageAlertRows }
end
