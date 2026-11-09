-- Reads the same minimap markers the game already shows you, and speaks up about the rare ones.
local REPEAT_SECONDS = 300
local RARE_ATLAS, TREASURE_ATLAS = "VignetteKill", "VignetteLoot"

local active = {}
local announced = {}

local function Safe(value)
    if issecretvalue and issecretvalue(value) then
        return nil
    end
    return value
end

local function Alert(text)
    if ForeverHub_Receive then
        ForeverHub_Receive("RareWatch", text)
    elseif UIErrorsFrame then
        UIErrorsFrame:AddMessage(text, 1, 0.85, 0.2)
    end
end

local function PlayAlertSound()
    if PlaySound and SOUNDKIT and SOUNDKIT.RAID_WARNING then
        pcall(PlaySound, SOUNDKIT.RAID_WARNING)
    end
end

local function KindOf(info)
    local atlas = Safe(info.atlasName)
    if type(atlas) ~= "string" then
        return nil
    elseif atlas:find(RARE_ATLAS, 1, true) then
        return "rare"
    elseif atlas:find(TREASURE_ATLAS, 1, true) then
        return "treasure"
    end
end

-- Respawns get a new marker, so repeats are judged by name and time.
local function AnnounceRare(name)
    local now = GetTime()
    if announced[name] and now - announced[name] < REPEAT_SECONDS then
        return
    end
    announced[name] = now
    Alert("Rare nearby: " .. name .. ". Look for it on your minimap.")
    PlayAlertSound()
end

local function ReadMarker(guid)
    local info = C_VignetteInfo.GetVignetteInfo(guid)
    local name = info and Safe(info.name)
    local kind = info and KindOf(info)
    if not (name and kind) or Safe(info.isDead) or Safe(info.onMinimap) == false then
        active[guid] = nil
        return
    end
    -- Markers are re-read on every update, so only a newly appeared one may alert; one you're
    -- standing next to would otherwise sound again every few minutes.
    local isNew = not active[guid]
    active[guid] = { name = name, kind = kind }
    if kind == "rare" and isNew then
        AnnounceRare(name)
    end
end

local function ReadAllMarkers()
    local listed = {}
    for _, guid in ipairs(C_VignetteInfo.GetVignettes() or {}) do
        guid = Safe(guid)
        if guid then
            listed[guid] = true
            ReadMarker(guid)
        end
    end
    for guid in pairs(active) do
        if not listed[guid] then
            active[guid] = nil
        end
    end
end

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:RegisterEvent("VIGNETTES_UPDATED")
events:RegisterEvent("VIGNETTE_MINIMAP_UPDATED")
events:SetScript("OnEvent", function(_, event, guid, onMinimap)
    if not C_VignetteInfo then
        return
    end
    guid = Safe(guid)
    if event == "VIGNETTE_MINIMAP_UPDATED" and guid then
        if Safe(onMinimap) then
            ReadMarker(guid)
        else
            active[guid] = nil
        end
    else
        ReadAllMarkers()
    end
end)

ForeverHubStatus = ForeverHubStatus or {}
ForeverHubStatus.RareWatch = function()
    local items = {}
    for _, marker in pairs(active) do
        local color = marker.kind == "rare" and "|cffff8040Rare|r " or "|cffffd933Treasure|r "
        items[#items + 1] = { text = color .. marker.name }
    end
    table.sort(items, function(a, b)
        return a.text < b.text
    end)
    return items
end
