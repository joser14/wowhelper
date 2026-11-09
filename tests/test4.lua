C_Container = C_Container or { GetContainerNumSlots = function() return 16 end, GetContainerItemInfo = function() end }
UnitClass = UnitClass or function() return "Warrior", "WARRIOR" end
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

-- WeaponSkillWatch
local equipped, skills = {}, {}
local weapons = { sword = 7, dagger = 15, bow = 2, cloak = false }
GetInventoryItemLink = function(_, slot) return equipped[slot] end
C_Item = {
    GetItemInfoInstant = function(link)
        local sub = weapons[link]
        if sub == false then return 1, "", "", "", 0, 4, 1 end
        return 1, "", "", "", 0, 2, sub
    end,
    GetItemCount = function(id) return ITEM_COUNTS[id] or 0 end,
}
C_SkillInfo = { GetSkillLineInfoByID = function(id) return skills[id] end }
local ws = load("WeaponSkillWatch")
equipped[16] = "sword"
skills[43] = { name = "Swords", rank = 30, maxRank = 100 }
fire(ws, "PLAYER_LOGIN")
need(chat, "Swords is only 30/100 (main hand)", "low skill warned")
reset(); fire(ws, "SKILL_LINES_CHANGED")
assert(#chat == 0, "warns once")
skills[43].rank = 90
fire(ws, "SKILL_LINES_CHANGED")
assert(#chat == 0, "within 15 of the cap is fine")
skills[43].rank = 30
fire(ws, "SKILL_LINES_CHANGED")
need(chat, "Swords is only", "warns again if it falls behind")
reset(); fire(ws, "PLAYER_EQUIPMENT_CHANGED", 1)
assert(#chat == 0, "armor slots don't re-check")
SlashCmdList.WEAPONSKILLWATCH("")
need(chat, "main hand: Swords 30/100", "slash shows equipped")
equipped[16] = "dagger"
reset(); SlashCmdList.WEAPONSKILLWATCH("")
need(chat, "may need to train", "untrained weapon")
fire(ws, "PLAYER_EQUIPMENT_CHANGED", 16)
equipped[16] = nil; reset(); SlashCmdList.WEAPONSKILLWATCH("")
need(chat, "No weapon equipped", "empty hands")
skills[45] = { name = "Bows", rank = 5, maxRank = 5 }
skills[173] = { name = "Daggers", rank = SECRET, maxRank = 100 }
reset(); SlashCmdList.WEAPONSKILLWATCH(" ALL ")
assert(chat[1]:find("Bows 5/5", 1, true) and chat[2]:find("Swords", 1, true), "all sorted: " .. table.concat(chat, "\n"))
never(chat, "Daggers", "secret rank skipped")
equipped[18] = "cloak"
reset(); fire(ws, "PLAYER_EQUIPMENT_CHANGED", 18)
assert(#chat == 0, "non-weapon in a watched slot ignored")
equipped[18] = nil

-- SupplyWatch
reset()
ITEM_COUNTS = {}
local usesAmmo, ammoCount = true, 500
UnitUsesAmmo = function() return usesAmmo end
GetInventoryItemCount = function() return ammoCount end
local sw = load("SupplyWatch")
SlashCmdList.SUPPLYWATCH("")
assert(#chat == 0, "does nothing before login")
fire(sw, "PLAYER_LOGIN")
equipped[0] = "arrows"
fire(sw, "PLAYER_ENTERING_WORLD")
assert(#errors == 0, "plenty of ammo")
ammoCount = 50
fire(sw, "BAG_UPDATE_DELAYED")
need(errors, "Low on Ammo: 50", "low ammo")
reset(); fire(sw, "BAG_UPDATE_DELAYED")
assert(#errors == 0, "warns once")
ammoCount = 500; fire(sw, "BAG_UPDATE_DELAYED")
ammoCount = 10; fire(sw, "BAG_UPDATE_DELAYED")
need(errors, "Low on Ammo: 10", "warns again after restocking")
equipped[0] = nil; ammoCount = 1
reset(); SlashCmdList.SUPPLYWATCH("")
need(chat, "Ammo: 0/200", "empty slot is zero, not the reported 1")
equipped[0] = "arrows"; ammoCount = 500
local link = "|cffffffff|Hitem:159:0:0|h[Refreshing Spring Water]|h|r"
reset(); SlashCmdList.SUPPLYWATCH("add " .. link .. " 20")
need(chat, "Watching Refreshing Spring Water: want 20", "add")
need(errors, "Low on Refreshing Spring Water: 0", "new item checked straight away")
ITEM_COUNTS[159] = 5
reset(); fire(sw, "MERCHANT_SHOW")
need(chat, "Restock Refreshing Spring Water: you have 5, 15 short", "restock list")
never(chat, "Restock Ammo", "ammo is fine")
reset(); SlashCmdList.SUPPLYWATCH("add " .. link .. " 8")
need(chat, "now want 8", "updates, doesn't duplicate")
assert(#SupplyWatchDB["Tester-Realm"].items == 1, "one entry")
reset(); SlashCmdList.SUPPLYWATCH("")
need(chat, "1. Refreshing Spring Water: 5/8", "list")
reset(); SlashCmdList.SUPPLYWATCH("add nonsense")
need(chat, "such as Water 20", "bad add")
SlashCmdList.SUPPLYWATCH("remove 9")
need(chat, "No watched item", "bad remove")
SlashCmdList.SUPPLYWATCH("remove 1")
need(chat, "Stopped watching", "remove")
reset(); SlashCmdList.SUPPLYWATCH("ammo 0")
need(chat, "Ammo warning off", "ammo off")
ammoCount = 1; reset(); fire(sw, "BAG_UPDATE_DELAYED")
assert(#errors == 0, "off means off")
usesAmmo = false
reset(); SlashCmdList.SUPPLYWATCH("")
need(chat, "Nothing watched", "melee character")
SlashCmdList.SUPPLYWATCH("help")

-- QuestCheck
reset()
local quests, maxQuests = {}, 25
local complete, ready, trivial = {}, {}, {}
C_QuestLog = {
    GetNumQuestLogEntries = function()
        local n = 0
        for _, q in ipairs(quests) do if not q.isHeader then n = n + 1 end end
        return #quests, n
    end,
    GetMaxNumQuestsCanAccept = function() return maxQuests end,
    GetInfo = function(i) return quests[i] end,
    IsComplete = function(id) return complete[id] or false end,
    ReadyForTurnIn = function(id) return ready[id] end,
    IsQuestTrivial = function(id) return trivial[id] or false end,
}
local qc = load("QuestCheck")
quests = { { isHeader = true, title = "Elwynn" },
    { questID = 1, title = "Done", level = 5, suggestedGroup = 0 },
    { questID = 2, title = "Old", level = 2, suggestedGroup = 0 },
    { questID = 3, title = "Hogger", level = 11, suggestedGroup = 3 },
    { questID = 4, title = "Hidden", level = 5, suggestedGroup = 0, isHidden = true },
    { questID = 5, title = "Plain", level = 5, suggestedGroup = 0 },
    { questID = 6, title = "TurnIn", level = 5, suggestedGroup = 0 } }
complete[1] = true; trivial[2] = true; trivial[1] = true; ready[6] = true
fire(qc, "QUEST_LOG_UPDATE")
assert(#errors == 0, "plenty of room")
SlashCmdList.QUESTCHECK("")
need(chat, "6/25 quests", "count")
need(chat, "[5] Done", "complete listed")
need(chat, "[5] TurnIn", "ready listed")
need(chat, "[2] Old", "gray listed")
need(chat, "[11] Hogger (group of 3)", "group listed")
never(chat, "Hidden", "hidden skipped")
never(chat, "Plain", "plain skipped")
assert(not saw(chat, "Gray") or chat[6] ~= nil, "headings")
maxQuests = 8
reset(); fire(qc, "QUEST_LOG_UPDATE")
need(errors, "Quest log nearly full: 2 free", "nearly full")
reset(); fire(qc, "QUEST_LOG_UPDATE")
assert(#errors == 0, "warns once")
maxQuests = 25; fire(qc, "QUEST_LOG_UPDATE")
maxQuests = 7; fire(qc, "QUEST_LOG_UPDATE")
need(errors, "Quest log nearly full", "warns again")
maxQuests = SECRET
reset(); fire(qc, "QUEST_LOG_UPDATE")
assert(#errors == 0, "secret maximum ignored")
maxQuests = 25
quests = { { questID = 9, title = "Plain", level = 5, suggestedGroup = 0 } }
reset(); SlashCmdList.QUESTCHECK("")
need(chat, "Nothing to flag", "clean log")

print("ALL TESTS PASSED")
