local LOW_FREE_SLOTS = 3

local warned = false

local function Safe(value)
    if issecretvalue and issecretvalue(value) then
        return nil
    end
    return value
end

local function Print(text)
    if ForeverHub_Receive then
        return ForeverHub_Receive("QuestCheck", text)
    end
    -- No hub window to show it in: stay quiet rather than fill the chat.
end

-- Returns used and maximum quest log slots, or nil before the log has loaded.
local function LogSlots()
    local _, used = C_QuestLog.GetNumQuestLogEntries()
    local maximum = C_QuestLog.GetMaxNumQuestsCanAccept()
    used, maximum = Safe(used), Safe(maximum)
    if not (used and maximum and maximum > 0) then
        return nil
    end
    return used, maximum
end

local function ReadQuests()
    local groups = { ready = {}, gray = {}, group = {} }
    local entries = C_QuestLog.GetNumQuestLogEntries()
    for index = 1, Safe(entries) or 0 do
        local info = C_QuestLog.GetInfo(index)
        if info and not Safe(info.isHeader) and not Safe(info.isHidden) and not Safe(info.isTask) then
            local questID, title, level = Safe(info.questID), Safe(info.title), Safe(info.level)
            if questID and title then
                local line = level and string.format("[%d] %s", level, title) or title
                if Safe(C_QuestLog.IsComplete(questID)) or Safe(C_QuestLog.ReadyForTurnIn(questID)) then
                    table.insert(groups.ready, line)
                elseif Safe(C_QuestLog.IsQuestTrivial(questID)) then
                    table.insert(groups.gray, line)
                end
                local size = Safe(info.suggestedGroup) or 0
                if size > 1 then
                    table.insert(groups.group, string.format("%s (group of %d)", line, size))
                end
            end
        end
    end
    return groups
end

local function CheckLog()
    local used, maximum = LogSlots()
    if not used then
        return
    end
    local free = maximum - used
    if free <= LOW_FREE_SLOTS and not warned then
        if not ForeverHub_Receive then UIErrorsFrame:AddMessage(string.format("Quest log nearly full: %d free", free), 1, 0.8, 0.1) end
        Print(string.format("Quest log nearly full: %d/%d. The Quests page shows what you could finish or drop.", used, maximum))
    end
    warned = free <= LOW_FREE_SLOTS
end

local function PrintGroup(heading, lines)
    if #lines > 0 then
        Print(heading .. ":")
        for _, line in ipairs(lines) do
            Print("  " .. line)
        end
    end
end

-- Forever asks each new character to pick "Classic" or "Enhanced". Classic turns the map's quest markers
-- and objective areas off by default, and LevelGuide (map "!" offers) and QuestMobs read those, so they
-- show less. C_GameRules.GetForeverExperiencePreset: 0 = Classic, 1 = Enhanced (API docs).
local CLASSIC_PRESET = 0
local PRESET_TEXT = "Your character uses Forever's Classic preset, which hides quest markers and objective areas on the map by default. "
    .. "The leveling guide and quest-mob markers use them; if they show little, turn the map's quest markers back on in the world map's settings."

local function ClassicPreset()
    if not (C_GameRules and C_GameRules.GetForeverExperiencePreset) then
        return false
    end
    local ok, preset = pcall(C_GameRules.GetForeverExperiencePreset)
    return ok and Safe(preset) == CLASSIC_PRESET
end

----------------------------------------------------------------------------------------------------
-- Round 6 #13: quests done per zone. Counts the quests in LevelGuide's QuestDB (LevelGuideQuestDB, built
-- from forever-db; Alliance quests only) that your race and class can take, by the map of whoever gives
-- them (or takes them back, for quests started from an item). Repeatable quests are left out; every part
-- of a chain counts. Done = the game says so (C_QuestLog.GetAllCompletedQuestIDs, else GetQuestsCompleted,
-- else IsQuestFlaggedCompleted one by one). Read only, nothing saved: worked out when the page is opened.

