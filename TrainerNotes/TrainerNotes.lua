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

local UPCOMING_LEVELS = 4

local charData, openList, trainerOpen, openTrainer

local function Safe(value)
    if issecretvalue and issecretvalue(value) then
        return nil
    end
    return value
end

local function Print(text)
    if ForeverHub_Receive then
        return ForeverHub_Receive("TrainerNotes", text)
    end
    -- No hub window to show it in: stay quiet rather than fill the chat.
end

local function FormatMoney(copper)
    return string.format("%dg %ds %dc", math.floor(copper / 10000), math.floor(copper / 100) % 100, copper % 100)
end

-- Recipes and pet skills aren't something you need to go back and train, and recipes have no level.
local function IsSpellTrainer()
    if C_Trainer and C_Trainer.GetTrainerType and Enum and Enum.TrainerType then
        return Safe(C_Trainer.GetTrainerType()) == Enum.TrainerType.General
    end
    return not (IsTradeskillTrainer and Safe(IsTradeskillTrainer()))
end

-- With the "used" filter off, as it is by default, a bought spell just leaves the list. Only trust
-- a missing entry when the filters that show unbought spells are both on.
local function ListIsComplete()
    return GetTrainerServiceTypeFilter and Safe(GetTrainerServiceTypeFilter("available"))
        and Safe(GetTrainerServiceTypeFilter("unavailable"))
end

