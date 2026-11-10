local MAX_LEVEL = 60
local HEARTHSTONE = 6948
-- Forever keeps Classic's rates (Warcraft Tavern's Forever XP guide, Nov 2026): 5% of a level
-- per 8 hours in an inn or city, up to 150%. The Well Rested Legacy perk raises both by up to 20%.
local REST_PERCENT_PER_HOUR = 5 / 8
local MAX_REST_PERCENT = 150

local function Safe(value)
    if issecretvalue and issecretvalue(value) then
        return nil
    end
    return value
end

local function Print(text)
    if ForeverHub_Receive then
        return ForeverHub_Receive("RestGuard", text)
    end
    -- No hub window to show it in: stay quiet rather than fill the chat.
end

local function IsLeveling()
    local level = Safe(UnitLevel("player"))
    return level and level < MAX_LEVEL
end

-- Rested XP as a percent of the current level, or nil if the game didn't report it.
local function RestedPercent()
    local maxXP = Safe(UnitXPMax("player"))
    if not (maxXP and maxXP > 0) then
        return nil
    end
    local rested = GetXPExhaustion()
    if issecretvalue and issecretvalue(rested) then
        return nil
    end
    return (rested or 0) * 100 / maxXP
end

-- Under a day reads better in hours than as "0.3 days".
local function WaitText(hours)
    if hours < 24 then
        return string.format("%d hour(s)", math.max(math.ceil(hours), 1))
    end
    return string.format("%.1f days", hours / 24)
end

local function HearthstoneText()
    local place = Safe(GetBindLocation()) or "unknown"
    -- A cooldown for a stone you don't carry would read as "ready".
    local carried = C_Item and C_Item.GetItemCount and Safe(C_Item.GetItemCount(HEARTHSTONE))
    if carried == 0 then
        return "Hearthstone: bound to " .. place .. ", but it isn't in your bags"
    end
    local start, duration
    if C_Container and C_Container.GetItemCooldown then
        local ok
        ok, start, duration = pcall(C_Container.GetItemCooldown, HEARTHSTONE)
        if not ok then
            start, duration = nil, nil
        end
    end
    start, duration = Safe(start), Safe(duration)
    if not (start and duration) then
        return "Hearthstone: " .. place
    end
    local left = start + duration - GetTime()
    if start > 0 and left > 0 then
        return string.format("Hearthstone: %s, ready in %d min", place, math.ceil(left / 60))
    end
    return string.format("Hearthstone: %s, ready", place)
end

local function ShowStatus()
    Print(Safe(IsResting()) and "You're in a rested area." or "You're not in a rested area.")
    local percent = IsLeveling() and RestedPercent()
    if percent then
        local hours = (MAX_REST_PERCENT - percent) / REST_PERCENT_PER_HOUR
        if hours > 0 then
            Print(string.format("Rested: %d%% of this level. About %s at an inn to fill it (sooner with the Well Rested perk).", math.floor(percent), WaitText(hours)))
        else
            Print(string.format("Rested: %d%% of this level. That's full.", math.floor(percent)))
        end
    end
    Print(HearthstoneText())
end

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_CAMPING")
events:SetScript("OnEvent", function()
    if IsLeveling() and Safe(IsResting()) == false then
        Print("You're logging out outside a rested area, so you'll gain rested XP more slowly. Cancel and go to an inn or city if you can.")
    end
end)

SLASH_RESTGUARD1 = "/rest"
SlashCmdList.RESTGUARD = ShowStatus
