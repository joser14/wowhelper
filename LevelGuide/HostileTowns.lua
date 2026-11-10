-- LevelGuide hostile towns (research\re_round3.md rank 17): Horde flight masters with no Alliance flight master
-- within 400 yd, after Shortest Path Forever's hazard rule (by cjber, Journey\Hazards.lua, GPL-3.0-or-later; see
-- NOTICE.md). The positions are the flight-map nodes in Shortest Path Forever's Data\Taxi.lua, which it took from
-- Blizzard's TaxiNodes table (build 1.60.1.70862); only these points are used. World yards: c = continent map,
-- x north, y west (as Travel.lua's frames). The travel planner (TravelPlan.lua) treats a 150 yd circle around each
-- as costly to walk through.
if not LevelGuideTravel then
    return
end
LevelGuideTravel.hostile = {
    { name = "The Sepulcher", c = 0, x = 478.86, y = 1536.59 },
    { name = "Undercity", c = 0, x = 1568.62, y = 267.97 },
    { name = "Tarren Mill", c = 0, x = -0.06, y = -859.91 },
    { name = "Hammerfall", c = 0, x = -916.29, y = -3496.89 },
    { name = "Grom'gol", c = 0, x = -12414.18, y = 146.29 },
    { name = "Kargath", c = 0, x = -6633.99, y = -2180.05 },
    { name = "Thunder Bluff", c = 1, x = -1197.21, y = 29.71 },
    { name = "Orgrimmar", c = 1, x = 1677.59, y = -4315.71 },
    { name = "Crossroads", c = 1, x = -441.8, y = -2596.08 },
    { name = "Sun Rock Retreat", c = 1, x = 966.57, y = 1040.32 },
    { name = "Freewind Post", c = 1, x = -5407.71, y = -2414.3 },
    { name = "Shadowprey Village", c = 1, x = -1767.64, y = 3263.89 },
    { name = "Camp Mojache", c = 1, x = -4419.86, y = 199.31 },
    { name = "Valormok", c = 1, x = 3661.52, y = -4390.38 },
    { name = "Bloodvenom Post", c = 1, x = 5068.4, y = -337.22 },
    { name = "Brackenwall Village", c = 1, x = -3147.39, y = -2842.18 },
    { name = "Stonard", c = 0, x = -10456.97, y = -3279.25 },
    { name = "Zoram'gar Outpost", c = 1, x = 3374.71, y = 996.97 },
    { name = "Splintertree Post", c = 1, x = 2302.39, y = -2524.55 },
    { name = "Flame Crest", c = 0, x = -7504.03, y = -2187.54 },
    { name = "Revantusk Village", c = 0, x = -635.26, y = -4720.5 },
    { name = "Camp Taurajo", c = 1, x = -2380.67, y = -1882.67 },
    { name = "Rog'mar", c = 0, x = -7923.74, y = -4782.96 },
}
