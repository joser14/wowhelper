local lastCount = 0

local function Safe(value)
    if issecretvalue and issecretvalue(value) then
        return nil
    end
    return value
end

local function Print(text)
    if ForeverHub_Receive then
        return ForeverHub_Receive("TalentNudge", text)
    end
    -- No hub window to show it in: stay quiet rather than fill the chat.
end

local function SafeCall(fn, ...)
    if type(fn) ~= "function" then
        return nil
    end
    local ok, result = pcall(fn, ...)
    return ok and Safe(result) or nil
end

-- Forever keeps talent points as trait currencies, one shared currency across the tabs.
local function TraitPoints()
    if not (C_ClassTalents and C_Traits) then
        return nil
    end
    local configID = SafeCall(C_ClassTalents.GetActiveConfigID)
    local config = configID and SafeCall(C_Traits.GetConfigInfo, configID)
    if type(config) ~= "table" or type(config.treeIDs) ~= "table" then
        return nil
    end
    local total, seen = nil, {}
    for _, treeID in ipairs(config.treeIDs) do
        -- Exclude staged changes: points placed but never applied are still unspent.
        local currencies = SafeCall(C_Traits.GetTreeCurrencyInfo, configID, treeID, true)
        for _, currency in ipairs(type(currencies) == "table" and currencies or {}) do
            local id, quantity = Safe(currency.traitCurrencyID), Safe(currency.quantity)
            if id and quantity and not seen[id] then
                seen[id] = true
                total = (total or 0) + quantity
            end
        end
    end
    return total
end

-- Returns the unspent count, or nil if the game gives no way to read it.
local function UnspentPoints()
    local best = TraitPoints()
    for _, count in ipairs({ SafeCall(GetUnspentTalentPoints) or false, SafeCall(UnitCharacterPoints, "player") or false }) do
        if type(count) == "number" and count > (best or -1) then
            best = count
        end
    end
    return best
end

local function CheckPoints()
    local count = UnspentPoints()
    if not count then
        return
    end
    if count > lastCount then
        Print(string.format("You have %d unspent talent point(s).", count))
    end
    lastCount = count
end

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("PLAYER_LEVEL_UP")
events:RegisterEvent("PLAYER_TALENT_UPDATE")
events:RegisterEvent("TRAIT_CONFIG_UPDATED")
-- The talent config can still be loading at login; these fire once it and its points are ready.
events:RegisterEvent("TRAIT_CONFIG_LIST_UPDATED")
events:RegisterEvent("TRAIT_TREE_CURRENCY_INFO_UPDATED")
events:SetScript("OnEvent", CheckPoints)

SLASH_TALENTNUDGE1 = "/tn"
SLASH_TALENTNUDGE2 = "/talentnudge"
SlashCmdList.TALENTNUDGE = function()
    local count = UnspentPoints()
    if count then
        Print(string.format("%d unspent talent point(s).", count))
    else
        Print("The game didn't report your talent points.")
    end
end

ForeverHubStatus = ForeverHubStatus or {}
ForeverHubStatus.TalentNudge = function()
    local count = UnspentPoints()
    if count and count > 0 then
        return { { text = string.format("|cffcc99eeSpend|r %d talent point(s)", count), page = "Talents" } }
    end
end
