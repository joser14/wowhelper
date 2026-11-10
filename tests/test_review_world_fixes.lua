-- Review fixes for the world helpers:
--  Landmarks: profession trainers are told apart with C_Trainer.GetTrainerType (documented on Forever),
--    not only the undocumented IsTradeskillTrainer.
--  WeaponSkillWatch: fist weapons (subclass 13) read the Fist Weapons line (473), not Unarmed (162);
--    a line reported with a zero cap counts as not learned.
--  MapPins: a full death list that gains a new death (same count) still refreshes the pins.
-- Run from the tests folder:  node run.js "<repo root>" test_review_world_fixes.lua
local base = ADDON_PATH
local SECRET = {}
issecretvalue = function(v) return v == SECRET end
local out = {}
ForeverHub_Receive = function(_, t) out[#out + 1] = t end
local function reset() out = {} end
local function saw(text) for _, t in ipairs(out) do if t:find(text, 1, true) then return true end end return false end
local function need(text, why) assert(saw(text), why .. ": wanted '" .. text .. "' in:\n" .. table.concat(out, "\n")) end
local function never(text, why) assert(not saw(text), why .. ": did not want '" .. text .. "' in:\n" .. table.concat(out, "\n")) end

local frames = {}
local function newFrame()
    local f = { registered = {}, scripts = {}, shown = true }
    function f:RegisterEvent(e) self.registered[e] = true end
    function f:SetScript(s, fn) self.scripts[s] = fn end
    function f:CreateTexture() return { SetAllPoints = function() end, SetTexture = function() end,
        SetAtlas = function() end, SetTexCoord = function() end } end
    for _, m in ipairs({ "SetAllPoints", "RegisterForClicks", "SetFrameStrata", "SetFrameLevel", "SetSize",
        "SetPoint", "ClearAllPoints", "SetOwner", "AddLine" }) do
        f[m] = function() end
    end
    function f:Show() self.shown = true end
    function f:Hide() self.shown = false end
    function f:IsShown() return self.shown end
    function f:GetEffectiveScale() return 1 end
    frames[#frames + 1] = f
    return f
end
CreateFrame = function() return newFrame() end
UIParent = newFrame()
SlashCmdList = {}
UnitName = function() return "Tester" end
UnitGUID = function() return "Player-1-00000001" end
GetRealmName = function() return "Realm" end
GetTime = function() return 100 end
time = time or os.time
local function load(path)
    local n = #frames
    assert(loadfile(base .. "/" .. path))(path:match("^([^/]+)"), {})
    return frames[n + 1]
end
local function fire(f, ev, ...) assert(f.registered[ev], "not registered: " .. ev); f.scripts.OnEvent(f, ev, ...) end

----- Landmarks: trainer type from C_Trainer
local playerMap = 1438
C_Map = {
    GetBestMapForUnit = function() return playerMap end,
    GetPlayerMapPosition = function() return { GetXY = function() return 0.5, 0.5 end } end,
    GetMapInfo = function(id) return { name = "Map " .. id } end,
}
IsTradeskillTrainer = nil
local trainerType = 2
Enum = { TrainerType = { General = 0, TalentsObsolete = 1, Tradeskills = 2, Pet = 3 } }
C_Trainer = { GetTrainerType = function() return trainerType end }
local lm = load("Landmarks/Landmarks.lua")
fire(lm, "PLAYER_LOGIN")
local places = LandmarksDB.Realm.places
fire(lm, "TRAINER_SHOW")
assert(places[1] and places[1].kind == "profession", "profession trainer from C_Trainer: " .. tostring(places[1] and places[1].kind))
trainerType = SECRET
playerMap = 1439
fire(lm, "TRAINER_SHOW")
assert(places[2] and places[2].kind == "trainer", "hidden type is not a profession trainer")
-- Older clients without C_Trainer still use the global.
C_Trainer = nil
IsTradeskillTrainer = function() return true end
playerMap = 1440
fire(lm, "TRAINER_SHOW")
assert(places[3] and places[3].kind == "profession", "fallback to IsTradeskillTrainer")

----- WeaponSkillWatch: fist weapons and zero caps
reset()
UnitClass = function() return "Rogue", "ROGUE" end
local inHand = { [16] = "fist", [17] = nil, [18] = nil }
GetInventoryItemLink = function(_, slot) return inHand[slot] end
C_Item = { GetItemInfoInstant = function() return 1, "", "", "", 0, 2, 13 end }
local skills = {
    [162] = { name = "Unarmed", rank = 1, maxRank = 50 },          -- bare hands: low, but not what a fist weapon uses
    [473] = { name = "Fist Weapons", rank = 48, maxRank = 50 },
    [45] = { name = "Bows", rank = 0, maxRank = 0 },               -- untrained line reported with a zero cap
}
C_SkillInfo = { GetSkillLineInfoByID = function(line) return skills[line] end }
local ws = load("WeaponSkillWatch/WeaponSkillWatch.lua")
fire(ws, "PLAYER_LOGIN")
never("Unarmed", "fist weapon doesn't read the Unarmed skill")
SlashCmdList.WEAPONSKILLWATCH("")
need("main hand: Fist Weapons 48/50", "fist weapon reads Fist Weapons")
skills[473].rank = 20
reset(); fire(ws, "SKILL_LINES_CHANGED")
need("Fist Weapons is only 20/50 (main hand)", "low fist skill warns")
reset(); SlashCmdList.WEAPONSKILLWATCH("all")
need("Fist Weapons 20/50", "all lists fist weapons")
never("Bows", "a zero-cap line isn't listed as 0/0")
skills[473] = { name = "Fist Weapons", rank = 0, maxRank = 0 }
reset(); SlashCmdList.WEAPONSKILLWATCH("")
need("main hand: no skill data for this weapon; you may need to train it.", "untrained weapon says so")

----- MapPins: a full death list still refreshes
reset()
Minimap = nil
WorldMapFrame = nil
InCombatLockdown = function() return false end
UnitLevel = function() return 20 end
DeathNotesDB = { Realm = { deaths = {} } }
local deaths = DeathNotesDB.Realm.deaths
for i = 1, 40 do
    deaths[i] = { when = 1000 + i, level = 5, mapID = 1429, x = 0.5, y = 0.5, where = "Elwynn" }
end
local nFrames = #frames
assert(loadfile(base .. "/MapPins/MapPins.lua"))("MapPins", {})
local driver, mp
for i = nFrames + 1, #frames do
    if frames[i].scripts.OnUpdate then driver = frames[i] end
    if frames[i].registered.PLAYER_LOGIN then mp = frames[i] end
end
assert(driver and mp, "MapPins driver and event frames")
fire(mp, "PLAYER_LOGIN")
playerMap = 1453
driver.scripts.OnUpdate(driver, 2)
SlashCmdList.MAPPINS("")
need("Deaths:|r on, 30 pins |cff999999(0 in this zone)", "newest 30 deaths, none here yet")
-- The list is full: the oldest goes, a new death on this map comes in, and the count stays 40.
table.remove(deaths, 1)
deaths[#deaths + 1] = { when = 5000, level = 20, mapID = 1453, x = 0.4, y = 0.4, where = "Stormwind" }
driver.scripts.OnUpdate(driver, 2)
reset(); SlashCmdList.MAPPINS("")
need("Deaths:|r on, 30 pins |cff999999(1 in this zone)", "new death at an unchanged count is pinned")

print("ALL TESTS PASSED")
