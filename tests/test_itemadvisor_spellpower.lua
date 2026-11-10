-- ItemAdvisor review 2026-11-10: a stat that changes the score but has no weight of its own (spell power
-- for casters) must count as a loss, so "better or equal in every stat" can't call a worse item an upgrade.
-- Also: a vendor's copy of a unique item you wear isn't a spare to sell, and hidden worn gear isn't empty.
-- ADDON_PATH = ItemAdvisor\ItemAdvisor.lua
local items, stats, tips, equipped = {}, {}, {}, {}
local secretSlots = {}
local handled = {}

local function def(id, t)
    local link = "|Hitem:" .. id .. ":|h[" .. t.name .. "]|h"
    items[link], stats[link], tips[link] = t, t.stats, t.tip
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
local SECRET = {}
issecretvalue = function(v) return v == SECRET end
UnitClass = function() return "Mage", "MAGE" end
UnitName = function() return "T" end
GetRealmName = function() return "R" end
UnitLevel = function() return 30 end
InCombatLockdown = function() return false end
GetInventoryItemLink = function(_, slot) if secretSlots[slot] then return SECRET end return equipped[slot] end
geterrorhandler = function() return function(e) handled[#handled + 1] = tostring(e) end end
ForeverHub_Receive = function() end
C_Timer = { After = function() end }
C_Item = {
    GetItemInfo = function(link)
        local t = items[link]
        if not t then return nil end
        return t.name, link, t.q or 2, 30, 1, "", "", 1, t.loc or "", 0, t.price or 100, t.c, t.s or 0, 1
    end,
    GetItemStats = function(link) return stats[link] end,
    RequestLoadItemDataByID = function() end,
}
C_TooltipInfo = { GetHyperlink = function(link)
    local lines = { { leftText = "name" } }
    for _, text in ipairs(tips[link] or {}) do lines[#lines + 1] = { leftText = text } end
    return { lines = lines }
end }
C_QuestLog = { GetNumQuestLogEntries = function() return 0 end }
C_Container = { GetContainerNumSlots = function() return 0 end, GetContainerItemInfo = function() end }
NUM_TOTAL_EQUIPPED_BAG_SLOTS = 0

assert(loadfile(ADDON_PATH))("ItemAdvisor", {})
local events; for _, f in ipairs(allFrames) do if f.scripts.OnEvent then events = f end end
events.scripts.OnEvent(events, "PLAYER_LOGIN")

local function ask(link)
    tipLines, shownLink = {}, link
    postCall(GameTooltip)
    return tipLines[1] or ""
end
local SP, INT, STA = "ITEM_MOD_SPELL_POWER_SHORT", "ITEM_MOD_INTELLECT_SHORT", "ITEM_MOD_STAMINA_SHORT"
local function ring(id, name, st, tip) return def(id, { name = name, loc = "INVTYPE_FINGER", c = 4, s = 0, stats = st, tip = tip }) end

-- 1. Losing 12 spell power for 1 Intellect and 5 Stamina is not "better in every stat".
equipped[11] = ring(1, "Spell Ring", { [SP] = 12, [INT] = 5 })
equipped[12] = ring(2, "Spell Ring Two", { [SP] = 12, [INT] = 5 })
local got = ask(ring(3, "Stamina Ring", { [INT] = 6, [STA] = 5 }))
assert(not got:find("EQUIP", 1, true), "worse ring called an upgrade: " .. got)
assert(got:find("Spell Power", 1, true), "the lost spell power is named: " .. got)
-- A real spell power gain still counts.
got = ask(ring(4, "Better Spell Ring", { [SP] = 14, [INT] = 5 }))
assert(got:find("EQUIP", 1, true), "more spell power is an upgrade: " .. got)
print("1 ok")

-- 2. A vendor's (not your bags') copy of a unique ring you wear isn't a spare to sell.
local unique = ring(5, "Unique Ring", { [SP] = 20 }, { "Unique" })
equipped[11] = unique
got = ask(unique)
assert(not got:find("Spare copy", 1, true), "not yours, not a spare: " .. got)
equipped[11] = ring(1, "Spell Ring", { [SP] = 12, [INT] = 5 })
print("2 ok")

-- 3. Worn gear hidden by the game (combat, instances) isn't "an empty slot": say so, and don't keep it.
secretSlots[11], secretSlots[12] = true, true
got = ask(ring(6, "Any Ring", { [STA] = 1 }))
assert(got:find("Can't read your worn gear", 1, true), "hidden gear: " .. got)
secretSlots[11], secretSlots[12] = nil, nil
got = ask(ring(6, "Any Ring", { [STA] = 1 }))
assert(not got:find("Can't read", 1, true), "readable again, not a remembered answer: " .. got)
assert(#handled == 0, "clean: " .. tostring(handled[1]))
print("ALL TESTS PASSED")
