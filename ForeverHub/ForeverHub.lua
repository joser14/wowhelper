local PANEL_WIDTH, ROW_HEIGHT, MAX_ROWS = 280, 18, 10
local WIDTH, HEIGHT, SIDEBAR_WIDTH = 640, 480, 126
local NAV_HEIGHT = 22
local TOAST_WIDTH, TOAST_SECONDS, MAX_TOASTS = 300, 6, 3
local REPEAT_SECONDS = 15
local MAX_ALERTS = 100
local MINIMAP_RADIUS = 105
local DEFAULT_ANGLE = 215
local MAX_LEVEL = 60

-- Most useful first; the panel shows these in this order.
local STATUS_ORDER = { "RareWatch", "DeathNotes", "ItemAdvisor", "TalentNudge", "TrainerNotes", "QuestCheck", "DurabilityWatch", "BagCheck", "SupplyWatch", "ProfessionCap", "WeaponSkillWatch", "GoldGoal" }

-- Pages in the details window. "hidden" pages open from the panel but take no sidebar space.
local TABS = {
    { label = "Bag advice", key = "ITEMADVISOR", hint = "To change what stats to favor, type: role healer" },
    { label = "Quests", key = "QUESTCHECK" },
    { label = "Trainer", key = "TRAINERNOTES" },
    { label = "Professions", key = "PROFESSIONCAP" },
    { label = "Weapon skills", key = "WEAPONSKILLWATCH", arg = "all" },
    { label = "Food and drink", key = "FOODCHECK" },
    { label = "Supplies", key = "SUPPLYWATCH", hint = "Item in your bags and how many: Water 20   Or: remove 1   Or: ammo 400", supplies = true },
    { label = "Find an item", key = "ITEMFINDER", hint = "Type part of an item name and press Enter", emptyHint = "Search your bags, bank, and gear on every character.", search = true },
    { label = "Gold goal", key = "GOLDGOAL", hint = "Gold and a name: 500 Bags   Or: clear" },
    { label = "Rested XP", key = "RESTGUARD" },
    { label = "Places", key = "LANDMARKS", hint = "Type a kind to pin the nearest on your map: repair, vendor, food, inn, flight, mail, bank, trainer" },
    { label = "Deaths", key = "DEATHNOTES", hint = "Type a number to pin that death on your map. Or: forget 2   Or: forget all" },
    { label = "Reputation", key = "REPWATCH", arg = "all" },
    { label = "Level log", key = "LEVELLOG", arg = "all" },
    { label = "Characters", key = "FOREVERHELPER", arg = "chars", hint = "To-do: add Buy bags   Or: remove 1   Or: reset   Or: window" },
    { label = "Pop-up history", alerts = true },
    { label = "Errors", key = "ERRORLOG", hint = "Type a number for details, or: clear" },
    { label = "Talents", key = "TALENTNUDGE", hidden = true },
    { label = "Bag space", key = "BAGCHECK", hidden = true },
    { label = "Repairs", key = "DURABILITYWATCH", hidden = true },
    { label = "Zone", key = "ZONELEVELS", hidden = true },
}
local PAGE_BY_KEY, PAGE_BY_LABEL = {}, {}
for _, tab in ipairs(TABS) do
    PAGE_BY_LABEL[tab.label] = tab
    if tab.key then
        PAGE_BY_KEY[tab.key] = tab
    end
end

local db, frame, body, scroll, content, inputBox, hintText, panel
local statLines, rows = {}, {}
local currentTab, renderedTab
local originals = {}
local alerts = {}
local toasts = {}
local capture
local lastShown = {}
local rowsDirty = true
local session = {}
local XP_WINDOW_SECONDS = 900
-- One early sale or purchase would otherwise read as a huge hourly rate.
local GOLD_RATE_MIN_SECONDS = 600
local xpSamples = {}
local toastSerial = 0
local opening
-- True for the early pass at login, when helpers that load after the hub haven't set up yet.
local quietStatus
local wrappers = {}

local function Safe(value)
    if issecretvalue and issecretvalue(value) then
        return nil
    end
    return value
end

