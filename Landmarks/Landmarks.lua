-- Landmarks: remembers the useful people and things you've visited (vendors, repairers, innkeepers,
-- flight masters, mailboxes, banks, trainers) and tells you the nearest one. Read-only: it only
-- listens for the windows you open yourself and reads your map position.

local MAX_PLACES = 400
local SAME_SPOT_YARDS = 30
local NEAREST_PER_KIND = 1

-- Kinds in the order the page lists them. The word is also what you type to pin the nearest one.
local KINDS = {
    { key = "repair", label = "Repair" },
    { key = "vendor", label = "Vendor" },
    { key = "food", label = "Food and drink" },
    { key = "inn", label = "Innkeeper" },
    { key = "flight", label = "Flight master" },
    { key = "mail", label = "Mailbox" },
    { key = "bank", label = "Bank" },
    { key = "trainer", label = "Class trainer" },
    { key = "profession", label = "Profession trainer" },
}
local KIND_LABEL = {}
for _, kind in ipairs(KINDS) do
    KIND_LABEL[kind.key] = kind.label
end

local CLASS_CONSUMABLE, SUBCLASS_FOOD_DRINK = 0, 5
local BINDER_ICON = 132052  -- the gossip icon on "Make this inn your home"

local db
local lastPinned

local function Safe(value)
    if issecretvalue and issecretvalue(value) then
        return nil
    end
    return value
end

local function Print(text)
    if ForeverHub_Receive then
        return ForeverHub_Receive("Landmarks", text)
    end
    -- No hub window to show it in: stay quiet rather than fill the chat.
end

-- Where you are: the map you're on, your place on it, and the same spot in world yards so
-- distances work across maps on one continent.
local function Here()
    if not (C_Map and C_Map.GetBestMapForUnit and C_Map.GetPlayerMapPosition) then
        return nil
    end
    local mapID = Safe(C_Map.GetBestMapForUnit("player"))
    local position = mapID and C_Map.GetPlayerMapPosition(mapID, "player")
    if not position then
        return nil
    end
    local x, y = position:GetXY()
    x, y = Safe(x), Safe(y)
    if not (x and y) then
        return nil
    end
    local spot = { mapID = mapID, x = x, y = y }
    if C_Map.GetWorldPosFromMapPos and CreateVector2D then
        local continent, world = C_Map.GetWorldPosFromMapPos(mapID, CreateVector2D(x, y))
        if continent and world then
            local wx, wy = world:GetXY()
            spot.continent, spot.wx, spot.wy = Safe(continent), Safe(wx), Safe(wy)
        end
    end
    return spot
end

local function PlaceName()
    local sub = GetSubZoneText and Safe(GetSubZoneText())
    local zone = GetZoneText and Safe(GetZoneText())
    if sub and sub ~= "" and sub ~= zone then
        return sub .. ", " .. (zone or "")
    end
    return zone or "somewhere"
end

local function Yards(spot, place)
    if spot.continent and place.continent and spot.continent == place.continent and spot.wx and place.wx then
        return math.sqrt((spot.wx - place.wx) ^ 2 + (spot.wy - place.wy) ^ 2)
    end
    return nil
end

-- The same spot, by world distance, or by map fraction where world positions aren't available (instances).
local function SameSpot(spot, place)
    local yards = Yards(spot, place)
    if yards then
        return yards < SAME_SPOT_YARDS
    end
    return spot.mapID == place.mapID and math.abs(spot.x - (place.x or 2)) < 0.003 and math.abs(spot.y - (place.y or 2)) < 0.003
end

