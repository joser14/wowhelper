const fs = require('fs');
const root = process.argv[2];
const edits = [
['LevelGuide/LevelGuide.lua', `local NO_SCALE_UNITS = 1000  -- without the map's size in yards, distances are only compared, never shown`, `local NO_SCALE_UNITS = 1000  -- without the map's size in yards, distances are only compared, never shown
local OUTLEVELED = 4         -- route steps this far below you count as done, so a route can start midway
local ZONE_MAP_TYPE = 3      -- Enum.UIMapType.Zone: caves and buildings below this report up to their zone`],
['LevelGuide/LevelGuide.lua', `local currentKey, requestedMap
`, `local currentKey, requestedMap
local charData
local titlesByID = {}
local activeRoute
`],
// Positions are read on the zone map, so caves and buildings don't break the arrow.
['LevelGuide/LevelGuide.lua', `local function PlayerPosition()
    local mapID = C_Map and C_Map.GetBestMapForUnit and Safe(C_Map.GetBestMapForUnit("player"))
    if not mapID then
        return nil
    end`, `local function PlayerPosition()
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
    end`],
// The route engine.
['LevelGuide/LevelGuide.lua', `-- Following the route, which turn-in takes you past the end of this level.`, `-- Hand-written routes (Routes.lua). Progress is read from your quest log, plus a count of what this
-- character has turned in, kept by title since several quests in a chain share one.
local ROUTE_KINDS = { accept = "pickup", ["do"] = "work", turnin = "turnin", go = "travel" }

local function LogByTitle()
    local byTitle = {}
    for index = 1, Safe(C_QuestLog.GetNumQuestLogEntries()) or 0 do
        local info = C_QuestLog.GetInfo(index)
        local id, title = info and Safe(info.questID), info and Safe(info.title)
        if id and title and not Safe(info.isHeader) then
            titlesByID[id] = title
            byTitle[title] = {
                id = id, logIndex = index,
                ready = (Safe(C_QuestLog.IsComplete(id)) or Safe(C_QuestLog.ReadyForTurnIn(id))) and true or false,
            }
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

local function RouteStepDone(route, index, step, byTitle, level)
    local key = RouteKey(route, index)
    if charData.skips[key] then
        return true
    end
    if level and step.lvl and level >= step.lvl + OUTLEVELED then
        return true
    end
    if step.t == "go" then
        return charData.visited[key] or false
    end
    local turnedIn = charData.done[step.q] or 0
    local part = step.part or 1
    local entry = byTitle[step.q]
    if step.t == "accept" then
        return turnedIn >= part or (entry ~= nil and turnedIn == part - 1)
    elseif step.t == "do" then
        return turnedIn >= part or (entry ~= nil and entry.ready and turnedIn == part - 1)
    end
    return turnedIn >= part
end

local function RouteDisplay(route, index, step, byTitle, zoneMap)
    local entry = step.q and byTitle[step.q]
    local shown = {
        kind = ROUTE_KINDS[step.t], title = step.q or step.text, routeKey = RouteKey(route, index),
        id = entry and entry.id, zone = route.zone,
    }
    if step.t == "accept" then
        shown.detail = "From " .. step.npc
    elseif step.t == "turnin" then
        shown.detail = "To " .. step.npc
    elseif step.t == "do" then
        local progress = entry and FirstUnfinished(entry.id)
        shown.detail = progress and step.note and (step.note .. ". Now: " .. progress) or progress or step.note
    else
        shown.detail = step.note
    end
    if entry then
        shown.xp = RewardXP(entry.id)
    end
    if zoneMap and step.x and step.y then
        shown.mapID, shown.x, shown.y = zoneMap, step.x / 100, step.y / 100
    end
    return shown
end

local function FindRoute(level, byTitle)
    local chains = LevelGuideRoutes and LevelGuideRoutes.chains
    local race = UnitRace and Safe(select(2, UnitRace("player")))
    for _, route in ipairs(chains and race and chains[race] or {}) do
        if level <= route.max then
            for index, step in ipairs(route.steps) do
                if not RouteStepDone(route, index, step, byTitle, level) then
                    return route
                end
            end
        end
    end
end

local function RouteSteps(level)
    if not charData then
        return nil
    end
    local byTitle = LogByTitle()
    local route = FindRoute(level, byTitle)
    if not route then
        return nil
    end
    local zoneMap = ZoneMap(route.zone)
    local list = {}
    if not zoneMap then
        list[1] = { kind = "travel", title = route.zone, detail = "Your route continues there", zone = route.zone }
    end
    for index, step in ipairs(route.steps) do
        if #list > MAX_NEXT then
            break
        end
        if not RouteStepDone(route, index, step, byTitle, level) then
            list[#list + 1] = RouteDisplay(route, index, step, byTitle, zoneMap)
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

-- Following the route, which turn-in takes you past the end of this level.`],
['LevelGuide/LevelGuide.lua', `local function BuildSteps()
    local mapID, playerX, playerY = PlayerPosition()
    local here, away, unplaced, later = ReadQuests(mapID)`, `local function BuildSteps()
    local mapID, playerX, playerY = PlayerPosition()
    local level = Safe(UnitLevel("player")) or 1
    local routed
    routed, activeRoute = RouteSteps(level)
    if routed then
        MarkLevelUp(routed)
        return routed, mapID, playerX, playerY, nil
    end
    local here, away, unplaced, later = ReadQuests(mapID)`],
['LevelGuide/LevelGuide.lua', `    for _, step in ipairs(travel) do
        list[#list + 1] = step
    end
    MarkLevelUp(list)`, `    for _, step in ipairs(travel) do
        list[#list + 1] = step
    end
    local plan = PlanStep(level, mapID)
    if plan then
        table.insert(list, 1, plan)
    end
    MarkLevelUp(list)`],
['LevelGuide/LevelGuide.lua', `local function StepKey(step)
    return step and (step.kind .. ":" .. tostring(step.id or step.zone)) or nil
end`, `local function StepKey(step)
    return step and (step.routeKey or (step.kind .. ":" .. tostring(step.id or step.zone))) or nil
end`],
// Marking and skipping route steps.
['LevelGuide/LevelGuide.lua', `    if step.kind == "pickup" then
        if C_Map.SetUserWaypoint`, `    if step.kind == "pickup" or (step.routeKey and not step.id and step.x) then
        if C_Map.SetUserWaypoint`],
['LevelGuide/LevelGuide.lua', `local function SkipStep(step)
    if step and step.id then`, `local function SkipStep(step)
    if step and step.routeKey and charData then
        charData.skips[step.routeKey] = true
        dirty = true
    elseif step and step.id then`],
['LevelGuide/LevelGuide.lua', `    if step.id and step.kind ~= "travel" then
        GameTooltip:AddLine("Right-click: skip this step.", 0.6, 0.6, 0.6)
    end`, `    if step.routeKey or (step.id and step.kind ~= "travel") then
        GameTooltip:AddLine("Right-click: skip this step.", 0.6, 0.6, 0.6)
    end`],
['LevelGuide/LevelGuide.lua', `        headerText:SetText(string.format("Guide  %sLevel %d, %d%%|r%s", COLOR_DIM, level, math.floor(xp * 100 / maxXP), readyText))`, `        local title = activeRoute and ("Route: " .. activeRoute.zone) or "Guide"
        headerText:SetText(string.format("%s  %sLevel %d, %d%%|r%s", title, COLOR_DIM, level, math.floor(xp * 100 / maxXP), readyText))`],
// Arriving at a "go" step completes it.
['LevelGuide/LevelGuide.lua', `    if isYards and yards <= ARRIVED_YARDS then
        arrow:Hide()
        yardsText:SetText("|cff33ff33You're there|r")
        return
    end`, `    if isYards and yards <= ARRIVED_YARDS then
        arrow:Hide()
        yardsText:SetText("|cff33ff33You're there|r")
        if step.routeKey and step.kind == "travel" and charData and not charData.visited[step.routeKey] then
            charData.visited[step.routeKey] = true
            dirty = true
        end
        return
    end`],
['LevelGuide/LevelGuide.lua', `    header:SetScript("OnClick", function()
        db.skipped = {}
        dirty = true
    end)`, `    header:SetScript("OnClick", function()
        db.skipped = {}
        if charData then
            charData.skips = {}
        end
        dirty = true
    end)`],
['LevelGuide/LevelGuide.lua', `        db.skipped = db.skipped or {}
        Attempt(Build)
        return
    end`, `        db.skipped = db.skipped or {}
        db.characters = db.characters or {}
        local key = (Safe(UnitName("player")) or "Unknown") .. "-" .. (Safe(GetRealmName()) or "Unknown")
        db.characters[key] = db.characters[key] or {}
        charData = db.characters[key]
        charData.done = charData.done or {}
        charData.skips = charData.skips or {}
        charData.visited = charData.visited or {}
        Attempt(Build)
        return
    end`],
['LevelGuide/LevelGuide.lua', `    if event == "QUEST_REMOVED" and questID then
        db.skipped[questID] = nil
    end`, `    if event == "QUEST_REMOVED" and questID then
        db.skipped[questID] = nil
    elseif event == "QUEST_TURNED_IN" and questID then
        local title = titlesByID[questID] or (C_QuestLog.GetTitleForQuestID and Safe(C_QuestLog.GetTitleForQuestID(questID)))
        if title then
            charData.done[title] = (charData.done[title] or 0) + 1
        end
    end`],
['LevelGuide/LevelGuide.toc', `LevelGuide.lua`, `Routes.lua
LevelGuide.lua`],
];
for (const [file, oldText, newText] of edits) {
    const path = root + '/' + file;
    const raw = fs.readFileSync(path, 'utf8');
    const crlf = raw.includes('\r\n');
    const text = raw.replace(/\r\n/g, '\n');
    const count = text.split(oldText).length - 1;
    if (count !== 1) throw new Error(file + ': matched ' + count + ' times: ' + oldText.slice(0, 70));
    let out = text.replace(oldText, () => newText);
    if (crlf) out = out.replace(/\n/g, '\r\n');
    fs.writeFileSync(path, out);
}
console.log('applied ' + edits.length);
