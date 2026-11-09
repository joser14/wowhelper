-- Builds: data validation, next talent from exact points and from steps, goal saved per character,
-- legacy talent API -> C_SpecializationInfo fallback, no talent API at all, secret values, the status
-- row only with unspent points, and alt-class lookup.
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
    MAGE = { dps = true }, WARLOCK = { dps = true }, DRUID = { tank = true, healer = true, dps = true },
}
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
    if build.points then
        local last, ranks = 0, {}
        for i, p in ipairs(build.points) do
            check(type(p.talent) == "string" and type(p.tree) == "string" and type(p.rank) == "number" and type(p.level) == "number", where .. " point " .. i)
            check(p.level >= last, where .. " points in level order")
            last = p.level
            ranks[p.talent] = (ranks[p.talent] or 0) + 1
            check(p.rank == ranks[p.talent], where .. " ranks count up for " .. tostring(p.talent))
        end
        check(#build.points <= 51 and last <= 60, where .. " at most 51 points to 60")
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

-- 2. Next talent from exact points (warlock leveling), legacy API.
setTrees({
    { name = "Affliction", talents = { { "Improved Corruption", 5, 5 }, { "Suppression", 2, 5 }, { "Improved Drains", 0, 3 } } },
    { name = "Demonology", talents = { { "Unholy Power", 0, 5 }, { "Fel Vitality", 1, 3 } } },
    { name = "Destruction", talents = { { "Improved Shadow Bolt", 0, 5 } } },
})
level, unspent = 18, 1
local p = page()
check(has(p, "Warlock") and has(p, "Leveling") and has(p, "Affliction leveling"), "class, goal, build name")
check(has(p, "medium confidence") and has(p, "2026-11-09") and has(p, "warcrafttavern.com"), "confidence, date, source")
check(has(p, "Forever is new"), "early-builds note")
check(has(p, "Next talent:|r Suppression (Affliction, rank 3)"), "next talent from points")
check(has(p, "Off-build points: Fel Vitality (1)") and has(p, "fine if you chose them"), "off-build points")
check(not has(p, "Improved Corruption (5)"), "build talents not off-build")
check(has(p, "Stats: Spell Power > Shadow Damage"), "stat priority")
check(not has(p, "Trainer"), "no trainer line when nothing is near level 18")
level = 12
check(has(page(), "Trainer, near your level: Summon Voidwalker (10), Drain Life (14)") and not has(page(), "Felhunter"), "trainer reminders near level")
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

-- 5. Steps build (warrior leveling).
classFile, level, unspent = "WARRIOR", 22, 2
setTrees({
    { name = "Arms", talents = { { "Deflection", 5, 5 }, { "Improved Tactical Mastery", 3, 3 }, { "Improved Overpower", 2, 2 },
        { "Anger Management", 0, 1 }, { "Deep Wounds", 0, 3 }, { "Improved Rend", 0, 3 } } },
    { name = "Fury", talents = { { "Cruelty", 0, 5 }, { "Booming Voice", 1, 5 } } },
    { name = "Protection", talents = { { "Improved Thunder Clap", 0, 3 } } },
})
p = page()
check(has(p, "Arms leveling") and has(p, "Next talent:|r Anger Management (Arms, rank 1)"), "next talent from steps")
check(has(p, "Levels 20-24:|r Arms tier 3"), "current step text")
check(has(p, "Off-build points: Booming Voice (1)") and not has(p, "Improved Overpower (2)"), "steps off-build uses step text")
fire("PLAYER_LEVEL_UP")
check(status() and status()[1].text == "|cff88bbeeTalent|r take Anger Management next", "status from steps")
-- An earlier step left unfinished comes first.
tabs[1].talents[1][2] = 3
p = page()
check(has(p, "Next talent:|r Deflection (Arms, rank 4)"), "unfinished earlier talent first")
tabs[1].talents[1][2] = 5
-- All picks up to this level taken.
tabs[1].talents[4][2] = 1; tabs[1].talents[5][2] = 3
level = 24
p = page()
check(has(p, "this level's picks are taken"), "step done message")
fire("PLAYER_LEVEL_UP")
check(status() == nil, "no row when steps give no named talent")

-- 6. Goal switching, saved per character.
classFile, level = "WARRIOR", 30
p = page("pvp")
check(has(p, "Goal set: PvP") and has(p, "Arms PvP"), "goal set to pvp")
local record = BuildsDB[guid]
check(record and record.goal == "pvp" and record.charName == "Tess Tester", "saved under the character key")
p = page("")
check(has(p, "Arms PvP") and has(p, "goal: PvP"), "goal kept")
-- Off-build matching: "Hamstring" only appears inside "Improved Hamstring", so it is off-build.
setTrees({ { name = "Arms", talents = { { "Deflection", 5, 5 }, { "Hamstring", 1, 1 }, { "Improved Hamstring", 0, 3 } } } })
p = page()
check(has(p, "Off-build points: Hamstring (1)") and not has(p, "Deflection (5)"), "longer names win when matching")
-- "Skip ..." talents in a step are off-build (Protection raid says skip Improved Thunder Clap).
page("tank")
setTrees({ { name = "Protection", talents = { { "Shield Specialization", 5, 5 }, { "Improved Thunder Clap", 2, 3 } } } })
p = page()
check(has(p, "Off-build points: Improved Thunder Clap (2)") and has(p, "Next talent:|r Anticipation (Protection, rank 1)"), "skipped talents are off-build")
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
check(has(p, "Fury raid") and BuildsDB["Player-1-0002"].goal == "dps", "dps chosen")
p = page("healer")
check(has(p, "no Dungeons and raids: healer build") and BuildsDB["Player-1-0002"].goal == "dps", "unavailable role not saved")
guid = "Player-1-0001"
level = 30
check(has(page(), "Arms PvP"), "first character's goal still pvp")
p = page("pvp2")
check(has(p, "no PvP (second choice) build"), "warrior has no pvp2")
p = page("leveling")
check(BuildsDB[guid].goal == "leveling", "back to leveling")
p = page("nonsense")
check(has(p, "Type a goal"), "help for unknown words")

-- 7. "all" and alt-class lookup.
p = page("all")
check(has(p, "Warrior builds") and has(p, "Leveling|r: Arms leveling") and has(p, "PvP|r: Arms PvP")
    and has(p, "tank|r: Protection raid") and has(p, "damage|r: Fury raid"), "all builds for your class")
check(#out == 5, "one line each plus title: " .. #out)
p = page("mage")
check(has(p, "Mage builds") and has(p, "Frost leveling (7 Arcane)") and has(p, "Fire (Fireball/Arcane)") and has(p, "Stats:"), "alt class builds")
check(not has(p, "Warrior"), "alt page is only that class")
p = page("Druids")
check(has(p, "Druid builds") and has(p, "Restoration PvP") and has(p, "Feral PvP"), "plural class name")

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

-- 9. Read-only and quiet.
check(#chat == 0, "no chat output: " .. table.concat(chat, " | "))
check(learned == 0, "never learns talents")

if #failures > 0 then
    error(#failures .. " check(s) failed:\n\n" .. table.concat(failures, "\n\n"), 0)
end
realPrint("ALL TESTS PASSED")
