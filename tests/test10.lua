-- Bag badges, quest reward marks, vendor reminder, and the login-order crash from the real error log.
local path = ADDON_PATH
local toasts, handled, timers = {}, {}, {}
local items, stats, equipped = {}, {}, {}
local level, combat = 20, false

local function def(id, t)
    local link = "|Hitem:" .. id .. ":|h[" .. t.name .. "]|h"
    items[link] = t
    stats[link] = t.stats
    return link
end
local function newRegion()
    local r = { shown = true, scripts = {}, hooks = {} }
    function r:Hide() self.shown = false end
    function r:Show() self.shown = true end
    function r:SetShown(v) self.shown = v and true or false end
    function r:IsShown() return self.shown end
    function r:SetText(t) self.text = t end
    function r:SetScript(s, f) self.scripts[s] = f end
    function r:HookScript(s, f) self.hooks[s] = f end
    function r:RegisterEvent() end
    function r:GetFrameLevel() return 1 end
    local function child()
        local t = newRegion()
        local kids = rawget(r, "children") or {}
        rawset(r, "children", kids)
        kids[#kids + 1] = t
        return t
    end
    function r:CreateTexture() return child() end
    function r:CreateFontString() return child() end
    return setmetatable(r, { __index = function(_, k) return function() end end })
end
local eventFrame
CreateFrame = function(_, _, parent)
    local f = newRegion()
    if parent then parent.mark = f else eventFrame = f end
    return f
end
SlashCmdList = {}
Enum = { TooltipDataType = { Item = 0 } }
GameTooltip, ItemRefTooltip = {}, {}
TooltipUtil = { GetDisplayedItem = function() end }
TooltipDataProcessor = { AddTooltipPostCall = function() end }
issecretvalue = function() return false end
UnitClass = function() return "Mage", "MAGE" end
UnitName = function() return "T" end
GetRealmName = function() return "R" end
UnitLevel = function() return level end
InCombatLockdown = function() return combat end
GetInventoryItemLink = function(_, slot) return equipped[slot] end
geterrorhandler = function() return function(e) handled[#handled + 1] = tostring(e) end end
ForeverHub_Receive = function(_, text) toasts[#toasts + 1] = text end
C_Timer = { After = function(_, fn) timers[#timers + 1] = fn end }
local function flush()
    while #timers > 0 do table.remove(timers, 1)() end
end
C_Item = {
    GetItemInfo = function(link)
        local t = items[link]
        if not t or t.uncached then return nil end
        return t.name, link, t.q or 1, 10, t.min or 1, "", "", 1, t.loc, 0, t.price or 0, t.c, t.s or 0, t.b or 1
    end,
    GetItemStats = function(link) return stats[link] end,
    RequestLoadItemDataByID = function() end,
}
C_TooltipInfo = { GetHyperlink = function() return { lines = { {} } } end }
C_QuestLog = { GetNumQuestLogEntries = function() return 0 end }

local INT, STA, STR = "ITEM_MOD_INTELLECT_SHORT", "ITEM_MOD_STAMINA_SHORT", "ITEM_MOD_STRENGTH_SHORT"
local CLOTH = { c = 4, s = 1 }
local function cloth(id, name, loc, extra, price)
    return def(id, { name = name, loc = loc, c = CLOTH.c, s = CLOTH.s, stats = extra, price = price })
end
local worn = cloth(1, "Worn Robe", "INVTYPE_CHEST", { [INT] = 2 })
equipped[5] = worn
local upgrade = cloth(2, "Fine Robe", "INVTYPE_CHEST", { [INT] = 8 }, 500)
local bigger = cloth(3, "Grand Robe", "INVTYPE_CHEST", { [INT] = 20 }, 100)
local worse = cloth(4, "Rag Robe", "INVTYPE_CHEST", { [INT] = 1 }, 300)
local mail = def(5, { name = "Mail Vest", loc = "INVTYPE_CHEST", c = 4, s = 3, stats = { [STR] = 30 }, price = 2000 })
local junk = def(6, { name = "Broken Tusk", q = 0, c = 15, price = 25, stats = {} })

local bag = {}
C_Container = {
    GetContainerNumSlots = function() return 5 end,
    GetContainerItemInfo = function(_, slot) return bag[slot] end,
}
NUM_TOTAL_EQUIPPED_BAG_SLOTS = 0

local function bagButton(slot)
    local button = newRegion()
    button.bagID = 0
    button.GetID = function() return slot end
    return button
end
local buttons = {}
for slot = 1, 5 do buttons[slot] = bagButton(slot) end
buttons[5].shown = false
ContainerFrameCombinedBags = newRegion()
ContainerFrameCombinedBags.Items = buttons
ContainerFrameCombinedBags.EnumerateValidItems = function() error("must not touch Blizzard's item cache") end
ContainerFrameCombinedBags.GetBagSize = function() error("must not touch Blizzard's size cache") end
ContainerFrameUtil_EnumerateContainerFrames = function() error("must not touch Blizzard's frame cache") end
ContainerFrameContainer = { ContainerFrames = { newRegion() } }
ContainerFrameContainer.ContainerFrames[1].shown = false

local rewardList = {}
GetNumQuestChoices = function() return #rewardList end
GetQuestItemLink = function(_, i) return rewardList[i] end
GetQuestItemInfo = function(_, i) return "n", "t", 1, 1, true, 1 end
local function rewardButton(i)
    local button = newRegion()
    button.type = "choice"
    button.Icon = newRegion()
    button.GetID = function() return i end
    return button
end
QuestInfoRewardsFrame = { RewardButtons = { rewardButton(1), rewardButton(2), rewardButton(3) } }
local rewardButtons = QuestInfoRewardsFrame.RewardButtons

assert(loadfile(path))("ItemAdvisor", {})
local events = eventFrame

-- The real crash: the hub's page ran before this addon's login step (hub loads first alphabetically).
SlashCmdList.ITEMADVISOR("")
assert(#handled == 0, "no crash before login")
events.scripts.OnEvent(events, "BAG_UPDATE_DELAYED")
assert(#timers == 0, "nothing runs before login")

events.scripts.OnEvent(events, "PLAYER_LOGIN")
assert(ContainerFrameCombinedBags.hooks.OnShow, "repaints when a bag opens")

-- Bag badges.
local function badge(button, which)
    local kids = rawget(button, "children") or {}
    return kids[which == "arrow" and 1 or 2]
end
bag[1] = { hyperlink = upgrade, stackCount = 1 }
bag[2] = { hyperlink = mail, stackCount = 1 }
bag[3] = { hyperlink = junk, stackCount = 3 }
ContainerFrameCombinedBags.hooks.OnShow()
flush()
assert(#handled == 0, "paint clean: " .. tostring(handled[1]))
assert(badge(buttons[1], "arrow").shown and not badge(buttons[1], "coin").shown, "upgrade gets the arrow")
assert(badge(buttons[2], "coin").shown and not badge(buttons[2], "arrow").shown, "armor a mage can't wear gets the coin")
assert(badge(buttons[3], "coin").shown, "junk gets the coin")
assert(not rawget(buttons[4], "children"), "empty slot gets nothing")

-- Slots get reused, so badges clear.
bag[1] = nil
events.scripts.OnEvent(events, "BAG_UPDATE_DELAYED")
flush()
assert(not badge(buttons[1], "arrow").shown, "badge clears when the item moves")

-- Equipping changes the verdict.
bag[1] = { hyperlink = worse, stackCount = 1 }
events.scripts.OnEvent(events, "PLAYER_EQUIPMENT_CHANGED")
flush()
assert(badge(buttons[1], "coin").shown, "worse robe is a sell")

-- In combat nothing scans; it catches up afterward.
combat = true
bag[1] = { hyperlink = upgrade, stackCount = 1 }
events.scripts.OnEvent(events, "BAG_UPDATE_DELAYED")
flush()
assert(not badge(buttons[1], "arrow").shown, "no scan in combat")
combat = false
events.scripts.OnEvent(events, "PLAYER_REGEN_ENABLED")
flush()
assert(badge(buttons[1], "arrow").shown, "catches up after combat")

-- Vendor reminder.
toasts = {}
events.scripts.OnEvent(events, "MERCHANT_SHOW")
flush()
assert(toasts[1] and toasts[1]:find("Sell 2 item(s) for 20s 75c", 1, true), "vendor: " .. tostring(toasts[1]))

-- Quest rewards: biggest upgrade is BEST, highest price gets the coin, and neither picks for you.
GetQuestReward = function() error("must never choose a reward") end
toasts = {}
rewardList = { upgrade, bigger, worse }
events.scripts.OnEvent(events, "QUEST_COMPLETE")
flush()
assert(#handled == 0, "rewards clean: " .. tostring(handled[1]))
local function mark(i) return rawget(rewardButtons[i], "mark") end
assert(mark(2) and mark(2).shown and mark(2).glow.shown and mark(2).label.shown, "biggest upgrade is best")
assert(mark(1) and mark(1).shown and mark(1).coin.shown and not mark(1).glow.shown, "highest price gets the coin")
assert(not mark(3), "the other choice gets no mark")
assert(#toasts == 1 and toasts[1]:find("take " .. bigger, 1, true) and toasts[1]:find("+18 Intellect", 1, true), "reward pop-up: " .. tostring(toasts[1]))
-- The retry doesn't repeat the pop-up.
events.scripts.OnEvent(events, "GET_ITEM_INFO_RECEIVED")
flush()
assert(#toasts == 1, "one pop-up per window")
events.scripts.OnEvent(events, "QUEST_FINISHED")
assert(not mark(2).shown and not mark(1).shown, "marks leave with the window")

-- No upgrades: says what sells best. The quest-offer screen marks, without a pop-up.
toasts = {}
rewardList = { worse, mail }
events.scripts.OnEvent(events, "QUEST_DETAIL")
flush()
assert(#toasts == 0, "no pop-up when only reading the offer")
assert(mark(2).shown and mark(2).coin.shown and not mark(2).glow.shown, "coin on offer")
events.scripts.OnEvent(events, "QUEST_FINISHED")
toasts = {}
events.scripts.OnEvent(events, "QUEST_COMPLETE")
flush()
assert(toasts[1]:find("no upgrades", 1, true) and toasts[1]:find("20s", 1, true), "sell-best pop-up: " .. tostring(toasts[1]))
events.scripts.OnEvent(events, "QUEST_FINISHED")

-- Late item data: wait, then mark and pop up once.
toasts = {}
local late = cloth(7, "Late Robe", "INVTYPE_CHEST", { [INT] = 40 }, 10)
items[late].uncached = true
rewardList = { upgrade, late }
events.scripts.OnEvent(events, "QUEST_COMPLETE")
flush()
assert(#toasts == 0, "waits for data")
items[late].uncached = nil
events.scripts.OnEvent(events, "GET_ITEM_INFO_RECEIVED")
flush()
assert(#toasts == 1 and toasts[1]:find(late, 1, true), "late data: " .. tostring(toasts[1]))
events.scripts.OnEvent(events, "QUEST_FINISHED")

-- A currency choice has no item to wait for, so the advice on the others still comes.
toasts = {}
GetQuestItemInfoLootType = function(_, i) return i == 3 and 1 or 0 end
rewardList = { upgrade, bigger, nil }
GetNumQuestChoices = function() return 3 end
events.scripts.OnEvent(events, "QUEST_COMPLETE")
flush()
assert(#toasts == 1 and toasts[1]:find(bigger, 1, true), "currency choice: " .. tostring(toasts[1]))
events.scripts.OnEvent(events, "QUEST_FINISHED")
GetQuestItemInfoLootType = nil
GetNumQuestChoices = function() return #rewardList end

-- An item whose stats never load doesn't cost you the advice: the wait runs out.
toasts = {}
-- Changed for the stat-less fix: a named item with empty stats now scores 0, so "never loads" means no name either.
local blank = def(8, { name = "Blank Robe", loc = "INVTYPE_CHEST", c = 4, s = 1, stats = {}, price = 10, uncached = true })
rewardList = { bigger, upgrade, blank }
local queued = {}
C_Timer.After = function(delay, fn) queued[#queued + 1] = { delay, fn } end
events.scripts.OnEvent(events, "QUEST_COMPLETE")
local function runUpTo(limit)
    for index = #queued, 1, -1 do
        if queued[index][1] <= limit then table.remove(queued, index)[2]() end
    end
end
runUpTo(0.5); runUpTo(0.5)
assert(#toasts == 0, "still waiting at first")
runUpTo(2); runUpTo(2)
assert(#toasts == 1 and toasts[1]:find(bigger, 1, true), "wait limit: " .. tostring(toasts[1]))
events.scripts.OnEvent(events, "QUEST_FINISHED")
C_Timer.After = function(_, fn) timers[#timers + 1] = fn end

-- One reward isn't a choice. Hidden values don't crash.
toasts = {}
rewardList = { upgrade }
events.scripts.OnEvent(events, "QUEST_COMPLETE")
flush()
assert(#toasts == 0, "single reward: no advice needed")
events.scripts.OnEvent(events, "QUEST_FINISHED")
issecretvalue = function() return true end
rewardList = { upgrade, bigger }
events.scripts.OnEvent(events, "QUEST_COMPLETE")
events.scripts.OnEvent(events, "MERCHANT_SHOW")
events.scripts.OnEvent(events, "BAG_UPDATE_DELAYED")
flush()
assert(#handled == 0, "secret values: " .. tostring(handled[1]))
print("ALL TESTS PASSED")
