-- DeathNotes + C_DeathRecap: the recap's killer and last hits replace the target guess; secret
-- fields are left out; an empty or missing recap keeps today's behaviour; the same recap is not
-- applied to a second death; the page asks again; no combat log or recap event is registered.
-- Run from the harness folder:  node run.js "<workspace root>" test_r5c_deathrecap.lua
local base = ADDON_PATH
local failures = {}
local SECRET = setmetatable({}, {
    __eq = function() error("compared a secret") end, __lt = function() error("compared a secret") end,
    __le = function() error("compared a secret") end, __concat = function() error("joined a secret") end,
    __add = function() error("arithmetic on a secret") end, __sub = function() error("arithmetic on a secret") end,
})
local function check(cond, why) if not cond then failures[#failures + 1] = why end end

local function Setup(recapApi, withAfter)
    local env = { out = {}, frames = {}, timers = {}, foe = nil, gametime = 1000, clock = 50000 }
    ForeverHub_Receive = function(_, t) env.out[#env.out + 1] = t end
    issecretvalue = function(v) return rawequal(v, SECRET) end
    CreateFrame = function()
        local f = { registered = {} }
        f.RegisterEvent = function(self, e) self.registered[e] = true end
        f.SetScript = function(self, _, fn) self.fn = fn end
        env.frames[#env.frames + 1] = f
        return f
    end
    SlashCmdList = {}
    UnitName = function(unit) if unit == "player" then return "Juan" elseif unit == "target" then return env.foe end end
    UnitGUID = function() return "Player-1-ABC" end
    UnitLevel = function() return 12 end
    UnitIsDeadOrGhost = function() return false end
    UnitExists = function(u) return u == "target" and env.foe ~= nil end
    UnitCanAttack = function() return true end
    GetRealmName = function() return "R" end
    time = function() return env.clock end
    GetTime = function() return env.gametime end
    GetZoneText = function() return "Elwynn Forest" end
    GetSubZoneText = function() return "Goldshire" end
    geterrorhandler = function() return function(e) failures[#failures + 1] = "error handler: " .. tostring(e) end end
    C_Timer = { NewTicker = function() end }
    if withAfter then
        C_Timer.After = function(s, fn) env.timers[#env.timers + 1] = { s = s, fn = fn } end
    end
    C_Map = { GetBestMapForUnit = function() return 37 end, GetPlayerMapPosition = function() return nil end }
    C_DeathRecap = recapApi
    DeathNotesDB = nil
    ForeverHubStatus, ForeverHubOptions = nil, nil
    assert(loadfile(base .. "/DeathNotes/DeathNotes.lua"))("DeathNotes", {})
    env.f = env.frames[#env.frames]
    for _, f in ipairs(env.frames) do
        for ev in pairs(f.registered) do
            check(not ev:find("^COMBAT_LOG") and not ev:find("DEATH_RECAP"), "registers no combat log or recap event: " .. ev)
        end
    end
    env.fire = function(ev) env.clock = env.clock + 1; env.gametime = env.gametime + 1; env.f.fn(env.f, ev) end
    env.runTimers = function()
        local list = env.timers
        env.timers = {}
        for _, t in ipairs(list) do
            local ok, err = pcall(t.fn)
            if not ok then failures[#failures + 1] = "timer error: " .. tostring(err) end
        end
    end
    env.has = function(text) for _, t in ipairs(env.out) do if t:find(text, 1, true) then return true end end return false end
    env.page = function(arg)
        env.out = {}
        local ok, err = pcall(SlashCmdList.DEATHNOTES, arg or "")
        if not ok then env.out[#env.out + 1] = "<<ERROR: " .. tostring(err) .. ">>" end
    end
    env.deaths = function() return DeathNotesDB.R.deaths end
    env.fire("PLAYER_LOGIN")
    return env
end

-- 1. No C_DeathRecap: exactly as before (target guess, no timers, no hits line).
do
    local e = Setup(nil, true)
    e.foe = "Young Wolf"
    e.fire("PLAYER_DEAD")
    check(e.has("Noted: died at level 12 in Goldshire, Elwynn Forest to Young Wolf."), "no API: target guess noted")
    check(#e.timers == 0, "no API: no recap timers")
    local d = e.deaths()[1]
    check(d.killer == "Young Wolf" and d.hits == nil and d.recap == nil, "no API: death saved as before")
    e.page()
    check(not e.has("Last hits"), "no API: no hits line")
end

-- 2. The recap names the real killer and the last hits (killing blow = newest timestamp).
local recap = {}
local api = {
    HasRecapEvents = function() return #recap > 0 end,
    GetRecapEvents = function() return recap end,
}
do
    local e = Setup(api, true)
    e.foe = "Young Wolf"   -- the guess: you were targeting a wolf
    recap = {
        { timestamp = 100.5, sourceName = "Kobold Miner", spellName = "Strike", spellId = 1, amount = 41, event = "SPELL_DAMAGE" },
        { timestamp = 99.0, sourceName = "Kobold Miner", spellId = 88163, amount = 38, event = "SWING_DAMAGE" },
        { timestamp = 98.0, sourceName = "Kobold Laborer", amount = 12, event = "SWING_DAMAGE" },
    }
    e.out = {}
    e.fire("PLAYER_DEAD")
    check(e.has("to Young Wolf"), "the guess is noted at once")
    check(#e.timers == 2 and e.timers[1].s == 1 and e.timers[2].s == 3, "recap read 1 s and 3 s after death")
    e.runTimers()
    local d = e.deaths()[1]
    check(d.killer == "Kobold Miner", "recap killer replaces the guess, got " .. tostring(d.killer))
    check(d.guess == "Young Wolf", "the guess is kept aside")
    check(d.blow == "Kobold Miner (Strike 41)", "killing blow text, got " .. tostring(d.blow))
    check(#d.hits == 3 and d.hits[3].spell == "Strike" and d.hits[2].spell == "Melee" and d.hits[1].source == "Kobold Laborer",
        "hits saved oldest first, swing shown as Melee")
    check(e.has("Death recap: killed by Kobold Miner, last hit Kobold Miner (Strike 41)."), "recap result shown in the hub")
    e.page()
    check(e.has("killed by Kobold Miner"), "page names the recap killer")
    check(e.has("Last hits: Kobold Laborer (Melee 12), Kobold Miner (Melee 38), Kobold Miner (Strike 41)"), "page lists the last hits")
    check(DeathNotesDB.R.lastRecap == 100.5, "last recap remembered")

    -- 3. A second death whose recap is the same old one: keeps its own guess.
    e.foe = "Murloc Raider"
    e.out = {}
    e.fire("PLAYER_DEAD")
    e.runTimers()
    local d2 = e.deaths()[2]
    check(d2.killer == "Murloc Raider" and d2.recap == nil, "a stale recap is not applied to a new death")
    check(not e.has("Death recap"), "no recap line for a stale recap")

    -- 4. Environmental death, secret fields, more than 5 hits.
    e.foe = nil
    recap = {
        { timestamp = 200, environmentalType = "Falling", amount = 120, event = "ENVIRONMENTAL_DAMAGE" },
        { timestamp = 199, sourceName = SECRET, spellName = SECRET, amount = SECRET },
        { timestamp = 198, sourceName = "Bat", amount = 5 },
        { timestamp = 197, sourceName = "Bat", amount = 4 },
        { timestamp = 196, sourceName = "Bat", amount = 3 },
        { timestamp = 195, sourceName = "Bat", amount = 2 },
        { timestamp = 194, sourceName = "Bat", amount = 1 },
    }
    e.fire("PLAYER_DEAD")
    e.runTimers()
    local d3 = e.deaths()[3]
    check(d3.killer == "Falling" and d3.blow == "Falling (120)", "environmental killer, got " .. tostring(d3.killer))
    check(#d3.hits == 5 and d3.hits[1].amount == 2, "secret-only hit dropped, the newest 5 kept; got " .. #d3.hits)
    check(d3.hits[#d3.hits].env == "Falling", "killing blow last")

    -- 5. Secret timestamps: game order (killing blow first); a secret killer falls back to the next readable source.
    recap = {
        { timestamp = SECRET, sourceName = SECRET, spellName = "Fireball", amount = 30 },
        { timestamp = SECRET, sourceName = "Defias Pillager", spellName = "Fireball", amount = 25 },
    }
    e.foe = "Defias Thug"
    e.fire("PLAYER_DEAD")
    e.runTimers()
    local d4 = e.deaths()[4]
    check(d4.killer == "Defias Pillager", "secret killer name: next readable source, got " .. tostring(d4.killer))
    check(d4.blow == "Fireball 30", "killing blow without a name, got " .. tostring(d4.blow))
end

-- 6. Empty recap, then the page opened later fills it in; a page much later doesn't.
do
    local e = Setup(api, true)
    recap = {}
    e.foe = "Young Wolf"
    e.fire("PLAYER_DEAD")
    e.runTimers()
    local d = e.deaths()[1]
    check(d.killer == "Young Wolf" and d.recap == nil, "empty recap keeps the guess")
    recap = { { timestamp = 300, sourceName = "Mother Fang", spellName = "Poison", amount = 22 } }
    e.page()
    check(d.killer == "Mother Fang", "page opening reads the recap")
    check(e.has("Last hits: Mother Fang (Poison 22)"), "page shows hits read on opening")
    -- Later death, recap never filled, page opened after 5 minutes: stays on its guess.
    recap = {}
    e.foe = "Gnoll"
    e.fire("PLAYER_DEAD")
    e.runTimers()
    recap = { { timestamp = 400, sourceName = "Hogger", amount = 50 } }
    e.gametime = e.gametime + 301
    e.page()
    check(e.deaths()[2].killer == "Gnoll", "an old pending death is not filled from a later recap")
end

-- 7. The API errors or returns junk: no error reaches the player, the guess stays; no C_Timer.After works too.
do
    local bad = {
        HasRecapEvents = function() error("boom") end,
        GetRecapEvents = function() return SECRET end,
    }
    local e = Setup(bad, false)
    e.foe = "Young Wolf"
    e.fire("PLAYER_DEAD")
    check(e.deaths()[1].killer == "Young Wolf", "broken API keeps the guess")
    bad.GetRecapEvents = function() return { "junk", 5, { amount = SECRET } } end
    e.fire("PLAYER_DEAD")
    check(e.deaths()[2].killer == "Young Wolf", "junk entries keep the guess")
    e.page()
    check(not e.has("<<ERROR"), "page works with a broken API")
end

if #failures > 0 then
    print("FAILURES (" .. #failures .. "):")
    for _, why in ipairs(failures) do print(" - " .. why) end
    os.exit(1)
end
print("test_r5c_deathrecap: all checks passed")
