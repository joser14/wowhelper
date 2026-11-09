-- Talent builds for World of Warcraft: Forever (client 1.60.1), researched 2026-11-09.
-- Forever keeps three talent trees per class: 51 points by level 60, one per level from 10,
-- tier N needs 5*(N-1) points in that tree, the 31-point capstone (tier 7) is reachable at 40.
-- Talent names are as the game shows them (checked against the 1.60.1.70790 tree data).
--
-- Shape: BuildsData[classFile] = { leveling = build, pvp = build, pvp2 = build (optional),
--   pve = { tank = build, healer = build, dps = build } (only the roles the class can fill) }
-- A build has either points = { { level, talent, tree, rank }, ... } (exact order) or
-- steps = { { from, to, text }, ... } (tier-level guidance when no source gives an exact order).
-- Talents named in steps texts are listed in keyTalents so they can be matched by name.
-- Level-60 builds were published within days of launch (2026-11-04) and the beta was capped at 30,
-- so most 31-60 guidance is low or medium confidence. See research\builds_forever.md.

local CHECKED = "2026-11-09"

local function warlockAfflictionLeveling()
    local order = {
        { "Improved Corruption", "Affliction", 5 }, { "Suppression", "Affliction", 5 },
        { "Unholy Power", "Demonology", 5 }, { "Demonic Energies", "Demonology", 2 },
        { "Improved Drains", "Affliction", 3 }, { "Amplify Curse", "Affliction", 1 },
        { "Improved Bane of Agony", "Affliction", 2 }, { "Improved Life Tap", "Affliction", 2 },
        { "Pandemic", "Affliction", 3 }, { "Soul Siphon", "Affliction", 3 },
        { "Malevolence", "Affliction", 5 }, { "Shadow Mastery", "Affliction", 5 },
        { "Siphon Life", "Affliction", 1 }, { "Fel Concentration", "Affliction", 3 },
        { "Nightfall", "Affliction", 2 }, { "Improved Shadow Bolt", "Destruction", 4 },
    }
    local points, level = {}, 10
    for _, entry in ipairs(order) do
        for rank = 1, entry[3] do
            points[#points + 1] = { level = level, talent = entry[1], tree = entry[2], rank = rank }
            level = level + 1
        end
    end
    return points -- 51 points, levels 10-60
end

BuildsData = {
    WARRIOR = {
        leveling = {
            name = "Arms leveling", spec = "Arms",
            summary = "Arms gives the steadiest solo leveling with burst from Overpower procs and a big 2-hander. Fury and Protection also work; Protection is good at AoE pulls.",
            steps = {
                { from = 10, to = 14, text = "Arms tier 1: Deflection 5/5 (or Improved Rend / Improved Heroic Strike if you prefer offense)." },
                { from = 15, to = 19, text = "Arms tier 2: Improved Tactical Mastery 3/3, then Improved Overpower." },
                { from = 20, to = 24, text = "Arms tier 3: Anger Management 1/1 and Deep Wounds 3/3." },
                { from = 25, to = 29, text = "Arms tier 4: Two-Handed Weapon Specialization (Spearing Strike is optional) and Impale." },
                { from = 30, to = 39, text = "Arms tier 5-6: Weaponmaster or Bloodthrill first, then the other; Sweeping Strikes; Improved Slam." },
                { from = 40, to = 40, text = "Mortal Strike (capstone). If you went Fury early for Cruelty, respec at 40 to get it." },
                { from = 41, to = 60, text = "Finish Improved Hamstring, then put the rest into Fury tier 1-2 (Cruelty, Unbridled Wrath)." },
            },
            keyTalents = { "Deflection", "Improved Tactical Mastery", "Anger Management", "Deep Wounds", "Two-Handed Weapon Specialization",
                "Impale", "Weaponmaster", "Bloodthrill", "Sweeping Strikes", "Mortal Strike", "Cruelty" },
            train = { "Rend (4)", "Charge (4)", "Overpower (12)", "Victory Rush (20)", "Execute (24)", "Berserker Stance (30, quest)", "Whirlwind (36)" },
            stats = { "Weapon DPS", "Strength", "Stamina", "Agility", "Armor" },
            source = "https://www.warcrafttavern.com/forever/guides/warrior-leveling/",
            checked = CHECKED, confidence = "medium",
        },
        pvp = {
            name = "Arms PvP", spec = "Arms",
            summary = "Mortal Strike's healing cut and Arms burst make it the warrior PvP pick in every Forever list that ranks warriors. Fury ranks low for PvP.",
            steps = {
                { from = 10, to = 40, text = "Arms as for leveling down to Mortal Strike: Deflection, Improved Tactical Mastery, Anger Management, Deep Wounds, Impale, Sweeping Strikes." },
                { from = 41, to = 60, text = "Improved Hamstring 3/3 for kiting control, then Fury: Cruelty and Piercing Howl." },
            },
            keyTalents = { "Mortal Strike", "Improved Hamstring", "Impale", "Deep Wounds", "Improved Tactical Mastery", "Piercing Howl", "Cruelty" },
            stats = { "Weapon DPS", "Hit", "Strength", "Crit", "Stamina" },
            source = "https://seemeta.com/en/wow-forever/pvp-tier-list",
            checked = CHECKED, confidence = "low",
        },
        pve = {
            dps = {
                name = "Fury raid (stance dancing)", spec = "Fury",
                summary = "Deep Fury for Bloodthirst, Flurry and Death Wish, with Arms points for Deep Wounds, Impale and Improved Overpower to support stance dancing.",
                steps = {
                    { from = 10, to = 40, text = "Fury: Cruelty, Unbridled Wrath, Furious Precision, Enrage, Dual Wield Specialization, Death Wish, Flurry, Bloodthirst." },
                    { from = 41, to = 60, text = "Arms: Improved Overpower, Deep Wounds, Impale (and fillers needed to reach them)." },
                },
                keyTalents = { "Bloodthirst", "Flurry", "Death Wish", "Cruelty", "Unbridled Wrath", "Furious Precision", "Enrage",
                    "Dual Wield Specialization", "Deep Wounds", "Impale", "Improved Overpower" },
                stats = { "Hit (to 8%)", "Crit", "Haste", "Strength", "Agility", "Stamina" },
                source = "https://www.method.gg/wow-forever/class-guides/fury-warrior/talents",
                checked = CHECKED, confidence = "medium",
            },
            tank = {
                name = "Protection raid", spec = "Protection",
                summary = "Deep Protection to Shield Slam with leftover points in Arms for Deep Wounds and Impale. The dungeon variant swaps toward Fury's Enrage for multi-mob fights.",
                steps = {
                    { from = 10, to = 40, text = "Protection: Shield Specialization, Anticipation, Defiance, Last Stand, Improved Shield Wall, Concussion Blow, Bastion, Shield Slam. Skip Improved Thunder Clap, Improved Sunder Armor, Improved Shield Bash." },
                    { from = 41, to = 60, text = "Arms: Deep Wounds and Impale. Dungeon variant: Fury Enrage instead." },
                },
                keyTalents = { "Shield Slam", "Bastion", "Defiance", "Anticipation", "Shield Specialization", "Last Stand", "Deep Wounds", "Impale", "Enrage" },
                stats = { "Stamina", "Expertise (to 6.5%)", "Hit (to 8%)", "Defense (to 440)", "Armor", "Crit", "Agility" },
                source = "https://www.method.gg/wow-forever/class-guides/protection-warrior/talents",
                checked = CHECKED, confidence = "low",
            },
        },
    },

    PALADIN = {
        leveling = {
            name = "Retribution leveling", spec = "Retribution",
            summary = "Retribution is the default for the first 20-30 levels even for future tanks; after that Ret, Protection or Shockadin all level fine.",
            steps = {
                { from = 10, to = 19, text = "Retribution tiers 1-2: Benediction and Deflection / Conviction." },
                { from = 20, to = 24, text = "Seal of Command; swap from Seal of Righteousness to it." },
                { from = 25, to = 34, text = "Two-Handed Weapon Specialization, Sacred Arbiter, then Vengeance (Repentance can replace one tier-5 point)." },
                { from = 35, to = 40, text = "Champion of the Light, then Unsealed Wrath at 40." },
                { from = 41, to = 60, text = "Holy or Protection utility; respec to Prot or Holy with dual spec at 40 if you plan to tank or heal." },
            },
            keyTalents = { "Benediction", "Conviction", "Seal of Command", "Two-Handed Weapon Specialization", "Sacred Arbiter", "Vengeance", "Repentance", "Champion of the Light", "Unsealed Wrath" },
            train = { "Judgement (4)", "Holy Strike (6)", "Seal of Fury (10)", "Consecration (20)", "Exorcism (20)", "Divine Shield (32)", "Hammer of Wrath (44)" },
            stats = { "Strength", "Attack Power", "Stamina", "Spell Power", "Intellect", "Armor" },
            source = "https://www.warcrafttavern.com/forever/guides/paladin-leveling/",
            checked = CHECKED, confidence = "low",
        },
        pvp = {
            name = "Holy PvP", spec = "Holy",
            summary = "Holy Paladin is rated the most durable PvP healer by several Forever lists. Points outside Holy go to Protection for stun reduction and Hammer of Justice.",
            steps = {
                { from = 10, to = 40, text = "Holy: Divine Strength / Spiritual Focus, Healing Light, Illumination, Divine Favor, Infusion of Light, Holy Shock, Holy Power, Light's Vigil." },
                { from = 41, to = 60, text = "Protection: Improved Hammer of Justice, Guardian's Favor, Templar's Bulwark, Stoicism if reachable." },
            },
            keyTalents = { "Holy Shock", "Light's Vigil", "Illumination", "Divine Favor", "Infusion of Light", "Improved Hammer of Justice", "Stoicism", "Templar's Bulwark" },
            stats = { "Healing Power", "Stamina", "Intellect", "Crit" },
            source = "https://seemeta.com/en/wow-forever/pvp-tier-list",
            checked = CHECKED, confidence = "low",
        },
        pvp2 = {
            name = "Retribution PvP", spec = "Retribution",
            summary = "Skycoach rates Retribution the top paladin PvP spec for burst; other lists put it lower. Built around Conviction, Two-Handed Weapon Specialization and Vengeance.",
            steps = {
                { from = 10, to = 40, text = "Retribution to Unsealed Wrath: Conviction, Seal of Command, Two-Handed Weapon Specialization, Repentance, Vengeance, Champion of the Light." },
                { from = 41, to = 60, text = "Protection utility: Improved Hammer of Justice, Templar's Bulwark." },
            },
            keyTalents = { "Conviction", "Two-Handed Weapon Specialization", "Vengeance", "Repentance", "Unsealed Wrath" },
            stats = { "Strength", "Hit", "Spell Power", "Stamina", "Crit" },
            source = "https://skycoach.gg/blog/wow-forever/articles/best-pvp-specs",
            checked = CHECKED, confidence = "low",
        },
        pve = {
            healer = {
                name = "Holy raid healer", spec = "Holy",
                summary = "Deep Holy for Holy Shock and the Light's Vigil capstone; the exact point map is only published as a calculator image.",
                steps = {
                    { from = 10, to = 40, text = "Holy: Healing Light, Reverence, Illumination, Divine Favor, Infusion of Light, Holy Shock, Holy Power, Light's Vigil." },
                    { from = 41, to = 60, text = "Protection tier 1-3 utility (Divine Intellect, Guardian's Favor)." },
                },
                keyTalents = { "Light's Vigil", "Holy Shock", "Holy Power", "Illumination", "Divine Favor", "Reverence", "Infusion of Light", "Divine Intellect" },
                stats = { "Healing Power", "Intellect", "Crit", "MP5", "Spirit", "Haste" },
                source = "https://www.method.gg/wow-forever/class-guides/holy-paladin",
                checked = CHECKED, confidence = "low",
            },
            tank = {
                name = "Protection (Sacred Arbiter)", spec = "Protection",
                summary = "Deep Protection to Shieldsworn with Retribution points for Sacred Arbiter; Method also lists Improved Seals and Shock Prot variants.",
                steps = {
                    { from = 10, to = 40, text = "Protection: Redoubt, Precision, Sacred Duty, Templar's Bulwark, Improved Righteous Fury, Holy Shield, Iron Creed, Shieldsworn." },
                    { from = 41, to = 60, text = "Retribution to Sacred Arbiter (or Holy to Improved Seals for the variant)." },
                },
                keyTalents = { "Shieldsworn", "Iron Creed", "Holy Shield", "Templar's Bulwark", "Improved Righteous Fury", "Sacred Arbiter", "Improved Seals" },
                stats = { "Defense (to 440)", "Stamina", "Hit (to 8%)", "Expertise", "Spell Power", "Block", "Crit" },
                source = "https://www.method.gg/wow-forever/class-guides/protection-paladin",
                checked = CHECKED, confidence = "low",
            },
            dps = {
                name = "Deep Retribution", spec = "Retribution",
                summary = "Deep Retribution to Unsealed Wrath, using Champion of the Light, Sacred Arbiter and the reworked Conviction; a Holy Shock DPS variant also exists.",
                steps = {
                    { from = 10, to = 40, text = "Retribution: Conviction, Seal of Command, Sacred Arbiter, Two-Handed Weapon Specialization, Vengeance, Champion of the Light, Unsealed Wrath." },
                    { from = 41, to = 60, text = "Holy for Improved Seals / Divine Strength, or Protection utility." },
                },
                keyTalents = { "Unsealed Wrath", "Champion of the Light", "Sacred Arbiter", "Conviction", "Vengeance", "Seal of Command" },
                stats = { "Hit (to 8%)", "Expertise (to 6.5%)", "Spell Power", "Strength", "Attack Power", "Intellect", "Crit" },
                source = "https://www.method.gg/wow-forever/class-guides/retribution-paladin",
                checked = CHECKED, confidence = "low",
            },
        },
    },

    HUNTER = {
        leveling = {
            name = "Beast Mastery leveling", spec = "Beast Mastery",
            summary = "Beast Mastery is the recommended leveling spec: a strong pet tanks while you shoot, with little downtime.",
            steps = {
                { from = 10, to = 19, text = "Beast Mastery tiers 1-2: Endurance Training / Deadly Aspects, Focused Fire." },
                { from = 20, to = 24, text = "Bestial Swiftness, Unleashed Fury." },
                { from = 25, to = 29, text = "Ferocity and Summon Hawk." },
                { from = 30, to = 34, text = "Intimidation and Bestial Discipline, then Spirit Bond / Frenzy." },
                { from = 35, to = 40, text = "Frenzy, then Bestial Wrath at 40." },
                { from = 41, to = 60, text = "Marksmanship: Efficiency, Lethal Attacks / Hawk Eye, Careful Aim (Lone Wolf is not advised while leveling with a pet)." },
            },
            keyTalents = { "Bestial Swiftness", "Ferocity", "Unleashed Fury", "Summon Hawk", "Intimidation", "Bestial Discipline", "Frenzy", "Bestial Wrath", "Efficiency", "Careful Aim" },
            train = { "Serpent Sting (4)", "Arcane Shot (6)", "Tame Beast (10)", "Mend Pet (12)", "Multi-Shot (18)", "Aimed Shot (20)", "Aspect of the Cheetah (20)", "Feign Death (30)" },
            stats = { "Agility", "Attack Power", "Crit", "Intellect", "Stamina", "Spirit", "Armor" },
            source = "https://www.warcrafttavern.com/forever/guides/hunter-leveling/",
            checked = CHECKED, confidence = "medium",
        },
        pvp = {
            name = "Beast Mastery PvP", spec = "Beast Mastery",
            summary = "Intimidation and Bestial Wrath give a stun and a burst window; rated A for PvP alongside Marksmanship.",
            steps = {
                { from = 10, to = 40, text = "Beast Mastery to Bestial Wrath with Intimidation and Bestial Discipline." },
                { from = 41, to = 60, text = "Marksmanship: Improved Concussive Shot, Efficiency, Careful Aim." },
            },
            keyTalents = { "Bestial Wrath", "Intimidation", "Improved Concussive Shot", "Careful Aim" },
            stats = { "Agility", "Intellect", "Stamina", "Crit" },
            source = "https://seemeta.com/en/wow-forever/pvp-tier-list",
            checked = CHECKED, confidence = "low",
        },
        pvp2 = {
            name = "Marksmanship PvP", spec = "Marksmanship",
            summary = "Scatter Shot and Improved Concussive Shot give peel and kiting; Sniper Shot adds long-range burst.",
            steps = {
                { from = 10, to = 40, text = "Marksmanship: Improved Concussive Shot, Efficiency, Careful Aim, Trueshot Aura, Mortal Shots, Scatter Shot, Ranged Weapon Specialization, Sniper Shot." },
                { from = 41, to = 60, text = "Beast Mastery or Survival utility (Deflection, Deterrence)." },
            },
            keyTalents = { "Scatter Shot", "Improved Concussive Shot", "Sniper Shot", "Mortal Shots", "Deterrence" },
            stats = { "Agility", "Intellect", "Stamina", "Crit" },
            source = "https://seemeta.com/en/wow-forever/pvp-tier-list",
            checked = CHECKED, confidence = "low",
        },
        pve = {
            dps = {
                name = "Marksmanship (Lone Wolf or pet)", spec = "Marksmanship",
                summary = "Method expects Marksmanship to be the best endgame hunter spec; Careful Aim turns Intellect into attack power so Intellect matters as much as Agility.",
                steps = {
                    { from = 10, to = 40, text = "Marksmanship: Lethal Attacks, Careful Aim, Efficiency, Lone Wolf (or keep the pet), Trueshot Aura, Mortal Shots, Barrage, Ranged Weapon Specialization, Sniper Shot." },
                    { from = 41, to = 60, text = "Beast Mastery tier 1-2 (Deadly Aspects) or Survival for the pet variant." },
                },
                keyTalents = { "Mortal Shots", "Ranged Weapon Specialization", "Barrage", "Lone Wolf", "Careful Aim", "Trueshot Aura", "Sniper Shot", "Deadly Aspects" },
                stats = { "Agility", "Intellect", "Strength" },
                source = "https://www.method.gg/wow-forever/class-guides/marksmanship-hunter",
                checked = CHECKED, confidence = "low",
            },
        },
    },

    ROGUE = {
        leveling = {
            name = "Combat leveling", spec = "Combat",
            summary = "Combat mixes damage and defense and works with any weapon type; Subtlety Ambush and Bleed builds are alternatives.",
            steps = {
                { from = 10, to = 14, text = "Combat tier 1: Coup de Grace / Efficient Strikes / Lightning Reflexes." },
                { from = 15, to = 19, text = "Precision." },
                { from = 20, to = 24, text = "Riposte." },
                { from = 25, to = 29, text = "Flawless Execution, Aggression, Weapon Expertise." },
                { from = 30, to = 34, text = "Dual Wield Specialization, Blade Flurry, Hack and Slash." },
                { from = 35, to = 40, text = "Flash of Steel, then Adrenaline Rush at 40." },
                { from = 41, to = 60, text = "Assassination: Malice, Remorseless Attacks, Improved Slice and Dice, Ruthlessness, Lethality." },
            },
            keyTalents = { "Precision", "Riposte", "Flawless Execution", "Aggression", "Weapon Expertise", "Dual Wield Specialization", "Blade Flurry", "Hack and Slash", "Flash of Steel", "Adrenaline Rush", "Malice", "Lethality" },
            train = { "Slice and Dice (10)", "Kick (12)", "Poisons (20, quest)", "Vanish (22)", "Shank (24)", "Kidney Shot (30)", "Blind (34)" },
            stats = { "Crit", "Agility", "Attack Power", "Strength", "Stamina", "Armor" },
            source = "https://www.warcrafttavern.com/forever/guides/rogue-leveling/",
            checked = CHECKED, confidence = "medium",
        },
        pvp = {
            name = "Subtlety PvP", spec = "Subtlety",
            summary = "Subtlety is the top-rated rogue PvP spec: Preparation gives a second opener and escape, Elusiveness and Quick Getaway add survival.",
            steps = {
                { from = 10, to = 40, text = "Subtlety: Opportunity, Camouflage, Improved Ambush, Initiative, Premeditation, Elusiveness, Quick Getaway, Preparation, Hemorrhage, Death Mark." },
                { from = 41, to = 60, text = "Assassination: Malice, Improved Slice and Dice / Ruthlessness, Lethality." },
            },
            keyTalents = { "Preparation", "Elusiveness", "Premeditation", "Opportunity", "Camouflage", "Quick Getaway", "Hemorrhage", "Death Mark" },
            stats = { "Agility", "Attack Power", "Stamina", "Crit", "Hit" },
            source = "https://seemeta.com/en/wow-forever/pvp-tier-list",
            checked = CHECKED, confidence = "low",
        },
        pve = {
            dps = {
                name = "Combat Sinister Strike", spec = "Combat",
                summary = "Combat with Sinister Strike as the builder; a Backstab variant exists. Assassination (Combat Mutilate) is the alternative.",
                steps = {
                    { from = 10, to = 40, text = "Combat: Precision, Weapon Expertise, Aggression, Dual Wield Specialization, Blade Flurry, Hack and Slash, Flash of Steel, Adrenaline Rush." },
                    { from = 41, to = 60, text = "Assassination: Malice, Ruthlessness, Improved Slice and Dice, Lethality, Relentless Strikes." },
                },
                keyTalents = { "Adrenaline Rush", "Blade Flurry", "Flash of Steel", "Hack and Slash", "Weapon Expertise", "Precision", "Malice", "Lethality" },
                stats = { "Weapon DPS", "Hit", "Expertise", "Agility", "Crit", "Strength", "Stamina" },
                source = "https://www.method.gg/wow-forever/class-guides/combat-rogue",
                checked = CHECKED, confidence = "low",
            },
        },
    },

    PRIEST = {
        leveling = {
            name = "Discipline to 40, then Shadow", spec = "Discipline",
            summary = "Level with a mana-efficient, wand-and-shield Discipline build, then respec to Shadow at 40 for Shadowform.",
            steps = {
                { from = 10, to = 19, text = "Discipline tiers 1-2: Wand Specialization, Twin Disciplines / Power in Light, Mental Strength." },
                { from = 20, to = 29, text = "Inner Focus, Improved Power Word: Shield, Meditation; Soul Warding." },
                { from = 30, to = 39, text = "Penance at 30, then Renewed Hope / Divine Aegis." },
                { from = 40, to = 40, text = "Respec to Shadow at the trainer (dual spec opens at 40): Spirit Tap, Improved Shadow Word: Pain, Mind Flay, Vampiric Embrace, Shadow Weaving, Silence, Darkness, Shadowform." },
                { from = 41, to = 60, text = "Finish Shadow (Improved Mind Flay, Early Demise), then Discipline tier 1-2." },
            },
            keyTalents = { "Wand Specialization", "Inner Focus", "Improved Power Word: Shield", "Meditation", "Penance", "Spirit Tap", "Mind Flay", "Vampiric Embrace", "Shadowform" },
            train = { "Shadow Word: Pain (4)", "Power Word: Shield (6)", "Renew (8)", "Mind Blast (10)", "Psychic Scream (14)", "Flash Heal (20)" },
            stats = { "Intellect", "Spell Damage", "Stamina", "Spirit", "Armor" },
            source = "https://www.method.gg/wow-forever/wow-forever-priest-leveling-guide-and-talents",
            checked = CHECKED, confidence = "medium",
        },
        pvp = {
            name = "Shadow PvP", spec = "Shadow",
            summary = "Shadow is rated S for PvP damage: Silence, Shadowform and Vampiric Embrace with Discipline points for shields.",
            steps = {
                { from = 10, to = 40, text = "Shadow: Blackout, Improved Shadow Word: Pain, Improved Psychic Scream, Mind Flay, Vampiric Embrace, Silence, Darkness, Shadowform." },
                { from = 41, to = 60, text = "Discipline: Silent Resolve / Mental Strength, Inner Focus, Improved Power Word: Shield." },
            },
            keyTalents = { "Shadowform", "Silence", "Vampiric Embrace", "Improved Psychic Scream", "Blackout", "Inner Focus" },
            stats = { "Spell Damage", "Stamina", "Hit", "Crit", "Intellect" },
            source = "https://seemeta.com/en/wow-forever/pvp-tier-list",
            checked = CHECKED, confidence = "low",
        },
        pvp2 = {
            name = "Discipline PvP healer", spec = "Discipline",
            summary = "Discipline is the top-rated priest healer for PvP thanks to Power Word: Shield and Penance.",
            steps = {
                { from = 10, to = 40, text = "Discipline: Improved Power Word: Shield, Soul Warding, Penance, Renewed Hope, Divine Aegis, Power Infusion." },
                { from = 41, to = 60, text = "Holy: Improved Renew, Holy Specialization, Inspiration." },
            },
            keyTalents = { "Penance", "Soul Warding", "Power Infusion", "Divine Aegis", "Improved Power Word: Shield" },
            stats = { "Healing Power", "Stamina", "Intellect", "MP5" },
            source = "https://skycoach.gg/blog/wow-forever/articles/best-pvp-specs",
            checked = CHECKED, confidence = "low",
        },
        pve = {
            healer = {
                name = "Holy 18/33/0", spec = "Holy",
                summary = "A level-60 Holy build with 33 Holy points to Prayer of Mending and 18 Discipline points for Meditation.",
                steps = {
                    { from = 10, to = 40, text = "Holy (33): Improved Renew, Holy Specialization, Inspiration, Holy Binding, Improved Healing, Litany of Light, Spiritual Guidance, Spiritual Healing, Prayer of Mending." },
                    { from = 41, to = 60, text = "Discipline (18): Twin Disciplines / Mental Strength, Inner Focus, Meditation, Improved Inner Fire / Soul Warding." },
                },
                keyTalents = { "Prayer of Mending", "Spiritual Healing", "Spiritual Guidance", "Litany of Light", "Holy Binding", "Improved Renew", "Meditation" },
                stats = { "Healing Power", "Intellect", "MP5", "Spirit", "Crit" },
                source = "https://www.warcrafttavern.com/forever/guides/holy-priest/",
                checked = CHECKED, confidence = "medium",
            },
            dps = {
                name = "Shadow raid", spec = "Shadow",
                summary = "Deep Shadow with Dark Inspiration for party mana; one projection puts it at 14/2/35.",
                steps = {
                    { from = 10, to = 40, text = "Shadow (about 35): Shadow Focus, Improved Shadow Word: Pain, Improved Mind Blast, Mind Flay, Improved Mind Flay, Shadow Weaving, Dark Inspiration, Darkness, Early Demise, Shadowform." },
                    { from = 41, to = 60, text = "Discipline (about 14): Twin Disciplines, Mental Strength, Inner Focus / Meditation." },
                },
                keyTalents = { "Shadowform", "Darkness", "Dark Inspiration", "Shadow Weaving", "Improved Mind Flay", "Mind Flay", "Shadow Focus" },
                stats = { "Hit (to cap)", "Spell Damage", "Crit", "Intellect", "Spirit" },
                source = "https://www.method.gg/wow-forever/class-guides/shadow-priest",
                checked = CHECKED, confidence = "low",
            },
        },
    },

    SHAMAN = {
        -- Alliance shamans are Dwarves only (not Night Elves).
        leveling = {
            name = "Enhancement leveling", spec = "Enhancement",
            summary = "Enhancement is the strongest leveling option and carries into endgame; Elemental works but runs out of mana.",
            steps = {
                { from = 10, to = 19, text = "Enhancement tiers 1-2: Thundering Strikes / Ancestral Knowledge, Mental Dexterity." },
                { from = 20, to = 24, text = "Elemental Weapons, Shamanistic Focus." },
                { from = 25, to = 29, text = "Stormstrike, Flurry, Improved Ghost Wolf." },
                { from = 30, to = 39, text = "Mental Quickness, Improved Stormstrike, Maelstrom Weapon." },
                { from = 40, to = 40, text = "Rage of the Farseer. Dual spec at 40 if you want Restoration for dungeons." },
                { from = 41, to = 60, text = "Restoration tier 1-2 (Ancestral Healing path) or Elemental (Earthbound) for utility." },
            },
            keyTalents = { "Mental Dexterity", "Elemental Weapons", "Stormstrike", "Flurry", "Improved Ghost Wolf", "Mental Quickness", "Maelstrom Weapon", "Rage of the Farseer" },
            train = { "Earth Shock (4)", "Lightning Shield (8)", "Flame Shock (10)", "Flametongue Weapon (10)", "Ghost Wolf (20)", "Call of the Elements (20)", "Windfury Weapon (30)" },
            stats = { "Hit", "Expertise", "Strength", "Intellect", "Crit", "Spell Damage", "Agility" },
            source = "https://www.warcrafttavern.com/forever/guides/shaman-leveling/",
            checked = CHECKED, confidence = "medium",
        },
        pvp = {
            name = "Enhancement PvP", spec = "Enhancement",
            summary = "Enhancement is the shaman PvP pick in most lists for its burst and survivability; Elemental is rated higher in one list.",
            steps = {
                { from = 10, to = 40, text = "Enhancement to Rage of the Farseer: Stormstrike, Flurry, Improved Ghost Wolf, Maelstrom Weapon." },
                { from = 41, to = 60, text = "Restoration: Nature's Swiftness path, or Elemental: Earthbound." },
            },
            keyTalents = { "Stormstrike", "Maelstrom Weapon", "Improved Ghost Wolf", "Nature's Swiftness", "Earthbound" },
            stats = { "Strength", "Hit", "Intellect", "Stamina", "Crit" },
            source = "https://skycoach.gg/blog/wow-forever/articles/best-pvp-specs",
            checked = CHECKED, confidence = "low",
        },
        pve = {
            healer = {
                name = "Restoration", spec = "Restoration",
                summary = "Restoration to Riptide with Water Shield and Mana Tide Totem for mana; published as a level-30 beta build pending a level-60 update.",
                steps = {
                    { from = 10, to = 40, text = "Restoration: Improved Healing Wave / Tidal Focus, Mindfulness, Ancestral Healing, Water Shield, Tidal Mastery, Mana Tide Totem, Nature's Swiftness, Purification, Riptide." },
                    { from = 41, to = 60, text = "Enhancement tier 1-2 (Ancestral Knowledge) or Elemental." },
                },
                keyTalents = { "Riptide", "Nature's Swiftness", "Mana Tide Totem", "Water Shield", "Mindfulness", "Tidal Mastery", "Ancestral Healing", "Purification" },
                stats = { "Healing Power", "Spirit", "Intellect", "Crit", "Haste" },
                source = "https://www.warcrafttavern.com/forever/guides/restoration-shaman/",
                checked = CHECKED, confidence = "low",
            },
            dps = {
                name = "Enhancement", spec = "Enhancement",
                summary = "Enhancement melee with Stormstrike and Maelstrom Weapon; it needs both melee and spell hit.",
                steps = {
                    { from = 10, to = 40, text = "Enhancement to Rage of the Farseer." },
                    { from = 41, to = 60, text = "Remaining points per Method's talent page (not published as text)." },
                },
                keyTalents = { "Rage of the Farseer", "Maelstrom Weapon", "Stormstrike", "Flurry" },
                stats = { "Hit (8%, up to 17%)", "Strength", "Intellect", "Crit", "Agility", "Spirit", "MP5" },
                source = "https://www.method.gg/wow-forever/class-guides/enhancement-shaman",
                checked = CHECKED, confidence = "low",
            },
        },
    },

    MAGE = {
        leveling = {
            name = "Frost leveling (7 Arcane)", spec = "Frost",
            summary = "Frost is safest and, once Ice Lance and gear come together, the fastest killer; an early 7 points in Arcane give Missile Barrage procs.",
            steps = {
                { from = 10, to = 14, text = "Improved Frostbolt." },
                { from = 15, to = 19, text = "Arcane: Arcane Subtlety / Arcane Concentration, Missile Barrage (7 Arcane points total); Frost: Frostbite, Ice Shards." },
                { from = 20, to = 24, text = "Frost Channeling, Ice Lance." },
                { from = 25, to = 29, text = "Shatter, Ice Block." },
                { from = 30, to = 34, text = "Cold Snap, Fingers of Frost." },
                { from = 35, to = 39, text = "Winter's Chill." },
                { from = 40, to = 40, text = "Ice Barrier." },
                { from = 41, to = 60, text = "Finish Frost, then more Arcane (Arcane Meditation)." },
            },
            keyTalents = { "Improved Frostbolt", "Missile Barrage", "Arcane Concentration", "Frostbite", "Ice Shards", "Frost Channeling", "Ice Lance", "Shatter", "Ice Block", "Cold Snap", "Fingers of Frost", "Winter's Chill", "Ice Barrier" },
            train = { "Frostbolt (4)", "Polymorph (8)", "Frost Nova (10)", "Blink (20)", "Blizzard (20)", "Counterspell (24)", "Frostfire Bolt (40)" },
            stats = { "Spell Damage", "Intellect", "MP5", "Stamina", "Spirit", "Armor" },
            source = "https://www.warcrafttavern.com/forever/guides/mage-leveling/",
            checked = CHECKED, confidence = "medium",
        },
        pvp = {
            name = "Frost PvP", spec = "Frost",
            summary = "Frost is rated S for PvP: Ice Block and Ice Barrier for survival plus Shatter control.",
            steps = {
                { from = 10, to = 40, text = "Frost to Ice Barrier: Improved Frostbolt, Frostbite, Improved Frost Nova, Permafrost, Ice Lance, Ice Block, Shatter, Cold Snap, Improved Cone of Cold." },
                { from = 41, to = 60, text = "Arcane: Arcane Subtlety, Magic Absorption, Improved Counterspell, Presence of Mind." },
            },
            keyTalents = { "Ice Block", "Ice Barrier", "Cold Snap", "Shatter", "Improved Frost Nova", "Improved Counterspell", "Presence of Mind" },
            stats = { "Spell Damage", "Stamina", "Crit", "Hit", "Intellect" },
            source = "https://seemeta.com/en/wow-forever/pvp-tier-list",
            checked = CHECKED, confidence = "low",
        },
        pve = {
            dps = {
                name = "Fire (Fireball/Arcane)", spec = "Fire",
                summary = "Fire built around Ignite, Heating Up and Combustion with Improved Scorch; Frost (Cone of Cold + Meditation) is the safer alternative with lower damage.",
                steps = {
                    { from = 10, to = 40, text = "Fire: Ignite, Impact / Incineration, Pyroblast, Improved Scorch, Heating Up, Master of Elements, Critical Mass, Fire Power, Combustion." },
                    { from = 41, to = 60, text = "Arcane: Arcane Subtlety / Arcane Concentration, Arcane Meditation." },
                },
                keyTalents = { "Combustion", "Ignite", "Heating Up", "Improved Scorch", "Critical Mass", "Fire Power", "Master of Elements", "Arcane Concentration" },
                stats = { "Hit", "Spell Damage", "Crit", "Haste", "Spell Penetration", "Intellect", "Spirit" },
                source = "https://www.method.gg/wow-forever/class-guides/fire-mage",
                checked = CHECKED, confidence = "low",
            },
        },
    },

    WARLOCK = {
        leveling = {
            name = "Affliction leveling", spec = "Affliction",
            summary = "Affliction needs no respec: instant Corruption and drains keep you fighting while moving between mobs, with a few Demonology points for pet support.",
            points = warlockAfflictionLeveling(),
            train = { "Corruption (4)", "Life Tap (6)", "Bane of Agony (8)", "Fear (8)", "Summon Voidwalker (10)", "Drain Life (14)", "Summon Felhunter (30)" },
            stats = { "Spell Power", "Shadow Damage", "Wand DPS (to 30)", "Spirit", "Intellect", "Stamina" },
            source = "https://www.warcrafttavern.com/forever/guides/warlock-leveling/",
            checked = CHECKED, confidence = "medium",
        },
        pvp = {
            name = "Demonology Soul Link PvP", spec = "Demonology",
            summary = "Demonology is rated S for PvP in two lists for Soul Link and Demonic Embrace survivability, with Siphon Life and Molten Skin from the other trees.",
            steps = {
                { from = 10, to = 30, text = "Demonology: Demonic Embrace, Fel Vitality, Improved Voidwalker / Demonic Aegis, Master Summoner, Fel Domination, Soul Link." },
                { from = 31, to = 50, text = "Affliction: Improved Corruption, Suppression, Improved Drains, Siphon Life." },
                { from = 51, to = 60, text = "Destruction: Molten Skin (or more Demonology toward Demonic Pact)." },
            },
            keyTalents = { "Soul Link", "Demonic Embrace", "Siphon Life", "Molten Skin", "Fel Domination", "Improved Corruption" },
            stats = { "Stamina", "Spell Power", "Hit", "Spell Penetration" },
            source = "https://skycoach.gg/blog/wow-forever/articles/best-pvp-specs",
            checked = CHECKED, confidence = "low",
        },
        pve = {
            dps = {
                name = "Affliction (Wrack)", spec = "Affliction",
                summary = "Deep Affliction to Wrack is the best single-target build per Warcraft Tavern; a Shadow Mastery/Ruin build with Shadow Bolt filler is close behind.",
                steps = {
                    { from = 10, to = 40, text = "Affliction: Improved Corruption, Suppression, Improved Drains, Pandemic, Malevolence, Nightfall, Soul Siphon, Shadow Mastery, Wrack." },
                    { from = 41, to = 60, text = "Destruction: Improved Shadow Bolt, Cataclysm / Aftermath, Ruin." },
                },
                keyTalents = { "Wrack", "Shadow Mastery", "Pandemic", "Malevolence", "Suppression", "Improved Shadow Bolt", "Ruin" },
                stats = { "Hit (to 17%)", "Spell Damage", "Shadow Damage", "Spell Penetration", "Crit", "Intellect", "Haste" },
                source = "https://www.warcrafttavern.com/forever/guides/warlock/",
                checked = CHECKED, confidence = "low",
            },
        },
    },

    DRUID = {
        leveling = {
            name = "Feral cat leveling", spec = "Feral Combat",
            summary = "Feral cat has the smoothest leveling with Prowl, Dash and almost no mana downtime, and can bear tank dungeons on the way.",
            steps = {
                { from = 10, to = 19, text = "Feral tiers 1-2: Furor / Ferocity, Feral Swiftness, Feral Instinct." },
                { from = 20, to = 24, text = "Feral Charge, Sharpened Claws / Savage Fury (skip Shredding Attacks)." },
                { from = 25, to = 29, text = "Lacerate, Predatory Discipline, Predatory Strikes." },
                { from = 30, to = 39, text = "Leader of the Pack, Natural Instinct, Rend and Tear." },
                { from = 40, to = 40, text = "Primal Bite or Shifting Power." },
                { from = 41, to = 60, text = "The other capstone, then Restoration (Heart of the Wild / Naturalist) or Balance utility." },
            },
            keyTalents = { "Furor", "Ferocity", "Feral Swiftness", "Feral Charge", "Lacerate", "Predatory Discipline", "Leader of the Pack", "Rend and Tear", "Primal Bite", "Shifting Power" },
            train = { "Bear Form (10)", "Cat Form (20)", "Prowl (20)", "Rip (20)", "Ferocious Bite (24)", "Dash (26)", "Travel Form (30)" },
            stats = { "Strength", "Agility", "Attack Power", "Stamina", "Intellect", "Spirit", "Armor" },
            source = "https://www.warcrafttavern.com/forever/guides/druid-leveling/",
            checked = CHECKED, confidence = "medium",
        },
        pvp = {
            name = "Restoration PvP", spec = "Restoration",
            summary = "Restoration is rated S or A for PvP healing in two lists; Bloom and shapeshift escapes keep it alive.",
            steps = {
                { from = 10, to = 40, text = "Restoration: Heart of the Wild / Nature's Focus, Naturalist, Bloom, Improved Rejuvenation, Swiftmend, Nature's Swiftness, Improved Regrowth, Wild Growth." },
                { from = 41, to = 60, text = "Feral: Feral Swiftness, Feral Instinct / Thick Hide." },
            },
            keyTalents = { "Bloom", "Swiftmend", "Nature's Swiftness", "Wild Growth", "Feral Swiftness" },
            stats = { "Healing Power", "Stamina", "Intellect", "Spirit" },
            source = "https://skycoach.gg/blog/wow-forever/articles/best-pvp-specs",
            checked = CHECKED, confidence = "low",
        },
        pvp2 = {
            name = "Feral PvP", spec = "Feral Combat",
            summary = "Feral Combat is rated A for PvP damage; Feral Charge and cat mobility do the work.",
            steps = {
                { from = 10, to = 40, text = "Feral as for leveling down to Primal Bite / Shifting Power." },
                { from = 41, to = 60, text = "Restoration: Heart of the Wild, Naturalist." },
            },
            keyTalents = { "Feral Charge", "Feral Swiftness", "Leader of the Pack", "Primal Bite", "Shifting Power" },
            stats = { "Strength", "Agility", "Stamina", "Hit" },
            source = "https://seemeta.com/en/wow-forever/pvp-tier-list",
            checked = CHECKED, confidence = "low",
        },
        pve = {
            tank = {
                name = "Hybrid Bear/Cat raid", spec = "Feral Combat",
                summary = "Method's recommended raid build tanks and deals damage, taking Predatory Discipline only to reach Shifting Power; main tanks can use the Mono-Bear variant.",
                steps = {
                    { from = 10, to = 40, text = "Feral: Ferocity, Furor, Thick Hide, Feral Instinct, Feral Charge, Predatory Strikes, Predatory Discipline, Leader of the Pack, Rend and Tear, Shifting Power (skip Shredding Attacks and Natural Reaction)." },
                    { from = 41, to = 60, text = "Primal Bite, then Restoration/Balance utility (Nature's Majesty in the single-target variant)." },
                },
                keyTalents = { "Shifting Power", "Rend and Tear", "Predatory Discipline", "Thick Hide", "Leader of the Pack", "Blood Frenzy", "Nature's Majesty", "Feral Swiftness" },
                stats = { "Weapon DPS", "Stamina", "Armor", "Strength", "Hit (to 8%)", "Expertise (to 6.5%)", "Agility", "Crit", "Defense (to 440)" },
                source = "https://www.method.gg/wow-forever/class-guides/feral-tank-druid/talents",
                checked = CHECKED, confidence = "low",
            },
            healer = {
                name = "Restoration", spec = "Restoration",
                summary = "Restoration to Wild Growth with Bloom and Swiftmend; Method's stat section is still a work in progress.",
                steps = {
                    { from = 10, to = 40, text = "Restoration: Heart of the Wild, Naturalist, Bloom, Gift of Nature, Improved Rejuvenation, Swiftmend, Nature's Swiftness, Living Spirit, Improved Regrowth, Wild Growth." },
                    { from = 41, to = 60, text = "Balance: Moonglow, Nature's Splendor (longer HoTs)." },
                },
                keyTalents = { "Wild Growth", "Bloom", "Swiftmend", "Nature's Swiftness", "Living Spirit", "Improved Regrowth", "Nature's Splendor" },
                stats = { "Healing Power", "Intellect", "Spirit", "MP5", "Crit" },
                source = "https://www.warcrafttavern.com/forever/guides/druid-leveling/",
                checked = CHECKED, confidence = "low",
            },
            dps = {
                name = "Mono Cat", spec = "Feral Combat",
                summary = "Pure cat damage with Rend and Tear, Primal Bite and Shifting Power; scales with weapon damage.",
                steps = {
                    { from = 10, to = 40, text = "Feral: Ferocity, Feral Instinct, Sharpened Claws, Predatory Strikes, Blood Frenzy, Leader of the Pack, Rend and Tear, Primal Bite." },
                    { from = 41, to = 60, text = "Shifting Power, then Balance Nature's Majesty or Restoration Heart of the Wild." },
                },
                keyTalents = { "Rend and Tear", "Primal Bite", "Shifting Power", "Blood Frenzy", "Predatory Strikes", "Leader of the Pack" },
                stats = { "Weapon DPS", "Strength", "Agility", "Hit", "Expertise", "Haste", "Spirit" },
                source = "https://www.method.gg/wow-forever/class-guides/feral-dps-druid",
                checked = CHECKED, confidence = "low",
            },
        },
    },
}
