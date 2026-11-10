-- ItemAdvisor logic review: a worn off-hand WEAPON always counts its weapon damage at the off-hand
-- rate (half), whatever kind of item it is compared with. Before the fix, a shield or held-in-off-hand
-- item was compared against the worn off-hand weapon's damage at full weight.
-- ADDON_PATH is the folder holding every addon.
local path = ADDON_PATH .. "/ItemAdvisor/ItemAdvisor.lua"
local timers, items, stats, equipped = {}, {}, {}, {}

local function def(id, t)
    local link = "|Hitem:" .. id .. ":|h[" .. t.name .. "]|h"
    items[link] = t
    stats[link] = t.stats
    return link
end
local function newRegion()
    local r = { shown = true, scripts = {} }
    function r:SetScript(s, f) self.scripts[s] = f end
    function r:IsShown() return self.shown end
    function r:IsVisible() return self.shown end
    function r:CreateTexture() return newRegion() end
    function r:CreateFontString() return newRegion() end
    return setmetatable(r, { __index = function() return function() end end })
end
local allFrames = {}
CreateFrame = function(_, name) local f = newRegion(); allFrames[#allFrames + 1] = f; if name then _G[name] = f end; return f end
SlashCmdList = {}
Enum = { TooltipDataType = { Item = 0 } }
local tipLines = {}
GameTooltip = { AddLine = function(_, text) tipLines[#tipLines + 1] = text end }
ItemRefTooltip = {}
local shownLink
TooltipUtil = { GetDisplayedItem = function() return "n", shownLink end }
local postCall
TooltipDataProcessor = { AddTooltipPostCall = function(_, fn) postCall = fn end }
issecretvalue = function() return false end
UnitClass = function() return "Warrior", "WARRIOR" end
UnitName = function() return "T" end
GetRealmName = function() return "R" end
UnitLevel = function() return 30 end
InCombatLockdown = function() return false end
CanDualWield = function() return true end
GetInventoryItemLink = function(_, slot) return equipped[slot] end
geterrorhandler = function() return function(e) error(e) end end
C_Timer = { After = function(_, fn) timers[#timers + 1] = fn end }
C_Item = {
    GetItemInfo = function(link)
        local t = items[link]
        if not t then return nil end
        return t.name, link, 2, 10, 1, "", "", 1, t.loc, 0, 100, t.c, t.s, 2
    end,
    GetItemStats = function(link) return stats[link] end,
    RequestLoadItemDataByID = function() end,
}
C_TooltipInfo = { GetHyperlink = function() return { lines = { { leftText = "name" }, { leftText = "x" } } } end }
C_QuestLog = { GetNumQuestLogEntries = function() return 0 end }
C_Container = { GetContainerNumSlots = function() return 0 end, GetContainerItemInfo = function() end }
NUM_TOTAL_EQUIPPED_BAG_SLOTS = 0

assert(loadfile(path))("ItemAdvisor", {})
local events
for _, f in ipairs(allFrames) do if f.scripts.OnEvent then events = f end end
events.scripts.OnEvent(events, "PLAYER_LOGIN")

local function ask(link)
    tipLines, shownLink = {}, link
    postCall(GameTooltip)
    return tipLines[1] or ""
end

local DPS, STA = "ITEM_MOD_DAMAGE_PER_SECOND_SHORT", "ITEM_MOD_STAMINA_SHORT"
-- Dual-wielding warrior: main-hand sword and a 20 DPS off-hand sword.
equipped[16] = def(1, { name = "Main Sword", loc = "INVTYPE_WEAPON", c = 2, s = 7, stats = { [DPS] = 10 } })
equipped[17] = def(2, { name = "Off Sword", loc = "INVTYPE_WEAPON", c = 2, s = 7, stats = { [DPS] = 20 } })
-- Warrior weights at level 30 (leveling bias on): melee 19, stamina 1.6 x 1.5 = 2.4.
-- Worn off-hand: 20 DPS x 19 x 0.5 = 190. Shield: 100 Stamina x 2.4 = 240, a clear upgrade.
-- (Counting the off-hand sword's damage at full weight made it 380 and the shield a "close call".)
local shield = def(3, { name = "Stout Shield", loc = "INVTYPE_SHIELD", c = 4, s = 6, stats = { [STA] = 100 } })
local got = ask(shield)
assert(got:find("EQUIP: Upgrade for warrior", 1, true), "shield vs off-hand weapon at the off-hand rate: " .. got)

-- The same off-hand sword stays the yardstick for another off-hand weapon (unchanged behavior):
-- 30 DPS x 19 x 0.5 = 285 beats 190.
local better = def(4, { name = "Better Off Sword", loc = "INVTYPE_WEAPONOFFHAND", c = 2, s = 7, stats = { [DPS] = 30 } })
got = ask(better)
assert(got:find("EQUIP: Upgrade for warrior", 1, true), "off-hand weapon vs off-hand weapon: " .. got)

-- A shield that only beats the full-weight number by stamina still loses to a much stronger sword:
-- 50 Stamina x 2.4 = 120 < 190.
local weak = def(5, { name = "Weak Shield", loc = "INVTYPE_SHIELD", c = 4, s = 6, stats = { [STA] = 50 } })
got = ask(weak)
assert(not got:find("EQUIP:", 1, true), "weaker shield is not an upgrade: " .. got)
print("ok")
