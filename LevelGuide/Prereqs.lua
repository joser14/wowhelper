-- Quest prerequisites gathered by research workers from wow4ever.quest (Questie's Forever
-- data) and wowhead.com/forever. Each block keeps its own source list.
local parts = {}

-- ek_1_30.lua
parts[#parts + 1] = (function()
-- Sources: https://wow4ever.quest/en/quests/<slug> (one page per pick-up title; "First you need" line and "Minimum level", Questie Forever data) ; https://www.wowhead.com/forever/quest=273 ; https://www.wowhead.com/forever/quest=287 ; https://www.wowhead.com/forever/quest=512 ; https://www.wowhead.com/forever/quest=526
return {
    -- Dun Morogh
    ["The Quarry's Smith"] = { level = 7 },

    -- Loch Modan

    -- Wetlands

    -- Duskwood
    ["Look To The Stars"] = { level = 20 },

    -- Hillsbrad Foothills
}
end)()

-- levels_20_45.lua
parts[#parts + 1] = (function()
-- Sources: https://wow4ever.quest/en/quests/<slug> (one page per title, Questie Forever data: "First you need" lines and minimum level) ; https://www.wowhead.com/forever/quest=970 ; https://www.wowhead.com/forever/quest=657 ; https://www.wowhead.com/forever/quest=658 ; https://www.wowhead.com/forever/quest=642 ; https://www.wowhead.com/forever/quest=574 ; https://www.wowhead.com/forever/quest=207 ; https://www.wowhead.com/forever/quest=208
-- level = minimum character level from wow4ever.quest. For multi-part titles the entry is for the first part the route picks up.
return {
    -- Ashenvale
    ["The Tower of Althalaxx"] = { all = { 967 }, level = 13 },        -- route picks up part 970; wowhead series: 965, 966, 967, 970
    ["Bathran's Hair"] = { level = 20 },
    ["Orendil's Cure"] = { all = { 1010 }, level = 20 },
    ["Raene's Cleansing"] = { level = 18 },
    ["Culling the Threat"] = { level = 18 },
    ["An Aggressive Defense"] = { all = { 991 }, level = 18 },          -- source names "Raene's Cleansing" without a part; 991 is part 1
    ["Elune's Tear"] = { all = { 1020 }, level = 20 },
    ["The Ruins of Stardust"] = { all = { 1033 }, level = 20 },
    ["Fallen Sky Lake"] = { all = { 1034 }, level = 20 },
    ["On Guard in Stonetalon"] = { level = 17 },
    ["The Ancient Statuette"] = { level = 19 },
    ["Ruuzel"] = { all = { 1007 }, level = 20 },
    ["Elemental Bracers"] = { level = 20 },
    ["Forsaken Diseases"] = { all = { 4581 }, level = 24 },             -- "Kayneth Stillwind" (from Shindrell Swiftfire, Astranaar)
    ["Insane Druids"] = { all = { 1011 }, level = 24 },
    ["The Branch of Cenarius"] = { all = { 1021 }, level = 26 },        -- "Vile Satyr! Dryads in Danger!" (from Illiyana)

    -- Arathi Highlands
    ["Crystal in the Mountains"] = { level = 30 },

    -- Desolace

    -- Stranglethorn Vale
    ["Stranglethorn Fever"] = { level = 32 },                           -- part 1 (349)
}
end)()

-- levels_40_60.lua
parts[#parts + 1] = (function()
-- Sources: https://wow4ever.quest/en/quests/<slug> (Questie Forever data: "First you need" and "Minimum level" per quest) ; https://www.wowhead.com/forever/quest=4127 ; https://www.wowhead.com/forever/quest=2870 ; https://www.wowhead.com/forever/quest=2869 ; https://www.wowhead.com/forever/quest=3909 ; https://www.wowhead.com/forever/quest=4986 ; https://www.wowhead.com/forever/quest=5149 ; https://www.wowhead.com/forever/quest=9419 ; https://www.wowhead.com/forever/quest=8279 ; https://www.wowhead.com/forever/quest=8287
-- Prerequisite title -> ID mapping via QuestIDs.lua; multi-ID prerequisites resolved from wowhead series where stated.
-- For multi-part titles, the entry describes the first part's requirements.
return {
    -- Tanaris

    -- Feralas

    -- The Hinterlands

    -- Un'Goro Crater

    -- Felwood

    -- Burning Steppes
    ["Dark Iron Legacy"] = { level = 48 },

    -- Western Plaguelands

    -- Eastern Plaguelands
    ["Invader's Scourgestones"] = { level = 50 },
    ["Plagued Hatchlings"] = { level = 55 },

    -- Winterspring

    -- Silithus
}
end)()

-- teldrassil_darkshore.lua
parts[#parts + 1] = (function()
-- Sources: https://wow4ever.quest/en/quests/<slug> (one page per title, Questie Forever data: "First you need" and "Minimum level") ; https://www.wowhead.com/forever/quest=920 ; https://www.wowhead.com/forever/quest=921 (series: 920 -> 921) ; https://www.wowhead.com/forever/quest=459 ; https://www.wowhead.com/forever/quest=916
-- Titles shared by several chain parts ("Crown of the Earth", "Washed Ashore", "Bashal'Aran", "The Tower of Althalaxx")
-- carry the requirement of the FIRST part the route picks up. Later parts need the previous part, which the route already orders.
return {
    -- Teldrassil
    ["A Good Friend"] = { level = 2 },
    ["Webwood Venom"] = { level = 3 },
    ["Webwood Egg"] = { all = { 916 } },
    ["Tenaron's Summons"] = { all = { 917 } },
    ["Crown of the Earth"] = { all = { 920 } },               -- part 1 (921); wowhead series only
    ["A Friend in Need"] = { all = { 4495 }, level = 2 },
    ["Zenn's Bidding"] = { level = 4 },
    ["Seek Redemption!"] = { all = { 488 }, level = 4 },
    ["The Lost Runner"] = { level = 4 },
    ["The Great Outdoors"] = { level = 4 },
    ["A Troubling Breeze"] = { level = 4 },
    ["The Relics of Wakening"] = { all = { 476 }, level = 4 },
    ["Twisted Hatred"] = { level = 4 },
    ["Soft Saber Pelts"] = { level = 4 },
    ["The Sisterhood of Elune"] = { level = 5 },
    ["The Great Tree Provides"] = { level = 4 },
    ["Denalan's Earth"] = { level = 4 },
    ["The Road to Darnassus"] = { level = 5 },
    ["Gnarlpine Corruption"] = { all = { 475 }, level = 4 },
    ["Ferocitas the Dream Eater"] = { all = { 2438 } },
    ["Timberling Seed"] = { all = { 997 }, level = 4 },
    ["Timberling Sprouts"] = { level = 4 },
    ["Not Dead Yet"] = { level = 4 },
    ["The Enchanted Glade"] = { level = 6 },
    ["Darkness in the Glade"] = { level = 6 },
    ["The Bounty of Teldrassil"] = { all = { 6344 }, level = 10 }, -- 6344 "Nessa Shadowsong", from Mydrannul in Darnassus
    ["Flight to Auberdine"] = { all = { 6341 }, level = 10 },

    -- Darkshore
    ["Buzzbox 827"] = { level = 7 },
    ["Washed Ashore"] = { level = 11 },
    ["For Love Eternal"] = { level = 11 },
    ["The Family and the Fishing Pole"] = { level = 10 },
    ["Plagued Lands"] = { level = 10 },
    ["How Big a Threat?"] = { level = 10 },
    ["Bashal'Aran"] = { level = 7 },
    ["Tools of the Highborne"] = { level = 9 },
    ["The Red Crystal"] = { level = 12 },
    ["As Water Cascades"] = { all = { 4811 }, level = 12 },
    ["Cave Mushrooms"] = { level = 12 },
    ["Onu"] = { all = { 947 }, level = 12 },
    ["The Tower of Althalaxx"] = { level = 13 },
    ["Deep Ocean, Vast Sea"] = { level = 13 },
    ["Cleansing of the Infected"] = { all = { 2118 }, level = 10 },
    ["The Fall of Ameth'Aran"] = { level = 9 },
    ["The Master's Glaive"] = { all = { 948 }, level = 12 },
    ["Mathystra Relics"] = { all = { 950 }, level = 12 },        -- 950 "Return to Onu" (needs The Twilight Camp)
    ["Swelling Forces"] = { level = 12 },
}
end)()

