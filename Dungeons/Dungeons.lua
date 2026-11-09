-- Dungeons: a dungeon reference for leveling. Which dungeons suit your level, where their entrances
-- are, which of their quests you've done, have in your log or can still pick up, and the loot worth
-- having. Read-only: it reads your level, class, quest log and bags, and can pin an entrance on your
-- map when you ask it to.

local COMING_UP = 2          -- how many later dungeons the "coming up" line names
local BELOW_MIN = 2          -- a dungeon is shown this many levels before its range starts

local GOLD, GRAY, GREEN, YELLOW, ORANGE = "|cffffd100", "|cff999999", "|cff33ff33", "|cffffff66", "|cffff9933"

-- The same zone on Classic-numbered maps, tried when the client doesn't know the Mainline number.
local CLASSIC_MAP = {
    [85] = 1454, [87] = 1455, [18] = 1420, [10] = 1413, [52] = 1436, [21] = 1421, [63] = 1440,
    [84] = 1453, [56] = 1437, [27] = 1426, [224] = 1434, [15] = 1418, [71] = 1446, [66] = 1443,
    [70] = 1445, [51] = 1435, [36] = 1428, [69] = 1444, [76] = 1447, [78] = 1449, [23] = 1423, [22] = 1422,
}
local CONTINENTS = { 12, 13, 1414, 1415 }

-- Armor: 1 cloth, 2 leather, 3 mail, 4 plate. What each class wears now, and from level 40.
local ARMOR_RANK = { cloth = 1, leather = 2, mail = 3, plate = 4 }
local CLASS_ARMOR = {
    MAGE = { 1, 1 }, PRIEST = { 1, 1 }, WARLOCK = { 1, 1 }, ROGUE = { 2, 2 }, DRUID = { 2, 2 },
    HUNTER = { 2, 3 }, SHAMAN = { 2, 3 }, WARRIOR = { 3, 4 }, PALADIN = { 3, 4 },
}

local resolvedMaps = {}
local statusDirty = true
local readyQuests = {}

local function Safe(value)
    if issecretvalue and issecretvalue(value) then
        return nil
    end
    return value
end

local function Print(text)
    if ForeverHub_Receive then
        return ForeverHub_Receive("Dungeons", text)
    end
    -- No hub window to show it in: stay quiet rather than fill the chat.
end

local function List()
    return type(DungeonsData) == "table" and DungeonsData or {}
end

local function MyLevel()
    local level = UnitLevel and tonumber(Safe(UnitLevel("player")))
    if not level or level < 1 then
        return 1
    end
    return level
end

local function MyClass()
    if not UnitClass then
        return nil
    end
    local _, classFile = UnitClass("player")
    return Safe(classFile)
end

-- Quest state --------------------------------------------------------------------------------------

local function Completed(questID)
    if C_QuestLog and C_QuestLog.IsQuestFlaggedCompleted then
        return Safe(C_QuestLog.IsQuestFlaggedCompleted(questID)) == true
    end
    return false
end

local function InLog(questID)
    if C_QuestLog and C_QuestLog.GetLogIndexForQuestID then
        local index = Safe(C_QuestLog.GetLogIndexForQuestID(questID))
        return type(index) == "number" and index > 0
    end
    return false
end

local function ReadyToTurnIn(questID)
    if C_QuestLog and C_QuestLog.IsComplete then
        return Safe(C_QuestLog.IsComplete(questID)) == true
    end
    return false
end

