#!/usr/bin/env node
// Builds LevelGuide\Travel.lua, the travel planner's data (research\guides_deep_re.md 12.7). No network; it only
// reads forever-db's JSONL tables as data.
//
//     node tools\gen_travel.js <path\to\forever-db> [LevelGuide\Travel.lua]
//
// From forever-db (GPL-3.0, the Polestar project's World of Warcraft: Forever quest database; see NOTICE.md):
//   * where each flight master and innkeeper stands (npc + spawn tables, by NPC ID below), turned into map
//     percent with the ui_map frames; where every spirit healer stands (the death-skip hint);
//   * the frames themselves (world yards of each map's edges), so the planner can measure across maps.
// Written here, in our own words (public game facts, research\*.md, wow4ever.quest, wowhead classic):
//   * which flight masters are linked (the Classic Alliance network; Forever's Riverglades one unverified);
//   * boats, the Deeprun Tram, the Darnassus portals and the Zephras Isle zeppelin, with dock spots and
//     typical wait + ride times in seconds (rounded estimates, not timetables);
//   * inn names as GetBindLocation reports them, zone level ranges, the Teldrassil / Rut'theran split.
// Nothing comes from Polestar's TravelData.lua, its walking grids or baked legs (their permission for reuse is
// unclear), nor from RestedXP, Guidelime or ForeverWisp.
'use strict';
const fs = require('fs');
const path = require('path');

const SRC = process.argv[2];
const ROOT = path.join(__dirname, '..');
const OUT = process.argv[3] || path.join(ROOT, 'LevelGuide', 'Travel.lua');
if (!SRC || !fs.existsSync(path.join(SRC, 'data', 'npc.jsonl'))) {
    console.error('usage: node tools/gen_travel.js <forever-db folder> [out.lua]');
    process.exit(2);
}
function read(name) {
    const rows = [];
    for (const line of fs.readFileSync(path.join(SRC, 'data', name + '.jsonl'), 'utf8').split('\n')) {
        if (line.trim()) rows.push(JSON.parse(line));
    }
    return rows;
}
const index = JSON.parse(fs.readFileSync(path.join(SRC, 'index.json'), 'utf8'));

// Classic uiMap IDs (Forever uses them) and their names.
const NAMES = {
    1411: 'Durotar', 1412: 'Mulgore', 1413: 'The Barrens', 1416: 'Alterac Mountains', 1417: 'Arathi Highlands',
    1418: 'Badlands', 1419: 'Blasted Lands', 1420: 'Tirisfal Glades', 1421: 'Silverpine Forest',
    1422: 'Western Plaguelands', 1423: 'Eastern Plaguelands', 1424: 'Hillsbrad Foothills', 1425: 'The Hinterlands',
    1426: 'Dun Morogh', 1427: 'Searing Gorge', 1428: 'Burning Steppes', 1429: 'Elwynn Forest', 1430: 'Deadwind Pass',
    1431: 'Duskwood', 1432: 'Loch Modan', 1433: 'Redridge Mountains', 1434: 'Stranglethorn Vale',
    1435: 'Swamp of Sorrows', 1436: 'Westfall', 1437: 'Wetlands', 1438: 'Teldrassil', 1439: 'Darkshore',
    1440: 'Ashenvale', 1441: 'Thousand Needles', 1442: 'Stonetalon Mountains', 1443: 'Desolace', 1444: 'Feralas',
    1445: 'Dustwallow Marsh', 1446: 'Tanaris', 1447: 'Azshara', 1448: 'Felwood', 1449: "Un'Goro Crater",
    1450: 'Moonglade', 1451: 'Silithus', 1452: 'Winterspring', 1453: 'Stormwind City', 1454: 'Orgrimmar',
    1455: 'Ironforge', 1456: 'Thunder Bluff', 1457: 'Darnassus', 1458: 'Undercity', 2521: 'Zephras Isle',
    2548: 'Riverglades',
};

