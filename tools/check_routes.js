#!/usr/bin/env node
// Checks every hand-written route step in LevelGuide\Routes.lua against LevelGuide\QuestDB.lua (quest IDs,
// titles, levels, giver / turn-in names, and coordinates more than 2 map points from the database) and
// writes the report to research\route_check.md. No network; runs our own Lua with fengari (tests\node_modules).
//
//     node tools\check_routes.js            -> writes research\route_check.md
//     node tools\check_routes.js --fix      -> also moves pick-up / turn-in coordinates that are off by more
//                                              than 2 points to QuestDB's spot, but only where the NPC name
//                                              matches, the NPC has a single spot, and the line isn't in
//                                              PROTECTED below (hand-checked spots)
'use strict';
const fs = require('fs');
const path = require('path');

const ROOT = path.join(__dirname, '..');
const LG = path.join(ROOT, 'LevelGuide');
const { lua, lauxlib, lualib, to_luastring } = require(path.join(ROOT, 'tests', 'node_modules', 'fengari'));

// Steps whose spots were checked by hand against in-game research (research\rxp_forever_guides.md section 4
// and the Night Elf side-step notes): never moved automatically.
const PROTECTED = [
    /Sentinel Dalia Sunblade/, /Eyes of the Sentinels/, /patrols/, /Mountaineer Kadrell/, /Deadwood Cauldron/, /Tooga/,
];
// Findings looked at and left as written, with why (shown in the report).
const KEPT = {
    'The Road to Darnassus': 'Moon Priestess Amara patrols the road (research\\rxp_forever_guides.md C12); QuestDB has one spawn point',
    'Rat Catching': 'Kadrell patrols Thelsamar (research\\rxp_forever_guides.md H11)',
    "Mountaineer Stormpike's Task": 'Kadrell patrols Thelsamar (research\\rxp_forever_guides.md H11)',
    'Stout to Kadrell': 'Kadrell patrols Thelsamar (research\\rxp_forever_guides.md H11)',
    'Report to Mountaineer Rockgar': 'Kadrell patrols Thelsamar (research\\rxp_forever_guides.md H11)',
    "Tooga's Quest": 'Tooga has several spots; the route uses one of them',
    'Falling to Corruption': 'the route points at the Timbermaw tunnel on the Winterspring map; the cauldron is in Felwood (the note says so)',
    'Mystery Goo': 'the route points at the Timbermaw tunnel on the Winterspring map; the cauldron is in Felwood (the note says so)',
    'Anything of Value': 'research\\routes_20_60.md already marks it unverified (no Forever data)',
    'Mrs. Dalson\'s Diary': 'the route names the outhouse the diary object sits in',
    'WANTED: Overseer Maltorius': 'the notice board is that object',
    "STOLEN: Smithing Tuyere and Lookout's Spyglass": 'the notice board is that object',
    'JOB OPPORTUNITY: Culling the Competition': 'the notice board is that object',
};
// What this pass changed in the route data because QuestDB clearly disagreed (kept here so the report
// says it after a rerun).
const FIXED = [
    'Routes.lua: Stormwind spots the research had marked U (from a guide on another Stormwind map) moved to QuestDB: Gilbert Gray (Fishin\' Time) 26.3, 47.1; Baros Alexston (Expanding Horizons) 57.8, 47.8; Furen Longbeard (Stormpike\'s Order) 64.6, 37.2; Argos Nightwhisper (The Corruption Abroad) 36.3, 67.6.',
    'Routes.lua: Ashenvale Maseara Autumnmoon (Vengeful Trail, Shared Fury) 81.0, 50.2 -> 86.3, 45.8; Teldrassil Sentinel Shayla Nightbreeze (Bounty: Gnarlpine Furbolg) 38.3, 54.4 -> 42.2, 51.3.',
    'Routes.lua: turn-ins the research left U now name QuestDB\'s NPC and spot: Westfall Stew -> Salma Saldean 56.4, 30.5; Searing Gorge WANTED: Overseer Maltorius -> Lookout Captain Lolo Longstriker 37.7, 26.6; STOLEN: Smithing Tuyere... and JOB OPPORTUNITY... -> Taskmaster Scrange 39.0, 27.5.',
    'Routes.lua: The Sprouted Fronds is handed back to the Sprouted Frond object (QuestDB), not Denalan (same spot).',
    'Routes.lua: In Favor of Elune picked up at level 5 (QuestDB minimum level), not 4.',
    'Routes.lua: three NPC notes said "<name>, Darnassus" inside parentheses (Doling Justice part 2, Glyphed Oaken Branch, Velinde Starsong), which made LevelGuide treat the step\'s zone coordinates as Darnassus city coordinates; reworded, and LevelGuide.lua CityToZone now ignores text in parentheses.',
    'QuestIDs.lua: renamed aliases for titles QuestDB spells differently (In Search of the Excavation Team, Plea to the Alliance, Wanted!  Marez Cowl, Wanted!  Otto and Falconcrest, "The Ruins of Solarsal " with its trailing space), so either spelling matches the log, a giver\'s list or the map.',
];

function runChecker() {
    const L = lauxlib.luaL_newstate();
    lualib.luaL_openlibs(L);
    lua.lua_pushstring(L, to_luastring(LG.replace(/\\/g, '/')));
    lua.lua_setglobal(L, to_luastring('LG_PATH'));
    let status = lauxlib.luaL_loadfile(L, to_luastring(path.join(__dirname, 'check_routes.lua')));
    if (status === lua.LUA_OK) status = lua.lua_pcall(L, 0, 1, 0);
    if (status !== lua.LUA_OK) throw new Error(lua.lua_tojsstring(L, -1));
    return lua.lua_tojsstring(L, -1);
}

