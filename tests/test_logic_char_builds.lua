-- Builds logic review (2026-11-09): trait trees without names, level-60 default role when the
-- game's tree name differs from the build's spec word, and the panel beside the talent window
-- (never an empty box; redrawn when the goal changes).
-- Run from the harness folder:  node run.js "<workspace root>" test_logic_char_builds.lua
local base = ADDON_PATH
local failures = {}
local function check(cond, why) if not cond then failures[#failures + 1] = why end end
local function has(text, needle) return type(text) == "string" and text:find(needle, 1, true) ~= nil end

local out = {}
ForeverHub_Receive = function(_, t) out[#out + 1] = t end
issecretvalue = function() return false end
SlashCmdList = {}

-- Frames: ours record scripts, shown state, points and text.
local frames = {}
local function NewFrame()
    local f = { scripts = {}, shown = false, text = nil, point = nil }
    frames[#frames + 1] = f
    return setmetatable(f, { __index = function(_, k)
        return function(self, ...)
            local a = { ... }
            if k == "SetScript" then self.scripts[a[1]] = a[2]
            elseif k == "Show" then self.shown = true
            elseif k == "Hide" then self.shown = false
            elseif k == "IsShown" then return self.shown
            elseif k == "SetPoint" then self.point = a
            elseif k == "SetText" then self.text = a[1]
            elseif k == "GetStringHeight" then return 70
            elseif k == "CreateTexture" or k == "CreateFontString" then return NewFrame() end
        end
    end })
end
CreateFrame = function() return NewFrame() end
UIParent = { GetEffectiveScale = function() return 1 end, GetWidth = function() return 1920 end }

local guid = "Player-1-0100"
UnitName = function() return "Tess", "Tester" end
UnitGUID = function() return guid end
GetRealmName = function() return "R" end
local classFile, level, unspent = "PRIEST", 60, 0
UnitClass = function() if classFile then return classFile, classFile end end
UnitLevel = function() return level end
UnitCharacterPoints = function() return unspent end

-- The trait system only (as on Forever): no legacy talent calls, no tab names.
-- trees[treeID] = { title = string|nil, nodes = { { name, sub, rank, max, x, y } } }
local trees, treeOrder, subNames = {}, {}, {}
local function nodeByID(id) local tree = math.floor(id / 1000); return trees[tree].nodes[id % 1000] end
C_ClassTalents = { GetActiveConfigID = function() return 7 end }
C_Traits = {
    GetConfigInfo = function() return { treeIDs = treeOrder } end,
    GetTreeCurrencyInfo = function() return { { traitCurrencyID = 1, quantity = unspent } } end,
    GetTreeInfo = function(_, tree) return { titleText = trees[tree].title } end,
    GetTreeNodes = function(tree)
        local ids = {}
        for i in ipairs(trees[tree].nodes) do ids[#ids + 1] = tree * 1000 + i end
        return ids
    end,
    GetNodeInfo = function(_, id)
        local n = nodeByID(id)
        return { ID = id, isVisible = true, maxRanks = n[4], currentRank = n[3], activeRank = n[3], posX = n[5], posY = n[6],
            activeEntry = { entryID = id, rank = n[3] }, entryIDs = { id }, subTreeID = n[2] and (900 + n[2]) or nil }
    end,
    GetEntryInfo = function(_, entryID) return { definitionID = entryID } end,
    GetDefinitionInfo = function(def) return { overrideName = nodeByID(def)[1] } end,
    GetSubTreeInfo = function(_, sub) return { name = subNames[sub - 900] } end,
}

assert(loadfile(base .. "/Builds/Data.lua"))("Builds", {})
assert(loadfile(base .. "/Builds/Builds.lua"))("Builds", {})
local events, watcher = frames[1], frames[2]
local function fire(e) events.scripts.OnEvent(events, e) end
local function page(arg) out = {}; SlashCmdList.BUILDS(arg or ""); return table.concat(out, "\n") end
local function panelText() return table.concat(Builds_TalentPanelLines() or {}, "\n") end

-- 1. Level 60, no saved goal: a Shadow priest (15/3/33 as the game names its trees: "Shadow Magic")
-- gets the Shadow raid build, not Holy because of 3 Holy points. The build's spec word is "Shadow"
-- while its points (and the game) say "Shadow Magic".
subNames = { "Discipline", "Holy", "Shadow Magic" }
trees = { [50] = { nodes = {
    { "Twin Disciplines", 1, 5, 5, 100, 100 }, { "Silent Resolve", 1, 5, 5, 200, 100 }, { "Mental Strength", 1, 5, 5, 300, 300 },
    { "Healing Focus", 2, 3, 3, 600, 100 },
    { "Spirit Tap", 3, 5, 5, 1100, 100 }, { "Shadow Focus", 3, 5, 5, 1200, 100 }, { "Improved Mind Blast", 3, 5, 5, 1100, 300 },
    { "Shadowform", 3, 1, 1, 1200, 900 }, { "Mind Flay", 3, 1, 1, 1100, 500 }, { "Shadow Weaving", 3, 5, 5, 1200, 500 },
    { "Vampiric Embrace", 3, 1, 1, 1100, 700 }, { "Darkness", 3, 5, 5, 1300, 700 }, { "Shadow Reach", 3, 6, 6, 1300, 300 },
} } }
treeOrder = { 50 }
local p = page()
check(has(p, "Shadow raid"), "level-60 shadow priest defaults to the Shadow raid build:\n" .. p)

-- 2. One tree, no sub-trees, no tree titles, no tab names: three columns found by the gaps between them.
-- The third tree has nothing in its right-most column, so equal thirds of the width would put the
-- second tree's right-most column (x = 800) into tree 3.
classFile, level, unspent = "WARRIOR", 10, 1
subNames = {}
trees = { [60] = { nodes = {
    { "Improved Heroic Strike", nil, 0, 3, 0, 100 }, { "Deflection", nil, 0, 5, 100, 100 }, { "Improved Charge", nil, 0, 2, 200, 300 },
    { "Tactical Mastery", nil, 0, 5, 300, 300 }, { "Booming Voice", nil, 0, 5, 600, 100 }, { "Cruelty", nil, 0, 5, 700, 100 }, { "Improved Rend", nil, 0, 3, 800, 100 },
    { "Shield Specialization", nil, 0, 5, 1100, 100 }, { "Anticipation", nil, 0, 5, 1200, 100 }, { "Toughness", nil, 0, 5, 1000, 300 },
} } }
treeOrder = { 60 }
fire("TRAIT_NODE_CHANGED")
local text = panelText()
check(has(text, "Improved Rend 1|r") and has(text, "(Tree 2, row 1)"), "x = 800 is in the middle tree:\n" .. text)

-- 3. Three tree IDs, no titles and no tab names: each tree keeps its own number (their x positions
-- overlap, so they must not be split into columns).
trees = {
    [71] = { nodes = { { "Deflection", nil, 0, 5, 0, 100 }, { "Tactical Mastery", nil, 0, 5, 300, 300 } } },
    [72] = { nodes = { { "Improved Rend", nil, 0, 3, 0, 100 }, { "Cruelty", nil, 0, 5, 300, 100 } } },
    [73] = { nodes = { { "Anticipation", nil, 0, 5, 0, 100 }, { "Toughness", nil, 0, 5, 300, 300 } } },
}
treeOrder = { 71, 72, 73 }
fire("TRAIT_NODE_CHANGED")
text = panelText()
check(has(text, "Improved Rend 1|r") and has(text, "(Tree 2, row 1)"), "second tree ID is Tree 2:\n" .. text)

-- 4. The panel beside the talent window.
local blizzOpen = true
PlayerTalentFrame = { IsShown = function() return blizzOpen end, GetLeft = function() return 100 end, GetRight = function() return 900 end,
    GetTop = function() return 800 end, GetEffectiveScale = function() return 1 end }
local function tick() watcher.scripts.OnUpdate(watcher, 1) end
tick()
local panel = frames[#frames - 2]  -- panel, then its texture and font string
local label = frames[#frames]
check(panel.shown and has(label.text, "Arms leveling"), "panel shows the leveling build: " .. tostring(label.text))
-- 4a. Choosing another goal on the hub page redraws the open panel.
page("pvp")
tick()
check(has(label.text, "Arms battleground") or has(label.text, BuildsData.WARRIOR.pvp.name), "panel follows the new goal: " .. tostring(label.text))
-- 4b. When there is nothing to show (class unreadable), the panel is hidden, not an empty box.
classFile = nil
fire("PLAYER_TALENT_UPDATE")
tick()
check(not panel.shown, "no empty panel when the build can't be worked out")
tick()
check(not panel.shown, "still hidden on the next tick")
classFile = "WARRIOR"
fire("PLAYER_TALENT_UPDATE")
tick()
check(panel.shown and has(label.text, "Build:"), "panel back once the class is readable")
blizzOpen = false
tick()
check(not panel.shown, "panel hidden with the talent window")

if #failures > 0 then
    error(#failures .. " check(s) failed:\n\n" .. table.concat(failures, "\n\n"), 0)
end
print("ALL TESTS PASSED")
