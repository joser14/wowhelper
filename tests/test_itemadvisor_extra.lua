-- ItemAdvisor: dodge/parry tooltip lines, exact quest-item names, safe public API, repaint on role change and new spells.
local path = ADDON_PATH
local toasts, handled, timers, registered = {}, {}, {}, {}
local items, stats, tips, equipped = {}, {}, {}, {}

local function def(id, t)
    local link = "|Hitem:" .. id .. ":|h[" .. t.name .. "]|h"
    items[link] = t
    stats[link] = t.stats
    tips[link] = t.tip
    return link
end
local function newRegion()
    local r = { shown = true, scripts = {}, hooks = {} }
    function r:Hide() self.shown = false end
    function r:Show() self.shown = true end
    function r:SetShown(v) self.shown = v and true or false end
    function r:IsShown() return self.shown end
    function r:SetScript(s, f) self.scripts[s] = f end
    function r:HookScript(s, f) self.hooks[s] = f end
    function r:RegisterEvent(name) registered[name] = true end
    function r:CreateTexture() return newRegion() end
    function r:CreateFontString() return newRegion() end
    return setmetatable(r, { __index = function() return function() end end })
end
local eventFrame
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
UnitClass = function() return "Druid", "DRUID" end
UnitName = function() return "T" end
GetRealmName = function() return "R" end
UnitLevel = function() return 30 end
InCombatLockdown = function() return false end
GetInventoryItemLink = function(_, slot) return equipped[slot] end
geterrorhandler = function() return function(e) handled[#handled + 1] = tostring(e) end end
ForeverHub_Receive = function(_, text) toasts[#toasts + 1] = text end
C_Timer = { After = function(_, fn) timers[#timers + 1] = fn end }
C_Item = {
    GetItemInfo = function(link)
        local t = items[link]
        if not t then return nil end
        return t.name, link, t.q or 1, 10, 1, "", "", 1, t.loc or "", 0, t.price or 0, t.c, t.s or 0, 1
    end,
    GetItemStats = function(link) return stats[link] end,
    RequestLoadItemDataByID = function() end,
}
C_TooltipInfo = { GetHyperlink = function(link)
    local lines = { { leftText = "name" } }
    for _, text in ipairs(tips[link] or {}) do lines[#lines + 1] = { leftText = text } end
    return { lines = lines }
end }
local objectives = {}
C_QuestLog = {
    GetNumQuestLogEntries = function() return 1 end,
    GetInfo = function() return { title = "Wolf Hunt", questID = 5, isHeader = false } end,
    GetQuestObjectives = function() return objectives end,
}
C_Container = { GetContainerNumSlots = function() return 0 end, GetContainerItemInfo = function() end }
NUM_TOTAL_EQUIPPED_BAG_SLOTS = 0

assert(loadfile(path))("ItemAdvisor", {})
local events; for _, f in ipairs(allFrames) do if f.scripts and f.scripts.OnEvent then events = f end end
events.scripts.OnEvent(events, "PLAYER_LOGIN")
assert(#handled == 0, "login: " .. tostring(handled[1]))

-- "Dodge an attack" and "parry an attack" are the classic wording; "an" used to stop them parsing.
local leather = def(1, { name = "Dodgy Vest", loc = "INVTYPE_CHEST", c = 4, s = 2, stats = {},
    tip = { "Equip: Increases your chance to dodge an attack by 1%.", "Equip: Increases your chance to parry an attack by 2%." } })
toasts = {}
SlashCmdList.ITEMADVISOR("stats " .. leather)
local all = table.concat(toasts, "\n")
assert(all:find("1% dodge", 1, true), "dodge parsed: " .. all)
assert(all:find("2% parry", 1, true), "parry parsed: " .. all)
-- A proc still isn't a stat line.
toasts = {}
local proc = def(2, { name = "Proc Ring", loc = "INVTYPE_FINGER", c = 4, s = 0, stats = { ITEM_MOD_STAMINA_SHORT = 1 },
    tip = { "Equip: When struck, you have a chance to gain an attack by 5%." } })
SlashCmdList.ITEMADVISOR("stats " .. proc)
assert(not table.concat(toasts, "\n"):find("Tooltip:", 1, true), "proc ignored")

-- Quest items match by exact name, with the count on either side.
local function verdictFor(link)
    tipLines = {}
    shownLink = link
    postCall(GameTooltip)
    return tipLines[1] or ""
end
local meat = def(10, { name = "Wolf Meat", c = 7, price = 5 })
local tender = def(11, { name = "Tender Wolf Meat", c = 7, price = 5 })
objectives = { { type = "item", text = "0/5 Tender Wolf Meat" } }
events.scripts.OnEvent(events, "QUEST_LOG_UPDATE")
assert(verdictFor(tender):find("Needed for Wolf Hunt", 1, true), "count first: " .. verdictFor(tender))
assert(not verdictFor(meat):find("Needed for", 1, true), "shorter name doesn't match: " .. verdictFor(meat))
objectives = { { type = "item", text = "Wolf Meat: 2/5" } }
events.scripts.OnEvent(events, "QUEST_LOG_UPDATE")
assert(verdictFor(meat):find("Needed for Wolf Hunt", 1, true), "count last: " .. verdictFor(meat))
assert(not verdictFor(tender):find("Needed for", 1, true), "longer name doesn't match")
-- Text without a count still matches loosely.
objectives = { { type = "item", text = "Bring back Wolf Meat" } }
events.scripts.OnEvent(events, "QUEST_LOG_UPDATE")
assert(verdictFor(meat):find("Needed for", 1, true), "no count: loose match")
-- A secret objective is skipped, not crashed on.
issecretvalue = function(v) return v == "item" end
events.scripts.OnEvent(events, "QUEST_LOG_UPDATE")
assert(not verdictFor(meat):find("Needed for", 1, true), "secret objective skipped")
issecretvalue = function() return false end

-- The public check takes junk input without erroring.
assert(ItemAdvisor_IsUpgrade(nil) == false, "nil link")
assert(ItemAdvisor_IsUpgrade(42) == false, "number")
assert(ItemAdvisor_IsUpgrade("") == false, "empty")
issecretvalue = function() return true end
assert(ItemAdvisor_IsUpgrade(leather) == false, "secret link")
issecretvalue = function() return false end

-- Changing role repaints the bag marks; learning a spell does too.
while #timers > 0 do table.remove(timers, 1)() end
SlashCmdList.ITEMADVISOR("role tank")
assert(#timers == 1, "role change repaints")
assert(toasts[#toasts]:find("Role set to tank", 1, true), "role toast")
while #timers > 0 do table.remove(timers, 1)() end
assert(registered.LEARNED_SPELL_IN_SKILL_LINE, "listens for new spells")
events.scripts.OnEvent(events, "LEARNED_SPELL_IN_SKILL_LINE")
assert(#timers == 1, "new spell repaints")
while #timers > 0 do table.remove(timers, 1)() end

assert(#handled == 0, "clean: " .. tostring(handled[1]))
print("ALL TESTS PASSED")
