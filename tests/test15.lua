IsShiftKeyDown = function() return true end -- skips need Shift now
GetTime = GetTime or function() return 0 end
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
local function header() for _, f in ipairs(FONTS) do if f.text:find("Route:", 1, true) or f.text:find("Guide", 1, true) then return f.text end end end

-- A fresh Night Elf starts at the top of Teldrassil, in a cave map that reports up to the zone.
assert(header():find("Route: Teldrassil", 1, true), "route header: " .. tostring(header()))
assert(current.left.text:find("Pick up:|r The Balance of Nature", 1, true), "first step: " .. current.left.text)
local arrow = frame.tex
assert(arrow and current.step.mapID == 57, "steps sit on the zone map")
assert(all():find("The Woodland Protector", 1, true), "next steps: " .. all())

-- Accepting it moves on; the log is the source of truth.
local function have(id, title, ready) log[#log + 1] = { questID = id, title = title, ready = ready } end
have(1, "The Balance of Nature")
update()
assert(current.left.text:find("Pick up:|r The Woodland Protector", 1, true), "after accepting: " .. current.left.text)
have(2, "The Woodland Protector", true)
-- Standing by Tarindrella, her turn-in beats walking off to the boars.
px, py = 0.578, 0.452
update()
assert(current.left.text:find("Turn in:|r The Woodland Protector", 1, true), "turn-in next: " .. current.left.text)
assert(current.step.detail == "To Tarindrella", "who to: " .. tostring(current.step.detail))
-- Turning in part 1, then the same title again is part 2.
events.scripts.OnEvent(events, "QUEST_TURNED_IN", 2)
table.remove(log, 2)
update()
assert(current.left.text:find("Pick up:|r The Woodland Protector", 1, true), "part 2 pick-up: " .. current.left.text)
have(3, "The Woodland Protector")
update()
assert(current.left.text:find("Pick up:|r Nature's Call", 1, true), "part 2 in log counts as accepted: " .. current.left.text)
assert(LevelGuideDB.characters["Juan-R"].done["The Woodland Protector"] == 1, "turn-ins counted per character")

-- Skipping a step with a right-click, and bringing it back.
current.scripts.OnClick(current, "RightButton")
update()
assert(not current.left.text:find("Nature's Call", 1, true), "skipped")
local headerButton
for _, f in ipairs(frames) do if f.scripts.OnDragStart then headerButton = f end end
headerButton.scripts.OnClick(headerButton)
update()
assert(current.left.text:find("Nature's Call", 1, true), "unskipped")

-- Marking: an unaccepted step pins its coordinates.
current.scripts.OnClick(current, "LeftButton")
assert(waypoint and math.abs(waypoint.x - 0.578) < 0.001 and waypoint.m == 57, "pins the NPC")

-- A quest in the log is tracked by the game instead.
have(4, "Nature's Call")
update()
current.scripts.OnClick(current, "LeftButton")
assert(superTracked == 1, "do step marks the quest in your log: " .. tostring(superTracked) .. " " .. current.left.text)

-- Walking to a "go" step finishes it.
LevelGuideDB.characters["Juan-R"].skips = {}
level = 5
log = {}
for i = 1, 30 do LevelGuideDB.characters["Juan-R"].skips["Teldrassil#" .. i] = true end
update()
assert(current.left.text:find("Go to:|r Githyiss", 1, true), "go step: " .. current.left.text)
px, py = 0.569, 0.263
update(0.06)
update()
assert(not current.left.text:find("Githyiss", 1, true), "arrival completes it: " .. current.left.text)

-- Outleveled steps are treated as done, so a route can start midway.
level = 10
update()
assert(not all():find("Balance of Nature", 1, true), "outleveled")
assert(current.step.routeKey, "still on the route")

-- In another zone the route says where to go.
zone = "Darkshore"
update()
assert(current.left.text:find("Go to:|r Teldrassil", 1, true), "route zone elsewhere: " .. current.left.text)
zone = "Teldrassil"

-- Every bracket to 60 has a route now, chosen for your level, never a zone far above you.
for _, at in ipairs({ 21, 30, 38, 44, 50, 55, 59 }) do
    level = at
    update()
    local text = header()
    assert(text:find("Route:", 1, true), "route at " .. at .. ": " .. tostring(text))
    local zoneName = text:match("Route: (.-)  ")
    local found
    for _, route in ipairs(LevelGuideRoutes.chains.NightElf) do
        if route.zone == zoneName then found = route end
    end
    assert(found and at <= found.max and at >= found.min - 2, "fits level " .. at .. ": " .. tostring(zoneName))
end
-- With every route done, the plan still names zones.
local saved = LevelGuideRoutes.chains.NightElf
LevelGuideRoutes.chains.NightElf = {}
level = 30
update()
assert(current.left.text:find("Duskwood or Hillsbrad Foothills or Wetlands", 1, true), "plan: " .. current.left.text)
LevelGuideRoutes.chains.NightElf = saved

-- Gnomes and dwarves get Dun Morogh; humans have only the plan.
race, level = "Gnome", 9
update()
assert(header():find("Route: Dun Morogh", 1, true), "gnome route: " .. tostring(header()))
race = "Human"
level = 5
update()
assert(not header():find("Route:", 1, true), "human: plan only")
assert(#handled == 0, "clean: " .. tostring(handled[1]))

-- Optimizing: what you can do now, nearby, comes first; the written order still guides the rest.
race, level, zone = "NightElf", 5, "Teldrassil"
local realChain = LevelGuideRoutes.chains.NightElf
LevelGuideRoutes.chains.NightElf = { { zone = "Teldrassil", min = 1, max = 10, steps = {
    { t = "do", q = "Far Task", note = "far", x = 80, y = 80, lvl = 5 },
    { t = "accept", q = "Later Quest", npc = "Giver", x = 20, y = 20, lvl = 9 },
    { t = "do", q = "Near Task", note = "near", x = 31, y = 30, lvl = 5 },
    { t = "turnin", q = "Ready One", npc = "Turnin NPC", x = 40, y = 30, lvl = 5 },
    { t = "accept", q = "Part Two", npc = "Chain NPC", x = 30, y = 31, lvl = 5, part = 2 },
    { t = "go", text = "Move on to the next camp", x = 90, y = 10, lvl = 5 },
    { t = "do", q = "After The Move", note = "beyond", x = 30, y = 30, lvl = 5 },
} } }
LevelGuideDB.characters["Juan-R"].skips = {}
log = {}
have(201, "Far Task")
have(202, "Near Task")
have(203, "Ready One", true)
have(204, "After The Move")
px, py = 0.30, 0.30
update()
local order = {}
for i = 1, 4 do if buttons[i].shown or i == 1 then order[#order + 1] = buttons[i].left.text end end
local text = table.concat(order, "\n")
assert(current.left.text:find("Near Task", 1, true), "nearest doable first: " .. text)
assert(text:find("Ready One", 1, true) and text:find("Far Task", 1, true), "both kept: " .. text)
assert(text:find("Ready One", 1, true) < text:find("Far Task", 1, true), "nearby turn-in before the far task: " .. text)
assert(not text:find("After The Move", 1, true), "a go step holds back what's beyond it")
assert(not text:find("Later Quest", 1, true) or text:find("Later Quest", 1, true) > text:find("Far Task", 1, true),
    "a quest above your level waits: " .. text)
assert(not text:find("Part Two", 1, true) or text:find("Part Two", 1, true) > text:find("Ready One", 1, true),
    "part 2 waits for part 1: " .. text)
-- Walking toward the far task flips the order.
px, py = 0.79, 0.79
update()
assert(current.left.text:find("Far Task", 1, true), "follows you: " .. current.left.text)
LevelGuideRoutes.chains.NightElf = realChain
assert(#handled == 0, "clean: " .. tostring(handled[1]))

-- Juan's real case: quests done before the addon was installed. Holding Webwood Egg means the
-- Shadowglen pick-ups before it are behind you, even though no turn-ins were counted.
race, level, zone = "NightElf", 4, "Teldrassil"
LevelGuideDB.characters["Juan-R"].done = {}
LevelGuideDB.characters["Juan-R"].skips = {}
LevelGuideDB.characters["Juan-R"].visited = {}
log = {}
have(301, "Webwood Egg")
have(302, "The Goddess Provides")
px, py = 0.608, 0.432
update()
local juan = all()
assert(not juan:find("Pick up:|r The Woodland Protector", 1, true), "no stale pick-up: " .. juan)
assert(not juan:find("Pick up:|r The Balance of Nature", 1, true), "no stale pick-up: " .. juan)
assert(#handled == 0, "clean: " .. tostring(handled[1]))

-- The screenshot case: the guide said "Pick up Tenaron's Summons from Gilshalan", but talking to him
-- opened straight to the Webwood Egg turn-in page, so he has nothing to offer yet.
local npcName
local clock = 100
GetTime = function() return clock end
UnitName = function(unit) if unit == "npc" then return npcName end return "Juan" end
-- Juan's real saved turn-ins.
LevelGuideDB.characters["Juan-R"].done = { ["A Friend in Need"] = 1, ["A Good Friend"] = 1, ["The Balance of Nature"] = 1, ["Webwood Venom"] = 1 }
log = {}
have(401, "Webwood Egg")
have(402, "The Goddess Provides")
px, py = 0.578, 0.416
update()
assert(all():find("Pick up:|r Tenaron's Summons", 1, true), "before talking: " .. all())
npcName = "Gilshalan Windwalker"
events.scripts.OnEvent(events, "QUEST_PROGRESS")
update()
assert(not all():find("Tenaron's Summons", 1, true), "not offered, so not shown: " .. all())
-- Turning something in can unlock it, so the guide asks again.
events.scripts.OnEvent(events, "QUEST_TURNED_IN", 401)
update()
assert(all():find("Tenaron's Summons", 1, true), "back after a turn-in: " .. all())
-- A giver's list counts too: offered quests stay, the rest go.
clock = clock + 200
C_GossipInfo = { GetAvailableQuests = function() return { { title = "Tenaron's Summons" } } end }
events.scripts.OnEvent(events, "GOSSIP_SHOW")
update()
assert(all():find("Tenaron's Summons", 1, true), "offered stays: " .. all())
C_GossipInfo.GetAvailableQuests = function() return {} end
events.scripts.OnEvent(events, "GOSSIP_SHOW")
update()
assert(not all():find("Tenaron's Summons", 1, true), "an empty list hides it: " .. all())
events.scripts.OnEvent(events, "PLAYER_LEVEL_UP")
update()
assert(all():find("Tenaron's Summons", 1, true), "a level-up asks again: " .. all())
-- Opening straight to one quest's page means that's all they have.
clock = clock + 200
GetTitleText = function() return "Some Other Quest" end
events.scripts.OnEvent(events, "QUEST_DETAIL")
update()
assert(not all():find("Tenaron's Summons", 1, true), "single offer: " .. all())
UnitName = function() return "Juan" end
assert(#handled == 0, "clean: " .. tostring(handled[1]))

-- Quest IDs: the game's own completion record beats anything inferred.
LevelGuideDB.characters["Juan-R"].done = {}
LevelGuideDB.characters["Juan-R"].skips = {}
log = {}
level = 3
local flagged = {}
C_QuestLog.IsQuestFlaggedCompleted = function(id) return flagged[id] or false end
local savedIDs = LevelGuideQuestIDs
LevelGuideQuestIDs = { ids = { ["The Balance of Nature"] = { 456, 457 }, ["The Woodland Protector"] = { 458, 459 } },
    renamed = { ["Old Name"] = "New Name" } }
px, py = 0.587, 0.443
update()
assert(current.left.text:find("The Balance of Nature", 1, true), "nothing flagged yet: " .. current.left.text)
flagged[456], flagged[457], flagged[458] = true, true, true
update()
local text15 = all()
assert(not text15:find("The Balance of Nature", 1, true), "both parts done in the game's record: " .. text15)
assert(text15:find("Pick up:|r The Woodland Protector", 1, true), "part 2 of Woodland is next: " .. text15)
LevelGuideQuestIDs = savedIDs
C_QuestLog.IsQuestFlaggedCompleted = nil
assert(#handled == 0, "clean: " .. tostring(handled[1]))

-- "I don't see them on the map": with the map listing what's available, other pick-ups wait.
LevelGuideDB.characters["Juan-R"].done = { ["A Friend in Need"] = 1, ["A Good Friend"] = 1, ["The Balance of Nature"] = 1, ["Webwood Venom"] = 1 }
LevelGuideDB.characters["Juan-R"].skips = {}
log = {}
have(501, "Webwood Egg")
have(502, "The Goddess Provides")
level = 4
events.scripts.OnEvent(events, "PLAYER_LEVEL_UP") -- forget what Gilshalan offered in the block above
local mapList = { { questID = 77, questName = "Dolanaar Delivery", x = 0.6, y = 0.47 } }
C_QuestLine = { RequestQuestLinesForMap = function() end, GetAvailableQuestLines = function() return mapList end }
px, py = 0.578, 0.416
update()
local onMapText = all()
-- The map is positive evidence only: what it lists is on offer; what it doesn't list is left to the
-- giver's window and the quest's prerequisites (the map doesn't know every quest).
assert(onMapText:find("Dolanaar Delivery", 1, true), "listed on the map, so suggested: " .. onMapText)
assert(onMapText:find("The Goddess Provides", 1, true), "your own quests still show: " .. onMapText)
-- Matching by quest ID works when the map's name differs.
mapList = { { questID = 4242, questName = "Some Forever Name" } }
local savedIDs2 = LevelGuideQuestIDs
LevelGuideQuestIDs = { ids = { ["Tenaron's Summons"] = { 4242 } }, renamed = {} }
update()
assert(all():find("Tenaron's Summons", 1, true), "found by ID: " .. all())
LevelGuideQuestIDs = savedIDs2
-- No map data: the written route stands.
mapList = {}
update()
assert(all():find("Tenaron's Summons", 1, true), "fallback: " .. all())
C_QuestLine = nil
assert(#handled == 0, "clean: " .. tostring(handled[1]))

-- The second screenshot: "Pick up: Crown of the Earth from Tenaron" while Tenaron's Summons (which
-- Tenaron is waiting for) was never taken. Tenaron has nothing to give yet, so it isn't shown.
LevelGuideDB.characters["Juan-R"].done = { ["A Friend in Need"] = 1, ["A Good Friend"] = 1, ["The Balance of Nature"] = 1, ["Webwood Venom"] = 1 }
LevelGuideDB.characters["Juan-R"].skips = {}
log = {}
have(601, "Webwood Egg")
have(602, "The Goddess Provides")
level = 4
events.scripts.OnEvent(events, "PLAYER_LEVEL_UP")
npcName = "Gilshalan Windwalker"
UnitName = function(unit) if unit == "npc" then return npcName end return "Juan" end
events.scripts.OnEvent(events, "QUEST_PROGRESS") -- Gilshalan: only the Webwood Egg turn-in
UnitName = function() return "Juan" end
px, py = 0.585, 0.417
update()
local crown = all()
assert(not crown:find("Crown of the Earth", 1, true), "no pick-up from a giver still waiting on you: " .. crown)
assert(not crown:find("Tenaron's Summons", 1, true), "and not the one Gilshalan isn't offering: " .. crown)
assert(crown:find("Webwood Egg", 1, true), "your real quests lead: " .. crown)
-- Once you hold Tenaron's Summons and turn it in, Crown of the Earth appears.
have(603, "Tenaron's Summons", true)
update()
assert(all():find("Turn in:|r Tenaron's Summons", 1, true), "turn-in shows: " .. all())
events.scripts.OnEvent(events, "QUEST_TURNED_IN", 603)
log[#log] = nil
update()
assert(all():find("Pick up:|r Crown of the Earth", 1, true), "then the pick-up: " .. all())
assert(#handled == 0, "clean: " .. tostring(handled[1]))

-- The newest screenshot: "Pick up Tenaron's Summons" while Gilshalan still wants Webwood Egg.
-- With prerequisites it waits until the game's own record shows them done.
LevelGuideDB.characters["Juan-R"].done = { ["A Friend in Need"] = 1, ["A Good Friend"] = 1, ["The Balance of Nature"] = 1, ["Webwood Venom"] = 1 }
LevelGuideDB.characters["Juan-R"].skips = {}
log = {}
have(701, "Webwood Egg")
have(702, "The Goddess Provides")
events.scripts.OnEvent(events, "PLAYER_LEVEL_UP")
local finished = {}
C_QuestLog.IsQuestFlaggedCompleted = function(id) return finished[id] or false end
LevelGuidePrereqs = { ["Tenaron's Summons"] = { all = { 916, 917 } }, ["Crown of the Earth"] = { level = 30 } }
update()
assert(not all():find("Tenaron's Summons", 1, true), "waits for Webwood Venom and Egg: " .. all())
finished[916] = true
update()
assert(not all():find("Tenaron's Summons", 1, true), "both are needed: " .. all())
finished[917] = true
update()
assert(all():find("Pick up:|r Tenaron's Summons", 1, true), "offered once both are done: " .. all())
LevelGuidePrereqs = nil
C_QuestLog.IsQuestFlaggedCompleted = nil
assert(#handled == 0, "clean: " .. tostring(handled[1]))

-- Review fixes. A quest giver isn't "busy" forever because of a quest you never got from the route
-- (one started by an item), or because they didn't offer one pick-up; and a move you've clearly made
-- (a later quest is in your log) doesn't hold the route up.
LevelGuideDB.characters["Juan-R"].done = {}
LevelGuideDB.characters["Juan-R"].skips = {}
LevelGuideDB.characters["Juan-R"].visited = {}
log = {}
level = 5
events.scripts.OnEvent(events, "PLAYER_LEVEL_UP")
realChain = LevelGuideRoutes.chains.NightElf
LevelGuideRoutes.chains.NightElf = { { zone = "Teldrassil", min = 1, max = 10, steps = {
    { t = "turnin", q = "Dropped Letter", npc = "Elder", x = 30, y = 30, lvl = 5 },
    { t = "accept", q = "Elder's Errand", npc = "Elder", x = 30, y = 30, lvl = 5 },
    { t = "accept", q = "Not Offered Yet", npc = "Ranger", x = 32, y = 30, lvl = 5 },
    { t = "accept", q = "Ranger's Other Job", npc = "Ranger", x = 32, y = 30, lvl = 5 },
} } }
px, py = 0.31, 0.30
update()
assert(all():find("Pick up:|r Elder's Errand", 1, true), "an item quest you don't hold doesn't block the giver: " .. all())
npcName = "Ranger"
UnitName = function(unit) if unit == "npc" then return npcName end return "Juan" end
clock = clock + 200
C_GossipInfo = { GetAvailableQuests = function() return { { title = "Ranger's Other Job" } } end }
events.scripts.OnEvent(events, "GOSSIP_SHOW")
UnitName = function() return "Juan" end
update()
assert(not all():find("Not Offered Yet", 1, true), "not offered stays hidden: " .. all())
assert(all():find("Pick up:|r Ranger's Other Job", 1, true), "what they do offer shows: " .. all())
-- The go step: never reached, but a pick-up after it is in your log, so it's behind you.
LevelGuideRoutes.chains.NightElf = { { zone = "Teldrassil", min = 1, max = 10, steps = {
    { t = "go", text = "Cross the river", x = 90, y = 10, lvl = 5 },
    { t = "accept", q = "Across The River", npc = "Scout", x = 50, y = 50, lvl = 5 },
    { t = "do", q = "Across The River", note = "here", x = 52, y = 50, lvl = 5 },
} } }
update()
assert(current.left.text:find("Go to:|r Cross the river", 1, true), "go step first: " .. current.left.text)
have(801, "Across The River")
update()
assert(not all():find("Cross the river", 1, true), "progress past it clears it: " .. all())
LevelGuideRoutes.chains.NightElf = realChain
assert(#handled == 0, "clean: " .. tostring(handled[1]))

-- The screenshot in Dolanaar: quests in your log that the route doesn't know (or hasn't reached) still
-- show, so a ready turn-in nearby isn't ignored in favour of route pick-ups.
LevelGuideDB.characters["Juan-R"].done = {}
LevelGuideDB.characters["Juan-R"].skips = {}
log = {}
level = 6
have(1001, "Garments of the Moon")
have(1002, "Camping 101: Cooking", true)
QUESTS_ON_MAP = { { questID = 1001, x = 0.40, y = 0.40 }, { questID = 1002, x = 0.301, y = 0.30 } }
realChain = LevelGuideRoutes.chains.NightElf
LevelGuideRoutes.chains.NightElf = { { zone = "Teldrassil", min = 1, max = 10, steps = {
    { t = "accept", q = "Route Pick-up", npc = "Byancie", x = 70, y = 70, lvl = 5 },
} } }
px, py = 0.30, 0.30
update()
assert(current.left.text:find("Turn in:|r Camping 101: Cooking", 1, true), "nearby log turn-in first: " .. all())
assert(all():find("Garments of the Moon", 1, true) and all():find("Route Pick-up", 1, true), "all kept: " .. all())
QUESTS_ON_MAP = nil
LevelGuideRoutes.chains.NightElf = realChain
assert(#handled == 0, "clean: " .. tostring(handled[1]))

-- Holding part 2 of a chain (found by quest ID, under a different Forever title) means part 1 is
-- behind you, even with nothing counted.
LevelGuideDB.characters["Juan-R"].done = {}
log = {}
level = 6
local savedIDs3 = LevelGuideQuestIDs
LevelGuideQuestIDs = { ids = { ["Chain Quest"] = { 7001, 7002 } }, renamed = {} }
have(7002, "Chain Quest: The Forever Name")
LevelGuideRoutes.chains.NightElf = { { zone = "Teldrassil", min = 1, max = 10, steps = {
    { t = "accept", q = "Chain Quest", npc = "Giver", x = 31, y = 30, lvl = 5, part = 1 },
    { t = "do", q = "Chain Quest", note = "part one", x = 32, y = 30, lvl = 5, part = 1 },
    { t = "turnin", q = "Chain Quest", npc = "Giver", x = 31, y = 30, lvl = 5, part = 1 },
    { t = "accept", q = "Chain Quest", npc = "Giver", x = 31, y = 30, lvl = 5, part = 2 },
    { t = "do", q = "Chain Quest", note = "part two", x = 40, y = 40, lvl = 5, part = 2 },
} } }
update()
assert(current.left.text:find("Do:|r Chain Quest", 1, true) and current.step.detail:find("part two", 1, true),
    "part 2 by ID: " .. all() .. " / " .. tostring(current.step.detail))
assert(not all():find("Pick up", 1, true), "no stale pick-ups: " .. all())
LevelGuideQuestIDs = savedIDs3
LevelGuideRoutes.chains.NightElf = realChain
assert(#handled == 0, "clean: " .. tostring(handled[1]))

-- Timed quests: a running clock puts the quest first with the time left and a warning sound; a
-- failed one says to abandon and pick it up again.
LevelGuideDB.characters["Juan-R"].done = {}
LevelGuideDB.characters["Juan-R"].skips = {}
log = {}
level = 4
have(901, "Webwood Egg")
have(902, "Iverron's Antidote", true)
local sounds = 0
PlaySound = function() sounds = sounds + 1 end
SOUNDKIT = { RAID_WARNING = 8959 }
clock = clock + 10
local timers, failedIDs = { [902] = { 300, clock - 30 } }, {}
C_QuestLog.GetTimeAllowed = function(id) local t = timers[id]; if t then return t[1], clock - t[2] end end
C_QuestLog.IsFailed = function(id) return failedIDs[id] or false end
update()
assert(current.left.text:find("Iverron's Antidote", 1, true), "timed quest first: " .. current.left.text)
assert(current.right.text:find("4:30 left", 1, true), "time left: " .. tostring(current.right.text))
assert(sounds == 1, "warned once: " .. sounds)
update()
assert(sounds == 1, "not again: " .. sounds)
clock = clock + 230
update()
assert(sounds == 2, "a minute left warns again: " .. sounds)
timers[902] = nil
failedIDs[902] = true
update()
assert(current.left.text:find("Iverron's Antidote", 1, true) and current.step.detail:find("Abandon", 1, true), "failed: " .. all())
C_QuestLog.GetTimeAllowed, C_QuestLog.IsFailed, PlaySound = nil, nil, nil
assert(#handled == 0, "clean: " .. tostring(handled[1]))

-- Route data sanity: every step has what it needs.
for raceName, chain in pairs(LevelGuideRoutes.chains) do
    for _, route in ipairs(chain) do
        for index, step in ipairs(route.steps) do
            local where = route.zone .. " #" .. index
            assert(step.t == "accept" or step.t == "do" or step.t == "turnin" or step.t == "go", where .. " type")
            assert((step.q or step.text) and step.x and step.y and step.lvl, where .. " fields")
            assert(step.x > 0 and step.x < 100 and step.y > 0 and step.y < 100, where .. " coordinates")
            if step.t == "accept" or step.t == "turnin" then assert(step.npc, where .. " npc") end
        end
    end
end
print("ALL TESTS PASSED")
