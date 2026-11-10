-- Quest facts by ID from QuestDB.lua (generated from forever-db by tools\gen_questdb.js), decoded on
-- first use and kept. Read-only: nothing here talks to the game except to read your race and class
-- (through the caller), and nothing is written anywhere but our own tables.
--
-- LevelGuideQuestFacts:
--   Quest(id)                     -> decoded quest or nil (title, level, min, races, classes, givers,
--                                    enders, all, any, crumbs, flags, objectives)
--   Place(kind, id)               -> { name, spots = { { map, x, y }, ... } } for "npc" / "object"
--   ItemName(id), Title(id), MapName(uiMapID), MapID(name)
--   Takes(q, race, class)         -> whether a character of that race/class token can take quest q
--   IDsForTitle(title, race, class[, maps]) -> quest IDs with that title in chain order (part 1 first)
--   Prereqs(id, race, class)      -> { all = {}, any = {}, level = n } in Prereqs.lua's shape, or nil
--   GiverSpot(id) / EnderSpot(id) / ObjectiveSpot(id) -> map, x, y, name (map percent 0-100)
--   Fill(routes, race, class)     -> fills quest IDs, prerequisites, NPC names and coordinates that
--                                    route steps lack (LevelGuideQuestIDs / LevelGuidePrereqs / steps)
--   BuildRoute(mapID, min, max, race, class, zone[, exclude]) -> generated steps (accept -> do -> turn in)
--   Project(fromMap, x, y, toMap)  -> a map point on another map of the same continent (QuestDB frames)
-- Objective spots are spawn camps: { map, x, y, r = radius in yards, n = spawns }, biggest first.
--   Generated(zone, mapID, min, max, fields) -> a route whose steps are built on first use

local facts = {}
LevelGuideQuestFacts = facts

local function DB()
    local db = LevelGuideQuestDB
    return type(db) == "table" and type(db.q) == "table" and db or nil
end

local RACE_BITS = { Human = 1, Orc = 2, Dwarf = 4, NightElf = 8, Scourge = 16, Tauren = 32, Gnome = 64, Troll = 128 }
local CLASS_BITS = { WARRIOR = 1, PALADIN = 2, HUNTER = 4, ROGUE = 8, PRIEST = 16, SHAMAN = 64, MAGE = 128,
    WARLOCK = 256, DRUID = 1024 }
local ALLIANCE_BITS = { 1, 4, 8, 64 }
local NOT_SOLO = { g = true, e = true, d = true, r = true, p = true, R = true }

local function HasBit(mask, bit)
    return math.floor(mask / bit) % 2 == 1
end

local quests, places, titleIndex = {}, { npc = {}, object = {} }, nil

