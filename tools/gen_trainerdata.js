// Generates TrainerNotes\Data.lua from What's Training's Forever ("Camelot") class data.
//
// What's Training (https://github.com/fusionpit/WhatsTraining) is MIT licensed, Copyright (c) 2019
// (see NOTICE.md). Its Classes\Camelot\*.lua files are read here as TEXT: a small Lua table-literal
// reader below turns them into JSON-like values. Nothing from them is executed.
//
// Usage:  node tools\gen_trainerdata.js <path to WhatsTraining\Classes\Camelot> [out file]
// Default out file: TrainerNotes\Data.lua next to this tools folder.
'use strict';
const fs = require('fs');
const path = require('path');

const src = process.argv[2];
if (!src || !fs.existsSync(src)) {
    console.error('usage: node gen_trainerdata.js <WhatsTraining\\Classes\\Camelot> [out]');
    process.exit(1);
}
const out = process.argv[3] || path.join(__dirname, '..', 'TrainerNotes', 'Data.lua');

// ---- a tiny reader for Lua table literals -------------------------------------------------------
function tokenize(text) {
    const tokens = [];
    let i = 0;
    while (i < text.length) {
        const c = text[i];
        if (/\s/.test(c)) { i++; continue; }
        if (text.startsWith('--[[', i)) { const e = text.indexOf(']]', i); i = e < 0 ? text.length : e + 2; continue; }
        if (text.startsWith('--', i)) { const e = text.indexOf('\n', i); i = e < 0 ? text.length : e + 1; continue; }
        if (c === '"' || c === "'") {
            let j = i + 1, s = '';
            while (j < text.length && text[j] !== c) { if (text[j] === '\\') { j++; } s += text[j]; j++; }
            tokens.push({ t: 'str', v: s }); i = j + 1; continue;
        }
        const num = /^-?\d+(\.\d+)?/.exec(text.slice(i, i + 32));
        if (num && (c !== '-' || /\d/.test(text[i + 1]))) { tokens.push({ t: 'num', v: Number(num[0]) }); i += num[0].length; continue; }
        const id = /^[A-Za-z_][A-Za-z0-9_]*(\.[A-Za-z_][A-Za-z0-9_]*)*/.exec(text.slice(i, i + 200));
        if (id) { tokens.push({ t: 'id', v: id[0] }); i += id[0].length; continue; }
        if (text.startsWith('...', i)) { tokens.push({ t: 'p', v: '...' }); i += 3; continue; }
        tokens.push({ t: 'p', v: c }); i++;
    }
    return tokens;
}

function readFile(file) {
    const tokens = tokenize(fs.readFileSync(file, 'utf8'));
    const locals = {}, assigned = {};
    let p = 0;
    const peek = (k = 0) => tokens[p + k];
    function expr() {
        const tk = tokens[p];
        if (!tk) return null;
        if (tk.t === 'p' && tk.v === '{') return table();
        p++;
        if (tk.t === 'num' || tk.t === 'str') return tk.v;
        if (tk.t === 'id') {
            if (tk.v === 'true') return true;
            if (tk.v === 'false') return false;
            if (tk.v === 'nil') return null;
            if (peek() && peek().v === '(') { // a call: skip its arguments
                let depth = 0;
                do { const x = tokens[p++]; if (x.v === '(') depth++; else if (x.v === ')') depth--; } while (depth > 0 && p < tokens.length);
                return null;
            }
            return Object.prototype.hasOwnProperty.call(locals, tk.v) ? locals[tk.v] : null;
        }
        return null;
    }
    function table() {
        p++; // {
        const arr = [], obj = {};
        let isObj = false;
        while (p < tokens.length && !(peek().t === 'p' && peek().v === '}')) {
            let key = null;
            if (peek().v === '[') { p++; key = expr(); p++; p++; } // [k] =
            else if (peek().t === 'id' && peek(1) && peek(1).v === '=' && !peek().v.includes('.')) { key = peek().v; p += 2; }
            const value = expr();
            if (key === null) arr.push(value); else { obj[key] = value; isObj = true; }
            if (peek() && (peek().v === ',' || peek().v === ';')) p++;
        }
        p++; // }
        if (isObj) { arr.forEach((v, k) => { obj[k + 1] = v; }); return obj; }
        return arr;
    }
    while (p < tokens.length) {
        const tk = peek();
        if (tk.t === 'id' && tk.v === 'local' && peek(1) && peek(1).t === 'id' && peek(2) && peek(2).v === '=') {
            const name = peek(1).v; p += 3; locals[name] = expr(); continue;
        }
        if (tk.t === 'id' && tk.v.includes('.') && peek(1) && peek(1).v === '=' && peek(2) && peek(2).v !== '=') {
            const name = tk.v; p += 2; assigned[name] = expr(); continue;
        }
        p++;
    }
    return { locals, assigned };
}