-- zz_v3_arathi.lua
parts[#parts + 1] = (function()
-- Prerequisites for routes_v3/arathi.lua from wow4ever.quest "First you need" / "Minimum level".
-- Sources: https://wow4ever.quest/en/quests/<slug> ; https://foreverchanges.pro/quest/<id>
return {
    ["Northfold Manor"] = { level = 30 },
    ["Wanted! Marez Cowl"] = { level = 30 },
    ["Wanted! Otto and Falconcrest"] = { level = 30 },
    ["Worth Its Weight in Gold"] = { all = { 690 }, level = 30 },       -- Malin's Request part 1 (turned in here first)
    ["Stromgarde Badges"] = { all = { 681 }, level = 30 },              -- Northfold Manor
    ["The Princess Trapped"] = { level = 30 },                          -- wow4ever lists no required quest (Crystal in the Mountains is optional)
    ["Stones of Binding"] = { all = { 642 }, level = 30 },              -- The Princess Trapped
    ["Hints of a New Plague?"] = { level = 30 },                        -- part 1 (659) is accepted in Hillsbrad; parts gate each other
    ["Wand over Fist"] = { all = { 691 }, level = 30 },                 -- Worth Its Weight in Gold
    ["Trelane's Defenses"] = { all = { 693 }, level = 30 },             -- Wand over Fist
    ["Breaking the Keystone"] = { all = { 651 }, level = 30 },          -- Stones of Binding
    ["An Apprentice's Enchantment"] = { all = { 694 }, level = 30 },    -- Trelane's Defenses
    ["Attack on the Tower"] = { all = { 695 }, level = 30 },            -- An Apprentice's Enchantment
    ["Land Ho!"] = { level = 35 },
    ["Deep Sea Salvage"] = { all = { 663 }, level = 35 },               -- Land Ho!
    ["Drowned Sorrows"] = { level = 35 },
    ["Sunken Treasure"] = { level = 35 },
    ["Myzrael's Allies"] = { all = { 652 }, level = 30 },               -- Breaking the Keystone
    ["Malin's Request"] = { level = 30 },                               -- part 1 (690) has no required quest; part 2 (697) needs 696, which the route turns in just before
}
end)()

-- zz_v3_burningsteppes.lua
parts[#parts + 1] = (function()
-- Prerequisites for routes_v3/burningsteppes.lua from wow4ever.quest "First you need" / "Minimum level".
-- Sources: https://wow4ever.quest/en/quests/extinguish-the-firegut, fifty-yep, dragonkin-menace, gortesh-the-brute-lord, broodling-essence,
-- tablet-of-the-seven, felnok-steelspring, ogre-head-on-a-stick-party, the-true-masters
return {
    ["Extinguish the Firegut"] = { level = 48 },
    ["FIFTY! YEP!"] = { level = 50 },
    ["Dragonkin Menace"] = { level = 48 },
    ["Gor'tesh the Brute Lord"] = { all = { 3823 }, level = 48 },      -- Extinguish the Firegut
    ["Broodling Essence"] = { level = 50 },
    ["Tablet of the Seven"] = { level = 50 },
    ["Felnok Steelspring"] = { all = { 4726 }, level = 50 },           -- Broodling Essence
    ["Ogre Head On A Stick = Party"] = { all = { 3824 }, level = 48 }, -- Gor'tesh the Brute Lord
    ["The True Masters"] = { all = { 4182 }, level = 48 },             -- Dragonkin Menace (part 1)
}
end)()

