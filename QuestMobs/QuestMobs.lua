-- QuestMobs: a small quest marker with your progress (like "3/8") next to enemies you still need for a
-- quest in your log, in the open world. It reads the same quest lines the game's own unit tooltip shows
-- (C_TooltipInfo.GetUnit) and checks them against your quest log.
-- Display only: it never targets, attacks, marks or interacts. The markers are our own frames; a
-- nameplate is only used as the point our marker is placed next to (SetPoint on OUR frame). Nothing is
-- ever called on a nameplate or any other game frame, and nothing is hooked.
local READ_EVERY = 2            -- seconds: one nameplate's tooltip is read at most this often
local MAX_READS_PER_FRAME = 3   -- tooltip reads per drawn frame, so a crowd of nameplates can't stutter
local LOG_DEBOUNCE = 1          -- seconds: bursts of quest log updates are read once
local WINDOW_EVERY = 0.5        -- seconds between list window refreshes
local MAX_CACHE = 200           -- remembered tooltip results before the memory is cleared
local MAX_WINDOW_ROWS = 8
local SIZES = { small = 14, medium = 20, large = 28 }
local SIZE_ORDER = { "small", "medium", "large" }
local ICON = "Interface\\GossipFrame\\AvailableQuestIcon"

-- Tooltip line kinds (Enum.TooltipDataLineType, TooltipInfoSharedDocumentation.lua): numbers as fallback.
local LINE_TYPES = (Enum and Enum.TooltipDataLineType) or {}
local LINE_OBJECTIVE = LINE_TYPES.QuestObjective or 8
local LINE_TITLE = LINE_TYPES.QuestTitle or 17
local LINE_PLAYER = LINE_TYPES.QuestPlayer or 18

local db
local plates = {}        -- nameplate unit token -> { dirty, result, marker }
local cache = {}         -- GUID (or token) -> { at, gen, quest, progress, title, secret }
local cacheCount = 0
local quests, questCount = {}, 0   -- normalized quest title -> { title, complete, objectives }
local logGen = 0
local logDirty, logReadAt = true, nil
local pool = {}
local anchorRestricted = false   -- set if the game refuses to place our marker next to a nameplate
local windowDirty, windowAt = true, 0
local container, window

local function Safe(value)
    if issecretvalue and issecretvalue(value) then
        return nil
    end
    return value
end

local function IsSecret(value)
    if issecretvalue and issecretvalue(value) then
        return true
    end
    if type(value) == "table" and issecrettable and issecrettable(value) then
        return true
    end
    return false
end

local function Now()
    return (GetTime and Safe(GetTime())) or 0
end

-- Page lines go only to the hub window. Without it, stay quiet: no chat.
local function Print(text)
    if ForeverHub_Receive then
        return ForeverHub_Receive("QuestMobs", text)
    end
end

---------------------------------------------------------------------------- text helpers

-- "Kobold Vermin slain: 3/8", " - 3/8 Kobold Vermin slain" and "kobold vermin slain" all give one key.
local function Key(text)
    if type(text) ~= "string" then
        return nil
    end
    local key = text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    key = key:gsub("%d+%s*/%s*%d+", ""):gsub("%d+%%", ""):lower():gsub("[^%a]", "")
    if key == "" then
        return nil
    end
    return key
end

local function Counts(text)
    local have, need = text:match("(%d+)%s*/%s*(%d+)")
    if have then
        return tonumber(have), tonumber(need), false
    end
    local percent = text:match("(%d+)%%")
    if percent then
        return tonumber(percent), 100, true
    end
end

local function Progress(have, need, percent)
    if not (have and need) then
        return nil
    elseif percent then
        return have .. "%"
    end
    return have .. "/" .. need
end

---------------------------------------------------------------------------- your quest log