-- "New in Forever": forever-db marks no quest as new, so the quest ID decides. The original Classic
-- quests all have IDs below 10000 (QuestDB's highest is 9664); every quest Forever added or took from a
-- later Classic release has a far higher one (QuestDB's next is 65602). The same rule is in QuestTracker
-- and Tooltips, so the tag works without QuestDB too.
local FOREVER_FIRST_ID = 10000
local FOREVER_TAG = "|cffc58cffnew in Forever|r"
local MAX_LEFT_LISTED, MAX_ZONES_LISTED = 8, 14
local RACE_BITS = { Human = 1, Orc = 2, Dwarf = 4, NightElf = 8, Scourge = 16, Tauren = 32, Gnome = 64, Troll = 128 }
local CLASS_BITS = { WARRIOR = 1, PALADIN = 2, HUNTER = 4, ROGUE = 8, PRIEST = 16, SHAMAN = 64, MAGE = 128,
    WARLOCK = 256, DRUID = 1024 }
local ALLIANCE_RACE_BITS = { 1, 4, 8, 64 }
local FOREVER_ALLIANCE_BIT = 4294967296
-- QuestDB keeps the quests an Alliance character can take, and that includes "anyone" quests handed out in
-- Horde cities and starting zones (Orgrimmar, Undercity, Durotar). An Alliance player won't go there for
-- them, so those maps aren't counted: Durotar, Mulgore, Tirisfal Glades, Silverpine Forest, Orgrimmar,
-- Thunder Bluff, Undercity.
local HORDE_MAPS = { [1411] = true, [1412] = true, [1420] = true, [1421] = true, [1454] = true, [1456] = true, [1458] = true }
local RECORD = "^([^|]*)|([^|]*)|([^|]*)|([^|]*)|([^|]*)|([^|]*)|([^|]*)|([^|]*)|([^|]*)|(.*)$"

local zoneIndex, indexedDB = nil, nil

local function IsForeverQuest(questID)
    return type(questID) == "number" and questID >= FOREVER_FIRST_ID
end

local function HasBit(mask, bit)
    return math.floor(mask / bit) % 2 == 1
end

-- The map of an NPC or object reference ("n123" / "o456"); items have no place.
local function PlaceMap(db, ref)
    local letter, id = ref:match("^(%a)(%d+)$")
    local places = letter == "n" and db.n or letter == "o" and db.o or nil
    local record = type(places) == "table" and places[tonumber(id)]
    return type(record) == "string" and tonumber(record:match("^(%d+):")) or nil
end

local function QuestMap(db, givers, enders)
    for _, refs in ipairs({ givers, enders }) do
        for ref in refs:gmatch("[^,]+") do
            local map = PlaceMap(db, ref)
            if map then
                return map
            end
        end
    end
    return nil
end

-- One light pass over QuestDB's strings: id, levels, race and class masks, map and title.
local function BuildIndex(db)
    local list = {}
    for id, record in pairs(db.q) do
        if type(id) == "number" and type(record) == "string" then
            local level, minLevel, races, classes, givers, enders, _, flags, _, title = record:match(RECORD)
            if title and title ~= "" and not flags:find("R", 1, true) then
                local map = QuestMap(db, givers, enders)
                if map and not HORDE_MAPS[map] then
                    level = tonumber(level) or 0
                    list[#list + 1] = { id = id, title = title, level = level, min = tonumber(minLevel) or 0,
                        races = tonumber(races) or 0, classes = tonumber(classes) or 0, map = map }
                end
            end
        end
    end
    table.sort(list, function(a, b) return a.id < b.id end)
    return list
end

-- The same rule as LevelGuide's QuestLookup (facts.Takes): a race the masks don't name only needs the
-- quest to be open to the Alliance.
local function Takes(quest, race, class)
    local raceBit, classBit = RACE_BITS[race or ""], CLASS_BITS[class or ""]
    if quest.races > 0 then
        local low = quest.races % FOREVER_ALLIANCE_BIT
        if raceBit then
            if not HasBit(low, raceBit) then
                return false
            end
        elseif not HasBit(quest.races, FOREVER_ALLIANCE_BIT) then
            local alliance = false
            for _, bit in ipairs(ALLIANCE_RACE_BITS) do
                alliance = alliance or HasBit(low, bit)
            end
            if not alliance then
                return false
            end
        end
    end
    return not (classBit and quest.classes > 0 and not HasBit(quest.classes, classBit))
end

-- The game's list of quests you've turned in, as a set; nil when only the one-by-one check is there.
local function CompletedSet()
    local all = C_QuestLog and C_QuestLog.GetAllCompletedQuestIDs
    local ok, ids
    if type(all) == "function" then
        ok, ids = pcall(all)
    elseif type(GetQuestsCompleted) == "function" then
        ok, ids = pcall(GetQuestsCompleted)
    end
    ids = ok and Safe(ids) or nil
    if type(ids) ~= "table" then
        return nil
    end
    local set = {}
    for key, value in pairs(ids) do
        -- GetAllCompletedQuestIDs: { id, id, ... }; GetQuestsCompleted: { [id] = true }.
        local id = type(all) == "function" and Safe(value) or (Safe(value) and Safe(key))
        if type(id) == "number" then
            set[id] = true
        end
    end
    return set
end

local function IsDone(set, questID)
    if set then
        return set[questID] == true
    end
    local check = C_QuestLog and C_QuestLog.IsQuestFlaggedCompleted
    if type(check) ~= "function" then
        return false
    end
    local ok, done = pcall(check, questID)
    return ok and Safe(done) == true
end

-- Per zone: total, done, the ones left you can take at your level, and how many need a higher level.
local function ZoneCounts()
    local db = LevelGuideQuestDB
    if type(db) ~= "table" or type(db.q) ~= "table" then
        return nil
    end
    if indexedDB ~= db then
        zoneIndex, indexedDB = BuildIndex(db), db
    end
    local race, class
    if UnitRace then
        local _, token = UnitRace("player")
        race = Safe(token)
    end
    if UnitClass then
        local _, token = UnitClass("player")
        class = Safe(token)
    end
    local level = UnitLevel and Safe(UnitLevel("player")) or 1
    local names = type(db.maps) == "table" and db.maps or {}
    local set = CompletedSet()
    local zones, byMap = {}, {}
    for _, quest in ipairs(zoneIndex) do
        if Takes(quest, race, class) then
            local zone = byMap[quest.map]
            if not zone then
                zone = { map = quest.map, name = names[quest.map] or ("Map " .. quest.map), total = 0, done = 0,
                    left = {}, later = 0, levels = 0 }
                byMap[quest.map] = zone
                zones[#zones + 1] = zone
            end
            zone.total = zone.total + 1
            zone.levels = zone.levels + quest.level
            if IsDone(set, quest.id) then
                zone.done = zone.done + 1
            elseif quest.min <= level then
                zone.left[#zone.left + 1] = quest
            else
                zone.later = zone.later + 1
            end
        end
    end
    for _, zone in ipairs(zones) do
        zone.average = zone.levels / zone.total
        table.sort(zone.left, function(a, b)
            if a.level ~= b.level then
                return a.level < b.level
            end
            return a.title < b.title
        end)
    end
    table.sort(zones, function(a, b)
        if a.average ~= b.average then
            return a.average < b.average
        end
        return a.name < b.name
    end)
    return zones, byMap
end

local function ZoneLine(zone)
    local line = string.format("%s: |cffffffff%d/%d|r done", zone.name, zone.done, zone.total)
    if #zone.left > 0 then
        local new = 0
        for _, quest in ipairs(zone.left) do
            new = new + (IsForeverQuest(quest.id) and 1 or 0)
        end
        line = line .. string.format(", |cff66ccff%d left at your level|r", #zone.left)
        if new > 0 then
            line = line .. string.format(" (%d %s)", new, FOREVER_TAG)
        end
    end
    if zone.later > 0 then
        line = line .. string.format(", |cff999999%d for later|r", zone.later)
    end
    return line
end

local function ShowZones()
    Print(" ")
    Print("|cffffd100Quests done per zone|r")
    local zones, byMap = ZoneCounts()
    if not zones then
        Print("|cff999999This needs the leveling guide's quest data: turn on the Forever Guides addon (LevelGuide).|r")
        return
    end
    local faction = UnitFactionGroup and Safe(UnitFactionGroup("player"))
    if faction == "Horde" then
        Print("|cff999999The leveling guide's quest data covers Alliance quests only.|r")
        return
    end
    local here = C_Map and C_Map.GetBestMapForUnit and Safe(C_Map.GetBestMapForUnit("player"))
    local zone = here and byMap[here]
    if zone then
        Print(ZoneLine(zone) .. "  |cff999999(you're here)|r")
        for index = 1, math.min(#zone.left, MAX_LEFT_LISTED) do
            local quest = zone.left[index]
            Print(string.format("  [%d] %s%s", quest.level, quest.title, IsForeverQuest(quest.id) and ("  " .. FOREVER_TAG) or ""))
        end
        if #zone.left > MAX_LEFT_LISTED then
            Print(string.format("  |cff999999+%d more|r", #zone.left - MAX_LEFT_LISTED))
        end
    end
    local finish = {}
    for _, other in ipairs(zones) do
        if #other.left > 0 and other.later == 0 then
            finish[#finish + 1] = string.format("%s (%d)", other.name, #other.left)
        end
    end
    if #finish > 0 then
        Print("Zones you can finish at your level: " .. table.concat(finish, ", "))
    end
    local shown, over, notYet = 0, 0, 0
    for _, other in ipairs(zones) do
        if other ~= zone then
            if other.done == 0 and #other.left == 0 then
                notYet = notYet + 1
            elseif shown < MAX_ZONES_LISTED then
                shown = shown + 1
                Print(ZoneLine(other))
            else
                over = over + 1
            end
        end
    end
    if over > 0 then
        Print(string.format("|cff999999+%d more zones|r", over))
    end
    if notYet > 0 then
        Print(string.format("|cff999999%d zones with nothing open at your level yet.|r", notYet))
    end
    Print("|cff999999Quests your race and class can take, from the leveling guide's quest data; repeatable quests aren't counted.|r")
end

local function ShowReport()
    local used, maximum = LogSlots()
    if used then
        Print(string.format("%d/%d quests.", used, maximum))
    end
    local groups = ReadQuests()
    PrintGroup("Ready to turn in", groups.ready)
    PrintGroup("Gray (low XP)", groups.gray)
    PrintGroup("Suggested group", groups.group)
    if #groups.ready + #groups.gray + #groups.group == 0 then
        Print("Nothing to flag.")
    end
    if ClassicPreset() then
        Print("|cff999999" .. PRESET_TEXT .. "|r")
    end
    ShowZones()
end

local events = CreateFrame("Frame")
events:RegisterEvent("QUEST_LOG_UPDATE")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_ENTERING_WORLD" then
        -- Said once per character; the Quests page keeps saying it.
        QuestCheckCharDB = type(QuestCheckCharDB) == "table" and QuestCheckCharDB or {}
        if not QuestCheckCharDB.presetNoted and ClassicPreset() then
            QuestCheckCharDB.presetNoted = true
            Print(PRESET_TEXT)
        end
        return
    end
    CheckLog()
end)

SLASH_QUESTCHECK1 = "/qc"
SLASH_QUESTCHECK2 = "/questcheck"
SlashCmdList.QUESTCHECK = ShowReport

ForeverHubStatus = ForeverHubStatus or {}
ForeverHubStatus.QuestCheck = function()
    local items = {}
    local groups = ReadQuests()
    if #groups.ready > 0 then
        items[#items + 1] = { text = string.format("|cffee9966Turn in|r %d quest(s)", #groups.ready), page = "Quests" }
    end
    local used, maximum = LogSlots()
    if used and maximum - used <= LOW_FREE_SLOTS then
        items[#items + 1] = { text = string.format("|cffee9966Quest log|r %d/%d full", used, maximum), page = "Quests" }
    end
    return items
end
