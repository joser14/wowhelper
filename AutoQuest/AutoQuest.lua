-- AutoQuest: when you open a quest giver's window yourself, accepts its quests and turns in the ones
-- you have finished. The only helper in the suite that acts, and only inside a window you opened: it
-- never targets, moves or talks to anyone for you.
--
-- It stays out of the way when:
--   * you hold the pause key (Shift unless you pick another);
--   * you are in combat;
--   * the quest asks for gold, is repeatable or daily/weekly, or has several rewards to choose from
--     (WindowBadges marks the best one; you click it);
--   * a player shared the quest (escorts and shared quests are yours to accept);
--   * the quest is gray (far below your level), unless you switch gray quests on;
--   * you put the NPC on the ignore list, or switched AutoQuest off on the hub's Manage page.
--
-- No Blizzard function is hooked or replaced and nothing of Blizzard's is written to; it only listens
-- to the quest window events and calls the same functions the window's own buttons call.

local SOURCE = "AutoQuest"
-- The same quest isn't picked again this soon, so going back from a quest you didn't take (or
-- that the game refused) doesn't open it over and over.
local RETRY_SECONDS = 30
local MAX_RECENT = 12
local MAX_IGNORED = 100
local PAUSE_KEYS = { shift = "Shift", ctrl = "Ctrl", alt = "Alt" }
local DEFAULTS = { accept = true, handin = true, gray = false, pause = "shift" }

local GOLD, GRAY, GREEN, ORANGE = "|cffffd100", "|cff999999", "|cff33ff33", "|cffffaa66"

local db
local tried = {}
local recent = {}
local lastNPC

local function Safe(value)
    if issecretvalue and issecretvalue(value) then
        return nil
    end
    return value
end

-- Reads a game value through a function that may be missing on this client.
local function Call(fn, ...)
    if type(fn) ~= "function" then
        return nil
    end
    local ok, a, b, c, d, e = pcall(fn, ...)
    if not ok then
        return nil
    end
    return Safe(a), Safe(b), Safe(c), Safe(d), Safe(e)
end

-- Runs one quest-window action; a failure goes to the error log, never to chat.
local function Act(fn, ...)
    if type(fn) ~= "function" then
        return false
    end
    local ok, err = pcall(fn, ...)
    if not ok then
        local handler = type(geterrorhandler) == "function" and geterrorhandler()
        if handler then
            handler(err)
        end
    end
    return ok
end

local function Print(text)
    if ForeverHub_Receive then
        ForeverHub_Receive(SOURCE, text)
    end
end

local function Option(key)
    if db and db[key] ~= nil then
        return db[key]
    end
    return DEFAULTS[key]
end

local function Now()
    return Call(GetTime) or 0
end

