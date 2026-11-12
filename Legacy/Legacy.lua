-- Legacy (round 6 #1): Forever's Legacy challenges you haven't finished yet, the Legacy points each one pays,
-- and your progress where the game shows it. Legacy points are account-wide and buy leveling perks in
-- Blizzard's Legacy panel (Well Rested, Talented, Frequent Flier, ...). Only shows information.
--
-- How it reads them: Legacy challenges are achievements. The class's default Legacy category comes from
-- Constants.LegacyConsts (LegacyConstantsDocumentation); every category in the same family is walked, and an
-- achievement counts as a Legacy challenge when C_Traits.GetTraitCurrencyForAchievement(4225, id) pays points
-- (SharedTraitsDocumentation). The achievement calls themselves (GetCategoryList, GetCategoryInfo,
-- GetCategoryNumAchievements, GetAchievementInfo, GetAchievementNumCriteria, GetAchievementCriteriaInfo) are
-- old globals that aren't in the client's API docs: every call is guarded, and a missing one only shortens
-- the page. Idea credit: Legacy Forever (cjber, GPL-3.0-or-later); written here from scratch.

-- Constants.LegacyConsts on this client (LegacyConstantsDocumentation); used when the table isn't there.
local FALLBACK = {
    LEGACY_POINTS_TRAIT_CURRENCY_ID = 4225,
    LEGACY_TREE_PROFESSIONS_ID = 1187, LEGACY_TREE_ADVENTURE_ID = 1188, LEGACY_TREE_PROGRESSION_ID = 1189,
    LEGACY_DEFAULT_CATEGORY_WARRIOR = 15585, LEGACY_DEFAULT_CATEGORY_PALADIN = 15580,
    LEGACY_DEFAULT_CATEGORY_HUNTER = 15578, LEGACY_DEFAULT_CATEGORY_ROGUE = 15582,
    LEGACY_DEFAULT_CATEGORY_PRIEST = 15581, LEGACY_DEFAULT_CATEGORY_SHAMAN = 15583,
    LEGACY_DEFAULT_CATEGORY_MAGE = 15579, LEGACY_DEFAULT_CATEGORY_WARLOCK = 15584,
    LEGACY_DEFAULT_CATEGORY_DRUID = 15577,
}
local CLASSES = { "WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST", "SHAMAN", "MAGE", "WARLOCK", "DRUID" }

-- Bounds, so a client with a huge achievement list can't stall a frame or grow the cache without limit.
local MAX_CATEGORIES = 400
local MAX_PER_CATEGORY = 300
local MAX_CHALLENGES = 1500
local MAX_CRITERIA = 60
local MAX_LEFT_NAMES = 4
local MAX_DEPTH = 12
local REBUILD_SECONDS = 10

local state = {
    dirty = true,
    builtAt = nil,
    list = {},          -- unfinished challenges
    doneCount = 0,
    donePoints = 0,
    done = {},          -- names of finished challenges (bounded by MAX_CHALLENGES)
    hiddenOther = 0,    -- challenges in other classes' categories, left out
    pointsKnown = true, -- false when GetTraitCurrencyForAchievement is missing
    source = nil,       -- "legacy" (found the Legacy categories) or "all" (scanned everything)
}

local function Safe(value)
    if issecretvalue and issecretvalue(value) then
        return nil
    end
    return value
end

local function Print(text)
    if ForeverHub_Receive then
        return ForeverHub_Receive("Legacy", text)
    end
    -- No hub window to show it in: stay quiet rather than fill the chat.
end

local function IsOff()
    return type(ForeverHub_IsOff) == "function" and ForeverHub_IsOff("Legacy") == true
end

local function InCombat()
    return InCombatLockdown and Safe(InCombatLockdown()) == true
end

local function Now()
    local now = type(GetTime) == "function" and Safe(GetTime())
    return type(now) == "number" and now or 0
end

-- A plain string or number from a call that may be missing, fail or answer with secrets.
local function Num(value)
    value = Safe(value)
    return type(value) == "number" and value or nil
end

local function Str(value)
    value = Safe(value)
    return type(value) == "string" and value ~= "" and value or nil
end

local function Const(name)
    local consts = type(Constants) == "table" and Constants.LegacyConsts
    local value = type(consts) == "table" and Num(consts[name])
    return value or FALLBACK[name]
end

local function PlayerClass()
    if not UnitClass then
        return nil
    end
    local ok, _, classFile = pcall(UnitClass, "player")
    return ok and Str(classFile) or nil
end

----- Achievements ------------------------------------------------------------------------------------------

local function CategoryParent(id)
    if type(GetCategoryInfo) ~= "function" then
        return nil
    end
    local ok, _, parent = pcall(GetCategoryInfo, id)
    parent = ok and Num(parent)
    if parent and parent > 0 then
        return parent
    end
    return nil
end

local function CategoryTitle(id)
    if type(GetCategoryInfo) ~= "function" then
        return nil
    end
    local ok, title = pcall(GetCategoryInfo, id)
    return ok and Str(title) or nil
end

-- The top of a category's family (itself when it has no parent).
local function Root(id)
    local depth = 0
    local parent = CategoryParent(id)
    while parent and depth < MAX_DEPTH do
        id, depth = parent, depth + 1
        parent = CategoryParent(id)
    end
    return id
end

-- True when the category is `ancestor` or sits somewhere below it.
local function Under(id, ancestor)
    local depth = 0
    while id and depth <= MAX_DEPTH do
        if id == ancestor then
            return true
        end
        id, depth = CategoryParent(id), depth + 1
    end
    return false
end

local function AllCategories()
    if type(GetCategoryList) ~= "function" then
        return {}
    end
    local ok, list = pcall(GetCategoryList)
    list = ok and Safe(list)
    local out = {}
    if type(list) == "table" then
        for _, id in ipairs(list) do
            id = Num(id)
            if id and #out < MAX_CATEGORIES then
                out[#out + 1] = id
            end
        end
    end
    return out
end

-- The categories to read, and the other classes' default categories (left out of the page).
local function LegacyCategories()
    local class = PlayerClass()
    local mine = class and Const("LEGACY_DEFAULT_CATEGORY_" .. class)
    local others = {}
    for _, c in ipairs(CLASSES) do
        local id = Const("LEGACY_DEFAULT_CATEGORY_" .. c)
        if c ~= class and id then
            others[#others + 1] = id
        end
    end
    local all = AllCategories()
    local root = mine and Root(mine)
    local picked = {}
    if root then
        for _, id in ipairs(all) do
            if Under(id, root) then
                picked[#picked + 1] = id
            end
        end
        if #picked == 0 then
            -- No category list on this client: the class's own category is still worth reading.
            picked[1] = mine
            if root ~= mine then
                picked[2] = root
            end
        end
        return picked, others, "legacy"
    end
    -- No Legacy constants for this class: read everything; only achievements paying points are kept.
    return all, others, "all"
end

local function PointsFor(id)
    if not (C_Traits and type(C_Traits.GetTraitCurrencyForAchievement) == "function") then
        return nil
    end
    local ok, amount = pcall(C_Traits.GetTraitCurrencyForAchievement, Const("LEGACY_POINTS_TRAIT_CURRENCY_ID"), id)
    return ok and Num(amount) or nil
end

-- Progress on one challenge: have, need, and the names of what's left (a few of them).
local function Progress(id)
    if type(GetAchievementNumCriteria) ~= "function" or type(GetAchievementCriteriaInfo) ~= "function" then
        return nil
    end
    local ok, count = pcall(GetAchievementNumCriteria, id)
    count = ok and Num(count)
    if not count or count < 1 then
        return nil
    end
    count = math.min(count, MAX_CRITERIA)
    local doneCount, left, readable = 0, {}, 0
    local single
    for index = 1, count do
        local okc, text, _, completed, quantity, required = pcall(GetAchievementCriteriaInfo, id, index)
        if okc then
            completed = Safe(completed)
            if completed ~= nil then
                readable = readable + 1
                if completed then
                    doneCount = doneCount + 1
                elseif #left < MAX_LEFT_NAMES then
                    left[#left + 1] = Str(text)
                end
            end
            if count == 1 then
                single = { Num(quantity), Num(required), completed }
            end
        end
    end
    -- One counter ("Complete 10 dungeons"): the counter is the progress.
    if single and single[1] and single[2] and single[2] > 1 then
        return { have = math.min(single[1], single[2]), need = single[2], left = {} }
    end
    if readable == 0 then
        return nil
    end
    return { have = doneCount, need = count, left = left }
end

local function Build()
    local categories, others, source = LegacyCategories()
    local otherSet = {}
    for _, id in ipairs(others) do
        otherSet[id] = true
    end
    local seen, list, done = {}, {}, {}
    local doneCount, donePoints, hiddenOther = 0, 0, 0
    local pointsKnown = C_Traits and type(C_Traits.GetTraitCurrencyForAchievement) == "function" or false
    local total = 0
    for _, category in ipairs(categories) do
        -- In another class's family when that class's default category is this one or above it.
        local other, step, depth = false, category, 0
        while step and depth <= MAX_DEPTH and not other do
            other = otherSet[step] == true
            step, depth = CategoryParent(step), depth + 1
        end
        local count
        if type(GetCategoryNumAchievements) == "function" then
            local ok, n = pcall(GetCategoryNumAchievements, category, true)
            count = ok and Num(n) or 0
        else
            count = 0
        end
        local title = CategoryTitle(category) or "Other"
        for index = 1, math.min(count, MAX_PER_CATEGORY) do
            if total >= MAX_CHALLENGES then
                break
            end
            local ok, id, name, _, completed, _, _, _, description = pcall(GetAchievementInfo, category, index)
            id, name = ok and Num(id), ok and Str(name)
            if id and name and not seen[id] then
                seen[id] = true
                local points = PointsFor(id)
                -- Points known and zero: an ordinary achievement, not a Legacy challenge. When the points
                -- call is missing, only the Legacy categories are trusted.
                local legacy = (points and points > 0) or (not pointsKnown and source == "legacy")
                if legacy then
                    total = total + 1
                    completed = Safe(completed)
                    if other then
                        if not completed then
                            hiddenOther = hiddenOther + 1
                        end
                    elseif completed then
                        doneCount = doneCount + 1
                        donePoints = donePoints + (points or 0)
                        done[#done + 1] = name
                    else
                        list[#list + 1] = {
                            id = id, name = name, description = Str(description), category = title,
                            points = points, progress = Progress(id),
                        }
                    end
                end
            end
        end
    end
    state.list, state.done, state.doneCount, state.donePoints = list, done, doneCount, donePoints
    state.hiddenOther, state.pointsKnown, state.source = hiddenOther, pointsKnown, source
    state.dirty, state.builtAt = false, Now()
end

-- Rebuilds when something changed, out of combat only (criteria reads may be secret in combat), and at
-- most every REBUILD_SECONDS unless `force` (the page was opened).
local function Refresh(force)
    if IsOff() or InCombat() then
        return
    end
    if not state.dirty and state.builtAt then
        return
    end
    if not force and state.builtAt and Now() - state.builtAt < REBUILD_SECONDS then
        return
    end
    local ok, err = pcall(Build)
    if not ok then
        state.dirty, state.builtAt = false, Now()
        if geterrorhandler then
            geterrorhandler()(err)
        end
    end
end

----- Points ------------------------------------------------------------------------------------------------

-- Unspent and spent Legacy points, from the Legacy trees' currency (nil when the game doesn't say).
local function PointsSummary()
    if not (C_Traits and type(C_Traits.GetConfigIDByTreeID) == "function"
        and type(C_Traits.GetTreeCurrencyInfo) == "function") then
        return nil
    end
    local currency = Const("LEGACY_POINTS_TRAIT_CURRENCY_ID")
    local unspent, spentTotal, spentInTrees, allTrees = nil, nil, 0, true
    for _, key in ipairs({ "LEGACY_TREE_PROFESSIONS_ID", "LEGACY_TREE_ADVENTURE_ID", "LEGACY_TREE_PROGRESSION_ID" }) do
        local tree = Const(key)
        local ok, config = pcall(C_Traits.GetConfigIDByTreeID, tree)
        config = ok and Num(config)
        local found = false
        if config then
            local okc, infos = pcall(C_Traits.GetTreeCurrencyInfo, config, tree, false)
            infos = okc and Safe(infos)
            for _, info in ipairs(type(infos) == "table" and infos or {}) do
                if type(info) == "table" and Num(info.traitCurrencyID) == currency then
                    found = true
                    unspent = unspent or Num(info.quantity)
                    spentTotal = spentTotal or Num(info.spent)
                    local inTree = Num(info.spentInTree)
                    if inTree then
                        spentInTrees = spentInTrees + inTree
                    else
                        allTrees = false
                    end
                end
            end
        end
        allTrees = allTrees and found
    end
    if unspent == nil and spentTotal == nil then
        return nil
    end
    return unspent, allTrees and spentInTrees or spentTotal
end

----- Text --------------------------------------------------------------------------------------------------

local function ZoneName()
    if C_Map and C_Map.GetBestMapForUnit and C_Map.GetMapInfo then
        local ok, map = pcall(C_Map.GetBestMapForUnit, "player")
        map = ok and Num(map)
        if map then
            local okm, info = pcall(C_Map.GetMapInfo, map)
            info = okm and Safe(info)
            local name = type(info) == "table" and Str(info.name)
            if name then
                return name
            end
        end
    end
    if type(GetRealZoneText) == "function" then
        local ok, name = pcall(GetRealZoneText)
        return ok and Str(name) or nil
    end
    return nil
end

local function InZone(entry, zone)
    if not zone then
        return false
    end
    local z = zone:lower()
    return entry.name:lower():find(z, 1, true) ~= nil
        or (entry.description and entry.description:lower():find(z, 1, true) ~= nil)
end

local function Fraction(entry)
    local p = entry.progress
    return p and p.need > 0 and p.have / p.need or 0
end

local function PointsText(points)
    if not points then
        return ""
    end
    return string.format(", |cff66ccff+%d point%s|r", points, points == 1 and "" or "s")
end

local function EntryText(entry, indent)
    local text = indent .. entry.name
    local p = entry.progress
    if p then
        text = text .. string.format(": %d/%d", p.have, p.need)
        local remaining = p.need - p.have
        if #p.left > 0 then
            local more = remaining > #p.left and string.format(" and %d more", remaining - #p.left) or ""
            text = text .. " |cff999999(left: " .. table.concat(p.left, ", ") .. more .. ")|r"
        end
    elseif entry.description then
        text = text .. " |cff999999- " .. entry.description .. "|r"
    end
    return text .. PointsText(entry.points)
end

local function Sorted(list)
    local copy = {}
    for i, entry in ipairs(list) do
        copy[i] = entry
    end
    table.sort(copy, function(a, b)
        local fa, fb = Fraction(a), Fraction(b)
        if fa ~= fb then
            return fa > fb
        end
        return a.name < b.name
    end)
    return copy
end

local function HeaderLines()
    local unspent, spent = PointsSummary()
    local pending = 0
    for _, entry in ipairs(state.list) do
        pending = pending + (entry.points or 0)
    end
    if unspent or spent then
        Print(string.format("|cffffd100Legacy points|r: %d to spend, %d spent. Spend them in Blizzard's Legacy panel.",
            unspent or 0, spent or 0))
    end
    if state.pointsKnown then
        Print(string.format("%d unfinished challenge%s, worth %d more point%s. %d finished.",
            #state.list, #state.list == 1 and "" or "s", pending, pending == 1 and "" or "s", state.doneCount))
    else
        Print(string.format("%d unfinished challenge%s, %d finished. |cff999999(This client doesn't say what each pays.)|r",
            #state.list, #state.list == 1 and "" or "s", state.doneCount))
    end
    if InCombat() then
        Print("|cff999999Progress refreshes after combat.|r")
    end
end

local function ShowZone(zone, alone)
    local here = {}
    for _, entry in ipairs(state.list) do
        if InZone(entry, zone) then
            here[#here + 1] = entry
        end
    end
    if #here == 0 then
        if alone then
            Print(zone and ("No unfinished Legacy challenges name " .. zone .. ".") or "Can't tell which zone you're in.")
        end
        return
    end
    Print(" ")
    Print("|cffffd100In " .. zone .. "|r")
    for _, entry in ipairs(Sorted(here)) do
        Print(EntryText(entry, "  "))
    end
end

local function ShowUnfinished()
    HeaderLines()
    if #state.list == 0 then
        if state.doneCount > 0 then
            Print("Every Legacy challenge this character can see is done.")
        else
            Print("No Legacy challenges found. They may not have loaded yet: open this page again in a moment.")
            Print("|cff999999If it stays empty, the game may not show Legacy challenges to addons on this client.|r")
        end
        return
    end
    ShowZone(ZoneName(), false)
    local groups, order = {}, {}
    for _, entry in ipairs(state.list) do
        if not groups[entry.category] then
            groups[entry.category] = {}
            order[#order + 1] = entry.category
        end
        table.insert(groups[entry.category], entry)
    end
    table.sort(order)
    for _, title in ipairs(order) do
        Print(" ")
        Print("|cffffd100" .. title .. "|r")
        for _, entry in ipairs(Sorted(groups[title])) do
            Print(EntryText(entry, "  "))
        end
    end
    if state.hiddenOther > 0 then
        Print(" ")
        Print(string.format("|cff999999Not shown: %d challenge%s for other classes (play that class to earn them).|r",
            state.hiddenOther, state.hiddenOther == 1 and "" or "s"))
    end
end

local function ShowDone()
    Print(string.format("|cffffd100Finished Legacy challenges|r: %d%s", state.doneCount,
        state.pointsKnown and string.format(", %d point%s", state.donePoints, state.donePoints == 1 and "" or "s") or ""))
    local names = {}
    for i, name in ipairs(state.done) do
        names[i] = name
    end
    table.sort(names)
    for _, name in ipairs(names) do
        Print("  " .. name)
    end
end

-- The hub's Legacy page runs this: "" for unfinished challenges, "zone" for this zone, "done" for finished.
local function Show(message)
    if IsOff() then
        return
    end
    Refresh(true)
    local arg = type(message) == "string" and message:lower():match("^%s*(%S*)") or ""
    if arg == "done" then
        ShowDone()
    elseif arg == "zone" then
        HeaderLines()
        ShowZone(ZoneName(), true)
    else
        ShowUnfinished()
    end
end

----- Side panel --------------------------------------------------------------------------------------------

-- The closest unfinished challenge named after the zone you're in, if any.
ForeverHubStatus = ForeverHubStatus or {}
ForeverHubStatus.Legacy = function()
    if IsOff() then
        return nil
    end
    Refresh(false)
    local zone = ZoneName()
    local best
    for _, entry in ipairs(state.list) do
        if InZone(entry, zone) and (not best or Fraction(entry) > Fraction(best)) then
            best = entry
        end
    end
    if not best then
        return nil
    end
    local p = best.progress
    local progress = p and string.format(" %d/%d", p.have, p.need) or ""
    local points = best.points and string.format(", +%d point%s", best.points, best.points == 1 and "" or "s") or ""
    return { { text = "|cffffd100Legacy|r " .. best.name .. progress .. points, page = "Legacy" } }
end

----- Events ------------------------------------------------------------------------------------------------

-- Each only marks the list stale; the work happens when the page or the side panel next asks.
local EVENTS = { "PLAYER_ENTERING_WORLD", "RECEIVED_ACHIEVEMENT_LIST", "CRITERIA_UPDATE", "ACHIEVEMENT_EARNED",
    "MAP_EXPLORATION_UPDATED", "TRAIT_CONFIG_UPDATED" }

local events = CreateFrame("Frame")

local function Listen(on)
    if on then
        for _, name in ipairs(EVENTS) do
            pcall(events.RegisterEvent, events, name)
        end
    elseif events.UnregisterAllEvents then
        events:UnregisterAllEvents()
    end
    events:RegisterEvent("PLAYER_LOGIN")
end

events:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_LOGIN" then
        if IsOff() then
            Listen(false)
        end
        return
    end
    state.dirty = true
end)
Listen(true)

-- Switched Off on the hub's Manage page: stop listening and drop the list; On: start again.
ForeverHubOnSwitch = ForeverHubOnSwitch or {}
ForeverHubOnSwitch.Legacy = function(off)
    Listen(not off)
    state.dirty = true
    if off then
        state.list, state.done, state.builtAt = {}, {}, nil
    end
end

SLASH_LEGACYPOINTS1 = "/legacypoints"
SlashCmdList.LEGACYPOINTS = Show
