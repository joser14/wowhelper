-- XP flow audit for one race's chain. ADDON_PATH = LevelGuide folder. KILLS_ARG = kill XP as a fraction of
-- quest XP (default 0.5: Classic questing is roughly 2/3 quest XP, 1/3 kills). MODE_ARG = "old" models the
-- engine before this round (you stay in a zone while it has any pending pick-up), "new" (default) the engine
-- that sends you on to the next zone in the chain with something to do when you're stuck under-leveled.
-- Approximations: a quest's level = its step lvl; full quest XP by level is a piecewise fit to typical Classic
-- rewards (~410 at 5, ~760 at 10, ~1610 at 20, ~2460 at 30, ~3460 at 40, ~4460 at 50, ~5960 at 60);
-- reduction by (player - quest level): <=5 100%, 6 80%, 7 60%, 8 40%, 9 20%, >=10 10% (warcraft.wiki.gg
-- Experience_point); XP to level from warcraft.wiki.gg Experience_to_level (Classic).
local base = ADDON_PATH
assert(loadfile(base .. "/QuestIDs.lua"))("LevelGuide", {})
assert(loadfile(base .. "/Prereqs.lua"))("LevelGuide", {})
assert(loadfile(base .. "/Routes.lua"))("LevelGuide", {})
local RACE = RACE_ARG or "NightElf"
local KILLS = KILLS_ARG or 0.5
local MODE = MODE_ARG or "new"
local OUTLEVELED = 4
local TO_LEVEL = { 400, 900, 1400, 2100, 2800, 3600, 4500, 5400, 6500, 7600, 8800, 10100, 11400, 12900, 14400, 16000,
    17700, 19400, 21300, 23200, 25200, 27300, 29400, 31700, 34000, 36400, 38900, 41400, 44300, 47400, 50800, 54500,
    58600, 62800, 67100, 71600, 76100, 80800, 85700, 90700, 95800, 101000, 106300, 111800, 117500, 123200, 129100,
    135100, 141200, 147500, 153900, 160400, 167100, 173900, 180800, 187900, 195000, 202300, 209800 }
local function FullXP(q)
    if q <= 10 then return 60 + 70 * q end
    if q <= 30 then return 760 + 85 * (q - 10) end
    if q <= 50 then return 2460 + 100 * (q - 30) end
    return 4460 + 150 * (q - 50)
end
local function Factor(diff)
    if diff <= 5 then return 1 elseif diff == 6 then return 0.8 elseif diff == 7 then return 0.6
    elseif diff == 8 then return 0.4 elseif diff == 9 then return 0.2 end
    return 0.1
end
local level, xp = 1, 0
local function Gain(amount)
    xp = xp + amount
    while level < 60 and xp >= TO_LEVEL[level] do
        xp = xp - TO_LEVEL[level]
        level = level + 1
    end
    if level == 60 then xp = 0 end
end
local function Lvl() return level + (level < 60 and xp / TO_LEVEL[level] or 0) end

