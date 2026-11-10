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

local ADDON_NAME = ...
local RECENT_LEVELS = 10

local levels, currentLevel, lastMark
-- The last XP reading, to count what each XP update added.
local lastXP, lastMax, lastLevel

local function Safe(value)
    if issecretvalue and issecretvalue(value) then
        return nil
    end
    return value
end

local function Print(text)
    if ForeverHub_Receive then
        return ForeverHub_Receive("LevelLog", text)
    end
    -- No hub window to show it in: stay quiet rather than fill the chat.
end

local function FormatDuration(seconds)
    seconds = math.floor(seconds)
    local hours = math.floor(seconds / 3600)
    local minutes = math.floor(seconds / 60) % 60
    if hours > 0 then
        return string.format("%dh %dm", hours, minutes)
    end
    return string.format("%dm", minutes)
end

local function Entry(level)
    local entry = type(levels[level]) == "table" and levels[level] or {}
    entry.seconds = tonumber(entry.seconds) or 0
    entry.deaths = tonumber(entry.deaths) or 0
    levels[level] = entry
    return entry
end

-- Where your XP came from. All XP is counted from the XP bar (PLAYER_XP_UPDATE); quest XP from the
-- turn-in itself (QUEST_TURNED_IN's reward). The rest is from kills and exploring. Counting from the bar
-- avoids the combat XP chat text, which this client can hide.
local function AddXP(level, field, amount)
    if level and amount and amount > 0 then
        local entry = Entry(level)
        entry[field] = (tonumber(entry[field]) or 0) + amount
    end
end

local function ReadXP()
    if not (UnitXP and UnitXPMax and UnitLevel) then
        return nil
    end
    return Safe(UnitXP("player")), Safe(UnitXPMax("player")), Safe(UnitLevel("player"))
end

-- ---- Kill XP (research\re_round3.md rank 3) ----------------------------------------------------------------
-- What one kill gives you, measured from the XP bar: a gain while you fight (or just after) that no quest
-- turn-in explains. The rested bonus is taken off (the rested pool drops by the bonus it pays), so the
-- median is a kill's own XP and rested XP can be counted on top.
local KILL_SAMPLES, MIN_KILL_SAMPLES, AFTER_COMBAT_SECONDS, QUEST_SAME_SECONDS = 10, 3, 3, 0.5
local lastRested -- the rested pool at the last XP reading
local combatUntil = -math.huge

local function ReadRested()
    if not GetXPExhaustion then
        return nil
    end
    local value = GetXPExhaustion()
    if issecretvalue and issecretvalue(value) then
        return nil
    end
    return tonumber(value) or 0
end

local function Fighting()
    local now = GetTime()
    if now <= combatUntil then
        return true
    end
    local busy = UnitAffectingCombat and Safe(UnitAffectingCombat("player"))
    if busy == nil and InCombatLockdown then
        busy = Safe(InCombatLockdown())
    end
    return busy == true
end

local function KillSamples()
    local list = type(levels.killSamples) == "table" and levels.killSamples or {}
    levels.killSamples = list
    return list
end

local function AddKillSample(gained, level, restedBefore, restedAfter)
    if not (levels and level and gained and gained > 0) or not Fighting() then
        return
    end
    if restedBefore == nil or restedAfter == nil then
        -- The pool can't be read: the rested share can't be taken off, so no sample.
        return
    end
    local bonus = math.max(restedBefore - restedAfter, 0)
    -- A rested kill pays at most twice its own XP.
    local own = math.max(gained - bonus, gained / 2)
    local list = KillSamples()
    list[#list + 1] = { xp = math.floor(own + 0.5), level = level, at = GetTime() }
    while #list > KILL_SAMPLES do
        table.remove(list, 1)
    end
end

local function TrackXP()
    local xp, max, level = ReadXP()
    if not (xp and max) then
        -- Hidden now: the next readable update counts what came in between.
        return
    end
    local rested = ReadRested()
    if lastXP and lastMax then
        local gained, gainLevel
        if max ~= lastMax or xp < lastXP then
            -- A new level: the rest of the old bar to the old level, the new XP to the new one.
            -- UnitLevel can still say the old level right at the level-up.
            local before = lastLevel or (level and level - 1)
            local after = before and math.max(level or 0, before + 1) or level
            AddXP(before, "xp", math.max(lastMax - lastXP, 0))
            AddXP(after, "xp", xp)
            gained, gainLevel = math.max(lastMax - lastXP, 0) + xp, before
            level = after
        else
            gained, gainLevel = xp - lastXP, level or lastLevel
            AddXP(gainLevel, "xp", gained)
        end
        AddKillSample(gained, gainLevel, lastRested, rested)
    end
    lastXP, lastMax, lastLevel = xp, max, level or lastLevel
    lastRested = rested
end

-- A quest turned in this very moment explains the gain just counted as a kill.
local function ForgetQuestSample()
    local list = levels and type(levels.killSamples) == "table" and levels.killSamples
    local last = list and list[#list]
    if last and math.abs(GetTime() - (tonumber(last.at) or -math.huge)) <= QUEST_SAME_SECONDS then
        list[#list] = nil
    end
end

-- One kill's XP for a player level and mob level. Uses LevelGuide's XP model when it's loaded; otherwise
-- this copy of the same formula, ported from Polestar (addon\Polestar\Core\Levels.lua,
-- https://github.com/fitzforge/polestar, Copyright (c) 2026 The Polestar authors, GPL-3.0-only; see NOTICE.md).
local function ZeroDiff(l)
    if l <= 7 then return 5 elseif l <= 9 then return 6 elseif l <= 11 then return 7
    elseif l <= 15 then return 8 elseif l <= 19 then return 9 elseif l <= 29 then return 11
    elseif l <= 39 then return 12 elseif l <= 44 then return 13 elseif l <= 49 then return 14
    elseif l <= 54 then return 15 elseif l <= 59 then return 16 end
    return 17
end
local function GreyLevel(l)
    if l <= 5 then return 0 end
    if l <= 39 then return l - math.floor(l / 10) - 5 end
    if l <= 59 then return l - math.floor(l / 5) - 1 end
    return l - 9
end
local function LocalMobXP(plevel, mob, elite)
    local base = plevel * 5 + 45
    local v
    if mob >= plevel then
        v = base * (1 + 0.05 * math.min(mob - plevel, 4))
    elseif mob <= GreyLevel(plevel) then
        v = 0
    else
        v = math.max(0, base * (1 - (plevel - mob) / ZeroDiff(plevel)))
    end
    return math.floor(v + 0.5) * (elite and 2 or 1)
end
local function MobXP(plevel, mob, elite)
    local planner = LevelGuidePlanner
    if type(planner) == "table" and type(planner.MobXP) == "function" then
        local ok, value = pcall(planner.MobXP, plevel, mob, elite)
        if ok and type(value) == "number" then
            return value
        end
    end
    return LocalMobXP(plevel, mob, elite)
end

local function Median(list)
    local sorted = {}
    for i, v in ipairs(list) do
        sorted[i] = v
    end
    table.sort(sorted)
    local n = #sorted
    if n == 0 then
        return nil
    end
    if n % 2 == 1 then
        return sorted[(n + 1) / 2]
    end
    return (sorted[n / 2] + sorted[n / 2 + 1]) / 2
end

-- The median of your recent kills' own XP, scaled to your current level (a kill's XP grows with
-- 5 x level + 45). nil until a few kills were seen.
function LevelLog_KillXP()
    if not levels then
        return nil
    end
    local level = Safe(UnitLevel("player")) or currentLevel
    local values = {}
    for _, sample in ipairs(KillSamples()) do
        local xp, at = tonumber(sample.xp), tonumber(sample.level)
        if xp and xp > 0 and at and level then
            values[#values + 1] = xp * (level * 5 + 45) / (at * 5 + 45)
        end
    end
    if #values < MIN_KILL_SAMPLES then
        return nil
    end
    return Median(values), #values
end

-- Kills to the next level counting rested XP (rested kills pay double until the pool runs out), and how
-- many kills the rested pool covers. nil when unknown or at the top level.
function LevelLog_KillsToLevel()
    local perKill = LevelLog_KillXP()
    local xp, max, level = ReadXP()
    if not (perKill and perKill > 0 and xp and max and max > 0) or (level and level >= 60) then
        return nil
    end
    local rested = ReadRested() or 0
    local missing = max - xp
    local kills = 0
    if missing > 0 then
        kills = math.max(1, math.ceil(math.max(missing - rested, missing / 2) / perKill))
    end
    return kills, math.floor(rested / perKill), perKill
end

-- What your current target gives per kill: its XP, the XP with your rested bonus, and its name. nil for
-- anything that gives no kill XP or whose level can't be read.
function LevelLog_TargetXP()
    if not (UnitExists and Safe(UnitExists("target"))) then
        return nil
    end
    if Safe(UnitIsPlayer("target")) ~= false or Safe(UnitCanAttack("player", "target")) ~= true then
        return nil
    end
    if UnitIsDead and Safe(UnitIsDead("target")) then
        return nil
    end
    local mob, plevel = Safe(UnitLevel("target")), Safe(UnitLevel("player"))
    if type(mob) ~= "number" or type(plevel) ~= "number" or mob <= 0 or plevel >= 60 then
        return nil
    end
    local class = UnitClassification and Safe(UnitClassification("target"))
    local elite = class == "elite" or class == "rareelite" or class == "worldboss"
    local xp = MobXP(plevel, mob, elite)
    local rested = ReadRested() or 0
    local name = UnitName and Safe(UnitName("target"))
    return xp, xp + math.min(xp, rested), type(name) == "string" and name or nil
end

-- One line for the pages: "About 45 kills to level (a kill ~110 XP, rested taken off); rested covers ~38."
function LevelLog_KillsText()
    local kills, restedKills, perKill = LevelLog_KillsToLevel()
    if not kills then
        return nil
    end
    local text = string.format("About %d kill(s) to level (a kill ~%d XP, rested taken off)", kills, math.floor(perKill + 0.5))
    if restedKills > 0 then
        text = text .. string.format("; rested covers about %d kill(s)", restedKills)
    end
    return text .. "."
end

-- "62% quests, 38% kills and exploring", or nil before any XP was counted.
local function SourceText(entry)
    local total = tonumber(entry.xp) or 0
    if total <= 0 then
        return nil
    end
    local quest = math.min(tonumber(entry.questXP) or 0, total)
    local percent = math.floor(quest * 100 / total + 0.5)
    return string.format("%d%% quests, %d%% kills and exploring", percent, 100 - percent)
end

local function BankTime()
    local now = GetTime()
    local entry = Entry(currentLevel)
    entry.seconds = entry.seconds + now - lastMark
    lastMark = now
end

local function ShowLog(showAll)
    BankTime()
    local first = showAll and 1 or math.max(1, currentLevel - RECENT_LEVELS + 1)
    local totalSeconds, totalDeaths = 0, 0
    local all = { xp = 0, questXP = 0 }
    for level = 1, currentLevel do
        local entry = levels[level]
        if type(entry) == "table" then
            -- Older saves may lack a field; count it as nothing rather than stop the whole page.
            local seconds, deaths = tonumber(entry.seconds) or 0, tonumber(entry.deaths) or 0
            totalSeconds = totalSeconds + seconds
            totalDeaths = totalDeaths + deaths
            all.xp = all.xp + (tonumber(entry.xp) or 0)
            all.questXP = all.questXP + math.min(tonumber(entry.questXP) or 0, tonumber(entry.xp) or 0)
            if level >= first then
                local source = SourceText(entry)
                Print(string.format("Level %d: %s, %d death(s)%s", level, FormatDuration(seconds), deaths,
                    source and ("; XP " .. source) or ""))
            end
        end
    end
    Print(string.format("Total logged: %s, %d death(s)", FormatDuration(totalSeconds), totalDeaths))
    local source = SourceText(all)
    if source then
        Print("XP so far: " .. source .. ". Counted since this version; earlier levels have none.")
    end
    local kills = LevelLog_KillsText()
    if kills then
        Print(kills)
    end
end

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("PLAYER_LOGOUT")
events:RegisterEvent("PLAYER_LEVEL_UP")
events:RegisterEvent("PLAYER_DEAD")
events:RegisterEvent("PLAYER_XP_UPDATE")
events:RegisterEvent("QUEST_TURNED_IN")
events:RegisterEvent("PLAYER_REGEN_ENABLED")
events:RegisterEvent("UPDATE_EXHAUSTION")
events:SetScript("OnEvent", function(_, event, arg1, arg2)
    if event == "PLAYER_LOGIN" then
        LevelLogDB = LevelLogDB or {}
        local key = ForeverCharacterAdopt(LevelLogDB)
        LevelLogDB[key] = LevelLogDB[key] or {}
        levels = ForeverCharacterStamp(LevelLogDB[key])
        currentLevel = Safe(UnitLevel("player")) or 1
        lastMark = GetTime()
        lastXP, lastMax, lastLevel = ReadXP()
        lastRested = ReadRested()
    elseif not levels then
        -- Saved data isn't set up until PLAYER_LOGIN.
        return
    elseif event == "PLAYER_REGEN_ENABLED" then
        -- The last kill's XP can arrive just after combat ends.
        combatUntil = GetTime() + AFTER_COMBAT_SECONDS
    elseif event == "UPDATE_EXHAUSTION" then
        -- Rest earned (an inn, a camp) raises the pool; a drop is a rested kill's bonus and is
        -- measured at the XP update, whichever event comes first.
        local rested = ReadRested()
        if rested and (lastRested == nil or rested > lastRested) then
            lastRested = rested
        end
    elseif event == "PLAYER_LEVEL_UP" then
        BankTime()
        Print(string.format("Level %d took %s.", currentLevel, FormatDuration(levels[currentLevel].seconds)))
        currentLevel = Safe(arg1) or currentLevel + 1
    elseif event == "PLAYER_XP_UPDATE" then
        TrackXP()
    elseif event == "QUEST_TURNED_IN" then
        -- Counted to the level you hand it in at.
        local reward = Safe(arg2)
        AddXP(Safe(UnitLevel("player")) or currentLevel, "questXP", type(reward) == "number" and reward or nil)
        ForgetQuestSample()
    elseif event == "PLAYER_DEAD" then
        local entry = Entry(currentLevel)
        entry.deaths = entry.deaths + 1
    elseif event == "PLAYER_LOGOUT" then
        BankTime()
    end
end)

-- Side panel: what the mob you target gives per kill, so you can pick what to fight.
ForeverHubStatus = ForeverHubStatus or {}
ForeverHubStatus.LevelLog = function()
    local xp, restedXP, name = LevelLog_TargetXP()
    if not xp then
        return nil
    end
    local who = name or "Target"
    if xp <= 0 then
        return { { text = string.format("|cff999999%s gives no XP (grey)|r", who), page = "Level log" } }
    end
    local extra = restedXP > xp and string.format(" |cff999999(%d rested)|r", restedXP) or ""
    return { { text = string.format("|cffffd100%s|r gives ~%d XP%s", who, xp, extra), page = "Level log" } }
end

SLASH_LEVELLOG1 = "/levellog"
SlashCmdList.LEVELLOG = function(message)
    -- Saved data isn't ready until login, and the hub can open this page before then.
    if not levels then
        return
    end
    ShowLog(message:lower():match("^%s*all") ~= nil)
end
