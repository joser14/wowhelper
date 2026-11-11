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

local WIDTH, HEADER_HEIGHT, MAX_ROWS = 290, 24, 40
local SECTION_HEIGHT, TITLE_HEIGHT, OBJECTIVE_HEIGHT = 19, 18, 14
local ITEM_SIZE, BAR_HEIGHT = 18, 2
local BOTTOM_MARGIN, MIN_ROOM, OVERFLOW_HEIGHT, PANEL_PADDING = 12, 120, 16, 6
local RESORT_SECONDS, NEW_SECONDS, MAX_OFFERS = 3, 3600, 3
-- Room under the minimap for the coordinate line other addons draw there.
local MINIMAP_GAP = 22
local YARDS_LABEL = "%d yd away"
local OTHER_ZONE = "Other quests"

local COLOR_READY = "|cff33ff33"
local COLOR_DIM = "|cff999999"
local COLOR_NEW = "|cff66ccff"
local COLOR_FOCUS = "|cffffd100"
local COLOR_WARN = "|cffff8040"
local COLOR_BAD = "|cffff3333"

local db, panel, headerTitle, collapseButton
local rows, itemButtons = {}, {}
local atlasKnown = {}
local shownRows, shownButtons = 0, 0
local dirty, layoutWaiting, moving = true, false, false
-- forceLayout: you changed the list yourself (folded a zone, moved it), so it redraws even under the mouse.
-- staleLayout: something changed while the mouse was on the list; it re-sorts once the mouse leaves.
local forceLayout, staleLayout = false, false
local lastOrder
local secondsSinceSort = 0
local readySeen
local requested = {}
-- Reward items asked for once each; waitingItems is what GET_ITEM_INFO_RECEIVED should wake us for.
local requestedItems, waitingItems = {}, {}
local upgradeCache = {}
local requestedMap
local OFFERS_SECTION = { name = "Quests nearby", quests = {}, isLocal = true,
    note = "Quests the game shows on your map that you haven't picked up. Click one to mark it." }

local function Safe(value)
    if issecretvalue and issecretvalue(value) then
        return nil
    end
    return value
end

local function InCombat()
    return InCombatLockdown and InCombatLockdown()
end

-- This addon's own tooltip, so nothing is ever written into Blizzard's GameTooltip.
local ownTip
local function Tip()
    if not ownTip then
        ownTip = CreateFrame("GameTooltip", "QuestTrackerTooltip", UIParent, "GameTooltipTemplate")
    end
    return ownTip
end

-- Inline atlas icon, or plain text when this client doesn't have that atlas.
local function Icon(atlas, size, fallback)
    if atlasKnown[atlas] == nil then
        atlasKnown[atlas] = (C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(atlas)) and true or false
    end
    if atlasKnown[atlas] then
        return string.format("|A:%s:%d:%d|a", atlas, size, size)
    end
    return fallback
end

local function Notify(text)
    if ForeverHub_Receive then
        ForeverHub_Receive("Quests", text)
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

local function FormatNumber(value)
    local text = tostring(math.floor(value))
    while true do
        local changed
        text, changed = text:gsub("^(%d+)(%d%d%d)", "%1,%2")
        if changed == 0 then
            return text
        end
    end
end

-- The game's quest colors, from how far the quest is above or below you.
local function DifficultyColor(quest)
    if quest.trivial then
        return COLOR_DIM
    end
    local playerLevel = Safe(UnitLevel("player"))
    local difference = playerLevel and quest.level and quest.level - playerLevel or 0
    if difference >= 5 then
        return "|cffff3333"
    elseif difference >= 3 then
        return "|cffff8040"
    elseif difference >= -2 then
        return "|cffffd100"
    end
    return "|cff40c040"
end

