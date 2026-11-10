-- Checks every hand-written LevelGuide route step against QuestDB.lua. Run by tools\check_routes.js
-- (fengari); LG is the LevelGuide folder. Returns one tab-separated line per finding:
--   category, zone, step index, step type, title, part, message, fix (x,y or "")
local LG = LG_PATH
for _, file in ipairs({ "QuestIDs.lua", "Prereqs.lua", "QuestDB.lua", "QuestLookup.lua", "Routes.lua" }) do
    assert(loadfile(LG .. "/" .. file))("LevelGuide", {})
end
local F = LevelGuideQuestFacts
local ids, renamed = LevelGuideQuestIDs.ids, LevelGuideQuestIDs.renamed
local THRESHOLD = 2.0

local out = {}
local function emit(category, route, index, step, message, fix)
    out[#out + 1] = table.concat({ category, route.key or route.zone, tostring(index), step.t, step.q or step.text or "",
        tostring(step.part or 1), message, fix or "" }, "\t")
end

local function Norm(text)
    text = (text or ""):lower():gsub("^the ", ""):gsub("[%p]", ""):gsub("%s+", " ")
    return text
end
local function Trim(text)
    return (text or ""):match("^%s*(.-)%s*$")
end
local function NpcKey(npc)
    return npc and (npc:match("^%s*([^,(]-)%s*[,(]") or npc:match("^%s*(.-)%s*$")) or nil
end

local lowerTitles
local function CaseInsensitive(title)
    if not lowerTitles then
        lowerTitles = {}
        for id, record in pairs(LevelGuideQuestDB.q) do
            local t = record:match("^[^|]*|[^|]*|[^|]*|[^|]*|[^|]*|[^|]*|[^|]*|[^|]*|[^|]*|(.*)$")
            lowerTitles[Norm(t)] = lowerTitles[Norm(t)] or t
        end
    end
    return lowerTitles[Norm(title)]
end

local function StepMap(route, step)
    if step.map then
        return F.MapID(step.map)
    end
    -- As LevelGuide.lua CityToZone: "Name, Darnassus" outside any parentheses means the city's own map.
    local text = (step.npc or step.note or ""):gsub("%b()", "")
    if text:find(", Darnassus", 1, true) then
        return 1457
    end
    return F.MapID(route.zone)
end

