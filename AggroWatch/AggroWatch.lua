-- AggroWatch (research\re_round6.md item 2): out of combat, a small line under your character when you're about
-- to walk into a hostile mob's aggro range ("Careful: Bristleback Shaman aggro in ~4 yd"). Read-only: it never
-- targets, casts, moves or marks anything, and only reads units the game already shows you (nameplates, your
-- target, your mouseover). It never changes, reparents or reads into nameplate frames, and never touches a CVar.
--
-- The aggro radius follows the Classic rule as Olfato models it (GPL-3.0, see NOTICE.md): about 20 yd against a
-- mob of your level, 1 yd less per level you're above it (at least 5), 1 yd more per level it's above you (at most
-- 45). Grey mobs don't attack on sight and are skipped. Distance comes in bands from range checks, the way
-- LibRangeCheck-3.0 does it (MIT, see NOTICE.md): CheckInteractDistance and C_Item.IsItemInRange with items of a
-- known range; the item IDs and yards are LibRangeCheck's Classic Era / Forever table. Our own code.
--
-- Quiet in combat (the scan stops on PLAYER_REGEN_DISABLED) and when switched Off on the hub. Range answers,
-- levels and names may be secret: a secret value is skipped, never compared.
-- CHECK IN GAME: C_Item.IsItemInRange on a hostile nameplate unit out of combat returns true/false (not nil,
-- not refused); no "blocked" pop-up; the line hides at once on pull.

local SOURCE = "AggroWatch"
local SCAN_SECONDS = 0.25          -- 4 scans a second, only while out of combat with a candidate in view
local WARN_MARGIN = 10             -- show when a mob's radius is within this many yards of you
local NEAR_MARGIN = 5              -- closer than this: orange
local MAX_UNITS = 20               -- units range-checked per scan, at most
local SOUND_GAP = 8                -- seconds between two warning sounds
local NAMEPLATES = 40
local BASE_RADIUS, MIN_RADIUS, MAX_RADIUS = 20, 5, 45
local SKULL_ABOVE = 10             -- a "??" mob is at least this many levels above you

-- Range checks, nearest first: { yards, interact index } or { yards, nil, item IDs }. From LibRangeCheck-3.0's
-- Classic Era / Forever lists (HarmItems, interact 3 = 8 yd, 4 = 28 yd). Two items per band where it has them,
-- in case one isn't in the client's item cache.
local CHECKS = {
    { 5, nil, { 8149, 15826 } },
    { 8, 3 },
    { 10, nil, { 9606, 9618 } },
    { 15, nil, { 4559 } },
    { 20, nil, { 1191, 10645 } },
    { 25, nil, { 13289 } },
    { 28, 4 },
    { 30, nil, { 835, 7734 } },
    { 35, nil, { 1258, 18904 } },
    { 40, nil, { 4945, 8348 } },
}
-- LibRangeCheck: these races stand at another interact distance.
local INTERACT_BY_RACE = { Tauren = { [3] = 6, [4] = 25 }, Scourge = { [3] = 7, [4] = 27 } }
local SKIP_CREATURE = { [8] = true, [11] = true, [12] = true }   -- critter, totem, non-combat pet

local COLOR_RED, COLOR_ORANGE, COLOR_YELLOW = "|cffff3030", "|cffff8c1a", "|cffffd100"

local NAMEPLATE_TOKENS = {}
for i = 1, NAMEPLATES do
    NAMEPLATE_TOKENS[i] = "nameplate" .. i
end

local plates = {}                  -- nameplate tokens in view (keys reused, so nothing new per scan)
local fighting = false
local db
local frame, label
local elapsed = 0
local running = false
local lastSoundName, lastSoundAt = nil, -100

-- The warning on screen now (nil gap: none). Kept in locals so a scan builds no tables.
local shownName, shownLevel, shownGap, shownRadius, shownInside

local function Safe(value)
    if issecretvalue and issecretvalue(value) then
        return nil
    end
    return value
end

-- A call that may be refused or return a secret: nil then.
local function Read(fn, ...)
    if type(fn) ~= "function" then
        return nil
    end
    local ok, a, b = pcall(fn, ...)
    if not ok then
        return nil
    end
    return Safe(a), Safe(b)
end

local function Now()
    return GetTime and Safe(GetTime()) or 0
end

local function IsOff()
    return type(ForeverHub_IsOff) == "function" and ForeverHub_IsOff(SOURCE) == true
end

local function InCombat()
    if fighting then
        return true
    end
    return (InCombatLockdown and Read(InCombatLockdown)) or (UnitAffectingCombat and Read(UnitAffectingCombat, "player")) or false
end

---------------------------------------------------------------------------- the rules

