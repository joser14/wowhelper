# WoW Forever talent builds: leveling, PvP, PvE (researched 2026-11-09, rechecked 2026-11-11)

> **Update 2026-11-11:** the first pass below is history. The shipped data (`Builds\Data.lua`, generated from
> `research\builds\<CLASS>.lua` by `research\builds\gen_data.js`) now has exact 51-point lists for 40 builds; per-class sources
> are in `research\builds\<CLASS>.md`. After Blizzard's 2026-11-10 class tuning, Warlock leveling (41/7/3, Wrack at 47) and
> Warlock raid (Affliction Wrack 35/11/5) were rebuilt from Warcraft Tavern, Hunter leveling gained Trueshot Aura (Method),
> and Enhancement Shaman stats now put Strength above Intellect. Details: `research\builds_tuning_2026-11-10.md`.

Data file: `Builds\Data.lua` (`BuildsData[CLASS].leveling / pvp / pvp2 / pve.{tank,healer,dps}`).
All guidance below is summarized in my own words; builds are lists of talent choices from the cited pages.

## Big caveat on data quality

- Forever launched **2026-11-04** (client 1.60.1). The beta was **capped at level 30**, so most leveling guides
  (Warcraft Tavern) publish level-30 builds and promise level-60 builds "at launch". Method.gg updated level-60
  spec guides on 4-9 Nov 2026, but the exact point maps live in calculator widgets, not text; the text only names
  key talents. Icy Veins and Mobalytics pages returned HTTP 403 to text fetches.
- Result: only **Warlock leveling** has an exact, point-by-point order. Everything else is tier-level guidance built
  from the talents the sources name, placed into the real 1.60.1 tree layout. Confidence is marked per build.
- PvP rankings are editorial (no Forever PvP stats exist yet) and disagree between sites.

## How Forever talents work

- **Class talents: classic 3-tree point system, reworked content.** One point per level from 10 to 60 = **51 points**
  (metabot.gg "Talent points explained", 2026-10-29). Each tree has 7 tiers; tier N needs 5*(N-1) points in that tree,
  so tier 3 opens at 20, tier 5 at 30, and the **tier-7 capstone (30 points in tree) at level 40**.
- 381 of 432 talents changed vs Classic (metabot). New capstones: e.g. Warrior Mortal Strike/Bloodthirst/Shield Slam,
  Paladin Light's Vigil/Shieldsworn/Unsealed Wrath, Priest Power Infusion/Prayer of Mending/Shadowform, Shaman
  Lightning Mastery/Rage of the Farseer/Riptide, Mage Arcane Power/Combustion/Ice Barrier, Warlock Wrack/Demonic
  Pact/Incinerate, Druid Moonkin Form/Primal Bite + Shifting Power/Wild Growth, Rogue Mutilate/Adrenaline Rush/Death Mark,
  Hunter Bestial Wrath/Sniper Shot/Lacerating Strikes. Curses are now "Banes" for warlocks (Improved Bane of Agony).
- **Dual Talent Specialization** at level 40 from the class trainer. Respec at the trainer for gold (launch price unpublished).
- **Legacy Tree (separate, account-wide).** Tabs Professions / Adventure / Resourcefulness, bought with Legacy Points
  earned e.g. for reaching 25/45/60 on each class. "Working Overtime" (+tradeskill skill-up chance) and
  "Frequent Flier" are **Legacy talents, not class talents**. Others named in guides: Talented (talents unlock up to
  5 levels early, starting at 9; still max 51 class points), Gourmand, Permanence, Reagent Economy, Well Rested.
  (Warcraft Tavern Legacy Tree article, 2026-09-13; Method feral tank talents page, 2026-11-04.)
- **Races/factions:** both factions get all nine classes. Alliance gets **Shaman via Dwarf** only; Horde gets Undead
  Paladins; new Skyborne race (Alliance "High Order": Warrior, Hunter, Rogue, Druid, Mage). Night Elves can be
  Warrior, Hunter, Rogue, Priest, Druid (+ any new combos – check the character screen). (metabot beginner's guide;
  method.gg race/class combos.)