-- zz_v3_desolace.lua
parts[#parts + 1] = (function()
-- Prerequisites for routes_v3/desolace.lua from wow4ever.quest "First you need" / "Minimum level" (New quests: foreverchanges.pro/quest/<id>).
-- Sources: https://wow4ever.quest/en/quests/<slug> ; https://foreverchanges.pro/quest/<id>
return {
    ["Reagents for Reclaimers Inc."] = { all = { 1453 }, level = 30 },   -- Reclaimers' Business in Desolace (Ironforge)
    ["The Karnitol Shipwreck"] = { all = { 1453 }, level = 30 },
    ["Vahlarriel's Search"] = { level = 30 },
    ["Vahlarriel's Vengeance"] = { level = 30 },
    ["Centaur Bounty"] = { level = 30 },
    ["Strange Alliance"] = { level = 30 },
    ["Carved Centaur Totems"] = { level = 30 },
    ["Search for Tyranis"] = { all = { 1438 }, level = 30 },
    ["Return to Vahlarriel"] = { all = { 1439 }, level = 30 },
    ["Sceptre of Light"] = { level = 30 },
    ["Claim Rackmore's Treasure!"] = { level = 30 },
    ["Book of the Ancients"] = { all = { 5741 }, level = 30 },
    ["Bone Collector"] = { level = 33 },
    ["Bodyguard for Hire"] = { level = 30 },
    ["Kodo Roundup"] = { level = 30 },
    ["Ghost-o-plasm Round Up"] = { level = 34 },
    ["Gizelton Caravan"] = { level = 32 },
    ["Buying Friendship: Gelkis"] = { all = { 93224 }, level = 30 },     -- offered after Carved Centaur Totems (Pentigast's turn-in text); needs Gelkis >= Neutral
    ["Down the Scarlet Path"] = { level = 34 },
    ["Raid on the Kolkar"] = { all = { 1382 }, level = 30 },
    ["Get Me Out of Here!"] = { level = 34 },
}
end)()

-- zz_v3_dunmorogh.lua
parts[#parts + 1] = (function()
-- Prerequisites for routes_v3/dunmorogh.lua from wow4ever.quest "First you need" / "Minimum level" (Forever-new quests: foreverchanges.pro/quest/<id>).
-- Sources: https://wow4ever.quest/en/quests/<slug>, https://foreverchanges.pro/quest/<id>
return {
    ["Grund and Gozwin"] = { level = 4 },
    ["Secure the Mountain"] = { level = 4 },                 -- part 1 (98322); parts 2-3 gated by the parts
    ["Dawn in the Mountains"] = { level = 5 },
    ["Beer Basted Boar Ribs"] = { level = 5 },
    ["Tools for Steelgrill"] = { level = 2 },
    ["Flintfire's Shipment"] = { level = 4 },
    ["Stocking Jetsteam"] = { level = 2 },
    ["The Grizzled Den"] = { level = 4 },
    ["Ammo for Rumbleshot"] = { level = 5 },
    ["Frostmane Hold"] = { any = { 282, 420 }, level = 7 },  -- "First you need: Senir's Observations"
    ["Operation Recombobulation"] = { level = 7 },
    ["Evershine"] = { all = { 317 }, level = 2 },            -- needs Stocking Jetsteam
    ["Finding Warmth"] = { level = 5 },
    ["Rime's Wrath"] = { level = 5 },                        -- part 1 (99160)
    ["Treacherous Cold"] = { level = 5 },
    ["A Favor for Evershine"] = { all = { 318 }, level = 2 },  -- needs Evershine
    ["The Perfect Stout"] = { level = 5 },
    ["Bitter Rivals"] = { level = 2 },
    ["Frosthowl"] = { level = 5 },
    ["Tundra MacGrann's Stolen Stash"] = { level = 7 },
    ["Return to Marleth"] = { all = { 310 }, level = 2 },    -- needs Bitter Rivals
    ["The Reports"] = { all = { 287 }, level = 1 },          -- needs Frostmane Hold
    ["Return to Bellowfiz"] = { all = { 319 }, level = 2 },  -- needs A Favor for Evershine
    ["Shimmer Stout"] = { all = { 315 }, level = 8 },        -- needs The Perfect Stout
    ["A Visitor to Dun Morogh"] = { level = 9 },
    ["Never Saddle on Quality"] = { level = 7 },
    ["Protecting the Herd"] = { level = 6 },
    ["Those Blasted Troggs!"] = { level = 5 },
    ["The Public Servant"] = { level = 6 },
    ["Stolen Blasting Powder"] = { level = 7 },              -- part 1 starts from the Empty Powder Keg item; part 2 gated by part 1
    ["Farsen's Watch"] = { all = { 96408 }, level = 9 },     -- follows A Visitor to Dun Morogh (foreverchanges chain)
    ["Nip 'Em in the Bud"] = { all = { 96392 }, level = 9 }, -- follows Farsen's Watch
    ["Underground Map"] = { level = 9 },                     -- item start (Dark Iron Map), no prerequisite (foreverchanges 96391)
    ["The Lost Pilot"] = { level = 8 },
    ["A Pilot's Revenge"] = { all = { 419 }, level = 8 },    -- needs The Lost Pilot; starts at A Dwarven Corpse
    ["Stout to Kadrell"] = { all = { 413 }, level = 8 },     -- needs Shimmer Stout
}
end)()

-- zz_v3_duskwood.lua
parts[#parts + 1] = (function()
-- Prerequisites for routes_v3/duskwood.lua from wow4ever.quest "First you need" / "Minimum level".
-- Sources: https://wow4ever.quest/en/quests/<slug> (Questie Forever data); https://foreverchanges.pro/quests/duskwood (required levels)
return {
    ["The Night Watch"] = { level = 18 },
    ["The Totem of Infliction"] = { level = 18 },
    ["The Hermit"] = { level = 17 },
    ["Deliveries to Sven"] = { level = 17 },
    ["Raven Hill"] = { level = 17 },
    ["The Valor Family"] = { level = 18 },
    ["Look to the Stars"] = { level = 20 },
    ["Eight-Legged Menaces"] = { level = 17 },
    ["Jitters' Growling Gut"] = { all = { 163 }, level = 17 },           -- Raven Hill
    ["Supplies from Darkshire"] = { all = { 165 }, level = 20 },         -- The Hermit
    ["Sven's Revenge"] = { level = 20 },
    ["Wolves at Our Heels"] = { level = 19 },
    ["Sven's Camp"] = { all = { 95 }, level = 20 },                      -- Sven's Revenge
    ["Ghost Hair Thread"] = { all = { 148 }, level = 20 },               -- Supplies from Darkshire
    ["Dusky Crab Cakes"] = { all = { 5 }, level = 17 },                  -- Jitters' Growling Gut
    ["Return the Comb"] = { all = { 149 }, level = 20 },                 -- Ghost Hair Thread
    ["Deliver the Thread"] = { all = { 154 }, level = 20 },              -- Return the Comb
    ["The Shadowy Figure"] = { all = { 230 }, level = 20 },              -- Sven's Camp
    ["Zombie Juice"] = { all = { 157 }, level = 20 },                    -- Deliver the Thread
    ["The Shadowy Search Continues"] = { all = { 262 }, level = 20 },    -- The Shadowy Figure
    ["Inquire at the Inn"] = { all = { 265 }, level = 20 },              -- The Shadowy Search Continues
    ["Finding the Shadowy Figure"] = { all = { 266 }, level = 20 },      -- Inquire at the Inn
    ["Gather Rot Blossoms"] = { all = { 158 }, level = 20 },             -- Zombie Juice
    ["Return to Jitters"] = { all = { 93 }, level = 17 },                -- Dusky Crab Cakes
    ["Worgen in the Woods"] = { level = 23 },
    ["Juice Delivery"] = { all = { 156 }, level = 20 },                  -- Gather Rot Blossoms
    ["Return to Sven"] = { all = { 453 }, level = 20 },                  -- Finding the Shadowy Figure
    ["Proving Your Worth"] = { all = { 268 }, level = 20 },              -- Return to Sven
    ["Seeking Wisdom"] = { all = { 323 }, level = 20 },                  -- Proving Your Worth
    ["Ghoulish Effigy"] = { all = { 159 }, level = 20 },                 -- Juice Delivery
    ["Ogre Thieves"] = { all = { 133 }, level = 20 },                    -- Ghoulish Effigy
    ["The Weathered Grave"] = { level = 28 },
    ["Note to the Mayor"] = { all = { 134 }, level = 20 },               -- Ogre Thieves
    ["Translate Abercrombie's Note"] = { all = { 160 }, level = 20 },    -- Note to the Mayor
    ["Wait for Sirra to Finish"] = { all = { 251 }, level = 20 },        -- Translate Abercrombie's Note
    ["Translation to Ello"] = { all = { 401 }, level = 20 },             -- Wait for Sirra to Finish
    ["Bride of the Embalmer"] = { all = { 252 }, level = 20 },           -- Translation to Ello
    ["The Doomed Fleet"] = { all = { 269 }, level = 20 },                -- Seeking Wisdom
    ["Lightforge Iron"] = { all = { 270 }, level = 20 },                 -- The Doomed Fleet
    ["The Lost Ingots"] = { all = { 321 }, level = 20 },                 -- Lightforge Iron
    ["Lightforge Ingots"] = { all = { 324 }, level = 20 },               -- The Lost Ingots
    ["Blessed Arm"] = { all = { 324 }, level = 20 },                     -- The Lost Ingots (wow4ever lists 324, not 526)
    ["Armed and Ready"] = { all = { 322 }, level = 20 },                 -- Blessed Arm
    ["Morbent Fel"] = { all = { 325 }, level = 20 },                     -- Armed and Ready
}
end)()

-- zz_v3_easternplaguelands.lua
parts[#parts + 1] = (function()
-- Prerequisites for routes_v3/easternplaguelands.lua from wow4ever.quest "First you need" / "Minimum level".
-- Sources: https://wow4ever.quest/en/quests/<slug> (pamelas-doll, uncle-carlin, auntie-marlene, demon-dogs, blood-tinged-skies, carrion-grubbage,
-- augustus-receipt-book, defenders-of-darrowshire, villains-of-darrowshire, zaeldarr-the-outcast, argent-dawn-commission, minions-scourgestones,
-- redemption, of-forgotten-memories, of-lost-honor, of-love-and-family)
return {
    ["Pamela's Doll"] = { any = { 5142, 5601 }, level = 50 },        -- Little Pamela (WPL, Alliance) or Sister Pamela (Winterspring)
    ["Uncle Carlin"] = { all = { 5149 }, level = 50 },
    ["Auntie Marlene"] = { all = { 5149 }, level = 50 },
    ["Demon Dogs"] = { level = 52 },
    ["Blood Tinged Skies"] = { level = 52 },
    ["Carrion Grubbage"] = { level = 52 },
    ["Augustus' Receipt Book"] = { level = 50 },
    ["Defenders of Darrowshire"] = { all = { 5241 }, level = 50 },   -- Uncle Carlin
    ["Villains of Darrowshire"] = { all = { 5210 }, level = 50 },    -- Brother Carlin (WPL, Chromie)
    ["Zaeldarr the Outcast"] = { level = 50 },
    ["Argent Dawn Commission"] = { level = 50 },                     -- part 2 (5503); part 1 = 5401 in WPL
    ["Minion's Scourgestones"] = { level = 50 },                     -- no "First you need" on wow4ever; needs the Commission trinket in practice
    ["Redemption"] = { all = { 5542, 5543, 5544 }, level = 52 },
    ["Of Forgotten Memories"] = { all = { 5742 }, level = 52 },
    ["Of Lost Honor"] = { all = { 5781 }, level = 52 },
    ["Of Love and Family"] = { all = { 5845 }, level = 52 },
}
end)()

