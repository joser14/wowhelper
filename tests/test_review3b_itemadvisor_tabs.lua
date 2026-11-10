-- Review 3b (2026-11-10): ItemAdvisor's role from talents knew the shaman and priest trees only as
-- "Elemental" and "Shadow". The 1.60.1 game data names them "Elemental Combat" and "Shadow Magic"
-- (research\builds\SHAMAN.md, PRIEST.md; Builds\Data.lua uses the same names), so an Elemental shaman read
-- from the game's tree names kept the Enhancement (melee) weights, and a Shadow priest who once had more
-- Holy points stayed a healer.
-- Run: node run.js "<workspace root>" test_review3b_itemadvisor_tabs.lua
local base = ADDON_PATH
local handled = {}
local function newRegion()
    local r = { shown = true, scripts = {} }
    function r:SetScript(s, f) self.scripts[s] = f end
    function r:CreateTexture() return newRegion() end
    function r:CreateFontString() return newRegion() end
    return setmetatable(r, { __index = function() return function() end end })
end
local allFrames = {}
CreateFrame = function(_, name) local f = newRegion(); allFrames[#allFrames + 1] = f; if name then _G[name] = f end; return f end
SlashCmdList = {}
Enum = { TooltipDataType = { Item = 0 } }
GameTooltip = { AddLine = function() end }
ItemRefTooltip = {}
TooltipUtil = { GetDisplayedItem = function() end }
TooltipDataProcessor = { AddTooltipPostCall = function() end }
issecretvalue = function() return false end
local class = "SHAMAN"
UnitClass = function() return class, class end
UnitName = function() return "T" end
GetRealmName = function() return "R" end
UnitLevel = function() return 30 end
InCombatLockdown = function() return false end
GetInventoryItemLink = function() end
geterrorhandler = function() return function(e) handled[#handled + 1] = tostring(e) end end
ForeverHub_Receive = function() end
C_Timer = { After = function() end }
C_Item = { GetItemInfo = function() end, GetItemStats = function() end, RequestLoadItemDataByID = function() end }
C_TooltipInfo = { GetHyperlink = function() return { lines = {} } end }
C_QuestLog = { GetNumQuestLogEntries = function() return 0 end }
C_Container = { GetContainerNumSlots = function() return 0 end, GetContainerItemInfo = function() end }
NUM_TOTAL_EQUIPPED_BAG_SLOTS = 0

-- Talents as a trait tree with named sub-trees, as the game names them.
local nodes, subTrees = {}, {}
C_ClassTalents = { GetActiveConfigID = function() return 7 end }
C_Traits = {
    GetConfigInfo = function() return { treeIDs = { 50 } } end,
    GetTreeNodes = function() local ids = {}; for id in pairs(nodes) do ids[#ids + 1] = id end; table.sort(ids); return ids end,
    GetNodeInfo = function(_, id) local n = nodes[id]; return { ID = id, ranksPurchased = n[1], subTreeID = n[2] } end,
    GetSubTreeInfo = function(_, sub) return { ID = sub, name = subTrees[sub] } end,
}

assert(loadfile(base .. "/ItemAdvisor/ItemAdvisor.lua"))("ItemAdvisor", {})
local events; for _, f in ipairs(allFrames) do if f.scripts.OnEvent then events = f end end
local function fire(e, ...) events.scripts.OnEvent(events, e, ...) end

-- 1. Shaman, 20 points in Elemental Combat: the caster weights.
subTrees = { [1] = "Elemental Combat", [2] = "Enhancement", [3] = "Restoration" }
nodes = { [101] = { 15, 1 }, [102] = { 5, 1 }, [103] = { 2, 2 } }
fire("PLAYER_LOGIN")
local db = ItemAdvisorDB["T-R"]
assert(db.profile == "caster", "20 points in Elemental Combat is the caster role: " .. tostring(db.profile))

-- 2. Priest: Holy first, then a respec to 21 points in Shadow Magic.
class = "PRIEST"
ItemAdvisorDB = {}
subTrees = { [1] = "Discipline", [2] = "Holy", [3] = "Shadow Magic" }
nodes = { [201] = { 10, 2 } }
fire("PLAYER_LOGIN")
db = ItemAdvisorDB["T-R"]
assert(db.profile == "healer", "10 points in Holy is the healer role: " .. tostring(db.profile))
nodes = { [201] = { 21, 3 }, [202] = { 5, 1 } }
fire("TRAIT_CONFIG_UPDATED")
assert(db.profile == "shadow", "21 points in Shadow Magic is the shadow role: " .. tostring(db.profile))
assert(#handled == 0, "clean: " .. tostring(handled[1]))
print("ALL TESTS PASSED")
