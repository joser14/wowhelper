-- AutoQuest: every event path (gossip, greeting, detail, progress, reward), every skip rule (pause key,
-- gold, several rewards, repeatable, combat, gray, player-shared, ignored NPC, Off switch, secret
-- values), the hub page and options, and that it calls nothing but the quest window's own functions.
-- Then a sweep: every OTHER helper is loaded and shown the same quest windows, and must not call any
-- accept, complete, reward or select function (AutoQuest itself is the positive control).
-- Run from the harness folder:  node run.js "<workspace root>" test_autoquest.lua
local base = ADDON_PATH
local failures = {}
local function check(cond, why)
    if not cond then failures[#failures + 1] = why end
end
local SECRET = setmetatable({}, { __tostring = function() return "SECRET" end })

----------------------------------------------------------------------------------------------------
-- Game state the mocks read.
local S
local function reset()
    -- The clock only moves forward; each reset is well past the helper's retry wait.
    local now = S and S.now + 1000 or 1000
    S = {
        now = now, combat = false, shift = false, ctrl = false, alt = false,
        npc = "Gryan Stoutmantle", npcIsPlayer = false,
        active = {}, available = {},
        greetActive = {}, greetAvailable = {},
        questID = 100, title = "Westfall Stew", trivial = {}, repeatable = {}, daily = false, weekly = false,
        autoAccept = false, completable = true, money = 0, choices = 0,
        failQuestIDSelect = false,
    }
end
reset()

local calls = {}
local function record(text) calls[#calls + 1] = text end
local function args(...)
    local parts = {}
    for i = 1, select("#", ...) do parts[#parts + 1] = tostring((select(i, ...))) end
    return table.concat(parts, ",")
end

local out, chat, handled = {}, {}, {}
local offSwitch = false

-- Frames: only what AutoQuest uses; anything else on a frame is a failure.
local frames = {}
CreateFrame = function(kind)
    local f = { kind = kind, events = {}, scripts = {} }
    function f:RegisterEvent(e) self.events[e] = true end
    function f:SetScript(s, fn) self.scripts[s] = fn end
    setmetatable(f, { __index = function(_, k) failures[#failures + 1] = "frame method used: " .. tostring(k); return function() end end })
    frames[#frames + 1] = f
    return f
end
SlashCmdList = {}
DEFAULT_CHAT_FRAME = { AddMessage = function(_, t) chat[#chat + 1] = t end }
local realPrint = print
print = function(...) chat[#chat + 1] = args(...) end
issecretvalue = function(v) return v == SECRET end
geterrorhandler = function() return function(e) handled[#handled + 1] = tostring(e) end end
ForeverHub_Receive = function(source, text) out[#out + 1] = { source = source, text = text } end
ForeverHub_IsOff = function(name) return offSwitch and name == "AutoQuest" end
GetTime = function() return S.now end
InCombatLockdown = function() return S.combat end
IsShiftKeyDown = function() return S.shift end
IsControlKeyDown = function() return S.ctrl end
IsAltKeyDown = function() return S.alt end
UnitName = function(unit) if unit == "npc" then return S.npc end end
UnitIsPlayer = function(unit) if unit == "npc" then return S.npcIsPlayer end return false end
hooksecurefunc = function() failures[#failures + 1] = "hooksecurefunc used" end

C_GossipInfo = {
    GetActiveQuests = function() return S.active end,
    GetAvailableQuests = function() return S.available end,
    SelectActiveQuest = function(id)
        if S.failQuestIDSelect and id > 50 then error("bad index") end
        record("gossip.SelectActiveQuest(" .. args(id) .. ")")
    end,
    SelectAvailableQuest = function(id)
        if S.failQuestIDSelect and id > 50 then error("bad index") end
        record("gossip.SelectAvailableQuest(" .. args(id) .. ")")
    end,
    SelectOption = function() record("gossip.SelectOption") end,
    CloseGossip = function() record("gossip.CloseGossip") end,
}
C_QuestLog = {
    IsQuestTrivial = function(id) return S.trivial[id] == true end,
    IsRepeatableQuest = function(id) return S.repeatable[id] == true end,
    IsComplete = function() return false end,
}
GetQuestID = function() return S.questID end
GetTitleText = function() return S.title end
QuestIsDaily = function() return S.daily end
QuestIsWeekly = function() return S.weekly end
QuestGetAutoAccept = function() return S.autoAccept end
IsQuestCompletable = function() return S.completable end
GetQuestMoneyToGet = function() return S.money end
GetNumQuestChoices = function() return S.choices end
AcceptQuest = function(...) record("AcceptQuest(" .. args(...) .. ")") end
CompleteQuest = function(...) record("CompleteQuest(" .. args(...) .. ")") end
GetQuestReward = function(...) record("GetQuestReward(" .. args(...) .. ")") end
DeclineQuest = function() record("DeclineQuest") end
CloseQuest = function() record("CloseQuest") end
-- Old-style greeting window.
GetNumActiveQuests = function() return #S.greetActive end
GetActiveTitle = function(i) local q = S.greetActive[i]; if q then return q.title, q.isComplete end end
GetActiveQuestID = function(i) local q = S.greetActive[i]; return q and q.questID end
GetNumAvailableQuests = function() return #S.greetAvailable end
GetAvailableTitle = function(i) local q = S.greetAvailable[i]; return q and q.title end
GetAvailableQuestInfo = function(i)
    local q = S.greetAvailable[i]
    if q then return q.isTrivial, q.frequency or 0, q.isRepeatable, false, q.questID end
end
SelectActiveQuest = function(i) record("SelectActiveQuest(" .. args(i) .. ")") end
SelectAvailableQuest = function(i) record("SelectAvailableQuest(" .. args(i) .. ")") end
-- Forbidden for everyone, AutoQuest included.
for _, name in ipairs({ "TargetUnit", "InteractUnit", "MoveForwardStart", "BuyMerchantItem", "UseContainerItem",
    "CastSpellByName", "AbandonQuest", "SetAbandonQuest", "AcknowledgeAutoAcceptQuest", "ConfirmAcceptQuest" }) do
    _G[name] = function() record("FORBIDDEN " .. name) end
end

-- From here on: reads of globals that don't exist, and new globals, are recorded.
local unknownReads, newGlobals = {}, {}
setmetatable(_G, {
    __index = function(_, k) unknownReads[tostring(k)] = true end,
    __newindex = function(t, k, v) newGlobals[tostring(k)] = true; rawset(t, k, v) end,
})

----------------------------------------------------------------------------------------------------
local chunk = assert(loadfile(base .. "/AutoQuest/AutoQuest.lua"))
chunk("AutoQuest", {})
local ev = frames[1]
check(ev and ev.scripts.OnEvent, "event frame made")
local expectedEvents = { PLAYER_LOGIN = true, GOSSIP_SHOW = true, QUEST_GREETING = true, QUEST_DETAIL = true,
    QUEST_PROGRESS = true, QUEST_COMPLETE = true }
for e in pairs(ev.events) do
    check(expectedEvents[e], "unexpected event registered: " .. e)
    check(not e:match("^COMBAT_LOG"), "combat log registered")
end
for e in pairs(expectedEvents) do check(ev.events[e], "event not registered: " .. e) end
check(#frames == 1, "one frame only")

local function fire(event, ...)
    calls = {}
    ev.scripts.OnEvent(ev, event, ...)
    return table.concat(calls, " ")
end

-- 0. Before login (saved data not read yet): nothing.
S.active = { { title = "Done", questID = 77, isComplete = true, isTrivial = false } }
check(fire("GOSSIP_SHOW") == "", "nothing before login")
check(fire("QUEST_DETAIL") == "", "no accept before login")
fire("PLAYER_LOGIN")
check(type(AutoQuestDB) == "table" and AutoQuestDB.accept == true and AutoQuestDB.handin == true
    and AutoQuestDB.gray == false and AutoQuestDB.pause == "shift" and type(AutoQuestDB.ignored) == "table", "defaults")

-- 1. Gossip: the finished quest is handed in first, by its questID.
reset()
S.active = {
    { title = "Not yet", questID = 10, isComplete = false, isTrivial = false },
    { title = "Finished", questID = 11, isComplete = true, isTrivial = false },
}
S.available = { { title = "New", questID = 20, isTrivial = false } }
local r = fire("GOSSIP_SHOW")
check(r == "gossip.SelectActiveQuest(11)", "gossip turn-in first: " .. r)
-- The window comes back with nothing left to hand in: the new quest is picked.
S.active = { { title = "Not yet", questID = 10, isComplete = false, isTrivial = false } }
r = fire("GOSSIP_SHOW")
check(r == "gossip.SelectAvailableQuest(20)", "gossip pick-up: " .. r)
-- Back again (you declined it): not picked again right away, but after the retry wait.
r = fire("GOSSIP_SHOW")
check(r == "", "no repeat right away: " .. r)
S.now = S.now + 31
r = fire("GOSSIP_SHOW")
check(r == "gossip.SelectAvailableQuest(20)", "picked again after the wait: " .. r)

-- 1b. Gossip entries: gray, repeatable, daily, ignored by Blizzard's UI are skipped; gray option.
reset()
S.available = {
    { title = "Gray", questID = 21, isTrivial = true },
    { title = "Repeat", questID = 22, isTrivial = false, repeatable = true },
    { title = "Daily", questID = 23, isTrivial = false, frequency = 1 },
    { title = "Hidden", questID = 24, isTrivial = false, isIgnored = true },
}
r = fire("GOSSIP_SHOW")
check(r == "", "skipped gray/repeatable/daily: " .. r)
AutoQuestDB.gray = true
S.now = S.now + 100
r = fire("GOSSIP_SHOW")
check(r == "gossip.SelectAvailableQuest(21)", "gray on picks the gray quest: " .. r)
AutoQuestDB.gray = false
-- Finished but repeatable quests are left alone too.
S.active = { { title = "Cloth", questID = 30, isComplete = true, isTrivial = false, repeatable = true } }
S.available = {}
check(fire("GOSSIP_SHOW") == "", "repeatable turn-in skipped")

-- 1c. Defensive argument: no questID -> list position; a questID the call rejects -> list position.
reset()
S.active = { { title = "No ID", isComplete = true, isTrivial = false } }
r = fire("GOSSIP_SHOW")
check(r == "gossip.SelectActiveQuest(1)", "index when no questID: " .. r)
S.now = S.now + 100
S.failQuestIDSelect = true
S.active = { { title = "x", questID = 12, isComplete = false }, { title = "Rejected", questID = 99, isComplete = true } }
r = fire("GOSSIP_SHOW")
check(r == "gossip.SelectActiveQuest(2)", "falls back to index: " .. r)
check(#handled == 0, "first try's rejection isn't an error: " .. table.concat(handled, "|"))

-- 1d. Secret values in gossip entries: never acted on.
reset()
S.active = { { title = "S", questID = 40, isComplete = SECRET } }
S.available = { { title = "S2", questID = 41, isTrivial = SECRET, repeatable = SECRET, frequency = SECRET } }
r = fire("GOSSIP_SHOW")
check(r == "gossip.SelectAvailableQuest(41)", "secret isComplete skipped, secret trivial treated as unknown: " .. r)
C_QuestLog.IsQuestTrivial = function() return SECRET end
S.now = S.now + 100
r = fire("GOSSIP_SHOW")
check(r == "gossip.SelectAvailableQuest(41)", "secret IsQuestTrivial ok: " .. r)
C_QuestLog.IsQuestTrivial = function(id) return S.trivial[id] == true end
S.available = SECRET
S.active = SECRET
S.now = S.now + 100
check(fire("GOSSIP_SHOW") == "", "secret lists ignored")

-- 2. Greeting window (old style): turn-ins by position, then pick-ups.
reset()
S.greetActive = { { title = "A", isComplete = false, questID = 50 }, { title = "B", isComplete = true, questID = 51 } }
S.greetAvailable = { { title = "C", isTrivial = false, questID = 52 } }
r = fire("QUEST_GREETING")
check(r == "SelectActiveQuest(2)", "greeting turn-in: " .. r)
S.greetActive = {}
r = fire("QUEST_GREETING")
check(r == "SelectAvailableQuest(1)", "greeting pick-up: " .. r)
S.now = S.now + 100
S.greetAvailable = { { title = "G", isTrivial = true, questID = 53 }, { title = "R", isTrivial = false, isRepeatable = true, questID = 54 },
    { title = "D", isTrivial = false, frequency = 1, questID = 55 } }
check(fire("QUEST_GREETING") == "", "greeting skips gray/repeatable/daily")
-- Missing greeting functions: nothing, no error.
local keep = rawget(_G, "SelectActiveQuest")
rawset(_G, "SelectActiveQuest", nil)
S.greetActive = { { title = "B", isComplete = true, questID = 56 } }
check(fire("QUEST_GREETING") == "", "no SelectActiveQuest: nothing")
rawset(_G, "SelectActiveQuest", keep)

-- 3. Quest detail: accept.
reset()
check(fire("QUEST_DETAIL") == "AcceptQuest()", "accept")
S.npcIsPlayer = true
check(fire("QUEST_DETAIL") == "", "player-shared quest not accepted")
S.npcIsPlayer = SECRET
check(fire("QUEST_DETAIL") == "", "unknown giver not accepted")
S.npcIsPlayer = false
S.npc = nil -- started from an item you clicked: no NPC, not a player
check(fire("QUEST_DETAIL") == "AcceptQuest()", "item-started quest accepted")
reset()
S.trivial[100] = true
check(fire("QUEST_DETAIL") == "", "gray not accepted")
AutoQuestDB.gray = true
check(fire("QUEST_DETAIL") == "AcceptQuest()", "gray accepted with the option")
AutoQuestDB.gray = false
reset()
S.repeatable[100] = true
check(fire("QUEST_DETAIL") == "", "repeatable not accepted")
reset()
S.daily = true
check(fire("QUEST_DETAIL") == "", "daily not accepted")
reset()
S.weekly = true
check(fire("QUEST_DETAIL") == "", "weekly not accepted")
reset()
S.autoAccept = true
check(fire("QUEST_DETAIL") == "", "auto-accepted quest left alone")

-- 4. Progress page: complete only when completable and no gold asked.
reset()
check(fire("QUEST_PROGRESS") == "CompleteQuest()", "complete")
S.completable = false
check(fire("QUEST_PROGRESS") == "", "not completable")
S.completable = SECRET
check(fire("QUEST_PROGRESS") == "", "secret completable")
reset()
S.money = 500
check(fire("QUEST_PROGRESS") == "", "gold asked: progress")
S.money = SECRET
check(fire("QUEST_PROGRESS") == "CompleteQuest()", "secret money reads as unknown, not as a price")
reset()
S.repeatable[100] = true
check(fire("QUEST_PROGRESS") == "", "repeatable not completed")

-- 5. Reward page.
reset()
check(fire("QUEST_COMPLETE") == "GetQuestReward()", "no choice: no argument")
S.choices = 1
check(fire("QUEST_COMPLETE") == "GetQuestReward(1)", "one choice: 1")
S.choices = 2
check(fire("QUEST_COMPLETE") == "", "several choices: yours")
S.choices = SECRET
check(fire("QUEST_COMPLETE") == "", "secret choices: nothing")
reset()
S.money = 100
check(fire("QUEST_COMPLETE") == "", "gold asked: reward")
reset()
S.daily = true
check(fire("QUEST_COMPLETE") == "", "daily not turned in")
-- A client that insists on a number for "no choice" gets 0.
reset()
local plain = GetQuestReward
GetQuestReward = function(...)
    if select("#", ...) == 0 or (...) == nil then error("Usage: GetQuestReward(itemChoice)") end
    record("GetQuestReward(" .. args(...) .. ")")
end
check(fire("QUEST_COMPLETE") == "GetQuestReward(0)", "fallback to 0")
GetQuestReward = plain
handled = {}

-- 6. Skip rules that cover every window.
local function all()
    S.now = S.now + 100
    S.active = { { title = "F", questID = 61, isComplete = true } }
    S.available = { { title = "N", questID = 62, isTrivial = false } }
    S.greetActive = { { title = "F", isComplete = true, questID = 63 } }
    S.greetAvailable = { { title = "N", isTrivial = false, questID = 64 } }
    S.choices = 1
    local parts = {}
    for _, e in ipairs({ "GOSSIP_SHOW", "QUEST_GREETING", "QUEST_DETAIL", "QUEST_PROGRESS", "QUEST_COMPLETE" }) do
        parts[#parts + 1] = fire(e)
    end
    return table.concat(parts, "")
end
reset()
check(all() ~= "", "control: acts when nothing blocks")
reset(); S.shift = true
check(all() == "", "Shift pauses everything")
reset(); S.combat = true
check(all() == "", "combat: nothing")
reset(); S.combat = SECRET
check(all() ~= "", "secret combat flag reads as not in combat")
reset(); offSwitch = true
check(all() == "", "switched off on Manage")
offSwitch = false
reset(); AutoQuestDB.accept = false
r = all()
check(not r:find("Accept", 1, true) and not r:find("Available", 1, true) and r:find("CompleteQuest", 1, true), "accept off: " .. r)
AutoQuestDB.accept = true
reset(); AutoQuestDB.handin = false
r = all()
check(not r:find("Active", 1, true) and not r:find("Complete", 1, true) and not r:find("Reward", 1, true) and r:find("AcceptQuest", 1, true), "hand-in off: " .. r)
AutoQuestDB.handin = true

-- 7. The hub page: options, pause key, ignore list.
local function page(arg)
    out = {}
    SlashCmdList.AUTOQUEST(arg)
    local lines = {}
    for _, o in ipairs(out) do
        check(o.source == "AutoQuest", "page source")
        lines[#lines + 1] = o.text
    end
    return table.concat(lines, "\n")
end
local text = page("")
check(text:find("Accept quests:", 1, true) and text:find("Pause key: |cffffffffShift", 1, true), "page shows options")
check(text:find("Last NPC you talked to: Gryan Stoutmantle", 1, true), "page shows the last NPC")
check(text:find("Accepted Westfall Stew", 1, true) and text:find("Turned in Westfall Stew", 1, true), "page shows what it did")
check(text:find("Left Westfall Stew open: pick your reward", 1, true), "page says when a reward is yours to pick")
page("accept off"); check(AutoQuestDB.accept == false, "accept off")
page("accept on"); check(AutoQuestDB.accept == true, "accept on")
page("handin off"); check(AutoQuestDB.handin == false, "handin off")
page("turnin on"); check(AutoQuestDB.handin == true, "turnin on")
page("gray on"); check(AutoQuestDB.gray == true, "gray on")
page("grey off"); check(AutoQuestDB.gray == false, "grey off")
text = page("pause banana")
check(AutoQuestDB.pause == "shift" and text:find("shift, ctrl or alt", 1, true), "bad pause key refused")
page("pause ctrl"); check(AutoQuestDB.pause == "ctrl", "pause ctrl")
reset(); S.shift = true
check(all() ~= "", "Shift no longer pauses with Ctrl chosen")
reset(); S.ctrl = true
check(all() == "", "Ctrl pauses")
page("pause alt")
reset(); S.alt = true
check(all() == "", "Alt pauses")
page("pause shift")
-- Ignore the NPC you're talking to.
reset()
text = page("ignore")
check(AutoQuestDB.ignored[1] == "Gryan Stoutmantle" and text:find("Ignoring Gryan Stoutmantle", 1, true), "ignore current NPC")
text = page("ignore")
check(#AutoQuestDB.ignored == 1 and text:find("already ignored", 1, true), "no duplicates")
check(all() == "", "ignored NPC: nothing")
S.npc = "GRYAN STOUTMANTLE"
check(all() == "", "ignore is case-insensitive")
S.npc = "Salma Saldean"
check(all() ~= "", "other NPC still handled")
page("ignore Old Blanchy")
check(AutoQuestDB.ignored[2] == "Old Blanchy", "ignore by name")
text = page("")
check(text:find("1. Gryan Stoutmantle", 1, true) and text:find("2. Old Blanchy", 1, true), "list shown")
page("unignore 1")
check(#AutoQuestDB.ignored == 1 and AutoQuestDB.ignored[1] == "Old Blanchy", "unignore by number")
page("unignore old blanchy")
check(#AutoQuestDB.ignored == 0, "unignore by name")
text = page("unignore 5")
check(text:find("Not on the list", 1, true), "unignore unknown")
reset(); S.npc = nil
local saved = AutoQuestDB
text = page("what")
check(text:find("Not sure what", 1, true), "unknown command")

-- 8. Options for the hub's Options page.
local options = ForeverHubOptions and ForeverHubOptions.AutoQuest
check(options and #options.rows == 3, "three option rows")
if options then
    for _, row in ipairs(options.rows) do
        local before = row.get()
        row.set(not before)
        check(row.get() == not before, "option row toggles: " .. row.label)
        row.set(before)
    end
end

-- 9. Saved data cleanup on login: bad values replaced, list bounded.
AutoQuestDB = { accept = "yes", pause = "f1", ignored = { "A", 5, "B" } }
for i = 1, 150 do AutoQuestDB.ignored[#AutoQuestDB.ignored + 1] = "N" .. i end
fire("PLAYER_LOGIN")
check(AutoQuestDB.accept == true and AutoQuestDB.pause == "shift", "bad saved values reset")
check(#AutoQuestDB.ignored == 100 and AutoQuestDB.ignored[2] == "B", "ignore list cleaned and bounded: " .. #AutoQuestDB.ignored)
AutoQuestDB = saved
fire("PLAYER_LOGIN")

-- 10. Nothing but the quest window's functions; no chat; no errors; only its own globals.
check(#chat == 0, "no chat output: " .. table.concat(chat, "|"))
check(#handled == 0, "no errors: " .. table.concat(handled, "|"))
for name in pairs(newGlobals) do
    check(name == "AutoQuestDB" or name == "ForeverHubOptions" or name == "SLASH_AUTOQUEST1", "new global: " .. name)
end
-- Globals it looked for that this harness doesn't define must be optional ones it guards.
local OPTIONAL = { IsAvailableQuestTrivial = true, SelectActiveQuest = true, AutoQuestDB = true, ForeverHubOptions = true }
for name in pairs(unknownReads) do
    check(OPTIONAL[name], "read an unknown global: " .. name)
end

setmetatable(_G, nil)

----------------------------------------------------------------------------------------------------
-- Sweep: every other helper, shown the same quest windows, must not act on them.
local ACTIONS = { "AcceptQuest", "CompleteQuest", "GetQuestReward", "SelectActiveQuest", "SelectAvailableQuest",
    "DeclineQuest", "AbandonQuest", "SetAbandonQuest", "ConfirmAcceptQuest", "AcknowledgeAutoAcceptQuest", "SelectGossipOption" }
local HELPERS = {
    { "!ErrorLog", { "!ErrorLog.lua" } }, { "BagCheck", { "BagCheck.lua" } }, { "Builds", { "Data.lua", "Builds.lua" } },
    { "DeathNotes", { "DeathNotes.lua" } }, { "Dungeons", { "Data.lua", "Dungeons.lua" } }, { "DurabilityWatch", { "DurabilityWatch.lua" } },
    { "FoodCheck", { "FoodCheck.lua" } }, { "ForeverHelper", { "ForeverHelper.lua" } }, { "ForeverHub", { "ForeverHub.lua", "ForeverHubExtras.lua" } },
    { "GoldGoal", { "GoldGoal.lua" } }, { "GoldGuide", { "Data.lua", "GoldGuide.lua" } }, { "ItemAdvisor", { "ItemAdvisor.lua" } },
    { "ItemFinder", { "ItemFinder.lua" } }, { "Landmarks", { "Landmarks.lua" } },
    { "LevelGuide", { "QuestIDs.lua", "Prereqs.lua", "Routes.lua", "LevelGuide.lua" } }, { "LevelLog", { "LevelLog.lua" } },
    { "MapPins", { "MapPins.lua" } }, { "PriceMemory", { "PriceMemory.lua" } }, { "ProfessionCap", { "ProfessionCap.lua" } },
    { "ProfessionGuide", { "ProfessionGuide.lua" } }, { "QuestCheck", { "QuestCheck.lua" } }, { "QuestMobs", { "QuestMobs.lua" } },
    { "QuestTracker", { "QuestTracker.lua" } }, { "RareWatch", { "RareWatch.lua" } }, { "ReadyCheck", { "ReadyCheck.lua" } },
    { "RepWatch", { "RepWatch.lua" } }, { "RestGuard", { "RestGuard.lua" } }, { "SupplyWatch", { "SupplyWatch.lua" } },
    { "TalentNudge", { "TalentNudge.lua" } }, { "Tooltips", { "Tooltips.lua" } }, { "TrainerNotes", { "TrainerNotes.lua" } },
    { "WeaponSkillWatch", { "WeaponSkillWatch.lua" } }, { "WindowBadges", { "WindowBadges.lua" } }, { "ZoneLevels", { "ZoneLevels.lua" } },
    { "AutoQuest", { "AutoQuest.lua" } },
}
local QUEST_EVENTS = { "GOSSIP_SHOW", "QUEST_GREETING", "QUEST_DETAIL", "QUEST_PROGRESS", "QUEST_COMPLETE", "QUEST_ACCEPT_CONFIRM" }

local function sweep(name, files)
    local acted, quest = {}, {}
    local frameList = {}
    local function newFrame()
        local f = { registered = {}, scripts = {} }
        frameList[#frameList + 1] = f
        return setmetatable(f, { __index = function(_, k)
            if k == "RegisterEvent" then return function(self, e) self.registered[e] = true end end
            if k == "SetScript" then return function(self, s, fn) self.scripts[s] = fn end end
            if k == "HookScript" then return function() end end
            if k == "CreateFontString" or k == "CreateTexture" then return function() return newFrame() end end
            if k == "GetStringHeight" or k == "GetHeight" or k == "GetWidth" or k == "GetVerticalScroll" then return function() return 10 end end
            if k == "GetText" then return function() return "" end end
            return function() return nil end
        end })
    end
    local env = {
        -- Everything that would tempt a helper to act: a finished quest, a new one, an NPC.
        C_GossipInfo = {
            GetActiveQuests = function() return { { title = "Done", questID = 1, isComplete = true, isTrivial = false } } end,
            GetAvailableQuests = function() return { { title = "New", questID = 2, isTrivial = false } } end,
            SelectActiveQuest = function() acted[#acted + 1] = "C_GossipInfo.SelectActiveQuest" end,
            SelectAvailableQuest = function() acted[#acted + 1] = "C_GossipInfo.SelectAvailableQuest" end,
            SelectOption = function() acted[#acted + 1] = "C_GossipInfo.SelectOption" end,
            GetOptions = function() return {} end,
        },
        GetNumActiveQuests = function() return 1 end, GetActiveTitle = function() return "Done", true end,
        GetNumAvailableQuests = function() return 1 end, GetAvailableQuestInfo = function() return false, 0, false, false, 2 end,
        IsQuestCompletable = function() return true end, GetNumQuestChoices = function() return 0 end,
        GetQuestMoneyToGet = function() return 0 end, GetQuestID = function() return 2 end,
        UnitIsPlayer = function() return false end, UnitName = function() return "Quest Giver" end,
        InCombatLockdown = function() return false end, IsShiftKeyDown = function() return false end,
        CreateFrame = function() return newFrame() end,
        UIParent = newFrame(), Minimap = newFrame(), GameTooltip = newFrame(), WorldMapFrame = newFrame(),
        SlashCmdList = {}, UISpecialFrames = {}, ForeverHub_Receive = function() end,
        DEFAULT_CHAT_FRAME = { AddMessage = function() end }, UIErrorsFrame = { AddMessage = function() end },
        C_Timer = { After = function() end, NewTicker = function() end, NewTimer = function() end },
        Enum = setmetatable({}, { __index = function() return setmetatable({}, { __index = function() return 0 end }) end }),
        issecretvalue = function() return false end, geterrorhandler = function() return function() end end,
        seterrorhandler = function() end, hooksecurefunc = function() acted[#acted + 1] = "hooksecurefunc" end,
        GetTime = function() return 1000 end, time = function() return 1000 end, date = function() return "now" end,
        tinsert = table.insert, tremove = table.remove, wipe = function(t) for k in pairs(t) do t[k] = nil end return t end,
        strsplit = function(sep, s) local t = {} for p in (s .. sep):gmatch("(.-)" .. sep:gsub("%p", "%%%0")) do t[#t + 1] = p end return table.unpack(t) end,
        debugstack = function() return "" end,
    }
    for _, action in ipairs(ACTIONS) do
        env[action] = function() acted[#acted + 1] = action end
    end
    for k, v in pairs(_G) do
        if env[k] == nil and (type(v) == "table" and (k == "string" or k == "table" or k == "math" or k == "os" or k == "coroutine" or k == "utf8")
            or type(v) == "function" and k:match("^%l")) then
            env[k] = v
        end
    end
    env._G = env
    setmetatable(env, { __index = function(_, k)
        if type(k) ~= "string" then return nil end
        if k:match("^C_") then return setmetatable({}, { __index = function() return function() return nil end end }) end
        if k:match("^[A-Z][a-z]") and not k:match("DB$") and not k:match("^Forever") and not k:match("^LevelGuide") then
            return function() return nil end
        end
        return nil
    end })
    local ns = {}
    local loaded = true
    for _, file in ipairs(files) do
        local fn = loadfile(base .. "/" .. name .. "/" .. file, "t", env)
        if not fn then loaded = false break end
        local ok = pcall(fn, name, ns)
        if not ok then loaded = false end
    end
    local function fireAll(event, ...)
        for _, f in ipairs(frameList) do
            local onEvent = f.scripts.OnEvent
            if onEvent and f.registered[event] then pcall(onEvent, f, event, ...) end
        end
    end
    fireAll("ADDON_LOADED", name)
    fireAll("PLAYER_LOGIN")
    fireAll("PLAYER_ENTERING_WORLD", true, false)
    for _, event in ipairs(QUEST_EVENTS) do
        fireAll(event)
        for _, f in ipairs(frameList) do
            if f.registered[event] then quest[event] = true end
        end
    end
    return acted, loaded, quest
end

local controlActed
for _, helper in ipairs(HELPERS) do
    local name = helper[1]
    local acted, loaded = sweep(name, helper[2])
    -- A helper that fails to load here would pass without being looked at.
    check(loaded, name .. " didn't load in the sweep")
    if name == "AutoQuest" then
        controlActed = acted
    else
        check(#acted == 0, name .. " acted on a quest window: " .. table.concat(acted, ", "))
    end
end
-- Positive control: the same harness sees AutoQuest act.
local seen = {}
for _, a in ipairs(controlActed or {}) do seen[a] = true end
check(seen.AcceptQuest and seen.CompleteQuest and seen.GetQuestReward and seen["C_GossipInfo.SelectActiveQuest"] and seen.SelectActiveQuest,
    "sweep harness sees AutoQuest act: " .. table.concat(controlActed or {}, ", "))

if #failures > 0 then
    error(#failures .. " failure(s):\n" .. table.concat(failures, "\n"))
end
realPrint("ALL TESTS PASSED")