-- zz_v3_felwood.lua
parts[#parts + 1] = (function()
-- Prerequisites for routes_v3/felwood.lua from wow4ever.quest "First you need" / "Minimum level".
-- Sources: https://wow4ever.quest/en/quests/<slug> ; https://foreverchanges.pro/quests/felwood (Req. column)
return {
    ["Cleansing Felwood"] = { level = 48 },
    ["Timbermaw Ally"] = { level = 45 },
    ["Forces of Jaedenar"] = { level = 48 },
    ["Verifying the Corruption"] = { level = 48 },
    ["Speak to Nafien"] = { all = { 8460 }, level = 45 },
    ["The Corruption of the Jadefire"] = { level = 49 },
    ["Collection of the Corrupt Water"] = { all = { 5155 }, level = 48 },
    ["Further Corruption"] = { all = { 4421 }, level = 49 },
    ["Deadwood of the North"] = { level = 45 },
    ["Speak to Salfa"] = { all = { 8461 }, level = 45 },
    ["Flute of Xavaric"] = { level = 49 },
    ["Seeking Spiritual Aid"] = { all = { 5157 }, level = 48 },
    ["Felbound Ancients"] = { all = { 939 }, level = 49 },
    ["Silver Heart"] = { all = { 3942 }, level = 47 },              -- Linken's Memory (Un'Goro chain)
    ["Purified!"] = { all = { 4441 }, level = 49 },
    ["Dousing the Flames of Protection"] = { all = { 5159 }, level = 48 },
    ["A Strange Red Key"] = { level = 49 },
    ["Rescue From Jaedenar"] = { all = { 5202 }, level = 49 },
    ["A Final Blow"] = { all = { 5165 }, level = 48 },
    ["Retribution of the Light"] = { all = { 5203 }, level = 49 },
    ["The Remains of Trey Lightforge"] = { all = { 5204 }, level = 49 },
    ["Ancient Spirit"] = { all = { 4442 }, level = 49 },
    ["Aquementas"] = { all = { 4084 }, level = 47 },
}
end)()

