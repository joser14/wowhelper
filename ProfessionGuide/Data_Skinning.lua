-- Skinning leveling path for World of Warcraft: Forever (Alliance, Night Elf start).
-- Sources: https://www.wow-professions.com/forever/skinning-leveling-guide
--          https://www.warcrafttavern.com/forever/guides/profession-trainers/ (trainer coords)
-- Skin rule (Classic, same in Forever): mob level 1-10 needs 1 skill; level 11-20 needs (level - 10) x 10;
-- level 21+ needs level x 5. So skill 100 skins level 20, 150 -> 30, 200 -> 40, 250 -> 50, 300 -> 60.
-- Skin mobs near your max level for reliable skill-ups. Zones adapted for a Night Elf; mob names are
-- the usual Classic beasts of each zone (Forever guide only lists Loch Modan/Wetlands/Hillsbrad/Feralas/Un'Goro).
ProfessionGuideData = ProfessionGuideData or {}
ProfessionGuideData[393] = {
    name = "Skinning",
    steps = {
        { from = 1, to = 50, gather = "Beasts level 1-15",
          where = "Teldrassil (Nightsabers, Thistle Boars, Strigid Owls), then Darkshore",
          note = "Needs a Skinning Knife (trade/leatherworking vendors). Starting-zone mobs still give points to 75." },
        { from = 50, to = 100, gather = "Beasts level 13-20",
          where = "Darkshore (Moonstalkers, Thistle Bears, Foreststriders, Threshers)",
          note = "Train Journeyman at 50 (level 10) - not from the Shadowglen trainer. Level 15 = 50, 19 = 90." },
        { from = 100, to = 150, gather = "Beasts level 20-30",
          where = "Ashenvale (Ghostpaw wolves, bears, Shadowhorn Stags), Stonetalon, Wetlands (Mottled raptors)",
          note = "Train Expert at 125 (level 20). Wetlands raptors at Whelgar's Excavation are 25-27." },
        { from = 150, to = 200, gather = "Beasts level 30-40",
          where = "Hillsbrad (Foothill Caverns yetis), Arathi Highlands, Desolace (kodos, scorpids), Stranglethorn Vale",
          note = "Yetis (30-32) respawn fast. Train Artisan at 200 (level 35)." },
        { from = 200, to = 250, gather = "Beasts level 40-50",
          where = "Feralas (Feral Scar Vale yetis, bears), Tanaris (hyenas, basilisks), The Hinterlands (wolves, owlbeasts)",
          note = "Feral Scar yetis (43-46) are close to Feathermoon Stronghold." },
        { from = 250, to = 280, gather = "Beasts level 50-56",
          where = "Un'Goro Crater (diemetradons, pterrordax, stegodons), Felwood (wolves, bears), Burning Steppes (worgs)",
          note = "Un'Goro dinosaurs near Marshal's Refuge give Rugged Leather and Thick Hides." },
        { from = 280, to = 300, gather = "Beasts level 55-60",
          where = "Winterspring (Frostsabers, Shardtooth Bears, Ice Thistle Yetis), Un'Goro Crater",
          note = "Level 56+ beasts are needed past 280. Enchant Gloves - Skinning lets you skin 1 level higher." },
    },
    trainers = {
        { rank = "All ranks", name = "Eladriel", where = "Craftsmen's Terrace, Darnassus",
          zone = "Darnassus", mapID = 1457, x = 0.642, y = 0.217 },
        { rank = "All ranks", name = "Radnaal Maneweaver", where = "Road outside Darnassus, Teldrassil",
          zone = "Teldrassil", mapID = 1438, x = 0.421, y = 0.500 },
        { rank = "Apprentice (to 75)", name = "Terunne Bearshaper", where = "Shadowglen, Teldrassil",
          zone = "Teldrassil", mapID = 1438, x = 0.594, y = 0.387 },
        { rank = "All ranks", name = "Jayla", where = "Silverwind Refuge, Ashenvale",
          zone = "Ashenvale", mapID = 1440, x = 0.501, y = 0.672 },
        { rank = "All ranks", name = "Maris Granger", where = "Old Town, Stormwind",
          zone = "Stormwind City", mapID = 1453, x = 0.723, y = 0.623 },
        { rank = "All ranks", name = "Balthus Stoneflayer", where = "Ironforge",
          zone = "Ironforge", mapID = 1455, x = 0.396, y = 0.328 },
        { rank = "All ranks", name = "Helene Peltskinner", where = "Goldshire, Elwynn Forest",
          zone = "Elwynn Forest", mapID = 1429, x = 0.463, y = 0.622 },
        { rank = "All ranks", name = "Wilma Ranthal", where = "Lakeshire, Redridge Mountains",
          zone = "Redridge Mountains", mapID = 1433, x = 0.836, y = 0.711 },
    },
    notes = {
        "Journeyman: skill 50, level 10. Expert: skill 125, level 20. Artisan: skill 200, level 35.",
        "Starting-zone trainers (Shadowglen) only teach up to 75.",
        "Skill needed: mob level 11-20 = (level - 10) x 10, level 21+ = level x 5.",
        "Skinning pairs well with Leatherworking.",
        "Bonus: Enchant Gloves - Skinning (+5 skill).",
    },
}