local function ReadQuestLog()
    local list, count = {}, 0
    if not (C_QuestLog and C_QuestLog.GetNumQuestLogEntries and C_QuestLog.GetInfo) then
        return list, count
    end
    for index = 1, Safe(C_QuestLog.GetNumQuestLogEntries()) or 0 do
        local info = Safe(C_QuestLog.GetInfo(index))
        if type(info) == "table" and not Safe(info.isHeader) then
            local title, questID = Safe(info.title), Safe(info.questID)
            local key = Key(title)
            if key and questID then
                local entry = { title = title, objectives = {} }
                -- IsComplete is quest-wide readiness; an objective's own "finished" is the truth for a row
                -- (Forever has rows that read 1/1 while unfinished).
                entry.complete = C_QuestLog.IsComplete and Safe(C_QuestLog.IsComplete(questID)) == true or false
                local objectives = C_QuestLog.GetQuestObjectives and Safe(C_QuestLog.GetQuestObjectives(questID))
                for _, objective in ipairs(type(objectives) == "table" and objectives or {}) do
                    local okey = type(objective) == "table" and Key(Safe(objective.text))
                    if okey then
                        entry.objectives[okey] = {
                            finished = Safe(objective.finished) == true,
                            have = tonumber(Safe(objective.numFulfilled)),
                            need = tonumber(Safe(objective.numRequired)),
                        }
                    end
                end
                list[key] = entry
                count = count + 1
            end
        end
    end
    return list, count
end

-- An objective line from the tooltip, decided with your quest log when the log knows the row.
-- Returns unfinished, progress text; or nil, nil, true when the line is hidden from addons.
local function Objective(line, entry)
    local text = line.leftText
    if IsSecret(text) then
        return nil, nil, true
    end
    if type(text) ~= "string" then
        return false
    end
    if entry and entry.complete then
        return false
    end
    local key = Key(text)
    local have, need, percent = Counts(text)
    local row = entry and key and entry.objectives[key]
    if not row and not entry and key then
        -- No title above it: accept a row your log knows by its wording.
        for _, quest in pairs(quests) do
            if quest.objectives[key] and not quest.complete then
                row = quest.objectives[key]
                break
            end
        end
        if not row and questCount > 0 then
            return false   -- not a row of any quest in your log
        end
    end
    if row then
        if row.finished then
            return false
        end
        if row.need and row.need > 0 and not percent then
            have, need = row.have or have or 0, row.need
        end
        return true, Progress(have, need, percent)
    end
    local done = line.completed
    if IsSecret(done) then
        return nil, nil, true
    end
    if type(done) == "boolean" then
        return not done, Progress(have, need, percent)
    end
    if have and need then
        return have < need, Progress(have, need, percent)
    end
    return entry ~= nil, nil
end

---------------------------------------------------------------------------- reading one unit

-- "quest", progress, title | "no" | "secret"
local function ReadTooltip(unit)
    if not (C_TooltipInfo and C_TooltipInfo.GetUnit) then
        return "no"
    end
    local ok, data = pcall(C_TooltipInfo.GetUnit, unit)
    if not ok then
        return "secret"
    elseif data == nil then
        return "no"
    elseif IsSecret(data) then
        return "secret"
    end
    local lines = data.lines
    if IsSecret(lines) then
        return "secret"
    elseif type(lines) ~= "table" then
        return "no"
    end
    local me = UnitName and Safe(UnitName("player"))
    local entry, title, inBlock, mine, sawTitle = nil, nil, false, true, false
    for _, line in ipairs(lines) do
        if IsSecret(line) then
            return "secret"
        end
        if type(line) == "table" then
            local kind = line.type
            if IsSecret(kind) then
                return "secret"
            end
            if kind == LINE_TITLE then
                local text = line.leftText
                if IsSecret(text) then
                    return "secret"
                end
                local key = Key(text)
                entry = key and quests[key] or nil
                -- Only quests in your log count; before the log is read, trust the tooltip.
                inBlock = key ~= nil and (entry ~= nil or questCount == 0)
                title = entry and entry.title or text
                mine, sawTitle = true, true
            elseif kind == LINE_PLAYER then
                -- In a group the tooltip lists other players' progress under their names.
                local text = line.leftText
                if IsSecret(text) then
                    return "secret"
                end
                mine = type(text) == "string" and me ~= nil and text:find(me, 1, true) ~= nil
            elseif kind == LINE_OBJECTIVE and mine and (inBlock or not sawTitle) then
                local unfinished, progress, secret = Objective(line, inBlock and entry or nil)
                if secret then
                    return "secret"
                end
                if unfinished then
                    return "quest", progress, title
                end
            end
        end
    end
    return "no"