local function Split(text, sep)
    local list = {}
    if text and text ~= "" then
        for part in (text .. sep):gmatch("(.-)" .. sep:gsub("%p", "%%%0")) do
            list[#list + 1] = part
        end
    end
    return list
end

local function Refs(text)
    local list = {}
    for _, ref in ipairs(Split(text, ",")) do
        local letter, id = ref:match("^(%a)(%d+)$")
        if letter then
            list[#list + 1] = { kind = letter == "n" and "npc" or letter == "o" and "object" or "item", id = tonumber(id) }
        end
    end
    return list
end

local OBJ_KINDS = { k = "kill", i = "item", o = "object", e = "event", t = "talk" }

function facts.Quest(id)
    id = tonumber(id)
    if not id then
        return nil
    end
    local cached = quests[id]
    if cached ~= nil then
        return cached or nil
    end
    local db = DB()
    local record = db and db.q[id]
    if type(record) ~= "string" then
        quests[id] = false
        return nil
    end
    local level, min, races, classes, givers, enders, pre, flags, objs, title =
        record:match("^([^|]*)|([^|]*)|([^|]*)|([^|]*)|([^|]*)|([^|]*)|([^|]*)|([^|]*)|([^|]*)|(.*)$")
    if not title then
        quests[id] = false
        return nil
    end
    local q = {
        id = id, title = title, level = tonumber(level), min = tonumber(min), races = tonumber(races) or 0,
        classes = tonumber(classes) or 0, givers = Refs(givers), enders = Refs(enders),
        all = {}, any = {}, crumbs = {}, flags = {}, objectives = {},
    }
    for _, ref in ipairs(Split(pre, ",")) do
        local letter, pid = ref:match("^(%a)(%d+)$")
        pid = tonumber(pid)
        if letter == "a" then
            q.all[#q.all + 1] = pid
        elseif letter == "y" then
            q.any[#q.any + 1] = pid
        elseif letter == "A" or letter == "Y" then
            q.crumbs[#q.crumbs + 1] = pid
        end
    end
    for flag in flags:gmatch(".") do
        q.flags[flag] = true
    end
    for _, text in ipairs(Split(objs, "/")) do
        local head, where = text:match("^([^@]*)@?(.*)$")
        local letter, target, count = head:match("^(%a)(%d*)x?(%d*)$")
        local objective = { kind = OBJ_KINDS[letter or ""] or "event", target = tonumber(target), count = tonumber(count) or 1 }
        -- Spawn camps: "<map>:x,y,r,n;x,y,r,n;<map>:x,y,r,n" (r = radius in yards, n = spawns), biggest first.
        local map
        for _, camp in ipairs(Split(where, ";")) do
            local m, rest = camp:match("^(%d+):(.*)$")
            if m then
                map, camp = tonumber(m), rest
            end
            local x, y, r, n = camp:match("^([%d%.%-]+),([%d%.%-]+),?(%d*),?(%d*)$")
            if map and x then
                objective.map = objective.map or map
                objective.spots = objective.spots or {}
                objective.spots[#objective.spots + 1] = { map = map, x = tonumber(x), y = tonumber(y), r = tonumber(r), n = tonumber(n) }
            end
        end
        q.objectives[#q.objectives + 1] = objective
    end
    quests[id] = q
    return q
end

function facts.Title(id)
    local q = facts.Quest(id)
    return q and q.title or nil
end

function facts.Place(kind, id)
    local cache = places[kind]
    id = tonumber(id)
    if not (cache and id) then
        return nil
    end
    if cache[id] ~= nil then
        return cache[id] or nil
    end
    local db = DB()
    local tableOf = db and (kind == "npc" and db.n or kind == "object" and db.o)
    local record = tableOf and tableOf[id]
    if type(record) ~= "string" then
        cache[id] = false
        return nil
    end
    local where, name = record:match("^([^|]*)|(.*)$")
    local place = { name = name ~= "" and name or nil, spots = {} }
    local map
    for _, part in ipairs(Split(where or "", ";")) do
        local m, x, y = part:match("^(%d+):([%d%.]+),([%d%.]+)$")
        if m then
            map = tonumber(m)
        else
            x, y = part:match("^([%d%.]+),([%d%.]+)$")
        end
        if map and x then
            place.spots[#place.spots + 1] = { map = map, x = tonumber(x), y = tonumber(y) }
        end
    end
    cache[id] = place
    return place
end

function facts.ItemName(id)
    local db = DB()
    local name = db and db.i and db.i[tonumber(id) or 0]
    return type(name) == "string" and name or nil
end

function facts.MapName(mapID)
    local db = DB()
    return db and db.maps and db.maps[mapID] or nil
end

local mapIDs
function facts.MapID(name)
    if not mapIDs then
        local db = DB()
        if not db then
            return nil
        end
        mapIDs = {}
        for id, mapName in pairs(db.maps or {}) do
            if not mapIDs[mapName] or id < mapIDs[mapName] then
                mapIDs[mapName] = id
            end
        end
    end
    return name and mapIDs[name] or nil
end

-- A point (map percent) on one map as a point on another, through the maps' world frames; nil when
-- either frame is unknown or they're on different continents.
function facts.Project(fromMap, x, y, toMap)
    if fromMap == toMap then
        return x, y
    end
    local db = DB()
    local from, to = db and db.frames and db.frames[fromMap], db and db.frames and db.frames[toMap]
    if not (from and to and from[1] == to[1] and x and y) then
        return nil
    end
    -- frame = { continent, left, right, top, bottom }: x% runs left -> right (world y), y% top -> bottom (world x).
    local worldY = from[2] + (from[3] - from[2]) * x / 100
    local worldX = from[4] + (from[5] - from[4]) * y / 100
    return (worldY - to[2]) / (to[3] - to[2]) * 100, (worldX - to[4]) / (to[5] - to[4]) * 100
end

-- Whether a character of this race and class token can take the quest. Unknown tokens (a race the
-- masks don't name) only need the quest to be open to the Alliance.
function facts.Takes(q, race, class)
    if not q then
        return false
    end
    local raceBit, classBit = RACE_BITS[race or ""], CLASS_BITS[class or ""]
    local races = q.races or 0
    if races > 0 then
        local low = races % 4294967296
        if raceBit then
            if not HasBit(low, raceBit) then
                return false
            end
        elseif not HasBit(races, 4294967296) then
            -- Not Forever's Alliance race bit: one of the four Alliance races must be in the mask.
            local alliance = false
            for _, bit in ipairs(ALLIANCE_BITS) do
                alliance = alliance or HasBit(low, bit)
            end
            if not alliance then
                return false
            end
        end
    end
    if classBit and (q.classes or 0) > 0 and not HasBit(q.classes, classBit) then
        return false
    end
    return true
end

local function Spot(ref, prefer)
    if not ref or ref.kind == "item" then
        return nil
    end
    local place = facts.Place(ref.kind, ref.id)
    if not (place and place.spots[1]) then
        return nil, nil, nil, place and place.name
    end
    local best = place.spots[1]
    for _, spot in ipairs(place.spots) do
        if prefer and spot.map == prefer then
            best = spot
            break
        end
    end
    return best.map, best.x, best.y, place.name
end

function facts.GiverSpot(id, prefer)
    local q = facts.Quest(id)
    for _, ref in ipairs(q and q.givers or {}) do
        local map, x, y, name = Spot(ref, prefer)
        if map then
            return map, x, y, name
        end
    end
end

function facts.EnderSpot(id, prefer)
    local q = facts.Quest(id)
    for _, ref in ipairs(q and q.enders or {}) do
        local map, x, y, name = Spot(ref, prefer)
        if map then
            return map, x, y, name
        end
    end
end

function facts.ObjectiveSpot(id)
    local q = facts.Quest(id)
    for _, objective in ipairs(q and q.objectives or {}) do
        if objective.spots and objective.spots[1] then
            local spot = objective.spots[1]
            return spot.map, spot.x, spot.y
        end
    end
end

-- Names of what gives / takes a quest ("Marshal McBride", "a Wanted Poster", "Kobold Map").
local function RefName(ref)
    if ref.kind == "item" then
        return facts.ItemName(ref.id)
    end
    local place = facts.Place(ref.kind, ref.id)
    return place and place.name
end

function facts.GiverName(id)
    local q = facts.Quest(id)
    for _, ref in ipairs(q and q.givers or {}) do
        local name = RefName(ref)
        if name then
            return name, ref.kind
        end
    end
end

function facts.EnderName(id)
    local q = facts.Quest(id)
    for _, ref in ipairs(q and q.enders or {}) do
        local name = RefName(ref)
        if name then
            return name, ref.kind
        end
    end
end

local function TitleIndex()
    if not titleIndex then
        titleIndex = {}
        local db = DB()
        for id, record in pairs(db and db.q or {}) do
            local title = type(record) == "string" and record:match("^[^|]*|[^|]*|[^|]*|[^|]*|[^|]*|[^|]*|[^|]*|[^|]*|[^|]*|(.*)$")
            if title then
                local list = titleIndex[title] or {}
                list[#list + 1] = id
                titleIndex[title] = list
            end
        end
    end
    return titleIndex
end

-- How far down a chain of same-title quests this one is (1 = no earlier part among them).
local function Depth(id, set, memo, guard)
    if memo[id] then
        return memo[id]
    end
    if guard[id] then
        return 1
    end
    guard[id] = true
    local q = facts.Quest(id)
    local depth = 1
    for _, list in ipairs(q and { q.all, q.any, q.crumbs } or {}) do
        for _, pre in ipairs(list) do
            if set[pre] then
                depth = math.max(depth, Depth(pre, set, memo, guard) + 1)
            end
        end
    end
    guard[id] = nil
    memo[id] = depth
    return depth
end

local function OnMaps(id, maps)
    local q = facts.Quest(id)
    for _, list in ipairs(q and { q.givers, q.enders } or {}) do
        for _, ref in ipairs(list) do
            local place = ref.kind ~= "item" and facts.Place(ref.kind, ref.id)
            for _, spot in ipairs(place and place.spots or {}) do
                if maps[spot.map] then
                    return true
                end
            end
        end
    end
    return false
end

-- Quest IDs with this title a character of race/class can take, earliest part first. With maps (a set
-- of uiMapIDs), quests given or taken there are preferred when that still leaves `need` parts.
function facts.IDsForTitle(title, race, class, maps, need)
    local all = TitleIndex()[title]
    if not all then
        return nil
    end
    local list, set = {}, {}
    for _, id in ipairs(all) do
        if facts.Takes(facts.Quest(id), race, class) then
            list[#list + 1] = id
            set[id] = true
        end
    end
    if #list == 0 then
        return nil
    end
    if maps and #list > 1 then
        local here = {}
        for _, id in ipairs(list) do
            if OnMaps(id, maps) then
                here[#here + 1] = id
            end
        end
        if #here >= (need or 1) and #here < #list then
            list, set = here, {}
            for _, id in ipairs(list) do
                set[id] = true
            end
        end
    end
    local memo = {}
    table.sort(list, function(a, b)
        local da, db = Depth(a, set, memo, {}), Depth(b, set, memo, {})
        if da ~= db then
            return da < db
        end
        local qa, qb = facts.Quest(a), facts.Quest(b)
        if (qa.min or 0) ~= (qb.min or 0) then
            return (qa.min or 0) < (qb.min or 0)
        end
        return a < b
    end)
    return list
end

-- A quest's prerequisites in Prereqs.lua's shape, for a character of race/class: quests another race or
-- class would do are left out of "all" (they could never be done), breadcrumbs are never needed.
function facts.Prereqs(id, race, class)
    local q = facts.Quest(id)
    if not q then
        return nil
    end
    local need = { all = {}, any = {}, level = q.min }
    for _, pre in ipairs(q.all) do
        if facts.Takes(facts.Quest(pre), race, class) then
            need.all[#need.all + 1] = pre
        end
    end
    for _, pre in ipairs(q.any) do
        if facts.Takes(facts.Quest(pre), race, class) then
            need.any[#need.any + 1] = pre
        end
    end
    -- One of a single quest is that quest.
    if #need.any == 1 then
        need.all[#need.all + 1] = need.any[1]
        need.any = {}
    end
    if #need.any == 0 then
        need.any = nil
    end
    if #need.all == 0 then
        need.all = nil
    end
    return need
end

-- ---- filling what route steps lack --------------------------------------------------------------

local function RouteMaps(route)
    local maps = {}
    local zones = { route.zone }
    for _, zone in ipairs(route.zones or {}) do
        zones[#zones + 1] = zone
    end
    for _, zone in ipairs(zones) do
        local id = facts.MapID(zone)
        if id then
            maps[id] = true
        end
    end
    return maps
end

-- The highest part of each title a route uses, and the lowest part it picks up.
local function PartsOf(routes)
    local parts = {}
    for _, route in ipairs(routes) do
        local steps = rawget(route, "steps")
        for _, step in ipairs(steps or {}) do
            if step.q and (step.t == "accept" or step.t == "turnin" or step.t == "do") then
                local entry = parts[step.q] or { max = 1, maps = {}, firstPick = nil }
                local part = tonumber(step.part) or 1
                entry.max = math.max(entry.max, part)
                if step.t == "accept" and (not entry.firstPick or part < entry.firstPick) then
                    entry.firstPick = part
                end
                for map in pairs(RouteMaps(route)) do
                    entry.maps[map] = true
                end
                if step.map then
                    local id = facts.MapID(step.map)
                    if id then
                        entry.maps[id] = true
                    end
                end
                parts[step.q] = entry
            end
        end
    end
    return parts
end

local function PlaceStep(step, routeMap, map, x, y)
    if not (map and x and y) then
        return false
    end
    if routeMap and map ~= routeMap and not step.map then
        step.map = facts.MapName(map)
        if not step.map then
            return false
        end
    end
    step.x, step.y = x, y
    step.filled = true
    return true
end

-- Fills, for the routes of one character: quest IDs for titles QuestIDs.lua doesn't list, prerequisites
-- for titles Prereqs.lua doesn't list, and the NPC name and coordinates of steps that have none.
-- Hand-written data always wins; only what's missing is added. Returns how many of each were filled.
function facts.Fill(routes, race, class)
    local filled = { ids = 0, prereqs = 0, places = 0 }
    if not DB() or type(routes) ~= "table" then
        return filled
    end
    LevelGuideQuestIDs = LevelGuideQuestIDs or { ids = {}, renamed = {} }
    LevelGuideQuestIDs.ids = LevelGuideQuestIDs.ids or {}
    LevelGuideQuestIDs.renamed = LevelGuideQuestIDs.renamed or {}
    LevelGuidePrereqs = LevelGuidePrereqs or {}
    local ids, renamed, prereqs = LevelGuideQuestIDs.ids, LevelGuideQuestIDs.renamed, LevelGuidePrereqs
    for title, entry in pairs(PartsOf(routes)) do
        local real = renamed[title] or title
        local list = ids[title] or ids[real]
        if not list then
            list = facts.IDsForTitle(real, race, class, entry.maps, entry.max)
                or (real ~= title and facts.IDsForTitle(title, race, class, entry.maps, entry.max))
            if list then
                ids[title] = list
                filled.ids = filled.ids + 1
            end
        end
        if list and not (prereqs[title] or prereqs[real]) then
            local id = list[entry.firstPick or 1]
            local need = id and facts.Prereqs(id, race, class)
            -- A later part's earlier parts are the chain itself: the route's own order handles them.
            if need and entry.firstPick and entry.firstPick > 1 and need.all then
                local kept = {}
                for _, pre in ipairs(need.all) do
                    local isPart = false
                    for _, part in ipairs(list) do
                        isPart = isPart or part == pre
                    end
                    if not isPart then
                        kept[#kept + 1] = pre
                    end
                end
                need.all = #kept > 0 and kept or nil
            end
            if need and (need.all or need.any or need.level) then
                prereqs[title] = need
                filled.prereqs = filled.prereqs + 1
            end
        end
    end
    for _, route in ipairs(routes) do
        local routeMap = facts.MapID(route.zone)
        for _, step in ipairs(rawget(route, "steps") or {}) do
            if step.q and (step.t == "accept" or step.t == "turnin" or step.t == "do") then
                local list = ids[step.q] or ids[renamed[step.q] or step.q]
                local id = list and list[tonumber(step.part) or 1]
                if id then
                    local prefer = step.map and facts.MapID(step.map) or routeMap
                    local map, x, y, name
                    if step.t == "accept" then
                        map, x, y, name = facts.GiverSpot(id, prefer)
                    elseif step.t == "turnin" then
                        map, x, y, name = facts.EnderSpot(id, prefer)
                    else
                        map, x, y = facts.ObjectiveSpot(id)
                    end
                    if step.t ~= "do" and not step.npc and name then
                        step.npc = name
                    end
                    if not (step.x and step.y) and PlaceStep(step, routeMap, map, x, y) then
                        filled.places = filled.places + 1
                    end
                    step.lvl = step.lvl or (facts.Quest(id) and (facts.Quest(id).min or facts.Quest(id).level))
                end
            end
        end
    end
    return filled
end

-- ---- generated routes ----------------------------------------------------------------------------

local function ObjectiveNote(q)
    local parts = {}
    for _, objective in ipairs(q.objectives) do
        local count = objective.count or 1
        local name
        if objective.kind == "kill" or objective.kind == "talk" then
            local place = facts.Place("npc", objective.target)
            name = place and place.name
        elseif objective.kind == "object" then
            local place = facts.Place("object", objective.target)
            name = place and place.name
        elseif objective.kind == "item" then
            name = facts.ItemName(objective.target)
        end
        if name then
            if objective.kind == "kill" then
                parts[#parts + 1] = string.format("Kill %d %s", count, name)
            elseif objective.kind == "talk" then
                parts[#parts + 1] = "Talk to " .. name
            elseif objective.kind == "object" then
                parts[#parts + 1] = (count > 1 and string.format("Use %d %s", count, name)) or ("Use " .. name)
            else
                parts[#parts + 1] = string.format("Get %d %s", count, name)
            end
        end
    end
    return #parts > 0 and table.concat(parts, ", ") or nil
end

local function Dist(ax, ay, bx, by)
    return math.sqrt((ax - bx) ^ 2 + (ay - by) ^ 2)
end

-- Nearest first from (x, y), then nearest to that: a short walk through the points.
local function Walk(items, x, y)
    local out, left = {}, {}
    for _, item in ipairs(items) do
        left[#left + 1] = item
    end
    while #left > 0 do
        local best, bestD
        for index, item in ipairs(left) do
            local d = Dist(x, y, item.x, item.y)
            if not bestD or d < bestD or (d == bestD and item.order < left[best].order) then
                best, bestD = index, d
            end
        end
        local item = table.remove(left, best)
        out[#out + 1] = item
        x, y = item.x, item.y
    end
    return out, x, y
end


local function PartKey(title, part)
    return title .. "#" .. (part or 1)
end

-- Quests given and taken on mapID with a quest level between min and max that a character of race/class
-- takes alone (no group, elite, dungeon, raid, PvP or repeatable quests, none started from an item), in
-- batches. A batch is every quest open once the earlier batches are turned in (its prerequisites on this
-- map done) up to one level above a cursor that rises as the quests run out: pick them up nearest first,
-- do them nearest first, turn them in nearest first. A turn-in far from everything else in its batch
-- waits for a later batch that passes by (unless a quest in the pool needs it first). exclude: a set of
-- "title#part" pick-ups written in hand-made routes, left out here. Steps carry generated = true.
local FAR = 15   -- map points
function facts.BuildRoute(mapID, min, max, race, class, zone, exclude)
    local steps = {}
    local db = DB()
    if not (db and mapID) then
        return steps
    end
    local pool = {}
    for id, record in pairs(db.q) do
        -- Only quests in the level range are decoded (the record starts "level|minLevel|").
        local rawLevel = tonumber(type(record) == "string" and record:match("^(%d+)") or "")
        local q = rawLevel and rawLevel >= min and rawLevel <= max and facts.Quest(id)
        local solo = true
        for flag in pairs(q and q.flags or {}) do
            solo = solo and not NOT_SOLO[flag]
        end
        local level = q and (q.level or q.min)
        if q and solo and level and level >= min and level <= max and (q.min or 1) <= max and facts.Takes(q, race, class) then
            local gMap, gx, gy, gName = facts.GiverSpot(id, mapID)
            local eMap, ex, ey, eName = facts.EnderSpot(id, mapID)
            if gMap == mapID and eMap == mapID then
                pool[id] = { q = q, gx = gx, gy = gy, gName = gName, ex = ex, ey = ey, eName = eName }
            end
        end
    end
    -- Parts of a title, in chain order; pick-ups a hand-made route already has are left out.
    local partOf = {}
    for id, entry in pairs(pool) do
        local list = facts.IDsForTitle(entry.q.title, race, class, { [mapID] = true }, 1) or { id }
        for position, other in ipairs(list) do
            if other == id then
                partOf[id] = position
            end
        end
        if #list > 1 then
            LevelGuideQuestIDs = LevelGuideQuestIDs or { ids = {}, renamed = {} }
            LevelGuideQuestIDs.ids = LevelGuideQuestIDs.ids or {}
            LevelGuideQuestIDs.ids[entry.q.title] = LevelGuideQuestIDs.ids[entry.q.title] or list
        end
    end
    for id, entry in pairs(pool) do
        if exclude and exclude[PartKey(entry.q.title, partOf[id])] then
            pool[id] = nil
        end
    end
    local function Part(id)
        return partOf[id] ~= 1 and partOf[id] or nil
    end
    local function Needed(id)
        -- Another quest in the pool not yet turned in needs this one.
        for other, entry in pairs(pool) do
            if other ~= id then
                for _, list in ipairs({ entry.q.all, entry.q.any }) do
                    for _, pre in ipairs(list) do
                        if pre == id then
                            return true
                        end
                    end
                end
            end
        end
        return false
    end
    local done, picked, owed = {}, {}, {}
    local left = 0
    for _ in pairs(pool) do
        left = left + 1
    end
    local x, y
    local cursor = min
    for _ = 1, 400 do
        if left <= 0 then
            break
        end
        local batch = {}
        for id, entry in pairs(pool) do
            if not picked[id] and (entry.q.level or entry.q.min or 1) <= cursor + 1 and (entry.q.min or 1) <= cursor + 1 then
                local open = true
                for _, list in ipairs({ entry.q.all, entry.q.any }) do
                    for _, pre in ipairs(list) do
                        if pool[pre] and not done[pre] then
                            open = false
                        end
                    end
                end
                if open then
                    batch[#batch + 1] = { id = id, entry = entry, x = entry.gx, y = entry.gy, order = id }
                end
            end
        end
        if #batch == 0 and cursor <= max + 1 then
            cursor = cursor + 1
        elseif #batch == 0 and next(owed) == nil then
            break
        else
            table.sort(batch, function(a, b) return a.id < b.id end)
            if not x and batch[1] then
                x, y = batch[1].x, batch[1].y
            end
            local accepts
            accepts, x, y = Walk(batch, x or 50, y or 50)
            local here = {}
            for _, item in ipairs(accepts) do
                local q = item.entry.q
                picked[item.id] = true
                here[#here + 1] = { item.x, item.y }
                steps[#steps + 1] = { t = "accept", q = q.title, npc = item.entry.gName, x = item.x, y = item.y,
                    lvl = math.max(q.min or 1, (q.level or q.min or 1) - 1), part = Part(item.id), generated = true }
            end
            local work = {}
            for _, item in ipairs(batch) do
                local q = item.entry.q
                local spot = q.objectives[1] and q.objectives[1].spots and q.objectives[1].spots[1]
                if spot and spot.map == mapID then
                    work[#work + 1] = { id = item.id, q = q, x = spot.x, y = spot.y, order = item.id }
                end
            end
            work, x, y = Walk(work, x, y)
            for _, item in ipairs(work) do
                here[#here + 1] = { item.x, item.y }
                steps[#steps + 1] = { t = "do", q = item.q.title, note = ObjectiveNote(item.q), x = item.x, y = item.y,
                    lvl = item.q.level or item.q.min, part = Part(item.id), generated = true }
            end
            for _, item in ipairs(batch) do
                owed[item.id] = { id = item.id, entry = item.entry, x = item.entry.ex, y = item.entry.ey, order = item.id }
            end
            -- Turn in what's near this batch's stops (or needed next); the rest waits for a later batch.
            local flush = #batch == 0
            local turnins = {}
            for id, item in pairs(owed) do
                local close = flush or Needed(id)
                for _, point in ipairs(here) do
                    close = close or Dist(point[1], point[2], item.x, item.y) <= FAR
                end
                if close then
                    turnins[#turnins + 1] = item
                end
            end
            table.sort(turnins, function(a, b) return a.id < b.id end)
            turnins, x, y = Walk(turnins, x, y)
            for _, item in ipairs(turnins) do
                local q = item.entry.q
                steps[#steps + 1] = { t = "turnin", q = q.title, npc = item.entry.eName, x = item.x, y = item.y,
                    lvl = q.level or q.min, part = Part(item.id), generated = true }
                done[item.id], owed[item.id] = true, nil
                left = left - 1
            end
        end
    end
    return steps
end

-- Pick-ups ("title#part") in the hand-made routes, so a generated route doesn't repeat them.
local function WrittenPickups()
    local set = {}
    for _, chain in pairs(LevelGuideRoutes and LevelGuideRoutes.chains or {}) do
        for _, route in ipairs(chain) do
            for _, step in ipairs(rawget(route, "steps") or {}) do
                if step.t == "accept" and step.q then
                    set[PartKey(step.q, tonumber(step.part))] = true
                end
            end
        end
    end
    return set
end

local function Token(fn)
    if not fn then
        return nil
    end
    local ok, _, token = pcall(fn, "player")
    if ok and type(token) == "string" and not (issecretvalue and issecretvalue(token)) then
        return token
    end
end

-- A route for a zone with no written stop list: its steps are built from QuestDB the first time anything
-- reads route.steps, for your race and class (UnitRace / UnitClass tokens, secret values ignored).
-- fields may set qmin / qmax (quest levels to take; default min / max), key and name. Without QuestDB
-- the route has no steps and the guide passes it by.
function facts.Generated(zone, mapID, min, max, fields)
    local route = { zone = zone, min = min, max = max, generated = true, key = zone .. " (generated)",
        name = zone .. " (generated from quest data)" }
    for k, v in pairs(fields or {}) do
        route[k] = v
    end
    return setmetatable(route, { __index = function(self, key)
        if key ~= "steps" then
            return nil
        end
        local steps = facts.BuildRoute(mapID, self.qmin or min, self.qmax or max, Token(UnitRace), Token(UnitClass), zone,
            WrittenPickups())
        rawset(self, "steps", steps)
        return steps
    end })
end