// ---- Lua writer -----------------------------------------------------------------------------------
function lua(v) {
    if (v === null || v === undefined) return 'nil';
    if (typeof v === 'number') return String(v);
    if (typeof v === 'boolean') return String(v);
    if (typeof v === 'string') return JSON.stringify(v);
    if (Array.isArray(v)) return '{ ' + v.map(lua).join(', ') + ' }';
    return '{ ' + Object.keys(v).map(k => (/^[A-Za-z_]\w*$/.test(k) ? k : `[${JSON.stringify(Number(k)) === 'null' ? JSON.stringify(k) : k}]`) + ' = ' + lua(v[k])).join(', ') + ' }';
}

const CLASSES = ['Druid', 'Hunter', 'Mage', 'Paladin', 'Priest', 'Rogue', 'Shaman', 'Warlock', 'Warrior'];
const lines = [];
lines.push('-- TrainerNotes data: every class trainer spell on World of Warcraft: Forever, 1-60, by level.');
lines.push('-- GENERATED by tools\\gen_trainerdata.js; do not edit by hand.');
lines.push('-- Source: What\'s Training (https://github.com/fusionpit/WhatsTraining), Classes\\Camelot\\*.lua,');
lines.push('-- MIT License, Copyright (c) 2019 (full text and credit in NOTICE.md). Facts only (spell IDs, levels,');
lines.push('-- costs in copper, prerequisites, races/factions); re-shaped into our own format.');
lines.push('--');
lines.push('-- classes[CLASS].spells: { level, spellID, cost, req = { spellIDs needed first }, talent = talent spellID,');
lines.push('--   race = raceID or races = { raceIDs }, faction = "Alliance"/"Horde" }');
lines.push('-- classes[CLASS].ranks: rank groups, lowest rank first (spells the trainer teaches as ranks of one spell).');
lines.push('-- questSpells[CLASS][spellID] = { { races, level, quests } } (spells taught by a class quest, not a trainer).');
lines.push('-- tomes: warlock demon tomes { level, itemID, cost, family, spell }; tomeMerchants: NPC IDs that sell them.');
lines.push('-- trainerFactions[CLASS] = { Alliance = { factionIDs }, Horde = { factionIDs } }: Honored with one of them');
lines.push('--   gives 10 % off at that faction\'s trainers (tomes are never discounted on Forever).');
lines.push('TrainerNotesData = {');
lines.push('    classes = {');
let rowCount = 0;
const summary = [];
for (const cls of CLASSES) {
    const data = readFile(path.join(src, cls + '.lua'));
    const byLevel = data.assigned['class.spellsByLevel'] || {};
    const rows = [];
    const reqBy = {};
    for (const levelKey of Object.keys(byLevel).map(Number).sort((a, b) => a - b)) {
        for (const s of byLevel[levelKey] || []) {
            if (!s || typeof s.id !== 'number') continue;
            const row = [levelKey, s.id, s.cost || 0];
            const extra = {};
            if (Array.isArray(s.requiredIds) && s.requiredIds.length) {
                extra.req = s.requiredIds;
                for (const r of s.requiredIds) (reqBy[r] = reqBy[r] || []).push(s.id);
            }
            if (s.requiredTalentId) extra.talent = s.requiredTalentId;
            if (s.race) extra.race = s.race;
            if (Array.isArray(s.races)) extra.races = s.races;
            if (s.faction) extra.faction = s.faction;
            rows.push({ row, extra, id: s.id, req: s.requiredIds || [] });
        }
    }
    // Rank groups: WT's explicit groups first, then chains where a spell needs exactly one earlier
    // spell that nothing else needs (rank N needs rank N-1). ReadyCheck also checks the two spells'
    // names in game before it calls one an older rank of the other.
    const groups = [];
    const inGroup = {};
    for (const g of data.assigned['class.overriddenGroups'] || []) {
        if (Array.isArray(g) && g.length > 1) { groups.push(g); g.forEach(id => { inGroup[id] = true; }); }
    }
    const trainable = new Set(rows.map(r => r.id));
    const next = {}, prev = {};
    for (const r of rows) {
        if (r.req.length === 1) {
            const q = r.req[0];
            if ((reqBy[q] || []).length === 1 && !inGroup[q] && !inGroup[r.id]) { next[q] = r.id; prev[r.id] = q; }
        }
    }
    for (const r of rows) {
        const id = r.id;
        if (prev[id] || !next[id] || inGroup[id]) continue;
        const chain = [id];
        let cur = id;
        while (next[cur]) { cur = next[cur]; chain.push(cur); }
        groups.push(chain);
        chain.forEach(x => { inGroup[x] = true; });
    }
    // A chain's first link may be a rank 1 the trainer doesn't sell (learned at level 1 or from a quest).
    void trainable;
    lines.push(`        ${cls.toUpperCase()} = {`);
    lines.push('            spells = {');
    for (const r of rows) {
        const parts = r.row.map(String);
        for (const k of Object.keys(r.extra)) parts.push(`${k} = ${lua(r.extra[k])}`);
        lines.push(`                { ${parts.join(', ')} },`);
    }
    lines.push('            },');
    lines.push('            ranks = {');
    for (const g of groups) lines.push(`                ${lua(g)},`);
    lines.push('            },');
    lines.push('        },');
    rowCount += rows.length;
    summary.push(`${cls}: ${rows.length} spells, ${groups.length} rank groups`);
}
lines.push('    },');

