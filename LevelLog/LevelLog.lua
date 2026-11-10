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
-- LevelGuide measures your kills (rested bonus and quest turn-ins taken out) and keeps the last 30 per
-- character as a share of a same-level mob's XP (LevelGuideDB.characters[key].killXP). LevelLog only reads
-- that list, never writes it; without LevelGuide there is no kill estimate.
local MIN_KILL_SAMPLES = 3

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

-- Quest XP is split across a level-up the same way as the bar (review 3b, S1): the part that filled the old
-- bar counts for the old level, the rest for the new one. The turn-in and the XP update can come in either
-- order, so whichever comes second does the split: a reward waits for the next gain (pendingQuest), and a
-- gain is remembered for a moment (lastGain) in case its reward comes just after.
-- A reward waits up to 2 s for its gain; a gain only counts as the reward's when it came within 0.5 s before.
local QUEST_MATCH_SECONDS, GAIN_MATCH_SECONDS = 2, 0.5
local pendingQuest -- { xp, at }
local lastGain -- { at, oldLevel, oldXP, newLevel, newXP, quest = XP already given to a reward }

local function SplitQuest(reward, gain)
    local fromOld = math.min(reward, math.max(gain.oldXP - gain.quest, 0))
    local fromNew = math.min(reward - fromOld, math.max(gain.newXP - math.max(gain.quest - gain.oldXP, 0), 0))
    AddXP(gain.oldLevel, "questXP", fromOld)
    AddXP(gain.newLevel, "questXP", fromNew)
    gain.quest = gain.quest + fromOld + fromNew
    -- XP the bar didn't show yet (hidden, or still to come) stays with the level you're at now.
    local rest = reward - fromOld - fromNew
    if rest > 0 then
        AddXP(gain.newLevel or gain.oldLevel, "questXP", rest)
    end
end

local function TrackXP()
    local xp, max, level = ReadXP()
    if not (xp and max) then
        -- Hidden now: the next readable update counts what came in between.
        return
    end
    if lastXP and lastMax then
        local gain
        if max ~= lastMax or xp < lastXP then
            -- A new level: the rest of the old bar to the old level, the new XP to the new one.
            -- UnitLevel can still say the old level right at the level-up.
            local before = lastLevel or (level and level - 1)
            local after = before and math.max(level or 0, before + 1) or level
            AddXP(before, "xp", math.max(lastMax - lastXP, 0))
            AddXP(after, "xp", xp)
            gain = { oldLevel = before, oldXP = math.max(lastMax - lastXP, 0), newLevel = after, newXP = xp }
            level = after
        else
            AddXP(level or lastLevel, "xp", xp - lastXP)
            gain = { oldLevel = level or lastLevel, oldXP = xp - lastXP, newLevel = level or lastLevel, newXP = 0 }
        end
        gain.at, gain.quest = GetTime(), 0
        lastGain = gain
        if pendingQuest then
            if GetTime() - pendingQuest.at <= QUEST_MATCH_SECONDS then
                SplitQuest(pendingQuest.xp, gain)
            else
                AddXP(gain.newLevel or gain.oldLevel, "questXP", pendingQuest.xp)
            end
            pendingQuest = nil
        end
    end
    lastXP, lastMax, lastLevel = xp, max, level or lastLevel
end

-- QUEST_TURNED_IN's reward: split with the gain just seen, or wait for the next one.
local function QuestTurnedIn(reward)
    if type(reward) ~= "number" or reward <= 0 then
        return
    end
    if pendingQuest then
        -- An older reward no gain came for (XP hidden): it stays with the level you're at.
        AddXP(Safe(UnitLevel("player")) or currentLevel, "questXP", pendingQuest.xp)
        pendingQuest = nil
    end
    if lastGain and GetTime() - lastGain.at <= GAIN_MATCH_SECONDS
        and lastGain.oldXP + lastGain.newXP - lastGain.quest >= reward then
        SplitQuest(reward, lastGain)
    else
        pendingQuest = { xp = reward, at = GetTime() }
    end
end

