#!/usr/bin/env node
// Offline audit: compares LevelGuide's quest data (QuestDB.lua, Prereqs.lua, QuestIDs.lua, QuestRules.lua) with a
// local QuestieDB checkout and PRINTS the differences, so each one can be checked by hand (Wowhead Forever, in
// game) before anything goes into our own files. It only reads Questie's files as text (regular expressions; no
// Lua is run) and writes nothing: QuestieDB's data is "all rights reserved when in doubt" and is never shipped.
//
//     node tools\audit_questie.js <path\to\QuestieDB> [--all]
//
// Without --all only quests our routes use (QuestIDs.lua, Prereqs.lua) are listed. Sections:
//   exclusive   Questie exclusiveTo groups that QuestRules.lua doesn't have
//   prereq      Questie preQuestGroup / preQuestSingle entries our QuestDB/Prereqs don't have (and the reverse)
//   next        nextQuestInChain;  disabled  disabledByQuest;  crumb  breadcrumbForQuestId
//   missing     Forever-range quests (90000+) Questie has and our QuestDB doesn't, and the reverse
//   spot        NPC spawns that differ from our QuestDB's spot by more than 1.5 map units (same zone name)
'use strict';
const fs = require('fs');
const path = require('path');

const SRC = process.argv[2];
const ALL = process.argv.includes('--all');
const ROOT = path.join(__dirname, '..');
const FOREVER = SRC && path.join(SRC, 'src', 'corrections', 'Forever');
if (!SRC || !fs.existsSync(FOREVER)) {
    console.error('usage: node tools/audit_questie.js <QuestieDB folder> [--all]');
    process.exit(2);
}
const read = p => fs.readFileSync(p, 'utf8');

// ---- Questie (text only) --------------------------------------------------------------------------
// Splits a corrections file into "[id] = { ... }," records at two levels of nesting and pulls out the keys we
// compare. Later files override earlier ones, as Questie applies them.
function questieRecords(file, keyName) {
    const out = new Map();
    if (!fs.existsSync(file)) return out;
    const text = read(file);
    const re = /^\s{8}\[(\d+)\]\s*=\s*\{([^\n]*)\n([\s\S]*?)^\s{8}\},?/gm;
    let m;
    while ((m = re.exec(text))) {
        const id = Number(m[1]);
        const body = m[3];
        const rec = out.get(id) || {};
        rec.title = rec.title || (m[2].match(/--\s*(.*?)(?:\s*:\s*https?:.*)?$/) || [])[1];
        const keyRe = new RegExp('\\[' + keyName + '\\.(\\w+)\\]\\s*=\\s*(.*?),?\\s*$', 'gm');
        let k;
        while ((k = keyRe.exec(body))) rec[k[1]] = k[2];
        out.set(id, rec);
    }
    return out;
}
const numbers = v => (v ? (v.match(/-?\d+(?:\.\d+)?/g) || []).map(Number) : []);
const questFiles = [
    path.join(FOREVER, 'legacy', 'classicQuestFixes.lua'),
    path.join(FOREVER, 'generated', 'foreverBaseQuest.lua'),
    path.join(FOREVER, 'traces', 'foreverQuestTraces.lua'),
    path.join(FOREVER, 'foreverQuestFixes.lua'),
];
const qq = new Map();
for (const f of questFiles) {
    for (const [id, rec] of questieRecords(f, 'questKeys')) qq.set(id, Object.assign(qq.get(id) || {}, rec));
}
const npcFiles = [
    path.join(FOREVER, 'legacy', 'classicNPCFixes.lua'),
    path.join(FOREVER, 'generated', 'foreverBaseNpc.lua'),
    path.join(FOREVER, 'traces', 'foreverNpcTraces.lua'),
    path.join(FOREVER, 'foreverNPCFixes.lua'),
];
const qn = new Map();
for (const f of npcFiles) {
    for (const [id, rec] of questieRecords(f, 'npcKeys')) qn.set(id, Object.assign(qn.get(id) || {}, rec));
}

