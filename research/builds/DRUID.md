# Druid builds, WoW Forever 1.60.1 (second pass, read 2026-11-09)

Data: `research\builds\DRUID.lua` (replaces `BuildsData.DRUID`). Every build except the steps-based one is a full
51-point list `{ level, talent, tree, rank }`, validated against the tree (tier = points needed in that tree, max rank).
Splits are Balance/Feral/Restoration.

## How the builds were read (decoding method, applies to all three classes)

- **Warcraft Tavern (WT)** guides link `warcrafttavern.com/forever/tools/talent-calculator/<class>#?t=<code>`.
  Code = a tree letter (`A`/`B`/`C` = 1st/2nd/3rd tab) followed by one character per talent point **in the order
  clicked**; a new letter switches tree. Each character is a per-tree talent index (`0-9a-z`, not the on-screen order:
  the index has gaps). I decoded by loading the calculator in the browser pane and setting the hash to every prefix
  of the code, recording which talent's rank went up at each step. Two cautions found:
  the calculator silently **rejects** a point whose tier is not yet unlocked (so some author orders lose a point,
  e.g. WT's Fire mage link drops Combustion), and some links are in tree order, not leveling order.
- **Icy Veins (IV)** embeds `druid-talent-calculator#tc-<code>~70755-<hash>` (70755 = client build). Each character
  is one point on the talent whose `data-talenturlid` equals it (read from the rendered tree inputs). On leveling pages
  (`data-talentcalculator-includehistory="1"`, level slider) the order is the leveling order; on PvE pages it is not
  always a valid order. IV inputs also expose `data-talent-requiredpoints` = the tier gate, used for validation.
- **rankedboost** tree buttons have aria-labels `"<Talent>, rank N of M. Requires X points in <Tree>"`; Mobalytics
  shows ranks positionally (matched to the IV tree order, which has identical max ranks per position).
- Where a source gives ranks but no order, the order in the .lua is mine (tier-legal, core talents first) and the
  summary says so.

## Tree (1.60.1, tier gate in points)
Balance: Improved Wrath 5, Genesis 5 (0) · Moonglow 3, Improved Moonfire 2, Nature's Majesty 2, Nature's Reach 2 (5) ·
Improved Entangling Roots 3, Nature's Splendor 1 (10) · Insect Swarm 1, Vengeance 5, Improved Starfire 5 (15) ·
Overgrowth 2, Nature's Grace 1, Eclipse 3 (20) · Moonfury 5 (25) · Moonkin Form (30).
Feral Combat: Ferocity 5, Furor 5 (0) · Feral Swiftness 2, Feral Instinct 3, Brutal Impact 2, Thick Hide 3 (5) ·
Shredding Attacks 3, Savage Fury 2, Feral Charge 1, Sharpened Claws 2 (10) · Predatory Strikes 3, Lacerate 1,
Predatory Discipline 1, Blood Frenzy 2 (15) · Leader of the Pack 1, Natural Instinct 2 (20) · Rend and Tear 5,
Natural Reaction 5 (25) · Primal Bite 1, Shifting Power 1 (30).
Restoration: Nature's Focus 5, Heart of the Wild 5 (0) · Naturalist 5, Reflection 3, Natural Shapeshifter 3 (5) ·
Subtlety 3, Gift of Nature 5, Bloom 1 (10) · Tranquil Spirit 5, Improved Rejuvenation 3, Swiftmend 1 (15) ·
Nature's Swiftness 1, Living Spirit 3, Improved Tranquility 2 (20) · Improved Regrowth 5 (25) · Wild Growth (30).

## Builds chosen

| Slot | Build | Split | Order | Confidence | Why |
|---|---|---|---|---|---|
| leveling | WT Feral leveling | 9/37/5 | exact (WT link) | high | WT and IV feral leveling share the same 32 Feral points in nearly the same order; they differ only in the last 5 (WT Furor, IV Naturalist). |
| pvp | rankedboost Restoration PvP | 0/11/40 | mine | low | Only published Forever druid PvP point map. Resto is S/A on skycoach/seemeta. IV PvP lists are still "TBD". |
| pvp2 | WT hybrid used for feral PvP | 9/37/5 | exact | low | No feral PvP build is published; hybrid keeps bear survivability + Feral Charge. |
| pve.tank | WT Hybrid Bear/Cat | 9/37/5 | exact | high | WT, IV and Method all lead with a hybrid; WT and IV differ by a few points (below). |
| pve.healer | WT Restoration | 13/0/38 | exact | medium | IV default differs in Balance filler; both agree on the Resto core. |
| pve.dps | IV Cat DPS | 8/33/10 | mine | medium | Only exact mono-cat build; matches Method's mono-cat talent notes. |

Feral leveling milestones in the chosen order: Feral Charge 20, Predatory Discipline 25, Lacerate 26,
Leader of the Pack 30, Rend and Tear 35-39, Shifting Power 40, Primal Bite 41, then Heart of the Wild, Genesis,
Nature's Reach, Nature's Majesty, Furor (56-60). Skips Shredding Attacks (WT: you rarely Shred solo).

## Other exact builds found (not in the .lua)

- **WT Balance multi-DoT leveling** 43/0/8 order: Improved Wrath 5, Moonglow 3, Nature's Majesty 2, Nature's Reach 2,
  Improved Moonfire 2, Nature's Splendor, Insect Swarm, Improved Entangling Roots 3, Genesis 1, Overgrowth 2, Genesis 4,
  Moonfury 4, Moonkin Form (40); Heart of the Wild 5, Reflection 3, Moonfury 5th, Vengeance 5, Nature's Grace, Improved Starfire 5.
- **WT Balance Eclipse leveling** 38/0/13: as above to Insect Swarm, then Improved Starfire 4, Eclipse 3, Improved Starfire,
  Nature's Grace, Moonfury 5, Moonkin Form (40); Nature's Focus 5, Reflection 3, Vengeance 5, Heart of the Wild 5, Genesis 2.
- **WT Restoration leveling** 13/0/38: Heart of the Wild 5, Reflection 3, Naturalist 5, Gift of Nature 2, Swiftmend, Gift of
  Nature 3, Bloom, Living Spirit 3, Nature's Swiftness, Tranquil Spirit 5, Improved Rejuvenation 3, Wild Growth (42);
  Genesis 5, Nature's Majesty 2, Improved Wrath 3, Nature's Splendor, Improved Wrath 2, Nature's Focus 5. (WT: not recommended for leveling.)
- **WT Balance raid** 41/0/10 (`balance-druid`): Improved Wrath 5, Genesis 5, Moonglow 3, Improved Moonfire 2, Nature's Majesty 2,
  Nature's Reach 2, Nature's Splendor, Insect Swarm, Vengeance 5, Improved Starfire 5, Nature's Grace, Eclipse 3, Moonfury 5,
  Moonkin Form; Heart of the Wild 5, Reflection 3, Nature's Focus 2. **IV Balance default** is the same Balance 41 with
  Nature's Focus 5 + Naturalist 5 in Restoration. Two sources agree, so a Balance DPS build could be added with high confidence
  (the shape has one `dps` slot; I kept Cat because the player levels feral).
- **IV Hybrid** 8/33/10: WT's Feral 37 without Shredding Attacks 3 and Blood Frenzy 2, with Thick Hide 3 (not 2); Balance Genesis 5,
  Nature's Majesty 1, Nature's Reach 2; Restoration Heart of the Wild 5, Naturalist 5.
- **IV Bear Tank Only** 9/32/10: drops Predatory Discipline and Shifting Power, adds Blood Frenzy 1, Nature's Majesty 2.
- **IV leveling (feral)** order: Ferocity 5, Feral Instinct 3, Feral Swiftness 2, Feral Charge, Savage Fury 2, Sharpened Claws 2,
  Lacerate, Blood Frenzy 2, Predatory Discipline, Predatory Strikes, Leader of the Pack, Natural Instinct 2, Predatory Strikes 2,
  Rend and Tear 5, Primal Bite, Shifting Power, Heart of the Wild 5, Naturalist 5, Genesis 5, Nature's Reach 2, Nature's Majesty 2.
- **rankedboost** also lists Feral leveling 0/38/13 (with Natural Reaction 5, Furor 5, Naturalist 5) and Resto healing 6/0/45.
  rankedboost reads as auto-generated; used only where nothing better exists.

## Disagreements
- Hit cap for feral: IV says 8% (6.5%/14% Expertise), WT says 9% for raid bosses. Both note Nature's Reach covers 4%.
- Cat stat order: IV/Method put **Weapon DPS first**; WT starts at Hit > Expertise > Crit > Haste > Agi > Str. Method puts
  Strength above Agility, IV Agility above Strength. I used Weapon DPS > Hit > Expertise > Agi > Str.
- Bear mitigation: IV Armor > Defense(440) > Sta > Agi > Dodge; WT Defense(440) > Dodge > Armor > Sta;
  Method Sta = Armor > Agi > Dodge > Defense. No consensus; Armor/Stamina/Defense lead in all three.
- Resto: IV Healing > Int > Spirit > MP5 > Crit; WT Healing > Spirit > Haste > Crit > Int (both say provisional).

## Sources (read 2026-11-09)
- https://www.warcrafttavern.com/forever/guides/druid-leveling/ (Luxrah; no date shown, sidebar posts to 2026-11-08)
- https://www.warcrafttavern.com/forever/guides/feral-druid/ , /restoration-druid/ , /balance-druid/
- https://www.icy-veins.com/wow-forever/feral-druid-melee-dps-and-tank-pve-spec-builds-talents (Meyra, 2026-11-04),
  /feral-druid-leveling, /balance-druid-leveling, /restoration-druid-leveling, /balance-druid-ranged-dps-pve-spec-builds-talents,
  /restoration-druid-healer-pve-spec-builds-talents, /*-stat-priority (all Last Updated 2026-11-04)
- https://rankedboost.com/world-of-warcraft/forever/build/druid/ (updated 2026-11-04)
- https://www.method.gg/wow-forever/class-guides/feral-tank-druid/talents (2026-11-04), method druid leveling (2026-11-07, no point map)
- PvP ratings: skycoach.gg best PvP specs (2026-11-06), seemeta.com PvP tier list (2026-11-08); IV PvP tier lists still TBD (2026-10-26).
- Not found: any Forever druid PvP guide from WT/IV/Method/Mobalytics/Wowhead; Mobalytics has no druid PvP guide.