-- LevelGuide's recent kill shares for this character (read-only), or nil.
local function GuideKillShares()
    local db = type(LevelGuideDB) == "table" and LevelGuideDB
    local chars = db and type(db.characters) == "table" and db.characters
    local key = chars and ForeverCharacterKey and ForeverCharacterKey()
    local record = key and chars[key]
    local list = type(record) == "table" and record.killXP
    if type(list) ~= "table" then
        return nil
    end
    local shares = {}
    for _, v in ipairs(list) do
        if type(v) == "number" and v > 0 then
            shares[#shares + 1] = v
        end
    end
    return shares
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

-- A kill's own XP at your current level: the median of LevelGuide's recent kill shares (LevelGuidePlanner's
-- Median when loaded) times a same-level mob's XP (5 x level + 45). nil until a few kills were seen.
function LevelLog_KillXP()
    local shares = GuideKillShares()
    local level = Safe(UnitLevel("player")) or currentLevel
    if not (shares and level) or #shares < MIN_KILL_SAMPLES then
        return nil
    end
    local planner = LevelGuidePlanner
    local median = type(planner) == "table" and type(planner.Median) == "function" and planner.Median(shares) or Median(shares)
    return math.max(1, math.floor((level * 5 + 45) * median + 0.5)), #shares
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
    local planner = LevelGuidePlanner
    local kills
    if type(planner) == "table" and type(planner.KillsLeft) == "function" then
        kills = planner.KillsLeft(missing, rested, perKill)
    else
        -- The same rule: rested kills pay double until the pool runs out.
        kills = missing > 0 and math.max(1, math.ceil(math.max(missing - rested, missing / 2) / perKill)) or 0
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

-- One line for the pages: "A kill gives you about 110 XP; rested covers about 38 kills." (LevelGuide's own
-- window already says how many kills to level.)
function LevelLog_KillsText()
    local kills, restedKills, perKill = LevelLog_KillsToLevel()
    if not kills then
        return nil
    end
    local text = string.format("A kill gives you about %d XP (your recent kills, rested taken off)", perKill)
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

-- ---- Pace per level (research\re_round3.md rank 18) --------------------------------------------------------
-- XP per hour for each level (a finished level's whole bar from LevelGuide's level table when loaded, else
-- the XP counted for it), and how its time compares with your fastest other character at that level.
local MIN_PACE_SECONDS = 60

local function LevelXP(level, entry)
    local planner = LevelGuidePlanner
    if level < currentLevel and type(planner) == "table" and type(planner.LEVEL_XP) == "table" and planner.LEVEL_XP[level] then
        return planner.LEVEL_XP[level]
    end
    return tonumber(entry.xp) or 0
end

local function PaceText(xp, seconds)
    if seconds < MIN_PACE_SECONDS or xp <= 0 then
        return nil
    end
    local perHour = xp * 3600 / seconds
    if perHour >= 1000 then
        return string.format("%.1fk XP/h", perHour / 1000)
    end
    return string.format("%d XP/h", math.floor(perHour))
end

-- Your fastest other character's time for a level they finished: seconds and name, or nil.
local function BestOther(level)
    local own = levels
    local best, bestName
    for _, record in pairs(LevelLogDB or {}) do
        if type(record) == "table" and record ~= own then
            local entry, after = record[level], record[level + 1]
            local seconds = type(entry) == "table" and tonumber(entry.seconds)
            -- Only a level they got past counts as a run.
            if seconds and seconds >= MIN_PACE_SECONDS and type(after) == "table" and (not best or seconds < best) then
                best, bestName = seconds, record.charName
            end
        end
    end
    return best, bestName
end

local function CompareText(level, seconds)
    if level >= currentLevel or seconds < MIN_PACE_SECONDS then
        return nil
    end
    local best, name = BestOther(level)
    if not best then
        return nil
    end
    local delta = seconds - best
    local who = type(name) == "string" and name or "another character"
    if delta <= 0 then
        return string.format("|cff33ff33%s faster than %s|r", FormatDuration(-delta), who)
    end
    return string.format("|cffff6666%s slower than %s (%s)|r", FormatDuration(delta), who, FormatDuration(best))
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
                local pace = PaceText(LevelXP(level, entry), seconds)
                local compare = CompareText(level, seconds)
                Print(string.format("Level %d: %s, %d death(s)%s%s%s", level, FormatDuration(seconds), deaths,
                    pace and ("; " .. pace) or "", source and ("; XP " .. source) or "",
                    compare and ("; " .. compare) or ""))
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

-- ---- The way to 60 (research\re_round4.md R9) ------------------------------------------------------------
-- The XP each level needs, learned from UnitXPMax whenever it can be read, on any character of the account
-- (LevelLogXPCurve[level] = bar size), over the Classic table, so the curve corrects itself if Forever's
-- differs. The idea (a Classic curve replaced level by level by what the account has seen) is from XP Horizon
-- by thejvfdev (GPL-3.0-or-later, see NOTICE.md); our own code. No /played and no XP-bar hook.
local MAX_LEVEL = 60
local CLASSIC_LEVEL_XP = {
    400, 900, 1400, 2100, 2800, 3600, 4500, 5400, 6500, 7600,
    8800, 10100, 11400, 12900, 14400, 16000, 17700, 19400, 21300, 23200,
    25200, 27300, 29400, 31700, 34000, 36400, 38900, 41400, 44300, 47400,
    50800, 54500, 58600, 62800, 67100, 71600, 76100, 80800, 85700, 90700,
    95800, 101000, 106300, 111800, 117500, 123200, 129100, 135100, 141200, 147500,
    153900, 160400, 167100, 173900, 180800, 187900, 195000, 202300, 209800,
}

-- From the last reading TrackXP kept: its level is corrected across a level-up (UnitLevel can lag behind).
local function LearnCurve()
    local max, level = lastMax, lastLevel
    if type(level) == "number" and level >= 1 and level < MAX_LEVEL and type(max) == "number" and max > 0 then
        LevelLogXPCurve = type(LevelLogXPCurve) == "table" and LevelLogXPCurve or {}
        LevelLogXPCurve[level] = max
    end
end

local function CurveXP(level)
    local learned = type(LevelLogXPCurve) == "table" and tonumber(LevelLogXPCurve[level])
    return learned or CLASSIC_LEVEL_XP[level] or 0
end

-- Share of the way from level 1 to 60 (0-1), XP still to earn, and the whole way's XP; nil when unreadable.
function LevelLog_ToSixty()
    local xp, _, level = ReadXP()
    if type(level) ~= "number" then
        return nil
    end
    local total = 0
    for l = 1, MAX_LEVEL - 1 do
        total = total + CurveXP(l)
    end
    if level >= MAX_LEVEL then
        return 1, 0, total
    end
    if type(xp) ~= "number" then
        return nil
    end
    local done = xp
    for l = 1, level - 1 do
        done = done + CurveXP(l)
    end
    done = math.min(done, total)
    return done / total, total - done, total
end

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("PLAYER_LOGOUT")
events:RegisterEvent("PLAYER_LEVEL_UP")
events:RegisterEvent("PLAYER_DEAD")
events:RegisterEvent("PLAYER_XP_UPDATE")
events:RegisterEvent("QUEST_TURNED_IN")
events:SetScript("OnEvent", function(_, event, arg1, arg2)
    if event == "PLAYER_LOGIN" then
        LevelLogDB = LevelLogDB or {}
        local key = ForeverCharacterAdopt(LevelLogDB)
        LevelLogDB[key] = LevelLogDB[key] or {}
        levels = ForeverCharacterStamp(LevelLogDB[key])
        currentLevel = Safe(UnitLevel("player")) or 1
        lastMark = GetTime()
        lastXP, lastMax, lastLevel = ReadXP()
        LearnCurve()
    elseif not levels then
        -- Saved data isn't set up until PLAYER_LOGIN.
        return
    elseif event == "PLAYER_LEVEL_UP" then
        BankTime()
        Print(string.format("Level %d took %s.", currentLevel, FormatDuration(levels[currentLevel].seconds)))
        currentLevel = Safe(arg1) or currentLevel + 1
    elseif event == "PLAYER_XP_UPDATE" then
        TrackXP()
        LearnCurve()
    elseif event == "QUEST_TURNED_IN" then
        -- Split across a level-up like the bar (see QuestTurnedIn).
        QuestTurnedIn(Safe(arg2))
    elseif event == "PLAYER_DEAD" then
        local entry = Entry(currentLevel)
        entry.deaths = entry.deaths + 1
    elseif event == "PLAYER_LOGOUT" then
        BankTime()
        -- A reward no XP update came for stays with the level you're at.
        if pendingQuest then
            AddXP(currentLevel, "questXP", pendingQuest.xp)
            pendingQuest = nil
        end
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
