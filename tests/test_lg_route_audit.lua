-- Step-by-step audit of the Night Elf route from level 1 to Hillsbrad (about 30), as a priest, against
-- QuestDB.lua (forever-db). It walks the chain in order, keeps a quest log and the XP the quests give
-- (QuestXP.lua and Planner.lua's formulas: quest rewards and the kills their objectives take, plus the route's
-- own "grind to" steps; no other kills, so it runs a little behind a real player), and checks:
--   every quest step names a quest a Night Elf priest can take; nothing is taken twice; work is only done on
--   quests in the log; pick-ups come after their QuestDB and Prereqs.lua prerequisites, at a step level at or
--   above QuestDB's minimum, and when the simulated character is within a level of that minimum; the log stays
--   under 20; what is left in the log at 30 is only the cross-zone hand-ins the route names.
-- And the 2026-11-11 fixes: the Darkshore escorts are handed in in Ashenvale, the Redridge trip takes only what
-- it hands in, Ashenvale and Wetlands are two passes of their own steps, Stonetalon starts at Windshear Crag.
-- ADDON_PATH = LevelGuide.
for _, file in ipairs({ "QuestIDs.lua", "Prereqs.lua", "QuestDB.lua", "QuestLookup.lua", "QuestRules.lua", "QuestXP.lua", "Planner.lua", "Routes.lua" }) do
    assert(loadfile(ADDON_PATH .. "/" .. file))("LevelGuide", {})
end
local F, P = LevelGuideQuestFacts, LevelGuidePlanner
local RACE, CLASS = "NightElf", "PRIEST"
local chain = LevelGuideRoutes.chains.NightElf
local handPrereqs = {}
for title, need in pairs(LevelGuidePrereqs) do handPrereqs[title] = need end

-- 1. The chain to 30: the legs in order, Ashenvale and Wetlands in two passes around Stonetalon and Duskwood.
local want = { "Teldrassil", "Darkshore", "Stormwind, Ironforge and Loch Modan", "Darkshore", "Stormwind and Redridge", "Darkshore",
    "Ashenvale", "Stonetalon Mountains", "Wetlands", "Duskwood", "Ashenvale, second visit", "Wetlands, second visit", "Hillsbrad Foothills" }
local routes = {}
for i, name in ipairs(want) do
    local r = chain[i]
    assert(r and (r.name or r.zone) == name, "chain " .. i .. ": " .. tostring(r and (r.name or r.zone)) .. ", want " .. name)
    routes[i] = r
end
local LAST = #want - 1   -- the audit runs to the end of Wetlands' second visit; Hillsbrad is 28-34
F.Fill(routes, RACE, CLASS)
local ids, renamed = LevelGuideQuestIDs.ids, LevelGuideQuestIDs.renamed

-- The two passes (and the Night Elf Duskwood) are the zone's own steps, some as copies that stay up longer
-- (outlevel): together they are the zone's route, less the pick-ups left out, each step once.
local function Zone(name)
    for race, list in pairs(LevelGuideRoutes.chains) do
        if race == "Human" then
            for _, r in ipairs(list) do
                if r.zone == name then return r end
            end
        end
    end
end
local function Sig(step)
    return table.concat({ step.t, tostring(step.q or step.text), tostring(step.part or 1), tostring(step.npc or step.note or ""),
        tostring(step.x), tostring(step.y), tostring(step.atLevel or "") }, "|")
end
for _, pair in ipairs({ { "Ashenvale", chain[7], chain[11], { ["Velinde Starsong"] = true, ["Seeking Caitlin"] = true } },
    { "Wetlands", chain[9], chain[12], {} }, { "Duskwood", chain[10], nil, { ["The Carevin Family"] = true } } }) do
    local whole, first, later, out = Zone(pair[1]), pair[2], pair[3], pair[4]
    assert(whole and whole ~= first and whole ~= later, pair[1] .. ": the other races' route")
    local seen = {}
    for _, part in ipairs({ first, later }) do
        for _, step in ipairs(part.steps) do
            seen[Sig(step)] = (seen[Sig(step)] or 0) + 1
        end
    end
    for _, step in ipairs(whole.steps) do
        local sig = Sig(step)
        assert((seen[sig] or 0) > 0 or out[step.q], pair[1] .. ": step missing for Night Elves: " .. sig)
        seen[sig] = (seen[sig] or 0) - 1
    end
    for sig, n in pairs(seen) do
        assert(n <= 0 or sig:find("^trainer|"), pair[1] .. ": a step the zone doesn't have, or twice: " .. sig)
    end
    if later then
        assert(first.max >= later.min - 1 and first.min <= later.min, pair[1] .. ": the passes' bands meet")
    end
end
-- Nothing in the other races' Ashenvale, Wetlands or Duskwood changed level-skipping (outlevel) for them.
for _, name in ipairs({ "Ashenvale", "Wetlands", "Duskwood" }) do
    for _, step in ipairs(Zone(name).steps) do
        assert(step.outlevel == nil, name .. ": the shared step " .. Sig(step) .. " has an outlevel")
    end