local held, everAccepted = {}, {}
local chain = LevelGuideRoutes.chains[RACE]
if ORDER_ARG then
    local byZone = {}
    for _, r in ipairs(chain) do byZone[r.zone] = r end
    chain = {}
    for _, z in ipairs(ORDER_ARG) do chain[#chain + 1] = assert(byZone[z], z) end
end
local totalOut, totalGrind = 0, 0
for _, route in ipairs(chain) do
    for _, s in ipairs(route.steps) do
        if s.t == "accept" then everAccepted[s.q .. "#" .. (s.part or 1)] = true end
    end
end
local done, stats = {}, {}
for _, route in ipairs(chain) do
    done[route] = {}
    stats[route] = { turnins = 0, outleveled = 0, stalls = {}, total = 0 }
    for _, s in ipairs(route.steps) do
        if s.t == "turnin" then stats[route].total = stats[route].total + 1 end
    end
end
local function Key(s) return s.q and (s.q .. "#" .. (s.part or 1)) end
local function NeedLevel(s)
    local need = LevelGuidePrereqs[s.q]
    return math.max(need and need.level or 0, (s.lvl or 0) - (SLACK_ARG or 1))
end
-- Mark what the level makes done (outleveled); report whether something is doable now and the lowest
-- level a pending pick-up waits for.
local function Scan(route)
    local work, minBlocked = false, nil
    for i, s in ipairs(route.steps) do
        if not done[route][i] then
            local key = Key(s)
            if s.lvl and level >= s.lvl + OUTLEVELED then
                done[route][i] = true
                if s.t == "turnin" then stats[route].outleveled = stats[route].outleveled + 1 end
            elseif s.t == "accept" then
                if level >= NeedLevel(s) then work = true else minBlocked = math.min(minBlocked or 99, NeedLevel(s)) end
            elseif s.t == "turnin" then
                if held[key] or not everAccepted[key] then work = true end
            end
        end
    end
    return work, minBlocked
end
local function Unfinished(route)
    local work, blocked = Scan(route)
    return work or blocked ~= nil
end
-- One pass over the route in written order, doing what can be done.
local function Pass(route)
    local st = stats[route]
    for i, s in ipairs(route.steps) do
        if level > route.max then return end
        if not done[route][i] then
            local key = Key(s)
            if s.lvl and level >= s.lvl + OUTLEVELED then
                done[route][i] = true
                if s.t == "turnin" then st.outleveled = st.outleveled + 1 end
            elseif s.t == "accept" then
                if level >= NeedLevel(s) then held[key] = true; done[route][i] = true end
            elseif s.t == "turnin" then
                if held[key] or not everAccepted[key] then
                    Gain(FullXP(s.lvl or level) * Factor(level - (s.lvl or level)) * (1 + KILLS))
                    st.turnins = st.turnins + 1
                    held[key] = nil
                    done[route][i] = true
                end
            else
                done[route][i] = true
            end
        end
    end
end
local function InWindow(route, low) return level <= route.max and level >= route.min - (low or 0) end
local current
local order = {}
for _ = 1, 2000 do
    if level >= 60 then break end
    local pick
    -- 1. the zone you're in, if its level fits and it has something
    if current and InWindow(current) then
        local work, blocked = Scan(current)
        if work or (MODE == "old" and blocked) then pick = current end
        -- stay and grind when the next pick-up here is close
        if not pick and blocked and STAY_ARG and blocked - Lvl() <= STAY_ARG then pick = current end
    end
    -- 2. (new) first zone in the chain with something doable now
    if not pick and MODE == "new" then
        for _, route in ipairs(chain) do
            if InWindow(route, 2) and (Scan(route)) then pick = route break end
        end
    end
    -- 2b. (ahead) zones after the current one first, then the ones before
    if not pick and MODE == "ahead" then
        local start = 1
        for i, r in ipairs(chain) do if r == current then start = i end end
        for n = 0, #chain - 1 do
            local route = chain[(start - 1 + n) % #chain + 1]
            if InWindow(route, 2) and (Scan(route)) then pick = route break end
        end
    end
    -- 3. first unfinished zone in the chain (pending pick-ups count)
    if not pick then
        for _, route in ipairs(chain) do
            if InWindow(route, 2) and Unfinished(route) then pick = route break end
        end
    end
    if not pick then
        -- nothing in the level window at all: a gap. Grind one level where you are.
        local from = Lvl()
        Gain(TO_LEVEL[level] - xp)
        order[#order + 1] = string.format("  GAP at %.1f: no route in window, ground to %d", from, level)
    else
        if pick ~= current then
            stats[pick].arrive = stats[pick].arrive or Lvl()
            order[#order + 1] = string.format("  %.1f -> %s", Lvl(), pick.zone)
            current = pick
        end
        local work, blocked = Scan(pick)
        if work then
            Pass(pick)
        else
            local from = Lvl()
            if blocked and blocked <= pick.max + 1 then
                while level < blocked do Gain(TO_LEVEL[level] - xp) end
            else
                Gain(TO_LEVEL[level] - xp)
            end
            stats[pick].stalls[#stats[pick].stalls + 1] = string.format("%.1f->%d", from, level); totalGrind = totalGrind + (Lvl() - from)
        end
        stats[pick].leave = Lvl()
    end
end
print(string.format("mode=%s kills=%.2f race=%s", MODE, KILLS, RACE))
for _, line in ipairs(order) do print(line) end
print(string.format("%-22s %7s %6s %6s %7s %6s  %s", "zone", "min-max", "arrive", "leave", "turnins", "outlvl", "stalls (grind)"))
for _, route in ipairs(chain) do
    local st = stats[route]
    print(string.format("%-22s %3d-%-3d %6s %6s %3d/%-3d %6d  %s", route.zone, route.min, route.max,
        st.arrive and string.format("%.1f", st.arrive) or "-", st.leave and string.format("%.1f", st.leave) or "-",
        st.turnins, st.total, st.outleveled, table.concat(st.stalls, " ")))
end
local o = 0 for _, r in ipairs(chain) do o = o + stats[r].outleveled end
print(string.format("final level %.1f, outleveled turn-ins %d, ground levels %.1f, zone switches %d", Lvl(), o, totalGrind, #order))