-- Returns the shown objectives, the quest's progress (0-1), and which objectives (by the game's index)
-- are finished.
local function ReadObjectives(questID)
    local list, fulfilled, required, done = {}, 0, 0, {}
    for index, objective in ipairs(C_QuestLog.GetQuestObjectives(questID) or {}) do
        local text = Safe(objective.text)
        local finished = Safe(objective.finished)
        local have, need = Safe(objective.numFulfilled) or 0, Safe(objective.numRequired) or 0
        -- Forever's criteria objectives can read 1/1 while the game still says unfinished: that's 0/1
        -- (the same rule Questie uses). Only when "finished" is plainly false, never when it's hidden.
        if finished == false and have == 1 and need == 1 then
            have = 0
            if text then
                text = text:gsub("1%s*/%s*1", "0/1", 1)
            end
        end
        done[index] = finished == true
        if text and text ~= "" then
            list[#list + 1] = { text = text, finished = finished and true or false, have = have }
            fulfilled, required = fulfilled + math.min(have, need), required + need
        end
    end
    return list, required > 0 and fulfilled / required or 0, done
end

-- When the game gives no distance (often on Forever), the nearest unfinished objective camp from
-- LevelGuide's quest data, or the turn-in NPC once the quest is done. Read-only use of LevelGuide's
-- public lookup (LevelGuideQuestFacts); nil without LevelGuide or on another continent.
local campCache = {}
local function PlayerSpot()
    if not (C_Map and C_Map.GetBestMapForUnit and C_Map.GetPlayerMapPosition) then
        return nil
    end
    local mapID = Safe(C_Map.GetBestMapForUnit("player"))
    local position = mapID and C_Map.GetPlayerMapPosition(mapID, "player")
    if not position then
        return nil
    end
    local x, y = position:GetXY()
    x, y = Safe(x), Safe(y)
    if type(x) == "number" and type(y) == "number" then
        return mapID, x, y
    end
end

-- The camp points (0-1 on mapID) still worth walking to for a quest. Kept per quest, map and progress.
local function CampPoints(quest, done, mapID)
    local facts = LevelGuideQuestFacts
    if type(facts) ~= "table" or type(facts.Quest) ~= "function" or type(facts.Project) ~= "function" then
        return nil
    end
    local key = { mapID, quest.ready and "r" or "" }
    for index = 1, #done do
        key[#key + 1] = done[index] and "1" or "0"
    end
    key = table.concat(key, ",")
    local cached = campCache[quest.id]
    if cached and cached.key == key then
        return cached.points
    end
    local points = {}
    local function Add(map, x, y)
        local px, py = facts.Project(map, x, y, mapID)
        if type(px) == "number" and type(py) == "number" then
            points[#points + 1] = { px / 100, py / 100 }
        end
    end
    if quest.ready then
        if type(facts.EnderSpot) == "function" then
            local map, x, y = facts.EnderSpot(quest.id, mapID)
            if map then
                Add(map, x, y)
            end
        end
    else
        local q = facts.Quest(quest.id)
        for index, objective in ipairs(q and q.objectives or {}) do
            if not done[index] then
                for _, spot in ipairs(objective.spots or {}) do
                    Add(spot.map, spot.x, spot.y)
                end
            end
        end
    end
    campCache[quest.id] = { key = key, points = points }
    return points
end

local YardsBetween
local function CampDistance(quest, done)
    local mapID, px, py = PlayerSpot()
    if not mapID then
        return nil
    end
    local ok, points = pcall(CampPoints, quest, done, mapID)
    if not ok or not points or #points == 0 then
        return nil
    end
    -- The nearest point on the map first, then yards for that one only.
    local best, bestSq
    for _, point in ipairs(points) do
        local sq = (point[1] - px) ^ 2 + (point[2] - py) ^ 2
        if not bestSq or sq < bestSq then
            best, bestSq = point, sq
        end
    end
    return YardsBetween(mapID, px, py, best[1], best[2])
end

local function ObjectiveText(objective)
    if objective.finished then
        return Icon("ui-questtracker-tracker-check", 10, "") .. COLOR_READY .. objective.text .. "|r"
    elseif objective.have > 0 then
        return objective.text
    end
    return COLOR_DIM .. objective.text .. "|r"
end

local function ReadItem(logIndex)
    if not GetQuestLogSpecialItemInfo then
        return nil
    end
    local link, icon, _, showWhenComplete = GetQuestLogSpecialItemInfo(logIndex)
    link, icon = Safe(link), Safe(icon)
    if link and icon then
        return { link = link, icon = icon, showWhenComplete = Safe(showWhenComplete) and true or false }
    end
end

-- Quest rewards can load late; asking once per quest is enough.
local function RewardXP(questID)
    if not GetQuestLogRewardXP then
        return 0
    end
    if HaveQuestRewardData and not Safe(HaveQuestRewardData(questID)) and not requested[questID] then
        requested[questID] = true
        if C_QuestLog.RequestLoadQuestByID then
            C_QuestLog.RequestLoadQuestByID(questID)
        end
    end
    return Safe(GetQuestLogRewardXP(questID)) or 0
end

-- Looks through a quest's rewards for one ItemAdvisor would tell you to equip. Results are kept until
-- your gear or level changes, except while an item hasn't loaded yet.
local function CheckRewards(questID, count, getInfo)
    local pending = false
    for index = 1, count do
        local itemID = Safe(select(6, getInfo(index, questID)))
        local link = itemID and select(2, C_Item.GetItemInfo(itemID))
        link = Safe(link)
        if link then
            local isUpgrade, reason = ItemAdvisor_IsUpgrade(link)
            if isUpgrade then
                return { link = link, reason = reason }, false
            end
        elseif itemID then
            pending = true
            -- Once only: an item that never loads would otherwise be asked for on every refresh, and each
            -- answer would trigger another refresh.
            if not requestedItems[itemID] then
                requestedItems[itemID] = true
                waitingItems[itemID] = true
                C_Item.RequestLoadItemDataByID(itemID)
            end
        end
    end
    return nil, pending
end

local function FindRewardUpgrade(questID)
    if not ItemAdvisor_IsUpgrade then
        return nil
    end
    local known = upgradeCache[questID]
    if known ~= nil then
        return known or nil
    end
    if HaveQuestRewardData and not Safe(HaveQuestRewardData(questID)) then
        return nil
    end
    local found, pending = nil, false
    if GetNumQuestLogChoices and GetQuestLogChoiceInfo then
        found, pending = CheckRewards(questID, Safe(GetNumQuestLogChoices(questID)) or 0, GetQuestLogChoiceInfo)
    end
    if not found and GetNumQuestLogRewards and GetQuestLogRewardInfo then
        local fixedPending
        found, fixedPending = CheckRewards(questID, Safe(GetNumQuestLogRewards(questID)) or 0, GetQuestLogRewardInfo)
        pending = pending or fixedPending
    end
    if found or not pending then
        upgradeCache[questID] = found or false
    end
    return found
end

-- The same order Blizzard's tracker uses: the quest's own text, then its waypoint.
local function TurnInText(quest)
    if quest.autoComplete then
        return "Click to open the completion window"
    end
    local text = quest.logIndex and GetQuestLogCompletionText and Safe(GetQuestLogCompletionText(quest.logIndex))
    if text and text ~= "" then
        return text
    end
    text = C_QuestLog.GetNextWaypointText and Safe(C_QuestLog.GetNextWaypointText(quest.id))
    if text and text ~= "" then
        return text
    end
    return nil
end

local function ReadQuest(info, zone)
    local questID, title = Safe(info.questID), Safe(info.title)
    if not (questID and title) then
        return nil
    end
    -- Blizzard's quest log leaves these out too; they're bonus objectives, not quests you picked up.
    if Safe(info.isTask) or (Safe(info.isBounty) and not Safe(C_QuestLog.IsComplete(questID))) then
        return nil
    end
    local quest = {
        id = questID, title = title, zone = zone, logIndex = Safe(info.questLogIndex),
        autoComplete = Safe(info.isAutoComplete) and true or false,
        level = Safe(info.difficultyLevel) or Safe(info.level),
        group = Safe(info.suggestedGroup) or 0,
    }
    quest.ready = (Safe(C_QuestLog.IsComplete(questID)) or Safe(C_QuestLog.ReadyForTurnIn(questID))) and true or false
    quest.failed = C_QuestLog.IsFailed and Safe(C_QuestLog.IsFailed(questID)) or false
    quest.trivial = Safe(C_QuestLog.IsQuestTrivial(questID)) or false
    local done
    quest.objectives, quest.progress, done = ReadObjectives(questID)
    quest.xp = RewardXP(questID)
    quest.money = GetQuestLogRewardMoney and Safe(GetQuestLogRewardMoney(questID)) or 0
    if C_QuestLog.IsOnMap then
        quest.onMap = Safe((C_QuestLog.IsOnMap(questID))) or false
    end
    if C_QuestLog.GetDistanceSqToQuest then
        local distanceSq, onContinent = C_QuestLog.GetDistanceSqToQuest(questID)
        distanceSq, onContinent = Safe(distanceSq), Safe(onContinent)
        if distanceSq and onContinent then
            quest.distance = math.sqrt(distanceSq)
        end
    end
    if not quest.distance then
        quest.distance = CampDistance(quest, done)
    end
    -- Escort and delivery quests with a clock; the end time lets the row count down without rereading.
    if C_QuestLog.GetTimeAllowed and GetTime then
        local total, elapsed = C_QuestLog.GetTimeAllowed(questID)
        total, elapsed = Safe(total), Safe(elapsed)
        if total and elapsed and total > 0 then
            quest.timerEnds = GetTime() + total - elapsed
        end
    end
    if quest.logIndex then
        quest.item = ReadItem(quest.logIndex)
    end
    if quest.ready then
        quest.turnIn = TurnInText(quest)
    end
    quest.upgrade = FindRewardUpgrade(questID)
    return quest
end

-- Everything in the log, plus watched quests hidden under a collapsed log header.
-- The log files class and race quests under "Mage" or "Night Elf" rather than a zone.
local function PersonalHeaders()
    local names = {}
    local className = UnitClass and Safe((UnitClass("player")))
    local raceName = UnitRace and Safe((UnitRace("player")))
    if className then
        names[className] = true
    end
    if raceName then
        names[raceName] = true
    end
    return names
end

local function ReadQuests()
    local quests, seen = {}, {}
    local personal = PersonalHeaders()
    local entries = C_QuestLog.GetNumQuestLogEntries()
    local zone = OTHER_ZONE
    for index = 1, Safe(entries) or 0 do
        local info = C_QuestLog.GetInfo(index)
        if info and Safe(info.isHeader) then
            zone = Safe(info.title) or OTHER_ZONE
        elseif info and not Safe(info.isHidden) then
            local quest = ReadQuest(info, zone)
            if quest then
                quest.personal = personal[zone]
                quests[#quests + 1] = quest
                seen[quest.id] = true
            end
        end
    end
    if C_QuestLog.GetNumQuestWatches and C_QuestLog.GetQuestIDForQuestWatchIndex and C_QuestLog.GetLogIndexForQuestID then
        for index = 1, Safe(C_QuestLog.GetNumQuestWatches()) or 0 do
            local questID = Safe(C_QuestLog.GetQuestIDForQuestWatchIndex(index))
            if questID and not seen[questID] then
                local logIndex = Safe(C_QuestLog.GetLogIndexForQuestID(questID))
                local info = logIndex and C_QuestLog.GetInfo(logIndex)
                local quest = info and ReadQuest(info, OTHER_ZONE)
                if quest then
                    quests[#quests + 1] = quest
                    seen[questID] = true
                end
            end
        end
    end
    -- Camp points only for quests still in the log.
    for questID in pairs(campCache) do
        if not seen[questID] then
            campCache[questID] = nil
        end
    end
    return quests
end

YardsBetween = function(mapID, x1, y1, x2, y2)
    if not (C_Map and C_Map.GetWorldPosFromMapPos and CreateVector2D) then
        return nil
    end
    local _, first = C_Map.GetWorldPosFromMapPos(mapID, CreateVector2D(x1, y1))
    local _, second = C_Map.GetWorldPosFromMapPos(mapID, CreateVector2D(x2, y2))
    if not (first and second) then
        return nil
    end
    local ax, ay = first:GetXY()
    local bx, by = second:GetXY()
    ax, ay, bx, by = Safe(ax), Safe(ay), Safe(bx), Safe(by)
    if not (ax and ay and bx and by) then
        return nil
    end
    return math.sqrt((ax - bx) ^ 2 + (ay - by) ^ 2)
end

-- Where the game's own map gets its "!" markers. Empty if Forever doesn't offer any here.
local function ReadOffers()
    local offers = {}
    if not (C_QuestLine and C_QuestLine.GetAvailableQuestLines and C_Map and C_Map.GetBestMapForUnit) then
        return offers
    end
    local mapID = Safe(C_Map.GetBestMapForUnit("player"))
    if not mapID then
        return offers
    end
    if requestedMap ~= mapID and C_QuestLine.RequestQuestLinesForMap then
        requestedMap = mapID
        C_QuestLine.RequestQuestLinesForMap(mapID)
    end
    local position = C_Map.GetPlayerMapPosition and C_Map.GetPlayerMapPosition(mapID, "player")
    local px, py
    if position then
        px, py = position:GetXY()
        px, py = Safe(px), Safe(py)
    end
    for _, info in ipairs(C_QuestLine.GetAvailableQuestLines(mapID) or {}) do
        local questID, name, x, y = Safe(info.questID), Safe(info.questName), Safe(info.x), Safe(info.y)
        local startMap = Safe(info.startMapID)
        if questID and name and x and y and not Safe(info.isHidden) and not Safe(info.inProgress)
            and (not startMap or startMap == 0 or startMap == mapID) then
            local offer = { id = questID, name = name, mapID = mapID, x = x, y = y }
            if px and py then
                offer.mapDistance = (x - px) ^ 2 + (y - py) ^ 2
                offer.yards = YardsBetween(mapID, px, py, x, y)
            end
            offers[#offers + 1] = offer
        end
    end
    table.sort(offers, function(a, b)
        if a.mapDistance and b.mapDistance and a.mapDistance ~= b.mapDistance then
            return a.mapDistance < b.mapDistance
        end
        return a.id < b.id
    end)
    for index = #offers, MAX_OFFERS + 1, -1 do
        offers[index] = nil
    end
    return offers
end

local function MarkOffer(offer)
    ForeverWaypoint_Set(offer.mapID, offer.x, offer.y, offer.title or offer.name)
end

local function CurrentZone()
    return (GetRealZoneText and Safe(GetRealZoneText())) or (GetZoneText and Safe(GetZoneText())) or nil
end

local function FocusedQuest()
    if C_SuperTrack and C_SuperTrack.GetSuperTrackedQuestID then
        return Safe(C_SuperTrack.GetSuperTrackedQuestID())
    end
end

local function NearestFirst(a, b)
    if a.trivial ~= b.trivial then
        return b.trivial
    end
    if a.distance and b.distance and a.distance ~= b.distance then
        return a.distance < b.distance
    end
    if (a.distance ~= nil) ~= (b.distance ~= nil) then
        return a.distance ~= nil
    end
    if (a.level or 0) ~= (b.level or 0) then
        return (a.level or 0) < (b.level or 0)
    end
    return a.id < b.id
end

-- Turn-ins first, then the zone you're in, then the rest. Other zones fold up until you want them.
local function BuildSections(quests)
    local ready, zones, byName = {}, {}, {}
    local here = CurrentZone()
    for _, quest in ipairs(quests) do
        if quest.ready then
            ready[#ready + 1] = quest
        else
            -- A class or race quest you can do here joins this zone; the rest get a label that says what they are.
            local name = quest.zone
            if quest.personal then
                name = (quest.onMap and here) or (quest.zone .. " quests")
            end
            local section = byName[name]
            if not section then
                section = { name = name, quests = {}, order = #zones }
                byName[name] = section
                zones[#zones + 1] = section
            end
            section.quests[#section.quests + 1] = quest
            section.isLocal = section.isLocal or quest.onMap or name == here
        end
    end
    table.sort(zones, function(a, b)
        if (a.name == here) ~= (b.name == here) then
            return a.name == here
        end
        if (a.isLocal and true or false) ~= (b.isLocal and true or false) then
            return a.isLocal and true or false
        end
        return a.order < b.order
    end)
    for _, section in ipairs(zones) do
        table.sort(section.quests, NearestFirst)
    end
    table.sort(ready, NearestFirst)
    return ready, zones
end

local function SectionOpen(section)
    local saved = db.zones[section.name]
    if saved ~= nil then
        return saved
    end
    return section.isLocal and true or false
end

local function TimeLeft(quest)
    local seconds = quest.timerEnds and GetTime and math.max(math.floor(quest.timerEnds - GetTime()), 0)
    if not seconds then
        return nil
    end
    return string.format("%d:%02d", math.floor(seconds / 60), seconds % 60)
end

-- Tags sit in the short right-hand column so the quest name keeps the width; the tooltip spells them out.
local function RightText(quest)
    local parts = {}
    local left = TimeLeft(quest)
    if left then
        parts[#parts + 1] = COLOR_BAD .. left .. "|r"
    end
    if quest.upgrade then
        parts[#parts + 1] = Icon("bags-greenarrow", 12, COLOR_READY .. "Upg|r")
    end
    if quest.group > 1 then
        parts[#parts + 1] = string.format("%sG%d|r", COLOR_WARN, quest.group)
    end
    local accepted = db.accepted[quest.id]
    if accepted and GetServerTime and GetServerTime() - accepted < NEW_SECONDS then
        parts[#parts + 1] = COLOR_NEW .. "NEW|r"
    end
    if quest.xp and quest.xp > 0 then
        parts[#parts + 1] = COLOR_DIM .. FormatNumber(quest.xp) .. " xp|r"
    end
    return table.concat(parts, " ")
end

local function QuestTooltip(owner, quest)
    Tip():SetOwner(owner, "ANCHOR_LEFT")
    Tip():SetText(quest.title, 1, 0.82, 0)
    Tip():AddLine(string.format("Level %d, %s", quest.level or 0, quest.zone), 0.8, 0.8, 0.8)
    if quest.distance then
        Tip():AddLine(string.format(YARDS_LABEL, math.floor(quest.distance)), 0.8, 0.8, 0.8)
    end
    if quest.group > 1 then
        Tip():AddLine(string.format("Suggested group: %d players", quest.group), 1, 0.5, 0.25)
    end
    local left = TimeLeft(quest)
    if left then
        Tip():AddLine("Time left: " .. left, 1, 0.2, 0.2)
    end
    if quest.failed then
        Tip():AddLine("This quest has failed.", 1, 0.2, 0.2)
    end
    for _, objective in ipairs(quest.objectives) do
        if objective.finished then
            Tip():AddLine(objective.text, 0.2, 1, 0.2)
        else
            Tip():AddLine(objective.text, 1, 1, 1)
        end
    end
    if quest.xp and quest.xp > 0 then
        local maxXP = Safe(UnitXPMax("player"))
        local share = maxXP and maxXP > 0 and string.format(" (%d%% of a level)", math.floor(quest.xp * 100 / maxXP)) or ""
        Tip():AddLine("Reward: " .. FormatNumber(quest.xp) .. " XP" .. share, 0.6, 0.8, 1)
    end
    if quest.money and quest.money > 0 then
        Tip():AddLine("Reward: " .. ShortMoney(quest.money), 1, 0.85, 0.2)
    end
    if quest.upgrade then
        Tip():AddLine("Upgrade: " .. quest.upgrade.link, 0.2, 1, 0.2)
    end
    if quest.ready and quest.autoComplete then
        Tip():AddLine("Left-click: open the completion window. Right-click: track it.", 0.6, 0.6, 0.6)
    else
        Tip():AddLine("Left-click: mark it on the map. Right-click: track it.", 0.6, 0.6, 0.6)
    end
    Tip():Show()
end

local function SectionTooltip(owner, section)
    Tip():SetOwner(owner, "ANCHOR_LEFT")
    Tip():SetText(section.name, 1, 0.82, 0)
    if section.note then
        Tip():AddLine(section.note, 1, 1, 1, true)
    end
    for _, quest in ipairs(section.quests) do
        Tip():AddLine(string.format("[%d] %s", quest.level or 0, quest.title), 1, 1, 1)
        for _, objective in ipairs(quest.objectives) do
            if not objective.finished then
                Tip():AddLine("   " .. objective.text, 0.7, 0.7, 0.7)
            end
        end
    end
    Tip():Show()
end

local function ToggleFocus(questID)
    if not (C_SuperTrack and C_SuperTrack.SetSuperTrackedQuestID) then
        return
    end
    C_SuperTrack.SetSuperTrackedQuestID(FocusedQuest() == questID and 0 or questID)
    dirty = true
end

-- Never call QuestMapFrame_OpenToQuestDetails or OpenQuestLog from here: they are Blizzard Lua, and
-- the value they write (QuestMapFrame.DetailsFrame.questID) is read by Blizzard's objective tracker on
-- every update, so the whole tracker then runs tainted and its aura reads fail. Pointing the game's
-- own tracking at the quest is a C call and highlights it in the log and on the map just the same.
local function OpenQuest(questID)
    if not InCombat() and C_SuperTrack and C_SuperTrack.SetSuperTrackedQuestID then
        C_SuperTrack.SetSuperTrackedQuestID(questID)
        dirty = true
    end
end

local function OnRowClick(row, mouseButton)
    if row.section then
        -- The rows can't move until combat ends, so a fold now would look like nothing happened
        -- and a second click would quietly undo it.
        if InCombat() then
            return
        end
        db.zones[row.section.name] = not SectionOpen(row.section)
        dirty, forceLayout = true, true
    elseif row.offer then
        MarkOffer(row.offer)
    elseif row.quest then
        if mouseButton == "RightButton" then
            OpenQuest(row.quest.id)
        elseif row.quest.ready and row.quest.autoComplete and ShowQuestComplete then
            ShowQuestComplete(row.quest.id)
        else
            ToggleFocus(row.quest.id)
        end
    end
end

local function OnRowEnter(row)
    if row.quest then
        QuestTooltip(row, row.quest)
    elseif row.offer then
        Tip():SetOwner(row, "ANCHOR_LEFT")
        Tip():SetText(row.offer.name, 1, 0.82, 0)
        Tip():AddLine("Left-click: mark it on your map.", 0.6, 0.6, 0.6)
        Tip():Show()
    elseif row.section then
        SectionTooltip(row, row.section)
    end
end

local function GetRow(index)
    if rows[index] then
        return rows[index]
    end
    local row = CreateFrame("Button", nil, panel)
    row:SetWidth(WIDTH - 16)
    row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
    row.left = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.left:SetJustifyH("LEFT")
    row.left:SetWordWrap(false)
    row.right = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.right:SetJustifyH("RIGHT")
    -- Zone headers get a band and the focused quest a gold wash, so the list reads at a glance.
    row.band = row:CreateTexture(nil, "BACKGROUND")
    row.band:SetAllPoints(row)
    row.band:SetColorTexture(1, 1, 1, 0.07)
    row.glow = row:CreateTexture(nil, "BACKGROUND")
    row.glow:SetAllPoints(row)
    row.glow:SetColorTexture(1, 0.82, 0, 0.12)
    row.stripe = row:CreateTexture(nil, "ARTWORK")
    row.stripe:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)
    row.stripe:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 0, 0)
    row.stripe:SetWidth(2)
    row.stripe:SetColorTexture(1, 0.82, 0, 0.9)
    -- The track shows how far the bar has left to go.
    row.track = row:CreateTexture(nil, "BORDER")
    row.track:SetColorTexture(0, 0, 0, 0.5)
    row.track:SetHeight(BAR_HEIGHT)
    row.track:SetWidth(WIDTH - 20)
    row.track:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 2, 0)
    row.bar = row:CreateTexture(nil, "ARTWORK")
    row.bar:SetColorTexture(0.9, 0.75, 0.2, 0.8)
    row.bar:SetHeight(BAR_HEIGHT)
    row.bar:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 2, 0)
    row:SetScript("OnClick", OnRowClick)
    row:SetScript("OnEnter", OnRowEnter)
    row:SetScript("OnLeave", function()
        Tip():Hide()
    end)
    rows[index] = row
    return row
end

-- A real action button you click yourself, the same way Blizzard's tracker offers quest items.
local function GetItemButton(index)
    if itemButtons[index] then
        return itemButtons[index]
    end
    local button = CreateFrame("Button", nil, panel, "SecureActionButtonTemplate")
    button:SetSize(ITEM_SIZE, ITEM_SIZE)
    button:RegisterForClicks("AnyUp", "AnyDown")
    button:SetAttribute("type", "item")
    button.icon = button:CreateTexture(nil, "ARTWORK")
    button.icon:SetAllPoints(button)
    -- The same cooldown swirl Blizzard's tracker draws on quest items.
    button.cooldown = CreateFrame("Cooldown", nil, button, "CooldownFrameTemplate")
    button.cooldown:SetAllPoints(button)
    button:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
    button:SetScript("OnEnter", function(self)
        if self.link then
            Tip():SetOwner(self, "ANCHOR_LEFT")
            Tip():SetHyperlink(self.link)
            Tip():Show()
        end
    end)
    button:SetScript("OnLeave", function()
        Tip():Hide()
    end)
    itemButtons[index] = button
    return button
end

local function PlaceRow(index, y, height, indent, leftText, rightText)
    local row = GetRow(index)
    row:ClearAllPoints()
    row:SetPoint("TOPLEFT", panel, "TOPLEFT", 8, y)
    row:SetHeight(height)
    row.left:ClearAllPoints()
    row.left:SetPoint("LEFT", row, "LEFT", indent, 0)
    row.right:ClearAllPoints()
    row.right:SetPoint("RIGHT", row, "RIGHT", -2, 0)
    row.left:SetPoint("RIGHT", row.right, "LEFT", -4, 0)
    row.left:SetText(leftText)
    row.right:SetText(rightText or "")
    row.quest, row.section, row.objectiveIndex, row.offer, row.isTitle = nil, nil, nil, nil, nil
    row.bar:Hide()
    row.track:Hide()
    row.band:Hide()
    row.glow:Hide()
    row.stripe:Hide()
    row:Show()
    return row
end

local function PlaceItemButton(row, item, questID)
    local itemID = item.link:match("item:(%d+)")
    -- Secure buttons can't be moved or re-pointed once combat has started, even mid-layout.
    if not itemID or (InCombatLockdown and InCombatLockdown()) then
        return
    end
    shownButtons = shownButtons + 1
    local button = GetItemButton(shownButtons)
    button:ClearAllPoints()
    button:SetPoint("RIGHT", row, "RIGHT", -2, 0)
    -- Rows are made as needed and share the panel's level, so a newer row could sit over the button
    -- and take its clicks. Keep the button above its row. Out of combat only, like all of Layout.
    local rowLevel = row:GetFrameLevel()
    if rowLevel then
        button:SetFrameLevel(rowLevel + 2)
    end
    button:SetAttribute("item", "item:" .. itemID)
    button.icon:SetTexture(item.icon)
    button.link, button.questID = item.link, questID
    button:Show()
    row.right:ClearAllPoints()
    row.right:SetPoint("RIGHT", button, "LEFT", -4, 0)
end

local function QuestRowText(quest, focused)
    local prefix = quest.id == focused and (COLOR_FOCUS .. "> |r") or ""
    local failed = quest.failed and (COLOR_BAD .. "Failed|r ") or ""
    return string.format("%s%s%s[%d] %s|r", prefix, failed, quest.ready and COLOR_READY or DifficultyColor(quest), quest.level or 0, quest.title)
end

-- Text, textures and the bar only: safe in combat, since none of them move a frame.
local function DrawTitle(row, focused)
    local quest = row.quest
    row.left:SetText(QuestRowText(quest, focused))
    row.right:SetText(RightText(quest))
    row.glow:SetShown(quest.id == focused)
    row.stripe:SetShown(quest.id == focused)
end

local function SetBar(row, quest)
    local shown = quest.progress > 0 and not quest.ready
    row.bar:SetShown(shown)
    row.track:SetShown(shown)
    row.bar:SetWidth(math.max((WIDTH - 20) * quest.progress, 1))
end

-- What the last Layout worked out, so Order() right after it needn't sort the log and read the map again.
local layoutCache

local function Layout(quests)
    local ready, zones = BuildSections(quests)
    layoutCache = { quests = quests, ready = ready, zones = zones }
    local focused = FocusedQuest()
    local count, y = 0, -HEADER_HEIGHT
    shownButtons = 0
    local hiddenRows = 0
    -- Stop at the bottom of the screen, or the game slides the whole panel up to keep it on screen.
    local top = panel:GetTop()
    if not top then
        -- The game hasn't placed the panel yet, so measure again on the next tick.
        dirty = true
    end
    local overflowRoom = math.max((top or 0) - BOTTOM_MARGIN, MIN_ROOM) - OVERFLOW_HEIGHT - PANEL_PADDING

    local function AddRow(height, indent, left, right)
        if hiddenRows > 0 or count >= MAX_ROWS - 1 or -y + height > overflowRoom then
            hiddenRows = hiddenRows + 1
            return nil
        end
        count = count + 1
        local row = PlaceRow(count, y, height, indent, left, right)
        y = y - height
        return row
    end

    local function AddOffers()
        local offers = ReadOffers()
        layoutCache.offers = offers
        if #offers == 0 then
            return
        end
        local open = SectionOpen(OFFERS_SECTION)
        local header = AddRow(SECTION_HEIGHT, 4, string.format("%s%s%s (%d)|r", COLOR_FOCUS, open and "- " or "+ ", OFFERS_SECTION.name, #offers))
        if header then
            header.section = OFFERS_SECTION
            header.band:Show()
        end
        if open then
            for _, offer in ipairs(offers) do
                local distance = offer.yards and string.format("%s%d yd|r", COLOR_DIM, math.floor(offer.yards)) or ""
                local row = AddRow(TITLE_HEIGHT, 6, COLOR_FOCUS .. "! |r" .. offer.name, distance)
                if row then
                    row.offer = offer
                end
            end
        end
    end

    if #ready > 0 then
        local totalXP = 0
        for _, quest in ipairs(ready) do
            totalXP = totalXP + (quest.xp or 0)
        end
        local maxXP = Safe(UnitXPMax("player"))
        local summary = totalXP > 0 and maxXP and maxXP > 0
            and string.format("%s+%d%% of a level|r", COLOR_READY, math.floor(totalXP * 100 / maxXP)) or ""
        local header = AddRow(SECTION_HEIGHT, 4, string.format("%sReady to turn in (%d)|r", COLOR_READY, #ready), summary)
        if header then
            header.band:Show()
        end
        for _, quest in ipairs(ready) do
            local row = AddRow(TITLE_HEIGHT, 6, "")
            if row then
                row.quest, row.isTitle = quest, true
                DrawTitle(row, focused)
                if quest.item and quest.item.showWhenComplete then
                    PlaceItemButton(row, quest.item, quest.id)
                end
            end
            if quest.turnIn then
                local line = AddRow(OBJECTIVE_HEIGHT, 14, COLOR_DIM .. quest.turnIn .. "|r")
                if line then
                    line.quest = quest
                end
            end
        end
    end
    for sectionIndex, section in ipairs(zones) do
        local open = SectionOpen(section)
        local marker = open and "- " or "+ "
        -- What the whole zone is worth, to help pick where to go next.
        local zoneXP = 0
        for _, quest in ipairs(section.quests) do
            zoneXP = zoneXP + (quest.xp or 0)
        end
        local row = AddRow(SECTION_HEIGHT, 4, string.format("%s%s%s (%d)|r", COLOR_FOCUS, marker, section.name, #section.quests),
            zoneXP > 0 and (COLOR_DIM .. FormatNumber(zoneXP) .. " xp|r") or "")
        if row then
            row.section = section
            row.band:Show()
        end
        if open then
            for _, quest in ipairs(section.quests) do
                local title = AddRow(TITLE_HEIGHT, 6, "")
                if title then
                    title.quest, title.isTitle = quest, true
                    DrawTitle(title, focused)
                    SetBar(title, quest)
                    if quest.item then
                        PlaceItemButton(title, quest.item, quest.id)
                    end
                end
                for index, objective in ipairs(quest.objectives) do
                    local line = AddRow(OBJECTIVE_HEIGHT, 14, ObjectiveText(objective))
                    if line then
                        line.quest, line.objectiveIndex = quest, index
                    end
                end
            end
        end
        -- Your active quests in this zone come first, then what else you could pick up here.
        if sectionIndex == 1 then
            AddOffers()
        end
    end
    if #zones == 0 then
        AddOffers()
    end
    if hiddenRows > 0 then
        count = count + 1
        PlaceRow(count, y, OVERFLOW_HEIGHT, 4, string.format("%s%d more lines. Fold a zone to see them.|r", COLOR_DIM, hiddenRows))
        y = y - OVERFLOW_HEIGHT
    end
    if count == 0 then
        count = 1
        PlaceRow(1, y, TITLE_HEIGHT, 4, COLOR_DIM .. "No quests in your log.|r")
        y = y - TITLE_HEIGHT
    end
    for index = count + 1, #rows do
        rows[index]:Hide()
    end
    for index = shownButtons + 1, #itemButtons do
        itemButtons[index]:Hide()
    end
    shownRows = count
    panel:SetHeight(-y + PANEL_PADDING)
end

local function ApplyCollapse()
    for index = 1, shownRows do
        rows[index]:SetShown(not db.collapsed)
    end
    for index = 1, shownButtons do
        itemButtons[index]:SetShown(not db.collapsed)
    end
    collapseButton:SetText(db.collapsed and "+" or "-")
    if db.collapsed then
        panel:SetHeight(HEADER_HEIGHT + 2)
    end
end

local function HeaderText(quests)
    local _, used = C_QuestLog.GetNumQuestLogEntries()
    used = Safe(used)
    local maximum = C_QuestLog.GetMaxNumQuestsCanAccept and Safe(C_QuestLog.GetMaxNumQuestsCanAccept())
    if used and maximum then
        -- Warn before the log fills, since a full log refuses new quests.
        local color = (used >= maximum and COLOR_BAD) or (used >= maximum - 3 and COLOR_WARN) or COLOR_DIM
        return string.format("Quests  %s%d/%d|r", color, used, maximum)
    end
    return string.format("Quests  %s%d|r", COLOR_DIM, #quests)
end

local function AnnounceReady(quests)
    local now = {}
    for _, quest in ipairs(quests) do
        if quest.ready then
            now[quest.id] = true
            if readySeen and not readySeen[quest.id] then
                Notify(COLOR_READY .. "Ready to turn in:|r " .. quest.title)
            end
        end
    end
    readySeen = now
end

-- During combat only text changes: moving anything beside a secure button then would be blocked.
local function UpdateTextOnly()
    local cache = {}
    local focused = FocusedQuest()
    for index = 1, shownRows do
        local row = rows[index]
        if row.quest then
            local objectives = cache[row.quest.id]
            local progress
            if not objectives then
                objectives, progress = ReadObjectives(row.quest.id)
                cache[row.quest.id] = objectives
                if row.isTitle == true then
                    row.quest.progress = progress
                    SetBar(row, row.quest)
                end
            end
            -- Clicking a quest in combat still moves the focus marker.
            if row.isTitle == true then
                DrawTitle(row, focused)
            end
            local objective = row.objectiveIndex and objectives[row.objectiveIndex]
            if objective then
                row.left:SetText(ObjectiveText(objective))
            end
        end
    end
end

-- Every second, in or out of combat: clocks, item cooldowns and range. None of it moves a frame.
local function UpdateLive()
    for index = 1, shownRows do
        local row = rows[index]
        if row.isTitle == true and row.quest.timerEnds then
            row.right:SetText(RightText(row.quest))
        end
    end
    for index = 1, shownButtons do
        local button = itemButtons[index]
        local logIndex = button.questID and C_QuestLog.GetLogIndexForQuestID and Safe(C_QuestLog.GetLogIndexForQuestID(button.questID))
        if logIndex then
            if GetQuestLogSpecialItemCooldown and CooldownFrame_Set then
                local start, duration, enable = GetQuestLogSpecialItemCooldown(logIndex)
                start, duration, enable = Safe(start), Safe(duration), Safe(enable)
                if start and duration then
                    CooldownFrame_Set(button.cooldown, start, duration, enable)
                end
            end
            -- Red while you're too far away to use it, as Blizzard's tracker shows.
            if IsQuestLogSpecialItemInRange then
                if Safe(IsQuestLogSpecialItemInRange(logIndex)) == 0 then
                    button.icon:SetVertexColor(1, 0.2, 0.2)
                else
                    button.icon:SetVertexColor(1, 1, 1)
                end
            end
        end
    end
end

local function Order(quests)
    local ids = {}
    local cached = layoutCache and layoutCache.quests == quests and layoutCache or nil
    local ready, zones
    if cached then
        ready, zones = cached.ready, cached.zones
    else
        ready, zones = BuildSections(quests)
    end
    for _, quest in ipairs(ready) do
        ids[#ids + 1] = quest.id
    end
    for _, section in ipairs(zones) do
        ids[#ids + 1] = section.name
        for _, quest in ipairs(section.quests) do
            ids[#ids + 1] = quest.id
        end
    end
    for _, offer in ipairs(cached and cached.offers or ReadOffers()) do
        ids[#ids + 1] = "offer" .. offer.id
    end
    return table.concat(ids, ",")
end

-- Until you drag it, the panel sits just under the minimap. It copies the spot rather than anchoring to
-- MinimapCluster, so Blizzard's frame never gets tied to one holding secure buttons. Out of combat only.
local function PlaceDefault()
    local cluster = MinimapCluster
    local bottom = cluster and Safe(cluster:GetBottom())
    local right = cluster and Safe(cluster:GetRight())
    local scale = cluster and Safe(cluster:GetEffectiveScale())
    local ours = Safe(UIParent:GetEffectiveScale())
    panel:ClearAllPoints()
    if bottom and right and scale and ours and ours > 0 then
        -- Edit Mode can scale the minimap, so convert into UIParent's units.
        bottom, right = bottom * scale / ours, right * scale / ours
        if bottom - MINIMAP_GAP > MIN_ROOM + HEADER_HEIGHT then
            panel:SetPoint("TOPRIGHT", UIParent, "BOTTOMLEFT", right - 4, bottom - MINIMAP_GAP)
            return
        end
    end
    panel:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -16, -280)
end

-- Takes the quests when the caller already read them, so the log isn't read twice.
local function Refresh(quests)
    if not db.position and not moving then
        PlaceDefault()
    end
    quests = quests or ReadQuests()
    staleLayout = false
    AnnounceReady(quests)
    headerTitle:SetText(HeaderText(quests))
    Layout(quests)
    ApplyCollapse()
    lastOrder = Order(quests)
end

local function Attempt(step)
    local ok, err = pcall(step)
    if not ok then
        geterrorhandler()(err)
    end
end

local function OnTick()
    secondsSinceSort = secondsSinceSort + 1
    if ObjectiveTrackerFrame and not db.keepBlizzard then
        -- Safe: a hidden (secret) alpha can't be compared; the next tick tries again.
        local alpha = Safe(ObjectiveTrackerFrame:GetAlpha())
        if type(alpha) == "number" and alpha > 0 then
            ObjectiveTrackerFrame:SetAlpha(0)
        end
    end
    Attempt(UpdateLive)
    if InCombat() then
        if dirty then
            dirty, layoutWaiting = false, true
            Attempt(UpdateTextOnly)
        end
        return
    end
    -- Nearest-first follows you as you move, but never jumps while the mouse is on the list:
    -- a kill or a loaded item then only updates the text, and the re-sort waits for the mouse to leave.
    local hovered = panel:IsMouseOver()
    if layoutWaiting or forceLayout or ((dirty or staleLayout) and not hovered) then
        dirty, layoutWaiting, forceLayout = false, false, false
        secondsSinceSort = 0
        Attempt(Refresh)
    elseif dirty then
        dirty, staleLayout = false, true
        Attempt(UpdateTextOnly)
    elseif secondsSinceSort >= RESORT_SECONDS then
        secondsSinceSort = 0
        if not hovered then
            Attempt(function()
                local quests = ReadQuests()
                if Order(quests) ~= lastOrder then
                    Refresh(quests)
                end
            end)
        end
    end
end

local function SavePosition()
    local left, top = panel:GetLeft(), panel:GetTop()
    if left and top then
        panel:ClearAllPoints()
        panel:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left, top)
        db.position = { left, top }
        -- More or less of the list may fit from the new spot.
        dirty, forceLayout = true, true
    end
end

-- A drag can't finish during combat, so PLAYER_REGEN_DISABLED, which fires just before combat locks frames, ends it.
local function FinishMoving()
    if moving then
        moving = false
        panel:StopMovingOrSizing()
        SavePosition()
    end
end

-- Blizzard's tracker is only ever made clear, never hidden or shown. Calling its Hide() or Show() from here
-- runs its OnShow/size-change code (UpdateHeight, MarkDirty, Update) under this addon's taint, and its
-- scenario module then fails reading secret aura data. SetAlpha runs none of Blizzard's Lua.
-- What's left: the clear tracker still takes clicks (its quest-item buttons included) where this panel
-- doesn't cover it. EnableMouse can't fix that: it's restricted on the tracker in combat like Hide(), it
-- doesn't reach the child buttons (each has its own mouse setting), and changing those would taint them.
local function HideBlizzardTracker()
    local tracker = ObjectiveTrackerFrame
    if not tracker or db.keepBlizzard then
        return
    end
    tracker:SetAlpha(0)
end

-- No script hook on Blizzard's frame: the once-a-second tick below makes it clear again if Blizzard
-- showed it, which costs one alpha read.
local function WatchBlizzardTracker()
    HideBlizzardTracker()
end

local function ToggleBlizzardTracker()
    if not ObjectiveTrackerFrame then
        return
    end
    db.keepBlizzard = not db.keepBlizzard
    if db.keepBlizzard then
        ObjectiveTrackerFrame:SetAlpha(1)
    else
        HideBlizzardTracker()
    end
end

-- ---- Quest sounds (research\re_round5.md #6; the idea is Questie's, the code our own) -------------------
-- A short sound when a quest objective moves on, when one is finished, and when the whole quest is done.
-- Each has its own switch and sound on the "Snd" pop-up in this panel's header. Progress is off by default;
-- the other two are on, on the sound-effects channel. The game's own sound kits only (PlaySound, in pcall).
-- Nothing plays at login, after a loading screen, or for a quest you just picked up: only a change from the
-- last reading of a quest that was already in your log counts.
local SOUND_EVENTS = {
    { key = "progress", label = "Progress", about = "A kill or item counted towards an objective." },
    { key = "objective", label = "Objective done", about = "One objective finished." },
    { key = "complete", label = "Quest complete", about = "Everything done: ready to turn in." },
}
-- name: the SOUNDKIT constant, read when it's there; id: the same kit's number for when it isn't.
local SOUND_CHOICES = {
    { name = "Soft tick", kit = "IG_MAINMENU_OPTION_CHECKBOX_ON", id = 856 },
    { name = "Quest tick", kit = "IG_QUEST_LIST_SELECT", id = 877 },
    { name = "Map ping", kit = "MAP_PING", id = 3175 },
    { name = "Whisper", kit = "TELL_MESSAGE", id = 3081 },
    { name = "Quest done", kit = "IG_QUEST_LIST_COMPLETE", id = 878 },
    { name = "Ready check", kit = "READY_CHECK", id = 8960 },
}
local SOUND_DEFAULTS = {
    progress = { on = false, choice = 1 },
    objective = { on = true, choice = 2 },
    complete = { on = true, choice = 5 },
}
-- Wait this long after a quest log update, so one kill that moves two quests plays one sound.
local SOUND_DELAY, SOUND_QUIET_SECONDS = 0.5, 5
local soundSnap, soundPending, soundQuietUntil = nil, false, 0
local soundPanel

local function SoundSettings()
    db.sounds = type(db.sounds) == "table" and db.sounds or {}
    for key, default in pairs(SOUND_DEFAULTS) do
        local entry = type(db.sounds[key]) == "table" and db.sounds[key] or {}
        if type(entry.on) ~= "boolean" then
            entry.on = default.on
        end
        if not SOUND_CHOICES[tonumber(entry.choice) or 0] then
            entry.choice = default.choice
        end
        db.sounds[key] = entry
    end
    return db.sounds
end

local function AnySoundOn()
    for _, entry in pairs(SoundSettings()) do
        if entry.on then
            return true
        end
    end
    return false
end

local function SoundKitID(choice)
    local sound = SOUND_CHOICES[choice] or SOUND_CHOICES[1]
    local id = type(SOUNDKIT) == "table" and Safe(SOUNDKIT[sound.kit])
    return type(id) == "number" and id or sound.id
end

-- True when the game took the sound.
local function PlayChoice(choice)
    if type(PlaySound) ~= "function" then
        return false
    end
    local ok, willPlay = pcall(PlaySound, SoundKitID(choice), "SFX")
    return ok and willPlay ~= false
end

-- One reading of a quest: complete (nil when unreadable) and each readable objective's count and state.
local function SoundReading(questID)
    local reading = { objectives = {} }
    local complete = Safe(C_QuestLog.IsComplete(questID))
    if type(complete) == "boolean" then
        reading.complete = complete
    end
    for index, objective in ipairs(C_QuestLog.GetQuestObjectives(questID) or {}) do
        local have, need, finished = Safe(objective.numFulfilled), Safe(objective.numRequired), Safe(objective.finished)
        if type(have) == "number" and type(finished) == "boolean" then
            -- The 1/1-but-unfinished rule (ReadObjectives): that row is still 0/1.
            if finished == false and have == 1 and need == 1 then
                have = 0
            end
            reading.objectives[index] = { have = have, finished = finished }
        end
    end
    return reading
end

-- Compares the log with the last reading. Returns "complete", "objective", "progress" or nil (the biggest
-- change wins), and keeps the new reading. The first reading only remembers.
function QuestTracker_SoundScan()
    local now = {}
    local entries = Safe((C_QuestLog.GetNumQuestLogEntries())) or 0
    for index = 1, entries do
        local info = C_QuestLog.GetInfo(index)
        local questID = info and not Safe(info.isHeader) and not Safe(info.isTask) and Safe(info.questID)
        if type(questID) == "number" then
            now[questID] = SoundReading(questID)
        end
    end
    local found = {}
    if soundSnap then
        for questID, reading in pairs(now) do
            local old = soundSnap[questID]
            if old then
                if reading.complete == true and old.complete == false then
                    found.complete = true
                end
                for index, objective in pairs(reading.objectives) do
                    local was = old.objectives[index]
                    if was then
                        if objective.finished and not was.finished then
                            found.objective = true
                        elseif not objective.finished and objective.have > was.have then
                            found.progress = true
                        end
                    end
                end
                -- What can't be read now keeps its last value, so it isn't news when it comes back.
                if reading.complete == nil then
                    reading.complete = old.complete
                end
                for index, objective in pairs(old.objectives) do
                    if reading.objectives[index] == nil then
                        reading.objectives[index] = objective
                    end
                end
            end
        end
    end
    soundSnap = now
    if GetTime and GetTime() < soundQuietUntil then
        return nil
    end
    -- Quest complete covers the objective that finished it; a switched-off sound lets the next one play.
    local settings = SoundSettings()
    for _, key in ipairs({ "complete", "objective", "progress" }) do
        if found[key] and settings[key].on then
            PlayChoice(settings[key].choice)
            return key
        end
    end
    return nil
end

local function RunSoundScan()
    soundPending = false
    if not AnySoundOn() then
        -- Switched off: start again from a fresh reading when one is turned on.
        soundSnap = nil
        return
    end
    Attempt(QuestTracker_SoundScan)
end

local function QueueSoundScan()
    if soundPending then
        return
    end
    soundPending = true
    if C_Timer and C_Timer.After then
        C_Timer.After(SOUND_DELAY, RunSoundScan)
    else
        RunSoundScan()
    end
end

-- After login or a loading screen, quest data can arrive in pieces: stay quiet for a few seconds.
local function QuietSounds()
    soundQuietUntil = (GetTime and GetTime() or 0) + SOUND_QUIET_SECONDS
end

local function SoundRowText(row)
    local entry = SoundSettings()[row.key]
    row.toggle:SetText(entry.on and (COLOR_READY .. "On|r") or (COLOR_DIM .. "Off|r"))
    local choice = SOUND_CHOICES[entry.choice] or SOUND_CHOICES[1]
    row.choice:SetText((entry.on and "" or COLOR_DIM) .. choice.name .. (entry.on and "" or "|r"))
end

local function BuildSoundPanel()
    soundPanel = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
    soundPanel:SetSize(WIDTH, 22 + #SOUND_EVENTS * 22)
    soundPanel:SetFrameStrata("DIALOG")
    soundPanel:SetClampedToScreen(true)
    soundPanel:EnableMouse(true)
    soundPanel:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 14,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    soundPanel:SetBackdropColor(0.04, 0.04, 0.07, 0.95)
    soundPanel:SetBackdropBorderColor(0.5, 0.5, 0.55, 0.9)
    local title = soundPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    title:SetPoint("TOPLEFT", soundPanel, "TOPLEFT", 8, -7)
    title:SetText("Quest sounds  " .. COLOR_DIM .. "(click a sound to change it)|r")
    soundPanel.rows = {}
    for index, event in ipairs(SOUND_EVENTS) do
        local y = -6 - index * 22
        local row = { key = event.key }
        row.label = soundPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        row.label:SetPoint("TOPLEFT", soundPanel, "TOPLEFT", 8, y - 4)
        row.label:SetText(event.label)
        local function Tooltip(owner, line)
            owner:SetScript("OnEnter", function(self)
                Tip():SetOwner(self, "ANCHOR_RIGHT")
                Tip():SetText(event.label)
                Tip():AddLine(event.about, 1, 1, 1, true)
                Tip():AddLine(line, 0.6, 0.6, 0.6, true)
                Tip():Show()
            end)
            owner:SetScript("OnLeave", function()
                Tip():Hide()
            end)
        end
        row.toggle = CreateFrame("Button", nil, soundPanel)
        row.toggle:SetSize(34, 18)
        row.toggle:SetPoint("TOPLEFT", soundPanel, "TOPLEFT", 112, y)
        row.toggle:SetNormalFontObject(GameFontHighlightSmall)
        row.toggle:SetScript("OnClick", function()
            local entry = SoundSettings()[row.key]
            entry.on = not entry.on
            SoundRowText(row)
        end)
        Tooltip(row.toggle, "Click to switch it on or off.")
        row.choice = CreateFrame("Button", nil, soundPanel)
        row.choice:SetSize(86, 18)
        row.choice:SetPoint("TOPLEFT", soundPanel, "TOPLEFT", 150, y)
        row.choice:SetNormalFontObject(GameFontHighlightSmall)
        row.choice:SetScript("OnClick", function()
            local entry = SoundSettings()[row.key]
            entry.choice = entry.choice % #SOUND_CHOICES + 1
            SoundRowText(row)
            PlayChoice(entry.choice)
        end)
        Tooltip(row.choice, "Click for the next sound; it plays once so you can hear it.")
        row.play = CreateFrame("Button", nil, soundPanel)
        row.play:SetSize(40, 18)
        row.play:SetPoint("TOPLEFT", soundPanel, "TOPLEFT", 240, y)
        row.play:SetNormalFontObject(GameFontNormalSmall)
        row.play:SetText("Play")
        row.play:SetScript("OnClick", function()
            PlayChoice(SoundSettings()[row.key].choice)
        end)
        Tooltip(row.play, "Plays this sound once.")
        SoundRowText(row)
        soundPanel.rows[index] = row
    end
    soundPanel:Hide()
end

-- Opens under the header. It copies the panel's spot instead of anchoring to it (the panel holds secure
-- item buttons), so out of combat only.
local function ToggleSoundPanel()
    if InCombat() then
        return
    end
    if not soundPanel then
        BuildSoundPanel()
    end
    if soundPanel:IsShown() then
        soundPanel:Hide()
        return
    end
    for _, row in ipairs(soundPanel.rows) do
        SoundRowText(row)
    end
    local right, top = Safe(panel:GetRight()), Safe(panel:GetTop())
    soundPanel:ClearAllPoints()
    if type(right) == "number" and type(top) == "number" then
        soundPanel:SetPoint("TOPRIGHT", UIParent, "BOTTOMLEFT", right, top - HEADER_HEIGHT)
    else
        soundPanel:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    end
    soundPanel:Show()
end

local function BuildPanel()
    panel = CreateFrame("Frame", "QuestTrackerPanel", UIParent, "BackdropTemplate")
    panel:SetWidth(WIDTH)
    panel:SetHeight(HEADER_HEIGHT + 2)
    panel:SetClampedToScreen(true)
    panel:SetMovable(true)
    panel:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 14,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    panel:SetBackdropColor(0.04, 0.04, 0.07, 0.72)
    panel:SetBackdropBorderColor(0.5, 0.5, 0.55, 0.9)
    -- The header band and a thin gold rule under it.
    local band = panel:CreateTexture(nil, "BORDER")
    band:SetPoint("TOPLEFT", panel, "TOPLEFT", 3, -3)
    band:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -3, -3)
    band:SetHeight(HEADER_HEIGHT - 3)
    band:SetColorTexture(1, 1, 1, 0.06)
    local rule = panel:CreateTexture(nil, "BORDER")
    rule:SetPoint("TOPLEFT", band, "BOTTOMLEFT", 0, 0)
    rule:SetPoint("TOPRIGHT", band, "BOTTOMRIGHT", 0, 0)
    rule:SetHeight(1)
    rule:SetColorTexture(1, 0.82, 0, 0.35)
    if db.position then
        panel:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", db.position[1], db.position[2])
    else
        PlaceDefault()
    end

    local header = CreateFrame("Button", nil, panel)
    header:SetPoint("TOPLEFT", panel, "TOPLEFT", 4, -3)
    header:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -56, -3)
    header:SetHeight(HEADER_HEIGHT - 4)
    header:RegisterForDrag("LeftButton")
    header:RegisterForClicks("RightButtonUp")
    header:SetScript("OnDragStart", function()
        if not InCombat() then
            moving = true
            panel:StartMoving()
        end
    end)
    header:SetScript("OnDragStop", FinishMoving)
    header:SetScript("OnClick", ToggleBlizzardTracker)
    header:SetScript("OnEnter", function(self)
        Tip():SetOwner(self, "ANCHOR_LEFT")
        Tip():SetText("Quest Tracker")
        Tip():AddLine("Drag to move.", 1, 1, 1)
        Tip():AddLine(db.keepBlizzard and "Right-click: hide Blizzard's tracker." or "Right-click: show Blizzard's tracker too.", 1, 1, 1)
        Tip():Show()
    end)
    header:SetScript("OnLeave", function()
        Tip():Hide()
    end)

    headerTitle = header:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    headerTitle:SetPoint("LEFT", header, "LEFT", 6, 0)
    headerTitle:SetText("Quests")

    collapseButton = CreateFrame("Button", nil, panel)
    collapseButton:SetSize(20, 18)
    collapseButton:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -5, -4)
    collapseButton:SetNormalFontObject(GameFontNormal)
    collapseButton:SetHighlightFontObject(GameFontHighlight)
    collapseButton:SetText("-")
    collapseButton:SetScript("OnClick", function()
        if not InCombat() then
            db.collapsed = not db.collapsed
            dirty, forceLayout = true, true
        end
    end)

    -- Quest sounds: their switches open from here.
    local soundButton = CreateFrame("Button", nil, panel)
    soundButton:SetSize(30, 18)
    soundButton:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -26, -4)
    soundButton:SetNormalFontObject(GameFontNormalSmall)
    soundButton:SetHighlightFontObject(GameFontHighlightSmall)
    soundButton:SetText("Snd")
    soundButton:SetScript("OnClick", ToggleSoundPanel)
    soundButton:SetScript("OnEnter", function(self)
        Tip():SetOwner(self, "ANCHOR_LEFT")
        Tip():SetText("Quest sounds")
        Tip():AddLine("Click to choose which quest sounds play: progress, objective done, quest complete.", 1, 1, 1, true)
        Tip():Show()
    end)
    soundButton:SetScript("OnLeave", function()
        Tip():Hide()
    end)
    panel.soundButton = soundButton
end

local function Start()
    QuestTrackerDB = QuestTrackerDB or {}
    db = QuestTrackerDB
    -- Blizzard's tracker stays visible unless the player right-clicks the header to make it clear, so by default
    -- nothing is written to Blizzard's frame. Older saves defaulted to clear; move them over once.
    if not db.blizzardShownDefault then
        db.keepBlizzard = true
        db.blizzardShownDefault = true
    end
    db.zones = db.zones or {}
    db.accepted = db.accepted or {}
    -- Quests dropped while the addon was off never sent QUEST_REMOVED; forget their NEW stamps.
    if GetServerTime then
        local now = GetServerTime()
        for questID, accepted in pairs(db.accepted) do
            if now - accepted >= NEW_SECONDS then
                db.accepted[questID] = nil
            end
        end
    end
    SoundSettings()
    QuietSounds()
    BuildPanel()
    -- A /reload in combat can't place secure buttons yet; the layout waits for combat to end.
    if InCombat() then
        layoutWaiting = true
    else
        Attempt(Refresh)
    end
    -- Blizzard's tracker only goes away once this one has been built.
    Attempt(WatchBlizzardTracker)
    C_Timer.NewTicker(1, OnTick)
end

local events = CreateFrame("Frame")
for _, name in ipairs({ "PLAYER_LOGIN", "QUEST_LOG_UPDATE", "QUEST_WATCH_LIST_CHANGED", "QUEST_ACCEPTED", "QUEST_REMOVED", "QUEST_TURNED_IN",
    "ZONE_CHANGED_NEW_AREA", "PLAYER_LEVEL_UP", "PLAYER_REGEN_ENABLED", "PLAYER_REGEN_DISABLED", "SUPER_TRACKING_CHANGED", "QUEST_DATA_LOAD_RESULT", "PLAYER_EQUIPMENT_CHANGED", "GET_ITEM_INFO_RECEIVED", "PLAYER_ENTERING_WORLD" }) do
    events:RegisterEvent(name)
end
events:SetScript("OnEvent", function(_, event, questID)
    if event == "PLAYER_LOGIN" then
        Start()
        return
    end
    if not db then
        return
    end
    if event == "PLAYER_ENTERING_WORLD" then
        -- Quest sounds only: after a loading screen the log is read again, quietly.
        QuietSounds()
        return
    elseif event == "QUEST_LOG_UPDATE" then
        QueueSoundScan()
    end
    questID = Safe(questID)
    if event == "PLAYER_EQUIPMENT_CHANGED" or event == "PLAYER_LEVEL_UP" then
        upgradeCache = {}
    end
    if event == "QUEST_ACCEPTED" and questID and GetServerTime then
        db.accepted[questID] = GetServerTime()
    elseif event == "QUEST_REMOVED" and questID then
        db.accepted[questID] = nil
    elseif event == "PLAYER_REGEN_DISABLED" then
        Attempt(FinishMoving)
        return
    elseif event == "GET_ITEM_INFO_RECEIVED" then
        -- Any addon's item lookups fire this; only the reward items this panel asked for matter.
        if not (questID and waitingItems[questID]) then
            return
        end
        waitingItems[questID] = nil
    end
    dirty = true
end)
