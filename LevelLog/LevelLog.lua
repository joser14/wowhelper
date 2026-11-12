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
-- Kill counting and the day log (further down) look at every XP gain and every turn-in.
local NoteGain, DropRecentKills
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
        local total = gain.oldXP + gain.newXP
        if total > 0 and NoteGain then
            NoteGain(gain.newLevel or gain.oldLevel, total,
                pendingQuest ~= nil and GetTime() - pendingQuest.at <= QUEST_MATCH_SECONDS)
        end
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
    -- An XP gain just before this was the reward, not a kill.
    if DropRecentKills then
        DropRecentKills(GAIN_MATCH_SECONDS)
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
    if LevelLog_ETAText then
        local eta = LevelLog_ETAText(currentLevel + 1)
        if eta then
            Print(eta)
        end
        Print("|cff999999Your journey by day, lifetime stats and where your time goes are in the LevelLog window (the button above).|r")
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

-- ---- Journey, stats, time split and level ETA (research\re_round5.md #8, #9, #10) --------------------------
-- Ideas from Questie's Journey, AutoBiographer and LevelETA (MIT); the code is our own. Everything is per
-- character in LevelLogDB and capped: the journey keeps the newest JOURNEY_CAP entries (older ones fold into
-- counts per month), the day log the newest DAYS_CAP play days, the zone times the ZONES_CAP biggest zones.
local JOURNEY_CAP, DAYS_CAP, ZONES_CAP, SEEN_CAP = 1000, 60, 120, 300
-- No movement, XP, money, combat or quest event for this long: away from the keyboard (UnitIsAFK is secret
-- while chat is locked down, so this rule is used instead).
local AFK_SECONDS = 180
-- Talking to quest givers (or an objective moved) this recently counts as questing.
local QUEST_ACTIVE_SECONDS = 20
-- An XP gain in combat, or this soon after it, is a kill once no turn-in claimed it within KILL_WAIT.
local KILL_COMBAT_GRACE, KILL_WAIT = 3, 1.5
-- A longer gap between ticks (loading screen, a stall) only counts this much.
local TICK_MAX = 2
-- Pace: finished levels with at least this much active time, the newest PACE_LEVELS of them.
local PACE_MIN_SECONDS, PACE_LEVELS, PACE_DECAY = 300, 12, 0.85
-- Play per day: the median of the last PLAY_DAYS play days of at least PLAY_DAY_MIN seconds.
local PLAY_DAYS, PLAY_DAY_MIN = 7, 300
local JOURNEY_SHOWN = 300

local ACTIVITIES = { "fight", "quest", "travel", "flight", "town", "dead", "afk", "other" }
local ACTIVITY_LABEL = {
    fight = "Fighting", quest = "Questing (quest NPCs, objectives)", travel = "Travelling on foot or mount",
    flight = "Flying (taxi)", town = "In town or an inn", dead = "Dead or running back",
    afk = "Away (nothing for 3 min)", other = "Standing (eating, looting, waiting)",
}

local DateFn = date or (os and os.date)
local inCombat, combatEndedAt = false, nil
local lastActive, lastQuestAt, lastTick, wasOnTaxi = 0, nil, nil, false
local currentZone, lastMoney
local pendingKills = {}
local window

local function Now()
    local t = GetServerTime and Safe(GetServerTime())
    if type(t) ~= "number" and time then
        t = time()
    end
    return type(t) == "number" and t or 0
end

local function DayKey(t)
    return DateFn and DateFn("%Y-%m-%d", t) or "today"
end

local function Bump(t, key, amount)
    t[key] = (tonumber(t[key]) or 0) + (amount or 1)
end

local function Table(parent, key)
    local t = type(parent[key]) == "table" and parent[key] or {}
    parent[key] = t
    return t
end

local function Stats()
    local stats = Table(levels, "stats")
    Table(stats, "activity")
    Table(stats, "zones")
    if not stats.since then
        stats.since = Now()
    end
    return stats
end

-- How many keys a table has (the capped maps are small).
local function CountKeys(t)
    local n = 0
    for _ in pairs(t) do
        n = n + 1
    end
    return n
end

-- Today's line in the day log; the oldest play days go once there are more than DAYS_CAP.
local function Day()
    local days = Table(levels, "days")
    local key = DayKey(Now())
    if type(days[key]) ~= "table" then
        days[key] = {}
        local keys = {}
        for k in pairs(days) do
            keys[#keys + 1] = k
        end
        if #keys > DAYS_CAP then
            table.sort(keys)
            for i = 1, #keys - DAYS_CAP do
                days[keys[i]] = nil
            end
        end
    end
    return days[key]
end

local function RefreshWindowSoon()
    if window and window:IsShown() then
        window.dirty = true
    end
end

-- A journey entry: t (server time), k (kind), l (your level), plus the kind's own fields.
local function AddEvent(kind, fields)
    local list = Table(levels, "journey")
    local entry = { t = Now(), k = kind, l = currentLevel }
    for key, value in pairs(fields or {}) do
        entry[key] = value
    end
    list[#list + 1] = entry
    if #list > JOURNEY_CAP then
        local folded = Table(levels, "journeyOld")
        while #list > JOURNEY_CAP do
            local old = table.remove(list, 1)
            local month = (DateFn and type(old.t) == "number" and old.t > 0) and DateFn("%Y-%m", old.t) or "older"
            Bump(Table(folded, month), tostring(old.k or "other"))
        end
    end
    RefreshWindowSoon()
    return entry
end

local function ReadZone()
    local zone = (GetRealZoneText and Safe(GetRealZoneText())) or (GetZoneText and Safe(GetZoneText()))
    if type(zone) ~= "string" or zone == "" then
        return nil
    end
    local dungeon = false
    if IsInInstance then
        local ok, inside, kind = pcall(IsInInstance)
        if ok then
            inside, kind = Safe(inside), Safe(kind)
            dungeon = inside == true and (kind == "party" or kind == "raid")
        end
    end
    return zone, dungeon
end

-- First visits. The zone you're in when the journal starts is only remembered, since you may have been
-- there long before.
local function UpdateZone()
    local zone, dungeon = ReadZone()
    if not zone then
        return
    end
    currentZone = zone
    local seen = Table(levels, "seen")
    local zones, dungeons = Table(seen, "zones"), Table(seen, "dungeons")
    local bucket = dungeon and dungeons or zones
    if bucket[zone] then
        return
    end
    if CountKeys(zones) + CountKeys(dungeons) >= SEEN_CAP then
        return
    end
    local starting = not levels.journeyStart
    bucket[zone] = Now()
    if starting then
        return
    end
    if dungeon then
        AddEvent("dungeon", { z = zone, first = CountKeys(dungeons) == 1 or nil })
    else
        AddEvent("zone", { z = zone })
    end
end

local function StartJourney()
    if levels.journeyStart then
        return
    end
    levels.journeyStart = Now()
    levels.journeyStartLevel = currentLevel
    local zone = ReadZone()
    AddEvent("start", { z = zone })
end

-- A second's time in a zone; with more than ZONES_CAP zones the smallest goes.
local function AddZoneTime(stats, zone, seconds)
    local zones = stats.zones
    if zones[zone] == nil and CountKeys(zones) >= ZONES_CAP then
        local smallest, least
        for name, value in pairs(zones) do
            if not least or (tonumber(value) or 0) < least then
                smallest, least = name, tonumber(value) or 0
            end
        end
        if smallest then
            zones[smallest] = nil
        end
    end
    Bump(zones, zone, seconds)
end

local function InFight()
    if inCombat then
        return true
    end
    return UnitAffectingCombat and Safe(UnitAffectingCombat("player")) == true or false
end

local function MarkActive()
    lastActive = GetTime()
end

-- Every XP gain: the day's XP, and a kill when it came in or just after combat and wasn't a quest's.
NoteGain = function(level, amount, fromQuest)
    if not levels then
        return
    end
    MarkActive()
    Bump(Day(), "x", amount)
    if fromQuest then
        return
    end
    local now = GetTime()
    if InFight() or (combatEndedAt and now - combatEndedAt <= KILL_COMBAT_GRACE) then
        pendingKills[#pendingKills + 1] = { at = now, level = level or currentLevel }
        if #pendingKills > 50 then
            table.remove(pendingKills, 1)
        end
    end
end

DropRecentKills = function(seconds)
    local now = GetTime()
    for i = #pendingKills, 1, -1 do
        if now - pendingKills[i].at <= seconds then
            table.remove(pendingKills, i)
        end
    end
end

-- Kills nobody claimed for KILL_WAIT seconds are counted.
local function ResolveKills()
    if not levels then
        return
    end
    local now = GetTime()
    while pendingKills[1] and now - pendingKills[1].at >= KILL_WAIT do
        local kill = table.remove(pendingKills, 1)
        Bump(Entry(kill.level), "kills")
        Bump(Stats(), "kills")
        Bump(Day(), "k")
    end
end

local function TrackMoney()
    local money = GetMoney and Safe(GetMoney())
    if type(money) ~= "number" then
        -- Unreadable now: the next reading counts what changed in between.
        return
    end
    if lastMoney then
        local delta = money - lastMoney
        if delta ~= 0 then
            MarkActive()
            local field = delta > 0 and "moneyIn" or "moneyOut"
            Bump(Stats(), field, math.abs(delta))
            Bump(Entry(currentLevel), field, math.abs(delta))
        end
    end
    lastMoney = money
end

-- What you're doing this second (the first that applies).
local function ActivityNow(now)
    if UnitIsDeadOrGhost and Safe(UnitIsDeadOrGhost("player")) == true then
        return "dead"
    end
    if UnitOnTaxi and Safe(UnitOnTaxi("player")) == true then
        return "flight"
    end
    if InFight() then
        lastActive = now
        return "fight"
    end
    local moving = IsPlayerMoving and Safe(IsPlayerMoving()) == true
    if moving then
        lastActive = now
    end
    if now - lastActive >= AFK_SECONDS then
        return "afk"
    end
    if lastQuestAt and now - lastQuestAt <= QUEST_ACTIVE_SECONDS then
        return "quest"
    end
    if IsResting and Safe(IsResting()) == true then
        return "town"
    end
    if moving then
        return "travel"
    end
    return "other"
end

local RefreshWindow

-- Once a second: time by activity (this level and lifetime), time per zone, the day's play time, flights.
local function Tick()
    if not levels then
        return
    end
    ResolveKills()
    local now = GetTime()
    local delta = lastTick and now - lastTick or 0
    lastTick = now
    local taxi = UnitOnTaxi and Safe(UnitOnTaxi("player")) == true or false
    if taxi and not wasOnTaxi then
        Bump(Stats(), "flights")
        Bump(Entry(currentLevel), "flights")
    end
    wasOnTaxi = taxi
    if delta > 0 then
        delta = math.min(delta, TICK_MAX)
        local state = ActivityNow(now)
        Bump(Table(Entry(currentLevel), "activity"), state, delta)
        local stats = Stats()
        Bump(stats.activity, state, delta)
        if currentZone then
            AddZoneTime(stats, currentZone, delta)
        end
        if state ~= "afk" then
            Bump(Day(), "s", delta)
        end
    end
    if window and window:IsShown() and (window.dirty or (window.view == "time" and now - (window.drawnAt or 0) >= 5)) then
        RefreshWindow()
    end
end

-- Seconds you played a level, without the time away.
local function ActiveSeconds(entry)
    local seconds = tonumber(entry.seconds) or 0
    local afk = type(entry.activity) == "table" and tonumber(entry.activity.afk) or 0
    return math.max(seconds - afk, 0)
end

-- XP per hour of play, weighted towards your recent levels (LevelETA's way): the newest PACE_LEVELS finished
-- levels, each 0.85 times the weight of the one after it, levels over twice the median left out; the level
-- you're on blends in up to 40 % once you've played it two hours. Returns XP/h and the levels used, or nil.
function LevelLog_Pace()
    if not levels then
        return nil
    end
    BankTime()
    local samples = {}
    for level = currentLevel - 1, 1, -1 do
        local entry = levels[level]
        if type(entry) == "table" then
            local seconds = ActiveSeconds(entry)
            -- The XP counted for the level when there is some (a level only partly logged), else its bar.
            local xp = (tonumber(entry.xp) or 0) > 0 and tonumber(entry.xp) or CurveXP(level)
            if seconds >= PACE_MIN_SECONDS and xp > 0 then
                samples[#samples + 1] = xp * 3600 / seconds
            end
        end
        if #samples >= PACE_LEVELS then
            break
        end
    end
    local rate, used
    if #samples > 0 then
        local median = Median(samples)
        local sum, weights, weight = 0, 0, 1
        used = 0
        for _, perHour in ipairs(samples) do
            if perHour <= 2 * median then
                sum, weights, used = sum + perHour * weight, weights + weight, used + 1
                weight = weight * PACE_DECAY
            end
        end
        rate = weights > 0 and sum / weights or nil
    end
    local current = type(levels[currentLevel]) == "table" and levels[currentLevel]
    if current then
        local seconds, xp = ActiveSeconds(current), tonumber(current.xp) or 0
        if seconds >= 120 and xp > 0 then
            local perHour = xp * 3600 / seconds
            if rate then
                local blend = math.min(0.4, seconds / 60 / 120)
                rate = rate * (1 - blend) + perHour * blend
            elseif seconds >= 600 then
                rate, used = perHour, 0
            end
        end
    end
    if not rate or rate <= 0 then
        return nil
    end
    return rate, used or 0
end

-- Hours you play on a day: the median of your last PLAY_DAYS play days (today only while there are fewer
-- than two others). Returns hours and how many days, or nil.
function LevelLog_HoursPerDay()
    if not levels or type(levels.days) ~= "table" then
        return nil
    end
    local today = DayKey(Now())
    local keys = {}
    for key, day in pairs(levels.days) do
        if key ~= today and type(day) == "table" and (tonumber(day.s) or 0) >= PLAY_DAY_MIN then
            keys[#keys + 1] = key
        end
    end
    table.sort(keys, function(a, b) return a > b end)
    local hours = {}
    for i = 1, math.min(#keys, PLAY_DAYS) do
        hours[#hours + 1] = levels.days[keys[i]].s / 3600
    end
    local todayEntry = levels.days[today]
    if #hours < 2 and type(todayEntry) == "table" and (tonumber(todayEntry.s) or 0) >= PLAY_DAY_MIN then
        hours[#hours + 1] = todayEntry.s / 3600
    end
    if #hours == 0 then
        return nil
    end
    return Median(hours), #hours
end

-- XP still to earn to reach a level, or nil.
local function XPTo(target)
    local xp, max, level = ReadXP()
    level = level or currentLevel
    if type(xp) ~= "number" or type(max) ~= "number" or type(level) ~= "number" or target <= level or target > MAX_LEVEL then
        return nil
    end
    local need = max - xp
    for l = level + 1, target - 1 do
        need = need + CurveXP(l)
    end
    return need
end

-- When you'd reach a level: hours of play, and the date at your usual play per day. nil when unknown.
function LevelLog_ETA(target)
    local need = XPTo(target)
    local rate = LevelLog_Pace()
    if not (need and rate) then
        return nil
    end
    local result = { target = target, hours = need / rate, rate = rate }
    local perDay = LevelLog_HoursPerDay()
    if perDay and perDay > 0 then
        result.perDay = perDay
        result.at = Now() + result.hours / perDay * 86400
    end
    return result
end

-- "Level 20 about Sat 15 Nov (about 9h 0m of play at 1.6 h a day)".
function LevelLog_ETAText(target)
    local eta = LevelLog_ETA(target)
    if not eta then
        return nil
    end
    local played = FormatDuration(eta.hours * 3600)
    if eta.at and DateFn then
        return string.format("Level %d about %s (about %s of play at %.1f h a day)", target,
            DateFn("%a %d %b", eta.at), played, eta.perDay)
    end
    return string.format("Level %d in about %s of play", target, played)
end

-- ---- The window's pages -------------------------------------------------------------------------------------
local GOLD, GREY, GREEN, RED = "|cffffd100", "|cff999999", "|cff33ff33", "|cffff6666"

local function Money(copper)
    copper = math.floor(tonumber(copper) or 0)
    local gold, silver, rest = math.floor(copper / 10000), math.floor(copper / 100) % 100, copper % 100
    if gold > 0 then
        return string.format("%dg %ds", gold, silver)
    elseif silver > 0 then
        return string.format("%ds %dc", silver, rest)
    end
    return string.format("%dc", rest)
end

local function Clock(t)
    return DateFn and DateFn("%H:%M", t) or ""
end

local function EventText(entry)
    local kind = entry.k
    if kind == "level" then
        local took = tonumber(entry.s)
        return string.format("%sReached level %s|r%s", GOLD, tostring(entry.n or "?"),
            took and took > 0 and string.format(" (level %d took %s)", (tonumber(entry.n) or 1) - 1, FormatDuration(took)) or "")
    elseif kind == "zone" then
        return "First visit: " .. tostring(entry.z or "?")
    elseif kind == "dungeon" then
        local first = ""
        if entry.first then
            first = (tonumber(levels.journeyStartLevel) or 1) <= 10 and (GREEN .. " - your first dungeon|r") or (GREEN .. " - first dungeon in this log|r")
        end
        return "Entered dungeon: " .. tostring(entry.z or "?") .. first
    elseif kind == "death" then
        return RED .. "Died|r" .. (entry.z and (" in " .. entry.z) or "")
    elseif kind == "start" then
        return GREY .. "Journal started" .. (entry.z and (" in " .. entry.z) or "") .. string.format(" at level %d|r", tonumber(entry.l) or 1)
    end
    return tostring(kind)
end

local function DaySummary(key)
    local day = type(levels.days) == "table" and levels.days[key]
    if type(day) ~= "table" then
        return ""
    end
    local parts = {}
    if (tonumber(day.s) or 0) > 0 then
        parts[#parts + 1] = FormatDuration(day.s) .. " played"
    end
    if (tonumber(day.k) or 0) > 0 then
        parts[#parts + 1] = day.k .. " kills"
    end
    if (tonumber(day.q) or 0) > 0 then
        parts[#parts + 1] = day.q .. " quests"
    end
    if (tonumber(day.x) or 0) > 0 then
        parts[#parts + 1] = day.x .. " XP"
    end
    return #parts > 0 and (GREY .. "  " .. table.concat(parts, ", ") .. "|r") or ""
end

-- The journey, newest first, by day (with the day's totals) or by level.
function LevelLog_JourneyLines(byLevel)
    if not levels then
        return {}
    end
    local lines = {}
    local list = type(levels.journey) == "table" and levels.journey or {}
    local lastGroup
    local shown = 0
    for i = #list, 1, -1 do
        local entry = list[i]
        if type(entry) == "table" then
            local group, header
            if byLevel then
                group = tonumber(entry.l) or 0
                header = string.format("%sLevel %d|r", GOLD, group)
            else
                group = (DateFn and type(entry.t) == "number" and entry.t > 0) and DateFn("%Y-%m-%d", entry.t) or "?"
                header = GOLD .. ((DateFn and type(entry.t) == "number" and entry.t > 0) and DateFn("%a %d %b %Y", entry.t) or "Undated") .. "|r" .. DaySummary(group)
            end
            if group ~= lastGroup then
                if lastGroup ~= nil then
                    lines[#lines + 1] = " "
                end
                lines[#lines + 1] = header
                lastGroup = group
            end
            local when = byLevel and ((DateFn and type(entry.t) == "number" and entry.t > 0) and DateFn("%d %b %H:%M", entry.t) or "") or Clock(entry.t)
            lines[#lines + 1] = string.format("  %s%s|r  %s", GREY, when, EventText(entry))
            shown = shown + 1
            if shown >= JOURNEY_SHOWN then
                lines[#lines + 1] = string.format("%s... and %d older entries.|r", GREY, i - 1)
                break
            end
        end
    end
    if type(levels.journeyOld) == "table" and next(levels.journeyOld) then
        lines[#lines + 1] = " "
        lines[#lines + 1] = GOLD .. "Older (counted only)|r"
        local months = {}
        for month in pairs(levels.journeyOld) do
            months[#months + 1] = month
        end
        table.sort(months, function(a, b) return a > b end)
        for _, month in ipairs(months) do
            local counts = levels.journeyOld[month]
            local parts = {}
            for _, kind in ipairs({ "level", "zone", "dungeon", "death" }) do
                if type(counts) == "table" and (tonumber(counts[kind]) or 0) > 0 then
                    parts[#parts + 1] = counts[kind] .. " " .. (kind == "level" and "levels" or kind == "zone" and "new zones" or kind == "dungeon" and "dungeons" or "deaths")
                end
            end
            lines[#lines + 1] = string.format("  %s: %s", month, #parts > 0 and table.concat(parts, ", ") or "-")
        end
    end
    if #lines == 0 then
        lines[1] = GREY .. "Nothing yet. Levels, new zones, dungeons and deaths appear here from now on.|r"
    end
    return lines
end

local function Percent(part, total)
    if total <= 0 then
        return 0
    end
    return math.floor(part * 100 / total + 0.5)
end

-- Lifetime counters and one line per level.
function LevelLog_StatsLines()
    if not levels then
        return {}
    end
    BankTime()
    ResolveKills()
    local stats = Stats()
    local lines = {}
    local seconds, deaths, quests = 0, 0, 0
    for level = 1, currentLevel do
        local entry = levels[level]
        if type(entry) == "table" then
            seconds = seconds + (tonumber(entry.seconds) or 0)
            deaths = deaths + (tonumber(entry.deaths) or 0)
            quests = quests + (tonumber(entry.quests) or 0)
        end
    end
    local seen = type(levels.seen) == "table" and levels.seen or {}
    local since = tonumber(stats.since)
    lines[#lines + 1] = GOLD .. "Lifetime|r" .. ((since and since > 0 and DateFn) and (GREY .. "  (kills, quests, gold and flights counted since " .. DateFn("%d %b %Y", since) .. ")|r") or "")
    lines[#lines + 1] = string.format("  Time logged: %s   Deaths: %d", FormatDuration(seconds), deaths)
    lines[#lines + 1] = string.format("  Kills that gave XP: %d   Quests turned in: %d", tonumber(stats.kills) or 0, tonumber(stats.quests) or quests)
    lines[#lines + 1] = string.format("  Gold in: %s   Gold out: %s", Money(stats.moneyIn), Money(stats.moneyOut))
    lines[#lines + 1] = string.format("  Flights: %d (%s in the air)", tonumber(stats.flights) or 0, FormatDuration(tonumber(stats.activity.flight) or 0))
    lines[#lines + 1] = string.format("  Zones visited: %d   Dungeons visited: %d",
        type(seen.zones) == "table" and CountKeys(seen.zones) or 0, type(seen.dungeons) == "table" and CountKeys(seen.dungeons) or 0)
    -- Where you spent the most time.
    local zones = {}
    for name, value in pairs(stats.zones) do
        zones[#zones + 1] = { name = name, seconds = tonumber(value) or 0 }
    end
    table.sort(zones, function(a, b) return a.seconds > b.seconds end)
    if #zones > 0 then
        lines[#lines + 1] = " "
        lines[#lines + 1] = GOLD .. "Most time in|r"
        for i = 1, math.min(8, #zones) do
            lines[#lines + 1] = string.format("  %s: %s", zones[i].name, FormatDuration(zones[i].seconds))
        end
    end
    lines[#lines + 1] = " "
    lines[#lines + 1] = GOLD .. "Per level|r"
    for level = currentLevel, 1, -1 do
        local entry = levels[level]
        if type(entry) == "table" and (tonumber(entry.seconds) or 0) > 0 then
            local parts = { FormatDuration(tonumber(entry.seconds) or 0), (tonumber(entry.deaths) or 0) .. " deaths" }
            if entry.kills then
                parts[#parts + 1] = entry.kills .. " kills"
            end
            if entry.quests then
                parts[#parts + 1] = entry.quests .. " quests"
            end
            if entry.flights then
                parts[#parts + 1] = entry.flights .. " flights"
            end
            local pace = PaceText(LevelXP(level, entry), ActiveSeconds(entry))
            if pace then
                parts[#parts + 1] = pace
            end
            lines[#lines + 1] = string.format("  Level %d: %s", level, table.concat(parts, ", "))
        end
    end
    return lines
end

local function ActivityLines(activity, title)
    local lines = { GOLD .. title .. "|r" }
    local total = 0
    for _, key in ipairs(ACTIVITIES) do
        total = total + (tonumber(activity[key]) or 0)
    end
    if total < 1 then
        lines[#lines + 1] = GREY .. "  Nothing counted yet.|r"
        return lines
    end
    local order = {}
    for _, key in ipairs(ACTIVITIES) do
        if (tonumber(activity[key]) or 0) >= 1 then
            order[#order + 1] = key
        end
    end
    table.sort(order, function(a, b) return (tonumber(activity[a]) or 0) > (tonumber(activity[b]) or 0) end)
    for _, key in ipairs(order) do
        local seconds = tonumber(activity[key]) or 0
        lines[#lines + 1] = string.format("  %s: %s (%d%%)", ACTIVITY_LABEL[key], FormatDuration(seconds), Percent(seconds, total))
    end
    return lines
end

-- Where your time goes (this level and since the split was first counted), your pace and the dates.
function LevelLog_TimeLines()
    if not levels then
        return {}
    end
    BankTime()
    local lines = {}
    local entry = Entry(currentLevel)
    for _, line in ipairs(ActivityLines(Table(entry, "activity"), string.format("Level %d so far", currentLevel))) do
        lines[#lines + 1] = line
    end
    lines[#lines + 1] = " "
    for _, line in ipairs(ActivityLines(Stats().activity, "All levels since it was first counted")) do
        lines[#lines + 1] = line
    end
    lines[#lines + 1] = " "
    lines[#lines + 1] = GOLD .. "When you'll level|r"
    local rate, used = LevelLog_Pace()
    if not rate then
        lines[#lines + 1] = GREY .. "  Not enough play counted yet: a finished level, or 10 minutes on this one.|r"
        return lines
    end
    lines[#lines + 1] = string.format("  Pace: %s of play (%s; time away left out)", PaceText(rate, 3600) or "?",
        used > 0 and string.format("your last %d level(s), recent ones count more", used) or "this level so far")
    local perDay, days = LevelLog_HoursPerDay()
    if perDay then
        lines[#lines + 1] = string.format("  You play about %.1f h a day (middle of your last %d play day(s)).", perDay, days)
    else
        lines[#lines + 1] = GREY .. "  Dates appear after a day of play.|r"
    end
    local targets, seen = {}, {}
    for _, target in ipairs({ currentLevel + 1, math.min(MAX_LEVEL, (math.floor(currentLevel / 5) + 1) * 5), MAX_LEVEL }) do
        if target > currentLevel and target <= MAX_LEVEL and not seen[target] then
            seen[target] = true
            targets[#targets + 1] = target
        end
    end
    for _, target in ipairs(targets) do
        local text = LevelLog_ETAText(target)
        if text then
            lines[#lines + 1] = "  " .. text
        end
    end
    return lines
end

-- ---- The window ----------------------------------------------------------------------------------------------
local WINDOW_WIDTH, WINDOW_HEIGHT = 480, 440
local VIEWS = {
    { key = "journey", label = "Journey" },
    { key = "stats", label = "Stats" },
    { key = "time", label = "Time and ETA" },
}

-- Kept in this character's record, so LevelLogDB stays one record per character.
local function Settings()
    local settings = Table(levels, "window")
    -- Off by default (cross-addon review): at its default spot this window covers most of the hub's
    -- Level log page it opened with, and the page has its own "Show or hide window" button. Saves from
    -- before, when it was on by default, move over once.
    if not settings.pageDefault2 then
        settings.openWithPage = false
        settings.pageDefault2 = true
    end
    if type(settings.openWithPage) ~= "boolean" then
        settings.openWithPage = false
    end
    return settings
end

RefreshWindow = function()
    if not (window and levels) then
        return
    end
    window.dirty = false
    window.drawnAt = GetTime()
    local lines
    if window.view == "stats" then
        lines = LevelLog_StatsLines()
    elseif window.view == "time" then
        lines = LevelLog_TimeLines()
    else
        lines = LevelLog_JourneyLines(window.byLevel)
    end
    window.text:SetText(table.concat(lines, "\n"))
    window.content:SetHeight(math.max((Safe(window.text:GetStringHeight()) or 0) + 8, 10))
    for _, tab in ipairs(window.tabs) do
        if tab.key == window.view then
            tab:LockHighlight()
        else
            tab:UnlockHighlight()
        end
    end
    window.order:SetShown(window.view == "journey")
    window.order:SetText(window.byLevel and "By day" or "By level")
    window.auto:SetChecked(Settings().openWithPage)
end

local function BuildWindow()
    window = CreateFrame("Frame", "LevelLogWindow", UIParent, "BackdropTemplate")
    window:SetSize(WINDOW_WIDTH, WINDOW_HEIGHT)
    window:SetFrameStrata("HIGH")
    window:SetClampedToScreen(true)
    window:SetMovable(true)
    window:EnableMouse(true)
    window:RegisterForDrag("LeftButton")
    window:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 14,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    window:SetBackdropColor(0.05, 0.05, 0.08, 0.92)
    window:SetScript("OnDragStart", window.StartMoving)
    window:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local point, _, relativePoint, x, y = self:GetPoint()
        if point then
            Settings().position = { point, relativePoint, x, y }
        end
    end)
    local position = Settings().position
    if type(position) == "table" and position[1] then
        window:SetPoint(position[1], UIParent, position[2], position[3], position[4])
    else
        window:SetPoint("CENTER", UIParent, "CENTER", 260, 40)
    end
    window.view = "journey"

    local title = window:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOPLEFT", window, "TOPLEFT", 12, -10)
    title:SetText("Level log")
    local close = CreateFrame("Button", nil, window, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", window, "TOPRIGHT", -2, -2)

    window.tabs = {}
    local x = 10
    for _, view in ipairs(VIEWS) do
        local tab = CreateFrame("Button", nil, window, "UIPanelButtonTemplate")
        tab:SetSize(view.key == "time" and 104 or 80, 22)
        tab:SetPoint("TOPLEFT", window, "TOPLEFT", x, -30)
        tab:SetText(view.label)
        tab.key = view.key
        tab:SetScript("OnClick", function()
            window.view = view.key
            RefreshWindow()
        end)
        window.tabs[#window.tabs + 1] = tab
        x = x + (view.key == "time" and 108 or 84)
    end
    window.order = CreateFrame("Button", nil, window, "UIPanelButtonTemplate")
    window.order:SetSize(80, 22)
    window.order:SetPoint("TOPRIGHT", window, "TOPRIGHT", -12, -30)
    window.order:SetScript("OnClick", function()
        window.byLevel = not window.byLevel
        RefreshWindow()
    end)

    local scroll = CreateFrame("ScrollFrame", nil, window, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", window, "TOPLEFT", 12, -60)
    scroll:SetPoint("BOTTOMRIGHT", window, "BOTTOMRIGHT", -32, 36)
    window.content = CreateFrame("Frame", nil, scroll)
    window.content:SetSize(WINDOW_WIDTH - 50, 10)
    scroll:SetScrollChild(window.content)
    window.text = window.content:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    window.text:SetPoint("TOPLEFT", window.content, "TOPLEFT", 0, 0)
    window.text:SetWidth(WINDOW_WIDTH - 54)
    window.text:SetJustifyH("LEFT")
    window.text:SetJustifyV("TOP")
    window.text:SetSpacing(2)

    window.auto = CreateFrame("CheckButton", nil, window, "UICheckButtonTemplate")
    window.auto:SetSize(22, 22)
    window.auto:SetPoint("BOTTOMLEFT", window, "BOTTOMLEFT", 10, 8)
    window.auto:SetScript("OnClick", function(self)
        Settings().openWithPage = self:GetChecked() and true or false
    end)
    local autoLabel = window:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    autoLabel:SetPoint("LEFT", window.auto, "RIGHT", 2, 0)
    autoLabel:SetText("Open this window with the hub's Level log page")

    window:SetScript("OnShow", RefreshWindow)
    -- Not added to UISpecialFrames (a Blizzard table): the close button and "window" close it.
    window:Hide()
end

-- Switched Off on the hub's Manage page: the window hides and can't be opened; reopenWhenOn remembers
-- that it was open, so switching On brings it back. Recording goes on. Never Off without the hub.
local reopenWhenOn = false
local function HubSaysOff()
    return type(ForeverHub_IsOff) == "function" and ForeverHub_IsOff("LevelLog") == true
end

ForeverHubOnSwitch = ForeverHubOnSwitch or {}
ForeverHubOnSwitch.LevelLog = function(off)
    if not window then
        return
    end
    if off then
        reopenWhenOn = window:IsShown() and true or false
        window:Hide()
    elseif reopenWhenOn then
        reopenWhenOn = false
        window:Show()
        RefreshWindow()
    end
end

-- Opens (or with toggle, closes) the window. Only out of the way of loading: needs saved data and UIParent.
function LevelLog_OpenWindow(toggle)
    if not (levels and UIParent and CreateFrame) or HubSaysOff() then
        return
    end
    if not window then
        BuildWindow()
    end
    if window:IsShown() then
        if toggle then
            window:Hide()
        else
            RefreshWindow()
        end
        return
    end
    window:Show()
    RefreshWindow()
end

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("PLAYER_LOGOUT")
events:RegisterEvent("PLAYER_LEVEL_UP")
events:RegisterEvent("PLAYER_DEAD")
events:RegisterEvent("PLAYER_XP_UPDATE")
events:RegisterEvent("QUEST_TURNED_IN")
-- Journey, stats and time split (round 5 #8-#10).
for _, name in ipairs({ "PLAYER_ENTERING_WORLD", "ZONE_CHANGED_NEW_AREA", "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED",
    "PLAYER_MONEY", "QUEST_DETAIL", "QUEST_PROGRESS", "QUEST_COMPLETE", "QUEST_GREETING", "QUEST_ACCEPTED" }) do
    events:RegisterEvent(name)
end
local QUEST_WINDOW_EVENTS = { QUEST_DETAIL = true, QUEST_PROGRESS = true, QUEST_COMPLETE = true, QUEST_GREETING = true, QUEST_ACCEPTED = true }
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
        -- The zone you log in to is remembered first, so it isn't a "first visit" when the journal starts.
        lastActive, lastTick = GetTime(), GetTime()
        UpdateZone()
        StartJourney()
        Stats()
        lastMoney = GetMoney and Safe(GetMoney()) or nil
        if C_Timer and C_Timer.NewTicker then
            C_Timer.NewTicker(1, function()
                local ok, err = pcall(Tick)
                if not ok and geterrorhandler then
                    geterrorhandler()(err)
                end
            end)
        end
    elseif not levels then
        -- Saved data isn't set up until PLAYER_LOGIN.
        return
    elseif event == "PLAYER_LEVEL_UP" then
        BankTime()
        local took = tonumber(Entry(currentLevel).seconds) or 0
        Print(string.format("Level %d took %s.", currentLevel, FormatDuration(took)))
        currentLevel = Safe(arg1) or currentLevel + 1
        AddEvent("level", { n = currentLevel, s = math.floor(took), z = currentZone })
        MarkActive()
    elseif event == "PLAYER_XP_UPDATE" then
        TrackXP()
        LearnCurve()
        ResolveKills()
    elseif event == "QUEST_TURNED_IN" then
        -- Split across a level-up like the bar (see QuestTurnedIn).
        QuestTurnedIn(Safe(arg2))
        Bump(Entry(currentLevel), "quests")
        Bump(Stats(), "quests")
        Bump(Day(), "q")
        lastQuestAt = GetTime()
        MarkActive()
        RefreshWindowSoon()
    elseif event == "PLAYER_DEAD" then
        local entry = Entry(currentLevel)
        entry.deaths = entry.deaths + 1
        Bump(Day(), "d")
        AddEvent("death", { z = currentZone })
    elseif event == "PLAYER_ENTERING_WORLD" or event == "ZONE_CHANGED_NEW_AREA" then
        UpdateZone()
    elseif event == "PLAYER_REGEN_DISABLED" then
        inCombat = true
        MarkActive()
    elseif event == "PLAYER_REGEN_ENABLED" then
        inCombat, combatEndedAt = false, GetTime()
        MarkActive()
    elseif event == "PLAYER_MONEY" then
        TrackMoney()
    elseif QUEST_WINDOW_EVENTS[event] then
        lastQuestAt = GetTime()
        MarkActive()
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
-- With the hub, its "Level log" page runs this with "all": the page text, and this helper's own window
-- too when "Open this window with the hub's Level log page" is ticked (off by default). Without the hub,
-- /levellog opens the window. "window" (the page's button) opens or closes the window either way.
SlashCmdList.LEVELLOG = function(message)
    -- Saved data isn't ready until login, and the hub can open this page before then.
    if not levels then
        return
    end
    local arg = (message or ""):lower():match("^%s*(.-)%s*$")
    if arg == "window" then
        LevelLog_OpenWindow(true)
        return
    end
    if not ForeverHub_Receive then
        LevelLog_OpenWindow(false)
        return
    end
    ShowLog(arg:match("^all") ~= nil)
    if Settings().openWithPage then
        LevelLog_OpenWindow(false)
    end
end