// Typical level ranges (Classic zone ranges; Riverglades and Zephras Isle from research\routes_20_60.md and
// research\rxp_forever_guides.md). Cities have none.
const LEVELS = {
    1411: [1, 10], 1412: [1, 10], 1413: [10, 25], 1416: [30, 40], 1417: [30, 40], 1418: [35, 45], 1419: [45, 55],
    1420: [1, 10], 1421: [10, 20], 1422: [51, 58], 1423: [53, 60], 1424: [20, 30], 1425: [40, 50], 1426: [1, 10],
    1427: [43, 50], 1428: [50, 58], 1429: [1, 10], 1430: [50, 60], 1431: [18, 30], 1432: [10, 20], 1433: [15, 25],
    1434: [30, 45], 1435: [35, 45], 1436: [10, 20], 1437: [20, 30], 1438: [1, 10], 1439: [10, 20], 1440: [18, 30],
    1441: [25, 35], 1442: [15, 27], 1443: [30, 40], 1444: [40, 50], 1445: [35, 45], 1446: [40, 50], 1447: [45, 55],
    1448: [48, 55], 1449: [48, 55], 1450: [55, 60], 1451: [55, 60], 1452: [53, 60], 2521: [1, 13], 2548: [36, 46],
};

// Flight masters: game node name (the part before the comma), NPC ID in forever-db, A = Alliance, N = neutral.
const FP = [
    // Eastern Kingdoms
    ['Stormwind', 352, 'A', 1453], ['Sentinel Hill', 523, 'A', 1436], ['Lakeshire', 931, 'A', 1433], ['Darkshire', 2409, 'A', 1431],
    ['Ironforge', 1573, 'A', 1455], ['Thelsamar', 1572, 'A', 1432], ['Menethil Harbor', 1571, 'A', 1437], ['Southshore', 2432, 'A', 1424],
    ['Refuge Pointe', 2835, 'A', 1417], ['Aerie Peak', 8018, 'A', 1425], ['Booty Bay', 2859, 'A', 1434], ['Nethergarde Keep', 8609, 'A', 1419],
    ["Morgan's Vigil", 2299, 'A', 1428], ['Thorium Point', 2941, 'A', 1427], ['Chillwind Camp', 12596, 'A', 1422],
    ["Light's Hope Chapel", 12617, 'A', 1423],
    // Forever's Riverglades (Gretchen Mayberry, research\routes_20_60.md "Farholde Keep 60.6, 81.4").
    ['Farholde Keep', 257087, 'A', 2548],
    // Kalimdor
    ["Rut'theran Village", 3838, 'A', 1438], ['Auberdine', 3841, 'A', 1439], ['Astranaar', 4267, 'A', 1440], ['Stonetalon Peak', 4407, 'A', 1442],
    ["Nijel's Point", 6706, 'A', 1443], ['Thalanaar', 4319, 'A', 1444], ['Feathermoon', 8019, 'A', 1444], ['Theramore', 4321, 'A', 1445],
    ['Gadgetzan', 7823, 'A', 1446], ["Marshal's Refuge", 10583, 'N', 1449], ['Cenarion Hold', 15177, 'A', 1451], ['Ratchet', 16227, 'N', 1413],
    ['Talrendis Point', 12577, 'A', 1447], ['Talonbranch Glade', 12578, 'A', 1448], ['Everlook', 11138, 'A', 1452], ['Moonglade', 10897, 'A', 1450],
];

