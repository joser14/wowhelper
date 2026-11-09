-- Compare accept step lvl with Prereqs min level.
local base = ADDON_PATH
assert(loadfile(base .. "/QuestIDs.lua"))("LevelGuide", {})
assert(loadfile(base .. "/Prereqs.lua"))("LevelGuide", {})
assert(loadfile(base .. "/Routes.lua"))("LevelGuide", {})
local hist, n, without = {}, 0, 0
local seen = {}
for _, route in ipairs(LevelGuideRoutes.chains.NightElf) do
    local zh = {}
    for _, s in ipairs(route.steps) do
        if s.t == "accept" and not seen[s] then
            seen[s] = true
            local p = LevelGuidePrereqs[s.q]
            if p and p.level then
                local d = s.lvl - p.level
                hist[d] = (hist[d] or 0) + 1
                zh[#zh + 1] = d
                n = n + 1
            else
                without = without + 1
            end
        end
    end
    local sum = 0 for _, d in ipairs(zh) do sum = sum + d end
    print(string.format("%-22s accepts with min level: %3d, mean(step lvl - min lvl) = %.1f", route.zone, #zh, #zh > 0 and sum / #zh or 0))
end
local keys = {}
for d in pairs(hist) do keys[#keys + 1] = d end
table.sort(keys)
for _, d in ipairs(keys) do print("diff " .. d .. ": " .. hist[d]) end
print("with min level " .. n .. ", without " .. without)
