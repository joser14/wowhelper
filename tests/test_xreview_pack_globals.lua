-- Packaging review: every file the six bundles ship, read as compiled code (string.dump, nothing is run).
-- Checks, across the whole suite at once:
--  * every global a helper writes is in its own namespace: its folder or file name, "Forever" (the shared
--    helpers), SLASH_<KEY><n> or BINDING_*. A missing "local" (a stray `count = 0` in a function) fails here;
--  * no write into a global table that isn't ours (SlashCmdList only under the helper's own slash key);
--  * a global outside the shared "Forever" names has exactly one owner;
--  * slash keys and slash command strings are unique across the suite;
--  * no CallbackEvent name (COMBAT_LOG_*, MINIMAP_PING, ...) appears as a string anywhere;
--  * the code fits the game's Lua 5.1: no 5.3-only operators (//, &, |, ~, <<, >>), at most 60 upvalues
--    and 250 registers per function. The tests run on Lua 5.3, so nothing else would catch these.
-- The file lists follow build.ps1 and each helper's .toc (build.ps1 stops if a .toc misses a .lua).
-- Run from the tests folder:  node run.js "<repo root>" test_xreview_pack_globals.lua
local base = ADDON_PATH
local failures = {}
local function check(cond, why) if not cond then failures[#failures + 1] = why end end

local BUNDLES = {
    { "!ForeverHub", {
        { "!ErrorLog", { "!ErrorLog.lua" } },
        { "ForeverHub", { "ForeverHub.lua", "ForeverHubExtras.lua" } },
        { "ForeverHelper", { "ForeverHelper.lua" } } } },
    { "ForeverGuides", {
        { "LevelGuide", { "QuestIDs.lua", "Prereqs.lua", "QuestDB.lua", "QuestLookup.lua", "QuestRules.lua", "Routes.lua",
            "QuestXP.lua", "Travel.lua", "HostileTowns.lua", "Boats.lua", "SkyborneSpots.lua", "Planner.lua", "TravelPlan.lua",
            "QuestRewards.lua", "Ahead.lua", "LevelGuide.lua" } },
        { "ProfessionCap", { "ProfessionCap.lua" } },
        { "ProfessionGuide", { "Data_Alchemy.lua", "Data_Blacksmithing.lua", "Data_Enchanting.lua", "Data_Engineering.lua",
            "Data_Leatherworking.lua", "Data_Tailoring.lua", "Data_Mining.lua", "Data_Herbalism.lua", "Data_Skinning.lua",
            "Data_Cooking.lua", "Data_FirstAid.lua", "Data_Fishing.lua", "ProfessionGuide.lua" } },
        { "GoldGoal", { "GoldGoal.lua" } },
        { "GoldGuide", { "Data.lua", "GoldGuide.lua" } },
        { "Dungeons", { "Data.lua", "Dungeons.lua" } } } },
    { "ForeverQuests", {
        { "QuestTracker", { "QuestTracker.lua" } },
        { "QuestCheck", { "QuestCheck.lua" } },
        { "ZoneLevels", { "ZoneLevels.lua" } },
        { "QuestMobs", { "Drops.lua", "QuestMobs.lua" } },
        { "AutoQuest", { "AutoQuest.lua" } } } },
    { "ForeverBags", {
        { "ItemAdvisor", { "GearCurves.lua", "ItemAdvisor.lua" } },
        { "BagCheck", { "BagCheck.lua" } },
        { "ItemFinder", { "ItemFinder.lua" } },
        { "PriceMemory", { "PriceMemory.lua" } },
        { "FoodCheck", { "FoodIDs.lua", "CampObjects.lua", "FoodCheck.lua", "ManaFull.lua" } },
        { "SupplyWatch", { "SupplyWatch.lua" } },
        { "DurabilityWatch", { "DurabilityWatch.lua" } },
        { "Tooltips", { "Tooltips.lua" } },
        { "WindowBadges", { "WindowBadges.lua" } } } },
    { "ForeverCharacter", {
        { "TalentNudge", { "TalentNudge.lua" } },
        { "Builds", { "Data.lua", "Builds.lua" } },
        { "TrainerNotes", { "Data.lua", "TrainerNotes.lua" } },
        { "WeaponSkillWatch", { "WeaponSkillWatch.lua" } },
        { "RestGuard", { "RestGuard.lua" } },
        { "LevelLog", { "LevelLog.lua" } },
        { "RepWatch", { "RepWatch.lua" } },
        { "ReadyCheck", { "ReadyCheck.lua" } },
        { "Legacy", { "Legacy.lua" } },
        { "SpellMath", { "SpellMath.lua" } } } },
    { "ForeverWorld", {
        { "Landmarks", { "Landmarks.lua" } },
        { "DeathNotes", { "DeathNotes.lua", "BreathWatch.lua", "LowWarn.lua" } },
        { "RareWatch", { "RareWatch.lua" } },
        { "MapPins", { "MapPins.lua", "Way.lua" } },
        { "AggroWatch", { "AggroWatch.lua" } },
        { "Events", { "Data.lua", "Events.lua" } },
        { "Nodes", { "Nodes.lua" } } } },
}

local CALLBACK_EVENTS = {}
for _, e in ipairs({ "COMBAT_LOG_EVENT_UNFILTERED", "COMBAT_LOG_EVENT", "COMBAT_LOG_EVENT_INTERNAL_UNFILTERED",
    "COMBAT_LOG_APPLY_FILTER_SETTINGS", "COMBAT_LOG_REFILTER_ENTRIES", "MINIMAP_PING", "ENCOUNTER_STATE_CHANGED",
    "TOOLTIP_SHOW_ITEM_COMPARISON", "CLASS_TALENTS_SWITCH_TO_LOADOUT_BY_INDEX", "CLASS_TALENTS_SWITCH_TO_LOADOUT_BY_NAME",
    "CLASS_TALENTS_SWITCH_TO_SPECIALIZATION_BY_INDEX", "CLASS_TALENTS_SWITCH_TO_SPECIALIZATION_BY_NAME" }) do
    CALLBACK_EVENTS[e] = true
end

-- A reader for the Lua 5.3 chunk format string.dump writes here (fengari: 4-byte ints and sizes, 8-byte floats).
local function Reader(s)
    local pos = 1
    local r = {}
    function r.byte() local b = s:byte(pos); pos = pos + 1; return b end
    function r.int() local v; v, pos = string.unpack("<i4", s, pos); return v end
    function r.uint() local v; v, pos = string.unpack("<I4", s, pos); return v end
    function r.num() local v; v, pos = string.unpack("<d", s, pos); return v end
    function r.str()
        local size = r.byte()
        if size == 0 then return nil end
        if size == 0xFF then size = r.int() end
        local v = s:sub(pos, pos + size - 2)
        pos = pos + size - 1
        return v
    end
    function r.skip(n) pos = pos + n end
    return r
end

local function ReadFunction(r)
    local f = { k = {}, code = {}, p = {}, lines = {}, upnames = {} }
    r.str()
    f.line = r.int(); r.int()
    r.byte(); r.byte()
    f.maxstack = r.byte()
    for i = 1, r.int() do f.code[i] = r.uint() end
    for i = 1, r.int() do
        local t = r.byte()
        if t == 1 then f.k[i] = r.byte() ~= 0
        elseif t == 3 then f.k[i] = r.num()
        elseif t == 19 then f.k[i] = r.int()
        elseif t == 4 or t == 20 then f.k[i] = r.str()
        else f.k[i] = false end
    end
    f.nups = r.int()
    for _ = 1, f.nups do r.byte(); r.byte() end
    for i = 1, r.int() do f.p[i] = ReadFunction(r) end
    for i = 1, r.int() do f.lines[i] = r.int() end
    for _ = 1, r.int() do r.str(); r.int(); r.int() end
    for i = 1, r.int() do f.upnames[i] = r.str() end
    return f
end

local function Parse(chunk)
    local s = string.dump(chunk)
    assert(s:sub(1, 4) == "\27Lua" and s:byte(5) == 0x53, "not a Lua 5.3 chunk")
    local r = Reader(s)
    r.skip(29)   -- signature, version, format, LUAC_DATA, five sizes, LUAC_INT, LUAC_NUM
    r.byte()     -- main function's upvalue count
    return ReadFunction(r)
end

local OP_LOADK, OP_GETTABUP, OP_SETTABUP, OP_SETTABLE = 1, 6, 8, 10
local OP_CALL, OP_TFORCALL, OP_VARARG, OP_LOADNIL = 36, 41, 45, 4
local LUA53_ONLY = { [19] = "//", [20] = "&", [21] = "|", [22] = "~", [23] = "<<", [24] = ">>", [26] = "unary ~" }

-- Every global write (name, constant value, where) and every field written into a global table.
local function Walk(f, where, out)
    local env = {}
    for index, name in ipairs(f.upnames) do
        if name == "_ENV" then env[index - 1] = true end
    end
    local kreg, greg = {}, {}
    local function K(x) local v = f.k[(x & 0xFF) + 1]; return type(v) == "string" and v or nil end
    local function Key(x) if x & 0x100 ~= 0 then return K(x) end return kreg[x] end
    local function Value(x) if x & 0x100 ~= 0 then return f.k[(x & 0xFF) + 1] end return kreg[x] end
    for pc, ins in ipairs(f.code) do
        local op, a = ins & 0x3F, (ins >> 6) & 0xFF
        local b, c, bx = (ins >> 23) & 0x1FF, (ins >> 14) & 0x1FF, (ins >> 14) & 0x3FFFF
        local at = where .. ":" .. tostring(f.lines[pc] or f.line)
        if op == OP_LOADK then
            local v = f.k[bx + 1]
            kreg[a], greg[a] = type(v) == "string" and v or nil, nil
        elseif op == OP_GETTABUP and env[b] then
            greg[a], kreg[a] = Key(c), nil
        elseif op == OP_SETTABUP and env[a] then
            out.writes[#out.writes + 1] = { name = Key(b) or "?", value = Value(c), at = at }
        elseif op == OP_SETTABLE then
            if greg[a] then
                out.fields[#out.fields + 1] = { table = greg[a], key = Key(b) or "?", at = at }
            end
        elseif op == OP_CALL or op == OP_TFORCALL or op == OP_VARARG or op == OP_LOADNIL then
            for r = a, 255 do kreg[r], greg[r] = nil, nil end
        else
            kreg[a], greg[a] = nil, nil
        end
        if LUA53_ONLY[op] then
            out.lua51[#out.lua51 + 1] = at .. " uses " .. LUA53_ONLY[op] .. " (Lua 5.3 only; the game runs 5.1)"
        end
    end
    if f.nups > 60 then out.lua51[#out.lua51 + 1] = where .. ":" .. f.line .. " has " .. f.nups .. " upvalues (Lua 5.1 allows 60)" end
    if f.maxstack > 250 then out.lua51[#out.lua51 + 1] = where .. ":" .. f.line .. " needs " .. f.maxstack .. " registers (Lua 5.1 allows 250)" end
    for _, v in ipairs(f.k) do
        if type(v) == "string" and CALLBACK_EVENTS[v] then out.events[#out.events + 1] = where .. ": " .. v end
    end
    for _, p in ipairs(f.p) do Walk(p, where, out) end
end

local function Starts(name, prefix) return prefix ~= "" and name:sub(1, #prefix) == prefix end

local ownersOf, slashKeyOwner, slashString, slashHandlers = {}, {}, {}, {}
local fileCount, writeCount, moduleCount = 0, 0, 0
for _, bundle in ipairs(BUNDLES) do
    for _, module in ipairs(bundle[2]) do
        moduleCount = moduleCount + 1
        local folder = module[1]
        local own = folder:gsub("^!", "")
        local out = { writes = {}, fields = {}, lua51 = {}, events = {} }
        for _, file in ipairs(module[2]) do
            local path = base .. "/" .. folder .. "/" .. file
            local chunk, err = loadfile(path)
            check(chunk, "load " .. folder .. "/" .. file .. ": " .. tostring(err))
            if chunk then
                fileCount = fileCount + 1
                local ok, parsed = pcall(Parse, chunk)
                check(ok, "read " .. folder .. "/" .. file .. ": " .. tostring(parsed))
                if ok then
                    out.file = file:gsub("%.lua$", "")
                    local before = #out.writes
                    Walk(parsed, folder .. "/" .. file, out)
                    for i = before + 1, #out.writes do out.writes[i].fileBase = out.file end
                end
            end
        end
        for _, w in ipairs(out.writes) do
            writeCount = writeCount + 1
            local name = w.name
            local slashKey = name:match("^SLASH_(.-)%d+$")
            local ours = Starts(name, own) or Starts(name, w.fileBase) or Starts(name, "Forever")
                or slashKey ~= nil or Starts(name, "BINDING_")
            check(ours, w.at .. " writes global " .. name .. ", outside " .. folder .. "'s names (missing local?)")
            ownersOf[name] = ownersOf[name] or {}
            ownersOf[name][folder] = w.at
            if slashKey then
                check(slashKeyOwner[slashKey] == nil or slashKeyOwner[slashKey] == folder,
                    "slash key " .. slashKey .. " used by " .. tostring(slashKeyOwner[slashKey]) .. " and " .. folder)
                slashKeyOwner[slashKey] = folder
                check(type(w.value) == "string" and w.value:match("^/%w+$"), w.at .. ": " .. name .. " isn't a plain /command")
                if type(w.value) == "string" then
                    local cmd = w.value:lower()
                    check(slashString[cmd] == nil, "slash command " .. cmd .. " is in " .. tostring(slashString[cmd]) .. " and " .. folder)
                    slashString[cmd] = folder
                end
            end
        end
        for _, fw in ipairs(out.fields) do
            if fw.table == "SlashCmdList" and fw.key == "?" and folder == "ForeverHub" then
                -- The hub's WrapCommands: re-points the helpers' own keys (its page list) at the window.
            elseif fw.table == "SlashCmdList" then
                slashHandlers[fw.key] = folder
                check(slashKeyOwner[fw.key] == folder, fw.at .. " sets SlashCmdList." .. fw.key .. " without its own SLASH_" .. fw.key .. "1")
            else
                check(Starts(fw.table, own) or Starts(fw.table, "Forever") or ownersOf[fw.table] and ownersOf[fw.table][folder],
                    fw.at .. " writes " .. fw.table .. "." .. fw.key .. ", a table that isn't " .. folder .. "'s")
            end
        end
        for _, line in ipairs(out.lua51) do check(false, line) end
        for _, line in ipairs(out.events) do check(false, line .. " (a CallbackEvent: registering it is forbidden)") end
    end
end

-- One owner per global, except the shared helpers every copy defines the same way ("Forever...").
for name, owners in pairs(ownersOf) do
    local list = {}
    for folder in pairs(owners) do list[#list + 1] = folder end
    table.sort(list)
    check(#list == 1 or Starts(name, "Forever"), "global " .. name .. " is written by " .. table.concat(list, ", "))
end
for key, folder in pairs(slashKeyOwner) do
    check(slashHandlers[key] == folder, "SLASH_" .. key .. "1 in " .. folder .. " has no SlashCmdList." .. key)
end

-- Not a vacuous pass.
check(moduleCount == 40, "helpers read: " .. moduleCount)
check(fileCount == 81, "files read: " .. fileCount)
check(writeCount >= 200, "global writes found: " .. writeCount)
local keys = 0
for _ in pairs(slashKeyOwner) do keys = keys + 1 end
check(keys >= 30, "slash keys found: " .. keys)
check(slashString["/way"] == "MapPins" and slashString["/hub"] == "ForeverHub", "slash strings read")
check(ownersOf.ItemAdvisorDB and ownersOf.ItemAdvisorDB.ItemAdvisor, "saved variable writes read")

-- The scanner itself: a leak, a Blizzard-table write, a 5.3 operator and a forbidden event are all caught.
do
    local probe = { writes = {}, fields = {}, lua51 = {}, events = {} }
    Walk(Parse(load([[
        local t = {}
        function Probe_Ok() end
        count = 0
        StaticPopupDialogs.PROBE = {}
        local a = select("#", ...); local x = a // 2
        local e = "COMBAT_LOG_EVENT_UNFILTERED"
    ]])), "probe", probe)
    local names = {}
    for _, w in ipairs(probe.writes) do names[w.name] = true end
    check(names.Probe_Ok and names.count, "probe: global writes")
    check(probe.fields[1] and probe.fields[1].table == "StaticPopupDialogs" and probe.fields[1].key == "PROBE", "probe: table write")
    check(#probe.lua51 == 1, "probe: 5.3 operator")
    check(#probe.events == 1, "probe: forbidden event")
end

if #failures > 0 then
    error("FAILURES (" .. #failures .. "):\n" .. table.concat(failures, "\n"))
end
print("ALL TESTS PASSED (" .. fileCount .. " files, " .. writeCount .. " global writes)")
