-- Round 6 #19: Tooltips adds "New in Forever" to quest tooltips (TooltipDataProcessor, Enum.TooltipDataType.Quest)
-- for quest IDs 10000 and up, and "(new in Forever)" after such quests on the quest-giver lines of creature
-- tooltips. The "forever" line can be switched off on the Tooltips page; the hub's Off switch silences it.
-- Harness after test_cr6c_tooltips_secretcast.lua.
-- Run from the tests folder:  node run.js "<repo root>" test_r6_quests_tooltips.lua
local realPrint = print
local frames, failures = {}, {}
local function check(cond, why) if not cond then failures[#failures + 1] = why end end
local secret = {}
issecretvalue = function(v) return secret[v] == true end
local pageLines = {}
ForeverHub_Receive = function(_, t) pageLines[#pageLines + 1] = t end
local off = false
ForeverHub_IsOff = function(name) return name == "Tooltips" and off end
print = function() failures[#failures + 1] = "print called" end
hooksecurefunc = function() failures[#failures + 1] = "hooksecurefunc called" end
CreateFrame = function()
    local f = { registered = {} }
    f.RegisterEvent = function(self, e) self.registered[e] = true end
    f.RegisterUnitEvent = function(self, e, u) self.registered[e] = u end
    f.SetScript = function(self, _, fn) self.fn = fn end
    frames[#frames + 1] = f
    return f
end
SlashCmdList = {}
local mouseName = "Marshal Dughan"
UnitName = function(u) if u == "player" then return "Juan" end return mouseName end
GetRealmName = function() return "R" end
UnitLevel = function() return 11 end
IsInInstance = function() return false, "none" end
GetTime = function() return 100 end
local callbacks = {}
Enum = { TooltipDataType = { Item = 0, Unit = 2, Quest = 23 }, TooltipDataLineType = { SellPrice = 11 } }
TooltipDataProcessor = { AddTooltipPostCall = function(kind, fn) callbacks[kind] = fn end }
local tip = { lines = {} }
GameTooltip = tip
ItemRefTooltip = { lines = {} }
function tip:AddLine(t) self.lines[#self.lines + 1] = t end
function tip:AddDoubleLine(l, r) self.lines[#self.lines + 1] = l .. " = " .. r end
function tip:GetName() return "GameTooltip" end
function tip:NumLines() return #self.lines end
function tip:GetUnit() return mouseName, "mouseover" end
local guid = "Creature-0-5000-0-111-240-00000001"
UnitGUID = function() return guid end
C_QuestLog = {
    GetNumQuestLogEntries = function() return 0 end,
    GetInfo = function() return nil end,
    IsQuestFlaggedCompleted = function() return false end,
}
-- LevelGuide's routes and IDs: Marshal Dughan starts a Classic quest and a Forever one.
LevelGuideQuestIDs = { ids = { ["Wolves Across the Border"] = { 33 }, ["Follow That Kobold!"] = { 91758 } }, renamed = {} }
LevelGuideRoutes = { chains = { NightElf = { { zone = "Elwynn Forest", steps = {
    { t = "accept", q = "Wolves Across the Border", npc = "Marshal Dughan" },
    { t = "accept", q = "Follow That Kobold!", npc = "Marshal Dughan" },
} } } } }

assert(loadfile(ADDON_PATH .. "/Tooltips/Tooltips.lua"))("Tooltips", {})
local ev = frames[#frames]
ev.fn(ev, "PLAYER_LOGIN")
check(type(callbacks[23]) == "function", "quest tooltip post-call registered")
check(type(callbacks[0]) == "function" and type(callbacks[2]) == "function", "item and unit post-calls still registered")

local function show() return table.concat(tip.lines, "\n") end
local function quest(id, tooltip)
    tooltip = tooltip or tip
    tooltip.lines = {}
    local ok, err = pcall(callbacks[23], tooltip, { id = id })
    check(ok, tostring(err))
    return table.concat(tooltip.lines, "\n")
end
local function unit()
    tip.lines = {}
    local ok, err = pcall(callbacks[2], tip, { guid = guid })
    check(ok, tostring(err))
    return show()
end

-- 1. Quest tooltips.
check(quest(91758):find("New in Forever", 1, true), "Forever quest tooltip tagged")
check(not quest(33):find("New in Forever", 1, true), "Classic quest tooltip not tagged")
check(quest(91758, { lines = {}, AddLine = tip.AddLine }) == "", "only the game's own shown tooltips get lines")
local SECRET_ID = setmetatable({}, {})
secret[SECRET_ID] = true
check(quest(SECRET_ID) == "", "a secret quest ID adds nothing")

-- 2. Quest-giver lines on the creature tooltip.
local s = unit()
check(s:find("Starts: Follow That Kobold! |cffc58cff(new in Forever)|r", 1, true), "giver line tagged:\n" .. s)
check(s:find("Starts: Wolves Across the Border", 1, true) and not s:find("Border |cffc58cff", 1, true), "Classic giver line not tagged:\n" .. s)

-- 3. Switched off on the Tooltips page: no tag anywhere; the giver lines stay.
SlashCmdList.TOOLTIPS("off forever")
check(TooltipsDB.forever == false, "saved as one boolean")
check(not quest(91758):find("New in Forever", 1, true), "off: quest tooltip clean")
s = unit()
check(s:find("Starts: Follow That Kobold!", 1, true) and not s:find("new in Forever", 1, true), "off: giver line untagged:\n" .. s)
SlashCmdList.TOOLTIPS("on forever")
pageLines = {}
SlashCmdList.TOOLTIPS("")
check(table.concat(pageLines, "\n"):find("New in Forever", 1, true), "the page lists the line")

-- 4. Hub Off switch: nothing at all.
off = true
check(quest(91758) == "", "hub Off: no quest line")
check(unit() == "", "hub Off: no unit lines")
off = false

for e in pairs(ev.registered) do check(not e:find("^COMBAT_LOG"), "no combat log event") end
if #failures > 0 then error(table.concat(failures, "\n")) end
realPrint("test_r6_quests_tooltips: ok")
