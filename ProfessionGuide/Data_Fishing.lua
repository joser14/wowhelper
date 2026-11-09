-- Fishing leveling path for World of Warcraft: Forever (Alliance, Night Elf start).
-- Sources: https://www.wow-professions.com/forever/fishing-leveling-guide (route, book, Artisan quest, lures)
--          https://www.wow-professions.com/forever/npc/<name> (Old Man Heming, Nat Pagle, Nessa coords)
--          https://www.warcrafttavern.com/forever/guides/profession-trainers/ (trainer coords)
--          Item IDs checked on https://classicdb.ch/?item=<id> (wowhead blocked automated reads).
-- Skill-ups do not depend on the zone; a zone only decides whether fish get away. Zone values are the
-- Classic ones (no Forever list found): Teldrassil/Elwynn/Dun Morogh -70, Darkshore/Loch Modan/Westfall -20,
-- Ashenvale/Wetlands/Redridge/Duskwood 55, Arathi/Desolace/Dustwallow/inland Stranglethorn 130,
-- Feralas/Tanaris/Hinterlands/Azshara/Felwood/Un'Goro/W. Plaguelands 205. No getaways at zone value + 95
-- (fishing skill including lure). Zone ranges past 150 follow the guide's zone list (beta was capped low).
ProfessionGuideData = ProfessionGuideData or {}
ProfessionGuideData[356] = {
    name = "Fishing",
    steps = {
        { from = 1, to = 75, gather = "Any fish (Brilliant Smallfish, Slitherskin Mackerel)",
          where = "Teldrassil (Rut'theran pier, Lake Al'Ameth), Darnassus pools, Darkshore coast, Elwynn, Dun Morogh",
          note = "Buy a Fishing Pole and Shiny Baubles (+25). Train Journeyman at 50 (level 10)." },
        { from = 75, to = 150, gather = "Longjaw Mud Snapper, Rainbow Fin Albacore, Bristle Whisker Catfish",
          where = "Ashenvale lakes, Wetlands (Menethil), Darkshore, Stormwind canals, Redridge, Duskwood",
          note = "Use Nightcrawlers (+50). At 125 (level 20) buy the Expert book from Old Man Heming, Booty Bay." },
        { from = 150, to = 225, gather = "Mithril Head Trout, Rockscale Cod and others",
          where = "Dustwallow Marsh (Theramore), Arathi Highlands, Desolace, Stranglethorn (inland), Thousand Needles",
          note = "Use Bright Baubles (+75). At 225 (level 35) do Nat Pagle's quest before passing 225." },
        { from = 225, to = 260, gather = "Raw Redgill, Spotted Yellowtail and others",
          where = "Feralas (Feathermoon coast), Tanaris coast, The Hinterlands, Stranglethorn coast",
          note = "Needs Artisan. Bright Baubles stop fish escaping in these zones." },
        { from = 260, to = 300, gather = "Raw Sunscale Salmon, Nightfin Snapper and others",
          where = "Feralas, Tanaris, The Hinterlands, Un'Goro Crater, Felwood, Western Plaguelands",
          note = "Skill-ups slow down: several catches per point near 300. Keep a lure on." },
    },
    trainers = {
        { rank = "Apprentice-Journeyman", name = "Astaia", where = "Temple Gardens, Darnassus",
          zone = "Darnassus", mapID = 1457, x = 0.475, y = 0.565 },
        { rank = "Apprentice-Journeyman", name = "Androl Oakhand", where = "Rut'theran Village, Teldrassil",
          zone = "Teldrassil", mapID = 1438, x = 0.558, y = 0.935 },
        { rank = "Fishing supplies: pole, lures", name = "Nessa Shadowsong", where = "Rut'theran Village, Teldrassil",
          zone = "Teldrassil", mapID = 1438, x = 0.562, y = 0.924 },
        { rank = "Apprentice-Journeyman", name = "Arnold Leland", where = "Trade District canals, Stormwind",
          zone = "Stormwind City", mapID = 1453, x = 0.551, y = 0.696 },
        { rank = "Apprentice-Journeyman", name = "Grimnur Stonebrand", where = "The Forlorn Cavern, Ironforge",
          zone = "Ironforge", mapID = 1455, x = 0.485, y = 0.062 },
        { rank = "Apprentice-Journeyman", name = "Harold Riggs", where = "Menethil Harbor, Wetlands",
          zone = "Wetlands", mapID = 1437, x = 0.082, y = 0.583 },
        { rank = "Apprentice-Journeyman", name = "Brannock", where = "Feathermoon Stronghold, Feralas",
          zone = "Feralas", mapID = 1444, x = 0.322, y = 0.414 },
        { rank = "Expert (book) + Bright Baubles", name = "Old Man Heming", where = "Booty Bay, Stranglethorn Vale",
          zone = "Stranglethorn Vale", mapID = 1434, x = 0.275, y = 0.771 },
        { rank = "Artisan (quest: Nat Pagle, Angler Extreme)", name = "Nat Pagle", where = "Tidefury Cove, Dustwallow Marsh",
          zone = "Dustwallow Marsh", mapID = 1445, x = 0.585, y = 0.599 },
    },
    notes = {
        "Apprentice: no level needed. Journeyman: skill 50, level 10, any trainer.",
        "Expert: Expert Fishing - The Bass and You (Old Man Heming, Booty Bay or AH), skill 125, level 20.",
        "Artisan: quest Nat Pagle, Angler Extreme, skill 225, level 35.",
        "Quest fish: Feralas Ahi (Feralas), Sar'theris Striker (Desolace),",
        "Savage Coast Blue Sailfin (Stranglethorn), Misty Reed Mahi Mahi (Swamp of Sorrows).",
        "Lures: Shiny Bauble +25, Nightcrawlers +50, Bright Baubles +75, Aquadynamic Fish Attractor +100.",
        "Cook what you catch: the Cooking route uses the same fish.",
    },
}
