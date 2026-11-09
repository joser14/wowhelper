const fs = require('fs');
const root = process.argv[2];
const edits = [
['TrainerNotes/TrainerNotes.lua', `-- The trainer window only lists what its filters show, so this only learns from what's visible.
local function ReadTrainer()
    if not charData then
        return
    end
    for index = 1, Safe(GetNumTrainerServices()) or 0 do
        local name, serviceType, _, level, subText = GetTrainerServiceInfo(index)
        name, serviceType, level, subText = Safe(name), Safe(serviceType), Safe(level), Safe(subText)
        if name and serviceType and serviceType ~= "header" then
            local key = name .. "|" .. (subText or "")
            if serviceType == "used" then
                charData.services[key] = nil
            else
                charData.services[key] = {`, `-- Recipes and pet skills aren't something you need to go back and train, and recipes have no level.
local function IsSpellTrainer()
    if C_Trainer and C_Trainer.GetTrainerType and Enum and Enum.TrainerType then
        return Safe(C_Trainer.GetTrainerType()) == Enum.TrainerType.General
    end
    return not (IsTradeskillTrainer and Safe(IsTradeskillTrainer()))
end

-- With the "used" filter off, as it is by default, a bought spell just leaves the list. Only trust
-- a missing entry when the filters that show unbought spells are both on.
local function ListIsComplete()
    return GetTrainerServiceTypeFilter and Safe(GetTrainerServiceTypeFilter("available"))
        and Safe(GetTrainerServiceTypeFilter("unavailable"))
end

local function ForgetMissing(listed)
    local complete = ListIsComplete()
    if not complete then
        return
    end
    local matches, stored = 0, 0
    for key in pairs(charData.services) do
        stored = stored + 1
        if listed[key] then
            matches = matches + 1
        end
    end
    -- Mostly the same list means your class trainer, so what's missing was bought earlier.
    -- A weapon master barely overlaps, so nothing is forgotten because of one.
    local isFullList = matches * 2 >= stored
    for key in pairs(charData.services) do
        local boughtJustNow = openList and openList[key]
        if not listed[key] and (boughtJustNow or isFullList) then
            charData.services[key] = nil
        end
    end
    openList = listed
end

local function ReadTrainer()
    if not (charData and IsSpellTrainer()) then
        return
    end
    local count = Safe(GetNumTrainerServices()) or 0
    if count == 0 then
        -- The list can be empty for a moment as the window opens.
        return
    end
    local listed = {}
    for index = 1, count do
        local name, serviceType, _, level, subText = GetTrainerServiceInfo(index)
        name, serviceType, level, subText = Safe(name), Safe(serviceType), Safe(level), Safe(subText)
        if name and serviceType and serviceType ~= "header" then
            local key = name .. "|" .. (subText or "")
            if serviceType == "used" then
                charData.services[key] = nil
            else
                listed[key] = true
                charData.services[key] = {`],
['TrainerNotes/TrainerNotes.lua', `                    cost = Safe((GetTrainerServiceCost(index))) or 0,
                }
            end
        end
    end
end`, `                    cost = Safe((GetTrainerServiceCost(index))) or 0,
                }
            end
        end
    end
    ForgetMissing(listed)
end`],
['TrainerNotes/TrainerNotes.lua', `local charData
`, `local charData, openList
`],
['TrainerNotes/TrainerNotes.lua', `events:RegisterEvent("TRAINER_UPDATE")
`, `events:RegisterEvent("TRAINER_UPDATE")
events:RegisterEvent("TRAINER_CLOSED")
`],
['TrainerNotes/TrainerNotes.lua', `        charData = TrainerNotesDB[key]
    elseif event == "PLAYER_LEVEL_UP" then`, `        charData = TrainerNotesDB[key]
        -- Older versions also saved recipes, which all have level 0 and looked ready to train forever.
        for serviceKey, service in pairs(charData.services) do
            if (service.level or 0) <= 0 then
                charData.services[serviceKey] = nil
            end
        end
    elseif event == "TRAINER_CLOSED" then
        openList = nil
    elseif event == "PLAYER_LEVEL_UP" then`],
['TrainerNotes/TrainerNotes.lua', `ForeverHubStatus = ForeverHubStatus or {}ForeverHubStatus.TrainerNotes`, `ForeverHubStatus = ForeverHubStatus or {}
ForeverHubStatus.TrainerNotes`],
['ForeverHelper/ForeverHelper.lua', `        db.shown = frame:IsShown()
        SaveCharacter()
`, `        -- Not saved here: the game can give wrong values while logging out, and the events above keep this current.
        db.shown = frame:IsShown()
`],
['!ErrorLog/!ErrorLog.lua', `    if #entries >= MAX_ENTRIES then
        return
    end
    stack = Safe(stack)`, `    -- A full list drops its oldest error, so a new problem is never the one lost.
    if #entries >= MAX_ENTRIES then
        table.remove(entries, 1)
    end
    stack = Safe(stack)`],
['BagCheck/BagCheck.lua', `local function CheckSpace()
    local free = FreeSlots()
    if free <= LOW_FREE_SLOTS and not warned then`, `local function BagsLoaded()
    return (Safe(C_Container.GetContainerNumSlots(0)) or 0) > 0
end

local function CheckSpace()
    if not BagsLoaded() then
        return
    end
    local free = FreeSlots()
    if free <= LOW_FREE_SLOTS and not warned then`],
['BagCheck/BagCheck.lua', `    if event == "MERCHANT_SHOW" then
        ReportJunk()
    else`, `    if event == "MERCHANT_SHOW" then
        -- ItemAdvisor's vendor pop-up already includes junk.
        if not (ForeverHubStatus and ForeverHubStatus.ItemAdvisor) then
            ReportJunk()
        end
    else`],
['BagCheck/BagCheck.lua', `ForeverHubStatus.BagCheck = function()
    local free = FreeSlots()
    if free <= LOW_FREE_SLOTS then`, `ForeverHubStatus.BagCheck = function()
    local free = FreeSlots()
    if BagsLoaded() and free <= LOW_FREE_SLOTS then`],
['WeaponSkillWatch/WeaponSkillWatch.lua', `local warned = {}
`, `local warned = {}

-- These classes cast rather than swing, so a low staff or dagger skill changes nothing. Their wand skill still matters.
local CASTER_CLASSES = { MAGE = true, PRIEST = true, WARLOCK = true }
local RANGED_SLOT = 18
`],
['WeaponSkillWatch/WeaponSkillWatch.lua', `-- Returns the skill line for the weapon in a slot, or nil if the slot holds no weapon.`, `local function SlotMatters(slot)
    return slot == RANGED_SLOT or not CASTER_CLASSES[Safe(select(2, UnitClass("player")))]
end

-- Returns the skill line for the weapon in a slot, or nil if the slot holds no weapon.`],
['WeaponSkillWatch/WeaponSkillWatch.lua', `    for slot, label in pairs(WATCHED_SLOTS) do
        local line = SlotSkillLine(slot)`, `    for slot, label in pairs(WATCHED_SLOTS) do
        local line = SlotMatters(slot) and SlotSkillLine(slot)`],
['WeaponSkillWatch/WeaponSkillWatch.lua', `        local line = SlotSkillLine(slot)
        local name, rank, maxRank`, `        local line = SlotMatters(slot) and SlotSkillLine(slot)
        local name, rank, maxRank`],
['QuestCheck/QuestCheck.lua', `if info and not Safe(info.isHeader) and not Safe(info.isHidden) then`, `if info and not Safe(info.isHeader) and not Safe(info.isHidden) and not Safe(info.isTask) then`],
['QuestCheck/QuestCheck.lua', `    Print("Quests under collapsed headers aren't checked.")
`, ``],
['GoldGoal/GoldGoal.lua', `    local percent = math.min(math.floor(money * 100 / (goal.gold * COPPER_PER_GOLD)), 100)
    return {`, `    local level = Safe(UnitLevel("player"))
    if money >= goal.gold * COPPER_PER_GOLD and level and level >= (goal.level or 1) then
        return { { text = string.format("|cff33ff33Buy|r %s (%dg)", goal.short or goal.name, goal.gold), page = "Gold goal" } }
    end
    local percent = math.min(math.floor(money * 100 / (goal.gold * COPPER_PER_GOLD)), 100)
    return {`],
['ItemFinder/ItemFinder.lua', `local charData
`, `local charData
local bankOpen = false
`],
['ItemFinder/ItemFinder.lua', `        if name:find("Bank", 1, true) and not name:find("Account", 1, true) then`, `        local lower = name:lower()
        if lower:find("bank", 1, true) and not lower:find("account", 1, true) then`],
['ItemFinder/ItemFinder.lua', `local function SaveGear()`, `-- The bank can only be read while its window is open, and an unread one reports no slots.
local function SaveBank()
    if not (charData and bankOpen) then
        return
    end
    local slots = 0
    local list = BankList()
    for _, bag in ipairs(list) do
        slots = slots + (Safe(C_Container.GetContainerNumSlots(bag)) or 0)
    end
    if slots > 0 then
        charData.bank = ScanContainers(list)
    end
end

local function SaveGear()`],
['ItemFinder/ItemFinder.lua', `pcall(events.RegisterEvent, events, "BANKFRAME_OPENED")
`, `pcall(events.RegisterEvent, events, "BANKFRAME_OPENED")
pcall(events.RegisterEvent, events, "BANKFRAME_CLOSED")
pcall(events.RegisterEvent, events, "PLAYERBANKSLOTS_CHANGED")
`],
['ItemFinder/ItemFinder.lua', `        SaveGear()
    elseif event == "PLAYER_EQUIPMENT_CHANGED" then
        SaveGear()
    elseif charData then
        charData.bank = ScanContainers(BankList())
    end`, `        SaveGear()
        SaveBank()
    elseif event == "PLAYER_EQUIPMENT_CHANGED" then
        SaveGear()
    elseif event == "BANKFRAME_OPENED" then
        bankOpen = true
        SaveBank()
    elseif event == "BANKFRAME_CLOSED" then
        bankOpen = false
    else
        SaveBank()
    end`],
['ItemAdvisor/ItemAdvisor.lua', `    if event == "QUEST_LOG_UPDATE" then
        RebuildQuestItems()
        return
    end
    if event ~= "PLAYER_LOGIN" then`, `    if event == "QUEST_LOG_UPDATE" then
        RebuildQuestItems()
        -- Picking up or finishing a quest can change whether an item is safe to sell.
        if charData then
            ScheduleRepaint()
        end
        return
    end
    if event ~= "PLAYER_LOGIN" then`],
['ForeverHub/ForeverHub.lua', `        return string.format("%dg %ds", gold, silver)
    end
    return string.format("%ds %dc", silver, copper % 100)
end`, `        return string.format("%dg %ds", gold, silver)
    elseif silver > 0 then
        return string.format("%ds %dc", silver, copper % 100)
    end
    return string.format("%dc", copper % 100)
end`],
['ForeverHub/ForeverHub.lua', `    local items = GatherStatus()
    local shown = math.min(#items, MAX_ROWS)`, `    local items = GatherStatus()
    if #items > MAX_ROWS then
        -- Say so rather than silently dropping what doesn't fit.
        items[MAX_ROWS] = { text = string.format("|cff999999%d more. Open Details to see them.|r", #items - MAX_ROWS + 1) }
    end
    local shown = math.min(#items, MAX_ROWS)`],
['ForeverHub/ForeverHub.lua', `    MakeDraggable(panel, "panelPosition")
    if db.panelPosition then
        local p = db.panelPosition
        panel:SetPoint(p[1], UIParent, p[2], p[3], p[4])
    else
        panel:SetPoint("LEFT", UIParent, "LEFT", 16, 120)
    end
`, `    MakeDraggable(panel, "panelPosition")
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
`],
['ForeverHub/ForeverHub.lua', `        for index = 1, math.min(#alerts, MAX_TOASTS) do
            ShowToast(alerts[index].text)
        end`, `        for index = math.max(#alerts - MAX_TOASTS + 1, 1), #alerts do
            ShowToast(alerts[index].text)
        end`],
];
for (const [file, oldText, newText] of edits) {
    const path = root + '/' + file;
    const raw = fs.readFileSync(path, 'utf8');
    const crlf = raw.includes('\r\n');
    const text = raw.replace(/\r\n/g, '\n');
    const count = text.split(oldText).length - 1;
    if (count !== 1) throw new Error(file + ': matched ' + count + ' times: ' + oldText.slice(0, 70));
    let out = text.replace(oldText, () => newText);
    if (crlf) out = out.replace(/\n/g, '\r\n');
    fs.writeFileSync(path, out);
}
console.log('applied ' + edits.length);