const routesPath = path.join(LG, 'Routes.lua');
const source = fs.readFileSync(routesPath, 'utf8').split('\n');
const fmt = v => {
    const n = Number(v);
    return [n.toFixed(1), String(n), n.toFixed(2)];
};
// The Routes.lua line of a step: the title and both coordinates on one line.
function findLine(title, x, y, t) {
    const quoted = '"' + title + '"';
    const xs = fmt(x), ys = fmt(y);
    const head = { accept: 'A(', turnin: 'T(', do: 'D(' }[t];
    let fallback = null;
    for (let i = 0; i < source.length; i++) {
        const line = source[i];
        if (!line.includes(quoted)) continue;
        if (head && !line.includes(head + quoted)) continue;
        if (xs.some(a => ys.some(b => line.includes(a + ', ' + b)))) return i + 1;
        fallback = fallback || i + 1;
    }
    return fallback;
}

const rows = runChecker().split('\n').filter(Boolean).map(l => l.split('\t'));
const stats = rows.shift();
const findings = rows.map(([category, zone, index, t, title, part, message, fix]) => ({ category, zone, index: Number(index), t, title, part, message, fix }));
for (const f of findings) {
    const m = f.message.match(/^([\d.]+), ([\d.]+) is/);
    f.line = m ? findLine(f.title, m[1], m[2], f.t) : findLine(f.title, null, null, f.t);
}

const fixMode = process.argv.includes('--fix');
const fixed = [];
if (fixMode) {
    for (const f of findings) {
        if (f.category !== 'coords' || !f.fix || !f.line) continue;
        const i = f.line - 1;
        const line = source[i];
        if (PROTECTED.some(re => re.test(line))) { f.kept = 'protected'; continue; }
        const m = f.message.match(/^([\d.]+), ([\d.]+) is/);
        const [nx, ny] = f.fix.split(',');
        let done = false;
        for (const a of fmt(m[1])) for (const b of fmt(m[2])) {
            if (!done && line.includes(a + ', ' + b)) {
                source[i] = line.replace(a + ', ' + b, nx + ', ' + ny);
                done = true;
            }
        }
        if (done) { f.applied = nx + ', ' + ny; fixed.push(f); }
    }
    fs.writeFileSync(routesPath, source.join('\n'), 'utf8');
}

const order = ['id', 'title', 'part', 'npc', 'coords', 'level', 'level-info'];
const heads = {
    id: 'Wrong quest IDs (QuestIDs.lua)', title: 'Titles QuestDB does not know as written', part: 'Parts beyond the known IDs',
    npc: 'Giver / turn-in names that differ', coords: 'Coordinates more than 2 map points off', level: 'Levels below the minimum',
    'level-info': 'Red pick-ups (quest 6+ levels above the step; for information, often deliberate)',
};
const out = [];
out.push('# Route check: Routes.lua against QuestDB');
out.push('');
out.push('Generated by `node tools\\check_routes.js` from `LevelGuide\\QuestDB.lua` (forever-db ' +
    (fs.readFileSync(path.join(LG, 'QuestDB.lua'), 'utf8').match(/version = "([^"]+)"/) || [])[1] + ').');
out.push(`Checked: ${stats.slice(1).join(', ')}. Findings: ${findings.length}.`);
out.push('');
out.push('Each line: route (key) #step, Routes.lua line, step type, title (part), what differs. "fix" is QuestDB\'s');
out.push('spot for a pick-up / turn-in whose NPC name matches and has one spot; `--fix` applies those.');
out.push('');
const counts = {};
for (const f of findings) counts[f.category] = (counts[f.category] || 0) + 1;
out.push('| Category | Count |');
out.push('|---|---|');
for (const c of order) if (counts[c]) out.push(`| ${heads[c]} | ${counts[c]} |`);
out.push('');
out.push('## Fixed after the first run');
out.push('');
for (const line of FIXED) out.push('- ' + line);
out.push('');
for (const c of order) {
    const list = findings.filter(f => f.category === c);
    if (!list.length) continue;
    out.push('## ' + heads[c]);
    out.push('');
    for (const f of list) {
        const where = `${f.zone} #${f.index} (Routes.lua:${f.line || '?'})`;
        let tail = f.fix ? ` fix: ${f.fix}.` : '';
        if (f.applied) tail += ' **Applied.**';
        if (f.kept) tail += ` Kept (${f.kept}).`;
        else if (KEPT[f.title] && !f.applied) tail += ` Left as written: ${KEPT[f.title]}.`;
        out.push(`- ${where} ${f.t} "${f.title}"${f.part !== '1' ? ' (' + f.part + ')' : ''}: ${f.message}.${tail}`);
    }
    out.push('');
}
const reportPath = path.join(ROOT, 'research', 'route_check.md');
fs.writeFileSync(reportPath, out.join('\n'), 'utf8');
console.log(`${stats.slice(1).join(', ')}; ${findings.length} findings ` +
    order.filter(c => counts[c]).map(c => `${c} ${counts[c]}`).join(', ') + (fixMode ? `; ${fixed.length} coordinates fixed` : '') +
    ` -> ${reportPath}`);
