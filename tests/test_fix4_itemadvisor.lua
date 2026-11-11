-- Review 4 note 11 and perf audit 5 (ItemAdvisor):
-- 11. The reward coin ("sells for the most") stays when the only unscored thing is the item you wear: the choice
--     itself was scored ("Looks better, but your current item has stats I can't score").
-- 5.  QUEST_LOG_UPDATE no longer walks the quest log every time: a burst is read once (debounced), and a tooltip
--     or bag check right after the event still sees the new quest items (read on demand).
local M = dofile(ADDON_PATH .. "/tests/r4a_ia_mock.lua")
local objectives, objectiveReads = {}, 0
C_QuestLog = {
    GetNumQuestLogEntries = function() return 1 end,
    GetInfo = function() return { title = "Wolf Hunt", questID = 5 } end,
    GetQuestObjectives = function() objectiveReads = objectiveReads + 1; return objectives end,
}
M.load("WARRIOR")
M.flush()

local STR, INT = "ITEM_MOD_STRENGTH_SHORT", "ITEM_MOD_INTELLECT_SHORT"
M.equipped[5] = M.def(1, { name = "Odd Vest", loc = "INVTYPE_CHEST", stats = { [STR] = 2, ITEM_MOD_ODD_THING_SHORT = 5 } })
M.equipped[11] = M.def(2, { name = "Str Ring A", loc = "INVTYPE_FINGER", stats = { [STR] = 9 } })
M.equipped[12] = M.def(3, { name = "Str Ring B", loc = "INVTYPE_FINGER", stats = { [STR] = 9 } })
M.equipped[13] = M.def(4, { name = "Str Trinket A", loc = "INVTYPE_TRINKET", stats = { [STR] = 9 } })
M.equipped[14] = M.def(5, { name = "Str Trinket B", loc = "INVTYPE_TRINKET", stats = { [STR] = 9 } })
local vest = M.def(10, { name = "Strong Vest", loc = "INVTYPE_CHEST", stats = { [STR] = 30 }, price = 100 })
local ring = M.def(11, { name = "Dear Int Ring", loc = "INVTYPE_FINGER", stats = { [INT] = 1 }, price = 900 })
local trinket = M.def(12, { name = "Odd Idol", loc = "INVTYPE_TRINKET", stats = {}, tip = { "Use: Heals you." }, price = 50 })

local function open(choices)
    M.rewards = choices
    M.toasts = {}
    M.event("QUEST_FINISHED")
    M.event("QUEST_COMPLETE")
    M.flush()
    return M.rewardMarks(), table.concat(M.toasts, "\n")
end

-- 11. The vest is scored; only the worn vest has a stat we can't weigh.
M.want(vest, "your current item has stats I can't score", "sanity: worn item unscored")
local marks = open({ { link = vest }, { link = ring } })
assert(marks[2] and marks[2].coin, "coin on the dearer choice when only the worn item is unscored")
-- A choice that itself can't be scored still hides the coin.
marks = open({ { link = vest }, { link = ring }, { link = trinket } })
for index, mark in pairs(marks) do
    assert(not mark.coin, "no coin when a choice can't be scored (choice " .. index .. ")")
end
M.event("QUEST_FINISHED")
print("11 ok")

-- 5. A burst of quest log updates: no walk per event; one after the burst.
M.flush()
objectiveReads = 0
for _ = 1, 20 do M.event("QUEST_LOG_UPDATE") end
assert(objectiveReads == 0, "no walk per event: " .. objectiveReads)
M.flush()
assert(objectiveReads == 1, "one walk after the burst: " .. objectiveReads)
-- Read on demand: a tooltip right after the event sees the new quest item.
local meat = M.def(30, { name = "Wolf Meat", c = 7, price = 5 })
M.wantNot(meat, "Needed for", "not needed yet")
objectives = { { type = "item", text = "0/5 Wolf Meat" } }
M.event("QUEST_LOG_UPDATE")
M.want(meat, "Needed for Wolf Hunt", "tooltip right after the event")
-- Dropping the quest: also seen at once.
objectives = {}
M.event("QUEST_LOG_UPDATE")
M.wantNot(meat, "Needed for", "quest gone")
M.flush()
assert(#M.handled == 0, "no errors: " .. table.concat(M.handled, "\n"))
print("test_fix4_itemadvisor: ok")