// Flight connections (both ways). Times are worked out by the planner from the distance (and replaced by what
// Landmarks learns from your own flights).
const FLIGHTS = [
    ['Stormwind', 'Ironforge'], ['Stormwind', 'Sentinel Hill'], ['Stormwind', 'Lakeshire'], ['Stormwind', 'Darkshire'],
    ['Stormwind', 'Booty Bay'], ['Stormwind', 'Nethergarde Keep'], ['Stormwind', "Morgan's Vigil"],
    ['Sentinel Hill', 'Lakeshire'], ['Sentinel Hill', 'Darkshire'], ['Sentinel Hill', 'Booty Bay'],
    ['Lakeshire', 'Darkshire'], ['Lakeshire', "Morgan's Vigil"], ['Lakeshire', 'Nethergarde Keep'],
    ['Darkshire', 'Booty Bay'], ['Darkshire', 'Nethergarde Keep'], ['Nethergarde Keep', "Morgan's Vigil"],
    ["Morgan's Vigil", 'Ironforge'], ["Morgan's Vigil", 'Thorium Point'], ['Thorium Point', 'Ironforge'],
    ['Ironforge', 'Thelsamar'], ['Ironforge', 'Menethil Harbor'], ['Ironforge', 'Southshore'], ['Ironforge', 'Refuge Pointe'],
    ['Ironforge', 'Aerie Peak'], ['Ironforge', 'Chillwind Camp'], ['Ironforge', "Light's Hope Chapel"],
    ['Thelsamar', 'Menethil Harbor'], ['Menethil Harbor', 'Southshore'], ['Menethil Harbor', 'Refuge Pointe'],
    ['Southshore', 'Refuge Pointe'], ['Southshore', 'Aerie Peak'], ['Southshore', 'Chillwind Camp'],
    ['Refuge Pointe', 'Aerie Peak'], ['Aerie Peak', 'Chillwind Camp'], ['Chillwind Camp', "Light's Hope Chapel"],
    // Unverified (Forever): Riverglades' flight master linked to its neighbours.
    ['Farholde Keep', 'Lakeshire'], ['Farholde Keep', "Morgan's Vigil"],
    ["Rut'theran Village", 'Auberdine'], ['Auberdine', 'Astranaar'], ['Auberdine', 'Stonetalon Peak'],
    ['Auberdine', "Nijel's Point"], ['Auberdine', 'Theramore'], ['Auberdine', 'Talonbranch Glade'],
    ['Astranaar', 'Stonetalon Peak'], ['Astranaar', 'Talrendis Point'], ['Astranaar', 'Talonbranch Glade'],
    ['Astranaar', 'Theramore'], ['Stonetalon Peak', "Nijel's Point"], ["Nijel's Point", 'Feathermoon'],
    ['Thalanaar', 'Feathermoon'], ['Thalanaar', 'Theramore'], ['Thalanaar', 'Gadgetzan'],
    ['Theramore', 'Gadgetzan'], ['Theramore', 'Ratchet'], ['Gadgetzan', "Marshal's Refuge"], ['Gadgetzan', 'Cenarion Hold'],
    ["Marshal's Refuge", 'Cenarion Hold'], ['Talonbranch Glade', 'Everlook'], ['Talonbranch Glade', 'Moonglade'],
    ['Everlook', 'Moonglade'],
];

