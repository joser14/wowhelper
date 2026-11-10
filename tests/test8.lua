-- Loads every addon, fires every event, and runs every command while the game API
-- returns nothing, returns hidden (secret) values, or returns empty data.
local base = ADDON_PATH
local names = { "!ErrorLog", "BagCheck", "DurabilityWatch", "FoodCheck", "ForeverHelper", "ForeverHub", "GoldGoal", "ItemAdvisor", "ItemFinder",
    "LevelLog", "PriceMemory", "ProfessionCap", "QuestCheck", "RepWatch", "RestGuard", "SupplyWatch", "TalentNudge",
    "TrainerNotes", "WeaponSkillWatch", "ZoneLevels", "AutoQuest" }

local SECRET = setmetatable({}, { __tostring = function() return "SECRET" end })
local mode = "nil"
local function apiResult()
    if mode == "secret" then return SECRET, SECRET, SECRET, SECRET, SECRET, SECRET, SECRET end
    if mode == "zero" then return 0, 0, 0, 0, 0, 0, 0 end
    return nil
end

local KEEP = { print = true, tostring = true, tonumber = true, type = true, pairs = true, ipairs = true, next = true, select = true,
    pcall = true, error = true, assert = true, loadfile = true, load = true, table = true, string = true, math = true, os = true,
    setmetatable = true, getmetatable = true, rawget = true, rawset = true, _G = true, ADDON_PATH = true, _VERSION = true,
    rawequal = true, require = true, package = true, coroutine = true, debug = true, io = true, utf8 = true, collectgarbage = true,
    dofile = true, rawlen = true, xpcall = true, unpack = true }

-- A frame answers any method call, like a real frame would for the methods addons use.
local function newFrame()
    local frame = { registered = {}, scripts = {} }
    return setmetatable(frame, { __index = function(t, k)
        if k == "RegisterEvent" then return function(self, e) self.registered[e] = true end end
        if k == "SetScript" then return function(self, s, fn) self.scripts[s] = fn end end
        if k == "CreateFontString" or k == "CreateTexture" then return function() return newFrame() end end
        if k == "GetStringHeight" or k == "GetHeight" or k == "GetVerticalScroll" then return function() return 10 end end
        if k == "GetText" then return function() return "" end end
        return function() return nil end
    end })
end

local frames, chat = {}, {}
local apiNames = {}
local namespace = setmetatable({}, { __index = function(_, k) return function() return apiResult() end end })
setmetatable(_G, { __index = function(_, k)
    if type(k) == "string" and k:match("^C_") then return namespace end
    if type(k) == "string" and k:match("^[A-Z][a-z]") and not k:match("DB$") and not k:match("^Forever") then apiNames[k] = true; return function() return apiResult() end end
    return nil
end })

CreateFrame = function() local f = newFrame(); frames[#frames + 1] = f; return f end
DEFAULT_CHAT_FRAME = { AddMessage = function(_, t) chat[#chat + 1] = t end }
UIErrorsFrame = { AddMessage = function() end }
UIParent = newFrame()
Minimap = newFrame()
C_Timer = { After = function() end, NewTicker = function() end }
GameTooltip = newFrame()
ItemRefTooltip = newFrame()
SlashCmdList = {}
Enum = { TooltipDataType = { Item = 0 }, BagIndex = { Backpack = 0, CharacterBankTab_1 = 6 } }
issecretvalue = function(v) return v == SECRET end
local hooks = {}
TooltipDataProcessor = { AddTooltipPostCall = function(_, fn) hooks[#hooks + 1] = fn end }
TooltipUtil = { GetDisplayedItem = function() return apiResult() end }
time = function() return 1000 end
date = function() return "now" end
debugstack = function() return "stack" end
seterrorhandler = function() end
tinsert = table.insert
UISpecialFrames = {}
GetTime = function() return 1000 end
geterrorhandler = function() return function() end end

-- Ordinary frames must not produce unknown globals beyond saved data and slash commands.
local before = {}
for k in next, _G do before[k] = true end

local failures = {}
local function try(where, fn, ...)
    local ok, err = pcall(fn, ...)
    if not ok then failures[#failures + 1] = mode .. " | " .. where .. " | " .. tostring(err) end
end

for _, name in ipairs(names) do
    local path = base .. "/" .. name .. "/" .. name .. ".lua"
    local chunk = assert(loadfile(path))
    for _, m in ipairs({ "nil", "secret" }) do
        local handled = {}
        for k in pairs(SlashCmdList) do SlashCmdList[k] = nil end
        mode = m
        local start = #frames
        try(name .. " load", chunk, name, {})
        for i = start + 1, #frames do
            local f = frames[i]
            local onEvent = f.scripts.OnEvent
            if onEvent then
                -- Login events first, in the game's order.
                if f.registered.ADDON_LOADED then try(name .. " ADDON_LOADED", onEvent, f, "ADDON_LOADED", name) end
                if f.registered.PLAYER_LOGIN then try(name .. " PLAYER_LOGIN", onEvent, f, "PLAYER_LOGIN") end
                for event in pairs(f.registered) do
                    try(name .. " " .. event, onEvent, f, event, m == "secret" and SECRET or nil, m == "secret" and SECRET or nil)
                end
            end
        end
        for key, handler in pairs(SlashCmdList) do
            local mine = not handled[key]; handled[key] = true
            if mine then
            for _, arg in ipairs({ "", "all", "help", "1", "stats", "clear", "add x 5", "remove 1", "ammo 5", "role x", "500 Bags" }) do
                try(name .. " /" .. key .. " '" .. arg .. "'", handler, arg)
            end
            end
        end
        for _, hook in ipairs(hooks) do try(name .. " tooltip", hook, GameTooltip) end
        hooks = {}
    end
end

local leaks = {}
for k in next, _G do
    if not before[k] and not tostring(k):match("^SLASH_") then leaks[#leaks + 1] = tostring(k) end
end
table.sort(leaks)
print("GLOBALS ADDED: " .. table.concat(leaks, ", "))

local slash = {}
for k, v in next, _G do
    if type(k) == "string" and k:match("^SLASH_") then slash[#slash + 1] = v end
end
table.sort(slash)
print("COMMANDS: " .. table.concat(slash, " "))
local seen = {}
for _, c in ipairs(slash) do
    if seen[c] then print("DUPLICATE COMMAND: " .. c) end
    seen[c] = true
end

local unique, order = {}, {}
for _, f in ipairs(failures) do
    local key = f:gsub("| [^|]* '[^']*' |", "|")
    if not unique[key] then unique[key] = f; order[#order + 1] = f end
end
print("FAILURES: " .. #order .. " unique of " .. #failures)
for _, f in ipairs(order) do print(f) end