-- zz_v3_feralas.lua
parts[#parts + 1] = (function()
-- Prerequisites for routes_v3/feralas.lua from wow4ever.quest "First you need" / "Minimum level".
-- Sources: https://wow4ever.quest/en/quests/<slug> ; https://www.wowhead.com/forever/quest=<id>
return {
    ["The Ruins of Solarsal"] = { level = 40 },
    ["The Missing Courier"] = { level = 40 },
    ["The High Wilderness"] = { level = 39 },
    ["The Mark of Quality"] = { level = 40 },
    ["Return to Feathermoon Stronghold"] = { all = { 2866 }, level = 40 },
    ["Against the Hatecrest"] = { all = { 2867 }, level = 40 },          -- part 1 (3130); part 2 (2869) needs 3130
    ["Against Lord Shalzaru"] = { all = { 2869 }, level = 40 },
    ["Boat Wreckage"] = { all = { 4125 }, level = 40 },
    ["The Knife Revealed"] = { all = { 4127 }, level = 40 },
    ["Psychometric Reading"] = { all = { 4129 }, level = 40 },
    ["The Woodpaw Gnolls"] = { all = { 4130 }, level = 40 },
    ["Thalanaar Delivery"] = { all = { 4131 }, level = 40 },
    ["The Writhing Deep"] = { all = { 4131 }, level = 40 },
    ["Freed from the Hive"] = { all = { 4135 }, level = 40 },
    ["Freedom for All Creatures"] = { level = 38 },
    ["Doling Justice"] = { all = { 2969 }, level = 38 },                  -- part 1 (2970); part 2 (2972) needs 2970
    ["An Orphan Looking For a Home"] = { all = { 2970 }, level = 38 },
    ["A Hero's Welcome"] = { all = { 4265 }, level = 40 },
    ["The Sunken Temple"] = { level = 46 },
    ["In Search of Knowledge"] = { level = 42 },
    ["Improved Quality"] = { all = { 2821 }, level = 40 },
    ["Delivering the Relic"] = { all = { 2870 }, level = 40 },
    ["Zapped Giants"] = { level = 45 },
    ["Fuel for the Zapping"] = { level = 45 },
    ["The Giant Guardian"] = { level = 44 },
    ["Wandering Shay"] = { all = { 2844 }, level = 44 },
}
end)()

-- zz_v3_hillsbrad.lua
parts[#parts + 1] = (function()
-- Prerequisites for routes_v3/hillsbrad.lua from wow4ever.quest "First you need" / "Minimum level" (foreverchanges.pro for the New quests).
-- Sources: https://wow4ever.quest/en/quests/<slug> ; https://foreverchanges.pro/quest/<id>
return {
    ["Down the Coast"] = { level = 25 },
    ["Brewer's Trade"] = { level = 23 },
    ["Soothing Turtle Bisque"] = { level = 28 },
    ["Talk of the Town"] = { level = 28 },
    ["Syndicate Assassins"] = { level = 26 },
    ["Hillsbrad's Hoard"] = { level = 23 },
    ["Farren's Proof"] = { all = { 536 }, level = 25 },      -- part 1 (559) needs Down the Coast
    ["Stormwind Ho!"] = { all = { 561 }, level = 25 },       -- needs Farren's Proof (last part)
    ["Reassignment"] = { all = { 562 }, level = 25 },        -- needs Stormwind Ho!
    ["Hints of a New Plague?"] = { level = 30 },
    ["An Alarming Request"] = { level = 30 },
    ["Costly Menace"] = { level = 30 },
    ["Bartolo's Yeti Fur Cloak"] = { level = 29 },
    ["Letter to Stormpike"] = { all = { 511 }, level = 30 }, -- needs Encrypted Letter (Syndicate drop)
    ["Noble Deaths"] = { all = { 510 }, level = 26 },        -- needs Foreboding Plans (Syndicate drop)
}
end)()

-- zz_v3_hinterlands.lua
parts[#parts + 1] = (function()
-- Prerequisites for routes_v3/hinterlands.lua from wow4ever.quest "First you need" / "Minimum level".
-- Sources: https://wow4ever.quest/en/quests/<slug> (Questie Forever data) ; https://www.wowhead.com/forever/quest=485 and =836 (OOX series)
-- Cross-zone prerequisites: 1449 To The Hinterlands (accepted in Stormwind), 3843 The Newest Member of the Family (accepted in Thousand Needles).
return {
    ["Gryphon Master Talonaxe"] = { all = { 1449 }, level = 38 },
    ["Rhapsody Shindigger"] = { all = { 1450 }, level = 38 },
    ["Rhapsody's Kalimdor Kocktail"] = { all = { 1451 }, level = 38 },
    ["Rhapsody's Tale"] = { all = { 1452 }, level = 38 },
    ["Witherbark Cages"] = { level = 40 },
    ["Troll Necklace Bounty"] = { level = 40 },
    ["Skulk Rock Clean-up"] = { level = 40 },
    ["Food for Baby"] = { all = { 3843 }, level = 38 },
    ["Becoming a Parent"] = { all = { 4297 }, level = 37 },
    ["Find OOX-09/HL!"] = { level = 43 },
    ["Rescue OOX-09/HL!"] = { all = { 485 }, level = 43 },
    ["The Altar of Zul"] = { all = { 2988 }, level = 40 },
    ["Jammal'an the Prophet"] = { level = 38 },
    ["Thadius Grimshade"] = { all = { 2989 }, level = 40 },
    ["Saving Sharpbeak"] = { all = { 2993 }, level = 40 },
}
end)()

-- zz_v3_lochmodan.lua
parts[#parts + 1] = (function()
-- Prerequisites for routes_v3/lochmodan.lua from wow4ever.quest "First you need" / "Minimum level".
-- Sources: https://wow4ever.quest/en/quests/<slug> ; https://foreverchanges.pro/quest/<id> (New quests' required level)
-- "Report to Ironforge", "Powder to Ironband", "Gryth Thurden" and "Return to Brock" are accepted in Ironforge (G leg) but listed as the chain requires them.
return {
    ["Rat Catching"] = { level = 10 },
    ["Mountaineer Stormpike's Task"] = { level = 9 },
    ["Thelsamar Blood Sausages"] = { level = 7 },
    ["Honor Students"] = { level = 10 },
    ["Ride to Ironforge"] = { all = { 6387 }, level = 10 },
    ["Gryth Thurden"] = { all = { 6391 }, level = 10 },
    ["Return to Brock"] = { all = { 6388 }, level = 10 },
    ["Snowbound"] = { level = 10 },
    ["In Defense of the King's Lands"] = { level = 10 },
    ["The Trogg Threat"] = { level = 10 },
    ["Filthy Paws"] = { level = 9 },
    ["Stormpike's Order"] = { all = { 1339 }, level = 9 },
    ["Silver of the Waves"] = { level = 13 },
    ["Ironband's Excavation"] = { level = 13 },
    ["Gathering Idols"] = { all = { 436 }, level = 13 },
    ["Excavation Progress Report"] = { level = 10 },
    ["Report to Ironforge"] = { all = { 298 }, level = 10 },
    ["Powder to Ironband"] = { all = { 301 }, level = 10 },
    ["Resupplying the Excavation"] = { all = { 302 }, level = 10 },
    ["Mercenaries"] = { level = 15 },
    ["Banner of the Fallen"] = { level = 10 },
    ["After the Ambush"] = { all = { 273 }, level = 10 },
    ["Protecting the Shipment"] = { all = { 454 }, level = 10 },
    ["Crocolisk Hunting"] = { level = 10 },
    ["Twisting the Knife"] = { level = 12 },
    ["A Hunter's Boast"] = { level = 11 },
    ["A Hunter's Challenge"] = { all = { 257 }, level = 11 },
    ["Vyrin's Revenge"] = { all = { 258 }, level = 15 },
    ["Bingles' Missing Supplies"] = { level = 12 },
    ["WANTED: Chok'sul"] = { level = 17 },
    ["A Dark Threat Looms"] = { level = 16 },
    ["Report to Mountaineer Rockgar"] = { level = 19 },
}
end)()

