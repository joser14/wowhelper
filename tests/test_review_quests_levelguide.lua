-- Review fixes for LevelGuide. ADDON_PATH is the repo root.
local base = ADDON_PATH .. "/LevelGuide"
local frames, handled = {}, {}
FONTS = {}
local function newRegion(kind)
    local r = { kind = kind, shown = true, scripts = {}, text = "", rotation = 0 }
    function r:SetText(t) self.text = t end
    function r:SetScript(s, f) self.scripts[s] = f end
    function r:Show() self.shown = true end
    function r:Hide() self.shown = false end
    function r:SetShown(v) self.shown = v and true or false end
    function r:IsShown() return self.shown end
    function r:SetRotation(a) self.rotation = a end
    function r:GetStringHeight() return 12 end
    function r:CreateFontString() local f = newRegion("font"); FONTS[#FONTS + 1] = f; return f end
    function r:CreateTexture() local t = newRegion("texture"); rawset(r, "tex", t); return t end
    return setmetatable(r, { __index = function(_, k)
        if k == "step" or k == "tex" then return nil end
        return function() end
    end })
end
CreateFrame = function(kind, name)
    local f = newRegion(kind)
    frames[#frames + 1] = f
    if name then _G[name] = f end
    return f
end
UIParent = newRegion("Frame")
local SECRET = 4242.5
issecretvalue = function(v) return v == SECRET end
geterrorhandler = function() return function(e) handled[#handled + 1] = tostring(e) end end
UnitLevel = function() return 10 end
UnitXP = function() return 0 end
UnitXPMax = function() return 400 end
UnitName = function() return "Juan" end
GetRealmName = function() return "R" end
UnitRace = function() return "Night Elf", "NightElf" end
local px, py = 0.5, 0.5
local secretWorld = false
local function vec(x, y) return { GetXY = function() return x, y end } end
CreateVector2D = vec
C_Map = {
    GetBestMapForUnit = function() return 57 end,
    GetMapInfo = function(id)
        if id == 57 then return { name = "Teldrassil", mapType = 3, parentMapID = 12 } end
        if id == 12 then return { name = "Kalimdor", mapType = 2, parentMapID = 0 } end
    end,
    GetPlayerMapPosition = function(id) if id == 57 then return vec(px, py) end end,
    GetWorldPosFromMapPos = function(_, p)
        local x, y = p:GetXY()
        if secretWorld and x == 0 and y == 0 then return 0, vec(SECRET, SECRET) end
        return 0, vec(x * 3000, y * 3000)
    end,
}
GetPlayerFacing = function() return 0 end
local log = {}
C_QuestLog = {
    GetNumQuestLogEntries = function() return #log end,
    GetInfo = function(i) return log[i] end,
    IsComplete = function(id) for _, q in ipairs(log) do if q.questID == id then return q.ready end end end,
    ReadyForTurnIn = function() return false end,
    GetQuestObjectives = function() return {} end,
    GetTitleForQuestID = function() return nil end,
    IsQuestTrivial = function() return false end,
    GetQuestsOnMap = function() return QUESTS_ON_MAP or {} end,
    IsQuestFlaggedCompleted = function() return false end,
}

-- A route whose next move is written on another zone's map (Routes.lua On(), like Duskwood's Sven leg in
-- Wetlands): while you stand in the route's zone that move has no point here.
LevelGuideRoutes = { chains = { NightElf = { {
    zone = "Teldrassil", min = 1, max = 20,
    steps = {
        { t = "go", text = "Fly back from Menethil", x = 9.5, y = 59.7, lvl = 10, map = "Wetlands" },
        { t = "accept", q = "Next Quest", npc = "Someone", x = 40, y = 40, lvl = 10 },
    },
} } }, plan = {} }

assert(loadfile(base .. "/LevelGuide.lua"))("LevelGuide", {})
local events = frames[1]
events.scripts.OnEvent(events, "PLAYER_LOGIN")
local frame = LevelGuideFrame
local function update(t) frame.scripts.OnUpdate(frame, t or 2.1) end

local buttons = {}
for _, f in ipairs(frames) do if f.kind == "Button" and rawget(f, "left") then buttons[#buttons + 1] = f end end
local current = buttons[1]

-- 1. A map corner whose world position comes back secret: the map's size can't be worked out, so no
-- yards are shown (the scale is read once per map, so this runs first).
log = { { questID = 501, title = "Off Route" } }
QUESTS_ON_MAP = { { questID = 501, x = 0.52, y = 0.5 } }
local route = LevelGuideRoutes.chains.NightElf[1]
local moveFirst = route.steps
route.steps = { { t = "accept", q = "Next Quest", npc = "Someone", x = 40, y = 40, lvl = 10 } }
secretWorld = true
update()
update()
assert(#handled == 0, "secret world positions: " .. tostring(handled[1]))
local rows = 0
for i = 2, 4 do
    if buttons[i].shown then
        rows = rows + 1
        assert(not buttons[i].right.text:find("yd", 1, true), "no yards from secret positions: " .. buttons[i].right.text)
    end
end
assert(rows > 0, "steps listed")
secretWorld = false

-- 2. A quest in your log the route doesn't know joins the pool, so the list is routed by distance; the
-- move with no point on this map must not break that.
route.steps = moveFirst
update()
update()
assert(#handled == 0, "a move with no point on this map must not break the route: " .. tostring(handled[1]))
assert(current.left.text:find("Fly back from Menethil", 1, true), "the move still comes first: " .. current.left.text)
local found = false
for i = 2, 4 do if buttons[i].shown and buttons[i].left.text:find("Off Route", 1, true) then found = true end end
assert(found, "the off-route quest is still listed")
print("ALL TESTS PASSED")
