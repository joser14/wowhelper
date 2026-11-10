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

-- ---- Camps and tents (research\re_round3.md 2.5 and rank 4) ------------------------------------------------
-- Spell IDs from Tweaks Forever's Data\CampBenefits.lua (GPL-3.0-or-later, taken from Blizzard's spell data).
-- UNVERIFIED in game: confirm each with the aura on your buff bar.
local CAMP_BENEFITS = 1229741 -- "Camp Benefits", one hour
local CAMPFIRE_NEARBY = 1283391 -- "Campfire Nearby"
local TENT_BOOST = 1229451 -- the camp tent's rested boost; while it's on you, the next boost is locked out
local CAMPFIRE_PLACED = { [1307227] = true, [1307252] = true, [1307237] = true } -- basic / journeyman / expert
local CAMPFIRE_YARDS, CAMPFIRE_KEEP_SECONDS = 120, 3600
local campfire -- { x, y, map, at }: where you last placed a campfire (or first stood by one)

-- One of your auras by spell ID: the aura table, false when you don't have it, nil when it can't be read
-- now (in combat, or while auras are secret). Never read while either is true.
local function PlayerAura(spellID)
    if InCombatLockdown and InCombatLockdown() then
        return nil
    end
    if C_Secrets and C_Secrets.ShouldAurasBeSecret then
        local ok, secret = pcall(C_Secrets.ShouldAurasBeSecret)
        if not ok or Safe(secret) ~= false then
            return nil
        end
    end
    if not (C_UnitAuras and C_UnitAuras.GetPlayerAuraBySpellID) then
        return nil
    end
    local ok, aura = pcall(C_UnitAuras.GetPlayerAuraBySpellID, spellID)
    if not ok or (issecretvalue and issecretvalue(aura)) then
        return nil
    end
    return type(aura) == "table" and aura or false
end

-- Minutes left on an aura, or nil when it has no end time.
local function MinutesLeft(aura)
    local expires = Safe(aura.expirationTime)
    if type(expires) ~= "number" or expires <= 0 then
        return nil
    end
    return math.max(math.ceil((expires - GetTime()) / 60), 0)
end

local function PlayerPosition()
    if not UnitPosition then
        return nil
    end
    local ok, a, b, _, map = pcall(UnitPosition, "player")
    a, b, map = ok and Safe(a), ok and Safe(b), ok and Safe(map)
    if type(a) == "number" and type(b) == "number" then
        return a, b, map
    end
end

local function RememberCampfire()
    local a, b, map = PlayerPosition()
    if a then
        campfire = { x = a, y = b, map = map, at = GetTime() }
    end
end

local SECTORS = { "ahead", "ahead and to the left", "to your left", "behind you, to the left", "behind you",
    "behind you, to the right", "to your right", "ahead and to the right" }

-- "40 yd behind you" for a remembered campfire within reach, else nil. UnitPosition's first value grows
-- northward and its second westward; GetPlayerFacing is 0 facing north, growing to the left (west).
local function CampfireWhere()
    if not campfire or GetTime() - campfire.at > CAMPFIRE_KEEP_SECONDS then
        return nil
    end
    local a, b, map = PlayerPosition()
    if not a or (campfire.map and map and campfire.map ~= map) then
        return nil
    end
    local north, west = campfire.x - a, campfire.y - b
    local yards = math.sqrt(north * north + west * west)
    if yards > CAMPFIRE_YARDS then
        return nil
    end
    if yards < 5 then
        return "right here"
    end
    local facing = GetPlayerFacing and Safe(GetPlayerFacing())
    if type(facing) ~= "number" then
        return string.format("%d yd away", math.floor(yards + 0.5))
    end
    local atan2 = math.atan2 or math.atan
    local turn = (atan2(west, north) - facing) % (2 * math.pi)
    local sector = math.floor(turn / (math.pi / 4) + 0.5) % 8 + 1
    return string.format("%d yd %s", math.floor(yards + 0.5), SECTORS[sector])
end

