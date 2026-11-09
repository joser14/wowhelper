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

-- Every talent the game lists: { byName = { [lower name] = { name, tree, rank, maxRank } }, list = {...},
-- spent = total points }, or nil when no talent could be read at all.
local function ReadTalents()
    local hasLegacy = type(GetTalentInfo) == "function"
    local hasSpec = C_SpecializationInfo and type(C_SpecializationInfo.GetTalentInfo) == "function"
    if not (hasLegacy or hasSpec) then
        return nil
    end
    local tabs = Number(SafeCall(GetNumTalentTabs)) or 3
    local group = ActiveGroup()
    local result = { byName = {}, list = {}, spent = 0 }
    for tab = 1, math.min(math.max(tabs, 0), MAX_TABS) do
        local tree = TabName(tab) or ("Tree " .. tab)
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
        local bestRole, bestPoints
        for _, role in ipairs(DEFAULT_ROLE_ORDER) do
            local build = pve[role]
            local points = build and perTree[build.spec] or 0
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

local function CurrentGoal(classFile, level, talents)
    local saved = Record().goal
    if saved and BuildFor(classFile, saved) then
        return saved, true
    end
    if (level or 0) >= MAX_LEVEL then
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

local function SpentRank(talents, name)
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

-- The next talent to take: { name, tree, rank, level?, step? } or nil, plus the step text for steps builds.
local function NextTalent(build, talents, level)
    if type(build.points) == "table" and #build.points > 0 then
        if not talents then
            return nil
        end
        for _, point in ipairs(build.points) do
            if SpentRank(talents, point.talent) < (point.rank or 1) then
                return { name = point.talent, tree = point.tree, rank = point.rank or 1, level = point.level }
            end
        end
        return nil
    end
    local current = CurrentStep(build, level)
    if not talents or not current then
        return nil, current
    end
    local keys = KeyTalents(build)
    -- Steps up to your level, earliest first, so a talent you skipped earlier comes before later ones.
    for _, step in ipairs(build.steps or {}) do
        if (step.from or 0) > math.max(level, FIRST_TALENT_LEVEL) then
            break
        end
        for _, hit in ipairs(Mentions(TakeText(step.text), keys)) do
            local rank, entry = SpentRank(talents, hit.name)
            local full = entry and entry.maxRank and rank >= entry.maxRank or (not (entry and entry.maxRank) and rank > 0)
            if not full then
                return { name = hit.name, tree = entry and entry.tree or build.spec, rank = rank + 1, step = step }, current
            end
        end
    end
    return nil, current
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
        "TRAIT_CONFIG_UPDATED", "ACTIVE_TALENT_GROUP_CHANGED" }) do
        pcall(events.RegisterEvent, events, event)
    end
    events:SetScript("OnEvent", function()
        dirty = true
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
    Print(GRAY .. "Forever is new (launched November 2026) and Blizzard announced class tuning for 2026-11-10, so these builds may change.|r")
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
        return ShowMain(GREEN .. "Goal set: " .. GOAL_LABELS[goal] .. "|r")
    end
    local alt = ClassFromArg(arg)
    if alt and BuildsData and BuildsData[alt] then
        return ShowAll(alt, true)
    end
    Print("Type a goal: leveling, pvp, pvp2, tank, healer, dps, dps2. Or: all, or a class name like mage.")
end
