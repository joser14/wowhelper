-- Round 5 #5, QuestMobs side: "Your drops: N% (k/n)" next to the classic drop chance on enemy tooltips and in
-- the list, from Tooltips_YourDrops (Tooltips counts corpses you loot); a mob the classic table doesn't know gets
-- your own rate as its chance; nothing until Tooltips says there are enough corpses; nothing without Tooltips.
-- Harness copied from test_r4a_questmobs_drops.lua.
local realPrint = print
local out, frames, violations = {}, {}, {}
local function violate(what) violations[#violations + 1] = what end
ForeverHub_Receive = function(_, t) out[#out + 1] = t end
issecretvalue = function() return false end
print = function() violate("print") end
hooksecurefunc = function() violate("hooksecurefunc") end

local function Obj(kind, parent)
    local o = { kind = kind, parent = parent, shown = true, points = {}, scripts = {}, registered = {} }
    function o:SetPoint(p, rel, rp, x, y) self.points[#self.points + 1] = { p, rel, rp, x, y } end
    function o:ClearAllPoints() self.points = {} end
    function o:Show() self.shown = true end
    function o:Hide() self.shown = false end
    function o:SetText(t) self.text = t end
    function o:SetScript(n, fn) self.scripts[n] = fn end
    function o:RegisterEvent(e) self.registered[e] = true end
    function o:CreateTexture() return Obj("Texture", self) end
    function o:CreateFontString() return Obj("FontString", self) end
    return setmetatable(o, { __index = function() return function() end end })
end
CreateFrame = function(kind, _, parent) local f = Obj(kind, parent); frames[#frames + 1] = f; return f end
UIParent = Obj("UIParent")
SlashCmdList = {}
Enum = { TooltipDataLineType = { QuestObjective = 8, QuestTitle = 17, QuestPlayer = 18 }, TooltipDataType = { Item = 0, Unit = 2 } }
local tooltipCalls = {}
TooltipDataProcessor = { AddTooltipPostCall = function(kind, fn) tooltipCalls[kind] = fn end }
local clock = 1000
GetTime = function() return clock end
IsInInstance = function() return false, "none" end

local units = {}
UnitExists = function(u) return units[u] ~= nil end
UnitGUID = function(u) return units[u] and units[u].guid end
UnitName = function(u) if u == "player" then return "Josefina" end return units[u] and units[u].name end
UnitCanAttack = function(_, u) return units[u] and units[u].hostile or false end
UnitIsPlayer = function() return false end
local nameplates = {}
C_NamePlate = { GetNamePlateForUnit = function(u) if units[u] then nameplates[u] = nameplates[u] or Obj("NamePlate"); return nameplates[u] end end }
C_TooltipInfo = { GetUnit = function(u) return units[u] and { type = 2, lines = units[u].lines } end }
C_Item = { GetItemNameByID = function() return nil end }

local log
C_QuestLog = {
    GetNumQuestLogEntries = function() return #log end,
    GetInfo = function(i) return log[i] end,
    IsComplete = function() return false end,
    GetQuestObjectives = function(id) for _, q in ipairs(log) do if q.questID == id then return q.objectives end end return {} end,
}
local function setLog(have)
    log = {
        { title = "Riverpaw Gnoll Bounty", questID = 11, objectives = {
            { text = "Painted Gnoll Armband: " .. have .. "/8", type = "item", finished = have >= 8, numFulfilled = have, numRequired = 8 } } },
        { title = "Kobold Camp Cleanup", questID = 7, objectives = {
            { text = "Kobold Vermin slain: 3/8", type = "monster", finished = false, numFulfilled = 3, numRequired = 8 } } },
    }
end
setLog(2)
local function gnollLines(have)
    return { { type = 2, leftText = "Riverpaw Runt" }, { type = 17, leftText = "Riverpaw Gnoll Bounty" },
        { type = 8, leftText = " - Painted Gnoll Armband: " .. have .. "/8", completed = have >= 8 } }
end

assert(loadfile(ADDON_PATH .. "/QuestMobs/Drops.lua"))("QuestMobs", {})
assert(type(QuestMobsDrops) == "table" and QuestMobsDrops.npc[97] and QuestMobsDrops.names[782] == "Painted Gnoll Armband", "generated data has the Riverpaw Runt row")
assert(loadfile(ADDON_PATH .. "/QuestMobs/QuestMobs.lua"))("QuestMobs", {})
local ev
for _, f in ipairs(frames) do if f.scripts.OnEvent then ev = f end end
local function fire(e, ...) ev.scripts.OnEvent(ev, e, ...) end
local function tick() clock = clock + 2.5; ev.scripts.OnUpdate(ev, 2.5) end
fire("PLAYER_LOGIN")
fire("PLAYER_ENTERING_WORLD")
tick()


assert(type(tooltipCalls[2]) == "function", "a unit tooltip post-call is registered")
local lines = {}
local tip = { AddLine = function(_, t) lines[#lines + 1] = t end, AddDoubleLine = function(_, l, r) lines[#lines + 1] = l .. " " .. r end }
GameTooltip = tip
local function hover(guid) lines = {}; tooltipCalls[2](tip, { guid = guid, type = 2 }); return table.concat(lines, "\n") end
local runt = "Creature-0-5000-0-111-97-0000ABCD"
local newMob = "Creature-0-5000-0-111-250123-0000ABCD"
C_Item = { GetItemNameByID = function(id) if id == 782 then return "Painted Gnoll Armband" end end }

-- 1. Without Tooltips: the classic line only.
local text = hover(runt)
assert(text:find("Painted Gnoll Armband 40%", 1, true) and not text:find("Your drops", 1, true), "no Tooltips: " .. text)
assert(hover(newMob) == "", "no Tooltips: nothing for a new mob")

-- 2. Tooltips with too few corpses: still nothing of yours.
local own = {}   -- npc -> { n, items }
Tooltips_YourDrops = function(npc, item)
    local c = own[npc]
    if not c then return nil end
    if item == nil then local copy = {} for k, v in pairs(c.items) do copy[k] = v end return copy, c.n, c.n >= 10 end
    return c.items[item] or 0, c.n, c.n >= 10
end
own[97] = { n = 9, items = { [782] = 3 } }
text = hover(runt)
assert(not text:find("Your drops", 1, true), "9 corpses: not shown: " .. text)

-- 3. Enough corpses: your rate beside the classic chance.
own[97] = { n = 20, items = { [782] = 7 } }
text = hover(runt)
assert(text:find("Painted Gnoll Armband 40%  (~15 kills for 6 more)  Your drops: 35% (7/20)", 1, true), "both rates: " .. text)

-- 4. A mob new in Forever: your own rate is the chance, kills left from it.
own[250123] = { n = 10, items = { [782] = 5, [999] = 2 } }
text = hover(newMob)
assert(text:find("Painted Gnoll Armband Your drops: 50% (5/10)  (~12 kills for 6 more)", 1, true), "own rate for a new mob: " .. text)
assert(not text:find("999", 1, true), "an item no quest needs isn't listed: " .. text)

-- 5. The list/page row says so too.
units.nameplate1 = { name = "Riverpaw Runt", hostile = true, guid = runt, lines = gnollLines(2) }
fire("NAME_PLATE_UNIT_ADDED", "nameplate1")
tick()
out = {}
SlashCmdList.QUESTMOBS("")
local page = table.concat(out, "\n")
assert(page:find("2/8 40% (you 35%), ~15 kills", 1, true), "page row with your rate:\n" .. page)

-- 6. A broken Tooltips answer adds nothing and breaks nothing.
Tooltips_YourDrops = function() error("broken") end
text = hover(runt)
assert(text:find("Painted Gnoll Armband 40%", 1, true) and not text:find("Your drops", 1, true), "broken read: " .. text)
Tooltips_YourDrops = function() return "junk", "x", true end
assert(hover(newMob) == "", "junk read: nothing")

-- 7. Hub Off: no lines.
ForeverHub_IsOff = function(name) return name == "QuestMobs" end
ForeverHubOnSwitch.QuestMobs()
assert(hover(runt) == "", "hub Off: nothing")

assert(#violations == 0, "violations: " .. table.concat(violations, ", "))
realPrint("test_r5f_questmobs: ok")