-- A step-by-step leveling guide worked out live from your quest log and the map, with an arrow.
-- It never accepts, completes or turns in anything: you do the clicking.
local WIDTH, HEADER_HEIGHT, ARROW_SIZE = 330, 22, 44
local MAX_NEXT = 3
local ARRIVED_YARDS = 12
local KEEP_RATIO = 1.3       -- the current step stays until another is this much closer, so it doesn't flicker
local TURNIN_BIAS = 0.7      -- a ready turn-in is worth going a bit further for: it's XP now
local PICKUP_BIAS = 0.4      -- quest givers nearby come before heading out; a turn-in at the same
                             -- spot still comes first (it can unlock the next pick-up)
local TRIVIAL_PENALTY = 400  -- gray quests come last unless they're right there
local HARD_LEVELS = 5        -- red quests are left out until you're closer to their level
local ARROW_SECONDS, ROUTE_SECONDS = 0.05, 2
local AHEAD_RADIANS = 0.35
local XP_WEIGHT = 2          -- a quest worth a fifth of a level counts as 1.4 times closer
local NO_SCALE_UNITS = 1000  -- without the map's size in yards, distances are only compared, never shown
local OUTLEVELED = 4         -- route steps this far below you count as done, so a route can start midway
local ROUTE_WINDOW = 10      -- how many upcoming route steps may be reordered to save walking
local ZONE_MAP_TYPE = 3      -- Enum.UIMapType.Zone: caves and buildings below this report up to their zone

local KINDS = {
    turnin = { label = "Turn in", color = "|cff33ff33" },
    work = { label = "Do", color = "|cffffd100" },
    pickup = { label = "Pick up", color = "|cff66ccff" },
    travel = { label = "Go to", color = "|cffff9933" },
    level = { label = "Reach level", color = "|cffff8040" },  -- the route waits on your level (LevelStep)
}
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
local frontiers = {}
local progressMarks = {}
local turnedCache = {}
local offersByNpc, visit = {}, nil  -- what each quest giver offered when you last talked to them
local VISIT_SECONDS = 60
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

local function NpcKey(npc)
    return npc and (npc:match("^%s*([^,(]-)%s*[,(]") or npc:match("^%s*(.-)%s*$")) or nil
end

local function StepKey(step)
    return step and (step.routeKey or (step.kind .. ":" .. tostring(step.id or step.zone))) or nil
end

-- How many yards one whole map width and height cover, from the map's own corners.
local function MapScale(mapID)
    if scales[mapID] ~= nil then
        return scales[mapID] or nil
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
            local width = math.sqrt((ex - ox) ^ 2 + (ey - oy) ^ 2)
            local height = math.sqrt((sx - ox) ^ 2 + (sy - oy) ^ 2)
            if width > 0 and height > 0 then
                scale = { width, height }
            end
        end
    end
    scales[mapID] = scale
    return scale or nil
end

-- Yards east and south from one map point to another, and whether those are real yards.
local function Offset(mapID, fromX, fromY, toX, toY)
    local scale = MapScale(mapID)
    if scale then
        return (toX - fromX) * scale[1], (toY - fromY) * scale[2], true
    end
    return (toX - fromX) * NO_SCALE_UNITS, (toY - fromY) * NO_SCALE_UNITS, false
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
        if not (mapType and mapType > ZONE_MAP_TYPE and parent and parent > 0) then
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