end

local function InInstance()
    if not IsInInstance then
        return false
    end
    local inside = IsInInstance()
    return IsSecret(inside) or inside == true
end

local function Allowed(unit)
    if type(unit) ~= "string" or IsSecret(unit) or InInstance() then
        return false
    end
    if not (UnitExists and Safe(UnitExists(unit))) then
        return false
    end
    if not (UnitCanAttack and Safe(UnitCanAttack("player", unit)) == true) then
        return false
    end
    if UnitIsPlayer and Safe(UnitIsPlayer(unit)) then
        return false
    end
    return true
end

-- The cache key: the unit's GUID, or the token when there is no GUID. nil, true when the GUID is secret.
local function UnitKey(unit)
    local raw = UnitGUID and UnitGUID(unit)
    if raw ~= nil and Safe(raw) == nil then
        return nil, true
    end
    return raw or unit
end

-- The result for a unit, reading its tooltip at most once every READ_EVERY seconds.
-- Returns result, didRead; result is nil when it changed but may not be read again yet.
local function Lookup(unit, now)
    local key, secret = UnitKey(unit)
    if not key then
        return { at = now, gen = logGen, secret = secret }, false
    end
    local hit = cache[key]
    if hit and now - hit.at < READ_EVERY then
        if hit.gen == logGen then
            return hit, false
        end
        return nil, false
    end
    local status, progress, title = ReadTooltip(unit)
    local result = {
        at = now, gen = logGen, quest = status == "quest", secret = status == "secret",
        progress = progress, title = title,
    }
    if not hit then
        cacheCount = cacheCount + 1
        if cacheCount > MAX_CACHE then
            cache, cacheCount = {}, 1
        end
    end
    cache[key] = result
    return result, true
end

---------------------------------------------------------------------------- markers (our own frames)

local function Size()
    return SIZES[db and db.size] or SIZES.medium
end

local function Container()
    if not container then
        container = CreateFrame("Frame", nil, UIParent)
        container:SetAllPoints(UIParent)
        container:SetFrameStrata("LOW")
    end
    return container
end

local function Acquire()
    local marker = table.remove(pool)
    if marker then
        return marker
    end
    marker = CreateFrame("Frame", nil, Container())
    marker.icon = marker:CreateTexture(nil, "ARTWORK")
    marker.icon:SetAllPoints(marker)
    marker.icon:SetTexture(ICON)
    marker.text = marker:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    marker.text:SetPoint("LEFT", marker, "RIGHT", 1, 0)
    marker.text:SetTextColor(1, 0.82, 0)
    return marker
end