-- Classic aggro radius for a mob of mobLevel against you at playerLevel. -1 (a "??" mob) counts as far above.
function AggroWatch_Radius(mobLevel, playerLevel)
    if type(mobLevel) ~= "number" or type(playerLevel) ~= "number" then
        return BASE_RADIUS
    end
    if mobLevel < 1 then
        mobLevel = playerLevel + SKULL_ABOVE
    end
    local radius = BASE_RADIUS + (mobLevel - playerLevel)
    if radius < MIN_RADIUS then
        return MIN_RADIUS
    elseif radius > MAX_RADIUS then
        return MAX_RADIUS
    end
    return radius
end

-- The highest mob level that is grey to you (Classic's GetGrayLevel). 0: nothing is grey.
function AggroWatch_GreyLevel(playerLevel)
    if type(playerLevel) ~= "number" or playerLevel <= 5 then
        return 0
    elseif playerLevel <= 39 then
        return playerLevel - math.floor(playerLevel / 10) - 5
    elseif playerLevel <= 59 then
        return playerLevel - math.floor(playerLevel / 5) - 1
    end
    return playerLevel - 9
end

---------------------------------------------------------------------------- range

local raceInteract
local function InteractYards(index, yards)
    local race = raceInteract and raceInteract[index]
    return race or yards
end

-- true / false, or nil when this check can't answer (item not cached, refused, secret).
local function InRange(unit, check)
    if check[2] then
        if not CheckInteractDistance then
            return nil
        end
        local result = Read(CheckInteractDistance, unit, check[2])
        if type(result) == "boolean" then
            return result
        end
        return nil
    end
    if not (C_Item and C_Item.IsItemInRange) then
        return nil
    end
    local items = check[3]
    for i = 1, #items do
        local result = Read(C_Item.IsItemInRange, items[i], unit)
        if type(result) == "boolean" then
            return result
        end
    end
    return nil
end

-- The band a unit is in: low (it's farther than this) and high (it's within this), high nil when farther than
-- every check that answered or than `limit`. One check for a unit out past 40 yd; the walk stops past `limit`.
local function Measure(unit, limit)
    local far = InRange(unit, CHECKS[#CHECKS])
    if far == false then
        return CHECKS[#CHECKS][1], nil
    end
    local low = 0
    for i = 1, #CHECKS do
        local check = CHECKS[i]
        local yards = check[2] and InteractYards(check[2], check[1]) or check[1]
        if yards > low then
            local result = InRange(unit, check)
            if result == true then
                return low, yards
            elseif result == false then
                low = yards
                if low > limit then
                    return low, nil
                end
            end
        end
    end
    return low, nil
end
AggroWatch_Measure = Measure

---------------------------------------------------------------------------- the frame

local function Build()
    if frame or not CreateFrame then
        return
    end
    frame = CreateFrame("Frame", nil, UIParent)
    frame:SetSize(360, 22)
    frame:SetPoint("CENTER", UIParent, "CENTER", 0, -175)
    frame:SetFrameStrata("LOW")
    if frame.EnableMouse then
        frame:EnableMouse(false)   -- never in the way of a click
    end
    local back = frame:CreateTexture(nil, "BACKGROUND")
    back:SetAllPoints(frame)
    back:SetColorTexture(0, 0, 0, 0.45)
    label = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    label:SetPoint("CENTER", frame, "CENTER", 0, 0)
    frame:Hide()
end

local function HideWarning()
    shownName, shownLevel, shownGap, shownRadius, shownInside = nil, nil, nil, nil, nil
    if frame then
        frame:Hide()
    end
end

local function SoundAllowed()
    if not (db and db.sound == true) or IsOff() then
        return false
    end
    local hub = type(ForeverHubDB) == "table" and ForeverHubDB
    local alerts = hub and type(hub.alerts) == "table" and hub.alerts
    return not (alerts and alerts.sound == false)
end

local function MaybeSound(name, gap, inside)
    if not (inside or gap <= NEAR_MARGIN) or not SoundAllowed() then
        return
    end
    local now = Now()
    if name == lastSoundName and now - lastSoundAt < SOUND_GAP * 4 then
        return
    end
    if now - lastSoundAt < SOUND_GAP then
        return
    end
    lastSoundName, lastSoundAt = name, now
    if PlaySound and SOUNDKIT and SOUNDKIT.RAID_WARNING then
        pcall(PlaySound, SOUNDKIT.RAID_WARNING)
    end
end

local function ShowWarning(name, level, gap, radius, inside)
    Build()
    if not frame then
        return
    end
    local changed = name ~= shownName or inside ~= shownInside or gap ~= shownGap or level ~= shownLevel
    shownName, shownLevel, shownGap, shownRadius, shownInside = name, level, gap, radius, inside
    if changed then
        local levelText = (type(level) == "number" and level > 0) and (" (" .. level .. ")") or " (??)"
        if inside then
            label:SetText(string.format("%sCareful: %s%s - you're in its aggro range (~%d yd)|r", COLOR_RED, name, levelText, radius))
        else
            local color = gap <= NEAR_MARGIN and COLOR_ORANGE or COLOR_YELLOW
            label:SetText(string.format("%sCareful: %s%s aggro in ~%d yd|r", color, name, levelText, math.max(gap, 1)))
        end
    end
    frame:Show()
    MaybeSound(name, gap, inside)
end

---------------------------------------------------------------------------- the scan

local Refresh                      -- defined with the event frame below
local playerLevel, greyLevel
local bestName, bestLevel, bestGap, bestRadius, bestInside
local checked

-- One unit: skipped unless it's a hostile, living, idle, non-grey NPC the game lets us read.
local function Consider(unit)
    if checked >= MAX_UNITS then
        return
    end
    if not (UnitExists and Read(UnitExists, unit)) then
        return
    end
    if not (UnitCanAttack and Read(UnitCanAttack, "player", unit) == true) then
        return
    end
    local reaction = UnitReaction and Read(UnitReaction, unit, "player")
    if type(reaction) ~= "number" or reaction > 3 then
        return   -- neutral (yellow) mobs don't attack on sight
    end
    if (UnitIsPlayer and Read(UnitIsPlayer, unit) ~= false) or (UnitIsDead and Read(UnitIsDead, unit) ~= false) then
        return   -- players, dead mobs, and anything the game won't tell us
    end
    if UnitAffectingCombat and Read(UnitAffectingCombat, unit) ~= false then
        return   -- already fighting (someone else's pull), or unknown
    end
    local level = UnitLevel and Read(UnitLevel, unit)
    if type(level) ~= "number" then
        return
    end
    if level > 0 then
        local trivial = UnitIsTrivial and Read(UnitIsTrivial, unit)
        if trivial == true or (trivial == nil and level <= greyLevel) then
            return
        end
    end
    if UnitCreatureType then
        local _, typeID = Read(UnitCreatureType, unit)
        if SKIP_CREATURE[typeID] then
            return
        end
    end
    checked = checked + 1
    local radius = AggroWatch_Radius(level, playerLevel)
    local low, high = Measure(unit, radius + WARN_MARGIN)
    if not high then
        return
    end
    local inside = high <= radius
    -- The middle of the band, less the radius: how far you can still walk toward it.
    local gap = math.floor((low + high) / 2 - radius + 0.5)
    if not inside and gap > WARN_MARGIN then
        return
    end
    local score = inside and -100 or gap
    if bestGap == nil or score < (bestInside and -100 or bestGap) then
        bestName = (UnitName and Read(UnitName, unit)) or "a hostile mob"
        bestLevel, bestGap, bestRadius, bestInside = level, gap, radius, inside
    end
end

local function Scan()
    if IsOff() or InCombat() then
        return HideWarning()
    end
    playerLevel = UnitLevel and Read(UnitLevel, "player")
    if type(playerLevel) ~= "number" then
        return HideWarning()
    end
    greyLevel = AggroWatch_GreyLevel(playerLevel)
    bestName, bestLevel, bestGap, bestRadius, bestInside = nil, nil, nil, nil, nil
    checked = 0
    for token in pairs(plates) do
        Consider(token)
    end
    Consider("target")
    Consider("mouseover")
    if bestGap == nil then
        HideWarning()
        if next(plates) == nil then
            Refresh()   -- the mouseover left with no event: stop scanning once nothing is in view
        end
        return
    end
    ShowWarning(bestName, bestLevel, bestGap, bestRadius, bestInside)
end

local events = CreateFrame("Frame")

local function OnUpdate(_, delta)
    elapsed = elapsed + (tonumber(delta) or 0)
    if elapsed < SCAN_SECONDS then
        return
    end
    elapsed = 0
    local ok, err = pcall(Scan)
    if not ok then
        HideWarning()
        if geterrorhandler then
            geterrorhandler()(err)
        end
    end
end

-- The scan runs only out of combat, switched On, with something to look at.
function Refresh()
    local want = not IsOff() and not InCombat()
        and (next(plates) ~= nil or (UnitExists and (Read(UnitExists, "target") or Read(UnitExists, "mouseover"))) and true or false)
    if want and not running then
        running, elapsed = true, SCAN_SECONDS
        events:SetScript("OnUpdate", OnUpdate)
    elseif not want and running then
        running = false
        events:SetScript("OnUpdate", nil)
    end
    if not want then
        HideWarning()
    end
end

local function SeedPlates()
    for token in pairs(plates) do
        plates[token] = nil
    end
    if not UnitExists then
        return
    end
    for i = 1, NAMEPLATES do
        local token = NAMEPLATE_TOKENS[i]
        if Read(UnitExists, token) then
            plates[token] = true
        end
    end
end

-- Ask the client to cache the range items, so IsItemInRange can answer (it can't for an unknown item).
local function LoadItems()
    if not (C_Item and C_Item.RequestLoadItemDataByID) then
        return
    end
    for i = 1, #CHECKS do
        local items = CHECKS[i][3]
        if items then
            for j = 1, #items do
                pcall(C_Item.RequestLoadItemDataByID, items[j])
            end
        end
    end
end

events:RegisterEvent("PLAYER_LOGIN")
for _, name in ipairs({ "PLAYER_ENTERING_WORLD", "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED", "NAME_PLATE_UNIT_ADDED",
    "NAME_PLATE_UNIT_REMOVED", "PLAYER_TARGET_CHANGED", "UPDATE_MOUSEOVER_UNIT" }) do
    pcall(events.RegisterEvent, events, name)
end
events:SetScript("OnEvent", function(_, event, unit)
    if event == "PLAYER_LOGIN" then
        AggroWatchDB = type(AggroWatchDB) == "table" and AggroWatchDB or {}
        db = AggroWatchDB
        -- Bounded: one setting, nothing else is kept.
        for key in pairs(db) do
            if key ~= "sound" then
                db[key] = nil
            end
        end
        db.sound = db.sound == true
        local _, raceFile = Read(UnitRace, "player")
        raceInteract = INTERACT_BY_RACE[raceFile]
        LoadItems()
        Build()
        fighting = InCombatLockdown and Read(InCombatLockdown) == true or false
    elseif event == "PLAYER_ENTERING_WORLD" then
        SeedPlates()
    elseif event == "PLAYER_REGEN_DISABLED" then
        fighting = true
    elseif event == "PLAYER_REGEN_ENABLED" then
        fighting = false
    elseif event == "NAME_PLATE_UNIT_ADDED" then
        unit = Safe(unit)
        if type(unit) == "string" then
            plates[unit] = true
        end
    elseif event == "NAME_PLATE_UNIT_REMOVED" then
        unit = Safe(unit)
        if type(unit) == "string" then
            plates[unit] = nil
        end
    end
    Refresh()
end)

-- Switched Off on the hub: the line goes at once and the scan stops; On again picks up where it was.
ForeverHubOnSwitch = ForeverHubOnSwitch or {}
ForeverHubOnSwitch.AggroWatch = function()
    Refresh()
end

---------------------------------------------------------------------------- settings and page

function AggroWatch_SoundOn()
    return db ~= nil and db.sound == true
end

function AggroWatch_SetSound(on)
    if db then
        db.sound = on and true or false
    end
end

-- The warning on screen now, or nil: name, level, yards left (gap), radius, inside.
function AggroWatch_Current()
    if not (frame and frame:IsShown()) or shownGap == nil then
        return nil
    end
    return shownName, shownLevel, shownGap, shownRadius, shownInside
end

function AggroWatch_Frame()
    Build()
    return frame
end

local function Print(text)
    if ForeverHub_Receive then
        return ForeverHub_Receive(SOURCE, text)
    end
    -- No hub window to show it in: stay quiet rather than fill the chat.
end

local function ShowPage(arg)
    local want = string.lower(arg or ""):gsub("^%s+", ""):gsub("%s+$", "")
    if want == "sound on" then
        AggroWatch_SetSound(true)
    elseif want == "sound off" then
        AggroWatch_SetSound(false)
    elseif want ~= "" then
        Print("Type: sound on, or: sound off.")
    end
    Print("Out of combat, a line under your character warns you before you walk into a hostile mob's aggro range.")
    Print("|cff999999Radius: about 20 yd against a mob of your level, 1 yd less per level you're above it (at least 5), 1 more per level it's above you (at most 45). Grey and neutral mobs are skipped.|r")
    local enemies = C_CVar and C_CVar.GetCVarBool and Read(C_CVar.GetCVarBool, "nameplateShowEnemies")
    if enemies == false then
        Print("|cffff8c1aEnemy nameplates are off.|r Press V to turn them on: AggroWatch reads mobs from them (otherwise only your target and mouseover).")
    end
    Print(string.format("Sound: %s |cff999999(type sound on / sound off)|r", AggroWatch_SoundOn() and "on" or "off"))
    local name, _, gap, radius, inside = AggroWatch_Current()
    if name then
        Print(inside and string.format("Now: inside %s's aggro range (~%d yd).", name, radius)
            or string.format("Now: %s's aggro range is ~%d yd away.", name, gap))
    end
end

SLASH_AGGROWATCH1 = "/aggro"
SlashCmdList.AGGROWATCH = ShowPage
