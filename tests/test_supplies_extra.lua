-- Fixes in BagCheck, DurabilityWatch, FoodCheck, SupplyWatch, GoldGoal and RestGuard.
-- ADDON_PATH is the folder holding every addon.
local base = ADDON_PATH
local SECRET = setmetatable({}, { __tostring = function() return "SECRET" end })
issecretvalue = function(v) return v == SECRET end
local toasts = {}
ForeverHub_Receive = function(_, t) toasts[#toasts + 1] = t end
local frame
CreateFrame = function()
    frame = { RegisterEvent = function() end, SetScript = function(self, _, fn) self.fn = fn end }
    return frame
end
SlashCmdList = {}
UnitName = function() return "T" end
GetRealmName = function() return "R" end
local level = 30
UnitLevel = function() return level end
local class = "MAGE"
UnitClass = function() return "x", class end
GetTime = function() return 1000 end
local function load(name)
    assert(loadfile(base .. "/" .. name .. "/" .. name .. ".lua"))(name, {})
    return frame
end
local function fire(f, ...) f.fn(f, ...) end
local function saw(text) for _, t in ipairs(toasts) do if t:find(text, 1, true) then return true end end return false end
local function need(text, why) assert(saw(text), why .. ": wanted '" .. text .. "' in:\n" .. table.concat(toasts, "\n")) end
local function never(text, why) assert(not saw(text), why .. ": did not want '" .. text .. "' in:\n" .. table.concat(toasts, "\n")) end
local function reset() toasts = {} end

----- BagCheck: a hidden bag type is unknown, not full.
local bagType, freeSlots = 0, 2
NUM_TOTAL_EQUIPPED_BAG_SLOTS = 0
local bagItems = {}
C_Container = {
    GetContainerNumSlots = function() return 16 end,
    GetContainerNumFreeSlots = function() return freeSlots, bagType end,
    GetContainerItemInfo = function(_, slot) return bagItems[slot] end,
}
local prices = { [7] = 50 }
C_Item = {
    GetItemInfo = function(id) return "n", nil, nil, nil, nil, nil, nil, nil, nil, nil, prices[id] end,
    RequestLoadItemDataByID = function() end,
    GetItemCount = function() return 0 end,
}
local bc = load("BagCheck")
bagType = SECRET
fire(bc, "BAG_UPDATE_DELAYED")
never("nearly full", "secret bag type isn't a full bag")
assert(not ForeverHubStatus.BagCheck(), "no row when unknown")
SlashCmdList.BAGCHECK("")
need("didn't report your bag space", "page says so")
bagType = 0
fire(bc, "BAG_UPDATE_DELAYED")
need("nearly full: 2", "readable bags still warn")
-- Junk with a hidden item ID or price is skipped, never compared.
bagItems = { { quality = 0, stackCount = 1, itemID = SECRET }, { quality = 0, stackCount = 2, itemID = 7 } }
reset(); SlashCmdList.BAGCHECK("")
need("2 junk item(s) worth 0g 1s 0c", "only the readable junk")
prices[7] = SECRET
reset(); SlashCmdList.BAGCHECK("")
need("worth at least", "hidden price counts as unknown")
bagItems = {}

----- DurabilityWatch: names the damaged item.
local dur = { [5] = { 10, 100 }, [1] = { 90, 100 } }
GetInventoryItemDurability = function(slot) local d = dur[slot]; if d then return d[1], d[2] end end
GetInventoryItemLink = function(_, slot) if slot == 5 then return "|Hitem:10|h[Chest]|h" end end
local dw = load("DurabilityWatch")
local row = ForeverHubStatus.DurabilityWatch()[1]
assert(row.link == "|Hitem:10|h[Chest]|h" and row.page == "Repairs", "row carries the item link")
reset(); SlashCmdList.DURABILITYWATCH("")
need("most damaged item is at 10%: |Hitem:10|h[Chest]|h", "page names it")
GetInventoryItemLink = function() return SECRET end
assert(ForeverHubStatus.DurabilityWatch()[1].link == nil, "hidden link dropped")
reset(); SlashCmdList.DURABILITYWATCH("")
need("most damaged item is at 10%.", "still works without a link")
GetInventoryItemLink = nil

----- FoodCheck: equal levels prefer the smaller stack; hidden item data is skipped.
local foodBag = {
    { hyperlink = "|h[Big Bread]|h", stackCount = 20, itemID = 1 },
    { hyperlink = "|h[Small Bread]|h", stackCount = 3, itemID = 2 },
    { hyperlink = "|h[Hidden]|h", stackCount = 1, itemID = 3 },
}
C_Container.GetContainerItemInfo = function(_, slot) return foodBag[slot] end
C_Container.GetContainerNumSlots = function() return #foodBag end
C_Item.GetItemInfo = function(link)
    if link:find("Hidden") then return "Hidden", nil, nil, nil, SECRET, nil, nil, nil, nil, nil, nil, 0, 5 end
    return "Bread", nil, nil, nil, 25, nil, nil, nil, nil, nil, nil, 0, 5
end
C_TooltipInfo = { GetHyperlink = function() return { lines = { { leftText = "Use: Restores 874 health over 24 sec." } } } end }
load("FoodCheck")
reset(); SlashCmdList.FOODCHECK("")
need("Best food: |h[Small Bread]|h x3", "smaller stack of the same level first")

----- SupplyWatch
-- Ammo is for hunters only (round 3, rank 8).
class = "HUNTER"
C_Container.GetContainerNumSlots = function() return 0 end
local counts = { [159] = 5, [4540] = 0 }
C_Item.GetItemCount = function(id) return counts[id] or 0 end
C_Item.GetItemInfoInstant = function(id) return id, "", "", "", 0, id == 2512 and 6 or 0, 2 end
local usesAmmo, ammo = true, 1000
UnitUsesAmmo = function() return usesAmmo end
GetInventoryItemLink = function(_, slot) if slot == 0 then return "|Hitem:2512|h[Rough Arrow]|h" end end
GetInventoryItemCount = function() return ammo end
-- An older record without ammoMin still loads.
SupplyWatchDB = { ["T-R"] = { items = { { id = 159, name = "Water", min = 20 }, { id = 4540, name = "Bread", min = 10 } } } }
local sw = load("SupplyWatch")
fire(sw, "PLAYER_LOGIN")
assert(SupplyWatchDB["T-R"].ammoMin == 200, "missing ammoMin gets the default")
reset(); fire(sw, "PLAYER_ENTERING_WORLD")
assert(#toasts == 0, "no warnings before bags load: " .. table.concat(toasts, " / "))
C_Container.GetContainerNumSlots = function() return 16 end
fire(sw, "BAG_UPDATE_DELAYED")
need("Low on Water: 5", "warns once bags are read")
-- Panel rows link to the item.
local rows = ForeverHubStatus.SupplyWatch()
assert(rows[1].link == "item:159" and rows[1].page == "Supplies", "row links the item")
-- A vendor that sells water only mentions water.
local merchant = { 159 }
GetMerchantNumItems = function() return #merchant end
GetMerchantItemID = function(i) return merchant[i] end
reset(); fire(sw, "MERCHANT_SHOW")
need("Restock Water here: you have 5, 15 short", "sold here")
never("Bread", "not sold here")
-- A vendor whose list isn't readable yet mentions everything, as before.
merchant = {}
reset(); fire(sw, "MERCHANT_SHOW")
need("Restock Water: you have 5", "fallback water")
need("Restock Bread: you have 0", "fallback bread")
-- Any arrows on sale count for ammo.
ammo = 50
merchant = { 3030 }
C_Item.GetItemInfoInstant = function(id) return id, "", "", "", 0, 6, 2 end
reset(); fire(sw, "MERCHANT_SHOW")
need("Restock Ammo here", "projectile vendor")
never("Water", "water not sold")
GetMerchantItemID = function() return SECRET end
reset(); fire(sw, "MERCHANT_SHOW")
assert(#toasts == 0, "hidden vendor items match nothing")
-- Wanting 0 stops watching; 0 for a new item watches nothing.
local water = "|cffffffff|Hitem:159:0:0|h[Water]|h|r"
reset(); SlashCmdList.SUPPLYWATCH("add " .. water .. " 0")
need("Stopped watching Water", "0 removes")
assert(#SupplyWatchDB["T-R"].items == 1, "one left")
reset(); SlashCmdList.SUPPLYWATCH("add " .. water .. " 0")
need("0 doesn't watch anything", "0 adds nothing")
assert(#SupplyWatchDB["T-R"].items == 1, "still one")
-- Help talks about the page, not slash commands.
reset(); SlashCmdList.SUPPLYWATCH("help")
never("/supply", "no slash commands in help")
reset(); SlashCmdList.SUPPLYWATCH("ammo 2.5")
never("Ammo warning", "fractions aren't an amount")
reset(); SlashCmdList.SUPPLYWATCH("ammo 400")
need("Ammo warning at 400", "ammo set")

----- GoldGoal
local money = 1300000
GetMoney = function() return money end
C_SkillInfo = { GetSkillLineInfoByID = function() return nil end }
level = 39
local gg = load("GoldGoal")
fire(gg, "PLAYER_LOGIN")
never("You can afford", "level 39 can't ride yet")
-- UnitLevel still says 39 as the level-up event arrives.
fire(gg, "PLAYER_LEVEL_UP", 40)
need("You can afford Apprentice Riding", "uses the event's new level")
reset(); SlashCmdList.GOLDGOAL("500g Bags")
need("Bags: you have", "500g accepted")
assert(GoldGoalDB["T-R"].goal.gold == 500, "500 gold")
for _, bad in ipairs({ "2.5 Bags", "1e3 Bags", "999999999 Bags", "0 Bags" }) do
    reset(); SlashCmdList.GOLDGOAL(bad)
    need("Enter whole gold", "rejects " .. bad)
    assert(GoldGoalDB["T-R"].goal.gold == 500, "goal unchanged by " .. bad)
end
never("/goal", "no slash commands in help")
SlashCmdList.GOLDGOAL("clear")
class = "PALADIN"
reset(); SlashCmdList.GOLDGOAL("")
need("class quests", "paladins are told why riding isn't tracked")
class = "MAGE"

----- RestGuard
IsResting = function() return true end
UnitXPMax = function() return 1000 end
local rested = 1400
GetXPExhaustion = function() return rested end
GetBindLocation = function() return "Goldshire" end
C_Container.GetItemCooldown = function() return 0, 0, 1 end
local hearth = 1
C_Item.GetItemCount = function() return hearth end
level = 20
load("RestGuard")
reset(); SlashCmdList.RESTGUARD("")
need("About 16 hour(s) at an inn", "under a day in hours")
need("Hearthstone: Goldshire, ready", "carried stone")
rested = 500
reset(); SlashCmdList.RESTGUARD("")
need("About 6.7 days", "days when long")
hearth = 0
reset(); SlashCmdList.RESTGUARD("")
need("isn't in your bags", "no stone, no false ready")
never("ready", "no false ready")
hearth = SECRET
reset(); SlashCmdList.RESTGUARD("")
need("Hearthstone: Goldshire, ready", "hidden count falls back to the cooldown")

print("ALL TESTS PASSED")
