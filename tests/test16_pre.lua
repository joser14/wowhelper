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