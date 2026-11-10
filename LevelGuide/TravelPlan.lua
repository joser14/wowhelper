-- LevelGuide travel planner (research\guides_deep_re.md 12.7; our own code after the ideas described there):
-- the quickest way from where you are to a spot on any map, over walking, the flights you know, boats, the
-- tram, portals, the zeppelin and your hearthstone. Pure arithmetic over LevelGuideTravel (Travel.lua), no
-- game calls, so tests check it with plain numbers; LevelGuide.lua feeds it the game's state. It never acts:
-- it only says what to do.
--
--   TravelWorld(map, x, y) -> continent, wx, wy      TravelYards(a, b) -> yards or nil
--   TravelZoneAt(continent, wx, wy) -> uiMap          TravelDanger(zone, level) -> 1, 3 or 20
--   TravelPlan(opts) -> { legs = { { kind, text, from, to, seconds, learn } }, total, usesHearth } or nil
--     opts = { from, to = { map, x, y (percent)[, name] }, level, speed (yd/s, default 7),
--              known = function(flight master name) -> bool, hearth = { map, x, y, name } (ready and bound),
--              learned = { ["From>To"] = seconds } }
--
-- Costs (seconds):
--   walk    straight yards x 1.25 / speed, x3 through a zone whose lowest level is 4+ above you and x20 for 11+
--           above (the zones you start and end in don't count), +15 per zone border crossed; never between
--           places that aren't joined on foot (continents, Teldrassil's top and Rut'theran, Zephras Isle)
--   flight  your own learned time, else yards x 1.15 / 30 + 10; only to a flight point you know; from one you
--           don't know only after walking there (+10 to learn it); several hops are one flight
--   boat, tram, zeppelin, portal: typical wait + ride (Travel.lua)
--   hearth  15, used only when the trip takes 3 min or more without it and it saves 2 min or more
local P = LevelGuidePlanner
if not P then
    return
end

local sqrt, max, min, floor, abs = math.sqrt, math.max, math.min, math.floor, math.abs
P.TRAVEL = { speed = 7, winding = 1.25, zoneSeconds = 15, flightSpeed = 30, flightWinding = 1.15, flightSeconds = 10,
    learnSeconds = 10, hearthSeconds = 15, hearthMinTrip = 180, hearthMinSave = 120, shortWalk = 10 }

local function Data()
    return LevelGuideTravel
end

function P.TravelWorld(map, x, y)
    local T = Data()
    local f = T and T.frames[map]
    if not (f and x and y) then
        return nil
    end
    return f[1], f[4] + y / 100 * (f[5] - f[4]), f[2] + x / 100 * (f[3] - f[2])
end

function P.TravelYards(a, b)
    local ca, ax, ay = P.TravelWorld(a.map, a.x, a.y)
    local cb, bx, by = P.TravelWorld(b.map, b.x, b.y)
    if not (ca and cb and ca == cb) then
        return nil
    end
    return sqrt((ax - bx) ^ 2 + (ay - by) ^ 2)
end

-- The map a world point belongs to: of the maps around it, the one it sits deepest inside (map frames
-- overlap at their edges; a city sits deep inside its own small frame).
local byContinent
function P.TravelZoneAt(continent, wx, wy)
    local T = Data()
    if not (T and continent and wx and wy) then
        return nil
    end
    if not byContinent then
        byContinent = {}
        for id, f in pairs(T.frames) do
            byContinent[f[1]] = byContinent[f[1]] or {}
            table.insert(byContinent[f[1]], { id = id, f = f })
        end
    end
    local best, bestDepth
    for _, entry in ipairs(byContinent[continent] or {}) do
        local f = entry.f
        local u = (wy - f[2]) / (f[3] - f[2])
        local v = (wx - f[4]) / (f[5] - f[4])
        local depth = min(u, 1 - u, v, 1 - v)
        if depth >= 0 and (not bestDepth or depth > bestDepth) then
            best, bestDepth = entry.id, depth
        end
    end
    return best
end

function P.TravelDanger(zone, level)
    local T = Data()
    local range = T and zone and T.levels[zone]
    if not (range and level) then
        return 1
    end
    if range[1] > level + 10 then
        return 20
    elseif range[1] >= level + 4 then
        return 3
    end
    return 1
end

-- A place in the graph: map spot plus its world position, region and zone.
local function Vertex(p, extra)
    local T = Data()
    local c, wx, wy = P.TravelWorld(p.map, p.x, p.y)
    if not c then
        return nil
    end
    local v = extra or {}
    v.name, v.map, v.x, v.y, v.c, v.wx, v.wy = v.name or p.name, p.map, p.x, p.y, c, wx, wy
    v.region = T.Region(p.map, p.x, p.y)
    return v
end

-- The fixed part of the graph (flight masters and docks), built once.
local static
local function Static()
    if static then
        return static
    end
    local T = Data()
    local list, byFp, byDock = {}, {}, {}
    for _, fp in ipairs(T.fp) do
        local v = Vertex(fp, { kind = "fp", name = fp.name })
        if v then
            list[#list + 1] = v
            byFp[fp.name] = v
            v.flights = {}
        end
    end
    for _, pair in ipairs(T.flights) do
        local a, b = byFp[pair[1]], byFp[pair[2]]
        if a and b then
            a.flights[#a.flights + 1] = b
            b.flights[#b.flights + 1] = a
        end
    end
    local function Dock(p)
        local key = p.map .. ":" .. p.x .. ":" .. p.y
        if not byDock[key] then
            local v = Vertex(p, { kind = "dock", name = p.name, links = {} })
            if v then
                list[#list + 1] = v
                byDock[key] = v
            end
        end
        return byDock[key]
    end
    for _, link in ipairs(T.links) do
        local a, b = Dock(link.a), Dock(link.b)
        if a and b then
            local seconds = (link.wait or 0) + (link.ride or 0)
            a.links[#a.links + 1] = { to = b, link = link, from = a, seconds = seconds }
            if not link.oneWay then
                b.links[#b.links + 1] = { to = a, link = link, from = b, seconds = seconds, back = true }
            end
        end
    end
    for index, v in ipairs(list) do
        v.index = index
    end
    static = list
    return static
end

-- Seconds on foot from a to b, or nil when they aren't joined on foot.
local function Walk(a, b, ctx)
    if a.region ~= b.region or a.c ~= b.c then
        return nil
    end
    local C = P.TRAVEL
    local dx, dy = b.wx - a.wx, b.wy - a.wy
    local d = sqrt(dx * dx + dy * dy)
    local zones = { a.map }
    for _, t in ipairs({ 0.25, 0.5, 0.75 }) do
        zones[#zones + 1] = P.TravelZoneAt(a.c, a.wx + dx * t, a.wy + dy * t)
    end
    zones[#zones + 1] = b.map
    local mult, crossings, last = 1, 0, nil
    for _, zone in ipairs(zones) do
        if zone then
            if last and zone ~= last then
                crossings = crossings + 1
            end
            last = zone
            if not ctx.exempt[zone] then
                mult = max(mult, P.TravelDanger(zone, ctx.level))
            end
        end
    end
    return d * C.winding / ctx.speed * mult + crossings * C.zoneSeconds
end

local walkCache = { key = nil, pairs = {} }
local function StaticWalk(a, b, ctx)
    if walkCache.key ~= ctx.key then
        walkCache.key, walkCache.pairs = ctx.key, {}
    end
    local row = walkCache.pairs[a.index]
    if not row then
        row = {}
        walkCache.pairs[a.index] = row
    end
    local cached = row[b.index]
    if cached == nil then
        cached = Walk(a, b, ctx) or false
        row[b.index] = cached
    end
    return cached or nil
end

local function FlightSeconds(a, b, ctx)
    local learned = ctx.learned and (ctx.learned[a.name .. ">" .. b.name] or ctx.learned[b.name .. ">" .. a.name])
    if type(learned) == "number" and learned > 0 then
        return learned
    end
    local C = P.TRAVEL
    local d = sqrt((b.wx - a.wx) ^ 2 + (b.wy - a.wy) ^ 2)
    return d * C.flightWinding / C.flightSpeed + C.flightSeconds
end

local function Minutes(seconds)
    return max(1, floor(seconds / 60 + 0.5))
end

local function Point(v)
    return { map = v.map, x = v.x, y = v.y, name = v.name }
end

-- One leg's words.
local function LegText(leg)
    local T = Data()
    local kind, from, to = leg.kind, leg.from, leg.to
    if kind == "walk" then
        return "Walk to " .. tostring(to.name or T.names[to.map] or "there")
    elseif kind == "fly" then
        if leg.learn then
            return string.format("Learn the flight path at %s, then fly to %s, ~%d min", from.name, to.name, Minutes(leg.seconds))
        end
        return string.format("Fly %s to %s, ~%d min", from.name, to.name, Minutes(leg.seconds))
    elseif kind == "boat" then
        return string.format("Take the boat at %s to %s, ~%d min", from.name, to.name, Minutes(leg.seconds))
    elseif kind == "tram" then
        return string.format("Take the Deeprun Tram to %s, ~%d min", T.names[to.map] or to.name, Minutes(leg.seconds))
    elseif kind == "portal" then
        return string.format("Take %s to %s", from.name, to.name)
    elseif kind == "zeppelin" then
        return string.format("Take %s to %s, ~%d min", from.name, to.name, Minutes(leg.seconds))
    elseif kind == "hearth" then
        return "Use your hearthstone to " .. tostring(to.name)
    end
    return tostring(kind)
end

local function Run(opts, withHearth)
    local T = Data()
    local list = Static()
    local start = Vertex(opts.from, { kind = "start", name = "you" })
    local goal = Vertex(opts.to, { kind = "goal", name = opts.to.name or T.names[opts.to.map] })
    if not (start and goal) then
        return nil
    end
    local level = opts.level or 1
    local speed = min(max(tonumber(opts.speed) or P.TRAVEL.speed, 4), 14)
    local exempt = { [start.map] = true, [goal.map] = true }
    local ctx = { level = level, speed = speed, exempt = exempt, learned = opts.learned,
        key = level .. ":" .. speed .. ":" .. start.map .. ":" .. goal.map }
    local known = opts.known or function() return false end
    local n = #list
    start.index, goal.index = n + 1, n + 2
    local all = {}
    for i = 1, n do
        all[i] = list[i]
    end
    all[n + 1], all[n + 2] = start, goal
    local inn
    if withHearth and opts.hearth then
        inn = Vertex(opts.hearth, { kind = "inn", name = opts.hearth.name or T.names[opts.hearth.map] })
        if inn then
            inn.index = n + 3
            all[n + 3] = inn
        end
    end
    local dist, prev, done = {}, {}, {}
    dist[start.index] = 0
    local function Relax(u, v, seconds, edge)
        if not seconds then
            return
        end
        local d = dist[u.index] + seconds
        if not dist[v.index] or d < dist[v.index] then
            dist[v.index] = d
            edge.from, edge.to, edge.seconds = u, v, seconds
            prev[v.index] = edge
        end
    end
    while true do
        local u, best
        for index, d in pairs(dist) do
            if not done[index] and (not best or d < best) then
                u, best = all[index], d
            end
        end
        if not u or u == goal then
            break
        end
        done[u.index] = true
        -- On foot to every other place, and to the goal.
        for _, v in ipairs(all) do
            if v ~= u and v ~= start and v ~= inn and not done[v.index] then
                local seconds
                if u.kind ~= "start" and u.kind ~= "inn" and v.kind ~= "goal" then
                    seconds = StaticWalk(u, v, ctx)
                else
                    seconds = Walk(u, v, ctx)
                end
                Relax(u, v, seconds, { kind = "walk" })
            end
        end
        -- Flights: only to a flight point you know; from one you don't, learn it first.
        if u.kind == "fp" then
            local from = prev[u.index]
            local arrivedFlying = from and from.kind == "fly"
            local learn = not known(u.name)
            if not (learn and arrivedFlying) then
                for _, v in ipairs(u.flights) do
                    if known(v.name) and not done[v.index] then
                        Relax(u, v, FlightSeconds(u, v, ctx) + (learn and P.TRAVEL.learnSeconds or 0), { kind = "fly", learn = learn })
                    end
                end
            end
        end
        for _, edge in ipairs(u.links or {}) do
            if not done[edge.to.index] then
                Relax(u, edge.to, edge.seconds, { kind = edge.link.kind, link = edge.link })
            end
        end
        if u == start and inn then
            Relax(u, inn, P.TRAVEL.hearthSeconds, { kind = "hearth" })
        end
    end
    if not dist[goal.index] then
        return nil
    end
    -- Back from the goal: the edges in order, then flights merged and tiny walks dropped.
    local edges = {}
    local at = goal
    while at ~= start do
        local edge = prev[at.index]
        table.insert(edges, 1, edge)
        at = edge.from
    end
    local legs, usesHearth = {}, false
    for _, edge in ipairs(edges) do
        local last = legs[#legs]
        if edge.kind == "fly" and last and last.kind == "fly" then
            last.to, last.toVertex = Point(edge.to), edge.to
            last.seconds = last.seconds + edge.seconds
        else
            local leg = { kind = edge.kind, from = Point(edge.from), to = Point(edge.to), seconds = edge.seconds,
                learn = edge.learn, link = edge.link }
            if edge.kind == "hearth" then
                usesHearth = true
            end
            local yards = edge.kind == "walk" and sqrt((edge.to.wx - edge.from.wx) ^ 2 + (edge.to.wy - edge.from.wy) ^ 2)
            if not (yards and yards < P.TRAVEL.shortWalk and #edges > 1) then
                legs[#legs + 1] = leg
            end
        end
    end
    for _, leg in ipairs(legs) do
        leg.text = LegText(leg)
    end
    return { legs = legs, total = dist[goal.index], usesHearth = usesHearth }
end

function P.TravelPlan(opts)
    local T = Data()
    if not (T and opts and opts.from and opts.to and T.frames[opts.from.map] and T.frames[opts.to.map]) then
        return nil
    end
    local plan = Run(opts, opts.hearth ~= nil)
    if plan and plan.usesHearth then
        -- The hearthstone has a long cooldown: only for a real saving on a real trip.
        local without = Run(opts, false)
        local C = P.TRAVEL
        if without and not (without.total >= C.hearthMinTrip and without.total - plan.total >= C.hearthMinSave) then
            return without
        end
    end
    return plan
end

-- Whether a flight point is known, from LevelGuide's saved names ("Auberdine, Darkshore" or "Auberdine").
function P.TravelKnown(saved)
    local names = {}
    for name, value in pairs(saved or {}) do
        if value and type(name) == "string" then
            names[(name:match("^([^,]+)") or name):lower()] = true
        end
    end
    return function(name)
        return names[tostring(name):lower()] or false
    end
end

-- The inn a bind location name (GetBindLocation) stands for, as a point with that name, or nil.
function P.TravelInn(bindName)
    local T = Data()
    if not (T and type(bindName) == "string" and bindName ~= "") then
        return nil
    end
    local want = bindName:lower()
    for _, inn in ipairs(T.inns) do
        for _, name in ipairs(inn.names) do
            if name:lower() == want then
                return { map = inn.map, x = inn.x, y = inn.y, name = inn.names[1] }
            end
        end
    end
end

return P