local function FormatGold(copper)
    local gold, silver = math.floor(copper / 10000), math.floor(copper / 100) % 100
    if gold > 0 then
        return string.format("%dg %ds", gold, silver)
    elseif silver > 0 then
        return string.format("%ds %dc", silver, copper % 100)
    end
    return string.format("%dc", copper % 100)
end

local function FormatDuration(seconds)
    local minutes = math.floor(seconds / 60)
    if minutes >= 60 then
        return string.format("%dh %dm", math.floor(minutes / 60), minutes % 60)
    end
    return string.format("%dm", math.max(minutes, 1))
end

local function SetDarkBackdrop(target, alpha)
    target:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 14,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    target:SetBackdropColor(0.04, 0.04, 0.07, alpha)
    target:SetBackdropBorderColor(0.5, 0.5, 0.55, 0.9)
end

-- Runs an addon's command and returns the lines it wanted to show.
local function RunCommand(key, arg)
    local handler = originals[key] or SlashCmdList[key]
    if not handler then
        return { "|cff999999This addon isn't turned on.|r" }
    end
    local lines = {}
    capture = lines
    local ok, err = pcall(handler, arg or "")
    capture = nil
    if not ok then
        lines[#lines + 1] = "|cffff6666Something went wrong here. It's saved on the Errors page.|r"
        geterrorhandler()(err)
    end
    return lines
end

-- keepScroll leaves the page where you were reading; otherwise a new page starts at the top.
local function SetBody(text, keepScroll)
    local oldPosition = keepScroll and Safe(scroll:GetVerticalScroll()) or 0
    local oldHeight = keepScroll and Safe(content:GetHeight()) or 0
    body:SetText(text)
    local newHeight = math.max((Safe(body:GetStringHeight()) or 0) + 8, 1)
    content:SetHeight(newHeight)
    local position = 0
    if keepScroll and oldPosition > 0 then
        -- Newest lines are added on top, so move down by what was added to keep the same lines in view.
        position = oldPosition + math.max(newHeight - oldHeight, 0)
        local view = Safe(scroll:GetHeight())
        if view then
            position = math.min(position, math.max(newHeight - view, 0))
        end
    end
    scroll:SetVerticalScroll(position)
end

local function AlertsText()
    if #alerts == 0 then
        return "No pop-ups yet this session."
    end
    local parts = {}
    local now = GetTime()
    for index = #alerts, 1, -1 do
        local alert = alerts[index]
        local line = "|cff999999" .. alert.source .. ":|r " .. alert.text
        if alert.count > 1 then
            line = line .. string.format("  |cff999999(%d times)|r", alert.count)
        end
        local age = now - alert.time
        parts[#parts + 1] = line .. "  |cff666666" .. (age < 60 and "just now" or FormatDuration(age) .. " ago") .. "|r"
    end
    return table.concat(parts, "\n")
end

local function RenderPage(prefixLines)
    local tab = currentTab
    -- A new pop-up redraws the history page while you may be scrolled down in it; stay put then.
    -- Choosing a page or opening the window clears renderedTab, so those still start at the top.
    local keepScroll = tab.alerts and renderedTab == tab
    renderedTab = tab
    local text
    if tab.alerts then
        text = AlertsText()
    elseif tab.search then
        text = tab.emptyHint
    else
        text = table.concat(RunCommand(tab.key, tab.arg), "\n")
    end
    if text == "" then
        text = "|cff999999Nothing to show right now.|r"
    end
    if prefixLines and #prefixLines > 0 then
        text = table.concat(prefixLines, "\n") .. "\n\n" .. text
    end
    SetBody(text, keepScroll)
end

local function SelectTab(tab, prefixLines)
    currentTab = tab
    renderedTab = nil
    for _, candidate in ipairs(TABS) do
        if candidate.button then
            if candidate == tab then
                candidate.button:LockHighlight()
            else
                candidate.button:UnlockHighlight()
            end
        end
    end
    local hasInput = tab.hint ~= nil
    hintText:SetShown(hasInput)
    inputBox:SetShown(hasInput)
    hintText:SetText(tab.hint or "")
    inputBox:SetText("")
    inputBox:ClearFocus()
    scroll:ClearAllPoints()
    scroll:SetPoint("TOPLEFT", frame, "TOPLEFT", SIDEBAR_WIDTH + 22, hasInput and -84 or -36)
    scroll:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -34, 14)
    -- A hidden window fills in when it opens. At login, other addons may not have started yet.
    if frame:IsShown() then
        RenderPage(prefixLines)
    end
end

-- Finds an item link in your bags from part of its name, so no one needs to shift-click into chat.
local function FindBagLink(text)
    local needle = text:lower()
    local partial
    for bag = 0, (NUM_TOTAL_EQUIPPED_BAG_SLOTS or NUM_BAG_SLOTS or 4) do
        for slot = 1, Safe(C_Container.GetContainerNumSlots(bag)) or 0 do
            local info = C_Container.GetContainerItemInfo(bag, slot)
            local link = info and Safe(info.hyperlink)
            local name = link and link:match("%[(.-)%]")
            local lower = name and name:lower()
            -- A full name wins, so "Water" isn't taken as "Watermelon" just because it comes first.
            if lower == needle then
                return link
            elseif lower and not partial and lower:find(needle, 1, true) then
                partial = link
            end
        end
    end
    return partial
end

local function SupplyCommand(text)
    local lower = text:lower()
    if lower:match("^remove%s") or lower:match("^ammo%s") then
        return text
    end
    local name, amount = text:match("^(.-)%s+(%d+)$")
    if not name then
        return nil, "Type an item name and an amount, such as: Water 20"
    end
    local link = FindBagLink(name)
    if not link then
        return nil, "Couldn't find \"" .. name .. "\" in your bags."
    end
    return "add " .. link .. " " .. amount
end

local function SubmitInput(text)
    text = text:match("^%s*(.-)%s*$")
    if text == "" or not currentTab or not currentTab.key then
        return
    end
    inputBox:SetText("")
    if currentTab.search then
        local lines = RunCommand(currentTab.key, text)
        -- A blank page would look like the search never ran.
        if #lines == 0 then
            lines = { "|cff999999Nothing found for \"" .. text .. "\".|r" }
        end
        SetBody(table.concat(lines, "\n"))
        return
    end
    local command, problem = text, nil
    if currentTab.supplies then
        command, problem = SupplyCommand(text)
    end
    if not command then
        RenderPage({ "|cffffaa66" .. problem .. "|r" })
        return
    end
    RenderPage(RunCommand(currentTab.key, command))
    rowsDirty = true
end

local function MakeDraggable(target, key)
    target:SetClampedToScreen(true)
    target:SetMovable(true)
    target:EnableMouse(true)
    target:RegisterForDrag("LeftButton")
    target:SetScript("OnDragStart", target.StartMoving)
    target:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local point, _, relativePoint, x, y = self:GetPoint()
        db[key] = { point, relativePoint, x, y }
    end)
