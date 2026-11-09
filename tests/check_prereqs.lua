assert(loadfile(ADDON_PATH))()
local n, bad = 0, 0
for title, need in pairs(LevelGuidePrereqs) do
    n = n + 1
    for _, key in ipairs({ "all", "any" }) do
        for _, id in ipairs(need[key] or {}) do if type(id) ~= "number" then bad = bad + 1 end end
    end
    if need.level ~= nil and type(need.level) ~= "number" then bad = bad + 1 end
end
print(n .. " titles with prerequisites, " .. bad .. " malformed values")
