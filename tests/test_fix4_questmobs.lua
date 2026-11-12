-- Perf audit 9 (QuestMobs): while a nameplate's answer is pending (the quest log changed but its tooltip was
-- read under 2 s ago), the per-frame tick no longer re-runs the unit checks for that plate every frame; it waits
-- until the read may be repeated. A new plate, a renamed unit or an instance change aren't held back.
-- Mocks copied from test_questmobs.lua.
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
fire("PLAYER_LOGIN")
fire("PLAYER_ENTERING_WORLD")
tick()
plate("nameplate1", { name = "Kobold Vermin", hostile = true, lines = koboldLines(3) })
tick()
check(markerFor("nameplate1") and markerFor("nameplate1").text.text == "3/8", "marker 3/8")
-- The log changes 1.1 s after the read: the plate's answer is pending until the read is 2 s old.
setLog(4, false)
units.nameplate1.lines = koboldLines(4)
fire("QUEST_LOG_UPDATE")
tick(1.1)
local checks = 0
local realCanAttack = UnitCanAttack
rawset(_G, "UnitCanAttack", function(...) checks = checks + 1; return realCanAttack(...) end)
for _ = 1, 30 do tick() end
check(checks == 0, "no unit checks every frame while the answer is pending: " .. checks)
tick(0.4)
check(readsBy.nameplate1 == 2, "read again once 2 s passed, reads=" .. tostring(readsBy.nameplate1))
check(markerFor("nameplate1") and markerFor("nameplate1").text.text == "4/8", "progress updated")
-- A new mob on the same token isn't held back by the old wait.
setLog(5, false)
units.nameplate1.lines = koboldLines(5)
fire("QUEST_LOG_UPDATE")
tick(1.1)
unplate("nameplate1")
plate("nameplate1", { name = "Kobold Vermin", hostile = true, lines = koboldLines(5) })
tick()
check(markerFor("nameplate1") and markerFor("nameplate1").text.text == "5/8", "new plate read at once")
-- Entering an instance while pending hides markers at once.
units.nameplate1.lines = koboldLines(6)
setLog(6, false)
fire("QUEST_LOG_UPDATE")
tick(1.1)
instance = true
fire("PLAYER_ENTERING_WORLD")
tick()
check(markerFor("nameplate1") == nil, "no marker in an instance")
check(#violations == 0, "violations: " .. table.concat(violations, ", "))
if #failures > 0 then
    error("test_fix4_questmobs FAILED:\n- " .. table.concat(failures, "\n- "), 0)
end
realPrint("ALL TESTS PASSED")
