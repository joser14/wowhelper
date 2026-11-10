-- Round 4 item 11 (research\re_round4.md R11): near a camp, FoodCheck's page lists the camp objects whose buff
-- you could still get, and says which ones to skip because a class buff you have doesn't stack with them
-- ("Mana Well: skip, you have Blessing of Wisdom"). Camp buff IDs and effects from Tweaks Forever (GPL-3.0+),
-- "exclusive with" facts from Firekeeper (MIT). Auras only out of combat and when not secret.
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
GetTime = function() return 1000 end
C_Timer = { After = function(_, fn) fn() end, NewTicker = function() end }
UnitLevel = function() return 30 end
local combat, secret = false, false
InCombatLockdown = function() return combat end
C_Secrets = { ShouldAurasBeSecret = function() return secret end }
NUM_TOTAL_EQUIPPED_BAG_SLOTS = 0
C_Container = { GetContainerNumSlots = function() return 0 end, GetContainerItemInfo = function() end }
C_Item = { GetItemInfo = function() end, RequestLoadItemDataByID = function() end }
-- Your buffs: by spell ID and by name.
local byID, byName = {}, {}
C_UnitAuras = {
    GetPlayerAuraBySpellID = function(id) return byID[id] end,
    GetAuraDataBySpellName = function(_, name) return byName[name] end,
    GetBuffDataByIndex = function() return nil end,
}
assert(loadfile(base .. "/FoodCheck/FoodIDs.lua"))("FoodCheck", {})
assert(loadfile(base .. "/FoodCheck/CampObjects.lua"))("FoodCheck", {})
assert(loadfile(base .. "/FoodCheck/FoodCheck.lua"))("FoodCheck", {})
local events = frames[#frames]
events.fn(events, "PLAYER_LOGIN")
local function page() out = {}; SlashCmdList.FOODCHECK(""); return table.concat(out, "\n") end

-- 1. Away from a camp: no camp lines.
local text = page()
assert(not text:find("Mana Well", 1, true), "no camp lines away from a camp:\n" .. text)
print("1 ok")

-- 2. At a camp with no buffs: every object is listed with its effect.
byID[1283391] = { spellId = 1283391, name = "Campfire Nearby" }
text = page()
assert(text:find("At this camp", 1, true), "camp heading:\n" .. text)
for _, name in ipairs({ "Mana Well", "Sharpening Wheel", "Enchanted Lute", "First Aid Kit", "Fish Bowl",
    "Incense Candle", "Lodestone", "Camp Chair", "Faction Banner" }) do
    assert(text:find(name, 1, true), name .. " listed:\n" .. text)
end
assert(text:find("Mana Well|r: Restores 29 Mana every 5 seconds", 1, true), "effect shown:\n" .. text)
print("2 ok")

-- 3. A class buff that doesn't stack: skip that object, naming the buff. One you already have: not listed.
byName["Blessing of Wisdom"] = { name = "Blessing of Wisdom" }
byName["Arcane Brilliance"] = { name = "Arcane Brilliance" }        -- the group version counts too
byID[1230124] = { spellId = 1230124, name = "First Aid Kit" }        -- you used the First Aid Kit already
text = page()
assert(text:find("Mana Well|r: skip, you have Blessing of Wisdom", 1, true), "exclusive with BoW:\n" .. text)
assert(text:find("Incense Candle|r: skip, you have Arcane Brilliance", 1, true), "exclusive with AB:\n" .. text)
assert(not text:find("First Aid Kit", 1, true), "already have it:\n" .. text)
assert(text:find("Lodestone|r: Melee Attack Power", 1, true), "others still offered:\n" .. text)
print("3 ok")

-- 4. In combat or with secret auras: nothing guessed.
combat = true
text = page()
assert(not text:find("At this camp", 1, true), "nothing in combat:\n" .. text)
combat, secret = false, true
text = page()
assert(not text:find("At this camp", 1, true), "nothing while auras are secret:\n" .. text)
secret = false
-- A secret aura table is treated as unreadable, not as "you have it".
byName["Blessing of Wisdom"] = SECRET
text = page()
assert(not text:find("skip, you have Blessing of Wisdom", 1, true), "secret buff not trusted:\n" .. text)
assert(#handled == 0, "clean: " .. tostring(handled[1]))
print("ALL TESTS PASSED")