end

local function BuildWindow()
    -- Blizzard's own window frame, so it matches the rest of the game.
    frame = CreateFrame("Frame", "ForeverHubFrame", UIParent, "ButtonFrameTemplate")
    frame:SetSize(WIDTH, HEIGHT)
    if ButtonFrameTemplate_HidePortrait then
        ButtonFrameTemplate_HidePortrait(frame)
    end
    if ButtonFrameTemplate_HideAttic then
        ButtonFrameTemplate_HideAttic(frame)
    end
    if ButtonFrameTemplate_HideButtonBar then
        ButtonFrameTemplate_HideButtonBar(frame)
    end
    if frame.SetTitle then
        frame:SetTitle("Forever Hub")
    end
    frame:SetFrameStrata("HIGH")
    MakeDraggable(frame, "position")
    if db.position then
        local p = db.position
        frame:SetPoint(p[1], UIParent, p[2], p[3], p[4])
    else
        frame:SetPoint("CENTER", UIParent, "CENTER", 0, 40)
    end
    frame:Hide()
    table.insert(UISpecialFrames, "ForeverHubFrame")
    frame:SetScript("OnShow", function()
        -- OpenPage draws its own page right after, so drawing the old one first is wasted work.
        if currentTab and not opening then
            renderedTab = nil
            RenderPage()
        end
    end)

    local visible = 0
    for _, tab in ipairs(TABS) do
        if not tab.hidden then
            visible = visible + 1
            local button = CreateFrame("Button", nil, frame)
            button:SetSize(SIDEBAR_WIDTH, NAV_HEIGHT)
            button:SetPoint("TOPLEFT", frame, "TOPLEFT", 10, -30 - (visible - 1) * NAV_HEIGHT)
            button:SetNormalFontObject(GameFontHighlightSmall)
            button:SetHighlightFontObject(GameFontNormalSmall)
            button:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
            button:SetText(tab.label)
            local label = button:GetFontString()
            if label then
                label:ClearAllPoints()
                label:SetPoint("LEFT", button, "LEFT", 8, 0)
            end
            button:SetScript("OnClick", function()
                SelectTab(tab)
            end)
            tab.button = button
        end
    end

    hintText = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    hintText:SetPoint("TOPLEFT", frame, "TOPLEFT", SIDEBAR_WIDTH + 22, -36)
    hintText:SetPoint("RIGHT", frame, "RIGHT", -14, 0)
    hintText:SetJustifyH("LEFT")

    inputBox = CreateFrame("EditBox", nil, frame, "BackdropTemplate")
    inputBox:SetPoint("TOPLEFT", frame, "TOPLEFT", SIDEBAR_WIDTH + 22, -52)
    inputBox:SetPoint("RIGHT", frame, "RIGHT", -14, 0)
    inputBox:SetHeight(24)
    SetDarkBackdrop(inputBox, 1)
    inputBox:SetFontObject(GameFontHighlight)
    inputBox:SetTextInsets(8, 8, 0, 0)
    inputBox:SetAutoFocus(false)
    inputBox:SetScript("OnEnterPressed", function(self)
        SubmitInput(self:GetText())
    end)
    inputBox:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
    end)

    scroll = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
    content = CreateFrame("Frame", nil, scroll)
    content:SetSize(WIDTH - SIDEBAR_WIDTH - 64, 1)
    scroll:SetScrollChild(content)
    body = content:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    body:SetPoint("TOPLEFT", content, "TOPLEFT", 0, 0)
    body:SetWidth(WIDTH - SIDEBAR_WIDTH - 64)
    body:SetJustifyH("LEFT")
    body:SetJustifyV("TOP")
    body:SetWordWrap(true)
    body:SetSpacing(3)

    SelectTab(TABS[1])