-- zz_v3_silithus.lua
parts[#parts + 1] = (function()
-- Prerequisites for routes_v3/silithus.lua from wow4ever.quest "First you need" / "Minimum level" (level-60 quests: foreverchanges.pro/quest/<id> chain + required level).
-- Sources: https://wow4ever.quest/en/quests/<slug> ; https://foreverchanges.pro/quest/<id> ; https://www.wowhead.com/forever/quest=<id>
return {
    ["Report to Marshal Bluewall"] = { level = 1 },                     -- Forever "Changed": min level 1
    ["Securing the Supply Lines"] = { level = 54 },                      -- Taking Back Silithus 8275 is only the chain's step 1, not a requirement
    ["Deadly Desert Venom"] = { level = 54 },
    ["Desert Recipe"] = { level = 54 },
    ["The Twilight Mystery"] = { level = 54 },
    ["The Spirits of Southwind"] = { all = { 1124 }, level = 54 },       -- Wasteland (Moonglade)
    ["Hive in the Tower"] = { all = { 1125 }, level = 54 },
    ["Umber, Archivist"] = { all = { 1126 }, level = 54 },
    ["Stepping Up Security"] = { all = { 8280 }, level = 54 },
    ["Noggle's Last Hope"] = { all = { 8277 }, level = 54 },
    ["Secret Communication"] = { level = 57 },
    ["Sharing the Knowledge"] = { all = { 8307 }, level = 54 },
    ["Scouring the Desert"] = { all = { 9415 }, level = 1 },             -- Forever "Changed": min level 1; PvP objective
    ["The Deserter"] = { all = { 8284 }, level = 54 },
    ["Noggle's Lost Satchel"] = { all = { 8278 }, level = 54 },
    ["Wanted - Deathclasp, Terror of the Sands"] = { level = 54 },
    ["The Twilight Lexicon"] = { all = { 8285 }, level = 54 },
    ["True Believers"] = { level = 54 },                                 -- wow4ever lists no requirement; routed after The Twilight Lexicon anyway
    ["Still Believing"] = { all = { 8323 }, level = 54 },
    ["A Terrible Purpose"] = { all = { 8279 }, level = 54 },
    ["Twilight Geolords"] = { level = 60 },
    ["Vyral the Vile"] = { all = { 8320 }, level = 60 },
}
end)()

-- zz_v3_stranglethorn.lua
parts[#parts + 1] = (function()
-- Prerequisites for routes_v3/stranglethorn.lua from wow4ever.quest "First you need" / "Minimum level".
-- Sources: https://wow4ever.quest/en/quests/<slug>; New quests: https://foreverchanges.pro/quest/<id>.
-- Keep An Eye Out / Up to Snuff: wow4ever names "The Bloodsail Buccaneers" without an id; foreverchanges chains 576 after 595.
return {
    ["Jungle Secrets"] = { level = 30 },
    ["Bookie Herod"] = { all = { 215 }, level = 30 },
    ["The Second Rebellion"] = { level = 30 },
    ["Bad Medicine"] = { level = 30 },
    ["The Cook in the Cage"] = { level = 30 },
    ["The Hidden Key"] = { all = { 200 }, level = 30 },
    ["The Spy Revealed!"] = { all = { 328 }, level = 30 },
    ["Patrol Schedules"] = { all = { 329 }, level = 30 },
    ["Report to Doren"] = { all = { 330 }, level = 30 },
    ["Krazek's Cookery"] = { level = 32 },
    ["Welcome to the Jungle"] = { level = 28 },
    ["Tiger Mastery"] = { all = { 583 }, level = 28 },
    ["Panther Mastery"] = { all = { 583 }, level = 28 },
    ["Raptor Mastery"] = { all = { 583 }, level = 28 },
    ["The Green Hills of Stranglethorn"] = { all = { 583 }, level = 30 },
    ["Chapter I"] = { level = 30 },
    ["Chapter II"] = { level = 30 },
    ["Chapter III"] = { level = 30 },
    ["Chapter IV"] = { level = 30 },
    ["Favor for Krazek"] = { all = { 210 }, level = 32 },
    ["Return to Corporal Kaleb"] = { all = { 627 }, level = 32 },
    ["Supplies to Private Thorsen"] = { level = 30 },
    ["Investigate the Camp"] = { level = 28 },
    ["The Haunted Isle"] = { level = 32 },
    ["The Stone of the Tides"] = { all = { 616 }, level = 32 },
    ["Supply and Demand"] = { level = 26 },
    ["Singing Blue Shards"] = { level = 30 },
    ["Bloodscalp Ears"] = { level = 30 },
    ["Hostile Takeover"] = { level = 31 },
    ["Kurzen's Mystery"] = { all = { 203, 204 }, level = 30 },
    ["Special Forces"] = { all = { 203, 204 }, level = 30 },
    ["Anything of Value"] = { level = 30 },
    ["Where's the Key?"] = { level = 30 },
    ["Zimmix's Great Escape"] = { all = { 97329 }, level = 30 },
    ["Troll Witchery"] = { all = { 207 }, level = 30 },
    ["Water Elementals"] = { all = { 578 }, level = 32 },
    ["Venture Company Mining"] = { all = { 605 }, level = 30 },
    ["Some Assembly Required"] = { all = { 575 }, level = 31 },
    ["Magical Analysis"] = { all = { 601 }, level = 32 },
    ["\"Pretty Boy\" Duncan"] = { all = { 603 }, level = 32 },
    ["The Curse of the Tides"] = { all = { 610 }, level = 32 },
    ["The Bloodsail Buccaneers"] = { level = 37 },
    ["Scaring Shaky"] = { level = 30 },
    ["Return to MacKinley"] = { all = { 606 }, level = 30 },
    ["Voodoo Dues"] = { all = { 607 }, level = 30 },
    ["Skullsplitter Tusks"] = { all = { 189 }, level = 37 },
    ["Zanzil's Secret"] = { level = 35 },
    ["Akiris by the Bundle"] = { level = 38 },
    ["Keep An Eye Out"] = { all = { 595 }, level = 37 },
    ["Up to Snuff"] = { all = { 595 }, level = 37 },
    ["Stoley's Debt"] = { level = 40 },
    ["Tran'rek"] = { level = 40 },
    ["Colonel Kurzen"] = { all = { 574 }, level = 30 },
    ["Big Game Hunter"] = { all = { 188, 193, 197 }, level = 28 },
    -- "Sunken Treasure" (part 5 accepted here) is described by Arathi's prereqs file (part 1).
}
end)()

