-- Dungeons: a dungeon reference for leveling. Which dungeons suit your level, where their entrances
-- are, which of their quests you've done, have in your log or can still pick up, and the loot worth
-- having. Read-only: it reads your level, class, quest log and bags, and can pin an entrance on your
-- map when you ask it to.

-- Shared Forever waypoint (the same copy is in every helper that pins places; whichever loads first
-- defines it, so all helpers share one remembered pin). Sets the game's own map pin and tracks it,
-- remembers the point, and clears it once you are within ARRIVE_YARDS of it. It only ever clears a
-- pin that is still exactly the one it set: a pin you placed or moved yourself is never touched.
-- Returns true when the pin was set; false and a reason ("api", "map", "refused") when not.
if not ForeverWaypoint_Set then
    local ARRIVE_YARDS, CHECK_SECONDS, SAME_SPOT = 15, 0.5, 0.0005
    local active, watcher, elapsed, watching = nil, nil, 0, false
    local function Plain(value)
        if value == nil or (issecretvalue and issecretvalue(value)) then
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
    local function XY(vector)
        if type(vector) ~= "table" then
            return nil
        end
        local x, y = Plain(vector.x), Plain(vector.y)
        if type(x) ~= "number" and type(vector.GetXY) == "function" then
            x, y = Call(vector.GetXY, vector)
        end
        if type(x) == "number" and type(y) == "number" then
            return x, y
        end
    end
    local function Vector(x, y)
        if CreateVector2D then
            return CreateVector2D(x, y)
        end
        return { x = x, y = y }
    end
    -- Continent and world yards of a map point, or nil where the client has no world positions.
    local function World(mapID, x, y)
        if not (C_Map and C_Map.GetWorldPosFromMapPos) then
            return nil
        end
        local continent, pos = Call(C_Map.GetWorldPosFromMapPos, mapID, Vector(x, y))
        local wx, wy = XY(pos)
        if continent and wx then
            return continent, wx, wy
        end
    end
    local function Near(ax, ay, bx, by)
        return math.abs(ax - bx) <= SAME_SPOT and math.abs(ay - by) <= SAME_SPOT
    end
    -- True only while the game's pin is still the one we set.
    local function StillOurs()
        if not (active and C_Map) then
            return false
        end
        if C_Map.HasUserWaypoint and Call(C_Map.HasUserWaypoint) == false then
            return false
        end
        local point = C_Map.GetUserWaypoint and Call(C_Map.GetUserWaypoint)
        if type(point) == "table" then
            local px, py = XY(point.position)
            if Plain(point.uiMapID) == active.mapID and px then
                return Near(px, py, active.x, active.y)
            end
        end
        -- The game may keep the pin on another map; ask where it is on ours.
        local pos = C_Map.GetUserWaypointPositionForMap and Call(C_Map.GetUserWaypointPositionForMap, active.mapID)
        local qx, qy = XY(pos)
        return qx ~= nil and Near(qx, qy, active.x, active.y)
    end
    local function Stop()
        active, watching = nil, false
        if watcher then
            watcher:SetScript("OnUpdate", nil)
            if watcher.Hide then
                watcher:Hide()
            end
        end
    end
    -- Yards from the player to our pin, or nil when it can't be measured here (instances, other continent).
    local function YardsAway()
        if not (active and active.continent and C_Map and C_Map.GetBestMapForUnit and C_Map.GetPlayerMapPosition) then
            return nil
        end
        local mapID = Call(C_Map.GetBestMapForUnit, "player")
        if not mapID then
            return nil
        end
        local px, py = XY(Call(C_Map.GetPlayerMapPosition, mapID, "player"))
        if not px then
            return nil
        end
        local continent, wx, wy = World(mapID, px, py)
        if not continent or continent ~= active.continent then
            return nil
        end
        return math.sqrt((wx - active.wx) ^ 2 + (wy - active.wy) ^ 2)
    end
    local function Check()
        if not active then
            return Stop()
        end
        if not StillOurs() then
            -- Replaced or removed by the player (or another addon): forget it, never clear it.
            return Stop()
        end
        local yards = YardsAway()
        if yards and yards <= ARRIVE_YARDS then
            if C_Map.ClearUserWaypoint then
                pcall(C_Map.ClearUserWaypoint)
            end
            Stop()
        end
    end
    local function OnUpdate(_, delta)
        elapsed = elapsed + (tonumber(delta) or 0)
        if elapsed < CHECK_SECONDS then
            return
        end
        elapsed = 0
        local ok, err = pcall(Check)
        if not ok then
            Stop()
            if geterrorhandler then
                geterrorhandler()(err)
            end
        end
    end
    function ForeverWaypoint_Set(mapID, x, y, label)
        mapID, x, y = tonumber(mapID), tonumber(x), tonumber(y)
        if not (mapID and x and y and C_Map and C_Map.SetUserWaypoint and UiMapPoint and UiMapPoint.CreateFromCoordinates) then
            return false, "api"
        end
        if C_Map.CanSetUserWaypointOnMap and not Call(C_Map.CanSetUserWaypointOnMap, mapID) then
            return false, "map"
        end
        local ok, wasSet = pcall(C_Map.SetUserWaypoint, UiMapPoint.CreateFromCoordinates(mapID, x, y))
        if not ok or Plain(wasSet) == false then
            return false, "refused"
        end
        if C_SuperTrack and C_SuperTrack.SetSuperTrackedUserWaypoint then
            pcall(C_SuperTrack.SetSuperTrackedUserWaypoint, true)
        end
        -- Only watch where arrival can be measured; elsewhere the pin simply stays, as before.
        local continent, wx, wy = World(mapID, x, y)
        Stop()
        if continent and CreateFrame then
            active = { mapID = mapID, x = x, y = y, label = label, continent = continent, wx = wx, wy = wy }
            elapsed, watching = 0, true
            watcher = watcher or CreateFrame("Frame")
            watcher:SetScript("OnUpdate", OnUpdate)
            if watcher.Show then
                watcher:Show()
            end
        end
        return true
    end
    -- The pin we set and are still watching, or nil (for pages and tests).
    function ForeverWaypoint_Active()
        return watching and active or nil
    end
end


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

-- The game's ready-check tick, drawn inline in the text.
local TICK = "|TInterface\\RaidFrame\\ReadyCheck-Ready:0|t"
-- ENCOUNTER_END and BOSS_KILL both report one kill; the second within this many seconds is the same kill.
local SAME_KILL_SECONDS = 30

local resolvedMaps = {}
local statusDirty = true
local readyQuests = {}
local charKills          -- this character's kills (saved in DungeonsDB), read on first use
local recentKills = {}   -- boss key -> GetTime() of the last recorded kill, this session only

local function Safe(value)
    if issecretvalue and issecretvalue(value) then
        return nil
    end
    return value
end

