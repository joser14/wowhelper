-- Round 6 #12 and #14, the ItemAdvisor and ProfessionGuide side:
-- * ItemAdvisor_Judge(itemID) judges an item you don't own (a quest reward, a craft) against what you wear;
-- * the Bag advice page lists LevelGuide's "Upgrades ahead on your leveling route";
-- * ProfessionGuide's craft page lists "Upgrades you can make" from the recipes you know (else the guide's
--   steps up to your skill), with the materials you're missing. Read-only: nothing is crafted or equipped.
-- Run from the tests folder:  node run.js "<repo root>" test_r6_ahead_craft.lua
local M = dofile(ADDON_PATH .. "/tests/r4a_ia_mock.lua")
local forbidden = {}
local say = print
for _, name in ipairs({ "hooksecurefunc", "print", "DoTradeSkill", "EquipItemByName", "PickupContainerItem" }) do
    _G[name] = function() forbidden[#forbidden + 1] = name end
end

-- Items by ID as well as by link (ItemAdvisor_Judge asks with "item:<id>").
local byID = {}
local function def(id, t)
    local link = M.def(id, t)
    byID["item:" .. id], byID[id] = link, link
    return link
end
local getInfo, getStats, getTip = C_Item.GetItemInfo, C_Item.GetItemStats, C_TooltipInfo.GetHyperlink
C_Item.GetItemInfo = function(x) return getInfo(byID[x] or x) end
C_Item.GetItemStats = function(x) return getStats(byID[x] or x) end
C_TooltipInfo.GetHyperlink = function(x) return getTip(byID[x] or x) end
local bags = {}
C_Item.GetItemCount = function(id) return bags[id] or 0 end

M.level = 11
M.load("PRIEST")
local INT, STA, STR = "ITEM_MOD_INTELLECT_SHORT", "ITEM_MOD_STAMINA_SHORT", "ITEM_MOD_STRENGTH_SHORT"
M.equipped[5] = def(1, { name = "Old Robe", loc = "INVTYPE_ROBE", s = 1, stats = { [INT] = 2 } })
M.equipped[10] = def(2, { name = "Old Gloves", loc = "INVTYPE_HAND", s = 1, stats = { [INT] = 3, [STA] = 2 } })
def(9002, { name = "Sapling Robe", loc = "INVTYPE_ROBE", s = 1, stats = { [INT] = 6, [STA] = 2 } })
def(9004, { name = "Moonlit Robe", loc = "INVTYPE_ROBE", s = 1, stats = { [INT] = 9 }, minLevel = 14 })
def(9006, { name = "Plate Chest", loc = "INVTYPE_CHEST", s = 4, stats = { [STR] = 9 } })
def(9007, { name = "Thin Gloves", loc = "INVTYPE_HAND", s = 1, stats = { [INT] = 1 } })

----- 1. ItemAdvisor_Judge
local j = ItemAdvisor_Judge(9002)
assert(j and j.upgrade and j.verdict == "EQUIP" and j.percent and j.percent > 0 and j.gain > 0, "robe upgrade: " .. tostring(j and j.reason))
assert(j.level == nil, "wearable now")
j = ItemAdvisor_Judge(9004)
assert(j and j.upgrade and j.level == 14 and j.reason:find("Upgrade at level 14", 1, true), "later upgrade: " .. tostring(j and j.reason))
j = ItemAdvisor_Judge(9006)
assert(j and not j.upgrade, "plate isn't a priest upgrade: " .. tostring(j and j.reason))
j = ItemAdvisor_Judge(9007)
assert(j and not j.upgrade, "worse gloves: " .. tostring(j and j.reason))
assert(ItemAdvisor_Judge(123456) == nil, "an item still loading gives nil")
assert(ItemAdvisor_Judge(nil) == nil and ItemAdvisor_Judge("x") == nil, "bad input gives nil")
say("1 ok")

----- 2. Bag advice lists the route's upgrades ahead (LevelGuide_UpgradesAhead), and works without LevelGuide.
local page = M.slash("")
assert(not page:find("Upgrades ahead", 1, true), "no LevelGuide: no section")
LevelGuide_UpgradesAhead = function()
    return { { step = 14, quest = "The Moonlit Path", questLevel = 12, itemText = "[Moonlit Robe]", reason = "Upgrade at level 14 (+9)" } }
end
page = M.slash("")
assert(page:find("Upgrades ahead on your leveling route", 1, true)
    and page:find("[Moonlit Robe] from The Moonlit Path (step 14), level 12: Upgrade at level 14 (+9)", 1, true), "bag advice:\n" .. page)
LevelGuide_UpgradesAhead = function() error("boom") end
page = M.slash("")
assert(not page:find("Upgrades ahead", 1, true), "an error in LevelGuide doesn't break the page")
LevelGuide_UpgradesAhead = nil
say("2 ok")

----- 3. ProfessionGuide's craft page: upgrades you can make.
local base = ADDON_PATH .. "/ProfessionGuide/"
for _, name in ipairs({ "Data_Alchemy.lua", "Data_Blacksmithing.lua", "Data_Enchanting.lua", "Data_Engineering.lua",
    "Data_Leatherworking.lua", "Data_Tailoring.lua", "Data_Mining.lua", "Data_Herbalism.lua", "Data_Skinning.lua",
    "Data_Cooking.lua", "Data_FirstAid.lua", "Data_Fishing.lua", "ProfessionGuide.lua" }) do
    assert(loadfile(base .. name))("ProfessionGuide", {})
end
local professions = { { name = "Tailoring", rank = 60, maxRank = 75, skillLine = 197 } }
GetProfessions = function() return 1 end
GetProfessionInfo = function(index) local p = professions[index]; return p.name, 0, p.rank, p.maxRank, 0, 0, p.skillLine end
C_SkillInfo = { GetSkillLineInfoByID = function() return nil end }
local function craftPage()
    M.toasts = {}
    local ok, err = pcall(SlashCmdList.PROFESSIONGUIDE, "craft")
    assert(ok, "craft page errored: " .. tostring(err))
    return table.concat(M.toasts, "\n")
end
local BOLT, THREAD = 2996, 2320
def(BOLT, { name = "Bolt of Linen Cloth", c = 7 })
-- Recipes read from the profession window: one upgrade (missing a bolt), one not, one for a profession you dropped.
ProfessionGuideDB = { recipes = {
    [501] = { name = "Sapling Robe", line = 197, prof = "Tailoring", out = 9002, mats = { { BOLT, 3 }, { THREAD, 1 } } },
    [502] = { name = "Thin Gloves", line = 197, prof = "Tailoring", out = 9007, mats = { { BOLT, 1 } } },
    [503] = { name = "Moonlit Robe", line = 197, prof = "Tailoring", out = 9004, mats = { { THREAD, 2 } } },
    [504] = { name = "Plate Chest", line = 164, prof = "Blacksmithing", out = 9006, mats = { { BOLT, 1 } } },
} }
bags = { [BOLT] = 2, [THREAD] = 5 }
local text = craftPage()
assert(text:find("Upgrades you can make", 1, true), "section title:\n" .. text)
local robe = text:match("[^\n]*Sapling Robe[^\n]*Upgrade for[^\n]*")
assert(robe and robe:find("missing 1 Bolt of Linen Cloth", 1, true) and robe:find("(Tailoring)", 1, true), "robe row:\n" .. text)
local later = text:match("[^\n]*Moonlit Robe[^\n]*Upgrade at level 14[^\n]*")
assert(later and later:find("mats ready", 1, true), "later upgrade, mats ready:\n" .. text)
assert(text:find("Sapling Robe", 1, true) < text:find("Upgrade at level 14", 1, true), "wearable now comes first")
assert(not text:find("Thin Gloves[^\n]*Upgrade", 1, false), "not an upgrade, not listed")
assert(not text:find("Plate Chest", 1, true), "a dropped profession's recipe isn't listed")
say("3 ok")

----- 4. No window read yet: the guide's crafts up to your skill, marked as guesses; nothing at all without ItemAdvisor.
ProfessionGuideDB = { recipes = {} }
local guideItem
for _, step in ipairs(ProfessionGuideData[197].steps) do
    if step.from <= 60 and step.itemID and step.mats and #step.mats > 0 then guideItem = step end
end
def(guideItem.itemID, { name = guideItem.craft, loc = "INVTYPE_HAND", s = 1, stats = { [INT] = 9, [STA] = 9 } })
text = craftPage()
assert(text:find(guideItem.craft .. "[^\n]*Upgrade for[^\n]*guide recipe: if you know it"), "guide craft as a guess:\n" .. text)
local judge = ItemAdvisor_Judge
ItemAdvisor_Judge = nil
text = craftPage()
assert(not text:find("Upgrades you can make", 1, true), "no ItemAdvisor: no section")
ItemAdvisor_Judge = judge
say("4 ok")

assert(#forbidden == 0, "forbidden call: " .. tostring(forbidden[1]))
assert(#M.handled == 0, "no errors: " .. table.concat(M.handled, "\n"))
say("ALL TESTS PASSED")
