-- Review 3 (2026-11-10), AutoQuest:
--  1. A quest window the game pushes by itself (an area-trigger quest: QuestIsFromAreaTrigger() is true)
--     is not one the player opened, so it is never accepted.
--  2. A quest started from an item has no NPC: the "Accepted" note must not name the last NPC you talked to.
-- Run from the harness folder:  node run.js "<workspace root>" test_review3_autoquest.lua
local base = ADDON_PATH
local failures = {}
local function check(cond, why)
    if not cond then failures[#failures + 1] = why end
end

local S = { npc = "Gryan Stoutmantle", areaTrigger = false, now = 1000 }
local calls = {}
local out = {}
local frame
CreateFrame = function()
    frame = { events = {}, scripts = {} }
    function frame:RegisterEvent(e) self.events[e] = true end
    function frame:SetScript(s, fn) self.scripts[s] = fn end
    return frame
end
SlashCmdList = {}
issecretvalue = function() return false end
geterrorhandler = function() return function(e) failures[#failures + 1] = "error: " .. tostring(e) end end
ForeverHub_Receive = function(_, text) out[#out + 1] = text end
GetTime = function() return S.now end
InCombatLockdown = function() return false end
IsShiftKeyDown = function() return false end
UnitName = function(unit) if unit == "npc" then return S.npc end end
UnitIsPlayer = function() return false end
C_QuestLog = {
    IsQuestTrivial = function() return false end,
    IsRepeatableQuest = function() return false end,
}
C_GossipInfo = { GetActiveQuests = function() return {} end, GetAvailableQuests = function() return {} end }
GetQuestID = function() return 100 end
GetTitleText = function() return S.title or "Westfall Stew" end
QuestIsDaily = function() return false end
QuestIsWeekly = function() return false end
QuestGetAutoAccept = function() return false end
QuestIsFromAreaTrigger = function() return S.areaTrigger end
AcceptQuest = function() calls[#calls + 1] = "AcceptQuest" end

assert(loadfile(base .. "/AutoQuest/AutoQuest.lua"))("AutoQuest", {})
local function fire(event)
    calls = {}
    frame.scripts.OnEvent(frame, event)
    return table.concat(calls, " ")
end
local function page()
    out = {}
    SlashCmdList.AUTOQUEST("")
    return table.concat(out, "\n")
end
fire("PLAYER_LOGIN")

-- Control: a quest window you opened at an NPC is accepted.
check(fire("QUEST_DETAIL") == "AcceptQuest", "control: accepted at an NPC")

-- 1. Pushed by the game when you walked into an area: left for you.
S.areaTrigger = true
check(fire("QUEST_DETAIL") == "", "area-trigger quest must not be accepted")
S.areaTrigger = false

-- 2. Started from an item (no NPC): the note doesn't name the earlier NPC.
S.npc, S.title = nil, "A Mysterious Letter"
check(fire("QUEST_DETAIL") == "AcceptQuest", "item-started quest accepted")
local text = page()
check(text:find("Accepted A Mysterious Letter", 1, true), "item quest noted: " .. text)
check(not text:find("Accepted A Mysterious Letter from Gryan Stoutmantle", 1, true),
    "item quest credited to the last NPC: " .. text)
check(text:find("Accepted Westfall Stew from Gryan Stoutmantle", 1, true), "NPC quest still names its giver: " .. text)

-- 3. A finished quest completed from the tracker (no NPC) isn't credited to the last NPC either.
GetQuestMoneyToGet = function() return 0 end
GetNumQuestChoices = function() return 0 end
GetQuestReward = function() calls[#calls + 1] = "GetQuestReward" end
S.npc, S.title = nil, "Remote Hand-in"
check(fire("QUEST_COMPLETE") == "GetQuestReward", "remote turn-in done")
text = page()
check(text:find("Turned in Remote Hand-in", 1, true) and not text:find("Turned in Remote Hand-in to", 1, true),
    "remote turn-in credited to an NPC: " .. text)

if #failures > 0 then
    error(#failures .. " failure(s):\n" .. table.concat(failures, "\n"))
end
print("ALL TESTS PASSED")
