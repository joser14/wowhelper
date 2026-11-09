IsShiftKeyDown = function() return true end -- skips need Shift now
-- Route mode, on the real Routes.lua. ADDON_PATH is the LevelGuide folder.
local base = ADDON_PATH
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
GameTooltip = newRegion("Frame")
issecretvalue = function() return false end
geterrorhandler = function() return function(e) handled[#handled + 1] = tostring(e) end end
local level = 1
UnitLevel = function() return level end
UnitXP = function() return 0 end
UnitXPMax = function() return 400 end
UnitName = function() return "Juan" end
GetRealmName = function() return "R" end
local race = "NightElf"
UnitRace = function() return "Night Elf", race end
local zone = "Teldrassil"
local px, py = 0.587, 0.443
local function vec(x, y) return { GetXY = function() return x, y end } end
CreateVector2D = vec
C_Map = {
    GetBestMapForUnit = function() return 101 end,
    GetMapInfo = function(id)
        if id == 101 then return { name = "Shadowthread Cave", mapType = 5, parentMapID = 57 } end
        if id == 57 then return { name = zone, mapType = 3, parentMapID = 12 } end
        if id == 12 then return { name = "Kalimdor", mapType = 2, parentMapID = 0 } end
    end,
    GetPlayerMapPosition = function(id) if id == 57 then return vec(px, py) end end,
    GetWorldPosFromMapPos = function(_, p) local x, y = p:GetXY(); return 0, vec(x * 3000, y * 3000) end,
}
local waypoint
C_Map.SetUserWaypoint = function(p) waypoint = p end
UiMapPoint = { CreateFromCoordinates = function(m, x, y) return { m = m, x = x, y = y } end }
local superTracked
C_SuperTrack = { SetSuperTrackedQuestID = function(id) superTracked = id end, SetSuperTrackedUserWaypoint = function() end }
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
    IsQuestFlaggedCompleted = function(id) return FLAGGED and FLAGGED[id] or false end,
}

assert(loadfile(base .. "/Routes.lua"))("LevelGuide", {})
assert(loadfile(base .. "/LevelGuide.lua"))("LevelGuide", {})
local events = frames[1]
events.scripts.OnEvent(events, "PLAYER_LOGIN")
local frame = LevelGuideFrame
local function update(t) frame.scripts.OnUpdate(frame, t or 2.1) end
update()
assert(#handled == 0, "clean: " .. tostring(handled[1]))
local buttons = {}
for _, f in ipairs(frames) do if f.kind == "Button" and rawget(f, "left") then buttons[#buttons + 1] = f end end
local current = buttons[1]
local function all() local t = { current.left.text }; for i = 2, 4 do if buttons[i].shown then t[#t + 1] = buttons[i].left.text end end; return table.concat(t, "\n") end
local function header() for _, f in ipairs(FONTS) do if f.text:find("Route:", 1, true) or f.text:find("Guide", 1, true) then return f.text end end end

-- Juan in Dolanaar (screenshot 5), on the rebuilt Forever route with real quest IDs and prerequisites.
assert(loadfile(base .. "/QuestIDs.lua"))("LevelGuide", {})
assert(loadfile(base .. "/Prereqs.lua"))("LevelGuide", {})
local function have(id, title, ready) log[#log + 1] = { questID = id, title = title, ready = ready } end
local ids = LevelGuideQuestIDs.ids
local function id(title, part) return ids[title] and ids[title][part or 1] end
-- Everything before Dolanaar is done in the game's record.
FLAGGED = {}
for _, title in ipairs({ "The Balance of Nature", "The Woodland Protector", "Nature's Call", "The Goddess Provides",
    "A Good Friend", "A Friend in Need", "Iverron's Antidote", "Webwood Venom", "Webwood Egg", "Fang of Githyiss",
    "Tenaron's Summons", "Dolanaar Delivery" }) do
    for _, questID in ipairs(ids[title] or {}) do FLAGGED[questID] = true end
end
for part = 1, 2 do FLAGGED[id("Crown of the Earth", part)] = true end
level = 6
log = {}
have(id("Denalan's Earth"), "Denalan's Earth", true)
have(id("A Troubling Breeze"), "A Troubling Breeze", true)
have(id("The Lost Runner"), "The Lost Runner", true)
have(id("The Sisterhood of Elune"), "The Sisterhood of Elune", true)
have(id("Soft Saber Pelts"), "Soft Saber Pelts")
have(9001, "Garments of the Moon")
have(id("Crown of the Earth", 3), "Crown of the Earth")
have(id("The Road to Darnassus"), "The Road to Darnassus")
have(id("Camping 101: Cooking"), "Camping 101: Cooking")
have(id("Camping 101: Skinning"), "Camping 101: Skinning")
QUESTS_ON_MAP = { { questID = 9001, x = 0.556, y = 0.566 } }
px, py = 0.554, 0.568
update()
update()
local text = all()
print(text)
assert(header():find("Route: Teldrassil", 1, true), "route: " .. tostring(header()))
for _, title in ipairs({ "Denalan's Earth", "A Troubling Breeze", "The Lost Runner", "The Sisterhood of Elune",
    "Soft Saber Pelts", "Crown of the Earth", "The Road to Darnassus", "Camping 101" }) do
    assert(not text:find("Pick up:|r " .. title, 1, true), "already have " .. title .. ": " .. text)
end
assert(not text:find("Great Tree Provides", 1, true), "level 10 pick-up not yet: " .. text)
assert(text:find("Garments of the Moon", 1, true), "off-route quest from the log shows: " .. text)
assert(#handled == 0, "clean: " .. tostring(handled[1]))

-- Route data sanity on the real file.
for _, chain in pairs(LevelGuideRoutes.chains) do
    for _, route in ipairs(chain) do
        for index, step in ipairs(route.steps) do
            local where = route.zone .. " #" .. index
            -- Utility steps (home, fp, zone, item, train, xp) joined the quest steps in this version.
            local TYPES = { accept = true, ["do"] = true, turnin = true, go = true,
                home = true, fp = true, zone = true, item = true, train = true, xp = true }
            assert(TYPES[step.t], where .. " type")
            if step.t == "home" or step.t == "fp" then assert(step.place and step.npc, where .. " place/npc") end
            if step.t == "item" then assert(type(step.item) == "number" and step.count, where .. " item") end
            if step.t == "xp" then assert(step.level and step.frac and step.frac >= 0 and step.frac < 1, where .. " xp") end
            if step.pts then for _, p in ipairs(step.pts) do assert(p[1] > 0 and p[1] < 100 and p[2] > 0 and p[2] < 100, where .. " point") end end
            assert((step.q or step.text) and step.x and step.y and step.lvl, where .. " fields")
            assert(step.x > 0 and step.x < 100 and step.y > 0 and step.y < 100, where .. " coordinates")
            if step.t == "accept" or step.t == "turnin" then assert(step.npc, where .. " npc") end
        end
    end
end
print("ALL TESTS PASSED")