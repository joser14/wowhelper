-- Round 4 R12, Tooltips side: the dungeon source line ranks boss drops over trash over quest rewards (own faction
-- first), prefers the dungeon whose level range holds your level, appends "(lvl a-b)" and says "several dungeons"
-- for loot shared between dungeons. Ranking idea from DungeonJournal (idea only); data is ours (DungeonsData).
-- Harness trimmed from test_tooltips.lua.
local frames, failures = {}, {}
issecretvalue = function() return false end
ForeverHub_Receive = function() end
CreateFrame = function()
    local f = { registered = {} }
    f.RegisterEvent = function(self, e) self.registered[e] = true end
    f.SetScript = function(self, _, fn) self.fn = fn end
    frames[#frames + 1] = f
    return f
end
SlashCmdList = {}
UnitName = function(u) if u == "player" then return "Juan" end end
GetRealmName = function() return "R" end
UnitFactionGroup = function() return "Alliance" end
time = function() return 1000000 end
local callbacks = {}
Enum = { TooltipDataType = { Item = 0, Unit = 2 }, TooltipDataLineType = { SellPrice = 11 } }
TooltipDataProcessor = { AddTooltipPostCall = function(kind, fn) callbacks[kind] = fn end }
TooltipUtil = { GetDisplayedItem = function() return nil end }
local tip = { lines = {} }
GameTooltip = tip
ItemRefTooltip = { lines = {} }
function tip:AddLine(t) self.lines[#self.lines + 1] = t end
function tip:AddDoubleLine(l, r) self.lines[#self.lines + 1] = l .. " = " .. r end
function tip:GetName() return "GameTooltip" end
function tip:NumLines() return #self.lines end
function tip:GetProcessingTooltipInfo() return nil end
C_Item = { GetItemInfo = function(id)
    if id == 2589 then return "Linen Cloth", "link", 1, 5, 1, "t", "s", 20, "", 1, 13, 7, 0, 0 end
    if id == 5396 then return "Key to Searing Gorge", "link", 1, 5, 1, "t", "s", 1, "", 1, 0, 13, 0, 1 end
end }
C_Container = { GetContainerItemInfo = function() end }

local level, faction = 20, "Alliance"
UnitLevel = function() return level end
UnitFactionGroup = function() return faction end
C_Item = { GetItemInfo = function(id)
    return "Item " .. id, "link", 2, 20, 1, "t", "s", 1, "INVTYPE_FINGER", 1, 100, 4, 0, 1
end }
DungeonsData = {
    { name = "Wailing Caverns", minLevel = 17, maxLevel = 24, loot = {
        { 1001, "Trash Ring", "Trash mobs", "Finger" },
        { 1001, "Trash Ring", "quest: Leaders of the Fang", "Finger" },
        { 1002, "Shared Ring", "Mutanus the Devourer", "Finger" },
    } },
    { name = "Blackfathom Deeps", minLevel = 22, maxLevel = 30, loot = {
        { 1001, "Trash Ring", "Aku'mai", "Finger" },
        { 1002, "Shared Ring", "Aku'mai", "Finger" },
    } },
    { name = "Ragefire Chasm", minLevel = 13, maxLevel = 18, horde = true, loot = {
        { 1003, "Horde Reward", "quest: Hidden Enemies", "Finger" },
    } },
    { name = "The Deadmines", minLevel = 17, maxLevel = 26, loot = {
        { 1003, "Horde Reward", "quest: The Defias Brotherhood", "Finger" },
    } },
}

local function has(text) for _, t in ipairs(tip.lines) do if tostring(t):find(text, 1, true) then return true end end return false end
local function need(text, why) if not has(text) then failures[#failures + 1] = why .. ": wanted '" .. text .. "' in\n  " .. table.concat(tip.lines, "\n  ") end end
local function lack(text, why) if has(text) then failures[#failures + 1] = why .. ": did not want '" .. text .. "' in\n  " .. table.concat(tip.lines, "\n  ") end end
local function hover(id) tip.lines = {}; local ok, err = pcall(callbacks[0], tip, { id = id }); if not ok then failures[#failures + 1] = tostring(err) end end

assert(loadfile(ADDON_PATH .. "/Tooltips/Tooltips.lua"))("Tooltips", {})
frames[#frames].fn(frames[#frames], "PLAYER_LOGIN")

-- 1. A boss drop beats trash and a quest reward, even in a dungeon outside your level; shared loot says so.
hover(1001)
need("Drops from = Aku'mai in Blackfathom Deeps (lvl 22-30)", "boss drop ranks first")
need("several dungeons", "shared between two dungeons")
-- 2. Same rank in two dungeons: the one whose range holds your level wins.
level = 20
hover(1002)
need("Drops from = Mutanus the Devourer in Wailing Caverns (lvl 17-24)", "level 20: Wailing Caverns")
level = 28
hover(1002)
need("Drops from = Aku'mai in Blackfathom Deeps (lvl 22-30)", "level 28: Blackfathom Deeps")
-- 3. Quest rewards: your own faction's dungeon first.
hover(1003)
need("Quest reward = The Defias Brotherhood (The Deadmines, lvl 17-26)", "Alliance: the Deadmines quest")
faction = "Horde"
hover(1003)
need("Quest reward = Hidden Enemies (Ragefire Chasm, lvl 13-18)", "Horde: the Ragefire quest")
lack("Drops from", "a quest reward isn't a drop")

if #failures > 0 then error(table.concat(failures, "\n")) end
print("test_r4a_tooltips_source: ok")