-- ItemAdvisor: role from talents (trait tree and the older tab API), manual override and "role auto",
-- the leveling bias, weapon pairs against a worn two-hander, bag scans spread over frames, and the
-- bounded retry for items that never load. ADDON_PATH is ItemAdvisor.lua.
local path = ADDON_PATH
local toasts, handled, timers = {}, {}, {}
local items, stats, equipped = {}, {}, {}
local level, class = 30, "WARRIOR"

local function def(id, t)
    local link = "|Hitem:" .. id .. ":|h[" .. t.name .. "]|h"
    items[link] = t
    stats[link] = t.stats
    return link
end
local function newRegion()
    local r = { shown = true, scripts = {} }
    function r:Hide() self.shown = false end
    function r:Show() self.shown = true end
    function r:SetShown(v) self.shown = v and true or false end
    function r:IsShown() return self.shown end
    function r:IsVisible() return self.shown end
    function r:SetScript(s, f) self.scripts[s] = f end
    function r:CreateTexture() return newRegion() end
    function r:CreateFontString() return newRegion() end
    return setmetatable(r, { __index = function() return function() end end })
end
local allFrames = {}
local registered = {}
CreateFrame = function(_, name)
    local f = newRegion()
    f.RegisterEvent = function(_, e) registered[e] = true end
    allFrames[#allFrames + 1] = f
    if name then _G[name] = f end
    return f
end
SlashCmdList = {}
Enum = { TooltipDataType = { Item = 0 } }
GameTooltip = { AddLine = function() end }
ItemRefTooltip = {}
local shownLink
TooltipUtil = { GetDisplayedItem = function() return "n", shownLink end }
local postCall
local tipLines = {}
GameTooltip.AddLine = function(_, text) tipLines[#tipLines + 1] = text end
TooltipDataProcessor = { AddTooltipPostCall = function(_, fn) postCall = fn end }
issecretvalue = function() return false end
UnitClass = function() return class, class end
UnitName = function() return "T" end
GetRealmName = function() return "R" end
UnitLevel = function() return level end
InCombatLockdown = function() return false end
GetInventoryItemLink = function(_, slot) return equipped[slot] end
geterrorhandler = function() return function(e) handled[#handled + 1] = tostring(e) end end
ForeverHub_Receive = function(_, text) toasts[#toasts + 1] = text end
C_Timer = { After = function(delay, fn) timers[#timers + 1] = { delay = delay, fn = fn } end }
local function flush(limit)
    local runs = 0
    while #timers > 0 do
        runs = runs + 1
        assert(runs < (limit or 500), "timers never stop")
        table.remove(timers, 1).fn()
    end
    return runs
end
local loadRequests = 0
C_Item = {
    GetItemInfo = function(link)
        local t = items[link]
        if not t then return nil end
        return t.name, link, t.q or 1, 10, 1, "", "", 1, t.loc or "", 0, t.price or 0, t.c, t.s or 0, 1
    end,
    GetItemStats = function(link) return stats[link] end,
    RequestLoadItemDataByID = function() loadRequests = loadRequests + 1 end,
}
C_TooltipInfo = { GetHyperlink = function() return { lines = { { leftText = "name" }, { leftText = "x" } } } end }
C_QuestLog = { GetNumQuestLogEntries = function() return 0 end }
local bag, slotReads = {}, 0
local numSlots = 16
C_Container = {
    GetContainerNumSlots = function(bagID) return bagID == 0 and numSlots or 0 end,
    GetContainerItemInfo = function(bagID, slot) slotReads = slotReads + 1; return bagID == 0 and bag[slot] or nil end,
}
NUM_TOTAL_EQUIPPED_BAG_SLOTS = 0

-- Talents as a trait tree: node -> { ranks, subTree }; subTree -> name.
local nodes, subTrees = {}, { [1] = "Arms", [2] = "Fury", [3] = "Protection" }
local function useTraits()
    C_ClassTalents = { GetActiveConfigID = function() return 7 end }
    C_Traits = {
        GetConfigInfo = function(id) assert(id == 7); return { treeIDs = { 50 } } end,
        GetTreeNodes = function(tree) assert(tree == 50); local ids = {}; for id in pairs(nodes) do ids[#ids + 1] = id end; table.sort(ids); return ids end,
        GetNodeInfo = function(_, id) local n = nodes[id]; return { ID = id, ranksPurchased = n[1], subTreeID = n[2] } end,
        GetSubTreeInfo = function(_, sub) return { ID = sub, name = subTrees[sub] } end,
    }
end

assert(loadfile(path))("ItemAdvisor", {})
local events; for _, f in ipairs(allFrames) do if f.scripts.OnEvent then events = f end end
local function fire(e, ...) events.scripts.OnEvent(events, e, ...) end
local function ask(link)
    tipLines, shownLink = {}, link
    postCall(GameTooltip)
    return tipLines[1] or ""
end
local function want(link, text, why)
    local got = ask(link)
    assert(got:find(text, 1, true), why .. ": wanted '" .. text .. "', got: " .. got)
end
local function page(arg)
    toasts = {}
    SlashCmdList.ITEMADVISOR(arg or "")
    return table.concat(toasts, "\n")
end

-- 1. Role from the trait tree: the tab with the most points wins.
useTraits()
nodes = { [101] = { 5, 1 }, [102] = { 6, 3 }, [103] = { 5, 3 }, [104] = { 0, 2 } }
fire("PLAYER_LOGIN")
local db = ItemAdvisorDB["T-R"]
assert(db.profile == "tank", "11 points in Protection picks tank: " .. tostring(db.profile))
assert(db.roleChosen == false, "a new character follows talents")
local text = page("")
assert(text:find("Role:|r tank, picked from your talents (11 points in Protection)", 1, true), "page explains the role: " .. text)
assert(text:find("Leveling bias:|r on", 1, true), "page shows the leveling bias: " .. text)
assert(text:find("Type: leveling off", 1, true), "page says how to switch it: " .. text)
flush()
-- Respec: talent events follow.
nodes = { [101] = { 15, 1 }, [102] = { 3, 3 } }
assert(registered.TRAIT_CONFIG_UPDATED and registered.PLAYER_TALENT_UPDATE, "listens for talent changes")
fire("TRAIT_CONFIG_UPDATED")
assert(db.profile == "warrior", "15 in Arms picks warrior")
assert(#timers == 1, "a role change repaints")
flush()
-- A tie or too few points leaves the role alone.
nodes = { [101] = { 8, 1 }, [102] = { 8, 3 } }
fire("PLAYER_TALENT_UPDATE")
assert(db.profile == "warrior", "tie keeps the role")
nodes = { [102] = { 4, 3 } }
fire("PLAYER_TALENT_UPDATE")
assert(db.profile == "warrior", "4 points is too few")
-- Your own choice wins until "role auto".
nodes = { [102] = { 20, 3 } }
assert(page("role warrior"):find("Role set to warrior", 1, true), "manual role")
assert(db.roleChosen == true, "manual role remembered")
fire("TRAIT_CONFIG_UPDATED")
assert(db.profile == "warrior", "talents don't override a chosen role")
assert(page(""):find("you chose it. Type role auto", 1, true), "page says the role was chosen")
text = page("role auto")
assert(db.profile == "tank" and db.roleChosen == false, "role auto follows talents again")
assert(text:find("Role follows your talents: tank (20 points in Protection)", 1, true), "role auto message: " .. text)
flush()
-- A tab name this addon doesn't know changes nothing.
subTrees[3] = "Something New"
fire("TRAIT_CONFIG_UPDATED")
assert(db.profile == "tank", "unknown tab name keeps the role")
subTrees[3] = "Protection"
-- Broken or secret talent data is ignored, never an error.
C_Traits.GetNodeInfo = function() error("boom") end
fire("TRAIT_CONFIG_UPDATED")
issecretvalue = function(v) return v == "Protection" end
C_Traits.GetNodeInfo = function(_, id) local n = nodes[id]; return { ranksPurchased = n[1], subTreeID = n[2] } end
fire("TRAIT_CONFIG_UPDATED")
issecretvalue = function() return false end
assert(db.profile == "tank", "secret tab name keeps the role")
flush()

-- 2. The older tab API as a fallback, with either return layout.
C_ClassTalents, C_Traits = nil, nil
GetTalentTabInfo = function(i) return ({ "Arms", "Fury", "Protection" })[i], "icon", ({ 2, 21, 0 })[i] end
fire("PLAYER_TALENT_UPDATE")
assert(db.profile == "warrior", "legacy layout 1: Fury picks warrior")
GetTalentTabInfo = function(i) return i, ({ "Arms", "Fury", "Protection" })[i], "desc", "icon", ({ 0, 0, 12 })[i] end
fire("PLAYER_TALENT_UPDATE")
assert(db.profile == "tank", "legacy layout 2: Protection picks tank")
GetTalentTabInfo = nil
flush()

-- 3. Saves from before talent roles: a non-default role was picked by hand and is kept.
ItemAdvisorDB["T-R"] = { profile = "tank" }
useTraits()
nodes = { [101] = { 30, 1 } }
fire("PLAYER_LOGIN")
db = ItemAdvisorDB["T-R"]
assert(db.profile == "tank" and db.roleChosen == true, "old manual role kept")
ItemAdvisorDB["T-R"] = { profile = "warrior" }
nodes = { [102] = { 30, 3 } }
fire("PLAYER_LOGIN")
db = ItemAdvisorDB["T-R"]
assert(db.profile == "tank" and db.roleChosen == false, "old default role follows talents")
-- A class with one role never guesses.
class = "ROGUE"
fire("PLAYER_LOGIN")
db = ItemAdvisorDB["T-R"]
assert(db.profile == "rogue", "rogue stays rogue")
assert(page(""):find("your class has one role", 1, true), "single-role page text")
class = "WARRIOR"
C_ClassTalents, C_Traits = nil, nil
fire("PLAYER_LOGIN")
db = ItemAdvisorDB["T-R"]
SlashCmdList.ITEMADVISOR("role warrior")
flush()

-- 4. Leveling bias: Stamina counts 50% more below 60, so 5 Stamina beats 4 Strength for a warrior.
local function armor(id, name, st) return def(id, { name = name, loc = "INVTYPE_NECK", c = 4, s = 0, stats = st, price = 100 }) end
equipped[2] = armor(1, "Str Neck", { ITEM_MOD_STRENGTH_SHORT = 4 })
local staNeck = armor(2, "Sta Neck", { ITEM_MOD_STAMINA_SHORT = 5 })
want(staNeck, "EQUIP: Upgrade for warrior", "leveling bias favours stamina at 30")
page("leveling off")
assert(db.levelingBias == false, "bias saved off")
flush()
want(staNeck, "CHECK: Close call", "without the bias it's a trade-off")
assert(page(""):find("Leveling bias:|r off", 1, true), "page shows off")
page("leveling on")
flush()
want(staNeck, "EQUIP:", "bias back on")
level = 60
fire("PLAYER_LEVEL_UP")
flush()
want(staNeck, "CHECK: Close call", "no bias at the level cap")
assert(page(""):find("Not in use right now", 1, true), "page says the bias is idle at 60")
level = 30
fire("PLAYER_LEVEL_UP")
flush()
equipped[2] = nil

-- 5. Weapon pairs against a worn two-hander.
local DPS = "ITEM_MOD_DAMAGE_PER_SECOND_SHORT"
equipped[16] = def(20, { name = "Big Axe", loc = "INVTYPE_2HWEAPON", c = 2, s = 1, stats = { [DPS] = 20 } })
local mainAxe = def(21, { name = "Main Axe", loc = "INVTYPE_WEAPONMAINHAND", c = 2, s = 0, stats = { [DPS] = 18 }, price = 50 })
local shield = def(22, { name = "Tower Shield", loc = "INVTYPE_SHIELD", c = 4, s = 6, stats = { ITEM_MOD_ARMOR_SHORT = 1000 }, price = 50 })
local weakShield = def(23, { name = "Buckler", loc = "INVTYPE_SHIELD", c = 4, s = 6, stats = { ITEM_MOD_ARMOR_SHORT = 10 }, price = 50 })
-- Alone in the bags: nothing to pair with, so it's still "compare it yourself".
bag[1] = { hyperlink = mainAxe }
fire("BAG_UPDATE_DELAYED"); flush()
want(mainAxe, "CHECK: You wear a two-hander; this is only half", "no partner")
-- With a strong shield: both halves are upgrades, each naming the other.
bag[2] = { hyperlink = shield }
fire("BAG_UPDATE_DELAYED"); flush()
want(mainAxe, "EQUIP: Upgrade for warrior together with " .. shield, "main hand with shield partner")
want(shield, "EQUIP: Upgrade for warrior together with " .. mainAxe, "shield with main-hand partner")
assert(ask(mainAxe):find("the pair beats your two-hander", 1, true), "explains the pair")
-- A weak partner: still a check, never a sell.
bag[2] = { hyperlink = weakShield }
fire("BAG_UPDATE_DELAYED"); flush()
want(mainAxe, "CHECK: You wear a two-hander; even paired with " .. weakShield, "weak pair is a check")
want(weakShield, "CHECK: You wear a two-hander", "weak shield is a check")
-- Off-hand weapons pair only once you can dual wield.
local offAxe = def(24, { name = "Off Axe", loc = "INVTYPE_WEAPONOFFHAND", c = 2, s = 0, stats = { [DPS] = 30 }, price = 50 })
bag[2] = { hyperlink = offAxe }
fire("BAG_UPDATE_DELAYED"); flush()
want(mainAxe, "only half of a replacement", "no dual wield: the off axe is no partner")
CanDualWield = function() return true end
fire("BAG_UPDATE_DELAYED"); flush()
want(mainAxe, "together with " .. offAxe, "dual wield: the off axe partners the main axe")
CanDualWield = nil
-- Two copies of the same one-hander can pair with each other, but one copy can't pair with itself.
local oneHand = def(25, { name = "Twin Blade", loc = "INVTYPE_WEAPON", c = 2, s = 7, stats = { [DPS] = 18 }, price = 50 })
CanDualWield = function() return true end
bag[1], bag[2] = { hyperlink = oneHand }, nil
fire("BAG_UPDATE_DELAYED"); flush()
tipLines, shownLink = {}, oneHand
local bagTip = function(slot) return { getterName = "GetBagItem", getterArgs = { 0, slot } } end
GameTooltip.GetProcessingTooltipInfo = function() return bagTip(1) end
want(oneHand, "only half of a replacement", "a single one-hander can't pair with itself")
bag[2] = { hyperlink = oneHand }
fire("BAG_UPDATE_DELAYED"); flush()
want(oneHand, "together with " .. oneHand, "two copies pair up")
GameTooltip.GetProcessingTooltipInfo = nil
CanDualWield = nil
bag[1], bag[2] = nil, nil
-- A partner too high level doesn't count.
local futureShield = def(26, { name = "Future Shield", loc = "INVTYPE_SHIELD", c = 4, s = 6, stats = { ITEM_MOD_ARMOR_SHORT = 1000 }, price = 50 })
local realInfo = C_Item.GetItemInfo
C_Item.GetItemInfo = function(link)
    if link == futureShield then return "Future Shield", link, 1, 10, 45, "", "", 1, "INVTYPE_SHIELD", 0, 50, 4, 6, 1 end
    return realInfo(link)
end
bag[1], bag[2] = { hyperlink = mainAxe }, { hyperlink = futureShield }
fire("BAG_UPDATE_DELAYED"); flush()
want(mainAxe, "only half of a replacement", "level-45 shield is no partner at 30")
C_Item.GetItemInfo = realInfo
bag[1], bag[2] = nil, nil
equipped[16] = nil
fire("BAG_UPDATE_DELAYED"); flush()

-- 6. Bag scans for the side panel are spread over frames, 12 slots at a time.
numSlots = 40
for slot = 1, 40 do bag[slot] = { hyperlink = def(100 + slot, { name = "Junk " .. slot, c = 15, q = 0, price = 7 }) } end
fire("BAG_UPDATE_DELAYED")
flush()
slotReads = 0
local rows = ForeverHubStatus.ItemAdvisor()
assert(slotReads <= 12, "first frame reads at most 12 slots, read " .. slotReads)
assert(#timers >= 1, "the rest waits for later frames")
local runs = flush()
assert(runs >= 3, "40 slots take several frames, took " .. runs)
rows = ForeverHubStatus.ItemAdvisor()
local found = false
for _, row in ipairs(rows or {}) do if row.text:find("Sell|r 40 item(s) for 2s 80c", 1, true) then found = true end end
assert(found, "status row after the spread scan")
-- Nothing changed: the next ask reuses the result and starts nothing.
slotReads = 0
ForeverHubStatus.ItemAdvisor()
assert(slotReads == 0 and #timers == 0, "unchanged bags aren't scanned again")
-- A bag change mid-scan restarts it, and the answer is still complete.
fire("BAG_UPDATE_DELAYED"); flush()
ForeverHubStatus.ItemAdvisor()
bag[40] = nil
fire("BAG_UPDATE_DELAYED")
flush()
rows = ForeverHubStatus.ItemAdvisor()
found = false
for _, row in ipairs(rows or {}) do if row.text:find("Sell|r 39 item(s)", 1, true) then found = true end end
assert(found, "restarted scan sees the change")
-- The vendor reminder waits for the spread scan.
toasts = {}
fire("MERCHANT_SHOW")
flush()
assert(table.concat(toasts, "\n"):find("Sell 39 item(s)", 1, true), "vendor reminder: " .. table.concat(toasts, "\n"))
for slot = 1, 40 do bag[slot] = nil end
numSlots = 16
fire("BAG_UPDATE_DELAYED"); flush()

-- 7. An item that never loads is retried a few times, then left alone.
loadRequests = 0
local ghost = "|Hitem:999:|h[Ghost]|h"
bag[1] = { hyperlink = ghost }
fire("BAG_UPDATE_DELAYED")
flush()
-- The hub asks every second; each ask after a retry scans again.
local retryTimers = 0
for _ = 1, 8 do
    ForeverHubStatus.ItemAdvisor()
    for _, t in ipairs(timers) do if t.delay == 2 then retryTimers = retryTimers + 1 end end
    flush(200)
end
assert(loadRequests >= 2, "asked again on retry: " .. loadRequests)
assert(retryTimers >= 1 and retryTimers <= 3, "retries are bounded: " .. retryTimers)
want(ghost, "CHECK: Item data is still loading", "unloaded item")
-- Once an item arrives, retries are allowed again.
fire("GET_ITEM_INFO_RECEIVED", 999)
flush()
bag[1] = nil

assert(#handled == 0, "clean: " .. tostring(handled[1]))
print("ALL TESTS PASSED")
