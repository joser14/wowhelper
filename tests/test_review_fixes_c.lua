-- Review fixes, round C. ADDON_PATH is the folder holding QuestTracker and ForeverHub.
local base = ADDON_PATH
local env = {}

------------------------------------------------------------------ QuestTracker
do
    local frames, handled, blocked = {}, {}, {}
    local combat, mouseOver, tick = false, false, nil
    local function newRegion(kind, template)
        local r = { kind = kind, template = template, shown = true, scripts = {}, hooks = {}, attrs = {}, text = "", level = 5 }
        function r:SetText(t) self.text = t end
        function r:GetText() return self.text end
        function r:SetScript(s, f) self.scripts[s] = f end
        function r:HookScript(s, f) self.hooks[s] = f end
        function r:Show() self.shown = true end
        function r:Hide() self.shown = false end
        function r:SetShown(v) self.shown = v and true or false end
        function r:IsShown() return self.shown end
        function r:SetAttribute(k, v) if combat then blocked[#blocked + 1] = "SetAttribute" end self.attrs[k] = v end
        function r:ClearAllPoints() if combat and self.watchCombat then blocked[#blocked + 1] = "ClearAllPoints" end end
        function r:SetPoint(...) if combat and self.watchCombat then blocked[#blocked + 1] = "SetPoint" end self.point = { ... } end
        function r:SetHeight(h) if combat and self.watchCombat then blocked[#blocked + 1] = "SetHeight" end self.height = h end
        function r:SetFrameLevel(l) if combat and self.watchCombat then blocked[#blocked + 1] = "SetFrameLevel" end self.level = l end
        function r:GetFrameLevel() return self.level end
        function r:IsMouseOver() return mouseOver end
        function r:GetLeft() return 100 end
        function r:GetTop() return 900 end
        function r:CreateFontString() return newRegion("font") end
        function r:CreateTexture() return newRegion("texture") end
        return setmetatable(r, { __index = function(_, k)
            if type(k) == "string" and k:match("^%u") then return function() end end
        end })
    end
    CreateFrame = function(kind, name, parent, template)
        local f = newRegion(kind, template)
        f.watchCombat = template == "SecureActionButtonTemplate" or name == "QuestTrackerPanel"
        frames[#frames + 1] = f
        if name then _G[name] = f end
        return f
    end
    UIParent = newRegion("Frame")
    GameTooltip = newRegion("Frame")
    -- Blizzard's tracker: any Hide/Show from the addon would taint it.
    local trackerCalls = {}
    ObjectiveTrackerFrame = newRegion("Frame")
    ObjectiveTrackerFrame.alpha = 1
    function ObjectiveTrackerFrame:SetAlpha(a) self.alpha = a end
function ObjectiveTrackerFrame:GetAlpha() return self.alpha end
    function ObjectiveTrackerFrame:Show() trackerCalls[#trackerCalls + 1] = "Show" end
    function ObjectiveTrackerFrame:Hide() trackerCalls[#trackerCalls + 1] = "Hide" end
    function ObjectiveTrackerFrame:SetShown() trackerCalls[#trackerCalls + 1] = "SetShown" end
    function ObjectiveTrackerFrame:Update() trackerCalls[#trackerCalls + 1] = "Update" end
    issecretvalue = function() return false end
    InCombatLockdown = function() return combat end
    geterrorhandler = function() return function(e) handled[#handled + 1] = tostring(e) end end
    C_Timer = { NewTicker = function(_, fn) tick = fn end, After = function() end }
    GetTime = function() return 1000 end
    GetServerTime = function() return 100000 end
    UnitLevel = function() return 10 end
    UnitXPMax = function() return 1000 end
    GetRealZoneText = function() return "Elwynn Forest" end

    local log, data = {}, {}
    local infoReads = 0
    local function header(title) log[#log + 1] = { isHeader = true, title = title } end
    local function quest(id, title, o)
        log[#log + 1] = { questID = id, title = title, level = 10, difficultyLevel = 10, suggestedGroup = 0, questLogIndex = #log + 1 }
        data[id] = o or {}
    end
    local function indexOf(id) for i, e in ipairs(log) do if e.questID == id then return i end end end
    C_QuestLog = {
        GetNumQuestLogEntries = function() return #log, 3 end,
        GetMaxNumQuestsCanAccept = function() return 25 end,
        GetInfo = function(i) infoReads = infoReads + 1; return log[i] end,
        IsComplete = function() return false end,
        ReadyForTurnIn = function() return false end,
        IsQuestTrivial = function() return false end,
        GetQuestObjectives = function(id) return data[id].objectives or {} end,
        IsOnMap = function() return true, false end,
        GetDistanceSqToQuest = function(id) local d = data[id].distance; if d then return d * d, true end end,
        GetLogIndexForQuestID = function(id) return indexOf(id) end,
    }
    GetQuestLogSpecialItemInfo = function(i)
        local e = log[i]
        local o = e and data[e.questID]
        if o and o.item then return "|Hitem:" .. o.item .. ":|h[Rod]|h", 123, 1, false end
    end
    -- One reward item that never loads.
    local itemRequests = 0
    ItemAdvisor_IsUpgrade = function() return false end
    GetNumQuestLogChoices = function(id) return id == 1 and 1 or 0 end
    GetNumQuestLogRewards = function() return 0 end
    GetQuestLogChoiceInfo = function() return "n", 1, 1, 1, true, 4242 end
    C_Item = { GetItemInfo = function() return nil end, RequestLoadItemDataByID = function() itemRequests = itemRequests + 1 end }

    local function obj(text, have, need) return { text = text, numFulfilled = have, numRequired = need, finished = have >= need } end
    header("Elwynn Forest")
    quest(1, "Alpha", { distance = 10, objectives = { obj("Wolves: 0/8", 0, 8) } })
    quest(2, "Bravo", { distance = 50, item = 88, objectives = { obj("Bears: 0/4", 0, 4) } })
    header("Westfall")
    quest(3, "Charlie", { distance = 30, objectives = { obj("Murlocs: 0/5", 0, 5) } })
    QuestTrackerDB = {}

    assert(loadfile(base .. "/QuestTracker/QuestTracker.lua"))("QuestTracker", env)
    local events = frames[1]
    local function fire(e, ...) events.scripts.OnEvent(events, e, ...) end
    fire("PLAYER_LOGIN")
    tick()

    local function shownRows()
        local out = {}
        for _, f in ipairs(frames) do
            if f.kind == "Button" and rawget(f, "left") and f.shown then out[#out + 1] = f end
        end
        table.sort(out, function(a, b) return a.point[5] > b.point[5] end)
        return out
    end
    local function texts()
        local t = {}
        for _, r in ipairs(shownRows()) do t[#t + 1] = r.left.text end
        return table.concat(t, "\n")
    end
    local function find(text)
        for _, r in ipairs(shownRows()) do if r.left.text:find(text, 1, true) then return r end end
    end
    local function before(a, b)
        local s = texts()
        return s:find(a, 1, true) < s:find(b, 1, true)
    end
    assert(before("Alpha", "Bravo"), "nearest first: " .. texts())

    -- By default Blizzard's tracker is left alone (no write to Blizzard's frame).
    assert(QuestTrackerDB.keepBlizzard and ObjectiveTrackerFrame.alpha ~= 0, "Blizzard's tracker left visible by default")
    ObjectiveTrackerFrame.alpha = 1; tick()
    assert(ObjectiveTrackerFrame.alpha == 1, "the poll doesn't touch it by default")
    -- No hook on Blizzard's tracker: once the player opts in, the next tick clears it again if the game shows it.
    assert(not (ObjectiveTrackerFrame.hooks and ObjectiveTrackerFrame.hooks.OnShow), "no OnShow hook on Blizzard's tracker")
    local headerButton
    for _, f in ipairs(frames) do if f.scripts.OnDragStart then headerButton = f end end
    headerButton.scripts.OnClick(headerButton)
    assert(ObjectiveTrackerFrame.alpha == 0 and not QuestTrackerDB.keepBlizzard, "right-click makes it clear")
    ObjectiveTrackerFrame.alpha = 1; tick()
    assert(ObjectiveTrackerFrame.alpha == 0, "cleared again by the poll")
    combat = true; fire("PLAYER_REGEN_DISABLED"); ObjectiveTrackerFrame.alpha = 1; tick()
    combat = false; fire("PLAYER_REGEN_ENABLED"); tick()
    assert(ObjectiveTrackerFrame.alpha == 0, "clear after combat")
    headerButton.scripts.OnClick(headerButton)
    assert(ObjectiveTrackerFrame.alpha == 1 and QuestTrackerDB.keepBlizzard, "and right-click brings it back")
    assert(#trackerCalls == 0, "never Hide/Show/Update on Blizzard's tracker: " .. table.concat(trackerCalls, ","))

    -- 1. The item button sits above its row.
    local button
    for _, f in ipairs(frames) do if f.template == "SecureActionButtonTemplate" and f.shown then button = f end end
    local bravo = find("Bravo")
    assert(button and button.point[2] == bravo, "button on Bravo's row")
    assert(button.level > bravo.level, "button above its row: " .. button.level .. " vs " .. bravo.level)

    -- 2a. While the mouse is on the panel, a dirty refresh updates text but doesn't reorder.
    mouseOver = true
    data[2].distance = 5
    data[1].objectives = { obj("Wolves: 3/8", 3, 8) }
    fire("QUEST_LOG_UPDATE"); tick()
    assert(before("Alpha", "Bravo"), "no reorder under the mouse: " .. texts())
    assert(find("Wolves: 3/8"), "text still updates: " .. texts())
    for _ = 1, 4 do tick() end
    assert(before("Alpha", "Bravo"), "still no reorder while hovered")
    -- A zone header click under the mouse still folds right away.
    local westfall = find("Westfall")
    westfall.scripts.OnClick(westfall, "LeftButton"); tick()
    assert(QuestTrackerDB.zones.Westfall == false and not find("Charlie"), "fold applies under the mouse: " .. texts())
    westfall = find("Westfall")
    westfall.scripts.OnClick(westfall, "LeftButton"); tick()
    assert(find("Charlie"), "unfolds")
    mouseOver = false
    tick()
    assert(before("Bravo", "Alpha"), "re-sorts once the mouse leaves: " .. texts())

    -- 2b. A reward item that never loads is asked for once, and other addons' item loads are ignored.
    assert(itemRequests == 1, "item requested once: " .. itemRequests)
    for _ = 1, 3 do fire("QUEST_LOG_UPDATE"); tick() end
    assert(itemRequests == 1, "not re-requested on refresh: " .. itemRequests)
    tick()
    local reads = infoReads
    fire("GET_ITEM_INFO_RECEIVED", 999, true); tick()
    assert(infoReads == reads, "someone else's item doesn't refresh")
    fire("GET_ITEM_INFO_RECEIVED", 4242, false); tick()
    assert(infoReads > reads, "our item does")
    reads = infoReads
    fire("GET_ITEM_INFO_RECEIVED", 4242, false); tick()
    assert(infoReads == reads, "a second failed answer doesn't loop")
    assert(itemRequests == 1, "still once")

    -- 3. Zone header clicks are ignored in combat.
    combat = true
    fire("PLAYER_REGEN_DISABLED")
    local zones = QuestTrackerDB.zones.Westfall
    westfall = find("Westfall")
    westfall.scripts.OnClick(westfall, "LeftButton"); tick()
    assert(QuestTrackerDB.zones.Westfall == zones, "header click ignored in combat")
    combat = false
    fire("PLAYER_REGEN_ENABLED"); tick()
    assert(find("Charlie"), "nothing folded after combat either")

    -- 4. A 3-second re-sort reads the log once.
    tick(); tick(); tick()
    assert(before("Bravo", "Alpha"), "Bravo first before the move")
    data[1].distance = 1
    reads = infoReads
    for _ = 1, 3 do tick() end
    assert(before("Alpha", "Bravo"), "re-sorted: " .. texts())
    assert(infoReads - reads == #log, "log read once per re-sort: " .. (infoReads - reads))

    assert(#blocked == 0, "nothing locked touched in combat: " .. table.concat(blocked, ","))
    assert(#handled == 0, "tracker clean: " .. tostring(handled[1]))
    print("QuestTracker fixes passed")
end

------------------------------------------------------------------ ForeverHub
do
    local timers, frames, handled = {}, {}, {}
    local function newRegion(kind, name)
        local r = { kind = kind, name = name, shown = true, scripts = {}, text = "", height = 0, scrollPos = 0, strHeight = 14 }
        function r:SetText(t) self.text = t end
        function r:GetText() return self.text end
        function r:SetScript(s, f) self.scripts[s] = f end
        function r:Show() self.shown = true; if self.scripts.OnShow then self.scripts.OnShow(self) end end
        function r:Hide() self.shown = false end
        function r:SetShown(v) if v then self:Show() else self:Hide() end end
        function r:IsShown() return self.shown end
        function r:GetStringHeight() local _, n = tostring(self.text):gsub("\n", ""); return 14 * (n + 1) end
        function r:SetHeight(h) self.height = h end
        function r:GetHeight() return self.height end
        function r:GetVerticalScroll() return self.scrollPos end
        function r:SetVerticalScroll(v) self.scrollPos = v end
        function r:GetPoint() return "CENTER", nil, "CENTER", 1, 2 end
        function r:CreateFontString() return newRegion("font") end
        function r:CreateTexture() return newRegion("texture") end
        return setmetatable(r, { __index = function(_, k)
            if type(k) == "string" and k:match("^%u") then return function() end end
        end })
    end
    CreateFrame = function(kind, name)
        local f = newRegion(kind, name)
        frames[#frames + 1] = f
        if name then _G[name] = f end
        return f
    end
    UIParent = newRegion("Frame"); Minimap = newRegion("Frame"); GameTooltip = newRegion("Frame")
    UISpecialFrames = {}
    SlashCmdList = {}
    local tick
    C_Timer = { After = function(_, fn) timers[#timers + 1] = fn end, NewTicker = function(_, fn) tick = fn end }
    issecretvalue = function() return false end
    geterrorhandler = function() return function(e) handled[#handled + 1] = tostring(e) end end
    InCombatLockdown = function() return false end
    UnitXP = function() return 1 end
    GetXPExhaustion = function() return 0 end
    GetMoney = function() return 100 end
    UnitLevel = function() return 10 end
    UnitXPMax = function() return 1000 end

    -- A helper that loads after the hub: its status needs its own login, and it registers its command there.
    local helperReady, helperCalls = false, 0
    ForeverHubStatus = { QuestCheck = function()
        if not helperReady then error("helper not set up yet") end
        return { { text = "Turn in 1 quest", page = "Quests" } }
    end }
    local hub
    do
        local n = #frames
        assert(loadfile(base .. "/ForeverHub/ForeverHub.lua"))("ForeverHub", env)
        hub = frames[n + 1]
    end
    hub.scripts.OnEvent(hub, "PLAYER_LOGIN")
    assert(#handled == 0, "no errors from helpers that haven't set up: " .. table.concat(handled, "|"))
    -- Now the helper's own PLAYER_LOGIN runs.
    helperReady = true
    SlashCmdList.QUESTCHECK = function() helperCalls = helperCalls + 1; ForeverHub_Receive("QuestCheck", "quests page") end
    for _, fn in ipairs(timers) do fn() end
    timers = {}
    local function rowShown(text)
        for _, f in ipairs(frames) do
            if f.kind == "Button" and f.shown and rawget(f, "fullText") and f.text:find(text, 1, true) then return true end
        end
    end
    assert(rowShown("Turn in"), "status filled a frame later")
    assert(#handled == 0, "clean after the late pass: " .. table.concat(handled, "|"))
    SlashCmdList.QUESTCHECK("")
    assert(ForeverHubFrame.shown and helperCalls == 1, "command registered at login is wrapped into the window")
    -- Running the wrap again doesn't wrap the wrapper.
    for _, fn in ipairs(timers) do fn() end
    -- A helper still broken after login is reported.
    ForeverHubStatus.QuestCheck = function() error("real bug") end
    hub.scripts.OnEvent(hub, "BAG_UPDATE_DELAYED"); tick()
    assert(#handled == 1, "real problems still reported")
    handled = {}

    -- 7. The pop-up history keeps its place when a new message arrives.
    local nav, scroll
    for _, f in ipairs(frames) do
        if f.kind == "Button" and f.text == "Pop-up history" then nav = f end
        if f.kind == "ScrollFrame" then scroll = f end
    end
    scroll.height = 100
    for i = 1, 20 do ForeverHub_Receive("T", "message " .. i) end
    nav.scripts.OnClick(nav)
    assert(scroll.scrollPos == 0, "page opens at the top")
    scroll.scrollPos = 60
    ForeverHub_Receive("T", "message 21")
    assert(scroll.scrollPos == 74, "same lines stay in view as one is added on top: " .. scroll.scrollPos)
    -- At the top, it stays at the top so the newest shows.
    scroll.scrollPos = 0
    ForeverHub_Receive("T", "message 22")
    assert(scroll.scrollPos == 0, "top stays top")
    -- Choosing the page again starts at the top.
    scroll.scrollPos = 60
    nav.scripts.OnClick(nav)
    assert(scroll.scrollPos == 0, "reselecting starts at the top")
    assert(#handled == 0, "hub clean: " .. table.concat(handled, "|"))
    print("ForeverHub fixes passed")
end
print("ALL TESTS PASSED")
