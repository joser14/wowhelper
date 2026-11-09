-- ItemAdvisor review fixes: stat-less items, hit/crit scope, half of a two-hander pair, spare copies, combat badges.
local path = ADDON_PATH
local toasts, handled, timers = {}, {}, {}
local items, stats, tips, equipped = {}, {}, {}, {}
local combat = false
local class = "WARRIOR"

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
    function r:IsVisible() return self.shown end
    function r:SetPoint(_, rel) self.anchor = rawget(self, "anchor") or rel end
    function r:SetScript(s, f) self.scripts[s] = f end
    function r:HookScript(s, f) self.hooks[s] = f end
    function r:RegisterEvent() end
    local function child()
        local t = newRegion()
        local kids = rawget(r, "children") or {}
        rawset(r, "children", kids)
        kids[#kids + 1] = t
        return t
    end
    function r:CreateTexture() return child() end
    function r:CreateFontString() return child() end
    return setmetatable(r, { __index = function() return function() end end })
end
local eventFrame
local allFrames = {}
CreateFrame = function(_, name) local f = newRegion(); allFrames[#allFrames + 1] = f; if name then _G[name] = f end; return f end
SlashCmdList = {}
Enum = { TooltipDataType = { Item = 0 } }
local tipLines, procInfo = {}, nil
GameTooltip = {
    AddLine = function(_, text) tipLines[#tipLines + 1] = text end,
    GetProcessingTooltipInfo = function() return procInfo end,
}
ItemRefTooltip = {}
local shownLink
TooltipUtil = { GetDisplayedItem = function() return "n", shownLink end }
local postCall
TooltipDataProcessor = { AddTooltipPostCall = function(_, fn) postCall = fn end }
issecretvalue = function() return false end
UnitClass = function() return class, class end
UnitName = function() return "T" end
GetRealmName = function() return "R" end
UnitLevel = function() return 30 end
InCombatLockdown = function() return combat end
GetInventoryItemLink = function(_, slot) return equipped[slot] end
geterrorhandler = function() return function(e) handled[#handled + 1] = tostring(e) end end
ForeverHub_Receive = function(_, text) toasts[#toasts + 1] = text end
C_Timer = { After = function(_, fn) timers[#timers + 1] = fn end }
local function flush() while #timers > 0 do table.remove(timers, 1)() end end
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
C_QuestLog = { GetNumQuestLogEntries = function() return 0 end }
local bag = {}
C_Container = {
    GetContainerNumSlots = function() return 4 end,
    GetContainerItemInfo = function(bagID, slot) return bagID == 0 and bag[slot] or nil end,
}
NUM_TOTAL_EQUIPPED_BAG_SLOTS = 0
local buttons = {}
for slot = 1, 4 do
    local button = newRegion()
    button.bagID = 0
    button.GetID = function() return slot end
    buttons[slot] = button
end
ContainerFrameCombinedBags = newRegion()
ContainerFrameCombinedBags.Items = buttons
local function badge(slot, which)
    -- Badges live on the addon's overlay and are anchored to the bag button: arrow first, then coin.
    local found = {}
    for _, kid in ipairs(rawget(ItemAdvisorOverlay, "children") or {}) do
        if kid.anchor == buttons[slot] then found[#found + 1] = kid end
    end
    local t = found[which == "arrow" and 1 or 2]
    return t and t.shown
end

assert(loadfile(path))("ItemAdvisor", {})
local events; for _, f in ipairs(allFrames) do if f.scripts and f.scripts.OnEvent then events = f end end
local function login(newClass)
    class = newClass
    events.scripts.OnEvent(events, "PLAYER_LOGIN")
end
login("WARRIOR")

local function ask(link, info)
    tipLines, shownLink, procInfo = {}, link, info
    postCall(GameTooltip)
    return tipLines[1] or ""
end
local function want(link, text, why, info)
    local got = ask(link, info)
    assert(got:find(text, 1, true), why .. ": wanted '" .. text .. "', got: " .. got)
end
local function wantNot(link, text, why, info)
    local got = ask(link, info)
    assert(not got:find(text, 1, true), why .. ": got: " .. got)
end
local STA, INT = "ITEM_MOD_STAMINA_SHORT", "ITEM_MOD_INTELLECT_SHORT"
local DPS = "ITEM_MOD_DAMAGE_PER_SECOND_SHORT"
local function misc(id, name, loc, st, tip)
    return def(id, { name = name, loc = loc, c = 4, s = 0, stats = st, tip = tip, price = 100 })
end

-- 1. Worn stat-less trinkets (insignia, on-use) score 0 instead of blocking every comparison.
equipped[13] = misc(1, "Insignia", "INVTYPE_TRINKET", {}, { "Use: Removes all movement impairing effects." })
equipped[14] = misc(2, "Onuse", "INVTYPE_TRINKET", {}, { "Use: Increases attack power by 100 for 20 sec." })
local staTrinket = misc(3, "Sta Trinket", "INVTYPE_TRINKET", { [STA] = 5 })
want(staTrinket, "EQUIP: Upgrade for warrior", "stat trinket beats stat-less worn ones")
-- A stat-less item is never sold on score alone: its value is its effect.
want(misc(4, "Other Onuse", "INVTYPE_TRINKET", {}, { "Use: Heals you." }), "CHECK: No stats to score", "stat-less vs stat-less")
equipped[14] = staTrinket
equipped[13] = misc(5, "Sta Trinket 2", "INVTYPE_TRINKET", { [STA] = 6 })
local got = ask(misc(6, "Third Onuse", "INVTYPE_TRINKET", {}, { "Use: Heals you." }))
assert(got:find("CHECK: No stats to score", 1, true), "stat-less vs stat trinkets isn't sold: " .. got)
equipped[13], equipped[14] = nil, nil

-- 2. Unqualified vanilla wording is physical; spell rating keys only count for casters.
equipped[11] = misc(10, "Int Ring A", "INVTYPE_FINGER", { [INT] = 1 })
equipped[12] = misc(11, "Int Ring B", "INVTYPE_FINGER", { [INT] = 1 })
local hitRing = misc(12, "Hit Ring", "INVTYPE_FINGER", {}, { "Equip: Improves your chance to hit by 1%." })
local critRing = misc(13, "Crit Ring", "INVTYPE_FINGER", {}, { "Equip: Improves your chance to get a critical strike by 1%." })
local spellHitRing = misc(14, "Spell Hit Ring", "INVTYPE_FINGER", { ITEM_MOD_HIT_SPELL_RATING_SHORT = 20 })
local spellCritRing = misc(15, "Spell Crit Ring", "INVTYPE_FINGER", { ITEM_MOD_SPELL_CRIT_RATING = 20 })
local meleeHitRing = misc(16, "Melee Hit Ring", "INVTYPE_FINGER", { ITEM_MOD_HIT_MELEE_RATING_SHORT = 20 })
local bothRing = misc(17, "Both Ring", "INVTYPE_FINGER", {}, { "Equip: Improves your chance to hit with spells and attacks by 1%." })
want(hitRing, "EQUIP:", "warrior: plain hit counts")
want(critRing, "EQUIP:", "warrior: plain crit counts")
want(meleeHitRing, "EQUIP:", "warrior: melee hit rating counts")
want(spellHitRing, "SELL: Not an upgrade", "warrior: spell hit rating doesn't count")
want(spellCritRing, "SELL: Not an upgrade", "warrior: spell crit rating doesn't count")
want(bothRing, "EQUIP:", "warrior: spells and attacks counts")
toasts = {}
SlashCmdList.ITEMADVISOR("stats " .. hitRing)
assert(table.concat(toasts, "\n"):find("1% hit (attack)", 1, true), "plain hit is physical: " .. table.concat(toasts, "\n"))
login("MAGE")
want(hitRing, "SELL: Not an upgrade", "mage: plain hit is physical")
want(critRing, "SELL: Not an upgrade", "mage: plain crit is physical")
want(meleeHitRing, "SELL: Not an upgrade", "mage: melee hit rating doesn't count")
want(spellHitRing, "EQUIP:", "mage: spell hit rating counts")
want(spellCritRing, "EQUIP:", "mage: spell crit rating counts")
want(bothRing, "EQUIP:", "mage: spells and attacks counts")
login("WARRIOR")
equipped[11], equipped[12] = nil, nil

-- 3. Half of a pair against a worn two-hander is a check, never a sell.
local twoHander = def(20, { name = "Big Axe", loc = "INVTYPE_2HWEAPON", c = 2, s = 1, stats = { [DPS] = 20 } })
equipped[16] = twoHander
local smallAxe = def(21, { name = "Small Axe", loc = "INVTYPE_WEAPON", c = 2, s = 0, stats = { [DPS] = 3 }, price = 50 })
local mainAxe = def(22, { name = "Main Axe", loc = "INVTYPE_WEAPONMAINHAND", c = 2, s = 0, stats = { [DPS] = 3 }, price = 50 })
local shield = def(23, { name = "Shield", loc = "INVTYPE_SHIELD", c = 4, s = 6, stats = { ITEM_MOD_ARMOR_SHORT = 5 }, price = 50 })
for _, link in ipairs({ smallAxe, mainAxe, shield }) do
    want(link, "CHECK: You wear a two-hander", "half of a pair")
end
CanDualWield = function() return true end
want(def(24, { name = "Off Axe", loc = "INVTYPE_WEAPONOFFHAND", c = 2, s = 0, stats = { [DPS] = 3 }, price = 50 }), "CHECK: You wear a two-hander", "off-hand weapon")
CanDualWield = nil
-- A one-hander that beats the whole two-hander on its own is still an upgrade.
want(def(25, { name = "Huge Axe", loc = "INVTYPE_WEAPON", c = 2, s = 0, stats = { [DPS] = 40 } }), "EQUIP:", "one-hander beating the two-hander")
-- Two-hander vs two-hander is unchanged.
want(def(26, { name = "Worse Axe", loc = "INVTYPE_2HWEAPON", c = 2, s = 1, stats = { [DPS] = 5 }, price = 50 }), "SELL: Not an upgrade", "2H vs 2H still sells")
bag[1] = { hyperlink = smallAxe }
events.scripts.OnEvent(events, "BAG_UPDATE_DELAYED")
flush()
assert(not badge(1, "coin"), "no coin on half of a pair")
bag[1] = nil
equipped[16] = nil

-- 4. Spare copies: the tooltip uses the bag slot, and a unique item you wear is never an equip.
local robe = misc(30, "Robe", "INVTYPE_CHEST", { [STA] = 5 })
equipped[5] = robe
bag[2] = { hyperlink = robe, isBound = true }
want(robe, "EQUIPPED: You're wearing this", "no context: the worn one")
want(robe, "EQUIPPED", "character frame", { getterName = "GetInventoryItem", getterArgs = { "player", 5 } })
want(robe, "SELL: Not an upgrade", "bag copy of a worn robe", { getterName = "GetBagItem", getterArgs = { 0, 2 } })
-- A slot that no longer holds the item falls back to the plain check.
want(robe, "EQUIPPED", "stale bag slot", { getterName = "GetBagItem", getterArgs = { 0, 3 } })
events.scripts.OnEvent(events, "BAG_UPDATE_DELAYED")
flush()
assert(badge(2, "coin"), "badge agrees with the tooltip")
local unique = misc(31, "Unique Band", "INVTYPE_FINGER", { [STA] = 8 }, { "Unique-Equipped" })
local plain = misc(32, "Plain Band", "INVTYPE_FINGER", { [STA] = 8 })
equipped[11] = unique
equipped[12] = misc(33, "Weak Band", "INVTYPE_FINGER", { [STA] = 1 })
bag[3] = { hyperlink = unique }
local uniqueInfo = { getterName = "GetBagItem", getterArgs = { 0, 3 } }
want(unique, "Spare copy; it's unique", "unique spare isn't an equip", uniqueInfo)
wantNot(unique, "EQUIP:", "unique spare isn't an equip", uniqueInfo)
equipped[11] = plain
bag[3] = { hyperlink = plain }
want(plain, "EQUIP:", "a non-unique spare can fill the other ring slot", uniqueInfo)
equipped[11] = unique
bag[3] = { hyperlink = unique }
events.scripts.OnEvent(events, "BAG_UPDATE_DELAYED")
flush()
assert(not badge(3, "arrow"), "no arrow on a unique spare")
local uniqueTrinket = misc(34, "Unique Charm", "INVTYPE_TRINKET", { [STA] = 8 }, { "Unique" })
equipped[13] = uniqueTrinket
wantNot(uniqueTrinket, "EQUIP:", "unique trinket spare", { getterName = "GetBagItem", getterArgs = { 0, 4 } })
bag[4] = { hyperlink = uniqueTrinket }
want(uniqueTrinket, "Spare copy", "unique trinket spare", { getterName = "GetBagItem", getterArgs = { 0, 4 } })
for slot = 1, 4 do bag[slot] = nil end
for slot in pairs(equipped) do equipped[slot] = nil end

-- 5. Badges hide when combat starts and come back after.
local upgrade = misc(40, "Upgrade Neck", "INVTYPE_NECK", { [STA] = 5 })
bag[1] = { hyperlink = upgrade }
events.scripts.OnEvent(events, "BAG_UPDATE_DELAYED")
flush()
assert(badge(1, "arrow"), "arrow before combat")
combat = true
events.scripts.OnEvent(events, "PLAYER_REGEN_DISABLED")
assert(not badge(1, "arrow"), "arrow hidden as combat starts")
-- The item moves during combat; nothing points at the old slot.
bag[1], bag[2] = nil, { hyperlink = upgrade }
events.scripts.OnEvent(events, "BAG_UPDATE_DELAYED")
flush()
assert(not badge(1, "arrow") and not badge(2, "arrow"), "nothing painted in combat")
combat = false
events.scripts.OnEvent(events, "PLAYER_REGEN_ENABLED")
flush()
assert(badge(2, "arrow") and not badge(1, "arrow"), "repainted on the new slot after combat")

assert(#handled == 0, "clean: " .. tostring(handled[1]))
print("ALL TESTS PASSED")
