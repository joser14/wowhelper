-- Round 6 #18 (research\re_round6.md): Dungeons keeps who in the group looted which notable item, per run, read
-- from CHAT_MSG_LOOT only (a plain chat event, not a CallbackEvent). Secret text is skipped; nothing is sent to
-- chat; at most 20 lines per run; shown in the run's line on the Instance log; merged with the run.
-- Run from the tests folder:  node run.js "<repo root>" test_r6_stats_grouploot.lua
local base = ADDON_PATH
local out, frames, failures = {}, {}, {}
local function check(cond, why) if not cond then failures[#failures + 1] = why end end

local function NewFrame(kind, name)
    local f = { kind = kind, name = name, registered = {}, scripts = {}, shown = true, text = "" }
    function f:RegisterEvent(e) self.registered[e] = true end
    function f:SetScript(what, fn) self.scripts[what] = fn; if what == "OnEvent" then self.fn = fn end end
    function f:Show() self.shown = true end
    function f:Hide() self.shown = false end
    function f:IsShown() return self.shown end
    function f:SetText(t) self.text = t end
    function f:CreateFontString() return NewFrame("FontString") end
    return setmetatable(f, { __index = function() return function() end end })
end
CreateFrame = function(kind, name) local f = NewFrame(kind, name); frames[#frames + 1] = f; return f end
UIParent = NewFrame("Frame")
SlashCmdList = {}
ForeverHub_Receive = function(_, t) out[#out + 1] = t end
local SECRET = setmetatable({}, { __index = function() error("indexed a secret") end, __concat = function() error("concatenated a secret") end })
issecretvalue = function(v) return v == SECRET end
local sent = {}
SendChatMessage = function() sent[#sent + 1] = true end

local now = 1000000
time = function() return now end
GetTime = function() return 500 end
date = function(_, t) return "day " .. tostring(t) end
UnitName = function() return "Ann", "Leaf" end
UnitGUID = function(unit) return unit == "player" and "Player-1-0001" or nil end
GetRealmName = function() return "Realm" end
UnitLevel = function() return 18 end
UnitXP = function() return 0 end
UnitXPMax = function() return 9000 end
GetMoney = function() return 0 end
UnitClass = function() return "Priest", "PRIEST" end
UnitFactionGroup = function() return "Alliance" end
C_QuestLog = { IsQuestFlaggedCompleted = function() return false end, GetLogIndexForQuestID = function() return nil end, IsComplete = function() return false end }
C_Item = {
    GetItemCount = function() return 0 end,
    GetItemInfo = function(id)
        local n = tonumber(id) or tonumber(tostring(id):match("item:(%d+)"))
        return "Item " .. tostring(n), nil, n == 9999 and 3 or 2
    end,
}
local inside = false
IsInInstance = function() return inside, inside and "party" or "none" end
GetInstanceInfo = function() return inside and "The Deadmines" or "Elwynn Forest", inside and "party" or "none", 1, "Normal", 5, 0, false, inside and 36 or 0 end
C_Timer = { After = function(_, fn) fn() end, NewTicker = function() end }
-- The game's own strings, as the client defines them.
LOOT_ITEM = "%s receives loot: %s."
LOOT_ITEM_MULTIPLE = "%s receives loot: %sx%d."
LOOT_ITEM_SELF = "You receive loot: %s."
LOOT_ITEM_SELF_MULTIPLE = "You receive loot: %sx%d."

assert(loadfile(base .. "/Dungeons/Data.lua"))("Dungeons", {})
assert(loadfile(base .. "/Dungeons/Dungeons.lua"))("Dungeons", {})
local f = frames[1]
local function fire(ev, ...) if f.registered[ev] then f.fn(f, ev, ...) end end
local function page(arg) out = {}; local ok, err = pcall(SlashCmdList.DUNGEONS, arg); if not ok then out[#out + 1] = "<<ERROR " .. tostring(err) .. ">>" end end
local function has(text) for _, t in ipairs(out) do if t:find(text, 1, true) then return t end end end

check(f.registered.CHAT_MSG_LOOT, "listens for CHAT_MSG_LOOT")
fire("PLAYER_LOGIN")
-- Outside a dungeon: nothing kept.
fire("CHAT_MSG_LOOT", "Bob receives loot: |cff0070dd|Hitem:9999::::|h[Blue Thing]|h|r.", "Bob")
inside = true
fire("PLAYER_ENTERING_WORLD")
local run = DungeonsDB.runs[1]
check(run and run.group == nil, "nothing recorded outside the dungeon")

-- In a run: a dungeon item (Cruel Barb), a blue, a stack of greens (not notable), your own loot, secret text.
fire("CHAT_MSG_LOOT", "Bob receives loot: |cff1eff00|Hitem:5191::::|h[Cruel Barb]|h|r.", "Bob")
fire("CHAT_MSG_LOOT", "Cat receives loot: |cnIQ3:|Hitem:9999::::|h[Blue Thing]|h|r.", "Cat")
fire("CHAT_MSG_LOOT", "Cat receives loot: |cff1eff00|Hitem:2589::::|h[Linen Cloth]|h|rx4.", "Cat")
fire("CHAT_MSG_LOOT", "You receive loot: |cff0070dd|Hitem:9999::::|h[Blue Thing]|h|r.", "Ann")
fire("CHAT_MSG_LOOT", SECRET, "Dan")
fire("CHAT_MSG_LOOT", "Cat receives loot: |cnIQ3:|Hitem:9999::::|h[Blue Thing]|h|r.", "Cat")
local group = run.group or {}
check(#group == 3, "three notable lines: " .. #group)
local by = {}
for _, got in ipairs(group) do by[got.w .. ":" .. got.i] = got.n end
check(by["Bob:5191"] == 1, "Bob looted the dungeon item")
check(by["Cat:9999"] == 2, "Cat looted the blue twice")
check(by["Ann Leaf:9999"] == 1, "your own loot under your name")
check(not by["Cat:2589"], "greens left out")

page("log")
local line = has("Who looted what:") or ""
check(line:find("Bob|r Item 5191", 1, true) and line:find("Item 9999 x2", 1, true), "shown in the run's line: " .. line)

-- Bounded: at most 20 lines a run.
for i = 1, 40 do fire("CHAT_MSG_LOOT", "P" .. i .. " receives loot: |cnIQ4:|Hitem:" .. (20000 + i) .. "::::|h[Epic]|h|r.", "P" .. i) end
check(#run.group == 20, "at most 20 lines: " .. #run.group)

check(#sent == 0, "never sends chat")
local src = string.dump(assert(loadfile(base .. "/Dungeons/Dungeons.lua")))
for _, bad in ipairs({ "SendChatMessage", "AddMessage", "RollOnLoot", "ConfirmLootRoll", "hooksecurefunc", "COMBAT_LOG" }) do
    check(not src:find(bad, 1, true), "source has no " .. bad)
end
check(not has("<<ERROR"), "no errors")

if #failures > 0 then
    error("FAILURES (" .. #failures .. "):\n" .. table.concat(failures, "\n"))
end
print("test_r6_stats_grouploot: all checks passed")
