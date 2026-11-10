-- Round 3 rank 8: FoodCheck tells food from drink by item ID (Shortest Path Forever's list, any client language),
-- opt-in buff reminders (Well Fed, elixirs, weapon oil); SupplyWatch's ammo warning is for hunters only, counts
-- every stack the weapon fires, stays quiet 5 s after entering the world, says how many minutes of fighting are
-- left and where the nearest arrow vendor is; Landmarks learns which vendors sell arrows, bullets, bags and
-- reagents from the merchant window.
local base = ADDON_PATH
local SECRET = {}
issecretvalue = function(v) return v == SECRET end
local out, handled, frames = {}, {}, {}
ForeverHub_Receive = function(_, t) out[#out + 1] = t end
geterrorhandler = function() return function(e) handled[#handled + 1] = tostring(e) end end
CreateFrame = function()
    local f = { registered = {} }
    f.RegisterEvent = function(self, e) self.registered[e] = true end
    f.RegisterUnitEvent = function(self, e) self.registered[e] = true end
    f.SetScript = function(self, _, fn) self.fn = fn end
    frames[#frames + 1] = f
    return f
end
SlashCmdList = {}
UnitName = function(unit) if unit == "npc" then return "Gina" end return "Me" end
GetRealmName = function() return "R" end
local now = 1000
GetTime = function() return now end
local timers = {}
C_Timer = { After = function(_, fn) timers[#timers + 1] = fn end, NewTicker = function() end }
local function runTimers() local t = timers; timers = {}; for _, fn in ipairs(t) do fn() end end
UnitLevel = function() return 20 end
local class = "MAGE"
UnitClass = function() return "x", class end
local combat = false
InCombatLockdown = function() return combat end
C_Secrets = { ShouldAurasBeSecret = function() return false end }
NUM_TOTAL_EQUIPPED_BAG_SLOTS = 0
local function load(name)
    local n = #frames
    assert(loadfile(base .. "/" .. name .. "/" .. name .. ".lua"))(name, {})
    return frames[n + 1]
end
local function fire(f, ev, ...) f.fn(f, ev, ...) end
local function text() return table.concat(out, "\n") end

-- Bags: item ID -> { name, minLevel, classID, subClassID, tooltip }
local defs = {
    [4540] = { "Tough Hunk of Bread", 5, 0, 5, "Utiliser : Rend 61 points de vie." },     -- food by ID, French text
    [1179] = { "Ice Cold Milk", 5, 0, 5, "Utiliser : Rend 437 points de mana." },          -- drink by ID
    [99001] = { "New Forever Stew", 10, 0, 5, "Use: Restores 500 health over 21 sec." },   -- not in the list: tooltip
    [2512] = { "Rough Arrow", 1, 6, 2, "" }, [2516] = { "Light Shot", 1, 6, 3, "" },
}
local bag = {}
local function put(id, n) bag[#bag + 1] = { itemID = id, stackCount = n, hyperlink = "|Hitem:" .. id .. ":|h[" .. defs[id][1] .. "]|h" } end
C_Container = {
    GetContainerNumSlots = function(b) return b == 0 and 16 or 0 end,
    GetContainerItemInfo = function(b, slot) return b == 0 and bag[slot] or nil end,
}
local function idOf(link) return tonumber(tostring(link):match("item:(%d+)")) or link end
C_Item = {
    GetItemInfo = function(link)
        local d = defs[idOf(link)]
        if not d then return nil end
        return d[1], link, 1, 1, d[2], "", "", 20, "", 0, 1, d[3], d[4]
    end,
    GetItemInfoInstant = function(link)
        local id = idOf(link)
        if link == "bow" then return 1, "", "", "", 0, 2, 2 end
        local d = defs[id]
        if not d then return id, "", "", "", 0, 0, 0 end
        return id, "", "", "", 0, d[3], d[4]
    end,
    GetItemCount = function() return 0 end,
    RequestLoadItemDataByID = function() end,
}
C_TooltipInfo = { GetHyperlink = function(link)
    local d = defs[idOf(link)]
    return { lines = { { leftText = d[1] }, { leftText = d[5] } } }
end }

----- 1. FoodCheck: food and drink by item ID, whatever the tooltip's language.
assert(loadfile(base .. "/FoodCheck/FoodIDs.lua"))("FoodCheck", {})
assert(FoodCheckIDs.food[4540] and FoodCheckIDs.drink[1179] and not FoodCheckIDs.food[1179], "ID lists")
put(4540, 5); put(1179, 4); put(99001, 2)
local auras = {}
C_UnitAuras = {
    GetPlayerAuraBySpellID = function(id) for _, a in pairs(auras) do if a.spellId == id then return a end end end,
    GetAuraDataBySpellName = function(_, name) return auras[name] end,
    GetBuffDataByIndex = function(_, i) local list = {}; for _, a in pairs(auras) do list[#list + 1] = a end; return list[i] end,
}
local fc = load("FoodCheck")
fire(fc, "PLAYER_LOGIN")
out = {}
SlashCmdList.FOODCHECK("")
assert(text():find("Best food: |Hitem:99001", 1, true) or text():find("Best food: |Hitem:4540", 1, true), "food found:\n" .. text())
assert(text():find("Best drink: |Hitem:1179", 1, true), "drink by ID despite French text:\n" .. text())
assert(not text():find("Couldn't tell", 1, true), "every item classified:\n" .. text())
print("1 ok")

----- 2. Buff reminders: opt in by typing a buff you have; a pop-up at 3 minutes and when gone; never in
----- combat; none before the login delay; "ran out while you were away" after login.
runTimers() -- the login delay passes
auras["Well Fed"] = { spellId = 24870, name = "Well Fed", expirationTime = now + 900 }
out = {}
SlashCmdList.FOODCHECK("remind well fed")
assert(text():find("Watching Well Fed.", 1, true), "opt in:\n" .. text())
assert(text():find("Reminder: Well Fed, 15 min left", 1, true), "listed:\n" .. text())
out = {}
fire(fc, "UNIT_AURA", "player")
assert(#out == 0, "plenty left: quiet")
now = now + 750
fire(fc, "UNIT_AURA", "player")
assert(text():find("Well Fed runs out in 3 min.", 1, true), "low:\n" .. text())
out = {}
fire(fc, "UNIT_AURA", "player")
assert(#out == 0, "warned once")
-- In combat the buff can't be read: never "gone".
auras = {}
combat = true
fire(fc, "PLAYER_REGEN_ENABLED")
fire(fc, "UNIT_AURA", "player")
assert(#out == 0, "combat: unknown, no pop-up")
combat = false
fire(fc, "UNIT_AURA", "player")
assert(text():find("Well Fed is gone.", 1, true), "gone:\n" .. text())
-- Another Well Fed (a different food, another spell ID) re-arms it by name.
auras["Well Fed"] = { spellId = 99999, name = "Well Fed", expirationTime = now + 900 }
out = {}
fire(fc, "UNIT_AURA", "player")
assert(#out == 0, "back: quiet")
-- A buff you don't have can't be added; stop removes one.
out = {}
SlashCmdList.FOODCHECK("remind Elixir of Giants")
assert(text():find("You don't have", 1, true), "absent buff:\n" .. text())
-- Weapon oil: C_Item.GetWeaponEnchantInfo, time left in ms.
local enchant = { { hasEnchant = true, timeLeft = 1200 * 1000 } }
C_Item.GetWeaponEnchantInfo = function() return enchant end
out = {}
SlashCmdList.FOODCHECK("remind weapon")
assert(text():find("Watching your weapon oil or stone.", 1, true), "weapon:\n" .. text())
enchant = {}
out = {}
fire(fc, "UNIT_AURA", "player")
assert(text():find("Weapon oil or stone is gone.", 1, true), "weapon gone:\n" .. text())
out = {}
SlashCmdList.FOODCHECK("stop weapon")
assert(text():find("Stopped watching Weapon oil or stone.", 1, true), "stop:\n" .. text())
-- After a new login a tracked buff that's missing ran out while you were away (only after the delay).
auras = {}
fc = load("FoodCheck")
fire(fc, "PLAYER_LOGIN")
out = {}
fire(fc, "UNIT_AURA", "player")
assert(#out == 0, "nothing before the login delay")
runTimers()
assert(text():find("Well Fed ran out while you were away.", 1, true), "offline expiry:\n" .. text())
local key = next(FoodCheckDB)
assert(#FoodCheckDB[key].reminders == 1, "saved per character")
print("2 ok")

----- 3. SupplyWatch: ammo for hunters only, every stack the bow fires.
bag = {}
put(2512, 200); put(2512, 150); put(2516, 400)
GetInventoryItemLink = function(_, slot) if slot == 18 then return "bow" end end
local sw = load("SupplyWatch")
fire(sw, "PLAYER_LOGIN")
out = {}
SlashCmdList.SUPPLYWATCH("")
assert(not text():find("Ammo:", 1, true), "a mage has no ammo line:\n" .. text())
class = "HUNTER"
out = {}
SlashCmdList.SUPPLYWATCH("")
assert(text():find("Ammo: 350/200", 1, true), "arrows only, both stacks:\n" .. text())
-- Quiet for 5 s after entering the world; then one warning.
bag = {}
put(2512, 120)
out = {}
fire(sw, "PLAYER_ENTERING_WORLD")
assert(not text():find("Low on Ammo", 1, true), "quiet while bags arrive:\n" .. text())
now = now + 6
runTimers()
assert(text():find("Low on Ammo: 120", 1, true), "warns after the quiet time:\n" .. text())
out = {}
fire(sw, "BAG_UPDATE_DELAYED")
assert(#out == 0, "once per restock")
-- Fights teach how fast ammo goes: 60 arrows over 2 minutes -> 30 a minute.
fire(sw, "PLAYER_REGEN_DISABLED")
now = now + 120
bag = {}; put(2512, 60)
fire(sw, "PLAYER_REGEN_ENABLED")
-- The nearest arrow vendor from Landmarks.
Landmarks_Nearest = function(kind) if kind == "arrows" then return { name = "Gina", where = "Goldshire" }, 340 end end
out = {}
SlashCmdList.SUPPLYWATCH("")
assert(text():find("Ammo: 60/200 (about 2 min of fighting)", 1, true), "minutes left:\n" .. text())
assert(text():find("Nearest arrow vendor: Gina (Goldshire), 340 yd.", 1, true), "nearest vendor:\n" .. text())
-- Restocked above the threshold, then low again: warns again with the extras.
bag = {}; put(2512, 500)
fire(sw, "BAG_UPDATE_DELAYED")
bag = {}; put(2512, 30)
out = {}
fire(sw, "BAG_UPDATE_DELAYED")
assert(text():find("Low on Ammo: 30 (you want 200). About 1 min of fighting left. Nearest arrow vendor", 1, true), "re-armed:\n" .. text())
print("3 ok")

----- 4. Landmarks: a vendor selling arrows, a bag and a reagent is remembered under those kinds.
local function vec(x, y) return { x = x, y = y, GetXY = function(self) return self.x, self.y end } end
CreateVector2D = vec
C_Map = {
    GetBestMapForUnit = function() return 1429 end,
    GetPlayerMapPosition = function() return vec(0.42, 0.65) end,
    GetWorldPosFromMapPos = function(_, v) return 0, vec(v.x * 10000, v.y * 10000) end,
}
time = function() return 50000 end
GetZoneText = function() return "Elwynn Forest" end
GetSubZoneText = function() return "Goldshire" end
defs[4496] = { "Small Brown Pouch", 1, 1, 0, "" }
defs[17020] = { "Arcane Powder", 1, 15, 1, "" }
local merchant = { 2512, 4496, 17020, 1179 }
GetMerchantNumItems = function() return #merchant end
GetMerchantItemID = function(i) return merchant[i] end
CanMerchantRepair = function() return false end
Landmarks_Nearest = nil
local lm = load("Landmarks")
fire(lm, "PLAYER_LOGIN")
fire(lm, "MERCHANT_SHOW")
local kinds = {}
for _, place in ipairs(LandmarksDB.R.places) do kinds[place.kind] = true end
for _, kind in ipairs({ "vendor", "arrows", "bags", "reagents", "food" }) do
    assert(kinds[kind], "remembered as " .. kind)
end
assert(not kinds.bullets, "no bullets sold")
out = {}
SlashCmdList.LANDMARKS("arrows")
assert(text():find("Gina", 1, true), "nearest arrows:\n" .. text())
print("4 ok")

assert(#handled == 0, "clean: " .. tostring(handled[1]))
print("ALL TESTS PASSED")