end
print("1 ok")

-- 2. Walk the route.
local function ForClass(step)
    local c = step.cls
    if not c then return true end
    if type(c) == "string" then return c == CLASS end
    for _, v in ipairs(c) do if v == CLASS then return true end end
    return false
end
local function IdOf(step)
    local list = ids[step.q] or ids[renamed[step.q] or step.q]
    return list and list[tonumber(step.part) or 1]
end
local p = { level = 1, xp = 0 }
local function Level() return p.level + p.xp / P.LEVEL_XP[p.level] end
local function Gain(n)
    p.xp = p.xp + n
    while p.xp >= P.LEVEL_XP[p.level] do
        p.xp = p.xp - P.LEVEL_XP[p.level]
        p.level = p.level + 1
    end
end
local state, killed, logMax, problems = {}, {}, 0, {}
local function Problem(...) problems[#problems + 1] = string.format(...) end
local function Count()
    local n = 0
    for _, s in pairs(state) do if s == "log" then n = n + 1 end end
    return n
end
-- Known and accepted: Crown of the Earth part 6 (935) lists 934 and 7383 (the old and new Amethyst Phial
-- quests); the route's part 5 is 7383 and the game offers one or the other.
local PRE_OK = { [935] = { [934] = true } }
-- Hand-ins of quests started off the route (Messenger to Darkshire is the Westfall chain's; Seeking Caitlin is
-- the other races' Ashenvale pick-up; The Carevin Family is the Moonbeam Wand chain's): the guide passes them.
local NOT_HELD_OK = { ["Messenger to Darkshire"] = true, ["Seeking Caitlin"] = true, ["The Carevin Family"] = true }
-- Pick-ups the route itself marks as waiting for 30, or optional starts of a level 35 chain.
local LEVEL_OK = { ["Fiora Longears"] = true, ["The Weathered Grave"] = true }

for ri = 1, LAST do
    local route = routes[ri]
    for si, step in ipairs(route.steps) do
        local where = string.format("%s #%d %s %s%s (sim %.1f)", route.name or route.zone, si, step.t, tostring(step.q or step.text),
            step.part and (" part " .. step.part) or "", Level())
        -- The guide passes a step this many levels below you (LevelGuide.lua K.OUTLEVELED = 4, or the step's
        -- outlevel), even a hand-in of a quest you hold: such a step is skipped here too.
        local passed = step.lvl and p.level >= step.lvl + (step.outlevel or 4)
        if not passed and ForClass(step) and step.q and (step.t == "accept" or step.t == "do" or step.t == "turnin") then
            local id = IdOf(step)
            local q = id and F.Quest(id)
            if not q then
                Problem("no quest ID: %s", where)
            elseif not F.Takes(q, RACE, CLASS) then
                Problem("not for a Night Elf priest (%d): %s", id, where)
            elseif step.t == "accept" then
                if state[id] then Problem("taken twice (%d): %s", id, where) end
                if q.min and step.lvl and step.lvl < q.min then Problem("step level %d under QuestDB's minimum %d: %s", step.lvl, q.min, where) end
                if q.min and Level() < q.min - 1 and not LEVEL_OK[step.q] then Problem("about %.1f, QuestDB minimum %d: %s", Level(), q.min, where) end
                local need = F.Prereqs(id, RACE, CLASS) or {}
                for _, pre in ipairs(need.all or {}) do
                    if state[pre] ~= "done" and not (PRE_OK[id] and PRE_OK[id][pre]) then
                        Problem("needs %d %s first (QuestDB): %s", pre, tostring(F.Title(pre)), where)
                    end
                end
                if need.any then
                    local ok = false
                    for _, pre in ipairs(need.any) do ok = ok or state[pre] == "done" end
                    if not ok then Problem("needs one of its QuestDB prerequisites first: %s", where) end
                end
                local hand = (tonumber(step.part) or 1) == 1 and (handPrereqs[step.q] or handPrereqs[renamed[step.q] or step.q])
                for _, pre in ipairs(hand and hand.all or {}) do
                    if state[pre] ~= "done" then Problem("needs %d %s first (Prereqs.lua): %s", pre, tostring(F.Title(pre)), where) end
                end
                state[id] = "log"
                logMax = math.max(logMax, Count())
                assert(logMax <= 20, "quest log over 20 at " .. where)
            elseif step.t == "do" then
                if state[id] ~= "log" then Problem("work on a quest not in the log (%d): %s", id, where) end
                if not killed[id] then
                    killed[id] = true
                    local _, kills = P.QuestXP(id)
                    for _, k in ipairs(kills) do
                        for _ = 1, k.n do Gain(P.MobXP(p.level, k.mob, k.elite)) end
                    end
                end
            else
                if state[id] ~= "log" and not NOT_HELD_OK[step.q] then Problem("hand-in of a quest not in the log (%d): %s", id, where) end
                if state[id] == "log" then
                    local xp = P.QuestXP(id)
                    if xp then Gain(math.floor(xp * P.Share(p.level, q.level) + 0.5)) end
                    state[id] = "done"
                end
            end
        elseif step.t == "xp" and step.level then
            -- The route's own "grind to" steps.
            local target = step.short and (step.level - 1) or step.level
            local into = step.short and (P.LEVEL_XP[step.level - 1] - step.short) or step.into or (step.frac or 0) * P.LEVEL_XP[step.level]
            if p.level < target or (p.level == target and p.xp < into) then
                p.level, p.xp = target, into
            end
        end
    end
end
assert(#problems == 0, "route problems:\n" .. table.concat(problems, "\n"))
print(string.format("2 ok: about level %.1f before Hillsbrad, at most %d quests in the log", Level(), logMax))

-- 3. What's left in the log at 30: only the cross-zone hand-ins the Wetlands route names (Stormwind, Theramore).
local OPEN_OK = { ["Cleansing the Eye"] = true, ["A Friend of the Family"] = true, ["Fiora Longears"] = true }
for id, s in pairs(state) do
    if s == "log" then
        assert(OPEN_OK[F.Title(id)], "left in the log at 30: " .. id .. " " .. tostring(F.Title(id)))
    end
end
assert(Level() >= 28.5 and Level() < 31.5, "about 30 before Hillsbrad: " .. Level())
print("3 ok")

-- 4. The fixes, one by one.
local function Find(route, t, q, part)
    for i, step in ipairs(route.steps) do
        if step.t == t and step.q == q and (part == nil or (tonumber(step.part) or 1) == part) then return i, step end
    end
end
-- Priests take In Favor of Elune from Shanda at 5 (QuestDB minimum), on the level 5 visit to Aldrassil.
local fav = Find(chain[1], "accept", "In Favor of Elune")
assert(fav and fav > Find(chain[1], "turnin", "Fang of Githyiss"), "In Favor of Elune on the level 5 visit")
-- The Darkshore escorts are handed in in Ashenvale (Onaeya at Maestra's Post, Therysil at the Shrine of Aessina).
local _, onaeya = Find(chain[7], "turnin", "One Shot. One Kill.")
local _, therysil = Find(chain[7], "turnin", "Therylune's Escape")
assert(onaeya and onaeya.npc:find("Onaeya", 1, true) and therysil and therysil.npc:find("Therysil", 1, true), "Darkshore escorts handed in")
-- The Redridge trip takes nothing it doesn't hand in.
for _, title in ipairs({ "Solomon's Law", "An Unwelcome Guest", "The Everstill Bridge" }) do
    assert(not Find(chain[5], "accept", title), "Redridge trip leaves " .. title .. " for later")
end
-- Stonetalon: in through the Talondeep Path, Windshear Crag first, On Guard part 1 from Astranaar.
local ston = chain[8]
local onGuard = Find(ston, "accept", "On Guard in Stonetalon", 1)
local tunnel
for i, step in ipairs(ston.steps) do if step.t == "zone" and step.reach == "Stonetalon Mountains" then tunnel = i end end
assert(onGuard and tunnel and onGuard < tunnel and tunnel < Find(ston, "turnin", "On Guard in Stonetalon", 1), "On Guard part 1 then the tunnel")
assert(Find(ston, "turnin", "A Gnome's Respite") < Find(ston, "turnin", "Journey to Stonetalon Peak"), "Windshear before the Peak")
assert(not Find(ston, "accept", "Reclaiming the Charred Vale", 2), "no pick-up that ends in Thalanaar")
-- Wetlands: Report to Captain Stoutfist (needs The Algaz Gauntlet) is gone, and War Banners doesn't wait for it.
assert(not Find(chain[9], "accept", "Report to Captain Stoutfist"), "no Report to Captain Stoutfist")
assert(not (handPrereqs["War Banners"] and handPrereqs["War Banners"].all), "War Banners needs no breadcrumb")
-- Breadcrumbs (QuestDB A/Y prerequisites) are never required by Prereqs.lua for the route's quests.
for ri = 1, #routes do
    for _, step in ipairs(routes[ri].steps) do
        local hand = step.t == "accept" and handPrereqs[step.q]
        local id = hand and IdOf(step)
        local q = id and F.Quest(id)
        for _, crumb in ipairs(q and q.crumbs or {}) do
            for _, pre in ipairs(hand.all or {}) do
                assert(pre ~= crumb, step.q .. " requires its breadcrumb " .. crumb)
            end
        end
    end
end
-- Hillsbrad: An Alarming Request is handed in before Friend of the Kirin Tor, which waits for it.
local hill = chain[13]
assert(Find(hill, "turnin", "An Alarming Request") < Find(hill, "accept", "Friend of the Kirin Tor"), "An Alarming Request handed in first")
print("ALL TESTS PASSED")
