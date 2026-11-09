C_Timer = { After = function() end }
local path = ADDON_PATH
local chat, lines = {}, {}
local items, equipped, stats = {}, {}, {}
local class, level = "WARRIOR", 20
local requested, frame, hook = {}, nil, nil
local known = {}
local redLines = {}

local function def(id, t)
    local link = "|Hitem:" .. id .. ":|h[" .. t.name .. "]|h"
    items[link] = t
    stats[link] = t.stats
    return link
end
DEFAULT_CHAT_FRAME = { AddMessage = function(_, t) chat[#chat + 1] = t end }
CreateFrame = function()
    frame = { RegisterEvent = function() end, SetScript = function(self, _, fn) self.fn = fn end }
    return frame
end
SlashCmdList = {}
Enum = { TooltipDataType = { Item = 0 } }
GameTooltip = { AddLine = function(_, t) lines[#lines + 1] = t end }
ItemRefTooltip = { AddLine = function(_, t) lines[#lines + 1] = t end }
local shopping = { AddLine = function() error("must ignore other tooltips") end }
local hovered
TooltipUtil = { GetDisplayedItem = function() return "n", hovered end }
TooltipDataProcessor = { AddTooltipPostCall = function(_, fn) hook = fn end }
issecretvalue = function() return false end
IsPlayerSpell = function(id) return known[id] or false end
UnitClass = function() return "x", class end
UnitName = function() return "Tester" end
GetRealmName = function() return "Realm" end
UnitLevel = function() return level end
GetInventoryItemLink = function(_, slot) return equipped[slot] end
C_Item = {
    GetItemInfo = function(link)
        local t = items[link]
        if not t or t.uncached then return nil end
        return t.name, link, t.q or 2, 10, t.min or 1, "", "", 1, t.loc, 0, t.price or 100, t.c, t.s or 0, t.b or 1
    end,
    GetItemStats = function(link) return stats[link] end,
    RequestLoadItemDataByID = function(id) requested[id] = true end,
}
C_TooltipInfo = { GetHyperlink = function(link)
    if redLines[link] then
        return { lines = { { leftColor = { r = 1, g = 1, b = 1 } }, { rightColor = { r = 1, g = 0.125, b = 0.125 } } } }
    end
    return { lines = { { leftColor = { r = 1, g = 1, b = 1 } } } }
end }
local quests = {}
C_QuestLog = {
    GetNumQuestLogEntries = function() return #quests end,
    GetInfo = function(i) return quests[i].info end,
    GetQuestObjectives = function(id) for _, q in ipairs(quests) do if q.info.questID == id then return q.objectives end end end,
}
local bag = {}
NUM_TOTAL_EQUIPPED_BAG_SLOTS = 0
C_Container = {
    GetContainerNumSlots = function() return #bag end,
    GetContainerItemInfo = function(_, i) return bag[i] end,
}

local STR, STA, INT, SPI = "ITEM_MOD_STRENGTH_SHORT", "ITEM_MOD_STAMINA_SHORT", "ITEM_MOD_INTELLECT_SHORT", "ITEM_MOD_SPIRIT_SHORT"
local DPS = "ITEM_MOD_DAMAGE_PER_SECOND_SHORT"
local function ask(link)
    hovered = link; lines = {}
    hook(GameTooltip)
    return lines[1]
end
local function want(link, text, why)
    local got = ask(link)
    assert(got and got:find(text, 1, true), why .. ": wanted '" .. text .. "', got: " .. tostring(got))
end
local function login(newClass)
    class = newClass
    frame.fn(frame, "PLAYER_LOGIN")
end
local function role(name) SlashCmdList.ITEMADVISOR("role " .. name) end

assert(loadfile(path))("ItemAdvisor", {})
frame.fn(frame, "PLAYER_LOGIN")
assert(chat[1]:find("warrior role", 1, true), "class with options is told about roles")

-- Basic gear verdicts
local helm = def(1, { name = "Helm", loc = "INVTYPE_HEAD", c = 4, s = 3, stats = { [STR] = 5 } })
local betterHelm = def(2, { name = "Better", loc = "INVTYPE_HEAD", c = 4, s = 3, stats = { [STR] = 10 } })
local worseHelm = def(3, { name = "Worse", loc = "INVTYPE_HEAD", c = 4, s = 3, price = 250, stats = { [STR] = 1 } })
equipped[1] = helm
want(helm, "EQUIPPED", "wearing it")
want(betterHelm, "EQUIP: Upgrade for warrior (+11, 100%)", "stat upgrade with percent")
want(worseHelm, "vendor for 0g 2s 50c", "downgrade")
local boe = def(4, { name = "BoE", loc = "INVTYPE_HEAD", c = 4, s = 3, b = 2, stats = { [STR] = 1 } })
want(boe, "Auction if unbound, or vendor", "bind on equip green")
want(def(5, { name = "White", q = 1, loc = "INVTYPE_HEAD", c = 4, s = 3, b = 2, stats = { [STR] = 1 } }), "SELL:", "white not worth auction")
want(def(6, { name = "Later", min = 25, loc = "INVTYPE_HEAD", c = 4, s = 3, stats = { [STR] = 20 } }), "KEEP: Upgrade at level 25", "level locked")
local plate = def(7, { name = "Plate", loc = "INVTYPE_HEAD", c = 4, s = 4, stats = { [STR] = 20 } })
want(plate, "KEEP: Upgrade at level 40", "plate before 40")
level = 40; want(plate, "EQUIP:", "plate at 40"); level = 20

-- Close calls
local close = def(8, { name = "Close", loc = "INVTYPE_HEAD", c = 4, s = 3, stats = { [STR] = 5, ITEM_MOD_AGILITY_SHORT = 0.5 } })
stats[helm] = { [STR] = 50 }
stats[close] = { [STR] = 50, ITEM_MOD_AGILITY_SHORT = 1 }
want(close, "EQUIP: Upgrade for warrior (better or equal in every stat)", "tiny gain with nothing lost is still an upgrade")
stats[close] = { [STR] = 50, ITEM_MOD_AGILITY_SHORT = 2, ITEM_MOD_SPIRIT_SHORT = 0 }
stats[helm] = { [STR] = 50, ITEM_MOD_STAMINA_SHORT = 1 }
want(close, "CHECK: Close call", "gain under 3% with a trade-off")
stats[helm] = { [STR] = 5 }

-- Empty slot
local belt = def(9, { name = "Belt", loc = "INVTYPE_WAIST", c = 4, s = 3, stats = { [STR] = 1 } })
want(belt, "EQUIP: Upgrade for warrior (fills an empty slot)", "empty slot")

-- Non-gear
want(def(10, { name = "Junk", q = 0, c = 15, price = 75 }), "SELL: Junk, vendor for 0g 0s 75c", "gray")
want(def(11, { name = "Junk2", q = 0, c = 15, price = 0 }), "KEEP: Junk with no vendor", "gray unsellable")
want(def(12, { name = "Quest", c = 12 }), "KEEP: Quest item", "quest class")
want(def(13, { name = "Bound", c = 15, b = 4 }), "KEEP: Quest item", "quest bind")
want(def(14, { name = "Potion", c = 0, min = 15 }), "KEEP: Consumable", "current consumable")
want(def(15, { name = "Old", c = 0, min = 2 }), "CHECK: Outgrown consumable", "outgrown consumable")
want(def(16, { name = "Ore", c = 7 }), "KEEP: Crafting material", "trade good")
want(def(17, { name = "Odd", c = 15 }), "CHECK: No rule", "unknown item")

-- Quest log protection
local meat = def(18, { name = "Stringy Meat", q = 0, c = 15, price = 5 })
quests = { { info = { title = "Wolf Hunt", questID = 77, isHeader = false }, objectives = { { type = "item", text = "3/8 Stringy Meat" } } },
    { info = { title = "Header", isHeader = true }, objectives = {} } }
frame.fn(frame, "QUEST_LOG_UPDATE")
want(meat, "KEEP: Needed for Wolf Hunt", "gray quest objective protected")
quests = {}
frame.fn(frame, "QUEST_LOG_UPDATE")
want(meat, "SELL:", "quest finished, junk again")

-- Stat key handling
local unknown = def(20, { name = "Odd stat", loc = "INVTYPE_HEAD", c = 4, s = 3, stats = { ITEM_MOD_NEW_STAT = 9 } })
want(unknown, "CHECK: Has stats I can't score", "unknown stat not sold")
want(def(21, { name = "Fire res", loc = "INVTYPE_HEAD", c = 4, s = 3, stats = { RESISTANCE2_NAME = 9 } }), "SELL:", "known-ignored stat not flagged")
want(def(22, { name = "Untyped", loc = "INVTYPE_HEAD", c = 4, s = 3, stats = { ITEM_MOD_HIT_SHORT = 1 } }), "CHECK: Has stats", "untyped hit has unclear units")
stats[betterHelm] = { [STR] = 10, ITEM_MOD_STRENGTH = 10 }
want(betterHelm, "(+11, 100%)", "aliases counted once")
stats[betterHelm] = { ITEM_MOD_STRENGTH = 10 }
want(betterHelm, "(+11, 100%)", "unsuffixed key recognized")
stats[betterHelm] = { [STR] = 10 }
want(def(23, { name = "Loading", uncached = true, loc = "INVTYPE_HEAD", c = 4 }), "CHECK: Item data is still loading", "uncached")
assert(requested[23], "requested uncached")
local cold = def(24, { name = "Cold", loc = "INVTYPE_HEAD", c = 4, s = 3, stats = {} })
-- Changed for the stat-less fix: a loaded item with no stats scores 0 and is never sold.
want(cold, "CHECK: No stats to score", "empty stats")
items[helm].uncached = true
want(betterHelm, "CHECK: Can't read the stats", "uncached equipped not a zero baseline")
items[helm].uncached = nil
local oddHelm = def(25, { name = "OddHelm", loc = "INVTYPE_HEAD", c = 4, s = 3, stats = { ITEM_MOD_NEW_STAT = 50, [STR] = 1 } })
equipped[1] = oddHelm
want(betterHelm, "CHECK: Looks better, but your current item", "unreadable equipped")
equipped[1] = helm

-- Equipment set
local setHelm = def(26, { name = "SetHelm", loc = "INVTYPE_HEAD", c = 4, s = 3, price = 500, stats = { [STR] = 1 } })
C_EquipmentSet = { GetEquipmentSetIDs = function() return { 7 } end, GetItemIDs = function() return { [1] = 26 } end }
want(setHelm, "KEEP: In one of your equipment sets", "set protected")
C_EquipmentSet = nil
want(setHelm, "SELL:", "works without equipment set API")

-- Red line
local axe2 = def(30, { name = "2H Axe", loc = "INVTYPE_2HWEAPON", c = 2, s = 1, stats = { [DPS] = 10 } })
redLines[axe2] = true
want(axe2, "CHECK: Looks better, but the game says", "red tooltip line")
redLines[axe2] = nil
C_TooltipInfo = nil
want(axe2, "EQUIP:", "works without tooltip API")
C_TooltipInfo = { GetHyperlink = function() return { lines = {} } end }

-- Rings
local ringA = def(31, { name = "RingA", loc = "INVTYPE_FINGER", c = 4, stats = { [STR] = 8 } })
local ringB = def(32, { name = "RingB", loc = "INVTYPE_FINGER", c = 4, stats = { [STR] = 2 } })
local ringC = def(33, { name = "RingC", loc = "INVTYPE_FINGER", c = 4, stats = { [STR] = 4 } })
equipped[11], equipped[12] = ringA, ringB
want(ringC, "(+4, 100%)", "beats weakest ring")

-- Weapons and hands
local oneH = def(34, { name = "1H", loc = "INVTYPE_WEAPON", c = 2, s = 7, stats = { [DPS] = 5 } })
local bigOneH = def(35, { name = "Big1H", loc = "INVTYPE_WEAPON", c = 2, s = 7, stats = { [DPS] = 6 } })
local shield = def(36, { name = "Shield", loc = "INVTYPE_SHIELD", c = 4, s = 6, stats = { [STA] = 2 } })
local offWeapon = def(37, { name = "Off", loc = "INVTYPE_WEAPONOFFHAND", c = 2, s = 7, stats = { [DPS] = 3 } })
equipped[16] = axe2
-- Changed for the half-pair fix: never sell half of a possible replacement for a two-hander.
want(shield, "CHECK: You wear a two-hander", "shield not free with two-hander")
want(offWeapon, "CHECK: You can't dual wield yet", "a warrior may learn it, so don't say sell")
CanDualWield = function() return true end
equipped[16] = nil
want(offWeapon, "EQUIP", "the game's own check beats the spell ID")
equipped[16] = axe2
CanDualWield = nil
equipped[16], equipped[17] = oneH, shield
stats[axe2] = { [DPS] = 10 }
want(axe2, "EQUIP: Upgrade for warrior (+91, 93%)", "two-hander counts both hands: 190 - 95 - 3.2")
known[674] = true
equipped[16], equipped[17] = bigOneH, oneH
want(oneH, "EQUIPPED", "weapon in the off hand shows as equipped")
equipped[16], equipped[17] = bigOneH, nil
want(oneH, "EQUIP: Upgrade for warrior (fills an empty slot)", "dual wielder can fill off hand")
equipped[17] = def(38, { name = "Weak off", loc = "INVTYPE_WEAPON", c = 2, s = 7, stats = { [DPS] = 1 } })
want(oneH, "(+38, 400%)", "off-hand comparison at half DPS: 47.5 - 9.5")
known[674] = false
equipped[16], equipped[17] = nil, nil

-- Disenchant
known[13262] = true
want(worseHelm, "Disenchant, or vendor", "disenchant bound green")
want(boe, "Auction if unbound, disenchant, or vendor", "auction bind on equip first")
known[13262] = false

-- Class use table
login("MAGE")
want(plate, "can't wear this", "mage plate")
want(def(40, { name = "Leather", loc = "INVTYPE_HEAD", c = 4, s = 2, stats = { [INT] = 90 } }), "can't wear this", "mage leather")
want(def(41, { name = "Cape", loc = "INVTYPE_CLOAK", c = 4, s = 1, stats = { [INT] = 3 } }), "EQUIP:", "cloak fine")
want(axe2, "can't wear this", "mage two-hand axe")
want(shield, "can't wear this", "mage shield")
local wand = def(42, { name = "Wand", loc = "INVTYPE_RANGEDRIGHT", c = 2, s = 19, stats = { [DPS] = 10 } })
want(wand, "EQUIP: Upgrade for mage (fills an empty slot)", "mage wand")
equipped[18] = def(43, { name = "OldWand", loc = "INVTYPE_RANGEDRIGHT", c = 2, s = 19, stats = { [DPS] = 5 } })
want(wand, "(+15, 100%)", "casters score wand by damage at 3 per DPS")
equipped[18] = nil

-- Healing bonus converts to spell damage for damage dealers, full value for healers
local healChest = def(44, { name = "Heal", loc = "INVTYPE_CHEST", c = 4, s = 1, stats = { ITEM_MOD_SPELL_HEALING_DONE_SHORT = 30 } })
want(healChest, "fills an empty slot", "mage still scores healing gear")
equipped[5] = def(45, { name = "Dmg", loc = "INVTYPE_CHEST", c = 4, s = 1, stats = { ITEM_MOD_SPELL_DAMAGE_DONE_SHORT = 8 } })
want(healChest, "(+2, 25%)", "a third of 30 healing is 10 damage, beating 8")
equipped[5] = nil

login("PRIEST")
role("shadow")
equipped[5] = def(46, { name = "Int", loc = "INVTYPE_CHEST", c = 4, s = 1, stats = { [INT] = 10 } })
want(def(47, { name = "Spi", loc = "INVTYPE_CHEST", c = 4, s = 1, stats = { [SPI] = 10 } }), "EQUIP: Upgrade for shadow", "shadow prefers Spirit over Intellect")
role("healer")
equipped[5] = def(48, { name = "DmgChest", loc = "INVTYPE_CHEST", c = 4, s = 1, stats = { ITEM_MOD_SPELL_DAMAGE_DONE_SHORT = 20 } })
want(healChest, "EQUIP: Upgrade for healer", "healers score healing, not damage")
equipped[5] = nil
role("rogue")
assert(chat[#chat]:find("Choose: shadow, healer", 1, true), "profile for another class refused")

login("HUNTER")
local bow = def(50, { name = "Bow", loc = "INVTYPE_RANGED", c = 2, s = 2, stats = { [DPS] = 30 } })
want(bow, "fills an empty slot", "hunter bow")
equipped[18] = def(51, { name = "OldBow", loc = "INVTYPE_RANGED", c = 2, s = 2, stats = { [DPS] = 10 } })
want(bow, "(+180, 200%)", "hunter ranged DPS at 9")
equipped[18] = nil
equipped[16] = def(52, { name = "StatStick", loc = "INVTYPE_WEAPON", c = 2, s = 7, stats = { ["ITEM_MOD_AGILITY_SHORT"] = 5 } })
want(def(53, { name = "BigDps", loc = "INVTYPE_WEAPON", c = 2, s = 7, stats = { [DPS] = 50 } }), "CHECK: Close call", "hunter melee: never sell, show the trade-off")
role("survival")
want(def(54, { name = "BigDps2", loc = "INVTYPE_WEAPON", c = 2, s = 7, stats = { [DPS] = 50 } }), "EQUIP:", "survival scores melee DPS")
equipped[16] = nil
want(def(55, { name = "Polearm", min = 1, loc = "INVTYPE_2HWEAPON", c = 2, s = 6, stats = { [DPS] = 5 } }), "EQUIP", "polearm at level 20")
level = 15
want(def(56, { name = "Polearm2", min = 1, loc = "INVTYPE_2HWEAPON", c = 2, s = 6, stats = { [DPS] = 5 } }), "KEEP: Upgrade at level 20", "polearm unlocks at 20")
level = 20

want(def(60, { name = "HunterAxe", loc = "INVTYPE_2HWEAPON", c = 2, s = 1, stats = { [DPS] = 5 } }), "EQUIP", "hunters can use two-handed axes")

login("DRUID")
local staff = def(57, { name = "StaffDps", loc = "INVTYPE_2HWEAPON", c = 2, s = 10, stats = { [DPS] = 40 } })
want(staff, "EQUIP: Upgrade for feral (fills an empty slot)", "an empty slot is always worth filling")
equipped[16] = def(59, { name = "FeralStick", loc = "INVTYPE_2HWEAPON", c = 2, s = 10, stats = { ["ITEM_MOD_AGILITY_SHORT"] = 2 } })
want(staff, "CHECK: Close call", "feral: never sell, show the trade-off")
equipped[16] = nil
want(bow, "can't wear this", "druid bow")

login("WARRIOR")
role("warrior")
equipped[18] = def(58, { name = "Crossbow", loc = "INVTYPE_RANGED", c = 2, s = 18, stats = { [STA] = 1 } })
want(bow, "CHECK: Close call", "warrior ranged: trade-off shown")
equipped[18] = nil

-- Tooltip scope
lines = {}
hook(shopping)
assert(#lines == 0, "ignores comparison tooltips")

-- Bag scan
equipped[1] = helm
bag = {
    { hyperlink = betterHelm, stackCount = 1 },
    { hyperlink = worseHelm, stackCount = 3 },
    { hyperlink = boe, stackCount = 1, isBound = false },
    { hyperlink = unknown, stackCount = 1 },
}
chat = {}
DEFAULT_CHAT_FRAME = { AddMessage = function(_, t) chat[#chat + 1] = t end }
SlashCmdList.ITEMADVISOR("")
assert(chat[#chat]:find("1 to equip, 1 to sell (0g 7s 50c), 1 to auction, 0 to disenchant, 1 to check, 0 to keep.", 1, true), chat[#chat])
bag = { { hyperlink = boe, stackCount = 1, isBound = true } }
chat = {}
SlashCmdList.ITEMADVISOR("")
assert(chat[1]:find("SELL", 1, true), "bound bind-on-equip items can't be auctioned: " .. chat[1])
known[13262] = true
chat = {}
SlashCmdList.ITEMADVISOR("")
assert(chat[1]:find("DISENCHANT", 1, true), "bound green with enchanting: " .. chat[1])
known[13262] = false

-- Regressions found by the accuracy pass
bag = {}
local tips = {}
C_TooltipInfo = { GetHyperlink = function(link)
    local out = { { leftText = "Name" } }
    for _, text in ipairs(tips[link] or {}) do out[#out + 1] = { leftText = text } end
    return { lines = out }
end }
local function tipItem(id, name, tip, itemStats, loc)
    local link = def(id, { name = name, loc = loc or "INVTYPE_FEET", c = 4, s = 1, stats = itemStats or {} })
    tips[link] = tip
    return link
end
login("WARRIOR"); role("warrior"); level = 60
equipped[8] = def(70, { name = "Base boots", loc = "INVTYPE_FEET", c = 4, s = 1, stats = { [STR] = 10 } })
-- 1% crit at level 60 = 14 rating x weight 3 = 42 points, against 22 for the boots.
want(tipItem(71, "Crit boots", { "+1% Critical Strike Chance" }), "(+20, 90%)", "tooltip crit percent converted to rating")
want(tipItem(72, "Crit boots2", { "Equip: Improves your chance to get a critical strike by 1%." }), "(+20, 90%)", "sentence form")
want(tipItem(73, "Hit boots", { "Equip: Improves your chance to hit by 2%." }), "(+18, 81%)", "2% hit = 20 rating x 2 = 40")
want(tipItem(74, "API too", { "+1% Critical Strike Chance" }, { ITEM_MOD_CRIT_RATING_SHORT = 14 }), "(+20, 90%)", "tooltip percent not added to API rating")
want(tipItem(75, "API only", {}, { ITEM_MOD_CRIT_RATING_SHORT = 14 }), "(+20, 90%)", "game's rating scored directly")
want(tipItem(90, "Real wording", { "+0.5% Hit Chance" }, { [STR] = 8 }), "(+5, 25%)", "live wording: 0.5% hit = 5 rating x 2 = 10, plus 17.6 from Strength, against 22")
want(tipItem(91, "Ring", { "+0.4% Hit Chance" }, { ITEM_MOD_HIT_RATING_SHORT = 4 }, "INVTYPE_FINGER"), "EQUIP", "Pyrewood case: 4 rating is not 4%")
local oldKnown = C_SpellBook
C_SpellBook = { IsSpellKnown = function(id) return id == 13262 end }
want(worseHelm, "DISENCHANT", "modern spell check works without IsPlayerSpell")
C_SpellBook = oldKnown
GetProfessions = function() return 3 end
GetProfessionInfo = function() return "Enchanting", 0, 1, 300, 1, 0, 333 end
want(worseHelm, "DISENCHANT", "Enchanting skill counts if the spell isn't listed")
GetProfessionInfo = function() return "Mining", 0, 1, 300, 1, 0, 186 end
want(worseHelm, "SELL", "other professions don't")
GetProfessions, GetProfessionInfo = nil, nil
want(tipItem(76, "Proc", { "Equip: 5% chance on melee hit to gain 20 attack power." }, { [STR] = 1 }), "SELL:", "proc text is not a hit stat")
want(tipItem(77, "CritDmg", { "+3% Critical Strike Damage" }, { [STR] = 1 }), "SELL:", "crit damage is not crit chance")
want(tipItem(78, "Use", { "Use: Increases your critical strike chance by 5% for 10 sec." }, { [STR] = 1 }), "SELL:", "on-use effect not counted")
want(tipItem(79, "SpellCrit", { "Equip: Improves your chance to get a critical strike with spells by 1%." }, { [STR] = 1 }), "SELL:", "spell crit is no use to a warrior")
level = 20
-- Same 1% crit at level 20 is scaled to a third: 14 points.
want(tipItem(80, "Low crit", { "+1% Critical Strike Chance" }, { [STR] = 10 }), "(+14,", "percent stats scale with level")
equipped[8] = nil
want(tipItem(81, "Fire boots", {}, { ITEM_MOD_FIRE_RESISTANCE_SHORT = 5, [STR] = 1 }), "EQUIP", "resistance key is not an unknown stat")
equipped[8] = def(82, { name = "Fire base", loc = "INVTYPE_FEET", c = 4, s = 1, stats = { [STR] = 5 } })
want(tipItem(83, "Fire worse", {}, { ITEM_MOD_FIRE_RESISTANCE_SHORT = 5, [STR] = 1 }), "SELL:", "resistance doesn't force CHECK")
equipped[8] = nil

-- Gray gear
local grayChest = def(84, { name = "Gray", q = 0, loc = "INVTYPE_CHEST", c = 4, s = 1, stats = { RESISTANCE0_NAME = 20 } })
want(grayChest, "EQUIP:", "gray gear can fill an empty slot")
equipped[5] = grayChest
want(grayChest, "EQUIPPED", "gray gear you're wearing isn't junk")
equipped[5] = def(85, { name = "Better", loc = "INVTYPE_CHEST", c = 4, s = 1, stats = { RESISTANCE0_NAME = 90 } })
want(grayChest, "SELL:", "outclassed gray gear is sold")
equipped[5] = nil

-- A spare copy in your bags isn't the one you're wearing
local dupe = def(86, { name = "Dupe", loc = "INVTYPE_FINGER", c = 4, stats = { [STR] = 5 } })
equipped[11], equipped[12] = dupe, nil
want(dupe, "EQUIPPED", "hovering the worn one")
bag = { { hyperlink = dupe, stackCount = 1 } }
chat = {}
SlashCmdList.ITEMADVISOR("")
assert(chat[#chat]:find("1 to equip", 1, true), "spare copy can fill the other ring slot: " .. chat[#chat])
bag = {}
equipped[11], equipped[12] = nil, nil

-- Spell power isn't added to its own aliases
login("MAGE")
equipped[5] = def(87, { name = "Base", loc = "INVTYPE_CHEST", c = 4, s = 1, stats = { ITEM_MOD_SPELL_DAMAGE_DONE_SHORT = 10 } })
want(def(88, { name = "Both", loc = "INVTYPE_CHEST", c = 4, s = 1, stats = { ITEM_MOD_SPELL_POWER_SHORT = 20, ITEM_MOD_SPELL_DAMAGE_DONE_SHORT = 20 } }),
    "(+10, 100%)", "20 spell power reported twice is still 20")
equipped[5] = nil
login("PALADIN")
want(def(89, { name = "PalOff", loc = "INVTYPE_WEAPONOFFHAND", c = 2, s = 7, stats = { [DPS] = 3 } }), "Your class can't dual wield", "paladins never dual wield")
login("WARRIOR"); role("warrior")
tips = {}
C_TooltipInfo = { GetHyperlink = function() return { lines = {} } end }

-- Small real upgrades, as reported on the live client
login("MAGE")
level = 5
C_TooltipInfo = { GetHyperlink = function() return { lines = {} } end }
local ARMOR = "RESISTANCE0_NAME"
equipped[7] = def(100, { name = "OldPants", loc = "INVTYPE_LEGS", c = 4, s = 1, stats = { [ARMOR] = 10 } })
want(def(101, { name = "NewPants", loc = "INVTYPE_LEGS", c = 4, s = 1, stats = { [ARMOR] = 14 } }), "EQUIP: Upgrade for mage (better or equal in every stat): +4 Armor", "a little more armor is an upgrade")
want(def(102, { name = "Same", loc = "INVTYPE_LEGS", c = 4, s = 1, stats = { [ARMOR] = 10 } }), "SELL: Not an upgrade", "identical stats aren't an upgrade")
want(def(103, { name = "LessArmor", loc = "INVTYPE_LEGS", c = 4, s = 1, stats = { [ARMOR] = 8 } }), "SELL: Not an upgrade", "less armor isn't an upgrade")
equipped[7] = def(104, { name = "StamPants", loc = "INVTYPE_LEGS", c = 4, s = 1, stats = { [ARMOR] = 10 } })
want(def(105, { name = "PlusStam", loc = "INVTYPE_LEGS", c = 4, s = 1, stats = { [ARMOR] = 10, [STA] = 1 } }), "EQUIP:", "+1 Stamina with nothing lost")
equipped[7] = def(106, { name = "SpiPants", loc = "INVTYPE_LEGS", c = 4, s = 1, stats = { [ARMOR] = 10, [SPI] = 1 } })
want(def(107, { name = "StaPants", loc = "INVTYPE_LEGS", c = 4, s = 1, stats = { [ARMOR] = 10, [STA] = 1 } }), "CHECK: Close call: +1 Stamina, -1 Spirit", "small trade-off is shown, not sold")
want(def(113, { name = "ArmorNoSpi", loc = "INVTYPE_LEGS", c = 4, s = 1, stats = { [ARMOR] = 15 } }), "CHECK: Close call: +5 Armor, -1 Spirit", "armor beats nothing here but never says sell")
want(def(114, { name = "StrStuff", loc = "INVTYPE_LEGS", c = 4, s = 1, stats = { [ARMOR] = 10, [STR] = 9 } }), "SELL: Not an upgrade (-1 Spirit)", "a stat mages do not use is no gain")
equipped[7] = nil
equipped[16] = def(108, { name = "OldStaff", loc = "INVTYPE_2HWEAPON", c = 2, s = 10, stats = { [DPS] = 3 } })
want(def(109, { name = "NewStaff", loc = "INVTYPE_2HWEAPON", c = 2, s = 10, stats = { [DPS] = 5 } }), "EQUIP: Upgrade for mage (better or equal in every stat): +2 DPS", "a better staff is an upgrade")
want(def(112, { name = "StatStaff", loc = "INVTYPE_2HWEAPON", c = 2, s = 10, stats = { [DPS] = 9, [INT] = 0 } }), "EQUIP:", "more staff damage")
equipped[16] = def(110, { name = "OldDagger", loc = "INVTYPE_WEAPON", c = 2, s = 15, stats = { [DPS] = 3 } })
want(def(111, { name = "NewDagger", loc = "INVTYPE_WEAPON", c = 2, s = 15, stats = { [DPS] = 5 } }), "EQUIP:", "more weapon damage and nothing lost")
equipped[16] = nil
level = 20
login("WARRIOR"); role("warrior")

-- Raw stats diagnostics
chat = {}
SlashCmdList.ITEMADVISOR("stats " .. unknown)
assert(chat[1]:find("ITEM_MOD_NEW_STAT = 9 (unknown)", 1, true), chat[1])
chat = {}
SlashCmdList.ITEMADVISOR("stats")
assert(chat[1]:find("shift-click", 1, true), chat[1])
SlashCmdList.ITEMADVISOR("help")

print("ALL TESTS PASSED")
