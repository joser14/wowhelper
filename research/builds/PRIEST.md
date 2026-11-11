# Priest builds – second pass (researched 2026-11-09)

Data: `research\builds\PRIEST.lua` (replaces `BuildsData.PRIEST`). All five builds are full 51-point `points` lists,
validated against the 1.60.1 tree. Tree names follow the game data (`"Discipline"`, `"Holy"`, `"Shadow Magic"` – the
third tab is called "Shadow Magic" in warcraftdb, Icy Veins and Leprestore data; match talents by name or tab index).
Decoding method: see ROGUE.md.

| Slot | Build | Split (D/H/S) | Source (date) | Order | Confidence |
|---|---|---|---|---|---|
| leveling | Shadow leveling (Twicks) | 15/3/33 | Mobalytics priest-leveling-guide (2026-11-04) | from source | high |
| pvp | Shadow PvP | 18/0/33 | Leprestore shadow priest guide (upd. 2026-11-05) | **constructed** | low |
| pvp2 | Discipline PvP | 33/0/18 | RankedBoost priest builds (build 70862) | **constructed** | low |
| pve.healer | Holy 17/34/0 | 17/34/0 | Icy Veins holy spec-builds (2026-11-04) | from source | medium |
| pve.dps | Shadow raid (<Progress>) | 15/3/33 | Mobalytics shadow-priest-guide-progress (2026-11-04) | from source | high |

## Why these
- **Leveling.** Mobalytics (Twicks) and Icy Veins (shadow-priest-leveling, 13/3/35) both go Wand Specialization 2 →
  Spirit Tap 5 → Improved SW:P → Mind Flay ~22 → Shadowform 42 with no respec; the <Progress> guide's 1-60 tabs are
  similar but start Twin Disciplines and reach Shadowform only at 54. Method (06 Nov) instead levels Discipline to 39
  (Wand Spec, Spirit Tap, Twin Disciplines, Meditation, Penance at 37) and respecs to Shadow at 40 (31 pts), then
  17/0/34 at 60. Picked the no-respec path (two sources) because the addon follows one continuous point list; the
  summary mentions Method's alternative.
- **PvE DPS – Shadow 15/3/33.** <Progress> (raid guild) and Icy Veins agree on the split (Shadow to Shadowform with Dark
  Inspiration 5, Shadow Weaving 3, Devouring Contagion 2, Darkness 5; Discipline Twin Disciplines/Silent Resolve/
  Meditation; Holy Twilight Focus 3). Method is 17/0/34 (Early Demise, Mental Strength 5), RankedBoost 18/0/33.
  Picked <Progress> (endgame raid build, exact order). Icy Veins differs only by Silence vs. the 2nd Shadow Reach point
  and Mental Strength 4 vs. Inner Focus.
- **PvE Healer – Holy 17/34/0.** Icy Veins and RankedBoost both 17/34/0 (Holy to Prayer of Mending + Spiritual
  Healing; Discipline Twin Disciplines, Mental Strength, Meditation, Inner Focus, Silent Resolve). WT Holy (Oct 15 patch
  image) is 18/33/0. **Discipline 31/20/0** is the other consensus build (Icy Veins "Mitigation Machine", RankedBoost,
  WT): Discipline to Power Infusion with Penance, Renewed Hope, Divine Aegis; Holy Specialization, Divine Fury,
  Inspiration. Only one healer slot exists, so Holy stays (raw throughput per Icy Veins); Disc is documented here.
  Icy Veins Disc order: TD5, MS5, IF, MA3, Med3, IPWS3, SW, RH5, Penance, DA3, PI (40), then Holy HS5, DF5, TF3, HN, Insp3,
  SL2, Holy Reach 1.
- **PvP.** No complete PvP build with an order is published for priests. Seemeta rates Shadow S; Skycoach rates
  Discipline S. Leprestore gives an "exact legal" Shadow 18/0/33 (Blackout 5, Improved Psychic Scream, Silence, VE,
  Shadowform; Discipline Martyrdom, Mental Strength, Inner Focus, Mental Agility 2) and labels it theorycraft.
  RankedBoost's "Discipline Priest PvP Build" 33/0/18 (Power Infusion, Penance, Divine Aegis, Martyrdom, Improved Inner
  Fire, Improved Mana Burn; Shadow Blackout 5, Improved Mind Blast 5, Improved Psychic Scream). Both list final ranks
  only; I sequenced the points tier by tier (main tree first, key talents as early as the gates allow) and flagged them
  `orderFrom = "constructed"`.

## Stats
- Shadow (Icy Veins): **Hit (to 17%) > Spell Power > Crit > Spell Penetration > Spirit** (Method: Hit > SD > Crit > Int > Spirit).
- Holy & Discipline (Icy Veins): **Healing Power > MP5 > Spirit > Intellect > Crit**.
- Leveling (Mobalytics Twicks): Spell Power > Spirit > Intellect > Stamina > Crit > Hit > Haste > MP5.
- **ItemAdvisor:** shadow profile still weights Spirit above damage and Hit low – both sources put Hit (17%) first and
  Spirit last; Spell Penetration is ranked above Int by Icy Veins but ignored by IA. Healer profile: priest sources put
  MP5 right after Healing Power (IV) – fine if IA's healer MP5 weight is high; Crit last.

## Sources (read 2026-11-09)
- https://mobalytics.gg/wow-forever/classes/priest-leveling-guide (Twicks, 2026-11-04)
- https://mobalytics.gg/wow-forever/classes/shadow-priest-guide-progress (<Progress> Nescalz, 2026-11-04)
- https://www.icy-veins.com/wow-forever/holy-priest-healer-pve-spec-builds-talents, discipline-…, shadow-priest-ranged-dps-…, *-leveling, *-pve-stat-priority (2026-11-04)
- https://www.method.gg/wow-forever/wow-forever-priest-leveling-guide-and-talents (2026-11-06), …/class-guides/shadow-priest/talents (2026-11-04)
- https://leprestore.com/guides/world-of-warcraft-forever/wow-forever-shadow-priest-guide-best-builds-race-professions/ (Nov 3 fixes, Nov 5)
- https://rankedboost.com/world-of-warcraft/forever/build/priest/ (game build 1.60.1.70862)
- https://www.warcrafttavern.com/forever/guides/holy-priest/, /discipline-priest/ (build images only, no calculator links)

## Recheck 2026-11-11 (after the 2026-11-10 tuning)
fixes only (Revelation enchant no longer procs from Vampiric Embrace healing; Holy Nova unlearns when untalented; Nov 9 Shadowform/Fear Ward and Power Infusion fixes). Mobalytics priest leveling (Twicks) and the <Progress> shadow guide were both re-dated 2026-11-11; their 51-point paths were read again and are identical to the .lua (15/3/33 both). Leprestore PvP still 2026-11-05, rankedboost 2026-11-08 (build 70862), Icy Veins holy 2026-11-04. All builds kept.
