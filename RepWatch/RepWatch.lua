local ADDON_NAME = ...
local baseline
-- Faction IDs met on this character, saved so the next login can read them even under a collapsed header.
local seen = {}

-- Repeatable turn-ins (research\re_round5.md #16), our own list; Commissions Forever (GPL-3.0-or-later) was
-- only used as a checklist of which factions have them. Materials by item ID, how many one turn-in takes, and
-- the reputation guides list for it. The guide value is replaced by what you really got (racial bonuses
-- included) after your first turn-in: a quest turned in, a matching drop of the material in your bags and a
-- gain with that faction, all within a few seconds. NOT VERIFIED on Forever: item IDs and reputation values
-- (listed for an in-game check). Never turns anything in; it only counts and shows.
local RUNECLOTH = { item = 14047, name = "Runecloth", count = 20, rep = 75 }
local TURNINS = {
    [576] = { -- Timbermaw Hold
        { item = 21377, name = "Deadwood Headdress Feather", count = 5, rep = 300 },
        { item = 21383, name = "Winterfall Spirit Beads", count = 5, rep = 300 },
    },
    [529] = { -- Argent Dawn
        { item = 12840, name = "Minion's Scourgestone", count = 20, rep = 25 },
        { item = 12841, name = "Invader's Scourgestone", count = 10, rep = 25 },
        { item = 12843, name = "Corruptor's Scourgestone", count = 1, rep = 25 },
    },
    [59] = { -- Thorium Brotherhood
        { item = 11370, name = "Dark Iron Ore", count = 10, rep = 175 },
        { item = 17012, name = "Core Leather", count = 2, rep = 150 },
        { item = 17010, name = "Fiery Core", count = 1, rep = 200 },
        { item = 17011, name = "Lava Core", count = 1, rep = 200 },
    },
    [609] = { -- Cenarion Circle
        { item = 20404, name = "Encrypted Twilight Text", count = 10, rep = 500 },
    },
    -- Home cities: "Additional Runecloth", after the one-time cloth donations.
    [69] = { RUNECLOTH }, [72] = { RUNECLOTH }, [47] = { RUNECLOTH }, [54] = { RUNECLOTH },
    [76] = { RUNECLOTH }, [68] = { RUNECLOTH }, [81] = { RUNECLOTH }, [530] = { RUNECLOTH },
}
local MATCH_SECONDS = 5          -- turn-in, bag drop and reputation gain must fall this close together
local EXALTED = 8
local lastStanding, recentRep, recentDrop, lastCounts = {}, {}, {}, {}
local lastTurnIn

local function Safe(value)
    if issecretvalue and issecretvalue(value) then
        return nil
    end
    return value
end

local function Print(text)
    if ForeverHub_Receive then
        return ForeverHub_Receive("RepWatch", text)
    end
    -- No hub window to show it in: stay quiet rather than fill the chat.
end

-- One faction's data as a plain entry, or nil for plain headers and unreadable data.
local function ReadFaction(data)
    data = Safe(data)
    if type(data) ~= "table" or (Safe(data.isHeader) and not Safe(data.isHeaderWithRep)) then
        return nil
    end
    local id, name, standing = Safe(data.factionID), Safe(data.name), Safe(data.currentStanding)
    if id and name and standing then
        return {
            id = id, name = name, standing = standing, reaction = Safe(data.reaction),
            floor = Safe(data.currentReactionThreshold), ceiling = Safe(data.nextReactionThreshold),
        }
    end
end

-- Readable factions with a standing. The list skips groups collapsed in the Reputation window, so factions
-- met before are also read by ID, which works whatever is collapsed.
local function ReadFactions()
    local list, listed = {}, {}
    for index = 1, Safe(C_Reputation.GetNumFactions()) or 0 do
        local faction = ReadFaction(C_Reputation.GetFactionDataByIndex(index))
        if faction and not listed[faction.id] then
            listed[faction.id] = true
            seen[faction.id] = true
            list[#list + 1] = faction
        end
    end
    if C_Reputation.GetFactionDataByID then
        local hidden = {}
        for id in pairs(seen) do
            if not listed[id] then
                hidden[#hidden + 1] = id
            end
        end
        table.sort(hidden)
        for _, id in ipairs(hidden) do
            local faction = ReadFaction(C_Reputation.GetFactionDataByID(id))
            if faction then
                list[#list + 1] = faction
            end
        end
    end
    return list
end

-- The list can still be empty just after login, so this keeps adding factions it hasn't seen yet.
-- Known ones keep their starting point.
local function TakeBaseline()
    for _, faction in ipairs(ReadFactions()) do
        baseline = baseline or {}
        if not baseline[faction.id] then
            baseline[faction.id] = faction.standing
        end
    end
end

local function StandingName(reaction)
    return reaction and _G["FACTION_STANDING_LABEL" .. reaction] or nil
end

local function ProgressText(faction)
    local label = StandingName(faction.reaction) or "Standing"
    if faction.floor and faction.ceiling and faction.ceiling > faction.floor then
        local nextLabel = StandingName(faction.reaction and faction.reaction + 1)
        local left = faction.ceiling - faction.standing
        return string.format("%s %d/%d, %d to %s", label, faction.standing - faction.floor, faction.ceiling - faction.floor, left, nextLabel or "the next standing")
    end
    return label
end

local function ShowGains()
    TakeBaseline()
    local shown = false
    for _, faction in ipairs(ReadFactions()) do
        -- A faction first met this session starts at its current standing, so its first gain isn't known.
        local start = baseline and baseline[faction.id]
        if start and faction.standing ~= start then
            shown = true
            Print(string.format("%s: %+d this session. %s", faction.name, faction.standing - start, ProgressText(faction)))
        end
    end
    if not shown then
        Print("No reputation gained this session yet.")
    end
end

----- Turn-ins --------------------------------------------------------------------------------------------

local function Clock()
    local now = type(GetTime) == "function" and Safe(GetTime())
    return type(now) == "number" and now or 0
end

-- Saved per character: { turnins = { [factionID] = n }, learned = { [itemID] = rep per turn-in } }.
-- Both are keyed by the fixed lists above, so they can't grow past them.
local function Store()
    local db = type(RepWatchDB) == "table" and RepWatchDB or nil
    if not db then
        return { turnins = {}, learned = {} }
    end
    db.turnins = type(db.turnins) == "table" and db.turnins or {}
    db.learned = type(db.learned) == "table" and db.learned or {}
    return db
end

-- In your bags (includeBank false) or bags and bank (true); 0 when the game doesn't say.
local function Count(item, includeBank)
    if not (C_Item and C_Item.GetItemCount) then
        return 0
    end
    local ok, n = pcall(C_Item.GetItemCount, item, includeBank)
    n = ok and Safe(n)
    return type(n) == "number" and n or 0
end

-- Held by your other characters, from what ItemFinder saved (if it's installed).
local function OnAlts(item)
    local total = 0
    if type(ItemFinderDB) ~= "table" then
        return 0
    end
    local mine = ForeverCharacterKey and ForeverCharacterKey()
    for key, record in pairs(ItemFinderDB) do
        if key ~= mine and type(record) == "table" and type(record.items) == "table" then
            for _, place in pairs(record.items) do
                local n = type(place) == "table" and place[item]
                total = total + (type(n) == "number" and n or 0)
            end
        end
    end
    return total
end

local function EachTurnIn(fn)
    for factionID, list in pairs(TURNINS) do
        for _, def in ipairs(list) do
            fn(factionID, def)
        end
    end
end

-- A quest turned in, a material leaving your bags in whole turn-ins, and a gain with the faction that takes
-- it: count the turn-ins and learn what one is worth.
local function Resolve()
    if not lastTurnIn then
        return
    end
    local now = Clock()
    if now - lastTurnIn > MATCH_SECONDS then
        lastTurnIn = nil
        return
    end
    local store = Store()
    EachTurnIn(function(factionID, def)
        local drop, gain = recentDrop[def.item], recentRep[factionID]
        if lastTurnIn and drop and gain and math.abs(drop.at - lastTurnIn) <= MATCH_SECONDS
            and math.abs(gain.at - lastTurnIn) <= MATCH_SECONDS and drop.amount % def.count == 0 and gain.amount > 0 then
            local times = drop.amount / def.count
            store.turnins[factionID] = (tonumber(store.turnins[factionID]) or 0) + times
            store.learned[def.item] = math.floor(gain.amount / times + 0.5)
            recentDrop[def.item], recentRep[factionID], lastTurnIn = nil, nil, nil
        end
    end)
end

local function NoteBags()
    local now = Clock()
    local seenItem = {}
    EachTurnIn(function(_, def)
        if not seenItem[def.item] then
            seenItem[def.item] = true
            local count = Count(def.item, false)
            local before = lastCounts[def.item]
            if before and count < before then
                recentDrop[def.item] = { amount = before - count, at = now }
            end
            lastCounts[def.item] = count
        end
    end)
end

local function NoteFactions(factions)
    local now = Clock()
    for _, faction in ipairs(factions) do
        local before = lastStanding[faction.id]
        if before and faction.standing > before and TURNINS[faction.id] then
            recentRep[faction.id] = { amount = faction.standing - before, at = now }
        end
        lastStanding[faction.id] = faction.standing
    end
end

-- The "Turn-ins" lines for the Reputation page: only materials you (or your other characters) hold, and
-- factions you already turned in to, below Exalted.
local function TurnInLines(factions)
    local store = Store()
    local lines = {}
    table.sort(factions, function(a, b) return a.name < b.name end)
    for _, faction in ipairs(factions) do
        local list = TURNINS[faction.id]
        if list and (faction.reaction or 0) < EXALTED then
            local made = tonumber(store.turnins[faction.id]) or 0
            local header = false
            for _, def in ipairs(list) do
                local bags, all, alts = Count(def.item, false), Count(def.item, true), OnAlts(def.item)
                all = math.max(all, bags)
                if all + alts > 0 then
                    if not header then
                        header = true
                        lines[#lines + 1] = faction.name .. (made > 0 and string.format(" |cff999999(%d turn-in%s counted)|r", made, made == 1 and "" or "s") or "")
                    end
                    local rep = tonumber(store.learned[def.item])
                    local note = rep and "" or " |cff999999(guide value)|r"
                    rep = rep or def.rep
                    local where = {}
                    if bags > 0 then
                        where[#where + 1] = bags .. " in bags"
                    end
                    if all - bags > 0 then
                        where[#where + 1] = (all - bags) .. " in the bank"
                    end
                    if alts > 0 then
                        where[#where + 1] = alts .. " on other characters"
                    end
                    local ready = math.floor(all / def.count)
                    local text = string.format("    %s: %s = %d turn-in%s of %d, about %d rep%s", def.name, table.concat(where, ", "),
                        ready, ready == 1 and "" or "s", def.count, ready * rep, note)
                    if faction.ceiling and faction.ceiling > faction.standing and rep > 0 then
                        local turns = math.ceil((faction.ceiling - faction.standing) / rep)
                        local nextLabel = StandingName(faction.reaction and faction.reaction + 1) or "the next standing"
                        text = text .. string.format(". %d turn-in%s (%d) to %s", turns, turns == 1 and "" or "s", turns * def.count, nextLabel)
                    end
                    lines[#lines + 1] = text
                end
            end
            if not header and made > 0 then
                lines[#lines + 1] = string.format("%s |cff999999(%d turn-in%s counted, no materials on hand)|r", faction.name, made, made == 1 and "" or "s")
            end
        end
    end
    return lines
end

-- The hub's Reputation page runs this one, so it carries the session gains too.
local function ShowAll()
    TakeBaseline()
    local factions = ReadFactions()
    for _, faction in ipairs(factions) do
        local start = baseline and baseline[faction.id]
        local gain = start and faction.standing ~= start and string.format(" (%+d this session)", faction.standing - start) or ""
        Print(faction.name .. ": " .. ProgressText(faction) .. gain)
    end
    if #factions == 0 then
        Print("No factions to show yet.")
        return
    end
    local lines = TurnInLines(factions)
    if #lines > 0 then
        Print(" ")
        Print("|cffffd100Repeatable turn-ins|r |cff999999(bags and bank of this character; you turn them in yourself)|r")
        for _, line in ipairs(lines) do
            Print(line)
        end
    end
end

local events = CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:RegisterEvent("UPDATE_FACTION")
-- QuestLogDocumentation:1396 and ContainerDocumentation; guarded so a missing one can't stop the rest.
pcall(events.RegisterEvent, events, "QUEST_TURNED_IN")
pcall(events.RegisterEvent, events, "BAG_UPDATE_DELAYED")
events:SetScript("OnEvent", function(_, event, name)
    if event == "ADDON_LOADED" then
        if name == ADDON_NAME then
            RepWatchDB = type(RepWatchDB) == "table" and RepWatchDB or {}
            local saved = type(RepWatchDB.seen) == "table" and RepWatchDB.seen or {}
            for id in pairs(seen) do
                saved[id] = true
            end
            seen = saved
            RepWatchDB.seen = seen
        end
        return
    end
    if event == "QUEST_TURNED_IN" then
        lastTurnIn = Clock()
        Resolve()
        return
    elseif event == "BAG_UPDATE_DELAYED" then
        pcall(NoteBags)
        Resolve()
    elseif event == "PLAYER_ENTERING_WORLD" then
        pcall(NoteBags)
    end
    TakeBaseline()
    if event == "UPDATE_FACTION" or event == "PLAYER_ENTERING_WORLD" then
        pcall(NoteFactions, ReadFactions())
        Resolve()
    end
end)

SLASH_REPWATCH1 = "/rep"
SlashCmdList.REPWATCH = function(message)
    if message:lower():match("^%s*all%s*$") then
        ShowAll()
    else
        ShowGains()
    end
end
