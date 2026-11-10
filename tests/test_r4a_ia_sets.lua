-- Round 4 R8: the equipment-set check respects random suffixes. "X of the Monkey" isn't kept because a set holds
-- "X of the Owl" (same base item ID). Bag copies are asked by slot (C_Container.GetContainerItemEquipmentSetInfo);
-- other copies only count when an identical variant is worn in the set's slot or sits in a set bag slot.
local M = dofile(ADDON_PATH .. "/tests/r4a_ia_mock.lua")
M.load("WARRIOR")

local STR, AGI, INT = "ITEM_MOD_STRENGTH_SHORT", "ITEM_MOD_AGILITY_SHORT", "ITEM_MOD_INTELLECT_SHORT"
local function legs(suffix, name, st) return M.def(100, { name = name, loc = "INVTYPE_LEGS", c = 4, s = 4, stats = st, price = 500 }, suffix) end
local owl = legs("-14", "Ridge Legs of the Owl", { [INT] = 5 })
local monkey = legs("-6", "Ridge Legs of the Monkey", { [AGI] = 1 })
local plain = M.def(200, { name = "Plain Belt", loc = "INVTYPE_WAIST", c = 4, s = 4, stats = { [INT] = 1 }, price = 50 })
M.equipped[7] = M.def(300, { name = "Good Legs", loc = "INVTYPE_LEGS", c = 4, s = 4, stats = { [STR] = 10 } })
M.equipped[6] = M.def(301, { name = "Good Belt", loc = "INVTYPE_WAIST", c = 4, s = 4, stats = { [STR] = 10 } })

-- The set holds the Owl legs (in bag slot 1) and the plain belt (in bag slot 3).
M.sets[1] = { [7] = 100, [6] = 200 }
M.bag[1], M.bag[2], M.bag[3] = owl, monkey, plain
M.setSlots["0:1"], M.setSlots["0:3"] = true, true

M.want(owl, "KEEP: In one of your equipment sets", "the set's own variant is kept")
M.wantNot(monkey, "equipment set", "another suffix of the same item is not in the set")
M.want(plain, "KEEP: In one of your equipment sets", "an item without a suffix still matches by ID")

-- A vendor's or reward's Monkey copy (not in bags) is not a set item either.
M.bag[2] = nil
M.wantNot(monkey, "equipment set", "a Monkey copy you don't own isn't in the set")

-- Worn in the set's slot: the worn variant counts, another variant doesn't.
M.bag[1] = nil
M.setSlots["0:1"] = nil
M.equipped[7] = owl
M.want(owl, "In one of your equipment sets", "worn Owl in the set's slot")
M.wantNot(monkey, "equipment set", "Monkey while Owl is worn")

-- Without the bag API the old ID match is the fallback for items without a suffix, and suffixed items
-- need the worn proof.
C_Container.GetContainerItemEquipmentSetInfo = nil
M.event("BAG_UPDATE_DELAYED")
M.flush()
M.want(plain, "In one of your equipment sets", "no bag API: plain item by ID")
M.wantNot(monkey, "equipment set", "no bag API: Monkey still not in the set")
assert(#M.handled == 0, "no errors: " .. table.concat(M.handled, "\n"))
print("test_r4a_ia_sets: ok")
