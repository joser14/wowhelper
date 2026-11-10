-- Builds: data validation, next talent from exact points and from steps, goal saved per character,
-- legacy talent API -> C_SpecializationInfo fallback, no talent API at all, secret values, the status
-- row only with unspent points, and alt-class lookup. After the research merge: every points list is
-- checked (<= 51 points, levels from 10 never going down, ranks counting up, split and key talents
-- consistent), order provenance (orderFrom) on the page, and the Druid Balance build as goal dps2.
-- Run from the harness folder:  node run.js "<workspace root>" test_builds.lua
local base = ADDON_PATH
local out, frames, failures, chat = {}, {}, {}, {}
local SECRET = {}
ForeverHub_Receive = function(source, t)
    assert(source == "Builds", "source " .. tostring(source))
    out[#out + 1] = t
end
issecretvalue = function(v) return v == SECRET end
DEFAULT_CHAT_FRAME = { AddMessage = function(_, t) chat[#chat + 1] = t end }
local realPrint = print
print = function(...) chat[#chat + 1] = table.concat({ ... }, " ") end
local learned = 0
LearnTalent = function() learned = learned + 1 end
LearnTalents = LearnTalent
C_ClassTalents = { CommitConfig = LearnTalent, GetActiveConfigID = function() return nil end }
CreateFrame = function()
    local f = { registered = {} }
    f.RegisterEvent = function(self, e) self.registered[e] = true end
    f.SetScript = function(self, _, fn) self.fn = fn end
    frames[#frames + 1] = f
    return f
end
SlashCmdList = {}

local guid = "Player-1-0001"
UnitName = function() return "Tess", "Tester" end
UnitGUID = function() return guid end
GetRealmName = function() return "R" end
local classFile, level, unspent = "WARLOCK", 15, 1
UnitClass = function() return classFile == "WARLOCK" and "Warlock" or classFile, classFile end
UnitLevel = function() return level end
UnitCharacterPoints = function() return unspent end

-- Talent trees: tabs[t] = { name, talents = { { name, rank, maxRank } } }.
local tabs
local function setTrees(t) tabs = t end
local legacyCalls, specCalls = 0, 0
local function installLegacy()
    GetNumTalentTabs = function() return #tabs end
    GetTalentTabInfo = function(t) return tabs[t] and tabs[t].name, "icon", 0 end
    GetNumTalents = function(t) return tabs[t] and #tabs[t].talents or 0 end
    GetTalentInfo = function(t, i)
        legacyCalls = legacyCalls + 1
        local talent = tabs[t] and tabs[t].talents[i]
        if talent then return talent[1], "icon", 1, 1, talent[2], talent[3] end
    end
end
local function installSpec()
    C_SpecializationInfo = {
        GetActiveSpecGroup = function() return 1 end,
        GetTalentInfo = function(q)
            specCalls = specCalls + 1
            assert(q.groupIndex == 1, "group index passed")
            local talent = tabs[q.specializationIndex] and tabs[q.specializationIndex].talents[q.talentIndex]
            if talent then return { name = talent[1], rank = talent[2], maxRank = talent[3], tier = 1, column = 1 } end
        end,
        GetSpecializationInfo = function(t) return 100 + t, tabs[t] and tabs[t].name end,
    }
end
installLegacy()
installSpec()

local function load(name)
    assert(loadfile(base .. "/Builds/" .. name))("Builds", {})
end
load("Data.lua")
load("Builds.lua")
local events = frames[1]

local function dump() return "\n  page:\n    " .. table.concat(out, "\n    ") end
local function check(cond, why) if not cond then failures[#failures + 1] = why .. dump() end end
local function page(arg) out = {}; SlashCmdList.BUILDS(arg or ""); return table.concat(out, "\n") end
local function has(text, needle) return text:find(needle, 1, true) ~= nil end
local function fire(e) events.fn(events, e) end
local function status() return ForeverHubStatus.Builds() end

-- 0. Registration: slash, events.
check(SLASH_BUILDS1 == "/builds" and type(SlashCmdList.BUILDS) == "function", "slash command")
for _, e in ipairs({ "PLAYER_LEVEL_UP", "CHARACTER_POINTS_CHANGED", "PLAYER_TALENT_UPDATE", "SPELLS_CHANGED" }) do
    check(events.registered[e], "registers " .. e)
end

-- 1. Data validation.
local CLASSES = { "WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST", "SHAMAN", "MAGE", "WARLOCK", "DRUID" }
local ALLOWED_ROLES = {
    WARRIOR = { tank = true, dps = true }, PALADIN = { tank = true, healer = true, dps = true }, HUNTER = { dps = true },
    ROGUE = { dps = true }, PRIEST = { healer = true, dps = true }, SHAMAN = { healer = true, dps = true, tank = true },
    MAGE = { dps = true }, WARLOCK = { dps = true }, DRUID = { tank = true, healer = true, dps = true, dps2 = true },
}
local pointsBuilds, fullBuilds, stepsBuilds = 0, 0, {}
local function validBuild(build, where)
    check(type(build) == "table", where .. " is a table")
    if type(build) ~= "table" then return end
    for _, field in ipairs({ "name", "source", "checked", "confidence", "summary", "spec" }) do
        check(type(build[field]) == "string" and build[field] ~= "", where .. " has " .. field)
    end
    check(({ low = true, medium = true, high = true })[build.confidence], where .. " confidence word")
    check(build.checked:match("^%d%d%d%d%-%d%d%-%d%d$"), where .. " checked is a date")
    check(build.source:match("^https://"), where .. " source is a link")
    check(type(build.points) == "table" or type(build.steps) == "table", where .. " has points or steps")
    -- Optional fields from the research files.
    check(build.orderFrom == nil or build.orderFrom == "source" or build.orderFrom == "constructed", where .. " orderFrom word")
    check(build.split == nil or (type(build.split) == "string" and build.split:match("^%d+/%d+/%d+$")), where .. " split is a/b/c")
    check(build.sourceDate == nil or type(build.sourceDate) == "string", where .. " sourceDate is text")
    if build.points then
        pointsBuilds = pointsBuilds + 1
        -- Levels start at 10 and never go down; each talent's ranks count 1, 2, 3...; at most 51 points by 60.
        local last, ranks, perTree = 10, {}, {}
        for i, p in ipairs(build.points) do
            check(type(p.talent) == "string" and type(p.tree) == "string" and type(p.rank) == "number" and type(p.level) == "number", where .. " point " .. i)
            check(p.level >= last, where .. " point " .. i .. " level " .. tostring(p.level) .. " is not below " .. last)
            last = p.level
            ranks[p.talent] = (ranks[p.talent] or 0) + 1
            check(p.rank == ranks[p.talent], where .. " ranks count up for " .. tostring(p.talent))
            perTree[p.tree] = (perTree[p.tree] or 0) + 1
        end
        check(#build.points <= 51 and last <= 60, where .. " at most 51 points to 60: " .. #build.points)
        check(build.points[1] == nil or build.points[1].level >= 10, where .. " first point at 10 or later")
        if #build.points == 51 then fullBuilds = fullBuilds + 1 end
        -- The split, when given, matches the points per tree.
        if build.split then
            local sum = 0
            for n in build.split:gmatch("%d+") do sum = sum + tonumber(n) end
            check(sum == #build.points, where .. " split adds up to the points: " .. build.split)
            local biggest = 0
            for _, n in pairs(perTree) do biggest = math.max(biggest, n) end
            check(has(build.split, tostring(biggest)), where .. " split names the main tree's points")
        end
        local onPoints = {}
        for _, p in ipairs(build.points) do onPoints[p.talent] = true end
        for _, k in ipairs(build.keyTalents or {}) do
            check(onPoints[k], where .. " key talent is in the points: " .. k)
        end
    else
        stepsBuilds[#stepsBuilds + 1] = where
    end
    for i, s in ipairs(build.steps or {}) do
        check(type(s.from) == "number" and type(s.to) == "number" and s.from <= s.to and type(s.text) == "string", where .. " step " .. i)
    end
    for _, field in ipairs({ "keyTalents", "stats", "train" }) do
        for i, v in ipairs(build[field] or {}) do
            check(type(v) == "string" and v ~= "", where .. " " .. field .. " " .. i .. " is a string")
        end
    end
    check(type(build.stats) == "table" and #build.stats > 0, where .. " has stats")
end
for _, c in ipairs(CLASSES) do
    local data = BuildsData[c]
    check(type(data) == "table", c .. " has builds")
    if data then
        validBuild(data.leveling, c .. ".leveling")
        validBuild(data.pvp, c .. ".pvp")
        check(type(data.leveling.train) == "table" and #data.leveling.train > 0, c .. " leveling has trainer notes")
        if data.pvp2 then validBuild(data.pvp2, c .. ".pvp2") end
        check(type(data.pve) == "table" and next(data.pve) ~= nil, c .. " has pve roles")
        for role, build in pairs(data.pve or {}) do
            check(ALLOWED_ROLES[c][role], c .. " role makes sense: " .. role)
            validBuild(build, c .. ".pve." .. role)
        end
        check(data.pve and data.pve.dps or c == "PALADIN" or c == "PRIEST" or c == "DRUID" or c == "SHAMAN", c .. " can deal damage")
    end
end
for key in pairs(BuildsData) do
    local known = false
    for _, c in ipairs(CLASSES) do known = known or c == key end
    check(known, "unknown class key " .. key)
end
-- After the research merge every build is an exact 51-point list except Warlock's Soul Link PvP (steps).
check(#stepsBuilds == 1 and stepsBuilds[1] == "WARLOCK.pvp2", "only Warlock pvp2 is steps: " .. table.concat(stepsBuilds, ", "))
check(pointsBuilds == 40 and fullBuilds == pointsBuilds, "points builds have 51 points: " .. fullBuilds .. "/" .. pointsBuilds)
check(BuildsData.DRUID.pve.dps2 and BuildsData.DRUID.pve.dps2.spec == "Balance" and BuildsData.DRUID.pve.dps2.split == "41/0/10", "druid balance as dps2")

-- 2. Next talent from exact points (warlock leveling), legacy API.
setTrees({
    { name = "Affliction", talents = { { "Improved Corruption", 5, 5 }, { "Suppression", 2, 5 }, { "Improved Drains", 0, 3 } } },
    { name = "Demonology", talents = { { "Unholy Power", 0, 5 }, { "Fel Vitality", 1, 3 } } },
    { name = "Destruction", talents = { { "Improved Shadow Bolt", 0, 5 } } },
})
level, unspent = 18, 1
local p = page()
check(has(p, "Warlock") and has(p, "Leveling") and has(p, "Affliction leveling"), "class, goal, build name")
check(has(p, "high confidence") and has(p, "2026-11-09") and has(p, "warcrafttavern.com"), "confidence, date, source")
check(has(p, "order: from guide"), "order provenance shown")
check(has(p, "Forever is new") and has(p, "class tuning for 2026-11-10"), "early-builds and tuning note")
check(has(p, "Next talent:|r Suppression (Affliction, rank 3)"), "next talent from points")
check(has(p, "Off-build points: Fel Vitality (1)") and has(p, "fine if you chose them"), "off-build points")
check(not has(p, "Improved Corruption (5)"), "build talents not off-build")
check(has(p, "Stats: Spell Power > Shadow Damage"), "stat priority")
check(has(p, "Trainer, near your level: Summon Sayaad (20)"), "trainer line near level 18")
level = 12
check(has(page(), "Trainer, near your level: Summon Voidwalker (10), Drain Life (14)") and not has(page(), "Felhunter"), "trainer reminders near level")
level = 25
check(not has(page(), "Trainer"), "no trainer line when nothing is near level 25")
level = 18
check(has(p, "Unspent talent points: 1"), "unspent count")
check(has(p, "|TInterface\\RaidFrame\\ReadyCheck-Ready:0|tImproved Corruption") and has(p, "|cff999999Pandemic|r"), "key talents with checks")
check(legacyCalls > 0 and specCalls == 0, "legacy API used first")
local rows = status()
check(rows and #rows == 1 and rows[1].text == "|cff88bbeeTalent|r take Suppression next" and rows[1].page == "Builds", "status row with unspent points")
-- Cached until an event.
tabs[1].talents[2][2] = 5
check(status()[1].text:find("Suppression", 1, true), "status cached")
fire("CHARACTER_POINTS_CHANGED")
check(status()[1].text:find("Unholy Power", 1, true), "refreshed after points change: " .. tostring(status() and status()[1].text))
check(has(page(), "Unholy Power (Demonology, rank 1)"), "next talent crosses trees")
unspent = 0
fire("PLAYER_LEVEL_UP")
check(status() == nil, "no row without unspent points")
unspent = 1
fire("PLAYER_TALENT_UPDATE")
check(status() ~= nil, "row back")

-- 3. Fallback: legacy global missing, then legacy global erroring -> C_SpecializationInfo.
local savedLegacy = GetTalentInfo
GetTalentInfo = nil
legacyCalls, specCalls = 0, 0
p = page()
check(specCalls > 0 and has(p, "Next talent:|r Unholy Power (Demonology, rank 1)"), "C_SpecializationInfo fallback")
GetTalentInfo = function() error("not here") end
GetTalentTabInfo, GetNumTalents, GetNumTalentTabs = nil, nil, nil
p = page()
check(has(p, "Next talent:|r Unholy Power (Demonology, rank 1)"), "fallback when legacy errors, tab names from spec info")
GetTalentInfo = savedLegacy
installLegacy()

-- 4. Both talent APIs missing: page still works.
local savedSpec = C_SpecializationInfo
GetTalentInfo, C_SpecializationInfo = nil, nil
level = 18
p = page()
check(has(p, "Affliction leveling") and has(p, "can't be read"), "page without talent API")
check(has(p, "At level 18 the build takes:|r Suppression (Affliction, rank 4)"), "level's point shown without API")
check(has(p, "Stats:") and not has(p, "Off-build"), "rest of page still there")
fire("SPELLS_CHANGED")
check(status() == nil, "no status row when next talent unknown")
C_SpecializationInfo = savedSpec
installLegacy()

-- 5. Steps build (Warlock Demonology Soul Link PvP, the one build still given as steps).
classFile, level, unspent = "WARLOCK", 22, 2
setTrees({
    { name = "Affliction", talents = { { "Improved Corruption", 0, 5 }, { "Corruption", 1, 1 }, { "Improved Life Tap", 1, 2 },
        { "Improved Bane of Agony", 0, 2 } } },
    { name = "Demonology", talents = { { "Demonic Embrace", 5, 5 }, { "Fel Vitality", 3, 3 }, { "Demonic Aegis", 0, 3 },
        { "Demonic Sacrifice", 0, 1 }, { "Fel Domination", 0, 1 }, { "Soul Link", 0, 1 }, { "Demonic Pact", 0, 1 } } },
    { name = "Destruction", talents = { { "Bane", 1, 5 } } },
})
p = page("pvp2")
check(has(p, "Goal set: PvP (second choice)") and has(p, "Demonology Soul Link PvP"), "goal set to pvp2")
check(has(p, "Next talent:|r Demonic Aegis (Demonology, rank 1)"), "next talent from steps")
check(has(p, "Levels 10-30:|r Demonology: Demonic Embrace"), "current step text")
check(not has(p, "order:"), "steps builds show no order provenance")
-- Fel Vitality is named in the step text, Bane is not; "Corruption" only appears inside "Improved Corruption".
check(has(p, "Off-build points: Corruption (1), Improved Life Tap (1), Bane (1)") and not has(p, "Fel Vitality (3)"), "steps off-build uses step text, longer names win")
fire("PLAYER_LEVEL_UP")
check(status() and status()[1].text == "|cff88bbeeTalent|r take Demonic Aegis next", "status from steps")
-- "Skip ..." talents in a step are off-build even when the step names them.
local stepText = BuildsData.WARLOCK.pvp2.steps[1].text
BuildsData.WARLOCK.pvp2.steps[1].text = stepText .. " Bane is fine."
check(not has(page(), "Bane (1)"), "a talent the step names is on the build")
BuildsData.WARLOCK.pvp2.steps[1].text = stepText .. " Skip Bane."
check(has(page(), "Bane (1)"), "skipped talents are off-build")
BuildsData.WARLOCK.pvp2.steps[1].text = stepText
-- An earlier step left unfinished comes first.
level = 35
tabs[2].talents[1][2] = 3
p = page()
check(has(p, "Next talent:|r Demonic Embrace (Demonology, rank 4)"), "unfinished earlier talent first")
check(has(p, "Levels 31-40:|r Demonology: Demonic Knowledge"), "later step text")
tabs[2].talents[1][2] = 5
-- All picks up to this level taken.
level = 22
for i = 3, 6 do tabs[2].talents[i][2] = tabs[2].talents[i][3] end
p = page()
check(has(p, "this level's picks are taken"), "step done message")
fire("PLAYER_LEVEL_UP")
check(status() == nil, "no row when steps give no named talent")
p = page("leveling")
check(has(p, "Affliction leveling") and BuildsDB[guid].goal == "leveling", "warlock back to leveling")

-- 6. Goal switching, saved per character; points builds.
classFile, level = "WARRIOR", 30
setTrees({ { name = "Arms", talents = { { "Improved Rend", 3, 3 }, { "Deflection", 2, 5 }, { "Improved Charge", 2, 2 } } },
    { name = "Fury", talents = { { "Booming Voice", 1, 5 } } }, { name = "Protection", talents = {} } })
p = page()
check(has(p, "Arms leveling (Icy Veins)") and has(p, "Next talent:|r Improved Overpower (Arms, rank 1)"), "warrior leveling is a points build now")
-- Improved Charge is in the points list but not in keyTalents: it is on the build.
check(has(p, "Off-build points: Booming Voice (1)") and not has(p, "Improved Charge (2)"), "every points talent is on the build")
p = page("pvp")
check(has(p, "Goal set: PvP") and has(p, "Arms battleground (35/16/0)"), "goal set to pvp")
check(has(p, "order: built from final ranks"), "constructed order shown")
local record = BuildsDB[guid]
check(record and record.goal == "pvp" and record.charName == "Tess Tester", "saved under the character key")
p = page("")
check(has(p, "Arms battleground") and has(p, "goal: PvP"), "goal kept")
page("tank")
setTrees({ { name = "Protection", talents = { { "Shield Specialization", 5, 5 }, { "Improved Thunder Clap", 2, 3 } } } })
p = page()
check(has(p, "Off-build points: Improved Thunder Clap (2)") and has(p, "Next talent:|r Anticipation (Protection, rank 1)"), "talent outside the points is off-build")
check(has(p, "order: from guide"), "guide order shown")
page("pvp")
guid = "Player-1-0002"
p = page()
check(has(p, "Arms leveling") and has(p, "default for your level"), "other character has its own goal")
level = 60
setTrees({ { name = "Arms", talents = { { "Deflection", 2, 5 } } }, { name = "Fury", talents = {} },
    { name = "Protection", talents = { { "Shield Specialization", 5, 5 }, { "Anticipation", 5, 5 } } } })
p = page()
check(has(p, "Protection raid") and has(p, "tank"), "level 60 default follows your talents: tank")
p = page("dps")
check(has(p, "Fury dual-wield raid") and BuildsDB["Player-1-0002"].goal == "dps", "dps chosen")
p = page("healer")
check(has(p, "no Dungeons and raids: healer build") and BuildsDB["Player-1-0002"].goal == "dps", "unavailable role not saved")
p = page("dps2")
check(has(p, "no Dungeons and raids: damage (second choice) build") and BuildsDB["Player-1-0002"].goal == "dps", "warrior has no dps2")
guid = "Player-1-0001"
level = 30
check(has(page(), "Arms battleground"), "first character's goal still pvp")
p = page("pvp2")
check(has(p, "no PvP (second choice) build"), "warrior has no pvp2")
p = page("leveling")
check(BuildsDB[guid].goal == "leveling", "back to leveling")
p = page("nonsense")
check(has(p, "Type a goal") and has(p, "dps2"), "help for unknown words")

-- 6b. Druid: Balance as the second damage choice.
classFile, level = "DRUID", 60
guid = "Player-1-0003"
setTrees({ { name = "Balance", talents = { { "Improved Wrath", 5, 5 }, { "Genesis", 2, 5 } } },
    { name = "Feral Combat", talents = { { "Ferocity", 1, 5 } } }, { name = "Restoration", talents = {} } })
p = page()
check(has(p, "Balance raid 41/0/10") and has(p, "default for your level"), "level 60 default follows Balance talents to dps2")
check(has(p, "Next talent:|r Genesis (Balance, rank 3)") and has(p, "order: from guide"), "balance next talent and order")
check(has(p, "Choose a goal: leveling, pvp, pvp2, tank, healer, dps, dps2"), "dps2 offered to druids")
setTrees({ { name = "Balance", talents = {} }, { name = "Feral Combat", talents = { { "Ferocity", 5, 5 }, { "Furor", 5, 5 } } },
    { name = "Restoration", talents = {} } })
check(has(page(), "Cat DPS 8/33/10") , "feral talents still default to cat dps")
p = page("balance")
check(has(p, "Goal set: Dungeons and raids: damage (second choice)") and has(p, "Balance raid") and BuildsDB[guid].goal == "dps2", "balance word picks dps2")
p = page("dps")
check(has(p, "Cat DPS") and has(p, "order: built from final ranks"), "first damage choice still there")
p = page("dps2")
check(has(p, "Balance raid") and BuildsDB[guid].goal == "dps2", "dps2 word")
classFile, level = "PRIEST", 30
p = page("pvp")
check(has(p, "Shadow PvP") and has(p, "order: built from final ranks"), "priest constructed pvp order")
classFile = "WARRIOR"
guid = "Player-1-0001"

-- 7. "all" and alt-class lookup.
p = page("all")
check(has(p, "Warrior builds") and has(p, "Leveling|r: Arms leveling (Icy Veins)") and has(p, "PvP|r: Arms battleground")
    and has(p, "tank|r: Protection raid") and has(p, "damage|r: Fury dual-wield raid") and has(p, "high confidence"), "all builds for your class")
check(#out == 5, "one line each plus title: " .. #out)
p = page("mage")
check(has(p, "Mage builds") and has(p, "Frost leveling, 7 Arcane first") and has(p, "Fire 18/31/2") and has(p, "Stats:"), "alt class builds")
check(not has(p, "Warrior"), "alt page is only that class")
p = page("Druids")
check(has(p, "Druid builds") and has(p, "Restoration PvP") and has(p, "Feral hybrid PvP")
    and has(p, "damage (second choice)|r: Balance raid 41/0/10"), "plural class name, balance listed")
classFile = "WARLOCK"

-- 8. Secret values.
classFile = SECRET
p = page()
check(has(p, "didn't say what class"), "secret class")
fire("PLAYER_LEVEL_UP")
check(status() == nil, "no row with secret class")
classFile, level, unspent = "WARLOCK", 18, SECRET
setTrees({ { name = "Affliction", talents = { { "Improved Corruption", 5, 5 }, { SECRET, 2, 5 } } },
    { name = SECRET, talents = { { "Unholy Power", SECRET, 5 } } } })
p = page()
check(has(p, "Next talent:|r Suppression (Affliction, rank 1)"), "secret name and rank treated as unread")
check(not has(p, "Unspent talent points"), "secret unspent hidden")
fire("CHARACTER_POINTS_CHANGED")
check(status() == nil, "no row with secret unspent")
level = SECRET
unspent = 3
p = page()
check(has(p, "Affliction leveling"), "secret level still renders")
fire("PLAYER_LEVEL_UP")
check(status() ~= nil, "row with secret level")

-- 8b. Forever's talent window: the trait system. The legacy calls return nothing (as in game on
-- 2026-11-09: "Your talents can't be read right now"); talents come from C_Traits, trees from sub-trees.
do
    local savedLegacy, savedSpec2, savedClassTalents = GetTalentInfo, C_SpecializationInfo, C_ClassTalents
    GetTalentInfo = function() return nil end
    C_SpecializationInfo = nil
    classFile, level, unspent = "PRIEST", 11, 1
    -- node = { name, subtree, rank, max, x, y }
    local nodes = {
        [1] = { "Unbreakable Will", 1, 0, 5, 100, 100 }, [2] = { "Wand Specialization", 1, 1, 5, 200, 100 },
        [3] = { "Spirit Tap", 3, 0, 5, 1100, 100 }, [4] = { "Improved Shadow Word: Pain", 3, 0, 2, 1200, 300 },
        [5] = { "Holy Specialization", 2, 0, 5, 600, 100 },
    }
    local subNames = { "Discipline", "Holy", "Shadow Magic" }
    C_ClassTalents = { GetActiveConfigID = function() return 7 end, CommitConfig = LearnTalent }
    C_Traits = {
        GetConfigInfo = function(id) assert(id == 7); return { treeIDs = { 50 } } end,
        GetTreeCurrencyInfo = function() return { { traitCurrencyID = 1, quantity = unspent } } end,
        GetTreeInfo = function() return { titleText = "" } end,
        GetTreeNodes = function(tree) assert(tree == 50); return { 1, 2, 3, 4, 5 } end,
        GetNodeInfo = function(_, id)
            local n = nodes[id]
            return { ID = id, isVisible = true, maxRanks = n[4], currentRank = n[3], activeRank = n[3], posX = n[5], posY = n[6],
                activeEntry = { entryID = id * 10, rank = n[3] }, entryIDs = { id * 10 }, subTreeID = 900 + n[2] }
        end,
        GetEntryInfo = function(_, entryID) return { definitionID = entryID * 10 } end,
        GetDefinitionInfo = function(def) return { spellID = def } end,
        GetSubTreeInfo = function(_, sub) return { name = subNames[sub - 900] } end,
        PurchaseRank = LearnTalent, RefundRank = LearnTalent, CommitConfig = LearnTalent,
    }
    C_Spell = { GetSpellName = function(spell) local n = nodes[spell // 100]; return n and n[1] end }
    p = page()
    check(not has(p, "can't be read"), "trait talents are read")
    check(has(p, "Wand Specialization"), "next talent named from the build")
    local lines = Builds_TalentPanelLines()
    local text = lines and table.concat(lines, "\n") or ""
    check(has(text, "Shadow leveling"), "panel names the build: " .. text)
    check(has(text, "Spend now:"), "panel says to spend the point: " .. text)
    check(has(text, "Wand Specialization 2|r") and has(text, "(Discipline, row 1)"), "panel: next point with tree and row: " .. text)
    check(has(text, "Spirit Tap 1|r") and has(text, "Shadow Magic"), "panel: the points after it: " .. text)
    -- Spent off-build points are called out.
    nodes[5][3] = 2
    fire("TRAIT_NODE_CHANGED")
    text = table.concat(Builds_TalentPanelLines(), "\n")
    check(has(text, "Not in this build:|r Holy Specialization (2)"), "panel flags off-build talents: " .. text)
    nodes[5][3] = 0
    -- The panel beside the talent window: our own frame, Blizzard's window only read.
    local made, shown, point = {}, false, nil
    local function ours()
        local f = setmetatable({}, { __index = function(t, k)
            return function(self, ...)
                if k == "Show" then shown = true elseif k == "Hide" then shown = false
                elseif k == "IsShown" then return shown elseif k == "SetPoint" then point = { ... }
                elseif k == "GetStringHeight" then return 70
                elseif k == "CreateTexture" or k == "CreateFontString" then return ours() end
            end
        end })
        made[#made + 1] = f
        return f
    end
    local savedCreate = CreateFrame
    CreateFrame = function() return ours() end
    UIParent = { GetEffectiveScale = function() return 1 end, GetWidth = function() return 1920 end }
    local blizzOpen = true
    PlayerTalentFrame = setmetatable({
        IsShown = function() return blizzOpen end, GetLeft = function() return 100 end, GetRight = function() return 900 end,
        GetTop = function() return 800 end, GetEffectiveScale = function() return 1 end,
    }, { __index = function(_, k) failures[#failures + 1] = "touched PlayerTalentFrame." .. tostring(k) end })
    local watcher = frames[#frames]
    watcher.fn(watcher, 1)
    check(shown, "panel shown while the talent window is open")
    check(point and point[3] == "BOTTOMLEFT" and point[4] == 904 and point[5] == 800, "panel placed to the right of the window")
    blizzOpen = false
    watcher.fn(watcher, 1)
    check(not shown, "panel hidden with the talent window")
    CreateFrame, UIParent, PlayerTalentFrame = savedCreate, nil, nil
    GetTalentInfo, C_SpecializationInfo, C_ClassTalents, C_Traits, C_Spell = savedLegacy, savedSpec2, savedClassTalents, nil, nil
    classFile = "WARLOCK"
end

-- 9. Read-only and quiet.
check(#chat == 0, "no chat output: " .. table.concat(chat, " | "))
check(learned == 0, "never learns talents")

if #failures > 0 then
    error(#failures .. " check(s) failed:\n\n" .. table.concat(failures, "\n\n"), 0)
end
realPrint("ALL TESTS PASSED")