end

local function OpenPage(tab, prefixLines)
    opening = true
    frame:Show()
    opening = false
    SelectTab(tab, prefixLines)
end

-- XP waiting in quests that are finished but not turned in yet. Read at most every few seconds,
-- since the panel refreshes more often than the quest log changes.
local QUEST_XP_SECONDS = 5
local questXP, questXPAt = 0, -QUEST_XP_SECONDS
local function FinishedQuestXP(now)
    if now - questXPAt < QUEST_XP_SECONDS then
        return questXP
    end
    questXPAt = now
    local total = 0
    if C_QuestLog and C_QuestLog.GetNumQuestLogEntries and C_QuestLog.GetInfo and C_QuestLog.IsComplete and GetQuestLogRewardXP then
        for index = 1, Safe(C_QuestLog.GetNumQuestLogEntries()) or 0 do
            local info = C_QuestLog.GetInfo(index)
            local questID = info and not Safe(info.isHeader) and Safe(info.questID)
            if questID and Safe(C_QuestLog.IsComplete(questID)) then
                total = total + (tonumber(Safe(GetQuestLogRewardXP(questID))) or 0)
            end
        end
    end
    questXP = total
    return total
end

-- The always-on panel: your rates at the top, then only what needs doing.
local function RefreshStats()
    local now = GetTime()
    local elapsed = math.max(now - session.start, 60)
    while xpSamples[1] and now - xpSamples[1].time > XP_WINDOW_SECONDS do
        table.remove(xpSamples, 1)
    end
    local recentXP = 0
    for _, sample in ipairs(xpSamples) do
        recentXP = recentXP + sample.amount
    end
    local level = Safe(UnitLevel("player"))
    local xp, maxXP = Safe(UnitXP("player")), Safe(UnitXPMax("player"))
    if level and level < MAX_LEVEL and xp and maxXP and maxXP > 0 then
        local banked = FinishedQuestXP(now)
        statLines[1]:SetText(string.format("Level %d  |cffffd100%d%%|r%s", level, math.floor(xp * 100 / maxXP),
            banked > 0 and string.format("  |cff33ff33+%d%% to turn in|r", math.floor(banked * 100 / maxXP)) or ""))
        -- Recent play only, so a break or a long town visit doesn't drag the estimate out.
        local rate = recentXP * 3600 / math.min(elapsed, XP_WINDOW_SECONDS)
        if rate > 0 then
            statLines[2]:SetText(string.format("Next level in %s", FormatDuration((maxXP - xp) * 3600 / rate)))
        else
            statLines[2]:SetText("|cff999999Next level time appears once you earn XP|r")
        end
        local rested = Safe(GetXPExhaustion()) or 0
        statLines[3]:SetText(rested > 0 and string.format("Rested %d%% of this level", math.floor(rested * 100 / maxXP)) or "|cff999999Not rested|r")
    else
        statLines[1]:SetText(level and string.format("Level %d", level) or "")
        statLines[2]:SetText("")
        statLines[3]:SetText("")
    end
    local money = Safe(GetMoney())
    if money and not session.money then
        -- Gold was hidden at login; start counting from the first time it can be read.
        session.money, session.moneySince = money, now
    end
    if money then
        local earned = money - session.money
        local goldElapsed = now - session.moneySince
        if earned == 0 or goldElapsed < GOLD_RATE_MIN_SECONDS then
            statLines[4]:SetText(FormatGold(money))
        else
            local sign = earned > 0 and "+" or "-"
            statLines[4]:SetText(string.format("%s  |cff999999%s%s/hr|r", FormatGold(money), sign, FormatGold(math.floor(math.abs(earned) * 3600 / goldElapsed))))
        end
    else
        statLines[4]:SetText("")
    end