-- One record per kind and spot: a vendor you visit every day is still one line. Names alone don't
-- merge, since every mailbox is "Mailbox" and two towns can each have an innkeeper of the same name.
local function Remember(kind, name, spot)
    if not (db and spot) then
        return
    end
    for _, place in ipairs(db.places) do
        if place.kind == kind and SameSpot(spot, place) then
            place.name, place.seen = name, time()
            place.mapID, place.x, place.y = spot.mapID, spot.x, spot.y
            place.continent, place.wx, place.wy = spot.continent, spot.wx, spot.wy
            place.where = PlaceName()
            return
        end
    end
    db.places[#db.places + 1] = {
        kind = kind, name = name, where = PlaceName(), seen = time(),
        mapID = spot.mapID, x = spot.x, y = spot.y, continent = spot.continent, wx = spot.wx, wy = spot.wy,
    }
    if #db.places > MAX_PLACES then
        table.sort(db.places, function(a, b)
            return (a.seen or 0) > (b.seen or 0)
        end)
        for index = #db.places, MAX_PLACES + 1, -1 do
            db.places[index] = nil
        end
    end
end

local function NpcName(fallback)
    return (UnitName and Safe(UnitName("npc"))) or fallback
end

-- Whether the merchant window that just opened sells anything to eat or drink.
local function SellsFood()
    if not (GetMerchantNumItems and GetMerchantItemID and C_Item and C_Item.GetItemInfoInstant) then
        return false
    end
    for index = 1, Safe(GetMerchantNumItems()) or 0 do
        local itemID = Safe(GetMerchantItemID(index))
        if itemID then
            local _, _, _, _, _, classID, subClassID = C_Item.GetItemInfoInstant(itemID)
            if Safe(classID) == CLASS_CONSUMABLE and Safe(subClassID) == SUBCLASS_FOOD_DRINK then
                return true
            end
        end
    end
    return false
end

local function Nearest(spot, kind)
    local best, bestYards
    for _, place in ipairs(db.places) do
        if place.kind == kind then
            local yards = Yards(spot, place)
            if yards and (not bestYards or yards < bestYards) then
                best, bestYards = place, yards
            end
        end
    end
    return best, bestYards
end

local function YardsText(yards)
    if yards >= 1000 then
        return string.format("%.1f k yd", yards / 1000)
    end
    return string.format("%d yd", math.floor(yards))
end

-- Pins the place on your map and screen, the same way the game's own map pin works.
local function Pin(place)
    if not (place and place.mapID and place.x and C_Map and C_Map.SetUserWaypoint and UiMapPoint and UiMapPoint.CreateFromCoordinates) then
        return false
    end
    if C_Map.CanSetUserWaypointOnMap and not Safe(C_Map.CanSetUserWaypointOnMap(place.mapID)) then
        return false
    end
    local wasSet = C_Map.SetUserWaypoint(UiMapPoint.CreateFromCoordinates(place.mapID, place.x, place.y))
    if Safe(wasSet) == false then
        return false
    end
    if C_SuperTrack and C_SuperTrack.SetSuperTrackedUserWaypoint then
        C_SuperTrack.SetSuperTrackedUserWaypoint(true)
    end
    lastPinned = place
    return true
end

