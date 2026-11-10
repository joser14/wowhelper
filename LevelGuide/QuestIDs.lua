-- Forever quest IDs and renamed titles, gathered by research workers from wow4ever.quest
-- (Questie's Forever data) and wowhead.com/forever. Each block keeps its own source list.
local parts = {}

-- ek_1_30.lua
parts[#parts + 1] = (function()
-- Sources: https://wow4ever.quest/api/quest-index/en ; https://wow4ever.quest/en/quests/<slug> (one page per title, Questie Forever data, client 1.60.1.70790) ; https://www.wowhead.com/forever/quest=286 ; https://www.wowhead.com/forever/quest=98189 ; https://www.wowhead.com/forever/quest=98190 ; https://www.wowhead.com/forever/quest=98191
return {
    ids = {
        -- Dun Morogh
        ["The Quarry's Smith"] = { 95217 },
        -- Loch Modan
        -- Wetlands
        -- Duskwood
        ["Look To The Stars"] = { 174, 175, 177, 181 },
        -- Hillsbrad Foothills
    },
    renamed = {
        ["Look To The Stars"] = "Look to the Stars",
    },
}
end)()

-- levels_20_45.lua
parts[#parts + 1] = (function()
-- Sources: https://wow4ever.quest/en/quests/<slug> (one page per title, Questie Forever data) ; https://www.wowhead.com/forever/quest=657 ; https://www.wowhead.com/forever/quest=348 ; https://www.wowhead.com/forever/quest=349
return {
    ids = {
        -- Ashenvale
        ["Bathran's Hair"] = { 1010 },
        ["The Sleeper Has Awakened"] = { 5321 },
        ["Orendil's Cure"] = { 1020 },
        ["Trek to Ashenvale"] = { 990 },
        ["Raene's Cleansing"] = { 991, 1023, 1024, 1026, 1027, 1028, 1055, 1029, 1030, 1045, 1046 },
        ["Culling the Threat"] = { 1054 },
        ["An Aggressive Defense"] = { 1025 },
        ["Elune's Tear"] = { 1033 },
        ["The Ruins of Stardust"] = { 1034 },
        ["Fallen Sky Lake"] = { 1035 },
        ["On Guard in Stonetalon"] = { 1070 },
        ["The Ancient Statuette"] = { 1007 },
        ["Ruuzel"] = { 1009 },
        ["Elemental Bracers"] = { 1016 },
        ["Forsaken Diseases"] = { 1011 },
        ["Insane Druids"] = { 1012 },
        ["The Branch of Cenarius"] = { 1031 },

        -- Arathi Highlands
        ["Crystal in the Mountains"] = { 635 },

        -- Desolace

        -- Stranglethorn Vale
        ["A Meal Served Cold"] = { 212 },
        ["Pearl Diving"] = { 705 },
        ["Stranglethorn Fever"] = { 349 },
    },
    renamed = {},
}
end)()

-- levels_40_60.lua
parts[#parts + 1] = (function()
-- Sources: https://github.com/Ludovicus-Maior/WoW-Pro-Guides/tree/main/WoWPro_Leveling/Forever/Alliance (42_50_Alliance.lua, 50_55_Alliance.lua, 55_60_Alliance.lua), https://wow4ever.quest/en/quests/<slug>, https://www.wowhead.com/forever/quest=<id>
return {
    ids = {
        ["Barov Family Fortune"] = { 5343 },
        ["Dark Iron Legacy"] = { 3801, 3802 },
        ["Hameya's Plea"] = { 6024 },
        ["Invader's Scourgestones"] = { 5403 },
        ["Plagued Hatchlings"] = { 5529 },
        ["The Smoldering Ruins of Thaurissan"] = { 3701, 3702 },
    },
    renamed = {},
}
end)()

-- teldrassil_darkshore.lua
parts[#parts + 1] = (function()
-- Sources: https://wow4ever.quest/en/quests/<slug> (Questie Forever data), https://wow4ever.quest/en/npcs/conservator-ilthalaine,
--          https://www.wowhead.com/forever/quest=921 / 928 / 929 / 933 / 932 / 98403 / 918
-- Keys are the route's titles. Shared titles list IDs in part order.
-- Crown of the Earth part 5 (Oracle Glade, Amethyst Phial) left out: Forever lists both 934 and 7383 for it.
-- "The Great Outdoors" left out: Forever camping quest with several IDs (95998, 96101, 96606, 96608 for Alliance/both).
-- Twisted Hatred: 932 = Lord Melenas (the route's step); 98403 = Forever follow-up of the same name.
-- How Big a Threat?: 984 = find the furbolg camp, 985 = kill Pathfinders/Windtalkers (route only tracks the kill step).
-- Bashal'Aran has 4 parts (route uses 1-3); Tower of Althalaxx has 9 (route uses 1-2).
return {
    ids = {
        -- Teldrassil
        ["The Balance of Nature"] = { 456, 457 },
        ["The Woodland Protector"] = { 458, 459 },
        ["Nature's Call"] = { 97977 },
        ["The Goddess Provides"] = { 97979 },
        ["A Good Friend"] = { 4495 },
        ["Webwood Venom"] = { 916 },
        ["Webwood Egg"] = { 917 },
        ["Tenaron's Summons"] = { 920 },
        ["Crown of the Earth"] = { 921, 928, 929, 933 },
        ["A Friend in Need"] = { 3519 },
        ["Iverron's Antidote"] = { 3521, 3522 },
        ["Fang of Githyiss"] = { 97236 },
        ["Dolanaar Delivery"] = { 2159 },
        ["Zenn's Bidding"] = { 488 },
        ["Seek Redemption!"] = { 489 },
        ["The Lost Runner"] = { 99046 },
        ["Recipe of the Kaldorei"] = { 4161 },
        ["A Troubling Breeze"] = { 475 },
        ["The Relics of Wakening"] = { 483 },
        ["Twisted Hatred"] = { 932, 98403 },
        ["The Emerald Dreamcatcher"] = { 2438 },
        ["Soft Saber Pelts"] = { 87288 },
        ["The Sisterhood of Elune"] = { 98391 },
        ["The Great Tree Provides"] = { 99050 },
        ["Denalan's Earth"] = { 997 },
        ["The Road to Darnassus"] = { 487 },
        ["Gnarlpine Corruption"] = { 476 },
        ["Ferocitas the Dream Eater"] = { 2459 },
        ["Timberling Seed"] = { 918 },
        ["Timberling Sprouts"] = { 919 },
        ["The Sleeping Druid"] = { 2541 },
        ["Ursal the Mauler"] = { 486 },
        ["Not Dead Yet"] = { 99047 },
        ["The Enchanted Glade"] = { 937 },
        ["Darkness in the Glade"] = { 98392 },
        ["The Bounty of Teldrassil"] = { 6341 },
        ["Flight to Auberdine"] = { 6342 },
        -- Darkshore
        ["Buzzbox 827"] = { 983 },
        ["Buzzbox 411"] = { 1001 },
        ["Buzzbox 323"] = { 1002 },
        ["Washed Ashore"] = { 3524, 4681 },
        ["For Love Eternal"] = { 963 },
        ["The Family and the Fishing Pole"] = { 1141 },
        ["Plagued Lands"] = { 2118 },
        ["Cleansing of the Infected"] = { 2138 },
        ["How Big a Threat?"] = { 984, 985 },
        ["Bashal'Aran"] = { 954, 955, 956, 957 },
        ["Tools of the Highborne"] = { 958 },
        ["The Red Crystal"] = { 4811 },
        ["As Water Cascades"] = { 4812 },
        ["Cave Mushrooms"] = { 947 },
        ["Onu"] = { 948 },
        ["Deep Ocean, Vast Sea"] = { 982 },
        ["The Fall of Ameth'Aran"] = { 953 },
        ["The Master's Glaive"] = { 944 },
        ["Mathystra Relics"] = { 951 },
        ["Swelling Forces"] = { 98013 },
    },
    renamed = {
        ["Timberling Seed"] = "Timberling Seeds",
    },
}
end)()

-- zz_v2_ashenvale.lua
parts[#parts + 1] = (function()
-- Quest IDs for routes_v2/ashenvale.lua, one per route part in order.
-- Sources: https://foreverchanges.pro/quests/ashenvale ; https://www.wowhead.com/forever/quest=<id> (series lists) ; wow4ever.quest quest pages
return {
    ids = {
        ["The Sleeper Has Awakened"] = { 5321 },
        ["Bathran's Hair"] = { 1010 },
        ["Orendil's Cure"] = { 1020 },
        ["Trek to Ashenvale"] = { 990 },
        ["Raene's Cleansing"] = { 991, 1023, 1024, 1026, 1027, 1028, 1055, 1029, 1030, 1045, 1046 },
        ["Culling the Threat"] = { 1054 },
        ["Elune's Tear"] = { 1033 },
        ["The Zoram Strand"] = { 1008 },
        ["The Ruins of Stardust"] = { 1034 },
        ["The Ancient Statuette"] = { 1007 },
        ["Ruuzel"] = { 1009 },
        ["Supplies to Auberdine"] = { 976 },
        ["An Aggressive Defense"] = { 1025 },
        ["Kayneth Stillwind"] = { 4581 },
        ["Fallen Sky Lake"] = { 1035 },
        ["The Howling Vale"] = { 1022 },
        ["Vile Satyr! Dryads in Danger!"] = { 1021 },
        ["Elemental Bracers"] = { 1016 },
        ["Mage Summoner"] = { 1017 },
        ["Forsaken Diseases"] = { 1011 },
        ["Vengeful Trail"] = { 98417 },
        ["The Branch of Cenarius"] = { 1031 },
        ["Shared Fury"] = { 98418 },
        ["Insane Druids"] = { 1012 },
        ["Slowing the Orc Advance"] = { 86757 },
        ["Gleaming Crescent Necklace"] = { 98027 },
    },
    renamed = {},
}
end)()

-- zz_v2_darkshore.lua
parts[#parts + 1] = (function()
return { ids = {
    ["Flight to Auberdine"] = { 6342 },
    ["Buzzbox 827"] = { 983 },
    ["Buzzbox 411"] = { 1001 },
    ["Buzzbox 323"] = { 1002 },
    ["Buzzbox 525"] = { 1003 },
    ["Washed Ashore"] = { 3524, 4681 },
    ["The Family and the Fishing Pole"] = { 1141 },
    ["For Love Eternal"] = { 963 },
    ["WANTED: Jai'vhanel"] = { 98025 },
    ["The Red Crystal"] = { 4811 },
    ["As Water Cascades"] = { 4812 },
    ["The Fragments Within"] = { 4813 },
    ["Plagued Lands"] = { 2118 },
    ["Cleansing of the Infected"] = { 2138 },
    ["Tharnariun's Hope"] = { 2139 },
    ["How Big a Threat?"] = { 984, 985 },
    ["Thundris Windweaver"] = { 4761 },
    ["The Cliffspring River"] = { 4762 },
    ["The Blackwood Corrupted"] = { 4763 },
    ["Bashal'Aran"] = { 954, 955, 956, 957 },
    ["Tools of the Highborne"] = { 958 },
    ["Cave Mushrooms"] = { 947 },
    ["Onu"] = { 948 },
    ["The Fall of Ameth'Aran"] = { 953 },
    ["A Lost Master"] = { 986, 993 },
    ["The Tower of Althalaxx"] = { 965, 966, 967, 970, 973, 1140 },   -- Darkshore parts 1-2, Ashenvale parts 3-6
    ["Deep Ocean, Vast Sea"] = { 982 },
    ["Beached Sea Creature"] = { 4723, 4728, 4730, 4733 },
    ["Beached Sea Turtle"] = { 4725, 4727, 4722, 4731, 4732 },
    ["The Absent Minded Prospector"] = { 729, 731 },
    ["WANTED: Murkdeep!"] = { 4740 },
    ["Fruit of the Sea"] = { 1138 },
    ["The Master's Glaive"] = { 944 },
    ["The Twilight Camp"] = { 949 },
    ["Return to Onu"] = { 950 },
    ["It's All Fun and Games Until..."] = { 98042 },
    ["Therylune's Escape"] = { 945 },
    ["Swelling Forces"] = { 98013 },
    ["Mathystra Relics"] = { 951 },
    ["Holy Diver"] = { 87760 },
    ["Gyromast's Retrieval"] = { 2098 },
    ["Gyromast's Revenge"] = { 2078 },
    ["Baron Marinous"] = { 98028 },
    ["Escape Through Stealth"] = { 995 },
    ["Trek to Ashenvale"] = { 990 },
    ["The Sleeper Has Awakened"] = { 5321 },
    ["One Shot. One Kill."] = { 5713 },
}, renamed = {} }
end)()

-- zz_v2_teldrassil.lua
parts[#parts + 1] = (function()
-- Quest IDs for the Forever Teldrassil route, one per route part in part order.
return { ids = {
    ["The Balance of Nature"] = { 456, 457 },
    ["The Woodland Protector"] = { 458, 459 },
    ["Nature's Call"] = { 97977 },
    ["The Goddess Provides"] = { 97979 },
    ["A Good Friend"] = { 4495 },
    ["A Friend in Need"] = { 3519 },
    ["Iverron's Antidote"] = { 3521, 3522 },
    ["Webwood Venom"] = { 916 },
    ["Webwood Egg"] = { 917 },
    ["Fang of Githyiss"] = { 97236 },
    ["Tenaron's Summons"] = { 920 },
    ["Crown of the Earth"] = { 921, 928, 929, 933, 7383, 935, 98046, 98065 },
    ["The Adventurer"] = { 96630 },
    ["Dolanaar Delivery"] = { 2159 },
    ["Zenn's Bidding"] = { 488 },
    ["The Great Outdoors"] = { 96606 },
    ["Camping 101: Cooking"] = { 96634 },
    ["Camping 101: Skinning"] = { 97949 },
    ["A Troubling Breeze"] = { 475 },
    ["Denalan's Earth"] = { 997 },
    ["The Sisterhood of Elune"] = { 98391 },
    ["The Emerald Dreamcatcher"] = { 2438 },
    ["Twisted Hatred"] = { 932, 98403 },
    ["Soft Saber Pelts"] = { 87288 },
    ["The Lost Runner"] = { 99046 },
    ["Recipe of the Kaldorei"] = { 4161 },
    ["Timberling Seeds"] = { 918 },
    ["Timberling Sprouts"] = { 919 },
    ["Rellian Greenspyre"] = { 922 },
    ["Gnarlpine Corruption"] = { 476 },
    ["The Relics of Wakening"] = { 483 },
    ["Seek Redemption!"] = { 489 },
    ["Ferocitas the Dream Eater"] = { 2459 },
    ["The Road to Darnassus"] = { 487 },
    ["The Glowing Fruit"] = { 930 },
    ["Bounty: Gnarlpine Furbolg"] = { 490 },
    ["Tumors"] = { 923 },
    ["The Temple of the Moon"] = { 2519 },
    ["Tears of the Moon"] = { 2518 },
    ["Sathrah's Sacrifice"] = { 2520 },
    ["Not Dead Yet"] = { 99047 },
    ["The Enchanted Glade"] = { 937 },
    ["The Shimmering Frond"] = { 931 },
    ["Mist"] = { 938 },
    ["The Moss-twined Heart"] = { 927 },
    ["Planting the Heart"] = { 941 },
    ["The Sprouted Fronds"] = { 2399 },
    ["The Great Tree Provides"] = { 99050 },
    ["Easing Suffering"] = { 99073 },
    ["Darkness in the Glade"] = { 98392 },
    ["The Oracle Tree"] = { 98398 },
    ["Teldrassil"] = { 940 },
    ["Return to Denalan"] = { 2498 },
    ["Nessa Shadowsong"] = { 6344 },
    ["Oakenscowl"] = { 2499 },
    ["The Sleeping Druid"] = { 2541 },
    ["Druid of the Claw"] = { 2561 },
    ["Escaping Ban'ethil"] = { 99053 },
    ["Ursal the Mauler"] = { 486 },
    ["The Bounty of Teldrassil"] = { 6341 },
    ["Flight to Auberdine"] = { 6342 },
}, renamed = {} }
end)()

-- zz_v3_arathi.lua
parts[#parts + 1] = (function()
-- Quest IDs for routes_v3/arathi.lua, one per route part in order.
-- Sources: https://wow4ever.quest/en/quests/<slug> (Forever ids, givers) ; https://foreverchanges.pro/quests/arathi-highlands and /quest/<id> (chain boxes)
-- "Hints of a New Plague?": Arathi owns the whole 5-part list (part 1 accepted in Hillsbrad, part 5 turned in at Southshore).
-- "Malin's Request": both parts (part 1 accepted in Stormwind and turned in here; part 2 accepted here, turned in at Stormwind).
-- "Sunken Treasure": whole 5-part chain; the route does parts 1-4 here, part 5 (670) is accepted from Fleet Master Seahorn in Booty Bay
-- and turned in to Shakes O'Breen later. "Myzrael's Allies": 653 is the Alliance id (688 is the Horde variant, dropped).
return {
    ids = {
        ["Plea To The Alliance"] = { 634 },
        ["Malin's Request"] = { 690, 697 },                        -- parts 1-2
        ["Northfold Manor"] = { 681 },
        ["WANTED: Marez Cowl"] = { 684 },
        ["WANTED: Otto and Falconcrest"] = { 685 },
        ["Worth Its Weight in Gold"] = { 691 },
        ["Stromgarde Badges"] = { 682 },
        ["The Princess Trapped"] = { 642 },
        ["Stones of Binding"] = { 651 },
        ["Hints of a New Plague?"] = { 659, 657, 658, 660, 661 },  -- parts 1-5
        ["Wand over Fist"] = { 693 },
        ["Trelane's Defenses"] = { 694 },
        ["Breaking the Keystone"] = { 652 },
        ["An Apprentice's Enchantment"] = { 695 },
        ["Attack on the Tower"] = { 696 },
        ["Land Ho!"] = { 663 },
        ["Deep Sea Salvage"] = { 662 },
        ["Drowned Sorrows"] = { 664 },
        ["Sunken Treasure"] = { 665, 666, 668, 669, 670 },         -- parts 1-5 (route does 1-4 here)
        ["Myzrael's Allies"] = { 653 },
    },
    renamed = {},   -- all five "Hints of a New Plague?" quests (657-661) carry that exact title in Forever
}
end)()

-- zz_v3_burningsteppes.lua
parts[#parts + 1] = (function()
-- Quest IDs for routes_v3/burningsteppes.lua, one per route part in order.
-- Sources: https://foreverchanges.pro/quests/burning-steppes ; https://wow4ever.quest/en/quests/<slug> ; https://www.wowhead.com/forever/quest=4182 (series)
-- "The True Masters" lists the whole 6-part chain although the route only accepts part 1 (the chain continues in Lakeshire/Stormwind and ends here at Marshal Maxwell).
-- "Felnok Steelspring" is owned by this zone (accepted here, turned in in Winterspring).
return {
    ids = {
        ["Extinguish the Firegut"] = { 3823 },
        ["FIFTY! YEP!"] = { 4283 },
        ["Dragonkin Menace"] = { 4182 },
        ["Gor'tesh the Brute Lord"] = { 3824 },
        ["Broodling Essence"] = { 4726 },
        ["Tablet of the Seven"] = { 4296 },
        ["Felnok Steelspring"] = { 4808 },
        ["Ogre Head On A Stick = Party"] = { 3825 },
        ["The True Masters"] = { 4183, 4184, 4185, 4186, 4223, 4224 },   -- parts 1-6, route does part 1
    },
    renamed = {},
}
end)()

-- zz_v3_desolace.lua
parts[#parts + 1] = (function()
-- Quest IDs for routes_v3/desolace.lua, one per route part in order.
-- Sources: https://foreverchanges.pro/quests/desolace ; https://wow4ever.quest/en/quests/<slug> ; https://foreverchanges.pro/quest/<id>
-- Alliance variants kept: Centaur Bounty 1387 (1366 is Horde), Carved Centaur Totems 93224 (93225 is Horde), Buying Friendship: Gelkis 93227 (94873 is the Horde/Gurda Wildmane variant).
return {
    ids = {
        ["Reclaimers' Business in Desolace"] = { 1453 },
        ["Reagents for Reclaimers Inc."] = { 1458, 1459, 1466, 1467 },   -- parts 1-4
        ["The Karnitol Shipwreck"] = { 1454, 1455, 1456, 1457 },         -- parts 1-4
        ["Vahlarriel's Search"] = { 1437, 1465, 1438 },                  -- parts 1-3
        ["Vahlarriel's Vengeance"] = { 97284 },
        ["Centaur Bounty"] = { 1387 },
        ["Strange Alliance"] = { 1382 },
        ["Carved Centaur Totems"] = { 93224 },
        ["Search for Tyranis"] = { 1439 },
        ["Return to Vahlarriel"] = { 1440 },
        ["Sceptre of Light"] = { 5741 },
        ["Claim Rackmore's Treasure!"] = { 6161 },
        ["Book of the Ancients"] = { 6027 },
        ["Bone Collector"] = { 5501 },
        ["Bodyguard for Hire"] = { 5821 },
        ["Kodo Roundup"] = { 5561 },
        ["Ghost-o-plasm Round Up"] = { 6134 },
        ["Gizelton Caravan"] = { 5943 },
        ["Buying Friendship: Gelkis"] = { 93227 },
        ["Down the Scarlet Path"] = { 261, 1052 },                       -- parts 1-2
        ["Raid on the Kolkar"] = { 1384 },
        ["Get Me Out of Here!"] = { 6132 },
    },
    renamed = {},
}
end)()

-- zz_v3_dunmorogh.lua
parts[#parts + 1] = (function()
-- Quest IDs for routes_v3/dunmorogh.lua, one per route part in order.
-- Sources: https://wow4ever.quest/en/quests/<slug> (IDs via the Wowhead link), https://foreverchanges.pro/quests/dun-morogh and /quest/<id>
-- "Senir's Observations" lists the whole chain (282 Coldridge leg, 420 turned in here as part 2); the Coldridge Valley route must use part 1 for 282.
-- "Stolen Blasting Powder" 95213/95214 and "Rime's Wrath" 99160/99161 are two separate Alliance quests each (different objectives, both
-- obtained by the player; wowhead forever shows no series), not race variants: both kept as parts 1-2 in route order.
return {
    ids = {
        ["Grund and Gozwin"] = { 97277 },
        ["Senir's Observations"] = { 282, 420 },          -- parts 1-2 (route turns in part 2)
        ["Secure the Mountain"] = { 98322, 98319, 98323 },  -- parts 1-3
        ["Supplies to Tannok"] = { 2160 },
        ["Dawn in the Mountains"] = { 99158 },
        ["Beer Basted Boar Ribs"] = { 384 },
        ["Tools for Steelgrill"] = { 400 },
        ["Flintfire's Shipment"] = { 98321 },
        ["Stocking Jetsteam"] = { 317 },
        ["The Grizzled Den"] = { 313 },
        ["Ammo for Rumbleshot"] = { 5541 },
        ["Frostmane Hold"] = { 287 },
        ["Operation Recombobulation"] = { 412 },
        ["Evershine"] = { 318 },
        ["Finding Warmth"] = { 99159 },
        ["Rime's Wrath"] = { 99160, 99161 },               -- parts 1-2
        ["Treacherous Cold"] = { 99162 },
        ["A Favor for Evershine"] = { 319 },
        ["The Perfect Stout"] = { 315 },
        ["Bitter Rivals"] = { 310 },
        ["Frosthowl"] = { 98326 },
        ["Tundra MacGrann's Stolen Stash"] = { 312 },
        ["Return to Marleth"] = { 311 },
        ["The Reports"] = { 291 },
        ["Return to Bellowfiz"] = { 320 },
        ["Shimmer Stout"] = { 413 },
        ["A Visitor to Dun Morogh"] = { 96408 },
        ["Never Saddle on Quality"] = { 95212 },
        ["Protecting the Herd"] = { 314 },
        ["Those Blasted Troggs!"] = { 432 },
        ["The Public Servant"] = { 433 },
        ["Stolen Blasting Powder"] = { 95213, 95214 },     -- parts 1-2 (part 1 starts from the Empty Powder Keg item)
        ["Farsen's Watch"] = { 96392 },
        ["Nip 'Em in the Bud"] = { 96390 },
        ["Underground Map"] = { 96391 },
        ["The Lost Pilot"] = { 419 },
        ["A Pilot's Revenge"] = { 417 },
        ["Stout to Kadrell"] = { 414 },
    },
    renamed = {},   -- route title -> Forever in-game title, only when they differ (rare)
}
end)()

-- zz_v3_duskwood.lua
parts[#parts + 1] = (function()
-- Quest IDs for routes_v3/duskwood.lua, one per route part in order.
-- Sources: https://foreverchanges.pro/quests/duskwood ; https://wow4ever.quest/en/quests/<slug> ; https://www.wowhead.com/forever/quest=<id>
-- "Messenger to Darkshire": 145 (Magistrate Solomon, Redridge -> Lord Ello) is the one turned in here; 146 (Ello -> Solomon) dropped.
return {
    ids = {
        ["Messenger to Darkshire"] = { 145 },
        ["The Night Watch"] = { 56, 57, 58 },                 -- parts 1-3
        ["The Totem of Infliction"] = { 101 },
        ["The Hermit"] = { 165 },
        ["Deliveries to Sven"] = { 164 },
        ["Raven Hill"] = { 163 },
        ["The Valor Family"] = { 96139 },
        ["Look to the Stars"] = { 174, 175, 177, 181 },      -- parts 1-4
        ["Eight-Legged Menaces"] = { 245 },
        ["Jitters' Growling Gut"] = { 5 },
        ["Supplies from Darkshire"] = { 148 },
        ["Sven's Revenge"] = { 95 },
        ["Wolves at Our Heels"] = { 226 },
        ["Sven's Camp"] = { 230 },
        ["Ghost Hair Thread"] = { 149 },
        ["Dusky Crab Cakes"] = { 93 },
        ["Return the Comb"] = { 154 },
        ["Deliver the Thread"] = { 157 },
        ["The Shadowy Figure"] = { 262 },
        ["Zombie Juice"] = { 158 },
        ["The Shadowy Search Continues"] = { 265 },
        ["Inquire at the Inn"] = { 266 },
        ["Finding the Shadowy Figure"] = { 453 },
        ["Gather Rot Blossoms"] = { 156 },
        ["Return to Jitters"] = { 240 },
        ["Worgen in the Woods"] = { 173, 221, 222, 223 },    -- parts 1-4
        ["Juice Delivery"] = { 159 },
        ["Return to Sven"] = { 268 },
        ["Proving Your Worth"] = { 323 },
        ["Seeking Wisdom"] = { 269 },
        ["Ghoulish Effigy"] = { 133 },
        ["Ogre Thieves"] = { 134 },
        ["The Weathered Grave"] = { 225 },
        ["Note to the Mayor"] = { 160 },
        ["Translate Abercrombie's Note"] = { 251 },
        ["Wait for Sirra to Finish"] = { 401 },
        ["Translation to Ello"] = { 252 },
        ["Bride of the Embalmer"] = { 253 },
        ["The Doomed Fleet"] = { 270 },
        ["Lightforge Iron"] = { 321 },
        ["The Lost Ingots"] = { 324 },
        ["Lightforge Ingots"] = { 526 },
        ["Blessed Arm"] = { 322 },
        ["Armed and Ready"] = { 325 },
        ["Morbent Fel"] = { 55 },
    },
    renamed = {},   -- route title -> Forever in-game title, only when they differ (rare)
}
end)()

-- zz_v3_easternplaguelands.lua
parts[#parts + 1] = (function()
-- Quest IDs for routes_v3/easternplaguelands.lua, one per route part in order.
-- Sources: https://wow4ever.quest/en/quests/<slug> ; https://foreverchanges.pro/quests/eastern-plaguelands ; https://www.wowhead.com/forever/quest=<id>
-- Not defined here (owned by other zones): "Little Pamela" 5142 and "Brother Carlin" 5210 (WPL), "Argent Dawn Commission" (WPL owns { 5401, 5503 }).
return {
    ids = {
        ["Pamela's Doll"] = { 5149 },
        ["Uncle Carlin"] = { 5241 },
        ["Auntie Marlene"] = { 5152 },
        ["Demon Dogs"] = { 5542 },
        ["Blood Tinged Skies"] = { 5543 },
        ["Carrion Grubbage"] = { 5544 },
        ["Augustus' Receipt Book"] = { 6164 },
        ["Defenders of Darrowshire"] = { 5211 },
        ["Villains of Darrowshire"] = { 5181 },
        ["Zaeldarr the Outcast"] = { 6021 },
        ["Minion's Scourgestones"] = { 5510 },   -- Duke Nicholas Zverenhoff (Both) version; 5402 (Pureheart, Alliance, WPL) and 5408 (Horde) dropped
        ["Redemption"] = { 5742 },
        ["Of Forgotten Memories"] = { 5781 },
        ["Of Lost Honor"] = { 5845 },
        ["Of Love and Family"] = { 5846 },
    },
    renamed = {},   -- route title -> Forever in-game title, only when they differ (rare)
}
end)()

-- zz_v3_felwood.lua
parts[#parts + 1] = (function()
-- Quest IDs for routes_v3/felwood.lua, one per route part in order.
-- Sources: https://foreverchanges.pro/quests/felwood ; https://wow4ever.quest/en/quests/<slug> (Wowhead-ID links) ; https://www.wowhead.com/forever/quest=<id>
-- "Timbermaw Ally": Forever has 6131 (New, no giver on wow4ever/foreverchanges) and 8460 (Grazle); only 8460 is kept.
-- "Linken's Memory" (3942) is owned by Un'Goro and only turned in here (not listed).
return {
    ids = {
        ["Cleansing Felwood"] = { 4101 },                    -- Alliance; Horde copy 4102 dropped
        ["Timbermaw Ally"] = { 8460 },
        ["Forces of Jaedenar"] = { 5155 },
        ["Verifying the Corruption"] = { 5156 },             -- Elite
        ["Speak to Nafien"] = { 8462 },
        ["The Corruption of the Jadefire"] = { 4421 },
        ["Collection of the Corrupt Water"] = { 5157 },
        ["Further Corruption"] = { 4906 },
        ["Deadwood of the North"] = { 8461 },
        ["Speak to Salfa"] = { 8465 },                       -- turned in to Salfa, Winterspring
        ["Flute of Xavaric"] = { 939 },
        ["Seeking Spiritual Aid"] = { 5158 },                -- turned in to Islen Waterseer, The Barrens
        ["Felbound Ancients"] = { 4441 },
        ["Silver Heart"] = { 4084 },                         -- Changed (level 54)
        ["Purified!"] = { 4442 },
        ["Cleansed Water Returns to Felwood"] = { 5159 },    -- accepted from Islen Waterseer, The Barrens
        ["Dousing the Flames of Protection"] = { 5165 },
        ["A Strange Red Key"] = { 5202 },
        ["Rescue From Jaedenar"] = { 5203 },
        ["A Final Blow"] = { 5242 },
        ["Retribution of the Light"] = { 5204 },
        ["The Remains of Trey Lightforge"] = { 5385 },
        ["Ancient Spirit"] = { 4261 },                       -- turned in to Kayneth Stillwind, Ashenvale
        ["Aquementas"] = { 4005 },                           -- turned in to J.D. Collie, Un'Goro
    },
    renamed = {},
}
end)()

-- zz_v3_feralas.lua
parts[#parts + 1] = (function()
-- Quest IDs for routes_v3/feralas.lua, one per route part in order.
-- Sources: https://foreverchanges.pro/quests/feralas ; https://wow4ever.quest/en/quests/<slug> ; https://www.wowhead.com/forever/quest=<id> (series)
return {
    ids = {
        ["The Ruins of Solarsal"] = { 2866 },
        ["The Missing Courier"] = { 4124, 4125 },          -- parts 1-2
        ["The High Wilderness"] = { 2982 },
        ["The Mark of Quality"] = { 2821 },                -- Horde variant 2822 dropped
        ["Return to Feathermoon Stronghold"] = { 2867 },
        ["Against the Hatecrest"] = { 3130, 2869 },        -- parts 1-2 (Shandris' report, then naga scales)
        ["Against Lord Shalzaru"] = { 2870 },
        ["Boat Wreckage"] = { 4127 },
        ["The Knife Revealed"] = { 4129 },
        ["Psychometric Reading"] = { 4130 },
        ["The Woodpaw Gnolls"] = { 4131 },
        ["Thalanaar Delivery"] = { 4281 },
        ["The Writhing Deep"] = { 4135 },
        ["Freed from the Hive"] = { 4265 },
        ["Freedom for All Creatures"] = { 2969 },
        ["Doling Justice"] = { 2970, 2972 },               -- parts 1-2 (2972 = follow-up to Darnassus, accepted only)
        ["An Orphan Looking For a Home"] = { 3841 },
        ["A Hero's Welcome"] = { 4266 },
        ["The Sunken Temple"] = { 3445 },                  -- Horde variant 3380 dropped; Tanaris turns in
        ["In Search of Knowledge"] = { 2939 },
        ["Improved Quality"] = { 7733 },                   -- Horde variant 7734 dropped
        ["Delivering the Relic"] = { 2871 },
        ["Zapped Giants"] = { 7003 },
        ["Fuel for the Zapping"] = { 7721 },
        ["The Giant Guardian"] = { 2844 },
        ["Wandering Shay"] = { 2845 },
    },
    renamed = {},
}
end)()

-- zz_v3_hillsbrad.lua
parts[#parts + 1] = (function()
-- Quest IDs for routes_v3/hillsbrad.lua, one per route part in order.
-- Sources: https://wow4ever.quest/en/quests/<slug> ; https://foreverchanges.pro/quests/hillsbrad-foothills and /quests/alterac-mountains ; https://www.wowhead.com/forever/quest=<id>
-- "Hints of a New Plague?" is owned by Arathi ({ 659, 657, 658, 660, 661 }); part 1 is accepted here and not redefined.
-- Variants dropped: Soothing Turtle Bisque 7321 (Horde), Encrypted Letter 3102 (unrelated Elwynn level-1 quest).
return {
    ids = {
        ["Southshore"] = { 538 },
        ["The Shamed Lieutenant"] = { 98219 },
        ["MacKreel's Moonshine"] = { 647 },
        ["Down the Coast"] = { 536 },
        ["Brewer's Trade"] = { 98071 },
        ["Soothing Turtle Bisque"] = { 555 },
        ["Talk of the Town"] = { 98463 },
        ["Syndicate Assassins"] = { 505 },
        ["Hillsbrad's Hoard"] = { 98059 },
        ["Farren's Proof"] = { 559, 560, 561 },   -- parts 1-3
        ["Stormwind Ho!"] = { 562 },
        ["Reassignment"] = { 563 },
        ["An Alarming Request"] = { 92432 },
        ["Costly Menace"] = { 564 },
        ["Bartolo's Yeti Fur Cloak"] = { 565 },
        ["Encrypted Letter"] = { 511 },
        ["Letter to Stormpike"] = { 514 },
        ["Foreboding Plans"] = { 510 },
        ["Noble Deaths"] = { 512 },
    },
    renamed = {},
}
end)()

-- zz_v3_hinterlands.lua
parts[#parts + 1] = (function()
-- Quest IDs for routes_v3/hinterlands.lua, one per route part in order.
-- Sources: https://wow4ever.quest/en/quests/<slug> (Questie Forever ids) ; https://foreverchanges.pro/quests/the-hinterlands ; https://www.wowhead.com/forever/quest=<id>
-- "Cortello's Riddle" keeps the whole 3-part chain (624 Swamp of Sorrows, 625 Dustwallow Marsh, 626 turned in here as part 3); The Hinterlands owns the title.
-- Dropped variant: Troll Necklace Bounty 2881 (repeatable follow-up of 2880, not a separate route part).
return {
    ids = {
        ["To The Hinterlands"] = { 1449 },
        ["Gryphon Master Talonaxe"] = { 1450 },
        ["Rhapsody Shindigger"] = { 1451 },
        ["Rhapsody's Kalimdor Kocktail"] = { 1452 },
        ["Rhapsody's Tale"] = { 1469 },
        ["Witherbark Cages"] = { 2988 },
        ["Troll Necklace Bounty"] = { 2880 },
        ["Skulk Rock Clean-up"] = { 2877 },
        ["The Newest Member of the Family"] = { 3843 },
        ["Food for Baby"] = { 4297 },
        ["Becoming a Parent"] = { 4298 },
        ["Favored of Elune?"] = { 3661 },
        ["Sprinkle's Secret Ingredient"] = { 2641 },
        ["Find OOX-09/HL!"] = { 485 },
        ["Rescue OOX-09/HL!"] = { 836 },
        ["Cortello's Riddle"] = { 624, 625, 626 },   -- parts 1-3, only part 3 turned in here
        ["The Super Snapper FX"] = { 2944 },
        ["Whiskey Slim's Lost Grog"] = { 580 },
        ["The Altar of Zul"] = { 2989 },
        ["Jammal'an the Prophet"] = { 1446 },
        ["Thadius Grimshade"] = { 2990 },
        ["Return to the Hinterlands"] = { 2993 },
        ["Saving Sharpbeak"] = { 2994 },
    },
    renamed = {},
}
end)()

-- zz_v3_lochmodan.lua
parts[#parts + 1] = (function()
-- Quest IDs for routes_v3/lochmodan.lua, one per route part in order.
-- Sources: https://foreverchanges.pro/quests/loch-modan ; https://wow4ever.quest/en/quests/<slug> ; https://www.wowhead.com/forever/quest=250 (A Dark Threat Looms series)
-- "A Dark Threat Looms" lists the whole 7-part chain in chain order; the route does parts 1-3 (part 3 = 161 ends in Wetlands).
-- "Stout to Kadrell" (414) is only turned in here (accepted in Dun Morogh); "Return to Brock" (6392) is accepted in Ironforge during this route's Ironforge leg.
return {
    ids = {
        ["Stout to Kadrell"] = { 414 },
        ["Rat Catching"] = { 416 },
        ["Mountaineer Stormpike's Task"] = { 1339 },
        ["Thelsamar Blood Sausages"] = { 418 },
        ["Honor Students"] = { 6387 },
        ["Ride to Ironforge"] = { 6391 },
        ["Gryth Thurden"] = { 6388 },
        ["Return to Brock"] = { 6392 },
        ["Snowbound"] = { 86667 },
        ["In Defense of the King's Lands"] = { 224, 237, 263, 217 },   -- parts 1-4
        ["The Trogg Threat"] = { 267 },
        ["Filthy Paws"] = { 307 },
        ["Stormpike's Order"] = { 1338 },
        ["Silver of the Waves"] = { 86614 },
        ["Ironband's Excavation"] = { 436 },
        ["Gathering Idols"] = { 297 },
        ["Excavation Progress Report"] = { 298 },
        ["Report to Ironforge"] = { 301 },
        ["Powder to Ironband"] = { 302 },
        ["Resupplying the Excavation"] = { 273 },
        ["Mercenaries"] = { 255 },
        ["Banner of the Fallen"] = { 86585 },
        ["After the Ambush"] = { 454 },
        ["Protecting the Shipment"] = { 309 },
        ["Crocolisk Hunting"] = { 385 },
        ["Twisting the Knife"] = { 86758 },
        ["A Hunter's Boast"] = { 257 },
        ["A Hunter's Challenge"] = { 258 },
        ["Vyrin's Revenge"] = { 271, 531 },   -- parts 1-2
        ["Bingles' Missing Supplies"] = { 2038 },
        ["WANTED: Chok'sul"] = { 256 },
        ["A Dark Threat Looms"] = { 250, 199, 161, 274, 278, 280, 283 },   -- parts 1-7, route does 1-3
        ["Report to Mountaineer Rockgar"] = { 468 },
    },
    renamed = {},
}
end)()

-- zz_v3_silithus.lua
parts[#parts + 1] = (function()
-- Quest IDs for routes_v3/silithus.lua, one per route part in order.
-- Sources: https://foreverchanges.pro/quests/silithus and /quest/<id> ; https://wow4ever.quest/en/quests/<slug> (levels <= 59) ; https://www.wowhead.com/forever/quest=<id>
return {
    ids = {
        ["Report to Marshal Bluewall"] = { 9415 },          -- Alliance version (Horde: 9416 dropped)
        ["Securing the Supply Lines"] = { 8280 },
        ["Deadly Desert Venom"] = { 8277 },
        ["Desert Recipe"] = { 8307 },
        ["The Twilight Mystery"] = { 8284 },
        ["Wasteland"] = { 1124 },                           -- accepted in Moonglade, turned in here only
        ["The Spirits of Southwind"] = { 1125 },
        ["Hive in the Tower"] = { 1126 },
        ["Umber, Archivist"] = { 6844 },                    -- turned in in Moonglade
        ["Stepping Up Security"] = { 8281 },
        ["Noggle's Last Hope"] = { 8278 },
        ["Secret Communication"] = { 8318 },
        ["Sharing the Knowledge"] = { 8313 },
        ["Scouring the Desert"] = { 9419 },                 -- Alliance version (Horde: 9422 dropped)
        ["The Deserter"] = { 8285 },
        ["Noggle's Lost Satchel"] = { 8282 },
        ["Wanted - Deathclasp, Terror of the Sands"] = { 8283 },
        ["The Twilight Lexicon"] = { 8279 },
        ["True Believers"] = { 8323 },
        ["Still Believing"] = { 8324 },
        ["A Terrible Purpose"] = { 8287 },
        ["Twilight Geolords"] = { 8320 },
        ["Vyral the Vile"] = { 8321 },
    },
    renamed = {},
}
end)()

-- zz_v3_stranglethorn.lua
parts[#parts + 1] = (function()
-- Quest IDs for routes_v3/stranglethorn.lua, one per route part in order.
-- Sources: https://wow4ever.quest/en/quests/<slug>, https://foreverchanges.pro/quests/stranglethorn-vale and /quest/<id>.
-- Not defined here (owned by other zones): "Talk of the Town" (Hillsbrad, 98463), "Sunken Treasure" (Arathi, 665/666/668/669/670;
-- this route uses parts 4-5), "Stoley's Debt" (Tanaris, 2872), "Tran'rek" (Tanaris, 2864).
-- "Ansirem's Key" is accepted in Alterac Mountains (no route there); defined here because the chain belongs to Stranglethorn.
return {
    ids = {
        ["Jungle Secrets"] = { 215 },
        ["Bookie Herod"] = { 200 },
        ["The Second Rebellion"] = { 203 },
        ["Bad Medicine"] = { 204 },
        ["The Cook in the Cage"] = { 97047 },
        ["The Hidden Key"] = { 328 },
        ["The Spy Revealed!"] = { 329 },
        ["Patrol Schedules"] = { 330 },
        ["Report to Doren"] = { 331 },
        ["Krazek's Cookery"] = { 210 },
        ["Welcome to the Jungle"] = { 583 },
        ["Tiger Mastery"] = { 185, 186, 187, 188 },     -- parts 1-4
        ["Panther Mastery"] = { 190, 191, 192, 193 },   -- parts 1-4 (193 elite)
        ["Raptor Mastery"] = { 194, 195, 196, 197 },    -- parts 1-4 (197 elite)
        ["The Green Hills of Stranglethorn"] = { 338 },
        ["Chapter I"] = { 339 },
        ["Chapter II"] = { 340 },
        ["Chapter III"] = { 341 },
        ["Chapter IV"] = { 342 },
        ["Favor for Krazek"] = { 627 },
        ["Return to Corporal Kaleb"] = { 622 },
        ["Supplies to Private Thorsen"] = { 198 },
        ["Investigate the Camp"] = { 201 },
        ["The Haunted Isle"] = { 616 },
        ["The Stone of the Tides"] = { 578 },
        ["Supply and Demand"] = { 575 },
        ["Singing Blue Shards"] = { 605 },
        ["Bloodscalp Ears"] = { 189 },
        ["Hostile Takeover"] = { 213 },
        ["Kurzen's Mystery"] = { 207 },
        ["Special Forces"] = { 574 },
        ["Where's the Key?"] = { 97329 },
        ["Zimmix's Great Escape"] = { 97331 },
        ["Troll Witchery"] = { 205 },
        ["Water Elementals"] = { 601 },
        ["Venture Company Mining"] = { 600 },
        ["Some Assembly Required"] = { 577 },
        ["Magical Analysis"] = { 602 },
        ["Ansirem's Key"] = { 603 },
        ["\"Pretty Boy\" Duncan"] = { 610 },
        ["The Curse of the Tides"] = { 611 },
        ["The Bloodsail Buccaneers"] = { 595, 597, 599, 604, 608 },   -- parts 1-5
        ["Scaring Shaky"] = { 606 },
        ["Return to MacKinley"] = { 607 },
        ["Voodoo Dues"] = { 609 },
        ["Skullsplitter Tusks"] = { 209 },
        ["Zanzil's Secret"] = { 621 },
        ["Akiris by the Bundle"] = { 617 },   -- 623 (Alliance follow-up to Theramore) dropped
        ["Keep An Eye Out"] = { 576 },
        ["Up to Snuff"] = { 587 },
        ["Colonel Kurzen"] = { 202 },
        ["Big Game Hunter"] = { 208 },
    },
    renamed = {},
}
end)()

-- zz_v3_tanaris.lua
parts[#parts + 1] = (function()
-- Quest IDs for routes_v3/tanaris.lua, one per route part in order.
-- Sources: https://foreverchanges.pro/quests/tanaris ; https://wow4ever.quest/en/quests/<slug> ; https://www.wowhead.com/forever/quest=<id>
-- "The Sunken Temple" (3445) is owned by Feralas and is not listed here. Variants dropped: Water Pouch Bounty 1878 (repeatable),
-- Rise of the Silithid 32 (Horde) and 4267 (Feralas/Shandris quest with the same title).
return {
    ids = {
        ["Tran'rek"] = { 2864 },
        ["Wastewander Justice"] = { 1690 },
        ["Water Pouch Bounty"] = { 1707 },
        ["WANTED: Caliph Scorpidsting"] = { 2781 },
        ["Gadgetzan Water Survey"] = { 992 },
        ["Noxious Lair Investigation"] = { 82 },
        ["Stoley's Debt"] = { 2872 },
        ["Stoley's Shipment"] = { 2873 },
        ["Deliver to MacKinley"] = { 2874 },
        ["Southsea Shakedown"] = { 8366 },
        ["WANTED: Andre Firebeard"] = { 2875 },
        ["Pirate Hats Ahoy!"] = { 8365 },
        ["Screecher Spirits"] = { 3520 },
        ["Ship Schedules"] = { 2876 },
        ["More Wastewander Justice"] = { 1691 },
        ["The Dunemaul Compound"] = { 5863 },
        ["Thistleshrub Valley"] = { 3362 },
        ["The Thirsty Goblin"] = { 2605 },
        ["Gahz'ridian"] = { 3161 },
        ["Tooga's Quest"] = { 1560 },
        ["In Good Taste"] = { 2606 },
        ["The Scrimshank Redemption"] = { 10 },
        ["Insect Part Analysis"] = { 110, 113 },   -- parts 1-2
        ["Rise of the Silithid"] = { 162 },
        ["Handle With Care"] = { 3022 },
        ["Super Sticky"] = { 4504 },
        ["The Stone Circle"] = { 3444 },
    },
    renamed = {},
}
end)()

-- zz_v3_ungoro.lua
parts[#parts + 1] = (function()
-- Quest IDs for routes_v3/ungoro.lua, one per route part in order.
-- Sources: https://foreverchanges.pro/quests/ungoro-crater ; https://wow4ever.quest/en/quests/<slug> (Questie Forever 1.60.1)
-- "Aquementas" (4005) is owned by Felwood and only turned in here; not listed.
return {
    ids = {
        ["The Apes of Un'Goro"] = { 4289 },
        ["The Fare of Lar'korwi"] = { 4290 },
        ["The Scent of Lar'korwi"] = { 4291 },
        ["The Bait for Lar'korwi"] = { 4292 },
        ["The Mighty U'cha"] = { 4301 },
        ["It's a Secret to Everybody"] = { 3844, 3845, 3908 },   -- parts 1-3 (part 3 turned in in Winterspring)
        ["Williden's Journal"] = { 3884 },
        ["Expedition Salvation"] = { 3881 },
        ["Alien Ecology"] = { 3883 },
        ["Dadanga is Hungry!"] = { 5150 },
        ["Roll the Bones"] = { 3882 },
        ["Beware of Pterrordax"] = { 4501 },
        ["Muigin and Larion"] = { 4141 },
        ["A Visit to Gregan"] = { 4142 },
        ["Shizzle's Flyer"] = { 4503 },
        ["Crystals of Power"] = { 4284 },
        ["The Northern Pylon"] = { 4285 },
        ["The Eastern Pylon"] = { 4287 },
        ["The Western Pylon"] = { 4288 },
        ["Making Sense of It"] = { 4321 },
        ["Chasing A-Me 01"] = { 4243, 4244, 4245 },   -- parts 1-3
        ["Lost!"] = { 4492 },
        ["A Little Help From My Friends"] = { 4491 },
        ["Finding the Source"] = { 974 },
        ["The New Springs"] = { 980 },
        ["Linken's Sword"] = { 3914 },
        ["A Gnome's Assistance"] = { 3941 },
        ["Linken's Memory"] = { 3942 },
        ["Linken's Adventure"] = { 3961 },
        ["It's Dangerous to Go Alone"] = { 3962 },
    },
    renamed = {},
}
end)()

-- zz_v3_westernplaguelands.lua
parts[#parts + 1] = (function()
-- Quest IDs for routes_v3/westernplaguelands.lua, one per route part in order.
-- Sources: https://wow4ever.quest/en/quests/<slug> ; https://foreverchanges.pro/quests/western-plaguelands ; https://www.wowhead.com/forever/quest=<id> (series boxes)
-- "Argent Dawn Commission" holds the whole shared chain (part 1 here, part 2 = 5503 from Duke Nicholas Zverenhoff in EPL).
return {
    ids = {
        -- race/city variants of the entry quest: the player holds exactly one (Stormwind 5066, Ironforge 5090, Darnassus 5091)
        ["A Call to Arms: The Plaguelands!"] = { 5066, 5090, 5091 },
        ["Clear the Way"] = { 5092 },
        ["Argent Dawn Commission"] = { 5401, 5503 },   -- parts 1-2 (part 2 is EPL)
        ["A Plague Upon Thee"] = { 5903, 5904, 6389 },   -- parts 1-3 (chain Dumah -> Termite Barrel -> Dumah)
        ["Little Pamela"] = { 5142 },
        ["All Along the Watchtowers"] = { 5097 },
        ["The Scourge Cauldrons"] = { 5215 },
        ["Target: Felstone Field"] = { 5216 },
        ["Better Late Than Never"] = { 5021, 5022 },   -- parts 1-2
        ["Return to Chillwind Camp"] = { 5217, 5220, 5223, 5226 },   -- parts 1-4
        ["A Matter of Time"] = { 4971 },
        ["Counting Out Time"] = { 4972 },
        ["Target: Dalson's Tears"] = { 5219 },
        ["Mrs. Dalson's Diary"] = { 5058 },
        ["Locked Away"] = { 5059, 5060 },   -- parts 1-2
        ["The Wildlife Suffers Too"] = { 4984, 4985 },   -- parts 1-2
        ["Glyphed Oaken Branch"] = { 4986 },
        ["Target: Writhing Haunt"] = { 5222 },
        ["Scholomance"] = { 5533 },
        ["Skeletal Fragments"] = { 5537 },
        ["A Strange Historian"] = { 5153 },
        ["The Annals of Darrowshire"] = { 5154 },
        ["Brother Carlin"] = { 5210 },
        ["Target: Gahrron's Withering"] = { 5225 },
        ["Mold Rhymes With..."] = { 5538 },
        ["Unfinished Business"] = { 6004, 6023, 6025 },   -- parts 1-3
        ["Mission Accomplished!"] = { 5237 },
    },
    renamed = {},
}
end)()

-- zz_v3_wetlands.lua
parts[#parts + 1] = (function()
-- Quest IDs for routes_v3/wetlands.lua, one per route part in order.
-- Sources: https://foreverchanges.pro/quests/wetlands ; https://foreverchanges.pro/quest/<id> ; https://wow4ever.quest/en/quests/<slug> ; https://www.wowhead.com/forever/quest=<id>
return {
    ids = {
        ["The Greenwarden"] = { 463 },
        ["Digging Through the Ooze"] = { 470 },
        ["Claws from the Deep"] = { 279 },
        ["Spoils of War"] = { 98197 },
        ["Young Crocolisk Skins"] = { 484 },
        ["Alchemical Hazards"] = { 98282 },
        ["Fiora Longears"] = { 1132 },
        ["Apprentice's Duties"] = { 471 },
        ["In Search of The Excavation Team"] = { 305, 306 },   -- parts 1-2 (Tarrel -> Merrin, Merrin -> Tarrel)
        ["Reclaiming Goods"] = { 281 },
        ["The Third Fleet"] = { 288 },
        ["The Cursed Crew"] = { 289 },
        ["The Search Continues"] = { 284 },
        ["Search More Hovels"] = { 285 },
        ["Return the Statuette"] = { 286, 98189 },   -- parts 1-2 (barrel -> Karl Boran, Karl Boran -> Captain Stoutfist)
        ["Report to Captain Stoutfist"] = { 473 },
        ["War Banners"] = { 464 },
        ["From the Ashes"] = { 98221 },
        ["This Land Was Their Land"] = { 98230 },
        ["Ormer's Revenge"] = { 294, 295, 296 },   -- parts 1-3
        ["Uncovering the Past"] = { 299 },
        ["Daily Delivery"] = { 469 },
        ["Trying Times"] = { 98246 },
        ["Tramping Paws"] = { 276 },
        ["Old Habits"] = { 98223 },
        ["Fire Taboo"] = { 277 },
        ["Blisters on the Land"] = { 275 },
        ["Crimson Crate Delivery"] = { 98240 },
        ["Nek'rosh's Gambit"] = { 465 },
        ["Fall of Dun Modr"] = { 472 },
        ["Lifting the Curse"] = { 290 },
        ["The Eye of Paleth"] = { 292 },
        ["Razormaw Needling"] = { 98245 },
        ["Cleansing the Eye"] = { 293 },
        ["A Friend of the Family"] = { 98190 },   -- part 1 only (accepted here, turned in in Stormwind); part 2 = 98191 lives entirely in Stormwind
    },
    renamed = {},
}
end)()

-- zz_v3_winterspring.lua
parts[#parts + 1] = (function()
-- Quest IDs for routes_v3/winterspring.lua, one per route part in order.
-- Sources: https://foreverchanges.pro/quests/winterspring and /quest/<id> ; https://wow4ever.quest/en/quests/<slug> (ids, parts)
-- Not defined here (other owners): Speak to Salfa (Felwood), The New Springs / It's a Secret to Everybody (Un'Goro), Felnok Steelspring (Burning Steppes).
return {
    ids = {
        ["Winterfall Activity"] = { 8464 },
        ["Beads for Salfa"] = { 8469 },
        ["The Videre Elixir"] = { 3909 },        -- part 2 (4041) is Gregan Brewspewer's in Feralas, not accepted in this route
        ["Strange Sources"] = { 4842 },
        ["To Winterspring!"] = { 5249 },         -- accepted from Ivy Leafrunner (Felwood); "Starfall" 5250 (Daryn Lightwind, Rut'theran) is the same step
        ["The Ruins of Kel'Theril"] = { 5244 },
        ["Troubled Spirits of Kel'Theril"] = { 5245 },
        ["Moontouched Wildkin"] = { 978 },
        ["The Everlook Report"] = { 6028 },      -- 6029 is the Horde copy, dropped
        ["Duke Nicholas Zverenhoff"] = { 6030 },
        ["Chillwind Horns"] = { 4809 },
        ["Return to Tinkee"] = { 4810 },
        ["Are We There, Yeti?"] = { 3783, 977, 5163 },   -- parts 1-3
        ["Enraged Wildkin"] = { 6604, 4861, 4863, 4864 }, -- parts 1-4
        ["Sister Pamela"] = { 5601 },
        ["Trouble in Winterspring!"] = { 6603 },
        ["Winterfall Firewater"] = { 5083 },
        ["Threat of the Winterfall"] = { 5082 },
        ["Falling to Corruption"] = { 5084 },
        ["Mystery Goo"] = { 5085 },
        ["Toxic Horrors"] = { 5086 },
        ["Winterfall Runners"] = { 5087 },
        ["High Chief Winterfall"] = { 5121 },
        ["The Final Piece"] = { 5123 },
        ["Words of the High Chief"] = { 5128 },
        ["Find Ranshalla"] = { 979 },
        ["Guardians of the Altar"] = { 4901 },
    },
    renamed = {},
}
end)()

-- night_elf_priest.lua (2026-11): the Teldrassil priest quests and Forever's Eyes of the Sentinels.
-- Sources: https://warcraft.wiki.gg/wiki/In_Favor_of_Elune ; https://warcraft.wiki.gg/wiki/Garments_of_the_Moon ;
-- https://wow4ever.quest/en/quests/returning-home ; https://wow4ever.quest/en/quests/stars-of-elune ;
-- research\rxp_forever_guides.md phase B (Eyes of the Sentinels 98067).
parts[#parts + 1] = {
    ids = {
        ["In Favor of Elune"] = { 5622 },
        ["Garments of the Moon"] = { 5621 },
        ["Returning Home"] = { 5629 },
        ["Stars of Elune"] = { 5627 },
        ["Eyes of the Sentinels"] = { 98067 },
    },
    renamed = {},
}

-- legs_11_20.lua (2026-11): the Night Elf trips (Loch Modan, Redridge) and Darkshore's last leg.
-- Sources: research\rxp_forever_guides.md section 3 (IDs as facts), research\routes_20_60.md 2.2 and 3.5 (V).
parts[#parts + 1] = {
    ids = {
        ["Expanding Horizons"] = { 97914 },
        ["Fishin' Time"] = { 95065 },
        ["The Corruption Abroad"] = { 3765 },
        ["Elune's Grace"] = { 5672 },
        ["Find Bingles"] = { 2039 },
        -- Redridge Mountains
        ["Encroaching Gnolls"] = { 244 },
        ["Assessing the Threat"] = { 246 },
        ["Show of Force"] = { 98407 },
        ["Selling Fish"] = { 127 },
        ["The Lost Tools"] = { 125 },
        ["Redridge Goulash"] = { 92 },
        ["A Free Lunch"] = { 129 },
        ["Visit the Herbalist"] = { 130 },
        ["Delivering Daffodils"] = { 131 },
        ["Hilary's Necklace"] = { 3741 },
        ["Solomon's Law"] = { 91 },
        ["A Baying of Gnolls"] = { 124 },
        ["An Unwelcome Guest"] = { 34 },
        ["The Everstill Bridge"] = { 89 },
        ["Alther's Mill"] = { 98386 },
        ["Murloc Poachers"] = { 150 },
        ["Blackrock Menace"] = { 20 },
        ["Blackrock Blockade"] = { 98387 },
        ["WANTED: Gath'Ilzogg"] = { 169 },
        ["WANTED: Lieutenant Fangore"] = { 180 },
        ["WANTED: Incinerator Gar'im"] = { 95999 },
        ["Blackrock Bounty"] = { 128 },
        ["Tharil'zun"] = { 19 },
        ["Shadow Magic"] = { 115 },
        ["Missing In Action"] = { 219 },
    },
    renamed = {},
}

-- zones_20_60.lua (2026-11): the zones and add-ons from research\routes_20_60.md section 2 (IDs tagged V
-- there). Titles whose parts the research left unclear (Study of the Elements: Rock) have no IDs.
parts[#parts + 1] = {
    ids = {
        -- Stonetalon Mountains
        ["Journey to Stonetalon Peak"] = { 1056 },
        ["Pridewings of Stonetalon"] = { 1134 },
        ["Reclaiming the Charred Vale"] = { 1057, 1059 },
        ["Stonetalon Supply Run"] = { 86574 },
        ["On Guard in Stonetalon"] = { 1070, 1085 },   -- part 1 starts in Ashenvale and ends with Kaela
        ["A Gnome's Respite"] = { 1071 },
        ["Super Reaper 6000"] = { 1093 },
        ["Gerenzo's Orders"] = { 1090, 1092 },
        -- Westfall
        ["The People's Militia"] = { 12, 13, 14 },
        ["Patrolling Westfall"] = { 102 },
        ["The Killing Fields"] = { 9 },
        ["Westfall Stew"] = { 36 },
        ["The Forgotten Heirloom"] = { 64 },
        ["The Coastal Menace"] = { 104 },
        -- Dustwallow Marsh
        ["They Call Him Smiling Jim"] = { 1282 },
        ["James Hyal"] = { 1302 },
        ["Mudrock Soup and Bugs"] = { 1204 },
        ["Suspicious Hoofprints"] = { 1284 },
        ["Lieutenant Paval Reethe"] = { 1252, 1259 },
        ["The Black Shield"] = { 1253, 1319, 1320 },
        ["Hungry!"] = { 1177 },
        ["Soothing Spices"] = { 1218 },
        ["Jarl Needs Eyes"] = { 1206 },
        ["The Orc Report"] = { 1219 },
        ["Captain Vimes"] = { 1220 },
        ["Stinky's Escape"] = { 1222 },
        ["Daelin's Men"] = { 1285 },
        ["The Deserters"] = { 1286, 1287 },
        -- Badlands
        ["Find Agmond"] = { 738 },
        ["Murdaloc"] = { 739 },
        ["Mirages"] = { 718 },
        ["A Dwarf and His Tools"] = { 719 },
        ["Power Stones"] = { 2418 },
        ["Barbecued Buzzard Wings"] = { 703 },
        ["A Sign of Hope"] = { 720, 721 },
        ["Scrounging"] = { 733 },
        ["Tremors of the Earth"] = { 732 },
        -- Swamp of Sorrows
        ["This Light of Mine"] = { 93585 },
        ["My Little Friends"] = { 93176 },
        ["Encroaching Wildlife"] = { 1396 },
        ["Draenethyst Crystals"] = { 1389 },
        ["The Lost Caravan"] = { 1421 },
        ["Galen's Escape"] = { 1393 },
        ["Driftwood"] = { 1398 },
        ["Deliver the Shipment"] = { 1425 },
        -- Searing Gorge
        ["WANTED: Overseer Maltorius"] = { 7701 },
        ["STOLEN: Smithing Tuyere and Lookout's Spyglass"] = { 7728 },
        ["JOB OPPORTUNITY: Culling the Competition"] = { 7729 },
        ["What the Flux?"] = { 7722 },
        ["Curse These Fat Fingers"] = { 7723 },
        ["Fiery Menace!"] = { 7724 },
        ["Incendosaurs? Whateverosaur is More Like It"] = { 7727 },
        ["Caught!"] = { 4449 },
        -- Azshara
        ["Spiritual Unrest"] = { 5535 },
        ["A Land Filled with Hatred"] = { 5536 },
        ["Kim'jael Indeed!"] = { 3601 },
        ["Kim'jael's \"Missing\" Equipment"] = { 5534 },
        ["Cenarion Aid"] = { 8254 },
        ["Of Coursers We Know"] = { 8255 },
        ["The Ichor of Undeath"] = { 8256 },
        -- Thousand Needles
        ["The Brassbolts Brothers"] = { 1179 },
        ["Hardened Shells"] = { 1105 },
        ["Salt Flat Venom"] = { 1104 },
        ["Rocket Car Parts"] = { 1110 },
        ["A Bump in the Road"] = { 1175 },
        ["Load Lightening"] = { 1176 },
        -- Blasted Lands (the first of each buff quest; the repeats are separate quests)
        ["Snickerfang Jowls"] = { 2581 },
        ["A Boar's Vitality"] = { 2583 },
        ["The Decisive Striker"] = { 2585 },
        ["The Basilisk's Bite"] = { 2601 },
        ["Vulture's Vigor"] = { 2603 },
        ["Everything Counts In Large Amounts"] = { 3501 },
        -- Alterac Mountains and Dalaran (Hillsbrad route)
        ["Crushridge Bounty"] = { 500 },
        ["Syndicate Assassins"] = { 505 },
        ["Foreboding Plans"] = { 510 },
        ["Encrypted Letter"] = { 511 },
        ["Crushridge Warmongers"] = { 504 },
        ["Noble Deaths"] = { 512 },
        ["Friend of the Kirin Tor"] = { 92459 },
        -- Add-ons on older routes
        ["Seeking Caitlin"] = { 95737 },
        ["Velinde Starsong"] = { 1037 },
        ["The Carevin Family"] = { 1042 },
        ["Valley of Bones"] = { 93034 },
    },
    renamed = {},
}

-- These chains have more quests in Forever than the route has steps, so counting them would
-- mark route steps done too early. They fall back to turn-ins this addon has seen.
local MISMATCHED = {  }

LevelGuideQuestIDs = { ids = {}, renamed = {} }
for _, part in ipairs(parts) do
    -- Older worker files are a plain title-to-IDs table; newer ones split ids and renamed.
    local ids = part.ids or part
    for title, list in pairs(ids) do
        if type(list) == "table" and not MISMATCHED[title] then
            LevelGuideQuestIDs.ids[title] = list
        end
    end
    for from, to in pairs(part.renamed or {}) do
        LevelGuideQuestIDs.renamed[from] = to
    end
end

-- Quests an Alliance character can turn in that share a route quest's title but aren't the route's (the
-- "dropped" variants above): their turn-ins mustn't count toward that title.
LevelGuideQuestIDs.unrelated = {
    [3102] = true,   -- Encrypted Letter (Elwynn, level 1; the route's is 511 in Hillsbrad)
    [146] = true,    -- Messenger to Darkshire, the way back (the route's is 145)
    [5402] = true,   -- Minion's Scourgestones, Pureheart's copy (the route's is 5510)
    [623] = true,    -- Akiris by the Bundle, the Theramore follow-up (the route's is 617)
    [2881] = true,   -- Troll Necklace Bounty, repeatable
    [1878] = true,   -- Water Pouch Bounty, repeatable
}
