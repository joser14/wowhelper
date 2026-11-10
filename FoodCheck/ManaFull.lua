-- "Mana full in N s" (research\re_round4.md R17): a side-panel row after a fight, with how much sooner your
-- best drink would get you there. Facts from Full Mana Forever by KesaObscura (Regen.lua notes, MIT; see
-- NOTICE.md): mana regen on Forever is continuous, a mana-costing cast drops it to the "casting" rate for 5 s,
-- GetPowerRegen is readable out of combat and secret in combat, and the "normal" rate is best taken as the
-- lowest rate per 30 s over the last 5 minutes out of combat (so Innervate or a ley line doesn't count),
-- leaving out Resurrection Sickness (spell 15007). Our own code. Out of combat only; never drinks for you.

local MANA = 0                       -- Enum.PowerType.Mana
local BUCKET_SECONDS, KEEP_SECONDS = 30, 300
local FIVE_SECOND_RULE = 5
local MIN_ROW_SECONDS = 15           -- a shorter wait isn't worth a row
local MIN_SAVING_SECONDS = 10        -- drinking is suggested only when it saves at least this much
local DRINK_CACHE_SECONDS = 10
local RESURRECTION_SICKNESS = 15007

local buckets = {}                   -- bucket number -> lowest base regen (mana per second) seen in it
local lastCast                       -- GetTime() of your last successful cast (any spell: costs aren't read)
local drinkCache                     -- { at, link, amount, seconds } or { at } when there's none

local function Safe(value)
    if issecretvalue and issecretvalue(value) then
        return nil
    end
    return value
end

local function Now()
    return GetTime and GetTime() or 0
end

local function AurasReadable()
    if InCombatLockdown and InCombatLockdown() then
        return false
    end
    if C_Secrets and C_Secrets.ShouldAurasBeSecret then
        local ok, secret = pcall(C_Secrets.ShouldAurasBeSecret)
        return ok and Safe(secret) == false
    end
    return true
end

-- Nil when it can't be told (then nothing is shown either).
local function Sick()
    if not AurasReadable() then
        return nil
    end
    if not (C_UnitAuras and C_UnitAuras.GetPlayerAuraBySpellID) then
        return false
    end
    local ok, aura = pcall(C_UnitAuras.GetPlayerAuraBySpellID, RESURRECTION_SICKNESS)
    return ok and type(Safe(aura)) == "table"
end

-- Base and casting regen per second, out of combat only.
local function ReadRegen()
    if (InCombatLockdown and InCombatLockdown()) or not GetPowerRegen then
        return nil
    end
    local ok, baseRegen, casting = pcall(GetPowerRegen)
    baseRegen, casting = ok and Safe(baseRegen), ok and Safe(casting)
    if type(baseRegen) == "number" then
        return baseRegen, type(casting) == "number" and casting or 0
    end
end

local function Sample()
    local regen = ReadRegen()
    if not regen or regen <= 0 or Sick() ~= false then
        return
    end
    local now = Now()
    local bucket = math.floor(now / BUCKET_SECONDS)
    if not buckets[bucket] or regen < buckets[bucket] then
        buckets[bucket] = regen
    end
    for key in pairs(buckets) do
        if now - key * BUCKET_SECONDS > KEEP_SECONDS then
            buckets[key] = nil
        end
    end
end

local function NormalRegen()
    local low
    for _, regen in pairs(buckets) do
        if not low or regen < low then
            low = regen
        end
    end
    return low
end

-- Mana a drink restores and over how long, from its tooltip ("Restores 437 mana over 18 sec"; English only).
local function DrinkInfo()
    local now = Now()
    if drinkCache and now - drinkCache.at < DRINK_CACHE_SECONDS then
        return drinkCache
    end
    drinkCache = { at = now }
    local ok, link = pcall(FoodCheck_BestDrink or function() end)
    link = ok and link or nil
    local data = link and C_TooltipInfo and C_TooltipInfo.GetHyperlink and C_TooltipInfo.GetHyperlink(link)
    for _, line in ipairs(data and data.lines or {}) do
        local text = Safe(line.leftText)
        if type(text) == "string" then
            local amount, seconds = text:lower():match("restores (%d+) mana over (%d+) sec")
            if amount then
                drinkCache.link, drinkCache.amount, drinkCache.seconds = link, tonumber(amount), tonumber(seconds)
                break
            end
        end
    end
    return drinkCache
end

-- Seconds to gain `need` mana: a cast within 5 s first runs at the casting rate.
local function SecondsToFull(need, regen, casting)
    local t = 0
    if lastCast then
        local left = FIVE_SECOND_RULE - (Now() - lastCast)
        if left > 0 then
            local gained = casting * left
            if gained >= need and casting > 0 then
                return need / casting
            end
            t, need = left, need - gained
        end
    end
    return t + need / regen
end

-- While drinking (sitting, no casting): the drink's rate plus normal regen until it ends, then regen alone.
local function SecondsWithDrink(need, regen, amount, seconds)
    local rate = amount / seconds + regen
    if need <= rate * seconds then
        return need / rate
    end
    return seconds + (need - rate * seconds) / regen
end

local function Round(seconds)
    return math.floor(seconds + 0.5)
end

local function TimeText(seconds)
    seconds = Round(seconds)
    if seconds < 90 then
        return string.format("%d s", seconds)
    end
    return string.format("%d:%02d", math.floor(seconds / 60), seconds % 60)
end

-- The side-panel row, or nil.
local function ManaRow()
    if (InCombatLockdown and InCombatLockdown()) or Sick() ~= false then
        return nil
    end
    local current = UnitPower and Safe(UnitPower("player", MANA))
    local maximum = UnitPowerMax and Safe(UnitPowerMax("player", MANA))
    if type(current) ~= "number" or type(maximum) ~= "number" or maximum <= 0 or current >= maximum then
        return nil
    end
    Sample()
    local regen = NormalRegen()
    local _, casting = ReadRegen()
    if not regen or regen <= 0 then
        return nil
    end
    local need = maximum - current
    local fullIn = SecondsToFull(need, regen, casting or 0)
    if fullIn < MIN_ROW_SECONDS then
        return nil
    end
    local text = "Mana full in " .. TimeText(fullIn)
    local drink = DrinkInfo()
    if drink.amount and drink.seconds and drink.seconds > 0 then
        local withDrink = SecondsWithDrink(need, regen, drink.amount, drink.seconds)
        if fullIn - withDrink >= MIN_SAVING_SECONDS then
            text = text .. string.format(" |cff999999- drink %s: full in %s|r", drink.link, TimeText(withDrink))
        end
    end
    return text
end

local events = CreateFrame and CreateFrame("Frame") or { RegisterEvent = function() end, SetScript = function() end }
events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("BAG_UPDATE_DELAYED")
if events.RegisterUnitEvent then
    events:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
else
    events:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
end
events:SetScript("OnEvent", function(_, event, unit)
    if event == "PLAYER_LOGIN" then
        -- Regen samples every 5 s out of combat (a cheap read; nothing in combat).
        if C_Timer and C_Timer.NewTicker then
            C_Timer.NewTicker(5, function()
                pcall(Sample)
            end)
        end
    elseif event == "BAG_UPDATE_DELAYED" then
        drinkCache = nil
    elseif event == "UNIT_SPELLCAST_SUCCEEDED" and Safe(unit) == "player" then
        lastCast = Now()
    end
end)

ForeverHubStatus = ForeverHubStatus or {}
ForeverHubStatus.FoodCheck = function()
    local text = ManaRow()
    if text then
        return { { text = text, page = "Food and drink" } }
    end
    return nil
end