// Boats, tram, portals, zeppelin. a/b = { name, map, x, y } (map percent); ride and wait in seconds (typical:
// about half a crossing's round trip waiting, rounded). oneWay: only a -> b.
// Dock spots: Auberdine's Stormwind pier 30.7, 41.0 (research\rxp_forever_guides.md 2.4, as Routes.lua);
// Stormwind Harbor by the harbour guards' and dock workers' spawns (forever-db, Forever's new harbour);
// Booty Bay and Ratchet by their shipmasters (Grizzlowe, Grimble; forever-db); Southshore by its new
// dockmaster (Raul Sweete, forever-db); Steamwheedle Port 68.6, 23.0 (research\forever_improvements_2026-11-10.md);
// Powderfuse Port by its innkeeper and Melbin Powderfuse (forever-db, research\routes_20_60.md); the Darnassus
// portal 28.5, 39.9 (research\rxp_forever_guides.md D14); the Zephras Isle zeppelin 65.8, 83.4 (rxp 6.1) and
// Dalaran on the Alterac map (routes_20_60.md 2.4). The other piers are approximate (check in game).
const AUBERDINE_SW = { name: 'Auberdine pier', map: 1439, x: 30.7, y: 41.0 };
const AUBERDINE_NORTH = { name: 'Auberdine north pier', map: 1439, x: 33.2, y: 40.0 };
const AUBERDINE_SOUTH = { name: 'Auberdine south pier', map: 1439, x: 32.4, y: 43.8 };
const MENETHIL_NORTH = { name: 'Menethil north pier', map: 1437, x: 4.6, y: 57.0 };
const MENETHIL_SOUTH = { name: 'Menethil south pier', map: 1437, x: 5.0, y: 63.5 };
const SOUTHSHORE = { name: 'Southshore dock', map: 1424, x: 50.6, y: 68.6 };
const LINKS = [
    { id: 'boat-auberdine-stormwind', kind: 'boat', a: AUBERDINE_SW, b: { name: 'Stormwind Harbor', map: 1453, x: 22.5, y: 56.0 }, wait: 120, ride: 75 },
    { id: 'boat-auberdine-ruttheran', kind: 'boat', a: AUBERDINE_NORTH, b: { name: "Rut'theran Village dock", map: 1438, x: 54.9, y: 96.9 }, wait: 150, ride: 100 },
    { id: 'boat-menethil-theramore', kind: 'boat', a: MENETHIL_SOUTH, b: { name: 'Theramore dock', map: 1445, x: 71.6, y: 56.4 }, wait: 170, ride: 105 },
    { id: 'boat-menethil-auberdine', kind: 'boat', a: MENETHIL_NORTH, b: AUBERDINE_SOUTH, wait: 240, ride: 180 },
    { id: 'boat-southshore-menethil', kind: 'boat', a: SOUTHSHORE, b: MENETHIL_NORTH, wait: 240, ride: 180 },
    { id: 'boat-southshore-auberdine', kind: 'boat', a: SOUTHSHORE, b: AUBERDINE_SOUTH, wait: 240, ride: 180 },
    { id: 'boat-bootybay-ratchet', kind: 'boat', a: { name: 'Booty Bay dock', map: 1434, x: 26.1, y: 73.3 }, b: { name: 'Ratchet dock', map: 1413, x: 63.5, y: 38.6 }, wait: 180, ride: 115 },
    { id: 'boat-tanaris-riverglades', kind: 'boat', a: { name: 'Steamwheedle Port', map: 1446, x: 68.6, y: 23.0 }, b: { name: 'Powderfuse Port', map: 2548, x: 79.0, y: 53.0 }, wait: 150, ride: 75 },
    { id: 'boat-feathermoon', kind: 'boat', a: { name: 'Forgotten Coast dock', map: 1444, x: 43.1, y: 42.8 }, b: { name: 'Feathermoon dock', map: 1444, x: 31.0, y: 39.6 }, wait: 160, ride: 100 },
    { id: 'tram', kind: 'tram', a: { name: 'Deeprun Tram (Dwarven District)', map: 1453, x: 66.0, y: 34.0 }, b: { name: 'Deeprun Tram (Tinker Town)', map: 1455, x: 76.8, y: 51.2 }, wait: 60, ride: 95 },
    { id: 'portal-darnassus-ruttheran', kind: 'portal', oneWay: true, a: { name: 'the portal in Darnassus', map: 1457, x: 28.5, y: 39.9 }, b: { name: "Rut'theran Village", map: 1438, x: 55.9, y: 89.7 }, wait: 0, ride: 5 },
    { id: 'portal-ruttheran-darnassus', kind: 'portal', oneWay: true, a: { name: "the portal in Rut'theran Village", map: 1438, x: 55.9, y: 89.4 }, b: { name: 'Darnassus', map: 1457, x: 30.7, y: 41.4 }, wait: 0, ride: 5 },
    { id: 'zeppelin-zephras-dalaran', kind: 'zeppelin', oneWay: true, a: { name: 'the Zephras Isle zeppelin', map: 2521, x: 65.8, y: 83.4 }, b: { name: 'Dalaran', map: 1416, x: 14.0, y: 66.0 }, wait: 60, ride: 90 },
];