-- The camp lines for the page (full) or the side panel (short). Empty when no camp is around.
function RestGuard_CampLines(short)
    local lines = {}
    local benefits, nearby, tent = PlayerAura(CAMP_BENEFITS), PlayerAura(CAMPFIRE_NEARBY), PlayerAura(TENT_BOOST)
    if nearby and not CampfireWhere() then
        -- You're by a fire whose spot we don't know yet: this is close enough to point back to it.
        RememberCampfire()
    end
    local where = CampfireWhere()
    if benefits then
        local left = MinutesLeft(benefits)
        lines[#lines + 1] = left and string.format("Camp benefits: %d min left", left) or "Camp benefits active"
    end
    if nearby then
        lines[#lines + 1] = short and "Campfire nearby" or "A campfire is nearby: rest and cook here."
    end
    if where and where ~= "right here" then
        lines[#lines + 1] = "Your campfire: " .. where
    end
    if tent then
        local left = MinutesLeft(tent)
        lines[#lines + 1] = left and string.format("Tent rest boost used; again in %d min", left) or "Tent rest boost used"
    elseif tent == false and (benefits or nearby) and IsLeveling() then
        lines[#lines + 1] = short and "Tent rest boost ready" or "Tent rest boost ready: rest 30 s by a camp tent for extra rested XP (once an hour)."
    end
    if benefits == nil and nearby == nil and not short then
        lines[#lines + 1] = "|cff999999Camp buffs can't be read in combat; look again after the fight.|r"
    end
    return lines
end

local function RestStateText()
    if not GetRestState then
        return nil
    end
    local ok, _, name, factor = pcall(GetRestState)
    name, factor = ok and Safe(name), ok and Safe(factor)
    if type(name) ~= "string" or name == "" then
        return nil
    end
    if type(factor) == "number" and factor > 0 then
        -- A multiplier (2) or already a percent (200), depending on the client.
        local percent = factor <= 10 and factor * 100 or factor
        return string.format("Rest state: %s (%d%% XP from kills)", name, math.floor(percent + 0.5))
    end
    return "Rest state: " .. name
end

local function ShowStatus()
    Print(Safe(IsResting()) and "You're in a rested area." or "You're not in a rested area.")
    local state = RestStateText()
    if state then
        Print(state)
    end
    for _, line in ipairs(RestGuard_CampLines(false)) do
        Print(line)
    end
    local percent = IsLeveling() and RestedPercent()
    if percent then
        local hours = (MAX_REST_PERCENT - percent) / REST_PERCENT_PER_HOUR
        if hours > 0 then
            Print(string.format("Rested: %d%% of this level. About %s at an inn to fill it (sooner with the Well Rested perk).", math.floor(percent), WaitText(hours)))
        else
            Print(string.format("Rested: %d%% of this level. That's full.", math.floor(percent)))
        end
        -- In kills, from the kill XP LevelLog measures (when it's loaded and has seen a few kills).
        if type(LevelLog_KillsToLevel) == "function" then
            local ok, kills, restedKills = pcall(LevelLog_KillsToLevel)
            if ok and type(kills) == "number" and type(restedKills) == "number" and restedKills > 0 then
                Print(string.format("Rested covers about %d kill(s); about %d kill(s) to level.", restedKills, kills))
            end
        end
    end
    Print(HearthstoneText())
end

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_CAMPING")
if events.RegisterUnitEvent then
    events:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
else
    events:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
end
events:SetScript("OnEvent", function(_, event, unit, _, spellID)
    if event == "UNIT_SPELLCAST_SUCCEEDED" then
        -- Your own campfire placement: remember where it is.
        if Safe(unit) == "player" and CAMPFIRE_PLACED[Safe(spellID)] then
            RememberCampfire()
        end
        return
    end
    if IsLeveling() and Safe(IsResting()) == false then
        Print("You're logging out outside a rested area, so you'll gain rested XP more slowly. Cancel and go to an inn or city if you can.")
    end
end)

-- Side panel: the camp at a glance while you're in one (nothing in combat or away from camps).
ForeverHubStatus = ForeverHubStatus or {}
ForeverHubStatus.RestGuard = function()
    local lines = RestGuard_CampLines(true)
    if #lines == 0 then
        return nil
    end
    return { { text = "|cffffd100Camp|r " .. table.concat(lines, ", "), page = "Rested XP" } }
end

SLASH_RESTGUARD1 = "/rest"
SlashCmdList.RESTGUARD = ShowStatus
