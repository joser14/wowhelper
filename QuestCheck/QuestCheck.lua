local LOW_FREE_SLOTS = 3

local warned = false

local function Safe(value)
    if issecretvalue and issecretvalue(value) then
        return nil
    end
    return value
end

local function Print(text)
    if ForeverHub_Receive then
        return ForeverHub_Receive("QuestCheck", text)
    end
    -- No hub window to show it in: stay quiet rather than fill the chat.
end

-- Returns used and maximum quest log slots, or nil before the log has loaded.
local function LogSlots()
    local _, used = C_QuestLog.GetNumQuestLogEntries()
    local maximum = C_QuestLog.GetMaxNumQuestsCanAccept()
    used, maximum = Safe(used), Safe(maximum)
    if not (used and maximum and maximum > 0) then
        return nil
    end
    return used, maximum
end

local function ReadQuests()
    local groups = { ready = {}, gray = {}, group = {} }
    local entries = C_QuestLog.GetNumQuestLogEntries()
    for index = 1, Safe(entries) or 0 do
        local info = C_QuestLog.GetInfo(index)
        if info and not Safe(info.isHeader) and not Safe(info.isHidden) and not Safe(info.isTask) then
            local questID, title, level = Safe(info.questID), Safe(info.title), Safe(info.level)
            if questID and title then
                local line = level and string.format("[%d] %s", level, title) or title
                if Safe(C_QuestLog.IsComplete(questID)) or Safe(C_QuestLog.ReadyForTurnIn(questID)) then
                    table.insert(groups.ready, line)
                elseif Safe(C_QuestLog.IsQuestTrivial(questID)) then
                    table.insert(groups.gray, line)
                end
                local size = Safe(info.suggestedGroup) or 0
                if size > 1 then
                    table.insert(groups.group, string.format("%s (group of %d)", line, size))
                end
            end
        end
    end
    return groups
end

local function CheckLog()
    local used, maximum = LogSlots()
    if not used then
        return
    end
    local free = maximum - used
    if free <= LOW_FREE_SLOTS and not warned then
        if not ForeverHub_Receive then UIErrorsFrame:AddMessage(string.format("Quest log nearly full: %d free", free), 1, 0.8, 0.1) end
        Print(string.format("Quest log nearly full: %d/%d. The Quests page shows what you could finish or drop.", used, maximum))
    end
    warned = free <= LOW_FREE_SLOTS
end

local function PrintGroup(heading, lines)
    if #lines > 0 then
        Print(heading .. ":")
        for _, line in ipairs(lines) do
            Print("  " .. line)
        end
    end
end

-- Forever asks each new character to pick "Classic" or "Enhanced". Classic turns the map's quest markers
-- and objective areas off by default, and LevelGuide (map "!" offers) and QuestMobs read those, so they
-- show less. C_GameRules.GetForeverExperiencePreset: 0 = Classic, 1 = Enhanced (API docs).
local CLASSIC_PRESET = 0
local PRESET_TEXT = "Your character uses Forever's Classic preset, which hides quest markers and objective areas on the map by default. "
    .. "The leveling guide and quest-mob markers use them; if they show little, turn the map's quest markers back on in the world map's settings."

local function ClassicPreset()
    if not (C_GameRules and C_GameRules.GetForeverExperiencePreset) then
        return false
    end
    local ok, preset = pcall(C_GameRules.GetForeverExperiencePreset)
    return ok and Safe(preset) == CLASSIC_PRESET
end

local function ShowReport()
    local used, maximum = LogSlots()
    if used then
        Print(string.format("%d/%d quests.", used, maximum))
    end
    local groups = ReadQuests()
    PrintGroup("Ready to turn in", groups.ready)
    PrintGroup("Gray (low XP)", groups.gray)
    PrintGroup("Suggested group", groups.group)
    if #groups.ready + #groups.gray + #groups.group == 0 then
        Print("Nothing to flag.")
    end
    if ClassicPreset() then
        Print("|cff999999" .. PRESET_TEXT .. "|r")
    end
end

local events = CreateFrame("Frame")
events:RegisterEvent("QUEST_LOG_UPDATE")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_ENTERING_WORLD" then
        -- Said once per character; the Quests page keeps saying it.
        QuestCheckCharDB = type(QuestCheckCharDB) == "table" and QuestCheckCharDB or {}
        if not QuestCheckCharDB.presetNoted and ClassicPreset() then
            QuestCheckCharDB.presetNoted = true
            Print(PRESET_TEXT)
        end
        return
    end
    CheckLog()
end)

SLASH_QUESTCHECK1 = "/qc"
SLASH_QUESTCHECK2 = "/questcheck"
SlashCmdList.QUESTCHECK = ShowReport

ForeverHubStatus = ForeverHubStatus or {}
ForeverHubStatus.QuestCheck = function()
    local items = {}
    local groups = ReadQuests()
    if #groups.ready > 0 then
        items[#items + 1] = { text = string.format("|cffee9966Turn in|r %d quest(s)", #groups.ready), page = "Quests" }
    end
    local used, maximum = LogSlots()
    if used and maximum - used <= LOW_FREE_SLOTS then
        items[#items + 1] = { text = string.format("|cffee9966Quest log|r %d/%d full", used, maximum), page = "Quests" }
    end
    return items
end
