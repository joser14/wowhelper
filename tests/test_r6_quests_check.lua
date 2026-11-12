-- Round 6 #13: QuestCheck's Quests page counts quests done per zone from LevelGuide's QuestDB (race and class
-- filtered, repeatables left out), lists the ones left at your level in your zone, tags "new in Forever"
-- (quest ID 10000 and up), and says what it needs when QuestDB isn't loaded. Also checks the ID rule
-- against the real QuestDB: no quest ID between the last Classic one and Forever's first.
-- Run from the tests folder:  node run.js "<repo root>" test_r6_quests_check.lua
local base = ADDON_PATH
local realPrint = print
local failures = {}
local function check(cond, why) if not cond then failures[#failures + 1] = why end end
local out, frames = {}, {}
ForeverHub_Receive = function(_, t) out[#out + 1] = t end
print = function() failures[#failures + 1] = "print called" end
issecretvalue = function(v) return v == "SECRET" end
CreateFrame = function()
    local f = { registered = {} }
    f.RegisterEvent = function(self, e) self.registered[e] = true end
    f.SetScript = function(self, _, fn) self.fn = fn end
    frames[#frames + 1] = f
    return f
end
SlashCmdList = {}
local done = {}
C_QuestLog = {
    GetNumQuestLogEntries = function() return 0, 0 end,
    GetMaxNumQuestsCanAccept = function() return 25 end,
    GetAllCompletedQuestIDs = function()
        local list = {}
        for id in pairs(done) do list[#list + 1] = id end
        return list
    end,
}
local level, race, class, here = 11, "NightElf", "PRIEST", 1438
UnitLevel = function() return level end
UnitRace = function() return "Night Elf", race end
UnitClass = function() return "Priest", class end
C_Map = { GetBestMapForUnit = function() return here end }

assert(loadfile(base .. "/QuestCheck/QuestCheck.lua"))("QuestCheck", {})
local function page()
    out = {}
    SlashCmdList.QUESTCHECK("")
    return table.concat(out, "\n")
end
local function has(s, text) return s:find(text, 1, true) ~= nil end

-- 1. Without QuestDB: one line saying what's needed, no error.
LevelGuideQuestDB = nil
local s = page()
check(has(s, "Quests done per zone"), "heading shown without QuestDB")
check(has(s, "Forever Guides"), "says LevelGuide's data is needed:\n" .. s)

-- 2. A small QuestDB: Teldrassil (1438) and Darkshore (1439).
--    "level|minLevel|races|classes|givers|enders|prereqs|flags|objectives|title"
LevelGuideQuestDB = {
    maps = { [1438] = "Teldrassil", [1439] = "Darkshore", [1429] = "Elwynn Forest" },
    n = { [1] = "1438:50,50|Giver", [2] = "1439:40,40|Shore Giver", [3] = "1429:30,30|Elwynn Giver" },
    o = { [9] = "1438:10,10|Sign" },
    q = {
        [100] = "2|1|4294967373|0|n1|n1||||Done One",                      -- done
        [101] = "4|2|4294967373|0|n1|n1||||Left Low",                      -- left, at your level
        [102] = "8|5|4294967304|0|o9|n1||||Elf Only",                      -- Night Elf only, from an object
        [103] = "6|4|4294967297|0|n1|n1||||Human Only",                    -- Human only: never counted for an elf
        [104] = "10|8|4294967373|1|n1|n1||||Warrior Only",                 -- warrior class quest
        [105] = "5|1|4294967373|0|n1|n1||R||Repeatable",                   -- repeatable: left out
        [106] = "3|1|4294967373|0|i555|n1||||From An Item",                -- item-started: placed by its ender
        [91723] = "10|7|4294967373|0|n1|n1||||Forever Quest",               -- new in Forever
        [200] = "14|10|4294967373|0|n2|n2||||Shore Early",
        [201] = "18|14|4294967373|0|n2|n2||||Shore Later",                 -- above your level
        [300] = "5|1|0|0|n3|n3||||Elwynn Done",
        [301] = "7|5|0|0|n3|n3||||Elwynn Left",
    },
}
done[100] = true
done[300] = true
s = page()
-- Teldrassil: 100, 101, 102, 104? (no: warrior), 106, 91723 -> 5 quests, 1 done, 4 left.
check(has(s, "Teldrassil: |cffffffff1/5|r done"), "Teldrassil count:\n" .. s)
check(has(s, "4 left at your level"), "Teldrassil left:\n" .. s)
check(has(s, "(you're here)"), "current zone marked")
check(has(s, "[4] Left Low"), "left quests listed")
check(has(s, "[8] Elf Only"), "race quest counted for a Night Elf")
check(has(s, "[3] From An Item"), "an item-started quest is placed by its ender")
check(not has(s, "Human Only"), "Human-only quest not counted for a Night Elf")
check(not has(s, "Warrior Only"), "warrior quest not counted for a priest")
check(not has(s, "Repeatable"), "repeatables left out")
check(has(s, "[10] Forever Quest  |cffc58cffnew in Forever|r"), "Forever quest tagged:\n" .. s)
check(not has(s, "Left Low  |cffc58cff"), "Classic quest not tagged")
check(has(s, "(1 |cffc58cffnew in Forever|r)"), "zone line counts the new ones")
-- Darkshore: 1 left at level 11, 1 for later; Elwynn: 1/2 done, 1 left, finishable now.
check(has(s, "Darkshore: |cffffffff0/2|r done, |cff66ccff1 left at your level|r, |cff999999" .. "1 for later|r"), "Darkshore line:\n" .. s)
check(has(s, "Elwynn Forest: |cffffffff1/2|r done"), "Elwynn line")
check(has(s, "Zones you can finish at your level: ") and has(s, "Elwynn Forest (1)"), "finishable zones:\n" .. s)
check(not s:match("finish at your level:[^\n]*Darkshore"), "Darkshore has quests for later: not finishable yet")
-- Zones sorted by their quest levels: Elwynn before Darkshore.
check(s:find("Elwynn Forest: ", 1, true) < s:find("Darkshore: ", 1, true), "zones in level order")

-- 2b. "Anyone" quests in a Horde city aren't counted for an Alliance character; a Horde character is told the
--     data is Alliance only.
LevelGuideQuestDB.maps[1454] = "Orgrimmar"
LevelGuideQuestDB.n[4] = "1454:50,50|Horde Giver"
LevelGuideQuestDB.q[400] = "5|1|0|0|n4|n4||||Orgrimmar Book"
LevelGuideQuestDB = { maps = LevelGuideQuestDB.maps, n = LevelGuideQuestDB.n, o = LevelGuideQuestDB.o, q = LevelGuideQuestDB.q }
s = page()
check(not has(s, "Orgrimmar"), "Horde city not counted:\n" .. s)
UnitFactionGroup = function() return "Horde" end
s = page()
check(has(s, "Alliance quests only") and not has(s, "Teldrassil:"), "Horde character told")
UnitFactionGroup = function() return "Alliance" end

-- 3. A Human sees the Human quest and not the elf one.
race = "Human"
s = page()
check(has(s, "Human Only") and not has(s, "Elf Only"), "race filter follows the character")
race = "NightElf"

-- 4. Level 20: Darkshore's later quest opens up.
level = 20
s = page()
check(has(s, "Darkshore: |cffffffff0/2|r done, |cff66ccff2 left at your level|r") and not s:match("Darkshore[^\n]*for later"), "levels raise what's open:\n" .. s)
level = 11

-- 5. Fallbacks: GetQuestsCompleted ({ [id] = true }), then IsQuestFlaggedCompleted one by one.
C_QuestLog.GetAllCompletedQuestIDs = nil
GetQuestsCompleted = function() return { [100] = true, [101] = true } end
s = page()
check(has(s, "Teldrassil: |cffffffff2/5|r done"), "GetQuestsCompleted used:\n" .. s)
GetQuestsCompleted = nil
C_QuestLog.IsQuestFlaggedCompleted = function(id) return id == 102 or id == 91723 end
s = page()
check(has(s, "Teldrassil: |cffffffff2/5|r done"), "IsQuestFlaggedCompleted used:\n" .. s)
-- A secret answer counts as not done; a secret map or level doesn't break the page.
C_QuestLog.IsQuestFlaggedCompleted = function() return "SECRET" end
here = "SECRET"
UnitLevel = function() return "SECRET" end
s = page()
check(has(s, "Teldrassil: |cffffffff0/5|r done") and not has(s, "(you're here)"), "secret values ignored:\n" .. s)
UnitLevel = function() return level end
here = 1438

-- 6. Read only: no saved data written, no events added for it.
check(QuestCheckCharDB == nil, "nothing saved by the zone counts")
for e in pairs(frames[1].registered) do check(e == "QUEST_LOG_UPDATE" or e == "PLAYER_ENTERING_WORLD", "unexpected event " .. e) end

-- 7. The real QuestDB: the "new in Forever" rule holds (no quest ID between 9665 and 9999, many above),
--    and a level-11 Night Elf priest gets a sane Teldrassil count.
LevelGuideQuestDB = nil
assert(loadfile(base .. "/LevelGuide/QuestDB.lua"))()
local db = LevelGuideQuestDB
local classicMax, foreverMin, foreverCount = 0, math.huge, 0
for id in pairs(db.q) do
    if id < 10000 then classicMax = math.max(classicMax, id) else foreverMin = math.min(foreverMin, id); foreverCount = foreverCount + 1 end
end
check(classicMax <= 9700, "the Classic IDs end below 9700: " .. classicMax)
check(foreverMin > 60000, "the next quest ID is far above: " .. foreverMin)
check(foreverCount > 100, "QuestDB has Forever quests: " .. foreverCount)
for id, record in pairs(db.q) do
    check(type(id) == "number" and type(record) == "string", "QuestDB record shape")
end
C_QuestLog.IsQuestFlaggedCompleted = nil
C_QuestLog.GetAllCompletedQuestIDs = function() return {} end
local clock = os.clock()
s = page()
local first = os.clock() - clock
clock = os.clock()
page()
local second = os.clock() - clock
local total = s:match("Teldrassil: |cffffffff0/(%d+)|r done")
check(total and tonumber(total) >= 30 and tonumber(total) <= 150, "real Teldrassil total: " .. tostring(total) .. "\n" .. s)
check(has(s, "Darkshore: "), "real Darkshore listed")
check(second <= first + 0.05, "the zone index is built once")

if #failures > 0 then error(table.concat(failures, "\n")) end
realPrint("test_r6_quests_check: ok")
