# Rogue builds – second pass (researched 2026-11-09)

Data: `research\builds\ROGUE.lua` (replaces `BuildsData.ROGUE`). Every build is now an exact 51-point order,
validated against the 1.60.1 tree (tier gates, max ranks, Lethality needs Malice 5, Mutilate needs Venom).

| Slot | Build | Split (A/C/S) | Source (date) | Order | Confidence |
|---|---|---|---|---|---|
| leveling | Combat leveling | 16/35/0 | Method rogue leveling (upd. 2026-11-07) | from source | high |
| pvp | Backstab PvP (Perplexity "Backstab Standard") | 16/14/21 | Mobalytics rogue-pvp-guide (2026-11-04) | from source | medium |
| pvp2 | Hemorrhage PvP (Perplexity "Hemorrhage Standard") | 16/7/28 | same | from source | medium |
| pve.dps | Combat Sinister Strike | 16/35/0 | Icy Veins combat spec-builds (2026-11-04) | from source | high |

## Why these
- **Leveling – Combat.** Method (07 Nov), Warcraft Tavern and Icy Veins all open Remorseless Attacks or
  Efficient Strikes → Coup de Grace → Deflection/Precision → Riposte at 20-22, and reach Adrenaline Rush at 40-42.
  Picked Method because it is the newest and has a full order. Differences: WT finishes 15/36 with Composure 2;
  Icy Veins gets Adrenaline Rush at 40 then takes Remorseless Attacks late.
  Alternatives published with exact orders: WT Assassination (36/10/5, Mutilate at 40), WT Subtlety Ambush (15/5/31),
  WT Subtlety Bleed (13/3/35), Method Assassination-Backstab and Subtlety-Ambush, Icy Veins Assassination 31/15/5 and
  Subtlety 15/5/31.
- **PvP – Subtlety hybrids.** Seemeta and Skycoach rate Subtlety top; Mobalytics' PvP guide (author Perplexity,
  "Verified") gives four complete 60 builds with orders; I took the default "Backstab Standard" (author: usable
  for everything) and the deeper "Hemorrhage Standard". The author drops Relentless Strikes for PvP (calls it
  nerfed) and values Improved Gouge, Remorseless Attacks, Lethality, Vigor and Blood Splatter. RankedBoost's
  "Subtlety Rogue PvP Build" is 5/17/29 (Lightning Reflexes 5, Improved Kick 2, Setup 3, Heightened Senses 2)
  – ranks only, no order. Mobalytics also has "Backstab BG" 14/12/25 and "Mutilate Standard" 32/10/9.
- **PvE DPS – Combat 16/35/0.** Icy Veins, Warcraft Tavern and RankedBoost publish the same split: Combat to
  Adrenaline Rush + Flash of Steel 5, Assassination Malice 5, Ruthlessness 3, Improved Slice and Dice 3, plus
  Improved Expose Armor / Lethality / Cold Blood. Method's "Sinister Strike" is 15/36/0 (Vigor 2 and Blood Splatter
  instead of Improved Expose Armor and Cold Blood; Riposte + Deflection kept). Icy Veins chosen (exact order,
  agrees with two others). Daggers: Icy Veins "Backstab Combat" swaps Improved Sprint/Lightning Reflexes for
  Puncturing Wounds; Method "Backstab Focused" similar with Opportunity 5.
- WT's level-60 **Assassination** string (`A222227774448aaaaa99eeeeeccccc…`) was made on a pre-launch tree
  (Lethality 5, "Murder" 2/2, Seal Fate 5); in the 1.60.1 tree Lethality is 2, Seal Fate 3 and Murder is removed,
  so that link no longer decodes cleanly. WT's dagger Combat link also has tier-gate errors. Not used.

## Stats (PvE)
- Icy Veins Combat & Assassination: **Expertise (to 6.5%) > Hit (to 8%) > Agility > Weapon damage > Crit.**
- Icy Veins Subtlety: Weapon damage > Expertise > Hit > Weapon Skill > Agility.
- Method (first pass): Weapon DPS > Hit = Expertise > Agility > Crit > Strength.
- WT (leveling): Crit > Agility > AP > Strength > Stamina. Poisons now scale with AP and can crit.
- **ItemAdvisor:** the rogue profile valuing Expertise above Hit now matches Icy Veins (Expertise first);
  Method has them equal. Weapon DPS ranks 1st (Method, Subtlety) or 4th (Combat IV) – keep it high. No change needed
  beyond confirming Expertise ≥ Hit.

## Decoding method (all three classes)
1. **Warcraft Tavern / forever.warcraftdb.com** (`…/talent-calculator/<class>#?t=<string>`): from the site's
   `talent-core.js`: letters `A/B/C` switch tree (1st/2nd/3rd), every other char is ONE point in order; value =
   `tier*4 + column`, chars `0-9` then `a-z` (a=10). Tree layout from `https://forever.warcraftdb.com/api/v1/talents/<class>`
   (names, tier, column, max rank, prereqs; `points_to_level` = 10..60).
2. **Method.gg** (`data-talent="<loadout>;<order>"` in `.forever-talents` divs): part 1 is a retail-style bit-packed
   base64 loadout; part 2 is the order – each char is a base64 index (`A-Za-z0-9+/`) into all talent nodes of the
   class sorted by node ID (data `/dfc/ForeverTalentsData-1.60.1-2nov.json`). I read final ranks by calling the page's
   own `window.FTC.importString` into a detached div, and names by node ID from the warcraftdb API (same IDs).
3. **Icy Veins** (`data-talentcalculator-pointsurl="#tc-<chars>~<build>-<hash>"`): each char is one point in order,
   mapped through the `urlId` field of `https://static.icy-veins.com/r2/icydb/wowf/talents/<version>/<class>.json`
   (index.json lists versions 70755 → 70790 → 70862; rogue/priest/shaman unchanged since 70755).
4. **Mobalytics**: pages render the full "Leveling Path" (level → talent) as text per build tab.
5. **RankedBoost**: page JSON `alloc` = {nodeId: rank} (no order), game build 1.60.1.70862.
All decoded lists were re-validated with a Node script against the warcraftdb tree data (tier gates, max ranks).
Scripts: scratchpad `talentdec\decode.js`, `gen.js`, `assemble.js` (not part of the addon).

## Sources (read 2026-11-09)
- https://www.method.gg/wow-forever/wow-forever-rogue-leveling-guide-and-talents (upd. 2026-11-07)
- https://www.method.gg/wow-forever/class-guides/combat-rogue/talents, …/assassination-rogue/talents, …/subtlety-rogue/talents (2026-11-04, "based on beta build")
- https://mobalytics.gg/wow-forever/classes/rogue-pvp-guide (Perplexity, 2026-11-04)
- https://www.icy-veins.com/wow-forever/combat-rogue-melee-dps-pve-spec-builds-talents, …-leveling, …-pve-stat-priority (2026-11-04)
- https://www.warcrafttavern.com/forever/guides/rogue-leveling/, /combat-rogue/, /assassination-rogue/, /subtlety-rogue/ (no dates shown)
- https://rankedboost.com/world-of-warcraft/forever/build/rogue/ (game build 1.60.1.70862)
- https://metabot.gg/en/wow-forever/talent-calculator/rogue (tree check, 1.60.1.70790)
