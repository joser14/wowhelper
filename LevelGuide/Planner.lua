-- LevelGuide planner: the arithmetic behind the guide, kept apart from LevelGuide.lua (whose main chunk is
-- at Lua's 200-local limit) and free of game calls, so tests can check it with plain numbers. LevelGuide.lua
-- reads it through the global LevelGuidePlanner; without it the guide works as before, without these extras.
--
-- XP model (Share, GreyLevel, ZeroDiff, MobXP, LEVEL_XP, Run): ported from Polestar
-- (addon\Polestar\Core\Levels.lua, https://github.com/fitzforge/polestar), Copyright (c) 2026 The Polestar
-- authors, GPL-3.0-only; changed for LevelGuide (entries carry a projected level, rested XP and classes left
-- out). Everything else here is our own code after the ideas described in research\guides_deep_re.md.
--
--   XP:      Share(plevel, qlevel), GreyLevel(L), ZeroDiff(L), MobXP(L, mob, elite), Trivial(L, q, range),
--            QuestXP(id) -> xp, kills, Run(entries, p) -> summary
--   Arrow:   Damp(current, target, dt), Closing(state, yards, dt), ETA(yards, speed), Radius(kind, r),
--            Arrived(state, key, yards, r), Switch(curYards, newYards)
--   Here:    DetourSeconds(dPN, dNW, dPW), TurninShows(...), Mute(...)/Muted(...)
--   Camps:   PickCamp(camps, distances, state, now, sample)
--   Maps:    MapYards(mapID, x1, y1, x2, y2) on QuestDB frames (map percent 0-100)
--   Fit:     Fit(points, camps, ender, yards) -> do-after index, turn-in-after index

local P = {}
LevelGuidePlanner = P

local floor, ceil, max, min, abs, exp, pi = math.floor, math.ceil, math.max, math.min, math.abs, math.exp, math.pi

-- ---- XP (ported from Polestar Core\Levels.lua, GPL-3.0-only) ----------------------------------------------

-- XP to go from level L to L + 1 (index L): the 1.12 table.
P.LEVEL_XP = {
    400, 900, 1400, 2100, 2800, 3600, 4500, 5400, 6500, 7600,
    8800, 10100, 11400, 12900, 14400, 16000, 17700, 19400, 21300, 23200,
    25200, 27300, 29400, 31700, 34000, 36400, 38900, 41400, 44300, 47400,
    50800, 54500, 58600, 62800, 67100, 71600, 76100, 80800, 85700, 90700,
    95800, 101000, 106300, 111800, 117500, 123200, 129100, 135100, 141200, 147500,
    153900, 160400, 167100, 173900, 180800, 187900, 195000, 202300, 209800,
}
P.MAX_LEVEL = 60

-- Share of a quest's reward by player level - quest level: full up to 5 above it, then 80/60/40/20%, 10% from 10.
local SHARE = { 0.8, 0.6, 0.4, 0.2 }
function P.Share(plevel, qlevel)
    local d = plevel - (qlevel or plevel)
    if d <= 5 then
        return 1
    end
    if d >= 10 then
        return 0.1
    end
    return SHARE[d - 5]
end

-- The level gap that brings a lower mob's XP to nothing.
function P.ZeroDiff(l)
    if l <= 7 then return 5 elseif l <= 9 then return 6 elseif l <= 11 then return 7
    elseif l <= 15 then return 8 elseif l <= 19 then return 9 elseif l <= 29 then return 11
    elseif l <= 39 then return 12 elseif l <= 44 then return 13 elseif l <= 49 then return 14
    elseif l <= 54 then return 15 elseif l <= 59 then return 16 end
    return 17
end

-- The highest grey mob (and quest) level for a player level.
function P.GreyLevel(l)
    if l <= 5 then
        return 0
    end
    if l <= 39 then
        return l - floor(l / 10) - 5
    end
    if l <= 59 then
        return l - floor(l / 5) - 1
    end
    return l - 9
end

-- One kill: 45 + 5 x level for an equal mob, +5% per level above (up to 4), less below, none when grey,
-- elites x2.
function P.MobXP(plevel, mob, elite)
    local base = plevel * 5 + 45
    local v
    if mob >= plevel then
        v = base * (1 + 0.05 * min(mob - plevel, 4))
    elseif mob <= P.GreyLevel(plevel) then
        v = 0
    else
        v = max(0, base * (1 - (plevel - mob) / P.ZeroDiff(plevel)))
    end
    return floor(v + 0.5) * (elite and 2 or 1)
end

-- Whether a quest is grey: the client's trivial range when it gives one (trivial when L - q > range),
-- else the grey level.
function P.Trivial(plevel, qlevel, range)
    if not (plevel and qlevel) then
        return false
    end
    if type(range) == "number" and range > 0 then
        return plevel - qlevel > range
    end
    return qlevel <= P.GreyLevel(plevel)
end

-- A quest's full XP and the kills its objectives take, from QuestXP.lua (generated from forever-db):
-- xp (or nil), { { mob = level, n = kills, elite }, ... }.
local xpCache = {}
function P.QuestXP(id)
    id = tonumber(id)
    local data = id and LevelGuideQuestXP and LevelGuideQuestXP.q and LevelGuideQuestXP.q[id]
    if type(data) ~= "string" then
        return nil, {}
    end
    local cached = xpCache[id]
    if cached then
        return cached.xp, cached.kills
    end
    local xp, rest = data:match("^(%d+)|?(.*)$")
    local kills = {}
    for part in (rest or ""):gmatch("[^;]+") do
        local mob, n, e = part:match("^(%d+):(%d+):?(e?)$")
        if mob then
            kills[#kills + 1] = { mob = tonumber(mob), n = tonumber(n), elite = e == "e" }
        end
    end
    cached = { xp = tonumber(xp), kills = kills }
    xpCache[id] = cached
    return cached.xp, cached.kills
end

-- Simulates entries in order from p = { level, xp, xpMax }:
--   { kind = "quest", xp = full reward, level = quest level } (xp already the player's: share = false)
--   { kind = "kill", n, mob, elite }
-- Each entry gets e.at (the fractional level before it) and e.gain. Returns { level, xp, need, at (final
-- fractional level), questXP, killXP }.
function P.Run(entries, p)
    local level = p.level or 1
    local xp = p.xp or 0
    local function need(l)
        if l == p.level and (p.xpMax or 0) > 0 then
            return p.xpMax
        end
        return P.LEVEL_XP[l] or 0
    end
    local s = { questXP = 0, killXP = 0 }
    local function at()
        local n = need(level)
        return level + (n > 0 and min(xp / n, 0.999) or 0)
    end
    local function gain(n)
        xp = xp + n
        while level < P.MAX_LEVEL and xp >= need(level) and need(level) > 0 do
            xp = xp - need(level)
            level = level + 1
        end
        if level >= P.MAX_LEVEL then
            xp = 0
        end
    end
    for _, e in ipairs(entries) do
        e.at = at()
        e.gain = 0
        if level < P.MAX_LEVEL then
            if e.kind == "kill" then
                for _ = 1, e.n or 0 do
                    local one = P.MobXP(level, e.mob or level, e.elite)
                    e.gain = e.gain + one
                    s.killXP = s.killXP + one
                    gain(one)
                end
            elseif type(e.xp) == "number" and e.xp > 0 then
                local one = e.share == false and e.xp or floor(e.xp * P.Share(level, e.level) + 0.5)
                e.gain = one
                s.questXP = s.questXP + one
                gain(one)
            end
        end
    end
    s.level, s.xp, s.need, s.at = level, xp, need(level), at()
    return s
end

-- ---- arrow ------------------------------------------------------------------------------------------------

local function Wrap(a)
    return (a + pi) % (2 * pi) - pi
end
P.Wrap = Wrap

-- Turns a bearing toward the target: an exponential swing (rate 12/s), at most 3.5 rad/s. Nil: snap.
function P.Damp(current, target, dt)
    if current == nil or not dt or dt <= 0 then
        return current == nil and target or current
    end
    local diff = Wrap(target - current)
    local turn = diff * (1 - exp(-12 * dt))
    local cap = 3.5 * dt
    turn = max(-cap, min(cap, turn))
    return Wrap(current + turn)
end

-- Closing speed in yards per second (a low-pass of the change in distance); state is per target.
function P.Closing(state, yards, dt)
    if state.last and dt and dt > 0 then
        local v = (state.last - yards) / dt
        state.speed = (state.speed or 0) + (v - (state.speed or 0)) * min(1, 2 * dt)
    end
    state.last = yards
    return state.speed or 0
end

-- Seconds to arrive at that closing speed; nil when not really closing in (1.5 yd/s or less).
function P.ETA(yards, speed)
    if not (speed and speed > 1.5 and yards) then
        return nil
    end
    return yards / speed
end

-- Arrival radius per kind of stop: a person 8 yd, a move 12, a work area its camp's radius (at least 15).
local RADIUS = { pickup = 8, turnin = 8, travel = 12, work = 15, level = 8, flight = 8, home = 8, train = 8 }
function P.Radius(kind, campRadius)
    if kind == "work" and campRadius then
        return max(15, campRadius)
    end
    return RADIUS[kind] or 10
end

-- Arrived at the target (state keeps the last arrival): inside r, and once there, until beyond
-- r + max(5, r/2), so standing at the edge doesn't flip it back and forth.
function P.Arrived(state, key, yards, r)
    if state.arrived == key then
        if yards > r + max(5, r / 2) then
            state.arrived = nil
            return false
        end
        return true
    end
    if yards <= r then
        state.arrived = key
        return true
    end
    return false
end

-- Whether a new nearest target should replace the current one: only when more than 25% and more than
-- 40 yd nearer.
function P.Switch(curYards, newYards)
    if not (curYards and newYards) then
        return true
    end
    return newYards < curYards * 0.75 and curYards - newYards > 40
end

-- ---- while you're here ----------------------------------------------------------------------------------

P.HERE = { radius = 180, atNpc = 30, turninSeconds = 20, maxLines = 3, muteSeconds = 120, muteYards = 100,
    restingYards = 100, maxYards = 250 }

-- Seconds a detour to N on the way from P to W costs (yards winding by 1.25, run speed 7 yd/s).
function P.DetourSeconds(dPN, dNW, dPW)
    if not (dNW and dPW) then
        return 2 * dPN * 1.25 / 7
    end
    return max(0, dPN + dNW - dPW) * 1.25 / 7
end

-- A ready turn-in shows when you're at its NPC, or (within 250 yd) when the detour fits the budget
-- (20 s, doubled when waiting for the route's own turn-in would cost XP), or when resting within 100 yd.
function P.TurninShows(dPN, detour, losesXP, resting)
    local H = P.HERE
    if dPN <= H.atNpc then
        return true
    end
    if dPN > H.maxYards then
        return false
    end
    if resting and dPN <= H.restingYards then
        return true
    end
    return detour <= H.turninSeconds * (losesXP and 2 or 1)
end

-- Dismissing a line mutes it for 120 s and until you've moved 100 yd; a second dismiss mutes it for
-- the zone stay. mutes[key] = { n, untilT, x, y, zone }.
function P.Mute(mutes, key, now, x, y, zone)
    local m = mutes[key] or { n = 0 }
    m.n = m.n + 1
    m.untilT, m.x, m.y, m.zone = now + P.HERE.muteSeconds, x, y, zone
    mutes[key] = m
end

function P.Muted(mutes, key, now, movedYards, zone)
    local m = mutes[key]
    if not m then
        return false
    end
    if m.zone ~= zone then
        mutes[key] = nil
        return false
    end
    if m.n >= 2 then
        return true
    end
    return now < m.untilT or (movedYards or 0) < P.HERE.muteYards
end

-- ---- spawn camps ------------------------------------------------------------------------------------------

P.CAMP = { switchYards = 40, leaveYards = 4, forgetSeconds = 300, dwellSeconds = 7, dwellYards = 10, minRadius = 15 }

-- Which camp the arrow points at. distances[i] = yards from you to camp i's centre, camps[i].r its radius.
-- state = { at, visited = {i = time}, inside, dwellT, dwellX, dwellY } is kept per step. sample =
-- { progressed (objective progress since the last call), fighting, x, y (your position, yards) }.
-- A camp is checked once you've been inside it and left it (4 yd past its edge), or stood 7 s within 10 yd
-- with no progress and no fight. Checked camps are skipped for 300 s; the nearest unchecked one wins,
-- but a target changes only for one more than 40 yd nearer.
function P.PickCamp(camps, distances, state, now, sample)
    local C = P.CAMP
    state.visited = state.visited or {}
    for i, t in pairs(state.visited) do
        if now - t > C.forgetSeconds then
            state.visited[i] = nil
        end
    end
    sample = sample or {}
    local at = state.at
    if at and camps[at] then
        local r = max(C.minRadius, camps[at].r or 0)
        local d = distances[at]
        if d <= r then
            if state.inside ~= at then
                state.inside, state.dwellT, state.dwellX, state.dwellY = at, now, sample.x, sample.y
            end
            local moved = sample.x and state.dwellX and math.sqrt((sample.x - state.dwellX) ^ 2 + (sample.y - state.dwellY) ^ 2) or 0
            if sample.progressed or sample.fighting or moved > C.dwellYards then
                state.dwellT, state.dwellX, state.dwellY = now, sample.x, sample.y
            elseif now - (state.dwellT or now) >= C.dwellSeconds then
                state.visited[at], state.inside = now, nil
            end
        elseif state.inside == at and d > r + C.leaveYards then
            state.visited[at], state.inside = now, nil
        end
    end
    local best, bestD
    for i = 1, #camps do
        if not state.visited[i] and (not bestD or distances[i] < bestD) then
            best, bestD = i, distances[i]
        end
    end
    if not best then
        -- Every camp checked: start the circuit again, from the nearest other than the one just left.
        state.visited = {}
        for i = 1, #camps do
            if (i ~= at or #camps == 1) and (not bestD or distances[i] < bestD) then
                best, bestD = i, distances[i]
            end
        end
    end
    if at and camps[at] and not state.visited[at] and best ~= at and not P.Switch(distances[at], bestD) then
        best = at
    end
    if best ~= at then
        state.inside, state.dwellT = nil, nil
    end
    state.at = best
    return best
end

-- ---- maps -------------------------------------------------------------------------------------------------

-- Yards between two points (map percent) on a QuestDB map, from its world frame; nil without one.
function P.MapYards(mapID, x1, y1, x2, y2)
    local frames = LevelGuideQuestDB and LevelGuideQuestDB.frames
    local f = frames and frames[mapID]
    if not (f and x1 and y1 and x2 and y2) then
        return nil
    end
    local w, h = abs(f[3] - f[2]), abs(f[5] - f[4])
    return math.sqrt(((x2 - x1) * w / 100) ^ 2 + ((y2 - y1) * h / 100) ^ 2)
end

-- ---- fitting a quest that isn't on the route --------------------------------------------------------------

-- points: the route's upcoming stops in order, { x, y } (nil x for one without a spot); camps: the quest's
-- objective spots { x, y }; ender: its turn-in { x, y } or nil; yards(a, b) measures between two points.
-- Its work goes after the first stop within 250 yd of a camp (in the next 150), its turn-in after the first
-- stop from there within 80 yd of the turn-in. Returns doAfter, turnAfter (indexes into points) or nil.
P.FIT = { lookAhead = 150, workYards = 250, turninYards = 80 }
function P.Fit(points, camps, ender, yards)
    local F = P.FIT
    local doAfter
    for i = 1, min(#points, F.lookAhead) do
        local p = points[i]
        if p and p.x then
            for _, c in ipairs(camps) do
                local d = yards(p, c)
                if d and d <= F.workYards then
                    doAfter = i
                    break
                end
            end
        end
        if doAfter then
            break
        end
    end
    if #camps == 0 then
        doAfter = 0
    end
    if not doAfter then
        return nil
    end
    if not ender then
        return doAfter, nil
    end
    for i = max(doAfter, 1), min(#points, doAfter + F.lookAhead) do
        local p = points[i]
        local d = p and p.x and yards(p, ender)
        if d and d <= F.turninYards then
            return doAfter, i
        end
    end
    return doAfter, nil
end

return P
