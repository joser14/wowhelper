-- QuestCheck: Forever's Classic preset (quest markers off on the map) is said once per character and on
-- the Quests page; Enhanced, or a client without the call, says nothing.
local base = ADDON_PATH
local out, frames = {}, {}
ForeverHub_Receive = function(_, t) out[#out + 1] = t end
issecretvalue = function() return false end
CreateFrame = function()
    local f = {}
    f.RegisterEvent = function() end
    f.SetScript = function(self, _, fn) self.fn = fn end
    frames[#frames + 1] = f
    return f
end
SlashCmdList = {}
C_QuestLog = {
    GetNumQuestLogEntries = function() return 0, 0 end,
    GetMaxNumQuestsCanAccept = function() return 25 end,
}
local preset = 0
C_GameRules = { GetForeverExperiencePreset = function() return preset end }
assert(loadfile(base .. "/QuestCheck/QuestCheck.lua"))("QuestCheck", {})
local f = frames[1]
local function fire(e) f.fn(f, e) end
local function said() return table.concat(out, "\n"):find("Classic preset", 1, true) ~= nil end

fire("PLAYER_ENTERING_WORLD")
assert(said(), "Classic: said at login")
out = {}
fire("PLAYER_ENTERING_WORLD")
assert(not said(), "once per character")
SlashCmdList.QUESTCHECK("")
assert(said(), "the Quests page says it")
out = {}
preset = 1
SlashCmdList.QUESTCHECK("")
assert(not said(), "Enhanced: nothing")
C_GameRules = nil
QuestCheckCharDB = nil
fire("PLAYER_ENTERING_WORLD")
SlashCmdList.QUESTCHECK("")
assert(not said(), "no call on this client: nothing, no error")
print("ALL TESTS PASSED")