-- Whether the trainer window currently shows services of this type (true when it can't say).
local function FilterShows(serviceType)
    if not GetTrainerServiceTypeFilter then
        return true
    end
    return Safe(GetTrainerServiceTypeFilter(serviceType)) and true or false
end

-- The trainer's creature ID from its GUID ("Creature-0-server-instance-zone-ID-spawn"), or nil.
local function TrainerID()
    if not UnitGUID then
        return nil
    end
    local guid = Safe(UnitGUID("npc"))
    if type(guid) ~= "string" then
        return nil
    end
    return tonumber(guid:match("^%a+%-[^-]+%-[^-]+%-[^-]+%-[^-]+%-(%d+)%-"))
end

-- listed maps each key shown now to its service type. untagged holds keys saved before this
-- read with no trainer recorded (older saves, or a trainer whose ID couldn't be read).
local function ForgetMissing(listed, unread, trainer, untagged)
    -- A name still loading (or hidden) would look like a spell you already bought.
    if unread then
        return
    end
    -- Gone from the open window while its type is still shown: just bought. This runs whatever
    -- the filters are, so a purchase never lingers.
    if openList then
        for key, serviceType in pairs(openList) do
            if not listed[key] and FilterShows(serviceType) then
                charData.services[key] = nil
            end
        end
    end
    openList = listed
    if not ListIsComplete() then
        return
    end
    -- What this trainer used to list and no longer does was bought earlier. Other trainers' entries
    -- are left alone, so a weapon master and a class trainer never erase each other's.
    if trainer then
        for key, service in pairs(charData.services) do
            if service.trainer == trainer and not listed[key] then
                charData.services[key] = nil
            end
        end
    end
    -- Untagged entries can't say where they came from, so the old overlap rule still applies to
    -- them: mostly the same list means it's their trainer. Each visit tags what it lists, so this
    -- shrinks to nothing once a trainer ID is readable.
    local matches, stored = 0, 0
    for key in pairs(untagged) do
        stored = stored + 1
        if listed[key] then
            matches = matches + 1
        end
    end
    if stored > 0 and matches * 2 >= stored then
        for key in pairs(untagged) do
            local service = charData.services[key]
            if service and service.trainer == nil and not listed[key] then
                charData.services[key] = nil
            end
        end
    end
end

-- Whether a requirement is reported as missing. Blizzard's TrainerUI tests truthiness (the old
-- API returned 1/nil), so anything falsy is missing; a hidden value says nothing either way.
local function ReqMissing(hasReq)
    if issecretvalue and issecretvalue(hasReq) then
        return false
    end
    return not hasReq
end

-- What the trainer says you still lack, such as the talent a higher rank builds on, or nil.
-- Without this a priest or mage would be told to train ranks of talents they never took.
local function MissingRequirement(index, serviceType, level, playerLevel)
    if GetTrainerServiceNumAbilityReq and GetTrainerServiceAbilityReq then
        for i = 1, Safe(GetTrainerServiceNumAbilityReq(index)) or 0 do
            local ability, hasReq = GetTrainerServiceAbilityReq(index, i)
            ability = Safe(ability)
            if ability and ReqMissing(hasReq) then
                return ability
            end
        end
    end
    -- Greyed out at a level you already have: something other than level is in the way.
    if serviceType == "unavailable" and playerLevel and level <= playerLevel then
        if GetTrainerServiceSkillReq then
            local skill, rank, hasReq = GetTrainerServiceSkillReq(index)
            skill, rank = Safe(skill), Safe(rank)
            if skill and ReqMissing(hasReq) then
                return rank and (skill .. " " .. tostring(rank)) or skill
            end
        end
        return "something else first"
    end
    return nil
end

local function ReadTrainer()
    if not (charData and IsSpellTrainer()) then
        return
    end
    local count = Safe(GetNumTrainerServices()) or 0
    if count == 0 then
        -- The list can be empty for a moment as the window opens.
        return
    end
    -- Read once per window; the ID can't change while it stays open.
    openTrainer = openTrainer or TrainerID()
    local untagged = {}
    for key, service in pairs(charData.services) do
        if service.trainer == nil then
            untagged[key] = true
        end
    end
    local playerLevel = Safe(UnitLevel("player"))
    local listed, unread = {}, false
    for index = 1, count do
        -- Two return orders exist for this call: (name, type, _, level, rank) and Blizzard's own
        -- (name, rank, type, expanded) with the level from GetTrainerServiceLevelReq. Read whichever is live.
        local r1, r2, r3, r4, r5 = GetTrainerServiceInfo(index)
        local name, serviceType, level, subText = Safe(r1), Safe(r2), Safe(r4), Safe(r5)
        local third = Safe(r3)
        if third == "available" or third == "unavailable" or third == "used" or third == "header" then
            serviceType, subText = third, Safe(r2)
            level = GetTrainerServiceLevelReq and Safe(GetTrainerServiceLevelReq(index)) or nil
        end
        if type(level) ~= "number" then
            level = nil
        end
        if not (name and name ~= "" and serviceType) then
            unread = true
        elseif serviceType ~= "header" then
            local key = name .. "|" .. (subText or "")
            if serviceType == "used" then
                charData.services[key] = nil
            else
                level = math.max(level or 1, 1)
                listed[key] = serviceType
                charData.services[key] = {
                    name = name, rank = subText, level = level,
                    cost = Safe((GetTrainerServiceCost(index))) or 0,
                    needs = MissingRequirement(index, serviceType, level, playerLevel),
                    -- Where it was last seen, so only that trainer's list can forget it.
                    trainer = openTrainer,
                }
            end
        end
    end
    ForgetMissing(listed, unread, openTrainer, untagged)
end

-- Spellbook check: a spell learned elsewhere (a quest, a book, another trainer) or already known
-- leaves the list without a trainer visit. Uses the documented C_SpellBook skill-line calls.

local function SafeCall(fn, ...)
    if type(fn) ~= "function" then
        return nil
    end
    local ok, result = pcall(fn, ...)
    return ok and Safe(result) or nil
end

local function RankNumber(text)
    return type(text) == "string" and tonumber(text:match("(%d+)")) or nil
end

-- Lower-case spell name -> highest rank number known (0 when the rank can't be read), or nil when
-- the spellbook can't be read at all. Some clients list only the top rank; that's all this needs.
local function CanReadBook()
    return C_SpellBook and C_SpellBook.GetNumSpellBookSkillLines and C_SpellBook.GetSpellBookSkillLineInfo
        and C_SpellBook.GetSpellBookItemInfo
end

-- Skill lines first..last into ranks; returns true when any spell was read.
local function ReadBookLines(ranks, first, last)
    local bank = (Enum and Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Player) or 0
    local spellType = (Enum and Enum.SpellBookItemType and Enum.SpellBookItemType.Spell) or 1
    local any = false
    for line = first, last do
        local info = SafeCall(C_SpellBook.GetSpellBookSkillLineInfo, line)
        local offset = type(info) == "table" and Safe(info.itemIndexOffset)
        local count = type(info) == "table" and Safe(info.numSpellBookItems)
        if type(offset) == "number" and type(count) == "number" then
            for slot = offset + 1, offset + count do
                local item = SafeCall(C_SpellBook.GetSpellBookItemInfo, slot, bank)
                local name = type(item) == "table" and Safe(item.name)
                -- Only spells you actually have: not future spells, not another spec's.
                if type(name) == "string" and name ~= "" and Safe(item.itemType) == spellType and not Safe(item.isOffSpec) then
                    local subName = Safe(item.subName)
                    local id = Safe(item.spellID) or Safe(item.actionID)
                    if (type(subName) ~= "string" or subName == "") and type(id) == "number" and C_Spell then
                        subName = SafeCall(C_Spell.GetSpellSubtext, id)
                    end
                    local key = name:lower()
                    ranks[key] = math.max(ranks[key] or 0, RankNumber(subName) or 0)
                    any = true
                end
            end
        end
    end
    return any
end

local function BookLineCount()
    return SafeCall(C_SpellBook.GetNumSpellBookSkillLines) or 0
end

-- Lower-case spell name -> highest rank number known (0 when the rank can't be read), or nil when
-- the spellbook can't be read at all. Some clients list only the top rank; that's all this needs.
local function SpellBookRanks()
    if not CanReadBook() then
        return nil
    end
    local ranks = {}
    return ReadBookLines(ranks, 1, BookLineCount()) and ranks or nil
end

-- Drops noted services the spellbook says you know: same name, and for ranked spells a rank at
-- least as high. When a rank can't be read, the entry stays rather than vanish by mistake.
-- book: a list read beforehand (a spread walk); default: read now.
local function ForgetKnown(book)
    if not charData then
        return
    end
    book = book or SpellBookRanks()
    if not book then
        return
    end
    for key, service in pairs(charData.services) do
        local have = type(service.name) == "string" and book[service.name:lower()]
        if have then
            local want = RankNumber(service.rank)
            if not want or (have > 0 and have >= want) then
                charData.services[key] = nil
            end
        end
    end
end

-- Spell events come in bursts (a trainer visit can teach several spells); check once afterwards.
local SPELLBOOK_DELAY = 1
local BOOK_LINES_PER_STEP = 2
local spellbookCheckPending = false
local function ScheduleForgetKnown()
    if spellbookCheckPending then
        return
    end
    if C_Timer and C_Timer.After then
        spellbookCheckPending = true
        C_Timer.After(SPELLBOOK_DELAY, function()
            -- SPELLS_CHANGED comes in storms (a quest turn-in): walk BOOK_LINES_PER_STEP skill lines
            -- per frame instead of the whole book in one. Events meanwhile are covered by this walk.
            if not CanReadBook() then
                spellbookCheckPending = false
                return
            end
            local ranks, any, line, total = {}, false, 1, BookLineCount()
            local function step()
                local last = math.min(line + BOOK_LINES_PER_STEP - 1, total)
                if line <= last then
                    any = ReadBookLines(ranks, line, last) or any
                    line = last + 1
                end
                if line > total then
                    spellbookCheckPending = false
                    if any then
                        ForgetKnown(ranks)
                    end
                    return
                end
                C_Timer.After(0, step)
            end
            step()
        end)
    else
        ForgetKnown()
    end
end

-- Returns services ready at this level, those due within the next few levels, and those your level
-- allows but something else blocks, each sorted by level.
local function SplitServices(level)
    local ready, upcoming, blocked = {}, {}, {}
    for _, service in pairs(charData.services) do
        if service.level <= level and service.needs then
            blocked[#blocked + 1] = service
        elseif service.level <= level then
            ready[#ready + 1] = service
        elseif service.level <= level + UPCOMING_LEVELS then
            upcoming[#upcoming + 1] = service
        end
    end
    local function byLevel(a, b)
        if a.level ~= b.level then
            return a.level < b.level
        end
        return a.name < b.name
    end
    table.sort(ready, byLevel)
    table.sort(upcoming, byLevel)
    table.sort(blocked, byLevel)
    return ready, upcoming, blocked
end

local function TotalCost(list)
    local total = 0
    for _, service in ipairs(list) do
        total = total + (tonumber(service.cost) or 0)
    end
    return total
end

local function ServiceLine(service)
    local rank = service.rank and service.rank ~= "" and (" (" .. service.rank .. ")") or ""
    local needs = service.needs and (", needs " .. service.needs) or ""
    return string.format("  Level %d: %s%s, %s%s", service.level, service.name, rank, FormatMoney(service.cost), needs)
end

-- The full Forever list ------------------------------------------------------------------------
-- Every class-trainer spell 1-60 (TrainerNotes\Data.lua, generated by tools\gen_trainerdata.js from
-- What's Training's Forever data, MIT, credit in NOTICE.md), so the page works before any trainer
-- visit. Known is decided by spell ID: C_SpellBook.IsSpellKnown / IsSpellInSpellBook (or the older
-- globals), and a later rank in the same rank group counts as knowing the earlier ones (Forever
-- renumbered some ranks, e.g. Slam starts at 1240193). Never trains or buys anything.
local NEXT_LEVELS = 2
local KNOWN_CHUNK = 40          -- spells checked per frame when the spellbook changes
local Full = { known = {}, rankOf = nil, waiting = {}, plan = nil }

local function PlayerClassFile()
    if not UnitClass then
        return nil
    end
    local ok, _, file = pcall(UnitClass, "player")
    return ok and Safe(file) or nil
end

local function ClassData()
    local data = type(TrainerNotesData) == "table" and type(TrainerNotesData.classes) == "table" and TrainerNotesData.classes
    local file = PlayerClassFile()
    return data and file and data[file] or nil, file
end

-- A way to tell what you know by spell ID; without one the full list stays off.
local function CanCheckKnown()
    return (C_SpellBook and (C_SpellBook.IsSpellKnown or C_SpellBook.IsSpellInSpellBook)) or IsSpellKnown or IsPlayerSpell
end

local function AskKnown(id)
    local bank = (Enum and Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Player) or 0
    if C_SpellBook then
        if SafeCall(C_SpellBook.IsSpellKnown, id, bank) == true then
            return true
        end
        if SafeCall(C_SpellBook.IsSpellInSpellBook, id, bank, false) == true then
            return true
        end
    end
    return SafeCall(IsSpellKnown, id) == true or SafeCall(IsPlayerSpell, id) == true
end

-- spellID -> { group, position } for this class, built once.
local function RankOf(id)
    local data, file = ClassData()
    if not Full.rankOf or Full.rankClass ~= file then
        Full.rankOf, Full.rankClass = {}, file
        for _, group in ipairs(data and data.ranks or {}) do
            for position, spellID in ipairs(group) do
                Full.rankOf[spellID] = { group = group, position = position }
            end
        end
    end
    return Full.rankOf[id]
end

local function Known(id)
    if Full.known[id] then
        return true
    end
    local rank = RankOf(id)
    if rank then
        for position = rank.position + 1, #rank.group do
            if Full.known[rank.group[position]] then
                return true
            end
        end
    end
    return false
end

-- Every spell ID the list cares about: its rows, their requirements, talents and rank groups.
local function WatchedIDs()
    local data = ClassData()
    local ids, seen = {}, {}
    local function add(id)
        if type(id) == "number" and not seen[id] then
            seen[id] = true
            ids[#ids + 1] = id
        end
    end
    for _, row in ipairs(data and data.spells or {}) do
        add(row[2])
        add(row.talent)
        for _, req in ipairs(row.req or {}) do
            add(req)
        end
    end
    for _, group in ipairs(data and data.ranks or {}) do
        for _, id in ipairs(group) do
            add(id)
        end
    end
    return ids
end

-- Reads every watched spell now (the page, or no timers).
local function RefreshKnownNow()
    local known = {}
    for _, id in ipairs(WatchedIDs()) do
        known[id] = AskKnown(id) or nil
    end
    Full.known, Full.plan, Full.loaded = known, nil, true
end

-- After a spellbook change: the same, KNOWN_CHUNK spells per frame, swapped in when complete.
local walking = false
local function RefreshKnownSpread(done)
    if not (C_Timer and C_Timer.After) then
        RefreshKnownNow()
        if done then done() end
        return
    end
    if walking then
        return
    end
    walking = true
    local ids, known, index = WatchedIDs(), {}, 1
    local function step()
        for _ = 1, KNOWN_CHUNK do
            local id = ids[index]
            if not id then
                walking = false
                Full.known, Full.plan, Full.loaded = known, nil, true
                if done then done() end
                return
            end
            known[id] = AskKnown(id) or nil
            index = index + 1
        end
        C_Timer.After(0, step)
    end
    step()
end

-- Name and rank text from the game, asking it to load the spell when it isn't cached yet.
local function SpellText(id)
    local cachedOK, cached = false, nil
    if C_Spell and C_Spell.IsSpellDataCached then
        cachedOK, cached = pcall(C_Spell.IsSpellDataCached, id)
    end
    -- SafeCall turns false into nil, so the answer is read directly here.
    if cachedOK and cached == false then
        Full.waiting[id] = true
        if C_Spell.RequestLoadSpellData then
            pcall(C_Spell.RequestLoadSpellData, id)
        end
        return nil
    end
    local name = C_Spell and SafeCall(C_Spell.GetSpellName, id)
    if type(name) ~= "string" or name == "" then
        return nil
    end
    local rank = C_Spell and SafeCall(C_Spell.GetSpellSubtext, id)
    return name, type(rank) == "string" and rank or ""
end

local function SpellLabel(id)
    local name, rank = SpellText(id)
    if not name then
        return "spell " .. tostring(id), nil, ""
    end
    return name .. (rank ~= "" and (" (" .. rank .. ")") or ""), name, rank
end

local function RowFits(row, faction, race)
    if row.faction and faction and row.faction ~= faction then
        return false
    end
    if row.race and race and row.race ~= race then
        return false
    end
    if row.races and race then
        for _, r in ipairs(row.races) do
            if r == race then
                return true
            end
        end
        return false
    end
    return true
end

-- Which rows are ready, coming in the next levels, gated by a talent or by something you lack.
local function BuildPlan(level)
    local data = ClassData()
    if not (data and CanCheckKnown()) then
        return nil
    end
    local faction = UnitFactionGroup and SafeCall(UnitFactionGroup, "player")
    local race
    if UnitRace then
        local ok, _, _, id = pcall(UnitRace, "player")
        race = ok and Safe(id) or nil
    end
    local plan = { ready = {}, next = {}, talent = {}, blocked = {}, later = 0 }
    local coming = {}   -- IDs you'll have once you train what's ready / next
    local rows = {}
    for _, row in ipairs(data.spells or {}) do
        if RowFits(row, faction, race) and not Known(row[2]) then
            rows[#rows + 1] = row
        end
    end
    local function missing(row)
        for _, req in ipairs(row.req or {}) do
            if not (Known(req) or coming[req]) then
                return req
            end
        end
    end
    -- Rows are by level, so a rank's earlier rank is placed before it.
    for _, row in ipairs(rows) do
        local id, rowLevel = row[2], row[1]
        local entry = { id = id, level = rowLevel, cost = row[3] or 0 }
        if row.talent and not Known(row.talent) then
            if rowLevel <= level + NEXT_LEVELS then
                entry.needs = row.talent
                plan.talent[#plan.talent + 1] = entry
            end
        elseif rowLevel <= level + NEXT_LEVELS then
            local lacking = missing(row)
            entry.needs = lacking
            if rowLevel <= level and not lacking then
                plan.ready[#plan.ready + 1] = entry
                coming[id] = true
            elseif rowLevel <= level then
                plan.blocked[#plan.blocked + 1] = entry
            else
                plan.next[#plan.next + 1] = entry
                if not lacking then
                    coming[id] = true
                end
            end
        else
            plan.later = plan.later + 1
        end
    end
    return plan
end

local function CurrentPlan(level)
    if not Full.loaded then
        return nil
    end
    local key = tostring(level) .. ":" .. tostring(PlayerClassFile())
    if not Full.plan or Full.plan.key ~= key then
        local plan = BuildPlan(level)
        if not plan then
            return nil
        end
        plan.key = key
        Full.plan = plan
    end
    return Full.plan
end

-- What a row costs: the trainer's own price when you've seen it there (by name and rank; already
-- discounted by the game), else the list's. Second return: true when it's the list's price.
local function RowCost(entry)
    local _, name, rank = SpellLabel(entry.id)
    local seen = name and charData and charData.services[name .. "|" .. (rank or "")]
    if seen and tonumber(seen.cost) then
        return tonumber(seen.cost), false
    end
    return entry.cost, true
end

-- Trainer reputation discount (What's Training's Forever pricing, MIT): Honored or better with a
-- faction whose trainers teach your class takes 10 % off there, rounded to the copper. Returns the
-- percent and the names of those factions (from the game), or 0.
local DISCOUNT_PCT, HONORED = 10, 6
local function Discount()
    local data = type(TrainerNotesData) == "table" and TrainerNotesData.trainerFactions
    local factionGroup = UnitFactionGroup and SafeCall(UnitFactionGroup, "player")
    local ids = data and data[PlayerClassFile() or ""] and factionGroup and data[PlayerClassFile()][factionGroup]
    if type(ids) ~= "table" or not (C_Reputation and C_Reputation.GetFactionDataByID) then
        return 0
    end
    local names = {}
    for _, id in ipairs(ids) do
        local info = SafeCall(C_Reputation.GetFactionDataByID, id)
        local reaction = type(info) == "table" and Safe(info.reaction)
        if type(reaction) == "number" and reaction >= HONORED then
            local name = Safe(info.name)
            names[#names + 1] = type(name) == "string" and name or ("faction " .. id)
        end
    end
    if #names == 0 then
        return 0
    end
    return DISCOUNT_PCT, names
end

local function Discounted(cost, pct)
    return math.floor((cost * (100 - pct) + 50) / 100)
end

-- Total of a list; with pct, list prices get the discount (prices seen at a trainer already have it).
local function PlanCost(list, pct)
    local total = 0
    for _, entry in ipairs(list) do
        local cost, fromList = RowCost(entry)
        if pct and pct > 0 and fromList then
            cost = Discounted(cost, pct)
        end
        total = total + cost
    end
    return total
end

-- Class-quest spells (What's Training's QuestSpells, MIT) for your class and race:
-- spellID -> { level, quests } or nil.
local function QuestSpell(id)
    local data = type(TrainerNotesData) == "table" and TrainerNotesData.questSpells
    local list = data and data[PlayerClassFile() or ""] and data[PlayerClassFile()][id]
    if type(list) ~= "table" then
        return nil
    end
    local race
    if UnitRace then
        local ok, _, _, raceID = pcall(UnitRace, "player")
        race = ok and Safe(raceID) or nil
    end
    for _, entry in ipairs(list) do
        for _, r in ipairs(entry.races or {}) do
            if r == race then
                return entry
            end
        end
    end
    return nil
end

-- "class quest 'Bartleby's Mug'": the title from LevelGuide's quest database or the game, else the ID.
local function QuestLabel(entry)
    local questID = entry.quests and entry.quests[1]
    local title
    local db = type(LevelGuideQuestDB) == "table" and type(LevelGuideQuestDB.q) == "table" and LevelGuideQuestDB.q
    local record = db and questID and db[questID]
    if type(record) == "string" then
        title = record:match("([^|]+)$")
    end
    if not title and questID and C_QuestLog and C_QuestLog.GetTitleForQuestID then
        title = SafeCall(C_QuestLog.GetTitleForQuestID, questID)
    end
    if type(title) == "string" and title ~= "" then
        return "class quest '" .. title .. "'"
    end
    return "class quest " .. tostring(questID or "?")
end

local function NeedsText(id)
    local _, name = SpellLabel(id)
    local text = name or SpellLabel(id)
    local quest = QuestSpell(id)
    if quest then
        text = text .. " (" .. QuestLabel(quest) .. ")"
    end
    return text
end

local function PlanLine(entry)
    local label = SpellLabel(entry.id)
    local needs = entry.needs and (", needs " .. NeedsText(entry.needs)) or ""
    return string.format("  Level %d: %s, %s%s", entry.level, label, FormatMoney((RowCost(entry))), needs)
end

-- Class-quest spells you don't know yet, up to NEXT_LEVELS above your level.
local function QuestSpellLines(level)
    local data = type(TrainerNotesData) == "table" and TrainerNotesData.questSpells
    local spells = data and data[PlayerClassFile() or ""]
    local lines = {}
    for id in pairs(type(spells) == "table" and spells or {}) do
        local entry = QuestSpell(id)
        if entry and (entry.level or 1) <= level + NEXT_LEVELS and not AskKnown(id) then
            lines[#lines + 1] = { level = entry.level or 1, text = string.format("  Level %d: %s: %s",
                entry.level or 1, select(2, SpellLabel(id)) or SpellLabel(id), QuestLabel(entry)) }
        end
    end
    table.sort(lines, function(a, b) if a.level ~= b.level then return a.level < b.level end return a.text < b.text end)
    return lines
end

-- Warlock demon tomes (What's Training's WarlockTomes, MIT): for demons you can summon, up to
-- NEXT_LEVELS above your level, not known. A tome is known when its spell is in the pet spellbook
-- (only readable with that demon out), remembered per character from then on.
local SUMMONS = { Imp = 688, Voidwalker = 697, Succubus = 712, Incubus = 713, Felhunter = 691 }
local function TomeLines(level)
    local tomes = type(TrainerNotesData) == "table" and TrainerNotesData.tomes
    if PlayerClassFile() ~= "WARLOCK" or type(tomes) ~= "table" or not charData then
        return {}
    end
    charData.tomes = type(charData.tomes) == "table" and charData.tomes or {}
    local petBank = (Enum and Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Pet) or 1
    local lines = {}
    for _, tome in ipairs(tomes) do
        local tomeLevel, itemID, cost, family, spell = tome[1], tome[2], tome[3], tome[4], tome[5]
        if spell and not charData.tomes[spell] and C_SpellBook and SafeCall(C_SpellBook.IsSpellKnown, spell, petBank) == true then
            charData.tomes[spell] = true
        end
        local summon = SUMMONS[family]
        if tomeLevel <= level + NEXT_LEVELS and summon and AskKnown(summon) and not (spell and charData.tomes[spell]) then
            local name = C_Item and SafeCall(C_Item.GetItemNameByID, itemID)
            local inBags = C_Item and (tonumber(SafeCall(C_Item.GetItemCount, itemID)) or 0) > 0
            lines[#lines + 1] = string.format("  Level %d: %s (%s), %s%s", tomeLevel,
                type(name) == "string" and name or ("item " .. itemID), family, FormatMoney(cost),
                inBags and " |cff66ff66(in your bags)|r" or "")
        end
    end
    return lines
end

-- Rows that are spells from the full list, so the trainer notes below don't repeat them.
local function PlanNames(plan)
    local names = {}
    for _, list in ipairs({ plan.ready, plan.next, plan.talent, plan.blocked }) do
        for _, entry in ipairs(list) do
            local _, name, rank = SpellLabel(entry.id)
            if name then
                names[name .. "|" .. (rank or "")] = true
            end
        end
    end
    return names
end

local function ShowPlan(plan, level)
    local pct, factions = Discount()
    if pct > 0 then
        Print(string.format("|cff66ff66%d%% off|r at trainers of %s (Honored). Totals below show both prices.", pct, table.concat(factions, ", ")))
    end
    if #plan.ready > 0 then
        local total = PlanCost(plan.ready)
        local off = pct > 0 and string.format(" (%s with %d%% off)", FormatMoney(PlanCost(plan.ready, pct)), pct) or ""
        Print(string.format("Ready to train, %s in total%s:", FormatMoney(total), off))
        for _, entry in ipairs(plan.ready) do
            Print(PlanLine(entry))
        end
    else
        Print("Nothing new to train right now.")
    end
    if #plan.blocked > 0 then
        Print("Your level allows these, but you need something first:")
        for _, entry in ipairs(plan.blocked) do
            Print(PlanLine(entry))
        end
    end
    if #plan.next > 0 then
        Print(string.format("Next %d levels: set aside %s for level %d:", NEXT_LEVELS, FormatMoney(PlanCost(plan.next)), level + NEXT_LEVELS))
        for _, entry in ipairs(plan.next) do
            Print(PlanLine(entry))
        end
    end
    if #plan.talent > 0 then
        Print("Needs a talent you haven't taken:")
        for _, entry in ipairs(plan.talent) do
            Print(PlanLine(entry))
        end
    end
    local quests = QuestSpellLines(level)
    if #quests > 0 then
        Print("From class quests (not sold by trainers):")
        for _, entry in ipairs(quests) do
            Print(entry.text)
        end
    end
    local tomes = TomeLines(level)
    if #tomes > 0 then
        Print("Demon tomes from a demon-tome vendor (never discounted):")
        for _, text in ipairs(tomes) do
            Print(text)
        end
    end
    if plan.later > 0 then
        Print(string.format("|cff999999%d more spell(s) later, up to level 60.|r", plan.later))
    end
    -- Anything else a trainer sold you notes for (a weapon master, say), not on the list above.
    local names, extra = PlanNames(plan), {}
    local ready, upcoming = SplitServices(level)
    for _, list in ipairs({ ready, upcoming }) do
        for _, service in ipairs(list) do
            if not names[service.name .. "|" .. (service.rank or "")] then
                extra[#extra + 1] = service
            end
        end
    end
    if #extra > 0 then
        Print("Also noted at your trainers:")
        for _, service in ipairs(extra) do
            Print(ServiceLine(service))
        end
    end
end

local function ShowNotes()
    local level = Safe(UnitLevel("player"))
    if not level then
        Print("The game didn't report your level.")
        return
    end
    -- Read fresh when you look, so nothing you already know is listed.
    ForgetKnown()
    if ClassData() and CanCheckKnown() then
        RefreshKnownNow()
        local plan = CurrentPlan(level)
        if plan then
            ShowPlan(plan, level)
            return
        end
    end
    if next(charData.services) == nil then
        Print("Nothing noted yet. Open your trainer once, and I'll remember what they sell.")
        return
    end
    local ready, upcoming, blocked = SplitServices(level)
    if #ready > 0 then
        Print(string.format("Ready to train, %s in total:", FormatMoney(TotalCost(ready))))
        for _, service in ipairs(ready) do
            Print(ServiceLine(service))
        end
    else
        Print("Nothing new to train right now.")
    end
    if #upcoming > 0 then
        Print(string.format("Coming within %d levels, %s in total:", UPCOMING_LEVELS, FormatMoney(TotalCost(upcoming))))
        for _, service in ipairs(upcoming) do
            Print(ServiceLine(service))
        end
    end
    if #blocked > 0 then
        Print("Not counted until you have what they need (checked again at your trainer):")
        for _, service in ipairs(blocked) do
            Print(ServiceLine(service))
        end
    end
end

-- What's ready now and what it costs: from the full list when it's on, else from trainer notes.
local function ReadyNow(level)
    local plan = CurrentPlan(level)
    if plan then
        return #plan.ready, PlanCost(plan.ready)
    end
    local ready = SplitServices(level)
    return #ready, TotalCost(ready)
end

local function ReportLevelUp(level)
    ForgetKnown()
    local count, cost = ReadyNow(level)
    if count > 0 then
        Print(string.format("%d thing(s) to train, %s in total. See the Trainer page.", count, FormatMoney(cost)))
    end
end

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("PLAYER_LEVEL_UP")
events:RegisterEvent("TRAINER_SHOW")
events:RegisterEvent("TRAINER_UPDATE")
events:RegisterEvent("TRAINER_CLOSED")
-- Names can arrive after the list does; this says they have.
events:RegisterEvent("TRAINER_SERVICE_INFO_NAME_UPDATE")
-- New spells in your spellbook. pcall: a client without one of these must still load the addon.
local SPELLBOOK_EVENTS = { SPELLS_CHANGED = true, LEARNED_SPELL_IN_SKILL_LINE = true }
for name in pairs(SPELLBOOK_EVENTS) do
    pcall(events.RegisterEvent, events, name)
end
-- The answer to C_Spell.RequestLoadSpellData (spellID, success).
pcall(events.RegisterEvent, events, "SPELL_DATA_LOAD_RESULT")

-- The full list's known spells, read again after spellbook changes: once per burst, then at most
-- every KNOWN_EVERY seconds, spread over frames.
local KNOWN_EVERY = 5
local knownPending, lastKnownWalk = false, nil
local function ScheduleKnownWalk()
    if knownPending or not (ClassData() and CanCheckKnown()) then
        return
    end
    if not (C_Timer and C_Timer.After) then
        RefreshKnownNow()
        return
    end
    knownPending = true
    local now = GetTime and tonumber(SafeCall(GetTime))
    local wait = SPELLBOOK_DELAY
    if now and lastKnownWalk and now - lastKnownWalk < KNOWN_EVERY then
        wait = math.max(wait, KNOWN_EVERY - (now - lastKnownWalk))
    end
    C_Timer.After(wait, function()
        knownPending = false
        lastKnownWalk = GetTime and tonumber(SafeCall(GetTime)) or lastKnownWalk
        RefreshKnownSpread()
    end)
end

events:SetScript("OnEvent", function(_, event, newLevel)
    if SPELLBOOK_EVENTS[event] then
        if charData then
            ScheduleForgetKnown()
            ScheduleKnownWalk()
        end
        return
    end
    if event == "SPELL_DATA_LOAD_RESULT" then
        -- Names are read when the page draws; a loaded one just stops being waited on.
        local id = Safe(newLevel)
        if id and Full.waiting[id] then
            Full.waiting[id] = nil
        end
        return
    end
    if event == "PLAYER_LOGIN" then
        TrainerNotesDB = TrainerNotesDB or {}
        local key = ForeverCharacterAdopt(TrainerNotesDB)
        TrainerNotesDB[key] = TrainerNotesDB[key] or { services = {} }
        charData = ForeverCharacterStamp(TrainerNotesDB[key])
        charData.services = type(charData.services) == "table" and charData.services or {}
        -- Older versions also saved recipes, which all have level 0 and looked ready to train forever.
        for serviceKey, service in pairs(charData.services) do
            if (service.level or 0) <= 0 then
                charData.services[serviceKey] = nil
            end
        end
        -- Spells learned since the last session (or on another addon-less login) leave the list.
        ScheduleForgetKnown()
        ScheduleKnownWalk()
    elseif event == "TRAINER_CLOSED" then
        openList, trainerOpen, openTrainer = nil, false, nil
    elseif event == "PLAYER_LEVEL_UP" then
        local level = Safe(newLevel)
        if charData and level then
            ReportLevelUp(level)
        end
    elseif event == "TRAINER_SHOW" or trainerOpen then
        trainerOpen = true
        ReadTrainer()
    end
end)

SLASH_TRAINERNOTES1 = "/trainer"
SlashCmdList.TRAINERNOTES = function()
    if charData then
        ShowNotes()
    end
end

local function ShortMoney(copper)
    local gold, silver, rest = math.floor(copper / 10000), math.floor(copper / 100) % 100, copper % 100
    if gold > 0 then
        return string.format("%dg %ds", gold, silver)
    elseif silver > 0 then
        return string.format("%ds %dc", silver, rest)
    end
    return string.format("%dc", rest)
end

ForeverHubStatus = ForeverHubStatus or {}
ForeverHubStatus.TrainerNotes = function()
    local level = Safe(UnitLevel("player"))
    if not (charData and level) then
        return nil
    end
    local count, cost = ReadyNow(level)
    if count > 0 then
        local money = GetMoney and Safe(GetMoney())
        local shortBy = money and money < cost and string.format(", |cffff6666%s short|r", ShortMoney(cost - money)) or ""
        return { { text = string.format("|cffaaddffTrain|r %d spell(s), %s%s", count, ShortMoney(cost), shortBy), page = "Trainer" } }
    end
end
