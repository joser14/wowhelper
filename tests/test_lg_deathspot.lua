-- Round 4 item 5 (research\re_round4.md R5): the spot you died at is saved at PLAYER_DEAD (not in instances)
-- and the corpse arrow falls back to it when the game gives no corpse position; at the corpse, "Resurrect in
-- N s" from GetCorpseRecoveryDelay; the arrow goes red (behind) -> yellow -> green (ahead) with an "exact"
-- colour straight ahead; an optional arrival sound (off by default, a button on the guide) plays once per
-- arrival. ADDON_PATH = LevelGuide.
local M = dofile("lg_mock.lua")
LevelGuideDB = { characters = { ["Juan-R"] = { done = {}, skips = {}, visited = {} } } }
local inInstance, delay, sounds = false, 0, {}
IsInInstance = function() return inInstance end
GetCorpseRecoveryDelay = function() return delay end
SOUNDKIT = { UI_MAP_WAYPOINT_SUPER_TRACK_ON = 1234, RAID_WARNING = 8959 }
PlaySound = function(id) sounds[#sounds + 1] = id end
GetUnitSpeed = function() return 0, 7 end
M.best, M.pos, M.level = 1438, { [1438] = { 0.30, 0.30 } }, 6
M.load(ADDON_PATH, function()
    LevelGuideRoutes.chains.NightElf = { { zone = "Teldrassil", min = 1, max = 60, steps = {
        { t = "accept", q = "Far Away", npc = "Giver", x = 90, y = 90, lvl = 5 },
    } } }
    LevelGuideQuestIDs = { ids = {}, renamed = {} }
    LevelGuidePrereqs = {}
end)
local P = LevelGuidePlanner
local arrowTex = M.frame.tex
arrowTex.SetVertexColor = function(self, r, g, b) self.color = { r, g, b } end
local function yards() return M.yardsFont and M.yardsFont.text or "" end
-- The arrow's distance line is the font right under the arrow: find it by its text later.
local function corpseLine()
    for _, f in ipairs(M.fonts) do
        if f.text:find("Corpse", 1, true) or f.text:find("Resurrect", 1, true) or f.text:find("Your corpse", 1, true) then
            return f.text
        end
    end
    return ""
end

-- 1. The colour maths: straight ahead the exact colour, behind red, sideways yellow.
local er, eg, eb = P.ArrowColor(0)
local ar, ag, ab = P.ArrowColor(0.1)
assert(not (er == ar and eg == ag and eb == ab), "exact colour differs from 'nearly ahead'")
assert(ag > 0.9 and ar < 0.6, "nearly ahead is green: " .. ar .. "," .. ag)
local br, bg = P.ArrowColor(math.pi)
assert(br > 0.9 and bg < 0.3, "behind is red: " .. br .. "," .. bg)
local sr, sg = P.ArrowColor(-math.pi / 2)
assert(sr > 0.9 and sg > 0.7, "sideways is yellow: " .. sr .. "," .. sg)
local mr, mg = P.ArrowColor(3 * math.pi / 4)
assert(mr > 0.9 and mg > 0.3 and mg < 0.7, "between behind and sideways is orange: " .. mg)
print("1 ok")

-- 2. Dying outdoors saves the spot (per character); in an instance it doesn't.
M.fire("PLAYER_DEAD")
local spot = M.char.deathSpot
assert(spot and spot.map == 1438 and math.abs(spot.x - 0.3) < 1e-9 and math.abs(spot.y - 0.3) < 1e-9, "death spot saved")
M.char.deathSpot = nil
inInstance = true
M.fire("PLAYER_DEAD")
assert(not M.char.deathSpot, "not saved in an instance")
inInstance = false
M.fire("PLAYER_DEAD")
assert(M.char.deathSpot, "saved again outdoors")
print("2 ok")

-- 3. A ghost with no corpse position from the game: the arrow points at the saved spot (707 yd away).
M.ghost, M.corpse = true, nil
M.pos = { [1438] = { 0.40, 0.40 } }
M.update()
M.update(0.06)
assert(corpseLine():find("Corpse 70%d yd"), "saved spot used: " .. corpseLine())
assert(M.arrowShown(), "arrow shown")
-- The game's position wins when it has one.
M.corpse = { map = 1438, x = 0.5, y = 0.5 }
M.update(0.06)
assert(corpseLine():find("Corpse 70%d yd") and M.arrowShown(), "API corpse (also ~707 yd): " .. corpseLine())
M.corpse = { map = 1438, x = 0.4, y = 0.6 }
M.update(0.06)
assert(corpseLine():find("Corpse 1000 yd") or corpseLine():find("Corpse 999 yd"), "API position used: " .. corpseLine())
M.corpse = nil
print("3 ok")

-- 4. At the corpse: "Resurrect in N s" while the game makes you wait, then "Your corpse". No sound (off).
delay = 12
M.pos = { [1438] = { 0.30, 0.30 } }
M.update(0.06)
assert(corpseLine():find("Resurrect in 12 s", 1, true), "wait shown: " .. corpseLine())
delay = 0
M.update(0.06)
assert(corpseLine():find("Your corpse", 1, true), "ready: " .. corpseLine())
assert(#sounds == 0, "arrival sound is off by default")
print("4 ok")

-- 5. The sound button turns the arrival sound on; one sound per arrival, not every frame.
local soundButton
for _, f in ipairs(M.frames) do
    if f.kind == "Button" and f.text == "Snd" then soundButton = f end
end
assert(soundButton, "sound button on the guide")
soundButton.scripts.OnClick(soundButton)
assert(LevelGuideDB.arrivalSound == true, "saved on")
M.pos = { [1438] = { 0.40, 0.40 } }
M.update(0.06)
M.pos = { [1438] = { 0.30, 0.30 } }
M.update(0.06)
M.update(0.06)
M.update(0.06)
assert(#sounds == 1 and sounds[1] == 1234, "one sound on arrival: " .. #sounds)
M.pos = { [1438] = { 0.40, 0.40 } }
M.update(0.06)
M.pos = { [1438] = { 0.30, 0.30 } }
M.update(0.06)
assert(#sounds == 2, "again on the next arrival")
print("5 ok")

-- 6. The arrow colour follows the gradient: target straight north, facing north -> exact colour.
M.pos = { [1438] = { 0.30, 0.50 } }
M.update(0.06)
local c = arrowTex.color
assert(c and c[1] == er and c[2] == eg and c[3] == eb, "exact colour straight ahead")
-- Facing south: red.
GetPlayerFacing = function() return math.pi end
M.update(0.06)
c = arrowTex.color
assert(c[1] > 0.9 and c[2] < 0.3, "red when behind")
GetPlayerFacing = function() return 0 end
print("6 ok")

-- 7. Alive again: the saved spot is cleared (PLAYER_UNGHOST, or PLAYER_ALIVE when not a ghost).
M.fire("PLAYER_ALIVE")   -- releasing your spirit fires this too, while a ghost: keep the spot
assert(M.char.deathSpot, "kept on release")
M.ghost = false
M.fire("PLAYER_UNGHOST")
assert(not M.char.deathSpot, "cleared when alive")
M.fire("PLAYER_DEAD")
M.fire("PLAYER_ALIVE")   -- resurrected where you lay
assert(not M.char.deathSpot, "cleared by a resurrection")
M.update(0.06)
assert(#M.handled == 0, "clean: " .. tostring(M.handled[1]))
print("ALL TESTS PASSED")