end

local function GatherStatus()
    local items = {}
    for _, name in ipairs(STATUS_ORDER) do
        local source = ForeverHubStatus and ForeverHubStatus[name]
        if source then
            local ok, result = pcall(source)
            if ok then
                -- A helper answering with something other than a list mustn't take the others down.
                for _, entry in ipairs(type(result) == "table" and result or {}) do
                    if type(entry) == "table" then
                        items[#items + 1] = entry
                    end
                end
            elseif not quietStatus then
                geterrorhandler()(result)
            end
        end
    end
    return items
end

local function GetRow(index)
    if rows[index] then
        return rows[index]
    end
    local row = CreateFrame("Button", nil, panel)
    row:SetSize(PANEL_WIDTH - 16, ROW_HEIGHT)
    row:SetNormalFontObject(GameFontHighlightSmall)
    row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
    row:SetScript("OnClick", function(self)
        local page = self.page and PAGE_BY_LABEL[self.page]
        if page then
            OpenPage(page)
        elseif self.extra then
            frame:Show()
        end
    end)
    row:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        if self.link then
            -- A malformed link from a helper shouldn't break the panel.
            if not pcall(GameTooltip.SetHyperlink, GameTooltip, self.link) then
                GameTooltip:Hide()
                return
            end
        elseif self.extra then
            for _, text in ipairs(self.extra) do
                GameTooltip:AddLine(text, 1, 1, 1)
            end
        else
            -- Long lines are cut off on the panel, so show the whole line on hover.
            local label = self:GetFontString()
            if not (label and label.IsTruncated and Safe(label:IsTruncated())) then
                GameTooltip:Hide()
                return
            end
            GameTooltip:AddLine(self.fullText, 1, 1, 1)
        end
        GameTooltip:Show()
    end)
    row:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    rows[index] = row
    return row
end

