-- A step-by-step leveling guide worked out live from your quest log and the map, with an arrow.
-- It never accepts, completes or turns in anything: you do the clicking.

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

-- Tuning constants, in one table so they count as a single local (the file is near Lua's 200-local limit).
local K = {
    WIDTH = 330,
    HEADER_HEIGHT = 22,
    ARROW_SIZE = 44,
    MAX_NEXT = 3,
    ARRIVED_YARDS = 12,
    KEEP_RATIO = 1.3, -- the current step stays until another is this much closer, so it doesn't flicker
    TURNIN_BIAS = 0.7, -- a ready turn-in is worth going a bit further for: it's XP now
    PICKUP_BIAS = 0.4, -- quest givers nearby come before heading out; a turn-in at the same
    -- spot still comes first (it can unlock the next pick-up)
    TRIVIAL_PENALTY = 400, -- gray quests come last unless they're right there
    HARD_LEVELS = 5, -- red quests are left out until you're closer to their level
    ARROW_SECONDS = 0.05,
    ROUTE_SECONDS = 2,
    AHEAD_RADIANS = 0.35,
    XP_WEIGHT = 2, -- a quest worth a fifth of a level counts as 1.4 times closer
    NO_SCALE_UNITS = 1000, -- without the map's size in yards, distances are only compared, never shown
    OUTLEVELED = 4, -- route steps this far below you count as done, so a route can start midway
    ROUTE_WINDOW = 10, -- how many upcoming route steps may be reordered to save walking
    ZONE_MAP_TYPE = 3, -- Enum.UIMapType.Zone: caves and buildings below this report up to their zone
    NEAR_START_YARDS = 150, -- a move before the next pick-up is behind you when you stand this close to it
}
-- Helpers shared between the `do` blocks below (one table, one local) and per-rebuild caches. The arithmetic
-- lives in Planner.lua (LevelGuidePlanner).
local X = { places = {}, arrow = {}, clock = 0 }

local KINDS = {
    turnin = { label = "Turn in", color = "|cff33ff33" },
    work = { label = "Do", color = "|cffffd100" },
    pickup = { label = "Pick up", color = "|cff66ccff" },
    travel = { label = "Go to", color = "|cffff9933" },
    level = { label = "Reach level", color = "|cffff8040" },  -- the route waits on your level (LevelStep)
    -- Utility steps (Routes.lua Home/FP/Item/Train/XP): done by watching the game, never by clicking.
    home = { label = "Set hearth", color = "|cffcc99ff" },
    flight = { label = "Flight path", color = "|cffcc99ff" },
    item = { label = "Get", color = "|cffffd100" },
    train = { label = "Train", color = "|cffcc99ff" },
    grind = { label = "Grind", color = "|cffff8040" },
    -- Side steps (Routes.lua Buy/Vendor/Bags/Trainer/Keep), mostly shown beside the current step.
    buy = { label = "Buy", color = "|cffffd100" },
    vendor = { label = "Visit", color = "|cffffd100" },
    bags = { label = "Bags", color = "|cffffd100" },
    trainer = { label = "Train", color = "|cffcc99ff" },
    keep = { label = "Keep", color = "|cff999999" },
    hearth = { label = "Hearth to", color = "|cffcc99ff" },
}
-- What LevelGuide_UpcomingStops calls each kind (for the MapPins helper).
local STOP_KINDS = { pickup = "accept", work = "do", turnin = "turnin", travel = "go", level = "level",
    home = "hearth", flight = "flight", item = "item", train = "train", grind = "xp",
    buy = "item", vendor = "item", bags = "item", trainer = "train", keep = "item", hearth = "go" }
local MAX_SIDE = 5          -- rows for side steps ("On the way" first, then "For later")
local sideSteps = {}        -- from the last rebuild: shown steps with .side = "sticky" or "later"
local merchantNpc           -- the NPC ID of the merchant window open now (MERCHANT_SHOW)
local MAX_STOPS = 7
-- Server lag: the log can lag a moment behind an accept, and a turned-in quest can linger in it, so for
-- this long the guide trusts the event over the log instead of flickering back to the old step.
local ACCEPT_GRACE, TURNIN_GRACE = 2, 5
local recentAccepts, recentTurnins = {}, {}  -- quest ID or title -> GetTime() of the event
local FLIGHT_NEAR_YARDS = 60   -- "new flight path" message counts for a route flight step this close
local CHORES = { "TrainerNotes", "TalentNudge", "DurabilityWatch", "BagCheck" }
local COLOR_DIM = "|cff999999"

local atan2 = math.atan2 or math.atan
local db, frame, arrow, yardsText, currentRow, detailText, alsoText, collapseButton, headerText
local nextRows = {}
local steps = {}
local scales = {}
local currentKey, requestedMap
local charData
local titlesByID = {}
local activeRoute
local lastByTitle, lastZoneMap  -- from the last rebuild, for the route list window and the focus step
local focusKey                  -- a route step picked in the route list: the arrow points at it until it's done
local frontiers = {}
local turnedCache = {}
local zoneOffers = {}  -- per rebuild: what each zone's map shows as available
local dirty = true
local DIRTY_SECONDS = 0.1   -- a burst of quest events within this long rebuilds the route once
local sinceRoute, sinceArrow = DIRTY_SECONDS, 0

local function Safe(value)
    if issecretvalue and issecretvalue(value) then
        return nil
    end
    return value
end

local function Now()
    return GetTime and GetTime() or 0
end

-- Whether the written routes and plan are for your faction (Routes.lua `faction`). When the game
-- doesn't say, they are used as before.
local function RoutesForYou()
    local want = LevelGuideRoutes and LevelGuideRoutes.faction
    local mine = want and UnitFactionGroup and Safe((UnitFactionGroup("player")))
    return not (type(mine) == "string" and mine ~= want)
end

-- The plan entries that apply to you: race-only entries (Routes.lua PLAN `race`) for your race, then the rest.
local function PlanEntries()
    if not RoutesForYou() then
        return {}
    end
    local race = UnitRace and Safe(select(2, UnitRace("player")))
    local list = {}
    for _, entry in ipairs(LevelGuideRoutes and LevelGuideRoutes.plan or {}) do
        if not entry.race or entry.race == race then
            list[#list + 1] = entry
        end
    end
    return list
end

-- Whether an accept/turn-in event for this quest ID (or title) came in the last few seconds.
local function Recent(list, key, seconds)
    local at = key ~= nil and GetTime and list[key]
    return at and Now() - at < seconds or false
end

local function NpcKey(npc)
    return npc and (npc:match("^%s*([^,(]-)%s*[,(]") or npc:match("^%s*(.-)%s*$")) or nil
end

-- The NPC ID inside a creature GUID ("Creature-0-<server>-<instance>-<zone>-<npcID>-<spawn>").
local function NpcIDOf(guid)
    local id = type(guid) == "string" and guid:match("^%a+%-%d+%-%d+%-%d+%-%d+%-(%d+)%-")
    return id and tonumber(id) or nil
end

local function StepKey(step)
    return step and (step.routeKey or (step.kind .. ":" .. tostring(step.id or step.zone))) or nil
end

-- How many yards one whole map width and height cover, from the map's own corners.
local function MapScale(mapID)
    -- A failed read (hidden in combat, map not loaded yet) is tried again after a while, not kept.
    local cached = scales[mapID]
    if type(cached) == "table" then
        return cached
    elseif type(cached) == "number" and Now() - cached < 10 then
        return nil
    end
    local scale = false
    if C_Map.GetWorldPosFromMapPos and CreateVector2D then
        local _, origin = C_Map.GetWorldPosFromMapPos(mapID, CreateVector2D(0, 0))
        local _, east = C_Map.GetWorldPosFromMapPos(mapID, CreateVector2D(1, 0))
        local _, south = C_Map.GetWorldPosFromMapPos(mapID, CreateVector2D(0, 1))
        if origin and east and south then
            local ox, oy = origin:GetXY()
            local ex, ey = east:GetXY()
            local sx, sy = south:GetXY()
            ox, oy, ex, ey, sx, sy = Safe(ox), Safe(oy), Safe(ex), Safe(ey), Safe(sx), Safe(sy)
            if ox and oy and ex and ey and sx and sy then
                local width = math.sqrt((ex - ox) ^ 2 + (ey - oy) ^ 2)
                local height = math.sqrt((sx - ox) ^ 2 + (sy - oy) ^ 2)
                if width > 0 and height > 0 then
                    scale = { width, height }
                end
            end
        end
    end
    scales[mapID] = scale or Now()
    return scale or nil
end

-- Yards east and south from one map point to another, and whether those are real yards.
local function Offset(mapID, fromX, fromY, toX, toY)
    local scale = MapScale(mapID)
    if scale then
        return (toX - fromX) * scale[1], (toY - fromY) * scale[2], true
    end
    return (toX - fromX) * K.NO_SCALE_UNITS, (toY - fromY) * K.NO_SCALE_UNITS, false
end

local function Distance(mapID, fromX, fromY, toX, toY)
    local east, south, isYards = Offset(mapID, fromX, fromY, toX, toY)
    return math.sqrt(east * east + south * south), isYards
end

local function PlayerPosition()
    local mapID = C_Map and C_Map.GetBestMapForUnit and Safe(C_Map.GetBestMapForUnit("player"))
    if not mapID then
        return nil
    end
    for _ = 1, 4 do
        local info = C_Map.GetMapInfo and C_Map.GetMapInfo(mapID)
        local mapType, parent = info and Safe(info.mapType), info and Safe(info.parentMapID)
        if not (mapType and mapType > K.ZONE_MAP_TYPE and parent and parent > 0) then
            break
        end
        mapID = parent
    end
    local position = C_Map.GetPlayerMapPosition and C_Map.GetPlayerMapPosition(mapID, "player")
    if not position then
        return mapID
    end
    local x, y = position:GetXY()
    return mapID, Safe(x), Safe(y)
end

-- Moving a point from one map onto another through world positions. A map's "basis" is where its corners
-- lie in the world: its top-left, and how far one map width east and one map height south go. Solving
-- against that works whatever the world axes are, and gives numbers outside 0-1 for a point beyond the
-- map's edge (Darnassus is its own zone on Forever's Classic maps, beside Teldrassil, not inside it).
local Project, FindMap
do -- (a block, so its helpers don't count toward the file's 200-local limit)
local bases = {}
local function WorldOf(mapID, x, y)
    if not (C_Map and C_Map.GetWorldPosFromMapPos and CreateVector2D) then
        return nil
    end
    local continent, world = C_Map.GetWorldPosFromMapPos(mapID, CreateVector2D(x, y))
    continent = Safe(continent)
    if not (continent and world and world.GetXY) then
        return nil
    end
    local wx, wy = world:GetXY()
    wx, wy = Safe(wx), Safe(wy)
    if wx and wy then
        return continent, wx, wy
    end
end

local function Basis(mapID)
    -- Failures are tried again after a while (see MapScale).
    local cached = bases[mapID]
    if cached == nil or (type(cached) == "number" and Now() - cached >= 10) then
        local basis = false
        local continent, ox, oy = WorldOf(mapID, 0, 0)
        local _, ex, ey = WorldOf(mapID, 1, 0)
        local _, sx, sy = WorldOf(mapID, 0, 1)
        if continent and ex and sx then
            local b = { continent = continent, ox = ox, oy = oy, ex = ex - ox, ey = ey - oy, sx = sx - ox, sy = sy - oy }
            b.det = b.ex * b.sy - b.sx * b.ey
            -- Zero-size maps (Zephras Isle and other instanced areas report no world rectangle) can't be used.
            if math.abs(b.det) > 1e-9 then
                basis = b
            end
        end
        bases[mapID] = basis or Now()
    end
    return type(bases[mapID]) == "table" and bases[mapID] or nil
end

-- x, y (0-1) on fromMap as a position on toMap, or nil (other continent, no world data).
function Project(fromMap, x, y, toMap)
    if not (fromMap and toMap and x and y) then
        return nil
    end
    if fromMap == toMap then
        return x, y
    end
    local to = Basis(toMap)
    local continent, wx, wy = WorldOf(fromMap, x, y)
    if not (to and continent and continent == to.continent) then
        return nil
    end
    local dx, dy = wx - to.ox, wy - to.oy
    return (dx * to.sy - to.sx * dy) / to.det, (to.ex * dy - dx * to.ey) / to.det
end

-- A zone or city map's ID by its name, from the continent you're on (only hits are remembered: the map
-- list can be empty for a moment after a load).
local byName = {}
function FindMap(name)
    if not name then
        return nil
    end
    if byName[name] then
        return byName[name]
    end
    local mapID = C_Map and C_Map.GetBestMapForUnit and Safe(C_Map.GetBestMapForUnit("player"))
    for _ = 1, 6 do
        local info = mapID and C_Map.GetMapInfo and C_Map.GetMapInfo(mapID)
        if not info then
            break
        end
        if Safe(info.name) == name then
            byName[name] = mapID
            return mapID
        end
        local parent = Safe(info.parentMapID)
        -- The continent (or whatever is at the top) lists every zone and city under it.
        if Safe(info.mapType) == 2 or not parent or parent == 0 then
            for _, child in ipairs(C_Map.GetMapChildrenInfo and C_Map.GetMapChildrenInfo(mapID, nil, true) or {}) do
                if Safe(child.name) == name and Safe(child.mapID) then
                    byName[name] = Safe(child.mapID)
                    return byName[name]
                end
            end
            break
        end
        mapID = parent
    end
end
end -- map projection

local function PositionOn(mapID)
    local position = C_Map and C_Map.GetPlayerMapPosition and C_Map.GetPlayerMapPosition(mapID, "player")
    if position then
        local x, y = position:GetXY()
        x, y = Safe(x), Safe(y)
        if x and y then
            return x, y
        end
    end
    -- Not on that map (e.g. in Darnassus while the route is Teldrassil's): where you'd be on it.
    local best = C_Map and C_Map.GetBestMapForUnit and Safe(C_Map.GetBestMapForUnit("player"))
    if not best or best == mapID then
        return nil
    end
    local here = C_Map.GetPlayerMapPosition and C_Map.GetPlayerMapPosition(best, "player")
    if not here then
        return nil
    end
    local x, y = here:GetXY()
    return Project(best, Safe(x), Safe(y), mapID)
end

local function ZoneName(mapID)
    local info = C_Map.GetMapInfo and C_Map.GetMapInfo(mapID)
    return info and Safe(info.name) or "another zone"
end

local function FirstUnfinished(questID)
    for _, objective in ipairs(C_QuestLog.GetQuestObjectives(questID) or {}) do
        local text = Safe(objective.text)
        if text and text ~= "" and not Safe(objective.finished) then
            return text
        end
    end
end

local function QuestItemName(logIndex)
    if not GetQuestLogSpecialItemInfo then
        return nil
    end
    local link = Safe((GetQuestLogSpecialItemInfo(logIndex)))
    return link and link:match("%[(.-)%]")
end

local function RewardXP(questID)
    return GetQuestLogRewardXP and Safe(GetQuestLogRewardXP(questID)) or 0
end

-- Timed quests (deliveries, escorts): when the clock runs out the quest fails, so the guide puts a
-- running one first, shows the time left and plays a warning when it starts and with a minute left.
local COLOR_ALERT = "|cffff3333"
local LOW_SECONDS = 60
local timedWarned, lowWarned = {}, {}

local function TimerEnds(questID)
    if not (C_QuestLog.GetTimeAllowed and GetTime) then
        return nil
    end
    local total, elapsed = C_QuestLog.GetTimeAllowed(questID)
    total, elapsed = Safe(total), Safe(elapsed)
    if total and elapsed and total > 0 and elapsed < total then
        return GetTime() + total - elapsed
    end
end

local function TimeLeftText(ends)
    local seconds = math.max(math.floor(ends - GetTime()), 0)
    return string.format("%s%d:%02d left|r", COLOR_ALERT, math.floor(seconds / 60), seconds % 60)
end

local function Warn()
    if PlaySound and SOUNDKIT and SOUNDKIT.RAID_WARNING then
        PlaySound(SOUNDKIT.RAID_WARNING, "Master")
    end
end

local function MaxXP()
    local maxXP = Safe(UnitXPMax("player"))
    return maxXP and maxXP > 0 and maxXP or nil
end

local function QuestDetail(step, logIndex)
    if step.kind == "turnin" then
        local text = GetQuestLogCompletionText and Safe(GetQuestLogCompletionText(logIndex))
        if not (text and text ~= "") and C_QuestLog.GetNextWaypointText then
            text = Safe(C_QuestLog.GetNextWaypointText(step.id))
        end
        return text or "Ready to turn in"
    end
    local detail = FirstUnfinished(step.id)
    local item = QuestItemName(logIndex)
    if item then
        detail = (detail and (detail .. ". ") or "") .. "Use " .. item
    end
    return detail
end

-- Where each of your quests is on this map: its objective area, or its turn-in once it's done.
local function MapPoints(mapID)
    local points = {}
    for _, info in ipairs((C_QuestLog.GetQuestsOnMap and C_QuestLog.GetQuestsOnMap(mapID)) or {}) do
        local id, x, y = Safe(info.questID), Safe(info.x), Safe(info.y)
        if id and x and y then
            points[id] = { x = x, y = y }
        end
    end
    return points
end

local function ReadQuests(mapID)
    local here, away, unplaced, later = {}, {}, {}, {}
    local points = mapID and MapPoints(mapID) or {}
    local level = Safe(UnitLevel("player"))
    for index = 1, Safe(C_QuestLog.GetNumQuestLogEntries()) or 0 do
        local info = C_QuestLog.GetInfo(index)
        local id = info and Safe(info.questID)
        -- A quest turned in a moment ago can still be listed; it isn't shown as a turn-in again.
        if id and not Safe(info.isHeader) and not Safe(info.isHidden) and not Safe(info.isTask) and not db.skipped[id]
            and not Recent(recentTurnins, id, TURNIN_GRACE) then
            local questLevel = Safe(info.difficultyLevel) or Safe(info.level)
            local ready = (Safe(C_QuestLog.IsComplete(id)) or Safe(C_QuestLog.ReadyForTurnIn(id))) and true or false
            local failed = C_QuestLog.IsFailed and Safe(C_QuestLog.IsFailed(id))
            local tooHard = not ready and level and questLevel and questLevel - level >= K.HARD_LEVELS
            if tooHard then
                later[#later + 1] = questLevel
            end
            if not failed and not tooHard then
                local step = {
                    id = id, kind = ready and "turnin" or "work", title = Safe(info.title) or "A quest",
                    trivial = not ready and Safe(C_QuestLog.IsQuestTrivial(id)) or false,
                    xp = RewardXP(id), group = Safe(info.suggestedGroup) or 0,
                }
                step.detail = QuestDetail(step, index)
                local point = points[id]
                local waypointMap, waypointX, waypointY
                if not point and C_QuestLog.GetNextWaypoint then
                    waypointMap, waypointX, waypointY = C_QuestLog.GetNextWaypoint(id)
                    waypointMap, waypointX, waypointY = Safe(waypointMap), Safe(waypointX), Safe(waypointY)
                end
                if point then
                    step.mapID, step.x, step.y = mapID, point.x, point.y
                    here[#here + 1] = step
                elseif waypointMap and waypointMap == mapID and waypointX and waypointY then
                    step.mapID, step.x, step.y = mapID, waypointX, waypointY
                    here[#here + 1] = step
                elseif waypointMap then
                    local entry = { step = step, zone = ZoneName(waypointMap), mapID = waypointMap, x = waypointX, y = waypointY }
                    -- Where it is, for the travel planner (X.ApplyTravel), unless the game gives its own leg.
                    if waypointX and waypointY then
                        entry.goalMap, entry.goalX, entry.goalY = waypointMap, waypointX * 100, waypointY * 100
                    end
                    -- The game's next leg on the map you're on (the boat, portal or zone exit), when it knows it.
                    if mapID and C_QuestLog.GetNextWaypointForMap then
                        local legX, legY = C_QuestLog.GetNextWaypointForMap(id, mapID)
                        legX, legY = Safe(legX), Safe(legY)
                        if legX and legY then
                            entry.mapID, entry.x, entry.y = mapID, legX, legY
                            entry.goalMap = nil
                        end
                    end
                    away[#away + 1] = entry
                else
                    unplaced[#unplaced + 1] = step
                end
            end
        end
    end
    return here, away, unplaced, later
end

-- The "!" quests the game shows on your map that you haven't picked up.
local function ReadOffers(mapID)
    local offers = {}
    if not (mapID and C_QuestLine and C_QuestLine.GetAvailableQuestLines) then
        return offers
    end
    -- Asked once per map until you change zone (a set: two maps asked in turn would ask forever).
    if not (requestedMap and requestedMap[mapID]) and C_QuestLine.RequestQuestLinesForMap then
        requestedMap = requestedMap or {}
        requestedMap[mapID] = true
        C_QuestLine.RequestQuestLinesForMap(mapID)
    end
    for _, info in ipairs(C_QuestLine.GetAvailableQuestLines(mapID) or {}) do
        local id, name, x, y = Safe(info.questID), Safe(info.questName), Safe(info.x), Safe(info.y)
        local startMap = Safe(info.startMapID)
        -- The map's "!" can outlive an accept by a moment; it isn't offered again.
        if id and name and x and y and not Safe(info.isHidden) and not Safe(info.inProgress) and not db.skipped[id]
            and not Recent(recentAccepts, id, ACCEPT_GRACE)
            and (not startMap or startMap == 0 or startMap == mapID) then
            offers[#offers + 1] = { id = id, kind = "pickup", title = name, mapID = mapID, x = x, y = y }
        end
    end
    return offers
end

local function Cost(step, mapID, fromX, fromY)
    local cost = Distance(mapID, fromX, fromY, step.x, step.y)
    if step.kind == "turnin" then
        cost = cost * K.TURNIN_BIAS
    elseif step.kind == "pickup" then
        -- Picking a quest up takes seconds and gives you more to do on the way, so sweep the hub first.
        cost = cost * K.PICKUP_BIAS
    end
    local maxXP = MaxXP()
    if step.xp and step.xp > 0 and maxXP then
        cost = cost / (1 + K.XP_WEIGHT * step.xp / maxXP)
    end
    if step.trivial then
        cost = cost + K.TRIVIAL_PENALTY
    end
    return cost
end

-- Nearest first, then nearest to that, and so on: a short route through what's around you.
local function Route(candidates, mapID, playerX, playerY)
    local route, remaining = {}, {}
    for _, step in ipairs(candidates) do
        remaining[#remaining + 1] = step
    end
    if not (playerX and playerY) then
        table.sort(remaining, function(a, b)
            if (a.kind == "turnin") ~= (b.kind == "turnin") then
                return a.kind == "turnin"
            end
            return a.id < b.id
        end)
        return remaining
    end
    -- A step with no point on this map (a move written on another zone's map, Routes.lua On()) can't be
    -- measured: it keeps its place in front, as written.
    local placed = {}
    for _, step in ipairs(remaining) do
        if step.x and step.y then
            placed[#placed + 1] = step
        else
            route[#route + 1] = step
        end
    end
    remaining = placed
    local unplaced = #route
    local fromX, fromY = playerX, playerY
    while #remaining > 0 do
        local bestIndex, bestCost
        for index, step in ipairs(remaining) do
            local cost = Cost(step, mapID, fromX, fromY)
            if not bestCost or cost < bestCost then
                bestIndex, bestCost = index, cost
            end
        end
        -- Near-ties on distance (within 10%) go to the most XP per second (X.XPPerSecond).
        local bestRate = X.XPPerSecond(remaining[bestIndex], mapID, fromX, fromY)
        for index, step in ipairs(remaining) do
            if index ~= bestIndex and Cost(step, mapID, fromX, fromY) <= bestCost * 1.1 then
                local rate = X.XPPerSecond(step, mapID, fromX, fromY)
                if rate > bestRate then
                    bestIndex, bestRate = index, rate
                end
            end
        end
        if #route == unplaced and currentKey then
            local best = remaining[bestIndex]
            for index, step in ipairs(remaining) do
                if StepKey(step) == currentKey and (Cost(step, mapID, fromX, fromY) <= bestCost * K.KEEP_RATIO
                    or X.HoldTarget(step, best, mapID, fromX, fromY)) then
                    bestIndex = index
                end
            end
        end
        local step = table.remove(remaining, bestIndex)
        route[#route + 1] = step
        fromX, fromY = step.x, step.y
    end
    return route
end

local function TravelSteps(away)
    local zones, order = {}, {}
    for _, entry in ipairs(away) do
        if not zones[entry.zone] then
            zones[entry.zone] = { kind = "travel", zone = entry.zone, title = entry.zone, count = 0 }
            order[#order + 1] = zones[entry.zone]
        end
        local zone = zones[entry.zone]
        zone.count = zone.count + 1
        zone.firstQuest = zone.firstQuest or entry.step.id
        zone.detail = string.format("%d quest(s) there", zone.count)
        -- The game's own next waypoint for the quest there: the arrow points at it (from across the zone
        -- border too, through world positions).
        if not zone.x and entry.mapID and entry.x and entry.y then
            zone.mapID, zone.x, zone.y = entry.mapID, entry.x, entry.y
        end
        if not zone.goalMap and entry.goalMap then
            zone.goalMap, zone.goalX, zone.goalY = entry.goalMap, entry.goalX, entry.goalY
        end
    end
    table.sort(order, function(a, b)
        return a.count > b.count
    end)
    return order
end

-- Hand-written routes (Routes.lua). Progress is read from your quest log, plus a count of what this
-- character has turned in, kept by title since several quests in a chain share one.
local ROUTE_KINDS = { accept = "pickup", ["do"] = "work", turnin = "turnin", go = "travel",
    zone = "travel", home = "home", fp = "flight", item = "item", train = "train", xp = "grind",
    buy = "buy", vendor = "vendor", bags = "bags", trainer = "trainer", keep = "keep", hearth = "hearth" }
-- Steps with no quest: done by watching the game (Routes.lua G/Zone/Home/FP/Item/Train/XP and the
-- side kinds Buy/Vendor/Bags/Trainer/Keep).
local UTILITY = { go = true, zone = true, home = true, fp = true, item = true, train = true, xp = true,
    buy = true, vendor = true, bags = true, trainer = true, keep = true, hearth = true }
-- Moves the route wants made in order: what follows waits behind them (an XP gate too).
local BARRIER = { go = true, zone = true, xp = true, hearth = true }

local function LogByTitle()
    local byTitle = {}
    frontiers = {}
    X.places = {}
    zoneOffers = {}
    turnedCache = {}
    local byID = {}
    for index = 1, Safe(C_QuestLog.GetNumQuestLogEntries()) or 0 do
        local info = C_QuestLog.GetInfo(index)
        local id, title = info and Safe(info.questID), info and Safe(info.title)
        if id and title and not Safe(info.isHeader) and not Safe(info.isHidden) then
            titlesByID[id] = title
            byTitle[title] = {
                id = id, logIndex = index,
                ready = (Safe(C_QuestLog.IsComplete(id)) or Safe(C_QuestLog.ReadyForTurnIn(id))) and true or false,
            }
            byID[id] = byTitle[title]
        end
    end
    -- Quest IDs say which part of a chain you hold, and find it even when Forever's title differs.
    local data = LevelGuideQuestIDs
    for title, ids in pairs(data and data.ids or {}) do
        for position, id in ipairs(ids) do
            local entry = byID[id]
            if entry then
                entry.part = entry.part or position
                byTitle[title] = byTitle[title] or entry
            end
        end
    end
    return byTitle
end

-- Cities that belong to a zone's route but are their own zone on Forever's (Classic) maps, beside it
-- under the continent: standing in one counts as being in the zone.
local ZONE_PARTS = {
    ["Teldrassil"] = { ["Darnassus"] = true },
    ["Dun Morogh"] = { ["Ironforge"] = true },
    ["Elwynn Forest"] = { ["Stormwind City"] = true },
}

-- The map you're on, or one it sits in, with this name; nil when you're not there.
local function MapNamed(zoneName)
    local mapID = C_Map and C_Map.GetBestMapForUnit and Safe(C_Map.GetBestMapForUnit("player"))
    local parts = ZONE_PARTS[zoneName]
    for _ = 1, 6 do
        local info = mapID and C_Map.GetMapInfo and C_Map.GetMapInfo(mapID)
        if not info then
            return nil
        end
        local name = Safe(info.name)
        if name == zoneName then
            return mapID
        end
        if parts and name and parts[name] then
            return nil, true
        end
        mapID = Safe(info.parentMapID)
        if not mapID or mapID == 0 then
            return nil
        end
    end
end

-- The zone's map while you're in it, in a sub-map of it (town, cave), or in a city that belongs to it.
local function ZoneMap(zoneName)
    local mapID, inPart = MapNamed(zoneName)
    if mapID then
        return mapID
    end
    if inPart then
        return FindMap(zoneName)
    end
end

-- Saved skips, visits and reached points are keyed by what a step is (zone, type, quest or text, part,
-- the person or objective), not by its position, so adding a step to Routes.lua no longer moves every
-- saved skip after it onto the wrong step. A step written twice the same way gets "#2", "#3" by
-- occurrence; a step may also carry its own key (step.key).
local routeKeys = setmetatable({}, { __mode = "k" })

local function BaseKey(zone, step)
    if step.key then
        return zone .. "|" .. step.key
    end
    local who = NpcKey(step.npc) or ""
    if step.t == "do" then
        local obj = step.obj
        who = obj and ("obj" .. (type(obj) == "table" and table.concat(obj, ",") or tostring(obj))) or ""
    elseif step.t == "go" or step.t == "zone" or step.t == "xp" then
        who = ""
    end
    return table.concat({ zone, step.t or "?", tostring(step.q or step.text or ""), tostring(step.part or ""), who }, "|")
end

local function RouteKeys(route)
    local steps_ = route.steps
    local keys = routeKeys[route]
    -- Rebuilt if the steps were replaced (tests do; the game never edits a route while running).
    if not (keys and keys.n == #steps_ and keys.first == steps_[1] and keys.last == steps_[#steps_]) then
        keys = { n = #steps_, first = steps_[1], last = steps_[#steps_] }
        local seen = {}
        -- A leg with its own key (Routes.lua Leg(), e.g. the Night Elf Loch Modan trip) keeps its saved
        -- skips apart from the zone's own route; legs without one share the zone's keys.
        for index, step in ipairs(steps_) do
            local base = BaseKey(route.key or route.zone, step)
            seen[base] = (seen[base] or 0) + 1
            keys[index] = seen[base] > 1 and (base .. "#" .. seen[base]) or base
        end
        routeKeys[route] = keys
    end
    return keys
end

local function RouteKey(route, index)
    return RouteKeys(route)[index]
end

-- Saved data from before stable keys used "Zone#index". Each old key is moved to the step that sat at
-- that index then: the route's steps minus those added since (step.since, Routes.lua New()). Keys that
-- point past the end are dropped. Only old-style keys are touched, so running it again does nothing.
local function MigrateKeys(set)
    if type(set) ~= "table" then
        return
    end
    local old
    for key, value in pairs(set) do
        if type(key) == "string" and key:match("^[^|]+#%d+$") then
            old = old or {}
            old[key] = value
        end
    end
    if not old then
        return
    end
    -- A zone split into legs (Darkshore before and after the Loch Modan trip) was one route then: its
    -- legs without a key of their own, in chain order, are that route again.
    local byZone = {}
    for _, chain in pairs(LevelGuideRoutes and LevelGuideRoutes.chains or {}) do
        local here = {}
        for _, route in ipairs(chain) do
            if not route.key and not byZone[route.zone] then
                local keys, list = RouteKeys(route), here[route.zone] or {}
                for index, step in ipairs(route.steps) do
                    if not step.since then
                        list[#list + 1] = keys[index]
                    end
                end
                here[route.zone] = list
            end
        end
        for zone, list in pairs(here) do
            byZone[zone] = list
        end
    end
    for key, value in pairs(old) do
        set[key] = nil
        local zone, index = key:match("^([^|]+)#(%d+)$")
        local newKey = byZone[zone] and byZone[zone][tonumber(index)]
        if newKey and set[newKey] == nil then
            set[newKey] = value
        end
    end
end

local function MigrateCharacter(data)
    MigrateKeys(data.skips)
    MigrateKeys(data.visited)
end

local function Outleveled(step, level)
    -- step.outlevel (Routes.lua Outlevel()) overrides the usual "this far below you counts as done".
    return level and step.lvl and level >= step.lvl + (step.outlevel or K.OUTLEVELED) or false
end

-- Quest IDs (QuestIDs.lua) let the game itself say what this character has finished, including
-- quests done before this addon was installed. Titles Forever renamed are looked up under both names.
local function RealTitle(title)
    local data = LevelGuideQuestIDs
    return data and data.renamed and data.renamed[title] or title
end

local function InLog(byTitle, title)
    return byTitle[title] or byTitle[RealTitle(title)]
end

local function HasIDs(title)
    local data = LevelGuideQuestIDs
    return (data and data.ids and (data.ids[title] or data.ids[RealTitle(title)])) ~= nil
end

-- Every quest this character has completed, read once from the game (GetAllCompletedQuestIDs) and
-- topped up by QUEST_TURNED_IN, so a just-finished quest counts at once and quests started from
-- objects are known too. The single-quest check stays as the fallback.
local completedSet, completedTried = nil, nil
local COMPLETED_RETRY_SECONDS = 10

local function Flagged(id)
    if not completedSet and C_QuestLog.GetAllCompletedQuestIDs and (not completedTried or Now() - completedTried > COMPLETED_RETRY_SECONDS) then
        completedTried = Now()
        local list = C_QuestLog.GetAllCompletedQuestIDs()
        if type(list) == "table" and #list > 0 then
            completedSet = {}
            for _, questID in ipairs(list) do
                questID = Safe(questID)
                if questID then
                    completedSet[questID] = true
                end
            end
        end
    end
    if completedSet and completedSet[id] then
        return true
    end
    return C_QuestLog.IsQuestFlaggedCompleted and Safe(C_QuestLog.IsQuestFlaggedCompleted(id)) or false
end

local function TurnedIn(title)
    if turnedCache[title] then
        return turnedCache[title]
    end
    local counted = math.max(charData.done[title] or 0, charData.done[RealTitle(title)] or 0)
    local data = LevelGuideQuestIDs
    local ids = data and data.ids and (data.ids[title] or data.ids[RealTitle(title)])
    if ids then
        local flagged = 0
        for _, id in ipairs(ids) do
            if Flagged(id) then
                flagged = flagged + 1
            end
        end
        -- The count by title only grows for these IDs (QUEST_TURNED_IN below), so a wrong ID in our list
        -- can't make a finished quest look undone.
        counted = math.max(counted, flagged)
    end
    turnedCache[title] = counted
    return counted
end

-- The log entry for this step's quest and part: holding part 3 of a chain is not holding part 1.
local function HeldPart(byTitle, step)
    local entry = InLog(byTitle, step.q)
    if not entry then
        return nil
    end
    -- Without a part from the quest IDs, a chain's part you hold is the one after those turned in.
    -- (A step without a part is a one-part quest: any log entry of that title is it.)
    local held = entry.part or (step.part and TurnedIn(step.q) + 1)
    if held and held ~= (tonumber(step.part) or 1) then
        return nil
    end
    return entry
end

-- Quests done before this addon was installed were never counted, so it would send you back to
-- quest givers with nothing left to offer. The earliest route quest you're holding shows how far
-- you've got: pick-ups and moves before it are behind you.
local function Frontier(route, byTitle)
    if frontiers[route] == nil then
        local earliest = false
        for index, step in ipairs(route.steps) do
            if step.t == "accept" and HeldPart(byTitle, step) then
                earliest = index
                break
            end
        end
        frontiers[route] = earliest
    end
    return frontiers[route]
end

-- Prerequisites (Prereqs.lua, from Questie's Forever data): a quest giver only offers a quest once
-- these are done, so the guide waits for them too. Completion comes from the game's own record.
local titleByID

local function BuildTitleByID()
    if not titleByID then
        titleByID = {}
        for title, ids in pairs(LevelGuideQuestIDs and LevelGuideQuestIDs.ids or {}) do
            for _, questID in ipairs(ids) do
                titleByID[questID] = title
            end
        end
    end
    return titleByID
end

local function QuestDone(id)
    if Flagged(id) then
        return true
    end
    local title = BuildTitleByID()[id] or titlesByID[id]
    return title ~= nil and (charData.done[title] or 0) > 0
end

-- QuestDB (QuestLookup.lua, from forever-db) fills what the routes of your race lack: quest IDs,
-- prerequisites, NPC names and spots. Once per race; what Routes/QuestIDs/Prereqs.lua say always wins.
local dbFilledFor
local function FillFromDB()
    local facts = LevelGuideQuestFacts
    local race = UnitRace and Safe(select(2, UnitRace("player")))
    if not (facts and facts.Fill and race) or dbFilledFor == race then
        return
    end
    dbFilledFor = race
    local chains = LevelGuideRoutes and LevelGuideRoutes.chains
    facts.Fill(chains and chains[race] or {}, race, UnitClass and Safe(select(2, UnitClass("player"))))
    titleByID = nil
end

-- A quest's name for the player: our ID list, the log, QuestDB, then the game's own lookup.
local function TitleOf(id)
    local title = BuildTitleByID()[id] or titlesByID[id]
    if not title and LevelGuideQuestFacts then
        title = LevelGuideQuestFacts.Title(id)
    end
    if not title and C_QuestLog.GetTitleForQuestID then
        title = Safe(C_QuestLog.GetTitleForQuestID(id))
    end
    return title or ("quest " .. tostring(id))
end

-- Accepted a moment ago (by any of the title's quest IDs, or by title): the log may not show it yet.
local function RecentlyAccepted(title)
    if not next(recentAccepts) then
        return false
    end
    if Recent(recentAccepts, title, ACCEPT_GRACE) or Recent(recentAccepts, RealTitle(title), ACCEPT_GRACE) then
        return true
    end
    local data = LevelGuideQuestIDs
    for _, id in ipairs(data and data.ids and (data.ids[title] or data.ids[RealTitle(title)]) or {}) do
        if Recent(recentAccepts, id, ACCEPT_GRACE) then
            return true
        end
    end
    return false
end

local function PrereqsMet(title, level)
    local data = LevelGuidePrereqs
    local need = data and (data[title] or data[RealTitle(title)])
    if not need then
        return true
    end
    if need.level and level and level < need.level then
        return false
    end
    for _, id in ipairs(need.all or {}) do
        if not QuestDone(id) then
            return false
        end
    end
    if need.any and #need.any > 0 then
        for _, id in ipairs(need.any) do
            if QuestDone(id) then
                return true
            end
        end
        return false
    end
    return true
end

-- What still stands between you and a pick-up, by name: "level 12", "Tenaron's Summons",
-- "one of: A / B". Empty when nothing is known to be missing.
-- With QuestDB, a missing quest is named with who gives it: "Zenn's Bidding (from Zenn Foulhoof)".
-- When Prereqs.lua names nothing missing, QuestDB's own prerequisites for the step's quest (by part) are
-- asked too, so "not offered here" can say what's missing.
local function MissingPrereqs(title, level, part)
    local missing = {}
    local data, facts = LevelGuidePrereqs, LevelGuideQuestFacts
    local function Named(id)
        local giver = facts and facts.GiverName and facts.GiverName(id)
        return TitleOf(id) .. (giver and (" (from " .. giver .. ")") or "")
    end
    local function Add(need)
        if need.level and level and level < need.level then
            missing[#missing + 1] = "level " .. need.level
        end
        for _, id in ipairs(need.all or {}) do
            if not QuestDone(id) then
                missing[#missing + 1] = Named(id)
            end
        end
        if need.any and #need.any > 0 then
            local names, anyDone = {}, false
            for _, id in ipairs(need.any) do
                anyDone = anyDone or QuestDone(id)
                names[#names + 1] = Named(id)
            end
            if not anyDone then
                missing[#missing + 1] = "one of: " .. table.concat(names, " / ")
            end
        end
    end
    local need = title and data and (data[title] or data[RealTitle(title)])
    if need then
        Add(need)
    end
    local ids = title and LevelGuideQuestIDs and LevelGuideQuestIDs.ids
    ids = ids and (ids[title] or ids[RealTitle(title)])
    local id = ids and ids[tonumber(part) or 1]
    if #missing == 0 and id and facts and facts.Prereqs then
        local race = UnitRace and Safe(select(2, UnitRace("player")))
        local cls = UnitClass and Safe(select(2, UnitClass("player")))
        need = facts.Prereqs(id, race, cls)
        if need then
            -- An earlier part of the same chain is the route's own business, not a missing quest.
            local own = {}
            for _, other in ipairs(ids) do
                own[other] = true
            end
            local kept = {}
            for _, pre in ipairs(need.all or {}) do
                if not own[pre] then
                    kept[#kept + 1] = pre
                end
            end
            need.all = kept
            Add(need)
        end
    end
    return missing
end

-- Quests the map shows as available in a zone, by title and by quest ID. Nil when you're not in that
-- zone or the game lists none, so the written route is used as it is.
local function MapOffers(zoneName)
    if zoneOffers[zoneName] ~= nil then
        return zoneOffers[zoneName] or nil
    end
    local result = false
    local zoneMap = C_QuestLine and C_QuestLine.GetAvailableQuestLines and ZoneMap(zoneName)
    if zoneMap then
        if not (requestedMap and requestedMap[zoneMap]) and C_QuestLine.RequestQuestLinesForMap then
            requestedMap = requestedMap or {}
            requestedMap[zoneMap] = true
            C_QuestLine.RequestQuestLinesForMap(zoneMap)
        end
        local titles, ids, any = {}, {}, false
        for _, info in ipairs(C_QuestLine.GetAvailableQuestLines(zoneMap) or {}) do
            local id, name = Safe(info.questID), Safe(info.questName)
            if (id or name) and not Safe(info.isHidden) and not Safe(info.inProgress) then
                any = true
                if id then
                    ids[id] = true
                end
                if name then
                    titles[name] = true
                end
            end
        end
        if any then
            result = { titles = titles, ids = ids }
        end
    end
    zoneOffers[zoneName] = result
    return result or nil
end

local function OfferedOnMap(onMap, title)
    if onMap.titles[title] or onMap.titles[RealTitle(title)] then
        return true
    end
    local data = LevelGuideQuestIDs
    for _, id in ipairs(data and data.ids and (data.ids[title] or data.ids[RealTitle(title)]) or {}) do
        if onMap.ids[id] then
            return true
        end
    end
    return false
end
local ObjectivesDone, ObjectiveText, UtilityDone, ItemCount, LevelFraction, TravelTo, BagSlots, ClassMatches, SideSteps, GuardsPass
do -- (a block, so its helpers don't count toward the file's 200-local limit)
-- Per-objective "do" steps (Routes.lua Obj()): step.obj is an objective index, or a list of them, of the
-- quest's own objective list; the step is done when those are finished, even if the rest isn't.
-- With max (Routes.lua Count()), an objective counts as done once that many are fulfilled ("8 of 10
-- here, the rest later").
function ObjectivesDone(questID, obj, max)
    if not (questID and obj) then
        return false
    end
    local objectives = C_QuestLog.GetQuestObjectives(questID) or {}
    local list = type(obj) == "table" and obj or { obj }
    for _, index in ipairs(list) do
        local objective = objectives[index]
        local fulfilled = objective and Safe(objective.numFulfilled)
        if not (objective and (Safe(objective.finished) or (max and type(fulfilled) == "number" and fulfilled >= max))) then
            return false
        end
    end
    return #list > 0
end

function ObjectiveText(questID, obj)
    local objectives = questID and C_QuestLog.GetQuestObjectives(questID) or {}
    local texts = {}
    for _, index in ipairs(type(obj) == "table" and obj or { obj }) do
        local objective = objectives[index]
        local text = objective and Safe(objective.text)
        if text and text ~= "" and not Safe(objective.finished) then
            texts[#texts + 1] = text
        end
    end
    return #texts > 0 and table.concat(texts, ", ") or nil
end

local function LowerTrim(text)
    return type(text) == "string" and text:lower():match("^%s*(.-)%s*$") or nil
end

-- Your hearthstone's inn, as the game names it (GetBindLocation).
local function BoundTo(place)
    local bind = GetBindLocation and LowerTrim(Safe(GetBindLocation()))
    local want = LowerTrim(place)
    return bind and want and bind ~= "" and (bind == want or bind:find(want, 1, true) ~= nil) or false
end

-- Flight paths are known from the flight master's own map (TAXIMAP_OPENED) or the game's "new flight
-- path" message, remembered per character: there's no way to ask away from a flight master.
local function FlightKnown(place)
    local want = LowerTrim(place)
    for name in pairs(want and charData.flights or {}) do
        if LowerTrim(name):find(want, 1, true) then
            return true
        end
    end
    return false
end

-- Bags only (not the bank). itemID may be a list: the count of all of them together.
function ItemCount(itemID)
    if type(itemID) == "table" then
        local total = 0
        for _, id in ipairs(itemID) do
            total = total + ItemCount(id)
        end
        return total
    end
    if not (itemID and C_Item and C_Item.GetItemCount) then
        return 0
    end
    local count = Safe(C_Item.GetItemCount(itemID))
    return type(count) == "number" and count or 0
end

-- Slots in your backpack and four bags (C_Container.GetContainerNumSlots).
function BagSlots()
    local total = 0
    if C_Container and C_Container.GetContainerNumSlots then
        for bag = 0, 4 do
            local slots = Safe(C_Container.GetContainerNumSlots(bag))
            total = total + (type(slots) == "number" and slots or 0)
        end
    end
    return total
end

local function SpellKnown(spells)
    for _, id in ipairs(type(spells) == "table" and spells or { spells }) do
        if C_SpellBook and C_SpellBook.IsSpellKnown and Safe(C_SpellBook.IsSpellKnown(id)) then
            return true
        end
        if IsPlayerSpell and Safe(IsPlayerSpell(id)) then
            return true
        end
    end
    return false
end

-- Where you are in your level, as a fraction, and whether the XP gate's target is reached.
function LevelFraction()
    local xp, maxXP = Safe(UnitXP("player")), MaxXP()
    return xp and maxXP and xp / maxXP or 0
end

-- The XP an "N into level L" / "N short of level L" gate wants within the level it's read in, or nil.
local function XPTarget(step, level)
    local maxXP = MaxXP()
    if step.short and level == step.level - 1 and maxXP then
        return math.max(maxXP - step.short, 0)
    elseif step.into and level == step.level then
        return step.into
    end
end

local function XPReached(step, level)
    if not level then
        return false
    end
    if step.short then
        -- "2500 short of 13": done at 13, or at 12 within 2500 of the end.
        local target = XPTarget(step, level)
        return level >= step.level or (target ~= nil and (Safe(UnitXP("player")) or 0) >= target)
    end
    if step.into then
        local target = XPTarget(step, level)
        return level > step.level or (target ~= nil and (Safe(UnitXP("player")) or 0) >= target)
    end
    return level > step.level or (level == step.level and LevelFraction() >= (step.frac or 0))
end

local function InZone(name)
    if ZoneMap(name) then
        return true
    end
    local want = LowerTrim(name)
    for _, read in ipairs({ GetSubZoneText, GetRealZoneText, GetMinimapZoneText }) do
        if want and read and LowerTrim(Safe(read())) == want then
            return true
        end
    end
    return false
end

-- A move made another way: you stand in a zone the route only reaches after this step (a leg's tram ride
-- you skipped by flying, say). Steps on another zone's map (On()) are in that zone; a hearth is nowhere.
local function MovedPast(route, index)
    local function zoneOf(other)
        return not other.side and other.t ~= "hearth" and (other.map or route.zone) or nil
    end
    local before, checked = {}, {}
    -- The step's own zone (where you set out from) and every earlier one don't count.
    for earlier = 1, index do
        local zone = zoneOf(route.steps[earlier])
        if zone then
            before[zone] = true
        end
    end
    for later = index + 1, #route.steps do
        local zone = zoneOf(route.steps[later])
        if zone and not before[zone] and not checked[zone] then
            checked[zone] = true
            if ZoneMap(zone) then
                return true
            end
        end
    end
    return false
end

-- A utility step's own completion. What can be lost later (a bound hearth moved on, items used up for a
-- quest) is remembered once seen, so the guide never sends you back for it. With the route and the
-- step's place in it, a move is also done once you're past it (MovedPast).
-- Whether a move or XP gate before this step on the route is still open. Being in a place counts as
-- having arrived there only once you've reached that point of the route: in Auberdine before the Loch
-- Modan trip, the trip's closing "Hearth to Auberdine" is done for now but not remembered as done.
local function OpenMoveBefore(route, index, level)
    if not (route and index) then
        return false
    end
    local passed = X.PassedTo(route, lastByTitle or {}, level)
    for earlier = index - 1, 1, -1 do
        local other = route.steps[earlier]
        if earlier < passed then
            return false
        end
        if BARRIER[other.t] and not other.side and ClassMatches(other.cls) then
            local otherKey = RouteKey(route, earlier)
            if not charData.skips[otherKey] and not charData.visited[otherKey] then
                if other.t ~= "xp" or not XPReached(other, level) then
                    return true
                end
            end
        end
    end
    return false
end

-- Arrived: remembered when the route has got this far, else only true while you're there.
local function Arrived(key, route, index, level)
    if OpenMoveBefore(route, index, level) then
        return true
    end
    charData.visited[key] = true
    return true
end

function UtilityDone(step, key, level, route, index)
    if step.t == "go" then
        -- A move into a place (Routes.lua Reach(), e.g. "Enter Darnassus") is done once you're there,
        -- wherever you came in.
        if not charData.visited[key] and step.reach and (InZone(step.reach) or (route and MovedPast(route, index))) then
            return Arrived(key, route, index, level)
        end
        return charData.visited[key] or false
    elseif step.t == "zone" then
        if not charData.visited[key] and (InZone(step.reach) or (route and MovedPast(route, index))) then
            return Arrived(key, route, index, level)
        end
        return charData.visited[key] or false
    elseif step.t == "home" then
        if not charData.marks[key] and BoundTo(step.place) then
            charData.marks[key] = true
        end
        return charData.marks[key] or false
    elseif step.t == "fp" then
        return FlightKnown(step.place)
    elseif step.t == "item" then
        if not charData.marks[key] and ItemCount(step.item) >= (step.count or 1) then
            charData.marks[key] = true
        end
        return charData.marks[key] or false
    elseif step.t == "train" then
        return SpellKnown(step.spells)
    elseif step.t == "xp" then
        return XPReached(step, level)
    elseif step.t == "buy" then
        -- Bought (any of the listed items, from a vendor or the auction house): remembered, so eating,
        -- drinking or equipping it later doesn't bring the step back.
        if not charData.marks[key] and ItemCount(step.items) >= (step.count or 1) then
            charData.marks[key] = true
        end
        return charData.marks[key] or false
    elseif step.t == "vendor" then
        -- Marked when that vendor's window closes (MERCHANT_CLOSED).
        return charData.marks[key] or false
    elseif step.t == "hearth" then
        -- Done once you're there, by hearthstone or on foot.
        if not charData.visited[key] and InZone(step.place) then
            return Arrived(key, route, index, level)
        end
        return charData.visited[key] or false
    elseif step.t == "bags" then
        return BagSlots() >= (step.slots or 0)
    elseif step.t == "trainer" then
        -- A class trainer's window opened at this level or later (TRAINER_SHOW), or what it teaches known.
        return (charData.trainerLevel or 0) >= (step.atLevel or 0) or (step.spells ~= nil and SpellKnown(step.spells))
    end
    return false
end

-- Guards (Routes.lua When()): a step whose guard fails is hidden, not completed, and checked again on
-- every rebuild, so it comes back once the guard holds. Items are { id or {ids}, n }; quests are titles.
function GuardsPass(when, byTitle)
    if not when then
        return true
    end
    if when.hasItem and ItemCount(when.hasItem[1]) < (when.hasItem[2] or 1) then
        return false
    end
    if when.lacksItem and ItemCount(when.lacksItem[1]) >= (when.lacksItem[2] or 1) then
        return false
    end
    if when.onQuest and not InLog(byTitle, when.onQuest) then
        return false
    end
    if when.notOnQuest and InLog(byTitle, when.notOnQuest) then
        return false
    end
    if when.notTurnedIn and TurnedIn(when.notTurnedIn) > 0 then
        return false
    end
    if when.hearthNot and BoundTo(when.hearthNot) then
        return false
    end
    return true
end

-- Class filter (Routes.lua Class()): "PRIEST" or a list of class tokens; true when it applies to you.
-- When the class can't be read the step is shown.
function ClassMatches(cls)
    if not cls then
        return true
    end
    local mine = UnitClass and Safe(select(2, UnitClass("player")))
    if not mine then
        return true
    end
    for _, want in ipairs(type(cls) == "table" and cls or { cls }) do
        if want == mine then
            return true
        end
    end
    return false
end
end -- utility step helpers

-- Placement from live state (after Polestar's place/anchorStep, research\guides_deep_re.md 1.3 and 12.2),
-- worked out again on every rebuild from the quest log and completed quests, never stored as an index:
-- * anchor: the last route step with real progress, a quest turned in or with objectives under way, of a
--   quest the route gives at or before that step (class-only steps are not evidence). Holding a quest is
--   not progress. Once the log has loaded (QUEST_LOG_UPDATE) the anchor only moves forward this session,
--   so dropping a quest doesn't send you back through moves you made.
-- * start: the first step with a quest you hold, or a pick-up you can take now (IDs known, earlier part
--   and prerequisites done, level near).
-- Behind the anchor, utility steps are passed. Before the first quest you hold, moves and pick-ups the game
-- can't vouch for are passed (Frontier). A move before the start is passed when you stand within 150 yd of
-- the start. Nothing else is passed: skipped or deferred steps never count as done.
do
X.TRAVEL = { go = true, zone = true, hearth = true }

local function HasProgress(questID)
    for _, objective in ipairs(questID and C_QuestLog.GetQuestObjectives(questID) or {}) do
        local fulfilled = Safe(objective.numFulfilled)
        if Safe(objective.finished) or (type(fulfilled) == "number" and fulfilled > 0) then
            return true
        end
    end
    return false
end

local function PickupOpen(route, index, step, byTitle, level)
    return step.t == "accept" and HasIDs(step.q) and level ~= nil and not InLog(byTitle, step.q)
        and TurnedIn(step.q) == (tonumber(step.part) or 1) - 1 and (not step.lvl or step.lvl <= level + 1)
        and PrereqsMet(step.q, level)
end

function X.Placement(route, byTitle, level)
    local place = X.places[route]
    if place then
        return place
    end
    place = { anchor = 0 }
    local given = {}
    for index, step in ipairs(route.steps) do
        local quest = step.q and not step.side and (step.t == "accept" or step.t == "do" or step.t == "turnin")
        if quest and not step.cls then
            local part = tonumber(step.part) or 1
            local key = step.q .. "#" .. part
            given[key] = given[key] or step.t == "accept"
            if given[key] then
                local evidence = TurnedIn(step.q) >= part
                if not evidence and step.t ~= "accept" then
                    local entry = HeldPart(byTitle, step)
                    evidence = entry ~= nil and (entry.ready or HasProgress(entry.id))
                end
                if evidence then
                    place.anchor = index
                end
            end
        end
        if not place.start and not step.side and ClassMatches(step.cls) and not charData.skips[RouteKey(route, index)] then
            if (quest and HeldPart(byTitle, step)) or PickupOpen(route, index, step, byTitle, level) then
                place.start = index
            end
        end
    end
    X.latched = X.latched or setmetatable({}, { __mode = "k" })
    if X.logSeen then
        X.latched[route] = math.max(X.latched[route] or 0, place.anchor)
    end
    place.anchor = math.max(place.anchor, X.latched[route] or 0)
    X.places[route] = place
    return place
end

-- How far the route is behind you: the anchor, or the first quest you hold.
function X.PassedTo(route, byTitle, level)
    return math.max(X.Placement(route, byTitle, level).anchor, Frontier(route, byTitle) or 0)
end

-- A move written before the start step, while you stand within NEAR_START_YARDS of that step.
function X.NearStart(route, index, place)
    if not (place.start and index < place.start) then
        return false
    end
    if place.near == nil then
        place.near = false
        local start = route.steps[place.start]
        local zoneMap = start.x and start.y and not start.map and ZoneMap(route.zone)
        local px, py
        if zoneMap then
            px, py = PositionOn(zoneMap)
        end
        if px and py then
            local yards, isYards = Distance(zoneMap, px, py, start.x / 100, start.y / 100)
            place.near = isYards and yards <= K.NEAR_START_YARDS or false
        end
    end
    return place.near
end
end -- placement

local function RouteStepDone(route, index, step, byTitle, level)
    local key = RouteKey(route, index)
    if charData.skips[key] then
        return true
    end
    -- Another class's step (Routes.lua Class()) isn't yours to do.
    if step.cls and not ClassMatches(step.cls) then
        return true
    end
    -- A failed guard hides the step for now (nothing is saved, so it's back once the guard holds).
    if step.when and not GuardsPass(step.when, byTitle) then
        return true
    end
    if step.side and UTILITY[step.t] then
        -- Side steps (shopping, bags, trainer visits, keep an item) only answer to their own state, not to
        -- how far along the route you are: a wand to buy is still worth buying past where it was written.
        if step.t == "keep" then
            return ItemCount(step.item) == 0 or InLog(byTitle, step.forQ) ~= nil or TurnedIn(step.forQ) > 0
        end
        if step.t == "trainer" then
            -- A later visit (by level) you've reached replaces this one.
            for _, other in ipairs(route.steps) do
                if other ~= step and other.t == "trainer" and ClassMatches(other.cls) and level
                    and (other.atLevel or 0) > (step.atLevel or 0) and (other.atLevel or 0) <= level then
                    return true
                end
            end
        end
        return Outleveled(step, level) or UtilityDone(step, key, level)
    end
    -- Taken a moment ago: the log may not list it yet, so don't flicker back to the pick-up.
    if step.t == "accept" and RecentlyAccepted(step.q) then
        return true
    end
    -- You've talked to this quest giver and they don't offer it (yet), so don't send you back.
    if step.t == "accept" and not InLog(byTitle, step.q) then
        -- The map's "!" markers are the game saying what you can pick up right now. A quest it lists is
        -- on offer whatever else says; one it doesn't list may still be (the map doesn't know every
        -- quest), so then the giver's own window and the quest's prerequisites decide.
        local onMap = MapOffers(route.zone)
        if not (onMap and OfferedOnMap(onMap, step.q)) then
            if X.NotOffered(step, level) then
                return true
            end
            if not PrereqsMet(step.q, level) then
                return true
            end
        end
    end
    -- Behind the frontier (the first quest you hold): moves are behind you, and so are pick-ups the game
    -- can't vouch for. A pick-up with quest IDs is asked of the game instead, so one you took out of order
    -- still shows. Hearth, training and items before it are not: holding a quest isn't progress (X.Placement).
    local frontier = Frontier(route, byTitle)
    if frontier and index < frontier and (X.TRAVEL[step.t] or (step.t == "accept" and not HasIDs(step.q))) then
        return true
    end
    if Outleveled(step, level) then
        return true
    end
    if UTILITY[step.t] then
        if UtilityDone(step, key, level, route, index) then
            return true
        end
        local place = X.Placement(route, byTitle, level)
        return index < place.anchor or (X.TRAVEL[step.t] and X.NearStart(route, index, place)) or false
    end
    local turnedIn = TurnedIn(step.q)
    local part = tonumber(step.part) or 1
    local held = InLog(byTitle, step.q)
    -- Holding a later part means the earlier ones are behind you, counted or not.
    if held and held.part then
        turnedIn = math.max(turnedIn, held.part - 1)
    end
    local entry = HeldPart(byTitle, step)
    if step.t == "accept" then
        return turnedIn >= part or (entry ~= nil and turnedIn == part - 1)
    end
    -- A quest you don't have, such as one started in another zone or from a dropped item,
    -- has nothing to do or turn in, so it can't hold up the route.
    if turnedIn >= part or entry == nil then
        return true
    end
    if step.t == "do" then
        return entry.ready or (step.obj ~= nil and ObjectivesDone(entry.id, step.obj, step.objMax))
    end
    return false
end

-- "Not offered" marks (after DonData's Offers.lua and Polestar's checkOffers, research\guides_deep_re.md 4.1,
-- 1.5 and 12.3; our own code). The quest giver's own window is the truth: a route pick-up the giver doesn't
-- list (GOSSIP_SHOW / QUEST_GREETING, available or active) is "not offered at level L", saved per character
-- with where it was judged. The mark holds until a level-up, 30 minutes, a turn-in at that NPC or within
-- 100 yd (or of the quest's prerequisite), the quest being accepted, or seen offered. A window with an
-- unreadable entry, or within 3 s of a turn-in, judges nothing. The map's quest lines are never a "no".
do
local OFFER_HOLD, OFFER_NEAR, OFFER_AFTER_TURNIN = 1800, 100, 3

local function Clock()
    return (time and Safe(time())) or Now()
end

local function MarkKey(step)
    local ids = LevelGuideQuestIDs and LevelGuideQuestIDs.ids
    ids = ids and (ids[step.q] or ids[RealTitle(step.q)])
    local id = ids and ids[tonumber(step.part) or 1]
    return id or (step.q .. "#" .. (tonumber(step.part) or 1)), id
end

-- The mark on a route pick-up while it holds, else nil (an expired one is dropped).
function X.NotOffered(step, level)
    local marks = charData and charData.notOffered
    if not (marks and step.q) then
        return nil
    end
    local key = MarkKey(step)
    local mark = marks[key]
    if mark and not (type(mark) == "table" and level and (mark.level or 0) >= level and Clock() - (mark.t or 0) < OFFER_HOLD) then
        marks[key] = nil
        return nil
    end
    return mark
end

-- What the open window lists (available and active), by quest ID and title, and whether every entry
-- could be read.
local function ReadWindow(event)
    local offered, readable = {}, true
    local function Add(id, title)
        id, title = Safe(id), Safe(title)
        if id == nil and title == nil then
            readable = false
            return
        end
        if id then
            offered[id] = true
        end
        if title then
            offered[title] = true
        end
    end
    if event == "GOSSIP_SHOW" and C_GossipInfo then
        for _, info in ipairs(C_GossipInfo.GetAvailableQuests and C_GossipInfo.GetAvailableQuests() or {}) do
            Add(info.questID, info.title)
        end
        for _, info in ipairs(C_GossipInfo.GetActiveQuests and C_GossipInfo.GetActiveQuests() or {}) do
            Add(info.questID, info.title)
        end
    elseif event == "QUEST_GREETING" then
        for index = 1, GetNumAvailableQuests and Safe(GetNumAvailableQuests()) or 0 do
            Add(GetAvailableQuestInfo and select(5, GetAvailableQuestInfo(index)), GetAvailableTitle and GetAvailableTitle(index))
        end
        for index = 1, GetNumActiveQuests and Safe(GetNumActiveQuests()) or 0 do
            Add(GetActiveQuestID and GetActiveQuestID(index), GetActiveTitle and GetActiveTitle(index))
        end
    end
    return offered, readable
end

local function Clear(match)
    for key, mark in pairs(charData and charData.notOffered or {}) do
        if match(key, mark) then
            charData.notOffered[key] = nil
        end
    end
end

-- GOSSIP_SHOW / QUEST_GREETING / QUEST_DETAIL at a quest giver.
function X.JudgeOffers(event)
    local npc = NpcKey(Safe(UnitName("npc")))
    if not (npc and charData) then
        return
    end
    charData.notOffered = charData.notOffered or {}
    local marks = charData.notOffered
    if event == "QUEST_DETAIL" then
        -- A quest's own page: it's offered.
        local title = GetTitleText and Safe(GetTitleText())
        Clear(function(_, mark) return title ~= nil and (mark.q == title or RealTitle(mark.q or "") == title) end)
        return
    end
    local offered, readable = ReadWindow(event)
    Clear(function(key, mark) return offered[key] or (mark.q and (offered[mark.q] or offered[RealTitle(mark.q)])) end)
    if not (readable and activeRoute) then
        return
    end
    -- Right after a turn-in the window may not list what it just unlocked yet: confirm offers only.
    for _, at in pairs(recentTurnins) do
        if Now() - at < OFFER_AFTER_TURNIN then
            return
        end
    end
    local level = Safe(UnitLevel("player"))
    local zoneMap = ZoneMap(activeRoute.zone)
    local x, y
    if zoneMap then
        x, y = PositionOn(zoneMap)
    end
    for _, step in ipairs(activeRoute.steps) do
        if step.t == "accept" and step.q and not step.side and NpcKey(step.npc) == npc and ClassMatches(step.cls) then
            local key, id = MarkKey(step)
            local part = tonumber(step.part) or 1
            if not (offered[step.q] or offered[RealTitle(step.q)] or (id and offered[id])) and level
                and not InLog(lastByTitle or {}, step.q) and TurnedIn(step.q) == part - 1 and not Outleveled(step, level) then
                marks[key] = { level = level, npc = npc, q = step.q, t = Clock(), map = x and zoneMap or nil, x = x, y = y }
            end
        end
    end
end

-- A turn-in clears marks of that NPC, within 100 yd of where they were judged, or of quests it unlocks.
function X.OffersAfterTurnin(questID)
    local npc = NpcKey(Safe(UnitName("npc")))
    local facts = LevelGuideQuestFacts
    Clear(function(key, mark)
        if npc and mark.npc == npc then
            return true
        end
        if mark.map and mark.x and mark.y then
            local px, py = PositionOn(mark.map)
            if px and py then
                local yards, isYards = Distance(mark.map, px, py, mark.x, mark.y)
                if isYards and yards <= OFFER_NEAR then
                    return true
                end
            end
        end
        local need = mark.q and LevelGuidePrereqs and (LevelGuidePrereqs[mark.q] or LevelGuidePrereqs[RealTitle(mark.q)])
        if not need and type(key) == "number" and facts and facts.Quest then
            need = facts.Quest(key)
        end
        for _, list in ipairs({ need and need.all or {}, need and need.any or {} }) do
            for _, pre in ipairs(list) do
                if pre == questID then
                    return true
                end
            end
        end
        return false
    end)
end

-- Accepted: no longer "not offered".
function X.OffersAfterAccept(questID, title)
    Clear(function(key, mark) return key == questID or (title ~= nil and mark.q ~= nil and (mark.q == title or RealTitle(mark.q) == title)) end)
end

-- At login: marks past their 30 minutes go, so the saved table stays small.
function X.PruneOffers()
    Clear(function(_, mark) return type(mark) ~= "table" or Clock() - (mark.t or 0) >= OFFER_HOLD end)
end
end -- "not offered" marks

-- XP projection (research\guides_deep_re.md 12.4; the formulas are Planner.lua's, ported from Polestar):
-- the rest of the route simulated in order from your level and XP. Turn-ins add their reward (the game's
-- figure for quests you hold, else QuestXP.lua's reduced by the level gap at that point), work adds its
-- kills (what's left of them for quests under way), one at a time so level-ups lower later gains. Gives
-- the route's end level, the level the route has you at each step, and XP per second for ordering.
do
-- A route step's quest ID: the one you hold, else the route's ID for that part.
function X.QuestIDFor(step, byTitle)
    local entry = step.q and HeldPart(byTitle or {}, step)
    if entry and entry.id then
        return entry.id
    end
    local ids = step.q and LevelGuideQuestIDs and LevelGuideQuestIDs.ids
    ids = ids and (ids[step.q] or ids[RealTitle(step.q)])
    return ids and ids[tonumber(step.part) or 1] or nil
end

-- A quest's level: the log's, else the server's (X.ServerLevel), else QuestDB's.
function X.QuestLevel(id, logLevel)
    if logLevel then
        return logLevel
    end
    local server = id and X.ServerLevel and X.ServerLevel(id)
    if server then
        return server
    end
    local q = id and LevelGuideQuestFacts and LevelGuideQuestFacts.Quest and LevelGuideQuestFacts.Quest(id)
    return q and q.level or nil
end

local function LeftToDo(questID)
    local need, left = 0, 0
    for _, objective in ipairs(C_QuestLog.GetQuestObjectives(questID) or {}) do
        local have, want = Safe(objective.numFulfilled), Safe(objective.numRequired)
        if type(have) == "number" and type(want) == "number" and want > 0 then
            need, left = need + want, left + math.max(want - have, 0)
        end
    end
    return need > 0 and left / need or 1
end

-- Sets X.projection = { at = { [step index] = fractional level }, final } for the route, or nil.
function X.Project(route, byTitle, level)
    local P = LevelGuidePlanner
    X.projection = nil
    if not (P and route and level) then
        return
    end
    local entries, seen = {}, {}
    for index, step in ipairs(route.steps) do
        entries[#entries + 1] = { kind = "mark", index = index }
        local part = tonumber(step.part) or 1
        if step.q and not step.side and (step.t == "do" or step.t == "turnin") and ClassMatches(step.cls)
            and not charData.skips[RouteKey(route, index)] and TurnedIn(step.q) < part then
            local id = X.QuestIDFor(step, byTitle)
            local once = step.t .. "|" .. tostring(id or (step.q .. "#" .. part))
            local entry = HeldPart(byTitle, step)
            if not seen[once] then
                seen[once] = true
                if step.t == "do" and id and not (entry and entry.ready) then
                    local left = entry and LeftToDo(entry.id) or 1
                    for _, kill in ipairs(select(2, P.QuestXP(id))) do
                        entries[#entries + 1] = { kind = "kill", n = math.ceil(kill.n * left), mob = kill.mob, elite = kill.elite }
                    end
                elseif step.t == "turnin" then
                    local reward = entry and RewardXP(entry.id) or 0
                    if reward > 0 then
                        entries[#entries + 1] = { kind = "quest", xp = reward, share = false }
                    elseif id then
                        entries[#entries + 1] = { kind = "quest", xp = (P.QuestXP(id)), level = X.QuestLevel(id) }
                    end
                end
            end
        end
    end
    local summary = P.Run(entries, { level = level, xp = Safe(UnitXP("player")) or 0, xpMax = MaxXP() })
    local at = {}
    for _, e in ipairs(entries) do
        if e.kind == "mark" then
            at[e.index] = e.at
        end
    end
    X.projection = { at = at, final = summary.at, route = route }
end

-- Work or a pick-up for a quest 3+ levels above where the route has you then: step.hard = its level.
function X.MarkHard(list)
    local projection = X.projection
    for _, step in ipairs(list) do
        local planned = projection and step.stepIndex and projection.at[step.stepIndex]
        if planned and step.questLevel and (step.kind == "work" or step.kind == "pickup")
            and step.questLevel - math.floor(planned) >= 3 then
            step.hard = step.questLevel
        end
    end
end

-- XP per second of a candidate step from a point: its XP over the walk there (1.25 winding, 7 yd/s)
-- plus a few seconds of talking.
function X.XPPerSecond(step, mapID, fromX, fromY)
    local xp = step.xpValue or (step.kind == "turnin" and step.xp) or 0
    if xp <= 0 or not (step.x and fromX) then
        return 0
    end
    return xp / (Distance(mapID, fromX, fromY, step.x, step.y) * 1.25 / 7 + 6)
end
end -- XP projection

-- Exact order inside a hub (research\guides_deep_re.md 12.11; our own code, Planner.HubOrder): after the
-- nearest-first pass, the pick-ups and turn-ins within 100 yd of the current stop are walked in the shortest
-- order from it when they're 7 groups or fewer (NPCs within 10 yd are one), keeping a chain's later part after
-- the turn-in before it and an accept after its prerequisite's turn-in. Stops a route marks `inside` (in a
-- building) cost 60 yd more to reach from outside. The current stop never changes here (its hysteresis is
-- Route()'s); nothing changes unless it saves more than 5 yd.
do
local function QuestIDOf(shown)
    local ids = shown.quest and LevelGuideQuestIDs and LevelGuideQuestIDs.ids
    ids = ids and (ids[shown.quest] or ids[RealTitle(shown.quest)])
    return shown.id or (ids and ids[tonumber(shown.questPart) or 1]) or nil
end

function X.HubOrder(list, mapID)
    local P = LevelGuidePlanner
    local first = list[1]
    if not (P and P.HubOrder and first and first.x and first.mapID == mapID) then
        return list
    end
    local hub, items, positions = {}, {}, {}
    for position = 2, #list do
        local shown = list[position]
        if (shown.kind == "pickup" or shown.kind == "turnin") and shown.x and shown.mapID == mapID then
            local yards, isYards = Distance(mapID, first.x, first.y, shown.x, shown.y)
            if isYards and yards <= P.HUB.radius then
                hub[#hub + 1] = shown
                positions[#positions + 1] = position
            end
        end
    end
    if #hub < 2 then
        return list
    end
    local scale = MapScale(mapID)
    local function Point(shown)
        return { x = shown.x * scale[1], y = shown.y * scale[2], inside = shown.inside, kind = shown.kind }
    end
    for i, shown in ipairs(hub) do
        items[i] = Point(shown)
    end
    -- What must come first: a chain's earlier part's turn-in, or a prerequisite's turn-in.
    local pre = {}
    for i, b in ipairs(hub) do
        if b.kind == "pickup" then
            local need = b.quest and LevelGuidePrereqs and (LevelGuidePrereqs[b.quest] or LevelGuidePrereqs[RealTitle(b.quest)])
            for j, a in ipairs(hub) do
                if a.kind == "turnin" then
                    local earlierPart = a.quest == b.quest and (tonumber(a.questPart) or 1) == (tonumber(b.questPart) or 1) - 1
                    local id, needed = QuestIDOf(a), false
                    for _, want in ipairs(need and need.all or {}) do
                        needed = needed or want == id
                    end
                    if earlierPart or needed then
                        pre[i] = pre[i] or {}
                        pre[i][j] = true
                    end
                end
            end
        end
    end
    local given = {}
    for i = 1, #hub do
        given[i] = i
    end
    local order = P.HubOrder(Point(first), items, function(a, b)
        return math.sqrt((a.x - b.x) ^ 2 + (a.y - b.y) ^ 2)
    end, pre, given)
    if not order then
        return list
    end
    local out, taken = { first }, {}
    for _, i in ipairs(order) do
        out[#out + 1] = hub[i]
        taken[positions[i]] = true
    end
    for position = 2, #list do
        if not taken[position] then
            out[#out + 1] = list[position]
        end
    end
    return out
end
end -- hub order

-- Target hysteresis (Polestar's currentGoal rule, research\guides_deep_re.md 1.7; our own code): the step the
-- arrow points at stays while you fight, for 5 s after objective progress, and until another is more than
-- 25% and more than 40 yd nearer (Planner.Switch), so two nearly equal stops don't take turns.
do
local PROGRESS_HOLD = 5

function X.HoldTarget(current, best, mapID, fromX, fromY)
    local P = LevelGuidePlanner
    if not (P and current and best and current.x and best.x) or current == best then
        return false
    end
    if UnitAffectingCombat and Safe(UnitAffectingCombat("player")) then
        return true
    end
    if X.progressAt and Now() - X.progressAt < PROGRESS_HOLD then
        return true
    end
    local curYards, isYards = Distance(mapID, fromX, fromY, current.x, current.y)
    local newYards = Distance(mapID, fromX, fromY, best.x, best.y)
    return isYards and not P.Switch(curYards, newYards) or false
end

-- On QUEST_LOG_UPDATE: notes when any objective count went up (X.progressAt, for the hold above and the
-- spawn-camp dwell).
function X.CheckProgress()
    local total = 0
    for index = 1, Safe(C_QuestLog.GetNumQuestLogEntries()) or 0 do
        local info = C_QuestLog.GetInfo(index)
        local id = info and Safe(info.questID)
        if id and not Safe(info.isHeader) then
            for _, objective in ipairs(C_QuestLog.GetQuestObjectives(id) or {}) do
                total = total + (tonumber(Safe(objective.numFulfilled)) or 0)
            end
        end
    end
    if X.progressTotal and total > X.progressTotal then
        X.progressAt = Now()
    end
    X.progressTotal = total
end
end -- target hysteresis

-- Server quest levels (after DonData's Levels.lua, research\guides_deep_re.md 4.1 and 12.9; our own code):
-- the levels Forever's server gives the route's quests can differ from QuestDB's. From 60 s after login,
-- never in combat, one quest every 0.5 s: C_QuestLog.RequestLoadQuestByID, then on QUEST_DATA_LOAD_RESULT
-- (or after 5 s) C_QuestLog.GetQuestDifficultyLevel. A level that differs from QuestDB's is kept account-wide
-- (LevelGuideDB.serverLevels, reset on a new client build); each quest is asked once per build. A failed
-- load means only "no answer", never that the quest is missing.
do
local START, EVERY, WAIT = 60, 0.5, 5
local S = { tried = {}, queue = nil, last = 0 }

local function Store()
    if not db then
        return nil
    end
    local version, build = nil, nil
    if GetBuildInfo then
        version, build = GetBuildInfo()
    end
    local key = tostring(Safe(version) or "?") .. "." .. tostring(Safe(build) or "?")
    local store = db.serverLevels
    if type(store) ~= "table" or store.build ~= key then
        store = { build = key, levels = {}, checked = {} }
        db.serverLevels = store
    end
    return store
end
X.ServerStore = Store

function X.ServerLevel(id)
    local store = db and db.serverLevels
    return store and store.levels and store.levels[id] or nil
end

-- The route quests of your race's chain, in route order, once per session.
local function Queue()
    if S.queue then
        return S.queue
    end
    local queue, seen = {}, {}
    local race = UnitRace and Safe(select(2, UnitRace("player")))
    local chains = LevelGuideRoutes and LevelGuideRoutes.chains
    local ids = LevelGuideQuestIDs and LevelGuideQuestIDs.ids or {}
    for _, route in ipairs(race and chains and chains[race] or {}) do
        for _, step in ipairs(rawget(route, "steps") or {}) do
            local list = step.q and (ids[step.q] or ids[RealTitle(step.q)])
            local id = list and list[tonumber(step.part) or 1]
            if id and not seen[id] then
                seen[id] = true
                queue[#queue + 1] = id
            end
        end
    end
    S.queue, S.next = queue, 1
    return queue
end

local function Read(store, id)
    local level = C_QuestLog.GetQuestDifficultyLevel and Safe(C_QuestLog.GetQuestDifficultyLevel(id))
    if type(level) == "number" and level > 0 then
        store.checked[id] = true
        local facts = LevelGuideQuestFacts
        local q = facts and facts.Quest and facts.Quest(id)
        if level ~= (q and q.level) then
            store.levels[id] = level
        end
    end
end

-- Called every frame (cheap until a step is due).
function X.ScanTick()
    if X.clock < START or X.clock - S.last < EVERY or not (C_QuestLog.RequestLoadQuestByID and db) then
        return
    end
    S.last = X.clock
    if (InCombatLockdown and Safe(InCombatLockdown())) or (UnitAffectingCombat and Safe(UnitAffectingCombat("player"))) then
        return
    end
    local store = Store()
    if S.pending then
        if not S.pending.loaded and X.clock - S.pending.at < WAIT then
            return
        end
        Read(store, S.pending.id)
        S.pending = nil
        return
    end
    local queue = Queue()
    while S.next <= #queue do
        local id = queue[S.next]
        S.next = S.next + 1
        if not (store.checked[id] or S.tried[id]) then
            S.tried[id] = true
            S.pending = { id = id, at = X.clock }
            C_QuestLog.RequestLoadQuestByID(id)
            return
        end
    end
end

-- QUEST_DATA_LOAD_RESULT: the answer for the quest asked about (success or not, it's read next tick).
function X.ScanLoaded(questID)
    if S.pending and S.pending.id == questID then
        S.pending.loaded = true
    end
end
end -- server quest levels
-- Quest givers often offer the next quest only after an earlier one with them, so a pick-up waits
-- while anything earlier on the route with that same person is still to do.
local function RouteStepActionable(step, byTitle, level, busyNpcs)
    if UTILITY[step.t] then
        return true
    end
    local turnedIn = TurnedIn(step.q)
    local part = tonumber(step.part) or 1
    local entry = HeldPart(byTitle, step)
    if step.t == "accept" then
        -- When the game's own prerequisites for this quest are known, they decide; the "busy giver"
        -- guess is only for quests nothing else is known about.
        local data = LevelGuidePrereqs
        local knownPrereqs = data and (data[step.q] or data[RealTitle(step.q)]) ~= nil
        return entry == nil and turnedIn == part - 1 and (not step.lvl or step.lvl <= level + 1)
            and (knownPrereqs or not busyNpcs[NpcKey(step.npc) or ""])
    elseif step.t == "do" then
        return entry ~= nil and not entry.ready and not (step.obj ~= nil and ObjectivesDone(entry.id, step.obj, step.objMax))
    end
    return entry ~= nil and entry.ready
end

-- A turn-in you don't hold yet whose pick-up is still ahead of you on this route: the person waiting
-- for it won't offer what comes after until it's done. Quests with no pick-up on this route (from
-- items or other zones) and pick-ups you skipped, outleveled or are past don't count, or they would
-- keep that person's later pick-ups hidden for good. Pick-ups themselves never count: a giver who
-- doesn't offer one may still offer another.
local function Gone(route, index, step, level, byTitle)
    if charData.skips[RouteKey(route, index)] or Outleveled(step, level) or not ClassMatches(step.cls) then
        return true
    end
    if HasIDs(step.q) then
        return false
    end
    local frontier = Frontier(route, byTitle)
    return frontier and index < frontier or false
end

local function StillOwed(route, index, step, level, byTitle)
    if step.t ~= "turnin" or InLog(byTitle, step.q) or Gone(route, index, step, level, byTitle) then
        return false
    end
    local part = tonumber(step.part) or 1
    if TurnedIn(step.q) >= part then
        return false
    end
    for earlier = index - 1, 1, -1 do
        local other = route.steps[earlier]
        if other.t == "accept" and other.q == step.q and (tonumber(other.part) or 1) == part then
            -- A quest that starts from a drop, an object or a notice may simply never have been found;
            -- it mustn't lock the person it's handed to.
            local giver = (other.npc or ""):lower()
            if giver:find("<", 1, true) or giver:find("drop", 1, true) or giver:find("object", 1, true)
                or giver:find("poster", 1, true) or giver:find("item", 1, true) then
                return false
            end
            return not Gone(route, earlier, other, level, byTitle)
        end
    end
    return false
end

-- Steps written as "Name, Darnassus" use the city's own map. They're moved onto the zone map through
-- world positions, so distances and the arrow work the same inside and outside the city.
local CITIES = { "Darnassus" }
local cityMaps, cityPoints = {}, {}

local function CityMap(zoneMap, city)
    local key = zoneMap .. ":" .. city
    -- Only a hit is remembered: the map list can be empty for a moment after a load.
    if cityMaps[key] == nil then
        for _, info in ipairs(C_Map.GetMapChildrenInfo and C_Map.GetMapChildrenInfo(zoneMap, nil, true) or {}) do
            if Safe(info.name) == city and Safe(info.mapID) then
                cityMaps[key] = Safe(info.mapID)
            end
        end
        -- On Forever's Classic maps the city is not under the zone but beside it, under the continent.
        cityMaps[key] = cityMaps[key] or FindMap(city)
    end
    return cityMaps[key]
end

local function CityToZone(zoneMap, step, x, y)
    -- "Name, Darnassus" outside parentheses; a note in parentheses ("ring to Tyrande, Darnassus") is not.
    local text = (step.npc or step.note or ""):gsub("%b()", "")
    local city
    for _, name in ipairs(CITIES) do
        if text:find(", " .. name, 1, true) then
            city = name
        end
    end
    if not city then
        return x, y
    end
    local key = zoneMap .. ":" .. city .. ":" .. x .. ":" .. y
    -- A point that couldn't be placed is tried again after a while (CityPoints keeps the time).
    local tried = cityPoints[key]
    if tried == nil or (type(tried) == "number" and Now() - tried >= 10) then
        local cityMap = CityMap(zoneMap, city)
        if cityMap then
            cityPoints[key] = Now()
        end
        if cityMap and C_Map.GetWorldPosFromMapPos and C_Map.GetMapPosFromWorldPos and CreateVector2D then
            local continent, world = C_Map.GetWorldPosFromMapPos(cityMap, CreateVector2D(x, y))
            if continent and world then
                local _, onZone = C_Map.GetMapPosFromWorldPos(continent, world, zoneMap)
                if onZone then
                    local zoneX, zoneY = onZone:GetXY()
                    cityPoints[key] = { Safe(zoneX), Safe(zoneY) }
                end
            end
        end
        if cityMap and not (type(cityPoints[key]) == "table" and cityPoints[key][1]) then
            local zoneX, zoneY = Project(cityMap, x, y, zoneMap)
            if zoneX then
                cityPoints[key] = { zoneX, zoneY }
            end
        end
    end
    local point = cityPoints[key]
    if type(point) == "table" and point[1] and point[2] then
        return point[1], point[2]
    end
    -- No conversion: better no point than one in the wrong place.
    return nil
end

-- Where a route point (map percent) goes on the live map: the step's own zone map (On()), or the route's
-- zone map with Darnassus points moved onto it. Nil when it can't be placed right now.
local function PlacePoint(step, zoneMap, x, y)
    if not (x and y) then
        return nil
    end
    if step.map then
        -- Written on another zone's map (Routes.lua On()): placed only while you're in that zone, never
        -- at the same numbers on the route's own map.
        local onMap = ZoneMap(step.map)
        if onMap then
            return onMap, x / 100, y / 100
        end
    elseif zoneMap then
        local zoneX, zoneY = CityToZone(zoneMap, step, x / 100, y / 100)
        if zoneX then
            return zoneMap, zoneX, zoneY
        end
    end
    return nil
end

-- The text a utility step shows under its title, with live progress where there is any.
local function UtilityDetail(step, level)
    local note = step.note and (" " .. step.note) or ""
    if step.t == "home" then
        return string.format("Talk to %s and make this inn your home.%s", tostring(step.npc or "the innkeeper"), note)
    elseif step.t == "fp" then
        return string.format("Talk to %s to learn the flight path.%s", tostring(step.npc or "the flight master"), note)
    elseif step.t == "item" then
        return string.format("Have %d/%d.%s", math.min(ItemCount(step.item), step.count or 1), step.count or 1, note)
    elseif step.t == "train" then
        return string.format("Learn it from %s.%s", tostring(step.npc or "your trainer"), note)
    elseif step.t == "xp" and (step.short or step.into) then
        local xp, maxXP = Safe(UnitXP("player")) or 0, MaxXP() or 0
        local want = step.short and (step.level - 1 == level) and math.max(maxXP - step.short, 0)
            or (step.into and step.level == level and step.into) or nil
        return string.format("Level %d, %d/%d XP%s. Kill mobs around you until then.%s", level or 0, xp, maxXP,
            want and string.format(" (need %d)", want) or "", note)
    elseif step.t == "xp" then
        local percent = math.floor(LevelFraction() * 100)
        return string.format("You're level %d at %d%%. Kill mobs around you until then.%s", level or 0, percent, note)
    elseif step.t == "buy" then
        local where = step.where == "ah" and ("the Auction House" .. (step.npc and (" (" .. step.npc .. ")") or ""))
            or tostring(step.npc or "a vendor")
        local need = step.count or 1
        return string.format("Have %d/%d. Buy at %s.%s", math.min(ItemCount(step.items), need), need, where, note)
    elseif step.t == "vendor" then
        return string.format("Visit %s: sell, repair and restock.%s", tostring(step.npc or "a vendor"), note)
    elseif step.t == "bags" then
        return string.format("%d/%d bag slots. Bags from %s or the Auction House.%s", BagSlots(), step.slots or 0,
            tostring(step.npc or "a general goods vendor"), note)
    elseif step.t == "trainer" then
        return string.format("Visit %s for your level %d spells.%s", tostring(step.npc or "your class trainer"), step.atLevel or 0, note)
    elseif step.t == "keep" then
        return string.format("Keep it: it's for %s later.%s", tostring(step.forQ or "a quest"), note)
    elseif step.t == "hearth" then
        -- Hearthstone (item 6948) cooldown, read only.
        local start, duration
        if C_Container and C_Container.GetItemCooldown then
            start, duration = C_Container.GetItemCooldown(6948)
            start, duration = Safe(start), Safe(duration)
        end
        local left = start and duration and duration > 0 and math.ceil((start + duration - GetTime()) / 60) or 0
        local bound = GetBindLocation and Safe(GetBindLocation())
        local where = bound and bound ~= "" and (" Your hearth is set to " .. bound .. ".") or ""
        if left > 0 then
            return string.format("Hearthstone ready in %d min: walk or fly instead.%s%s", left, where, note)
        end
        return string.format("Use your hearthstone.%s%s", where, note)
    end
    return step.note
end

-- Spawn camps for work steps (after Polestar's Spots, research\guides_deep_re.md 1.7 and 12.8; our own code):
-- a "do" step of a quest with QuestDB camps on its zone map points at a camp instead of the written spot,
-- chosen by Planner.PickCamp (nearest unchecked; a camp is checked once left, or after 7 s standing in it
-- without progress or a fight; checks are forgotten after 300 s). Per step, for this session.
do
X.campState = {}

-- Sets shown.campIndex / campCount / campRadius and returns the camp's x, y (map percent), or nil.
function X.CampPoint(shown, step, byTitle, zoneMap)
    local P = LevelGuidePlanner
    if not (P and zoneMap and step.t == "do" and not step.map and not step.pts) then
        return nil
    end
    local camps = X.Camps(X.QuestIDFor(step, byTitle), zoneMap, step.obj)
    local scale = #camps > 0 and MapScale(zoneMap)
    local px, py = PositionOn(zoneMap)
    if not (scale and px and py) then
        return nil
    end
    local distances = {}
    for i, camp in ipairs(camps) do
        distances[i] = Distance(zoneMap, px, py, camp.x, camp.y)
    end
    local key = shown.routeKey or step.q
    local state = X.campState[key] or {}
    X.campState[key] = state
    local progressed = X.progressAt ~= nil and X.progressAt ~= state.seenProgress
    state.seenProgress = X.progressAt
    local fighting = UnitAffectingCombat and Safe(UnitAffectingCombat("player")) or false
    local at = P.PickCamp(camps, distances, state, Now(),
        { progressed = progressed, fighting = fighting, x = px * scale[1], y = py * scale[2] })
    local camp = at and camps[at]
    if not camp then
        return nil
    end
    shown.campIndex, shown.campCount, shown.campRadius = at, #camps, camp.r
    shown.detail = (shown.detail and (shown.detail .. " ") or "") .. string.format("(camp %d of %d)", at, #camps)
    return camp.x * 100, camp.y * 100
end
end -- spawn camps

local function RouteDisplay(route, index, step, byTitle, zoneMap)
    local entry = step.q and HeldPart(byTitle, step)
    local level = Safe(UnitLevel("player"))
    local shown = {
        kind = ROUTE_KINDS[step.t], title = step.q or step.text, routeKey = RouteKey(route, index),
        id = entry and entry.id, zone = route.zone, npc = NpcKey(step.npc), quest = step.q, stepType = step.t, questPart = step.part,
    }
    if step.t == "accept" then
        shown.detail = "From " .. tostring(step.npc or "?")
    elseif step.t == "turnin" then
        shown.detail = "To " .. tostring(step.npc or "?")
    elseif step.t == "do" then
        -- A per-objective step talks about its own objectives only.
        local progress = entry and (step.obj ~= nil and ObjectiveText(entry.id, step.obj) or FirstUnfinished(entry.id))
        shown.detail = progress and step.note and (step.note .. ". Now: " .. progress) or progress or step.note
    elseif UTILITY[step.t] and step.t ~= "go" and step.t ~= "zone" then
        shown.detail = UtilityDetail(step, level)
        if step.t == "xp" and (step.short or step.into) then
            shown.title = step.text
        elseif step.t == "xp" then
            shown.title = string.format("%d%% into level %d", math.floor((step.frac or 0) * 100 + 0.5), step.level)
        end
    else
        shown.detail = step.note
    end
    if entry then
        shown.xp = RewardXP(entry.id)
    end
    -- For the XP projection and ordering: where on the route, the quest's level, what it's worth to you now.
    shown.stepIndex = index
    shown.inside = step.inside   -- in a building (X.HubOrder)
    if step.q then
        local questID = X.QuestIDFor(step, byTitle)
        local logLevel
        if entry and entry.logIndex then
            local info = C_QuestLog.GetInfo(entry.logIndex)
            logLevel = info and (Safe(info.difficultyLevel) or Safe(info.level))
        end
        shown.questLevel = X.QuestLevel(questID, logLevel)
        local full = (step.t == "accept" or step.t == "turnin") and LevelGuidePlanner and questID and LevelGuidePlanner.QuestXP(questID)
        shown.xpValue = (step.t == "turnin" and shown.xp and shown.xp > 0 and shown.xp)
            or (full and level and math.floor(full * LevelGuidePlanner.Share(level, shown.questLevel) + 0.5)) or nil
    end
    local x, y = step.x, step.y
    -- Several points (Routes.lua Path()): the arrow takes them in order; the next one is remembered per step.
    -- Loop() goes round and round (a grind circuit) until the step is done its own way; Nearest() points
    -- at the closest of several spawn spots, other than the one you just checked.
    if step.pts and #step.pts > 0 then
        local count = #step.pts
        local saved = tonumber(charData.points[shown.routeKey])
        local at = math.min(math.max(saved or 1, 1), count)
        if step.mode == "nearest" then
            local px, py
            if zoneMap and not step.map then
                px, py = PositionOn(zoneMap)
            end
            local best
            for index, point in ipairs(step.pts) do
                if index ~= saved or count == 1 then
                    local d = px and ((point[1] / 100 - px) ^ 2 + (point[2] / 100 - py) ^ 2) or index
                    if not best or d < best then
                        best, at = d, index
                    end
                end
            end
        end
        x, y = step.pts[at][1], step.pts[at][2]
        shown.pointIndex, shown.pointCount, shown.pointMode = at, count, step.mode
        shown.detail = (shown.detail and (shown.detail .. " ") or "")
            .. (step.mode == "nearest" and string.format("(nearest of %d spots)", count)
                or string.format(step.mode == "loop" and "(loop point %d of %d)" or "(point %d of %d)", at, count))
        -- The other points for the map: in order, only those still ahead; loop/nearest, all the others.
        shown.morePoints = {}
        for later = step.mode and 1 or at + 1, count do
            if later ~= at then
                local mapID, laterX, laterY = PlacePoint(step, zoneMap, step.pts[later][1], step.pts[later][2])
                if mapID then
                    shown.morePoints[#shown.morePoints + 1] = { mapID = mapID, x = laterX, y = laterY, index = later }
                end
            end
        end
    elseif step.t == "do" and entry then
        -- A quest you hold with spawn camps on this map: the arrow takes them in a circuit.
        local campX, campY = X.CampPoint(shown, step, byTitle, zoneMap)
        if campX then
            x, y = campX, campY
        end
    end
    shown.mapID, shown.x, shown.y = PlacePoint(step, zoneMap, x, y)
    -- Where it is in any case, for the travel planner when you're on another map (X.ApplyTravel).
    shown.goalMap, shown.goalX, shown.goalY = X.GoalOf(route, step, x, y)
    return shown
end

-- A pick-up hidden only because its prerequisites (a level, an earlier quest) aren't met yet is still
-- work this route owes you, so the route isn't finished while one remains.
local function RouteStepPending(route, index, step, byTitle, level)
    if step.t ~= "accept" or charData.skips[RouteKey(route, index)] or InLog(byTitle, step.q) or not ClassMatches(step.cls) then
        return false
    end
    if Outleveled(step, level) then
        return false
    end
    return TurnedIn(step.q) < (tonumber(step.part) or 1) and not PrereqsMet(step.q, level)
end

local function RouteUnfinished(route, byTitle, level)
    for index, step in ipairs(route.steps) do
        if not step.side and (not RouteStepDone(route, index, step, byTitle, level) or RouteStepPending(route, index, step, byTitle, level)) then
            return true
        end
    end
    return false
end

-- Something on the route you can do right now. A route whose only open steps are pick-ups you're too
-- low for (or whose earlier quest isn't done) is unfinished, but has nothing for you yet.
local function RouteHasWork(route, byTitle, level)
    for index, step in ipairs(route.steps) do
        if not step.side and not RouteStepDone(route, index, step, byTitle, level)
            and (step.t ~= "accept" or RouteStepActionable(step, byTitle, level, {})) then
            return true
        end
    end
    return false
end

-- The level the route's next pick-up is waiting for: the lowest level that opens one of its pick-ups
-- you could otherwise take (earlier quests done, not skipped, not outleveled). Nil when nothing waits
-- on your level. The guide uses the higher of the game's minimum level and the route's own level
-- (a pick-up shows from one level below it, see RouteStepActionable).
local function LevelBlocker(route, byTitle, level)
    local best, bestNeed, bestIndex
    local data = LevelGuidePrereqs
    for index, step in ipairs(route.steps) do
        local part = tonumber(step.part) or 1
        if step.t == "accept" and not charData.skips[RouteKey(route, index)] and not InLog(byTitle, step.q) and ClassMatches(step.cls)
            and TurnedIn(step.q) == part - 1 and not Outleveled(step, level)
            and PrereqsMet(step.q, nil) then
            local need = data and (data[step.q] or data[RealTitle(step.q)])
            local needLevel = math.max(need and need.level or 0, step.lvl and step.lvl - 1 or 0)
            if needLevel > level and (not bestNeed or needLevel < bestNeed) then
                best, bestNeed, bestIndex = step, needLevel, index
            end
        end
    end
    return best, bestNeed, bestIndex
end

-- Returns the route to follow and, when the zone you're standing in was passed over because all it has
-- left waits on your level, that zone's route (so the guide can say why it sends you elsewhere).
local FindRoute
do -- route choice helpers
-- A route is "here" when you stand in its zone, or, for a leg spanning several (Routes.lua Leg(): the
-- Night Elf trip through Stormwind, Ironforge and Loch Modan), in any of them.
local function RouteHere(route)
    if ZoneMap(route.zone) then
        return true
    end
    for _, zone in ipairs(route.zones or {}) do
        if ZoneMap(zone) then
            return true
        end
    end
    return false
end

-- A leg is under way once one of its pick-ups is in your log or turned in (the part it names: holding
-- part 1 of a chain doesn't start the leg that takes part 2).
local function LegStarted(route, byTitle)
    for index, step in ipairs(route.steps) do
        if step.t == "accept" and not charData.skips[RouteKey(route, index)] and ClassMatches(step.cls) then
            local part = tonumber(step.part) or 1
            local held = InLog(byTitle, step.q)
            if TurnedIn(step.q) >= part or (held and (held.part or 1) == part) then
                return true
            end
        end
    end
    return false
end

-- Legs (Routes.lua Leg()) are a plan in order: once a later leg is under way, the earlier ones are behind
-- you, whatever they have left, so the guide never sends you back across the sea for a leftover.
local function PassedLegs(routes, byTitle)
    local passed, laterStarted = {}, false
    for index = #routes, 1, -1 do
        local route = routes[index]
        if route.leg then
            if laterStarted then
                passed[route] = true
            elseif LegStarted(route, byTitle) then
                laterStarted = true
            end
        end
    end
    return passed
end

function FindRoute(level, byTitle)
    local chains = RoutesForYou() and LevelGuideRoutes and LevelGuideRoutes.chains
    local race = UnitRace and Safe(select(2, UnitRace("player")))
    local all = chains and race and chains[race] or {}
    local passed = PassedLegs(all, byTitle)
    local routes = {}
    for _, route in ipairs(all) do
        if not passed[route] then
            routes[#routes + 1] = route
        end
    end
    -- The zone you're standing in comes first once you're its level: a few leftover steps in the
    -- zone before shouldn't keep the guide pointing back there.
    -- ZoneMap climbs from the map you're on (a town, a cave, a city) to its zone, so standing in
    -- Darnassus or Dolanaar still counts as Teldrassil.
    -- In a zone the plan puts you in for your level (Zephras Isle for a Skyborne under 13, Elwynn for a
    -- Human under 11), routes that start a couple of levels above you wait until you reach them.
    -- A race's own start (PLAN `race`, Zephras Isle for Skyborne) holds until its max level while you're
    -- there: no route elsewhere is chosen, however near its level.
    local early = 2
    for _, entry in ipairs(PlanEntries()) do
        if level >= entry.min and level < entry.max then
            for _, zone in ipairs(entry.zones or {}) do
                if ZoneMap(zone) or MapNamed(zone) then
                    if entry.race then
                        return nil
                    end
                    early = 0
                end
            end
        end
    end
    local stuckHere
    for _, route in ipairs(routes) do
        if level >= route.min and level <= route.max and RouteHere(route) and RouteUnfinished(route, byTitle, level) then
            if RouteHasWork(route, byTitle, level) then
                return route
            end
            stuckHere = stuckHere or route
        end
    end
    -- Nothing to do here until you level: zones of the same levels (Ashenvale, Wetlands and Duskwood are
    -- all 20-30) have work for you now, so the next one in the chain that does comes before grinding.
    -- Before this, the guide stayed in the zone you stood in with nothing to show until its max level.
    for _, route in ipairs(routes) do
        -- A zone more than a couple of levels above you waits, even when the ones before it are done.
        if level <= route.max and level >= route.min - early and RouteHasWork(route, byTitle, level) then
            return route, stuckHere
        end
    end
    if stuckHere then
        return stuckHere
    end
    for _, route in ipairs(routes) do
        if level <= route.max and level >= route.min - early and RouteUnfinished(route, byTitle, level) then
            return route
        end
    end
end
end -- route choice helpers

-- The plan's dungeon hint for your level, if any.
local function PlanNote(level)
    for _, entry in ipairs(PlanEntries()) do
        if level >= entry.min and level < entry.max then
            return entry.note
        end
    end
end

-- Under-leveled: the route's next pick-up needs a higher level than yours and nothing else on it can be
-- done now. Say so plainly, pointing at the quest giver, instead of an empty or puzzling list.
local function LevelStep(route, byTitle, level, zoneMap)
    local step, need, index = LevelBlocker(route, byTitle, level)
    if not step then
        return nil
    end
    local shown = RouteDisplay(route, index, step, byTitle, zoneMap)
    shown.kind = "level"
    shown.title = string.format("%d for %s", need, step.q)
    local note = PlanNote(level)
    shown.detail = string.format("Needs level %d, you're %d. Finish the quests you have, or kill mobs around your level nearby until then. Then pick it up from %s.%s",
        need, level, tostring(step.npc or "?"), note and (" " .. note .. ".") or "")
    return shown
end

-- The way into a route's zone from where you are, always as a stop with an arrow when it can be placed:
-- 1. the route's own ways (Routes.lua Way(): a way the planner can't know, e.g. a road through a pass),
-- 2. else the travel planner's next leg toward the route's next stop (X.ApplyTravel, from goalMap/X/Y),
-- 3. else the route's next step itself, straight across the map (same continent),
-- 4. else (another continent, no way known) just the zone's name.
function TravelTo(route, why, byTitle, level)
    local travel = { kind = "travel", title = route.name or route.zone, detail = why, zone = route.zone, why = why }
    for _, way in ipairs(route.ways or {}) do
        local fromMap = MapNamed(way.from)
        if fromMap and way.x and way.y then
            travel.title = way.text
            travel.detail = (way.note and (way.note .. ". ") or "") .. why
            travel.mapID, travel.x, travel.y = fromMap, way.x / 100, way.y / 100
            travel.wayKey = (route.key or route.zone) .. "|way|" .. way.from
            return travel
        end
    end
    for index, step in ipairs(route.steps) do
        if step.x and step.y and not step.side and not RouteStepDone(route, index, step, byTitle, level) then
            -- The planner aims at the next stop, on its own map (On()) or the route's.
            travel.goalMap, travel.goalX, travel.goalY = X.GoalOf(route, step, step.x, step.y)
            local zoneMap = not step.map and FindMap(route.zone)
            local x, y
            if zoneMap then
                x, y = CityToZone(zoneMap, step, step.x / 100, step.y / 100)
            end
            if x and PositionOn(zoneMap) then
                travel.mapID, travel.x, travel.y = zoneMap, x, y
                travel.detail = why .. ". The arrow points at the route's next stop there"
            end
            break
        end
    end
    if not travel.goalMap then
        travel.goalMap, travel.goalX, travel.goalY = X.GoalOf(route, nil, 50, 50)
    end
    return travel
end

-- Side steps in play (Routes.lua Sticky/Later): shown beside the current step, never as it.
-- * "sticky" (on the way): from where it's written, while any of the next `span` route steps is still to
--   do, e.g. "kill boars while you do the next 3 steps". Done by its own state (an objective, items).
-- * "later": shopping (vendor or auction house), bags, items to keep, trainer visits. From where it's
--   written (or from its level, for trainer visits) until done; each is done by watching only.
function SideSteps(route, byTitle, level, zoneMap, windowEnd)
    local sticky, later = {}, {}
    for index, step in ipairs(route.steps) do
        if step.side and not RouteStepDone(route, index, step, byTitle, level) then
            local inPlay
            if step.atLevel then
                inPlay = level ~= nil and level >= step.atLevel
            else
                inPlay = index <= windowEnd and not (step.lvl and level and step.lvl > level + 2)
            end
            if inPlay and step.side == "sticky" then
                inPlay = false
                local seen = 0
                for nextIndex = index + 1, #route.steps do
                    local other = route.steps[nextIndex]
                    if not other.side then
                        seen = seen + 1
                        if seen > (step.span or 1) then
                            break
                        end
                        if not RouteStepDone(route, nextIndex, other, byTitle, level) then
                            inPlay = true
                            break
                        end
                    end
                end
            end
            if inPlay then
                local shown = RouteDisplay(route, index, step, byTitle, zoneMap)
                shown.side = step.side
                local list = step.side == "sticky" and sticky or later
                list[#list + 1] = shown
            end
        end
    end
    for _, shown in ipairs(later) do
        sticky[#sticky + 1] = shown
    end
    return sticky
end

local function RouteSteps(level)
    if not charData then
        return nil
    end
    -- Old index keys written while this session runs (or left from before) move to stable keys.
    MigrateCharacter(charData)
    FillFromDB()
    local byTitle = LogByTitle()
    lastByTitle = byTitle
    local route, stuckHere = FindRoute(level, byTitle)
    X.projection = nil
    if not route then
        return nil
    end
    X.Project(route, byTitle, level)
    local zoneMap = ZoneMap(route.zone)
    lastZoneMap = zoneMap
    if not zoneMap then
        -- Not in the route's zone: what's around you here still comes first, then the way back.
        local mapID, playerX, playerY = PlayerPosition()
        local here = ReadQuests(mapID)
        for _, offer in ipairs(ReadOffers(mapID)) do
            here[#here + 1] = offer
        end
        local list = Route(here, mapID, playerX, playerY)
        local why = "Your route continues there"
        local need
        if stuckHere then
            need = select(2, LevelBlocker(stuckHere, byTitle, level))
        end
        if need then
            why = string.format("%s's next quests need level %d, you're %d. %s has quests for you now",
                stuckHere.zone, need, level, route.zone)
        end
        local written, writtenEnd = {}, 0
        for index, step in ipairs(route.steps) do
            if #written >= K.MAX_NEXT then
                break
            end
            if not step.side and not RouteStepDone(route, index, step, byTitle, level)
                and (step.t ~= "accept" or RouteStepActionable(step, byTitle, level, {})) then
                written[#written + 1] = RouteDisplay(route, index, step, byTitle, nil)
                writtenEnd = index
            end
        end
        -- A route leg written on this map (Routes.lua On(), e.g. Duskwood's Sven leg in Stormwind) is
        -- done here: no "go back" line before it.
        if not (written[1] and written[1].mapID) then
            list[#list + 1] = TravelTo(route, why, byTitle, level)
        end
        for _, shown in ipairs(written) do
            list[#list + 1] = shown
        end
        if #written == 0 then
            list[#list + 1] = LevelStep(route, byTitle, level, nil)
        end
        sideSteps = SideSteps(route, byTitle, level, nil, writtenEnd)
        return list, route
    end

    -- The written order is a good plan, but what you can do right now, nearby, should come first:
    -- the next several steps are reordered by distance and XP, up to the next "go" step, which marks
    -- a move the route wants made in order.
    local ready, waiting = {}, {}
    local busyNpcs = {}
    local considered = 0
    -- How far down the route this rebuild looked: side steps written up to here are in play.
    local windowEnd = #route.steps
    for index, step in ipairs(route.steps) do
        if step.side then -- luacheck: ignore 542
            -- Shown beside the steps (SideSteps), never one of them.
        elseif not RouteStepDone(route, index, step, byTitle, level) then
            -- A move (go, reach a zone) or an XP gate: it comes first, or ends the window.
            if BARRIER[step.t] and considered == 0 then
                -- The move comes first; what follows it stays in written order behind it.
                ready[1] = RouteDisplay(route, index, step, byTitle, zoneMap)
                for nextIndex = index + 1, #route.steps do
                    if #waiting >= K.MAX_NEXT then
                        break
                    end
                    local nextStep = route.steps[nextIndex]
                    if not nextStep.side and not RouteStepDone(route, nextIndex, nextStep, byTitle, level)
                        and (nextStep.t ~= "accept" or RouteStepActionable(nextStep, byTitle, level, {})) then
                        waiting[#waiting + 1] = RouteDisplay(route, nextIndex, nextStep, byTitle, zoneMap)
                    end
                end
                windowEnd = index
                break
            end
            if BARRIER[step.t] then
                waiting[#waiting + 1] = RouteDisplay(route, index, step, byTitle, zoneMap)
                windowEnd = index
                break
            end
            local shown = RouteDisplay(route, index, step, byTitle, zoneMap)
            local actionable = RouteStepActionable(step, byTitle, level, busyNpcs) and shown.x
            -- A pick-up you can't take yet isn't shown at all: it would only send you to someone
            -- with nothing to give you. Only what's shown uses up the window.
            local visible = actionable or step.t ~= "accept"
            if considered >= K.ROUTE_WINDOW then
                if visible then
                    waiting[#waiting + 1] = shown
                    windowEnd = index
                    break
                end
            else
                if actionable then
                    ready[#ready + 1] = shown
                elseif visible then
                    waiting[#waiting + 1] = shown
                end
                if visible then
                    considered = considered + 1
                end
            end
            -- Only a turn-in still to do holds a giver's later quests back; a pick-up never does, or a
            -- hub would show one quest per person and an under-level one would hide the rest.
            local npc = step.t == "turnin" and NpcKey(step.npc) or nil
            if npc then
                busyNpcs[npc] = true
            end
        elseif StillOwed(route, index, step, level, byTitle) then
            -- Not shown, because you don't have that quest, but it isn't turned in either: a quest giver
            -- waiting on it won't offer what comes after, so their later pick-ups wait too.
            local npc = NpcKey(step.npc)
            if npc then
                busyNpcs[npc] = true
            end
        end
    end
    sideSteps = SideSteps(route, byTitle, level, zoneMap, windowEnd)
    -- The route is a plan, not the whole truth: quests in your log it doesn't know (or hasn't reached
    -- yet) and "!" quests the map shows that it doesn't list are on offer too, so they join the pool.
    local known = {}
    -- A quest whose part for here is done ("kill 8 here, the rest later") is known too: hidden by the
    -- route on purpose, it mustn't come back as an extra from the map.
    for _, step in ipairs(route.steps) do
        if step.t == "do" and step.obj then
            local entry = HeldPart(byTitle, step)
            if entry and entry.id and ObjectivesDone(entry.id, step.obj, step.objMax) then
                known[entry.id] = true
            end
        end
    end
    for _, group in ipairs({ ready, waiting }) do
        for _, shown in ipairs(group) do
            if shown.id then
                known[shown.id] = true
            end
            if shown.title then
                -- The map's "!" list uses Forever's name, the route may use the old one.
                known[shown.title] = true
                known[RealTitle(shown.title)] = true
            end
        end
    end
    local here, away = ReadQuests(zoneMap)
    for _, offer in ipairs(ReadOffers(zoneMap)) do
        here[#here + 1] = offer
    end
    -- Quests you hold for other zones aren't forgotten: they wait at the end as a trip.
    for _, trip in ipairs(TravelSteps(away)) do
        waiting[#waiting + 1] = trip
    end
    -- Quests taken off the route are fitted into it (X.FitPending); one whose place on the route isn't
    -- reached yet waits behind the route's steps.
    X.FitPending(route, byTitle, level, zoneMap)
    for _, extra in ipairs(here) do
        if not known[extra.id] and not (extra.kind == "pickup" and known[extra.title]) then
            known[extra.id] = true
            if X.ExtraWaits(extra, route, byTitle, level) then
                waiting[#waiting + 1] = extra
            else
                ready[#ready + 1] = extra
            end
        end
    end
    local playerX, playerY = PositionOn(zoneMap)
    if playerX and playerY then
        ready = X.HubOrder(Route(ready, zoneMap, playerX, playerY), zoneMap)
    end
    local list = ready
    for _, shown in ipairs(waiting) do
        list[#list + 1] = shown
    end
    -- Nothing on the route you can do at your level: say what it waits for. Quests in your log come
    -- first (they're the way to the level); otherwise this is the step, with the arrow on the giver.
    if not RouteHasWork(route, byTitle, level) then
        local wait = LevelStep(route, byTitle, level, zoneMap)
        if wait then
            table.insert(list, math.min(#ready + 1, 2), wait)
        end
    end
    return list, route
end

local function PlanFor(level)
    for _, entry in ipairs(PlanEntries()) do
        if level >= entry.min and level < entry.max then
            return entry
        end
    end
end

-- Without a written route for your level, the plan says which zones to head for.
local function PlanStep(level, mapID)
    local plan = PlanFor(level)
    if not plan then
        return nil
    end
    local here = mapID and ZoneName(mapID)
    for _, zone in ipairs(plan.zones) do
        if zone == here then
            return nil
        end
    end
    local detail = plan.hub .. (plan.note and (". " .. plan.note) or "")
    local travel = { kind = "travel", title = table.concat(plan.zones, " or "), detail = detail, zone = plan.zones[1] }
    -- The planner (X.ApplyTravel) aims at the middle of the first zone.
    travel.goalMap, travel.goalX, travel.goalY = X.MapIDNamed(plan.zones[1]), 50, 50
    -- The middle of the first zone that's on your continent, so the arrow has somewhere to point.
    for _, zone in ipairs(plan.zones) do
        local zoneMap = FindMap(zone)
        if zoneMap and PositionOn(zoneMap) then
            travel.mapID, travel.x, travel.y, travel.zone = zoneMap, 0.5, 0.5, zone
            break
        end
    end
    return travel
end

-- Following the route, which turn-in takes you past the end of this level.
local function MarkLevelUp(list)
    local xp, maxXP = Safe(UnitXP("player")), MaxXP()
    if not (xp and maxXP) then
        return
    end
    local needed = maxXP - xp
    for _, step in ipairs(list) do
        if step.kind == "turnin" and step.xp and step.xp > 0 then
            needed = needed - step.xp
            if needed <= 0 then
                step.dings = true
                return
            end
        end
    end
end

-- XP waiting in ready turn-ins, and that as a share of your level (nil when none).
local function ReadyShare(list)
    local total, maxXP = 0, MaxXP()
    for _, step in ipairs(list) do
        if step.kind == "turnin" then
            total = total + (step.xp or 0)
        end
    end
    return maxXP and total > 0 and math.floor(total * 100 / maxXP) or nil, total
end

-- A running timed quest goes to the top, whatever the route says; a failed one asks to be redone.
local function PutTimedFirst(list)
    for index = 1, Safe(C_QuestLog.GetNumQuestLogEntries()) or 0 do
        local info = C_QuestLog.GetInfo(index)
        local id, title = info and Safe(info.questID), info and Safe(info.title)
        if id and title and not Safe(info.isHeader) and not Safe(info.isHidden) and not db.skipped[id]
            and not Recent(recentTurnins, id, TURNIN_GRACE) then
            local failed = C_QuestLog.IsFailed and Safe(C_QuestLog.IsFailed(id))
            local ends = not failed and TimerEnds(id)
            if failed then
                -- Abandoned after failing, it simply goes back (no "lost" card).
                X.failedSeen = X.failedSeen or {}
                X.failedSeen[id] = true
            end
            if failed or ends then
                local step
                for position = #list, 1, -1 do
                    local other = list[position]
                    if other.id == id and (other.kind == "turnin" or other.kind == "work") then
                        step = table.remove(list, position)
                    end
                end
                local ready = Safe(C_QuestLog.IsComplete(id)) or Safe(C_QuestLog.ReadyForTurnIn(id))
                step = step or { kind = ready and "turnin" or "work", title = title, id = id }
                if failed then
                    step.kind = "work"
                    step.detail = COLOR_ALERT .. "Failed.|r Abandon it in your quest log, then pick it up again"
                    step.mapID, step.x, step.y = nil, nil, nil
                else
                    step.timerEnds = ends
                    step.detail = COLOR_ALERT .. "Timed, don't stop on the way.|r " .. (step.detail or "")
                    if not timedWarned[id] then
                        timedWarned[id] = true
                        Warn()
                    end
                end
                table.insert(list, 1, step)
            end
        end
    end
end

-- The step picked in the route list goes first (the arrow points at it) until it's done or skipped.
local function PutFocusFirst(list, level)
    if not (focusKey and activeRoute and lastByTitle) then
        focusKey = nil
        return
    end
    for index, step in ipairs(activeRoute.steps) do
        if RouteKey(activeRoute, index) == focusKey then
            if RouteStepDone(activeRoute, index, step, lastByTitle, level) then
                break
            end
            for position = #list, 1, -1 do
                if list[position].routeKey == focusKey then
                    table.remove(list, position)
                end
            end
            local shown = RouteDisplay(activeRoute, index, step, lastByTitle, lastZoneMap)
            shown.focused = true
            table.insert(list, 1, shown)
            return
        end
    end
    focusKey = nil
end

local function BuildSteps()
    local mapID, playerX, playerY = PlayerPosition()
    local level = Safe(UnitLevel("player")) or 1
    local routed
    sideSteps = {}
    X.projection = nil
    routed, activeRoute = RouteSteps(level)
    if routed then
        PutFocusFirst(routed, level)
        X.PutLostFirst(routed)
        PutTimedFirst(routed)
        MarkLevelUp(routed)
        X.MarkHard(routed)
        return routed, mapID, playerX, playerY, nil
    end
    local here, away, unplaced, later = ReadQuests(mapID)
    for _, offer in ipairs(ReadOffers(mapID)) do
        here[#here + 1] = offer
    end
    local list = Route(here, mapID, playerX, playerY)
    for _, step in ipairs(unplaced) do
        list[#list + 1] = step
    end
    local travel = TravelSteps(away)
    -- Gray quests are barely worth the walk, so when that's all that's left here, move on first.
    local onlyGray = #travel > 0
    for _, step in ipairs(list) do
        if not step.trivial then
            onlyGray = false
        end
    end
    if onlyGray then
        travel[1].detail = travel[1].detail .. ". What's left here is gray"
        table.insert(list, 1, table.remove(travel, 1))
    end
    for _, step in ipairs(travel) do
        list[#list + 1] = step
    end
    local plan = PlanStep(level, mapID)
    if plan then
        table.insert(list, 1, plan)
    end
    PutTimedFirst(list)
    MarkLevelUp(list)
    return list, mapID, playerX, playerY, later
end

local function ChoresText(later)
    local parts = {}
    if later and #later > 0 then
        table.sort(later)
        parts[#parts + 1] = string.format("%d quest(s) for level %d+", #later, later[1] - K.HARD_LEVELS + 1)
    end
    for _, name in ipairs(CHORES) do
        local source = ForeverHubStatus and ForeverHubStatus[name]
        if source then
            local ok, items = pcall(source)
            for _, item in ipairs(ok and items or {}) do
                parts[#parts + 1] = item.text
            end
        end
    end
    return #parts > 0 and ("Also: " .. table.concat(parts, COLOR_DIM .. "  |  |r")) or nil
end

local function StepLine(step)
    local kind = KINDS[step.kind]
    local tags = ""
    if step.dings then
        tags = tags .. " |cff33ff33Level up!|r"
    end
    if step.group and step.group > 1 then
        tags = tags .. string.format(" |cffff8040Group %d|r", step.group)
    end
    if step.focused then
        tags = tags .. " |cff66ccff(picked)|r"
    end
    if step.hard then
        tags = tags .. string.format(" |cffff4040Hard (level %d)|r", step.hard)
    end
    -- A travel leg (X.ApplyTravel) reads "Travel: Take the boat at ...", not "Go to: Take ...".
    return kind.color .. (step.leg and step.kind == "travel" and "Travel" or kind.label) .. ":|r " .. tostring(step.title) .. tags
end

local function DistanceText(step, mapID, playerX, playerY)
    if not (step.x and playerX and step.mapID == mapID) then
        return ""
    end
    local yards, isYards = Distance(mapID, playerX, playerY, step.x, step.y)
    return isYards and string.format("%s%d yd|r", COLOR_DIM, math.floor(yards)) or ""
end

local function MarkStep(step)
    if not step then
        return
    end
    if (step.kind == "pickup" or (step.routeKey and not step.id) or (step.kind == "travel" and not step.firstQuest))
        and step.mapID and step.x then
        ForeverWaypoint_Set(step.mapID, step.x, step.y, step.title or step.id)
    elseif C_SuperTrack and C_SuperTrack.SetSuperTrackedQuestID then
        local questID = step.kind == "travel" and step.firstQuest or step.id
        if questID then
            C_SuperTrack.SetSuperTrackedQuestID(questID)
        end
    end
end

-- Skips are deliberate (Shift+right-click) and undoable (right-click the header), since a stray
-- click used to drop a step with no way back but clearing every skip.
local skipHistory = {}
local skipNotice
local SKIP_NOTICE_SECONDS = 10

local function SkipStep(step)
    if not step then
        return
    end
    if step.routeKey and charData then
        charData.skips[step.routeKey] = true
        skipHistory[#skipHistory + 1] = { routeKey = step.routeKey }
    elseif step.id then
        db.skipped[step.id] = true
        skipHistory[#skipHistory + 1] = { id = step.id }
    else
        return
    end
    skipNotice = { text = "Skipped " .. (step.title or "a step") .. ". Right-click here to undo.", until_ = GetTime() + SKIP_NOTICE_SECONDS }
    dirty = true
end

local function UndoSkip()
    local last = table.remove(skipHistory)
    if last then
        if last.keys and charData then
            -- A quest skipped with its follow-ups (X.SkipQuest) comes back in one go.
            for _, key in ipairs(last.keys) do
                charData.skips[key] = nil
            end
        elseif last.routeKey and charData then
            charData.skips[last.routeKey] = nil
        elseif last.id then
            db.skipped[last.id] = nil
        end
        skipNotice = nil
        dirty = true
        return true
    end
    return false
end

local function UndoAllSkips()
    db.skipped = {}
    if charData then
        charData.skips = {}
    end
    skipHistory, skipNotice = {}, nil
    dirty = true
end

-- Lost and extra quests (research\guides_deep_re.md 1.5 and 12.10; our own code after Polestar's holdLost /
-- SkipQuest and Leveldon's fitting of extra quests, both described there):
-- * A route quest that leaves your log without a turn-in (QUEST_REMOVED, decided at the next rebuild so a
--   turn-in event has had its say) is "lost": a card asks "go back or skip", and until you answer its
--   pick-up comes first, so the arrow points at the giver. A failed quest you abandon just goes back.
--   "Skip it" skips its steps and its follow-ups (later parts of the title, and pick-ups whose
--   prerequisites need it), undone together by one right-click on the header. Taking it again answers too.
-- * A quest you take that the route doesn't have is fitted 1 s later (its places arrive late): its work
--   after the first upcoming stop within 250 yd of one of its QuestDB camps, its turn-in after the first stop
--   from there within 80 yd of where it's handed in (Planner.Fit). Until the route gets there it waits
--   behind the route's steps; if it fits nowhere it says "Not on your route". Saved per character until the
--   quest leaves your log.
do
local function Clock()
    return (time and Safe(time())) or Now()
end

-- The route (active first, then your race's chain) and index of the pick-up of this quest ID.
function X.FindAccept(questID)
    local race = UnitRace and Safe(select(2, UnitRace("player")))
    local chains = LevelGuideRoutes and LevelGuideRoutes.chains
    local routes = { activeRoute }
    for _, route in ipairs(race and chains and chains[race] or {}) do
        routes[#routes + 1] = route
    end
    for _, route in ipairs(routes) do
        for index, step in ipairs(route and rawget(route, "steps") or {}) do
            if step.t == "accept" and step.q and X.QuestIDFor(step, nil) == questID then
                return route, index
            end
        end
    end
end

function X.QuestRemoved(questID)
    X.removed = X.removed or {}
    X.removed[questID] = { failed = X.failedSeen and X.failedSeen[questID] }
    if charData and charData.extras then
        charData.extras[questID] = nil
    end
end

function X.ResolveRemoved()
    if not (X.removed and charData) then
        return
    end
    for questID, info in pairs(X.removed) do
        X.removed[questID] = nil
        if not (Recent(recentTurnins, questID, TURNIN_GRACE) or Flagged(questID) or info.failed) then
            local route, index = X.FindAccept(questID)
            if route then
                charData.lost = charData.lost or {}
                charData.lost[questID] = { q = route.steps[index].q, part = route.steps[index].part, t = Clock() }
            end
        end
    end
end

-- A quest accepted: no longer lost; off the route, to be fitted.
function X.Accepted(questID)
    if not charData then
        return
    end
    if charData.lost then
        charData.lost[questID] = nil
    end
    if not X.FindAccept(questID) then
        local title = C_QuestLog.GetTitleForQuestID and Safe(C_QuestLog.GetTitleForQuestID(questID))
        local onRoute = false
        for _, step in ipairs(title and activeRoute and activeRoute.steps or {}) do
            onRoute = onRoute or step.q == title or RealTitle(step.q or "") == title
        end
        if not onRoute then
            X.pendingFit = X.pendingFit or {}
            X.pendingFit[questID] = Now()
        end
    end
end

-- The first lost quest still waiting for an answer, if any.
function X.Lost()
    local questID, lost = next(charData and charData.lost or {})
    if questID and lastByTitle then
        for _, entry in pairs(lastByTitle) do
            if entry.id == questID then
                -- Taken again.
                charData.lost[questID] = nil
                return X.Lost()
            end
        end
    end
    return questID, lost
end

-- While a lost quest waits for an answer its pick-up goes first.
function X.PutLostFirst(list)
    local questID = X.Lost()
    local route, index = questID and activeRoute and X.FindAccept(questID)
    if not (route == activeRoute and index and lastByTitle) then
        return
    end
    local key = RouteKey(route, index)
    for position = #list, 1, -1 do
        if list[position].routeKey == key then
            table.remove(list, position)
        end
    end
    local shown = RouteDisplay(route, index, route.steps[index], lastByTitle, lastZoneMap)
    shown.detail = "You dropped it: go back for it or skip it (below). " .. (shown.detail or "")
    table.insert(list, 1, shown)
end

-- Skips a quest's steps and its follow-ups on the route; returns how many follow-up quests went too.
function X.SkipQuest(route, title, part)
    local gone = { [title .. "#" .. (tonumber(part) or 1)] = true }
    local goneIDs = {}
    local followUps, changed = 0, true
    local function Mark(step)
        local key = step.q .. "#" .. (tonumber(step.part) or 1)
        if not gone[key] then
            gone[key], changed = true, true
            followUps = followUps + 1
        end
        local id = X.QuestIDFor(step, nil)
        if id then
            goneIDs[id] = true
        end
    end
    for _, step in ipairs(route.steps) do
        if step.q and gone[step.q .. "#" .. (tonumber(step.part) or 1)] then
            Mark(step)
        end
    end
    while changed do
        changed = false
        for _, step in ipairs(route.steps) do
            if step.t == "accept" and step.q and not gone[step.q .. "#" .. (tonumber(step.part) or 1)] then
                local part_ = tonumber(step.part) or 1
                local need = LevelGuidePrereqs and (LevelGuidePrereqs[step.q] or LevelGuidePrereqs[RealTitle(step.q)])
                local blocked = part_ > 1 and gone[step.q .. "#" .. (part_ - 1)]
                for _, id in ipairs(need and need.all or {}) do
                    blocked = blocked or goneIDs[id]
                end
                if need and need.any and #need.any > 0 then
                    local allGone = true
                    for _, id in ipairs(need.any) do
                        allGone = allGone and goneIDs[id]
                    end
                    blocked = blocked or allGone
                end
                if blocked then
                    Mark(step)
                end
            end
        end
    end
    local keys = {}
    for index, step in ipairs(route.steps) do
        local key = RouteKey(route, index)
        if step.q and gone[step.q .. "#" .. (tonumber(step.part) or 1)] and not charData.skips[key] then
            charData.skips[key] = true
            keys[#keys + 1] = key
        end
    end
    skipHistory[#skipHistory + 1] = { keys = keys }
    return followUps
end

function X.AnswerLost(goBack)
    local questID, lost = X.Lost()
    if not questID then
        return
    end
    charData.lost[questID] = nil
    local route, index = X.FindAccept(questID)
    if goBack then
        if route == activeRoute and index then
            focusKey = RouteKey(route, index)
        end
    elseif route then
        local more = X.SkipQuest(route, lost.q, lost.part)
        skipNotice = { text = string.format("Skipped %s%s. Right-click here to undo.", lost.q,
            more > 0 and string.format(" and %d follow-up(s)", more) or ""), until_ = GetTime() + SKIP_NOTICE_SECONDS }
    end
    dirty = true
end

-- Fits quests accepted off the route (see above); run from RouteSteps while you're in the route's zone.
function X.FitPending(route, byTitle, level, zoneMap)
    local P = LevelGuidePlanner
    for questID, at in pairs(X.pendingFit or {}) do
        if Now() - at >= 1 and P and charData then
            X.pendingFit[questID] = nil
            local camps = X.Camps(questID, zoneMap)
            if #camps > 0 then
                local facts = LevelGuideQuestFacts
                local ender
                if facts and facts.EnderSpot then
                    local map, x, y = facts.EnderSpot(questID, zoneMap)
                    if map == zoneMap and x and y then
                        ender = { x = x / 100, y = y / 100 }
                    end
                end
                local points, keys = {}, {}
                for index, step in ipairs(route.steps) do
                    if #points >= P.FIT.lookAhead then
                        break
                    end
                    if not step.side and not step.map and step.x and step.y and not RouteStepDone(route, index, step, byTitle, level) then
                        points[#points + 1] = { x = step.x / 100, y = step.y / 100 }
                        keys[#keys + 1] = RouteKey(route, index)
                    end
                end
                local function Yards(a, b)
                    local yards, isYards = Distance(zoneMap, a.x, a.y, b.x, b.y)
                    return isYards and yards or nil
                end
                local doAfter, turnAfter = P.Fit(points, camps, ender, Yards)
                charData.extras = charData.extras or {}
                charData.extras[questID] = { fits = doAfter ~= nil, doAfter = doAfter and keys[doAfter],
                    turnAfter = turnAfter and keys[turnAfter], t = Clock() }
            end
        end
    end
end

-- Whether a quest from your log that the route doesn't have should wait behind the route's steps (its fit
-- isn't reached yet); notes the reason in its detail.
function X.ExtraWaits(extra, route, byTitle, level)
    local fit = extra.id and charData and charData.extras and charData.extras[extra.id]
    if not fit then
        return false
    end
    if not fit.fits then
        extra.detail = "Not on your route. " .. (extra.detail or "")
        return false
    end
    local after = extra.kind == "turnin" and fit.turnAfter or (extra.kind == "work" and fit.doAfter)
    if not after then
        return false
    end
    for index, key in ipairs(RouteKeys(route)) do
        if key == after then
            local step = route.steps[index]
            if RouteStepDone(route, index, step, byTitle, level) then
                return false
            end
            extra.detail = "Fits your route after: " .. tostring(step.q or step.text) .. ". " .. (extra.detail or "")
            return true
        end
    end
    return false
end

-- The card: "You dropped X" with Go back / Skip it, under the guide window. Our own frame.
function X.RenderLost()
    local questID, lost = X.Lost()
    local card = X.lostCard
    if not card then
        if not questID then
            return
        end
        card = CreateFrame("Frame", "LevelGuideLostCard", frame, "BackdropTemplate")
        card:SetSize(K.WIDTH, 52)
        card:SetPoint("TOPLEFT", frame, "BOTTOMLEFT", 0, -2)
        if card.SetBackdrop then
            card:SetBackdrop({ bgFile = "Interface\\Tooltips\\UI-Tooltip-Background", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
                edgeSize = 14, insets = { left = 3, right = 3, top = 3, bottom = 3 } })
            card:SetBackdropColor(0.12, 0.04, 0.04, 0.9)
        end
        local text = card:CreateFontString("LevelGuideLostCardText", "OVERLAY", "GameFontHighlightSmall")
        text:SetPoint("TOPLEFT", card, "TOPLEFT", 10, -8)
        text:SetPoint("RIGHT", card, "RIGHT", -10, 0)
        text:SetJustifyH("LEFT")
        card.message = text
        for _, spec in ipairs({ { "LevelGuideLostBack", "Go back", true, -96 }, { "LevelGuideLostSkip", "Skip it", false, -10 } }) do
            local button = CreateFrame("Button", spec[1], card, "UIPanelButtonTemplate")
            button:SetSize(80, 20)
            button:SetPoint("BOTTOMRIGHT", card, "BOTTOMRIGHT", spec[4], 6)
            button:SetText(spec[2])
            local goBack = spec[3]
            button:SetScript("OnClick", function()
                X.AnswerLost(goBack)
                card:Hide()
            end)
        end
        X.lostCard = card
    end
    if questID then
        card.message:SetText(string.format("You dropped |cffffd100%s|r without turning it in. Go back for it, or skip it and what follows it?", tostring(lost.q)))
        card:Show()
    else
        card:Hide()
    end
end
end -- lost and extra quests

-- The guide's own tooltip, so it never changes Blizzard's shared one.
local tooltip
local function Tip()
    if not tooltip then
        tooltip = CreateFrame("GameTooltip", "LevelGuideTooltip", UIParent, "GameTooltipTemplate")
    end
    return tooltip
end

local function StepTooltip(owner, step)
    Tip():SetOwner(owner, "ANCHOR_LEFT")
    Tip():SetText(step.title, 1, 0.82, 0)
    if step.kind == "turnin" or step.kind == "work" then
        for _, objective in ipairs(C_QuestLog.GetQuestObjectives(step.id) or {}) do
            local text = Safe(objective.text)
            if text then
                if Safe(objective.finished) then
                    Tip():AddLine(text, 0.2, 1, 0.2)
                else
                    Tip():AddLine(text, 1, 1, 1)
                end
            end
        end
    end
    if step.detail then
        Tip():AddLine(step.detail, 0.8, 0.8, 0.8, true)
    end
    -- A pick-up the game won't offer yet: say what's missing, by name.
    if step.quest and (step.kind == "pickup" or step.kind == "level") then
        local missing = MissingPrereqs(step.quest, Safe(UnitLevel("player")), step.questPart)
        if #missing > 0 then
            Tip():AddLine("Needs first: " .. table.concat(missing, ", "), 1, 0.5, 0.25, true)
        end
    end
    local maxXP = MaxXP()
    if step.xp and step.xp > 0 and maxXP then
        Tip():AddLine(string.format("Reward: %d XP (%d%% of a level)", step.xp, math.floor(step.xp * 100 / maxXP)), 0.6, 0.8, 1)
    end
    Tip():AddLine("Left-click: show it on your map and screen.", 0.6, 0.6, 0.6)
    if step.routeKey or (step.id and step.kind ~= "travel") then
        Tip():AddLine("Shift+right-click: skip this step.", 0.6, 0.6, 0.6)
    end
    Tip():Show()
end

local function MakeStepButton(height, font)
    local button = CreateFrame("Button", nil, frame)
    button:SetHeight(height)
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    button:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
    button.left = button:CreateFontString(nil, "OVERLAY", font)
    button.left:SetJustifyH("LEFT")
    button.left:SetWordWrap(false)
    button.right = button:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    button.right:SetPoint("RIGHT", button, "RIGHT", -2, 0)
    button.left:SetPoint("LEFT", button, "LEFT", 2, 0)
    button.left:SetPoint("RIGHT", button.right, "LEFT", -4, 0)
    button:SetScript("OnClick", function(self, mouseButton)
        if mouseButton == "RightButton" then
            if IsShiftKeyDown and IsShiftKeyDown() then
                SkipStep(self.step)
            else
                -- A plain right-click was too easy to do by accident; say how instead.
                skipNotice = { text = "Hold Shift and right-click a step to skip it.", until_ = GetTime() + SKIP_NOTICE_SECONDS }
                dirty = true
            end
        else
            MarkStep(self.step)
        end
    end)
    button:SetScript("OnEnter", function(self)
        if self.step then
            StepTooltip(self, self.step)
        end
    end)
    button:SetScript("OnLeave", function()
        Tip():Hide()
    end)
    return button
end

-- "While you're here" (after Polestar's WhileHere, research\guides_deep_re.md 1.6 and 12.5; our own code):
-- later steps of the route you can do now on the way. A ready turn-in shows when you're at its NPC (30 yd),
-- or within 250 yd when the detour (yards there and on to the current step, minus the direct way, at
-- 7 yd/s with 1.25 winding) costs at most 20 s, twice that when waiting for the route's own turn-in would
-- cost XP (a lower share at the level the route has you then), or when resting within 100 yd. Work on a
-- quest you hold shows within 180 yd of its nearest spawn camp (QuestDB) or its spot, for mobs at most
-- 2 levels above you. At most 3 lines, nearest first; none in combat, on a taxi, in an instance or during
-- a timed quest. Right-click a line: not now (120 s and until you've moved 100 yd; again: this zone stay).
do
local function Paused(current)
    if UnitAffectingCombat and Safe(UnitAffectingCombat("player")) then
        return true
    end
    if UnitOnTaxi and Safe(UnitOnTaxi("player")) then
        return true
    end
    if IsInInstance and Safe((IsInInstance())) then
        return true
    end
    return current ~= nil and current.timerEnds ~= nil
end

-- A quest's spawn camps on this map from QuestDB, as { x, y (0-1), r (yards), n }; obj (an objective index
-- or a list of them, Routes.lua Obj()) keeps only those objectives' camps.
function X.Camps(questID, zoneMap, obj)
    local facts = LevelGuideQuestFacts
    local q = questID and facts and facts.Quest and facts.Quest(questID)
    local only
    if obj then
        only = {}
        for _, index in ipairs(type(obj) == "table" and obj or { obj }) do
            only[index] = true
        end
    end
    local list = {}
    for index, objective in ipairs(q and q.objectives or {}) do
        for _, spot in ipairs((not only or only[index]) and objective.spots or {}) do
            if spot.map == zoneMap and spot.x and spot.y then
                list[#list + 1] = { x = spot.x / 100, y = spot.y / 100, r = spot.r, n = spot.n }
            end
        end
    end
    return list
end

local function Yards(mapID, ax, ay, bx, by)
    local yards, isYards = Distance(mapID, ax, ay, bx, by)
    return isYards and yards or nil
end

function X.WhileHere(list)
    X.hereLines = {}
    local P = LevelGuidePlanner
    local route, byTitle, zoneMap = activeRoute, lastByTitle, lastZoneMap
    if not (P and route and byTitle and zoneMap and charData) or Paused(list[1]) then
        return
    end
    local px, py = PositionOn(zoneMap)
    if not (px and py) then
        return
    end
    local level = Safe(UnitLevel("player"))
    local shown = {}
    for position = 1, math.min(#list, K.MAX_NEXT + 1) do
        local step = list[position]
        shown[step.routeKey or ""], shown[step.id or ""] = true, true
    end
    local current = list[1]
    local wx, wy
    if current and current.mapID == zoneMap then
        wx, wy = current.x, current.y
    end
    local dPW = wx and Yards(zoneMap, px, py, wx, wy)
    local resting = IsResting and Safe(IsResting()) or false
    X.hereMutes = X.hereMutes or {}
    local candidates, found = {}, {}
    for index, step in ipairs(route.steps) do
        local routeKey = RouteKey(route, index)
        local entry = step.q and not step.side and (step.t == "turnin" or step.t == "do") and ClassMatches(step.cls)
            and not charData.skips[routeKey] and not shown[routeKey] and HeldPart(byTitle, step)
        local key = entry and (step.t .. "|" .. step.q .. "#" .. (tonumber(step.part) or 1))
        if entry and not found[key] and not shown[entry.id] then
            local turnin = step.t == "turnin" and entry.ready
            local work = step.t == "do" and not entry.ready and not (step.obj ~= nil and ObjectivesDone(entry.id, step.obj, step.objMax))
            local spot = (turnin or work) and RouteDisplay(route, index, step, byTitle, zoneMap)
            local d = spot and spot.mapID == zoneMap and spot.x and Yards(zoneMap, px, py, spot.x, spot.y)
            local ok = false
            if d and work then
                for _, camp in ipairs(X.Camps(entry.id, zoneMap)) do
                    d = math.min(d, Yards(zoneMap, px, py, camp.x, camp.y) or d)
                end
                ok = d <= P.HERE.radius and not (spot.questLevel and level and spot.questLevel > level + 2)
            elseif d and turnin then
                local dNW = wx and Yards(zoneMap, spot.x, spot.y, wx, wy)
                local planned = X.projection and X.projection.at[index]
                local q = spot.questLevel
                local losesXP = q and planned and level and P.Share(level, q) > P.Share(math.floor(planned), q) or false
                ok = P.TurninShows(d, P.DetourSeconds(d, dNW, dPW), losesXP, resting)
            end
            if ok then
                local mute = X.hereMutes[key]
                local moved = mute and mute.x and Yards(zoneMap, px, py, mute.x, mute.y) or 0
                if not P.Muted(X.hereMutes, key, Now(), moved, route.zone) then
                    found[key] = true
                    spot.hereKey, spot.hereYards = key, d
                    candidates[#candidates + 1] = spot
                end
            end
        end
    end
    table.sort(candidates, function(a, b) return a.hereYards < b.hereYards end)
    for position = 1, math.min(#candidates, P.HERE.maxLines) do
        X.hereLines[position] = candidates[position]
    end
end

-- Right-click on a line: not now.
function X.DismissHere(step)
    local P = LevelGuidePlanner
    if not (P and step and step.hereKey and activeRoute and lastZoneMap) then
        return
    end
    local px, py = PositionOn(lastZoneMap)
    X.hereMutes = X.hereMutes or {}
    P.Mute(X.hereMutes, step.hereKey, Now(), px, py, activeRoute.zone)
    dirty = true
end
end -- while you're here

local function Render(mapID, playerX, playerY, later)
    local current = steps[1]
    local y = -K.HEADER_HEIGHT
    local level = Safe(UnitLevel("player"))
    local xp, maxXP = Safe(UnitXP("player")), Safe(UnitXPMax("player"))
    if level and xp and maxXP and maxXP > 0 then
        local ready, readyXP = ReadyShare(steps)
        local readyText = ready and string.format("  |cff33ff33+%d XP waiting (%d%%)|r", readyXP, ready) or ""
        local title = activeRoute and ("Route: " .. (activeRoute.name or activeRoute.zone)) or "Guide"
        headerText:SetText(string.format("%s  %sLevel %d, %d%%|r%s", title, COLOR_DIM, level, math.floor(xp * 100 / maxXP), readyText))
    else
        headerText:SetText("Guide")
    end
    if skipNotice then
        if GetTime() < skipNotice.until_ then
            headerText:SetText(COLOR_ALERT .. skipNotice.text .. "|r")
        else
            skipNotice = nil
        end
    end
    currentRow.step = current
    if current then
        currentRow.left:SetText(StepLine(current))
        detailText:SetText(current.detail or "")
    else
        currentRow.left:SetText(COLOR_DIM .. "Nothing in your log here.|r")
        detailText:SetText("Look for ! markers on your map, or ask a guard where to find quests.")
    end
    currentRow.right:SetText(current and current.timerEnds and TimeLeftText(current.timerEnds) or "")
    currentRow:ClearAllPoints()
    currentRow:SetPoint("TOPLEFT", frame, "TOPLEFT", 8, y - 2)
    currentRow:SetPoint("RIGHT", frame, "RIGHT", -(K.ARROW_SIZE + 16), 0)
    y = y - 22
    detailText:ClearAllPoints()
    detailText:SetPoint("TOPLEFT", frame, "TOPLEFT", 10, y)
    detailText:SetPoint("RIGHT", frame, "RIGHT", -(K.ARROW_SIZE + 16), 0)
    y = y - math.max(detailText:GetStringHeight(), 12) - 6
    -- Where the route takes you (X.Project), one line.
    local projection = X.projection
    local planLine = projection and projection.final and activeRoute and projection.route == activeRoute
        and string.format("%sRoute ends at about level %.1f|r", COLOR_DIM, math.floor(projection.final * 10) / 10)
    if X.planText then
        X.planText:SetShown(planLine and not db.collapsed or false)
        if planLine and not db.collapsed then
            X.planText:SetText(planLine)
            X.planText:ClearAllPoints()
            X.planText:SetPoint("TOPLEFT", frame, "TOPLEFT", 10, y)
            X.planText:SetPoint("RIGHT", frame, "RIGHT", -(K.ARROW_SIZE + 16), 0)
            y = y - 14
        end
    end
    y = math.min(y, -K.HEADER_HEIGHT - K.ARROW_SIZE - 14)

    local shown = 0
    if not db.collapsed then
        for index = 2, K.MAX_NEXT + 1 do
            local step = steps[index]
            if step then
                shown = shown + 1
                local row = nextRows[shown]
                row.step = step
                row.left:SetText(COLOR_DIM .. (index - 1) .. ".|r " .. StepLine(step))
                row.right:SetText(DistanceText(step, mapID, playerX, playerY))
                row:ClearAllPoints()
                row:SetPoint("TOPLEFT", frame, "TOPLEFT", 8, y)
                row:SetPoint("RIGHT", frame, "RIGHT", -8, 0)
                row:Show()
                y = y - 16
            end
        end
    end
    for index = shown + 1, #nextRows do
        nextRows[index]:Hide()
        nextRows[index].step = nil
    end
    -- Side steps: "On the way" stays even when collapsed (it's part of what you're doing now);
    -- "For later" only when expanded.
    local sideShown = 0
    for _, step in ipairs(sideSteps) do
        if sideShown >= MAX_SIDE then
            break
        end
        if step.side == "sticky" or not db.collapsed then
            sideShown = sideShown + 1
            local row = nextRows.side[sideShown]
            row.step = step
            local tag = step.side == "sticky" and "|cffff8040On the way:|r " or "|cff66ccffFor later:|r "
            row.left:SetText(tag .. StepLine(step) .. (step.side == "sticky" and step.detail and (COLOR_DIM .. " - " .. step.detail .. "|r") or ""))
            row.right:SetText(DistanceText(step, mapID, playerX, playerY))
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", frame, "TOPLEFT", 8, y)
            row:SetPoint("RIGHT", frame, "RIGHT", -8, 0)
            row:Show()
            y = y - 16
        end
    end
    for index = sideShown + 1, #nextRows.side do
        nextRows.side[index]:Hide()
        nextRows.side[index].step = nil
    end
    -- While you're here (X.WhileHere): shown collapsed too, it's something to do now.
    for index, row in ipairs(X.hereRows or {}) do
        local step = X.hereLines and X.hereLines[index]
        row.step = step
        if step then
            row.left:SetText("|cff33ff33While you're here:|r " .. StepLine(step))
            row.right:SetText(DistanceText(step, mapID, playerX, playerY))
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", frame, "TOPLEFT", 8, y)
            row:SetPoint("RIGHT", frame, "RIGHT", -8, 0)
            row:Show()
            y = y - 16
        else
            row:Hide()
        end
    end
    local also = not db.collapsed and ChoresText(later)
    alsoText:SetShown(also and true or false)
    if also then
        alsoText:SetText(also)
        alsoText:ClearAllPoints()
        alsoText:SetPoint("TOPLEFT", frame, "TOPLEFT", 10, y - 2)
        alsoText:SetPoint("RIGHT", frame, "RIGHT", -10, 0)
        y = y - math.max(alsoText:GetStringHeight(), 12) - 4
    end
    frame:SetHeight(-y + 8)
end

-- While you're a ghost, where your corpse is: on your zone's map, else on the continent's (you may have
-- released into the next zone). Nil when alive or when the game doesn't say.
local function CorpseTarget()
    if not (UnitIsGhost and Safe(UnitIsGhost("player")) and C_DeathInfo and C_DeathInfo.GetCorpseMapPosition) then
        return nil
    end
    local mapID = PlayerPosition()
    for _ = 1, 2 do
        if not mapID then
            return nil
        end
        local position = C_DeathInfo.GetCorpseMapPosition(mapID)
        if position then
            local x, y = position:GetXY()
            x, y = Safe(x), Safe(y)
            if x and y and (x > 0 or y > 0) then
                return { corpse = true, kind = "travel", title = "Your corpse", mapID = mapID, x = x, y = y }
            end
        end
        local info = C_Map.GetMapInfo and C_Map.GetMapInfo(mapID)
        mapID = info and Safe(info.parentMapID)
        if mapID == 0 then
            mapID = nil
        end
    end
end

-- Points the arrow from you to the current step. Facing and bearing both count counterclockwise from north.
local function UpdateArrow()
    local step = steps[1]
    if step and step.timerEnds then
        currentRow.right:SetText(TimeLeftText(step.timerEnds))
        if step.timerEnds - GetTime() <= LOW_SECONDS and not lowWarned[step.id] then
            lowWarned[step.id] = true
            Warn()
        end
    end
    -- A ghost runs back to the body: the arrow points at your corpse until you're alive again.
    local corpse = CorpseTarget()
    if corpse then
        step = corpse
    end
    -- Read your position on the step's own map, so a city or cave map inside the zone still works.
    local mapID = step and step.mapID
    local playerX, playerY
    if mapID then
        playerX, playerY = PositionOn(mapID)
    end
    -- Arrow state (Planner.lua): the damped bearing, closing speed and arrival, per target.
    local P = LevelGuidePlanner
    local state = X.arrow
    local dt = math.max((X.clock or 0) - (state.clock or X.clock or 0), 0)
    state.clock = X.clock
    if not (step and step.x and playerX) then
        arrow:Hide()
        state.bearing = nil
        yardsText:SetText(step and (step.arrowNote or (step.kind == "travel" and COLOR_DIM .. "other zone|r")) or "")
        return
    end
    local target = (step.corpse and "corpse" or tostring(step.routeKey or StepKey(step) or step.title))
        .. ":" .. tostring(step.pointIndex or "") .. ":" .. tostring(step.campIndex or "") .. ":" .. tostring(step.legKey or "")
    if state.key ~= target then
        state.key, state.closing = target, {}
    end
    local east, south, isYards = Offset(mapID, playerX, playerY, step.x, step.y)
    local yards = math.sqrt(east * east + south * south)
    local radius = P and P.Radius(step.leg and "travel" or step.kind, step.campRadius) or K.ARRIVED_YARDS
    local arrived
    if P then
        arrived = isYards and P.Arrived(state, target, yards, radius)
    else
        arrived = isYards and yards <= radius
    end
    if arrived then
        arrow:Hide()
        state.bearing = nil
        if step.corpse then
            yardsText:SetText("|cff33ff33Your corpse|r")
            return
        end
        yardsText:SetText("|cff33ff33You're there|r")
        if step.leg then
            -- At a travel leg's spot (the pier, the flight master): the step itself isn't done here.
            return
        elseif step.routeKey and step.pointMode and step.pointCount and charData then
            -- A circuit goes on to the next point (wrapping); "nearest" remembers this spot as checked.
            local nextPoint = step.pointMode == "loop" and (step.pointIndex % step.pointCount + 1) or step.pointIndex
            if charData.points[step.routeKey] ~= nextPoint then
                charData.points[step.routeKey] = nextPoint
                dirty = true
            end
        elseif step.routeKey and step.pointCount and step.pointIndex < step.pointCount and charData then
            -- One point of several reached: on to the next one, remembered for this step.
            charData.points[step.routeKey] = step.pointIndex + 1
            dirty = true
        -- Only a "go" step is done by reaching its spot: a Travel() step's spot is where you board (the
        -- flight master, the pier), and it's done on arrival in the zone it takes you to (UtilityDone).
        elseif step.routeKey and step.kind == "travel" and step.stepType == "go" and charData and not charData.visited[step.routeKey] then
            charData.visited[step.routeKey] = true
            dirty = true
        end
        return
    end
    -- ETA from how fast you're closing in (shown only above 1.5 yd/s).
    local eta = P and isYards and P.ETA(yards, P.Closing(state.closing, yards, dt))
    local etaText = eta and eta < 6000 and string.format("  %d:%02d", math.floor(eta / 60), math.floor(eta % 60)) or ""
    yardsText:SetText(isYards and (string.format(step.corpse and "Corpse %d yd" or "%d yd", math.floor(yards)) .. etaText)
        or (step.corpse and "Corpse" or ""))
    local facing = GetPlayerFacing and Safe(GetPlayerFacing())
    if not facing then
        arrow:Hide()
        return
    end
    -- The map bearing swings smoothly to a new target; your facing applies at once (turning the camera).
    local bearing = atan2(-east, -south)
    if P then
        bearing = P.Damp(state.bearing, bearing, dt)
    end
    state.bearing = bearing
    local relative = bearing - facing
    arrow:SetRotation(relative)
    local wrapped = (relative + math.pi) % (2 * math.pi) - math.pi
    if math.abs(wrapped) < K.AHEAD_RADIANS then
        arrow:SetVertexColor(0.3, 1, 0.3)
    else
        arrow:SetVertexColor(1, 0.82, 0)
    end
    arrow:Show()
end
-- The route list window: every step of the current route with its state. Read-only like the rest:
-- a click only points the arrow (and your map waypoint) at a step; Shift+right-click skips or unskips.
local RefreshList, ToggleList
do -- (a block, so its helpers don't count toward the file's 200-local limit)
local LIST_ROWS, LIST_ROW_HEIGHT, LIST_WIDTH = 22, 16, 380
local listFrame, listTitle, listRows, listOffset = nil, nil, {}, 0
local STATE_TEXT = {
    done = "|cff33ff33done|r", skipped = COLOR_DIM .. "skipped|r", pending = "|cffffffffto do|r",
    blocked = "|cffff6040blocked|r", current = "|cffffd100now|r", other = COLOR_DIM .. "not your class|r",
}

-- A route step's state for the list, and why it's blocked (prerequisites by name, or level).
local function StepState(route, index, step, byTitle, level)
    local key = RouteKey(route, index)
    if step.cls and not ClassMatches(step.cls) then
        return "other"
    end
    if charData.skips[key] then
        return "skipped"
    end
    if key == currentKey then
        return "current"
    end
    if step.t == "accept" and RouteStepPending(route, index, step, byTitle, level) then
        local missing = MissingPrereqs(step.q, level, step.part)
        return "blocked", #missing > 0 and ("needs " .. table.concat(missing, ", ")) or nil
    end
    -- You talked to the giver and the quest wasn't on offer: say so, and what QuestDB says is missing,
    -- instead of "done".
    local mark = step.t == "accept" and not InLog(byTitle, step.q) and X.NotOffered(step, level)
    if mark and TurnedIn(step.q) < (tonumber(step.part) or 1) and not Outleveled(step, level) then
        local missing = MissingPrereqs(step.q, level, step.part)
        return "blocked", string.format("not offered here at level %d (%s)", mark.level or 0, tostring(mark.npc or "?"))
            .. (#missing > 0 and ("; needs " .. table.concat(missing, ", ")) or "")
    end
    if RouteStepDone(route, index, step, byTitle, level) then
        return "done"
    end
    if step.t == "accept" and not RouteStepActionable(step, byTitle, level, {}) then
        if step.lvl and level and step.lvl > level + 1 then
            return "blocked", "needs level " .. (step.lvl - 1)
        end
        return "blocked", "an earlier part comes first"
    end
    return "pending"
end

function RefreshList()
    if not (listFrame and listFrame:IsShown()) then
        return
    end
    local route, byTitle = activeRoute, lastByTitle
    local level = Safe(UnitLevel("player"))
    local total = route and #route.steps or 0
    listOffset = math.max(0, math.min(listOffset, total - LIST_ROWS))
    listTitle:SetText(route and string.format("Route: %s  %s(%d-%d of %d, scroll for more)|r", route.name or route.zone, COLOR_DIM,
        math.min(listOffset + 1, total), math.min(listOffset + LIST_ROWS, total), total) or "No route for your level here")
    for row = 1, LIST_ROWS do
        local button = listRows[row]
        local index = listOffset + row
        local step = route and byTitle and route.steps[index]
        if step then
            local state, why = StepState(route, index, step, byTitle, level)
            local kind = KINDS[ROUTE_KINDS[step.t]] or KINDS.travel
            button.routeIndex, button.state, button.why = index, state, why
            button.left:SetText(string.format("%s%d.|r %s:|r %s", COLOR_DIM, index, kind.color .. kind.label,
                tostring(step.q or step.text) .. (step.part and step.part > 1 and (" (" .. step.part .. ")") or "")))
            button.right:SetText(STATE_TEXT[state] or "")
            button:Show()
        else
            button.routeIndex = nil
            button:Hide()
        end
    end
end

local function ListRowClick(self, mouseButton)
    local route, index = activeRoute, self.routeIndex
    if not (route and index and lastByTitle and charData) then
        return
    end
    local key = RouteKey(route, index)
    if mouseButton == "RightButton" then
        if IsShiftKeyDown and IsShiftKeyDown() then
            if charData.skips[key] then
                charData.skips[key] = nil
            else
                charData.skips[key] = true
                skipHistory[#skipHistory + 1] = { routeKey = key }
            end
            if focusKey == key then
                focusKey = nil
            end
            dirty = true
        end
        return
    end
    -- Left-click: the arrow points at this step (and the map waypoint is set) until it's done.
    focusKey = key
    MarkStep(RouteDisplay(route, index, route.steps[index], lastByTitle, lastZoneMap))
    dirty = true
end

local function BuildList()
    listFrame = CreateFrame("Frame", "LevelGuideRouteList", UIParent, "BackdropTemplate")
    listFrame:SetSize(LIST_WIDTH, LIST_ROWS * LIST_ROW_HEIGHT + 44)
    listFrame:SetFrameStrata("MEDIUM")
    listFrame:SetClampedToScreen(true)
    listFrame:SetMovable(true)
    listFrame:EnableMouse(true)
    listFrame:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 14,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    listFrame:SetBackdropColor(0.04, 0.04, 0.07, 0.92)
    listFrame:SetBackdropBorderColor(0.5, 0.5, 0.55, 0.9)
    if db.listPosition then
        listFrame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", db.listPosition[1], db.listPosition[2])
    else
        listFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    end
    listFrame:RegisterForDrag("LeftButton")
    listFrame:SetScript("OnDragStart", function(self) self:StartMoving() end)
    listFrame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local left, top = self:GetLeft(), self:GetTop()
        if left and top then
            db.listPosition = { left, top }
        end
    end)
    listFrame:EnableMouseWheel(true)
    listFrame:SetScript("OnMouseWheel", function(_, delta)
        listOffset = listOffset - delta * 3
        RefreshList()
    end)
    listTitle = listFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    listTitle:SetPoint("TOPLEFT", listFrame, "TOPLEFT", 10, -9)
    local close = CreateFrame("Button", nil, listFrame)
    close:SetSize(20, 18)
    close:SetPoint("TOPRIGHT", listFrame, "TOPRIGHT", -5, -4)
    close:SetNormalFontObject(GameFontNormal)
    close:SetHighlightFontObject(GameFontHighlight)
    close:SetText("x")
    close:SetScript("OnClick", function() listFrame:Hide() end)
    local hint = listFrame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    hint:SetPoint("BOTTOMLEFT", listFrame, "BOTTOMLEFT", 10, 8)
    hint:SetText("Click: point the arrow at a step.  Shift+right-click: skip / unskip.")
    for row = 1, LIST_ROWS do
        local button = CreateFrame("Button", nil, listFrame)
        button:SetHeight(LIST_ROW_HEIGHT)
        button:SetPoint("TOPLEFT", listFrame, "TOPLEFT", 8, -24 - (row - 1) * LIST_ROW_HEIGHT)
        button:SetPoint("RIGHT", listFrame, "RIGHT", -8, 0)
        button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        button:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
        button.left = button:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        button.left:SetJustifyH("LEFT")
        button.left:SetWordWrap(false)
        button.right = button:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        button.right:SetPoint("RIGHT", button, "RIGHT", -2, 0)
        button.left:SetPoint("LEFT", button, "LEFT", 2, 0)
        button.left:SetPoint("RIGHT", button.right, "LEFT", -4, 0)
        button:SetScript("OnClick", function(self, mouseButton)
            ListRowClick(self, mouseButton)
            RefreshList()
        end)
        button:SetScript("OnEnter", function(self)
            local step = activeRoute and self.routeIndex and activeRoute.steps[self.routeIndex]
            if not step then
                return
            end
            Tip():SetOwner(self, "ANCHOR_RIGHT")
            Tip():SetText(tostring(step.q or step.text), 1, 0.82, 0)
            local who = step.npc or step.note
            if who then
                Tip():AddLine(who, 0.8, 0.8, 0.8, true)
            end
            if self.why then
                Tip():AddLine(self.why, 1, 0.5, 0.25, true)
            end
            Tip():AddLine("Click: point the arrow here. Shift+right-click: skip or unskip.", 0.6, 0.6, 0.6, true)
            Tip():Show()
        end)
        button:SetScript("OnLeave", function() Tip():Hide() end)
        listRows[row] = button
    end
    listFrame:Hide()
end

function ToggleList()
    if not listFrame then
        BuildList()
    end
    if listFrame:IsShown() then
        listFrame:Hide()
    else
        -- Open on the current step.
        for index = 1, activeRoute and #activeRoute.steps or 0 do
            if RouteKey(activeRoute, index) == currentKey then
                listOffset = math.max(0, index - 4)
            end
        end
        listFrame:Show()
        RefreshList()
    end
end
end -- route list window

-- The travel planner in the guide (research\guides_deep_re.md 12.7; LevelGuide\TravelPlan.lua does the sums,
-- LevelGuide\Travel.lua holds the flight masters, boats and inns). When the current step is on another map,
-- it shows the next leg of the quickest way there: "Take the portal in Darnassus to Rut'theran Village",
-- "Fly Rut'theran Village to Auberdine, ~2 min", "Use your hearthstone to Auberdine", "Take the boat at
-- Auberdine pier to Stormwind Harbor, ~3 min", with the arrow on that leg's spot. Flights are the ones this
-- character knows (charData.flights; Landmarks' learned flight times where it has them), the hearthstone
-- only when it's in your bags, off cooldown and bound at a known inn. Worked out again on a step or zone
-- change, after 10 s and 50 yd moved, or every 30 s; held while you fly (UnitOnTaxi) or ride a boat. A Way()
-- written in Routes.lua for the map you're on wins (TravelTo). It only says what to do.
do
-- One table, not several locals: this file is at Lua's 200-local limit.
local V = { dockYards = 30, leftYards = 40, holdExtra = 90, replanSeconds = 10, replanYards = 50, staleSeconds = 30 }
X.travel = { at = 0 }

-- A map's uiMap ID from its name (Travel.lua's names); a number is already one.
function X.MapIDNamed(name)
    if type(name) == "number" then
        return name
    end
    local T = LevelGuideTravel
    if not (T and type(name) == "string") then
        return nil
    end
    if not V.ids then
        V.ids = {}
        for id, mapName in pairs(T.names) do
            V.ids[mapName] = id
        end
    end
    return V.ids[name]
end

-- Where a route step is, as uiMap and map percent: its own map (On()), Darnassus for "Name, Darnassus",
-- else the route's zone. Nil without a spot or a known map.
function X.GoalOf(route, step, x, y)
    if not (route and x and y) then
        return nil
    end
    local name = step and step.map or route.zone
    if step and not step.map then
        local text = (step.npc or step.note or ""):gsub("%b()", "")
        for _, city in ipairs(CITIES) do
            if text:find(", " .. city, 1, true) then
                name = city
            end
        end
    end
    local id = X.MapIDNamed(name)
    if id then
        return id, x, y
    end
end

-- Flight times Landmarks learned from your own flights, by flight master name ("Auberdine>Astranaar").
function V.Learned()
    local out = {}
    pcall(function()
        local all = LandmarksDB
        if type(all) ~= "table" then
            return
        end
        local names = {}
        for _, saved in pairs(type(all.flightPoints) == "table" and all.flightPoints or {}) do
            for nodeID, node in pairs(type(saved) == "table" and type(saved.nodes) == "table" and saved.nodes or {}) do
                if type(node) == "table" and type(node.name) == "string" then
                    names[nodeID] = node.name:match("^([^,]+)") or node.name
                end
            end
        end
        for _, realm in pairs(all) do
            for key, entry in pairs(type(realm) == "table" and type(realm.flightTimes) == "table" and realm.flightTimes or {}) do
                local a, b = tostring(key):match("^(%d+)>(%d+)$")
                local from, to = names[tonumber(a)], names[tonumber(b)]
                if from and to and type(entry) == "table" and tonumber(entry.seconds) then
                    out[from .. ">" .. to] = tonumber(entry.seconds)
                end
            end
        end
    end)
    return out
end

-- The inn you'd hearth to, when the hearthstone is in your bags and ready (read only, never used).
function V.Hearth()
    local P = LevelGuidePlanner
    if not (C_Container and C_Container.GetItemCooldown and C_Item and C_Item.GetItemCount and GetBindLocation) then
        return nil
    end
    local count = Safe(C_Item.GetItemCount(6948))
    if not (type(count) == "number" and count > 0) then
        return nil
    end
    local start, duration = C_Container.GetItemCooldown(6948)
    start, duration = Safe(start), Safe(duration)
    if not (start and duration) or (start > 0 and duration > 0 and start + duration > Now()) then
        return nil
    end
    return P.TravelInn(Safe(GetBindLocation()))
end

function V.Speed()
    if not GetUnitSpeed then
        return nil
    end
    local _, run = GetUnitSpeed("player")
    run = Safe(run)
    return type(run) == "number" and run > 0 and run or nil
end

-- Puts a leg on the step: its words, the arrow on its spot (none for the hearthstone or in the air).
function V.Show(step, leg, title, note, point)
    local rest = step.why or step.detail
    step.leg, step.legKey = leg, leg.kind .. ":" .. tostring(leg.from and leg.from.name) .. ":" .. tostring(title)
    if step.kind == "travel" then
        step.title = title
        step.detail = note .. (rest and (". " .. rest) or "")
    else
        step.detail = title .. ". " .. note .. (rest and (". " .. rest) or "")
    end
    if point then
        step.mapID, step.x, step.y = point.map, point.x / 100, point.y / 100
    else
        step.mapID, step.x, step.y = nil, nil, nil
        step.arrowNote = COLOR_DIM .. (leg.kind == "hearth" and "Hearthstone" or "On the way") .. "|r"
    end
end

function X.ApplyTravel(list)
    local P, T, S = LevelGuidePlanner, LevelGuideTravel, X.travel
    local step = list and list[1]
    if not (P and P.TravelPlan and T and step and charData) or step.corpse or step.wayKey or not RoutesForYou() then
        return
    end
    local goalMap = X.MapIDNamed(step.goalMap)
    if not (goalMap and step.goalX and step.goalY and T.frames[goalMap]) then
        return
    end
    local mapID, px, py = PlayerPosition()
    if not (mapID and px and py and T.frames[mapID]) then
        return
    end
    local here, now = { map = mapID, x = px * 100, y = py * 100 }, Now()
    local goal = { map = goalMap, x = step.goalX, y = step.goalY }
    -- In the air: the flight you took, no arrow, nothing worked out mid-air.
    if UnitOnTaxi and Safe(UnitOnTaxi("player")) == true then
        local leg = S.shown and S.shown.kind == "fly" and S.shown or { kind = "fly" }
        V.Show(step, leg, leg.to and ("Flying to " .. tostring(leg.to.name)) or "On a flight", "The guide goes on when you land", nil)
        S.atDock, S.ride = nil, nil
        return
    end
    -- On a boat (you were at its pier and moved off): held until you land, walk back to the pier, or it
    -- should have arrived.
    if S.atDock and not S.ride then
        local yards = P.TravelYards(here, S.atDock.from)
        if yards and yards > V.leftYards then
            S.ride, S.atDock = { leg = S.atDock, at = now }, nil
        end
    end
    local ride = S.ride
    if ride then
        local toYards = P.TravelYards(here, ride.leg.to)
        local fromYards = P.TravelYards(here, ride.leg.from)
        if (toYards and toYards < 60) or (fromYards and fromYards <= V.dockYards) or mapID == ride.leg.to.map
            or now - ride.at > ride.leg.seconds + V.holdExtra or X.travelReplan then
            S.ride = nil
        else
            V.Show(step, ride.leg, "On the " .. ride.leg.kind .. " to " .. tostring(ride.leg.to.name), "The guide goes on when you get off", ride.leg.to)
            return
        end
    end
    if goalMap == mapID or (step.mapID and step.mapID == mapID) then
        S.shown, S.atDock = nil, nil
        return
    end
    local level = Safe(UnitLevel("player")) or 1
    local hearth = V.Hearth()
    local knownCount = 0
    for _ in pairs(charData.flights or {}) do
        knownCount = knownCount + 1
    end
    local key = table.concat({ goalMap, math.floor(goal.x), math.floor(goal.y), level, knownCount,
        hearth and hearth.name or "-" }, ":")
    local region = T.Region(mapID, here.x, here.y)
    local moved = S.here and P.TravelYards(here, S.here)
    if X.travelReplan or S.key ~= key or S.map ~= mapID or S.region ~= region or now - S.at >= V.staleSeconds
        or (now - S.at >= V.replanSeconds and (not moved or moved >= V.replanYards)) then
        X.travelReplan = false
        S.key, S.map, S.region, S.at, S.here = key, mapID, region, now, here
        S.plan = P.TravelPlan({ from = here, to = goal, level = level, speed = V.Speed(),
            known = P.TravelKnown(charData.flights), hearth = hearth, learned = V.Learned() })
    end
    local plan = S.plan
    local legs = plan and plan.legs or {}
    local leg = legs[1]
    if leg and leg.kind == "walk" then
        leg = legs[2]
    end
    if not leg then
        -- Walking there is quickest: straight at it when the step had no spot here.
        S.shown, S.atDock = nil, nil
        return
    end
    S.shown = leg
    local note = string.format("About %d min to %s", math.max(1, math.floor(plan.total / 60 + 0.5)),
        tostring(T.names[goalMap] or "there"))
    V.Show(step, leg, leg.text, note, leg.kind ~= "hearth" and leg.from or nil)
    -- At a pier: once you move off it with the boat, the step holds "On the boat to ..." (above).
    local yards = (leg.kind == "boat" or leg.kind == "zeppelin") and P.TravelYards(here, leg.from)
    if yards and yards <= V.dockYards then
        S.atDock = leg
    elseif not yards then
        S.atDock = nil
    end
end
end -- travel planner

local function Rebuild()
    local mapID, playerX, playerY, later
    X.ResolveRemoved()
    steps, mapID, playerX, playerY, later = BuildSteps()
    currentKey = StepKey(steps[1])
    -- A current step on another map shows the next leg of the way there (TravelPlan.lua).
    X.ApplyTravel(steps)
    X.WhileHere(steps)
    Render(mapID, playerX, playerY, later)
    X.RenderLost()
    UpdateArrow()
    RefreshList()
end

-- For the MapPins helper (it draws the pins; LevelGuide never touches the map): the next stops of the
-- route as last worked out, no new scans. Each is { mapID, x, y (0-1), label, kind, current }; a step
-- with several points adds its remaining points. Map IDs are the ones resolved from the live game.
function LevelGuide_UpcomingStops()
    local stops = {}
    for index, step in ipairs(steps or {}) do
        if #stops >= MAX_STOPS then
            break
        end
        if step.mapID and step.x and step.y then
            local kind = KINDS[step.kind]
            local label = (kind and kind.label or "Step") .. ": " .. tostring(step.title)
                .. (step.npc and step.npc ~= step.title and (" (" .. step.npc .. ")") or "")
            stops[#stops + 1] = { mapID = step.mapID, x = step.x, y = step.y, label = label,
                kind = STOP_KINDS[step.kind] or tostring(step.kind), current = index == 1 }
            for _, point in ipairs(step.morePoints or {}) do
                if #stops >= MAX_STOPS then
                    break
                end
                stops[#stops + 1] = { mapID = point.mapID, x = point.x, y = point.y,
                    label = string.format("%s (point %d of %d)", label, point.index, step.pointCount or point.index),
                    kind = STOP_KINDS[step.kind] or tostring(step.kind), current = false }
            end
        end
    end
    return stops
end

local function Attempt(step)
    local ok, err = pcall(step)
    if not ok then
        geterrorhandler()(err)
    end
end

local function OnUpdate(_, elapsed)
    sinceArrow = sinceArrow + elapsed
    sinceRoute = sinceRoute + elapsed
    X.clock = X.clock + elapsed   -- the arrow's own clock (damping, closing speed), and the level scan's
    if X.clock >= 60 then
        Attempt(X.ScanTick)
    end
    -- A burst of quest events (looting, zoning) rebuilds once, not once per frame.
    if (dirty and sinceRoute >= DIRTY_SECONDS) or sinceRoute >= K.ROUTE_SECONDS then
        dirty, sinceRoute, sinceArrow = false, 0, 0
        Attempt(Rebuild)
    elseif sinceArrow >= K.ARROW_SECONDS then
        sinceArrow = 0
        Attempt(UpdateArrow)
    end
end

local function SavePosition()
    local left, top = frame:GetLeft(), frame:GetTop()
    if left and top then
        frame:ClearAllPoints()
        frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left, top)
        db.position = { left, top }
    end
end

local function Build()
    frame = CreateFrame("Frame", "LevelGuideFrame", UIParent, "BackdropTemplate")
    frame:SetWidth(K.WIDTH)
    frame:SetHeight(100)
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 14,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    frame:SetBackdropColor(0.04, 0.04, 0.07, 0.78)
    frame:SetBackdropBorderColor(0.5, 0.5, 0.55, 0.9)
    if db.position then
        frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", db.position[1], db.position[2])
    else
        frame:SetPoint("TOP", UIParent, "TOP", 0, -8)
    end

    local header = CreateFrame("Button", nil, frame)
    header:SetPoint("TOPLEFT", frame, "TOPLEFT", 4, -3)
    header:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -50, -3)
    header:SetHeight(K.HEADER_HEIGHT - 4)
    header:RegisterForDrag("LeftButton")
    header:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    header:SetScript("OnDragStart", function()
        frame:StartMoving()
    end)
    header:SetScript("OnDragStop", function()
        frame:StopMovingOrSizing()
        SavePosition()
    end)
    header:SetScript("OnClick", function(_, mouseButton)
        if mouseButton == "LeftButton" then
            ToggleList()
            return
        end
        if IsShiftKeyDown and IsShiftKeyDown() then
            UndoAllSkips()
        elseif not UndoSkip() then
            -- Nothing skipped this session (a /reload clears that list): say so. Bringing back every saved
            -- skip is Shift+right-click only, so it never happens by accident.
            if ForeverHub_Receive then
                ForeverHub_Receive("LevelGuide", "No skip to undo this session. Shift+right-click brings back every skipped step.")
            end
        end
    end)
    header:SetScript("OnEnter", function(self)
        Tip():SetOwner(self, "ANCHOR_LEFT")
        Tip():SetText("Leveling guide")
        Tip():AddLine("Steps are worked out from your quest log and map, nearest first.", 1, 1, 1, true)
        Tip():AddLine("Click: show the whole route. Drag to move. Right-click: undo the last skip. Shift+right-click: bring back every skipped step.", 0.6, 0.6, 0.6, true)
        Tip():Show()
    end)
    header:SetScript("OnLeave", function()
        Tip():Hide()
    end)
    headerText = header:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    headerText:SetPoint("LEFT", header, "LEFT", 6, 0)

    collapseButton = CreateFrame("Button", nil, frame)
    collapseButton:SetSize(20, 18)
    collapseButton:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -5, -3)
    collapseButton:SetNormalFontObject(GameFontNormal)
    collapseButton:SetHighlightFontObject(GameFontHighlight)
    collapseButton:SetText(db.collapsed and "+" or "-")
    collapseButton:SetScript("OnClick", function(self)
        db.collapsed = not db.collapsed
        self:SetText(db.collapsed and "+" or "-")
        dirty = true
    end)
    -- The route list, also on a small button (a header click can turn into a drag).
    local listButton = CreateFrame("Button", nil, frame)
    listButton:SetSize(24, 18)
    listButton:SetPoint("RIGHT", collapseButton, "LEFT", -1, 0)
    listButton:SetNormalFontObject(GameFontNormalSmall)
    listButton:SetHighlightFontObject(GameFontHighlightSmall)
    listButton:SetText("List")
    listButton:SetScript("OnClick", ToggleList)
    listButton:SetScript("OnEnter", function(self)
        Tip():SetOwner(self, "ANCHOR_LEFT")
        Tip():SetText("Route list")
        Tip():AddLine("Every step of this zone's route: done, skipped, to do or blocked.", 1, 1, 1, true)
        Tip():Show()
    end)
    listButton:SetScript("OnLeave", function()
        Tip():Hide()
    end)

    -- Blizzard's own navigation arrow art, which points up when unrotated.
    arrow = frame:CreateTexture(nil, "OVERLAY")
    if C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo("Navigation-Tracked-Arrow") then
        arrow:SetAtlas("Navigation-Tracked-Arrow")
    else
        arrow:SetTexture("Interface\\MINIMAP\\MiniMap-QuestArrow")
    end
    arrow:SetSize(K.ARROW_SIZE * 0.6, K.ARROW_SIZE)
    arrow:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -14, -K.HEADER_HEIGHT - 2)
    arrow:Hide()
    yardsText = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    yardsText:SetPoint("TOP", arrow, "BOTTOM", 0, -1)

    currentRow = MakeStepButton(20, "GameFontNormal")
    detailText = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    detailText:SetJustifyH("LEFT")
    detailText:SetWordWrap(true)
    X.planText = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    X.planText:SetJustifyH("LEFT")
    for index = 1, K.MAX_NEXT do
        nextRows[index] = MakeStepButton(16, "GameFontHighlightSmall")
        nextRows[index]:Hide()
    end
    nextRows.side = {}
    for index = 1, MAX_SIDE do
        nextRows.side[index] = MakeStepButton(16, "GameFontHighlightSmall")
        nextRows.side[index]:Hide()
    end
    X.hereRows = {}
    for index = 1, 3 do
        local row = MakeStepButton(16, "GameFontHighlightSmall")
        row:SetScript("OnClick", function(self, mouseButton)
            if mouseButton == "RightButton" then
                X.DismissHere(self.step)
            else
                MarkStep(self.step)
            end
        end)
        row:SetScript("OnEnter", function(self)
            if self.step then
                StepTooltip(self, self.step)
                Tip():AddLine("Right-click: not now.", 0.6, 0.6, 0.6)
                Tip():Show()
            end
        end)
        row:Hide()
        X.hereRows[index] = row
    end
    alsoText = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    alsoText:SetJustifyH("LEFT")
    alsoText:SetWordWrap(true)

    frame:SetScript("OnUpdate", OnUpdate)
end

local events = CreateFrame("Frame")
for _, name in ipairs({ "PLAYER_LOGIN", "QUEST_LOG_UPDATE", "QUEST_ACCEPTED", "QUEST_REMOVED", "QUEST_TURNED_IN",
    "ZONE_CHANGED_NEW_AREA", "ZONE_CHANGED", "PLAYER_LEVEL_UP", "PLAYER_XP_UPDATE",
    "GOSSIP_SHOW", "QUEST_GREETING", "QUEST_DETAIL", "QUEST_PROGRESS", "QUEST_COMPLETE",
    "QUESTLINE_UPDATE", "QUEST_POI_UPDATE",
    -- Utility steps and the corpse arrow, all watched only.
    "HEARTHSTONE_BOUND", "TAXIMAP_OPENED", "UI_INFO_MESSAGE", "BAG_UPDATE_DELAYED", "SPELLS_CHANGED",
    "LEARNED_SPELL_IN_SKILL_LINE", "PLAYER_DEAD", "PLAYER_ALIVE", "PLAYER_UNGHOST",
    -- Vendor and class-trainer side steps: only which window opened is read, nothing is bought or trained.
    "MERCHANT_SHOW", "MERCHANT_CLOSED", "TRAINER_SHOW",
    -- The slow scan of server quest levels (X.ScanTick).
    "QUEST_DATA_LOAD_RESULT" }) do
    -- Events this client doesn't have are left out rather than stopping the addon.
    if not (C_EventUtils and C_EventUtils.IsEventValid) or C_EventUtils.IsEventValid(name) then
        pcall(events.RegisterEvent, events, name)
    end
end

-- At a flight master: every node on its map that isn't unreachable is one you know.
local function RecordFlights()
    if not (C_TaxiMap and C_TaxiMap.GetAllTaxiNodes and charData) then
        return
    end
    local unreachable = Enum and Enum.FlightPathState and Enum.FlightPathState.Unreachable or 2
    local mapID = PlayerPosition()
    for _ = 1, 3 do
        if not mapID or mapID == 0 then
            break
        end
        for _, node in ipairs(C_TaxiMap.GetAllTaxiNodes(mapID) or {}) do
            local name, state = Safe(node.name), Safe(node.state)
            if name and state ~= nil and state ~= unreachable then
                charData.flights[name] = true
            end
        end
        local info = C_Map.GetMapInfo and C_Map.GetMapInfo(mapID)
        mapID = info and Safe(info.parentMapID)
    end
end

-- The game's "new flight path discovered" message: the route's flight step you're standing at is done.
local function RecordNewFlight(message)
    if not (message and ERR_NEWTAXIPATH and message == ERR_NEWTAXIPATH and activeRoute and charData) then
        return
    end
    local zoneMap = ZoneMap(activeRoute.zone)
    if not zoneMap then
        return
    end
    local playerX, playerY = PositionOn(zoneMap)
    if not (playerX and playerY) then
        return
    end
    for _, step in ipairs(activeRoute.steps) do
        if step.t == "fp" and step.x and not step.map then
            local yards = Distance(zoneMap, playerX, playerY, step.x / 100, step.y / 100)
            if yards <= FLIGHT_NEAR_YARDS then
                charData.flights[step.place] = true
            end
        end
    end
end

events:SetScript("OnEvent", function(_, event, questID, extra)
    if event == "PLAYER_LOGIN" then
        LevelGuideDB = LevelGuideDB or {}
        db = LevelGuideDB
        db.skipped = db.skipped or {}
        db.characters = db.characters or {}
        local key = ForeverCharacterAdopt(db.characters)
        db.characters[key] = db.characters[key] or {}
        charData = ForeverCharacterStamp(db.characters[key])
        charData.done = charData.done or {}
        charData.skips = charData.skips or {}
        charData.visited = charData.visited or {}
        charData.points = charData.points or {}    -- step key -> next point of a several-point step
        charData.marks = charData.marks or {}      -- step key -> a bound hearth / items once had
        charData.flights = charData.flights or {}  -- flight node name -> known
        charData.notOffered = charData.notOffered or {}  -- quest ID (or "title#part") -> "not offered" mark
        X.PruneOffers()
        Attempt(X.ServerStore)   -- server quest levels: starts over on a new client build
        -- Lost quests and fitted extras (X.Lost, X.FitPending) are dropped after a week unanswered.
        for _, list in ipairs({ charData.lost or {}, charData.extras or {} }) do
            for questID, entry in pairs(list) do
                local now = (time and Safe(time())) or Now()
                if type(entry) ~= "table" or not entry.t or now - entry.t > 7 * 86400 or now < entry.t then
                    list[questID] = nil
                end
            end
        end
        -- Once: skips and visits saved under the old "Zone#index" keys move to stable keys, for every
        -- character on this account.
        if (db.stepKeys or 1) < 2 then
            for _, data in pairs(db.characters) do
                if type(data) == "table" then
                    MigrateCharacter(data)
                end
            end
            db.stepKeys = 2
        end
        Attempt(Build)
        return
    end
    if not db then
        return
    end
    if event == "QUEST_DATA_LOAD_RESULT" then
        X.ScanLoaded(Safe(questID))
        return
    elseif event == "UI_INFO_MESSAGE" then
        -- Fires for every on-screen info line; only "new flight path" matters.
        local message = Safe(extra)
        if message and ERR_NEWTAXIPATH and message == ERR_NEWTAXIPATH then
            Attempt(function() RecordNewFlight(message) end)
            dirty = true
        end
        return
    elseif event == "TAXIMAP_OPENED" then
        Attempt(RecordFlights)
    elseif event == "MERCHANT_SHOW" then
        -- Remember whose shop this is: at MERCHANT_CLOSED the "npc" unit may already be gone.
        merchantNpc = NpcIDOf(Safe(UnitGUID and UnitGUID("npc")))
        return
    elseif event == "MERCHANT_CLOSED" then
        local npcID = merchantNpc
        merchantNpc = nil
        if not (npcID and activeRoute and charData) then
            return
        end
        for index, step in ipairs(activeRoute.steps) do
            if step.t == "vendor" then
                for _, wanted in ipairs(step.npcIDs or {}) do
                    if wanted == npcID then
                        charData.marks[RouteKey(activeRoute, index)] = true
                    end
                end
            end
        end
    elseif event == "TRAINER_SHOW" then
        -- A class trainer (not a profession or pet trainer): this level's training is seen to.
        local general = Enum and Enum.TrainerType and Enum.TrainerType.General or 0
        local kind = C_Trainer and C_Trainer.GetTrainerType and Safe(C_Trainer.GetTrainerType())
        local level = Safe(UnitLevel("player"))
        if kind == general and level and charData then
            charData.trainerLevel = math.max(charData.trainerLevel or 0, level)
        end
    elseif event == "BAG_UPDATE_DELAYED" then
        -- Bags change all the time; only item, shopping, bag or keep steps on this route care.
        local wanted = false
        for _, step in ipairs(activeRoute and activeRoute.steps or {}) do
            wanted = wanted or step.t == "item" or step.t == "buy" or step.t == "bags" or step.t == "keep"
        end
        if not wanted then
            return
        end
    end
    questID = Safe(questID)
    if event == "QUEST_LOG_UPDATE" then
        -- The log has loaded: placement may latch from now on (never from an empty log at login).
        X.logSeen = true
        Attempt(X.CheckProgress)
    end
    if event == "QUEST_ACCEPTED" or event == "QUEST_TURNED_IN" then
        -- Grace entries only matter for seconds; old ones go so the tables stay small.
        for _, list in ipairs({ recentAccepts, recentTurnins }) do
            for key, at in pairs(list) do
                if Now() - at > TURNIN_GRACE * 2 then
                    list[key] = nil
                end
            end
        end
    end
    if event == "QUEST_ACCEPTED" and questID then
        recentAccepts[questID] = Now()
        local title = C_QuestLog.GetTitleForQuestID and Safe(C_QuestLog.GetTitleForQuestID(questID))
        if title then
            recentAccepts[title] = Now()
        end
    elseif event == "QUEST_TURNED_IN" and questID then
        recentTurnins[questID] = Now()
        if completedSet then
            completedSet[questID] = true
        end
    end
    if event == "QUEST_REMOVED" and questID then
        db.skipped[questID] = nil
        -- Dropped without a turn-in? Decided at the next rebuild (X.ResolveRemoved).
        X.QuestRemoved(questID)
        -- Picked up again later, a timed quest should warn again.
        timedWarned[questID], lowWarned[questID] = nil, nil
    elseif event == "QUEST_TURNED_IN" and questID then
        local title = titlesByID[questID] or (C_QuestLog.GetTitleForQuestID and Safe(C_QuestLog.GetTitleForQuestID(questID)))
        -- Another quest with a route quest's title (QuestIDs.lua "unrelated": the Elwynn Encrypted Letter,
        -- repeatable bounties) doesn't count as the route's.
        local unrelated = LevelGuideQuestIDs and LevelGuideQuestIDs.unrelated
        if title and not (unrelated and unrelated[questID]) then
            charData.done[title] = (charData.done[title] or 0) + 1
        end
        -- A turn-in at that NPC, nearby, or of a prerequisite clears "not offered" marks.
        Attempt(function()
            X.OffersAfterTurnin(questID)
        end)
    elseif event == "QUEST_ACCEPTED" and questID then
        local title = C_QuestLog.GetTitleForQuestID and Safe(C_QuestLog.GetTitleForQuestID(questID))
        X.OffersAfterAccept(questID, title)
        Attempt(function()
            X.Accepted(questID)
        end)
    elseif event == "ZONE_CHANGED_NEW_AREA" then
        requestedMap = nil
        X.travelReplan = true   -- off a boat, through a portal, landed: the next leg
    elseif event == "GOSSIP_SHOW" or event == "QUEST_GREETING" or event == "QUEST_DETAIL" then
        Attempt(function()
            X.JudgeOffers(event)
        end)
    end
    dirty = true
end)

-- Quest givers for the map (MapPins' "Quest givers" layer), the way Questie marks them: every pick-up on
-- the written routes you could take now (not in your log, not done, its earlier parts and prerequisites
-- done, within a few levels of yours), and where to hand in what's finished. From the routes, so
-- Alliance quests in zones a route covers; the game's own map shows the rest. Never acts.
do -- (a block, so its helpers don't count toward the file's 200-local limit)
    -- One table, not several locals: this file is at Lua's 200-local limit.
    local G = { above = 1 }

    -- The map a step's spot is on: its own (On()), a city named in the giver's text, else the route's zone.
    function G.StepZone(route, step)
        if step.map then
            return step.map
        end
        local text = (step.npc or ""):match("^[^(]*")
        for _, city in ipairs(CITIES) do
            if text:find(", " .. city, 1, true) then
                return city
            end
        end
        return route.zone
    end

    function G.Build(level)
        local list, seen, keys = {}, {}, {}
        local routesSeen = {}
        for _, chain in pairs(LevelGuideRoutes.chains or {}) do
            for _, route in ipairs(type(chain) == "table" and chain or {}) do
                -- A route in several chains (Skyborne share the Human one) is read once.
                local steps = type(route) == "table" and not routesSeen[route] and route.steps or {}
                routesSeen[route] = true
                for index, step in ipairs(steps) do
                    -- The guide's own filters: class, guards (When), steps you skipped.
                    if (step.t == "accept" or step.t == "turnin") and step.q and step.x and step.y and not step.side
                        and ClassMatches(step.cls) and GuardsPass(step.when, lastByTitle)
                        and not charData.skips[RouteKey(route, index)] then
                        local part = tonumber(step.part) or 1
                        local id = step.t .. "|" .. step.q .. "|" .. part
                        if not seen[id] then
                            seen[id] = true
                            local show
                            if step.t == "accept" then
                                local lvl = tonumber(step.lvl) or level
                                show = not InLog(lastByTitle, step.q) and TurnedIn(step.q) == part - 1
                                    and lvl <= level + G.above and not Outleveled(step, level)
                                    and PrereqsMet(step.q, level)
                            else
                                local entry = HeldPart(lastByTitle, step)
                                show = entry and entry.ready or false
                            end
                            if show then
                                list[#list + 1] = { kind = step.t, title = step.q, npc = step.npc, level = step.lvl,
                                    zone = G.StepZone(route, step), x = step.x / 100, y = step.y / 100 }
                                keys[#keys + 1] = id
                            end
                        end
                    end
                end
            end
        end
        table.sort(keys)
        return list, table.concat(keys, ";")
    end

    -- { { kind = "accept"|"turnin", title, npc, level, zone, x, y (0-1) } }, plus a key that changes when the
    -- list does. Worked out again after each of the guide's own rebuilds, or when your level changes.
    function LevelGuide_QuestGivers()
        if not (charData and lastByTitle and type(LevelGuideRoutes) == "table" and RoutesForYou()) then
            return {}, ""
        end
        local level = UnitLevel and Safe(UnitLevel("player"))
        if type(level) ~= "number" then
            return G.cache or {}, G.key or ""
        end
        if not (G.cache and G.forLog == lastByTitle and G.level == level) then
            local ok, list, key = pcall(G.Build, level)
            if ok then
                G.cache, G.key = list, key
            else
                G.cache, G.key = {}, ""
                if geterrorhandler then
                    geterrorhandler()(list)
                end
            end
            G.forLog, G.level = lastByTitle, level
        end
        return G.cache, G.key
    end
end
