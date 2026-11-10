-- Shared mock for the tests\test_lg_*.lua LevelGuide tests: a Classic-shaped Kalimdor where Darnassus (1457)
-- is its own zone under the continent, as on Forever, not a child of Teldrassil (1438). ADDON_PATH is the
-- LevelGuide folder. Returns a table of knobs (M) the test changes.
local M = { frames = {}, handled = {}, fonts = {}, tip = {} }
M.best = 1438
M.pos = { [1438] = { 0.56, 0.6 } }   -- player position on its best map
M.level, M.xp, M.class = 11, 0, "PRIEST"
M.log, M.obj, M.titles, M.flagged, M.items, M.spells, M.slots = {}, {}, {}, {}, {}, {}, { [0] = 16 }
M.now = 100
M.bind = "Dolanaar"
M.ghost, M.corpse = false, nil
M.npcGUID = nil
M.trainerType = 0

local function newRegion(kind)
    local r = { kind = kind, shown = true, scripts = {}, text = "", rotation = 0 }
    function r:SetText(t) self.text = t; if kind == "GameTooltip" then M.tip = { t } end end
    function r:AddLine(t) if kind == "GameTooltip" then M.tip[#M.tip + 1] = t end end
    function r:SetScript(s, f) self.scripts[s] = f end
    function r:Show() self.shown = true end
    function r:Hide() self.shown = false end
    function r:SetShown(v) self.shown = v and true or false end
    function r:IsShown() return self.shown end
    function r:SetRotation(a) self.rotation = a end
    function r:GetStringHeight() return 12 end
    function r:CreateFontString() local f = newRegion("font"); M.fonts[#M.fonts + 1] = f; return f end
    function r:CreateTexture() local t = newRegion("texture"); rawset(r, "tex", t); return t end
    return setmetatable(r, { __index = function(_, k)
        if k == "step" or k == "tex" or k == "routeIndex" or k == "why" or k == "state" then return nil end
        return function() end
    end })
end
CreateFrame = function(kind, name)
    local f = newRegion(kind)
    M.frames[#M.frames + 1] = f
    if name then _G[name] = f end
    return f
end
UIParent = newRegion("Frame")
issecretvalue = function() return false end
geterrorhandler = function() return function(e) M.handled[#M.handled + 1] = tostring(e) end end
GetTime = function() return M.now end
UnitLevel = function() return M.level end
UnitXP = function() return M.xp end
UnitXPMax = function() return 1000 end
UnitName = function(unit) if unit == "npc" then return M.npcName end return "Juan" end
UnitGUID = function(unit) if unit == "npc" then return M.npcGUID end return nil end
GetRealmName = function() return "R" end
UnitRace = function() return "Night Elf", "NightElf" end
UnitClass = function() return "Priest", M.class end
local function vec(x, y) return { x = x, y = y, GetXY = function() return x, y end } end
CreateVector2D = vec
-- Map rectangles on Kalimdor's world plane (world = origin + map percent * size).
M.rects = {
    [1438] = { 0, 0, 5000, 5000 },        -- Teldrassil
    [1457] = { 1250, 2000, 750, 1250 },   -- Darnassus, inside Teldrassil's x 25-40%, y 40-65%
    [1439] = { 6000, 2000, 4000, 6000 },  -- Darkshore
}
M.info = {
    [1438] = { mapID = 1438, name = "Teldrassil", mapType = 3, parentMapID = 1414 },
    [1457] = { mapID = 1457, name = "Darnassus", mapType = 3, parentMapID = 1414 },
    [1439] = { mapID = 1439, name = "Darkshore", mapType = 3, parentMapID = 1414 },
    [1414] = { mapID = 1414, name = "Kalimdor", mapType = 2, parentMapID = 947 },
    [947] = { mapID = 947, name = "Azeroth", mapType = 1, parentMapID = 946 },
}
C_Map = {
    GetBestMapForUnit = function() return M.best end,
    GetMapInfo = function(id) return M.info[id] end,
    GetMapChildrenInfo = function(id, _, all)
        local list = {}
        for childID, info in pairs(M.info) do
            if info.parentMapID == id or (all and id == 947 and info.mapType == 3) then
                list[#list + 1] = info
            end
        end
        return list
    end,
    -- Like the client: a position only on the map you're on (and its parents are left out here).
    GetPlayerMapPosition = function(id)
        local p = M.pos[id]
        if id == M.best and p then return vec(p[1], p[2]) end
    end,
    GetWorldPosFromMapPos = function(id, p)
        local r = M.rects[id]
        if not r then return nil end
        local x, y = p:GetXY()
        return 1, vec(r[1] + x * r[3], r[2] + y * r[4])
    end,
}
C_Map.SetUserWaypoint = function(p) M.waypoint = p end
UiMapPoint = { CreateFromCoordinates = function(m, x, y) return { m = m, x = x, y = y } end }
C_SuperTrack = { SetSuperTrackedQuestID = function() end, SetSuperTrackedUserWaypoint = function() end }
GetPlayerFacing = function() return 0 end
GetBindLocation = function() return M.bind end
C_Item = { GetItemCount = function(id) return M.items[id] or 0 end }
C_SpellBook = { IsSpellKnown = function(id) return M.spells[id] or false end }
C_Container = { GetContainerNumSlots = function(bag) return M.slots[bag] or 0 end }
C_Trainer = { GetTrainerType = function() return M.trainerType end }
Enum = { FlightPathState = { Current = 0, Reachable = 1, Unreachable = 2 }, TrainerType = { General = 0, Tradeskill = 1 } }
GetSubZoneText = function() return M.subzone or "" end
C_TaxiMap = { GetAllTaxiNodes = function() return M.taxi or {} end }
ERR_NEWTAXIPATH = "New flight path discovered!"
UnitIsGhost = function() return M.ghost end
C_DeathInfo = { GetCorpseMapPosition = function(m) if M.corpse and M.corpse.map == m then return vec(M.corpse.x, M.corpse.y) end end }
C_QuestLog = {
    GetNumQuestLogEntries = function() return #M.log end,
    GetInfo = function(i) return M.log[i] end,
    IsComplete = function(id) for _, q in ipairs(M.log) do if q.questID == id then return q.ready end end end,
    ReadyForTurnIn = function() return false end,
    GetQuestObjectives = function(id) return M.obj[id] or {} end,
    GetTitleForQuestID = function(id) return M.titles[id] end,
    IsQuestTrivial = function() return false end,
    GetQuestsOnMap = function() return {} end,
    IsQuestFlaggedCompleted = function(id) return M.flagged[id] or false end,
    GetAllCompletedQuestIDs = function() local t = {} for id in pairs(M.flagged) do t[#t + 1] = id end return t end,
}

function M.load(base, setup)
    assert(loadfile(base .. "/QuestIDs.lua"))("LevelGuide", {})
    assert(loadfile(base .. "/Prereqs.lua"))("LevelGuide", {})
    assert(loadfile(base .. "/Routes.lua"))("LevelGuide", {})
    if setup then setup() end
    assert(loadfile(base .. "/LevelGuide.lua"))("LevelGuide", {})
    M.events = M.frames[1]
    M.events.scripts.OnEvent(M.events, "PLAYER_LOGIN")
    M.frame = LevelGuideFrame
    M.buttons = {}
    for _, f in ipairs(M.frames) do
        if f.kind == "Button" and rawget(f, "left") then M.buttons[#M.buttons + 1] = f end
    end
    M.current = M.buttons[1]
    M.char = select(2, next(LevelGuideDB.characters))
end
function M.update(t) M.frame.scripts.OnUpdate(M.frame, t or 2.1) end
function M.fire(...) M.events.scripts.OnEvent(M.events, ...) end
function M.arrowShown() return M.frame.tex and M.frame.tex.shown end
function M.font(pattern) for _, f in ipairs(M.fonts) do if f.text:find(pattern, 1, true) then return f end end end
-- Marks quests done by title (both the saved count and the game's own completed list).
function M.done(list)
    for title, count in pairs(list) do
        local ids = LevelGuideQuestIDs.ids[title]
        for part = 1, count do
            if ids and ids[part] then M.flagged[ids[part]] = true end
        end
    end
end
return M
