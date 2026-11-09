const fs = require('fs');
const root = process.argv[2];
const edits = [
// ItemAdvisor: let other helpers ask about a reward.
['ItemAdvisor/ItemAdvisor.lua', `ForeverHubStatus = ForeverHubStatus or {}
ForeverHubStatus.ItemAdvisor = function()`, `-- Lets other helpers ask, such as the quest tracker asking about a quest's rewards.
function ItemAdvisor_IsUpgrade(link)
    if not charData then
        return false
    end
    local verdict, reason = Evaluate(link)
    return verdict == "EQUIP", reason
end

ForeverHubStatus = ForeverHubStatus or {}
ForeverHubStatus.ItemAdvisor = function()`],

// Hub: rares come first.
['ForeverHub/ForeverHub.lua', `local STATUS_ORDER = { "ItemAdvisor",`, `local STATUS_ORDER = { "RareWatch", "ItemAdvisor",`],

// TrainerNotes: say when you can't afford it yet.
['TrainerNotes/TrainerNotes.lua', `    local ready = SplitServices(level)
    if #ready > 0 then
        return { { text = string.format("|cffaaddffTrain|r %d spell(s), %s", #ready, ShortMoney(TotalCost(ready))), page = "Trainer" } }
    end`, `    local ready = SplitServices(level)
    if #ready > 0 then
        local cost = TotalCost(ready)
        local money = GetMoney and Safe(GetMoney())
        local shortBy = money and money < cost and string.format(", |cffff6666%s short|r", ShortMoney(cost - money)) or ""
        return { { text = string.format("|cffaaddffTrain|r %d spell(s), %s%s", #ready, ShortMoney(cost), shortBy), page = "Trainer" } }
    end`],

// ItemFinder: what you own elsewhere, on the tooltip.
['ItemFinder/ItemFinder.lua', `local events = CreateFrame("Frame")`, `local function OwnedElsewhereText(name)
    local mine = ItemFinderDB[myKey]
    local parts = {}
    local elsewhere = false
    if mine then
        if mine.bags and mine.bags[name] then
            parts[#parts + 1] = "bags " .. mine.bags[name]
        end
        if mine.bank and mine.bank[name] then
            parts[#parts + 1] = "bank " .. mine.bank[name]
            elsewhere = true
        end
    end
    local others = {}
    for character, data in pairs(ItemFinderDB) do
        if character ~= myKey then
            local count = ((data.bags and data.bags[name]) or 0) + ((data.bank and data.bank[name]) or 0) + ((data.gear and data.gear[name]) or 0)
            if count > 0 then
                others[#others + 1] = (character:match("^[^-]+") or character) .. " " .. count
                elsewhere = true
            end
        end
    end
    table.sort(others)
    for _, text in ipairs(others) do
        parts[#parts + 1] = text
    end
    -- Only your own bags is what you're already looking at, so it isn't worth a line.
    return elsewhere and table.concat(parts, ", ") or nil
end

local function OnTooltip(tooltip)
    if not charData or (tooltip ~= GameTooltip and tooltip ~= ItemRefTooltip) then
        return
    end
    local name = Safe((TooltipUtil.GetDisplayedItem(tooltip)))
    local text = type(name) == "string" and name ~= "" and OwnedElsewhereText(name)
    if text then
        tooltip:AddLine("Owned: " .. text, 0.6, 0.8, 1)
    end
end

local events = CreateFrame("Frame")`],
['ItemFinder/ItemFinder.lua', `local bankOpen = false
`, `local bankOpen = false
local myKey
`],
['ItemFinder/ItemFinder.lua', `        charData = ItemFinderDB[key]
        SaveBags()`, `        charData = ItemFinderDB[key]
        myKey = key
        if TooltipDataProcessor and TooltipUtil and Enum and Enum.TooltipDataType then
            TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, OnTooltip)
        end
        SaveBags()`],

// QuestTracker: rewards that are upgrades.
['QuestTracker/QuestTracker.lua', `-- The same order Blizzard's tracker uses: the quest's own text, then its waypoint.`, `-- Looks through a quest's rewards for one ItemAdvisor would tell you to equip. Results are kept until
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
            C_Item.RequestLoadItemDataByID(itemID)
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

-- The same order Blizzard's tracker uses: the quest's own text, then its waypoint.`],
['QuestTracker/QuestTracker.lua', `    if quest.ready then
        quest.turnIn = TurnInText(quest)
    end
    return quest`, `    if quest.ready then
        quest.turnIn = TurnInText(quest)
    end
    quest.upgrade = FindRewardUpgrade(questID)
    return quest`],
['QuestTracker/QuestTracker.lua', `local requested = {}
`, `local requested = {}
local upgradeCache = {}
local requestedMap
local OFFERS_SECTION = { name = "Quests nearby", quests = {}, isLocal = true,
    note = "Quests the game shows on your map that you haven't picked up. Click one to mark it." }
`],
['QuestTracker/QuestTracker.lua', `local function QuestTag(quest)
    local tags = ""`, `local function QuestTag(quest)
    local tags = ""
    if quest.upgrade then
        tags = tags .. " " .. COLOR_READY .. "Upgrade|r"
    end`],
['QuestTracker/QuestTracker.lua', `    if quest.money and quest.money > 0 then
        GameTooltip:AddLine("Reward: " .. ShortMoney(quest.money), 1, 0.85, 0.2)
    end`, `    if quest.money and quest.money > 0 then
        GameTooltip:AddLine("Reward: " .. ShortMoney(quest.money), 1, 0.85, 0.2)
    end
    if quest.upgrade then
        GameTooltip:AddLine("Upgrade: " .. quest.upgrade.link, 0.2, 1, 0.2)
    end`],

// QuestTracker: quests you haven't picked up.
['QuestTracker/QuestTracker.lua', `local function CurrentZone()`, `local function YardsBetween(mapID, x1, y1, x2, y2)
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
    if not (C_Map.SetUserWaypoint and UiMapPoint and UiMapPoint.CreateFromCoordinates) then
        return
    end
    C_Map.SetUserWaypoint(UiMapPoint.CreateFromCoordinates(offer.mapID, offer.x, offer.y))
    if C_SuperTrack and C_SuperTrack.SetSuperTrackedUserWaypoint then
        C_SuperTrack.SetSuperTrackedUserWaypoint(true)
    end
end

local function CurrentZone()`],
['QuestTracker/QuestTracker.lua', `local RESORT_SECONDS, NEW_SECONDS = 3, 3600`, `local RESORT_SECONDS, NEW_SECONDS, MAX_OFFERS = 3, 3600, 3`],
['QuestTracker/QuestTracker.lua', `local function SectionTooltip(owner, section)
    GameTooltip:SetOwner(owner, "ANCHOR_LEFT")
    GameTooltip:SetText(section.name, 1, 0.82, 0)`, `local function SectionTooltip(owner, section)
    GameTooltip:SetOwner(owner, "ANCHOR_LEFT")
    GameTooltip:SetText(section.name, 1, 0.82, 0)
    if section.note then
        GameTooltip:AddLine(section.note, 1, 1, 1, true)
    end`],
['QuestTracker/QuestTracker.lua', `    if row.section then
        db.zones[row.section.name] = not SectionOpen(row.section)
        dirty = true
    elseif row.quest then`, `    if row.section then
        db.zones[row.section.name] = not SectionOpen(row.section)
        dirty = true
    elseif row.offer then
        MarkOffer(row.offer)
    elseif row.quest then`],
['QuestTracker/QuestTracker.lua', `    if row.quest then
        QuestTooltip(row, row.quest)
    elseif row.section then`, `    if row.quest then
        QuestTooltip(row, row.quest)
    elseif row.offer then
        GameTooltip:SetOwner(row, "ANCHOR_LEFT")
        GameTooltip:SetText(row.offer.name, 1, 0.82, 0)
        GameTooltip:AddLine("Left-click: mark it on your map.", 0.6, 0.6, 0.6)
        GameTooltip:Show()
    elseif row.section then`],
['QuestTracker/QuestTracker.lua', `    row.quest, row.section, row.objectiveIndex = nil, nil, nil
    row.bar:Hide()
    row:Show()`, `    row.quest, row.section, row.objectiveIndex, row.offer = nil, nil, nil, nil
    row.bar:Hide()
    row:Show()`],
['QuestTracker/QuestTracker.lua', `    if #ready > 0 then
        local totalXP = 0`, `    local function AddOffers()
        local offers = ReadOffers()
        if #offers == 0 then
            return
        end
        local open = SectionOpen(OFFERS_SECTION)
        local header = AddRow(SECTION_HEIGHT, 0, string.format("%s%s%s (%d)|r", COLOR_FOCUS, open and "- " or "+ ", OFFERS_SECTION.name, #offers))
        if header then
            header.section = OFFERS_SECTION
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
        local totalXP = 0`],
['QuestTracker/QuestTracker.lua', `    for _, section in ipairs(zones) do
        local open = SectionOpen(section)`, `    for sectionIndex, section in ipairs(zones) do
        local open = SectionOpen(section)`],
['QuestTracker/QuestTracker.lua', `                    if line then
                        line.quest, line.objectiveIndex = quest, index
                    end
                end
            end
        end
    end
    if hiddenRows > 0 then`, `                    if line then
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
    if hiddenRows > 0 then`],
['QuestTracker/QuestTracker.lua', `    return table.concat(ids, ",")`, `    for _, offer in ipairs(ReadOffers()) do
        ids[#ids + 1] = "offer" .. offer.id
    end
    return table.concat(ids, ",")`],
['QuestTracker/QuestTracker.lua', `"SUPER_TRACKING_CHANGED", "QUEST_DATA_LOAD_RESULT" }) do`, `"SUPER_TRACKING_CHANGED", "QUEST_DATA_LOAD_RESULT", "PLAYER_EQUIPMENT_CHANGED", "GET_ITEM_INFO_RECEIVED" }) do`],
['QuestTracker/QuestTracker.lua', `    if event == "QUEST_ACCEPTED" and questID and GetServerTime then`, `    if event == "PLAYER_EQUIPMENT_CHANGED" or event == "PLAYER_LEVEL_UP" then
        upgradeCache = {}
    end
    if event == "QUEST_ACCEPTED" and questID and GetServerTime then`],
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
