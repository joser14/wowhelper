-- New QuestTracker behavior: default spot under the minimap, tags off the title, class/race quests,
-- timers, item cooldown and range, combat reload, focus in combat, NEW-stamp pruning.
local path = ADDON_PATH
local frames, handled, blocked = {}, {}, {}
local combat, tick = true, nil
local function newRegion(kind, template)
    local r = { kind = kind, template = template, shown = true, scripts = {}, hooks = {}, attrs = {}, text = "" }
    function r:SetText(t) self.text = t end
    function r:GetText() return self.text end
    function r:SetScript(s, f) self.scripts[s] = f end
    function r:HookScript(s, f) self.hooks[s] = f end
    function r:Show() if combat and self.watchCombat then blocked[#blocked + 1] = "Show" end self.shown = true end
    function r:Hide() if combat and self.watchCombat then blocked[#blocked + 1] = "Hide" end self.shown = false end
    function r:SetShown(v) if combat and self.watchCombat and (v and true or false) ~= self.shown then blocked[#blocked + 1] = "SetShown" end self.shown = v and true or false end
    function r:IsShown() return self.shown end
    function r:SetAttribute(k, v)
        if combat then blocked[#blocked + 1] = "SetAttribute" end
        self.attrs[k] = v
    end
    function r:ClearAllPoints() if combat and self.watchCombat then blocked[#blocked + 1] = "ClearAllPoints" end end
    function r:SetPoint(...) if combat and self.watchCombat then blocked[#blocked + 1] = "SetPoint" end self.point = { ... } end
    function r:SetHeight(h) if combat and self.watchCombat then blocked[#blocked + 1] = "SetHeight" end self.height = h end
    function r:SetWidth(w) self.width = w end
    function r:SetVertexColor(red, g, b) self.vertex = { red, g, b } end
    function r:IsMouseOver() return false end
    function r:GetLeft() return 100 end
    function r:GetTop() return 500 end
    function r:GetEffectiveScale() return 1 end
    function r:CreateFontString() return newRegion("font") end
    function r:CreateTexture() return newRegion("texture") end
    return setmetatable(r, { __index = function(_, k)
        if k == "quest" or k == "section" or k == "objectiveIndex" or k == "offer" or k == "link" or k == "watchCombat"
            or k == "isTitle" or k == "questID" then return nil end
        return function() end
    end })
end
local tipLines = {}
CreateFrame = function(kind, name, parent, template)
    local f = newRegion(kind, template)
    if kind == "GameTooltip" then
        -- The addon's own tooltip: capture what it writes.
        function f:AddLine(t) tipLines[#tipLines + 1] = t end
        function f:SetText(t) tipLines = { t } end
    end
    -- Only the panel and the secure buttons are locked in combat; plain rows aren't protected.
    f.watchCombat = template == "SecureActionButtonTemplate" or name == "QuestTrackerPanel"
    frames[#frames + 1] = f
    if name then _G[name] = f end
    return f
end
UIParent = newRegion("Frame")
GameTooltip = newRegion("Frame")
ObjectiveTrackerFrame = newRegion("Frame")
issecretvalue = function() return false end
InCombatLockdown = function() return combat end
geterrorhandler = function() return function(e) handled[#handled + 1] = tostring(e) end end
C_Timer = { NewTicker = function(_, fn) tick = fn end }
local serverTime, now = 100000, 1000
GetServerTime = function() return serverTime end
GetTime = function() return now end
UnitLevel = function() return 10 end
UnitXPMax = function() return 1000 end
UnitClass = function() return "Hunter", "HUNTER", 3 end
UnitRace = function() return "Night Elf", "NightElf", 4 end
local zone = "Teldrassil"
GetRealZoneText = function() return zone end
C_Texture = { GetAtlasInfo = function(name) if name == "bags-greenarrow" then return { width = 16 } end end }

local minimapBottom = 620
MinimapCluster = newRegion("Frame")
function MinimapCluster:GetBottom() return minimapBottom end
function MinimapCluster:GetRight() return 1900 end

local log, data = {}, {}
local function header(title) log[#log + 1] = { isHeader = true, title = title } end
local function quest(id, title, level, o)
    o = o or {}
    log[#log + 1] = { questID = id, title = title, level = level, difficultyLevel = level, suggestedGroup = o.group or 0, questLogIndex = #log + 1 }
    data[id] = o
end
local function indexOf(id) for i, e in ipairs(log) do if e.questID == id then return i end end end
C_QuestLog = {
    GetNumQuestLogEntries = function() return #log, 23 end,
    GetMaxNumQuestsCanAccept = function() return 25 end,
    GetInfo = function(i) return log[i] end,
    IsComplete = function(id) return data[id].ready end,
    ReadyForTurnIn = function() return false end,
    IsQuestTrivial = function() return false end,
    GetQuestObjectives = function(id) return data[id].objectives or {} end,
    IsOnMap = function(id) return data[id].onMap or false, false end,
    GetDistanceSqToQuest = function(id) local d = data[id].distance; if d then return d * d, true end end,
    GetLogIndexForQuestID = function(id) return indexOf(id) end,
    GetTimeAllowed = function(id) local t = data[id].timer; if t then return t[1], t[2] end end,
}
local focus = 0
C_SuperTrack = { GetSuperTrackedQuestID = function() return focus end, SetSuperTrackedQuestID = function(id) focus = id end }
GetQuestLogRewardXP = function(id) return data[id].xp or 0 end
GetQuestLogSpecialItemInfo = function(i)
    local e = log[i]
    local o = e and data[e.questID]
    if o and o.item then return "|Hitem:" .. o.item .. ":|h[Rod]|h", 123, 1, false end
end
local cooldowns, inRange = {}, 1
GetQuestLogSpecialItemCooldown = function() return 950, 120, 1 end
CooldownFrame_Set = function(frame, start, duration, enable) cooldowns[#cooldowns + 1] = { frame = frame, start = start, duration = duration } end
IsQuestLogSpecialItemInRange = function() return inRange end
ItemAdvisor_IsUpgrade = function() return true, "Better" end
GetNumQuestLogChoices = function(id) return id == 1 and 1 or 0 end
GetNumQuestLogRewards = function() return 0 end
GetQuestLogChoiceInfo = function() return "n", 1, 1, 1, true, 55 end
C_Item = { GetItemInfo = function(id) return "n", "LINK" .. id end, RequestLoadItemDataByID = function() end }

local function obj(text, have, need) return { text = text, numFulfilled = have, numRequired = need, finished = have >= need } end
header("Teldrassil")
quest(1, "The Woodland Protector With A Long Name", 3, { onMap = true, distance = 40, xp = 450, group = 3, item = 88, objectives = { obj("Grells: 1/8", 1, 8) } })
quest(2, "Escort Run", 5, { onMap = true, distance = 90, xp = 300, timer = { 300, 60 }, objectives = { obj("Escort: 0/1", 0, 1) } })
header("Night Elf")
quest(3, "Tree Spirit", 4, { onMap = true, xp = 100, objectives = { obj("Seed: 0/1", 0, 1) } })
header("Hunter")
quest(4, "Taming the Beast", 10, { onMap = false, xp = 200, objectives = { obj("Tame: 0/1", 0, 1) } })

-- A stale NEW stamp from a quest dropped while the addon was off, and a fresh one.
QuestTrackerDB = { accepted = { [999] = serverTime - 7200, [1] = serverTime - 60 } }

assert(loadfile(path))("QuestTracker", {})
local events = frames[1]
-- /reload in combat: nothing secure is placed until combat ends.
events.scripts.OnEvent(events, "PLAYER_LOGIN")
tick()
-- The brand-new panel has no secure children yet, so placing it is allowed; secure buttons must wait.
for _, f in ipairs(frames) do
    assert(f.template ~= "SecureActionButtonTemplate", "no secure button made in combat")
end
for _, b in ipairs(blocked) do
    assert(b ~= "SetAttribute", "no attributes set in combat")
end
blocked = {}
assert(#handled == 0, "login clean: " .. tostring(handled[1]))
assert(QuestTrackerDB.accepted[999] == nil and QuestTrackerDB.accepted[1], "old NEW stamps pruned, fresh kept")
combat = false
events.scripts.OnEvent(events, "PLAYER_REGEN_ENABLED")
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
    for _, r in ipairs(shownRows()) do t[#t + 1] = r.left.text .. " ~ " .. r.right.text end
    return table.concat(t, "\n")
end
local function find(text)
    for _, r in ipairs(shownRows()) do if r.left.text:find(text, 1, true) then return r end end
end
local function before(a, b)
    local s = texts()
    return s:find(a, 1, true) < s:find(b, 1, true)
end
assert(find("Woodland"), "laid out once combat ended: " .. texts())

-- Default spot: under the minimap, not over it.
local p = QuestTrackerPanel.point
assert(p[1] == "TOPRIGHT" and p[2] == UIParent and p[3] == "BOTTOMLEFT" and p[4] == 1896 and p[5] == 620 - 22,
    "under the minimap: " .. tostring(p[1]) .. " " .. tostring(p[4]) .. " " .. tostring(p[5]))
-- A minimap near the bottom of the screen falls back to the old corner spot.
minimapBottom = 100
events.scripts.OnEvent(events, "QUEST_LOG_UPDATE"); tick()
p = QuestTrackerPanel.point
assert(p[1] == "TOPRIGHT" and p[3] == "TOPRIGHT", "fallback when no room under the minimap")
minimapBottom = 620
events.scripts.OnEvent(events, "QUEST_LOG_UPDATE"); tick()

-- Title keeps the whole name; tags go right.
local woodland = find("Woodland")
assert(woodland.left.text:find("The Woodland Protector With A Long Name|r$"), "nothing after the name: " .. woodland.left.text)
assert(woodland.right.text:find("|A:bags-greenarrow", 1, true), "upgrade arrow: " .. woodland.right.text)
assert(woodland.right.text:find("G3", 1, true) and woodland.right.text:find("NEW", 1, true), "group and new on the right")
assert(woodland.right.text:find("450 xp", 1, true), "xp still there")
woodland.scripts.OnEnter(woodland)
local tip = table.concat(tipLines, "\n")
assert(tip:find("Suggested group: 3", 1, true) and tip:find("Upgrade: LINK55", 1, true), "tooltip spells tags out")

-- Zone header shows what the zone is worth.
assert(find("Teldrassil").right.text:find("850 xp", 1, true), "zone xp: " .. find("Teldrassil").right.text)

-- Class and race quests.
assert(not texts():find("- Night Elf", 1, true) and not texts():find("+ Night Elf", 1, true), "no race-only section: " .. texts())
assert(before("Teldrassil (3)", "Tree Spirit"), "race quest on this map joins the zone: " .. texts())
assert(texts():find("Hunter quests (1)", 1, true), "class quest elsewhere gets a clear label: " .. texts())

-- Timer counts down every second, in combat too.
local escort = find("Escort Run")
assert(escort.right.text:find("4:00", 1, true), "timer: " .. escort.right.text)
combat = true
blocked = {}
now = now + 30
tick()
assert(escort.right.text:find("3:30", 1, true), "counts down in combat: " .. escort.right.text)
escort.scripts.OnEnter(escort)
assert(table.concat(tipLines, "\n"):find("Time left: 3:30", 1, true), "tooltip time left")

-- Item cooldown and range, in combat.
local item
for _, f in ipairs(frames) do if f.template == "SecureActionButtonTemplate" then item = f end end
assert(item and item.attrs.item == "item:88", "item button")
assert(#cooldowns > 0 and cooldowns[#cooldowns].frame == item.cooldown and cooldowns[#cooldowns].duration == 120, "cooldown swirl")
inRange = 0
tick()
assert(item.icon.vertex and item.icon.vertex[2] < 0.5, "red when out of range")
inRange = 1
tick()
assert(item.icon.vertex[2] == 1, "normal in range")

-- Clicking a quest in combat moves the focus marker without moving anything.
woodland.scripts.OnClick(woodland, "LeftButton")
assert(focus == 1, "focus set")
tick()
assert(woodland.left.text:find("> ", 1, true), "marker drawn in combat")
assert(woodland.glow.shown, "focused row lit")
assert(#blocked == 0, "nothing locked touched in combat: " .. table.concat(blocked, ","))
combat = false
events.scripts.OnEvent(events, "PLAYER_REGEN_ENABLED"); tick()

-- A saved spot is left alone.
QuestTrackerDB.position = { 300, 700 }
QuestTrackerPanel.point = { "TOPLEFT", UIParent, "BOTTOMLEFT", 300, 700 }
events.scripts.OnEvent(events, "QUEST_LOG_UPDATE"); tick()
assert(QuestTrackerPanel.point[1] == "TOPLEFT" and QuestTrackerPanel.point[4] == 300, "saved position kept")

-- Secret values everywhere stay quiet.
issecretvalue = function() return true end
events.scripts.OnEvent(events, "QUEST_LOG_UPDATE"); tick()
for _ = 1, 4 do tick() end
assert(#handled == 0, "clean: " .. tostring(handled[1]))

-- Taint audit (2026-11-09): Blizzard's tracker is only made clear with SetAlpha, and a secret alpha
-- (which can't be compared) is skipped instead of erroring every second, in or out of combat.
-- In the game a secret number still has type "number"; this stand-in is one too.
local SECRET_ALPHA = 0.37
local trackerAlpha, alphaWrites = 1, 0
ObjectiveTrackerFrame.GetAlpha = function() return trackerAlpha end
ObjectiveTrackerFrame.SetAlpha = function(_, a) alphaWrites = alphaWrites + 1; trackerAlpha = a end
issecretvalue = function(v) return v == SECRET_ALPHA end
combat = true
tick()
assert(trackerAlpha == 0 and alphaWrites == 1, "tracker made clear")
trackerAlpha = SECRET_ALPHA
tick(); tick()
assert(alphaWrites == 1, "secret alpha left alone")
combat = false
tick()
assert(#handled == 0 and #blocked == 0, "secret alpha clean: " .. tostring(handled[1]))
print("ALL TESTS PASSED")
