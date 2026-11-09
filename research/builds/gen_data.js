// Builds Builds\Data.lua from research\builds\<CLASS>.lua (+ orderFrom where the file lacks it, + Druid Balance dps2).
const fs = require('fs');
const path = require('path');
const W = process.argv[2];
const CLASSES = ['WARRIOR', 'PALADIN', 'HUNTER', 'ROGUE', 'PRIEST', 'SHAMAN', 'MAGE', 'WARLOCK', 'DRUID'];

// From the "Order" column of each research\builds\<CLASS>.md table (Rogue/Priest/Shaman files already carry it).
const ORDER = {
  WARRIOR: { 'Arms leveling (Icy Veins)': 'source', 'Arms battleground (35/16/0)': 'constructed',
    'Protection raid (Shield Slam)': 'source', 'Fury dual-wield raid (17/34/0)': 'source' },
  PALADIN: { 'Retribution leveling (Icy Veins)': 'source', 'Holy healer (PvP use)': 'source',
    'Retribution (Unsealed Wrath, PvP use)': 'source', 'Protection raid (Sacred Arbiter)': 'source',
    "Holy raid (Light's Vigil)": 'source', 'Deep Retribution (Unsealed Wrath)': 'source' },
  HUNTER: { 'Beast Mastery leveling (Method)': 'source', 'Beast Mastery PvP / world (31/3/17)': 'source',
    'Marksmanship PvP / world (18/33/0)': 'constructed', 'Marksmanship Lone Wolf raid': 'source' },
  MAGE: { 'Frost leveling, 7 Arcane first (Warcraft Tavern)': 'source', 'Frost PvP 17/0/34 (rankedboost)': 'constructed',
    'Fire 18/31/2 (Warcraft Tavern)': 'source' },
  WARLOCK: { 'Affliction leveling (Warcraft Tavern)': 'source', 'Destruction PvP 7/7/37 (Mobalytics)': 'constructed',
    'Affliction Wrack 33/0/18': 'source' },
  DRUID: { 'Feral leveling (Warcraft Tavern)': 'source', 'Restoration PvP (rankedboost)': 'constructed',
    'Feral hybrid PvP': 'source', 'Hybrid Bear/Cat 9/37/5 (Warcraft Tavern)': 'source',
    'Restoration 13/0/38 (Warcraft Tavern)': 'source', 'Cat DPS 8/33/10 (Icy Veins)': 'constructed' },
};

function luaStr(s) { return '"' + s.replace(/\\/g, '\\\\').replace(/"/g, '\\"') + '"'; }

function balance() {
  const order = [
    ['Improved Wrath', 'Balance', 5], ['Genesis', 'Balance', 5], ['Moonglow', 'Balance', 3], ['Improved Moonfire', 'Balance', 2],
    ["Nature's Majesty", 'Balance', 2], ["Nature's Reach", 'Balance', 2], ["Nature's Splendor", 'Balance', 1], ['Insect Swarm', 'Balance', 1],
    ['Vengeance', 'Balance', 5], ['Improved Starfire', 'Balance', 5], ["Nature's Grace", 'Balance', 1], ['Eclipse', 'Balance', 3],
    ['Moonfury', 'Balance', 5], ['Moonkin Form', 'Balance', 1],
    ['Heart of the Wild', 'Restoration', 5], ['Reflection', 'Restoration', 3], ["Nature's Focus", 'Restoration', 2],
  ];
  const pts = [];
  let level = 10;
  for (const [talent, tree, ranks] of order) for (let r = 1; r <= ranks; r++) pts.push({ level: level++, talent, tree, rank: r });
  if (pts.length !== 51) throw new Error('balance has ' + pts.length);
  const rows = [];
  for (let i = 0; i < pts.length; i += 2) {
    rows.push('                ' + pts.slice(i, i + 2).map(p =>
      `{ level = ${p.level}, talent = ${luaStr(p.talent)}, tree = ${luaStr(p.tree)}, rank = ${p.rank} },`).join(' '));
  }
  const keys = order.map(o => luaStr(o[0])).join(', ');
  return `        -- Balance (Moonkin) raid build from research\\builds\\DRUID.md ("Other exact builds found"): WT and IV agree on the
        -- Balance 41; WT's Restoration 10 used. Offered as a second damage choice (goal "dps2" / "balance").
        dps2 = {
            name = "Balance raid 41/0/10 (Warcraft Tavern)", spec = "Balance", orderFrom = "source",
            summary = "Moonkin caster: Improved Wrath, Genesis, Moonglow and Nature's Reach first, Insect Swarm, Vengeance and Improved Starfire, then Nature's Grace, Eclipse 3, Moonfury and Moonkin Form; Restoration Heart of the Wild, Reflection and Nature's Focus 2. Icy Veins' default has the same Balance 41 with Nature's Focus 5 and Naturalist 5 instead. No Forever Balance stat list was recorded, so the stats follow the caster consensus (mage/warlock/priest guides).",
            split = "41/0/10",
            points = {
${rows.join('\n')}
            },
            keyTalents = { ${keys} },
            stats = { "Hit (to 17%)", "Spell Damage", "Crit", "Intellect", "Spirit" },
            source = "https://www.warcrafttavern.com/forever/guides/balance-druid/ ; same Balance 41 at https://www.icy-veins.com/wow-forever/balance-druid-ranged-dps-pve-spec-builds-talents (2026-11-04)",
            checked = "2026-11-09", confidence = "high",
        },
`;
}

const header = fs.readFileSync(path.join(__dirname, 'data_header.lua'), 'utf8');
let out = header + '\nBuildsData = {}\n';
for (const c of CLASSES) {
  let text = fs.readFileSync(path.join(W, 'research', 'builds', c + '.lua'), 'utf8').replace(/\r\n/g, '\n');
  const at = text.indexOf('\nreturn {');
  if (at < 0) throw new Error(c + ': no return');
  let body = text.slice(at + 1).replace(/^return \{/, `BuildsData.${c} = {`).trimEnd() + '\n';
  for (const [name, from] of Object.entries(ORDER[c] || {})) {
    const needle = `name = ${luaStr(name)},`;
    if (body.split(needle).length !== 2) throw new Error(c + ': name not unique/found ' + name);
    body = body.replace(needle, `${needle} orderFrom = "${from}",`);
  }
  if (c === 'DRUID') {
    // Insert dps2 just before the closing of pve (the last "    },\n}" of the file).
    const end = body.lastIndexOf('    },\n}');
    if (end < 0) throw new Error('druid pve end');
    body = body.slice(0, end) + balance() + body.slice(end);
  }
  out += `\n-- ${c}: research\\builds\\${c}.lua (sources and method in research\\builds\\${c}.md)\n` + body;
}
fs.writeFileSync(path.join(W, 'Builds', 'Data.lua'), out);
console.log('wrote', out.length);
