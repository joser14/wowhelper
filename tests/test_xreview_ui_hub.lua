-- Cross-addon review (player's side): the hub's view buttons, its alert sound next to QuestTracker's own,
-- ForeverHelper's window next to the hub, and LevelLog's window next to the hub's Level log page.
local base = ADDON_PATH
local realPrint = print
local frames, timers, handled, chat
local failures = {}
local function check(cond, why) if not cond then failures[#failures + 1] = why end end

local function newRegion(kind, name, template)
    local r = { kind = kind, name = name, template = template, shown = true, scripts = {}, text = "", height = 0, points = {} }
    function r:SetText(t) self.text = t end
    function r:GetText() return self.text end
    function r:SetScript(s, f) self.scripts[s] = f end
    function r:HookScript() end
    function r:Show() self.shown = true; if self.scripts.OnShow then self.scripts.OnShow(self) end end
    function r:Hide() self.shown = false end
    function r:SetShown(v) if v then self:Show() else self:Hide() end end
    function r:IsShown() return self.shown end
    function r:GetStringHeight() return 14 end
    function r:SetHeight(h) self.height = h end
    function r:GetHeight() return self.height end
    function r:ClearAllPoints() self.points = {} end
    function r:SetPoint(...) self.points[#self.points + 1] = { ... } end
    function r:GetPoint() return "CENTER", nil, "CENTER", 1, 2 end
    function r:LockHighlight() self.locked = true end
    function r:UnlockHighlight() self.locked = false end
    function r:SetChecked(v) self.checked = v end
    function r:GetChecked() return self.checked end
    function r:RegisterEvent(e) self.events = self.events or {}; self.events[e] = true end
    function r:CreateFontString() local fs = newRegion("font"); ALLFONTS[#ALLFONTS + 1] = fs; return fs end
    function r:CreateTexture() return newRegion("texture") end
    function r:GetFontString() return nil end
    return setmetatable(r, { __index = function(_, k)
        if type(k) == "string" and k:match("^%u") then return function() end end
    end })
end

-- A fresh game with the hub (both files) loaded and logged in. opts.commands: SlashCmdList entries.
local function Setup(opts)
    opts = opts or {}
    frames, timers, handled, chat = {}, {}, {}, {}
    ALLFONTS = {}
    CreateFrame = function(kind, name, parent, template)
        local f = newRegion(kind, name, template)
        frames[#frames + 1] = f
        if name then _G[name] = f end
        return f
    end
    print = function(...) chat[#chat + 1] = table.concat({ ... }, " ") end
    DEFAULT_CHAT_FRAME = { AddMessage = function(_, t) chat[#chat + 1] = t end }
    UIParent = newRegion("Frame"); Minimap = newRegion("Frame")
    UISpecialFrames = {}
    SlashCmdList = {}
    for key, fn in pairs(opts.commands or {}) do SlashCmdList[key] = fn end
    GetTime = function() return 1000 end
    C_Timer = { After = function(_, fn) timers[#timers + 1] = fn end, NewTicker = function() end }
    issecretvalue = function() return false end
    geterrorhandler = function() return function(e) handled[#handled + 1] = tostring(e) end end
    InCombatLockdown = function() return false end
    UnitLevel = function() return 11 end
    UnitXP = function() return 100 end
    UnitXPMax = function() return 1000 end
    UnitName = function() return "Tester" end
    GetXPExhaustion = function() return 0 end
    GetMoney = function() return 100 end
    NUM_TOTAL_EQUIPPED_BAG_SLOTS = 0
    C_Container = { GetContainerNumSlots = function() return 0 end, GetContainerItemInfo = function() end, GetItemCooldown = function() return 0, 0, 1 end }
    C_Item = { GetItemCount = function() return 0 end }
    SOUNDKIT = { TELL_MESSAGE = 3081 }
    SOUNDS, FLASHES = {}, 0
    PlaySound = function(id) SOUNDS[#SOUNDS + 1] = id end
    FlashClientIcon = function() FLASHES = FLASHES + 1 end
    Settings = nil
    ForeverHubDB = nil
    ForeverHub_Receive = nil
    QuestTracker_SoundScan = opts.questTracker and function() end or nil
    QuestTrackerDB = opts.trackerDB
    local ns = {}
    local n = #frames
    assert(loadfile(base .. "/ForeverHub/ForeverHub.lua"))("!ForeverHub", ns)
    local hubEvents = frames[n + 1]
    assert(loadfile(base .. "/ForeverHub/ForeverHubExtras.lua"))("!ForeverHub", ns)
    hubEvents.scripts.OnEvent(hubEvents, "PLAYER_LOGIN")
    for _, fn in ipairs(timers) do fn() end
    timers = {}
    return ns.ForeverHub
end

local function button(text)
    for _, f in ipairs(frames) do
        if f.kind == "Button" and f.text == text and f.shown then return f end
    end
end
local function click(text)
    local b = button(text)
    check(b ~= nil, "no button '" .. text .. "'")
    if b then b.scripts.OnClick(b, "LeftButton") end
end
local function bodyHas(needle)
    for _, fs in ipairs(ALLFONTS) do
        if fs.text:find(needle, 1, true) then return true end
    end
    return false
end

------------------------------------------------------------------------------------------------
-- 1. A page whose addon isn't loaded shows no view buttons (they could only say "not turned on").
------------------------------------------------------------------------------------------------
do
    Setup({ commands = { DUNGEONS = function(arg) ForeverHub_Receive("Dungeons", "dungeons [" .. arg .. "]") end } })
    ForeverHubFrame:Show()
    click("Dungeons")
    check(button("All dungeons") ~= nil, "loaded addon: its view buttons are there")
    click("Gold goal")
    check(button("Money sources") == nil and button("Auction sales") == nil, "GoldGoal not loaded: no view buttons")
    check(bodyHas("isn't turned on"), "the page itself still says the addon is off")
    click("Places")
    check(button("Nearest repair") == nil, "Landmarks not loaded: no pin buttons")
    check(#handled == 0, "no errors: " .. table.concat(handled, "|"))
    check(#chat == 0, "nothing in chat")
end

------------------------------------------------------------------------------------------------
-- 2. A window toggle on a page whose own command also opens that window (LevelLog with "open with the
-- page" ticked): the toggle closes it and the page isn't run again behind it to reopen it.
------------------------------------------------------------------------------------------------
do
    local windowShown, pageRuns = false, 0
    Setup({ commands = { LEVELLOG = function(arg)
        if arg == "window" then
            windowShown = not windowShown
            return
        end
        pageRuns = pageRuns + 1
        ForeverHub_Receive("LevelLog", "log [" .. arg .. "]")
        windowShown = true -- the page opens the window too
    end } })
    ForeverHubFrame:Show()
    click("Level log")
    check(windowShown and pageRuns == 1, "page opened with its window")
    click("Show or hide window")
    check(not windowShown, "the button closes the window")
    check(pageRuns == 1, "page not run again behind the toggle: " .. pageRuns)
    check(bodyHas("log [all]"), "page text stays")
    click("Show or hide window")
    check(windowShown, "and opens it again")
    check(#handled == 0 and #chat == 0, "clean")
end

------------------------------------------------------------------------------------------------
-- 3. "Ready to turn in" pop-up: no hub chime while QuestTracker plays its own "Quest complete" sound;
-- the chime is back when that sound is switched off, or without QuestTracker.
------------------------------------------------------------------------------------------------
do
    Setup({ questTracker = true, trackerDB = {} })
    ForeverHub_Receive("Quests", "|cff33ff33Ready to turn in:|r The Woodland Protector")
    check(#SOUNDS == 0, "QuestTracker's default complete sound: no second chime (" .. #SOUNDS .. ")")
    check(FLASHES == 1, "the taskbar flash still comes")

    Setup({ questTracker = true, trackerDB = { sounds = { complete = { on = false, choice = 5 } } } })
    ForeverHub_Receive("Quests", "|cff33ff33Ready to turn in:|r Tree Spirit")
    check(#SOUNDS == 1 and SOUNDS[1] == 3081, "complete sound off: the hub chimes")

    Setup({})
    ForeverHub_Receive("Quests", "|cff33ff33Ready to turn in:|r Tree Spirit")
    check(#SOUNDS == 1, "no QuestTracker: the hub chimes")

    -- Other alerts are unchanged.
    Setup({ questTracker = true, trackerDB = {} })
    ForeverHub_Receive("DeathNotes", "Careful: you died here before.")
    check(#SOUNDS == 1, "death alert still chimes")
    check(#handled == 0 and #chat == 0, "clean")
end

------------------------------------------------------------------------------------------------
-- 4. ForeverHelper with the hub: a new install starts with its window closed (it sat on the quest
-- trackers at the right edge); the Characters page lists the to-dos; "Own window" opens it.
------------------------------------------------------------------------------------------------
do
    local function LoadHelper(saved)
        ForeverHelperDB = saved
        UnitGUID = function() return "Player-1-0001" end
        GetRealmName = function() return "Realm" end
        UnitClass = function() return "Priest", "PRIEST" end
        UnitRace = function() return "Night Elf", "NightElf" end
        local n = #frames
        assert(loadfile(base .. "/ForeverHelper/ForeverHelper.lua"))("!ForeverHub", {})
        local events
        for i = n + 1, #frames do
            if frames[i].events and frames[i].events.ADDON_LOADED then events = frames[i] end
        end
        events.scripts.OnEvent(events, "ADDON_LOADED", "!ForeverHub")
        events.scripts.OnEvent(events, "PLAYER_LOGIN")
        return ForeverHelperFrame
    end

    Setup({})
    local window = LoadHelper(nil)
    check(window and not window.shown, "new install with the hub: window starts closed")
    SlashCmdList.FOREVERHELPER("add Buy bags")
    local lines = {}
    local realReceive = ForeverHub_Receive
    ForeverHub_Receive = function(_, text) lines[#lines + 1] = text end
    SlashCmdList.FOREVERHELPER("chars")
    ForeverHub_Receive = realReceive
    local page = table.concat(lines, "\n")
    check(page:find("1. Buy bags", 1, true), "Characters page lists the to-do:\n" .. page)
    SlashCmdList.FOREVERHELPER("window")
    check(window.shown, "Own window opens it")

    -- A save that had the window shown keeps it.
    Setup({})
    window = LoadHelper({ characters = {}, shown = true })
    check(window.shown, "an open window stays open")
    check(#handled == 0 and #chat == 0, "helper clean: " .. table.concat(handled, "|"))
end

if #failures > 0 then
    realPrint("FAILURES (" .. #failures .. "):")
    for _, why in ipairs(failures) do realPrint(" - " .. why) end
    os.exit(1)
end
realPrint("test_xreview_ui_hub: all checks passed")
