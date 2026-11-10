#!/usr/bin/env node
// Builds LevelGuide\QuestDB.lua from forever-db (the GPL-3.0 World of Warcraft: Forever quest database
// of the Polestar project, https://github.com/fitzforge/polestar, folder forever-db). No network; it
// only reads the JSONL tables as data and never runs anything from that folder.
//
// Regenerate (from the repo root, with a forever-db release unpacked somewhere):
//
//     node tools\gen_questdb.js <path\to\forever-db> [LevelGuide\QuestDB.lua]
//
// What goes in (Alliance-available and neutral quests only; Horde-only quests are dropped):
//   quest id -> title, quest level, minimum level, race and class masks (client masks, 0 = every),
//   givers and turn-ins (npc / object / item ids), prerequisites (all / any, breadcrumbs marked),
//   flags (group, elite, timed, escort, dungeon, raid, pvp, repeatable) and objectives with up to three
//   representative spots each (the densest spawn clusters, not every spawn).
//   npc / object id -> name and up to three spots; item id -> name (only those the quests need).
// Spots are uiMapID + x, y in 0-100 map percent (one decimal), converted from world yards with
// forever-db's ui_map frames. Forever uses the Classic uiMapIDs (Teldrassil 1438, Darnassus 1457).
//
// Licences: the tables used are GPL-3.0 (quest*, npc, object, spawn, item, item_source, ui_map). The
// flags elite/timed/escort also read forever-db's mechanic table, which is CC BY 4.0 (Polestar's own
// layer); the generated file carries that attribution (NOTICE.md lists both).
'use strict';
const fs = require('fs');
const path = require('path');

const SRC = process.argv[2];
const OUT = process.argv[3] || path.join(__dirname, '..', 'LevelGuide', 'QuestDB.lua');
if (!SRC || !fs.existsSync(path.join(SRC, 'data', 'quest.jsonl'))) {
    console.error('usage: node tools/gen_questdb.js <forever-db folder> [out.lua]');
    process.exit(2);
}

function read(name) {
    const text = fs.readFileSync(path.join(SRC, 'data', name + '.jsonl'), 'utf8');
    const rows = [];
    for (const line of text.split('\n')) {
        if (line.trim()) rows.push(JSON.parse(line));
    }
    return rows;
}
function group(rows, key) {
    const map = new Map();
    for (const row of rows) {
        const k = key(row);
        if (!map.has(k)) map.set(k, []);
        map.get(k).push(row);
    }
    return map;
}

const index = JSON.parse(fs.readFileSync(path.join(SRC, 'index.json'), 'utf8'));
const quests = read('quest');
const starts = group(read('quest_start'), r => r.quest);
const ends = group(read('quest_end'), r => r.quest);
const objectives = group(read('quest_objective'), r => r.quest);
const prereqs = group(read('quest_prereq'), r => r.quest);
const npcs = new Map(read('npc').map(r => [r.id, r]));
const objects = new Map(read('object').map(r => [r.id, r]));
const items = new Map(read('item').map(r => [r.id, r]));
const itemSources = group(read('item_source'), r => r.item);
const spawns = group(read('spawn'), r => r.kind + ':' + r.id);
const frames = read('ui_map');
const mechanics = group(read('mechanic'), r => r.quest);

// Classic uiMap names (Forever's maps); the guide shows them and finds maps by name.
const MAP_NAMES = {
    1411: 'Durotar', 1412: 'Mulgore', 1413: 'The Barrens', 1416: 'Alterac Mountains', 1417: 'Arathi Highlands',
    1418: 'Badlands', 1419: 'Blasted Lands', 1420: 'Tirisfal Glades', 1421: 'Silverpine Forest',
    1422: 'Western Plaguelands', 1423: 'Eastern Plaguelands', 1424: 'Hillsbrad Foothills', 1425: 'The Hinterlands',
    1426: 'Dun Morogh', 1427: 'Searing Gorge', 1428: 'Burning Steppes', 1429: 'Elwynn Forest', 1430: 'Deadwind Pass',
    1431: 'Duskwood', 1432: 'Loch Modan', 1433: 'Redridge Mountains', 1434: 'Stranglethorn Vale',
    1435: 'Swamp of Sorrows', 1436: 'Westfall', 1437: 'Wetlands', 1438: 'Teldrassil', 1439: 'Darkshore',
    1440: 'Ashenvale', 1441: 'Thousand Needles', 1442: 'Stonetalon Mountains', 1443: 'Desolace', 1444: 'Feralas',
    1445: 'Dustwallow Marsh', 1446: 'Tanaris', 1447: 'Azshara', 1448: 'Felwood', 1449: "Un'Goro Crater",
    1450: 'Moonglade', 1451: 'Silithus', 1452: 'Winterspring', 1453: 'Stormwind City', 1454: 'Orgrimmar',
    1455: 'Ironforge', 1456: 'Thunder Bluff', 1457: 'Darnassus', 1458: 'Undercity', 1459: 'Alterac Valley',
    1460: 'Warsong Gulch', 1461: 'Arathi Basin', 2482: 'Mount Hyjal', 2521: 'Zephras Isle',
    2524: 'Darkspear Islands', 2548: 'Riverglades', 2652: "Shen'dralas", 2665: 'Zephras Isle',
};
const CONTINENTS = new Set([1414, 1415, 1463, 1464]);
const CITIES = new Set([1453, 1454, 1455, 1456, 1457, 1458]);

