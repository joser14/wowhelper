-- Round 5 (Dungeons): #3 instance log (entries per hour and day against a cap that is a setting, per-run
-- stats, new copy told from a re-entry), #7 wish list (window ticks, page, Dungeons_IsWished), #12 Group
-- Finder listings read only after the player's own search (never a search, an application or a sign-up).
-- Run from the tests folder:  node run.js "<repo root>" test_r5d_dungeons.lua
local base = ADDON_PATH
local out, frames, failures = {}, {}, {}
local function check(cond, why) if not cond then failures[#failures + 1] = why .. "\n  output was:\n  " .. table.concat(out, "\n  ") end end

-- A frame that accepts any method; the ones the tests look at keep their state.
local function NewFrame(kind, name)
    local f = { kind = kind, name = name, registered = {}, scripts = {}, shown = true, text = "", checked = false }
    function f:RegisterEvent(e) self.registered[e] = true end
    function f:SetScript(what, fn) self.scripts[what] = fn; if what == "OnEvent" then self.fn = fn end end
    function f:Show() local was = self.shown; self.shown = true; if not was and self.scripts.OnShow then self.scripts.OnShow(self) end end
    function f:Hide() self.shown = false end
    function f:SetShown(v) if v then self:Show() else self:Hide() end end
    function f:IsShown() return self.shown end
    function f:SetText(t) self.text = t end
    function f:GetText() return self.text end
    function f:SetChecked(v) self.checked = v and true or false end
    function f:GetChecked() return self.checked end
    function f:GetStringHeight() return 100 end
    function f:CreateFontString() return NewFrame("FontString") end
    function f:GetPoint() return "CENTER", nil, "CENTER", 0, 0 end
    return setmetatable(f, { __index = function() return function() end end })
end
CreateFrame = function(kind, name)
    local f = NewFrame(kind, name)
    frames[#frames + 1] = f
    return f
end
UIParent = NewFrame("Frame", "UIParent")
SlashCmdList = {}
ForeverHub_Receive = function(_, t) out[#out + 1] = t end
local secret = {}
issecretvalue = function(v) return secret[v] == true end

local now, mono = 1000000, 500
time = function() return now end
GetTime = function() return mono end
date = function(fmt, t) return "day " .. tostring(t) end
UnitName = function() return "Ana", "Moon" end
UnitGUID = function(unit) return unit == "player" and "Player-1-0001" or nil end
GetRealmName = function() return "Realm" end
local level, xp, xpMax, money = 18, 1000, 9000, 5000
UnitLevel = function() return level end
UnitXP = function() return xp end
UnitXPMax = function() return xpMax end
GetMoney = function() return money end
UnitClass = function() return "Priest", "PRIEST" end
UnitFactionGroup = function() return "Alliance" end
C_QuestLog = { IsQuestFlaggedCompleted = function() return false end, GetLogIndexForQuestID = function() return nil end, IsComplete = function() return false end }
local bags = {}
C_Item = {
    GetItemCount = function(id) return bags[id] or 0 end,
    GetItemInfo = function(id)
        local n = tonumber(id) or tonumber(tostring(id):match("item:(%d+)"))
        return "Item " .. tostring(n), "|Hitem:" .. tostring(n) .. "|h[Item " .. tostring(n) .. "]|h", n == 9999 and 3 or 2
    end,
}
local inside, instanceName, instanceID = false, nil, nil
IsInInstance = function() return inside, inside and "party" or "none" end
GetInstanceInfo = function() return instanceName or "Elwynn Forest", inside and "party" or "none", 1, "Normal", 5, 0, false, instanceID or 0 end
local lootLinks = {}
GetNumLootItems = function() return #lootLinks end
GetLootSlotLink = function(slot) return lootLinks[slot] end

-- Group Finder: results only; any search or application call is recorded as a failure.
local forbidden = {}
local results, infos = {}, {}
C_LFGList = {
    GetSearchResults = function() return #results, results end,
    GetSearchResultInfo = function(id) return infos[id] end,
    GetActivityInfoTable = function(id)
        if id == 799 then return { fullName = "The Deadmines", minLevel = 10, minLevelSuggestion = 17, maxLevelSuggestion = 26 } end
        if id == 801 then return { fullName = "Scarlet Monastery", minLevel = 20, minLevelSuggestion = 30, maxLevelSuggestion = 45 } end
        return nil
    end,
}
for _, fn in ipairs({ "Search", "ApplyToGroup", "CreateListing", "UpdateListing", "RefreshResults", "SetSearchToActivity" }) do
    C_LFGList[fn] = function() forbidden[#forbidden + 1] = fn end
end

local timers = {}
C_Timer = { After = function(_, fn) timers[#timers + 1] = fn end, NewTicker = function() end }
local function flush()
    local n = 0
    while #timers > 0 and n < 1000 do
        n = n + 1
        table.remove(timers, 1)()
    end
end

assert(loadfile(base .. "/Dungeons/Data.lua"))("Dungeons", {})
assert(loadfile(base .. "/Dungeons/Dungeons.lua"))("Dungeons", {})
local f = frames[1]
local function fire(ev, ...) f.fn(f, ev, ...) end
local function has(text) for _, t in ipairs(out) do if t:find(text, 1, true) then return t end end return nil end
local function page(arg) out = {}; local ok, err = pcall(SlashCmdList.DUNGEONS, arg); if not ok then out[#out + 1] = "<<ERROR " .. tostring(err) .. ">>" end; flush() end
local function enter(name, id) inside, instanceName, instanceID = true, name, id; fire("PLAYER_ENTERING_WORLD"); flush() end
local function leave() inside, instanceName, instanceID = false, nil, nil; fire("PLAYER_ENTERING_WORLD"); flush() end
local function runs() return DungeonsDB and DungeonsDB.runs or {} end

fire("PLAYER_LOGIN")
flush()

-- Events: plain ones only, never the combat log or a CallbackEvent.
for _, name in ipairs({ "ZONE_CHANGED_NEW_AREA", "CHAT_MSG_COMBAT_XP_GAIN", "PLAYER_XP_UPDATE", "PLAYER_MONEY", "PLAYER_DEAD",
    "LOOT_OPENED", "LOOT_CLOSED", "UPDATE_MOUSEOVER_UNIT", "NAME_PLATE_UNIT_ADDED", "LFG_LIST_SEARCH_RESULTS_RECEIVED" }) do
    check(f.registered[name], "listens for " .. name)
end
for name in pairs(f.registered) do
    check(not name:find("^COMBAT_LOG"), "no combat log event: " .. name)
end

-- #3 A first run: time, XP kills, XP, gold looted, deaths, notable loot, levels.
out = {}
enter("The Deadmines", 36)
check(#runs() == 1, "one run after entering: " .. #runs())
local run = runs()[1]
check(run and run.inSince == now and run.name == "The Deadmines" and run.lvlIn == 18, "run opened with level in")
fire("CHAT_MSG_COMBAT_XP_GAIN", "secret text")
fire("CHAT_MSG_COMBAT_XP_GAIN", "secret text")
xp = 1400; fire("PLAYER_XP_UPDATE", "player")
-- Level-up while UnitLevel still gives the old level: counted once.
xp = 200; fire("PLAYER_XP_UPDATE", "player")
level = 19; xpMax = 10000; xp = 300; fire("PLAYER_XP_UPDATE", "player")
check(run.kills == 2, "two kills with XP: " .. tostring(run.kills))
check(run.xp == 400 + 7800 + 100, "XP over a level-up: " .. tostring(run.xp))
-- Money while a loot window is open counts; a vendor sale later doesn't.
lootLinks = { "|cff1eff00|Hitem:5191::::|h[Cruel Barb]|h|r", "|Hitem:2589::::|h[Linen Cloth]|h", "|Hitem:9999::::|h[Blue Thing]|h" }
fire("LOOT_OPENED", false, false)
money = 5300; fire("PLAYER_MONEY")
bags[5191] = 1; bags[2589] = 3; bags[9999] = 1
fire("LOOT_CLOSED")
flush()
mono = mono + 10
money = 6300; fire("PLAYER_MONEY")
check(run.gold == 300, "gold looted only: " .. tostring(run.gold))
check(#run.loot == 2 and run.loot[1] ~= 2589 and run.loot[2] ~= 2589, "notable loot only (dungeon item and blue): " .. #run.loot)
fire("PLAYER_DEAD")
check(run.deaths == 1, "a death counted")
now = now + 1500
leave()
check(run.inSince == nil and run.leave == now and run.secs == 1500 and run.lvlOut == 19, "visit closed with time and level out")
-- Nothing counts outside.
fire("CHAT_MSG_COMBAT_XP_GAIN", "x")
check(run.kills == 2, "kills outside don't count")

page("log")
check(has("1 of 5 this hour, 1 of 30 today"), "entry counts on the log page")
check(has("The Deadmines") and has("2 kills with XP") and has("8300 XP") and has("3s 0c looted") and has("1 death"), "run line stats")
check(has("level 18 to 19") and has("Loot:") and has("Item 5191"), "levels and loot shown")
check(has("isn't confirmed"), "cap is said to be unconfirmed")

-- Back in within 30 minutes, no GUID readable: the same run (re-entry rule).
now = now + 600
enter("The Deadmines", 36)
check(#runs() == 1 and run.reentries == 1 and run.judged == "time", "re-entry within the window is the same run")
-- A creature GUID names the copy.
UnitGUID = function(unit) if unit == "mouseover" then return "Creature-0-4372-36-1111-644-0000AAAA" end return "Player-1-0001" end
fire("UPDATE_MOUSEOVER_UNIT")
check(run.copy == "4372-36-1111" and run.judged == "ids", "copy learned from a creature GUID: " .. tostring(run.copy))
now = now + 300
leave()

-- Back in again within the window, but the creatures show another copy: a new run after all.
now = now + 300
enter("The Deadmines", 36)
check(#runs() == 1 and run.reentries == 2, "taken for a re-entry first")
UnitGUID = function(unit) if unit == "target" then return "Creature-0-4372-36-2222-645-0000BBBB" end return "Player-1-0001" end
fire("PLAYER_TARGET_CHANGED")
check(#runs() == 2 and run.reentries == 1 and run.inSince == nil, "split into a new run when the copy differs")
local second = runs()[2]
check(second.copy == "4372-36-2222" and second.inSince ~= nil, "the new run is open with its copy")
now = now + 600
leave()

-- 40 minutes later: a new run by the rule, but the creatures show the earlier copy: merged back.
now = now + 2400
enter("The Deadmines", 36)
check(#runs() == 3, "new run after the window")
UnitGUID = function(unit) if unit == "target" then return "Creature-0-4372-36-2222-646-0000CCCC" end return "Player-1-0001" end
fire("PLAYER_TARGET_CHANGED")
check(#runs() == 2 and second.reentries == 1 and second.inSince ~= nil, "merged into the run of the same copy")
-- Secret GUIDs are ignored.
leave()

-- Cap warnings: cap 3 an hour, then two more new dungeons.
page("cap 3 30")
check(has("3 an hour and 30 a day"), "cap set from the page")
out = {}
now = now + 4000
enter("Shadowfang Keep", 33)
leave()
check(not has("Dungeon entries"), "no warning far from the cap")
now = now + 100
enter("Wailing Caverns", 43)
check(has("one more new dungeon reaches the cap"), "near the cap: warned: " .. tostring(has("Dungeon entries")))
local status = ForeverHubStatus.Dungeons()
check(status == nil or not (status[1] and status[1].text:find("entries", 1, true)), "no cap line while inside")
leave()
status = ForeverHubStatus.Dungeons()
check(status and status[1] and status[1].text:find("2 of 3 this hour", 1, true), "side panel near the cap")
out = {}
now = now + 100
enter("Blackfathom Deeps", 48)
check(has("at the cap"), "at the cap: warned")
leave()
page("log")
check(has("t the cap: a new dungeon may be refused for about"), "log page names the wait")
-- Settings are bounded.
page("cap 0 9999")
check(DungeonsDB.settings.hourCap == 1 and DungeonsDB.settings.dayCap == 200, "caps clamped")
page("cap 5 30")
page("reentry 1")
check(DungeonsDB.settings.reentryMinutes == 5, "re-entry window clamped")

-- Runs are bounded.
for i = 1, 150 do
    now = now + 4000
    enter("Run " .. i, 1000 + i)
    leave()
end
check(#runs() == 100, "at most 100 runs kept: " .. #runs())

-- #7 Wish list.
page("wish")
check(has("Nothing on it yet"), "empty wish list")
check(Dungeons_IsWished(5191) == false, "not wished yet")
page("wish deadmines 1")
check(has("Cruel Barb is on your wish list"), "added from the page")
local wished, where, boss = Dungeons_IsWished(5191)
check(wished == true and where == "The Deadmines" and boss == "Edwin VanCleef", "global read: " .. tostring(where) .. " / " .. tostring(boss))
check(Dungeons_IsWished("|cff0070dd|Hitem:5191::::::::19:::::|h[Cruel Barb]|h|r") == true, "global read takes a link")
check(Dungeons_IsWished(nil) == false and Dungeons_IsWished("junk") == false, "global read with bad input")
page("wish")
check(has("Cruel Barb") and has("Edwin VanCleef, The Deadmines") and has("(you have it)"), "wish list on the page")
page("")
local dmLine = has("The Deadmines") or ""
check(dmLine:find("RaidTargetingIcon_1", 1, true), "dungeon line shows the wish count")
page("dm")
check((has("Cruel Barb") or ""):find("wish list", 1, true), "loot line marked")
check(has("Wish list: tick items"), "details page explains how to wish")
-- A wished item in a loot window: a pop-up, nothing looted for you.
out = {}
lootLinks = { "|Hitem:5191::::|h[Cruel Barb]|h" }
fire("LOOT_OPENED", false, false)
fire("LOOT_CLOSED")
flush()
check(has("On your wish list, in this loot: "), "wish item in loot: pop-up")
-- Only dungeon items.
page("wish 99 1")
check(has("Type wish"), "bad wish arguments explained")

-- #12 Group Finder: nothing before your own search.
page("groups")
check(has("Search the game's Group Finder"), "no listings before a search")
results = { 11, 12, 13, 14, 15, 16 }
infos[11] = { activityIDs = { 799 }, numMembers = 3, age = 60, isDelisted = false, hasSelf = false, name = "never read" }
infos[12] = { activityIDs = { 799 }, numMembers = 4, age = 30, isDelisted = false }
infos[13] = { activityIDs = { 801 }, numMembers = 2, age = 30, isDelisted = false }
infos[14] = { activityIDs = { 799 }, numMembers = 1, age = 30, isDelisted = true }
infos[15] = { activityIDs = { 12345 }, numMembers = 1, age = 30 }
local hidden = {}
secret[hidden] = true
infos[16] = { activityIDs = hidden, numMembers = 1, age = 30 }
level = 19
fire("LFG_LIST_SEARCH_RESULTS_RECEIVED")
page("groups")
check((has("The Deadmines") or ""):find("2 groups (3/5, 4/5)", 1, true), "Deadmines groups: " .. tostring(has("The Deadmines")))
check((has("The Deadmines") or ""):find("quests to do there", 1, true), "quests named")
check((has("The Deadmines") or ""):find("wish list", 1, true), "wish items named")
check(has("Also listed: 3 groups"), "other listings counted: " .. tostring(has("Also listed")))
status = ForeverHubStatus.Dungeons()
local found = false
for _, line in ipairs(status or {}) do if line.text:find("Group Finder: 2 groups", 1, true) then found = true end end
check(found, "side panel names the groups that fit")
check(#forbidden == 0, "never searched or applied: " .. table.concat(forbidden, ", "))

-- Window: tabs, wish ticks, Off from the hub.
page("window")
local w
for _, fr in ipairs(frames) do if fr.name == "DungeonsWindow" then w = fr end end
check(w and w.shown, "window opens")
check(w and w.scripts and true, "window built")
-- Find the wish tab and a row.
local wishTab
for _, fr in ipairs(frames) do if fr.kind == "Button" and fr.text == "Wish list" then wishTab = fr end end
check(wishTab, "wish tab exists")
if wishTab then wishTab.scripts.OnClick(wishTab) end
local rowCheck
for _, fr in ipairs(frames) do
    if fr.kind == "CheckButton" and fr.shown and fr.checked == false and not rowCheck then rowCheck = fr end
end
check(rowCheck, "an unticked item row")
if rowCheck then
    rowCheck.scripts.OnClick(rowCheck)
    check(rowCheck.checked == true, "ticking adds the item")
end
local count = 0
for _ in pairs(DungeonsDB.wish[next(DungeonsDB.wish)]) do count = count + 1 end
check(count == 2, "two items wished: " .. count)
ForeverHubOnSwitch.Dungeons(true)
check(w and not w.shown, "Off hides the window")
ForeverHubOnSwitch.Dungeons(false)
check(w and w.shown, "On shows it again")
page("window")
check(w and not w.shown, "window toggles closed")

-- Static (compiled code, so comments don't count): no apply, chat output, hooks or Blizzard tables.
local src = string.dump(assert(loadfile(base .. "/Dungeons/Dungeons.lua")))
for _, bad in ipairs({ "ApplyToGroup", "CreateListing", "SetSearchToActivity", "AddMessage", "hooksecurefunc",
    "UISpecialFrames", "AddDataProvider", "AcquirePin", "COMBAT_LOG" }) do
    check(not src:find(bad, 1, true), "source has no " .. bad)
end
check(not has("<<ERROR"), "no errors")

if #failures > 0 then
    print("FAILURES (" .. #failures .. "):")
    for _, why in ipairs(failures) do print(" - " .. why) end
    os.exit(1)
end
print("test_r5d_dungeons: all checks passed")
