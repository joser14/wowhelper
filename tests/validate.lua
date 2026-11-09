-- Checks one route file written by a research worker. ADDON_PATH is the file.
function A(q, npc, x, y, lvl, part) return { t = "accept", q = q, npc = npc, x = x, y = y, lvl = lvl, part = part } end
function D(q, note, x, y, lvl, part) return { t = "do", q = q, note = note, x = x, y = y, lvl = lvl, part = part } end
function T(q, npc, x, y, lvl, part) return { t = "turnin", q = q, npc = npc, x = x, y = y, lvl = lvl, part = part } end
function G(text, x, y, lvl, note) return { t = "go", text = text, x = x, y = y, lvl = lvl, note = note } end
local chunk, err = loadfile(ADDON_PATH)
assert(chunk, "syntax: " .. tostring(err))
local route = chunk()
assert(type(route) == "table" and type(route.zone) == "string" and route.min and route.max and type(route.steps) == "table", "shape")
local problems, accepts, turnins = {}, {}, {}
for index, s in ipairs(route.steps) do
    local where = "#" .. index .. " " .. tostring(s.q or s.text)
    if not ((s.q or s.text) and type(s.x) == "number" and type(s.y) == "number" and type(s.lvl) == "number") then
        problems[#problems + 1] = where .. ": missing field"
    elseif s.x <= 0 or s.x >= 100 or s.y <= 0 or s.y >= 100 then
        problems[#problems + 1] = where .. ": coordinates out of range"
    end
    if (s.t == "accept" or s.t == "turnin") and type(s.npc) ~= "string" then
        problems[#problems + 1] = where .. ": no NPC"
    end
    if s.lvl and (s.lvl < route.min - 2 or s.lvl > route.max + 2) then
        problems[#problems + 1] = where .. ": level " .. s.lvl .. " outside " .. route.min .. "-" .. route.max
    end
    local key = tostring(s.q) .. "#" .. tostring(s.part or 1)
    if s.t == "accept" then accepts[key] = index end
    if s.t == "turnin" then
        turnins[key] = index
        if accepts[key] and accepts[key] > index then problems[#problems + 1] = where .. ": turned in before accepted" end
    end
end
local orphan = 0
for key in pairs(turnins) do if not accepts[key] then orphan = orphan + 1 end end
print(string.format("%s: %d steps, levels %d-%d, %d problem(s), %d turn-in(s) with no pick-up in this file",
    route.zone, #route.steps, route.min, route.max, #problems, orphan))
for _, p in ipairs(problems) do print("  " .. p) end
