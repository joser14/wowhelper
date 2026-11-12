-- Round 6: the packaging checks of test_xreview_pack_globals.lua, applied to Events (new in the ForeverWorld
-- bundle, not yet in that test's fixed list) and the changed GoldGuide. The scanner is taken from that test's own
-- source (CALLBACK_EVENTS through Walk, copied unchanged), so both tests apply the same rules:
--  * every global written is in the helper's namespace (folder or file name, "Forever...", SLASH_<KEY><n>);
--  * fields are only written into our own global tables (SlashCmdList only under the helper's own key);
--  * no CallbackEvent name appears anywhere; Lua 5.1 limits and operators hold.
-- Run from the tests folder:  node run.js "<repo root>" test_r6_events_globals.lua
local base = ADDON_PATH
local failures = {}
local function check(cond, why) if not cond then failures[#failures + 1] = why end end

-- Copied unchanged from test_xreview_pack_globals.lua (CALLBACK_EVENTS through Walk); fengari has no io.open to read it.
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

local MODULES = {
    { "Events", { "Data.lua", "Events.lua" } },
    { "GoldGuide", { "Data.lua", "GoldGuide.lua" } },
}
local seen = {}
for _, module in ipairs(MODULES) do
    local folder = module[1]
    local out = { writes = {}, fields = {}, lua51 = {}, events = {} }
    local slashKeys = {}
    for _, file in ipairs(module[2]) do
        local chunk, err = loadfile(base .. "/" .. folder .. "/" .. file)
        check(chunk, "load " .. folder .. "/" .. file .. ": " .. tostring(err))
        if chunk then
            local before = #out.writes
            Walk(Parse(chunk), folder .. "/" .. file, out)
            for i = before + 1, #out.writes do out.writes[i].fileBase = file:gsub("%.lua$", "") end
        end
    end
    for _, w in ipairs(out.writes) do
        seen[w.name] = true
        local slashKey = w.name:match("^SLASH_(.-)%d+$")
        local ours = Starts(w.name, folder) or Starts(w.name, w.fileBase) or Starts(w.name, "Forever") or slashKey ~= nil
        check(ours, w.at .. " writes global " .. w.name .. ", outside " .. folder .. "'s names (missing local?)")
        if slashKey then
            slashKeys[slashKey] = true
            check(type(w.value) == "string" and w.value:match("^/%w+$"), w.at .. ": " .. w.name .. " isn't a plain /command")
        end
    end
    for _, fw in ipairs(out.fields) do
        if fw.table == "SlashCmdList" then
            check(slashKeys[fw.key], fw.at .. " sets SlashCmdList." .. fw.key .. " without its own SLASH_" .. fw.key .. "1")
        else
            check(Starts(fw.table, folder) or Starts(fw.table, "Forever"), fw.at .. " writes " .. fw.table .. "." .. fw.key .. ", a table that isn't " .. folder .. "'s")
        end
    end
    for _, line in ipairs(out.lua51) do check(false, line) end
    for _, line in ipairs(out.events) do check(false, line .. " (a CallbackEvent: registering it is forbidden)") end
end

-- Not a vacuous pass: the scan saw what Events defines.
for _, name in ipairs({ "EventsData", "Events_Faire", "Events_TurnIns", "Events_TurnInFor", "SLASH_EVENTS1", "ForeverHubOnSwitch", "ForeverHubStatus" }) do
    check(seen[name], "global write seen: " .. name)
end

-- The slash command doesn't clash with any other helper's: no other helper's code holds the string "/fhevents".
local function HasString(f, text)
    for _, v in ipairs(f.k) do
        if v == text then return true end
    end
    for _, p in ipairs(f.p) do
        if HasString(p, text) then return true end
    end
    return false
end
local others = 0
for _, dir in ipairs({ "AutoQuest", "BagCheck", "Builds", "DeathNotes", "Dungeons", "DurabilityWatch", "FoodCheck",
    "ForeverHelper", "ForeverHub", "GoldGoal", "GoldGuide", "ItemAdvisor", "ItemFinder", "Landmarks", "LevelGuide",
    "LevelLog", "MapPins", "PriceMemory", "ProfessionCap", "ProfessionGuide", "QuestCheck", "QuestMobs", "QuestTracker",
    "RareWatch", "ReadyCheck", "RepWatch", "RestGuard", "SupplyWatch", "TalentNudge", "Tooltips", "TrainerNotes",
    "WeaponSkillWatch", "WindowBadges", "ZoneLevels" }) do
    local chunk = loadfile(base .. "/" .. dir .. "/" .. dir .. ".lua")
    if chunk then
        others = others + 1
        check(not HasString(Parse(chunk), "/fhevents"), "/fhevents also used by " .. dir)
    end
end
check(others >= 30, "other helpers scanned: " .. others)
if #failures > 0 then
    error("FAILURES (" .. #failures .. "):\n" .. table.concat(failures, "\n"))
end
print("ALL TESTS PASSED")
