local base = ADDON_PATH
local chat, errors, frames = {}, {}, {}
local SECRET = {}
local function reset() chat, errors = {}, {} end

CreateFrame = function()
    local f = { registered = {} }
    f.RegisterEvent = function(self, e) self.registered[e] = true end
    f.SetScript = function(self, _, fn) self.fn = fn end
    frames[#frames + 1] = f
    return f
end
DEFAULT_CHAT_FRAME = { AddMessage = function(_, t) chat[#chat + 1] = t end }
UIErrorsFrame = { AddMessage = function(_, t) errors[#errors + 1] = t end }
SlashCmdList = {}
issecretvalue = function(v) return v == SECRET end
UnitName = function() return "Tester" end
GetRealmName = function() return "Realm" end
local level, class, money, now = 8, "WARRIOR", 0, 1000
UnitLevel = function() return level end
UnitClass = function() return "x", class end
GetMoney = function() return money end
GetTime = function() return now end

local function load(name)
    local n = #frames
    assert(loadfile(base .. "/" .. name .. "/" .. name .. ".lua"))(name, {})
    return frames[n + 1]
end
local function fire(f, ev, ...)
    assert(f.registered[ev], "not registered: " .. ev)
    f.fn(f, ev, ...)
end
local function saw(list, text) for _, t in ipairs(list) do if t:find(text, 1, true) then return true end end return false end
local function need(list, text, why) assert(saw(list, text), why .. ": wanted '" .. text .. "' in:\n" .. table.concat(list, "\n")) end
local function never(list, text, why) assert(not saw(list, text), why .. ": did not want '" .. text .. "' in:\n" .. table.concat(list, "\n")) end

-- ProfessionCap
local slots, profs = {}, {}
GetProfessions = function() return slots[1], slots[2], slots[3], slots[4], slots[5] end
GetProfessionInfo = function(i) local p = profs[i]; return p[1], 0, p[2], p[3], 0, 0, 0 end
local pc = load("ProfessionCap")
fire(pc, "PLAYER_LOGIN")
SlashCmdList.PROFESSIONCAP("")
need(chat, "haven't learned", "no professions")
reset()
slots = { 1, nil, nil, 4, 5 }
profs = { [1] = { "Mining", 75, 75 }, [4] = { "Fishing", 10, 75 }, [5] = { "Cooking", 300, 300 } }
fire(pc, "SKILL_LINES_CHANGED")
need(chat, "Mining is capped at 75/75. Visit a trainer for Journeyman. You may need level 10 first.", "capped, gaps walked")
never(chat, "Fishing", "under cap")
never(chat, "Cooking", "top rank never warns")
assert(#errors == 1, "one warning")
reset(); fire(pc, "SKILL_LINES_CHANGED")
assert(#chat == 0, "warns once")
profs[1] = { "Mining", 75, 150 }; fire(pc, "SKILL_LINES_CHANGED")
assert(#chat == 0, "trained")
profs[1] = { "Mining", 150, 150 }; level = 25; fire(pc, "SKILL_LINES_CHANGED")
need(chat, "Visit a trainer for Expert.", "next tier")
never(chat, "may need level", "already high enough")
reset(); SlashCmdList.PROFESSIONCAP("")
need(chat, "Fishing 10/75", "list")
need(chat, "Cooking 300/300", "list top")
profs[4] = { "Fishing", SECRET, 75 }
reset(); SlashCmdList.PROFESSIONCAP("")
never(chat, "Fishing", "secret skipped")

-- TalentNudge
reset()
local unspent = 2
C_ClassTalents = { GetActiveConfigID = function() return 9 end }
C_Traits = {
    GetConfigInfo = function() return { treeIDs = { 1117, 1117 } } end,
    GetTreeCurrencyInfo = function() return { { traitCurrencyID = 3820, quantity = unspent } } end,
}
local tn = load("TalentNudge")
fire(tn, "PLAYER_LOGIN")
need(chat, "You have 2 unspent", "login, one currency counted once")
reset(); fire(tn, "TRAIT_CONFIG_UPDATED")
assert(#chat == 0, "no nag")
unspent = 3; fire(tn, "PLAYER_LEVEL_UP")
need(chat, "You have 3 unspent", "new point")
reset(); unspent = 0; fire(tn, "PLAYER_TALENT_UPDATE")
assert(#chat == 0, "spending is silent")
unspent = 1; fire(tn, "PLAYER_LEVEL_UP")
need(chat, "You have 1 unspent", "again after spending")
reset(); SlashCmdList.TALENTNUDGE("")
need(chat, "1 unspent", "slash")
C_Traits.GetTreeCurrencyInfo = function() error("boom") end
GetUnspentTalentPoints = function() return 4 end
reset(); fire(tn, "PLAYER_LEVEL_UP")
need(chat, "You have 4 unspent", "error caught, fallback used")
C_ClassTalents, C_Traits, GetUnspentTalentPoints = nil, nil, nil
reset(); SlashCmdList.TALENTNUDGE("")
need(chat, "didn't report", "no API")

-- GoldGoal
reset()
local riding
C_SkillInfo = { GetSkillLineInfoByID = function(id) if id == 762 then return riding end end }
local gg = load("GoldGoal")
SlashCmdList.GOLDGOAL("")
assert(#chat == 0, "nothing before login")
level = 20; money = 340000
fire(gg, "PLAYER_LOGIN")
assert(#chat == 0, "not enough yet")
SlashCmdList.GOLDGOAL("")
need(chat, "Apprentice Riding and a mount: you have 34g 0s of 120g, 86g 0s short.", "apprentice")
need(chat, "Requires level 40. You're level 20.", "level note")
need(chat, "10% off", "discount")
money = 1300000; reset(); fire(gg, "PLAYER_MONEY")
assert(#chat == 0, "can't afford-yet below level 40")
level = 40; fire(gg, "PLAYER_LEVEL_UP")
need(chat, "You can afford Apprentice Riding", "ready at 40")
reset(); fire(gg, "PLAYER_MONEY")
assert(#chat == 0, "tells once")
riding = { rank = 75 }; money = 2000000
reset(); SlashCmdList.GOLDGOAL("")
need(chat, "Journeyman Riding and a mount: you have 200g 0s of 1200g, 1000g 0s short.", "journeyman")
now = now + 3600; money = money + 1000000
reset(); SlashCmdList.GOLDGOAL("")
need(chat, "hour(s) at this session's rate", "eta")
riding = { rank = 150 }
reset(); SlashCmdList.GOLDGOAL("")
need(chat, "No goal set", "riding done")
reset(); SlashCmdList.GOLDGOAL("500 New bags")
need(chat, "New bags: you have 300g 0s of 500g, 200g 0s short.", "custom goal")
never(chat, "10% off", "no discount note on your own goal")
money = 5000000; reset(); fire(gg, "PLAYER_MONEY")
need(chat, "You can afford New bags", "custom reached")
assert(GoldGoalDB["Tester-Realm"].goal.gold == 500, "saved")
reset(); SlashCmdList.GOLDGOAL("clear")
need(chat, "cleared", "clear")
reset(); SlashCmdList.GOLDGOAL("help")
need(chat, "Or: clear", "help")
class = "PALADIN"; riding = nil
reset(); SlashCmdList.GOLDGOAL("")
need(chat, "No goal set", "paladins quest for riding")
class = "WARRIOR"
money = SECRET
reset(); SlashCmdList.GOLDGOAL("")
need(chat, "didn't report your gold", "secret money")
fire(gg, "PLAYER_MONEY")

print("ALL TESTS PASSED")