-- zz_v3_tanaris.lua
parts[#parts + 1] = (function()
-- Prerequisites for routes_v3/tanaris.lua from wow4ever.quest "First you need" / "Minimum level".
-- Sources: https://wow4ever.quest/en/quests/<slug> ; https://foreverchanges.pro/quest/2781 (Caliph, wow4ever slug 404)
return {
    ["Wastewander Justice"] = { level = 40 },
    ["Water Pouch Bounty"] = { level = 40 },
    ["WANTED: Caliph Scorpidsting"] = { level = 39 },
    ["Gadgetzan Water Survey"] = { level = 38 },
    ["Noxious Lair Investigation"] = { all = { 992 }, level = 39 },
    ["Stoley's Shipment"] = { all = { 2872 }, level = 40 },        -- Stoley's Debt (MacKinley, Booty Bay)
    ["Southsea Shakedown"] = { level = 40 },
    ["WANTED: Andre Firebeard"] = { level = 40 },
    ["Pirate Hats Ahoy!"] = { level = 40 },
    ["Screecher Spirits"] = { level = 40 },
    ["Ship Schedules"] = { level = 40 },                            -- started by the Ship Schedule drop
    ["Deliver to MacKinley"] = { all = { 2873 }, level = 40 },
    ["More Wastewander Justice"] = { all = { 1690 }, level = 40 },
    ["The Dunemaul Compound"] = { level = 44 },
    ["Thistleshrub Valley"] = { level = 45 },
    ["The Thirsty Goblin"] = { level = 44 },
    ["Gahz'ridian"] = { level = 43 },
    ["Tooga's Quest"] = { level = 40 },
    ["In Good Taste"] = { all = { 2605 }, level = 44 },
    ["The Scrimshank Redemption"] = { all = { 82 }, level = 39 },
    ["Insect Part Analysis"] = { all = { 10 }, level = 39 },        -- part 1 (110); part 2 (113) is gated by part 1
    ["Rise of the Silithid"] = { all = { 113 }, level = 39 },       -- "Insect Part Analysis" (last part)
    ["Handle With Care"] = { level = 42 },
    ["Super Sticky"] = { level = 48 },
    ["The Stone Circle"] = { all = { 3445 }, level = 46 },          -- The Sunken Temple (Alliance, Feralas)
}
end)()

-- zz_v3_ungoro.lua
parts[#parts + 1] = (function()
-- Prerequisites for routes_v3/ungoro.lua from wow4ever.quest "First you need" / "Minimum level".
-- Sources: https://wow4ever.quest/en/quests/<slug> (Questie Forever 1.60.1); https://foreverchanges.pro/quests/ungoro-crater (Req. column)
return {
    ["The Apes of Un'Goro"] = { level = 47 },
    ["The Fare of Lar'korwi"] = { level = 48 },
    ["The Scent of Lar'korwi"] = { all = { 4290 }, level = 48 },
    ["The Bait for Lar'korwi"] = { all = { 4291 }, level = 48 },
    ["The Mighty U'cha"] = { all = { 4289 }, level = 50 },
    ["It's a Secret to Everybody"] = { level = 47 },
    ["Williden's Journal"] = { level = 48 },
    ["Expedition Salvation"] = { level = 48 },
    ["Alien Ecology"] = { level = 48 },
    ["Dadanga is Hungry!"] = { level = 47 },
    ["Roll the Bones"] = { level = 49 },
    ["Beware of Pterrordax"] = { level = 49 },
    ["Muigin and Larion"] = { level = 47 },
    ["A Visit to Gregan"] = { all = { 4141 }, level = 47 },
    ["Shizzle's Flyer"] = { level = 49 },
    ["Crystals of Power"] = { level = 47 },
    ["The Northern Pylon"] = { all = { 4284 }, level = 47 },
    ["The Eastern Pylon"] = { all = { 4284 }, level = 47 },
    ["The Western Pylon"] = { all = { 4284 }, level = 47 },
    ["Making Sense of It"] = { all = { 4285, 4287, 4288 }, level = 47 },
    ["Chasing A-Me 01"] = { level = 48 },
    ["Lost!"] = { level = 50 },
    ["A Little Help From My Friends"] = { all = { 4492 }, level = 50 },
    ["Finding the Source"] = { level = 51 },
    ["The New Springs"] = { all = { 974 }, level = 51 },
    ["A Gnome's Assistance"] = { all = { 3914 }, level = 47 },      -- Linken's Sword (Tanaris gravestone)
    ["Linken's Memory"] = { all = { 3941 }, level = 47 },
    ["Linken's Adventure"] = { all = { 4005 }, level = 47 },        -- Aquementas (Felwood)
    ["It's Dangerous to Go Alone"] = { all = { 3961 }, level = 47 },
}
end)()

-- zz_v3_westernplaguelands.lua
parts[#parts + 1] = (function()
-- Prerequisites for routes_v3/westernplaguelands.lua from wow4ever.quest "First you need" / "Minimum level".
-- Sources: https://wow4ever.quest/en/quests/<slug> ; https://www.wowhead.com/forever/quest=<id>
return {
    ["Clear the Way"] = { any = { 5066, 5090, 5091 }, level = 50 },   -- A Call to Arms: The Plaguelands! (city variants)
    ["Argent Dawn Commission"] = { level = 50 },
    ["A Plague Upon Thee"] = { level = 48 },
    ["Little Pamela"] = { level = 50 },
    ["All Along the Watchtowers"] = { all = { 5092 }, level = 50 },
    ["The Scourge Cauldrons"] = { all = { 5092 }, level = 50 },
    ["Target: Felstone Field"] = { all = { 5215 }, level = 50 },
    ["Better Late Than Never"] = { level = 50 },
    ["Return to Chillwind Camp"] = { all = { 5216 }, level = 50 },
    ["A Matter of Time"] = { level = 53 },
    ["Counting Out Time"] = { all = { 4971 }, level = 53 },
    ["Target: Dalson's Tears"] = { all = { 5217 }, level = 50 },
    ["Mrs. Dalson's Diary"] = { level = 52 },
    ["Locked Away"] = { all = { 5058 }, level = 52 },
    ["The Wildlife Suffers Too"] = { level = 51 },
    ["Glyphed Oaken Branch"] = { all = { 4985 }, level = 51 },
    ["Target: Writhing Haunt"] = { all = { 5220 }, level = 50 },
    ["Scholomance"] = { all = { 5097 }, level = 55 },
    ["Skeletal Fragments"] = { all = { 5533 }, level = 55 },
    ["A Strange Historian"] = { all = { 5152 }, level = 50 },   -- Auntie Marlene (EPL)
    ["The Annals of Darrowshire"] = { all = { 5153 }, level = 50 },
    ["Brother Carlin"] = { all = { 5154 }, level = 50 },
    ["Target: Gahrron's Withering"] = { all = { 5223 }, level = 50 },
    ["Mold Rhymes With..."] = { all = { 5537 }, level = 55 },
    ["Unfinished Business"] = { level = 50 },
    ["Mission Accomplished!"] = { all = { 5226 }, level = 50 },
}
end)()