// Alliance races in the client mask: Human 1, Dwarf 4, Night Elf 8, Gnome 64, and bit 32 (Forever's
// Alliance-side race; every Alliance quest carries it, bit 33 is the Horde one).
const ALLIANCE_RACES = 1n | 4n | 8n | 64n | (1n << 32n);
function allianceCan(q) {
    const races = BigInt(q.races || 0);
    if (races === 0n) return q.side !== 2;
    return (races & ALLIANCE_RACES) !== 0n;
}

// ---- world yards -> map percent ------------------------------------------------------------------
const zoneFrames = frames.filter(f => !CONTINENTS.has(f.ui_map) && MAP_NAMES[f.ui_map]);
const frameArea = f => Math.abs((f.left - f.right) * (f.top - f.bottom));
zoneFrames.sort((a, b) => frameArea(a) - frameArea(b) || a.ui_map - b.ui_map);
function toPercent(frame, s) {
    return [(frame.left - s.y) / (frame.left - frame.right) * 100, (frame.top - s.x) / (frame.top - frame.bottom) * 100];
}
function containing(s) {
    return zoneFrames.filter(f => f.map === s.map && s.y <= f.left && s.y >= f.right && s.x <= f.top && s.x >= f.bottom);
}
const frameByID = new Map(frames.map(f => [f.ui_map, f]));

// Which map a quest's zone (AreaTable id) means: the map most of its givers stand on (smallest frame).
const areaVotes = new Map();
for (const q of quests) {
    if (!q.zone_area) continue;
    for (const st of starts.get(q.id) || []) {
        if (st.kind === 'item') continue;
        const sp = (spawns.get(st.kind + ':' + st.id) || [])[0];
        const c = sp && containing(sp);
        if (c && c.length) {
            const zone = c.find(f => !CITIES.has(f.ui_map)) || c[0];
            const votes = areaVotes.get(q.zone_area) || new Map();
            votes.set(zone.ui_map, (votes.get(zone.ui_map) || 0) + 1);
            areaVotes.set(q.zone_area, votes);
        }
    }
}
const areaMap = new Map();
for (const [area, votes] of areaVotes) {
    areaMap.set(area, [...votes].sort((a, b) => b[1] - a[1])[0][0]);
}

// The map a world point is on: a city frame that holds it, else the preferred zone (where the quest
// says it is) when that holds it, else the smallest frame. Zone rectangles overlap at their borders.
function placeOn(s, preferred) {
    const c = containing(s);
    if (!c.length) return null;
    let frame = c.find(f => CITIES.has(f.ui_map));
    if (!frame && preferred) frame = c.find(f => preferred.has(f.ui_map));
    frame = frame || c[0];
    const [x, y] = toPercent(frame, s);
    return { map: frame.ui_map, x, y };
}
const r1 = v => Math.round(v * 10) / 10;

// Up to `max` spots for a set of spawn points: the densest 5x5 map-unit cells on the map that holds
// the most points (the quest's zone wins a tie), each as the mean of its cell.
function spots(points, preferred, max) {
    const placed = [];
    for (const s of points) {
        const p = placeOn(s, preferred);
        if (p) placed.push(p);
    }
    if (!placed.length) return [];
    const byMap = group(placed, p => p.map);
    let best = null;
    for (const [map, list] of byMap) {
        const score = list.length + (preferred && preferred.has(map) ? 0.5 : 0);
        if (!best || score > best.score || (score === best.score && map < best.map)) best = { map, list, score };
    }
    const cells = group(best.list, p => Math.floor(p.x / 5) + ':' + Math.floor(p.y / 5));
    const ranked = [...cells.values()].sort((a, b) => b.length - a.length || a[0].x - b[0].x);
    const out = [];
    for (const cell of ranked) {
        if (out.length >= max) break;
        const x = r1(cell.reduce((t, p) => t + p.x, 0) / cell.length);
        const y = r1(cell.reduce((t, p) => t + p.y, 0) / cell.length);
        // Not right next to one already chosen.
        if (out.every(o => Math.abs(o.x - x) + Math.abs(o.y - y) > 4)) out.push({ map: best.map, x, y });
    }
    return out;
}

