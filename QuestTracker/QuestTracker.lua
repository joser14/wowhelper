local WIDTH, HEADER_HEIGHT, MAX_ROWS = 290, 24, 40
local SECTION_HEIGHT, TITLE_HEIGHT, OBJECTIVE_HEIGHT = 19, 18, 14
local ITEM_SIZE, BAR_HEIGHT = 18, 2
local BOTTOM_MARGIN, MIN_ROOM, OVERFLOW_HEIGHT, PANEL_PADDING = 12, 120, 16, 6
local RESORT_SECONDS, NEW_SECONDS, MAX_OFFERS = 3, 3600, 3
-- Room under the minimap for the coordinate line other addons draw there.
local MINIMAP_GAP = 22
local YARDS_LABEL = "%d yd away"
local OTHER_ZONE = "Other quests"

local COLOR_READY = "|cff33ff33"
local COLOR_DIM = "|cff999999"
local COLOR_NEW = "|cff66ccff"
local COLOR_FOCUS = "|cffffd100"
local COLOR_WARN = "|cffff8040"
local COLOR_BAD = "|cffff3333"

local db, panel, headerTitle, collapseButton
local rows, itemButtons = {}, {}
local atlasKnown = {}
local shownRows, shownButtons = 0, 0
local dirty, layoutWaiting, moving = true, false, false
-- forceLayout: you changed the list yourself (folded a zone, moved it), so it redraws even under the mouse.
-- staleLayout: something changed while the mouse was on the list; it re-sorts once the mouse leaves.
local forceLayout, staleLayout = false, false
local lastOrder
local secondsSinceSort = 0
local readySeen
local requested = {}
-- Reward items asked for once each; waitingItems is what GET_ITEM_INFO_RECEIVED should wake us for.
local requestedItems, waitingItems = {}, {}
local upgradeCache = {}
local requestedMap
local OFFERS_SECTION = { name = "Quests nearby", quests = {}, isLocal = true,
    note = "Quests the game shows on your map that you haven't picked up. Click one to mark it." }

local function Safe(value)
    if issecretvalue and issecretvalue(value) then
        return nil
    end
    return value
end

local function InCombat()
    return InCombatLockdown and InCombatLockdown()
end

-- This addon's own tooltip, so nothing is ever written into Blizzard's GameTooltip.
local ownTip
local function Tip()
    if not ownTip then
        ownTip = CreateFrame("GameTooltip", "QuestTrackerTooltip", UIParent, "GameTooltipTemplate")
    end
    return ownTip
end

-- Inline atlas icon, or plain text when this client doesn't have that atlas.
local function Icon(atlas, size, fallback)
    if atlasKnown[atlas] == nil then
        atlasKnown[atlas] = (C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(atlas)) and true or false
    end
    if atlasKnown[atlas] then
        return string.format("|A:%s:%d:%d|a", atlas, size, size)
    end
    return fallback
end

local function Notify(text)
    if ForeverHub_Receive then
        ForeverHub_Receive("Quests", text)
    end
end

local function ShortMoney(copper)
    local gold, silver, rest = math.floor(copper / 10000), math.floor(copper / 100) % 100, copper % 100
    if gold > 0 then
        return string.format("%dg %ds", gold, silver)
    elseif silver > 0 then
        return string.format("%ds %dc", silver, rest)
    end
    return string.format("%dc", rest)
end

local function FormatNumber(value)
    local text = tostring(math.floor(value))
    while true do
        local changed
        text, changed = text:gsub("^(%d+)(%d%d%d)", "%1,%2")
        if changed == 0 then
            return text
        end
    end
end

-- The game's quest colors, from how far the quest is above or below you.
local function DifficultyColor(quest)
    if quest.trivial then
        return COLOR_DIM
    end
    local playerLevel = Safe(UnitLevel("player"))
    local difference = playerLevel and quest.level and quest.level - playerLevel or 0
    if difference >= 5 then
        return "|cffff3333"
    elseif difference >= 3 then
        return "|cffff8040"
    elseif difference >= -2 then
        return "|cffffd100"
    end
    return "|cff40c040"
end