// Class-quest spells.
const qs = readFile(path.join(src, 'QuestSpells.lua')).locals.QuestSpells || {};
lines.push('    questSpells = {');
let qsCount = 0;
for (const cls of Object.keys(qs).sort()) {
    lines.push(`        ${cls} = {`);
    for (const id of Object.keys(qs[cls]).map(Number).sort((a, b) => a - b)) {
        const entries = (qs[cls][id] || []).map(e => ({ races: e.races, level: e.level, quests: e.quests }));
        lines.push(`            [${id}] = ${lua(entries)},`);
        qsCount++;
    }
    lines.push('        },');
}
lines.push('    },');

// Warlock tomes.
const tomes = readFile(path.join(src, 'WarlockTomes.lua'));
const tomesByLevel = tomes.assigned['class.tomesByLevel'] || {};
const taught = tomes.assigned['class.tomeTaughtSpells'] || {};
lines.push('    tomes = {');
let tomeCount = 0;
for (const levelKey of Object.keys(tomesByLevel).map(Number).sort((a, b) => a - b)) {
    for (const t of tomesByLevel[levelKey] || []) {
        if (!t || typeof t.itemId !== 'number') continue;
        lines.push(`        { ${levelKey}, ${t.itemId}, ${t.cost || 0}, ${lua(t.family)}, ${lua(taught[t.itemId] || null)} },`);
        tomeCount++;
    }
}
lines.push('    },');
lines.push(`    tomeMerchants = ${lua(Object.keys(tomes.assigned['wt.WarlockTomeMerchantIds'] || {}).map(Number).sort((a, b) => a - b))},`);

// Trainer factions (reputation discount).
const tf = readFile(path.join(src, 'TrainerFactions.lua')).assigned['wt.TrainerFactions'] || {};
lines.push('    trainerFactions = {');
for (const cls of Object.keys(tf.roles || {}).sort()) {
    if (cls === 'PET') continue;
    lines.push(`        ${cls} = ${lua(tf.roles[cls])},`);
}
lines.push('    },');
lines.push('}');
fs.writeFileSync(out, lines.join('\r\n') + '\r\n');
console.log(summary.join('\n'));
console.log(`${rowCount} trainer rows, ${qsCount} quest spells, ${tomeCount} tomes -> ${out}`);