// Inns: names as GetBindLocation gives them, innkeeper NPC ID in forever-db.
const INNS = [
    [['Goldshire', "Lion's Pride Inn"], 295, 1429], [['Kharanos', 'Thunderbrew Distillery'], 1247, 1426],
    [['Menethil Harbor', 'Deepwater Tavern'], 1464, 1437], [['Southshore'], 2352, 1424], [['Ironforge', 'Stonefire Tavern'], 5111, 1455],
    [['Lakeshire'], 6727, 1433], [['Thelsamar', 'Stoutlager Inn'], 6734, 1432], [['Darnassus', "Craftsmen's Terrace"], 6735, 1457],
    [['Dolanaar'], 6736, 1438], [['Auberdine'], 6737, 1439], [['Astranaar'], 6738, 1440], [['Stormwind City', 'Trade District', 'The Gilded Rose'], 6740, 1453],
    [['Darkshire', 'Scarlet Raven Tavern'], 6790, 1431], [['Theramore Isle', 'Theramore'], 6272, 1445], [['Booty Bay'], 6807, 1434],
    [['Ratchet'], 6791, 1413], [['Gadgetzan'], 7733, 1446], [['Feathermoon Stronghold', 'Feathermoon'], 7736, 1444],
    [['Aerie Peak', 'Wildhammer Keep'], 7744, 1425], [["Nijel's Point"], 11103, 1443], [['Sentinel Hill'], 8931, 1436],
    [['Everlook'], 11118, 1452], [['Cenarion Hold'], 15174, 1451], [['Stonetalon Peak'], 16458, 1442], [["Light's Hope Chapel"], 16256, 1423],
    [['Farholde Keep'], 257595, 2548], [['Powderfuse Port'], 255894, 2548], [["Shen'dar Village"], 254089, 2521], [['Valanaar'], 255940, 2521],
];

// --- forever-db lookups ---
const frames = new Map(read('ui_map').map(r => [r.ui_map, r]));
const spawns = new Map();
const wantNpc = new Set([...FP.map(f => f[1]), ...INNS.map(i => i[1])]);
for (const s of read('spawn')) {
    if (s.kind === 'npc' && wantNpc.has(s.id) && !spawns.has(s.id)) spawns.set(s.id, s);
}
const allNpcs = read('npc');
const npcs = new Map(allNpcs.filter(n => wantNpc.has(n.id)).map(n => [n.id, n]));
// Spirit healers (the death-skip hint): every spawn of an NPC named or titled "Spirit Healer", on the zone map
// (not a city) that holds it.
const healerIds = new Set(allNpcs.filter(n => n.name === 'Spirit Healer' || n.subname === 'Spirit Healer').map(n => n.id));
const CITIES = new Set([1453, 1454, 1455, 1456, 1457, 1458]);
const healerSpots = [];
for (const s of read('spawn')) {
    if (s.kind !== 'npc' || !healerIds.has(s.id)) continue;
    for (const id of Object.keys(NAMES).map(Number).sort((a, b) => a - b)) {
        if (CITIES.has(id)) continue;
        const p = onMap(s, id);
        if (p) {
            if (!healerSpots.some(h => h.map === id && Math.abs(h.x - p.x) < 1 && Math.abs(h.y - p.y) < 1)) {
                healerSpots.push({ map: id, x: p.x, y: p.y });
            }
            break;
        }
    }
}
healerSpots.sort((a, b) => a.map - b.map || a.x - b.x || a.y - b.y);
function onMap(s, uiMap) {
    const m = frames.get(uiMap);
    if (!m || m.map !== s.map) return null;
    const x = 100 * (s.y - m.left) / (m.right - m.left), y = 100 * (s.x - m.top) / (m.bottom - m.top);
    return x >= 0 && x <= 100 && y >= 0 && y <= 100 ? { x: Math.round(x * 10) / 10, y: Math.round(y * 10) / 10 } : null;
}
// The spawn on the map named for it (maps overlap at their edges, so the map is written, not guessed).
function place(id, uiMap) {
    const s = spawns.get(id);
    if (!s) throw new Error('no spawn for NPC ' + id);
    const p = onMap(s, uiMap);
    if (!p) throw new Error('NPC ' + id + ' is not on map ' + uiMap);
    return { map: uiMap, x: p.x, y: p.y };
}
const used = new Set();
const q = s => JSON.stringify(s).replace(/\\u0027/g, "'");
const pt = p => { used.add(p.map); return `map = ${p.map}, x = ${p.x}, y = ${p.y}`; };

const fpLines = FP.map(([name, id, side, uiMap]) => {
    const p = place(id, uiMap);
    const npc = npcs.get(id);
    return `        { name = ${q(name)}, side = "${side}", npc = ${q(npc ? npc.name : '?')}, ${pt(p)} },`;
});
const fpNames = new Set(FP.map(f => f[0]));
for (const [a, b] of FLIGHTS) {
    if (!fpNames.has(a) || !fpNames.has(b)) throw new Error('unknown flight master in ' + a + ' - ' + b);
}
const flightLines = FLIGHTS.map(([a, b]) => `        { ${q(a)}, ${q(b)} },`);
const end = p => `{ name = ${q(p.name)}, ${pt(p)} }`;
const linkLines = LINKS.map(l => `        { id = "${l.id}", kind = "${l.kind}", ${l.oneWay ? 'oneWay = true, ' : ''}wait = ${l.wait}, ride = ${l.ride},\n` +
    `          a = ${end(l.a)},\n          b = ${end(l.b)} },`);