local function RefreshRows()
    local items = GatherStatus()
    if #items > MAX_ROWS then
        -- Say so rather than silently dropping what doesn't fit, and list them on hover.
        local extra = {}
        for index = MAX_ROWS, #items do
            extra[#extra + 1] = tostring(items[index].text)
        end
        items[MAX_ROWS] = { text = string.format("|cff999999%d more. Point here to see them.|r", #extra), extra = extra }
    end
    local shown = math.min(#items, MAX_ROWS)
    for index = 1, shown do
        local item = items[index]
        local row = GetRow(index)
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", panel, "TOPLEFT", 8, -70 - (index - 1) * ROW_HEIGHT)
        row:SetText(item.text)
        local label = row:GetFontString()
        if label then
            label:ClearAllPoints()
            label:SetPoint("LEFT", row, "LEFT", 2, 0)
            label:SetPoint("RIGHT", row, "RIGHT", -2, 0)
            label:SetJustifyH("LEFT")
            label:SetWordWrap(false)
        end
        row.page, row.link, row.extra, row.fullText = item.page, item.link, item.extra, item.text
        row:Show()
    end
    for index = shown + 1, #rows do
        rows[index]:Hide()
    end
    panel.empty:SetShown(shown == 0)
    panel:SetHeight(70 + math.max(shown, 1) * ROW_HEIGHT + 8)
end

local function BuildPanel()
    panel = CreateFrame("Frame", "ForeverHubPanel", UIParent, "BackdropTemplate")
    panel:SetWidth(PANEL_WIDTH)
    SetDarkBackdrop(panel, 0.72)
    MakeDraggable(panel, "panelPosition")
    -- Held by its top-left corner, so the top stays put as rows come and go.
    panel:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local left, top = self:GetLeft(), self:GetTop()
        if left and top then
            self:ClearAllPoints()
            self:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left, top)
            db.panelTopLeft = { left, top }
        end
    end)
    if db.panelTopLeft then
        panel:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", db.panelTopLeft[1], db.panelTopLeft[2])
    else
        panel:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 16, -220)
    end

    local details = CreateFrame("Button", nil, panel)
    details:SetSize(50, 16)
    details:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -24, -6)
    details:SetNormalFontObject(GameFontNormalSmall)
    details:SetHighlightFontObject(GameFontHighlightSmall)
    details:SetText("Details")
    details:SetScript("OnClick", function()
        frame:SetShown(not frame:IsShown())
    end)

    local close = CreateFrame("Button", nil, panel, "UIPanelCloseButton")
    close:SetSize(22, 22)
    close:SetPoint("TOPRIGHT", panel, "TOPRIGHT", 0, 0)

    for index = 1, 4 do
        local line = panel:CreateFontString(nil, "OVERLAY", index == 1 and "GameFontNormal" or "GameFontHighlightSmall")
        line:SetPoint("TOPLEFT", panel, "TOPLEFT", 10, index == 1 and -8 or (-12 - (index - 1) * 14))
        line:SetJustifyH("LEFT")
        statLines[index] = line
    end

    panel.empty = panel:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    panel.empty:SetPoint("TOPLEFT", panel, "TOPLEFT", 10, -74)
    panel.empty:SetText("All caught up.")
    panel:Hide()
end

local function PositionMinimapButton(button)
    local radians = math.rad(db.angle or DEFAULT_ANGLE)
    button:ClearAllPoints()
    button:SetPoint("CENTER", Minimap, "CENTER", math.cos(radians) * MINIMAP_RADIUS, math.sin(radians) * MINIMAP_RADIUS)
end

local function BuildMinimapButton()
    local button = CreateFrame("Button", "ForeverHubMinimapButton", Minimap)
    button:SetSize(32, 32)
    button:SetFrameStrata("MEDIUM")
    button:SetFrameLevel(8)
    local icon = button:CreateTexture(nil, "BACKGROUND")
    icon:SetSize(20, 20)
    icon:SetPoint("CENTER", button, "CENTER", 0, 0)
    icon:SetTexture("Interface\\Icons\\INV_Misc_Book_09")
    local border = button:CreateTexture(nil, "OVERLAY")
    border:SetSize(54, 54)
    border:SetPoint("TOPLEFT", button, "TOPLEFT", 0, 0)
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    button:RegisterForDrag("LeftButton")
    button:SetScript("OnClick", function(_, mouseButton)
        if mouseButton == "RightButton" then
            frame:SetShown(not frame:IsShown())
        else
            panel:SetShown(not panel:IsShown())
        end
    end)
    button:SetScript("OnDragStart", function(self)
        self:SetScript("OnUpdate", function()
            local x, y = GetCursorPosition()
            local scale = Minimap:GetEffectiveScale()
            local centerX, centerY = Minimap:GetCenter()
            db.angle = math.deg(math.atan2(y / scale - centerY, x / scale - centerX))
            PositionMinimapButton(self)
        end)
    end)
    button:SetScript("OnDragStop", function(self)
        self:SetScript("OnUpdate", nil)
    end)
    button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:SetText("Forever Hub")
        GameTooltip:AddLine("Left-click: panel. Right-click: details. Drag: move.", 1, 1, 1)
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    PositionMinimapButton(button)
end

