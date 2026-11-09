# Warrior builds, WoW Forever 1.60.1 (second pass, researched 2026-11-09)

Data: `research\builds\WARRIOR.lua` (replaces `BuildsData.WARRIOR`). Every build is now a full 51-point
`points` list. Summaries are my own words; builds are talent facts taken from the cited calculators.

## How the builds were decoded (applies to WARRIOR, PALADIN and HUNTER)

Guides publish builds as calculator widgets/links, not text. Three formats were decoded (read in the
built-in browser as page text/DOM only; no sign-in, no forms):

1. **Icy Veins** (`/wow-forever/<class>-talent-calculator#tc-<string>~70755-<datahash>`). Each character is
   one talent point, in the order the author clicked; the character is the talent's `data-talenturlid`,
   read from the calculator DOM (`input[data-talenturlid]` + its label's `<h3>` name, `data-talent-requiredpoints`,
   `max`). So the string is an exact ordered point list (point i = level 10+i). Leveling-guide strings are in
   level order (they match the guide text, e.g. Warrior "Reckless Swings at 56" = character 47).
2. **Method.gg** (`<div class="forever-talents" data-talent="<loadout>;<order>">`). The part after `;` is the
   ordered point list; each character is a base64 index (A-Z a-z 0-9 + /) into all of the class's talent nodes
   from `/dfc/ForeverTalentsData-1.60.1-2nov.json`, pooled across the three tabs and sorted by numeric node id
   (logic read from `/dfc/ForeverTalents.min.js`, function `u()`). Nodes carry no names, so I matched them to
   Icy Veins by tree + grid slot (row*4+col, row = (y-2130)/600, col = (x-[1020,5020,9080][tab])/600); spell IDs
   agree between the two sites for every node checked.
3. **Warcraft Tavern** (`/forever/tools/talent-calculator/<class>#?t=<string>`): upper-case A/B/C switch tree,
   other characters are grid slots in base 36. The WT calculator page itself prints the "Talent Order" with
   names, which I read directly.

Scripts (scratchpad, not shipped): `ivdecode\maps.js` (Icy Veins id tables for the three classes),
`decode.js` (decode + validate tier gates and max ranks), `decode_method.js`, `gen.js` (writes the .lua).
Every list was validated: 51 points, no rank over max, no point before its tier opens (5 per tier in that
tree). Where a PvE calculator string was clicked out of tier order (author error, not a leveling order), I
re-sequenced only the affected points by hand into a legal order with the same totals; flagged per build.
Prerequisite arrows are not modelled by the checker, but every re-sequence keeps the source's relative order
within a talent chain.

## Builds chosen

| Goal | Build | Split (A/F/P) | Source (date) | Order | Confidence |
|---|---|---|---|---|---|
| leveling | Arms (2H, Bloodthrill) | 33/16/2 | Icy Veins arms-warrior-leveling (upd. 2026-11-04) | exact, author's | high |
| pvp | Arms battleground | 35/16/0 | Mobalytics, Omnivore's Arms Warrior PvP Guide (2026-11-07) | totals exact, order mine | medium |
| pve.dps | Fury dual wield | 17/34/0 | Method fury-warrior/talents (upd. 2026-11-04) | exact, author's | high |
| pve.tank | Protection Shield Slam (raid) | 17/3/31 | Method protection-warrior/talents, Standard Raid Build (2026-11-04) | author's 10-40; 41-60 re-sequenced | high |

### Leveling – Arms (Icy Veins)
Levels: 10-12 Improved Rend, 13-14 Deflection, 15-16 Improved Overpower, 17-18 Improved Charge, 19-21 Improved
Tactical Mastery, 22 Anger Management, 23-24 Deep Wounds, 25 Spearing Strike, 26-28 Two-Handed Weapon Spec,
29 Deep Wounds 3, 30 Sweeping Strikes, 31-32 Bloodthrill, 33-34 Weaponmaster, 35-36 Improved Slam,
37-39 Weaponmaster 5, 40 Mortal Strike, 41-45 Cruelty, 46-50 Lingering Rage, 51-55 Enrage, 56 Reckless Swings,
57-58 Improved Bloodrage, 59-60 Impale.
- Method's warrior leveling guide (2026-11-04) decodes to nearly the same path (34/15/2: Deflection 5/5 and
  Improved Charge earlier, no Impale/Reckless Swings). Method also has a Protection leveling path. Agreement on
  everything through 40 → high confidence.
- Warcraft Tavern's leveling page still only shows the level-30 beta builds (images) – superseded.