local function Note(text)
    recent[#recent + 1] = { text = text, time = Now() }
    if #recent > MAX_RECENT then
        table.remove(recent, 1)
    end
end

---------------------------------------------------------------------------- checks

local function PlainString(value)
    value = Safe(value)
    if type(value) == "string" and value ~= "" then
        return value
    end
end

local function NPCName()
    local name = PlainString((Call(UnitName, "npc")))
    if name then
        lastNPC = name
    end
    return name
end

local function IgnoredIndex(name)
    if not (db and name) then
        return nil
    end
    local lower = name:lower()
    for index, entry in ipairs(db.ignored) do
        if type(entry) == "string" and entry:lower() == lower then
            return index
        end
    end
end

local function PauseHeld()
    local key = Option("pause")
    local fn = (key == "ctrl" and IsControlKeyDown) or (key == "alt" and IsAltKeyDown) or IsShiftKeyDown
    return Call(fn) == true
end

-- Nil when AutoQuest may act at this window right now.
local function Blocked()
    if not db then
        return "not loaded"
    end
    if ForeverHub_IsOff and ForeverHub_IsOff(SOURCE) then
        return "switched off"
    end
    if Call(InCombatLockdown) == true then
        return "combat"
    end
    if PauseHeld() then
        return "paused"
    end
    local name = NPCName()
    if IgnoredIndex(name) then
        return "ignored"
    end
end

local function RecentlyTried(key)
    local when = tried[key]
    return when ~= nil and Now() - when < RETRY_SECONDS
end

local function MarkTried(key)
    local now = Now()
    -- Old entries are of no use once they can't hold anything back; keeps the table small.
    for old, when in pairs(tried) do
        if now - when >= RETRY_SECONDS then
            tried[old] = nil
        end
    end
    tried[key] = now
end

local function QuestLogCall(name, questID)
    if type(questID) ~= "number" or type(C_QuestLog) ~= "table" then
        return nil
    end
    return (Call(C_QuestLog[name], questID))
end

-- The quest shown in the quest window (detail, progress or reward page).
local function WindowQuestID()
    local questID = Call(GetQuestID)
    if type(questID) == "number" and questID > 0 then
        return questID
    end
end

-- Repeatable, daily or weekly: the quest in the open quest window.
local function WindowQuestRepeats(questID)
    return QuestLogCall("IsRepeatableQuest", questID) == true or Call(QuestIsDaily) == true or Call(QuestIsWeekly) == true
end

local function WindowTitle()
    return PlainString((Call(GetTitleText))) or "a quest"
end

local function AsksForGold()
    local money = Call(GetQuestMoneyToGet)
    return type(money) == "number" and money > 0
end

---------------------------------------------------------------------------- gossip window

-- C_GossipInfo.SelectActiveQuest/SelectAvailableQuest name their argument "optionID"; on this
-- client's Mainline-based gossip window that number is the quest's questID from the
-- GossipQuestUIInfo entry. Should the entry come without one, the list position is passed instead.
local function SelectGossipQuest(fn, info, index)
    if type(fn) ~= "function" then
        return false
    end
    local questID = Safe(info.questID)
    if type(questID) == "number" and questID > 0 and pcall(fn, questID) then
        return true
    end
    return Act(fn, index)
end

local function GossipRepeats(info)
    local frequency = Safe(info.frequency)
    return Safe(info.repeatable) == true or (type(frequency) == "number" and frequency > 0)
end

local function OnGossip()
    if Blocked() or type(C_GossipInfo) ~= "table" then
        return
    end
    -- Turn-ins first: handing one in can bring the next quest of a chain.
    if Option("handin") then
        local active = Call(C_GossipInfo.GetActiveQuests)
        for index, info in ipairs(type(active) == "table" and active or {}) do
            local questID = type(info) == "table" and Safe(info.questID)
            local key = "turnin:" .. tostring(questID or ("#" .. index))
            if type(info) == "table" and Safe(info.isComplete) == true and not GossipRepeats(info) and not RecentlyTried(key) then
                MarkTried(key)
                if SelectGossipQuest(C_GossipInfo.SelectActiveQuest, info, index) then
                    return
                end
            end
        end
    end
    if Option("accept") then
        local available = Call(C_GossipInfo.GetAvailableQuests)
        for index, info in ipairs(type(available) == "table" and available or {}) do
            local questID = type(info) == "table" and Safe(info.questID)
            local key = "accept:" .. tostring(questID or ("#" .. index))
            local trivial = type(info) == "table" and Safe(info.isTrivial)
            if trivial == nil then
                trivial = QuestLogCall("IsQuestTrivial", questID)
            end
            if type(info) == "table" and not GossipRepeats(info) and Safe(info.isIgnored) ~= true
                and (Option("gray") or trivial ~= true) and not RecentlyTried(key) then
                MarkTried(key)
                if SelectGossipQuest(C_GossipInfo.SelectAvailableQuest, info, index) then
                    return
                end
            end
        end
    end
end

---------------------------------------------------------------------------- old-style greeting window

local function OnGreeting()
    if Blocked() then
        return
    end
    if Option("handin") and type(SelectActiveQuest) == "function" then
        local count = Call(GetNumActiveQuests)
        for index = 1, type(count) == "number" and count or 0 do
            local title, isComplete = Call(GetActiveTitle, index)
            local questID = Call(GetActiveQuestID, index)
            if isComplete == nil and type(questID) == "number" then
                isComplete = QuestLogCall("IsComplete", questID)
            end
            local key = "turnin:" .. tostring(questID or title or ("#" .. index))
            -- Repeatable quests are yours to hand in, as in the gossip window (final review).
            local repeats = QuestLogCall("IsRepeatableQuest", questID) == true
            if isComplete == true and not repeats and not RecentlyTried(key) then
                MarkTried(key)
                if Act(SelectActiveQuest, index) then
                    return
                end
            end
        end
    end
    if Option("accept") and type(SelectAvailableQuest) == "function" then
        local count = Call(GetNumAvailableQuests)
        for index = 1, type(count) == "number" and count or 0 do
            local isTrivial, frequency, isRepeatable, _, questID = Call(GetAvailableQuestInfo, index)
            if isTrivial == nil then
                isTrivial = Call(IsAvailableQuestTrivial, index)
            end
            local repeats = isRepeatable == true or (type(frequency) == "number" and frequency > 0)
            local title = PlainString((Call(GetAvailableTitle, index)))
            local key = "accept:" .. tostring(questID or title or ("#" .. index))
            if not repeats and (Option("gray") or isTrivial ~= true) and not RecentlyTried(key) then
                MarkTried(key)
                if Act(SelectAvailableQuest, index) then
                    return
                end
            end
        end
    end
end

---------------------------------------------------------------------------- quest window pages

local function OnDetail()
    if not Option("accept") or Blocked() then
        return
    end
    -- A quest a player shared with you (escorts too): the "npc" unit is that player. When the game
    -- won't say, leave it to you.
    if Call(UnitIsPlayer, "npc") ~= false then
        return
    end
    -- Quests the game accepts by itself have nothing left to click.
    if Call(QuestGetAutoAccept) == true then
        return
    end
    -- A quest the game pushed when you walked into an area: not a window you opened.
    if Call(QuestIsFromAreaTrigger) == true then
        return
    end
    local questID = WindowQuestID()
    if WindowQuestRepeats(questID) then
        return
    end
    if not Option("gray") and QuestLogCall("IsQuestTrivial", questID) == true then
        return
    end
    local title = WindowTitle()
    -- This window's giver only: a quest started from an item has none, and the last NPC didn't give it.
    local giver = NPCName()
    if Act(AcceptQuest) then
        Note("Accepted " .. title .. (giver and (" from " .. giver) or ""))
    end
end

local function OnProgress()
    if not Option("handin") or Blocked() or AsksForGold() then
        return
    end
    if WindowQuestRepeats(WindowQuestID()) then
        return
    end
    if Call(IsQuestCompletable) == true then
        Act(CompleteQuest)
    end
end

local function OnComplete()
    if not Option("handin") or Blocked() or AsksForGold() then
        return
    end
    if WindowQuestRepeats(WindowQuestID()) then
        return
    end
    local choices = Call(GetNumQuestChoices)
    if type(choices) ~= "number" or choices > 1 then
        -- Several rewards: yours to pick (WindowBadges marks the best one).
        if type(choices) == "number" then
            Note("Left " .. WindowTitle() .. " open: pick your reward")
        end
        return
    end
    local title = WindowTitle()
    -- No NPC when a finished quest completes itself from the tracker.
    local giver = NPCName()
    if type(GetQuestReward) ~= "function" then
        return
    end
    -- One reward: take it (index 1). None: no choice to pass; should this client insist on a number,
    -- 0 is what its own reward button passes when nothing is selected.
    local done = (choices == 1 and Act(GetQuestReward, 1)) or (choices == 0 and (pcall(GetQuestReward) or Act(GetQuestReward, 0)))
    if done then
        Note("Turned in " .. title .. (giver and (" to " .. giver) or ""))
    end
end

---------------------------------------------------------------------------- hub page

local function OnOff(value)
    return value and (GREEN .. "on|r") or (GRAY .. "off|r")
end

local function Ago(seconds)
    if seconds < 60 then
        return "just now"
    end
    return string.format("%dm ago", math.floor(seconds / 60))
end

local function ShowPage(notice)
    if not db then
        Print(GRAY .. "Not loaded yet.|r")
        return
    end
    if notice then
        Print(notice)
        Print(" ")
    end
    Print("Accepts quests and turns in finished ones when you open a quest giver's window yourself. "
        .. "Hold " .. PAUSE_KEYS[Option("pause")] .. " while you talk to an NPC to do it by hand.")
    Print(GRAY .. "Never: in combat, quests that ask for gold, repeatable or daily quests, a reward you have to choose, "
        .. "quests shared by players, or NPCs on your ignore list.|r")
    Print(" ")
    Print(string.format("Accept quests: %s   Turn in quests: %s   Gray quests: %s   Pause key: |cffffffff%s|r",
        OnOff(Option("accept")), OnOff(Option("handin")), OnOff(Option("gray")), PAUSE_KEYS[Option("pause")]))
    Print(" ")
    Print(GOLD .. "Ignored NPCs|r")
    if #db.ignored == 0 then
        Print(GRAY .. "  None. Talk to an NPC, then type: ignore|r")
    else
        for index, name in ipairs(db.ignored) do
            Print(string.format("  %d. %s", index, name))
        end
    end
    if lastNPC then
        Print(GRAY .. "  Last NPC you talked to: " .. lastNPC .. (IgnoredIndex(lastNPC) and " (ignored)" or "") .. "|r")
    end
    if #recent > 0 then
        Print(" ")
        Print(GOLD .. "This session|r")
        local now = Now()
        for index = #recent, 1, -1 do
            local entry = recent[index]
            Print("  " .. entry.text .. "  " .. GRAY .. Ago(now - entry.time) .. "|r")
        end
    end
end

local function Command(message)
    if not db then
        return ShowPage()
    end
    local text = type(message) == "string" and message:match("^%s*(.-)%s*$") or ""
    local lower = text:lower()
    if lower == "" then
        return ShowPage()
    end
    local key, value = lower:match("^(%a+)%s+(%a+)$")
    local names = { accept = "Accepting quests", handin = "Turning in quests", turnin = "Turning in quests", gray = "Gray quests", grey = "Gray quests" }
    if names[key] and (value == "on" or value == "off") then
        local option = (key == "turnin" and "handin") or (key == "grey" and "gray") or key
        db[option] = value == "on"
        return ShowPage(names[key] .. ": " .. value .. ".")
    end
    if key == "pause" then
        if not PAUSE_KEYS[value] then
            return ShowPage(ORANGE .. "Pause key can be: shift, ctrl or alt.|r")
        end
        db.pause = value
        return ShowPage("Hold " .. PAUSE_KEYS[value] .. " to pause.")
    end
    if lower == "ignore" or lower:match("^ignore%s") then
        local name = text:match("^%a+%s+(.+)$") or NPCName() or lastNPC
        if not name then
            return ShowPage(ORANGE .. "Talk to the NPC first, or type: ignore <name>|r")
        end
        if IgnoredIndex(name) then
            return ShowPage(name .. " is already ignored.")
        end
        if #db.ignored >= MAX_IGNORED then
            return ShowPage(ORANGE .. "The ignore list is full; remove one first.|r")
        end
        db.ignored[#db.ignored + 1] = name
        return ShowPage("Ignoring " .. name .. ".")
    end
    local target = text:match("^[Uu][Nn][Ii][Gg][Nn][Oo][Rr][Ee]%s+(.+)$")
    if target then
        local index = tonumber(target) or IgnoredIndex(target)
        local name = index and db.ignored[index]
        if not name then
            return ShowPage(ORANGE .. "Not on the list: " .. target .. "|r")
        end
        table.remove(db.ignored, index)
        return ShowPage("No longer ignoring " .. name .. ".")
    end
    return ShowPage(ORANGE .. "Not sure what \"" .. text .. "\" means.|r")
end

---------------------------------------------------------------------------- settings for the hub

-- The hub's Options page (ForeverHubExtras.lua) shows these as On/Off switches.
ForeverHubOptions = ForeverHubOptions or {}
ForeverHubOptions[SOURCE] = {
    title = "Auto quest",
    rows = {
        { label = "Accept quests", about = "Accepts quests when you open a quest giver's window. Hold Shift (or your pause key) to skip.",
            get = function() return Option("accept") end, set = function(on) if db then db.accept = on end end },
        { label = "Turn in quests", about = "Turns in finished quests at the NPC you talk to, unless you have to choose a reward.",
            get = function() return Option("handin") end, set = function(on) if db then db.handin = on end end },
        { label = "Gray quests", about = "Also accepts quests far below your level.",
            get = function() return Option("gray") end, set = function(on) if db then db.gray = on end end },
    },
}

---------------------------------------------------------------------------- events

local function Load()
    AutoQuestDB = type(AutoQuestDB) == "table" and AutoQuestDB or {}
    db = AutoQuestDB
    for key, default in pairs(DEFAULTS) do
        if type(db[key]) ~= type(default) then
            db[key] = default
        end
    end
    if not PAUSE_KEYS[db.pause] then
        db.pause = DEFAULTS.pause
    end
    -- Only names, and never more than the list can hold.
    local ignored = {}
    for _, name in ipairs(type(db.ignored) == "table" and db.ignored or {}) do
        if type(name) == "string" and name ~= "" and #ignored < MAX_IGNORED then
            ignored[#ignored + 1] = name
        end
    end
    db.ignored = ignored
end

local HANDLERS = {
    GOSSIP_SHOW = OnGossip,
    QUEST_GREETING = OnGreeting,
    QUEST_DETAIL = OnDetail,
    QUEST_PROGRESS = OnProgress,
    QUEST_COMPLETE = OnComplete,
}

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN")
for name in pairs(HANDLERS) do
    events:RegisterEvent(name)
end
events:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_LOGIN" then
        Load()
        return
    end
    local handler = HANDLERS[event]
    if handler then
        handler()
    end
end)

SLASH_AUTOQUEST1 = "/autoquest"
SlashCmdList.AUTOQUEST = Command