### Client API for reading spent talents (from uisrc2)
The shipped API docs include **C_ClassTalents** (retail loadout/trait API, `Environment = "All"`, with hero-talent
functions — almost certainly inherited, not how Forever's 3-tree UI works) and **C_SpecializationInfo.GetTalentInfo(query)**
where `query = { specializationIndex = tab, talentIndex = i, groupIndex = activeGroup }` returns
`{ name, tier, column, rank, maxRank, spellID, known, ... }`, plus `C_SpecializationInfo.GetActiveSpecGroup()`.
The classic globals `GetNumTalentTabs/GetTalentTabInfo` (already used by ItemAdvisor) and `GetNumTalents/GetTalentInfo(tab, i)`
are not in the generated docs (they are C globals not documented there); use them with `pcall` and fall back to
`C_SpecializationInfo.GetTalentInfo`. The Legacy Tree is likely a C_Traits tree (SharedTraits doc is present); not verified.

## Shared leveling tips (Forever-specific, all classes)
- Cooked food's Well Fed buff now gives bonus kill XP: keep it up. Campfires/Camping give extra buffs (pets too, if summoned at camp).
- Professions give leveling perks (e.g. Enchanting wands/oils, Tailoring soulbound gear, Blacksmithing spell-power BoPs for paladins).
- HoTs/DoTs update with current stats as they tick (priest guide note).
- Talented (Legacy) moves every milestone below up to 5 levels earlier.

---

## Warrior
- **Leveling – Arms** (all trees viable; Prot good at AoE). 10-14 Deflection; 15-19 Improved Tactical Mastery, Improved Overpower;
  20-24 Anger Management, Deep Wounds; 25-29 Two-Handed Weapon Specialization (Spearing Strike optional), Impale;
  30-39 Weaponmaster/Bloodthrill, Sweeping Strikes, Improved Slam; 40 Mortal Strike; then Improved Hamstring and Fury Cruelty.
  Lexd (Mobalytics) advises respeccing at 40 for Mortal Strike if you went early Cruelty. Train: Victory Rush 20, Execute 24,
  Berserker Stance quest 30, Whirlwind 36. Tips: slow weapons for rage, stance-swap freely, spend cooldowns to pull more.
  Stats: weapon DPS > Str > Sta > Agi > Armor. Source: warcrafttavern.com/forever/guides/warrior-leveling (no date shown; read 2026-11-09). **Medium.**
- **PvP – Arms** (seemeta A; Kargoz Arms > Prot > Fury; skycoach B; Fury rated D). Arms to Mortal Strike + Improved Hamstring, Fury Cruelty/Piercing Howl. **Low.**
- **PvE DPS – Fury raid** (Method, 2026-11-04): Fury Bloodthirst, Flurry, Death Wish (+Cruelty, Unbridled Wrath, Furious Precision,
  Enrage, Dual Wield Spec from WT); Arms Deep Wounds, Impale, Improved Overpower for stance dancing. Stats: Hit to 8% > Crit > Haste > Str > Agi > Sta. **Medium.**
- **PvE Tank – Protection raid** (Method, 2026-11-04): deep Prot to Shield Slam; skip Improved Thunder Clap/Sunder/Shield Bash/Charge;
  Arms Deep Wounds + Impale. Dungeon variant takes Fury Enrage. Stats: Sta > Expertise 6.5% > Hit 8% > Defense 440 > Armor > Crit > Agi. **Low.**

## Paladin (Alliance: Human, Dwarf)
- **Leveling – Retribution** for the first 20-30 levels, then Ret/Prot/Shockadin by taste. Seal of Command at 20 (replace Seal of
  Righteousness), Two-Handed Weapon Spec, Sacred Arbiter, Vengeance (Repentance optional), Champion of the Light, Unsealed Wrath at 40.
  New baseline: Holy Strike 6, Seal of Fury 10, Templar's Bulwark. Stats early: Str/AP > Sta > Spell Power > Armor; Prot/Shockadin: SP > Sta > Int.
  WT shows builds only as images. Source: warcrafttavern paladin-leveling. **Low.**
- **PvP – Holy** (seemeta A healer, Kargoz, Method "formidable in PvP"); alt **Retribution** (skycoach S). **Low.**
- **PvE Healer – Holy** to Light's Vigil (Method 2026-11-04 stats: Healing > Int > Crit > MP5 > Spirit > Haste). **Low** (talents not in text).
- **PvE Tank – Protection** to Shieldsworn; variants Sacred Arbiter / Improved Seals / Shock Prot (Method 2026-11-09).
  Stats: Defense 440 > Sta > Hit 8% > Expertise > Spell Power > Block > Crit. **Low.**
- **PvE DPS – Deep Retribution** to Unsealed Wrath (Champion of the Light, Sacred Arbiter, Conviction); Holy Shock DPS variant.
  Stats: Hit 8% > Expertise 6.5% > Spell Power > Str = AP > Int > Crit (Method 2026-11-09). **Low.**

## Hunter
- **Leveling – Beast Mastery** (WT "recommended"). Bestial Swiftness/Unleashed Fury ~20, Ferocity + Summon Hawk 25, Intimidation +
  Bestial Discipline 30, Bestial Wrath 40; then Marksmanship (Efficiency, Careful Aim). Avoid Lone Wolf while leveling.
  Stats: Agi > AP > Crit > Int > Sta/Spi. Tips: pets get camp buffs; Herbalism gives a camp Int buff; Cheetah dazes on hit. **Medium.**
- **PvP – Beast Mastery** (Intimidation, Bestial Wrath) or **Marksmanship** (Scatter Shot, Improved Concussive Shot) – both A on seemeta. **Low.**
- **PvE DPS – Marksmanship** (Method 2026-11-05: "likely best endgame"): Mortal Shots, Ranged Weapon Spec, Barrage, Lone Wolf or pet
  build, Careful Aim. Stats: **Agility = Intellect (with Careful Aim) > Strength.** BM is called "easiest and strongest" right now. **Low.**

## Rogue
- **Leveling – Combat** (WT offers Combat, Subtlety Ambush/Bleed; Assassination not advised to start). Precision 15, Riposte 20,
  Flawless Execution/Aggression/Weapon Expertise 25, Dual Wield Spec/Blade Flurry/Hack and Slash 30, Flash of Steel 35, Adrenaline Rush 40.
  Tips: Shank is a baseline builder for all specs; combo points don't carry over; Stealth slows you; poisons stack with stones/Windfury.
  Stats: Crit > Agi > AP > Str > Sta. **Medium.**
- **PvP – Subtlety** (S on seemeta and skycoach): Preparation, Elusiveness, Premeditation, Opportunity, Camouflage, Quick Getaway. **Low.**
- **PvE DPS – Combat (Sinister Strike)**; alt Combat Mutilate / Assa Shank. Stats: Weapon DPS > Hit = Expertise > Agi > Crit > Str > Sta (Method 2026-11-04). **Low.**

## Priest
- **Leveling – Discipline to 39, Shadow from 40** (Method 2026-11-06; WT agrees Disc is the general path). Inner Focus 20, Penance 30,
  respec at 40 for Shadowform. Wand is the key slot until 40. Stats: Int/Spell Damage > Sta/Spirit > Armor. **Medium.**
- **PvP – Shadow** (seemeta S: Silence, Shadowform) or **Discipline** healer (skycoach S: Shield, Penance). **Low.**
- **PvE Healer – Holy 18/33/0** (WT holy-priest, level-60 build image "October 15 patch"): Holy to Prayer of Mending with Improved Renew,
  Holy Binding, Spiritual Guidance, Litany of Light, Spiritual Healing; Discipline to Meditation. Stats: Healing > Int > MP5 > Spirit > Crit. **Medium.**
- **PvE DPS – Shadow** (Method 2026-11-04; Mobalytics projection 14/2/35 seen only in a search snippet). Dark Inspiration gives party mana;
  Divine Spirit is now baseline. Stats: Hit cap > Spell Damage > Crit > Int > Spirit. **Low.**

## Shaman (Alliance: Dwarf only — not available to a Night Elf)
- **Leveling – Enhancement** (WT "strongest"). Stormstrike 25, Improved Ghost Wolf (instant, indoors), Maelstrom Weapon, Rage of the Farseer 40.
  Dual spec at 40 for Resto. Tips: Astral Recall is a 15-min second hearth; level-30 Call of Air quest gives a spec weapon.
  Stats: Hit/Expertise > Str > Int > Crit > Spell Damage > Agi. **Medium.**
- **PvP – Enhancement** (skycoach A, ExitLag top); seemeta prefers Elemental (A) and rates Enh B. **Low.**
- **PvE Healer – Restoration** to Riptide (Mindfulness, Water Shield, Mana Tide, Ancestral Healing, Tidal Mastery, NS). WT build is level-30
  beta. Stats: Healing > Spirit > Int > Crit > Haste (WT notes this order is provisional). **Low.**
- **PvE DPS – Enhancement**; Stats Hit 8% (to 17% for spells) > Str > Int > Crit = Agi > Spirit = MP5 (Method 2026-11-09).
  Elemental: Hit 17% > Spell Power > Crit > Int > MP5 > Spirit. Enhancement can off-tank with Rockbiter (WT comment-level info). **Low.**

## Mage
- **Leveling – Frost with 7 Arcane** (WT): Improved Frostbolt 10; Missile Barrage/Arcane Concentration + Frostbite/Ice Shards 15;
  Frost Channeling + Ice Lance 20; Shatter + Ice Block 25; Cold Snap + Fingers of Frost 30; Winter's Chill 35; Ice Barrier 40.
  Tip: fish for Missile Barrage with rank-1 Frostbolt before Ice Lance. Stats: SD > Int > MP5 > Sta > Spi. **Medium.**
- **PvP – Frost** (seemeta S: Ice Block, Ice Barrier); skycoach prefers Arcane. **Low.**
- **PvE DPS – Fire (Fireball/Arcane)** with Ignite, Heating Up, Improved Scorch, Combustion (Method 2026-11-09). Frost (CoC + Meditation)
  is sturdier but lower damage. Stats: Hit > SD > Crit > Haste > Spell Pen > Int > Spirit. **Low.**

## Warlock
- **Leveling – Affliction, exact order** (WT warlock-leveling): 10-19 Improved Corruption 5, Suppression 5; 20-26 Unholy Power 5,
  Demonic Energies 2 (Demonology); 27-30 Improved Drains 3, Amplify Curse; 31-40 Improved Bane of Agony 2, Improved Life Tap 2, Pandemic 3,
  Soul Siphon 3; 41-60 Malevolence 5, Shadow Mastery 5, Siphon Life, Fel Concentration 3, Nightfall 2, Improved Shadow Bolt 4 (= 51).
  No respec needed. Tips: multi-DoT with a focus target, Drain Life tanking from 30, Fear is 20 yd. Stats: SP/Shadow > wand (to 30) > Spi/Int > Sta. **Medium**
  (within-band order is my sequencing of WT's grouped list).
- **PvP – Demonology Soul Link** (S on seemeta and skycoach: Soul Link, Demonic Embrace, plus Siphon Life, Molten Skin). **Low.**
- **PvE DPS – Affliction (Wrack)** best single target per WT (updated 2026-11-03); Shadow Mastery/Ruin close. Stats: Hit 17% > SD > Shadow >
  Spell Pen > Crit > Int > Haste (Method 2026-11-04). **Low.**

## Druid
- **Leveling – Feral cat** (WT): Feral Charge 20, Lacerate + Predatory Discipline 25, Leader of the Pack 30, Primal Bite/Shifting Power 40;
  skip Shredding Attacks. Tips: use consumables in form; Travel Form at 30; Idol of Shifting Tides from the Aquatic quest; feral scales with weapon damage.
  Stats: Str/Agi/AP > Sta/Int/Spi > Armor. **Medium.**
- **PvP – Restoration** (skycoach S, seemeta A) or **Feral** (seemeta A). **Low.**
- **PvE Tank – Hybrid Bear/Cat** (Method 2026-11-04; Mono-Bear for main tanks). Shifting Power via Predatory Discipline, Rend and Tear;
  avoid Natural Reaction. Stats: offense Weapon DPS > Str > Hit 8% > Expertise 6.5% > Crit > Haste; defense Sta = Armor > Agi > Dodge > Defense. **Low.**
- **PvE Healer – Restoration** to Wild Growth (Bloom, Swiftmend, NS, Living Spirit). Method stats are "work in progress". **Low.**
- **PvE DPS – Mono Cat**: Weapon DPS > Str > Agi > Hit > Expertise > Haste > Spirit (Method 2026-11-04). **Low.**

---

## ItemAdvisor weights vs sources (ItemAdvisor\ItemAdvisor.lua PROFILES; ratings converted with its RATING_PER_PERCENT)

| Profile | Disagreement |
|---|---|
| warrior | Method puts **Hit to 8% first**; IA values 1% hit (2×10=20 AP) below 1% crit (3×14=42) and 1% haste (26). IA gives Expertise the top per-% value (50) but Method lists no Expertise for Arms/Fury. |
| tank (shared warrior/paladin/druid) | Prot paladin wants **Spell Power** (rank 5) — tank profile has no `dmg`. Bear wants **weapon DPS and Strength first** offensively; tank `melee=8` is low. Prot warrior lists no Strength; IA str=1.5. Defense (440 soft cap) is #1 for paladins, #4 for warriors. |
| retribution | Method: Hit > Expertise > **Spell Power > Str**. IA dmg=0.5 vs str=2.2 (SP far too low) and crit=3 (42/1%) though crit is last. |
| hunter / survival | MM/BM with Careful Aim: **Agility = Intellect**. IA int=1 vs agi=4.5. |
| shadow | IA spi=1.1 > dmg=1 and hit=0.5. Method: **Hit cap > Spell Damage > Crit > Int > Spirit**. Spirit-first only fits leveling (Spirit Tap). |
| mage / warlock | Order matches, but **Spell Penetration** is ignored by IA (IGNORED_KEYS) while Method ranks it above Int (warlock: until targets have 0 resistance). |
| healer | Holy Paladin: Crit #3, Spirit #5 — IA weights spirit = int and crit low. Priest/Shaman orders roughly match. |
| enhancement | Method: Hit (to 17%) > Str > Int > Crit = Agi; no Expertise listed. IA exp=3 equals hit; crit=3 (42/1%) is above Str. |
| feral (cat) | Method ranks **Weapon DPS #1**; IA feral profile has **no `melee` weight**. |
| rogue | Broadly matches (Weapon DPS > Hit = Expertise > Agi > Crit); IA weights Expertise (50/1%) above Hit (35/1%) where Method has them equal. |

Leveling-stat lists from the WT leveling guides (Stamina/Armor high, Spirit for casters) fit IA's leveling bias.

## Sources (all read 2026-11-09)
- Warcraft Tavern Forever guides: `/forever/guides/{class}-leveling/`, `/forever/guides/warlock/` (upd. 2026-11-03), `/fury-warrior/`, `/holy-priest/`, `/restoration-shaman/`, `/classes/`; Legacy Tree news 2026-09-13.
- Method.gg Forever class guides and `/talents` subpages (updated 2026-11-04 to 2026-11-09, patch 1.60.1); priest leveling 2026-11-06.
- metabot.gg: talent calculators per class (tree layout, 1.60.1.70790), talent points explained (2026-10-29), beginner's guide.
- seemeta.com PvP tier list (2026-11-08); skycoach.gg best PvP specs (2026-11-06); rankedboost new talents (beta build 1.60.1.70790); powerupgaming talent changes (2026-09-14).
- Blocked (403): icy-veins.com/wow-forever, mobalytics.gg (Kargoz PvP, Lexd Arms, shadow priest/fire mage projections seen only in search snippets).
