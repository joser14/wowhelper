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
        UpgradeText(dungeon))
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
events:SetScript("OnEvent", function(_, event, ...)
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
    elseif event == "PLAYER_EQUIPMENT_CHANGED" or event == "PLAYER_LEVEL_UP" then
        -- Answers depend on what you wear and your level: ask again on the next look.
        upgradeOf = {}
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
    local first = readyQuests[1]
    if not first then
        return nil
    end
    local more = #readyQuests > 1 and string.format(" (+%d more)", #readyQuests - 1) or ""
    return { { text = string.format("Dungeon quest ready: %s%s", first.title, more), page = "Dungeons" } }
end