// ---- ours ---------------------------------------------------------------------------------------
const qdbText = read(path.join(ROOT, 'LevelGuide', 'QuestDB.lua'));
const ours = new Map();
for (const m of qdbText.matchAll(/^\[(\d+)\]="([^"]*)",$/gm)) {
    const f = m[2].split('|');
    if (f.length >= 10) ours.set(Number(m[1]), { pre: f[6], title: f.slice(9).join('|') });
}
const npcs = new Map();
const nSection = qdbText.split('\nn = {')[1] || '';
for (const m of nSection.split('\no = {')[0].matchAll(/^\[(\d+)\]="([^"]*)\|([^"|]*)",$/gm)) {
    npcs.set(Number(m[1]), { where: m[2], name: m[3] });
}
const mapNames = {};
for (const m of qdbText.matchAll(/^\[(\d+)\]="([^"]*)",$/gm)) if (Number(m[1]) < 3000 && !ours.has(Number(m[1]))) mapNames[m[1]] = m[2];
const routeIDs = new Set();
for (const m of read(path.join(ROOT, 'LevelGuide', 'QuestIDs.lua')).matchAll(/\{([\d,\s]+)\}/g)) numbers(m[1]).forEach(n => routeIDs.add(n));
const prereqText = read(path.join(ROOT, 'LevelGuide', 'Prereqs.lua'));
for (const m of prereqText.matchAll(/(?:all|any)\s*=\s*\{([\d,\s]+)\}/g)) numbers(m[1]).forEach(n => routeIDs.add(n));
const rulesText = fs.existsSync(path.join(ROOT, 'LevelGuide', 'QuestRules.lua')) ? read(path.join(ROOT, 'LevelGuide', 'QuestRules.lua')) : '';
const relevant = id => ALL || routeIDs.has(id);
const name = id => (ours.get(id) && ours.get(id).title) || (qq.get(id) && qq.get(id).title) || '?';
const lines = [];
const say = (section, id, text) => lines.push(`${section.padEnd(9)} ${String(id).padStart(6)} ${name(id)}: ${text}`);

// ---- compare --------------------------------------------------------------------------------------
for (const [id, rec] of [...qq].sort((a, b) => a[0] - b[0])) {
    if (!relevant(id)) continue;
    const mine = ours.get(id);
    const myPre = new Set(numbers(mine && mine.pre && mine.pre.replace(/[AY]\d+/g, '')));
    const ex = numbers(rec.exclusiveTo);
    for (const other of ex) {
        if (!new RegExp('\\{[^}]*\\b' + id + '\\b[^}]*\\b' + other + '\\b|\\{[^}]*\\b' + other + '\\b[^}]*\\b' + id + '\\b').test(rulesText)) {
            say('exclusive', id, `Questie: exclusive with ${other} (${name(other)})`);
        }
    }
    for (const key of ['preQuestGroup', 'preQuestSingle']) {
        for (const pre of numbers(rec[key])) {
            if (pre > 0 && !myPre.has(pre) && !new RegExp('\\b' + pre + '\\b').test(prereqText)) {
                say('prereq', id, `Questie ${key} has ${pre} (${name(pre)}); ours: ${mine ? mine.pre || 'none' : 'not in QuestDB'}`);
            }
        }
    }
    const next = numbers(rec.nextQuestInChain)[0];
    if (next) say('next', id, `Questie: next in chain ${next} (${name(next)})`);
    const dis = numbers(rec.disabledByQuest)[0];
    if (dis) say('disabled', id, `Questie: disabled while ${dis} (${name(dis)}) is in the log`);
    const crumb = numbers(rec.breadcrumbForQuestId)[0];
    if (crumb) {
        const target = ours.get(crumb);
        const marked = target && new RegExp('[AY]' + id + '\\b').test(target.pre);
        if (!marked) say('crumb', id, `Questie: breadcrumb for ${crumb} (${name(crumb)}); ours doesn't mark it`);
    }
}
for (const id of [...qq.keys()].filter(i => i >= 90000 && !ours.has(i)).sort((a, b) => a - b)) {
    if (ALL) say('missing', id, 'in Questie, not in our QuestDB');
}
for (const id of [...ours.keys()].filter(i => i >= 90000 && !qq.has(i)).sort((a, b) => a - b)) {
    if (relevant(id)) say('missing', id, 'in our QuestDB, not in Questie (removed? new?)');
}
const zoneName = z => z.toLowerCase().replace(/_/g, ' ');
for (const [id, rec] of [...qn].sort((a, b) => a[0] - b[0])) {
    const mine = npcs.get(id);
    if (!mine || !rec.spawns) continue;
    const ourSpots = [];
    let map;
    for (const part of mine.where.split(';')) {
        const m = part.match(/^(?:(\d+):)?([\d.]+),([\d.]+)$/);
        if (!m) continue;
        if (m[1]) map = m[1];
        ourSpots.push({ zone: (mapNames[map] || '').toLowerCase(), x: Number(m[2]), y: Number(m[3]) });
    }
    for (const z of rec.spawns.matchAll(/\[zoneIDs\.(\w+)\]\s*=\s*\{((?:\{[\d.,\s-]+\},?\s*)+)\}/g)) {
        const zone = zoneName(z[1]);
        for (const p of z[2].matchAll(/\{(-?[\d.]+),\s*(-?[\d.]+)/g)) {
            const x = Number(p[1]), y = Number(p[2]);
            const same = ourSpots.filter(s => s.zone === zone);
            if (same.length && same.every(s => Math.hypot(s.x - x, s.y - y) > 1.5)) {
                lines.push(`spot      npc ${id} ${mine.name}: Questie ${zone} ${x}, ${y}; ours ${same.map(s => s.x + ', ' + s.y).join(' / ')}`);
            }
        }
    }
}
console.log(lines.join('\n'));
console.error(`${lines.length} differences (${ALL ? 'all quests' : 'route quests only; --all for every quest'}). ` +
    'Each is a lead to check by hand, never data to copy.');
