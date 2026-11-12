-- Round 6 #1: Legacy lists the unfinished Legacy challenges (achievements that pay Legacy points), with their
-- points and progress, a "this zone" section and side-panel line, finished ones on their own view, and the
-- points to spend. It reads only; it hides with the hub's Off switch; missing or secret APIs only shorten it.
-- Run from the harness folder:  node run.js "<workspace root>" test_r6_legacy.lua
local failures = {}
local function check(cond, why) if not cond then failures[#failures + 1] = why end end
local SECRET = {}

-- A fresh game for each load; `opts` removes or changes parts of it.
local function Load(opts)
    opts = opts or {}
    local out, frames, forbidden, written, registered = {}, {}, {}, {}, {}
    local G = {}
    G.issecretvalue = function(v) return v == SECRET end
    G.ForeverHub_Receive = function(_, t) out[#out + 1] = t end
    local hubOff = {}
    G.ForeverHub_IsOff = function(name) return hubOff[name] == true end
    for _, name in ipairs({ "hooksecurefunc", "print", "ToggleLegacySystemUI", "AchievementFrame_SelectAchievement",
        "SetAchievementSearchString", "AddTrackedAchievement" }) do
        G[name] = function() forbidden[#forbidden + 1] = name end
    end
    G.CreateFrame = function()
        local f = {}
        f.RegisterEvent = function(_, e) registered[e] = true end
        f.UnregisterAllEvents = function() for k in pairs(registered) do registered[k] = nil end end
        f.SetScript = function(self, _, fn) self.fn = fn end
        frames[#frames + 1] = f
        return f
    end
    G.SlashCmdList = {}
    local clock = 100
    G.GetTime = function() return clock end
    G.InCombatLockdown = function() return opts.combat == true end
    G.UnitClass = function() return "Priest", "PRIEST", 5 end
    G.C_Map = {
        GetBestMapForUnit = function() return 1439 end,
        GetMapInfo = function() return { name = opts.zone or "Darkshore" } end,
    }
    if not opts.noConstants then
        G.Constants = { LegacyConsts = { LEGACY_POINTS_TRAIT_CURRENCY_ID = 4225, LEGACY_DEFAULT_CATEGORY_PRIEST = 15581,
            LEGACY_DEFAULT_CATEGORY_WARRIOR = 15585, LEGACY_TREE_PROFESSIONS_ID = 1187, LEGACY_TREE_ADVENTURE_ID = 1188,
            LEGACY_TREE_PROGRESSION_ID = 1189 } }
    end
    -- Categories: 15000 "Legacy" (top), 15581 Priest, 15585 Warrior, 15600 Exploration, 15601 Dungeons,
    -- 92 "General" (an ordinary top category, never read).
    local cats = {
        [92] = { "General", -1 }, [15000] = { "Legacy", -1 }, [15581] = { "Priest", 15000 },
        [15585] = { "Warrior", 15000 }, [15600] = { "Exploration", 15000 }, [15601] = { "Dungeons", 15000 },
    }
    -- Achievements: id, name, completed, description, points, criteria { text, done, qty, req }
    local ach = {
        [15581] = { { 9001, "Priest: Level 25", false, "Reach level 25 as a Priest.", 1, { { "Level 25", false, 11, 25 } } } },
        [15585] = { { 9101, "Warrior: Level 25", false, "Reach level 25 as a Warrior.", 1, { { "Level 25", false, 0, 25 } } } },
        [15600] = {
            { 9201, "Explore Darkshore", false, "Explore Darkshore.", 1, { { "Auberdine", true }, { "Bashal'Aran", true },
                { "Ameth'Aran", false }, { "Grove of the Ancients", false }, { "Cliffspring River", true } } },
            { 9202, "Explore Teldrassil", true, "Explore Teldrassil.", 1, {} },
            { 9203, "Explore Ashenvale", false, "Explore Ashenvale.", 2, { { "Astranaar", false }, { "Raynewood", false } } },
        },
        [15601] = {
            { 9301, "Dungeon: The Deadmines", false, "Defeat Van Cleef.", 3, {} },
            { 9302, "Darkshore's Secret", false, "A secret in Darkshore.", nil, {} },  -- no points: not a challenge
        },
        [92] = { { 1, "Level 10", false, "Reach level 10.", nil, { { "Level", false, 11, 10 } } } },
    }
    local byID = {}
    for _, list in pairs(ach) do for _, a in ipairs(list) do byID[a[1]] = a end end
    if not opts.noCategoryList then
        G.GetCategoryList = function() return { 92, 15000, 15581, 15585, 15600, 15601 } end
    end
    G.GetCategoryInfo = function(id) local c = cats[id]; if c then return c[1], c[2], 0 end end
    G.GetCategoryNumAchievements = function(id) return #(ach[id] or {}), 0, 0 end
    G.GetAchievementInfo = function(cat, i)
        local a = ach[cat] and ach[cat][i]
        if a then
            local name = opts.secretNames and SECRET or a[2]
            return a[1], name, 10, a[3], 1, 1, 26, a[4], 0, 0, "", false, a[3], ""
        end
    end
    G.GetAchievementNumCriteria = function(id) return #byID[id][6] end
    G.GetAchievementCriteriaInfo = function(id, i)
        local c = byID[id][6][i]
        if opts.secretCriteria then return SECRET, 0, SECRET, SECRET, SECRET end
        return c[1], 0, c[2], c[3] or (c[2] and 1 or 0), c[4] or 1
    end
    G.C_Traits = {
        GetConfigIDByTreeID = function(tree) return 700 end,
        GetTreeCurrencyInfo = function(config, tree)
            return { { traitCurrencyID = 4225, quantity = 2, spent = 5, spentInTree = tree == 1188 and 3 or (tree == 1189 and 2 or 0) } }
        end,
    }
    if not opts.noPoints then
        G.C_Traits.GetTraitCurrencyForAchievement = function(currency, id)
            assert(currency == 4225, "points asked in the Legacy currency")
            local a = byID[id]
            return a and a[5] or 0
        end
    end
    if opts.drop then for _, name in ipairs(opts.drop) do G[name] = nil end end
    setmetatable(G, { __index = _G, __newindex = function(t, k, v) written[#written + 1] = k; rawset(t, k, v) end })
    local chunk = assert(loadfile(ADDON_PATH .. "/Legacy/Legacy.lua", "t", G))
    chunk("Legacy", {})
    local env = {
        G = G, frames = frames, forbidden = forbidden, written = written, registered = registered, hubOff = hubOff,
        fire = function(e, ...) local f = frames[#frames]; f.fn(f, e, ...) end,
        page = function(arg) for k in pairs(out) do out[k] = nil end; G.SlashCmdList.LEGACYPOINTS(arg or ""); return table.concat(out, "\n") end,
        tick = function(s) clock = clock + s end,
        ach = ach,
    }
    return env
end

----- The page: unfinished challenges with progress and points
local e = Load()
local text = e.page()
check(text:find("Legacy points|r: 2 to spend, 5 spent", 1, true), "points summary (spentInTree summed):\n" .. text)
check(text:find("4 unfinished challenges, worth 7 more points. 1 finished.", 1, true), "counts and pending points:\n" .. text)
check(text:find("Priest: Level 25: 11/25", 1, true), "single counter progress:\n" .. text)
check(text:find("Explore Darkshore: 3/5 |cff999999(left: Ameth'Aran, Grove of the Ancients)|r, |cff66ccff+1 point|r", 1, true),
    "criteria progress with what's left:\n" .. text)
check(text:find("Dungeon: The Deadmines |cff999999- Defeat Van Cleef.|r, |cff66ccff+3 points|r", 1, true),
    "no criteria: description and points:\n" .. text)
check(text:find("|cffffd100Exploration|r", 1, true) and text:find("|cffffd100Dungeons|r", 1, true), "grouped by category:\n" .. text)
check(text:find("|cffffd100In Darkshore|r", 1, true), "this-zone section:\n" .. text)
check(not text:find("Warrior: Level 25", 1, true), "other classes' challenges left out")
check(text:find("Not shown: 1 challenge for other classes", 1, true), "and counted:\n" .. text)
check(not text:find("Darkshore's Secret", 1, true), "achievements paying no points aren't challenges")
check(not text:find("Level 10", 1, true), "ordinary categories aren't read")
check(not text:find("Explore Teldrassil", 1, true), "finished ones aren't on the main view")
-- Sorted closest-to-done first inside a group: Darkshore (3/5) before Ashenvale (0/2).
check(text:find("Explore Darkshore: 3/5", 1, true) < (text:find("Explore Ashenvale: 0/2", 1, true) or 0), "sorted by progress")

local done = e.page("done")
check(done:find("Finished Legacy challenges|r: 1, 1 point", 1, true) and done:find("Explore Teldrassil", 1, true), "done view:\n" .. done)
local zone = e.page("zone")
check(zone:find("In Darkshore", 1, true) and zone:find("Explore Darkshore", 1, true) and not zone:find("Ashenvale", 1, true),
    "zone view:\n" .. zone)

----- Side panel: the closest challenge in this zone
local lines = e.G.ForeverHubStatus.Legacy()
check(lines and lines[1] and lines[1].text == "|cffffd100Legacy|r Explore Darkshore 3/5, +1 point" and lines[1].page == "Legacy",
    "side panel line: " .. tostring(lines and lines[1] and lines[1].text))

----- Updates: events only mark it stale; the next page read picks up the change
check(e.registered.CRITERIA_UPDATE and e.registered.ACHIEVEMENT_EARNED and e.registered.MAP_EXPLORATION_UPDATED,
    "update events registered")
e.ach[15600][1][6][3][2] = true
e.fire("CRITERIA_UPDATE")
check(e.page():find("Explore Darkshore: 4/5", 1, true), "progress refreshed after CRITERIA_UPDATE")
-- The side panel rebuilds at most every 10 s.
e.ach[15600][1][6][4][2] = true
e.fire("CRITERIA_UPDATE")
check(e.G.ForeverHubStatus.Legacy()[1].text:find("4/5", 1, true), "side panel throttled")
e.tick(11)
check(e.G.ForeverHubStatus.Legacy()[1].text:find("5/5", 1, true), "side panel rebuilt after the throttle")

----- Elsewhere: no zone line
local away = Load({ zone = "Elwynn Forest" })
check(away.G.ForeverHubStatus.Legacy() == nil, "no side panel line away from challenge zones")
check(not away.page():find("|cffffd100In ", 1, true), "no zone section away")

----- Off: page and side panel are empty, events stop; On again restores them
e.hubOff.Legacy = true
e.G.ForeverHubOnSwitch.Legacy(true)
check(e.page() == "", "page empty while Off")
check(e.G.ForeverHubStatus.Legacy() == nil, "no side panel line while Off")
check(not e.registered.CRITERIA_UPDATE, "events unregistered while Off")
e.hubOff.Legacy = nil
e.G.ForeverHubOnSwitch.Legacy(false)
check(e.registered.CRITERIA_UPDATE and e.page():find("Explore Darkshore", 1, true), "back On")
-- Off already at login.
local offAtLogin = Load()
offAtLogin.hubOff.Legacy = true
offAtLogin.fire("PLAYER_LOGIN")
check(not offAtLogin.registered.CRITERIA_UPDATE, "Off at login: no event work")

----- Combat: nothing is read; the page says progress comes after the fight
local fight = Load({ combat = true })
local ft = fight.page()
check(ft:find("refreshes after combat", 1, true), "combat note:\n" .. ft)

----- Secrets: secret criteria and names are skipped, never compared
local s1 = Load({ secretCriteria = true })
local st = s1.page()
check(st:find("Explore Darkshore |cff999999- Explore Darkshore.|r", 1, true), "secret criteria: falls back to the description:\n" .. st)
local s2 = Load({ secretNames = true })
check(s2.page():find("No Legacy challenges found", 1, true), "secret names: nothing listed, no error")

----- Missing APIs
local np = Load({ noPoints = true })
local npt = np.page()
check(npt:find("doesn't say what each pays", 1, true) and npt:find("Explore Darkshore", 1, true)
    and npt:find("Darkshore's Secret", 1, true), "no points call: the Legacy categories are trusted:\n" .. npt)
check(not npt:find("Level 10", 1, true), "but nothing outside them")
local nc = Load({ noCategoryList = true })
local nct = nc.page()
check(nct:find("Priest: Level 25", 1, true), "no category list: the class category is still read:\n" .. nct)
local nk = Load({ noConstants = true })
check(nk.page():find("Explore Darkshore", 1, true), "built-in constants used without Constants.LegacyConsts")
local none = Load({ drop = { "GetCategoryList", "GetCategoryInfo", "GetCategoryNumAchievements", "GetAchievementInfo",
    "GetAchievementNumCriteria", "GetAchievementCriteriaInfo", "C_Traits", "C_Map" } })
check(none.page():find("No Legacy challenges found", 1, true), "no achievement API at all: an empty page, no error")
check(none.G.ForeverHubStatus.Legacy() == nil, "and no side panel line")

----- Rules: no chat, no Blizzard calls, globals in our own names, no forbidden events
for _, env in ipairs({ e, away, fight, s1, s2, np, nc, nk, none }) do
    check(#env.forbidden == 0, "forbidden call: " .. table.concat(env.forbidden, ", "))
    for _, name in ipairs(env.written) do
        check(name == "SLASH_LEGACYPOINTS1" or name:sub(1, 7) == "Forever" or name:sub(1, 6) == "Legacy",
            "global written outside Legacy's names: " .. name)
    end
    for name in pairs(env.registered) do
        check(not name:find("^COMBAT_LOG") and name ~= "MINIMAP_PING" and name ~= "ENCOUNTER_STATE_CHANGED",
            "forbidden event: " .. name)
    end
end
-- fengari has no io.open: the compiled chunk's string constants stand in for a source scan.
local dumped = string.dump(assert(loadfile(ADDON_PATH .. "/Legacy/Legacy.lua")))
for _, name in ipairs({ "COMBAT_LOG", "hooksecurefunc", "AddDataProvider", "AcquirePin", "DEFAULT_CHAT_FRAME", "SetCVar" }) do
    check(not dumped:find(name, 1, true), "Legacy names " .. name)
end

if #failures > 0 then
    error("FAILURES (" .. #failures .. "):\n" .. table.concat(failures, "\n"))
end
print("ALL TESTS PASSED")
