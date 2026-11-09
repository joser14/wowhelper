local addonPath = ADDON_PATH
local state = { money = 50000, xp = 4900, xpMax = 5000, level = 10, rested = 300, now = 1000, secret = false }
local frames = {}
local SECRET = {}

local function newFrame(name)
    local f = { scripts = {}, shownFlag = true, text = nil, checked = false, points = {} }
    setmetatable(f, { __index = function(_, k) return function() end end })
    f.SetScript = function(self, k, fn) self.scripts[k] = fn end
    f.SetShown = function(self, v) self.shownFlag = v and true or false end
    f.Show = function(self) self.shownFlag = true end
    f.Hide = function(self) self.shownFlag = false end
    f.IsShown = function(self) return self.shownFlag end
    f.SetText = function(self, t) self.text = t end
    f.SetChecked = function(self, v) self.checked = v end
    f.GetChecked = function(self) return self.checked end
    f.GetPoint = function() return "CENTER", nil, "CENTER", 1, 2 end
    f.CreateFontString = function() local s = newFrame(); frames[#frames + 1] = s; return s end
    frames[#frames + 1] = f
    return f
end

CreateFrame = function(_, name) return newFrame(name) end
UIParent = newFrame()
UISpecialFrames = {}
tinsert = table.insert
SlashCmdList = {}
local chat = {}
DEFAULT_CHAT_FRAME = { AddMessage = function(_, t) chat[#chat + 1] = t end }
C_Timer = { NewTicker = function(_, fn) TICK = fn end }
GetTime = function() return state.now end
GetMoney = function() return state.money end
GetRealmName = function() return "Realm" end
UnitName = function() return "Tester", nil end
UnitLevel = function() return state.level end
UnitXP = function() if state.secret then return SECRET end return state.xp end
UnitXPMax = function() if state.secret then return SECRET end return state.xpMax end
GetXPExhaustion = function() return state.rested end
issecretvalue = function(v) return v == SECRET end

local eventFrame
local realCreate = CreateFrame
CreateFrame = function(...) local f = realCreate(...); eventFrame = eventFrame or f; return f end

assert(loadfile(addonPath))("ForeverHelper", {})

local function fire(event, ...) eventFrame.scripts.OnEvent(eventFrame, event, ...) end
local function texts()
    local out = {}
    for _, f in ipairs(frames) do local t = rawget(f, "text"); if t then out[#out + 1] = t end end
    return table.concat(out, "\n")
end
local function has(s, why) assert(texts():find(s, 1, true), why .. ": wanted '" .. s .. "' in:\n" .. texts()) end
local slash = function(m) SlashCmdList.FOREVERHELPER(m) end

fire("ADDON_LOADED", "SomeOtherAddon")
assert(ForeverHelperDB == nil, "ignores other addons")
fire("ADDON_LOADED", "ForeverHelper")
fire("PLAYER_LOGIN")
has("Rate: no XP gained yet", "starts with no rate")
has("No tasks yet", "empty hint")

state.xp, state.xpMax, state.level = 100, 6000, 11
state.now = state.now + 3600
fire("PLAYER_XP_UPDATE")
has("Rate: 200/hr", "level rollover counts 100 + 100 XP over one hour")
has("next level in 29h 30m", "ETA from 5900 remaining at 200/hr")

state.money = 150000
fire("PLAYER_MONEY")
has("Gold: 15g 0s 0c (10g 0s 0c, 10g 0s 0c/hr)", "gold gain and rate")
state.money = 10000
fire("PLAYER_MONEY")
has("(-4g 0s 0c", "negative gold delta")

slash("add Train at level 12")
slash("add odd |cff text")
has("1. Train at level 12", "task added")
local tasks = ForeverHelperDB.characters["Tester-Realm"].tasks
assert(type(tasks[1].text) == "string" and tasks[2].text == "odd ||cff text", "pipes escaped: " .. tostring(tasks[2].text))
slash("remove 1")
assert(#tasks == 1, "task removed")
slash("remove 99")
assert(chat[#chat]:find("No to%-do"), "bad remove reported")

slash("chars")
assert(chat[#chat]:find("Total gold: 1g 0s 0c", 1, true), chat[#chat])
slash("")
slash("nonsense")
assert(chat[#chat]:find("reset", 1, true), "help printed")
slash("reset")

state.secret = true
fire("PLAYER_XP_UPDATE")
TICK()
slash("reset")
has("XP: unavailable", "secret XP does not crash")

fire("PLAYER_LOGOUT")
print("ALL TESTS PASSED")
