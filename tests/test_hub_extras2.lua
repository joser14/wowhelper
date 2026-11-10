-- ForeverHubExtras.lua: key bindings, the AddOns menu entry, the Options page, alerts, the Hearthstone button.
local base = ADDON_PATH
local realPrint = print
local frames, timers, handled, chat
local combat, now = false, 1000
local blocked = {}
local tipLines = {}

local function newRegion(kind, name, template)
    local r = { kind = kind, name = name, template = template, shown = true, scripts = {}, hooks = {}, text = "",
        height = 0, points = {}, attrs = {} }
    local secure = template == "SecureActionButtonTemplate"
    local function guard(what)
        if secure and combat then
            blocked[#blocked + 1] = what
            error("ADDON_ACTION_BLOCKED " .. what)
        end
    end
    function r:SetText(t) self.text = t end
    function r:GetText() return self.text end
    function r:SetScript(s, f) self.scripts[s] = f end
    function r:HookScript(s, f) self.hooks[s] = self.hooks[s] or {}; table.insert(self.hooks[s], f) end
    local function fire(self, s)
        if self.scripts[s] then self.scripts[s](self) end
        for _, f in ipairs(self.hooks[s] or {}) do f(self) end
    end
    r.fire = fire
    function r:Show() guard("Show"); self.shown = true; fire(self, "OnShow") end
    function r:Hide() guard("Hide"); self.shown = false; fire(self, "OnHide") end
    function r:SetShown(v) if v then self:Show() else self:Hide() end end
    function r:IsShown() return self.shown end
    function r:GetStringHeight() return 14 end
    function r:SetHeight(h) self.height = h end
    function r:GetHeight() return self.height end
    function r:ClearAllPoints() guard("ClearAllPoints"); self.points = {} end
    function r:SetPoint(...) guard("SetPoint"); self.points[#self.points + 1] = { ... } end
    function r:GetPoint() return "CENTER", nil, "CENTER", 1, 2 end
    function r:GetRight() return 300 end
    function r:GetTop() return 700 end
    function r:GetFrameLevel() return 3 end
    function r:GetFrameStrata() return "MEDIUM" end
    function r:SetAttribute(k, v) guard("SetAttribute"); self.attrs[k] = v end
    function r:RegisterEvent(e) self.events = self.events or {}; self.events[e] = true end
    function r:CreateFontString() return newRegion("font") end
    function r:CreateTexture() return newRegion("texture") end
    function r:GetFontString() if not self.fs then self.fs = newRegion("font") end return self.fs end
    return setmetatable(r, { __index = function(_, k)
        if type(k) == "string" and k:match("^%u") then return function() end end
    end })
end

local hearthCount, cooldown = 1, { 0, 0, 1 }
local settingsCalls
local SECRET = {}

-- A fresh game: globals set up, both hub files loaded, PLAYER_LOGIN sent. Returns the shared table.
local function Setup(opts)
    opts = opts or {}
    frames, timers, handled, chat, blocked = {}, {}, {}, {}, {}
    combat, now = opts.combat or false, 1000
    CreateFrame = function(kind, name, parent, template)
        local f = newRegion(kind, name, template)
        frames[#frames + 1] = f
        if name then _G[name] = f end
        if kind == "GameTooltip" then
            f.shown = false
            function f:SetOwner(owner) tipLines = {}; self.owner = owner end
            function f:SetText(t) tipLines[#tipLines + 1] = t end
            function f:AddLine(t) tipLines[#tipLines + 1] = t end
        end
        return f
    end
    DEFAULT_CHAT_FRAME = { AddMessage = function(_, t) chat[#chat + 1] = t end }
    print = function(...) chat[#chat + 1] = table.concat({ ... }, " ") end
    UIParent = newRegion("Frame"); Minimap = newRegion("Frame")
    GameTooltip = setmetatable({}, { __index = function(_, k) error("GameTooltip." .. tostring(k) .. " used") end })
    UISpecialFrames = {}
    SlashCmdList = {}
    GetTime = function() return now end
    C_Timer = { After = function(_, fn) timers[#timers + 1] = fn end, NewTicker = function() end }
    issecretvalue = function(v) return v == SECRET end
    geterrorhandler = function() return function(e) handled[#handled + 1] = tostring(e) end end
    NUM_TOTAL_EQUIPPED_BAG_SLOTS = 0
    C_Container = { GetContainerNumSlots = function() return 0 end, GetContainerItemInfo = function() end,
        GetItemCooldown = function(id) assert(id == 6948); return cooldown[1], cooldown[2], cooldown[3] end }
    C_Item = { GetItemCount = function(id) assert(id == 6948); return hearthCount end, GetItemIconByID = function() return 134414 end }
    C_CVar = { SetCVar = function() end }
    UnitLevel = function() return 10 end
    UnitXP = function() return 100 end
    UnitXPMax = function() return 1000 end
    GetXPExhaustion = function() return 0 end
    GetMoney = function() return 500 end
    GetBindLocation = function() return opts.secretHome and SECRET or "Goldshire" end
    InCombatLockdown = function() return combat end
    SOUNDKIT = { TELL_MESSAGE = 3081, RAID_WARNING = 8959 }
    ForeverHubDB = opts.db
    settingsCalls = {}
    if opts.settings then
        Settings = {
            RegisterCanvasLayoutCategory = function(frame, name)
                settingsCalls[#settingsCalls + 1] = { "canvas", frame, name }
                return { GetID = function() return 77 end }
            end,
            RegisterAddOnCategory = function(category) settingsCalls[#settingsCalls + 1] = { "addon", category } end,
        }
    elseif opts.partialSettings then
        Settings = { RegisterCanvasLayoutCategory = function() error("must not be called without RegisterAddOnCategory") end }
    else
        Settings = nil
    end
    FlashClientIcon = opts.noFlash and nil or function() FLASHES = (FLASHES or 0) + 1 end
    PlaySound = function(id) SOUNDS = SOUNDS or {}; SOUNDS[#SOUNDS + 1] = id end
    FLASHES, SOUNDS = 0, {}
    SlashCmdList.LANDMARKS = function(arg)
        if arg ~= "" then LANDMARK_ARGS[#LANDMARK_ARGS + 1] = arg end
        ForeverHub_Receive("Landmarks", "Pinned the nearest " .. arg .. ".")
    end
    LANDMARK_ARGS = {}

    local snapshot = opts.snapshot and opts.snapshot() or nil
    local ns = {}
    local n = #frames
    assert(loadfile(base .. "/ForeverHub/ForeverHub.lua"))("!ForeverHub", ns)
    local hubEvents = frames[n + 1]
    local m = #frames
    assert(loadfile(base .. "/ForeverHub/ForeverHubExtras.lua"))("!ForeverHub", ns)
    local extraEvents = frames[m + 1]
    hubEvents.scripts.OnEvent(hubEvents, "PLAYER_LOGIN")
    for _, fn in ipairs(timers) do fn() end
    timers = {}
    return ns.ForeverHub, hubEvents, extraEvents, snapshot
end

-- Every global function, and every function in Blizzard's tables, before anything of ours loads.
local function Snapshot()
    local seen = {}
    for key, value in pairs(_G) do
        if type(value) == "function" then
            seen[key] = value
        elseif type(value) == "table" and (key:match("^C_") or key == "Settings") then
            for inner, fn in pairs(value) do
                if type(fn) == "function" then seen[key .. "." .. inner] = fn end
            end
        end
    end
    return seen
end

------------------------------------------------------------------------------------------------
-- 1. No Blizzard function replaced, and only our own globals added.
------------------------------------------------------------------------------------------------
do
    local hub, _, _, before = Setup({ settings = true, snapshot = Snapshot })
    local after = Snapshot()
    for key, fn in pairs(before) do
        assert(after[key] == fn, "global function replaced: " .. key)
    end
    for key in pairs(after) do
        if not before[key] then
            assert(key:match("^ForeverHub") or key:match("^ForeverCharacter") or key:match("^ForeverWaypoint"), "unexpected new global function: " .. key)
        end
    end
    for _, name in ipairs({ "BINDING_HEADER_FOREVERHUB", "BINDING_NAME_FOREVERHUB_TOGGLE", "BINDING_NAME_FOREVERHUB_HOME",
        "BINDING_NAME_FOREVERHUB_PLACES", "BINDING_NAME_FOREVERHUB_REPAIR", "BINDING_NAME_FOREVERHUB_INN", "BINDING_NAME_FOREVERHUB_FLIGHT" }) do
        assert(type(_G[name]) == "string" and _G[name] ~= "", name .. " set")
    end
    assert(#handled == 0, "clean login: " .. table.concat(handled, "|"))
    assert(#chat == 0, "nothing in chat")
end

------------------------------------------------------------------------------------------------
-- 2. Bindings open the right pages; the place keys run Landmarks through the window.
------------------------------------------------------------------------------------------------
do
    local hub = Setup({ settings = true })
    local frame = ForeverHubFrame
    frame:Hide()
    ForeverHub_ToggleWindow()
    assert(frame:IsShown(), "toggle opens")
    ForeverHub_ToggleWindow()
    assert(not frame:IsShown(), "toggle closes")

    local opened = {}
    local realOpen = hub.OpenPage
    hub.OpenPage = function(tab, prefix) opened[#opened + 1] = { tab = tab, prefix = prefix }; realOpen(tab, prefix) end

    ForeverHub_OpenPage("Home")
    assert(opened[1].tab.label == "Home" and frame:IsShown(), "Home binding")
    ForeverHub_OpenPage("Places")
    assert(opened[2].tab.label == "Places", "Places binding")
    ForeverHub_OpenPage("Nope")
    assert(#opened == 2, "unknown page ignored")

    ForeverHub_PinNearest("repair")
    ForeverHub_PinNearest("inn")
    ForeverHub_PinNearest("flight")
    assert(table.concat(LANDMARK_ARGS, ",") == "repair,inn,flight", "landmarks args: " .. table.concat(LANDMARK_ARGS, ","))
    assert(opened[3].tab.label == "Places" and opened[3].prefix[1] == "Pinned the nearest repair.", "output shown in the window")
    assert(opened[5].prefix[1] == "Pinned the nearest flight.", "flight output")
    ForeverHub_PinNearest("bank")
    assert(#LANDMARK_ARGS == 3, "only the three binding kinds")

    -- Landmarks switched off: Home with a note, no command run.
    ForeverHubDB.off = { Landmarks = true }
    ForeverHub_PinNearest("repair")
    assert(#LANDMARK_ARGS == 3, "off helper not run")
    assert(opened[#opened].tab.label == "Home" and opened[#opened].prefix[1]:find("switched off"), "explains off")
    ForeverHub_OpenPage("Places")
    assert(opened[#opened].tab.label == "Home", "off page opens Home")
    ForeverHubDB.off = nil
    assert(#handled == 0, "bindings clean: " .. table.concat(handled, "|"))
end

-- Bindings.xml calls only these functions, and each binding name has a label. (Needs io.open; the fengari
-- runner has none, so the XML is also checked with PowerShell.)
if io and io.open then
    local file = assert(io.open(base .. "/ForeverHub/Bindings.xml", "r"))
    local xml = file:read("*a")
    file:close()
    local count = 0
    for name, body in xml:gmatch('<Binding name="([%w_]+)"[^>]*>(.-)</Binding>') do
        count = count + 1
        assert(type(_G["BINDING_NAME_" .. name]) == "string", "label for " .. name)
        local fn = body:match("then%s+([%w_]+)%(")
        assert(fn and type(_G[fn]) == "function", "binding calls a real function: " .. name)
        assert(load(body), "binding body compiles: " .. name)
    end
    assert(count == 6, "six bindings: " .. count)
    assert(xml:find('header="FOREVERHUB"', 1, true), "header")
end

------------------------------------------------------------------------------------------------
-- 3. AddOns menu entry: click toggles; tooltip uses the hub's own tooltip.
------------------------------------------------------------------------------------------------
do
    Setup({ settings = true })
    local frame = ForeverHubFrame
    frame:Hide()
    ForeverHub_OnAddonCompartmentClick("!ForeverHub", "LeftButton")
    assert(frame:IsShown(), "compartment opens")
    ForeverHub_OnAddonCompartmentClick("!ForeverHub", "LeftButton")
    assert(not frame:IsShown(), "compartment closes")
    local menuButton = newRegion("Button")
    menuButton.IsObjectType = function() return true end
    ForeverHub_OnAddonCompartmentEnter("!ForeverHub", menuButton)
    assert(tipLines[1] == "Forever Hub" and #tipLines >= 2, "compartment tooltip")
    assert(ForeverHubTooltip.owner == menuButton, "anchored to the menu button")
    ForeverHub_OnAddonCompartmentEnter("!ForeverHub", nil)
    assert(ForeverHubTooltip.owner == UIParent, "falls back without a button")
    ForeverHub_OnAddonCompartmentLeave("!ForeverHub")
    -- The toc names exactly these functions.
    local toc = io and io.open and assert(io.open(base .. "/ForeverHub/ForeverHub.toc", "r")):read("*a") or "ForeverHubExtras.lua"
    for field, fn in toc:gmatch("## (AddonCompartmentFunc%w*): ([%w_]+)") do
        assert(type(_G[fn]) == "function", field .. " -> " .. fn)
    end
    assert(toc:find("ForeverHubExtras.lua", 1, true), "extras listed in toc")
end

------------------------------------------------------------------------------------------------
-- 4. Options page: registered when the API is there, skipped quietly when it isn't.
------------------------------------------------------------------------------------------------
do
    local hub = Setup({ settings = false })
    assert(hub.extrasState().settingsCategory == nil, "no Settings: nothing registered")
    assert(#handled == 0, "no Settings: no errors: " .. table.concat(handled, "|"))

    hub = Setup({ partialSettings = true })
    assert(hub.extrasState().settingsCategory == nil, "half the API: nothing registered")
    assert(#handled == 0, "half the API: no errors: " .. table.concat(handled, "|"))

    hub = Setup({ settings = true })
    local state = hub.extrasState()
    assert(state.settingsCategory ~= nil, "registered")
    assert(settingsCalls[1][1] == "canvas" and settingsCalls[1][2] == state.canvas and settingsCalls[1][3] == "Forever Hub", "canvas category")
    assert(settingsCalls[2][1] == "addon" and settingsCalls[2][2] == state.settingsCategory, "added to AddOns")
    assert(not state.canvas.shown, "canvas hidden until the Options window shows it")

    -- The Open button shows the hub.
    ForeverHubFrame:Hide()
    local openButton
    for _, f in ipairs(frames) do if f.text == "Open Forever Hub" then openButton = f end end
    assert(openButton, "Open button")
    openButton.scripts.OnClick(openButton)
    assert(ForeverHubFrame:IsShown(), "Open button opens the hub")

    -- Helper switches mirror ForeverHubDB.off both ways.
    local rareRow
    for _, row in ipairs(state.canvasRows) do
        if row.helper and row.helper.name == "RareWatch" then rareRow = row end
        assert(not (row.helper and row.helper.noSwitch), "no switch for noSwitch helpers")
    end
    assert(rareRow and rareRow.button.text:find("On"), "starts on")
    rareRow.button.scripts.OnClick(rareRow.button)
    assert(ForeverHubDB.off.RareWatch == true, "settings switch writes ForeverHubDB.off")
    assert(rareRow.button.text:find("Off"), "row shows off")
    assert(ForeverHub_IsOff("RareWatch"), "hub sees it")
    -- Changing it on the Manage page updates the Options page.
    local helpers = hub.HELPERS
    for _, h in ipairs(helpers) do if h.name == "RareWatch" then hub.SetHelperOff(h, false) end end
    assert(rareRow.button.text:find("On"), "manage change mirrored")
    assert(#handled == 0, "settings clean: " .. table.concat(handled, "|"))
end

-- 4b. A helper's own switches (ForeverHubOptions, e.g. AutoQuest's) show on the Options page too.
do
    local value = { accept = true }
    ForeverHubOptions = { AutoQuest = { title = "Auto quest", rows = {
        { label = "Accept quests", about = "a", get = function() return value.accept end, set = function(on) value.accept = on end },
        { label = "Broken", about = "b", get = function() error("boom") end, set = function() end },
        "not a row",
    } } }
    local hub = Setup({ settings = true })
    local state = hub.extrasState()
    local acceptRow, brokenRow
    for _, row in ipairs(state.canvasRows) do
        if row.get and row.text == "Accept quests" then acceptRow = row end
        if row.get and row.text == "Broken" then brokenRow = row end
    end
    assert(acceptRow and acceptRow.button.text:find("On"), "option row shows on")
    acceptRow.button.scripts.OnClick(acceptRow.button)
    assert(value.accept == false and acceptRow.button.text:find("Off"), "option row toggles")
    assert(brokenRow and brokenRow.button.text:find("Off"), "a failing getter reads as off")
    ForeverHubOptions = nil
    handled = {}
end

------------------------------------------------------------------------------------------------
-- 5. Alerts: only the chosen pop-ups, at most one sound and flash per 10 s, switches respected.
------------------------------------------------------------------------------------------------
do
    local hub = Setup({ settings = true })
    ForeverHub_Receive("Quests", "|cff33ff33Ready to turn in:|r The Fargodeep Mine")
    assert(#SOUNDS == 1 and SOUNDS[1] == 3081 and FLASHES == 1, "quest done: sound and flash " .. #SOUNDS .. " " .. tostring(FLASHES) .. " " .. table.concat(handled, "|"))
    now = now + 3
    ForeverHub_Receive("DeathNotes", "Careful: you died near here at level 9, 20 yards away.")
    assert(#SOUNDS == 1 and FLASHES == 1, "throttled within 10 s")
    now = now + 8
    ForeverHub_Receive("ZoneLevels", "Duskwood is level 18-30 and you're level 10. Careful!")
    assert(#SOUNDS == 2 and FLASHES == 2, "after 10 s again")
    now = now + 20
    ForeverHub_Receive("BagCheck", "Bags nearly full.")
    ForeverHub_Receive("DeathNotes", "Noted: died at level 10 in Elwynn.")
    ForeverHub_Receive("ZoneLevels", "Elwynn Forest: level 1-10")
    assert(#SOUNDS == 2 and FLASHES == 2, "other pop-ups stay quiet")
    -- RareWatch plays its own sound: flash only, but it still holds back the next chime.
    ForeverHub_Receive("RareWatch", "Rare nearby: Mother Fang, north. Look for it on your minimap.")
    assert(#SOUNDS == 2 and FLASHES == 3, "rare: flash, no second sound")
    now = now + 5
    ForeverHub_Receive("Quests", "Ready to turn in: Wolves Across the Border")
    assert(#SOUNDS == 2, "rare's own sound counts toward the 10 s")
    now = now + 20
    -- Page text (a command's output) is never an alert.
    hub.RunCommand("LANDMARKS", "repair")
    SlashCmdList.DEATHPAGE = nil
    -- Switches.
    local state = hub.extrasState()
    ForeverHubDB.alerts = { sound = false }
    ForeverHub_Receive("Quests", "Ready to turn in: A")
    assert(#SOUNDS == 2 and FLASHES == 4, "sound off, flash on")
    now = now + 20
    ForeverHubDB.alerts = { sound = true, flash = false }
    ForeverHub_Receive("Quests", "Ready to turn in: B")
    assert(#SOUNDS == 3 and FLASHES == 4, "flash off, sound on")
    -- A helper switched off on Manage: no pop-up, so no alert.
    now = now + 20
    ForeverHubDB.off = { QuestTracker = true }
    ForeverHub_Receive("Quests", "Ready to turn in: C")
    assert(#SOUNDS == 3, "off helper: no alert")
    ForeverHubDB.off = nil
    -- Repeats the hub holds back don't chime either.
    now = now + 20
    ForeverHub_Receive("Quests", "Ready to turn in: D")
    now = now + 11
    ForeverHub_Receive("Quests", "Ready to turn in: D")
    assert(#SOUNDS == 4, "repeat within 15 s: no second alert")

    -- The Manage page's Alerts rows flip ForeverHubDB.alerts.
    ForeverHubDB.alerts = nil
    local manageButton
    for _, f in ipairs(frames) do if f.text == "Manage" then manageButton = f end end
    ForeverHubFrame:Show()
    manageButton.scripts.OnClick(manageButton)
    assert(#state.manageAlertRows == 2, "two alert rows on Manage")
    local soundRow = state.manageAlertRows[1]
    assert(soundRow.switch.text:find("On"), "sound starts on")
    soundRow.switch.scripts.OnClick(soundRow.switch)
    assert(ForeverHubDB.alerts.sound == false and soundRow.switch.text:find("Off"), "manage switch turns sound off")
    -- ...and the Options page shows the same.
    for _, row in ipairs(state.canvasRows) do
        if row.option and row.option.key == "sound" then assert(row.button.text:find("Off"), "options mirrors alerts") end
    end
    assert(#handled == 0, "alerts clean: " .. table.concat(handled, "|"))

    -- No FlashClientIcon or PlaySound on this client: nothing breaks.
    hub = Setup({ settings = true, noFlash = true })
    PlaySound = nil
    ForeverHub_Receive("Quests", "Ready to turn in: E")
    assert(#handled == 0, "missing alert APIs are fine")
end

------------------------------------------------------------------------------------------------
-- 6. Hearthstone button: attributes set once, out of combat; nothing protected touched in combat.
------------------------------------------------------------------------------------------------
do
    hearthCount = 1
    local hub, _, extraEvents = Setup({ settings = true })
    local hearth = hub.extrasState().hearth
    assert(hearth and hearth.template == "SecureActionButtonTemplate", "secure button made at login")
    assert(hearth.attrs.type == "item" and hearth.attrs.item == "item:6948", "uses the Hearthstone")
    assert(hearth.shown, "shown with a stone in the bags and the panel open")
    assert(hearth.points[1][2] == UIParent, "not anchored to the panel")
    assert(#blocked == 0, "nothing blocked")

    -- Tooltip: home and cooldown.
    cooldown = { now - 600, 3600, 1 }
    hearth.scripts.OnEnter(hearth)
    local text = table.concat(tipLines, "\n")
    assert(text:find("Home: Goldshire", 1, true) and text:find("Ready in 50m", 1, true), "tooltip: " .. text)
    cooldown = { 0, 0, 1 }
    hearth.scripts.OnEnter(hearth)
    assert(table.concat(tipLines, "\n"):find("Ready"), "ready")
    cooldown = { SECRET, SECRET, 1 }
    hearth.scripts.OnEnter(hearth)
    assert(table.concat(tipLines, "\n"):find("Cooldown unknown"), "secret cooldown")

    -- In combat: the panel can close and bags can change, but the button waits.
    combat = true
    hearthCount = 0
    extraEvents.scripts.OnEvent(extraEvents, "BAG_UPDATE_DELAYED")
    ForeverHubPanel:Hide()
    assert(#blocked == 0, "no protected call in combat: " .. table.concat(blocked, ","))
    assert(hearth.shown, "still shown until combat ends")
    assert(hub.extrasState().hearthPending, "queued")
    combat = false
    extraEvents.scripts.OnEvent(extraEvents, "PLAYER_REGEN_ENABLED")
    assert(not hearth.shown, "hidden after combat")
    assert(not hub.extrasState().hearthPending, "queue cleared")
    local attrs = hearth.attrs
    assert(attrs.type == "item" and attrs.item == "item:6948", "attributes unchanged")

    -- Out of combat it follows the panel straight away.
    hearthCount = 1
    ForeverHubPanel:Show()
    assert(hearth.shown, "back with the panel")
    ForeverHubPanel:Hide()
    assert(not hearth.shown, "hides with the panel")
    ForeverHubPanel:Show()
    hearthCount = 0
    extraEvents.scripts.OnEvent(extraEvents, "BAG_UPDATE_DELAYED")
    assert(not hearth.shown, "hidden without a stone")
    assert(#handled == 0, "hearth clean: " .. table.concat(handled, "|"))

    -- Logging in during combat (a /reload mid-fight): made only once combat ends.
    hearthCount = 1
    hub, _, extraEvents = Setup({ settings = true, combat = true })
    assert(hub.extrasState().hearth == nil, "not made in combat")
    assert(#blocked == 0, "nothing blocked at a combat login")
    combat = false
    extraEvents.scripts.OnEvent(extraEvents, "PLAYER_REGEN_ENABLED")
    hearth = hub.extrasState().hearth
    assert(hearth and hearth.attrs.item == "item:6948" and hearth.shown, "made after combat")
    assert(#handled == 0, "combat login clean: " .. table.concat(handled, "|"))

    -- A secret bind location doesn't break the tooltip.
    hub = Setup({ settings = true, secretHome = true })
    hub.extrasState().hearth.scripts.OnEnter(hub.extrasState().hearth)
    assert(table.concat(tipLines, "\n"):find("Home: unknown", 1, true), "secret home")
end

------------------------------------------------------------------------------------------------
-- 7. Without the hub (it failed to load), the extras file does nothing and defines nothing.
------------------------------------------------------------------------------------------------
do
    ForeverHub_ToggleWindow = nil
    assert(loadfile(base .. "/ForeverHub/ForeverHubExtras.lua"))("!ForeverHub", {})
    assert(ForeverHub_ToggleWindow == nil, "no hub, no extras")
end

------------------------------------------------------------------------------------------------
-- 8. Taint audit (2026-11-09): a login in combat (a /reload mid-fight) neither registers the Options
-- page nor changes a game setting until combat ends; both happen once it does.
------------------------------------------------------------------------------------------------
do
    local cvars = {}
    local hub, hubEvents, extraEvents = Setup({ settings = true, combat = true, snapshot = function()
        C_CVar = { SetCVar = function(name, value) cvars[#cvars + 1] = name .. "=" .. value end }
    end })
    assert(#settingsCalls == 0, "no Settings registration in combat")
    assert(hub.extrasState().settingsCategory == nil and hub.extrasState().settingsPending, "registration queued")
    assert(#cvars == 0, "no CVar change in combat")
    combat = false
    hubEvents.scripts.OnEvent(hubEvents, "PLAYER_REGEN_ENABLED")
    extraEvents.scripts.OnEvent(extraEvents, "PLAYER_REGEN_ENABLED")
    assert(cvars[1] == "accessibilityScreenNarrationEnabled=0" and #cvars == 1, "CVar set after combat: " .. table.concat(cvars, ","))
    assert(hub.extrasState().settingsCategory ~= nil and not hub.extrasState().settingsPending, "registered after combat")
    assert(settingsCalls[1][1] == "canvas" and settingsCalls[2][1] == "addon", "same two calls")
    hubEvents.scripts.OnEvent(hubEvents, "PLAYER_REGEN_ENABLED")
    extraEvents.scripts.OnEvent(extraEvents, "PLAYER_REGEN_ENABLED")
    assert(#cvars == 1 and #settingsCalls == 2, "done once only")
    assert(#blocked == 0 and #handled == 0, "combat login clean: " .. table.concat(handled, "|"))

    -- Out of combat both happen at login, as before.
    cvars = {}
    Setup({ settings = true, snapshot = function()
        C_CVar = { SetCVar = function(name, value) cvars[#cvars + 1] = name .. "=" .. value end }
    end })
    assert(#cvars == 1 and #settingsCalls == 2, "normal login registers and sets")
end

realPrint("ALL TESTS PASSED")
