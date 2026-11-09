-- Shared Forever character identity (the same copy is in every helper that saves per-character data,
-- so each helper still works alone; whichever loads first defines it). On Forever a character has a
-- first name and a surname (UnitName's second return), so the first name alone is not unique.
-- Key = the player GUID ("Player-<server>-<id>"); when that can't be read, "First Surname-Realm".
do
    local function Plain(value)
        if value == nil or (issecretvalue and issecretvalue(value)) or type(value) ~= "string" or value == "" then
            return nil
        end
        return value
    end
    local function Call(fn, ...)
        if type(fn) ~= "function" then
            return nil
        end
        local ok, a, b = pcall(fn, ...)
        if not ok then
            return nil
        end
        return Plain(a), Plain(b)
    end
    -- "First Surname" on Forever, the plain name elsewhere; nil when unreadable.
    ForeverCharacterName = ForeverCharacterName or function()
        local name, surname = Call(UnitName, "player")
        if not name then
            return nil
        end
        if surname then
            return name .. " " .. surname
        end
        return name
    end
    ForeverCharacterGUID = ForeverCharacterGUID or function()
        local guid = Call(UnitGUID, "player")
        if guid and guid:match("^Player%-") then
            return guid
        end
    end
    -- The key older versions used: first name only, "-", realm.
    ForeverCharacterLegacyKey = ForeverCharacterLegacyKey or function()
        local name = Call(UnitName, "player")
        local realm = Call(GetRealmName)
        return (name or "Unknown") .. "-" .. (realm or "Unknown")
    end
    -- "First Surname-Realm": the key when the GUID can't be read.
    ForeverCharacterNameKey = ForeverCharacterNameKey or function()
        local realm = Call(GetRealmName)
        return (ForeverCharacterName() or "Unknown") .. "-" .. (realm or "Unknown")
    end
    ForeverCharacterKey = ForeverCharacterKey or function()
        return ForeverCharacterGUID() or ForeverCharacterNameKey()
    end
    -- Once per login: moves this character's record from an older key to the current one. Only when
    -- nothing is saved under the current key yet (two records are never merged), and never a record
    -- stamped with another character's GUID. The old key's record is moved, not copied, so a second
    -- character with the same first name starts fresh instead of sharing it. Returns the current key.
    -- oldKeys: optional list of this helper's own older key spellings (default: the legacy key).
    ForeverCharacterAdopt = ForeverCharacterAdopt or function(db, oldKeys)
        local key = ForeverCharacterKey()
        if type(db) ~= "table" or db[key] ~= nil then
            return key
        end
        local guid = ForeverCharacterGUID()
        local candidates = { ForeverCharacterNameKey() }
        for _, old in ipairs(oldKeys or { ForeverCharacterLegacyKey() }) do
            candidates[#candidates + 1] = old
        end
        for _, old in ipairs(candidates) do
            local record = old ~= key and db[old]
            if type(record) == "table" and (record.charGUID == nil or record.charGUID == guid) then
                db[key] = record
                db[old] = nil
                record.migratedFrom = old
                break
            end
        end
        return key
    end
    -- Writes who a record belongs to into it, so pages can show a name instead of parsing the key.
    ForeverCharacterStamp = ForeverCharacterStamp or function(record)
        if type(record) ~= "table" then
            return record
        end
        record.charName = ForeverCharacterName() or record.charName
        record.charGUID = ForeverCharacterGUID() or record.charGUID
        return record
    end
end

local COPPER_PER_GOLD = 10000
local SKILL_RIDING = 762
local RANK_APPRENTICE, RANK_JOURNEYMAN = 75, 150
local MIN_ETA_SECONDS = 600
-- Far above anything a leveling character saves for; catches typos like an extra zero or three.
local MAX_GOAL_GOLD = 100000
-- Training plus mount, per Warcraft Tavern's Forever riding guide (checked at launch, Nov 2026).
local RIDING_GOALS = {
    apprentice = { name = "Apprentice Riding and a mount", short = "riding", gold = 120, level = 40 },
    journeyman = { name = "Journeyman Riding and a mount", short = "epic riding", gold = 1200, level = 60 },
}
-- These classes get riding and their mounts through class quests.
local QUEST_MOUNT_CLASSES = { PALADIN = true, WARLOCK = true }

local charData, startMoney, startTime
local reached = {}

local function Safe(value)
    if issecretvalue and issecretvalue(value) then
        return nil
    end
    return value
end

local function Print(text)
    if ForeverHub_Receive then
        return ForeverHub_Receive("GoldGoal", text)
    end
    -- No hub window to show it in: stay quiet rather than fill the chat.
end

local function FormatGold(copper)
    return string.format("%dg %ds", math.floor(copper / COPPER_PER_GOLD), math.floor(copper / 100) % 100)
end

local function RidingGoal()
    if QUEST_MOUNT_CLASSES[Safe(select(2, UnitClass("player")))] then
        return nil
    end
    local info = C_SkillInfo and Safe(C_SkillInfo.GetSkillLineInfoByID(SKILL_RIDING))
    local rank = type(info) == "table" and Safe(info.rank) or 0
    if rank >= RANK_JOURNEYMAN then
        return nil
    end
    return rank >= RANK_APPRENTICE and RIDING_GOALS.journeyman or RIDING_GOALS.apprentice
end

-- The goal being tracked: your own if you set one, otherwise the next riding step.
local function CurrentGoal()
    if charData and charData.goal then
        return charData.goal
    end
    return RidingGoal()
end

local function EtaText(short)
    local money = Safe(GetMoney())
    if not (money and startMoney) then
        return ""
    end
    local elapsed, earned = GetTime() - startTime, money - startMoney
    if elapsed < MIN_ETA_SECONDS or earned <= 0 then
        return ""
    end
    local hours = short / (earned / elapsed) / 3600
    return string.format(" About %.1f hour(s) at this session's rate.", hours)
end

-- newLevel comes from PLAYER_LEVEL_UP, since UnitLevel can still report the old level then.
local function CheckGoal(newLevel)
    local goal = CurrentGoal()
    local money = Safe(GetMoney())
    local level = type(newLevel) == "number" and newLevel or Safe(UnitLevel("player"))
    if not (goal and money and level) then
        return
    end
    local ready = money >= goal.gold * COPPER_PER_GOLD and level >= (goal.level or 1)
    if ready and not reached[goal.name] then
        Print("You can afford " .. goal.name .. "!")
    end
    reached[goal.name] = ready
end

local function ShowGoal()
    local goal = CurrentGoal()
    if not goal then
        if QUEST_MOUNT_CLASSES[Safe(select(2, UnitClass("player")))] then
            Print("Your class gets riding and its mounts from class quests, so riding isn't tracked here.")
        end
        Print("No goal set. Enter gold and a name on the Gold goal page, such as 500 Bags.")
        return
    end
    local money = Safe(GetMoney())
    if not money then
        Print("The game didn't report your gold.")
        return
    end
    local cost = goal.gold * COPPER_PER_GOLD
    if money >= cost then
        Print(string.format("%s: you have %s of %dg. Enough!", goal.name, FormatGold(money), goal.gold))
    else
        Print(string.format("%s: you have %s of %dg, %s short.%s", goal.name, FormatGold(money), goal.gold, FormatGold(cost - money), EtaText(cost - money)))
    end
    local level = Safe(UnitLevel("player"))
    if goal.level and level and level < goal.level then
        Print(string.format("Requires level %d. You're level %d.", goal.level, level))
    end
    if not charData.goal then
        Print("Guides list 10% off when you're Honored with your home faction.")
    end
end

local function HandleSlash(message)
    local command = message:match("^%s*(%S*)"):lower()
    -- Whole gold only, with or without a trailing g, so "500g" works and "1e9" or "2.5" don't.
    local gold = tonumber(command:match("^(%d+)g?$") or "")
    if command == "" then
        ShowGoal()
    elseif command == "clear" then
        charData.goal = nil
        Print("Your goal is cleared.")
    elseif gold and gold > 0 and gold <= MAX_GOAL_GOLD then
        local name = message:match("^%s*%S+%s+(.-)%s*$")
        charData.goal = { name = (name and name ~= "") and name or "Gold goal", gold = gold }
        reached = {}
        ShowGoal()
        CheckGoal()
    else
        Print(string.format("Enter whole gold from 1 to %d and a name, such as 500 Bags. Or: clear, to go back to tracking riding.", MAX_GOAL_GOLD))
    end
end

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("PLAYER_MONEY")
events:RegisterEvent("PLAYER_LEVEL_UP")
events:SetScript("OnEvent", function(_, event, arg)
    if event == "PLAYER_LOGIN" then
        GoldGoalDB = GoldGoalDB or {}
        local key = ForeverCharacterAdopt(GoldGoalDB)
        GoldGoalDB[key] = GoldGoalDB[key] or {}
        charData = ForeverCharacterStamp(GoldGoalDB[key])
        startMoney, startTime = Safe(GetMoney()), GetTime()
    end
    if charData then
        CheckGoal(event == "PLAYER_LEVEL_UP" and Safe(arg) or nil)
    end
end)

SLASH_GOLDGOAL1 = "/goal"
SLASH_GOLDGOAL2 = "/goldgoal"
SlashCmdList.GOLDGOAL = function(message)
    if charData then
        HandleSlash(message)
    end
end

ForeverHubStatus = ForeverHubStatus or {}
ForeverHubStatus.GoldGoal = function()
    local goal = charData and CurrentGoal()
    local money = Safe(GetMoney())
    if not (goal and money) then
        return nil
    end
    local level = Safe(UnitLevel("player"))
    if money >= goal.gold * COPPER_PER_GOLD and level and level >= (goal.level or 1) then
        return { { text = string.format("|cff33ff33Buy|r %s (%dg)", goal.short or goal.name, goal.gold), page = "Gold goal" } }
    end
    local percent = math.min(math.floor(money * 100 / (goal.gold * COPPER_PER_GOLD)), 100)
    return { { text = string.format("|cffeecc55Saving|r %d%% of %dg for %s", percent, goal.gold, goal.short or goal.name), page = "Gold goal" } }
end