local function Names(refs)
    local names = {}
    for _, ref in ipairs(refs) do
        local name = ref.kind == "item" and F.ItemName(ref.id) or (F.Place(ref.kind, ref.id) or {}).name
        if name then
            names[#names + 1] = { name = name, kind = ref.kind, id = ref.id }
        end
    end
    return names
end

-- Nearest DB spot of these refs on mapID (projected), its distance, and how many distinct spots there were.
local function Nearest(refs, mapID, x, y)
    local best, bx, by, count = nil, nil, nil, 0
    for _, ref in ipairs(refs) do
        local place = ref.kind ~= "item" and F.Place(ref.kind, ref.id)
        for _, spot in ipairs(place and place.spots or {}) do
            local px, py = F.Project(spot.map, spot.x, spot.y, mapID)
            if px and px >= -5 and px <= 105 and py >= -5 and py <= 105 then
                count = count + 1
                local d = math.sqrt((px - x) ^ 2 + (py - y) ^ 2)
                if not best or d < best then
                    best, bx, by = d, px, py
                end
            end
        end
    end
    return best, bx, by, count
end

local RACES = { "NightElf", "Dwarf", "Gnome", "Human" }
local seen, stats = {}, { routes = 0, steps = 0, checked = 0 }
for _, race in ipairs(RACES) do
    for _, route in ipairs(LevelGuideRoutes.chains[race] or {}) do
        if not seen[route] and not route.generated then
            seen[route] = true
            stats.routes = stats.routes + 1
            for index, step in ipairs(route.steps) do
                stats.steps = stats.steps + 1
                if step.q and (step.t == "accept" or step.t == "turnin" or step.t == "do") then
                    stats.checked = stats.checked + 1
                    local title, real = step.q, renamed[step.q] or step.q
                    local part = tonumber(step.part) or 1
                    local hand = ids[title] or ids[real]
                    local db = F.IDsForTitle(real, race) or F.IDsForTitle(title, race)
                    if not db then
                        local other = CaseInsensitive(real)
                        if other and other ~= real then
                            emit("title", route, index, step, string.format("not in QuestDB as written; QuestDB has \"%s\"", other))
                        elseif F.IDsForTitle(real) == nil and CaseInsensitive(real) then
                            emit("title", route, index, step, "in QuestDB but not for " .. race)
                        else
                            emit("title", route, index, step, "title not in QuestDB (Alliance/neutral)")
                        end
                    end
                    for position, id in ipairs(hand or {}) do
                        local q = F.Quest(id)
                        if not q then
                            emit("id", route, index, step, string.format("QuestIDs.lua part %d = %d is not an Alliance/neutral quest in QuestDB", position, id))
                        elseif Trim(q.title) ~= Trim(title) and Trim(q.title) ~= Trim(real) then
                            emit("id", route, index, step, string.format("QuestIDs.lua part %d = %d is \"%s\" in QuestDB", position, id, q.title))
                        end
                    end
                    local list = hand or db
                    local id = list and list[part]
                    if list and not id then
                        emit("part", route, index, step, string.format("part %d, but only %d known (%s)", part, #list, table.concat(list, ", ")))
                    end
                    local q = id and F.Quest(id)
                    if q then
                        if step.t == "accept" and step.lvl and q.min and step.lvl < q.min then
                            emit("level", route, index, step, string.format("picked up at level %d, QuestDB minimum level %d (quest %d, level %d)", step.lvl, q.min, id, q.level or 0))
                        elseif step.lvl and q.level and step.t == "accept" and q.level - step.lvl >= 6 then
                            emit("level-info", route, index, step, string.format("picked up at level %d, quest %d is level %d (red)", step.lvl, id, q.level))
                        end
                        if step.t == "accept" or step.t == "turnin" then
                            local refs = step.t == "accept" and q.givers or q.enders
                            local names = Names(refs)
                            local want = Norm(NpcKey(step.npc))
                            local match = false
                            for _, n in ipairs(names) do
                                local have = Norm(n.name)
                                if want ~= "" and (have:find(want, 1, true) or want:find(have, 1, true)) then
                                    match = true
                                end
                            end
                            local list = {}
                            for _, n in ipairs(names) do
                                list[#list + 1] = n.name .. (n.kind ~= "npc" and (" (" .. n.kind .. ")") or "")
                            end
                            -- An item or object giver is often written as a description ("Wanted poster").
                            local described = (step.npc or ""):lower()
                            local loose = described:find("drop", 1, true) or described:find("<", 1, true)
                                or described:find("poster", 1, true) or described:find("item", 1, true)
                                or described:find("object", 1, true)
                            if #names == 0 then
                                emit("npc", route, index, step, string.format("QuestDB has no %s for quest %d", step.t == "accept" and "giver" or "turn-in", id))
                            elseif not match and names[1].kind ~= "item" and not (loose and names[1].kind ~= "npc") then
                                emit("npc", route, index, step, string.format("route says \"%s\", QuestDB (quest %d) says %s", tostring(step.npc), id, table.concat(list, " / ")))
                            end
                            local mapID = StepMap(route, step)
                            if mapID and step.x and step.y then
                                local d, bx, by, count = Nearest(refs, mapID, step.x, step.y)
                                if d and d > THRESHOLD then
                                    local fix = (match and count == 1) and string.format("%.1f,%.1f", bx, by) or ""
                                    emit("coords", route, index, step, string.format("%.1f, %.1f is %.1f map points from QuestDB's %s at %.1f, %.1f%s",
                                        step.x, step.y, d, list[1] or "?", bx, by, count > 1 and string.format(" (nearest of %d spots)", count) or ""), fix)
                                elseif not d and #names > 0 and names[1].kind ~= "item" then
                                    local spotMap = refs[1] and F.Place(refs[1].kind, refs[1].id)
                                    spotMap = spotMap and spotMap.spots[1]
                                    if spotMap then
                                        emit("coords", route, index, step, string.format("QuestDB puts %s on %s (%.1f, %.1f), not on this step's map %s",
                                            list[1], tostring(F.MapName(spotMap.map)), spotMap.x, spotMap.y, tostring(F.MapName(mapID))))
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end
end
table.insert(out, 1, string.format("stats\t%d routes\t%d steps\t%d quest steps checked", stats.routes, stats.steps, stats.checked))
return table.concat(out, "\n")