local function ReadObjectives(questID)
    local list, fulfilled, required = {}, 0, 0
    for _, objective in ipairs(C_QuestLog.GetQuestObjectives(questID) or {}) do
        local text = Safe(objective.text)
        if text and text ~= "" then
            local have, need = Safe(objective.numFulfilled) or 0, Safe(objective.numRequired) or 0
            list[#list + 1] = { text = text, finished = Safe(objective.finished) and true or false, have = have }
            fulfilled, required = fulfilled + math.min(have, need), required + need
        end
    end
    return list, required > 0 and fulfilled / required or 0
end

local function ObjectiveText(objective)
    if objective.finished then
        return Icon("ui-questtracker-tracker-check", 10, "") .. COLOR_READY .. objective.text .. "|r"
    elseif objective.have > 0 then
        return objective.text
    end
    return COLOR_DIM .. objective.text .. "|r"
end

local function ReadItem(logIndex)
    if not GetQuestLogSpecialItemInfo then
        return nil
    end
    local link, icon, _, showWhenComplete = GetQuestLogSpecialItemInfo(logIndex)
    link, icon = Safe(link), Safe(icon)
    if link and icon then
        return { link = link, icon = icon, showWhenComplete = Safe(showWhenComplete) and true or false }
    end
end

-- Quest rewards can load late; asking once per quest is enough.
local function RewardXP(questID)
    if not GetQuestLogRewardXP then
        return 0
    end
    if HaveQuestRewardData and not Safe(HaveQuestRewardData(questID)) and not requested[questID] then
        requested[questID] = true
        if C_QuestLog.RequestLoadQuestByID then
            C_QuestLog.RequestLoadQuestByID(questID)
        end
    end
    return Safe(GetQuestLogRewardXP(questID)) or 0
end

-- Looks through a quest's rewards for one ItemAdvisor would tell you to equip. Results are kept until
-- your gear or level changes, except while an item hasn't loaded yet.
local function CheckRewards(questID, count, getInfo)
    local pending = false
    for index = 1, count do
        local itemID = Safe(select(6, getInfo(index, questID)))
        local link = itemID and select(2, C_Item.GetItemInfo(itemID))
        link = Safe(link)
        if link then
            local isUpgrade, reason = ItemAdvisor_IsUpgrade(link)
            if isUpgrade then
                return { link = link, reason = reason }, false
            end
        elseif itemID then
            pending = true
            -- Once only: an item that never loads would otherwise be asked for on every refresh, and each
            -- answer would trigger another refresh.
            if not requestedItems[itemID] then
                requestedItems[itemID] = true
                waitingItems[itemID] = true
                C_Item.RequestLoadItemDataByID(itemID)
            end
        end
    end
    return nil, pending
end

local function FindRewardUpgrade(questID)
    if not ItemAdvisor_IsUpgrade then
        return nil
    end
    local known = upgradeCache[questID]
    if known ~= nil then
        return known or nil
    end
    if HaveQuestRewardData and not Safe(HaveQuestRewardData(questID)) then
        return nil
    end
    local found, pending = nil, false
    if GetNumQuestLogChoices and GetQuestLogChoiceInfo then
        found, pending = CheckRewards(questID, Safe(GetNumQuestLogChoices(questID)) or 0, GetQuestLogChoiceInfo)
    end
    if not found and GetNumQuestLogRewards and GetQuestLogRewardInfo then
        local fixedPending
        found, fixedPending = CheckRewards(questID, Safe(GetNumQuestLogRewards(questID)) or 0, GetQuestLogRewardInfo)
        pending = pending or fixedPending
    end
    if found or not pending then
        upgradeCache[questID] = found or false
    end
    return found
end

-- The same order Blizzard's tracker uses: the quest's own text, then its waypoint.
local function TurnInText(quest)
    if quest.autoComplete then
        return "Click to open the completion window"
    end
    local text = quest.logIndex and GetQuestLogCompletionText and Safe(GetQuestLogCompletionText(quest.logIndex))
    if text and text ~= "" then
        return text
    end
    text = C_QuestLog.GetNextWaypointText and Safe(C_QuestLog.GetNextWaypointText(quest.id))
    if text and text ~= "" then
        return text
    end
    return nil
end

local function ReadQuest(info, zone)
    local questID, title = Safe(info.questID), Safe(info.title)
    if not (questID and title) then
        return nil
    end
    -- Blizzard's quest log leaves these out too; they're bonus objectives, not quests you picked up.
    if Safe(info.isTask) or (Safe(info.isBounty) and not Safe(C_QuestLog.IsComplete(questID))) then
        return nil
    end
    local quest = {
        id = questID, title = title, zone = zone, logIndex = Safe(info.questLogIndex),
        autoComplete = Safe(info.isAutoComplete) and true or false,
        level = Safe(info.difficultyLevel) or Safe(info.level),
        group = Safe(info.suggestedGroup) or 0,
    }
    quest.ready = (Safe(C_QuestLog.IsComplete(questID)) or Safe(C_QuestLog.ReadyForTurnIn(questID))) and true or false
    quest.failed = C_QuestLog.IsFailed and Safe(C_QuestLog.IsFailed(questID)) or false
    quest.trivial = Safe(C_QuestLog.IsQuestTrivial(questID)) or false
    quest.objectives, quest.progress = ReadObjectives(questID)
    quest.xp = RewardXP(questID)
    quest.money = GetQuestLogRewardMoney and Safe(GetQuestLogRewardMoney(questID)) or 0
    if C_QuestLog.IsOnMap then
        quest.onMap = Safe((C_QuestLog.IsOnMap(questID))) or false
    end
    if C_QuestLog.GetDistanceSqToQuest then
        local distanceSq, onContinent = C_QuestLog.GetDistanceSqToQuest(questID)
        distanceSq, onContinent = Safe(distanceSq), Safe(onContinent)
        if distanceSq and onContinent then
            quest.distance = math.sqrt(distanceSq)
        end
    end
    -- Escort and delivery quests with a clock; the end time lets the row count down without rereading.
    if C_QuestLog.GetTimeAllowed and GetTime then
        local total, elapsed = C_QuestLog.GetTimeAllowed(questID)
        total, elapsed = Safe(total), Safe(elapsed)
        if total and elapsed and total > 0 then
            quest.timerEnds = GetTime() + total - elapsed
        end
    end
    if quest.logIndex then
        quest.item = ReadItem(quest.logIndex)
    end
    if quest.ready then
        quest.turnIn = TurnInText(quest)
    end
    quest.upgrade = FindRewardUpgrade(questID)
    return quest
end

-- Everything in the log, plus watched quests hidden under a collapsed log header.
-- The log files class and race quests under "Mage" or "Night Elf" rather than a zone.
local function PersonalHeaders()
    local names = {}
    local className = UnitClass and Safe((UnitClass("player")))
    local raceName = UnitRace and Safe((UnitRace("player")))
    if className then
        names[className] = true
    end
    if raceName then
        names[raceName] = true
    end
    return names
end

local function ReadQuests()
    local quests, seen = {}, {}
    local personal = PersonalHeaders()
    local entries = C_QuestLog.GetNumQuestLogEntries()
    local zone = OTHER_ZONE
    for index = 1, Safe(entries) or 0 do
        local info = C_QuestLog.GetInfo(index)
        if info and Safe(info.isHeader) then
            zone = Safe(info.title) or OTHER_ZONE
        elseif info and not Safe(info.isHidden) then
            local quest = ReadQuest(info, zone)
            if quest then
                quest.personal = personal[zone]
                quests[#quests + 1] = quest
                seen[quest.id] = true
            end
        end
    end
    if C_QuestLog.GetNumQuestWatches and C_QuestLog.GetQuestIDForQuestWatchIndex and C_QuestLog.GetLogIndexForQuestID then
        for index = 1, Safe(C_QuestLog.GetNumQuestWatches()) or 0 do
            local questID = Safe(C_QuestLog.GetQuestIDForQuestWatchIndex(index))
            if questID and not seen[questID] then
                local logIndex = Safe(C_QuestLog.GetLogIndexForQuestID(questID))
                local info = logIndex and C_QuestLog.GetInfo(logIndex)
                local quest = info and ReadQuest(info, OTHER_ZONE)
                if quest then
                    quests[#quests + 1] = quest
                    seen[questID] = true
                end
            end
        end
    end
    return quests
end

local function YardsBetween(mapID, x1, y1, x2, y2)
    if not (C_Map.GetWorldPosFromMapPos and CreateVector2D) then
        return nil
    end
    local _, first = C_Map.GetWorldPosFromMapPos(mapID, CreateVector2D(x1, y1))
    local _, second = C_Map.GetWorldPosFromMapPos(mapID, CreateVector2D(x2, y2))
    if not (first and second) then
        return nil
    end
    local ax, ay = first:GetXY()
    local bx, by = second:GetXY()
    ax, ay, bx, by = Safe(ax), Safe(ay), Safe(bx), Safe(by)
    if not (ax and ay and bx and by) then
        return nil
    end
    return math.sqrt((ax - bx) ^ 2 + (ay - by) ^ 2)
end

-- Where the game's own map gets its "!" markers. Empty if Forever doesn't offer any here.
local function ReadOffers()
    local offers = {}
    if not (C_QuestLine and C_QuestLine.GetAvailableQuestLines and C_Map and C_Map.GetBestMapForUnit) then
        return offers
    end
    local mapID = Safe(C_Map.GetBestMapForUnit("player"))
    if not mapID then
        return offers
    end
    if requestedMap ~= mapID and C_QuestLine.RequestQuestLinesForMap then
        requestedMap = mapID
        C_QuestLine.RequestQuestLinesForMap(mapID)
    end
    local position = C_Map.GetPlayerMapPosition and C_Map.GetPlayerMapPosition(mapID, "player")
    local px, py
    if position then
        px, py = position:GetXY()
        px, py = Safe(px), Safe(py)
    end
    for _, info in ipairs(C_QuestLine.GetAvailableQuestLines(mapID) or {}) do
        local questID, name, x, y = Safe(info.questID), Safe(info.questName), Safe(info.x), Safe(info.y)
        local startMap = Safe(info.startMapID)
        if questID and name and x and y and not Safe(info.isHidden) and not Safe(info.inProgress)
            and (not startMap or startMap == 0 or startMap == mapID) then
            local offer = { id = questID, name = name, mapID = mapID, x = x, y = y }
            if px and py then
                offer.mapDistance = (x - px) ^ 2 + (y - py) ^ 2
                offer.yards = YardsBetween(mapID, px, py, x, y)
            end
            offers[#offers + 1] = offer
        end
    end
    table.sort(offers, function(a, b)
        if a.mapDistance and b.mapDistance and a.mapDistance ~= b.mapDistance then
            return a.mapDistance < b.mapDistance
        end
        return a.id < b.id
    end)
    for index = #offers, MAX_OFFERS + 1, -1 do
        offers[index] = nil
    end
    return offers
end

local function MarkOffer(offer)
    if not (C_Map and C_Map.SetUserWaypoint and UiMapPoint and UiMapPoint.CreateFromCoordinates) then
        return
    end
    C_Map.SetUserWaypoint(UiMapPoint.CreateFromCoordinates(offer.mapID, offer.x, offer.y))
    if C_SuperTrack and C_SuperTrack.SetSuperTrackedUserWaypoint then
        C_SuperTrack.SetSuperTrackedUserWaypoint(true)
    end
end

local function CurrentZone()
    return (GetRealZoneText and Safe(GetRealZoneText())) or (GetZoneText and Safe(GetZoneText())) or nil
end

local function FocusedQuest()
    if C_SuperTrack and C_SuperTrack.GetSuperTrackedQuestID then
        return Safe(C_SuperTrack.GetSuperTrackedQuestID())
    end
end

local function NearestFirst(a, b)
    if a.trivial ~= b.trivial then
        return b.trivial
    end
    if a.distance and b.distance and a.distance ~= b.distance then
        return a.distance < b.distance
    end
    if (a.distance ~= nil) ~= (b.distance ~= nil) then
        return a.distance ~= nil
    end
    if (a.level or 0) ~= (b.level or 0) then
        return (a.level or 0) < (b.level or 0)
    end
    return a.id < b.id
end

-- Turn-ins first, then the zone you're in, then the rest. Other zones fold up until you want them.
local function BuildSections(quests)
    local ready, zones, byName = {}, {}, {}
    local here = CurrentZone()
    for _, quest in ipairs(quests) do
        if quest.ready then
            ready[#ready + 1] = quest
        else
            -- A class or race quest you can do here joins this zone; the rest get a label that says what they are.
            local name = quest.zone
            if quest.personal then
                name = (quest.onMap and here) or (quest.zone .. " quests")
            end
            local section = byName[name]
            if not section then
                section = { name = name, quests = {}, order = #zones }
                byName[name] = section
                zones[#zones + 1] = section
            end
            section.quests[#section.quests + 1] = quest
            section.isLocal = section.isLocal or quest.onMap or name == here
        end
    end
    table.sort(zones, function(a, b)
        if (a.name == here) ~= (b.name == here) then
            return a.name == here
        end
        if (a.isLocal and true or false) ~= (b.isLocal and true or false) then
            return a.isLocal and true or false
        end
        return a.order < b.order
    end)
    for _, section in ipairs(zones) do
        table.sort(section.quests, NearestFirst)
    end
    table.sort(ready, NearestFirst)
    return ready, zones
end

local function SectionOpen(section)
    local saved = db.zones[section.name]
    if saved ~= nil then
        return saved
    end
    return section.isLocal and true or false
end

local function TimeLeft(quest)
    local seconds = quest.timerEnds and GetTime and math.max(math.floor(quest.timerEnds - GetTime()), 0)
    if not seconds then
        return nil
    end
    return string.format("%d:%02d", math.floor(seconds / 60), seconds % 60)
end

-- Tags sit in the short right-hand column so the quest name keeps the width; the tooltip spells them out.
local function RightText(quest)
    local parts = {}
    local left = TimeLeft(quest)
    if left then
        parts[#parts + 1] = COLOR_BAD .. left .. "|r"
    end
    if quest.upgrade then
        parts[#parts + 1] = Icon("bags-greenarrow", 12, COLOR_READY .. "Upg|r")
    end
    if quest.group > 1 then
        parts[#parts + 1] = string.format("%sG%d|r", COLOR_WARN, quest.group)
    end
    local accepted = db.accepted[quest.id]
    if accepted and GetServerTime and GetServerTime() - accepted < NEW_SECONDS then
        parts[#parts + 1] = COLOR_NEW .. "NEW|r"
    end
    if quest.xp and quest.xp > 0 then
        parts[#parts + 1] = COLOR_DIM .. FormatNumber(quest.xp) .. " xp|r"
    end
    return table.concat(parts, " ")
end

local function QuestTooltip(owner, quest)
    Tip():SetOwner(owner, "ANCHOR_LEFT")
    Tip():SetText(quest.title, 1, 0.82, 0)
    Tip():AddLine(string.format("Level %d, %s", quest.level or 0, quest.zone), 0.8, 0.8, 0.8)
    if quest.distance then
        Tip():AddLine(string.format(YARDS_LABEL, math.floor(quest.distance)), 0.8, 0.8, 0.8)
    end
    if quest.group > 1 then
        Tip():AddLine(string.format("Suggested group: %d players", quest.group), 1, 0.5, 0.25)
    end
    local left = TimeLeft(quest)
    if left then
        Tip():AddLine("Time left: " .. left, 1, 0.2, 0.2)
    end
    if quest.failed then
        Tip():AddLine("This quest has failed.", 1, 0.2, 0.2)
    end
    for _, objective in ipairs(quest.objectives) do
        if objective.finished then
            Tip():AddLine(objective.text, 0.2, 1, 0.2)
        else
            Tip():AddLine(objective.text, 1, 1, 1)
        end
    end
    if quest.xp and quest.xp > 0 then
        local maxXP = Safe(UnitXPMax("player"))
        local share = maxXP and maxXP > 0 and string.format(" (%d%% of a level)", math.floor(quest.xp * 100 / maxXP)) or ""
        Tip():AddLine("Reward: " .. FormatNumber(quest.xp) .. " XP" .. share, 0.6, 0.8, 1)
    end
    if quest.money and quest.money > 0 then
        Tip():AddLine("Reward: " .. ShortMoney(quest.money), 1, 0.85, 0.2)
    end
    if quest.upgrade then
        Tip():AddLine("Upgrade: " .. quest.upgrade.link, 0.2, 1, 0.2)
    end
    if quest.ready and quest.autoComplete then
        Tip():AddLine("Left-click: open the completion window. Right-click: track it.", 0.6, 0.6, 0.6)
    else
        Tip():AddLine("Left-click: mark it on the map. Right-click: track it.", 0.6, 0.6, 0.6)
    end
    Tip():Show()
end

local function SectionTooltip(owner, section)
    Tip():SetOwner(owner, "ANCHOR_LEFT")
    Tip():SetText(section.name, 1, 0.82, 0)
    if section.note then
        Tip():AddLine(section.note, 1, 1, 1, true)
    end
    for _, quest in ipairs(section.quests) do
        Tip():AddLine(string.format("[%d] %s", quest.level or 0, quest.title), 1, 1, 1)
        for _, objective in ipairs(quest.objectives) do
            if not objective.finished then
                Tip():AddLine("   " .. objective.text, 0.7, 0.7, 0.7)
            end
        end
    end
    Tip():Show()
end

local function ToggleFocus(questID)
    if not (C_SuperTrack and C_SuperTrack.SetSuperTrackedQuestID) then
        return
    end
    C_SuperTrack.SetSuperTrackedQuestID(FocusedQuest() == questID and 0 or questID)
    dirty = true
end

-- Never call QuestMapFrame_OpenToQuestDetails or OpenQuestLog from here: they are Blizzard Lua, and
-- the value they write (QuestMapFrame.DetailsFrame.questID) is read by Blizzard's objective tracker on
-- every update, so the whole tracker then runs tainted and its aura reads fail. Pointing the game's
-- own tracking at the quest is a C call and highlights it in the log and on the map just the same.
local function OpenQuest(questID)
    if not InCombat() and C_SuperTrack and C_SuperTrack.SetSuperTrackedQuestID then
        C_SuperTrack.SetSuperTrackedQuestID(questID)
        dirty = true
    end
end

local function OnRowClick(row, mouseButton)
    if row.section then
        -- The rows can't move until combat ends, so a fold now would look like nothing happened
        -- and a second click would quietly undo it.
        if InCombat() then
            return
        end
        db.zones[row.section.name] = not SectionOpen(row.section)
        dirty, forceLayout = true, true
    elseif row.offer then
        MarkOffer(row.offer)
    elseif row.quest then
        if mouseButton == "RightButton" then
            OpenQuest(row.quest.id)
        elseif row.quest.ready and row.quest.autoComplete and ShowQuestComplete then
            ShowQuestComplete(row.quest.id)
        else
            ToggleFocus(row.quest.id)
        end
    end
end

local function OnRowEnter(row)
    if row.quest then
        QuestTooltip(row, row.quest)
    elseif row.offer then
        Tip():SetOwner(row, "ANCHOR_LEFT")
        Tip():SetText(row.offer.name, 1, 0.82, 0)
        Tip():AddLine("Left-click: mark it on your map.", 0.6, 0.6, 0.6)
        Tip():Show()
    elseif row.section then
        SectionTooltip(row, row.section)
    end
end

local function GetRow(index)
    if rows[index] then
        return rows[index]
    end
    local row = CreateFrame("Button", nil, panel)
    row:SetWidth(WIDTH - 16)
    row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
    row.left = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.left:SetJustifyH("LEFT")
    row.left:SetWordWrap(false)
    row.right = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.right:SetJustifyH("RIGHT")
    -- Zone headers get a band and the focused quest a gold wash, so the list reads at a glance.
    row.band = row:CreateTexture(nil, "BACKGROUND")
    row.band:SetAllPoints(row)
    row.band:SetColorTexture(1, 1, 1, 0.07)
    row.glow = row:CreateTexture(nil, "BACKGROUND")
    row.glow:SetAllPoints(row)
    row.glow:SetColorTexture(1, 0.82, 0, 0.12)
    row.stripe = row:CreateTexture(nil, "ARTWORK")
    row.stripe:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)
    row.stripe:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 0, 0)
    row.stripe:SetWidth(2)
    row.stripe:SetColorTexture(1, 0.82, 0, 0.9)
    -- The track shows how far the bar has left to go.
    row.track = row:CreateTexture(nil, "BORDER")
    row.track:SetColorTexture(0, 0, 0, 0.5)
    row.track:SetHeight(BAR_HEIGHT)
    row.track:SetWidth(WIDTH - 20)
    row.track:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 2, 0)
    row.bar = row:CreateTexture(nil, "ARTWORK")
    row.bar:SetColorTexture(0.9, 0.75, 0.2, 0.8)
    row.bar:SetHeight(BAR_HEIGHT)
    row.bar:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 2, 0)
    row:SetScript("OnClick", OnRowClick)
    row:SetScript("OnEnter", OnRowEnter)
    row:SetScript("OnLeave", function()
        Tip():Hide()
    end)
    rows[index] = row
    return row
end

-- A real action button you click yourself, the same way Blizzard's tracker offers quest items.
local function GetItemButton(index)
    if itemButtons[index] then
        return itemButtons[index]
    end
    local button = CreateFrame("Button", nil, panel, "SecureActionButtonTemplate")
    button:SetSize(ITEM_SIZE, ITEM_SIZE)
    button:RegisterForClicks("AnyUp", "AnyDown")
    button:SetAttribute("type", "item")
    button.icon = button:CreateTexture(nil, "ARTWORK")
    button.icon:SetAllPoints(button)
    -- The same cooldown swirl Blizzard's tracker draws on quest items.
    button.cooldown = CreateFrame("Cooldown", nil, button, "CooldownFrameTemplate")
    button.cooldown:SetAllPoints(button)
    button:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
    button:SetScript("OnEnter", function(self)
        if self.link then
            Tip():SetOwner(self, "ANCHOR_LEFT")
            Tip():SetHyperlink(self.link)
            Tip():Show()
        end
    end)
    button:SetScript("OnLeave", function()
        Tip():Hide()
    end)
    itemButtons[index] = button
    return button
end

local function PlaceRow(index, y, height, indent, leftText, rightText)
    local row = GetRow(index)
    row:ClearAllPoints()
    row:SetPoint("TOPLEFT", panel, "TOPLEFT", 8, y)
    row:SetHeight(height)
    row.left:ClearAllPoints()
    row.left:SetPoint("LEFT", row, "LEFT", indent, 0)
    row.right:ClearAllPoints()
    row.right:SetPoint("RIGHT", row, "RIGHT", -2, 0)
    row.left:SetPoint("RIGHT", row.right, "LEFT", -4, 0)
    row.left:SetText(leftText)
    row.right:SetText(rightText or "")
    row.quest, row.section, row.objectiveIndex, row.offer, row.isTitle = nil, nil, nil, nil, nil
    row.bar:Hide()
    row.track:Hide()
    row.band:Hide()
    row.glow:Hide()
    row.stripe:Hide()
    row:Show()
    return row
end

local function PlaceItemButton(row, item, questID)
    local itemID = item.link:match("item:(%d+)")
    -- Secure buttons can't be moved or re-pointed once combat has started, even mid-layout.
    if not itemID or (InCombatLockdown and InCombatLockdown()) then
        return
    end
    shownButtons = shownButtons + 1
    local button = GetItemButton(shownButtons)
    button:ClearAllPoints()
    button:SetPoint("RIGHT", row, "RIGHT", -2, 0)
    -- Rows are made as needed and share the panel's level, so a newer row could sit over the button
    -- and take its clicks. Keep the button above its row. Out of combat only, like all of Layout.
    local rowLevel = row:GetFrameLevel()
    if rowLevel then
        button:SetFrameLevel(rowLevel + 2)
    end
    button:SetAttribute("item", "item:" .. itemID)
    button.icon:SetTexture(item.icon)
    button.link, button.questID = item.link, questID
    button:Show()
    row.right:ClearAllPoints()
    row.right:SetPoint("RIGHT", button, "LEFT", -4, 0)
end

local function QuestRowText(quest, focused)
    local prefix = quest.id == focused and (COLOR_FOCUS .. "> |r") or ""
    local failed = quest.failed and (COLOR_BAD .. "Failed|r ") or ""
    return string.format("%s%s%s[%d] %s|r", prefix, failed, quest.ready and COLOR_READY or DifficultyColor(quest), quest.level or 0, quest.title)
end

-- Text, textures and the bar only: safe in combat, since none of them move a frame.
local function DrawTitle(row, focused)
    local quest = row.quest
    row.left:SetText(QuestRowText(quest, focused))
    row.right:SetText(RightText(quest))
    row.glow:SetShown(quest.id == focused)
    row.stripe:SetShown(quest.id == focused)
end

local function SetBar(row, quest)
    local shown = quest.progress > 0 and not quest.ready
    row.bar:SetShown(shown)
    row.track:SetShown(shown)
    row.bar:SetWidth(math.max((WIDTH - 20) * quest.progress, 1))
end

-- What the last Layout worked out, so Order() right after it needn't sort the log and read the map again.
local layoutCache

local function Layout(quests)
    local ready, zones = BuildSections(quests)
    layoutCache = { quests = quests, ready = ready, zones = zones }
    local focused = FocusedQuest()
    local count, y = 0, -HEADER_HEIGHT
    shownButtons = 0
    local hiddenRows = 0
    -- Stop at the bottom of the screen, or the game slides the whole panel up to keep it on screen.
    local top = panel:GetTop()
    if not top then
        -- The game hasn't placed the panel yet, so measure again on the next tick.
        dirty = true
    end
    local overflowRoom = math.max((top or 0) - BOTTOM_MARGIN, MIN_ROOM) - OVERFLOW_HEIGHT - PANEL_PADDING

    local function AddRow(height, indent, left, right)
        if hiddenRows > 0 or count >= MAX_ROWS - 1 or -y + height > overflowRoom then
            hiddenRows = hiddenRows + 1
            return nil
        end
        count = count + 1
        local row = PlaceRow(count, y, height, indent, left, right)
        y = y - height
        return row
    end

    local function AddOffers()
        local offers = ReadOffers()
        layoutCache.offers = offers
        if #offers == 0 then
            return
        end
        local open = SectionOpen(OFFERS_SECTION)
        local header = AddRow(SECTION_HEIGHT, 4, string.format("%s%s%s (%d)|r", COLOR_FOCUS, open and "- " or "+ ", OFFERS_SECTION.name, #offers))
        if header then
            header.section = OFFERS_SECTION
            header.band:Show()
        end
        if open then
            for _, offer in ipairs(offers) do
                local distance = offer.yards and string.format("%s%d yd|r", COLOR_DIM, math.floor(offer.yards)) or ""
                local row = AddRow(TITLE_HEIGHT, 6, COLOR_FOCUS .. "! |r" .. offer.name, distance)
                if row then
                    row.offer = offer
                end
            end
        end
    end

    if #ready > 0 then
        local totalXP = 0
        for _, quest in ipairs(ready) do
            totalXP = totalXP + (quest.xp or 0)
        end
        local maxXP = Safe(UnitXPMax("player"))
        local summary = totalXP > 0 and maxXP and maxXP > 0
            and string.format("%s+%d%% of a level|r", COLOR_READY, math.floor(totalXP * 100 / maxXP)) or ""
        local header = AddRow(SECTION_HEIGHT, 4, string.format("%sReady to turn in (%d)|r", COLOR_READY, #ready), summary)
        if header then
            header.band:Show()
        end
        for _, quest in ipairs(ready) do
            local row = AddRow(TITLE_HEIGHT, 6, "")
            if row then
                row.quest, row.isTitle = quest, true
                DrawTitle(row, focused)
                if quest.item and quest.item.showWhenComplete then
                    PlaceItemButton(row, quest.item, quest.id)
                end
            end
            if quest.turnIn then
                local line = AddRow(OBJECTIVE_HEIGHT, 14, COLOR_DIM .. quest.turnIn .. "|r")
                if line then
                    line.quest = quest
                end
            end
        end
    end
    for sectionIndex, section in ipairs(zones) do
        local open = SectionOpen(section)
        local marker = open and "- " or "+ "
        -- What the whole zone is worth, to help pick where to go next.
        local zoneXP = 0
        for _, quest in ipairs(section.quests) do
            zoneXP = zoneXP + (quest.xp or 0)
        end
        local row = AddRow(SECTION_HEIGHT, 4, string.format("%s%s%s (%d)|r", COLOR_FOCUS, marker, section.name, #section.quests),
            zoneXP > 0 and (COLOR_DIM .. FormatNumber(zoneXP) .. " xp|r") or "")
        if row then
            row.section = section
            row.band:Show()
        end
        if open then
            for _, quest in ipairs(section.quests) do
                local title = AddRow(TITLE_HEIGHT, 6, "")
                if title then
                    title.quest, title.isTitle = quest, true
                    DrawTitle(title, focused)
                    SetBar(title, quest)
                    if quest.item then
                        PlaceItemButton(title, quest.item, quest.id)
                    end
                end
                for index, objective in ipairs(quest.objectives) do
                    local line = AddRow(OBJECTIVE_HEIGHT, 14, ObjectiveText(objective))
                    if line then
                        line.quest, line.objectiveIndex = quest, index
                    end
                end
            end
        end
        -- Your active quests in this zone come first, then what else you could pick up here.
        if sectionIndex == 1 then
            AddOffers()
        end
    end
    if #zones == 0 then
        AddOffers()
    end
    if hiddenRows > 0 then
        count = count + 1
        PlaceRow(count, y, OVERFLOW_HEIGHT, 4, string.format("%s%d more lines. Fold a zone to see them.|r", COLOR_DIM, hiddenRows))
        y = y - OVERFLOW_HEIGHT
    end
    if count == 0 then
        count = 1
        PlaceRow(1, y, TITLE_HEIGHT, 4, COLOR_DIM .. "No quests in your log.|r")
        y = y - TITLE_HEIGHT
    end
    for index = count + 1, #rows do
        rows[index]:Hide()
    end
    for index = shownButtons + 1, #itemButtons do
        itemButtons[index]:Hide()
    end
    shownRows = count
    panel:SetHeight(-y + PANEL_PADDING)
end

local function ApplyCollapse()
    for index = 1, shownRows do
        rows[index]:SetShown(not db.collapsed)
    end
    for index = 1, shownButtons do
        itemButtons[index]:SetShown(not db.collapsed)
    end
    collapseButton:SetText(db.collapsed and "+" or "-")
    if db.collapsed then
        panel:SetHeight(HEADER_HEIGHT + 2)
    end
end

local function HeaderText(quests)
    local _, used = C_QuestLog.GetNumQuestLogEntries()
    used = Safe(used)
    local maximum = C_QuestLog.GetMaxNumQuestsCanAccept and Safe(C_QuestLog.GetMaxNumQuestsCanAccept())
    if used and maximum then
        -- Warn before the log fills, since a full log refuses new quests.
        local color = (used >= maximum and COLOR_BAD) or (used >= maximum - 3 and COLOR_WARN) or COLOR_DIM
        return string.format("Quests  %s%d/%d|r", color, used, maximum)
    end
    return string.format("Quests  %s%d|r", COLOR_DIM, #quests)
end

local function AnnounceReady(quests)
    local now = {}
    for _, quest in ipairs(quests) do
        if quest.ready then
            now[quest.id] = true
            if readySeen and not readySeen[quest.id] then
                Notify(COLOR_READY .. "Ready to turn in:|r " .. quest.title)
            end
        end
    end
    readySeen = now
end

-- During combat only text changes: moving anything beside a secure button then would be blocked.
local function UpdateTextOnly()
    local cache = {}
    local focused = FocusedQuest()
    for index = 1, shownRows do
        local row = rows[index]
        if row.quest then
            local objectives = cache[row.quest.id]
            local progress
            if not objectives then
                objectives, progress = ReadObjectives(row.quest.id)
                cache[row.quest.id] = objectives
                if row.isTitle == true then
                    row.quest.progress = progress
                    SetBar(row, row.quest)
                end
            end
            -- Clicking a quest in combat still moves the focus marker.
            if row.isTitle == true then
                DrawTitle(row, focused)
            end
            local objective = row.objectiveIndex and objectives[row.objectiveIndex]
            if objective then
                row.left:SetText(ObjectiveText(objective))
            end
        end
    end
end

-- Every second, in or out of combat: clocks, item cooldowns and range. None of it moves a frame.
local function UpdateLive()
    for index = 1, shownRows do
        local row = rows[index]
        if row.isTitle == true and row.quest.timerEnds then
            row.right:SetText(RightText(row.quest))
        end
    end
    for index = 1, shownButtons do
        local button = itemButtons[index]
        local logIndex = button.questID and C_QuestLog.GetLogIndexForQuestID and Safe(C_QuestLog.GetLogIndexForQuestID(button.questID))
        if logIndex then
            if GetQuestLogSpecialItemCooldown and CooldownFrame_Set then
                local start, duration, enable = GetQuestLogSpecialItemCooldown(logIndex)
                start, duration, enable = Safe(start), Safe(duration), Safe(enable)
                if start and duration then
                    CooldownFrame_Set(button.cooldown, start, duration, enable)
                end
            end
            -- Red while you're too far away to use it, as Blizzard's tracker shows.
            if IsQuestLogSpecialItemInRange then
                if Safe(IsQuestLogSpecialItemInRange(logIndex)) == 0 then
                    button.icon:SetVertexColor(1, 0.2, 0.2)
                else
                    button.icon:SetVertexColor(1, 1, 1)
                end
            end
        end
    end
end

local function Order(quests)
    local ids = {}
    local cached = layoutCache and layoutCache.quests == quests and layoutCache or nil
    local ready, zones
    if cached then
        ready, zones = cached.ready, cached.zones
    else
        ready, zones = BuildSections(quests)
    end
    for _, quest in ipairs(ready) do
        ids[#ids + 1] = quest.id
    end
    for _, section in ipairs(zones) do
        ids[#ids + 1] = section.name
        for _, quest in ipairs(section.quests) do
            ids[#ids + 1] = quest.id
        end
    end
    for _, offer in ipairs(cached and cached.offers or ReadOffers()) do
        ids[#ids + 1] = "offer" .. offer.id
    end
    return table.concat(ids, ",")
end

-- Until you drag it, the panel sits just under the minimap. It copies the spot rather than anchoring to
-- MinimapCluster, so Blizzard's frame never gets tied to one holding secure buttons. Out of combat only.
local function PlaceDefault()
    local cluster = MinimapCluster
    local bottom = cluster and Safe(cluster:GetBottom())
    local right = cluster and Safe(cluster:GetRight())
    local scale = cluster and Safe(cluster:GetEffectiveScale())
    local ours = Safe(UIParent:GetEffectiveScale())
    panel:ClearAllPoints()
    if bottom and right and scale and ours and ours > 0 then
        -- Edit Mode can scale the minimap, so convert into UIParent's units.
        bottom, right = bottom * scale / ours, right * scale / ours
        if bottom - MINIMAP_GAP > MIN_ROOM + HEADER_HEIGHT then
            panel:SetPoint("TOPRIGHT", UIParent, "BOTTOMLEFT", right - 4, bottom - MINIMAP_GAP)
            return
        end
    end
    panel:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -16, -280)
end

-- Takes the quests when the caller already read them, so the log isn't read twice.
local function Refresh(quests)
    if not db.position and not moving then
        PlaceDefault()
    end
    quests = quests or ReadQuests()
    staleLayout = false
    AnnounceReady(quests)
    headerTitle:SetText(HeaderText(quests))
    Layout(quests)
    ApplyCollapse()
    lastOrder = Order(quests)
end

local function Attempt(step)
    local ok, err = pcall(step)
    if not ok then
        geterrorhandler()(err)
    end
end

local function OnTick()
    secondsSinceSort = secondsSinceSort + 1
    if ObjectiveTrackerFrame and not db.keepBlizzard then
        local alpha = ObjectiveTrackerFrame:GetAlpha()
        if type(alpha) == "number" and alpha > 0 then
            ObjectiveTrackerFrame:SetAlpha(0)
        end
    end
    Attempt(UpdateLive)
    if InCombat() then
        if dirty then
            dirty, layoutWaiting = false, true
            Attempt(UpdateTextOnly)
        end
        return
    end
    -- Nearest-first follows you as you move, but never jumps while the mouse is on the list:
    -- a kill or a loaded item then only updates the text, and the re-sort waits for the mouse to leave.
    local hovered = panel:IsMouseOver()
    if layoutWaiting or forceLayout or ((dirty or staleLayout) and not hovered) then
        dirty, layoutWaiting, forceLayout = false, false, false
        secondsSinceSort = 0
        Attempt(Refresh)
    elseif dirty then
        dirty, staleLayout = false, true
        Attempt(UpdateTextOnly)
    elseif secondsSinceSort >= RESORT_SECONDS then
        secondsSinceSort = 0
        if not hovered then
            Attempt(function()
                local quests = ReadQuests()
                if Order(quests) ~= lastOrder then
                    Refresh(quests)
                end
            end)
        end
    end
end

local function SavePosition()
    local left, top = panel:GetLeft(), panel:GetTop()
    if left and top then
        panel:ClearAllPoints()
        panel:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left, top)
        db.position = { left, top }
        -- More or less of the list may fit from the new spot.
        dirty, forceLayout = true, true
    end
end

-- A drag can't finish during combat, so PLAYER_REGEN_DISABLED, which fires just before combat locks frames, ends it.
local function FinishMoving()
    if moving then
        moving = false
        panel:StopMovingOrSizing()
        SavePosition()
    end
end

-- Blizzard's tracker is only ever made clear, never hidden or shown. Calling its Hide() or Show() from here
-- runs its OnShow/size-change code (UpdateHeight, MarkDirty, Update) under this addon's taint, and its
-- scenario module then fails reading secret aura data. SetAlpha runs none of Blizzard's Lua.
-- What's left: the clear tracker still takes clicks (its quest-item buttons included) where this panel
-- doesn't cover it. EnableMouse can't fix that: it's restricted on the tracker in combat like Hide(), it
-- doesn't reach the child buttons (each has its own mouse setting), and changing those would taint them.
local function HideBlizzardTracker()
    local tracker = ObjectiveTrackerFrame
    if not tracker or db.keepBlizzard then
        return
    end
    tracker:SetAlpha(0)
end

-- No script hook on Blizzard's frame: the once-a-second tick below makes it clear again if Blizzard
-- showed it, which costs one alpha read.
local function WatchBlizzardTracker()
    HideBlizzardTracker()
end

local function ToggleBlizzardTracker()
    if not ObjectiveTrackerFrame then
        return
    end
    db.keepBlizzard = not db.keepBlizzard
    if db.keepBlizzard then
        ObjectiveTrackerFrame:SetAlpha(1)
    else
        HideBlizzardTracker()
    end
end

local function BuildPanel()
    panel = CreateFrame("Frame", "QuestTrackerPanel", UIParent, "BackdropTemplate")
    panel:SetWidth(WIDTH)
    panel:SetHeight(HEADER_HEIGHT + 2)
    panel:SetClampedToScreen(true)
    panel:SetMovable(true)
    panel:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 14,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    panel:SetBackdropColor(0.04, 0.04, 0.07, 0.72)
    panel:SetBackdropBorderColor(0.5, 0.5, 0.55, 0.9)
    -- The header band and a thin gold rule under it.
    local band = panel:CreateTexture(nil, "BORDER")
    band:SetPoint("TOPLEFT", panel, "TOPLEFT", 3, -3)
    band:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -3, -3)
    band:SetHeight(HEADER_HEIGHT - 3)
    band:SetColorTexture(1, 1, 1, 0.06)
    local rule = panel:CreateTexture(nil, "BORDER")
    rule:SetPoint("TOPLEFT", band, "BOTTOMLEFT", 0, 0)
    rule:SetPoint("TOPRIGHT", band, "BOTTOMRIGHT", 0, 0)
    rule:SetHeight(1)
    rule:SetColorTexture(1, 0.82, 0, 0.35)
    if db.position then
        panel:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", db.position[1], db.position[2])
    else
        PlaceDefault()
    end

    local header = CreateFrame("Button", nil, panel)
    header:SetPoint("TOPLEFT", panel, "TOPLEFT", 4, -3)
    header:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -26, -3)
    header:SetHeight(HEADER_HEIGHT - 4)
    header:RegisterForDrag("LeftButton")
    header:RegisterForClicks("RightButtonUp")
    header:SetScript("OnDragStart", function()
        if not InCombat() then
            moving = true
            panel:StartMoving()
        end
    end)
    header:SetScript("OnDragStop", FinishMoving)
    header:SetScript("OnClick", ToggleBlizzardTracker)
    header:SetScript("OnEnter", function(self)
        Tip():SetOwner(self, "ANCHOR_LEFT")
        Tip():SetText("Quest Tracker")
        Tip():AddLine("Drag to move.", 1, 1, 1)
        Tip():AddLine(db.keepBlizzard and "Right-click: hide Blizzard's tracker." or "Right-click: show Blizzard's tracker too.", 1, 1, 1)
        Tip():Show()
    end)
    header:SetScript("OnLeave", function()
        Tip():Hide()
    end)

    headerTitle = header:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    headerTitle:SetPoint("LEFT", header, "LEFT", 6, 0)
    headerTitle:SetText("Quests")

    collapseButton = CreateFrame("Button", nil, panel)
    collapseButton:SetSize(20, 18)
    collapseButton:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -5, -4)
    collapseButton:SetNormalFontObject(GameFontNormal)
    collapseButton:SetHighlightFontObject(GameFontHighlight)
    collapseButton:SetText("-")
    collapseButton:SetScript("OnClick", function()
        if not InCombat() then
            db.collapsed = not db.collapsed
            dirty, forceLayout = true, true
        end
    end)
end

local function Start()
    QuestTrackerDB = QuestTrackerDB or {}
    db = QuestTrackerDB
    db.zones = db.zones or {}
    db.accepted = db.accepted or {}
    -- Quests dropped while the addon was off never sent QUEST_REMOVED; forget their NEW stamps.
    if GetServerTime then
        local now = GetServerTime()
        for questID, accepted in pairs(db.accepted) do
            if now - accepted >= NEW_SECONDS then
                db.accepted[questID] = nil
            end
        end
    end
    BuildPanel()
    -- A /reload in combat can't place secure buttons yet; the layout waits for combat to end.
    if InCombat() then
        layoutWaiting = true
    else
        Attempt(Refresh)
    end
    -- Blizzard's tracker only goes away once this one has been built.
    Attempt(WatchBlizzardTracker)
    C_Timer.NewTicker(1, OnTick)
end

local events = CreateFrame("Frame")
for _, name in ipairs({ "PLAYER_LOGIN", "QUEST_LOG_UPDATE", "QUEST_WATCH_LIST_CHANGED", "QUEST_ACCEPTED", "QUEST_REMOVED", "QUEST_TURNED_IN",
    "ZONE_CHANGED_NEW_AREA", "PLAYER_LEVEL_UP", "PLAYER_REGEN_ENABLED", "PLAYER_REGEN_DISABLED", "SUPER_TRACKING_CHANGED", "QUEST_DATA_LOAD_RESULT", "PLAYER_EQUIPMENT_CHANGED", "GET_ITEM_INFO_RECEIVED" }) do
    events:RegisterEvent(name)
end
events:SetScript("OnEvent", function(_, event, questID)
    if event == "PLAYER_LOGIN" then
        Start()
        return
    end
    if not db then
        return
    end
    questID = Safe(questID)
    if event == "PLAYER_EQUIPMENT_CHANGED" or event == "PLAYER_LEVEL_UP" then
        upgradeCache = {}
    end
    if event == "QUEST_ACCEPTED" and questID and GetServerTime then
        db.accepted[questID] = GetServerTime()
    elseif event == "QUEST_REMOVED" and questID then
        db.accepted[questID] = nil
    elseif event == "PLAYER_REGEN_DISABLED" then
        Attempt(FinishMoving)
        return
    elseif event == "GET_ITEM_INFO_RECEIVED" then
        -- Any addon's item lookups fire this; only the reward items this panel asked for matter.
        if not (questID and waitingItems[questID]) then
            return
        end
        waitingItems[questID] = nil
    end
    dirty = true
end)
