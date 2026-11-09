-- ProfessionGuide: a leveling path for each of your professions, what to make next, the materials still
-- missing, and where the trainers are. Read-only: it reads your skills and what you own, and only shows
-- information (the one action is placing the game's own map pin on a trainer when you ask for it).
-- The paths themselves live in the Data_<Profession>.lua files, keyed by skill line.

local MAX_PROFESSION_SLOTS = 5
-- GetProfessions has no First Aid position, so read that skill line directly.
local FIRST_AID_SKILL_LINE = 129
-- 1.28 standard deviations above the mean: enough crafts to finish a step about 9 times in 10.
local SAFETY_SIGMAS = 1.2816
-- Continents searched when a trainer's map has to be found by its zone name (same as Dungeons).
local CONTINENTS = { 12, 13, 1414, 1415 }

local resolvedMaps = {}

local function Safe(value)
    if issecretvalue and issecretvalue(value) then
        return nil
    end
    return value
end

local function Print(text)
    if ForeverHub_Receive then
        return ForeverHub_Receive("ProfessionGuide", text)
    end
    -- No hub window to show it in: stay quiet rather than fill the chat.
end

local function Data()
    return ProfessionGuideData or {}
end

-- Profession names in lower case without spaces, so "first aid", "FirstAid" and "first" all match.
local function Squash(text)
    return (tostring(text or ""):lower():gsub("[%s%-_']", ""))
end

----- Reading your professions ------------------------------------------------------------------------

-- The guide for a skill line, or for a name when the line isn't reported.
local function GuideFor(skillLine, name)
    local data = Data()
    if skillLine and data[skillLine] then
        return data[skillLine], skillLine
    end
    for line, guide in pairs(data) do
        if name and Squash(guide.name) == Squash(name) then
            return guide, line
        end
    end
    return nil
end

-- Every profession you have as { name, rank, maxRank, guide }. GetProfessions can leave gaps, so walk each position.
local function ReadProfessions()
    local list, seen = {}, {}
    if GetProfessions and GetProfessionInfo then
        local slots = { GetProfessions() }
        for position = 1, MAX_PROFESSION_SLOTS do
            local index = Safe(slots[position])
            if index then
                local name, _, rank, maxRank, _, _, skillLine = GetProfessionInfo(index)
                name, rank, maxRank, skillLine = Safe(name), Safe(rank), Safe(maxRank), Safe(skillLine)
                if name and rank and maxRank then
                    local guide, line = GuideFor(skillLine, name)
                    list[#list + 1] = { name = name, rank = rank, maxRank = maxRank, guide = guide, line = line }
                    seen[line or name] = true
                end
            end
        end
    end
    local info = C_SkillInfo and C_SkillInfo.GetSkillLineInfoByID and Safe(C_SkillInfo.GetSkillLineInfoByID(FIRST_AID_SKILL_LINE))
    if type(info) == "table" then
        local name, rank, maxRank = Safe(info.name), Safe(info.rank), Safe(info.maxRank)
        if name and rank and maxRank and maxRank > 0 and not seen[FIRST_AID_SKILL_LINE] then
            local guide, line = GuideFor(FIRST_AID_SKILL_LINE, name)
            list[#list + 1] = { name = name, rank = rank, maxRank = maxRank, guide = guide, line = line }
        end
    end
    return list
end

local function Owned(itemID)
    if not (C_Item and C_Item.GetItemCount) then
        return 0
    end
    -- true = count the bank too, so mats you stored aren't bought twice.
    return Safe(C_Item.GetItemCount(itemID, true)) or 0
end

----- Steps and craft counts ---------------------------------------------------------------------------

-- The step that covers your skill, or nil once the path is finished.
local function CurrentStep(guide, rank)
    for index, step in ipairs(guide.steps or {}) do
        if rank < step.to then
            return step, index
        end
    end
    return nil
end

-- Crafts to go from one skill to another with a recipe that turns yellow and grey at the given skills.
-- Each point at skill s succeeds with chance (grey - s) / (grey - yellow), always while orange, so the
-- crafts per point are geometric; the answer is their mean plus a safety margin. Nil if it reaches grey.
local function SafeCrafts(from, to, yellow, grey)
    local mean, variance = 0, 0
    for skill = from, to - 1 do
        local chance = 1
        if skill >= yellow then
            chance = (grey - skill) / (grey - yellow)
        end
        if chance <= 0 then
            return nil
        end
        chance = math.min(chance, 1)
        mean = mean + 1 / chance
        variance = variance + (1 - chance) / (chance * chance)
    end
    return math.ceil(mean + SAFETY_SIGMAS * math.sqrt(variance) - 1e-9)
end

-- Crafts left in this step from your skill. Steps that also stock parts for later steps (bolts, stones)
-- plan more crafts than the skill needs; that extra is kept.
local function CraftsLeft(step, rank)
    local start = math.max(rank, step.from)
    if step.yellow and step.grey then
        local whole = SafeCrafts(step.from, step.to, step.yellow, step.grey)
        local left = SafeCrafts(start, step.to, step.yellow, step.grey)
        if whole and left then
            return left + math.max((step.crafts or whole) - whole, 0)
        end
    end
    local crafts = step.crafts or (step.to - step.from)
    return math.ceil(crafts * (step.to - start) / (step.to - step.from))
end

-- What the rest of the step needs, per material: { mat, need, have }.
local function MatsLeft(step, crafts)
    local rows = {}
    for _, mat in ipairs(step.mats or {}) do
        local need = mat.count * crafts
        rows[#rows + 1] = { mat = mat, need = need, have = Owned(mat.itemID) }
    end
    return rows
end

-- How many crafts you could make right now from what you own.
local function CraftsReady(step)
    local ready
    for _, mat in ipairs(step.mats or {}) do
        local can = math.floor(Owned(mat.itemID) / mat.count)
        ready = ready and math.min(ready, can) or can
    end
    return ready or 0
end

local function LearnText(step)
    if not step.learn or step.learn == "auto" then
        return ""
    end
    if step.learn == "trainer" then
        return " |cff999999(trainer recipe)|r"
    end
    return " |cff999999(" .. step.learn .. ")|r"
end

local function StepText(step)
    if step.gather then
        return string.format("%d-%d: %s in %s", step.from, step.to, step.gather, step.where or "")
    end
    local made = (step.makes and step.makes > 1) and string.format(" (makes %d)", step.makes) or ""
    return string.format("%d-%d: %s x%d%s", step.from, step.to, step.craft, step.crafts or (step.to - step.from), made)
end

----- Map pins ----------------------------------------------------------------------------------------

local function MapName(mapID)
    local info = mapID and C_Map and C_Map.GetMapInfo and C_Map.GetMapInfo(mapID)
    return info and Safe(info.name)
end

local function EnglishClient()
    local locale = GetLocale and Safe(GetLocale())
    return not locale or locale == "enUS" or locale == "enGB"
end

-- The map a trainer is drawn on: the stored number when its name matches, else the zone found by name.
-- On an English client a name that never matches means the number is wrong, so nothing is pinned.
-- Other languages name zones differently, so there the stored number is trusted.
local function ResolveMap(place)
    local key = tostring(place.mapID) .. ":" .. tostring(place.zone)
    if resolvedMaps[key] ~= nil then
        return resolvedMaps[key] or nil
    end
    if not (C_Map and C_Map.GetMapInfo) then
        -- Too early to look (or no map API): try again next time rather than remember a miss.
        return nil
    end
    local found
    if place.zone then
        if MapName(place.mapID) == place.zone then
            found = place.mapID
        elseif C_Map.GetMapChildrenInfo then
            for _, continent in ipairs(CONTINENTS) do
                for _, child in ipairs(C_Map.GetMapChildrenInfo(continent, nil, true) or {}) do
                    if Safe(child.name) == place.zone and Safe(child.mapID) then
                        found = Safe(child.mapID)
                        break
                    end
                end
                if found then
                    break
                end
            end
        end
        if not found and not EnglishClient() then
            found = place.mapID
        end
    end
    resolvedMaps[key] = found or false
    return found
end

-- World position of a map point, for comparing distances across zones on one continent.
local function WorldPos(mapID, x, y)
    if not (mapID and C_Map and C_Map.GetWorldPosFromMapPos and CreateVector2D) then
        return nil
    end
    local continent, world = C_Map.GetWorldPosFromMapPos(mapID, CreateVector2D(x, y))
    if not (continent and world) then
        return nil
    end
    local wx, wy = world:GetXY()
    continent, wx, wy = Safe(continent), Safe(wx), Safe(wy)
    if continent and wx and wy then
        return { continent = continent, x = wx, y = wy }
    end
end

local function PlayerWorldPos()
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
    if x and y then
        return WorldPos(mapID, x, y)
    end
end

-- The trainer to pin: the nearest on your continent, else the first listed (the data lists the
-- ones closest to a Night Elf first). Only trainers whose map can be found are considered.
local function ChooseTrainer(trainers)
    local here = PlayerWorldPos()
    local first, best, bestYards
    for _, trainer in ipairs(trainers) do
        local mapID = ResolveMap(trainer)
        if mapID then
            first = first or trainer
            local there = here and WorldPos(mapID, trainer.x, trainer.y)
            if there and there.continent == here.continent then
                local yards = math.sqrt((there.x - here.x) ^ 2 + (there.y - here.y) ^ 2)
                if not bestYards or yards < bestYards then
                    best, bestYards = trainer, yards
                end
            end
        end
    end
    return best or first, bestYards
end

-- Pins the place on your map and screen, the same way the game's own map pin works.
local function Pin(place)
    if not (C_Map and C_Map.SetUserWaypoint and UiMapPoint and UiMapPoint.CreateFromCoordinates) then
        return false
    end
    local mapID = ResolveMap(place)
    if not mapID then
        return false
    end
    if C_Map.CanSetUserWaypointOnMap and not Safe(C_Map.CanSetUserWaypointOnMap(mapID)) then
        return false
    end
    local wasSet = C_Map.SetUserWaypoint(UiMapPoint.CreateFromCoordinates(mapID, place.x, place.y))
    if Safe(wasSet) == false then
        return false
    end
    if C_SuperTrack and C_SuperTrack.SetSuperTrackedUserWaypoint then
        C_SuperTrack.SetSuperTrackedUserWaypoint(true)
    end
    return true
end

----- Pages -------------------------------------------------------------------------------------------

-- The guide whose name starts with what you typed ("alch", "first aid", "LW" won't, "leather" will).
local function FindGuide(text)
    local want = Squash(text)
    if want == "" then
        return nil
    end
    local best
    for line, guide in pairs(Data()) do
        local name = Squash(guide.name)
        if name == want then
            return guide, line
        end
        if name:sub(1, #want) == want and (not best or guide.name < best.guide.name) then
            best = { guide = guide, line = line }
        end
    end
    if best then
        return best.guide, best.line
    end
end

local function ShowMats(rows)
    for _, row in ipairs(rows) do
        local missing = math.max(row.need - row.have, 0)
        local color = missing == 0 and "|cff66dd66" or "|cffffffff"
        local vendor = row.mat.vendor and " |cff999999(vendor)|r" or ""
        if missing == 0 then
            Print(string.format("    %s%s|r %d/%d, ready%s", color, row.mat.name, row.have, row.need, vendor))
        else
            Print(string.format("    %s%s|r %d/%d, need %d more%s", color, row.mat.name, row.have, row.need, missing, vendor))
        end
    end
end

local function ShowProfession(profession)
    Print(string.format("|cffffd100%s|r %d/%d", profession.name, profession.rank, profession.maxRank))
    local guide = profession.guide
    if not guide then
        Print("    No guide for this profession yet.")
        return
    end
    local step, index = CurrentStep(guide, profession.rank)
    if not step then
        Print("    Path complete. Nothing left to level.")
        return
    end
    if step.gather then
        Print(string.format("    Now: gather %s until %d", step.gather, step.to))
        Print("    Where: " .. (step.where or "?"))
    else
        local left = CraftsLeft(step, profession.rank)
        Print(string.format("    Now: craft %s x%d until %d%s", step.craft, left, step.to, LearnText(step)))
        ShowMats(MatsLeft(step, left))
    end
    if step.note then
        Print("    |cff999999" .. step.note .. "|r")
    end
    local nextStep = guide.steps[index + 1]
    if nextStep then
        Print("    |cff999999Next: " .. StepText(nextStep) .. "|r")
    end
end

local function ShowOverview()
    local list = ReadProfessions()
    if #list == 0 then
        Print("You haven't learned a profession yet.")
        Print("Good pairs while leveling: Herbalism + Alchemy, Mining + Engineering or Blacksmithing, Skinning + Leatherworking. Cooking, Fishing and First Aid go with any of them.")
        Print("Type a profession name to see its full guide.")
        return
    end
    for _, profession in ipairs(list) do
        ShowProfession(profession)
    end
    Print("|cff999999Type a profession for its full guide. Or: shopping   Or: trainer alchemy|r")
end

local function ShowGuide(guide, line)
    local rank
    for _, profession in ipairs(ReadProfessions()) do
        if profession.line == line then
            rank = profession.rank
        end
    end
    Print(string.format("|cffffd100%s guide|r%s", guide.name, rank and string.format(" (you: %d)", rank) or ""))
    local current = rank and select(2, CurrentStep(guide, rank))
    for index, step in ipairs(guide.steps or {}) do
        local marker = index == current and "|cff66dd66> |r" or "  "
        Print(marker .. StepText(step) .. LearnText(step))
        if step.mats and #step.mats > 0 then
            local parts = {}
            for _, mat in ipairs(step.mats) do
                parts[#parts + 1] = string.format("%d %s%s", mat.count, mat.name, mat.vendor and " (vendor)" or "")
            end
            Print("    |cff999999each: " .. table.concat(parts, ", ") .. "|r")
        end
        if step.note then
            Print("    |cff999999" .. step.note .. "|r")
        end
    end
    if guide.trainers and #guide.trainers > 0 then
        Print("|cffffd100Trainers|r |cff999999(type: trainer " .. guide.name:lower() .. ")|r")
        for _, trainer in ipairs(guide.trainers) do
            Print(string.format("  %s: %s, %s", trainer.rank, trainer.name, trainer.where))
        end
    end
    if guide.notes and #guide.notes > 0 then
        Print("|cffffd100Notes|r")
        for _, note in ipairs(guide.notes) do
            Print("  " .. note)
        end
    end
end

local function ShowShopping()
    local list = ReadProfessions()
    local totals, order = {}, {}
    for _, profession in ipairs(list) do
        local step = profession.guide and CurrentStep(profession.guide, profession.rank)
        if step and step.mats then
            local crafts = CraftsLeft(step, profession.rank)
            for _, mat in ipairs(step.mats) do
                local entry = totals[mat.itemID]
                if not entry then
                    entry = { mat = mat, need = 0, for_ = {} }
                    totals[mat.itemID] = entry
                    order[#order + 1] = mat.itemID
                end
                entry.need = entry.need + mat.count * crafts
                entry.for_[#entry.for_ + 1] = step.craft
            end
        end
    end
    Print("|cffffd100Shopping list|r |cff999999(current step of each profession, minus bags and bank)|r")
    local any = false
    for _, itemID in ipairs(order) do
        local entry = totals[itemID]
        local missing = entry.need - Owned(itemID)
        if missing > 0 then
            any = true
            Print(string.format("  %d %s%s |cff999999for %s|r", missing, entry.mat.name,
                entry.mat.vendor and " |cffffd100(vendor)|r" or "", table.concat(entry.for_, ", ")))
        end
    end
    if not any then
        if #list == 0 then
            Print("  You haven't learned a profession yet.")
        else
            Print("  Nothing missing for your current steps.")
        end
    end
end

local function PinTrainer(rest)
    -- "alchemy" or "alchemy artisan": the second word narrows to a rank.
    local name, rankWord = rest:match("^(.-)%s+(%a+)$")
    local guide = FindGuide(rest)
    local rankFilter
    if not guide and name then
        guide, rankFilter = FindGuide(name), rankWord:lower()
    end
    if not guide then
        Print("Which profession? For example: trainer alchemy")
        return
    end
    local trainers = {}
    for _, trainer in ipairs(guide.trainers or {}) do
        if not rankFilter or trainer.rank:lower():find(rankFilter, 1, true) then
            trainers[#trainers + 1] = trainer
        end
    end
    if #trainers == 0 then
        Print("No " .. guide.name .. " trainer" .. (rankFilter and (" for '" .. rankFilter .. "'") or "") .. " in the guide.")
        return
    end
    local trainer, yards = ChooseTrainer(trainers)
    trainer = trainer or trainers[1]
    local distance = yards and string.format(", %d yd away", math.floor(yards)) or ""
    if Pin(trainer) then
        Print(string.format("Pinned %s (%s), %s%s.", trainer.name, trainer.rank, trainer.where, distance))
    else
        Print(string.format("%s trainer: %s (%s), %s at %.1f, %.1f. The map pin couldn't be placed here.",
            guide.name, trainer.name, trainer.rank, trainer.where, trainer.x * 100, trainer.y * 100))
    end
end

local function ShowPage(arg)
    local text = tostring(arg or ""):gsub("^%s+", ""):gsub("%s+$", "")
    local lower = text:lower()
    if lower == "" then
        ShowOverview()
    elseif lower == "shopping" or lower == "list" then
        ShowShopping()
    elseif lower == "trainer" or lower:match("^trainer%s") then
        PinTrainer(lower:gsub("^trainer%s*", ""))
    else
        local guide, line = FindGuide(text)
        if guide then
            ShowGuide(guide, line)
        else
            Print("No guide called '" .. text .. "'. Try: alchemy, blacksmithing, cooking, enchanting, engineering, first aid, fishing, herbalism, leatherworking, mining, skinning, tailoring.")
        end
    end
end

SLASH_PROFESSIONGUIDE1 = "/profguide"
SlashCmdList.PROFESSIONGUIDE = ShowPage

ForeverHubStatus = ForeverHubStatus or {}
-- One row, only when you already own the mats for at least one craft of a current step.
ForeverHubStatus.ProfessionGuide = function()
    for _, profession in ipairs(ReadProfessions()) do
        local step = profession.guide and CurrentStep(profession.guide, profession.rank)
        if step and step.craft and step.mats and #step.mats > 0 and profession.rank < profession.maxRank then
            local ready = math.min(CraftsReady(step), CraftsLeft(step, profession.rank))
            if ready > 0 then
                return { { text = string.format("|cff88bbeeCraft|r %s x%d (mats ready)", step.craft, ready), page = "Profession guide" } }
            end
        end
    end
    return nil
end
