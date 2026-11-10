-- Round 3 rank 6: ItemAdvisor's weights follow your level (Gear Judge leveling curves, MIT, in
-- ItemAdvisor\GearCurves.lua), and a ring or trinket upgrade names which worn one it replaces.
-- Harness from test_review3b_itemadvisor_levelup.lua.
local base = ADDON_PATH
local items, stats, equipped = {}, {}, {}
local handled = {}

local function def(id, t)
    local link = "|Hitem:" .. id .. ":|h[" .. t.name .. "]|h"
    items[link], stats[link] = t, t.stats
    return link
end
local function newRegion()
    local r = { shown = true, scripts = {} }
    function r:SetScript(s, f) self.scripts[s] = f end
    function r:CreateTexture() return newRegion() end
    function r:CreateFontString() return newRegion() end
    return setmetatable(r, { __index = function() return function() end end })
end
local allFrames = {}
CreateFrame = function(_, name) local f = newRegion(); allFrames[#allFrames + 1] = f; if name then _G[name] = f end; return f end
SlashCmdList = {}
Enum = { TooltipDataType = { Item = 0 } }
local tipLines = {}
GameTooltip = { AddLine = function(_, text) tipLines[#tipLines + 1] = text end, GetProcessingTooltipInfo = function() end }
ItemRefTooltip = {}
local shownLink
TooltipUtil = { GetDisplayedItem = function() return "n", shownLink end }
local postCall
TooltipDataProcessor = { AddTooltipPostCall = function(_, fn) postCall = fn end }
issecretvalue = function() return false end
UnitClass = function() return "Warrior", "WARRIOR" end
UnitName = function() return "T" end
GetRealmName = function() return "R" end
local level = 30
UnitLevel = function() return level end
InCombatLockdown = function() return false end
GetInventoryItemLink = function(_, slot) return equipped[slot] end
geterrorhandler = function() return function(e) handled[#handled + 1] = tostring(e) end end
ForeverHub_Receive = function() end

-- A clock for C_Timer.After.
local now, timers = 0, {}
C_Timer = { After = function(delay, fn) timers[#timers + 1] = { at = now + delay, fn = fn } end }
local function advance(seconds)
    local stop = now + seconds
    while true do
        local nextIndex
        for index, timer in ipairs(timers) do
            if timer.at <= stop and (not nextIndex or timer.at < timers[nextIndex].at) then
                nextIndex = index
            end
        end
        if not nextIndex then
            break
        end
        local timer = table.remove(timers, nextIndex)
        now = math.max(now, timer.at)
        timer.fn()
    end
    now = stop
end

C_Item = {
    GetItemInfo = function(link)
        local t = items[link]
        if not t then return nil end
        -- name, link, quality, itemLevel, minLevel, type, subType, stack, equipLoc, icon, sellPrice, classID, subClassID, bindType
        return t.name, link, 2, 20, t.minLevel or 1, "", "", 1, t.loc, 0, 100, 4, t.s or 3, 2
    end,
    GetItemStats = function(link) return stats[link] end,
    RequestLoadItemDataByID = function() end,
}
C_TooltipInfo = { GetHyperlink = function() return { lines = { { leftText = "name" }, { leftText = "Chest" } } } end }
C_QuestLog = { GetNumQuestLogEntries = function() return 0 end }
local bag = {}
C_Container = {
    GetContainerNumSlots = function(b) return b == 0 and #bag or 0 end,
    GetContainerItemInfo = function(b, slot) local link = b == 0 and bag[slot]; return link and { hyperlink = link, isBound = false, stackCount = 1 } end,
}
NUM_TOTAL_EQUIPPED_BAG_SLOTS = 0

local function load(withCurves)
    ItemAdvisorCurves = nil
    if withCurves then
        assert(loadfile(base .. "/ItemAdvisor/GearCurves.lua"))("ItemAdvisor", {})
    end
    allFrames = {}
    assert(loadfile(base .. "/ItemAdvisor/ItemAdvisor.lua"))("ItemAdvisor", {})
    local events; for _, f in ipairs(allFrames) do if f.scripts.OnEvent and f ~= ItemAdvisorOverlay then events = f end end
    events.scripts.OnEvent(events, "PLAYER_LOGIN")
    return function(...) events.scripts.OnEvent(events, ...) end
end
local function ask(link)
    tipLines, shownLink = {}, link
    postCall(GameTooltip)
    return tipLines[1] or ""
end

local STR, STA, CRIT = "ITEM_MOD_STRENGTH_SHORT", "ITEM_MOD_STAMINA_SHORT", "ITEM_MOD_CRIT_RATING_SHORT"
equipped[11] = def(1, { name = "Sturdy Band", loc = "INVTYPE_FINGER", s = 0, stats = { [STA] = 4 } })
equipped[12] = def(2, { name = "Strong Band", loc = "INVTYPE_FINGER", s = 0, stats = { [STR] = 5 } })
local keen = def(3, { name = "Keen Band", loc = "INVTYPE_FINGER", s = 0, stats = { [CRIT] = 10 } })
bag[1] = keen

-- 1. The curve file is plain data for every class's leveling roles.
load(true)
for _, class in ipairs({ "WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST", "SHAMAN", "MAGE", "WARLOCK", "DRUID" }) do
    assert(ItemAdvisorCurves[class] and ItemAdvisorCurves[class].Leveling, "curve for " .. class)
end
print("1 ok")

-- 2. Level 30 warrior. Without curves (fixed level-60 weights) 10 crit rating beats 4 Stamina; Gear Judge's
-- level-30 curve says crit is worth far less there (9.9 per 1% vs Stamina 2.4), so it's no upgrade.
load(false)
local got = ask(keen)
assert(got:find("EQUIP", 1, true), "fixed weights call it an upgrade: " .. got)
local fire = load(true)
got = ask(keen)
assert(not got:find("EQUIP", 1, true), "level 30 curve: crit isn't worth 4 Stamina yet: " .. got)
print("2 ok")

-- 3. At 55 crit counts (26.4 per 1%, Stamina 0.8): an upgrade, and it names the weaker worn ring.
level = 55
fire("PLAYER_LEVEL_UP", 55)
advance(3)
got = ask(keen)
assert(got:find("EQUIP", 1, true), "level 55: an upgrade: " .. got)
assert(got:find("replaces Sturdy Band", 1, true), "names the ring it replaces: " .. got)
print("3 ok")

-- 4. At 60 the fixed weights are back.
level = 60
fire("PLAYER_LEVEL_UP", 60)
advance(3)
got = ask(keen)
assert(got:find("EQUIP", 1, true) and got:find("replaces Sturdy Band", 1, true), "level 60 fixed weights: " .. got)
-- A chest isn't a paired slot: no "replaces".
equipped[5] = def(4, { name = "Old Chest", loc = "INVTYPE_CHEST", s = 0, stats = { [STR] = 1 } })
local chest = def(5, { name = "New Chest", loc = "INVTYPE_CHEST", s = 0, stats = { [STR] = 9 } })
got = ask(chest)
assert(got:find("EQUIP", 1, true) and not got:find("replaces", 1, true), "single slot: " .. got)
print("4 ok")

assert(#handled == 0, "clean: " .. tostring(handled[1]))
print("ALL TESTS PASSED")