// ---- which quests -----------------------------------------------------------------------------
const keep = new Map();
for (const q of quests) {
    if (q.title && allianceCan(q)) keep.set(q.id, q);
}

const needNpc = new Map();   // id -> Set of preferred maps
const needObject = new Map();
const needItem = new Set();
function want(table, id, preferred) {
    if (!table.has(id)) table.set(id, new Set());
    if (preferred) for (const m of preferred) table.get(id).add(m);
}

function questZones(q) {
    const set = new Set();
    if (q.zone_area && areaMap.has(q.zone_area)) set.add(areaMap.get(q.zone_area));
    return set;
}

const FLAG_TYPES = { 1: 'g', 41: 'p', 62: 'r', 81: 'd', 84: 's' };
const FLAG_MECHANICS = { 'group/elite': 'e', timed: 't', escort: 's' };
const OBJ_KIND = { kill: 'k', item: 'i', object: 'o', event: 'e', talk: 't' };

const records = [];
let objectiveSpots = 0;
for (const q of [...keep.values()].sort((a, b) => a.id - b.id)) {
    const zones = questZones(q);
    const giverList = (starts.get(q.id) || []).map(s => {
        if (s.kind === 'npc') { want(needNpc, s.id, zones); return 'n' + s.id; }
        if (s.kind === 'object') { want(needObject, s.id, zones); return 'o' + s.id; }
        needItem.add(s.id); return 'i' + s.id;
    });
    const enderList = (ends.get(q.id) || []).map(s => {
        if (s.kind === 'npc') { want(needNpc, s.id, zones); return 'n' + s.id; }
        want(needObject, s.id, zones); return 'o' + s.id;
    });
    // Prerequisites: only those an Alliance character can do (the rest can never be done).
    const pre = (prereqs.get(q.id) || []).filter(p => keep.has(p.pre)).map(p => {
        const letter = p.mode === 'any' ? 'y' : 'a';
        return (p.breadcrumb ? letter.toUpperCase() : letter) + p.pre;
    });
    let flags = '';
    const add = f => { if (!flags.includes(f)) flags += f; };
    if (FLAG_TYPES[q.type]) add(FLAG_TYPES[q.type]);
    for (const m of mechanics.get(q.id) || []) if (FLAG_MECHANICS[m.kind]) add(FLAG_MECHANICS[m.kind]);
    if (q.repeatable) add('R');
    const objs = (objectives.get(q.id) || []).sort((a, b) => a.n - b.n).map(o => {
        let text = OBJ_KIND[o.kind] + (o.target || '') + (o.count && o.count > 1 ? 'x' + o.count : '');
        let points = [];
        if (o.kind === 'kill' || o.kind === 'talk') {
            if (o.target) { want(needNpc, o.target); points = spawns.get('npc:' + o.target) || []; }
        } else if (o.kind === 'object') {
            if (o.target) { want(needObject, o.target); points = spawns.get('object:' + o.target) || []; }
        } else if (o.kind === 'item' && o.target) {
            needItem.add(o.target);
            const sources = (itemSources.get(o.target) || []).filter(s => s.kind !== 'item');
            sources.sort((a, b) => (b.chance || 0) - (a.chance || 0));
            for (const s of sources.slice(0, 6)) points = points.concat(spawns.get(s.kind + ':' + s.id) || []);
        }
        const found = spots(points, zones, 3);
        if (found.length) {
            objectiveSpots += found.length;
            text += '@' + found[0].map + ':' + found.map(p => p.x + ',' + p.y).join(';');
        }
        return text;
    });
    records.push({
        id: q.id,
        fields: [q.level || '', q.min_level || '', q.races || 0, q.classes || 0, giverList.join(','),
            enderList.join(','), pre.join(','), flags, objs.join('/'), q.title],
    });
}

