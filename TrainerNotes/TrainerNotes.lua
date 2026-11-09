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
local function SpellBookRanks()
    if not (C_SpellBook and C_SpellBook.GetNumSpellBookSkillLines and C_SpellBook.GetSpellBookSkillLineInfo
        and C_SpellBook.GetSpellBookItemInfo) then
        return nil
    end
    local bank = (Enum and Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Player) or 0
    local spellType = (Enum and Enum.SpellBookItemType and Enum.SpellBookItemType.Spell) or 1
    local ranks, any = {}, false
    for line = 1, SafeCall(C_SpellBook.GetNumSpellBookSkillLines) or 0 do
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
    return any and ranks or nil
end

-- Drops noted services the spellbook says you know: same name, and for ranked spells a rank at
-- least as high. When a rank can't be read, the entry stays rather than vanish by mistake.
local function ForgetKnown()
    if not charData then
        return
    end
    local book = SpellBookRanks()
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
local spellbookCheckPending = false
local function ScheduleForgetKnown()
    if spellbookCheckPending then
        return
    end
    if C_Timer and C_Timer.After then
        spellbookCheckPending = true
        C_Timer.After(SPELLBOOK_DELAY, function()
            spellbookCheckPending = false
            ForgetKnown()
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

local function ShowNotes()
    local level = Safe(UnitLevel("player"))
    if not level then
        Print("The game didn't report your level.")
        return
    end
    -- Read fresh when you look, so nothing you already know is listed.
    ForgetKnown()
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

local function ReportLevelUp(level)
    ForgetKnown()
    local ready = SplitServices(level)
    if #ready > 0 then
        Print(string.format("%d thing(s) to train, %s in total. See the Trainer page.", #ready, FormatMoney(TotalCost(ready))))
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
events:SetScript("OnEvent", function(_, event, newLevel)
    if SPELLBOOK_EVENTS[event] then
        if charData then
            ScheduleForgetKnown()
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
    local ready = SplitServices(level)
    if #ready > 0 then
        local cost = TotalCost(ready)
        local money = GetMoney and Safe(GetMoney())
        local shortBy = money and money < cost and string.format(", |cffff6666%s short|r", ShortMoney(cost - money)) or ""
        return { { text = string.format("|cffaaddffTrain|r %d spell(s), %s%s", #ready, ShortMoney(cost), shortBy), page = "Trainer" } }
    end
end
