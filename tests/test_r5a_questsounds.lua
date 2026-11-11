-- Round 5 #6 (research\re_round5.md): QuestTracker's quest sounds. Progress, objective done and quest
-- complete each have their own switch and sound on the "Snd" pop-up; progress is off by default. Built-in
-- sound kits through PlaySound; nothing at login, after a loading screen or for a quest you just picked up.
local path = ADDON_PATH
if not path:find("%.lua$") then path = path .. "/QuestTracker/QuestTracker.lua" end
local frames, handled, chat, sounds, timers = {}, {}, {}, {}, {}
local combat, tick = false, nil
local function newRegion(kind, template)
    local r = { kind = kind, template = template, shown = true, scripts = {}, text = "" }
    function r:SetText(t) self.text = t end
    function r:GetText() return self.text end
    function r:SetScript(s, f) self.scripts[s] = f end
    function r:Show() self.shown = true end
    function r:Hide() self.shown = false end
    function r:SetShown(v) self.shown = v and true or false end
    function r:IsShown() return self.shown end
    function r:IsMouseOver() return false end
    function r:GetLeft() return 100 end
    function r:GetTop() return 500 end
    function r:GetRight() return 390 end
    function r:GetEffectiveScale() return 1 end
    function r:CreateFontString() return newRegion("font") end
    function r:CreateTexture() return newRegion("texture") end
    return setmetatable(r, { __index = function(_, k)
        if k == "quest" or k == "section" or k == "objectiveIndex" or k == "offer" or k == "link"
            or k == "isTitle" or k == "questID" then return nil end
        return function() end
    end })