-- zz_v3_wetlands.lua
parts[#parts + 1] = (function()
-- Prerequisites for routes_v3/wetlands.lua from wow4ever.quest "First you need" / "Minimum level" (Forever-new quests: foreverchanges.pro/quest/<id> and wowhead forever series boxes).
-- Sources: https://wow4ever.quest/en/quests/<slug> ; https://foreverchanges.pro/quest/<id> ; https://www.wowhead.com/forever/quest=<id>
return {
    ["The Greenwarden"] = { level = 20 },
    ["Digging Through the Ooze"] = { level = 19 },
    ["Claws from the Deep"] = { level = 20 },
    ["Spoils of War"] = { level = 18 },
    ["Young Crocolisk Skins"] = { level = 18 },
    ["Crocs of the Sky"] = { level = 19 },
    ["Alchemical Hazards"] = { level = 20 },
    ["Fiora Longears"] = { level = 18 },
    ["Apprentice's Duties"] = { all = { 484 }, level = 18 },
    ["In Search of The Excavation Team"] = { level = 21 },
    ["Reclaiming Goods"] = { all = { 279 }, level = 20 },
    ["The Third Fleet"] = { level = 22 },
    ["The Cursed Crew"] = { all = { 288 }, level = 22 },
    ["The Search Continues"] = { all = { 281 }, level = 20 },
    ["Search More Hovels"] = { all = { 284 }, level = 20 },
    ["Return the Statuette"] = { all = { 285 }, level = 20 },
    ["Report to Captain Stoutfist"] = { level = 23 },
    ["War Banners"] = { all = { 473 }, level = 23 },
    ["From the Ashes"] = { level = 23 },
    ["This Land Was Their Land"] = { level = 22 },
    ["Ormer's Revenge"] = { level = 22 },
    ["Uncovering the Past"] = { level = 22 },
    ["Daily Delivery"] = { level = 18 },
    ["Trying Times"] = { level = 21 },
    ["Tramping Paws"] = { level = 20 },
    ["Old Habits"] = { level = 23 },
    ["Fire Taboo"] = { all = { 276 }, level = 20 },
    ["Blisters on the Land"] = { all = { 277 }, level = 20 },
    ["Crimson Crate Delivery"] = { all = { 98072 }, level = 19 },
    ["Nek'rosh's Gambit"] = { all = { 464 }, level = 23 },
    ["Fall of Dun Modr"] = { level = 25 },
    ["Lifting the Curse"] = { all = { 289 }, level = 22 },
    ["The Eye of Paleth"] = { all = { 290 }, level = 22 },
    ["Razormaw Needling"] = { all = { 98240 }, level = 21 },
    ["Cleansing the Eye"] = { all = { 292 }, level = 22 },
    ["A Friend of the Family"] = { all = { 98189 }, level = 20 },
}
end)()

-- zz_v3_winterspring.lua
parts[#parts + 1] = (function()
-- Prerequisites for routes_v3/winterspring.lua from wow4ever.quest "First you need" / "Minimum level".
-- Sources: https://wow4ever.quest/en/quests/<slug> ; https://foreverchanges.pro/quest/<id>
return {
    ["Winterfall Activity"] = { level = 45 },
    ["The Videre Elixir"] = { all = { 3908 }, level = 47 },             -- It's a Secret to Everybody part 3 (Un'Goro)
    ["Strange Sources"] = { all = { 980 }, level = 51 },                -- The New Springs (Un'Goro)
    ["The Ruins of Kel'Theril"] = { any = { 5249, 5250 }, level = 53 }, -- To Winterspring! (Felwood) or Starfall (Rut'theran)
    ["Troubled Spirits of Kel'Theril"] = { all = { 5244 }, level = 53 },
    ["The Everlook Report"] = { level = 50 },
    ["Duke Nicholas Zverenhoff"] = { level = 50 },
    ["Chillwind Horns"] = { all = { 4808 }, level = 50 },               -- Felnok Steelspring (Burning Steppes)
    ["Return to Tinkee"] = { all = { 4809 }, level = 50 },
    ["Are We There, Yeti?"] = { level = 52 },
    ["Enraged Wildkin"] = { level = 53 },
    ["Sister Pamela"] = { level = 50 },
    ["Trouble in Winterspring!"] = { level = 52 },
    ["Winterfall Firewater"] = { level = 52 },                          -- item-started (Empty Firewater Flask)
    ["Threat of the Winterfall"] = { all = { 6603 }, level = 52 },
    ["Falling to Corruption"] = { all = { 5083 }, level = 52 },
    ["Beads for Salfa"] = { all = { 8464 }, level = 50 },
    ["Mystery Goo"] = { all = { 5084 }, level = 52 },                   -- accepted at the Deadwood Cauldron (Felwood)
    ["Toxic Horrors"] = { all = { 5085 }, level = 52 },
    ["Winterfall Runners"] = { all = { 5086 }, level = 52 },
    ["High Chief Winterfall"] = { all = { 5087 }, level = 52 },
    ["The Final Piece"] = { all = { 5087 }, level = 52 },               -- item-started (Crudely-written Log from High Chief Winterfall)
    ["Words of the High Chief"] = { all = { 5123 }, level = 52 },
    ["Guardians of the Altar"] = { all = { 979 }, level = 52 },         -- Find Ranshalla (Erelas Ambersky, Teldrassil)
}
end)()

LevelGuidePrereqs = {}
for _, part in ipairs(parts) do
    for title, need in pairs(part) do
        if type(need) == "table" then
            LevelGuidePrereqs[title] = need
        end
    end
end
