-- Dungeons: a name reported a little differently still matches its boss, but a kill of one boss on
-- our list never shows as a kill of another. "The Baron" (Ruins of Lordaeron) is part of "Baron
-- Silverlaine" (Shadowfang Keep), "Baron Aquanis", "Baroness Anastari" and "Baron Rivendare".
-- Run:  node run.js "<workspace root>" test_logic_hub_dungeons.lua
local base = ADDON_PATH
local out, frames, failures = {}, {}, {}
local function check(cond, why) if not cond then failures[#failures + 1] = why .. "\n  output was:\n  " .. table.concat(out, "\n  ") end end
SlashCmdList = {}
CreateFrame = function()
    local f = {}
    f.RegisterEvent = function() end
    f.SetScript = function(self, _, fn) self.fn = fn end
    frames[#frames + 1] = f
    return f
end
ForeverHub_Receive = function(_, t) out[#out + 1] = t end
local now = 100
GetTime = function() return now end
UnitName = function() return "Ana" end
GetRealmName = function() return "Realm" end
UnitLevel = function() return 30 end
UnitClass = function() return "Mage", "MAGE" end
C_QuestLog = {
    IsQuestFlaggedCompleted = function() return false end,
    GetLogIndexForQuestID = function() return nil end,
    IsComplete = function() return false end,
}
C_Item = { GetItemCount = function() return 0 end }

assert(loadfile(base .. "/Dungeons/Data.lua"))("Dungeons", {})
assert(loadfile(base .. "/Dungeons/Dungeons.lua"))("Dungeons", {})
local f = frames[1]
local function fire(ev, ...) f.fn(f, ev, ...) end
local function has(text) for _, t in ipairs(out) do if t:find(text, 1, true) then return true end end return false end
local function page(arg)
    out = {}
    local ok, err = pcall(SlashCmdList.DUNGEONS, arg)
    if not ok then out[#out + 1] = "<<ERROR: " .. tostring(err) .. ">>" end
end
fire("PLAYER_LOGIN")

-- Baron Silverlaine killed in Shadowfang Keep: The Baron in Ruins of Lordaeron is still to do.
fire("BOSS_KILL", 1, "Baron Silverlaine")
page("sfk")
check(has("|cff33ff33Baron Silverlaine|r"), "Silverlaine shows as killed on the SFK page")
page("ruins")
check(has("(none killed on this character yet)"), "a Silverlaine kill is not a kill of The Baron")
check(not has("|cff33ff33The Baron|r"), "The Baron not ticked")

-- Now The Baron himself: Baron Aquanis (Blackfathom Deeps) and Baron Rivendare stay unkilled.
now = now + 100
fire("BOSS_KILL", 2, "The Baron")
page("ruins")
check(has("|cff33ff33The Baron|r"), "The Baron ticked after his own kill")
page("bfd")
check(has("(none killed on this character yet)"), "a The Baron kill is not a kill of Baron Aquanis")
page("strat ud")
check(has("(none killed on this character yet)"), "nor of Baroness Anastari or Baron Rivendare")

-- A title the game adds or drops still matches (not another boss on our list).
fire("BOSS_KILL", 3, "Taragaman")
page("rfc")
check(has("|cff33ff33Taragaman the Hungerer|r"), "partial name still matches")

if #failures > 0 then
    error(#failures .. " check(s) failed:\n\n" .. table.concat(failures, "\n\n"), 0)
end
print("ALL TESTS PASSED")