-- Round 5 (instance log, wish list, Group Finder listings): filled in further down, used by the pages.
local R5 = {}

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
    -- Every quest done: a tick in front.
    local allDone = counts.done == #dungeon.quests and (TICK .. " ") or ""
    parts[#parts + 1] = string.format("%s%d/%d done", allDone, counts.done, #dungeon.quests)
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

-- Boss kills ---------------------------------------------------------------------------------------
-- Forever closes the combat log to addons, so kills come from ENCOUNTER_END (success) and BOSS_KILL,
-- both documented with the encounter's name. Kept per character in DungeonsDB.kills[ForeverCharacterKey()].

-- "The Baron" and "Baron", "Rhahk'Zor" and "Rhahk'zor" are the same boss.
local function BossKey(name)
    local key = name:lower():gsub("^the%s+", ""):gsub("[^%w]", "")
    return key
end

local function CharKills()
    if charKills then
        return charKills
    end
    local name = UnitName and Safe(UnitName("player"))
    if type(name) ~= "string" or name == "" then
        return nil
    end
    local realm = GetRealmName and Safe(GetRealmName())
    -- Older versions keyed kills by first name + realm ("?" when unreadable); moved once to the shared key.
    local oldKey = name .. "-" .. (type(realm) == "string" and realm or "?")
    DungeonsDB = type(DungeonsDB) == "table" and DungeonsDB or {}
    DungeonsDB.kills = type(DungeonsDB.kills) == "table" and DungeonsDB.kills or {}
    local key = ForeverCharacterAdopt(DungeonsDB.kills, { oldKey })
    DungeonsDB.kills[key] = type(DungeonsDB.kills[key]) == "table" and DungeonsDB.kills[key] or {}
    charKills = DungeonsDB.kills[key]
    return charKills
end

local function RecordKill(encounterName)
    encounterName = Safe(encounterName)
    if type(encounterName) ~= "string" or encounterName == "" then
        return
    end
    local kills = CharKills()
    local key = BossKey(encounterName)
    if not kills or key == "" then
        return
    end
    local now = GetTime and tonumber(Safe(GetTime()))
    if now and recentKills[key] and now - recentKills[key] < SAME_KILL_SECONDS then
        return
    end
    recentKills[key] = now
    local entry = type(kills[key]) == "table" and kills[key] or { name = encounterName, count = 0 }
    entry.count = (tonumber(entry.count) or 0) + 1
    entry.last = type(time) == "function" and Safe(time()) or entry.last
    kills[key] = entry
end

-- Every boss on our list by key, built on first use: a kill saved under one of them is that boss's.
local listedBosses
local function ListedBoss(key)
    if not listedBosses then
        listedBosses = {}
        for _, dungeon in ipairs(List()) do
            for _, boss in ipairs(dungeon.bosses or {}) do
                if type(boss) == "string" then
                    listedBosses[BossKey(boss)] = true
                end
            end
        end
    end
    return listedBosses[key] == true
end

-- How often this character killed a boss from our list, or nil. Names the game reports a little
-- differently (a title added or dropped) match when one contains the other, unless that name is
-- another boss on our list ("The Baron" is part of "Baron Silverlaine", a different boss).
local function KillsOf(boss)
    local kills = CharKills()
    if not kills or type(boss) ~= "string" then
        return nil
    end
    local key = BossKey(boss)
    local entry = kills[key]
    if not entry and #key >= 5 then
        for otherKey, other in pairs(kills) do
            -- Skip the record's own notes (migratedFrom), which are not kills.
            if type(other) == "table" and type(otherKey) == "string" and #otherKey >= 5 and not ListedBoss(otherKey)
                and (otherKey:find(key, 1, true) or key:find(otherKey, 1, true)) then
                entry = other
                break
            end
        end
    end
    return type(entry) == "table" and tonumber(entry.count) or nil
end

local function BossLines(dungeon)
    local lines, killed = {}, 0
    for _, boss in ipairs(dungeon.bosses or {}) do
        local count = KillsOf(boss)
        if count and count > 0 then
            killed = killed + 1
            local times = count > 1 and string.format(" (%d times)", count) or ""
            lines[#lines + 1] = "  " .. TICK .. " " .. GREEN .. boss .. "|r" .. GRAY .. " killed" .. times .. "|r"
        else
            lines[#lines + 1] = "  " .. boss
        end
    end
    return lines, killed
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
    -- Names in another language won't match: then trust the stored number, in Forever's Classic form.
    found = found or CLASSIC_MAP[entrance.mapID or 0] or entrance.mapID
    resolvedMaps[key] = found or false
    return found
end

-- An entrance learned in game (where you stood just before going in), for dungeons whose stored
-- entrance is only approximate. Saved in DungeonsDB.entrances[short] = { mapID, x, y }.
local function LearnedEntrance(dungeon)
    local db = type(DungeonsDB) == "table" and type(DungeonsDB.entrances) == "table" and DungeonsDB.entrances
    local learned = db and dungeon.short and db[dungeon.short]
    if type(learned) == "table" and tonumber(learned.mapID) and tonumber(learned.x) and tonumber(learned.y) then
        return learned
    end
    return nil
end

local function EntranceText(dungeon)
    local entrance = dungeon.entrance or {}
    local learned = LearnedEntrance(dungeon)
    if learned then
        return string.format("%s %.1f, %.1f", entrance.zone or dungeon.zone or "?", learned.x * 100, learned.y * 100)
            .. GRAY .. " (learned when you went in)|r"
    end
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
    local learned = LearnedEntrance(dungeon)
    if learned then
        return (ForeverWaypoint_Set(learned.mapID, learned.x, learned.y, dungeon.name))
    end
    local mapID = ResolveMap(entrance)
    if not mapID then
        return false
    end
    return (ForeverWaypoint_Set(mapID, entrance.x, entrance.y, dungeon.name))
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

-- Level ranges from the game ------------------------------------------------------------------------
-- The Group Finder knows each dungeon's range: C_LFGList.GetActivityInfoTable(activityID) gives minLevel
-- (to enter) and minLevelSuggestion / maxLevelSuggestion. Activity IDs come from Data.lua, or are found
-- by name in the activities the game lists. An activity is only trusted when its name is the dungeon's.
-- Read once per session (again after a login), never in a loop.

local function NameKey(text)
    return (tostring(text or ""):lower():gsub("^the%s+", ""):gsub("[^%w]", ""))
end

local function SameDungeon(dungeon, fullName)
    fullName = Safe(fullName)
    if type(fullName) ~= "string" or fullName == "" then
        return false
    end
    local key = NameKey(fullName)
    if key == NameKey(dungeon.name) then
        return true
    end
    for _, alias in ipairs(dungeon.aliases or {}) do
        if key == NameKey(alias) then
            return true
        end
    end
    return false
end

local function ActivityInfo(id)
    if not (C_LFGList and C_LFGList.GetActivityInfoTable and type(id) == "number") then
        return nil
    end
    local ok, info = pcall(C_LFGList.GetActivityInfoTable, id)
    return ok and type(info) == "table" and info or nil
end

local gameRanges          -- dungeon -> { enter, lo, hi } or false; nil = not read this session
-- Review 4, suspicion 3: the Group Finder may not have its data yet on the first read after login. While
-- any dungeon came back without a range, read again every RANGE_RETRY_SECONDS, up to RANGE_RETRIES times
-- per session (some dungeons are never listed); a range once read is kept.
local RANGE_RETRY_SECONDS, RANGE_RETRIES = 30, 10
local rangeRead = { at = nil, missing = false, retries = 0 }
local function ReadGameRanges()
    local old = gameRanges or {}
    gameRanges = {}
    rangeRead.at = GetTime and tonumber(Safe(GetTime())) or 0
    rangeRead.missing = false
    -- Activities the game lists (undocumented call; pcall), for dungeons without an ID of ours.
    local available = {}
    if C_LFGList and C_LFGList.GetAvailableActivities then
        local ok, list = pcall(C_LFGList.GetAvailableActivities)
        if ok and type(list) == "table" then
            for _, id in ipairs(list) do
                id = Safe(id)
                if type(id) == "number" then
                    available[#available + 1] = { id = id, info = ActivityInfo(id) }
                end
            end
        end
    end
    for _, dungeon in ipairs(List()) do
        local info = ActivityInfo(dungeon.activity)
        if info and not SameDungeon(dungeon, info.fullName) then
            info = nil
        end
        if not info then
            for _, entry in ipairs(available) do
                if entry.info and SameDungeon(dungeon, entry.info.fullName) then
                    info = entry.info
                    break
                end
            end
        end
        local enter = info and Safe(info.minLevel)
        local lo, hi = info and Safe(info.minLevelSuggestion), info and Safe(info.maxLevelSuggestion)
        if type(lo) == "number" and type(hi) == "number" and lo > 0 and hi >= lo then
            gameRanges[dungeon] = { enter = type(enter) == "number" and enter > 0 and enter or nil, lo = lo, hi = hi }
        else
            gameRanges[dungeon] = old[dungeon] or false
            rangeRead.missing = rangeRead.missing or not old[dungeon]
        end
    end
end

-- The game's range for a dungeon, or nil.
local function GameRange(dungeon)
    if not gameRanges then
        rangeRead.retries = 0
        ReadGameRanges()
    elseif rangeRead.missing and rangeRead.retries < RANGE_RETRIES then
        local now = GetTime and tonumber(Safe(GetTime())) or 0
        if now - (rangeRead.at or 0) >= RANGE_RETRY_SECONDS then
            rangeRead.retries = rangeRead.retries + 1
            ReadGameRanges()
        end
    end
    return gameRanges[dungeon] or nil
end

-- The range used for "suits you": the game's when it has one, else ours.
local function Range(dungeon)
    local game = GameRange(dungeon)
    if game then
        return game.lo, game.hi
    end
    return dungeon.minLevel or 0, dungeon.maxLevel or 0
end

local function Suits(dungeon, level)
    local lo, hi = Range(dungeon)
    return level >= lo - BELOW_MIN and level <= hi
end

local function GameRangeText(dungeon)
    local game = GameRange(dungeon)
    if game and (game.lo ~= dungeon.minLevel or game.hi ~= dungeon.maxLevel) then
        return string.format(" %s(game: %d-%d)|r", ORANGE, game.lo, game.hi)
    end
    return ""
end

-- Upgrades per dungeon ----------------------------------------------------------------------------
-- Each loot row is asked of ItemAdvisor's public ItemAdvisor_IsUpgrade(link) (ItemAdvisor's own
-- verdict, nothing reimplemented here), UPGRADE_PER_FRAME items per frame. Items the client hasn't
-- loaded are requested (C_Item.RequestLoadItemDataByID) and checked on ITEM_DATA_LOAD_RESULT; items
-- that don't exist (C_Item.DoesItemExistByID) are skipped. New gear or a level resets the answers.
local UPGRADE_PER_FRAME = 5
local upgradeOf = {}                  -- itemID -> true / false once checked
local upgradeQueue, upgradeQueued, upgradeRunning = {}, {}, false
local waitingItems = {}

local function CanJudge()
    return type(ItemAdvisor_IsUpgrade) == "function" and C_Item and C_Item.GetItemInfo
end

local function JudgeItem(id)
    if not CanJudge() then
        return
    end
    if C_Item.DoesItemExistByID then
        local ok, exists = pcall(C_Item.DoesItemExistByID, id)
        if ok and Safe(exists) == false then
            upgradeOf[id] = false
            return
        end
    end
    local ok, _, link = pcall(C_Item.GetItemInfo, id)
    link = ok and Safe(link) or nil
    if type(link) ~= "string" then
        waitingItems[id] = true
        if C_Item.RequestLoadItemDataByID then
            pcall(C_Item.RequestLoadItemDataByID, id)
        end
        return
    end
    local okJudge, yes, reason = pcall(ItemAdvisor_IsUpgrade, link)
    yes, reason = okJudge and Safe(yes) == true, okJudge and Safe(reason) or nil
    -- Review 4, suspicion 5: ItemAdvisor says false with no reason while it has no character data, and
    -- "still loading" / "Can't read" while stats load. That isn't a final "no": leave it unanswered, so the
    -- next look at the page asks again.
    if not yes and (type(reason) ~= "string" or reason:find("loading", 1, true) or reason:find("Can't read", 1, true)) then
        return
    end
    upgradeOf[id] = yes
end

local function RunUpgradeQueue()
    for _ = 1, UPGRADE_PER_FRAME do
        local id = table.remove(upgradeQueue, 1)
        if not id then
            upgradeRunning = false
            return
        end
        upgradeQueued[id] = nil
        JudgeItem(id)
    end
    if #upgradeQueue == 0 then
        upgradeRunning = false
    elseif C_Timer and C_Timer.After then
        C_Timer.After(0, RunUpgradeQueue)
    else
        return RunUpgradeQueue()
    end
end

local function QueueItem(id)
    if type(id) ~= "number" or upgradeOf[id] ~= nil or upgradeQueued[id] or waitingItems[id] then
        return
    end
    upgradeQueued[id] = true
    upgradeQueue[#upgradeQueue + 1] = id
    if not upgradeRunning then
        upgradeRunning = true
        if C_Timer and C_Timer.After then
            C_Timer.After(0, RunUpgradeQueue)
        else
            RunUpgradeQueue()
        end
    end
end

local function QueueDungeon(dungeon)
    if not CanJudge() then
        return
    end
    for _, item in ipairs(dungeon.loot or {}) do
        QueueItem(item[1])
    end
end

-- Slot words of the loot rows that are upgrades (not ones you already have), or an empty list.
local function UpgradeSlots(dungeon)
    local slots = {}
    if not CanJudge() then
        return slots
    end
    for _, item in ipairs(dungeon.loot or {}) do
        local have = item[1] and C_Item.GetItemCount and (tonumber(Safe(C_Item.GetItemCount(item[1], true))) or 0) > 0
        if item[1] and upgradeOf[item[1]] and not have then
            slots[#slots + 1] = type(item[4]) == "string" and item[4]:match("^([^,]+)"):lower() or "?"
        end
    end
    return slots
end

local function UpgradeText(dungeon)
    local slots = UpgradeSlots(dungeon)
    if #slots == 0 then
        return ""
    end
    return string.format(" %s%d upgrade%s (%s)|r", GREEN, #slots, #slots == 1 and "" or "s", table.concat(slots, ", "))
end

local function ShortLine(index, dungeon, level)
    return string.format("%s%d.|r %s%s %s(%d-%d, %s)|r%s %s%s", GOLD, index, dungeon.name, Tags(dungeon), GRAY,
        dungeon.minLevel or 0, dungeon.maxLevel or 0, dungeon.zone or "?", GameRangeText(dungeon), CountsText(dungeon, level),
        UpgradeText(dungeon)) .. R5.WishText(dungeon)
end

local STATE_TEXT = {
    -- A tick as well as the word, so finished quests stand out in the list.
    done = TICK .. " " .. GREEN .. "Done|r",
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
    if itemID and R5.IsWished(itemID) then
        text = text .. " " .. R5.STAR .. YELLOW .. "wish list|r"
    end
    if itemID and Owned(itemID) then
        text = text .. " " .. GREEN .. "(you have it)|r"
    elseif itemID and upgradeOf[itemID] and CanJudge() then
        text = text .. " " .. GREEN .. "(upgrade for you)|r"
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
    local game = GameRange(dungeon)
    if game then
        Print(GRAY .. string.format("Group Finder: from level %s, suggested %d-%d", tostring(game.enter or "?"), game.lo, game.hi) .. "|r")
    end
    local lo, hi = Range(dungeon)
    if level < lo - BELOW_MIN then
        Print(GRAY .. string.format("You're level %d: this one is for later.", level) .. "|r")
    elseif level > hi then
        Print(GRAY .. string.format("You're level %d: above this dungeon's range.", level) .. "|r")
    end
    Print(GOLD .. "Entrance:|r " .. EntranceText(dungeon))
    if dungeon.bosses and #dungeon.bosses > 0 then
        local lines, killed = BossLines(dungeon)
        if killed == 0 then
            Print(GOLD .. "Bosses:|r " .. table.concat(dungeon.bosses, ", ") .. GRAY .. " (none killed on this character yet)|r")
        else
            Print(GOLD .. "Bosses:|r " .. GRAY .. string.format("(%d/%d killed on this character)", killed, #dungeon.bosses) .. "|r")
            for _, line in ipairs(lines) do
                Print(line)
            end
        end
    end
    if dungeon.alsoReported and #dungeon.alsoReported > 0 then
        Print(GRAY .. "Also reported (not confirmed yet): " .. table.concat(dungeon.alsoReported, ", ") .. "|r")
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
        QueueDungeon(dungeon)
        Print(GOLD .. "Notable loot:|r" .. UpgradeText(dungeon))
        local classFile = MyClass()
        for _, item in ipairs(dungeon.loot) do
            Print(LootLine(item, classFile, level))
        end
        Print(GRAY .. "Wish list: tick items in the Dungeons window (Wish list), or type: wish " .. index
            .. " and the item's place in this list (wish " .. index .. " 1 for the first).|r")
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
            QueueDungeon(dungeon)
            Print(ShortLine(index, dungeon, level))
        end
    end
    if not any then
        Print("No dungeon fits your level right now.")
    end
    local coming = {}
    for index, dungeon in ipairs(list) do
        local lo, hi = Range(dungeon)
        if lo - BELOW_MIN > level and #coming < COMING_UP then
            coming[#coming + 1] = string.format("%d. %s (%d-%d)", index, dungeon.name, lo, hi)
        end
    end
    if #coming > 0 then
        Print(GRAY .. "Coming up: " .. table.concat(coming, ", ") .. "|r")
    end
    if UnitFactionGroup and Safe(UnitFactionGroup("player")) == "Horde" then
        Print(GRAY .. "The quest lists here are the Alliance ones.|r")
    end
    Print(GRAY .. "Type a number or a name for details, pin 2 to mark an entrance, or all for every dungeon.|r")
    Print(GRAY .. "Also: log (dungeon entries and your runs), wish (your wish list), groups (Group Finder listings"
        .. " after you search), window (the Dungeons window).|r")
    R5.CapLine()
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
        -- Hidden (in an instance, say): "dungeons for level 1" would be wrong, so say so instead.
        local readable = UnitLevel and tonumber(Safe(UnitLevel("player")))
        if not readable then
            Print("Your level can't be read right now (it's hidden in some instances). Type all to see every dungeon.")
            return
        end
        ShowSuited(level)
        return
    end
    -- Instance log, wish list, Group Finder listings, the window and their settings.
    if R5.Page(want) then
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

-- Kills by NPC ID ----------------------------------------------------------------------------------
-- Some bosses never fire ENCOUNTER_END / BOSS_KILL. UNIT_DIED(unitGUID) and PARTY_KILL(attackerGUID,
-- targetGUID) (UnitDocumentation; plain events, not CallbackEvents, but their GUIDs can be secret, so
-- they go through Safe()) name the creature that died; its NPC ID maps to a boss from Data.lua's npcs
-- or one learned in game. The kill is recorded under the boss's name, so the 30 s dedupe also covers
-- ENCOUNTER_END and BOSS_KILL for the same kill.

local function NpcID(guid)
    guid = Safe(guid)
    if type(guid) ~= "string" then
        return nil
    end
    local kind, id = guid:match("^(%a+)%-%d+%-%d+%-%d+%-%d+%-(%d+)%-")
    if kind == "Creature" or kind == "Vehicle" then
        return tonumber(id)
    end
    return nil
end

local function InInstance()
    if not IsInInstance then
        return nil
    end
    local ok, inside = pcall(IsInInstance)
    if not ok then
        return nil
    end
    return Safe(inside)
end

-- The dungeon you're in, from GetInstanceInfo's name, or nil.
local function CurrentDungeon()
    if not GetInstanceInfo then
        return nil
    end
    local ok, name = pcall(GetInstanceInfo)
    name = ok and Safe(name) or nil
    if type(name) ~= "string" then
        return nil
    end
    for _, dungeon in ipairs(List()) do
        if SameDungeon(dungeon, name) then
            return dungeon
        end
    end
    return nil
end

local function LearnedNpcs()
    DungeonsDB = type(DungeonsDB) == "table" and DungeonsDB or {}
    DungeonsDB.learnedNpcs = type(DungeonsDB.learnedNpcs) == "table" and DungeonsDB.learnedNpcs or {}
    return DungeonsDB.learnedNpcs
end

local bossByNpc
local function BossForNpc(npc)
    if not bossByNpc then
        bossByNpc = {}
        for _, dungeon in ipairs(List()) do
            for name, id in pairs(dungeon.npcs or {}) do
                bossByNpc[id] = name
            end
        end
    end
    local learned = LearnedNpcs()[npc]
    if type(learned) == "table" and type(learned.boss) == "string" then
        return learned.boss
    end
    return bossByNpc[npc]
end

local function KillByGUID(guid)
    local npc = NpcID(guid)
    -- Bosses live in dungeons; outdoors a creature with the same ID is not that kill.
    if not npc or InInstance() == false then
        return
    end
    local boss = BossForNpc(npc)
    if boss then
        RecordKill(boss)
    end
end

-- Your target inside a dungeon is one of its bosses by name, and its NPC ID isn't the one we have:
-- remember it (covers bosses without an ID and ones whose live ID differs).
local function LearnFromTarget()
    if not (UnitGUID and UnitName) then
        return
    end
    local npc = NpcID(UnitGUID("target"))
    local name = Safe(UnitName("target"))
    if not npc or type(name) ~= "string" or name == "" or BossForNpc(npc) then
        return
    end
    local dungeon = CurrentDungeon()
    if not dungeon then
        return
    end
    local key = BossKey(name)
    for _, boss in ipairs(dungeon.bosses or {}) do
        if BossKey(boss) == key then
            LearnedNpcs()[npc] = { boss = boss, dungeon = dungeon.short }
            return
        end
    end
end

-- Learned entrances -------------------------------------------------------------------------------
-- For dungeons whose entrance is marked "approx": every ENTRANCE_SAMPLE seconds outdoors, your map
-- position is noted; when you're then inside that dungeon (within ENTRANCE_FRESH seconds, on the
-- entrance's own zone map), the last spot is saved as its entrance.
local ENTRANCE_SAMPLE, ENTRANCE_FRESH = 2, 30
local lastSpot, entranceTicker, approxMaps

local function Approx(dungeon)
    local note = dungeon.entrance and dungeon.entrance.note
    return type(note) == "string" and note:lower():find("^approx") ~= nil
end

local function SampleSpot()
    if InInstance() ~= false or not (C_Map and C_Map.GetBestMapForUnit and C_Map.GetPlayerMapPosition) then
        return
    end
    local ok, mapID = pcall(C_Map.GetBestMapForUnit, "player")
    mapID = ok and Safe(mapID) or nil
    if type(mapID) ~= "number" then
        return
    end
    -- Only on a zone that has an approximate entrance.
    if not approxMaps then
        approxMaps = {}
        for _, dungeon in ipairs(List()) do
            local zoneMap = Approx(dungeon) and ResolveMap(dungeon.entrance)
            if zoneMap then
                approxMaps[zoneMap] = true
            end
        end
    end
    if not approxMaps[mapID] then
        return
    end
    local okPos, pos = pcall(C_Map.GetPlayerMapPosition, mapID, "player")
    local x, y = okPos and type(pos) == "table" and Safe(pos.x), okPos and type(pos) == "table" and Safe(pos.y)
    if type(x) == "number" and type(y) == "number" and (x > 0 or y > 0) then
        lastSpot = { mapID = mapID, x = x, y = y, at = GetTime and tonumber(Safe(GetTime())) }
    end
end

local function LearnEntrance()
    if InInstance() ~= true or not lastSpot then
        return
    end
    local dungeon = CurrentDungeon()
    if not (dungeon and dungeon.short and Approx(dungeon)) then
        return
    end
    local now = GetTime and tonumber(Safe(GetTime()))
    if not (now and lastSpot.at and now - lastSpot.at <= ENTRANCE_FRESH) then
        return
    end
    if ResolveMap(dungeon.entrance) ~= lastSpot.mapID then
        return
    end
    DungeonsDB = type(DungeonsDB) == "table" and DungeonsDB or {}
    DungeonsDB.entrances = type(DungeonsDB.entrances) == "table" and DungeonsDB.entrances or {}
    DungeonsDB.entrances[dungeon.short] = {
        mapID = lastSpot.mapID,
        x = math.floor(lastSpot.x * 1000 + 0.5) / 1000,
        y = math.floor(lastSpot.y * 1000 + 0.5) / 1000,
    }
    lastSpot = nil
end

-- Round 5 -------------------------------------------------------------------------------------------
-- #3 Instance log (ideas from Nova Instance Tracker and Memories; our own code): every new copy of a
-- dungeon you enter is a run, kept account-wide in DungeonsDB.runs (last MAX_RUNS). Entries in the last
-- hour and day are counted against a cap that is a setting (Forever's real cap is unconfirmed; Classic's
-- 5 an hour and 30 a day are the defaults). An entry is counted until an hour (a day) after you last left
-- that copy, the careful reading. Per run: time inside, kills that gave XP (one CHAT_MSG_COMBAT_XP_GAIN
-- each; the text is never read), XP, gold looted (money gained while a loot window is open), deaths,
-- notable loot that reached your bags, levels in and out.
-- A new copy is told from a re-entry by the copy number in creature GUIDs (Creature-0-server-instance-
-- zoneUID-npc-spawn) of your target, mouseover or nameplates, when the game lets us read them in there
-- (in-game check: they may be hidden in instances). Until then, and when they never show: back within
-- the re-entry window (30 minutes, a setting) is the same copy. A guess the GUIDs prove wrong is undone.
-- #7 Wish list (ideas from AtlasLoot's favourites; no code): per character, dungeon items only, at most
-- MAX_WISH. Dungeons_IsWished(itemID or link) answers for a later tooltip line.
-- #12 Group Finder listings: only after you search yourself (LFG_LIST_SEARCH_RESULTS_RECEIVED), the
-- results are matched to our dungeons by activity ID. Nothing here searches, applies or signs up, and a
-- listing's name and comment are never read. Kept for this session only.
do
    local MAX_RUNS, MAX_WISH, MAX_RUN_LOOT, LOG_RUNS, WISH_ROWS = 100, 150, 12, 15, 14
    local HOUR, DAY = 3600, 86400
    local LOOT_GRACE, GROUPS_FRESH, MAX_RESULTS = 1.5, 600, 200
    local DEFAULTS = { hourCap = 5, dayCap = 30, reentryMinutes = 30 }
    local LIMITS = { hourCap = { 1, 30 }, dayCap = { 1, 200 }, reentryMinutes = { 5, 240 } }
    -- What the round-5 code keeps between events: XP, level and money last read, the copy seen this visit,
    -- the loot window, the Group Finder snapshot, the window.
    local st = { lootOpen = false }
    R5.STAR = "|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_1:0|t"

    local function Call(fn, ...)
        if type(fn) ~= "function" then
            return nil
        end
        local ok, a, b, c = pcall(fn, ...)
        if not ok then
            return nil
        end
        return Safe(a), Safe(b), Safe(c)
    end

    local function Clock()
        return tonumber(Call(time)) or 0
    end

    local function Mono()
        return tonumber(Call(GetTime)) or 0
    end

    local function DB()
        DungeonsDB = type(DungeonsDB) == "table" and DungeonsDB or {}
        local db = DungeonsDB
        db.runs = type(db.runs) == "table" and db.runs or {}
        db.wish = type(db.wish) == "table" and db.wish or {}
        db.settings = type(db.settings) == "table" and db.settings or {}
        return db
    end

    local function CharKey()
        return type(ForeverCharacterKey) == "function" and ForeverCharacterKey() or "?"
    end

    function R5.Setting(name)
        local value = type(DungeonsDB) == "table" and type(DungeonsDB.settings) == "table" and tonumber(DungeonsDB.settings[name])
        local limit = LIMITS[name]
        if not value or value < limit[1] or value > limit[2] then
            return DEFAULTS[name]
        end
        return math.floor(value)
    end

    function R5.SetSetting(name, value)
        value = tonumber(value)
        local limit = LIMITS[name]
        if not (limit and value) then
            return nil
        end
        value = math.max(limit[1], math.min(limit[2], math.floor(value + 0.5)))
        DB().settings[name] = value
        return value
    end

    local function Money(copper)
        copper = math.floor(tonumber(copper) or 0)
        local gold, silver = math.floor(copper / 10000), math.floor(copper / 100) % 100
        if gold > 0 then
            return string.format("%dg %ds", gold, silver)
        elseif silver > 0 then
            return string.format("%ds %dc", silver, copper % 100)
        end
        return string.format("%dc", copper % 100)
    end

    local function Minutes(seconds)
        local minutes = math.max(1, math.ceil((tonumber(seconds) or 0) / 60))
        if minutes >= 60 then
            return string.format("%dh %dm", math.floor(minutes / 60), minutes % 60)
        end
        return minutes .. " min"
    end

    local function When(stamp)
        local text = type(date) == "function" and tonumber(stamp) and Call(date, "%d %b %H:%M", stamp)
        return type(text) == "string" and text or "?"
    end

    -- Wish list and item sources ---------------------------------------------------------------------

    local sourceOf
    -- { dungeon, item row } for a dungeon item on our list, or nil.
    function R5.Source(id)
        if not sourceOf then
            sourceOf = {}
            for _, dungeon in ipairs(List()) do
                for _, item in ipairs(dungeon.loot or {}) do
                    if type(item[1]) == "number" and not sourceOf[item[1]] then
                        sourceOf[item[1]] = { dungeon = dungeon, item = item }
                    end
                end
            end
        end
        return sourceOf[tonumber(id) or 0]
    end

    -- This character's wish list (itemID -> time added), read only: nil before saved data exists.
    local function Wishes(create)
        if create then
            local db = DB()
            local key = CharKey()
            db.wish[key] = type(db.wish[key]) == "table" and db.wish[key] or {}
            return db.wish[key]
        end
        local list = type(DungeonsDB) == "table" and type(DungeonsDB.wish) == "table" and DungeonsDB.wish[CharKey()]
        return type(list) == "table" and list or nil
    end

    function R5.IsWished(id)
        local list = Wishes(false)
        return list ~= nil and list[tonumber(id) or 0] ~= nil
    end

    local function WishCount()
        local count = 0
        for _ in pairs(Wishes(false) or {}) do
            count = count + 1
        end
        return count
    end

    -- Adds or removes a dungeon item. Returns true (added), false (removed), or nil and a reason.
    function R5.Toggle(id)
        id = tonumber(id)
        if not (id and R5.Source(id)) then
            return nil, "Only items from the dungeon loot lists can go on the wish list."
        end
        local list = Wishes(true)
        if list[id] then
            list[id] = nil
            return false
        end
        if WishCount() >= MAX_WISH then
            return nil, string.format("Your wish list is full (%d items). Take something off first.", MAX_WISH)
        end
        list[id] = Clock()
        return true
    end

    local function ItemName(id, link)
        local name = Call(C_Item and C_Item.GetItemInfo, id)
        if type(name) == "string" and name ~= "" then
            return name
        end
        if type(link) == "string" and link:match("%[(.-)%]") then
            return link:match("%[(.-)%]")
        end
        local source = R5.Source(id)
        return source and source.item[2] or ("item " .. tostring(id))
    end

    local function Have(id)
        return (tonumber(Call(C_Item and C_Item.GetItemCount, id, true)) or 0) > 0
    end

    -- " *2" after a dungeon's line when 2 of its items are on your wish list.
    function R5.WishText(dungeon)
        local count = 0
        for _, item in ipairs(dungeon.loot or {}) do
            if item[1] and R5.IsWished(item[1]) then
                count = count + 1
            end
        end
        return count > 0 and (" " .. R5.STAR .. YELLOW .. count .. "|r") or ""
    end

    -- Wished items in loot-list order: { id, item row, dungeon }.
    local function WishedItems()
        local items = {}
        local list = Wishes(false)
        if not list then
            return items
        end
        for _, dungeon in ipairs(List()) do
            for _, item in ipairs(dungeon.loot or {}) do
                if item[1] and list[item[1]] then
                    items[#items + 1] = { id = item[1], item = item, dungeon = dungeon }
                end
            end
        end
        return items
    end

    local function WishLine(entry)
        local item = entry.item
        local text = R5.STAR .. " " .. (item[2] or ItemName(entry.id))
        if item[4] then
            text = text .. GRAY .. " (" .. item[4] .. ")|r"
        end
        text = text .. " - " .. tostring(item[3] or "?") .. ", " .. entry.dungeon.name
        if Have(entry.id) then
            text = text .. " " .. GREEN .. "(you have it)|r"
        end
        return text
    end

    function R5.WishLines()
        local lines = { GOLD .. "Your wish list|r" .. GRAY .. " (this character; dungeon items only)|r" }
        local items = WishedItems()
        if #items == 0 then
            lines[#lines + 1] = "Nothing on it yet. Tick items in the Dungeons window (Wish list), or open a dungeon's page"
                .. " and type: wish <dungeon number> <item number>."
            return lines
        end
        local byDungeon = {}
        for _, entry in ipairs(items) do
            local name = entry.dungeon.name
            byDungeon[name] = (byDungeon[name] or 0) + 1
        end
        for _, entry in ipairs(items) do
            lines[#lines + 1] = "  " .. WishLine(entry)
        end
        local counts = {}
        for _, dungeon in ipairs(List()) do
            if byDungeon[dungeon.name] then
                counts[#counts + 1] = string.format("%s %d", dungeon.name, byDungeon[dungeon.name])
            end
        end
        lines[#lines + 1] = GRAY .. "By dungeon: " .. table.concat(counts, ", ") .. "|r"
        return lines
    end

    -- Instance log -----------------------------------------------------------------------------------

    -- In a dungeon or raid: true, its name, its map's instance ID. false outside; nil when unreadable.
    local function Where()
        if not IsInInstance then
            return nil
        end
        local ok, inside, kind = pcall(IsInInstance)
        if not ok then
            return nil
        end
        inside, kind = Safe(inside), Safe(kind)
        if inside ~= true or (kind ~= "party" and kind ~= "raid") then
            return false
        end
        local okInfo, name, _, _, _, _, _, _, mapID = pcall(GetInstanceInfo)
        name, mapID = okInfo and Safe(name) or nil, okInfo and Safe(mapID) or nil
        if type(name) ~= "string" or name == "" then
            return nil
        end
        return true, name, tonumber(mapID) or name
    end

    local function Snapshot()
        st.xp, st.xpMax = tonumber(Call(UnitXP, "player")), tonumber(Call(UnitXPMax, "player"))
        st.level = tonumber(Call(UnitLevel, "player"))
        st.money = tonumber(Call(GetMoney))
    end

    -- The latest run of a character (in that dungeon), skipping one.
    local function LatestRun(char, mapID, except)
        local runs = DB().runs
        for index = #runs, 1, -1 do
            local run = runs[index]
            if type(run) == "table" and run ~= except and run.char == char and (mapID == nil or run.mapID == mapID) then
                return run
            end
        end
        return nil
    end

    local function Remove(run)
        local runs = DB().runs
        for index = #runs, 1, -1 do
            if runs[index] == run then
                table.remove(runs, index)
                return
            end
        end
    end

    local function NewRun(name, mapID, now)
        local runs = DB().runs
        local run = { char = CharKey(), who = type(ForeverCharacterName) == "function" and ForeverCharacterName() or nil,
            name = name, mapID = mapID, start = now, seen = now, secs = 0, xp = 0, kills = 0, gold = 0, deaths = 0,
            loot = {}, lvlIn = st.level, reentries = 0, judged = "new" }
        runs[#runs + 1] = run
        while #runs > MAX_RUNS do
            table.remove(runs, 1)
        end
        return run
    end

    local function Open()
        local run = st.run
        return run and run.inSince and run or nil
    end

    -- New dungeons entered in the last hour and day (every character on this account), and the seconds
    -- until the oldest of them stops counting.
    function R5.Entries(now)
        now = now or Clock()
        local hour, day, freeHour, freeDay = 0, 0, nil, nil
        for _, run in ipairs(DB().runs) do
            if type(run) == "table" then
                local last = run.inSince and now or tonumber(run.leave) or tonumber(run.seen) or tonumber(run.start) or 0
                if now - last < HOUR then
                    hour = hour + 1
                    freeHour = math.min(freeHour or HOUR, last + HOUR - now)
                end
                if now - last < DAY then
                    day = day + 1
                    freeDay = math.min(freeDay or DAY, last + DAY - now)
                end
            end
        end
        return hour, day, freeHour, freeDay
    end

    -- "2 of 5 this hour, 3 of 30 today", and the warning part when near or at the cap.
    local function CapState()
        local hour, day, freeHour, freeDay = R5.Entries()
        local hourCap, dayCap = R5.Setting("hourCap"), R5.Setting("dayCap")
        local counts = string.format("%d of %d this hour, %d of %d today", hour, hourCap, day, dayCap)
        local full = hour >= hourCap and freeHour or (day >= dayCap and freeDay) or nil
        if full then
            return counts, string.format("at the cap: a new dungeon may be refused for about %s", Minutes(full)), true
        elseif hour == hourCap - 1 or day >= dayCap - 2 then
            return counts, "one more new dungeon reaches the cap", false
        end
        return counts, nil, nil
    end

    function R5.WarnCap()
        local counts, warning, full = CapState()
        if warning then
            Print((full and ORANGE or YELLOW) .. "Dungeon entries: " .. counts .. ": " .. warning .. ".|r")
        end
    end

    -- One line for the dungeon list page, only when you entered something lately.
    function R5.CapLine()
        local hour, day = R5.Entries()
        if day == 0 then
            return
        end
        local counts, warning, full = CapState()
        Print((full and ORANGE or GRAY) .. "Dungeon entries: " .. counts .. (warning and (": " .. warning) or "") .. ".|r")
    end

    local function Changed()
        if st.window and st.window:IsShown() and R5.Refresh then
            R5.Refresh()
        end
    end

    local function Enter(name, mapID)
        local now = Clock()
        Snapshot()
        local last = LatestRun(CharKey(), mapID)
        local lastOut = last and (tonumber(last.leave) or tonumber(last.seen) or tonumber(last.start))
        local run
        if last and lastOut and now - lastOut <= R5.Setting("reentryMinutes") * 60 then
            run = last
            run.reentries = (tonumber(run.reentries) or 0) + 1
            run.prevLeave, run.leave = run.leave, nil
            if run.judged ~= "ids" then
                run.judged = "time"
            end
        else
            run = NewRun(name, mapID, now)
        end
        run.inSince, run.seen = now, now
        st.run, st.copy, st.visitStart = run, nil, now
        if run.reentries == 0 then
            R5.WarnCap()
        end
        Changed()
    end

    local function CloseVisit(now)
        local run = Open()
        if run then
            run.secs = (tonumber(run.secs) or 0) + math.max(0, now - run.inSince)
            run.inSince, run.leave, run.seen = nil, now, now
            run.lvlOut = tonumber(Call(UnitLevel, "player")) or run.lvlOut
        end
        st.run, st.copy = nil, nil
    end

    -- Runs left open by a crash or a lost logout: closed at the last time we saw you inside.
    local function CloseStale()
        for _, run in ipairs(DB().runs) do
            if type(run) == "table" and run.inSince and run ~= st.run then
                local seen = tonumber(run.seen) or tonumber(run.inSince) or 0
                run.secs = (tonumber(run.secs) or 0) + math.max(0, seen - (tonumber(run.inSince) or seen))
                run.inSince, run.leave = nil, seen
            end
        end
    end

    function R5.CheckZone()
        st.zonePending = false
        local inside, name, mapID = Where()
        if inside == nil then
            return
        end
        if not st.staleChecked then
            st.staleChecked = true
            CloseStale()
        end
        local run = Open()
        if inside then
            if run and run.mapID == mapID then
                run.seen = Clock()
                return
            end
            if run then
                CloseVisit(Clock())
            end
            Enter(name, mapID)
        elseif run then
            CloseVisit(Clock())
            Changed()
        end
    end

    local function AddLoot(run, id)
        run.loot = type(run.loot) == "table" and run.loot or {}
        for _, have in ipairs(run.loot) do
            if have == id then
                return
            end
        end
        if #run.loot < MAX_RUN_LOOT then
            run.loot[#run.loot + 1] = id
        end
    end

    local function Add(run, field, amount)
        run[field] = (tonumber(run[field]) or 0) + amount
    end

    -- This visit's run was opened as new, but the GUIDs show the copy of your previous run: one run.
    local function MergeInto(previous, run)
        Remove(run)
        for _, field in ipairs({ "xp", "kills", "gold", "deaths", "secs" }) do
            Add(previous, field, tonumber(run[field]) or 0)
        end
        for _, id in ipairs(type(run.loot) == "table" and run.loot or {}) do
            AddLoot(previous, id)
        end
        previous.reentries = (tonumber(previous.reentries) or 0) + 1
        previous.prevLeave, previous.leave = previous.leave, nil
        previous.inSince, previous.seen, previous.judged = run.inSince, run.seen, "ids"
        st.run = previous
    end

    -- This visit was taken for a re-entry, but the GUIDs show another copy: a new run from this visit on.
    local function Split(run, copy)
        local fresh = NewRun(run.name, run.mapID, st.visitStart or Clock())
        fresh.inSince, fresh.seen, fresh.copy, fresh.judged = run.inSince, run.seen, copy, "ids"
        run.inSince = nil
        run.leave = run.prevLeave or st.visitStart
        run.reentries = math.max(0, (tonumber(run.reentries) or 1) - 1)
        st.run = fresh
        R5.WarnCap()
    end

    -- A creature's GUID seen inside: its copy number tells this copy of the dungeon from another.
    function R5.SeeGUID(guid)
        local run = Open()
        guid = Safe(guid)
        if not run or st.copy or type(guid) ~= "string" then
            return
        end
        local kind, server, instance, zone = guid:match("^(%a+)%-%d+%-(%d+)%-(%d+)%-(%d+)%-%d+%-")
        if (kind ~= "Creature" and kind ~= "Vehicle") or not zone or zone == "0" then
            return
        end
        local copy = server .. "-" .. instance .. "-" .. zone
        st.copy = copy
        if run.copy == nil then
            local previous = run.reentries == 0 and LatestRun(run.char, run.mapID, run)
            if previous and previous.copy == copy and not previous.inSince then
                MergeInto(previous, run)
            else
                run.copy, run.judged = copy, "ids"
            end
        elseif run.copy ~= copy then
            Split(run, copy)
        else
            run.judged = "ids"
        end
        Changed()
    end

    local function XPChanged()
        local xp, xpMax, level = tonumber(Call(UnitXP, "player")), tonumber(Call(UnitXPMax, "player")), tonumber(Call(UnitLevel, "player"))
        if not (xp and level) then
            return
        end
        local run = Open()
        if st.xp and st.level then
            local gained
            if level == st.level and xp < st.xp and st.xpMax then
                -- A level-up while UnitLevel still gives the old level: count it once, as the next level.
                gained = st.xpMax - st.xp + xp
                level = level + 1
            elseif level == st.level then
                gained = xp - st.xp
            elseif level > st.level and st.xpMax then
                gained = st.xpMax - st.xp + xp
            end
            if run and gained and gained > 0 then
                Add(run, "xp", gained)
                run.seen = Clock()
            end
        end
        st.xp, st.xpMax, st.level = xp, xpMax or st.xpMax, math.max(level, st.level or level)
    end

    local function MoneyChanged()
        local money = tonumber(Call(GetMoney))
        if not money then
            return
        end
        local run = Open()
        local looting = st.lootOpen or (st.lootClosedAt and Mono() - st.lootClosedAt <= LOOT_GRACE)
        if run and st.money and money > st.money and looting then
            Add(run, "gold", money - st.money)
        end
        st.money = money
    end

    local function Count(id)
        return tonumber(Call(C_Item and C_Item.GetItemCount, id)) or 0
    end

    -- Worth keeping in a run: a dungeon item on our lists, a wish, or anything blue or better.
    local function Notable(id, link)
        if R5.Source(id) or R5.IsWished(id) then
            return true
        end
        local _, _, quality = Call(C_Item and C_Item.GetItemInfo, link or id)
        return (tonumber(quality) or 0) >= 3
    end

    local function LootOpened()
        st.lootOpen = true
        local slots = math.min(tonumber(Call(GetNumLootItems)) or 0, 30)
        local run = Open()
        local wished = {}
        st.pending = run and {} or nil
        for slot = 1, slots do
            local link = Call(GetLootSlotLink, slot)
            local id = type(link) == "string" and tonumber(link:match("item:(%d+)"))
            if id then
                if R5.IsWished(id) then
                    wished[#wished + 1] = ItemName(id, link)
                end
                if run and Notable(id, link) then
                    st.pending[id] = Count(id)
                end
            end
        end
        if #wished > 0 then
            Print(YELLOW .. "On your wish list, in this loot: " .. table.concat(wished, ", ") .. "|r")
        end
    end

    -- After the loot window closes: notable items that reached your bags join the run.
    local function CheckPending()
        local pending, run = st.pending, st.lootRun
        st.pending, st.lootRun = nil, nil
        if not (pending and run) then
            return
        end
        for id, before in pairs(pending) do
            if Count(id) > before then
                AddLoot(run, id)
            end
        end
    end

    local function LootClosed()
        st.lootOpen, st.lootClosedAt = false, Mono()
        if st.pending then
            st.lootRun = Open()
            if C_Timer and C_Timer.After then
                C_Timer.After(1, CheckPending)
            else
                CheckPending()
            end
        end
    end

    local function RunLine(run, now)
        local secs = (tonumber(run.secs) or 0) + (run.inSince and math.max(0, now - run.inSince) or 0)
        local parts = { string.format("%s%s|r %s(%s)|r, %s", GOLD, tostring(run.name or "?"), GRAY, When(run.start), Minutes(secs)) }
        parts[#parts + 1] = string.format("%d kill%s with XP", tonumber(run.kills) or 0, (tonumber(run.kills) or 0) == 1 and "" or "s")
        if (tonumber(run.xp) or 0) > 0 then
            parts[#parts + 1] = string.format("%d XP", run.xp)
        end
        if (tonumber(run.gold) or 0) > 0 then
            parts[#parts + 1] = Money(run.gold) .. " looted"
        end
        local deaths = tonumber(run.deaths) or 0
        if deaths > 0 then
            parts[#parts + 1] = ORANGE .. deaths .. (deaths == 1 and " death" or " deaths") .. "|r"
        end
        local lvlOut = run.inSince and st.level or run.lvlOut
        if run.lvlIn and lvlOut and lvlOut ~= run.lvlIn then
            parts[#parts + 1] = string.format("level %d to %d", run.lvlIn, lvlOut)
        end
        local text = table.concat(parts, ", ")
        if type(run.loot) == "table" and #run.loot > 0 then
            local names = {}
            for _, id in ipairs(run.loot) do
                names[#names + 1] = (R5.IsWished(id) and (R5.STAR) or "") .. ItemName(id)
            end
            text = text .. "\n      " .. GRAY .. "Loot:|r " .. table.concat(names, ", ")
        end
        local notes = {}
        if (tonumber(run.reentries) or 0) > 0 then
            notes[#notes + 1] = string.format("went back in %d time%s", run.reentries, run.reentries == 1 and "" or "s")
        end
        if run.judged == "ids" then
            notes[#notes + 1] = "copy told by creature IDs"
        elseif run.judged == "time" then
            notes[#notes + 1] = "same copy by the re-entry rule"
        end
        if run.char ~= CharKey() and run.who then
            notes[#notes + 1] = tostring(run.who)
        end
        if run.inSince then
            notes[#notes + 1] = GREEN .. "inside now|r"
        end
        if #notes > 0 then
            text = text .. GRAY .. " (" .. table.concat(notes, "; ") .. ")|r"
        end
        return "  " .. text
    end

    function R5.LogLines()
        local now = Clock()
        local counts, warning, full = CapState()
        local lines = { GOLD .. "Instance log|r" }
        lines[#lines + 1] = "New dungeons entered: " .. counts .. "."
        if warning then
            lines[#lines + 1] = (full and ORANGE or YELLOW) .. warning:sub(1, 1):upper() .. warning:sub(2) .. ".|r"
        end
        lines[#lines + 1] = GRAY .. string.format("Forever's real cap isn't confirmed: %d an hour and %d a day are the"
            .. " settings (type: cap %d %d, or use the window's buttons). An entry counts until an hour (a day) after you"
            .. " last left it. Going back in within %d minutes counts as the same copy unless the creatures show another"
            .. " (type: reentry 30).|r", R5.Setting("hourCap"), R5.Setting("dayCap"), R5.Setting("hourCap"),
            R5.Setting("dayCap"), R5.Setting("reentryMinutes"))
        local runs = DB().runs
        if #runs == 0 then
            lines[#lines + 1] = "No runs yet. Each dungeon you enter shows here with its time, kills, XP, gold, deaths and loot."
            return lines
        end
        lines[#lines + 1] = GOLD .. "Your runs|r " .. GRAY .. "(newest first, every character)|r"
        local shown = 0
        for index = #runs, 1, -1 do
            local run = runs[index]
            if type(run) == "table" and shown < LOG_RUNS then
                shown = shown + 1
                lines[#lines + 1] = RunLine(run, now)
            end
        end
        if #runs > shown then
            lines[#lines + 1] = GRAY .. string.format("(%d older runs kept for the counts)", #runs - shown) .. "|r"
        end
        return lines
    end

    -- Group Finder ----------------------------------------------------------------------------------

    local dungeonOfActivity = {}
    local function ActivityDungeon(id)
        id = tonumber(Safe(id))
        if not id then
            return nil
        end
        if dungeonOfActivity[id] == nil then
            local found = false
            local info = ActivityInfo(id)
            for _, dungeon in ipairs(List()) do
                if (info and SameDungeon(dungeon, info.fullName)) or (not info and dungeon.activity == id) then
                    found = dungeon
                    break
                end
            end
            dungeonOfActivity[id] = found
        end
        return dungeonOfActivity[id] or nil
    end

    -- Reads the results of the search you just made. Never searches, applies or reads names or comments.
    function R5.ReadSearch()
        local lfg = C_LFGList
        if not (lfg and lfg.GetSearchResults and lfg.GetSearchResultInfo) then
            return
        end
        local ok, _, results = pcall(lfg.GetSearchResults)
        if not ok or type(results) ~= "table" then
            return
        end
        local snapshot = { at = Mono(), total = 0, other = 0, byDungeon = {} }
        for index = 1, math.min(#results, MAX_RESULTS) do
            local id = Safe(results[index])
            local okInfo, info = false, nil
            if type(id) == "number" then
                okInfo, info = pcall(lfg.GetSearchResultInfo, id)
            end
            if okInfo and type(info) == "table" and Safe(info.isDelisted) ~= true and Safe(info.hasSelf) ~= true then
                local dungeon
                local ids = Safe(info.activityIDs)
                for _, activity in ipairs(type(ids) == "table" and ids or {}) do
                    dungeon = ActivityDungeon(activity)
                    if dungeon then
                        break
                    end
                end
                dungeon = dungeon or ActivityDungeon(info.activityID)
                snapshot.total = snapshot.total + 1
                if dungeon then
                    local list = snapshot.byDungeon[dungeon] or {}
                    list[#list + 1] = { members = tonumber(Safe(info.numMembers)), age = tonumber(Safe(info.age)) }
                    snapshot.byDungeon[dungeon] = list
                else
                    snapshot.other = snapshot.other + 1
                end
            end
        end
        st.groups = snapshot
        Changed()
    end

    -- Dungeons with listings: { dungeon, groups, suits }, the ones for your level first.
    local function Listed()
        local level = MyLevel()
        local rows = {}
        for index, dungeon in ipairs(List()) do
            local groups = st.groups and st.groups.byDungeon[dungeon]
            if groups then
                rows[#rows + 1] = { dungeon = dungeon, groups = groups, suits = Suits(dungeon, level), index = index }
            end
        end
        table.sort(rows, function(a, b)
            if a.suits ~= b.suits then
                return a.suits
            end
            if #a.groups ~= #b.groups then
                return #a.groups > #b.groups
            end
            return a.index < b.index
        end)
        return rows, level
    end

    function R5.GroupLines()
        local lines = { GOLD .. "Group Finder listings that fit you|r" }
        local groups = st.groups
        if not groups then
            lines[#lines + 1] = "Search the game's Group Finder for dungeons yourself; the groups it lists are matched to"
                .. " these dungeons here. This page never searches, applies or signs you up."
            return lines
        end
        local age = Mono() - groups.at
        lines[#lines + 1] = GRAY .. string.format("From your search %s ago: %d group%s listed.", Minutes(age), groups.total,
            groups.total == 1 and "" or "s") .. (age > GROUPS_FRESH and " Search again for fresh listings." or "") .. "|r"
        local rows, level = Listed()
        local fitting, others = 0, 0
        for _, row in ipairs(rows) do
            if row.suits then
                fitting = fitting + 1
                local sizes = {}
                for _, group in ipairs(row.groups) do
                    if #sizes < 6 then
                        sizes[#sizes + 1] = group.members and (group.members .. "/5") or "?"
                    end
                end
                local text = string.format("  %s%s|r: %d group%s (%s)", GREEN, row.dungeon.name, #row.groups,
                    #row.groups == 1 and "" or "s", table.concat(sizes, ", "))
                local counts = QuestCounts(row.dungeon, level)
                local extras = {}
                if counts.log + counts.open > 0 then
                    extras[#extras + 1] = string.format("%d quest%s to do there", counts.log + counts.open,
                        counts.log + counts.open == 1 and "" or "s")
                end
                local wish = R5.WishText(row.dungeon)
                if wish ~= "" then
                    extras[#extras + 1] = "wish list" .. wish
                end
                if #extras > 0 then
                    text = text .. ". " .. table.concat(extras, ", ")
                end
                lines[#lines + 1] = text
            else
                others = others + #row.groups
            end
        end
        if fitting == 0 then
            lines[#lines + 1] = string.format("No listed group is for a dungeon that suits level %d.", level)
        end
        if others + groups.other > 0 then
            lines[#lines + 1] = GRAY .. string.format("Also listed: %d group%s for other dungeons or activities.",
                others + groups.other, others + groups.other == 1 and "" or "s") .. "|r"
        end
        return lines
    end

    -- Side panel ------------------------------------------------------------------------------------

    function R5.Status()
        local lines = {}
        local counts, warning, full = CapState()
        if warning and not Open() then
            lines[#lines + 1] = { text = "Dungeon entries: " .. counts .. (full and " (at the cap)" or ""), page = "Dungeons" }
        end
        local groups = st.groups
        if groups and Mono() - groups.at <= GROUPS_FRESH then
            local fitting = 0
            for _, row in ipairs((Listed())) do
                if row.suits then
                    fitting = fitting + #row.groups
                end
            end
            if fitting > 0 then
                lines[#lines + 1] = { text = string.format("Group Finder: %d group%s for dungeons that fit you", fitting,
                    fitting == 1 and "" or "s"), page = "Dungeons" }
            end
        end
        return lines
    end

    -- Window ------------------------------------------------------------------------------------------
    -- Our own frame (never a Blizzard one): Runs, Wish list (tick items to want) and Groups.

    local WIDTH, HEIGHT = 480, 460
    local VIEWS = { { key = "log", label = "Runs" }, { key = "wish", label = "Wish list" }, { key = "groups", label = "Groups" } }

    local function HubSaysOff()
        return type(ForeverHub_IsOff) == "function" and ForeverHub_IsOff("Dungeons") == true
    end

    local function Tip()
        st.tip = st.tip or CreateFrame("GameTooltip", "DungeonsTooltip", UIParent, "GameTooltipTemplate")
        return st.tip
    end

    -- The rows the Wish list view shows: a dungeon's loot, or (pick 0) your list.
    local function PickRows(pick)
        local rows = {}
        if pick == 0 then
            for _, entry in ipairs(WishedItems()) do
                rows[#rows + 1] = { id = entry.id, text = WishLine(entry) }
            end
            return rows
        end
        local dungeon = List()[pick]
        for _, item in ipairs(dungeon and dungeon.loot or {}) do
            local text = (item[2] or "?") .. GRAY .. " (" .. tostring(item[4] or "?") .. ")|r - " .. tostring(item[3] or "?")
            if item[1] and Have(item[1]) then
                text = text .. " " .. GREEN .. "(you have it)|r"
            end
            rows[#rows + 1] = { id = item[1], text = text }
        end
        return rows
    end

    local function DefaultPick()
        local current = CurrentDungeon()
        local level = MyLevel()
        for index, dungeon in ipairs(List()) do
            if dungeon == current then
                return index
            end
        end
        for index, dungeon in ipairs(List()) do
            if Suits(dungeon, level) and not dungeon.horde and #(dungeon.loot or {}) > 0 then
                return index
            end
        end
        return 0
    end

    function R5.Refresh()
        local w = st.window
        if not w then
            return
        end
        local wish = w.view == "wish"
        w.scroll:SetShown(not wish)
        st.picker:SetShown(wish)
        w.capBar:SetShown(w.view == "log")
        for _, tab in ipairs(w.tabs) do
            if tab.key == w.view then
                tab:LockHighlight()
            else
                tab:UnlockHighlight()
            end
        end
        if not wish then
            local lines = w.view == "groups" and R5.GroupLines() or R5.LogLines()
            w.text:SetText(table.concat(lines, "\n"))
            w.content:SetHeight(math.max((tonumber(Safe(w.text:GetStringHeight())) or 0) + 8, 1))
            w.capText:SetText(string.format("Cap: %d an hour, %d a day", R5.Setting("hourCap"), R5.Setting("dayCap")))
            for _, row in ipairs(w.rows) do
                row:Hide()
            end
            return
        end
        local count = #List()
        st.pick = st.pick or DefaultPick()
        if st.pick < 0 or st.pick > count then
            st.pick = 0
        end
        if st.pick == 0 then
            st.pickText:SetText(string.format("%sYour wish list|r (%d)", GOLD, WishCount()))
        else
            local dungeon = List()[st.pick]
            st.pickText:SetText(string.format("%s%d. %s|r%s", GOLD, st.pick, dungeon.name, R5.WishText(dungeon)))
        end
        local rows = PickRows(st.pick)
        for index, row in ipairs(w.rows) do
            local data = rows[index]
            if data and not (index == #w.rows and #rows > #w.rows) then
                row.id = data.id
                row.check:Show()
                row.check:SetChecked(R5.IsWished(data.id))
                row.label:SetText(data.text)
                row:Show()
            elseif data then
                row.id = nil
                row.check:Hide()
                row.label:SetText(GRAY .. string.format("+%d more on the hub's Dungeons page (wish)", #rows - index + 1) .. "|r")
                row:Show()
            elseif index == 1 then
                row.id = nil
                row.check:Hide()
                row.label:SetText(st.pick == 0 and "Nothing on your wish list yet: pick a dungeon with the arrows and tick items."
                    or "No notable loot listed for this dungeon.")
                row:Show()
            else
                row:Hide()
            end
        end
    end

    local function Button(parent, text, width, onClick)
        local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
        button:SetSize(width, 22)
        button:SetText(text)
        button:SetScript("OnClick", onClick)
        return button
    end

    local function BuildWindow()
        local w = CreateFrame("Frame", "DungeonsWindow", UIParent, "BackdropTemplate")
        st.window = w
        w:SetSize(WIDTH, HEIGHT)
        w:SetFrameStrata("HIGH")
        w:SetClampedToScreen(true)
        w:SetMovable(true)
        w:EnableMouse(true)
        w:RegisterForDrag("LeftButton")
        if w.SetBackdrop then
            w:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
                edgeSize = 14, insets = { left = 3, right = 3, top = 3, bottom = 3 } })
            w:SetBackdropColor(0.05, 0.05, 0.08, 0.92)
        end
        w:SetScript("OnDragStart", w.StartMoving)
        w:SetScript("OnDragStop", function(self)
            self:StopMovingOrSizing()
            local point, _, relativePoint, x, y = self:GetPoint()
            if point then
                DB().settings.position = { point, relativePoint, x, y }
            end
        end)
        local position = DB().settings.position
        if type(position) == "table" and position[1] then
            w:SetPoint(position[1], UIParent, position[2], position[3], position[4])
        else
            w:SetPoint("CENTER", UIParent, "CENTER", -240, 40)
        end
        w.view = "log"
        local title = w:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        title:SetPoint("TOPLEFT", w, "TOPLEFT", 12, -10)
        title:SetText("Dungeons")
        local close = CreateFrame("Button", nil, w, "UIPanelCloseButton")
        close:SetPoint("TOPRIGHT", w, "TOPRIGHT", -2, -2)

        w.tabs = {}
        for index, view in ipairs(VIEWS) do
            local tab = Button(w, view.label, 90, function()
                w.view = view.key
                R5.Refresh()
            end)
            tab:SetPoint("TOPLEFT", w, "TOPLEFT", 10 + (index - 1) * 94, -30)
            tab.key = view.key
            w.tabs[#w.tabs + 1] = tab
        end

        -- Runs and Groups: text in a scroll frame.
        w.scroll = CreateFrame("ScrollFrame", nil, w, "UIPanelScrollFrameTemplate")
        w.scroll:SetPoint("TOPLEFT", w, "TOPLEFT", 12, -60)
        w.scroll:SetPoint("BOTTOMRIGHT", w, "BOTTOMRIGHT", -32, 40)
        w.content = CreateFrame("Frame", nil, w.scroll)
        w.content:SetSize(WIDTH - 50, 10)
        w.scroll:SetScrollChild(w.content)
        w.text = w.content:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        w.text:SetPoint("TOPLEFT", w.content, "TOPLEFT", 0, 0)
        w.text:SetWidth(WIDTH - 54)
        w.text:SetJustifyH("LEFT")
        w.text:SetJustifyV("TOP")
        w.text:SetSpacing(2)

        -- Runs: the entry cap, a setting until Forever's real cap is known.
        w.capBar = CreateFrame("Frame", nil, w)
        w.capBar:SetPoint("BOTTOMLEFT", w, "BOTTOMLEFT", 10, 8)
        w.capBar:SetSize(WIDTH - 20, 24)
        w.capText = w.capBar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        w.capText:SetPoint("LEFT", w.capBar, "LEFT", 2, 0)
        local x = 190
        for _, spec in ipairs({ { "Hour -", "hourCap", -1 }, { "Hour +", "hourCap", 1 }, { "Day -", "dayCap", -1 }, { "Day +", "dayCap", 1 } }) do
            local button = Button(w.capBar, spec[1], 62, function()
                R5.SetSetting(spec[2], R5.Setting(spec[2]) + spec[3])
                R5.Refresh()
            end)
            button:SetPoint("LEFT", w.capBar, "LEFT", x, 0)
            x = x + 66
        end

        -- Wish list: a dungeon picker and a ticked row per item.
        st.picker = CreateFrame("Frame", nil, w)
        st.picker:SetPoint("TOPLEFT", w, "TOPLEFT", 10, -58)
        st.picker:SetSize(WIDTH - 20, 24)
        local prev = Button(st.picker, "<", 28, function()
            st.pick = (st.pick or 0) - 1
            if st.pick < 0 then
                st.pick = #List()
            end
            R5.Refresh()
        end)
        prev:SetPoint("LEFT", st.picker, "LEFT", 0, 0)
        local nextButton = Button(st.picker, ">", 28, function()
            st.pick = (st.pick or 0) + 1
            if st.pick > #List() then
                st.pick = 0
            end
            R5.Refresh()
        end)
        nextButton:SetPoint("LEFT", prev, "RIGHT", 4, 0)
        local mine = Button(st.picker, "My list", 70, function()
            st.pick = 0
            R5.Refresh()
        end)
        mine:SetPoint("LEFT", nextButton, "RIGHT", 4, 0)
        st.pickText = st.picker:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        st.pickText:SetPoint("LEFT", mine, "RIGHT", 8, 0)

        w.rows = {}
        for index = 1, WISH_ROWS do
            local row = CreateFrame("Frame", nil, w)
            row:SetSize(WIDTH - 24, 22)
            row:SetPoint("TOPLEFT", w, "TOPLEFT", 12, -86 - (index - 1) * 24)
            row:EnableMouse(true)
            row.check = CreateFrame("CheckButton", nil, row, "UICheckButtonTemplate")
            row.check:SetSize(22, 22)
            row.check:SetPoint("LEFT", row, "LEFT", 0, 0)
            row.check:SetScript("OnClick", function()
                local _, problem = R5.Toggle(row.id)
                if problem then
                    Print(problem)
                end
                R5.Refresh()
            end)
            row.label = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            row.label:SetPoint("LEFT", row.check, "RIGHT", 4, 0)
            row.label:SetWidth(WIDTH - 60)
            row.label:SetJustifyH("LEFT")
            row:SetScript("OnEnter", function(self)
                if not self.id then
                    return
                end
                local tip = Tip()
                tip:SetOwner(self, "ANCHOR_RIGHT")
                pcall(tip.SetItemByID, tip, self.id)
                tip:Show()
            end)
            row:SetScript("OnLeave", function()
                if st.tip then
                    st.tip:Hide()
                end
            end)
            row:Hide()
            w.rows[index] = row
        end

        w:SetScript("OnShow", R5.Refresh)
        -- Not added to UISpecialFrames (a Blizzard table): the close button and "window" close it.
        w:Hide()
    end

    -- Switched Off on the hub's Manage page: the window hides, and comes back when switched On.
    ForeverHubOnSwitch = ForeverHubOnSwitch or {}
    ForeverHubOnSwitch.Dungeons = function(off)
        local w = st.window
        if not w then
            return
        end
        if off then
            st.reopen = w:IsShown() and true or false
            w:Hide()
        elseif st.reopen then
            st.reopen = false
            w:Show()
            R5.Refresh()
        end
    end

    function R5.ToggleWindow(view)
        if not (UIParent and CreateFrame) or HubSaysOff() then
            return
        end
        if not st.window then
            BuildWindow()
        end
        local w = st.window
        if view then
            w.view = view
        end
        if w:IsShown() and not view then
            w:Hide()
            return
        end
        w:Show()
        R5.Refresh()
    end

    -- Hub page words ----------------------------------------------------------------------------------

    local function PrintLines(lines)
        for _, line in ipairs(lines) do
            Print(line)
        end
    end

    -- Handles the round-5 words of the Dungeons page; false for anything else.
    function R5.Page(want)
        if want == "log" or want == "runs" then
            PrintLines(R5.LogLines())
            return true
        elseif want == "wish" or want == "wishlist" or want == "wish list" then
            PrintLines(R5.WishLines())
            return true
        elseif want == "groups" or want == "group finder" then
            PrintLines(R5.GroupLines())
            return true
        elseif want == "window" then
            R5.ToggleWindow()
            return true
        end
        local hourCap, dayCap = want:match("^cap%s+(%d+)%s+(%d+)$")
        if hourCap then
            hourCap, dayCap = R5.SetSetting("hourCap", hourCap), R5.SetSetting("dayCap", dayCap)
            Print(string.format("Dungeon entry cap set to %d an hour and %d a day.", hourCap, dayCap))
            PrintLines(R5.LogLines())
            return true
        end
        local minutes = want:match("^reentry%s+(%d+)$")
        if minutes then
            Print(string.format("Going back in within %d minutes counts as the same copy.", R5.SetSetting("reentryMinutes", minutes)))
            return true
        end
        local which, number = want:match("^wish%s+(.-)%s+(%d+)$")
        if which then
            local matches = Find(which)
            local dungeon = #matches == 1 and List()[matches[1]]
            local item = dungeon and (dungeon.loot or {})[tonumber(number)]
            if not item then
                Print("Type wish, a dungeon's number or name, and the item's place in its loot list: wish 3 1")
                return true
            end
            local added, problem = R5.Toggle(item[1])
            if problem then
                Print(problem)
            else
                Print(string.format("%s %s your wish list.", item[2] or "?", added and "is on" or "is off"))
            end
            PrintLines(R5.WishLines())
            return true
        end
        return false
    end

    -- Events ------------------------------------------------------------------------------------------

    local OWN = { ZONE_CHANGED_NEW_AREA = true, CHAT_MSG_COMBAT_XP_GAIN = true, PLAYER_XP_UPDATE = true, PLAYER_MONEY = true,
        PLAYER_DEAD = true, LOOT_OPENED = true, LOOT_CLOSED = true, UPDATE_MOUSEOVER_UNIT = true, NAME_PLATE_UNIT_ADDED = true,
        LFG_LIST_SEARCH_RESULTS_RECEIVED = true, PLAYER_LOGOUT = true }
    R5.EVENTS = OWN

    local function ZoneSoon()
        if st.zonePending then
            return
        end
        st.zonePending = true
        if C_Timer and C_Timer.After then
            C_Timer.After(1, R5.CheckZone)
        else
            R5.CheckZone()
        end
    end

    -- Every event Dungeons gets passes here first; true when it was only ours.
    function R5.OnEvent(event, ...)
        if event == "PLAYER_ENTERING_WORLD" or event == "ZONE_CHANGED_NEW_AREA" then
            ZoneSoon()
        elseif event == "PLAYER_LOGIN" then
            Snapshot()
        elseif event == "PLAYER_TARGET_CHANGED" then
            R5.SeeGUID(Call(UnitGUID, "target"))
        elseif event == "UPDATE_MOUSEOVER_UNIT" then
            R5.SeeGUID(Call(UnitGUID, "mouseover"))
        elseif event == "NAME_PLATE_UNIT_ADDED" then
            local unit = Safe((...))
            if type(unit) == "string" then
                R5.SeeGUID(Call(UnitGUID, unit))
            end
        elseif event == "CHAT_MSG_COMBAT_XP_GAIN" then
            -- One per kill that gave XP; the message text is never read.
            local run = Open()
            if run then
                Add(run, "kills", 1)
            end
        elseif event == "PLAYER_XP_UPDATE" or event == "PLAYER_LEVEL_UP" then
            XPChanged()
        elseif event == "PLAYER_MONEY" then
            MoneyChanged()
        elseif event == "PLAYER_DEAD" then
            local run = Open()
            if run then
                Add(run, "deaths", 1)
            end
        elseif event == "LOOT_OPENED" then
            LootOpened()
        elseif event == "LOOT_CLOSED" then
            LootClosed()
        elseif event == "LFG_LIST_SEARCH_RESULTS_RECEIVED" then
            R5.ReadSearch()
        elseif event == "PLAYER_LOGOUT" then
            -- Logout or /reload inside: the visit is stamped, and logging back in within the re-entry
            -- window continues the same run.
            CloseVisit(Clock())
        end
        return OWN[event] == true
    end
end

-- Answers a later tooltip line: true, the dungeon and the boss when this character wants the item.
-- item: an item ID or an item link.
function Dungeons_IsWished(item)
    local id = tonumber(item) or (type(item) == "string" and tonumber(item:match("item:(%d+)")))
    if not id then
        return false
    end
    local ok, wished = pcall(R5.IsWished, id)
    if not (ok and wished) then
        return false
    end
    local source = R5.Source(id)
    return true, source and source.dungeon.name or nil, source and source.item[3] or nil
end

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("QUEST_LOG_UPDATE")
events:RegisterEvent("QUEST_TURNED_IN")
-- pcall: a client without one of these events must still load the addon.
pcall(events.RegisterEvent, events, "ENCOUNTER_END")
pcall(events.RegisterEvent, events, "BOSS_KILL")
pcall(events.RegisterEvent, events, "UNIT_DIED")
pcall(events.RegisterEvent, events, "PARTY_KILL")
pcall(events.RegisterEvent, events, "PLAYER_TARGET_CHANGED")
pcall(events.RegisterEvent, events, "PLAYER_ENTERING_WORLD")
-- Upgrade checks: an item the client loaded, new gear, a new level.
pcall(events.RegisterEvent, events, "ITEM_DATA_LOAD_RESULT")
pcall(events.RegisterEvent, events, "PLAYER_EQUIPMENT_CHANGED")
pcall(events.RegisterEvent, events, "PLAYER_LEVEL_UP")
-- ItemAdvisor's answers follow your talents too (its role), on these events (none is a CallbackEvent).
local TALENT_EVENTS = { TRAIT_CONFIG_UPDATED = true, PLAYER_TALENT_UPDATE = true, CHARACTER_POINTS_CHANGED = true }
for name in pairs(TALENT_EVENTS) do
    pcall(events.RegisterEvent, events, name)
end
-- Round 5: instance log, wish-list loot, Group Finder results after your own search (none is a CallbackEvent).
for name in pairs(R5.EVENTS) do
    pcall(events.RegisterEvent, events, name)
end
-- UnitLevel can still give the old level for about a second after a level-up (ItemAdvisor judges again
-- then too), and the event order between addons isn't fixed: answers asked for meanwhile are forgotten again.
local UPGRADE_SETTLE_SECONDS = 2
events:SetScript("OnEvent", function(_, event, ...)
    -- Round 5 first (it shares a few events); a fault there never stops the rest.
    local ok, own = pcall(R5.OnEvent, event, ...)
    if not ok then
        if geterrorhandler then
            geterrorhandler()(own)
        end
    elseif own then
        return
    end
    if event == "UNIT_DIED" then
        KillByGUID((...))
        return
    elseif event == "PARTY_KILL" then
        local _, targetGUID = ...
        KillByGUID(targetGUID)
        return
    elseif event == "PLAYER_TARGET_CHANGED" then
        LearnFromTarget()
        return
    elseif event == "PLAYER_ENTERING_WORLD" then
        LearnEntrance()
        return
    elseif event == "ITEM_DATA_LOAD_RESULT" then
        -- itemID, success.
        local id = Safe((...))
        if id and waitingItems[id] then
            waitingItems[id] = nil
            QueueItem(id)
        end
        return
    elseif event == "PLAYER_EQUIPMENT_CHANGED" or event == "PLAYER_LEVEL_UP" or TALENT_EVENTS[event] then
        -- Answers depend on what you wear, your level and your talents: ask again on the next look.
        upgradeOf = {}
        if event ~= "PLAYER_EQUIPMENT_CHANGED" and C_Timer and C_Timer.After then
            C_Timer.After(UPGRADE_SETTLE_SECONDS, function()
                upgradeOf = {}
            end)
        end
        return
    elseif event == "ENCOUNTER_END" then
        -- encounterID, encounterName, difficultyID, groupSize, success (1 on a kill).
        local _, encounterName, _, _, success = ...
        success = Safe(success)
        if success == 1 or success == true then
            RecordKill(encounterName)
        end
        return
    elseif event == "BOSS_KILL" then
        -- encounterID, encounterName.
        local _, encounterName = ...
        RecordKill(encounterName)
        return
    elseif event == "PLAYER_LOGIN" then
        -- Saved variables are read by now; pick up this character's kills on next use. The game's
        -- dungeon ranges are read again on next use too.
        charKills, gameRanges = nil, nil
        -- Entrance samples: a cheap ticker (one map read every 2 s), not an OnUpdate.
        if not entranceTicker and C_Timer and C_Timer.NewTicker then
            entranceTicker = C_Timer.NewTicker(ENTRANCE_SAMPLE, SampleSpot)
        end
    end
    statusDirty = true
end)

ForeverHubStatus = ForeverHubStatus or {}
ForeverHubStatus.Dungeons = function()
    if statusDirty then
        RefreshReady()
    end
    local lines = {}
    local first = readyQuests[1]
    if first then
        local more = #readyQuests > 1 and string.format(" (+%d more)", #readyQuests - 1) or ""
        lines[1] = { text = string.format("Dungeon quest ready: %s%s", first.title, more), page = "Dungeons" }
    end
    -- Near the entry cap, and Group Finder groups for your dungeons after a search.
    local ok, extra = pcall(R5.Status)
    if ok and type(extra) == "table" then
        for _, line in ipairs(extra) do
            lines[#lines + 1] = line
        end
    end
    return #lines > 0 and lines or nil
end
