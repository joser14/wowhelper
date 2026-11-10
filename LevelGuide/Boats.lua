-- LevelGuide boat and zeppelin timetable (research\re_round3.md rank 5).
-- The periods and the arrive/depart times at each stop (seconds into the ship's loop) are from Shortest Path Forever
-- by cjber (Data\Routes.lua, GPL-3.0-or-later; https://github.com/cjber/shortest-path-forever, NOTICE.md), which built
-- them from Blizzard's TaxiPathNode table (build 1.60.1.70862) and the CMaNGOS mangos-classic transport model
-- (GPL-3.0) at 30 yd/s with 1 yd/s^2, stretched onto CMaNGOS classic-db's measured periods. Only these numbers
-- are used; when a ship leaves is learned from your own boardings (TravelPlan.lua P.BoatLearn), never shared.
--
--   routes[ship] = { period, stops = { [stop] = { arrive, depart } } }   (a depart below its arrive spans the loop's start)
--   links[Travel.lua link id] = { route = ship, a = stop at the link's a end, b = stop at its b end }
LevelGuideBoats = {
    routes = {
        [241] = { period = 350.818, stops = { ratchet = { 66.861, 126.887 }, bootybay = { 233.741, 293.768 } } },
        [292] = { period = 329.313, stops = { menethilSouth = { 54.297, 114.325 }, theramore = { 217.967, 277.995 } } },
        [293] = { period = 316.251, stops = { ruttheran = { 42.039, 102.080 }, auberdineNorth = { 206.368, 266.410 } } },
        [295] = { period = 295.579, stops = { menethilNorth = { 43.526, 103.544 }, auberdineSouth = { 199.629, 259.647 } } },
        [303] = { period = 317.038, stops = { feathermoon = { 287.026, 30.012 }, forgottenCoast = { 90.127, 150.150 } } },
        [11167] = { period = 486.183, stops = { menethilNorth = { 43.533, 103.560 }, southshore = { 245.612, 305.639 },
            auberdineSouth = { 390.219, 450.246 } } },
        [11391] = { period = 271.107, stops = { tanaris = { 37.915, 97.942 }, riverglades = { 174.425, 234.452 } } },
        [11398] = { period = 358.693, stops = { dalaran = { 85.107, 145.134 }, zephras = { 252.651, 312.678 } } },
        [11616] = { period = 247.096, stops = { auberdine = { 34.804, 94.831 }, stormwind = { 162.089, 222.116 } } },
    },
    links = {
        ["boat-auberdine-stormwind"] = { route = 11616, a = "auberdine", b = "stormwind" },
        ["boat-auberdine-ruttheran"] = { route = 293, a = "auberdineNorth", b = "ruttheran" },
        ["boat-menethil-theramore"] = { route = 292, a = "menethilSouth", b = "theramore" },
        ["boat-menethil-auberdine"] = { route = 295, a = "menethilNorth", b = "auberdineSouth" },
        ["boat-southshore-menethil"] = { route = 11167, a = "southshore", b = "menethilNorth" },
        ["boat-southshore-auberdine"] = { route = 11167, a = "southshore", b = "auberdineSouth" },
        ["boat-bootybay-ratchet"] = { route = 241, a = "bootybay", b = "ratchet" },
        ["boat-tanaris-riverglades"] = { route = 11391, a = "tanaris", b = "riverglades" },
        ["boat-feathermoon"] = { route = 303, a = "forgottenCoast", b = "feathermoon" },
        ["zeppelin-zephras-dalaran"] = { route = 11398, a = "zephras", b = "dalaran" },
    },
}
