-- Round 4 item 16 (research\re_round4.md R17, Full Mana Forever's in-game facts, MIT): FoodCheck's side-panel
-- row "Mana full in 64 s - drink Ice Cold Milk: full in 20 s". Out of combat only (GetPowerRegen is secret in
-- combat); "normal" regen is the lowest 30 s bucket of the last 5 minutes (so Innervate or a ley line doesn't
-- inflate it); Resurrection Sickness (15007) skips it; a cast in the last 5 s counts at the casting rate.
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

-- 1. No drink in the bags: just the time to full mana at the normal regen (640 / 10 = 64 s).
tick()
local text, entry = row()
assert(text:find("Mana full in 64 s", 1, true), "time to full: " .. text)
assert(entry.page == "Food and drink", "opens the food page")
print("1 ok")

-- 2. With Ice Cold Milk: 437 over 18 s plus regen -> 617 in 18 s, the last 23 at 10/s -> 20 s.
bag[1] = { itemID = 1179, stackCount = 5, hyperlink = link }
frames[#frames].fn(frames[#frames], "BAG_UPDATE_DELAYED")
text = row()
assert(text:find("Mana full in 64 s", 1, true) and text:find("Ice Cold Milk", 1, true) and text:find("full in 20 s", 1, true),
    "drink advice: " .. text)
print("2 ok")

-- 3. A spike (Innervate, ley line) doesn't count as normal: the lowest 30 s bucket of 5 min is used.
now = now + 40; regen = 50
tick()
text = row()
assert(text:find("Mana full in 64 s", 1, true), "spike ignored: " .. text)
-- Five minutes later the low bucket has aged out.
now = now + 300
tick()
-- New normal 50/s: full in 13 s, too short for a row.
assert(row() == "", "new normal: " .. row())
mana = 0   -- 1000 at 50/s = 20 s; the drink (24/s + 50/s) gets there in 13.5 s, saving under 10 s: no advice
text = row()
assert(text:find("Mana full in 20 s", 1, true), "new normal: " .. text)
assert(not text:find("Ice Cold Milk", 1, true), "drinking isn't worth it when regen is fast: " .. text)
mana = 360
regen = 10
now = now + 400
tick()
print("3 ok")

-- 4. The five-second rule: a cast 2 s ago -> 3 s at the casting rate (0 here) first: 67 s.
local events
for _, f in ipairs(frames) do if f.isManaFull then events = f end end
events = events or frames[#frames]
events.fn(events, "UNIT_SPELLCAST_SUCCEEDED", "player")
now = now + 2
text = row()
assert(text:find("Mana full in 67 s", 1, true), "five-second rule: " .. text)
now = now + 10
print("4 ok")

-- 5. Nothing in combat, at full mana, or with Resurrection Sickness.
combat = true
assert(row() == "", "nothing in combat")
combat = false
mana = 1000
assert(row() == "", "nothing at full mana")
mana = 360
auras[15007] = { spellId = 15007 }
assert(row() == "", "nothing with Resurrection Sickness")
auras[15007] = nil
-- Almost full: under 15 s isn't worth a row.
mana = 900
assert(row() == "", "not worth a row: " .. row())
assert(#out == 0 and #handled == 0, "no pop-ups, no errors: " .. tostring(handled[1]))
print("ALL TESTS PASSED")
