-- QuestMobs smoke test: a quest marker with progress appears next to hostile nameplates whose tooltip
-- lists an unfinished objective of a quest in your log; finished objectives, friendly units, other
-- players' progress, instances and secret values show nothing; tooltip reads are throttled (2 s per
-- unit, 3 per frame); removing a nameplate releases its marker; on/off, size and list window work; a
-- refused anchor falls back to the list window. Fails if any nameplate or Blizzard frame is touched,
-- any targeting/marking API or hook is called, anything is printed to chat, or a stray global is written.
-- Run from the harness folder:  node run.js "<workspace root>" test_questmobs.lua
local base = ADDON_PATH
local realPrint = print
local out, frames, failures, violations = {}, {}, {}, {}
local SECRET = {}
local function violate(what) violations[#violations + 1] = what end

ForeverHub_Receive = function(_, t) out[#out + 1] = t end
issecretvalue = function(v) return v == SECRET end
issecrettable = function(v) return v == SECRET end

-- Our own frames: a permissive mock that records points, shown state and text.
local function Obj(kind, parent)
    local o = { kind = kind, parent = parent, shown = true, points = {}, scripts = {}, registered = {} }
    function o:SetPoint(p, rel, rp, x, y)
        if type(rel) == "table" and rawget(rel, "restricted") then error("anchor family restricted") end
        self.points[#self.points + 1] = { p, rel, rp, x, y }
    end
    function o:ClearAllPoints() self.points = {} end
    function o:SetAllPoints(rel) self.points = { { "ALL", rel } } end
    function o:Show() self.shown = true end
    function o:Hide() self.shown = false end
    function o:IsShown() return self.shown end
    function o:SetSize(w, h) self.w, self.h = w, h end
    function o:SetHeight(h) self.h = h end
    function o:SetText(t) self.text = t end
    function o:SetScript(n, fn) self.scripts[n] = fn end
    function o:RegisterEvent(e) self.registered[e] = true end
    function o:CreateTexture() return Obj("Texture", self) end
    function o:CreateFontString() return Obj("FontString", self) end
    function o:GetPoint(i) local p = self.points[i or 1]; if p then return p[1], p[2], p[3], p[4], p[5] end end
    return setmetatable(o, { __index = function() return function() end end })
end
-- Blizzard frames: calling ANY method on them is a violation.
local function Trap(name)
    return setmetatable({ trapName = name }, { __index = function(_, k)
        return function() violate(name .. ":" .. tostring(k)) end
    end })
end

CreateFrame = function(kind, _, parent)
    local f = Obj(kind, parent)
    frames[#frames + 1] = f
    return f
end
UIParent = Trap("UIParent")
WorldFrame = Trap("WorldFrame")
SlashCmdList = {}
DEFAULT_CHAT_FRAME = Trap("DEFAULT_CHAT_FRAME")
print = function() violate("print") end
for _, name in ipairs({ "TargetUnit", "SetRaidTarget", "SetRaidTargetIcon", "InteractUnit", "AttackTarget", "StartAttack",
    "FocusUnit", "AssistUnit", "ClearTarget", "TargetNearestEnemy", "TargetLastTarget", "CastSpellByName", "hooksecurefunc" }) do
    _G[name] = function() violate(name) end
end
Enum = { TooltipDataLineType = { QuestObjective = 8, QuestTitle = 17, QuestPlayer = 18, UnitName = 2 } }

local clock = 1000
GetTime = function() return clock end
local instance = false
IsInInstance = function() return instance, instance and "party" or "none" end

-- Units: token -> { guid, name, hostile, player, lines }
local units = {}
UnitExists = function(u) return units[u] ~= nil end
UnitGUID = function(u) return units[u] and units[u].guid end
UnitName = function(u) if u == "player" then return "Josefina" end return units[u] and units[u].name end
UnitCanAttack = function(_, u) return units[u] and units[u].hostile or false end
UnitIsPlayer = function(u) return units[u] and units[u].player or false end

local nameplates = {}
local restrictedPlates = false
C_NamePlate = { GetNamePlateForUnit = function(u)
    if not units[u] then return nil end
    if not nameplates[u] then
        nameplates[u] = Trap("NamePlate:" .. u)
    end
    if restrictedPlates then rawset(nameplates[u], "restricted", true) end
    return nameplates[u]
end }

local reads, readsBy = 0, {}
C_TooltipInfo = { GetUnit = function(u)
    reads = reads + 1
    readsBy[u] = (readsBy[u] or 0) + 1
    local unit = units[u]
    if not unit then return nil end
    if unit.lines == SECRET then return SECRET end
    return { type = 2, lines = unit.lines }
end }

-- Quest log
local log = {}
C_QuestLog = {
    GetNumQuestLogEntries = function() return #log end,
    GetInfo = function(i) return log[i] end,
    IsComplete = function(id) for _, q in ipairs(log) do if q.questID == id then return q.complete or false end end return false end,
    GetQuestObjectives = function(id) for _, q in ipairs(log) do if q.questID == id then return q.objectives end end return {} end,
}
local function setLog(koboldHave, koboldFinished)
    log = {
        { title = "Elwynn Forest", isHeader = true },
        { title = "Kobold Camp Cleanup", questID = 7, objectives = {
            { text = "Kobold Vermin slain: " .. koboldHave .. "/8", finished = koboldFinished, numFulfilled = koboldHave, numRequired = 8 } } },
        { title = "Wolves Across the Border", questID = 33, objectives = {
            { text = "Tough Wolf Meat: 2/8", finished = false, numFulfilled = 2, numRequired = 8 } } },
        { title = "A Bundle of Trouble", questID = 5545, objectives = {
            { text = "Bundle of Wood: 1/1", finished = false, numFulfilled = 1, numRequired = 1 } } },
    }
end
setLog(3, false)

local function koboldLines(have)
    return {
        { type = 2, leftText = "Kobold Vermin" },
        { type = 0, leftText = "Level 2" },
        { type = 17, leftText = "Kobold Camp Cleanup" },
        { type = 8, leftText = " - Kobold Vermin slain: " .. have .. "/8", completed = have >= 8 },
    }
end

-- Stray globals: only ours may be created.
-- ForeverHubOnSwitch: the hub's shared table, where QuestMobs registers for the Manage page's Off/On switch.
local allowedGlobals = { QuestMobsDB = true, QuestMobs_IsQuestMob = true, SLASH_QUESTMOBS1 = true, ForeverHubOnSwitch = true }
setmetatable(_G, { __newindex = function(t, k, v)
    if not allowedGlobals[k] then violate("global " .. tostring(k)) end
    rawset(t, k, v)
end })

local n = #frames
assert(loadfile(base .. "/QuestMobs/QuestMobs.lua"))("QuestMobs", {})
local ev = frames[n + 1]
local function fire(e, ...) ev.scripts.OnEvent(ev, e, ...) end
local function tick(dt) clock = clock + (dt or 0.02); ev.scripts.OnUpdate(ev, dt or 0.02) end
local function has(text) for _, t in ipairs(out) do if t:find(text, 1, true) then return true end end return false end
local function dump() return "\n  output was:\n  " .. table.concat(out, "\n  ") end
local function check(cond, why) if not cond then failures[#failures + 1] = why .. dump() end end
local function need(text, why) check(has(text), why .. ": wanted '" .. text .. "'") end
local function page(arg)
    out = {}
    local ok, err = pcall(SlashCmdList.QUESTMOBS, arg)
    if not ok then out[#out + 1] = "<<ERROR: " .. tostring(err) .. ">>" end
end
local guidN = 0
local function plate(token, u)
    guidN = guidN + 1
    u.guid = u.guid or string.format("Creature-0-5000-0-111-%d-%08X", u.npc or 475, guidN)
    units[token] = u
    fire("NAME_PLATE_UNIT_ADDED", token)
end
local function unplate(token) fire("NAME_PLATE_UNIT_REMOVED", token); units[token] = nil end
-- The marker anchored to a given nameplate, if one is shown.
local function markerFor(token)
    local np = nameplates[token]
    if not np then return nil end
    for _, f in ipairs(frames) do
        if f.kind == "Frame" and f.shown and f.points[1] and f.points[1][2] == np then return f end
    end
end
local function shownMarkers()
    local c = 0
    for _, f in ipairs(frames) do
        if f.kind == "Frame" and f.shown and f.points[1] and type(f.points[1][2]) == "table" and rawget(f.points[1][2], "trapName")
            and tostring(rawget(f.points[1][2], "trapName")):find("NamePlate", 1, true) then c = c + 1 end
    end
    return c
end

for _, e in ipairs({ "PLAYER_LOGIN", "NAME_PLATE_UNIT_ADDED", "NAME_PLATE_UNIT_REMOVED", "UNIT_NAME_UPDATE", "QUEST_LOG_UPDATE", "PLAYER_ENTERING_WORLD" }) do
    check(ev.registered[e], "registers " .. e)
end
check(SLASH_QUESTMOBS1 == "/questmobs" and SlashCmdList.QUESTMOBS, "slash command")
check(type(QuestMobs_IsQuestMob) == "function", "global QuestMobs_IsQuestMob")

-- Before login: quiet, no reads, no error.
page("")
check(#out == 0, "nothing before login")
plate("nameplate1", { name = "Kobold Vermin", hostile = true, lines = koboldLines(3) })
tick()
check(reads == 0, "no tooltip reads before login")
check(QuestMobs_IsQuestMob("nameplate1") == false, "IsQuestMob false before login")
unplate("nameplate1")

fire("PLAYER_LOGIN")
fire("PLAYER_ENTERING_WORLD")
check(QuestMobsDB.enabled == true and QuestMobsDB.size == "medium", "defaults saved")
tick()

-- 1. A hostile kobold you still need: marker with 3/8, our own frame, anchored next to its nameplate.
plate("nameplate1", { name = "Kobold Vermin", hostile = true, lines = koboldLines(3) })
tick()
local m1 = markerFor("nameplate1")
check(m1 ~= nil, "marker shown for a quest mob")
check(m1 and m1.text and m1.text.text == "3/8", "marker shows 3/8, got " .. tostring(m1 and m1.text and m1.text.text))
check(m1 and m1.parent ~= nameplates.nameplate1 and m1.parent and m1.parent.kind == "Frame", "marker parented to our own container")
check(m1 and m1.w == 20, "medium size is 20")
local ok, prog = QuestMobs_IsQuestMob("nameplate1")
check(ok == true and prog == "3/8", "IsQuestMob returns true, 3/8")
check(readsBy.nameplate1 == 1, "IsQuestMob within 2 s reuses the cached read")
page("")
need("Kobold Vermin  |cffffd1003/8|r", "page lists the mob with progress")
need("Kobold Camp Cleanup", "page names the quest")
need("Type: off   Or: on   Or: size large", "page hint")

-- 2. Non-hostile unit with the same lines: ignored, never read.
plate("nameplate2", { name = "Kobold Pet", hostile = false, lines = koboldLines(3) })
tick()
check(markerFor("nameplate2") == nil, "no marker for a friendly unit")
check(readsBy.nameplate2 == nil, "friendly unit's tooltip not read")
check(QuestMobs_IsQuestMob("nameplate2") == false, "IsQuestMob false for friendly")
unplate("nameplate2")

-- 3. Throttle: a quest log update 1.1 s later doesn't re-read; after 2 s it does.
units.nameplate1.lines = koboldLines(4)
setLog(4, false)
fire("QUEST_LOG_UPDATE")
tick(1.1)
tick()
check(readsBy.nameplate1 == 1, "no re-read within 2 s, reads=" .. tostring(readsBy.nameplate1))
tick(1.0)
check(readsBy.nameplate1 == 2, "re-read after 2 s, reads=" .. tostring(readsBy.nameplate1))
m1 = markerFor("nameplate1")
check(m1 and m1.text.text == "4/8", "progress updated to 4/8")
-- A burst of quest updates is read once (debounced) and still waits for the 2 s.
for _ = 1, 5 do fire("QUEST_LOG_UPDATE") end
tick(); tick()
check(readsBy.nameplate1 == 2, "burst doesn't re-read immediately")

-- 4. Finished objective hides the marker (your log's finished flag is the truth).
setLog(8, true)
units.nameplate1.lines = koboldLines(8)
fire("QUEST_LOG_UPDATE")
tick(1.1); tick(1.1)
check(markerFor("nameplate1") == nil, "finished objective hides the marker")
check(QuestMobs_IsQuestMob("nameplate1") == false, "IsQuestMob false once finished")
-- A row that reads 1/1 but your log says unfinished still counts (Forever type-14 rows).
plate("nameplate3", { name = "Bundle Thief", hostile = true, lines = {
    { type = 17, leftText = "A Bundle of Trouble" }, { type = 8, leftText = "Bundle of Wood: 1/1", completed = true } } })
tick()
check(markerFor("nameplate3") ~= nil and markerFor("nameplate3").text.text == "1/1", "1/1 but unfinished in the log still marked")
unplate("nameplate3")
-- Quest not in your log: nothing.
plate("nameplate4", { name = "Murloc", hostile = true, lines = {
    { type = 17, leftText = "The Fargodeep Mine" }, { type = 8, leftText = "Murloc slain: 0/10", completed = false } } })
tick()
check(markerFor("nameplate4") == nil, "quest not in log: no marker")
unplate("nameplate4")
-- Another player's progress (QuestPlayer line) doesn't count; yours does.
plate("nameplate5", { name = "Prowler", hostile = true, lines = {
    { type = 17, leftText = "Wolves Across the Border" },
    { type = 18, leftText = "Otherguy" }, { type = 8, leftText = "Tough Wolf Meat: 0/8", completed = false } } })
tick()
check(markerFor("nameplate5") == nil, "other player's objective ignored")
unplate("nameplate5")
plate("nameplate6", { name = "Prowler", hostile = true, lines = {
    { type = 17, leftText = "Wolves Across the Border" },
    { type = 18, leftText = "Otherguy" }, { type = 8, leftText = "Tough Wolf Meat: 0/8" },
    { type = 18, leftText = "Josefina" }, { type = 8, leftText = "Tough Wolf Meat: 2/8" } } })
tick()
check(markerFor("nameplate6") ~= nil and markerFor("nameplate6").text.text == "2/8", "your own block under QuestPlayer counts")

-- 5. Nameplate removed releases the marker (hidden, detached from the nameplate).
local m6 = markerFor("nameplate6")
unplate("nameplate6")
check(m6 and not m6.shown and #m6.points == 0, "removed nameplate: marker hidden and detached")
check(shownMarkers() == 0, "no markers left")

unplate("nameplate1")
-- 6. Per-frame cap: 8 new quest mobs at once -> at most 3 reads in one frame.
setLog(3, false)
fire("QUEST_LOG_UPDATE")
tick(2.5)
local before = reads
for i = 10, 17 do plate("nameplate" .. i, { name = "Kobold Vermin", hostile = true, lines = koboldLines(3) }) end
tick()
check(reads - before == 3, "3 reads per frame, got " .. (reads - before))
tick(); tick()
check(reads - before == 8, "all 8 read over 3 frames, got " .. (reads - before))
check(shownMarkers() == 8, "8 markers, got " .. shownMarkers())

-- 7. Toggles and size.
page("size large")
need("Marker size: large", "size notice")
check(markerFor("nameplate10").w == 28, "large size applied")
check(QuestMobsDB.size == "large", "size saved")
page("size huge")
need("Sizes: small, medium, large", "bad size explained")
page("off")
check(QuestMobsDB.enabled == false and shownMarkers() == 0, "off hides every marker")
need("Quest markers are off", "off notice")
page("on")
check(QuestMobsDB.enabled == true and shownMarkers() == 8, "on shows them again")
page("list on")
local win
for _, f in ipairs(frames) do if rawget(f, "rows") then win = f end end
check(win and win.shown, "list window shown")
check(win and win.rows[1].text:find("Kobold Vermin", 1, true), "list window lists the mob")
check(win and win.rows[9].text:find("and 0 more", 1, true) == nil, "no bogus overflow row")
page("list off")
check(win and not win.shown, "list window hidden")
page("dance")
need("Not sure what", "unknown command")
for i = 10, 17 do unplate("nameplate" .. i) end
tick(0.6)

-- 8. Secret values: secret tooltip data, a secret objective line, a secret GUID, a secret unit token.
tick(2.5)
plate("nameplate20", { name = "Hidden", hostile = true, lines = SECRET })
plate("nameplate21", { name = "Hidden2", hostile = true, lines = {
    { type = 17, leftText = "Kobold Camp Cleanup" }, { type = 8, leftText = SECRET } } })
plate("nameplate22", { name = "Hidden3", hostile = true, guid = SECRET, lines = koboldLines(3) })
fire("NAME_PLATE_UNIT_ADDED", SECRET)
tick(); tick()
check(shownMarkers() == 0, "secret values show nothing")
check(readsBy.nameplate22 == nil, "secret GUID: tooltip not read")
check(QuestMobs_IsQuestMob(SECRET) == false, "IsQuestMob(secret) false")
page("")
need("can't be read right now", "page mentions hidden enemies")
for i = 20, 22 do unplate("nameplate" .. i) end

-- 9. Instance: nothing read or shown, markers cleared on entry.
plate("nameplate30", { name = "Kobold Vermin", hostile = true, lines = koboldLines(3) })
tick(2.5)
check(markerFor("nameplate30") ~= nil, "marker before entering instance")
instance = true
fire("PLAYER_ENTERING_WORLD")
tick(2.5)
check(shownMarkers() == 0, "entering an instance clears markers")
local r = reads
plate("nameplate31", { name = "Defias", hostile = true, lines = koboldLines(3) })
tick(2.5); tick()
check(reads == r, "no tooltip reads inside an instance")
check(QuestMobs_IsQuestMob("nameplate31") == false, "IsQuestMob false in instance")
page("")
need("Inside dungeons", "page explains instance")
instance = false
fire("PLAYER_ENTERING_WORLD")
tick(2.5); tick()
check(markerFor("nameplate30") ~= nil, "marker back after leaving")
unplate("nameplate30"); unplate("nameplate31")

-- 10. UNIT_NAME_UPDATE re-reads (after the 2 s).
plate("nameplate40", { name = "Kobold Vermin", hostile = true, lines = { { type = 2, leftText = "Kobold Vermin" } } })
tick()
check(markerFor("nameplate40") == nil, "no quest lines yet")
units.nameplate40.lines = koboldLines(3)
fire("UNIT_NAME_UPDATE", "nameplate40")
tick()
check(markerFor("nameplate40") == nil, "name update within 2 s waits")
tick(2.1)
check(markerFor("nameplate40") ~= nil, "name update re-reads after 2 s")
unplate("nameplate40")

-- 11. Anchoring refused by the client: fall back to the list window.
restrictedPlates = true
plate("nameplate50", { name = "Kobold Tunneler", hostile = true, lines = koboldLines(3) })
tick(2.5); tick(0.6)
check(shownMarkers() == 0, "no marker when anchoring is refused")
check(win and win.shown and win.rows[1].text:find("Kobold Tunneler", 1, true), "fallback list window shows the mob")
page("")
need("won't let a marker sit next to a nameplate", "page explains the fallback")

-- No chat, no Blizzard frame calls, no targeting/marking, no hooks, no stray globals.
check(#violations == 0, "violations: " .. table.concat(violations, ", "))

if #failures > 0 then
    error("QuestMobs test FAILED:\n- " .. table.concat(failures, "\n- "), 0)
end
realPrint("QuestMobs test passed")
