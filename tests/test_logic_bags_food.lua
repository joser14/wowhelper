-- FoodCheck logic review: a "well fed" food whose buff mentions mana (Smoked Sagefish: "...gain 3 Mana
-- every 5 seconds") is food, not a drink. Before the fix it could be named the best drink.
-- ADDON_PATH is the folder holding every addon.
local out = {}
ForeverHub_Receive = function(_, t) out[#out + 1] = t end
SlashCmdList = {}
issecretvalue = function() return false end
UnitLevel = function() return 20 end
NUM_TOTAL_EQUIPPED_BAG_SLOTS = 0

local defs = {}
local bag = {}
local function add(id, name, minLevel, tip, count)
    local link = "|Hitem:" .. id .. ":|h[" .. name .. "]|h"
    defs[link] = { name = name, minLevel = minLevel, tip = tip }
    bag[#bag + 1] = { hyperlink = link, itemID = id, stackCount = count }
    return link
end
local sagefish = add(21072, "Smoked Sagefish", 10,
    "Use: Restores 378 health over 21 sec. If you spend at least 10 seconds eating you will become well fed and gain 3 Mana every 5 seconds for 15 min.", 5)
local water = add(1179, "Ice Cold Milk", 5, "Use: Restores 436.8 mana over 18 sec.", 10)
local feast = add(13724, "Enriched Manna Biscuit", 1, "Use: Restores 2148 health and 4410 mana over 30 sec.", 1)

C_Container = {
    GetContainerNumSlots = function(b) return b == 0 and #bag or 0 end,
    GetContainerItemInfo = function(b, slot) return b == 0 and bag[slot] or nil end,
}
C_Item = {
    GetItemInfo = function(link)
        local d = defs[link]
        return d.name, link, 1, 1, d.minLevel, "", "", 20, "", 0, 1, 0, 5
    end,
    RequestLoadItemDataByID = function() end,
}
C_TooltipInfo = { GetHyperlink = function(link)
    return { lines = { { leftText = defs[link].name }, { leftText = defs[link].tip } } }
end }

assert(loadfile(ADDON_PATH .. "/FoodCheck/FoodCheck.lua"))("FoodCheck", {})
SlashCmdList.FOODCHECK("")
local text = table.concat(out, "\n")
assert(text:find("Best food: " .. sagefish, 1, true), "sagefish is the best food:\n" .. text)
assert(text:find("Best drink: " .. water, 1, true), "the real drink is the best drink, not the sagefish:\n" .. text)

-- Health-and-mana food still counts for both (with nothing else in the bags it is both answers).
bag = { bag[3] }
out = {}
SlashCmdList.FOODCHECK("")
text = table.concat(out, "\n")
assert(text:find("Best food: " .. feast, 1, true) and text:find("Best drink: " .. feast, 1, true), "health and mana:\n" .. text)
print("ok")