-- "done" when the last quest of the chain is turned in; "ready" or "log" while one is in your log;
-- "part" when an earlier step is done; "open" when you can pick it up; "low" when you're too low yet.
local function QuestState(quest, level)
    local ids = quest.questIDs or {}
    if #ids == 0 then
        return "open"
    end
    if Completed(ids[#ids]) then
        return "done"
    end
    for _, id in ipairs(ids) do
        if InLog(id) then
            return ReadyToTurnIn(id) and "ready" or "log"
        end
    end
    for _, id in ipairs(ids) do
        if Completed(id) then
            return "part"
        end
    end
    if quest.min and level < quest.min then
        return "low"
    end
    return "open"
end

local function QuestCounts(dungeon, level)
    local counts = { done = 0, log = 0, ready = 0, open = 0, low = 0 }
    for _, quest in ipairs(dungeon.quests or {}) do
        local state = QuestState(quest, level)
        if state == "ready" then
            counts.ready = counts.ready + 1
            counts.log = counts.log + 1
        elseif state == "part" then
            counts.open = counts.open + 1
        else
            counts[state] = counts[state] + 1
        end
    end
    return counts
end

local function CountsText(dungeon, level)
    if #(dungeon.quests or {}) == 0 then
        return GRAY .. "no Alliance quests known|r"
    end
    local counts = QuestCounts(dungeon, level)
    local parts = {}
    parts[#parts + 1] = string.format("%d/%d done", counts.done, #dungeon.quests)
    if counts.log > 0 then
        parts[#parts + 1] = YELLOW .. counts.log .. " in your log|r"
    end
    if counts.ready > 0 then
        parts[#parts + 1] = GREEN .. counts.ready .. " ready to turn in|r"
    end
    if counts.open > 0 then
        parts[#parts + 1] = counts.open .. " to pick up"
    end
    if counts.low > 0 then
        parts[#parts + 1] = GRAY .. counts.low .. " later|r"
    end
    return "quests: " .. table.concat(parts, ", ")
end

-- Maps ---------------------------------------------------------------------------------------------

local function MapName(mapID)
    local info = mapID and C_Map.GetMapInfo(mapID)
    return info and Safe(info.name)
end

-- The map the entrance point is drawn on: the stored number when its name matches, the Classic
-- number for the same zone, or the zone found by name. Remembered after the first look.
local function ResolveMap(entrance)
    local key = tostring(entrance.mapID) .. ":" .. tostring(entrance.zone)
    if resolvedMaps[key] ~= nil then
        return resolvedMaps[key] or nil
    end
    local found
    if C_Map and C_Map.GetMapInfo and entrance.zone then
        -- Forever uses the Classic numbers (Elwynn 1429, not 37), so those are tried first.
        for _, id in ipairs({ CLASSIC_MAP[entrance.mapID or 0] or false, entrance.mapID or false }) do
            if id and MapName(id) == entrance.zone then
                found = id
                break
            end
        end
        if not found and C_Map.GetMapChildrenInfo then
            for _, continent in ipairs(CONTINENTS) do
                for _, child in ipairs(C_Map.GetMapChildrenInfo(continent, nil, true) or {}) do
                    if Safe(child.name) == entrance.zone and Safe(child.mapID) then
                        found = Safe(child.mapID)
                        break
                    end
                end
                if found then
                    break
                end
            end
        end
    end
    -- Names in another language won't match: then trust the stored number.
    found = found or entrance.mapID
    resolvedMaps[key] = found or false
    return found
end

local function EntranceText(dungeon)
    local entrance = dungeon.entrance or {}
    local text = string.format("%s %.1f, %.1f", entrance.zone or dungeon.zone or "?", (entrance.x or 0) * 100, (entrance.y or 0) * 100)
    if entrance.note then
        text = text .. GRAY .. " (" .. entrance.note .. ")|r"
    end
    return text
end

-- Pins the entrance on your map and screen, the same way the game's own map pin works.
local function Pin(dungeon)
    local entrance = dungeon.entrance
    if not (entrance and entrance.x and entrance.y and C_Map and C_Map.SetUserWaypoint and UiMapPoint and UiMapPoint.CreateFromCoordinates) then
        return false
    end
    local mapID = ResolveMap(entrance)
    if not mapID then
        return false
    end
    if C_Map.CanSetUserWaypointOnMap and not Safe(C_Map.CanSetUserWaypointOnMap(mapID)) then
        return false
    end
    local wasSet = C_Map.SetUserWaypoint(UiMapPoint.CreateFromCoordinates(mapID, entrance.x, entrance.y))
    if Safe(wasSet) == false then
        return false
    end
    if C_SuperTrack and C_SuperTrack.SetSuperTrackedUserWaypoint then
        C_SuperTrack.SetSuperTrackedUserWaypoint(true)
    end
    return true
end

-- Finding a dungeon by what you typed ------------------------------------------------------------

local function Names(dungeon)
    local names = { (dungeon.short or ""):lower(), (dungeon.name or ""):lower() }
    local bare = names[2]:gsub("^the%s+", "")
    names[#names + 1] = bare
    for _, alias in ipairs(dungeon.aliases or {}) do
        names[#names + 1] = alias:lower()
    end
    return names
end

-- A number, then exact names, then names that start with what you typed, then names containing it.
local function Find(want)
    local list = List()
    local number = tonumber(want)
    if number then
        return { list[number] and number or nil }
    end
    local tests = {
        function(name) return name == want end,
        function(name) return name:sub(1, #want) == want end,
        function(name) return name:find(want, 1, true) ~= nil end,
    }
    for _, test in ipairs(tests) do
        local matches = {}
        for index, dungeon in ipairs(list) do
            for _, name in ipairs(Names(dungeon)) do
                if name ~= "" and test(name) then
                    matches[#matches + 1] = index
                    break
                end
            end
        end
        if #matches > 0 then
            return matches
        end
    end
    return {}
end

-- Lines --------------------------------------------------------------------------------------------

local function Tags(dungeon)
    local tags = ""
    if dungeon.forever then
        tags = tags .. " " .. ORANGE .. "[new]|r"
    end
    if dungeon.horde then
        tags = tags .. " " .. GRAY .. "[Horde city]|r"
    end
    return tags
end

local function Suits(dungeon, level)
    return level >= (dungeon.minLevel or 0) - BELOW_MIN and level <= (dungeon.maxLevel or 0)
end

local function ShortLine(index, dungeon, level)
    return string.format("%s%d.|r %s%s %s(%d-%d, %s)|r %s", GOLD, index, dungeon.name, Tags(dungeon), GRAY,
        dungeon.minLevel or 0, dungeon.maxLevel or 0, dungeon.zone or "?", CountsText(dungeon, level))
end

local STATE_TEXT = {
    done = GREEN .. "Done|r",
    ready = GREEN .. "Ready to turn in|r",
    log = YELLOW .. "In your log|r",
    part = YELLOW .. "Part done|r",
    open = "Not started",
}

local function QuestLine(quest, level)
    local state = QuestState(quest, level)
    local stateText = STATE_TEXT[state] or (GRAY .. "From level " .. tostring(quest.min) .. "|r")
    local text = string.format("  %s: %s %s(level %s)|r", stateText, quest.title or "?", GRAY, tostring(quest.level or "?"))
    if state ~= "done" then
        text = text .. " - " .. (quest.giver or "?")
        if quest.where then
            text = text .. ", " .. quest.where
        end
    end
    if quest.note then
        text = text .. GRAY .. ". " .. quest.note .. "|r"
    end
    return text
end

local function Owned(itemID)
    if C_Item and C_Item.GetItemCount then
        return (tonumber(Safe(C_Item.GetItemCount(itemID, true))) or 0) > 0
    end
    return false
end

-- Only armor is judged, from the armor word in the slot text; weapons are left alone.
local function WearNote(slot, classFile, level)
    local limits = classFile and CLASS_ARMOR[classFile]
    local word = type(slot) == "string" and slot:lower():match("(%a+)$")
    local rank = word and ARMOR_RANK[word]
    if not (limits and rank) then
        return nil
    end
    if rank > limits[2] then
        return GRAY .. "(your class can't wear " .. word .. ")|r"
    elseif rank > limits[1] and level < 40 then
        return GRAY .. "(" .. word .. " from level 40)|r"
    end
    return nil
end

local function LootLine(item, classFile, level)
    local itemID, name, boss, slot, note = item[1], item[2], item[3], item[4], item[5]
    local text = "  " .. (name or "?")
    if slot then
        text = text .. GRAY .. " (" .. slot .. ")|r"
    end
    if boss then
        text = text .. " - " .. boss
    end
    if note then
        text = text .. GRAY .. ", " .. note .. "|r"
    end
    if itemID and Owned(itemID) then
        text = text .. " " .. GREEN .. "(you have it)|r"
    else
        local wear = WearNote(slot, classFile, level)
        if wear then
            text = text .. " " .. wear
        end
    end
    return text
end

-- Pages --------------------------------------------------------------------------------------------

local function ShowDetails(index, dungeon, level)
    Print(string.format("%s%d. %s|r%s  %slevels %d-%d, %s|r", GOLD, index, dungeon.name, Tags(dungeon), GRAY,
        dungeon.minLevel or 0, dungeon.maxLevel or 0, dungeon.zone or "?"))
    if dungeon.note then
        Print(dungeon.note)
    end
    if level < (dungeon.minLevel or 0) - BELOW_MIN then
        Print(GRAY .. string.format("You're level %d: this one is for later.", level) .. "|r")
    elseif level > (dungeon.maxLevel or 0) then
        Print(GRAY .. string.format("You're level %d: above this dungeon's range.", level) .. "|r")
    end
    Print(GOLD .. "Entrance:|r " .. EntranceText(dungeon))
    if dungeon.bosses and #dungeon.bosses > 0 then
        Print(GOLD .. "Bosses:|r " .. table.concat(dungeon.bosses, ", "))
    end
    if #(dungeon.quests or {}) > 0 then
        Print(GOLD .. "Quests|r " .. GRAY .. "(" .. CountsText(dungeon, level) .. ")|r")
        for _, quest in ipairs(dungeon.quests) do
            Print(QuestLine(quest, level))
        end
    else
        Print(GOLD .. "Quests:|r none known for the Alliance.")
    end
    if #(dungeon.loot or {}) > 0 then
        Print(GOLD .. "Notable loot:|r")
        local classFile = MyClass()
        for _, item in ipairs(dungeon.loot) do
            Print(LootLine(item, classFile, level))
        end
    end
    if dungeon.keys then
        Print(GOLD .. "Keys:|r " .. dungeon.keys)
    end
    Print(GRAY .. "Type: pin " .. index .. "   to mark the entrance on your map.|r")
end

local function ShowAll(level)
    Print(GOLD .. "Every dungeon|r " .. GRAY .. "(the ones that suit you now are bright)|r")
    for index, dungeon in ipairs(List()) do
        local line = ShortLine(index, dungeon, level)
        if not Suits(dungeon, level) then
            line = GRAY .. line:gsub("|r", "|r" .. GRAY) .. "|r"
        end
        Print(line)
    end
end

local function ShowSuited(level)
    local list = List()
    Print(string.format("%sDungeons for level %d|r", GOLD, level))
    local any = false
    for index, dungeon in ipairs(list) do
        if Suits(dungeon, level) then
            any = true
            Print(ShortLine(index, dungeon, level))
        end
    end
    if not any then
        Print("No dungeon fits your level right now.")
    end
    local coming = {}
    for index, dungeon in ipairs(list) do
        if (dungeon.minLevel or 0) - BELOW_MIN > level and #coming < COMING_UP then
            coming[#coming + 1] = string.format("%d. %s (%d-%d)", index, dungeon.name, dungeon.minLevel or 0, dungeon.maxLevel or 0)
        end
    end
    if #coming > 0 then
        Print(GRAY .. "Coming up: " .. table.concat(coming, ", ") .. "|r")
    end
    if UnitFactionGroup and Safe(UnitFactionGroup("player")) == "Horde" then
        Print(GRAY .. "The quest lists here are the Alliance ones.|r")
    end
    Print(GRAY .. "Type a number or a name for details, pin 2 to mark an entrance, or all for every dungeon.|r")
end

local function Which(matches)
    local list = List()
    local names = {}
    for _, index in ipairs(matches) do
        names[#names + 1] = string.format("%d. %s", index, list[index].name)
    end
    Print("Which one? " .. table.concat(names, ", "))
end

local function ShowPage(arg)
    local want = tostring(arg or ""):lower():gsub("^%s+", ""):gsub("%s+$", ""):gsub("%s+", " ")
    local level = MyLevel()
    local list = List()
    if want == "" then
        ShowSuited(level)
        return
    end
    if want == "all" then
        ShowAll(level)
        return
    end
    local pinWhat = want:match("^pin%s+(.+)$")
    if want == "pin" then
        Print("Type pin and a number or name, for example: pin 2")
        return
    end
    local matches = Find(pinWhat or want)
    if #matches == 0 then
        Print("I don't know a dungeon called '" .. (pinWhat or want) .. "'. Type all to see every dungeon.")
        return
    end
    if #matches > 1 then
        Which(matches)
        return
    end
    local index = matches[1]
    local dungeon = list[index]
    if pinWhat then
        if Pin(dungeon) then
            Print(string.format("Pinned the entrance to %s: %s", dungeon.name, EntranceText(dungeon)))
        else
            Print(string.format("Can't pin that from here. The entrance to %s: %s", dungeon.name, EntranceText(dungeon)))
        end
        return
    end
    ShowDetails(index, dungeon, level)
end

SLASH_DUNGEONS1 = "/dungeons"
SlashCmdList.DUNGEONS = ShowPage

-- Side panel: a dungeon quest in your log that's ready to hand in. Worked out again only after the
-- quest log changes.
local function RefreshReady()
    statusDirty = false
    readyQuests = {}
    local seen = {}
    for _, dungeon in ipairs(List()) do
        for _, quest in ipairs(dungeon.quests or {}) do
            for _, id in ipairs(quest.questIDs or {}) do
                if not seen[id] then
                    seen[id] = true
                    if InLog(id) and ReadyToTurnIn(id) then
                        readyQuests[#readyQuests + 1] = { title = quest.title, dungeon = dungeon.name }
                    end
                end
            end
        end
    end
end

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("QUEST_LOG_UPDATE")
events:RegisterEvent("QUEST_TURNED_IN")
events:SetScript("OnEvent", function()
    statusDirty = true
end)

ForeverHubStatus = ForeverHubStatus or {}
ForeverHubStatus.Dungeons = function()
    if statusDirty then
        RefreshReady()
    end
    local first = readyQuests[1]
    if not first then
        return nil
    end
    local more = #readyQuests > 1 and string.format(" (+%d more)", #readyQuests - 1) or ""
    return { { text = string.format("Dungeon quest ready: %s%s", first.title, more), page = "Dungeons" } }
end
