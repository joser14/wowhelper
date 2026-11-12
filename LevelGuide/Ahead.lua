-- Upgrades ahead (research\re_round6.md #12): quest rewards on the next turn-ins of your leveling route that
-- ItemAdvisor rates as upgrades for your role, so you don't buy or keep a stopgap for a slot a quest fills soon.
-- The guide shows the first as "Upgrade ahead: <item> from <quest> (step N)" (N = the step's number in the route
-- list); clicking that line opens this file's own list window. ItemAdvisor's Bag advice page lists them too
-- (LevelGuide_UpgradesAhead).
-- Rewards: QuestRewards.lua (generated from ALL THE THINGS' Forever database, MIT; see its header). Judged by
-- ItemAdvisor_Judge (ItemAdvisor's own weights against what you wear); without ItemAdvisor nothing is shown.
-- Read-only: nothing is accepted, chosen or equipped. No frame is made until the window is first opened.
LevelGuideAhead = {
    MAX_QUESTS = 25,   -- route turn-ins looked at, from the guide's current step on
    MAX_LIST = 20,     -- upgrades kept (the window shows them all)
    REFRESH = 5,       -- seconds between judgements while the route stays the same
}
local A = LevelGuideAhead
local ROWS, ROW_HEIGHT, WIDTH = 20, 16, 440
local state = { list = {}, at = nil, signature = nil, pending = 0 }
local parsed = {}
local window

local function Safe(value)
    if issecretvalue and issecretvalue(value) then
        return nil
    end
    return value
end

-- Reward item IDs of a quest (QuestRewards.lua), parsed once per quest.
function A.Rewards(questID)
    local data = LevelGuideQuestRewards and LevelGuideQuestRewards.r
    local raw = data and data[questID]
    if type(raw) ~= "string" then
        return {}
    end
    local ids = parsed[questID]
    if not ids then
        ids = {}
        for id in raw:gmatch("%d+") do
            ids[#ids + 1] = tonumber(id)
        end
        parsed[questID] = ids
    end
    return ids
end

-- The item's link (its quality colour and name) once the game has it, else "item <id>".
local function ItemText(itemID)
    if C_Item and C_Item.GetItemInfo then
        local ok, name, link = pcall(C_Item.GetItemInfo, itemID)
        name, link = ok and Safe(name), ok and Safe(link)
        if type(link) == "string" and link ~= "" then
            return link
        elseif type(name) == "string" and name ~= "" then
            return name
        end
    end
    return "item " .. tostring(itemID)
end

local function InCombat()
    return UnitAffectingCombat and Safe(UnitAffectingCombat("player")) == true
end

-- quests: the route's next turn-ins in order, { step, id, title, questLevel }. Judges their rewards with
-- ItemAdvisor at most every REFRESH seconds (at once when the list of quests changes) and keeps, per quest,
-- the reward with the biggest gain. In combat worn gear can be hidden: the last list stays.
function A.Update(quests, now)
    now = tonumber(now) or 0
    local parts = {}
    for index = 1, math.min(#quests, A.MAX_QUESTS) do
        parts[index] = tostring(quests[index].id) .. "@" .. tostring(quests[index].step)
    end
    local signature = table.concat(parts, ",")
    if signature == state.signature and state.at and now - state.at < A.REFRESH then
        return
    end
    if InCombat() then
        return
    end
    state.signature, state.at = signature, now
    local judge = ItemAdvisor_Judge
    if type(judge) ~= "function" then
        state.list, state.pending = {}, 0
        return
    end
    local list, pending = {}, 0
    for index = 1, math.min(#quests, A.MAX_QUESTS) do
        local quest = quests[index]
        local best
        for _, itemID in ipairs(A.Rewards(quest.id)) do
            local ok, verdict = pcall(judge, itemID)
            if not ok or verdict == nil then
                pending = pending + 1
            elseif type(verdict) == "table" and verdict.upgrade then
                local gain = tonumber(verdict.gain) or 0
                if not best or gain > best.gain then
                    best = { step = quest.step, quest = tostring(quest.title or ("quest " .. quest.id)), questID = quest.id,
                        itemID = itemID, reason = tostring(verdict.reason or ""), gain = gain,
                        percent = tonumber(verdict.percent), level = tonumber(verdict.level),
                        questLevel = tonumber(quest.questLevel) }
                end
            end
        end
        if best then
            best.itemText = ItemText(best.itemID)
            list[#list + 1] = best
            if #list >= A.MAX_LIST then
                break
            end
        end
    end
    state.list, state.pending = list, pending
    -- Items still loading: judge again sooner than REFRESH (ItemAdvisor asked the game for them).
    if pending > 0 then
        state.at = now - A.REFRESH + 1
    end
    if window and window:IsShown() then
        A.Refresh()
    end
end

function A.First()
    return state.list[1]
end

function A.List()
    return state.list
end

-- The guide's line for one upgrade.
function A.Line(entry)
    local extra = ""
    if entry.percent then
        extra = string.format(" |cff33ff33+%d%%|r", entry.percent)
    end
    if entry.level then
        extra = extra .. string.format(" |cff999999(wear at %d)|r", entry.level)
    end
    return string.format("|cffa335eeUpgrade ahead:|r %s from %s (step %d)%s", tostring(entry.itemText), entry.quest,
        tonumber(entry.step) or 0, extra)
end

-- For other helpers (ItemAdvisor's Bag advice page): copies, so nobody changes the guide's list.
function LevelGuide_UpgradesAhead()
    local copy = {}
    for index, entry in ipairs(state.list) do
        local row = {}
        for key, value in pairs(entry) do
            row[key] = value
        end
        copy[index] = row
    end
    return copy
end

----- The list window: our own frame and tooltip, never Blizzard's ------------------------------------------

local tip
local function Tip()
    if not tip then
        tip = CreateFrame("GameTooltip", "LevelGuideAheadTooltip", UIParent, "GameTooltipTemplate")
    end
    return tip
end

function A.Refresh()
    if not window then
        return
    end
    local list = state.list
    window.title:SetText(string.format("Upgrades ahead on your route  |cff999999(%d)|r", #list))
    if #list == 0 then
        window.empty:SetText(state.pending > 0 and "Reading the rewards' stats..."
            or "No quest reward on your next route steps beats what you wear.")
        window.empty:Show()
    else
        window.empty:Hide()
    end
    for index = 1, ROWS do
        local row, entry = window.rows[index], list[index]
        row.entry = entry
        if entry then
            row.left:SetText(string.format("|cff999999%d.|r %s  |cff999999from|r %s", entry.step, tostring(entry.itemText), entry.quest))
            row.right:SetText(entry.percent and string.format("|cff33ff33+%d%%|r", entry.percent)
                or (entry.level and string.format("|cff999999at %d|r", entry.level) or ""))
            row:Show()
        else
            row:Hide()
        end
    end
end

local function Build()
    window = CreateFrame("Frame", "LevelGuideAheadFrame", UIParent, "BackdropTemplate")
    window:SetSize(WIDTH, ROWS * ROW_HEIGHT + 48)
    window:SetFrameStrata("MEDIUM")
    window:SetClampedToScreen(true)
    window:SetMovable(true)
    window:EnableMouse(true)
    window:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 14,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    window:SetBackdropColor(0.04, 0.04, 0.07, 0.92)
    window:SetBackdropBorderColor(0.5, 0.5, 0.55, 0.9)
    window:SetPoint("CENTER", UIParent, "CENTER", 0, 60)
    window:RegisterForDrag("LeftButton")
    window:SetScript("OnDragStart", function(self) self:StartMoving() end)
    window:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
    window.title = window:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    window.title:SetPoint("TOPLEFT", window, "TOPLEFT", 10, -9)
    local close = CreateFrame("Button", nil, window)
    close:SetSize(20, 18)
    close:SetPoint("TOPRIGHT", window, "TOPRIGHT", -5, -4)
    close:SetNormalFontObject(GameFontNormal)
    close:SetHighlightFontObject(GameFontHighlight)
    close:SetText("x")
    close:SetScript("OnClick", function() window:Hide() end)
    window.empty = window:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    window.empty:SetPoint("TOPLEFT", window, "TOPLEFT", 10, -28)
    local hint = window:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    hint:SetPoint("BOTTOMLEFT", window, "BOTTOMLEFT", 10, 8)
    hint:SetText("Step = its number in the route list. Hover a row for the item. Judged by ItemAdvisor for your role.")
    window.rows = {}
    for index = 1, ROWS do
        local row = CreateFrame("Button", nil, window)
        row:SetHeight(ROW_HEIGHT)
        row:SetPoint("TOPLEFT", window, "TOPLEFT", 8, -24 - (index - 1) * ROW_HEIGHT)
        row:SetPoint("RIGHT", window, "RIGHT", -8, 0)
        row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
        row.left = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        row.left:SetJustifyH("LEFT")
        row.left:SetWordWrap(false)
        row.right = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        row.right:SetPoint("RIGHT", row, "RIGHT", -2, 0)
        row.left:SetPoint("LEFT", row, "LEFT", 2, 0)
        row.left:SetPoint("RIGHT", row.right, "LEFT", -4, 0)
        row:SetScript("OnEnter", function(self) A.ShowTip(self, self.entry) end)
        row:SetScript("OnLeave", function() Tip():Hide() end)
        row:Hide()
        window.rows[index] = row
    end
    window:Hide()
end

-- The item on our own tooltip, with the quest and ItemAdvisor's reason.
function A.ShowTip(owner, entry)
    if not entry then
        return
    end
    local t = Tip()
    t:SetOwner(owner, "ANCHOR_RIGHT")
    if t.SetHyperlink then
        pcall(t.SetHyperlink, t, "item:" .. entry.itemID)
    else
        t:SetText(tostring(entry.itemText))
    end
    t:AddLine(string.format("Reward of %s (route step %d%s)", entry.quest, entry.step,
        entry.questLevel and string.format(", quest level %d", entry.questLevel) or ""), 0.6, 0.8, 1, true)
    t:AddLine(entry.reason, 0.2, 1, 0.2, true)
    t:AddLine("Rewards from ALL THE THINGS' Forever data; check the quest window, some Forever rewards changed.", 0.6, 0.6, 0.6, true)
    t:Show()
end

function A.Toggle()
    if not window then
        Build()
    end
    if window:IsShown() then
        window:Hide()
    else
        window:Show()
        A.Refresh()
    end
end