end
CreateFrame = function(kind, name, parent, template)
    local f = newRegion(kind, template)
    frames[#frames + 1] = f
    if name then _G[name] = f end
    return f
end
UIParent = newRegion("Frame")
ObjectiveTrackerFrame = newRegion("Frame")
local SECRET = {}
issecretvalue = function(v) return v == SECRET end
InCombatLockdown = function() return combat end
geterrorhandler = function() return function(e) handled[#handled + 1] = tostring(e) end end
DEFAULT_CHAT_FRAME = { AddMessage = function(_, t) chat[#chat + 1] = t end }
local say = print
print = function(...) chat[#chat + 1] = table.concat({ ... }, " ") end
C_Timer = { NewTicker = function(_, fn) tick = fn end, After = function(_, fn) timers[#timers + 1] = fn end }
local now = 1000
GetTime = function() return now end
GetServerTime = function() return 100000 end
UnitLevel = function() return 10 end
UnitXPMax = function() return 1000 end
GetRealZoneText = function() return "Teldrassil" end
-- Most kits by name; READY_CHECK missing here, so its number is used.
SOUNDKIT = { IG_MAINMENU_OPTION_CHECKBOX_ON = 856, IG_QUEST_LIST_SELECT = 877, IG_QUEST_LIST_COMPLETE = 878, MAP_PING = 3175, TELL_MESSAGE = 3081 }
PlaySound = function(id, channel) sounds[#sounds + 1] = { id = id, channel = channel }; return true end

local log, data = {}, {}
local function header(title) log[#log + 1] = { isHeader = true, title = title } end
local function quest(id, title, objectives, ready)
    log[#log + 1] = { questID = id, title = title, level = 5, difficultyLevel = 5, questLogIndex = #log + 1 }
    data[id] = { objectives = objectives, ready = ready or false }
end
local function obj(have, need, finished)
    if finished == nil then finished = have >= need end
    return { text = "Thing: " .. tostring(have) .. "/" .. need, numFulfilled = have, numRequired = need, finished = finished }
end
C_QuestLog = {
    GetNumQuestLogEntries = function() return #log, 3 end,
    GetMaxNumQuestsCanAccept = function() return 25 end,
    GetInfo = function(i) return log[i] end,
    IsComplete = function(id) return data[id].ready end,
    ReadyForTurnIn = function() return false end,
    IsQuestTrivial = function() return false end,
    GetQuestObjectives = function(id) return data[id].objectives end,
}
GetQuestLogRewardXP = function() return 0 end

header("Teldrassil")
quest(10, "Wolves", { obj(0, 5), obj(0, 2) })
quest(11, "Cave", { obj(1, 1, false) })
QuestTrackerDB = {}
assert(loadfile(path))("QuestTracker", {})
local events = frames[1]
local function fire(...) events.scripts.OnEvent(events, ...) end
fire("PLAYER_LOGIN")
local function update()
    fire("QUEST_LOG_UPDATE")
    local pending = timers
    timers = {}
    for _, fn in ipairs(pending) do fn() end
end

-- 1. Defaults: progress off, the other two on.
local s = QuestTrackerDB.sounds
assert(s and s.progress.on == false and s.objective.on == true and s.complete.on == true, "defaults")
-- The first reading only remembers, and login is quiet anyway.
update()
assert(#sounds == 0, "first reading silent")
-- Still in the quiet seconds after login: a change is remembered but makes no sound.
data[10].objectives[1] = obj(5, 5)
update()
assert(#sounds == 0, "quiet after login")
now = now + 6
say("1 ok")

-- 2. Progress is off by default; switched on, it plays its sound.
data[10].objectives[2] = obj(1, 2)
update()
assert(#sounds == 0, "progress off by default")
s.progress.on = true
data[10].objectives[2] = obj(1, 2)
quest(12, "New", { obj(3, 5) })     -- picked up with progress already: no sound for it
update()
assert(#sounds == 0, "a new quest is silent")
data[12].objectives[1] = obj(4, 5)
update()
assert(#sounds == 1 and sounds[1].id == 856 and sounds[1].channel == "SFX", "progress sound: " .. tostring(sounds[1] and sounds[1].id))
-- Several quests moving in one update: one sound.
data[12].objectives[1] = obj(5, 5)
data[10].objectives[2] = obj(2, 2)
data[10].ready = true
update()
assert(#sounds == 2 and sounds[2].id == 878, "quest complete wins: " .. tostring(sounds[2] and sounds[2].id))
say("2 ok")

-- 3. Objective done; the 1/1-but-unfinished row isn't done until the game says so.
data[11].objectives[1] = obj(1, 1, false)
update()
assert(#sounds == 2, "1/1 unfinished is not news")
data[11].objectives[1] = obj(1, 1, true)
update()
assert(#sounds == 3 and sounds[3].id == 877, "objective done: " .. tostring(sounds[3] and sounds[3].id))
-- Complete off: an objective that finishes a quest plays the objective sound instead.
s.complete.on = false
quest(13, "Two step", { obj(0, 1) })
update()
data[13].objectives[1] = obj(1, 1)
data[13].ready = true
update()
assert(#sounds == 4 and sounds[4].id == 877, "falls back to objective")
s.complete.on = true
say("3 ok")

-- 4. Secret readings are skipped and keep the last value, so they don't sound when they come back.
quest(14, "Hidden", { obj(1, 4) })
update()
data[14].objectives[1] = { text = "x", numFulfilled = SECRET, numRequired = 4, finished = SECRET }
update()
data[14].objectives[1] = obj(1, 4)
update()
assert(#sounds == 4, "secret then same value: no sound")
-- After a loading screen: quiet again for a few seconds.
fire("PLAYER_ENTERING_WORLD")
data[14].objectives[1] = obj(2, 4)
update()
assert(#sounds == 4, "quiet after a loading screen")
now = now + 6
say("4 ok")

-- 5. The Snd pop-up: switches and sound choices, out of combat.
local snd
for _, f in ipairs(frames) do if f.kind == "Button" and f.text == "Snd" then snd = f end end
assert(snd, "Snd button in the header")
combat = true
snd.scripts.OnClick(snd)
local before = #frames
combat = false
snd.scripts.OnClick(snd)
assert(#frames > before, "pop-up built out of combat")
local toggles, choices, plays = {}, {}, {}
for i = before + 1, #frames do
    local f = frames[i]
    if f.kind == "Button" then
        if f.text == "Play" then plays[#plays + 1] = f
        elseif f.text:find("On|r", 1, true) or f.text:find("Off|r", 1, true) then toggles[#toggles + 1] = f
        else choices[#choices + 1] = f end
    end
end
assert(#toggles == 3 and #choices == 3 and #plays == 3, "three rows: " .. #toggles .. "/" .. #choices .. "/" .. #plays)
toggles[2].scripts.OnClick(toggles[2])
assert(s.objective.on == false and toggles[2].text:find("Off", 1, true), "objective switched off")
local n = #sounds
choices[3].scripts.OnClick(choices[3])
assert(s.complete.choice == 6 and #sounds == n + 1 and sounds[#sounds].id == 8960, "next sound plays once (by number)")
choices[3].scripts.OnClick(choices[3])
assert(s.complete.choice == 1, "wraps around")
plays[1].scripts.OnClick(plays[1])
assert(#sounds == n + 3, "play button")
say("5 ok")

-- 6. All off: nothing is read; turned back on, the first reading is silent again.
s.progress.on, s.objective.on, s.complete.on = false, false, false
data[14].objectives[1] = obj(3, 4)
n = #sounds
update()
s.progress.on = true
update()
assert(#sounds == n, "fresh start after all off")
data[14].objectives[1] = obj(4, 4)
s.objective.on = true
update()
assert(#sounds == n + 1, "plays again")
-- No PlaySound on the client: nothing breaks.
PlaySound = nil
data[10].objectives = { obj(0, 5), obj(0, 2) }
data[10].ready = false
quest(15, "Last", { obj(0, 3) })
update()
data[15].objectives[1] = obj(1, 3)
update()
say("6 ok")

assert(#chat == 0, "no chat: " .. tostring(chat[1]))
assert(#handled == 0, "no errors: " .. table.concat(handled, " | "))
say("ALL TESTS PASSED")