local function ShowPage(arg)
    if not db then
        return
    end
    local want = (arg or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
    local spot = Here()
    if want ~= "" then
        local kind
        for _, entry in ipairs(KINDS) do
            if entry.key == want or entry.label:lower() == want then
                kind = entry.key
            end
        end
        if not kind then
            Print("I don't know a place called '" .. want .. "'. Try: repair, vendor, food, inn, flight, mail, bank, trainer, profession.")
        elseif not spot then
            Print("I can't read where you are right now.")
        else
            local place, yards = Nearest(spot, kind)
            if not place then
                Print("No " .. KIND_LABEL[kind]:lower() .. " remembered on this continent yet. Visit one and it's saved.")
            elseif Pin(place) then
                Print(string.format("Pinned %s (%s), %s away.", place.name, place.where or "", YardsText(yards)))
            else
                Print(string.format("Nearest %s: %s (%s), %s away.", KIND_LABEL[kind]:lower(), place.name, place.where or "", YardsText(yards)))
            end
        end
    end
    if not spot then
        Print("Where you are can't be read right now, so distances are left out.")
        Print(string.format("|cff999999%d places remembered.|r", #db.places))
        return
    end
    local any = false
    for _, entry in ipairs(KINDS) do
        local place, yards
        if spot then
            place, yards = Nearest(spot, entry.key)
        end
        if place then
            any = true
            Print(string.format("|cffffd100%s:|r %s, %s |cff999999(%s)|r", entry.label, place.name, place.where or "", YardsText(yards)))
        else
            local count = 0
            for _, other in ipairs(db.places) do
                if other.kind == entry.key then
                    count = count + 1
                end
            end
            if count > 0 then
                any = true
                Print(string.format("|cffffd100%s:|r %d remembered, none on this continent", entry.label, count))
            end
        end
    end
    if not any then
        Print("Nothing remembered yet. Talk to vendors, innkeepers, flight masters and trainers, open mailboxes and banks, and they're saved here.")
    end
    Print(string.format("|cff999999%d places remembered.|r", #db.places))
end

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("MERCHANT_SHOW")
events:RegisterEvent("MAIL_SHOW")
events:RegisterEvent("TAXIMAP_OPENED")
events:RegisterEvent("TRAINER_SHOW")
events:RegisterEvent("BANKFRAME_OPENED")
events:RegisterEvent("CONFIRM_BINDER")
events:RegisterEvent("GOSSIP_SHOW")
events:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_LOGIN" then
        LandmarksDB = LandmarksDB or {}
        local realm = (GetRealmName and Safe(GetRealmName())) or "Unknown"
        LandmarksDB[realm] = LandmarksDB[realm] or { places = {} }
        db = LandmarksDB[realm]
        db.places = db.places or {}
        return
    end
    if not db then
        return
    end
    local spot = Here()
    if not spot then
        return
    end
    if event == "MERCHANT_SHOW" then
        local name = NpcName("Vendor")
        Remember("vendor", name, spot)
        if CanMerchantRepair and Safe(CanMerchantRepair()) then
            Remember("repair", name, spot)
        end
        if SellsFood() then
            Remember("food", name, spot)
        end
    elseif event == "MAIL_SHOW" then
        Remember("mail", "Mailbox", spot)
    elseif event == "TAXIMAP_OPENED" then
        Remember("flight", NpcName("Flight master"), spot)
    elseif event == "TRAINER_SHOW" then
        local profession = IsTradeskillTrainer and Safe(IsTradeskillTrainer())
        Remember(profession and "profession" or "trainer", NpcName("Trainer"), spot)
    elseif event == "BANKFRAME_OPENED" then
        Remember("bank", NpcName("Banker"), spot)
    elseif event == "CONFIRM_BINDER" then
        Remember("inn", NpcName("Innkeeper"), spot)
    elseif event == "GOSSIP_SHOW" then
        -- An innkeeper's menu offers to make the inn your home; that's enough to remember them.
        if C_GossipInfo and C_GossipInfo.GetOptions then
            for _, option in ipairs(C_GossipInfo.GetOptions() or {}) do
                local name, icon = Safe(option.name), Safe(option.icon)
                -- The binder's own icon, or the English wording as a fallback.
                if icon == BINDER_ICON or (type(name) == "string" and name:lower():find("home", 1, true)) then
                    Remember("inn", NpcName("Innkeeper"), spot)
                    break
                end
            end
        end
    end
end)

SLASH_LANDMARKS1 = "/places"
SLASH_LANDMARKS2 = "/landmarks"
SlashCmdList.LANDMARKS = ShowPage

-- Lets other helpers ask: the nearest remembered place of a kind, with its distance in yards.
function Landmarks_Nearest(kind)
    if not db then
        return nil
    end
    local spot = Here()
    if not spot then
        return nil
    end
    return Nearest(spot, kind)
end
