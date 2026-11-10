-- Round 4 R15: no "sells for the most" coin (nor the gold suggestion) when a reward choice can't be scored, such as
-- an on-use trinket: its effect may be worth more than any vendor price. Idea from Pawn (no code). Price x count
-- stays the measure otherwise.
local M = dofile(ADDON_PATH .. "/tests/r4a_ia_mock.lua")
M.load("WARRIOR")

local STR, INT = "ITEM_MOD_STRENGTH_SHORT", "ITEM_MOD_INTELLECT_SHORT"
M.equipped[11] = M.def(1, { name = "Str Ring A", loc = "INVTYPE_FINGER", stats = { [STR] = 9 } })
M.equipped[12] = M.def(2, { name = "Str Ring B", loc = "INVTYPE_FINGER", stats = { [STR] = 9 } })
M.equipped[13] = M.def(3, { name = "Str Trinket A", loc = "INVTYPE_TRINKET", stats = { [STR] = 9 } })
M.equipped[14] = M.def(4, { name = "Str Trinket B", loc = "INVTYPE_TRINKET", stats = { [STR] = 9 } })
local cheapRing = M.def(10, { name = "Cheap Int Ring", loc = "INVTYPE_FINGER", stats = { [INT] = 1 }, price = 100 })
local dearRing = M.def(11, { name = "Dear Int Ring", loc = "INVTYPE_FINGER", stats = { [INT] = 2 }, price = 900 })
local onUse = M.def(12, { name = "Odd Idol", loc = "INVTYPE_TRINKET", stats = {}, tip = { "Use: Heals you." }, price = 300 })

local function open(choices)
    M.rewards = choices
    M.toasts = {}
    M.event("QUEST_FINISHED")
    M.event("QUEST_COMPLETE")
    M.flush()
    return M.rewardMarks(), table.concat(M.toasts, "\n")
end

-- 1. Both choices scored, neither an upgrade: the dearer one gets the coin, and the toast says so.
local marks, toast = open({ { link = cheapRing }, { link = dearRing } })
assert(marks[2] and marks[2].coin, "coin on the dearer ring")
assert(toast:find("sells for the most", 1, true), "gold suggestion: " .. toast)

-- 2. An on-use trinket among the choices: no coin anywhere, no gold suggestion.
marks, toast = open({ { link = cheapRing }, { link = dearRing }, { link = onUse } })
for index, mark in pairs(marks) do
    assert(not mark.coin, "no coin when a choice can't be scored (choice " .. index .. ")")
end
assert(not toast:find("sells for the most", 1, true), "no gold suggestion: " .. toast)

-- 3. Price x count still decides between stacks.
local potion = M.def(20, { name = "Potion", c = 0, price = 100 })
local elixir = M.def(21, { name = "Elixir", c = 0, price = 150 })
marks = open({ { link = potion, count = 5 }, { link = elixir, count = 1 } })
assert(marks[1] and marks[1].coin, "five potions sell for more than one elixir")
assert(#M.handled == 0, "no errors: " .. table.concat(M.handled, "\n"))
print("test_r4a_ia_rewards: ok")
