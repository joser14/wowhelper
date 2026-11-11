-- Final review (hub, guides, quests): the bugs confirmed in that review, each shown failing before its fix.
--   A. ProfessionGuide: a profession window event inside the 2 s wait is read later, not dropped.
--   B. ProfessionGuide: "craft" still lists guide crafts for a profession whose window was never opened.
--   C. AutoQuest: the greeting window never opens a finished repeatable quest for you.
--   D. ForeverHelper: a hidden (secret) rested value keeps the saved one instead of writing 0.
local base = ADDON_PATH
local realPrint = print
local failures = {}
local function check(cond, why) if not cond then failures[#failures + 1] = why end end
local SECRET = setmetatable({}, { __tostring = function() return "SECRET" end })
issecretvalue = function(v) return v == SECRET end

----------------------------------------------------------------------------------------------- A, B
do
    local out, frames, timers = {}, {}, {}
    ForeverHub_Receive = function(_, t) out[#out + 1] = t end
    CreateFrame = function()
        local f = { registered = {} }
        f.RegisterEvent = function(self, e) self.registered[e] = true end
        f.SetScript = function(self, _, fn) self.fn = fn end
        frames[#frames + 1] = f
        return f
    end
    SlashCmdList = {}
    local clock = 100
    GetTime = function() return clock end
    C_Timer = { After = function(seconds, fn) timers[#timers + 1] = { seconds = seconds, fn = fn } end }
    ProfessionGuideDB, ProfessionGuideData = nil, nil
    for _, name in ipairs({ "Data_Tailoring.lua", "Data_FirstAid.lua", "Data_Cooking.lua", "ProfessionGuide.lua" }) do
        assert(loadfile(base .. "/ProfessionGuide/" .. name))("ProfessionGuide", {})
    end
    local scanner = frames[#frames]
    local professions = {
        { name = "Tailoring", rank = 40, maxRank = 75, skillLine = 197 },
        { name = "First Aid", rank = 10, maxRank = 75, skillLine = 129 },
    }
    GetProfessions = function() return 1, 2 end
    GetProfessionInfo = function(index) local p = professions[index]; return p.name, 0, p.rank, p.maxRank, 0, 0, p.skillLine end
    C_SkillInfo = { GetSkillLineInfoByID = function() return nil end }
    local LINEN, BOLT, THREAD = 2589, 2996, 2320
    local bags = { [BOLT] = 5, [THREAD] = 8, [LINEN] = 10 }
    C_Item = { GetItemCount = function(id) return bags[id] or 0 end }
    local recipes = { [101] = { name = "Linen Belt", mats = { { BOLT, 1 }, { THREAD, 1 } } } }
    C_TradeSkillUI = {
        GetAllRecipeIDs = function() local ids = {}; for id in pairs(recipes) do ids[#ids + 1] = id end; table.sort(ids); return ids end,
        GetRecipeInfo = function(id) local r = recipes[id]; return r and { name = r.name, learned = true } end,
        GetRecipeSchematic = function(id)
            local slots = {}
            for _, m in ipairs(recipes[id].mats) do slots[#slots + 1] = { reagents = { { itemID = m[1] } }, quantityRequired = m[2], required = true } end
            return { reagentSlotSchematics = slots }
        end,
        GetBaseProfessionInfo = function() return { professionID = 197, professionName = "Tailoring" } end,
    }
    scanner.fn(scanner, "TRADE_SKILL_SHOW")
    check(ProfessionGuideDB.recipes[101], "A: first read stored")

    -- A. The list fills in a moment later, inside the wait: read once the wait is over.
    recipes[106] = { name = "Linen Cloak", mats = { { BOLT, 1 } } }
    clock = clock + 0.5
    scanner.fn(scanner, "TRADE_SKILL_LIST_UPDATE")
    scanner.fn(scanner, "TRADE_SKILL_LIST_UPDATE")
    check(ProfessionGuideDB.recipes[106] == nil, "A: not read inside the wait")
    check(#timers == 1, "A: one later read planned, got " .. #timers)
    clock = clock + 2
    for _, t in ipairs(timers) do t.fn() end
    check(ProfessionGuideDB.recipes[106] ~= nil, "A: the update inside the wait was read later")

    -- B. First Aid's window was never opened: its guide crafts are still listed, with the hint.
    out = {}
    SlashCmdList.PROFESSIONGUIDE("craft")
    local text = table.concat(out, "\n")
    check(text:find("Linen Belt x5", 1, true), "B: Tailoring recipe from the window:\n" .. text)
    check(text:find("Linen Bandage x10", 1, true), "B: First Aid guide craft listed:\n" .. text)
    check(text:find("First Aid", 1, true) and text:find("Open a profession window once", 1, true), "B: hint names First Aid:\n" .. text)
    C_TradeSkillUI, C_Timer = nil, nil
end

----------------------------------------------------------------------------------------------- C
do
    local frames, selected = {}, {}
    CreateFrame = function()
        local f = {}
        f.RegisterEvent = function() end
        f.SetScript = function(self, _, fn) self.fn = fn end
        frames[#frames + 1] = f
        return f
    end
    SlashCmdList = {}
    ForeverHub_Receive = function() end
    ForeverHub_IsOff = function() return false end
    GetTime = function() return 5000 end
    InCombatLockdown = function() return false end
    IsShiftKeyDown = function() return false end
    UnitName = function(unit) if unit == "npc" then return "Innkeeper" end end
    local repeatable = { [500] = true }
    C_QuestLog = { IsRepeatableQuest = function(id) return repeatable[id] == true end, IsComplete = function() return true end }
    GetNumActiveQuests = function() return 1 end
    GetActiveTitle = function() return "Daily Bread", true end
    GetActiveQuestID = function() return 500 end
    GetNumAvailableQuests = function() return 0 end
    SelectActiveQuest = function(index) selected[#selected + 1] = index end
    SelectAvailableQuest = function() end
    AutoQuestDB = nil
    assert(loadfile(base .. "/AutoQuest/AutoQuest.lua"))("AutoQuest", {})
    local events = frames[#frames]
    events.fn(events, "PLAYER_LOGIN")
    events.fn(events, "QUEST_GREETING")
    check(#selected == 0, "C: a finished repeatable quest isn't opened from the greeting window")
    -- Positive control: a finished one-time quest still is.
    repeatable[500] = nil
    GetActiveQuestID = function() return 501 end
    events.fn(events, "QUEST_GREETING")
    check(#selected == 1, "C: a finished quest is still turned in from the greeting window")
end

----------------------------------------------------------------------------------------------- D
do
    local frames = {}
    local function region()
        return setmetatable({ shown = true }, { __index = function(t, k)
            if k == "IsShown" then return function(self) return self.shown end end
            if k == "SetShown" then return function(self, v) self.shown = v end end
            if k == "SetScript" then return function(self, s, fn) self[s] = fn end end
            if k == "CreateFontString" or k == "CreateTexture" then return function() return region() end end
            return function() end
        end })
    end
    CreateFrame = function() local f = region(); frames[#frames + 1] = f; return f end
    UIParent = region()
    UISpecialFrames = {}
    SlashCmdList = {}
    C_Timer = { NewTicker = function() end, After = function() end }
    GetTime = function() return 100 end
    GetMoney = function() return 500 end
    UnitLevel = function() return 12 end
    UnitXP = function() return 10 end
    UnitXPMax = function() return 1000 end
    UnitName = function() return "Tester" end
    UnitGUID = function() return "Player-1-0001" end
    GetRealmName = function() return "Realm" end
    local rested = 5000
    GetXPExhaustion = function() return rested end
    ForeverHelperDB = nil
    assert(loadfile(base .. "/ForeverHelper/ForeverHelper.lua"))("ForeverHelper", {})
    local events = frames[#frames]
    events.OnEvent(events, "ADDON_LOADED", "ForeverHelper")
    events.OnEvent(events, "PLAYER_LOGIN")
    local char = ForeverHelperDB.characters["Player-1-0001"]
    check(char and char.rested == 5000, "D: rested saved at login")
    rested = SECRET
    events.OnEvent(events, "UPDATE_EXHAUSTION")
    check(char and char.rested == 5000, "D: a hidden rested value keeps the saved one, got " .. tostring(char and char.rested))
    rested = nil
    events.OnEvent(events, "UPDATE_EXHAUSTION")
    check(char and char.rested == 0, "D: no rested XP saves 0")
end

if #failures > 0 then
    realPrint("FAILURES (" .. #failures .. "):")
    for _, why in ipairs(failures) do realPrint(" - " .. why) end
    os.exit(1)
end
realPrint("test_final_hub_fixes: all checks passed")