local function Release(plate)
    local marker = plate and plate.marker
    if marker then
        marker:Hide()
        marker:ClearAllPoints()   -- never stay attached to a nameplate the game hands to another unit
        marker.text:SetText("")
        pool[#pool + 1] = marker
        plate.marker = nil
    end
end

local function ReleaseAll()
    for _, plate in pairs(plates) do
        Release(plate)
    end
end

local function ShowMarker(unit, plate)
    local nameplate
    if C_NamePlate and C_NamePlate.GetNamePlateForUnit then
        local ok, found = pcall(C_NamePlate.GetNamePlateForUnit, unit)
        nameplate = ok and Safe(found) or nil
    end
    if not nameplate then
        Release(plate)
        return
    end
    local marker = plate.marker or Acquire()
    plate.marker = marker
    marker:ClearAllPoints()
    -- Our frame is placed relative to the nameplate; the nameplate itself is never changed.
    if not pcall(marker.SetPoint, marker, "BOTTOM", nameplate, "TOP", 0, 2) then
        anchorRestricted = true
        windowDirty = true
        Release(plate)
        return
    end
    local size = Size()
    marker:SetSize(size, size)
    marker.text:SetText(plate.result and plate.result.progress or "")
    marker:Show()
end

local function Apply(unit, plate, result)
    plate.result = result
    windowDirty = true
    if result and result.quest and db and db.enabled and not anchorRestricted then
        ShowMarker(unit, plate)
    else
        Release(plate)
    end
end

local function ReapplyAll()
    for unit, plate in pairs(plates) do
        Apply(unit, plate, plate.result)
    end
end

---------------------------------------------------------------------------- list window (our own frame)

local function WindowWanted()
    return db and db.enabled and (db.list or anchorRestricted) and not InInstance()
end

local function NearbyList()
    local list = {}
    for unit, plate in pairs(plates) do
        local result = plate.result
        if result and result.quest then
            local name = UnitName and Safe(UnitName(unit))
            list[#list + 1] = {
                name = type(name) == "string" and name or "Unknown",
                progress = result.progress, title = result.title,
            }
        end
    end
    table.sort(list, function(a, b)
        return a.name < b.name
    end)
    return list
end

local function SaveWindowSpot()
    if not (window and db) then
        return
    end
    local point, _, relative, x, y = window:GetPoint(1)
    point, relative, x, y = Safe(point), Safe(relative), Safe(x), Safe(y)
    if type(point) == "string" and type(x) == "number" and type(y) == "number" then
        db.spot = { point, relative or point, x, y }
    end
end

local function Window()
    if window then
        return window
    end
    window = CreateFrame("Frame", nil, UIParent)
    window:SetSize(230, 34)
    window:SetFrameStrata("MEDIUM")
    window:SetClampedToScreen(true)
    window:SetMovable(true)
    window:EnableMouse(true)
    window:RegisterForDrag("LeftButton")
    window:SetScript("OnDragStart", function(self) self:StartMoving() end)
    window:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        SaveWindowSpot()
    end)
    local spot = db and type(db.spot) == "table" and db.spot
    if spot and type(spot[1]) == "string" and type(spot[3]) == "number" and type(spot[4]) == "number" then
        window:SetPoint(spot[1], UIParent, spot[2] or spot[1], spot[3], spot[4])
    else
        window:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -260, -220)
    end
    window.bg = window:CreateTexture(nil, "BACKGROUND")
    window.bg:SetAllPoints(window)
    window.bg:SetColorTexture(0, 0, 0, 0.6)
    window.title = window:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    window.title:SetPoint("TOPLEFT", window, "TOPLEFT", 8, -6)
    window.title:SetText("Quest mobs nearby")
    window.close = CreateFrame("Button", nil, window, "UIPanelCloseButton")
    window.close:SetSize(20, 20)
    window.close:SetPoint("TOPRIGHT", window, "TOPRIGHT", 0, 0)
    window.close:SetScript("OnClick", function()
        if db then
            db.list = false
        end
        window:Hide()
    end)
    window.rows = {}
    for i = 1, MAX_WINDOW_ROWS + 1 do
        local row = window:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        row:SetPoint("TOPLEFT", window, "TOPLEFT", 10, -10 - i * 14)
        row:SetWidth(212)
        row:SetJustifyH("LEFT")
        window.rows[i] = row
    end
    return window
end

