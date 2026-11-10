-- LevelGuide quest rules (research\re_round3.md rank 2; our own code): which quests the route must not send you
-- for because another one shuts them out. Pure functions over quest IDs; the caller says what is done and what
-- is in the log. Nothing here talks to the game.
--
--   exclusive groups: once one quest of a group is done or in your log, the others are never offered;
--   next in chain:    a quest whose follow-up is done or in your log is behind you;
--   disabled by:      a quest is not offered while another one is in your log;
--   removed:          quests the game no longer offers;
--   breadcrumbs:      a quest that only leads to another (QuestDB's capital A/Y prerequisites, from forever-db).
--                     The breadcrumb is dropped once its target is done or in your log, and the target's pick-up
--                     waits while the breadcrumb is in your log (turn it in first; never abandon it).
--   In an "all" prerequisite list, a quest counts as done when one of its exclusive partners is done.
--
-- Data: only entries we checked ourselves go in the tables below (research\review3_levelguide.md lists the
-- candidates tools\audit_questie.js found and how each was checked). QuestieDB is never shipped.
local R = {
    exclusive = {
        -- { questID, questID, ... },
    },
    next = {
        -- [questID] = follow-up questID,
    },
    disabledBy = {
        -- [questID] = questID that blocks it while in the log,
    },
    removed = {
        -- [questID] = true,
    },
}
LevelGuideQuestRules = R

local partners, crumbTargets

-- Exclusive groups worked out from QuestDB (forever-db) itself: when a quest takes "one of" several earlier
-- quests that all have the same title, level and race/class masks (the same quest offered at several places,
-- e.g. Forever's "The Great Outdoors" at each starting zone's camp), those are one quest: once you've done or
-- taken one, the others are not for you.
function R.DerivedGroups()
    local db = LevelGuideQuestDB
    local q = type(db) == "table" and type(db.q) == "table" and db.q or {}
    -- Title and level, and the race and class masks (0 = everyone); repeatable quests are never one of these.
    local function Parts(id)
        local record = q[id]
        if type(record) ~= "string" then
            return nil
        end
        local level, _, races, classes, flags, title =
            record:match("^([^|]*)|([^|]*)|([^|]*)|([^|]*)|[^|]*|[^|]*|[^|]*|([^|]*)|[^|]*|(.*)$")
        if not title or flags:find("R", 1, true) then
            return nil
        end
        return title .. "|" .. level, tonumber(races) or 0, tonumber(classes) or 0
    end
    local function Overlap(a, b)
        if a == 0 or b == 0 or a == b then
            return true
        end
        local low = function(v) return v % 4294967296 end
        for bit = 0, 31 do
            local p = 2 ^ bit
            if math.floor(low(a) / p) % 2 == 1 and math.floor(low(b) / p) % 2 == 1 then
                return true
            end
        end
        return a >= 4294967296 and b >= 4294967296
    end
    local groups, seen = {}, {}
    for _, record in pairs(q) do
        local pre = type(record) == "string" and record:match("^[^|]*|[^|]*|[^|]*|[^|]*|[^|]*|[^|]*|([^|]*)|")
        if pre and pre:find("y%d+,y%d+") then
            local ids, key, races, classes, same = {}, nil, nil, nil, true
            for id in pre:gmatch("y(%d+)") do
                id = tonumber(id)
                local k, r, c = Parts(id)
                if key == nil then
                    key, races, classes = k, r, c
                end
                same = same and k ~= nil and k == key and Overlap(r, races) and Overlap(c, classes)
                ids[#ids + 1] = id
            end
            table.sort(ids)
            local sig = table.concat(ids, ",")
            if same and #ids > 1 and not seen[sig] then
                seen[sig] = true
                groups[#groups + 1] = ids
            end
        end
    end
    return groups
end

-- questID -> { other IDs of its exclusive groups } (the written groups and the derived ones).
function R.Partners(id)
    if not partners then
        partners = {}
        local all = {}
        for _, group in ipairs(R.exclusive) do
            all[#all + 1] = group
        end
        for _, group in ipairs(R.DerivedGroups()) do
            all[#all + 1] = group
        end
        for _, group in ipairs(all) do
            for _, a in ipairs(group) do
                for _, b in ipairs(group) do
                    if a ~= b then
                        partners[a] = partners[a] or {}
                        table.insert(partners[a], b)
                    end
                end
            end
        end
    end
    return partners[id] or {}
end

-- Breadcrumb ID -> { target IDs }, from QuestDB's records (the prerequisite field, capital letters).
function R.CrumbTargets(id)
    if not crumbTargets then
        crumbTargets = {}
        local db = LevelGuideQuestDB
        for target, record in pairs(type(db) == "table" and type(db.q) == "table" and db.q or {}) do
            local pre = type(record) == "string" and record:match("^[^|]*|[^|]*|[^|]*|[^|]*|[^|]*|[^|]*|([^|]*)|")
            for crumb in (pre or ""):gmatch("[AY](%d+)") do
                crumb = tonumber(crumb)
                crumbTargets[crumb] = crumbTargets[crumb] or {}
                table.insert(crumbTargets[crumb], target)
            end
        end
    end
    return crumbTargets[id] or {}
end

-- The breadcrumbs that lead to a quest (QuestDB), or {}.
function R.Crumbs(id)
    local facts = LevelGuideQuestFacts
    local q = id and facts and facts.Quest and facts.Quest(id)
    return q and q.crumbs or {}
end

-- Why a pick-up is shut out for good (or for as long as the log holds what blocks it), or nil.
-- done(id) and inLog(id) answer for this character.
function R.Hidden(id, done, inLog)
    if not id then
        return nil
    end
    if R.removed[id] then
        return "removed"
    end
    for _, other in ipairs(R.Partners(id)) do
        if done(other) or inLog(other) then
            return "exclusive", other
        end
    end
    local follow = R.next[id]
    if follow and (done(follow) or inLog(follow)) then
        return "next", follow
    end
    local blocker = R.disabledBy[id]
    if blocker and inLog(blocker) then
        return "disabled", blocker
    end
    for _, target in ipairs(R.CrumbTargets(id)) do
        if done(target) or inLog(target) then
            return "breadcrumb", target
        end
    end
    return nil
end

-- A breadcrumb to this quest that's in your log: its pick-up waits until you turn that in.
function R.WaitsForCrumb(id, inLog)
    for _, crumb in ipairs(R.Crumbs(id)) do
        if inLog(crumb) then
            return crumb
        end
    end
    return nil
end

-- Done, or one of its exclusive partners done (for "all" prerequisite lists).
function R.DoneOrPartner(id, done)
    if done(id) then
        return true
    end
    for _, other in ipairs(R.Partners(id)) do
        if done(other) then
            return true
        end
    end
    return false
end

-- For generated routes (QuestLookup.BuildRoute): of each exclusive group in a pool, only the lowest ID stays;
-- removed quests go. pool = { [id] = anything }; changed in place.
function R.Prune(pool)
    for id in pairs(R.removed) do
        pool[id] = nil
    end
    for _, group in ipairs(R.exclusive) do
        local keep
        for _, id in ipairs(group) do
            if pool[id] and (not keep or id < keep) then
                keep = id
            end
        end
        for _, id in ipairs(group) do
            if id ~= keep then
                pool[id] = nil
            end
        end
    end
end

-- Tests replace the tables; this forgets what was worked out from them.
function R.Reset()
    partners, crumbTargets = nil, nil
end

return R