const innLines = INNS.map(([names, id, uiMap]) => `        { names = { ${names.map(q).join(', ')} }, ${pt(place(id, uiMap))} },`);
const healerLines = healerSpots.map(h => `        { ${pt(h)} },`);
for (const id of Object.keys(LEVELS).map(Number)) used.add(id);
const allFrames = [...used].sort((a, b) => a - b).map(id => {
    const m = frames.get(id);
    if (!m) throw new Error('no frame for ' + id);
    return `        [${id}] = { ${m.map}, ${m.left}, ${m.right}, ${m.top}, ${m.bottom} },`;
});
const nameLines = [...used].sort((a, b) => a - b).map(id => `        [${id}] = ${q(NAMES[id])},`);
const levelLines = Object.keys(LEVELS).map(Number).sort((a, b) => a - b).map(id => `        [${id}] = { ${LEVELS[id][0]}, ${LEVELS[id][1]} },`);

const out = `-- LevelGuide travel data: GENERATED by tools\\gen_travel.js; edit that script, not this file.
-- Flight master and innkeeper spots and the map frames come from forever-db ${index.version || ''} (the Polestar
-- project's World of Warcraft: Forever quest database, https://github.com/fitzforge/polestar), GPL-3.0; see
-- NOTICE.md for its own credits. Connections, boats, tram, portals, zeppelin, wait and ride times, inn names and
-- zone levels are written in tools\\gen_travel.js in our own words (sources listed there). Derived work under the
-- GNU GPL version 3 (LICENSE). World of Warcraft names and game data (c) Blizzard Entertainment.
--
--   fp      = { { name (the game's node name before the comma), side (A/N), npc, map, x, y (percent) } }
--   flights = { { name, name } }  both ways; times come from the distance (or your own flights)
--   links   = { { id, kind (boat/tram/portal/zeppelin), oneWay, wait, ride (seconds), a, b = { name, map, x, y } } }
--   inns    = { { names (GetBindLocation), map, x, y } }
--   healers = { { map, x, y } }  spirit healers (forever-db spawns), for the death-skip hint
--   frames  = { [uiMap] = { continent, left, right, top, bottom } } world yards (x north, y west)
--   levels  = { [uiMap] = { min, max } }
LevelGuideTravel = {
    fp = {
${fpLines.join('\n')}
    },
    flights = {
${flightLines.join('\n')}
    },
    links = {
${linkLines.join('\n')}
    },
    inns = {
${innLines.join('\n')}
    },
    healers = {
${healerLines.join('\n')}
    },
    frames = {
${allFrames.join('\n')}
    },
    names = {
${nameLines.join('\n')}
    },
    levels = {
${levelLines.join('\n')}
    },
}

-- Places you can't walk between: continents, Teldrassil's top (with Darnassus) and Rut'theran Village below
-- the tree (joined only by the portals), and Zephras Isle.
local RUTTHERAN = { 50, 66, 84, 100 }   -- x from, x to, y from, y to on Teldrassil's map
function LevelGuideTravel.Region(map, x, y)
    local frame = LevelGuideTravel.frames[map]
    if not frame then
        return nil
    end
    if map == 1438 and x and y and x >= RUTTHERAN[1] and x <= RUTTHERAN[2] and y >= RUTTHERAN[3] and y <= RUTTHERAN[4] then
        return "ruttheran"
    end
    if map == 1438 or map == 1457 then
        return "teldrassil"
    end
    return "c" .. frame[1]
end
`;
fs.writeFileSync(OUT, out);
console.log(`${FP.length} flight masters, ${FLIGHTS.length} connections, ${LINKS.length} links, ${INNS.length} inns, ${healerSpots.length} spirit healers -> ${OUT}`);
