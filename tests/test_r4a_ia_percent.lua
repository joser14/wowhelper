-- Round 4 R2: ItemAdvisor reads Forever's haste and expertise tooltip lines (research\re_round4.md 3.1, R2).
-- Game wordings: "Equip: Increases your attack speed by N%.", "...your casting speed by N%.", "...your attack
-- speed and casting speed by N%." and "Equip: Reduces chance to be Dodged or Parried by N%."
local M = dofile(ADDON_PATH .. "/tests/r4a_ia_mock.lua")
M.load("WARRIOR")

local INT = "ITEM_MOD_INTELLECT_SHORT"
local function ring(id, name, st, tip) return M.def(id, { name = name, loc = "INVTYPE_FINGER", c = 4, s = 0, stats = st, tip = tip, price = 100 }) end
M.equipped[11] = ring(1, "Int Ring A", { [INT] = 1 })
M.equipped[12] = ring(2, "Int Ring B", { [INT] = 1 })

local attackHaste = ring(10, "Quick Band", {}, { "Equip: Increases your attack speed by 2%." })
local castHaste = ring(11, "Swift Band", {}, { "Equip: Increases your casting speed by 2%." })
local bothHaste = ring(12, "Hasty Band", {}, { "Equip: Increases your attack speed and casting speed by 2%." })
local expertise = ring(13, "Precise Band", {}, { "Equip: Reduces chance to be Dodged or Parried by 1%." })
local proc = ring(14, "Proc Band", {}, { "Chance on hit: Increases your attack speed by 20% for 10 sec." })

-- 1. The raw stats page names what the tooltip gave.
local out = M.slash("stats " .. attackHaste)
assert(out:find("2% haste (attack)", 1, true), "attack speed is physical haste: " .. out)
out = M.slash("stats " .. castHaste)
assert(out:find("2% haste (spell)", 1, true), "casting speed is spell haste: " .. out)
out = M.slash("stats " .. bothHaste)
assert(out:find("2% haste (any)", 1, true), "attack and casting speed is both: " .. out)
out = M.slash("stats " .. expertise)
assert(out:find("1% exp (attack)", 1, true), "dodged or parried is expertise: " .. out)
out = M.slash("stats " .. proc)
assert(not out:find("haste", 1, true), "a proc is not a stat line: " .. out)

-- 2. A warrior values them; spell haste isn't for him.
M.want(attackHaste, "EQUIP:", "warrior: attack speed haste counts")
M.want(bothHaste, "EQUIP:", "warrior: attack and casting speed counts")
M.want(expertise, "EQUIP:", "warrior: expertise counts")
M.want(castHaste, "Not an upgrade", "warrior: casting speed doesn't count")
M.wantNot(proc, "EQUIP:", "warrior: a proc isn't scored as haste")

-- 3. A mage is the other way round.
M.login("MAGE")
M.want(castHaste, "EQUIP:", "mage: casting speed counts")
M.want(bothHaste, "EQUIP:", "mage: attack and casting speed counts")
M.want(attackHaste, "Not an upgrade", "mage: attack speed doesn't count")
M.want(expertise, "Not an upgrade", "mage: expertise doesn't count")

-- 4. Every physical profile has a haste weight, so the new lines are never worth 0 to them.
M.login("SHAMAN")
M.slash("role enhancement")
M.want(attackHaste, "EQUIP:", "enhancement values haste")
M.login("PALADIN")
M.slash("role retribution")
M.want(attackHaste, "EQUIP:", "retribution values haste")
M.slash("role tank")
M.want(attackHaste, "EQUIP:", "paladin tank values a little haste")
M.want(expertise, "EQUIP:", "paladin tank values expertise")
M.login("DRUID")
M.slash("role feral")
M.want(attackHaste, "EQUIP:", "feral values haste")
M.slash("role tank")
M.want(attackHaste, "EQUIP:", "bear values a little haste")

-- 5. The game's own stat list wins: a haste rating there isn't counted twice with the tooltip line.
M.login("WARRIOR")
local both = ring(20, "Listed Band", { ITEM_MOD_HASTE_RATING_SHORT = 20 }, { "Equip: Increases your attack speed by 2%." })
out = M.slash("stats " .. both)
assert(out:find("ITEM_MOD_HASTE_RATING_SHORT = 20", 1, true), out)
assert(#M.handled == 0, "no errors: " .. table.concat(M.handled, "\n"))
print("test_r4a_ia_percent: ok")