// NPC and object records: name and up to three spots (a giver that walks, or stands in two places).
function placeRecords(table, kind, names) {
    const out = [];
    for (const [id, preferred] of [...table].sort((a, b) => a[0] - b[0])) {
        const row = names.get(id);
        const found = spots(spawns.get(kind + ':' + id) || [], preferred.size ? preferred : null, 3);
        const parts = [];
        let lastMap;
        for (const p of found) {
            parts.push((p.map !== lastMap ? p.map + ':' : '') + p.x + ',' + p.y);
            lastMap = p.map;
        }
        out.push({ id, text: parts.join(';') + '|' + ((row && row.name) || '') });
    }
    return out;
}
const npcRecords = placeRecords(needNpc, 'npc', npcs);
const objectRecords = placeRecords(needObject, 'object', objects);
const itemRecords = [...needItem].sort((a, b) => a - b).map(id => ({ id, text: (items.get(id) && items.get(id).name) || '' }))
    .filter(r => r.text);

// ---- write ------------------------------------------------------------------------------------
const lua = s => '"' + String(s).replace(/\\/g, '\\\\').replace(/"/g, '\\"').replace(/\n/g, '\\n') + '"';
const lines = [];
lines.push('-- LevelGuide quest database: GENERATED by tools\\gen_questdb.js; do not edit by hand.');
lines.push('-- Regenerate: node tools\\gen_questdb.js <path\\to\\forever-db> (see that script\'s header).');
lines.push('--');
lines.push('-- Built from forever-db ' + index.version + ' (client ' + index.clientBuild + '), the World of Warcraft: Forever');
lines.push('-- quest database of the Polestar project (https://github.com/fitzforge/polestar), GPL-3.0. This file is');
lines.push('-- a derived work and is licensed under the GNU General Public License version 3 (see LICENSE).');
lines.push('-- forever-db credits, which carry through to this file (NOTICE.md has them in full): EG Link output');
lines.push('-- (Efficient Games, CC BY 4.0), CMaNGOS classic-db (GPL-3.0), VMaNGOS through pfQuest and Factoruide');
lines.push('-- (GPL-2.0-or-later), ForeverTDB (GPL-2.0), QuestieDB, pfQuest (MIT, Copyright (c) 2017-2021 Eric');
lines.push('-- Mauser (Shagu)) and the game client\'s tables. The elite/timed/escort flags come from forever-db\'s');
lines.push('-- mechanic table, (c) the Polestar project, CC BY 4.0 (https://creativecommons.org/licenses/by/4.0/).');
lines.push('-- World of Warcraft names and game data (c) Blizzard Entertainment.');
lines.push('--');
lines.push('-- Records are strings, decoded on first use by QuestLookup.lua:');
lines.push('--   q[id] = "level|minLevel|races|classes|givers|enders|prereqs|flags|objectives|title"');
lines.push('--     givers/enders: n<npc> o<object> i<item>, comma-separated');
lines.push('--     prereqs: a<id> all, y<id> any, capital A / Y = breadcrumb (leads to it, not needed)');
lines.push('--     flags: g group, e elite, t timed, s escort, d dungeon, r raid, p pvp, R repeatable');
lines.push('--     objectives: "/"-separated <kind><target>[x<count>][@<map>:x,y;x,y]; kind k kill, i item,');
lines.push('--       o object, e event, t talk');
lines.push('--   n[npc] / o[object] = "<map>:x,y;x,y;<map>:x,y|name" (map percent, 0-100); i[item] = name');
lines.push('LevelGuideQuestDB = {');
lines.push('version = ' + lua(index.version) + ', build = ' + lua(index.clientBuild) + ',');
lines.push('maps = {');
for (const [id, name] of Object.entries(MAP_NAMES)) lines.push('[' + id + ']=' + lua(name) + ',');
lines.push('},');
lines.push('q = {');
for (const r of records) lines.push('[' + r.id + ']=' + lua(r.fields.join('|')) + ',');
lines.push('},');
lines.push('n = {');
for (const r of npcRecords) lines.push('[' + r.id + ']=' + lua(r.text) + ',');
lines.push('},');
lines.push('o = {');
for (const r of objectRecords) lines.push('[' + r.id + ']=' + lua(r.text) + ',');
lines.push('},');
lines.push('i = {');
for (const r of itemRecords) lines.push('[' + r.id + ']=' + lua(r.text) + ',');
lines.push('},');
lines.push('}');
const text = lines.join('\n') + '\n';
fs.writeFileSync(OUT, text, 'utf8');
console.log(`wrote ${OUT}: ${(text.length / 1024).toFixed(0)} KB, ${records.length} quests (of ${quests.length}), ` +
    `${npcRecords.length} npcs, ${objectRecords.length} objects, ${itemRecords.length} items, ${objectiveSpots} objective spots`);