### PvP – Arms (Omnivore, Mobalytics)
Totals: Arms Improved Rend 3, Deflection 5, Improved Tactical Mastery 3, Improved Overpower 2, Anger Management,
Deep Wounds 3, Spearing Strike, Two-Handed Weapon Spec 3, Impale 2, Bloodthrill 2, Sweeping Strikes,
Weaponmaster 5, Improved Hamstring 3, Mortal Strike; Fury Booming Voice 5 (it now also improves Piercing Howl),
Cruelty 5, Piercing Howl, Enrage 5. Author skips Improved Heroic Strike, Improved Charge, Improved Slam and Blood Craze.
- The guide has a "Leveling Path" toggle but it was empty for this build, so the order is mine: Arms in the
  Icy Veins leveling order to Mortal Strike at 41, Improved Hamstring 42-44, then Fury.
- Older Mobalytics PvP pages cited in the first pass (Lexd, Kargoz) now return HTTP 410 (archived).
- Variant on the same page: "Arms + Iron Will & Last Stand" for world PvP (not decoded; no ranks in text).

### PvE DPS – Fury (Method, Icy Veins agree)
Method 17/34/0: Fury Cruelty 5, Unbridled Wrath 5, Furious Precision 3, Enrage 4, Dual Wield Spec 5, Reckless
Swings, Improved Execute 2, Death Wish, Improved Berserker Rage 2, Flurry 3, Improved Whirlwind 2, Bloodthirst;
Arms Improved Rend 3, Improved Heroic Strike 3, Improved Tactical Mastery 3, Improved Overpower 2, Deep Wounds 3,
Anger Management, Impale 2. Method's order is Fury first (Bloodthirst at 40), so it doubles as a Fury leveling path.
- Icy Veins Fury (18/33/0, 2026-11-04) differs only in Spearing Strike + Enrage 5/5 instead of Improved Execute
  2/2 – and its own text names that swap as the alternative if Enrage uptime is low. Arms raid build
  (Icy Veins 32/17/2, Method 32/19/0) exists for players who prefer two-handers; both sites present Fury as the
  dual-wield raid default.

### PvE Tank – Protection (Method raid; Icy Veins same Protection tree)
Protection 31: Shield Specialization 5, Anticipation 5, Improved Revenge 3, Master of Defense 2, Last Stand,
Defiance 3, Vanguard, Concussion Blow, Improved Shield Wall 2, Focused Rage 2, Bastion 5, Shield Slam.
Arms 17: Deflection 5, Improved Rend 3, Deep Wounds 3, Impale 2, Improved Tactical Mastery 3, Anger Management.
Fury: Cruelty 3. Method's string takes Deep Wounds/Impale before their Arms tier opens; I re-sequenced the
Arms points (Deflection 41-45, Improved Rend, Improved Tactical Mastery, Deep Wounds 52-54, Anger Management,
Impale 56-57, Cruelty 58-60). Protection 10-40 is Method's own order.
- Icy Veins (5/15/31) takes the identical 31 Protection points; off-tree Deflection 5 + Fury Cruelty 5,
  Lingering Rage 5, Enrage 5. Method's dungeon build goes Fury first (Cruelty/Unbridled Wrath/Enrage) with
  Improved Thunder Clap and Improved Shield Bash.

## Stats (for ItemAdvisor)
- Fury: Icy Veins **Weapon DPS > Hit (8% special-attack cap) > Expertise (6.5% from behind) > Crit > Strength**,
  Haste/Agility/AP compared against crit/str. Method (first pass): Hit > Crit > Haste > Str > Agi. Both put Hit
  first – ItemAdvisor's warrior profile still values 1% hit below 1% crit and haste (see builds_forever.md).
  Icy Veins does list Expertise (Method did not), so IA's high Expertise weight is defensible for Fury.
- Protection: Icy Veins offensive **Expertise > Hit > Agility > Strength > Stamina**, defensive **Stamina > Armor >
  Agility > Avoidance > Defense**. Method: Sta > Expertise > Hit > Defense 440 > Armor > Crit > Agi. Both value
  Agility above Strength for warrior tanks; Defense is low for warriors (unlike paladins).
- Arms leveling: weapon first, then Hit/Expertise/Crit/Strength (Agility gives warriors no AP).

## Gaps / risks
- Warcraft Tavern shows "Class Tuning Incoming – 10 November" in its blue-post feed; builds may shift next week.
- No warrior source states it was written from level-60 play; all are launch-day (2026-11-04) guides.
- Sources not usable: Mobalytics Lexd/Kargoz pages (410), Warcraft Tavern warrior pages (level-30 images only).