local function ArrangeToasts()
    local shown = {}
    for _, toast in ipairs(toasts) do
        if toast:IsShown() then
            shown[#shown + 1] = toast
        end
    end
    -- Oldest on top, so a new message doesn't move the one you're reading.
    table.sort(shown, function(a, b)
        return a.shownAt < b.shownAt
    end)
    -- Below the leveling guide, which sits at the top of the screen.
    local offset = 170
    for _, toast in ipairs(shown) do
        toast:ClearAllPoints()
        toast:SetPoint("TOP", UIParent, "TOP", 0, -offset)
        -- Stacked by real height, so a two-line message doesn't cover the next one.
        offset = offset + (Safe(toast:GetHeight()) or 44) + 8
    end
end

local function GetToast()
    for _, toast in ipairs(toasts) do
        if not toast:IsShown() then
            return toast
        end
    end
    if #toasts >= MAX_TOASTS then
        -- All full, so the oldest one makes room.
        local oldest = toasts[1]
        for _, toast in ipairs(toasts) do
            if toast.shownAt < oldest.shownAt then
                oldest = toast
            end
        end
        return oldest
    end
    local toast = CreateFrame("Button", nil, UIParent, "BackdropTemplate")
    toast:SetSize(TOAST_WIDTH, 44)
    SetDarkBackdrop(toast, 0.85)
    toast:SetFrameStrata("MEDIUM")
    toast.message = toast:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    toast.message:SetPoint("TOPLEFT", toast, "TOPLEFT", 10, -10)
    toast.message:SetPoint("RIGHT", toast, "RIGHT", -10, 0)
    toast.message:SetJustifyH("LEFT")
    toast:SetScript("OnClick", function(self)
        self:Hide()
        ArrangeToasts()
    end)
    toasts[#toasts + 1] = toast
    return toast
end

local function ShowToast(text)
    local toast = GetToast()
    -- A counter, not the clock: several messages in one frame share a time, and the
    -- older timer would then hide the newer message early.
    toastSerial = toastSerial + 1
    local stamp = toastSerial
    toast.shownAt = stamp
    toast.message:SetText(text)
    toast:SetHeight(math.max((Safe(toast.message:GetStringHeight()) or 16) + 20, 36))
    toast:Show()
    ArrangeToasts()
    C_Timer.After(TOAST_SECONDS, function()
        -- A newer message may have reused this pop-up, and that one keeps its full time.
        if toast.shownAt == stamp then
            toast:Hide()
            ArrangeToasts()
        end
    end)
end

-- Every helper addon sends its messages here instead of to chat.
function ForeverHub_Receive(source, text)
    -- A helper may pass on something it read from the game; never let that break the hub.
    text, source = Safe(text), Safe(source)
    if text == nil then
        return
    end
    text, source = tostring(text), tostring(source or "")
    if capture then
        capture[#capture + 1] = text
        return
    end
    rowsDirty = true
    local now = GetTime()
    local last = alerts[#alerts]
    if last and last.source == source and last.text == text then
        -- Repeats are counted, so the history isn't one message over and over.
        last.count, last.time = last.count + 1, now
    else
        alerts[#alerts + 1] = { source = source, text = text, time = now, count = 1 }
        if #alerts > MAX_ALERTS then
            table.remove(alerts, 1)
        end
    end
    if frame and frame:IsShown() and currentTab and currentTab.alerts then
        RenderPage()
    end
    if lastShown[text] and now - lastShown[text] < REPEAT_SECONDS then
        return
    end
    -- Old entries are of no use once they can't suppress a repeat any more.
    for key, when in pairs(lastShown) do
        if now - when >= REPEAT_SECONDS then
            lastShown[key] = nil
        end
    end
    lastShown[text] = now
    if frame then
        ShowToast(text)
    end
end

-- Anyone who still types a command gets the window instead of chat lines. Safe to run again: commands
-- already wrapped are skipped, and ones a helper registered (or replaced) since then get wrapped.
local function WrapCommands()
    for key, tab in pairs(PAGE_BY_KEY) do
        local handler = SlashCmdList[key]
        if handler and handler ~= wrappers[key] then
            originals[key] = handler
            wrappers[key] = function(message)
                local arg = message and message:match("^%s*(.-)%s*$") or ""
                OpenPage(tab, arg ~= "" and RunCommand(key, arg) or nil)
            end
            SlashCmdList[key] = wrappers[key]
        end
    end
end

local function TrackXP()
    local xp, maxXP = Safe(UnitXP("player")), Safe(UnitXPMax("player"))
    if not (xp and maxXP) then
        return
    end
    local gained = 0
    if session.lastXP then
        if xp >= session.lastXP then
            gained = xp - session.lastXP
        elseif session.lastMax then
            gained = session.lastMax - session.lastXP + xp
        end
    end
    if gained > 0 then
        xpSamples[#xpSamples + 1] = { time = GetTime(), amount = gained }
    end
    session.lastXP, session.lastMax = xp, maxXP
end

local function Attempt(step)
    local ok, err = pcall(step)
    if not ok then
        geterrorhandler()(err)
    end
end

local function OnTick()
    Attempt(RefreshStats)
    if rowsDirty and panel and panel:IsShown() and not (InCombatLockdown and InCombatLockdown()) then
        rowsDirty = false
        Attempt(RefreshRows)
    end
end

local function Start()
    ForeverHubDB = ForeverHubDB or {}
    db = ForeverHubDB
    -- You asked for the screen narration voice to stay off; this also keeps it off at the login screen.
    if C_CVar and C_CVar.SetCVar then
        pcall(C_CVar.SetCVar, "accessibilityScreenNarrationEnabled", "0")
    end
    session.start = GetTime()
    session.money, session.moneySince = Safe(GetMoney()), session.start
    session.lastXP, session.lastMax = Safe(UnitXP("player")), Safe(UnitXPMax("player"))
    -- Each step runs on its own, so a problem with one still leaves the rest usable.
    Attempt(BuildWindow)
    Attempt(BuildPanel)
    Attempt(BuildMinimapButton)
    Attempt(WrapCommands)
    Attempt(function()
        panel:Show()
    end)
    Attempt(function()
        for index = math.max(#alerts - MAX_TOASTS + 1, 1), #alerts do
            ShowToast(alerts[index].text)
        end
    end)
    -- The hub loads before most helpers, so it hears PLAYER_LOGIN before they set up. This first pass
    -- fills the panel with what's ready and keeps quiet about helpers that aren't yet.
    quietStatus = true
    Attempt(OnTick)
    quietStatus = false
    rowsDirty = true
    -- One frame later every helper has run its login code: wrap the commands they registered there and
    -- check them all again, this time reporting real problems.
    C_Timer.After(0, function()
        Attempt(WrapCommands)
        rowsDirty = true
        Attempt(OnTick)
    end)
    C_Timer.NewTicker(1, function()
        Attempt(OnTick)
    end)
end

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN")
for _, name in ipairs({ "BAG_UPDATE_DELAYED", "PLAYER_EQUIPMENT_CHANGED", "QUEST_LOG_UPDATE", "PLAYER_LEVEL_UP", "PLAYER_MONEY",
    "SKILL_LINES_CHANGED", "TRAINER_UPDATE", "PLAYER_REGEN_ENABLED", "PLAYER_ENTERING_WORLD", "UPDATE_INVENTORY_DURABILITY", "PLAYER_XP_UPDATE",
    "TRAIT_CONFIG_UPDATED" }) do
    events:RegisterEvent(name)
end
events:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_LOGIN" then
        Start()
    elseif event == "PLAYER_XP_UPDATE" then
        if session.start then
            TrackXP()
        end
    else
        rowsDirty = true
    end
end)

SLASH_FOREVERHUB1 = "/hub"
SlashCmdList.FOREVERHUB = function()
    if panel then
        panel:SetShown(not panel:IsShown())
    end
end
