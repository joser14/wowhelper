-- Personal location corrections (research\guides_deep_re.md 12.16): Ctrl+right-click a step opens a small card;
-- "It's here" saves where you stand as that step's spot for this character, used over the route's data (also
-- after the data changes) until "Restore"; at most 200 are kept. ADDON_PATH = LevelGuide.
local M = dofile("lg_mock.lua")
LevelGuideDB = { characters = { ["Juan-R"] = { done = {}, skips = {}, visited = {} } } }
M.best, M.pos, M.level = 1438, { [1438] = { 0.52, 0.52 } }, 6
local R
M.load(ADDON_PATH, function()
    R = { zone = "Teldrassil", min = 1, max = 20, steps = {
        { t = "accept", q = "Q1", npc = "Giver A", x = 50, y = 50, lvl = 5 },
    } }
    LevelGuideRoutes.chains.NightElf = { R }
    LevelGuideQuestIDs = { ids = {}, renamed = {} }
    LevelGuidePrereqs = {}
end)
local ctrl = false
IsControlKeyDown = function() return ctrl end
local function card() return LevelGuideSpotCard and LevelGuideSpotCard.shown and LevelGuideSpotCard end
M.update()
assert(math.abs(M.current.step.x - 0.5) < 1e-9, "the route's spot first")

-- 1. Ctrl+right-click: the card; "It's here" saves where you stand.
ctrl = true
M.current.scripts.OnClick(M.current, "RightButton")
ctrl = false
assert(card() and LevelGuideSpotCard.message.text:find("Giver A", 1, true), "card for the step")
LevelGuideSpotHere.scripts.OnClick(LevelGuideSpotHere)
M.update()
local key = "Teldrassil|accept|Q1||Giver A"
local saved = M.char.spots and M.char.spots[key]
assert(saved and saved.map == 1438 and math.abs(saved.x - 0.52) < 1e-9 and math.abs(saved.ox - 0.5) < 1e-9, "saved with the original")
assert(math.abs(M.current.step.x - 0.52) < 1e-9 and math.abs(M.current.step.y - 0.52) < 1e-9, "used over the data")
assert(tostring(M.current.step.detail):find("your spot", 1, true), "says so: " .. tostring(M.current.step.detail))
print("1 ok")

-- 2. The route's data changes: your spot still wins.
R.steps[1].x = 45
M.update()
assert(math.abs(M.current.step.x - 0.52) < 1e-9, "re-applied after a data change")
print("2 ok")

-- 3. Restore: the route's spot again.
ctrl = true
M.current.scripts.OnClick(M.current, "RightButton")
ctrl = false
LevelGuideSpotRestore.scripts.OnClick(LevelGuideSpotRestore)
M.update()
assert(M.char.spots[key] == nil and math.abs(M.current.step.x - 0.45) < 1e-9, "restored")
print("3 ok")

-- 4. At most 200 are kept (the oldest go).
for i = 1, 205 do M.char.spots["Teldrassil|old|" .. i] = { map = 1438, x = 0.1, y = 0.1, t = i } end
ctrl = true
M.current.scripts.OnClick(M.current, "RightButton")
ctrl = false
LevelGuideSpotHere.scripts.OnClick(LevelGuideSpotHere)
local count = 0
for _ in pairs(M.char.spots) do count = count + 1 end
assert(count == 200 and M.char.spots[key] and M.char.spots["Teldrassil|old|1"] == nil, "capped: " .. count)
assert(#M.handled == 0, "clean: " .. tostring(M.handled[1]))
print("ALL TESTS PASSED")
