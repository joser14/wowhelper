-- Current cap = the next rank, the level it needs, and the skill a trainer wants before teaching it
-- (same as Classic, per Forever's profession guides). Other caps have no next rank here.
local NEXT_RANK = {
    [75] = { name = "Journeyman", level = 10, skill = 50 },
    [150] = { name = "Expert", level = 20, skill = 125 },
    [225] = { name = "Artisan", level = 35, skill = 200 },
}
local MAX_PROFESSION_SLOTS = 5
-- GetProfessions has no First Aid position, so read that skill line directly.
local FIRST_AID_SKILL_LINE = 129

-- As in Classic, Expert for these three comes from a vendor book rather than a trainer.
-- Keyed by skill line, with English names as a fallback when the line isn't reported.
local EXPERT_BOOK = {
    [185] = "the Expert Cookbook, sold by Shandrina in Ashenvale or Wulan in Desolace",
    [129] = "Expert First Aid - Under Wraps, sold by Deneb Walker in Stromgarde (Arathi Highlands) or Balai Lok'Wein in Brackenwall Village (Dustwallow Marsh)",
    [356] = "Expert Fishing - The Bass and You, sold by Old Man Heming in Booty Bay",
}
local BOOK_LINE_BY_NAME = { Cooking = 185, ["First Aid"] = 129, Fishing = 356 }

local warned = {}

local function Safe(value)
    if issecretvalue and issecretvalue(value) then
        return nil
    end
    return value
end

local function Print(text)
    if ForeverHub_Receive then
        return ForeverHub_Receive("ProfessionCap", text)
    end
    -- No hub window to show it in: stay quiet rather than fill the chat.
end

-- Every profession as { name, rank, maxRank, secondary }. GetProfessions can leave gaps, so walk each position.
local function ReadProfessions()
    local list, seen = {}, {}
    if not (GetProfessions and GetProfessionInfo) then
        return list
    end
    local slots = { GetProfessions() }
    for position = 1, MAX_PROFESSION_SLOTS do
        local index = Safe(slots[position])
        if index then
            local name, _, rank, maxRank, _, _, skillLine = GetProfessionInfo(index)
            name, rank, maxRank, skillLine = Safe(name), Safe(rank), Safe(maxRank), Safe(skillLine)
            if name and rank and maxRank then
                -- Positions after the two primaries are cooking, fishing and the like.
                list[#list + 1] = { name = name, rank = rank, maxRank = maxRank, secondary = position > 2,
                    skillLine = EXPERT_BOOK[skillLine] and skillLine or BOOK_LINE_BY_NAME[name] }
                seen[name] = true
            end
        end
    end
    local info = C_SkillInfo and C_SkillInfo.GetSkillLineInfoByID and Safe(C_SkillInfo.GetSkillLineInfoByID(FIRST_AID_SKILL_LINE))
    if type(info) == "table" then
        local name, rank, maxRank = Safe(info.name), Safe(info.rank), Safe(info.maxRank)
        if name and rank and maxRank and maxRank > 0 and not seen[name] then
            list[#list + 1] = { name = name, rank = rank, maxRank = maxRank, secondary = true, skillLine = FIRST_AID_SKILL_LINE }
        end
    end
    return list
end

local function PlayerLevel(eventLevel)
    return Safe(eventLevel) or Safe(UnitLevel("player"))
end

-- Whether the level is high enough for the next rank; true when the game hides the level.
local function LevelAllows(nextRank, level)
    return not level or level >= nextRank.level
end

-- The vendor book that teaches this profession's next rank, or nil when a trainer does.
local function ExpertBook(profession)
    local nextRank = NEXT_RANK[profession.maxRank]
    if nextRank and nextRank.name == "Expert" and profession.skillLine then
        return EXPERT_BOOK[profession.skillLine]
    end
end

local function NextRankText(profession, level)
    local nextRank = NEXT_RANK[profession.maxRank]
    local text = "Visit a trainer for " .. nextRank.name .. "."
    local book = ExpertBook(profession)
    if book then
        text = "Expert comes from a book: " .. book .. "."
    elseif profession.secondary and nextRank.name == "Artisan" then
        text = "Artisan comes from a quest rather than a trainer."
    end
    if not LevelAllows(nextRank, level) then
        text = text .. string.format(" You may need level %d first.", nextRank.level)
    end
    return text
end

local function CheckCaps(_, _, eventLevel)
    local level = PlayerLevel(eventLevel)
    local active = {}
    for _, profession in ipairs(ReadProfessions()) do
        local nextRank = NEXT_RANK[profession.maxRank]
        if nextRank and profession.rank >= profession.maxRank then
            -- Reaching the level says so again, since the advice changes then.
            local key = profession.name .. profession.maxRank .. (LevelAllows(nextRank, level) and "" or "low")
            active[key] = true
            if not warned[key] then
                if not ForeverHub_Receive then UIErrorsFrame:AddMessage(profession.name .. " is at its skill cap", 1, 0.8, 0.1) end
                Print(string.format("%s is capped at %d/%d. %s", profession.name, profession.rank, profession.maxRank, NextRankText(profession, level)))
            end
        end
    end
    warned = active
end

local function ShowList()
    local list = ReadProfessions()
    local level = PlayerLevel()
    if #list == 0 then
        Print("You haven't learned a profession yet.")
    end
    for _, profession in ipairs(list) do
        local nextRank = NEXT_RANK[profession.maxRank]
        local note = ""
        if nextRank and profession.rank >= profession.maxRank then
            note = ". " .. NextRankText(profession, level)
        elseif nextRank and profession.rank >= nextRank.skill and LevelAllows(nextRank, level) then
            -- Training before the cap means no skill-ups are wasted waiting at it.
            note = ". " .. nextRank.name .. (ExpertBook(profession) and " can be learned now from its book." or " can be learned now.")
        end
        Print(string.format("%s %d/%d%s", profession.name, profession.rank, profession.maxRank, note))
    end
end

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("SKILL_LINES_CHANGED")
events:RegisterEvent("PLAYER_LEVEL_UP")
events:SetScript("OnEvent", CheckCaps)

SLASH_PROFESSIONCAP1 = "/profs"
SlashCmdList.PROFESSIONCAP = ShowList

ForeverHubStatus = ForeverHubStatus or {}
ForeverHubStatus.ProfessionCap = function()
    local items = {}
    local level = PlayerLevel()
    for _, profession in ipairs(ReadProfessions()) do
        local nextRank = NEXT_RANK[profession.maxRank]
        if nextRank and profession.rank >= profession.maxRank then
            local text
            if not LevelAllows(nextRank, level) then
                text = string.format("|cff88bbee%s capped|r, %s at level %d", profession.name, nextRank.name, nextRank.level)
            elseif ExpertBook(profession) then
                text = string.format("|cff88bbeeBuy|r the %s %s book", nextRank.name, profession.name)
            else
                text = string.format("|cff88bbeeTrain|r %s %s", nextRank.name, profession.name)
            end
            items[#items + 1] = { text = text, page = "Professions" }
        end
    end
    return items
end