local function RefreshWindow()
    windowDirty = false
    if not WindowWanted() then
        if window then
            window:Hide()
        end
        return
    end
    local frame = Window()
    local list = NearbyList()
    local shown = 0
    for i, row in ipairs(frame.rows) do
        local text = ""
        if i <= MAX_WINDOW_ROWS and list[i] then
            local mob = list[i]
            text = mob.name .. (mob.progress and ("  |cffffd100" .. mob.progress .. "|r") or "")
            shown = i
        elseif i == 1 and #list == 0 then
            text = "|cff999999None in sight.|r"
            shown = 1
        elseif i == MAX_WINDOW_ROWS + 1 and #list > MAX_WINDOW_ROWS then
            text = "|cff999999and " .. (#list - MAX_WINDOW_ROWS) .. " more|r"
            shown = i
        end
        row:SetText(text)
    end
    frame:SetHeight(30 + shown * 14)
    frame:Show()
end

---------------------------------------------------------------------------- work loop

local events = CreateFrame("Frame")

local function Tick()
    if not db then
        return
    end
    local now = Now()
    if logDirty and (not logReadAt or now - logReadAt >= LOG_DEBOUNCE) then
        logDirty, logReadAt = false, now
        quests, questCount = ReadQuestLog()
        logGen = logGen + 1
        for _, plate in pairs(plates) do
            plate.dirty = true
        end
    end
    local reads = 0
    for unit, plate in pairs(plates) do
        if reads >= MAX_READS_PER_FRAME then
            break
        end
        if plate.dirty then
            if not Allowed(unit) then
                plate.dirty = false
                Apply(unit, plate, nil)
            else
                local result, didRead = Lookup(unit, now)
                if didRead then
                    reads = reads + 1
                end
                if result then
                    plate.dirty = false
                    Apply(unit, plate, result)
                end
            end
        end
    end
    if windowDirty and now - windowAt >= WINDOW_EVERY then
        windowAt = now
        RefreshWindow()
    end
end

local function CheckInstance()
    if InInstance() then
        for _, plate in pairs(plates) do
            plate.result = nil
            plate.dirty = true
        end
        ReleaseAll()
    else
        for _, plate in pairs(plates) do
            plate.dirty = true
        end
    end
    windowDirty = true
end

---------------------------------------------------------------------------- page

local function OnOff(value)
    return value and "|cff33ff33on|r" or "|cff999999off|r"
end

local function ShowPage(notice)
    if not db then
        return
    end
    if notice then
        Print(notice)
        Print(" ")
    end
    Print("A small quest marker with your progress (like 3/8) next to enemies you still need for a quest in your log. It only reads what the game's own tooltip already says about that enemy. Only gives information.")
    Print(" ")
    Print(string.format("Markers: %s   Size: |cffffffff%s|r   List window: %s", OnOff(db.enabled), db.size, OnOff(db.list or anchorRestricted)))
    if anchorRestricted then
        Print("|cffff9933This game version won't let a marker sit next to a nameplate, so quest mobs are listed in the small window instead.|r")
    end
    if InInstance() then
        Print("|cff999999Inside dungeons, raids and battlegrounds the game hides quest lines from addons, so nothing is shown here.|r")
    end
    Print(" ")
    local list = NearbyList()
    if #list == 0 then
        Print("No quest mobs in sight. Turn on enemy nameplates (V) to see markers.")
    else
        Print("Quest mobs in sight:")
        for _, mob in ipairs(list) do
            local progress = mob.progress and ("  |cffffd100" .. mob.progress .. "|r") or ""
            local title = mob.title and ("  |cff999999" .. mob.title .. "|r") or ""
            Print("  " .. mob.name .. progress .. title)
        end
    end
    local hidden = 0
    for _, plate in pairs(plates) do
        if plate.result and plate.result.secret then
            hidden = hidden + 1
        end
    end
    if hidden > 0 then
        Print(string.format("|cff999999%d nearby enemies can't be read right now (the game hides them).|r", hidden))
    end
    Print(" ")
    Print("|cff999999Type: off   Or: on   Or: size large   Or: list on|r")
end

local function Command(message)
    if not db then
        return
    end
    local text = type(message) == "string" and message:lower():match("^%s*(.-)%s*$") or ""
    if text == "" then
        return ShowPage()
    elseif text == "on" or text == "off" then
        db.enabled = text == "on"
        if db.enabled then
            ReapplyAll()
        else
            ReleaseAll()
        end
        windowDirty = true
        RefreshWindow()
        return ShowPage(db.enabled and "Quest markers are on." or "Quest markers are off.")
    end
    local size = text:match("^size%s+(%a+)$")
    if size then
        if not SIZES[size] then
            return ShowPage("Sizes: " .. table.concat(SIZE_ORDER, ", ") .. ".")
        end
        db.size = size
        ReapplyAll()
        return ShowPage("Marker size: " .. size .. ".")
    end
    local list = text:match("^list%s+(%a+)$") or (text == "list" and "toggle")
    if list == "on" or list == "off" or list == "toggle" then
        if list == "toggle" then
            db.list = not db.list
        else
            db.list = list == "on"
        end
        windowDirty = true
        RefreshWindow()
        return ShowPage(db.list and "The list window is on." or "The list window is off.")
    end
    return ShowPage("Not sure what \"" .. text .. "\" means.")
end

---------------------------------------------------------------------------- for other helpers

-- true, "3/8" when the unit is an enemy you still need for a quest in your log (progress may be nil).
function QuestMobs_IsQuestMob(unit)
    if not db or not Allowed(unit) then
        return false
    end
    local result = Lookup(unit, Now())
    if not result then
        local key = UnitKey(unit)
        result = key and cache[key]
    end
    if result and result.quest then
        return true, result.progress
    end
    return false
end

---------------------------------------------------------------------------- events

events:RegisterEvent("PLAYER_LOGIN")
for _, name in ipairs({
    "PLAYER_ENTERING_WORLD", "ZONE_CHANGED_NEW_AREA", "NAME_PLATE_UNIT_ADDED", "NAME_PLATE_UNIT_REMOVED",
    "UNIT_NAME_UPDATE", "QUEST_LOG_UPDATE", "UNIT_QUEST_LOG_CHANGED",
}) do
    pcall(events.RegisterEvent, events, name)
end
events:SetScript("OnUpdate", Tick)
events:SetScript("OnEvent", function(_, event, unit)
    if event == "PLAYER_LOGIN" then
        QuestMobsDB = type(QuestMobsDB) == "table" and QuestMobsDB or {}
        db = QuestMobsDB
        if type(db.enabled) ~= "boolean" then
            db.enabled = true
        end
        if not SIZES[db.size] then
            db.size = "medium"
        end
        if type(db.list) ~= "boolean" then
            db.list = false
        end
        logDirty = true
        return
    end
    unit = Safe(unit)
    if event == "NAME_PLATE_UNIT_ADDED" then
        if type(unit) == "string" then
            Release(plates[unit])
            plates[unit] = { dirty = true }
        end
    elseif event == "NAME_PLATE_UNIT_REMOVED" then
        if type(unit) == "string" and plates[unit] then
            Release(plates[unit])
            plates[unit] = nil
            windowDirty = true
        end
    elseif event == "UNIT_NAME_UPDATE" then
        local plate = type(unit) == "string" and plates[unit]
        if plate then
            local key = UnitKey(unit)
            if key and cache[key] then
                cache[key].gen = -1
            end
            plate.dirty = true
        end
    elseif event == "QUEST_LOG_UPDATE" or event == "UNIT_QUEST_LOG_CHANGED" then
        logDirty = true
    elseif event == "PLAYER_ENTERING_WORLD" or event == "ZONE_CHANGED_NEW_AREA" then
        CheckInstance()
    end
end)

SLASH_QUESTMOBS1 = "/questmobs"
SlashCmdList = SlashCmdList or {}
SlashCmdList.QUESTMOBS = Command
