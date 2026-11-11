-- Builds: recommended talent builds for your class (leveling, PvP, dungeons/raids) from Data.lua,
-- compared with the talents you have spent, so the page can say which talent to take next.
-- Read-only: it only reads your talents and level. It never learns talents or respecs for you.

-- Shared Forever character identity (the same copy is in every helper that saves per-character data,
-- so each helper still works alone; whichever loads first defines it). On Forever a character has a
-- first name and a surname (UnitName's second return), so the first name alone is not unique.
-- Key = the player GUID ("Player-<server>-<id>"); when that can't be read, "First Surname-Realm".
do
    local function Plain(value)
        if value == nil or (issecretvalue and issecretvalue(value)) or type(value) ~= "string" or value == "" then
            return nil
        end
        return value
    end
    local function Call(fn, ...)
        if type(fn) ~= "function" then
            return nil
        end
        local ok, a, b = pcall(fn, ...)
        if not ok then
            return nil
        end
        return Plain(a), Plain(b)
    end
    -- "First Surname" on Forever, the plain name elsewhere; nil when unreadable.
    ForeverCharacterName = ForeverCharacterName or function()
        local name, surname = Call(UnitName, "player")
        if not name then
            return nil
        end
        if surname then
            return name .. " " .. surname
        end
        return name
    end
    ForeverCharacterGUID = ForeverCharacterGUID or function()
        local guid = Call(UnitGUID, "player")
        if guid and guid:match("^Player%-") then
            return guid
        end
    end
    -- The key older versions used: first name only, "-", realm.
    ForeverCharacterLegacyKey = ForeverCharacterLegacyKey or function()
        local name = Call(UnitName, "player")
        local realm = Call(GetRealmName)
        return (name or "Unknown") .. "-" .. (realm or "Unknown")
    end
    -- "First Surname-Realm": the key when the GUID can't be read.
    ForeverCharacterNameKey = ForeverCharacterNameKey or function()
        local realm = Call(GetRealmName)
        return (ForeverCharacterName() or "Unknown") .. "-" .. (realm or "Unknown")
    end
    ForeverCharacterKey = ForeverCharacterKey or function()
        return ForeverCharacterGUID() or ForeverCharacterNameKey()
    end
    -- Once per login: moves this character's record from an older key to the current one. Only when
    -- nothing is saved under the current key yet (two records are never merged), and never a record
    -- stamped with another character's GUID. The old key's record is moved, not copied, so a second
    -- character with the same first name starts fresh instead of sharing it. Returns the current key.
    -- oldKeys: optional list of this helper's own older key spellings (default: the legacy key).
    ForeverCharacterAdopt = ForeverCharacterAdopt or function(db, oldKeys)
        local key = ForeverCharacterKey()
        if type(db) ~= "table" or db[key] ~= nil then
            return key
        end
        local guid = ForeverCharacterGUID()
        local candidates = { ForeverCharacterNameKey() }
        for _, old in ipairs(oldKeys or { ForeverCharacterLegacyKey() }) do
            candidates[#candidates + 1] = old
        end
        for _, old in ipairs(candidates) do
            local record = old ~= key and db[old]
            if type(record) == "table" and (record.charGUID == nil or record.charGUID == guid) then
                db[key] = record
                db[old] = nil
                record.migratedFrom = old
                break
            end
        end
        return key
    end
    -- Writes who a record belongs to into it, so pages can show a name instead of parsing the key.
    ForeverCharacterStamp = ForeverCharacterStamp or function(record)
        if type(record) ~= "table" then
            return record
        end
        record.charName = ForeverCharacterName() or record.charName
        record.charGUID = ForeverCharacterGUID() or record.charGUID
        return record
    end
end

local MAX_LEVEL = 60
local FIRST_TALENT_LEVEL = 10
local MAX_TABS, MAX_TALENTS_PER_TAB = 5, 40
local TRAIN_BEHIND, TRAIN_AHEAD = 2, 4
local GOLD, GRAY, GREEN, BLUE = "|cffffd100", "|cff999999", "|cff33ff33", "|cff88bbee"
local TICK = "|TInterface\\RaidFrame\\ReadyCheck-Ready:0|t"

local CLASS_ORDER = { "WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST", "SHAMAN", "MAGE", "WARLOCK", "DRUID" }
local CLASS_NAMES = { WARRIOR = "Warrior", PALADIN = "Paladin", HUNTER = "Hunter", ROGUE = "Rogue", PRIEST = "Priest",
    SHAMAN = "Shaman", MAGE = "Mage", WARLOCK = "Warlock", DRUID = "Druid" }
-- Goals you can choose, in the order "all" lists them.
-- dps2 is an optional second damage build (Druid: Balance next to Cat).
local GOALS = { "leveling", "pvp", "pvp2", "tank", "healer", "dps", "dps2" }
local ROLES = { tank = true, healer = true, dps = true, dps2 = true }
local GOAL_LABELS = { leveling = "Leveling", pvp = "PvP", pvp2 = "PvP (second choice)", tank = "Dungeons and raids: tank",
    healer = "Dungeons and raids: healer", dps = "Dungeons and raids: damage", dps2 = "Dungeons and raids: damage (second choice)" }
-- Where a build's point order came from (the build's optional orderFrom field).
local ORDER_LABELS = { source = "order: from guide", constructed = "order: built from final ranks" }
-- Each order puts damage first, so a tie between two builds of the same tree goes to dps.
local DEFAULT_ROLE_ORDER = { "dps", "dps2", "healer", "tank" }

local function Safe(value)
    if issecretvalue and issecretvalue(value) then
        return nil
    end
    return value
end

local function Print(text)
    if ForeverHub_Receive then
        return ForeverHub_Receive("Builds", text)
    end
    -- No hub window to show it in: stay quiet rather than fill the chat.
end

local function SafeCall(fn, ...)
    if type(fn) ~= "function" then
        return nil
    end
    local ok, result = pcall(fn, ...)
    return ok and Safe(result) or nil
end

local function Number(value)
    value = Safe(value)
    return type(value) == "number" and value or nil
end

local function Text(value)
    value = Safe(value)
    return type(value) == "string" and value ~= "" and value or nil
end

-- ---------------------------------------------------------------------------------------------------
-- Reading the player

local function PlayerClass()
    if type(UnitClass) ~= "function" then
        return nil
    end
    local ok, localized, classFile = pcall(UnitClass, "player")
    if not ok then
        return nil
    end
    classFile = Text(classFile)
    return classFile, Text(localized)
end

local function PlayerLevel()
    return Number(SafeCall(UnitLevel, "player"))
end

-- Forever keeps talent points as trait currencies, one shared currency across the tabs (same reading
-- as TalentNudge, so both helpers agree on the count).
local function TraitPoints()
    if not (C_ClassTalents and C_Traits) then
        return nil
    end
    local configID = SafeCall(C_ClassTalents.GetActiveConfigID)
    local config = configID and SafeCall(C_Traits.GetConfigInfo, configID)
    if type(config) ~= "table" or type(Safe(config.treeIDs)) ~= "table" then
        return nil
    end
    local total, seen = nil, {}
    for _, treeID in ipairs(config.treeIDs) do
        local currencies = SafeCall(C_Traits.GetTreeCurrencyInfo, configID, Safe(treeID), true)
        for _, currency in ipairs(type(currencies) == "table" and currencies or {}) do
            local id, quantity = type(currency) == "table" and Safe(currency.traitCurrencyID), type(currency) == "table" and Number(currency.quantity)
            if id and quantity and not seen[id] then
                seen[id] = true
                total = (total or 0) + quantity
            end
        end
    end
    return total
end

-- Unspent talent points, or nil when the game gives no way to read them.
local function UnspentPoints()
    local best = TraitPoints()
    for _, count in ipairs({ Number(SafeCall(GetUnspentTalentPoints)) or false, Number(SafeCall(UnitCharacterPoints, "player")) or false }) do
        if count and count > (best or -1) then
            best = count
        end
    end
    return best
end

local function TabName(tab)
    if type(GetTalentTabInfo) == "function" then
        -- Two return layouts are in use: (name, icon, points) and (id, name, description, icon, points).
        local ok, r1, r2 = pcall(GetTalentTabInfo, tab)
        local name = ok and (type(Safe(r1)) == "number" and Text(r2) or Text(r1)) or nil
        if name then
            return name
        end
    end
    if C_SpecializationInfo and type(C_SpecializationInfo.GetSpecializationInfo) == "function" then
        local ok, r1, r2 = pcall(C_SpecializationInfo.GetSpecializationInfo, tab)
        if ok then
            r1 = Safe(r1)
            local name = type(r1) == "table" and Text(r1.name) or Text(r2)
            if name then
                return name
            end
        end
    end
    return nil
end

-- The talent window's trees left to right, named as the build data names them. Forever's API has one spec
-- per class, named after the class (research\thirdparty_features.md 6.10), and its trait tree may not name
-- its parts, so a tree takes its name from here unless the game gives one of the class's own tree names.
local CLASS_TREES = {
    WARRIOR = { "Arms", "Fury", "Protection" }, PALADIN = { "Holy", "Protection", "Retribution" },
    HUNTER = { "Beast Mastery", "Marksmanship", "Survival" }, ROGUE = { "Assassination", "Combat", "Subtlety" },
    PRIEST = { "Discipline", "Holy", "Shadow Magic" }, SHAMAN = { "Elemental Combat", "Enhancement", "Restoration" },
    MAGE = { "Arcane", "Fire", "Frost" }, WARLOCK = { "Affliction", "Demonology", "Destruction" },
    DRUID = { "Balance", "Feral Combat", "Restoration" },
}

-- True when the game's name is one of your class's trees ("Shadow" for "Shadow Magic" too).
local function KnownTree(name)
    local trees = CLASS_TREES[PlayerClass() or ""]
    local first = type(name) == "string" and name:lower():match("^(%S+)")
    if not (trees and first) then
        return false
    end
    for _, tree in ipairs(trees) do
        if tree:lower():match("^(%S+)") == first then
            return true
        end
    end
    return false
end

-- The name of the tree at a position: the game's when it is one of your class's trees, else the class's
-- tree at that position, else whatever the game says, else "Tree N".
local function TreeName(index)
    local name = TabName(index)
    if KnownTree(name) then
        return name
    end
    local trees = CLASS_TREES[PlayerClass() or ""]
    return (trees and trees[index]) or name or ("Tree " .. index)
end

-- The classic global first: GetTalentInfo(tab, index) -> name, icon, tier, column, rank, maxRank.
local function LegacyTalent(tab, index)
    if type(GetTalentInfo) ~= "function" then
        return nil
    end
    local ok, r1, _, _, _, r5, r6 = pcall(GetTalentInfo, tab, index)
    if not ok then
        return nil
    end
    r1 = Safe(r1)
    if type(r1) == "table" then
        return Text(r1.name), Number(r1.rank), Number(r1.maxRank)
    end
    return Text(r1), Number(r5), Number(r6)
end

local function ActiveGroup()
    if C_SpecializationInfo and type(C_SpecializationInfo.GetActiveSpecGroup) == "function" then
        local group = Number(SafeCall(C_SpecializationInfo.GetActiveSpecGroup))
        if group then
            return group
        end
    end
    return Number(SafeCall(GetActiveTalentGroup))
end

-- The documented call: C_SpecializationInfo.GetTalentInfo({ specializationIndex, talentIndex, groupIndex }).
local function SpecTalent(tab, index, group)
    if not (C_SpecializationInfo and type(C_SpecializationInfo.GetTalentInfo) == "function") then
        return nil
    end
    local info = SafeCall(C_SpecializationInfo.GetTalentInfo, { specializationIndex = tab, talentIndex = index, groupIndex = group })
    if type(info) ~= "table" then
        return nil
    end
    return Text(info.name), Number(info.rank), Number(info.maxRank)
end

-- Forever's talent window is the trait system (C_ClassTalents / C_Traits): one config with the three
-- trees either as separate tree IDs or as sub-trees of one tree. The legacy calls above return nothing
-- there, so this is the reading that works in game. Read-only: only Get* calls.
local function TraitName(configID, node)
    local entryID = type(node.activeEntry) == "table" and Safe(node.activeEntry.entryID)
    if not entryID and type(node.entryIDs) == "table" then
        entryID = Safe(node.entryIDs[1])
    end
    local entry = entryID and SafeCall(C_Traits.GetEntryInfo, configID, entryID)
    local definitionID = type(entry) == "table" and Safe(entry.definitionID)
    local definition = definitionID and SafeCall(C_Traits.GetDefinitionInfo, definitionID)
    if type(definition) ~= "table" then
        return nil
    end
    local name = Text(definition.overrideName)
    local spellID = Number(definition.spellID)
    if not name and spellID then
        name = (C_Spell and Text(SafeCall(C_Spell.GetSpellName, spellID))) or Text(SafeCall(GetSpellInfo, spellID))
    end
    return name
end

local function TraitTalents()
    if not (C_ClassTalents and C_Traits and type(C_Traits.GetTreeNodes) == "function" and type(C_Traits.GetNodeInfo) == "function") then
        return nil
    end
    local configID = SafeCall(C_ClassTalents.GetActiveConfigID)
    local config = configID and SafeCall(C_Traits.GetConfigInfo, configID)
    if type(config) ~= "table" or type(Safe(config.treeIDs)) ~= "table" then
        return nil
    end
    local treeIDs = config.treeIDs
    local nodes = {}
    for treeIndex, rawTree in ipairs(treeIDs) do
        local treeID = Safe(rawTree)
        local treeInfo = treeID and SafeCall(C_Traits.GetTreeInfo, configID, treeID)
        local treeTitle = type(treeInfo) == "table" and Text(treeInfo.titleText) or nil
        local nodeIDs = treeID and SafeCall(C_Traits.GetTreeNodes, treeID)
        for _, rawNode in ipairs(type(nodeIDs) == "table" and nodeIDs or {}) do
            local nodeID = Safe(rawNode)
            local node = nodeID and SafeCall(C_Traits.GetNodeInfo, configID, nodeID)
            if type(node) == "table" and Safe(node.isVisible) ~= false and Number(node.maxRanks) and Number(node.maxRanks) > 0 then
                local name = TraitName(configID, node)
                if name then
                    local tree
                    local subTreeID = Number(node.subTreeID)
                    if subTreeID and type(C_Traits.GetSubTreeInfo) == "function" then
                        local sub = SafeCall(C_Traits.GetSubTreeInfo, configID, subTreeID)
                        tree = type(sub) == "table" and Text(sub.name) or nil
                    end
                    if not tree and #treeIDs > 1 then
                        -- Each tree ID has its own positions, so a tree is never split into columns.
                        tree = (KnownTree(treeTitle) and treeTitle) or TreeName(treeIndex)
                    end
                    nodes[#nodes + 1] = { name = name, tree = tree, treeIndex = treeIndex, subTreeID = subTreeID,
                        rank = math.max(Number(node.activeRank) or Number(node.currentRank) or 0, 0),
                        maxRank = Number(node.maxRanks), x = Number(node.posX) or 0, y = Number(node.posY) or 0 }
                end
            end
        end
    end
    if #nodes == 0 then
        return nil
    end
    -- One tree holding all three: split it into three columns of the window, left to right, and name each
    -- column after the class's talent tabs.
    local unnamed = 0
    for _, node in ipairs(nodes) do
        if not node.tree then
            unnamed = unnamed + 1
        end
    end
    if unnamed > 0 then
        local xs, seenX = {}, {}
        local minX, maxX = math.huge, -math.huge
        for _, node in ipairs(nodes) do
            if not node.tree then
                minX, maxX = math.min(minX, node.x), math.max(maxX, node.x)
                if not seenX[node.x] then
                    seenX[node.x] = true
                    xs[#xs + 1] = node.x
                end
            end
        end
        table.sort(xs)
        -- The space between two trees is wider than between columns of one tree: when the two widest
        -- gaps clearly stand out, they are the borders. Otherwise equal thirds of the width (a tree with
        -- an empty outer column would shift those, so they are only the fallback).
        local cut1, cut2
        local gaps = {}
        for index = 2, #xs do
            gaps[#gaps + 1] = { size = xs[index] - xs[index - 1], at = index }
        end
        table.sort(gaps, function(a, b)
            if a.size ~= b.size then
                return a.size > b.size
            end
            return a.at < b.at
        end)
        if gaps[2] and gaps[2].size > 0 and (not gaps[3] or gaps[2].size > gaps[3].size) then
            local a, b = math.min(gaps[1].at, gaps[2].at), math.max(gaps[1].at, gaps[2].at)
            cut1, cut2 = (xs[a - 1] + xs[a]) / 2, (xs[b - 1] + xs[b]) / 2
        end
        local width = math.max(maxX - minX, 1)
        for _, node in ipairs(nodes) do
            if not node.tree then
                local column
                if cut1 then
                    column = node.x < cut1 and 1 or node.x < cut2 and 2 or 3
                else
                    column = math.min(3, math.floor((node.x - minX) / width * 3) + 1)
                end
                node.tree = TreeName(column)
                node.treeIndex = column
            end
        end
    end
    -- Row numbers within each tree, from the nodes' heights (top row = 1).
    local heights = {}
    for _, node in ipairs(nodes) do
        heights[node.tree] = heights[node.tree] or {}
        heights[node.tree][node.y] = true
    end
    local rowOf = {}
    for tree, set in pairs(heights) do
        local sorted = {}
        for y in pairs(set) do
            sorted[#sorted + 1] = y
        end
        table.sort(sorted)
        rowOf[tree] = {}
        for index, y in ipairs(sorted) do
            rowOf[tree][y] = index
        end
    end
    local result = { byName = {}, list = {}, spent = 0 }
    for _, node in ipairs(nodes) do
        local entry = { name = node.name, tree = node.tree, rank = node.rank, maxRank = node.maxRank, row = rowOf[node.tree][node.y] }
        result.list[#result.list + 1] = entry
        result.byName[node.name:lower()] = entry
        result.spent = result.spent + entry.rank
    end
    return result
end

-- Every talent the game lists: { byName = { [lower name] = { name, tree, rank, maxRank, row? } }, list = {...},
-- spent = total points }, or nil when no talent could be read at all.
local function LegacyTalents()
    local hasLegacy = type(GetTalentInfo) == "function"
    local hasSpec = C_SpecializationInfo and type(C_SpecializationInfo.GetTalentInfo) == "function"
    if not (hasLegacy or hasSpec) then
        return nil
    end
    local tabs = Number(SafeCall(GetNumTalentTabs)) or 3
    local group = ActiveGroup()
    local result = { byName = {}, list = {}, spent = 0 }
    for tab = 1, math.min(math.max(tabs, 0), MAX_TABS) do
        local tree = TreeName(tab)
        local count = Number(SafeCall(GetNumTalents, tab))
        for index = 1, math.min(count or MAX_TALENTS_PER_TAB, MAX_TALENTS_PER_TAB) do
            local name, rank, maxRank = LegacyTalent(tab, index)
            if not name then
                name, rank, maxRank = SpecTalent(tab, index, group)
            end
            if name then
                local entry = { name = name, tree = tree, rank = math.max(rank or 0, 0), maxRank = maxRank }
                result.list[#result.list + 1] = entry
                result.byName[name:lower()] = entry
                result.spent = result.spent + entry.rank
            elseif not count then
                break
            end
        end
    end
    return #result.list > 0 and result or nil
end

local function ReadTalents()
    return LegacyTalents() or TraitTalents()
end

-- ---------------------------------------------------------------------------------------------------
-- Saved goal

local function Record()
    if type(BuildsDB) ~= "table" then
        BuildsDB = {}
    end
    local key = ForeverCharacterAdopt(BuildsDB)
    if type(BuildsDB[key]) ~= "table" then
        BuildsDB[key] = {}
    end
    return ForeverCharacterStamp(BuildsDB[key])
end

local function BuildFor(classFile, goal)
    local class = BuildsData and BuildsData[classFile]
    if type(class) ~= "table" then
        return nil
    end
    if ROLES[goal] then
        return type(class.pve) == "table" and class.pve[goal] or nil
    end
    return class[goal]
end

local function Available(classFile)
    local list = {}
    for _, goal in ipairs(GOALS) do
        if BuildFor(classFile, goal) then
            list[#list + 1] = goal
        end
    end
    return list
end

-- At 60 with no saved choice: the dungeon/raid build whose tree you have most points in, else damage.
local function DefaultRole(classFile, talents)
    local pve = BuildsData and BuildsData[classFile] and BuildsData[classFile].pve
    if type(pve) ~= "table" then
        return nil
    end
    if talents then
        local perTree = {}
        for _, entry in ipairs(talents.list) do
            perTree[entry.tree] = (perTree[entry.tree] or 0) + entry.rank
        end
        -- A build's tree: its spec word, or the tree most of its points go to. The two can differ
        -- ("Shadow" and the game's "Shadow Magic"), so both are tried.
        local function PointsIn(build)
            local count, mainTree, mainCount = {}, nil, 0
            for _, point in ipairs(type(build.points) == "table" and build.points or {}) do
                if type(point.tree) == "string" then
                    count[point.tree] = (count[point.tree] or 0) + 1
                    if count[point.tree] > mainCount then
                        mainTree, mainCount = point.tree, count[point.tree]
                    end
                end
            end
            local points = perTree[build.spec] or 0
            if mainTree and mainTree ~= build.spec then
                points = math.max(points, perTree[mainTree] or 0)
            end
            return points
        end
        local bestRole, bestPoints
        for _, role in ipairs(DEFAULT_ROLE_ORDER) do
            local build = pve[role]
            local points = build and PointsIn(build) or 0
            if build and points > 0 and points > (bestPoints or 0) then
                bestRole, bestPoints = role, points
            end
        end
        if bestRole then
            return bestRole
        end
    end
    for _, role in ipairs(DEFAULT_ROLE_ORDER) do
        if pve[role] then
            return role
        end
    end
end

local NextTalent, SpentRank

-- True when the leveling build (a point-by-point one) has points left and everything you spent is
-- exactly its points so far.
local function FollowingLeveling(classFile, talents)
    local build = BuildFor(classFile, "leveling")
    if not (build and talents and type(build.points) == "table" and #build.points > 0) then
        return false
    end
    local met = 0
    for _, point in ipairs(build.points) do
        if SpentRank(talents, point.talent) >= (point.rank or 1) then
            met = met + 1
        else
            return met == (talents.spent or -1)
        end
    end
    return false
end

local function CurrentGoal(classFile, level, talents)
    local saved = Record().goal
    if saved and BuildFor(classFile, saved) then
        return saved, true
    end
    -- At 60 the last point still belongs to the leveling build if you followed it point for point (every
    -- point before its next one taken, nothing else): a role build only once that's spent, or if you
    -- went another way (a respec is your call).
    if (level or 0) >= MAX_LEVEL and not FollowingLeveling(classFile, talents) then
        local role = DefaultRole(classFile, talents)
        if role then
            return role, false
        end
    end
    return "leveling", false
end

-- ---------------------------------------------------------------------------------------------------
-- Comparing a build with what is spent

local function Lower(text)
    return type(text) == "string" and text:lower() or ""
end

local function IsLetter(char)
    return char ~= "" and char:match("[%a']") ~= nil
end

-- Where each name appears in text as a whole phrase, longest names winning, in reading order.
local function Mentions(text, names)
    local lowered = Lower(text)
    local found = {}
    for _, name in ipairs(names) do
        local needle = Lower(name)
        local start = 1
        while needle ~= "" do
            local s, e = lowered:find(needle, start, true)
            if not s then
                break
            end
            if not IsLetter(lowered:sub(s - 1, s - 1)) and not IsLetter(lowered:sub(e + 1, e + 1)) then
                found[#found + 1] = { s = s, e = e, name = name }
            end
            start = e + 1
        end
    end
    table.sort(found, function(a, b)
        if a.s ~= b.s then
            return a.s < b.s
        end
        return (a.e - a.s) > (b.e - b.s)
    end)
    local kept, reach = {}, 0
    for _, hit in ipairs(found) do
        if hit.s > reach then
            kept[#kept + 1] = hit
            reach = hit.e
        elseif hit.e > reach then
            reach = hit.e
        end
    end
    return kept
end

-- The part of a steps text that is advice to take: alternatives in brackets and "Skip ..." are dropped.
local function TakeText(text)
    text = (type(text) == "string" and text or ""):gsub("%b()", "")
    local cut = text:find("[Ss]kip ")
    return cut and text:sub(1, cut - 1) or text
end

local function WithoutSkips(text)
    text = type(text) == "string" and text or ""
    local cut = text:find("[Ss]kip ")
    return cut and text:sub(1, cut - 1) or text
end

local function KeyTalents(build)
    if type(build.keyTalents) == "table" and #build.keyTalents > 0 then
        return build.keyTalents
    end
    local list, seen = {}, {}
    for _, point in ipairs(build.points or {}) do
        if type(point.talent) == "string" and not seen[point.talent] then
            seen[point.talent] = true
            list[#list + 1] = point.talent
        end
    end
    return list
end

function SpentRank(talents, name)
    local entry = talents and talents.byName[Lower(name)]
    return entry and entry.rank or 0, entry
end

local function CurrentStep(build, level)
    local steps = build.steps or {}
    for _, step in ipairs(steps) do
        if level >= (step.from or 0) and level <= (step.to or MAX_LEVEL) then
            return step
        end
    end
    return steps[1]
end

-- Points spent in one tree.
local function TreeSpent(talents, tree)
    local total = 0
    for _, entry in ipairs(talents and talents.list or {}) do
        if entry.tree == tree then
            total = total + (entry.rank or 0)
        end
    end
    return total
end

-- Whether a talent's row is open: row N needs 5 x (N - 1) points in its tree. True when the row is unknown.
local function RowOpen(talents, entry)
    return not (entry and entry.row and entry.tree) or TreeSpent(talents, entry.tree) >= 5 * (entry.row - 1)
end

-- The next talent to take: { name, tree, rank, level?, step? } or nil, plus the step text for steps builds.
-- A talent whose row isn't open yet (points spent off the build) is passed over for the next one that is.
function NextTalent(build, talents, level)
    if type(build.points) == "table" and #build.points > 0 then
        if not talents then
            return nil
        end
        local first
        for _, point in ipairs(build.points) do
            local rank, entry = SpentRank(talents, point.talent)
            if rank < (point.rank or 1) then
                local pick = { name = point.talent, tree = point.tree, rank = point.rank or 1, level = point.level }
                if RowOpen(talents, entry) then
                    return pick
                end
                first = first or pick
            end
        end
        return first
    end
    local current = CurrentStep(build, level)
    if not talents or not current then
        return nil, current
    end
    local keys = KeyTalents(build)
    local first
    -- Steps up to your level, earliest first, so a talent you skipped earlier comes before later ones.
    for _, step in ipairs(build.steps or {}) do
        if (step.from or 0) > math.max(level, FIRST_TALENT_LEVEL) then
            break
        end
        for _, hit in ipairs(Mentions(TakeText(step.text), keys)) do
            local rank, entry = SpentRank(talents, hit.name)
            local full = entry and entry.maxRank and rank >= entry.maxRank or (not (entry and entry.maxRank) and rank > 0)
            -- A name the game's talent list doesn't have (renamed, or another client) can't be taken.
            local unknown = not entry and talents.list and #talents.list > 0
            if not full and not unknown then
                -- The tree the game gives, else the one the step names before its colon ("Affliction: ...").
                local tree = entry and entry.tree or (type(step.text) == "string" and step.text:match("^(%a[%a ]-):")) or build.spec
                local pick = { name = hit.name, tree = tree, rank = rank + 1, step = step }
                if RowOpen(talents, entry) then
                    return pick, current
                end
                first = first or pick
            end
        end
    end
    return first, current
end

-- Spent talents that the build doesn't mention, as "Name (ranks)".
local function OffBuild(build, talents)
    if not talents then
        return {}
    end
    local onBuild = {}
    for _, name in ipairs(KeyTalents(build)) do
        onBuild[Lower(name)] = true
    end
    if type(build.points) == "table" and #build.points > 0 then
        -- keyTalents is only a highlight list; every talent in the points list is on the build.
        for _, point in ipairs(build.points) do
            if type(point.talent) == "string" then
                onBuild[Lower(point.talent)] = true
            end
        end
    else
        -- Key talents join the list so a short name never matches inside a longer one the API left out.
        local names = {}
        for _, name in ipairs(KeyTalents(build)) do
            names[#names + 1] = name
        end
        for _, entry in ipairs(talents.list) do
            names[#names + 1] = entry.name
        end
        for _, step in ipairs(build.steps or {}) do
            for _, hit in ipairs(Mentions(WithoutSkips(step.text), names)) do
                onBuild[Lower(hit.name)] = true
            end
        end
    end
    local list = {}
    for _, entry in ipairs(talents.list) do
        if entry.rank > 0 and not onBuild[Lower(entry.name)] then
            list[#list + 1] = string.format("%s (%d)", entry.name, entry.rank)
        end
    end
    return list
end

-- ---------------------------------------------------------------------------------------------------
-- Status row (cached; refreshed when level, talents or spells change)

local dirty, cachedRows = true, nil
local panelDirty = true  -- the talent-window panel's text needs redrawing

local function ComputeStatus()
    local classFile = PlayerClass()
    local unspent = UnspentPoints()
    if not classFile or not unspent or unspent <= 0 then
        return nil
    end
    local level = PlayerLevel() or FIRST_TALENT_LEVEL
    local talents = ReadTalents()
    local goal = CurrentGoal(classFile, level, talents)
    local build = BuildFor(classFile, goal)
    if not build then
        return nil
    end
    local nextTalent = NextTalent(build, talents, level)
    if not nextTalent then
        return nil
    end
    return { { text = string.format("|cff88bbeeTalent|r take %s next", nextTalent.name), page = "Builds" } }
end

ForeverHubStatus = ForeverHubStatus or {}
ForeverHubStatus.Builds = function()
    if dirty then
        local ok, rows = pcall(ComputeStatus)
        cachedRows = ok and rows or nil
        dirty = false
    end
    return cachedRows
end

local events = type(CreateFrame) == "function" and CreateFrame("Frame") or nil
if events then
    for _, event in ipairs({ "PLAYER_LOGIN", "PLAYER_LEVEL_UP", "CHARACTER_POINTS_CHANGED", "PLAYER_TALENT_UPDATE", "SPELLS_CHANGED",
        "TRAIT_CONFIG_UPDATED", "TRAIT_CONFIG_LIST_UPDATED", "TRAIT_NODE_CHANGED", "TRAIT_TREE_CURRENCY_INFO_UPDATED", "ACTIVE_TALENT_GROUP_CHANGED" }) do
        pcall(events.RegisterEvent, events, event)
    end
    events:SetScript("OnEvent", function()
        dirty = true
        panelDirty = true
    end)
end

-- ---------------------------------------------------------------------------------------------------
-- Beside the talent window: our own small panel, shown while the game's talent window is open.
-- Rule-safe by construction: the panel is parented to UIParent and placed by reading the talent window's
-- position. Nothing is anchored to, parented to, shown, hidden, hooked or changed on Blizzard's frames.

local TALENT_WINDOWS = { "PlayerTalentFrame", "TalentFrame", "ClassTalentFrame", "PlayerSpellsFrame" }
local PANEL_WIDTH, PANEL_LINES = 260, 9

-- The next few points the build still wants, in order: { { name, tree, rank, level } }.
local function Upcoming(build, talents, count)
    local list = {}
    if type(build.points) ~= "table" or not talents then
        return list
    end
    for _, point in ipairs(build.points) do
        if SpentRank(talents, point.talent) < (point.rank or 1) then
            list[#list + 1] = { name = point.talent, tree = point.tree, rank = point.rank or 1, level = point.level }
            if #list >= count then
                break
            end
        end
    end
    return list
end

local function TalentWhere(talents, name, tree)
    local _, entry = SpentRank(talents, name)
    local where = (entry and entry.tree) or tree
    if entry and entry.row then
        where = (where and (where .. ", ") or "") .. "row " .. entry.row
    end
    return where and (GRAY .. " (" .. where .. ")|r") or ""
end

-- The panel's text lines (also used by the tests).
function Builds_TalentPanelLines()
    local classFile = PlayerClass()
    if not classFile then
        return nil
    end
    local level = PlayerLevel() or FIRST_TALENT_LEVEL
    local talents = ReadTalents()
    local goal = CurrentGoal(classFile, level, talents)
    local build = BuildFor(classFile, goal)
    if not build then
        return nil
    end
    local lines = { GOLD .. "Build:|r " .. (build.name or GOAL_LABELS[goal] or goal) }
    if not talents then
        lines[#lines + 1] = GRAY .. "Your talents can't be read right now." .. "|r"
    end
    local unspent = UnspentPoints() or 0
    local upcoming = Upcoming(build, talents, unspent > 0 and math.max(unspent, 3) or 3)
    if #upcoming > 0 then
        lines[#lines + 1] = unspent > 0 and (GREEN .. "Spend now:|r") or (GOLD .. "Coming up:|r")
        for index, point in ipairs(upcoming) do
            local label = string.format("%s%s %d|r%s", index <= unspent and GREEN or "", point.name, point.rank, TalentWhere(talents, point.name, point.tree))
            if index > unspent and point.level then
                label = label .. GRAY .. " at " .. point.level .. "|r"
            end
            lines[#lines + 1] = label
        end
    else
        local nextTalent, step = NextTalent(build, talents, level)
        if nextTalent then
            lines[#lines + 1] = (unspent > 0 and GREEN .. "Spend now:|r " or GOLD .. "Next:|r ") .. nextTalent.name .. TalentWhere(talents, nextTalent.name, nextTalent.tree)
        elseif step and step.text then
            lines[#lines + 1] = GOLD .. "Now:|r " .. step.text
        elseif talents then
            lines[#lines + 1] = GREEN .. "Everything the build asks for is taken.|r"
        end
    end
    local off = OffBuild(build, talents)
    if #off > 0 then
        lines[#lines + 1] = "|cffff8800Not in this build:|r " .. table.concat(off, ", ")
    end
    lines[#lines + 1] = GRAY .. "Click for the full build (Forever Hub > Builds).|r"
    return lines
end

local panel, panelText

-- Forever's talent window name isn't in the UI source we have, so besides the known names, look once
-- (and again when a Blizzard talent addon loads) for top-level frames named "...Talent...Frame".
local function DiscoverTalentWindows()
    local known = {}
    for _, name in ipairs(TALENT_WINDOWS) do
        known[name] = true
    end
    for key, value in pairs(_G) do
        if type(key) == "string" and not known[key] and key:find("Talent", 1, true) and key:sub(-5) == "Frame"
            and not key:find("^Builds") and type(value) == "table" and type(value.GetParent) == "function" then
            local ok, parent = pcall(value.GetParent, value)
            if ok and parent ~= nil and parent == UIParent then
                TALENT_WINDOWS[#TALENT_WINDOWS + 1] = key
                known[key] = true
            end
        end
    end
end

local function TalentWindow()
    for _, name in ipairs(TALENT_WINDOWS) do
        local frame = _G[name]
        if type(frame) == "table" and type(frame.IsShown) == "function" then
            local ok, shown = pcall(frame.IsShown, frame)
            if ok and Safe(shown) == true then
                return frame
            end
        end
    end
end

local function Rect(frame)
    local ok, left, right, top, scale = pcall(function()
        return frame:GetLeft(), frame:GetRight(), frame:GetTop(), frame:GetEffectiveScale()
    end)
    if not ok then
        return nil
    end
    left, right, top, scale = Number(left), Number(right), Number(top), Number(scale)
    if left and right and top and scale and scale > 0 then
        return left * scale, right * scale, top * scale
    end
end

local function PlacePanel(window)
    local left, right, top = Rect(window)
    local uiScale = Number(SafeCall(function() return UIParent:GetEffectiveScale() end)) or 1
    local screenWidth = Number(SafeCall(function() return UIParent:GetWidth() end)) or 1920
    if not left then
        return false
    end
    local x = right / uiScale + 4
    if x + PANEL_WIDTH > screenWidth then
        x = left / uiScale - PANEL_WIDTH - 4
    end
    panel:ClearAllPoints()
    panel:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", math.max(x, 0), top / uiScale)
    return true
end

local function MakePanel()
    if panel or type(CreateFrame) ~= "function" or not UIParent then
        return panel
    end
    panel = CreateFrame("Button", "BuildsTalentPanel", UIParent)
    panel:SetSize(PANEL_WIDTH, 40)
    panel:SetFrameStrata("HIGH")
    panel:Hide()
    local bg = panel:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0, 0, 0, 0.8)
    panelText = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    panelText:SetPoint("TOPLEFT", 8, -8)
    panelText:SetWidth(PANEL_WIDTH - 16)
    panelText:SetJustifyH("LEFT")
    panelText:SetSpacing(2)
    panel:SetScript("OnClick", function()
        if ForeverHub_OpenPage then
            pcall(ForeverHub_OpenPage, "Builds")
        end
    end)
    return panel
end

-- Returns true when the panel has text to show.
local function RefreshPanel()
    local ok, lines = pcall(Builds_TalentPanelLines)
    if not ok or not lines then
        return false
    end
    while #lines > PANEL_LINES do
        table.remove(lines, #lines - 1)
    end
    panelText:SetText(table.concat(lines, "\n"))
    local height = Number(SafeCall(function() return panelText:GetStringHeight() end)) or (#lines * 14)
    panel:SetHeight(height + 16)
    return true
end

local watcher = type(CreateFrame) == "function" and CreateFrame("Frame") or nil
if watcher then
    pcall(watcher.RegisterEvent, watcher, "PLAYER_LOGIN")
    pcall(watcher.RegisterEvent, watcher, "ADDON_LOADED")
    watcher:SetScript("OnEvent", function(_, event, addon)
        if event == "PLAYER_LOGIN" or (type(Safe(addon)) == "string" and addon:find("Talent", 1, true)) then
            pcall(DiscoverTalentWindows)
        end
    end)
    local elapsedSince = 0
    local hasText = false  -- the last redraw had something to show
    watcher:SetScript("OnUpdate", function(_, elapsed)
        elapsedSince = elapsedSince + (elapsed or 0)
        if elapsedSince < 0.25 then
            return
        end
        elapsedSince = 0
        local window = (not (ForeverHub_IsOff and ForeverHub_IsOff("Builds"))) and TalentWindow() or nil
        if not window then
            if panel and panel:IsShown() then
                panel:Hide()
            end
            panelDirty = true
            return
        end
        -- The panel is made once, out of combat (the talent window can't be opened in combat anyway).
        if not panel and InCombatLockdown and InCombatLockdown() then
            return
        end
        if not MakePanel() or not PlacePanel(window) then
            return
        end
        -- Redrawn when something changed (closing the window marks it too); with nothing to show the
        -- panel stays hidden until the next change, never an empty box.
        if panelDirty then
            hasText = RefreshPanel()
            panelDirty = false
        end
        if not hasText then
            if panel:IsShown() then
                panel:Hide()
            end
            return
        end
        panel:Show()
    end)
end

-- ---------------------------------------------------------------------------------------------------
-- Page

local function Domain(url)
    return type(url) == "string" and (url:match("^%a+://([^/]+)") or url):gsub("^www%.", "") or "unknown"
end

local function Confidence(build)
    local value = type(build.confidence) == "string" and build.confidence or "unknown"
    return value .. " confidence"
end

-- ", order: from guide" for a points build whose orderFrom is known; "" otherwise (steps have no order).
local function OrderNote(build)
    local label = type(build.points) == "table" and #build.points > 0 and ORDER_LABELS[build.orderFrom]
    return label and ", " .. label or ""
end

local function StatsLine(build)
    if type(build.stats) == "table" and #build.stats > 0 then
        return "Stats: " .. table.concat(build.stats, " > ")
    end
end

local function TrainLine(classFile, level)
    local leveling = BuildFor(classFile, "leveling")
    local near = {}
    for _, entry in ipairs(leveling and leveling.train or {}) do
        local at = tonumber(type(entry) == "string" and entry:match("%((%d+)") or nil)
        if at and at >= level - TRAIN_BEHIND and at <= level + TRAIN_AHEAD then
            near[#near + 1] = entry
        end
    end
    if #near > 0 then
        return "Trainer, near your level: " .. table.concat(near, ", ")
    end
end

local function GoalChoices(classFile)
    return table.concat(Available(classFile), ", ")
end

local function ShowMain(prefix)
    local classFile, localized = PlayerClass()
    if prefix then
        Print(prefix)
    end
    if not classFile then
        Print("The game didn't say what class you are yet. Try again in a moment.")
        return
    end
    local className = localized or CLASS_NAMES[classFile] or classFile
    if not (BuildsData and BuildsData[classFile]) then
        Print(string.format("No builds are saved for %s yet.", className))
        return
    end
    local level = PlayerLevel()
    local talents = ReadTalents()
    local goal, chosen = CurrentGoal(classFile, level or FIRST_TALENT_LEVEL, talents)
    local build = BuildFor(classFile, goal)
    Print(string.format("%s%s|r, goal: %s%s", GOLD, className, GOAL_LABELS[goal] or goal, chosen and "" or GRAY .. " (default for your level)|r"))
    Print(string.format("%s%s|r  %s(%s, from %s, checked %s%s)|r", GOLD, build.name or "Build", GRAY, Confidence(build), Domain(build.source),
        build.checked or "?", OrderNote(build)))
    Print(GRAY .. "Forever is new (launched November 2026). These builds were rechecked after Blizzard's 2026-11-10 class tuning, but guides may still change.|r")
    if build.summary then
        Print(build.summary)
    end

    local lvl = level or FIRST_TALENT_LEVEL
    local nextTalent, step = NextTalent(build, talents, lvl)
    if not talents then
        Print(GRAY .. "Your talents can't be read right now, so this page can't tell what you have taken.|r")
        if type(build.points) == "table" then
            local due
            for _, point in ipairs(build.points) do
                if (point.level or 0) <= lvl then
                    due = point
                end
            end
            if due then
                Print(string.format("%sAt level %d the build takes:|r %s (%s, rank %d)", GOLD, due.level, due.talent, due.tree or "?", due.rank or 1))
            end
        end
    end
    if nextTalent then
        local when = nextTalent.level and level and nextTalent.level > level and string.format(" at level %d", nextTalent.level) or ""
        Print(string.format("%sNext talent:|r %s (%s, rank %d)%s", GOLD, nextTalent.name, nextTalent.tree or "?", nextTalent.rank, when))
    elseif talents and type(build.points) == "table" and #build.points > 0 then
        Print(GREEN .. "Every point in this build is spent.|r")
    elseif talents and step then
        Print(GOLD .. "Next talent:|r this level's picks are taken; spend spare points as the next step says.")
    end
    if step and step.text then
        Print(string.format("%sLevels %d-%d:|r %s", GOLD, step.from or 0, step.to or MAX_LEVEL, step.text))
    end

    local keys = KeyTalents(build)
    if #keys > 0 then
        local parts = {}
        for _, name in ipairs(keys) do
            local rank = SpentRank(talents, name)
            parts[#parts + 1] = (talents and rank > 0) and (TICK .. name) or (GRAY .. name .. "|r")
        end
        Print("Key talents: " .. table.concat(parts, ", "))
    end

    local off = OffBuild(build, talents)
    if #off > 0 then
        Print(GRAY .. "Off-build points: " .. table.concat(off, ", ") .. " - fine if you chose them.|r")
    end

    local stats = StatsLine(build)
    if stats then
        Print(stats)
    end
    if level then
        local train = TrainLine(classFile, level)
        if train then
            Print(train)
        end
    end
    local unspent = UnspentPoints()
    if unspent then
        Print(string.format("Unspent talent points: %d", unspent))
    end
    Print(GRAY .. "Choose a goal: " .. GoalChoices(classFile) .. ". Or: all, or a class name for alts.|r")
end

local function BuildLine(classFile, goal)
    local build = BuildFor(classFile, goal)
    return string.format("%s%s|r: %s %s(%s, %s)|r", GOLD, GOAL_LABELS[goal] or goal, build.name or "Build", GRAY, Confidence(build), Domain(build.source))
end

local function ShowAll(classFile, detailed)
    local className = CLASS_NAMES[classFile] or classFile
    Print(string.format("%s%s builds|r", GOLD, className))
    for _, goal in ipairs(Available(classFile)) do
        Print(BuildLine(classFile, goal))
        if detailed then
            local build = BuildFor(classFile, goal)
            if build.summary then
                Print("    " .. build.summary)
            end
            local stats = StatsLine(build)
            if stats then
                Print("    " .. GRAY .. stats .. "|r")
            end
        end
    end
end

local function ClassFromArg(arg)
    local word = arg:gsub("%s+", "")
    for _, classFile in ipairs(CLASS_ORDER) do
        local lower = classFile:lower()
        if word == lower or word == lower .. "s" then
            return classFile
        end
    end
end

SLASH_BUILDS1 = "/builds"
SlashCmdList.BUILDS = function(msg)
    local arg = Lower(type(msg) == "string" and msg or ""):gsub("^%s+", ""):gsub("%s+$", "")
    local classFile = PlayerClass()
    if arg == "" then
        return ShowMain()
    end
    if arg == "all" then
        if not classFile then
            return Print("The game didn't say what class you are yet. Try again in a moment.")
        end
        return ShowAll(classFile, false)
    end
    local goal = arg
    if goal == "pve" then
        goal = classFile and DefaultRole(classFile, ReadTalents()) or "dps"
    elseif goal == "heal" or goal == "healing" then
        goal = "healer"
    elseif goal == "damage" then
        goal = "dps"
    elseif goal == "balance" or goal == "moonkin" then
        goal = "dps2"
    end
    if GOAL_LABELS[goal] then
        if not classFile then
            return Print("The game didn't say what class you are yet. Try again in a moment.")
        end
        if not BuildFor(classFile, goal) then
            return Print(string.format("There is no %s build for %s. Choose: %s.", GOAL_LABELS[goal], CLASS_NAMES[classFile] or classFile, GoalChoices(classFile)))
        end
        Record().goal = goal
        dirty = true
        panelDirty = true
        return ShowMain(GREEN .. "Goal set: " .. GOAL_LABELS[goal] .. "|r")
    end
    local alt = ClassFromArg(arg)
    if alt and BuildsData and BuildsData[alt] then
        return ShowAll(alt, true)
    end
    Print("Type a goal: leveling, pvp, pvp2, tank, healer, dps, dps2. Or: all, or a class name like mage.")
end
