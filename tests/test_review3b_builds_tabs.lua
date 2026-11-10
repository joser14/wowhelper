-- Review 3b (2026-11-10): Builds names the talent trees itself when the game doesn't.
-- On Forever the talents are one trait tree with no tree titles or sub-trees, GetTalentTabInfo is gone, and
-- C_SpecializationInfo.GetSpecializationInfo has one spec per class, named after the class
-- (research\thirdparty_features.md 6.10). Columns were then named "Warrior", "Tree 2", "Tree 3":
--   * the panel said "(Warrior, row 1)" for an Arms talent;
--   * at 60 with no saved goal, the dungeon/raid build "whose tree you have most points in" never matched
--     a tree, so a Protection warrior got the damage build.
-- Run: node run.js "<workspace root>" test_review3b_builds_tabs.lua
local base = ADDON_PATH
local failures = {}
local function check(cond, why) if not cond then failures[#failures + 1] = why end end
local function has(text, needle) return type(text) == "string" and text:find(needle, 1, true) ~= nil end

local out = {}
ForeverHub_Receive = function(_, t) out[#out + 1] = t end
issecretvalue = function() return false end
SlashCmdList = {}

local frames = {}
local function NewFrame()
    local f = { scripts = {}, shown = false }
    frames[#frames + 1] = f
    return setmetatable(f, { __index = function(_, k)
        return function(self, ...)
            local a = { ... }
            if k == "SetScript" then self.scripts[a[1]] = a[2]
            elseif k == "Show" then self.shown = true
            elseif k == "Hide" then self.shown = false
            elseif k == "IsShown" then return self.shown
            elseif k == "SetText" then self.text = a[1]
            elseif k == "GetStringHeight" then return 70
            elseif k == "CreateTexture" or k == "CreateFontString" then return NewFrame() end
        end
    end })
end
CreateFrame = function() return NewFrame() end
UIParent = { GetEffectiveScale = function() return 1 end, GetWidth = function() return 1920 end }

UnitName = function() return "Tess", "Tester" end
UnitGUID = function() return "Player-1-0200" end
GetRealmName = function() return "R" end
local level, unspent = 60, 0
UnitClass = function() return "Warrior", "WARRIOR" end
UnitLevel = function() return level end
UnitCharacterPoints = function() return unspent end

-- As measured on Forever: one spec, named after the class; no legacy talent calls.
C_SpecializationInfo = {
    GetSpecializationInfo = function(index)
        if index == 1 then return 1446, "Warrior" end
        return 0
    end,
}

-- One tree, no titles, no sub-trees: Arms x 0-300, Fury x 600-800, Protection x 1000-1200.
-- { name, rank, maxRank, x, y }
local nodes = {
    { "Improved Heroic Strike", 2, 3, 0, 100 }, { "Deflection", 0, 5, 100, 100 }, { "Improved Rend", 0, 3, 200, 100 },
    { "Tactical Mastery", 0, 5, 300, 300 },
    { "Booming Voice", 0, 5, 600, 100 }, { "Cruelty", 0, 5, 700, 100 }, { "Unbridled Wrath", 0, 5, 800, 300 },
    { "Shield Specialization", 5, 5, 1100, 100 }, { "Anticipation", 5, 5, 1200, 100 }, { "Toughness", 5, 5, 1000, 300 },
    { "Improved Shield Block", 3, 3, 1100, 300 }, { "Defiance", 5, 5, 1200, 500 }, { "Last Stand", 1, 1, 1000, 500 },
}
C_ClassTalents = { GetActiveConfigID = function() return 7 end }
C_Traits = {
    GetConfigInfo = function() return { treeIDs = { 60 } } end,
    GetTreeCurrencyInfo = function() return { { traitCurrencyID = 1, quantity = unspent } } end,
    GetTreeInfo = function() return {} end,
    GetTreeNodes = function()
        local ids = {}
        for i in ipairs(nodes) do ids[#ids + 1] = i end
        return ids
    end,
    GetNodeInfo = function(_, id)
        local n = nodes[id]
        return { ID = id, isVisible = true, maxRanks = n[3], currentRank = n[2], activeRank = n[2], posX = n[4], posY = n[5],
            activeEntry = { entryID = id }, entryIDs = { id } }
    end,
    GetEntryInfo = function(_, entryID) return { definitionID = entryID } end,
    GetDefinitionInfo = function(def) return { overrideName = nodes[def][1] } end,
}

assert(loadfile(base .. "/Builds/Data.lua"))("Builds", {})
assert(loadfile(base .. "/Builds/Builds.lua"))("Builds", {})
local function page(arg) out = {}; SlashCmdList.BUILDS(arg or ""); return table.concat(out, "\n") end

-- 1. Level 60, 24 points in Protection and 2 in Arms, no saved goal: the tank build.
local p = page()
check(has(p, "goal: Dungeons and raids: tank"), "a Protection warrior at 60 gets the tank build:\n" .. p)

-- 2. The panel names the class's own trees, not the class name or "Tree 2".
level, unspent = 30, 1
BuildsDB = {}
local text = table.concat(Builds_TalentPanelLines() or {}, "\n")
check(not has(text, "(Warrior") and not has(text, "(Tree "), "no class name or tree number as a tree name:\n" .. text)
check(has(text, "(Arms") or has(text, "(Fury") or has(text, "(Protection"), "a real tree name is shown:\n" .. text)

-- 3. A name the game does give for a tab (any position) is kept.
C_SpecializationInfo.GetSpecializationInfo = function(index)
    return 100 + index, ({ "Arms", "Fury", "Protection" })[index]
end
level, unspent = 60, 0
BuildsDB = {}
p = page()
check(has(p, "goal: Dungeons and raids: tank"), "game tab names still work:\n" .. p)

if #failures > 0 then
    error(#failures .. " check(s) failed:\n\n" .. table.concat(failures, "\n\n"), 0)
end
print("ALL TESTS PASSED")
