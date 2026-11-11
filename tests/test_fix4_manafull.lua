-- Review 4, suspicion 2: ManaFull's drink advice reads drinks whose tooltip amount has decimals
-- ("Restores 1344.6 mana over 27 sec", Classic style). Mocks copied from test_r4c_manafull.lua.
local base = ADDON_PATH
local SECRET = {}
issecretvalue = function(v) return v == SECRET end
local out, handled, frames = {}, {}, {}
ForeverHub_Receive = function(_, t) out[#out + 1] = t end
geterrorhandler = function() return function(e) handled[#handled + 1] = tostring(e) end end
CreateFrame = function()
    local f = {}
    f.RegisterEvent = function() end
    f.RegisterUnitEvent = function() end
    f.SetScript = function(self, _, fn) self.fn = fn end
    frames[#frames + 1] = f
    return f
end
SlashCmdList = {}
UnitName = function() return "Me" end
GetRealmName = function() return "R" end
local now = 1000
GetTime = function() return now end
local tickers = {}
C_Timer = { After = function(_, fn) fn() end, NewTicker = function(s, fn) tickers[#tickers + 1] = { s = s, fn = fn } end }
local function tick() for _, t in ipairs(tickers) do t.fn() end end
UnitLevel = function() return 20 end
local combat = false
InCombatLockdown = function() return combat end
C_Secrets = { ShouldAurasBeSecret = function() return false end }
local auras = {}
C_UnitAuras = {
    GetPlayerAuraBySpellID = function(id) return auras[id] end,
    GetAuraDataBySpellName = function() return nil end,
    GetBuffDataByIndex = function() return nil end,
}
local mana, maxMana, regen, castRegen = 360, 1000, 10, 0
UnitPower = function(_, t) return t == 0 and mana or 0 end
UnitPowerMax = function(_, t) return t == 0 and maxMana or 0 end
GetPowerRegen = function() if combat then return SECRET, SECRET end return regen, castRegen end
NUM_TOTAL_EQUIPPED_BAG_SLOTS = 0
local bag = {}
C_Container = {
    GetContainerNumSlots = function(b) return b == 0 and 4 or 0 end,
    GetContainerItemInfo = function(b, slot) return b == 0 and bag[slot] or nil end,
}
local link = "|Hitem:1179:|h[Ice Cold Milk]|h"
C_Item = {
    GetItemInfo = function(l) if l == link then return "Ice Cold Milk", l, 1, 5, 5, "", "", 20, "", 0, 1, 0, 5 end end,
    RequestLoadItemDataByID = function() end,
}
C_TooltipInfo = { GetHyperlink = function(l)
    return { lines = { { leftText = "Ice Cold Milk" }, { leftText = "Use: Restores 437 mana over 18 sec.  Must remain seated while drinking." } } }
end }
for _, f in ipairs({ "FoodIDs", "CampObjects", "FoodCheck", "ManaFull" }) do
    assert(loadfile(base .. "/FoodCheck/" .. f .. ".lua"))("FoodCheck", {})
end
for _, f in ipairs(frames) do if f.fn then f.fn(f, "PLAYER_LOGIN") end end
local function row()
    local list = ForeverHubStatus and ForeverHubStatus.FoodCheck and ForeverHubStatus.FoodCheck() or {}
    return list[1] and list[1].text or "", list[1]
end
C_TooltipInfo.GetHyperlink = function()
    return { lines = { { leftText = "Ice Cold Milk" }, { leftText = "Use: Restores 1344.6 mana over 27 sec.  Must remain seated while drinking." } } }
end
tick()
bag[1] = { itemID = 1179, stackCount = 5, hyperlink = link }
frames[#frames].fn(frames[#frames], "BAG_UPDATE_DELAYED")
-- 640 mana to go at 10/s: 64 s. Drinking: 1344.6 / 27 = 49.8/s plus 10/s -> 640 / 59.8 = 10.7 s -> 11 s.
local text = row()
assert(text:find("Mana full in 64 s", 1, true), "time to full: " .. text)
assert(text:find("Ice Cold Milk", 1, true) and text:find("full in 11 s", 1, true), "decimal drink read: " .. text)
-- A comma as a thousands separator is read too.
C_TooltipInfo.GetHyperlink = function()
    return { lines = { { leftText = "Use: Restores 1,344.6 mana over 27 sec." } } }
end
now = now + 60
frames[#frames].fn(frames[#frames], "BAG_UPDATE_DELAYED")
text = row()
assert(text:find("full in 11 s", 1, true), "thousands separator: " .. text)
assert(#handled == 0, "no errors: " .. tostring(handled[1]))
print("ALL TESTS PASSED")