local function PositionOn(mapID)
    local position = C_Map and C_Map.GetPlayerMapPosition and C_Map.GetPlayerMapPosition(mapID, "player")
    if not position then
        return nil
    end
    local x, y = position:GetXY()
    return Safe(x), Safe(y)
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
        if id and not Safe(info.isHeader) and not Safe(info.isHidden) and not Safe(info.isTask) and not db.skipped[id] then
            local questLevel = Safe(info.difficultyLevel) or Safe(info.level)
            local ready = (Safe(C_QuestLog.IsComplete(id)) or Safe(C_QuestLog.ReadyForTurnIn(id))) and true or false
            local failed = C_QuestLog.IsFailed and Safe(C_QuestLog.IsFailed(id))
            local tooHard = not ready and level and questLevel and questLevel - level >= HARD_LEVELS
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
                    away[#away + 1] = { step = step, zone = ZoneName(waypointMap) }
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
    if requestedMap ~= mapID and C_QuestLine.RequestQuestLinesForMap then
        requestedMap = mapID
        C_QuestLine.RequestQuestLinesForMap(mapID)
    end
    for _, info in ipairs(C_QuestLine.GetAvailableQuestLines(mapID) or {}) do
        local id, name, x, y = Safe(info.questID), Safe(info.questName), Safe(info.x), Safe(info.y)
        local startMap = Safe(info.startMapID)
        if id and name and x and y and not Safe(info.isHidden) and not Safe(info.inProgress) and not db.skipped[id]
            and (not startMap or startMap == 0 or startMap == mapID) then
            offers[#offers + 1] = { id = id, kind = "pickup", title = name, mapID = mapID, x = x, y = y }
        end
    end
    return offers
end

local function Cost(step, mapID, fromX, fromY)
    local cost = Distance(mapID, fromX, fromY, step.x, step.y)
    if step.kind == "turnin" then
        cost = cost * TURNIN_BIAS
    elseif step.kind == "pickup" then
        -- Picking a quest up takes seconds and gives you more to do on the way, so sweep the hub first.
        cost = cost * PICKUP_BIAS
    end
    local maxXP = MaxXP()
    if step.xp and step.xp > 0 and maxXP then
        cost = cost / (1 + XP_WEIGHT * step.xp / maxXP)
    end
    if step.trivial then
        cost = cost + TRIVIAL_PENALTY
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
    local fromX, fromY = playerX, playerY
    while #remaining > 0 do
        local bestIndex, bestCost
        for index, step in ipairs(remaining) do
            local cost = Cost(step, mapID, fromX, fromY)
            if not bestCost or cost < bestCost then
                bestIndex, bestCost = index, cost
            end
        end
        if #route == 0 and currentKey then
            for index, step in ipairs(remaining) do
                if StepKey(step) == currentKey and Cost(step, mapID, fromX, fromY) <= bestCost * KEEP_RATIO then
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
    end
    table.sort(order, function(a, b)
        return a.count > b.count
    end)
    return order
end

-- Hand-written routes (Routes.lua). Progress is read from your quest log, plus a count of what this
-- character has turned in, kept by title since several quests in a chain share one.
local ROUTE_KINDS = { accept = "pickup", ["do"] = "work", turnin = "turnin", go = "travel" }

local function LogByTitle()
    local byTitle = {}
    frontiers = {}
    progressMarks = {}
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

local function ZoneMap(zoneName)
    local mapID = C_Map and C_Map.GetBestMapForUnit and Safe(C_Map.GetBestMapForUnit("player"))
    for _ = 1, 6 do
        local info = mapID and C_Map.GetMapInfo and C_Map.GetMapInfo(mapID)
        if not info then
            return nil
        end
        if Safe(info.name) == zoneName then
            return mapID
        end
        mapID = Safe(info.parentMapID)
        if not mapID or mapID == 0 then
            return nil
        end
    end
end

local function RouteKey(route, index)
    return route.zone .. "#" .. index
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

local function TurnedIn(title)
    if turnedCache[title] then
        return turnedCache[title]
    end
    local counted = math.max(charData.done[title] or 0, charData.done[RealTitle(title)] or 0)
    local data = LevelGuideQuestIDs
    local ids = data and data.ids and (data.ids[title] or data.ids[RealTitle(title)])
    if ids and C_QuestLog.IsQuestFlaggedCompleted then
        local flagged = 0
        for _, id in ipairs(ids) do
            if Safe(C_QuestLog.IsQuestFlaggedCompleted(id)) then
                flagged = flagged + 1
            end
        end
        counted = math.max(counted, flagged)
    end
    turnedCache[title] = counted
    return counted
end

-- The log entry for this step's quest and part: holding part 3 of a chain is not holding part 1.
local function HeldPart(byTitle, step)
    local entry = InLog(byTitle, step.q)
    if entry and entry.part and entry.part ~= (tonumber(step.part) or 1) then
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

-- The furthest pick-up on the route you've taken (in your log or turned in). A move written before
-- it is behind you even if the addon never saw you reach the spot.
local function LastProgress(route, byTitle)
    if progressMarks[route] == nil then
        local furthest = 0
        for index, step in ipairs(route.steps) do
            if step.t == "accept" then
                -- Holding part 1 of a chain says nothing about where part 8's pick-up is.
                local held = InLog(byTitle, step.q)
                local part = tonumber(step.part) or 1
                if (held and (not held.part or held.part >= part)) or TurnedIn(step.q) >= part then
                    furthest = index
                end
            end
        end
        progressMarks[route] = furthest
    end
    return progressMarks[route]
end

-- Prerequisites (Prereqs.lua, from Questie's Forever data): a quest giver only offers a quest once
-- these are done, so the guide waits for them too. Completion comes from the game's own record.
local titleByID

local function QuestDone(id)
    if C_QuestLog.IsQuestFlaggedCompleted and Safe(C_QuestLog.IsQuestFlaggedCompleted(id)) then
        return true
    end
    if not titleByID then
        titleByID = {}
        for title, ids in pairs(LevelGuideQuestIDs and LevelGuideQuestIDs.ids or {}) do
            for _, questID in ipairs(ids) do
                titleByID[questID] = title
            end
        end
    end
    local title = titleByID[id] or titlesByID[id]
    return title ~= nil and (charData.done[title] or 0) > 0
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

-- Quests the map shows as available in a zone, by title and by quest ID. Nil when you're not in that
-- zone or the game lists none, so the written route is used as it is.
local function MapOffers(zoneName)
    if zoneOffers[zoneName] ~= nil then
        return zoneOffers[zoneName] or nil
    end
    local result = false
    local zoneMap = C_QuestLine and C_QuestLine.GetAvailableQuestLines and ZoneMap(zoneName)
    if zoneMap then
        if requestedMap ~= zoneMap and C_QuestLine.RequestQuestLinesForMap then
            requestedMap = zoneMap
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
local function RouteStepDone(route, index, step, byTitle, level)
    local key = RouteKey(route, index)
    if charData.skips[key] then
        return true
    end
    -- You've talked to this quest giver and they don't offer it (yet), so don't send you back.
    if step.t == "accept" and not InLog(byTitle, step.q) then
        -- The map's "!" markers are the game saying what you can pick up right now. A quest it lists is
        -- on offer whatever else says; one it doesn't list may still be (the map doesn't know every
        -- quest), so then the giver's own window and the quest's prerequisites decide.
        local onMap = MapOffers(route.zone)
        if not (onMap and OfferedOnMap(onMap, step.q)) then
            local offers = offersByNpc[NpcKey(step.npc) or ""]
            if offers and not (offers[step.q] or offers[RealTitle(step.q)]) then
                return true
            end
            if not PrereqsMet(step.q, level) then
                return true
            end
        end
    end
    -- Behind the frontier: moves are behind you, and so are pick-ups the game can't vouch for.
    -- A pick-up with quest IDs is asked of the game instead, so one you took out of order still shows.
    local frontier = Frontier(route, byTitle)
    if frontier and index < frontier and (step.t == "go" or (step.t == "accept" and not HasIDs(step.q))) then
        return true
    end
    if level and step.lvl and level >= step.lvl + OUTLEVELED then
        return true
    end
    if step.t == "go" then
        return charData.visited[key] or index < LastProgress(route, byTitle)
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
        return entry.ready
    end
    return false
end

-- Whether a step can be done right now: a pick-up whose earlier part is turned in and whose level
-- you've nearly reached, objectives for a quest you have, or a turn-in that's ready.
local function OfferVisit(npc)
    if not (visit and visit.npc == npc and GetTime() - visit.time < VISIT_SECONDS) then
        visit = { npc = npc, time = GetTime(), listed = false }
    end
    return visit
end

-- What a quest giver offers, read from their window when you talk to them. The route is written
-- for a typical character, but a giver may want an earlier quest done first; this is the truth.
local function RecordOffers(event)
    local npc = NpcKey(Safe(UnitName("npc")))
    if not npc then
        return
    end
    local current = OfferVisit(npc)
    if event == "GOSSIP_SHOW" or event == "QUEST_GREETING" then
        local offers = {}
        if event == "GOSSIP_SHOW" and C_GossipInfo and C_GossipInfo.GetAvailableQuests then
            for _, info in ipairs(C_GossipInfo.GetAvailableQuests() or {}) do
                local title = Safe(info.title)
                if title then
                    offers[title] = true
                end
            end
        elseif event == "QUEST_GREETING" and GetNumAvailableQuests and GetAvailableTitle then
            for index = 1, Safe(GetNumAvailableQuests()) or 0 do
                local title = Safe(GetAvailableTitle(index))
                if title then
                    offers[title] = true
                end
            end
        end
        offersByNpc[npc] = offers
        current.listed = true
    elseif event == "QUEST_DETAIL" then
        local title = GetTitleText and Safe(GetTitleText())
        if title then
            -- Straight to one quest's page means it's the only one they have for you.
            if not current.listed then
                offersByNpc[npc] = {}
            end
            offersByNpc[npc] = offersByNpc[npc] or {}
            offersByNpc[npc][title] = true
        end
    elseif not current.listed then
        -- Straight to a turn-in page means nothing else is on offer.
        offersByNpc[npc] = offersByNpc[npc] or {}
    end
end

-- Quest givers often offer the next quest only after an earlier one with them, so a pick-up waits
-- while anything earlier on the route with that same person is still to do.
local function RouteStepActionable(step, byTitle, level, busyNpcs)
    if step.t == "go" then
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
        return entry ~= nil and not entry.ready
    end
    return entry ~= nil and entry.ready
end

-- A turn-in you don't hold yet whose pick-up is still ahead of you on this route: the person waiting
-- for it won't offer what comes after until it's done. Quests with no pick-up on this route (from
-- items or other zones) and pick-ups you skipped, outleveled or are past don't count, or they would
-- keep that person's later pick-ups hidden for good. Pick-ups themselves never count: a giver who
-- doesn't offer one may still offer another.
local function Gone(route, index, step, level, byTitle)
    if charData.skips[RouteKey(route, index)] or (level and step.lvl and level >= step.lvl + OUTLEVELED) then
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
    end
    return cityMaps[key]
end

local function CityToZone(zoneMap, step, x, y)
    local text = step.npc or step.note or ""
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
    if cityPoints[key] == nil then
        local cityMap = CityMap(zoneMap, city)
        if cityMap then
            cityPoints[key] = false
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
    end
    local point = cityPoints[key]
    if point and point[1] and point[2] then
        return point[1], point[2]
    end
    -- No conversion: better no point than one in the wrong place.
    return nil
end

local function RouteDisplay(route, index, step, byTitle, zoneMap)
    local entry = step.q and HeldPart(byTitle, step)
    local shown = {
        kind = ROUTE_KINDS[step.t], title = step.q or step.text, routeKey = RouteKey(route, index),
        id = entry and entry.id, zone = route.zone,
    }
    if step.t == "accept" then
        shown.detail = "From " .. tostring(step.npc or "?")
    elseif step.t == "turnin" then
        shown.detail = "To " .. tostring(step.npc or "?")
    elseif step.t == "do" then
        local progress = entry and FirstUnfinished(entry.id)
        shown.detail = progress and step.note and (step.note .. ". Now: " .. progress) or progress or step.note
    else
        shown.detail = step.note
    end
    if entry then
        shown.xp = RewardXP(entry.id)
    end
    if step.map then
        -- Written on another zone's map (Routes.lua On()): placed only while you're in that zone, never
        -- at the same numbers on the route's own map.
        local onMap = ZoneMap(step.map)
        if onMap and step.x and step.y then
            shown.mapID, shown.x, shown.y = onMap, step.x / 100, step.y / 100
        end
    elseif zoneMap and step.x and step.y then
        local x, y = CityToZone(zoneMap, step, step.x / 100, step.y / 100)
        if x then
            shown.mapID, shown.x, shown.y = zoneMap, x, y
        end
    end
    return shown
end

-- A pick-up hidden only because its prerequisites (a level, an earlier quest) aren't met yet is still
-- work this route owes you, so the route isn't finished while one remains.
local function RouteStepPending(route, index, step, byTitle, level)
    if step.t ~= "accept" or charData.skips[RouteKey(route, index)] or InLog(byTitle, step.q) then
        return false
    end
    if level and step.lvl and level >= step.lvl + OUTLEVELED then
        return false
    end
    return TurnedIn(step.q) < (tonumber(step.part) or 1) and not PrereqsMet(step.q, level)
end

local function RouteUnfinished(route, byTitle, level)
    for index, step in ipairs(route.steps) do
        if not RouteStepDone(route, index, step, byTitle, level) or RouteStepPending(route, index, step, byTitle, level) then
            return true
        end
    end
    return false
end

-- Something on the route you can do right now. A route whose only open steps are pick-ups you're too
-- low for (or whose earlier quest isn't done) is unfinished, but has nothing for you yet.
local function RouteHasWork(route, byTitle, level)
    for index, step in ipairs(route.steps) do
        if not RouteStepDone(route, index, step, byTitle, level)
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
        if step.t == "accept" and not charData.skips[RouteKey(route, index)] and not InLog(byTitle, step.q)
            and TurnedIn(step.q) == part - 1 and not (step.lvl and level >= step.lvl + OUTLEVELED)
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
local function FindRoute(level, byTitle)
    local chains = LevelGuideRoutes and LevelGuideRoutes.chains
    local race = UnitRace and Safe(select(2, UnitRace("player")))
    local routes = chains and race and chains[race] or {}
    -- The zone you're standing in comes first once you're its level: a few leftover steps in the
    -- zone before shouldn't keep the guide pointing back there.
    -- ZoneMap climbs from the map you're on (a town, a cave, a city) to its zone, so standing in
    -- Darnassus or Dolanaar still counts as Teldrassil.
    local stuckHere
    for _, route in ipairs(routes) do
        if level >= route.min and level <= route.max and ZoneMap(route.zone) and RouteUnfinished(route, byTitle, level) then
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
        if level <= route.max and level >= route.min - 2 and RouteHasWork(route, byTitle, level) then
            return route, stuckHere
        end
    end
    if stuckHere then
        return stuckHere
    end
    for _, route in ipairs(routes) do
        if level <= route.max and level >= route.min - 2 and RouteUnfinished(route, byTitle, level) then
            return route
        end
    end
end

-- The plan's dungeon hint for your level, if any.
local function PlanNote(level)
    for _, entry in ipairs(LevelGuideRoutes and LevelGuideRoutes.plan or {}) do
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

local function RouteSteps(level)
    if not charData then
        return nil
    end
    local byTitle = LogByTitle()
    local route, stuckHere = FindRoute(level, byTitle)
    if not route then
        return nil
    end
    local zoneMap = ZoneMap(route.zone)
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
        local written = {}
        for index, step in ipairs(route.steps) do
            if #written >= MAX_NEXT then
                break
            end
            if not RouteStepDone(route, index, step, byTitle, level)
                and (step.t ~= "accept" or RouteStepActionable(step, byTitle, level, {})) then
                written[#written + 1] = RouteDisplay(route, index, step, byTitle, nil)
            end
        end
        -- A route leg written on this map (Routes.lua On(), e.g. Duskwood's Sven leg in Stormwind) is
        -- done here: no "go back" line before it.
        if not (written[1] and written[1].mapID) then
            list[#list + 1] = { kind = "travel", title = route.zone, detail = why, zone = route.zone }
        end
        for _, shown in ipairs(written) do
            list[#list + 1] = shown
        end
        if #written == 0 then
            list[#list + 1] = LevelStep(route, byTitle, level, nil)
        end
        return list, route
    end

    -- The written order is a good plan, but what you can do right now, nearby, should come first:
    -- the next several steps are reordered by distance and XP, up to the next "go" step, which marks
    -- a move the route wants made in order.
    local ready, waiting = {}, {}
    local busyNpcs = {}
    local considered = 0
    for index, step in ipairs(route.steps) do
        if not RouteStepDone(route, index, step, byTitle, level) then
            if step.t == "go" and considered == 0 then
                -- The move comes first; what follows it stays in written order behind it.
                ready[1] = RouteDisplay(route, index, step, byTitle, zoneMap)
                for nextIndex = index + 1, #route.steps do
                    if #waiting >= MAX_NEXT then
                        break
                    end
                    local nextStep = route.steps[nextIndex]
                    if not RouteStepDone(route, nextIndex, nextStep, byTitle, level)
                        and (nextStep.t ~= "accept" or RouteStepActionable(nextStep, byTitle, level, {})) then
                        waiting[#waiting + 1] = RouteDisplay(route, nextIndex, nextStep, byTitle, zoneMap)
                    end
                end
                break
            end
            if step.t == "go" then
                waiting[#waiting + 1] = RouteDisplay(route, index, step, byTitle, zoneMap)
                break
            end
            local shown = RouteDisplay(route, index, step, byTitle, zoneMap)
            local actionable = RouteStepActionable(step, byTitle, level, busyNpcs) and shown.x
            -- A pick-up you can't take yet isn't shown at all: it would only send you to someone
            -- with nothing to give you. Only what's shown uses up the window.
            local visible = actionable or step.t ~= "accept"
            if considered >= ROUTE_WINDOW then
                if visible then
                    waiting[#waiting + 1] = shown
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
    -- The route is a plan, not the whole truth: quests in your log it doesn't know (or hasn't reached
    -- yet) and "!" quests the map shows that it doesn't list are on offer too, so they join the pool.
    local known = {}
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
    for _, extra in ipairs(here) do
        if not known[extra.id] and not (extra.kind == "pickup" and known[extra.title]) then
            known[extra.id] = true
            ready[#ready + 1] = extra
        end
    end
    local playerX, playerY = PositionOn(zoneMap)
    if playerX and playerY then
        ready = Route(ready, zoneMap, playerX, playerY)
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
    for _, entry in ipairs(LevelGuideRoutes and LevelGuideRoutes.plan or {}) do
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
    return { kind = "travel", title = table.concat(plan.zones, " or "), detail = detail, zone = plan.zones[1] }
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

local function ReadyShare(list)
    local total, maxXP = 0, MaxXP()
    for _, step in ipairs(list) do
        if step.kind == "turnin" then
            total = total + (step.xp or 0)
        end
    end
    return maxXP and total > 0 and math.floor(total * 100 / maxXP) or nil
end

-- A running timed quest goes to the top, whatever the route says; a failed one asks to be redone.
local function PutTimedFirst(list)
    for index = 1, Safe(C_QuestLog.GetNumQuestLogEntries()) or 0 do
        local info = C_QuestLog.GetInfo(index)
        local id, title = info and Safe(info.questID), info and Safe(info.title)
        if id and title and not Safe(info.isHeader) and not Safe(info.isHidden) and not db.skipped[id] then
            local failed = C_QuestLog.IsFailed and Safe(C_QuestLog.IsFailed(id))
            local ends = not failed and TimerEnds(id)
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

local function BuildSteps()
    local mapID, playerX, playerY = PlayerPosition()
    local level = Safe(UnitLevel("player")) or 1
    local routed
    routed, activeRoute = RouteSteps(level)
    if routed then
        PutTimedFirst(routed)
        MarkLevelUp(routed)
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
        parts[#parts + 1] = string.format("%d quest(s) for level %d+", #later, later[1] - HARD_LEVELS + 1)
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
    return kind.color .. kind.label .. ":|r " .. step.title .. tags
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
    if (step.kind == "pickup" or (step.routeKey and not step.id)) and step.mapID and step.x then
        if C_Map.SetUserWaypoint and UiMapPoint and UiMapPoint.CreateFromCoordinates then
            C_Map.SetUserWaypoint(UiMapPoint.CreateFromCoordinates(step.mapID, step.x, step.y))
            if C_SuperTrack and C_SuperTrack.SetSuperTrackedUserWaypoint then
                C_SuperTrack.SetSuperTrackedUserWaypoint(true)
            end
        end
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
        if last.routeKey and charData then
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

local function Render(mapID, playerX, playerY, later)
    local current = steps[1]
    local y = -HEADER_HEIGHT
    local level = Safe(UnitLevel("player"))
    local xp, maxXP = Safe(UnitXP("player")), Safe(UnitXPMax("player"))
    if level and xp and maxXP and maxXP > 0 then
        local ready = ReadyShare(steps)
        local readyText = ready and string.format("  |cff33ff33+%d%% ready to turn in|r", ready) or ""
        local title = activeRoute and ("Route: " .. activeRoute.zone) or "Guide"
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
    currentRow:SetPoint("RIGHT", frame, "RIGHT", -(ARROW_SIZE + 16), 0)
    y = y - 22
    detailText:ClearAllPoints()
    detailText:SetPoint("TOPLEFT", frame, "TOPLEFT", 10, y)
    detailText:SetPoint("RIGHT", frame, "RIGHT", -(ARROW_SIZE + 16), 0)
    y = y - math.max(detailText:GetStringHeight(), 12) - 6
    y = math.min(y, -HEADER_HEIGHT - ARROW_SIZE - 14)

    local shown = 0
    if not db.collapsed then
        for index = 2, MAX_NEXT + 1 do
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
    -- Read your position on the step's own map, so a city or cave map inside the zone still works.
    local mapID = step and step.mapID
    local playerX, playerY
    if mapID then
        playerX, playerY = PositionOn(mapID)
    end
    if not (step and step.x and playerX) then
        arrow:Hide()
        yardsText:SetText(step and step.kind == "travel" and COLOR_DIM .. "other zone|r" or "")
        return
    end
    local east, south, isYards = Offset(mapID, playerX, playerY, step.x, step.y)
    local yards = math.sqrt(east * east + south * south)
    if isYards and yards <= ARRIVED_YARDS then
        arrow:Hide()
        yardsText:SetText("|cff33ff33You're there|r")
        if step.routeKey and step.kind == "travel" and charData and not charData.visited[step.routeKey] then
            charData.visited[step.routeKey] = true
            dirty = true
        end
        return
    end
    yardsText:SetText(isYards and string.format("%d yd", math.floor(yards)) or "")
    local facing = GetPlayerFacing and Safe(GetPlayerFacing())
    if not facing then
        arrow:Hide()
        return
    end
    local relative = atan2(-east, -south) - facing
    arrow:SetRotation(relative)
    local wrapped = (relative + math.pi) % (2 * math.pi) - math.pi
    if math.abs(wrapped) < AHEAD_RADIANS then
        arrow:SetVertexColor(0.3, 1, 0.3)
    else
        arrow:SetVertexColor(1, 0.82, 0)
    end
    arrow:Show()
end

local function Rebuild()
    local mapID, playerX, playerY, later
    steps, mapID, playerX, playerY, later = BuildSteps()
    currentKey = StepKey(steps[1])
    Render(mapID, playerX, playerY, later)
    UpdateArrow()
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
    -- A burst of quest events (looting, zoning) rebuilds once, not once per frame.
    if (dirty and sinceRoute >= DIRTY_SECONDS) or sinceRoute >= ROUTE_SECONDS then
        dirty, sinceRoute, sinceArrow = false, 0, 0
        Attempt(Rebuild)
    elseif sinceArrow >= ARROW_SECONDS then
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
    frame:SetWidth(WIDTH)
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
    header:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -26, -3)
    header:SetHeight(HEADER_HEIGHT - 4)
    header:RegisterForDrag("LeftButton")
    header:RegisterForClicks("RightButtonUp")
    header:SetScript("OnDragStart", function()
        frame:StartMoving()
    end)
    header:SetScript("OnDragStop", function()
        frame:StopMovingOrSizing()
        SavePosition()
    end)
    header:SetScript("OnClick", function()
        if IsShiftKeyDown and IsShiftKeyDown() then
            UndoAllSkips()
        elseif not UndoSkip() then
            -- Nothing skipped this session: fall back to bringing everything back.
            UndoAllSkips()
        end
    end)
    header:SetScript("OnEnter", function(self)
        Tip():SetOwner(self, "ANCHOR_LEFT")
        Tip():SetText("Leveling guide")
        Tip():AddLine("Steps are worked out from your quest log and map, nearest first.", 1, 1, 1, true)
        Tip():AddLine("Drag to move. Right-click: undo the last skip. Shift+right-click: bring back every skipped step.", 0.6, 0.6, 0.6, true)
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

    -- Blizzard's own navigation arrow art, which points up when unrotated.
    arrow = frame:CreateTexture(nil, "OVERLAY")
    if C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo("Navigation-Tracked-Arrow") then
        arrow:SetAtlas("Navigation-Tracked-Arrow")
    else
        arrow:SetTexture("Interface\\MINIMAP\\MiniMap-QuestArrow")
    end
    arrow:SetSize(ARROW_SIZE * 0.6, ARROW_SIZE)
    arrow:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -14, -HEADER_HEIGHT - 2)
    arrow:Hide()
    yardsText = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    yardsText:SetPoint("TOP", arrow, "BOTTOM", 0, -1)

    currentRow = MakeStepButton(20, "GameFontNormal")
    detailText = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    detailText:SetJustifyH("LEFT")
    detailText:SetWordWrap(true)
    for index = 1, MAX_NEXT do
        nextRows[index] = MakeStepButton(16, "GameFontHighlightSmall")
        nextRows[index]:Hide()
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
    "QUESTLINE_UPDATE", "QUEST_POI_UPDATE" }) do
    -- Events this client doesn't have are left out rather than stopping the addon.
    pcall(events.RegisterEvent, events, name)
end
events:SetScript("OnEvent", function(_, event, questID)
    if event == "PLAYER_LOGIN" then
        LevelGuideDB = LevelGuideDB or {}
        db = LevelGuideDB
        db.skipped = db.skipped or {}
        db.characters = db.characters or {}
        local key = (Safe(UnitName("player")) or "Unknown") .. "-" .. (Safe(GetRealmName()) or "Unknown")
        db.characters[key] = db.characters[key] or {}
        charData = db.characters[key]
        charData.done = charData.done or {}
        charData.skips = charData.skips or {}
        charData.visited = charData.visited or {}
        Attempt(Build)
        return
    end
    if not db then
        return
    end
    questID = Safe(questID)
    if event == "QUEST_REMOVED" and questID then
        db.skipped[questID] = nil
        -- Picked up again later, a timed quest should warn again.
        timedWarned[questID], lowWarned[questID] = nil, nil
    elseif event == "QUEST_TURNED_IN" and questID then
        local title = titlesByID[questID] or (C_QuestLog.GetTitleForQuestID and Safe(C_QuestLog.GetTitleForQuestID(questID)))
        if title then
            charData.done[title] = (charData.done[title] or 0) + 1
        end
        -- Turning a quest in can open new ones anywhere, so what givers offered is out of date.
        offersByNpc = {}
    elseif event == "PLAYER_LEVEL_UP" then
        offersByNpc = {}
    elseif event == "QUEST_ACCEPTED" then
        -- Taking a quest can unlock the giver's next one, so what they offered is out of date.
        local npc = NpcKey(Safe(UnitName("npc")))
        if npc then
            offersByNpc[npc] = nil
        end
    elseif event == "ZONE_CHANGED_NEW_AREA" then
        requestedMap = nil
    elseif event == "GOSSIP_SHOW" or event == "QUEST_GREETING" or event == "QUEST_DETAIL"
        or event == "QUEST_PROGRESS" or event == "QUEST_COMPLETE" then
        Attempt(function()
            RecordOffers(event)
        end)
    end
    dirty = true
end)
