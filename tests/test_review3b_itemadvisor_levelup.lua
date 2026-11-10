-- Review 3b (2026-11-10): ItemAdvisor after a level-up. On Forever UnitLevel can still give the old level
-- for about a second after PLAYER_LEVEL_UP (research\thirdparty_features.md 6.12). The bag scan the hub asks
-- for every second then judged your bags with the old level and kept that answer: an item you can now wear
-- stayed "Upgrade at level 20" (KEEP), with no arrow and no Equip row, until something else changed.
-- Run: node run.js "<workspace root>" test_review3b_itemadvisor_levelup.lua
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
local level = 19
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

assert(loadfile(base .. "/ItemAdvisor/ItemAdvisor.lua"))("ItemAdvisor", {})
local events; for _, f in ipairs(allFrames) do if f.scripts.OnEvent and f ~= ItemAdvisorOverlay then events = f end end
local function fire(...) events.scripts.OnEvent(events, ...) end
fire("PLAYER_LOGIN")

local STR, STA = "ITEM_MOD_STRENGTH_SHORT", "ITEM_MOD_STAMINA_SHORT"
equipped[5] = def(1, { name = "Old Chest", loc = "INVTYPE_CHEST", stats = { [STR] = 2, [STA] = 2 } })
local newChest = def(2, { name = "Level 20 Chest", loc = "INVTYPE_CHEST", minLevel = 20, stats = { [STR] = 10, [STA] = 8 } })
bag[1] = newChest

local function ask(link)
    tipLines, shownLink = {}, link
    postCall(GameTooltip)
    return tipLines[1] or ""
end
local function hubRows()
    local rows = ForeverHubStatus.ItemAdvisor() or {}
    local texts = {}
    for _, row in ipairs(rows) do texts[#texts + 1] = row.text end
    return table.concat(texts, "\n")
end

-- Level 19: an upgrade once you're 20.
hubRows()
assert(ask(newChest):find("Upgrade at level 20", 1, true), "level 19: " .. ask(newChest))

-- Ding. The event says 20, but UnitLevel still says 19 for a moment, and the hub asks meanwhile.
fire("PLAYER_LEVEL_UP", 20)
advance(0.5)
hubRows()
advance(0.5)
hubRows()
-- A second later the game reports the new level.
level = 20
advance(3)
hubRows()
local got = ask(newChest)
assert(got:find("EQUIP", 1, true), "at 20 the chest is an upgrade to wear now: " .. got)
assert(hubRows():find("Equip", 1, true), "the hub lists it to equip: " .. hubRows())
assert(#handled == 0, "clean: " .. tostring(handled[1]))
print("ALL TESTS PASSED")
