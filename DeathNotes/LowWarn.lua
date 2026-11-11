-- Low health and low mana in combat (research\re_round4.md R7): a red glow at the screen's edges under 35 %
-- health and a drink icon under 20 % mana, on our own frames only. In combat the game keeps your health and
-- mana secret, so they are never read: UnitHealthPercent/UnitPowerPercent evaluate them through a curve
-- (C_CurveUtil) and the (secret) result goes straight into SetAlpha, which accepts secret values
-- (UnitDocumentation UnitHealthPercent/UnitPowerPercent, CurveUtilDocumentation CreateCurve,
-- SimpleFrameAPIDocumentation SetAlpha "AllowedWhenTainted"). Nothing compares, adds or prints the result.
-- The idea (a step curve into SetAlpha) is from Glowing Bars by vattiss (value-curves.service.ts, MIT; see
-- NOTICE.md); this is our own code. CHECK IN GAME: the curve argument on client 1.60.1, and that the
-- percent is 0-1 (the curve's x axis).

local HEALTH_AT, MANA_AT = 0.35, 0.20   -- fraction of the maximum below which the cue shows
local EDGE = 0.02                        -- the cue fades in over the last 2 % above the threshold
local MIN_GAP = 0.1                      -- seconds between reads during a burst of events
local MANA = 0                           -- Enum.PowerType.Mana

local events = CreateFrame("Frame")
local edge, drink
local healthCurve, manaCurve
local hasMana = true
local broken = false                     -- the curve call failed on this client: stay off
local lastApply, pending = -1, false

local function Safe(value)
    if issecretvalue and issecretvalue(value) then
        return nil
    end
    return value
end

local function Now()
    return GetTime and GetTime() or 0
end

local function IsOff()
    return ForeverHub_IsOff and ForeverHub_IsOff("DeathNotes") or false
end

-- 1 from 0 up to the threshold, 0 from just above it (linear in between).
local function MakeCurve(at)
    if not (C_CurveUtil and C_CurveUtil.CreateCurve) then
        return nil
    end
    local ok, curve = pcall(C_CurveUtil.CreateCurve)
    if not (ok and curve) then
        return nil
    end
    local linear = Enum and Enum.LuaCurveType and Enum.LuaCurveType.Linear or 0
    if curve.SetType then
        pcall(curve.SetType, curve, linear)
    end
    curve:AddPoint(0, 1)
    curve:AddPoint(at - EDGE, 1)
    curve:AddPoint(at, 0)
    curve:AddPoint(1, 0)
    return curve
end

local function Build()
    if edge then
        return
    end
    -- Four red bars along the screen's edges, faded together by their holder's alpha.
    edge = CreateFrame("Frame", nil, UIParent)
    edge:SetAllPoints(UIParent)
    edge:SetFrameStrata("BACKGROUND")
    if edge.EnableMouse then
        edge:EnableMouse(false)
    end
    for _, side in ipairs({ { "TOPLEFT", "TOPRIGHT", nil, 14 }, { "BOTTOMLEFT", "BOTTOMRIGHT", nil, 14 },
        { "TOPLEFT", "BOTTOMLEFT", 14, nil }, { "TOPRIGHT", "BOTTOMRIGHT", 14, nil } }) do
        local bar = edge:CreateTexture(nil, "BACKGROUND")
        bar:SetColorTexture(0.9, 0.05, 0.05, 0.55)
        bar:SetPoint(side[1], edge, side[1])
        bar:SetPoint(side[2], edge, side[2])
        if side[3] then
            bar:SetWidth(side[3])
        else
            bar:SetHeight(side[4])
        end
    end
    edge:Hide()
    drink = CreateFrame("Frame", nil, UIParent)
    drink:SetSize(36, 36)
    drink:SetPoint("CENTER", UIParent, "CENTER", 0, -140)
    if drink.EnableMouse then
        drink:EnableMouse(false)
    end
    local icon = drink:CreateTexture(nil, "ARTWORK")
    icon:SetAllPoints(drink)
    icon:SetTexture("Interface\\Icons\\INV_Drink_07")
    drink:Hide()
    healthCurve, manaCurve = MakeCurve(HEALTH_AT), MakeCurve(MANA_AT)
end

local function HideAll()
    if edge then
        edge:Hide()
        drink:Hide()
    end
end

-- In a fight, from the regen events (review 4, suspicion 1): PLAYER_REGEN_DISABLED is commonly dispatched
-- before InCombatLockdown() turns true, and the cue must show at once rather than wait for the next health
-- or mana event. InCombatLockdown() only seeds it at login (a /reload in the middle of a fight).
local fighting = false
local function InCombat()
    return fighting
end

-- Out of combat (values readable): whether you have a mana bar at all (warriors and rogues don't).
local function ReadMana()
    local maxMana = UnitPowerMax and Safe(UnitPowerMax("player", MANA))
    if type(maxMana) == "number" then
        hasMana = maxMana > 0
    end
end

-- The secret results go straight from the game into SetAlpha; nothing else touches them.
local function ApplyNow()
    lastApply, pending = Now(), false
    events:SetScript("OnUpdate", nil)
    if broken or IsOff() or not InCombat() or not (healthCurve and UnitHealthPercent) then
        HideAll()
        return
    end
    local ok = pcall(function()
        edge:SetAlpha(UnitHealthPercent("player", true, healthCurve))
        edge:Show()
        if hasMana and manaCurve and UnitPowerPercent then
            drink:SetAlpha(UnitPowerPercent("player", MANA, false, manaCurve))
            drink:Show()
        else
            drink:Hide()
        end
    end)
    if not ok then
        -- This client refuses the curve call: switch the cue off for the session, quietly.
        broken = true
        HideAll()
    end
end

-- At most one read per MIN_GAP; a skipped update is caught up once by a one-shot OnUpdate.
local function CatchUp()
    if Now() - lastApply >= MIN_GAP then
        ApplyNow()
    end
end

local function Request()
    if Now() - lastApply >= MIN_GAP then
        ApplyNow()
    elseif not pending then
        pending = true
        events:SetScript("OnUpdate", CatchUp)
    end
end

events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("PLAYER_REGEN_DISABLED")
events:RegisterEvent("PLAYER_REGEN_ENABLED")
for _, name in ipairs({ "UNIT_HEALTH", "UNIT_MAXHEALTH", "UNIT_POWER_UPDATE", "UNIT_MAXPOWER" }) do
    if events.RegisterUnitEvent then
        pcall(events.RegisterUnitEvent, events, name, "player")
    else
        pcall(events.RegisterEvent, events, name)
    end
end
events:SetScript("OnEvent", function(_, event, unit)
    if event == "PLAYER_LOGIN" then
        fighting = InCombatLockdown and InCombatLockdown() and true or false
        Build()
        ReadMana()
        if fighting then
            ApplyNow()
        end
        return
    elseif not edge then
        return
    elseif event == "PLAYER_REGEN_ENABLED" then
        fighting = false
        ReadMana()
        ApplyNow()   -- hides
        return
    elseif event == "PLAYER_REGEN_DISABLED" then
        fighting = true
        ApplyNow()
        return
    end
    -- Unit events: only yours, and only while the cue is up (in combat).
    if Safe(unit) ~= "player" or not InCombat() then
        return
    end
    Request()
end)

-- For tests: the two cue frames (built at load so tests can find them before login).
function LowWarn_Frames()
    Build()
    return edge, drink
end
