#!/usr/bin/env node
// Builds LevelGuide\QuestRewards.lua: the reward items of each quest the leveling guide knows, from ALL THE
// THINGS' Forever ("Camelot") database (https://github.com/ATTWoWAddon/AllTheThings, folder db/Camelot,
// MIT License, Copyright (c) 2026 AllTheThings WoW Addon). No network; ATT's files are read as TEXT and
// parsed here. Nothing from them is loaded, required or run.
//
// Regenerate (from the repo root, with ATT's Categories files saved somewhere outside the repo):
//
//     node tools\gen_questrewards.js <...\db\Camelot\Categories\Zones.lua> [more category files] [--out <file>]
//
// What goes in: for every quest `q(<questID>, { ... g = { ... } })`, the items in its g (rewards) list,
// written by ATT as `i(<itemID>...)` or `s(<sourceID>, <itemID>...)` (an item with an appearance). Items
// under a nested quest, quest objective (qo) or recipe (r) belong to those, not to the quest. ATT does not
// say which rewards are a choice and which are given; ItemAdvisor judges each one in game.
// Only quests the guide knows are kept: those in LevelGuide\QuestDB.lua (forever-db) or LevelGuide\QuestIDs.lua.
'use strict';
const fs = require('fs');
const path = require('path');

const args = process.argv.slice(2);
let OUT = path.join(__dirname, '..', 'LevelGuide', 'QuestRewards.lua');
const inputs = [];
for (let i = 0; i < args.length; i++) {
    if (args[i] === '--out') OUT = args[++i];
    else inputs.push(args[i]);
}
if (inputs.length === 0 || !inputs.every(f => fs.existsSync(f))) {
    console.error('usage: node tools/gen_questrewards.js <ATT db/Camelot/Categories/Zones.lua> [more.lua] [--out file]');
    process.exit(2);
}

// Quest -> Set of item IDs, from one ATT category file.
function parse(text, rewards) {
    const stack = [];          // { kind: '(' | '{', fn, id }
    const ident = /[A-Za-z_][A-Za-z0-9_]*/y;
    const lead = /\s*(-?\d+)\s*(?:,\s*(-?\d+))?/y;
    let i = 0;
    const n = text.length;
    while (i < n) {
        const ch = text[i];
        if (ch === '-' && text[i + 1] === '-') {               // comment to end of line
            while (i < n && text[i] !== '\n') i++;
            continue;
        }
        if (ch === '"' || ch === "'") {                         // string literal
            i++;
            while (i < n && text[i] !== ch) i += text[i] === '\\' ? 2 : 1;
            i++;
            continue;
        }
        if (ch === '[' && (text[i + 1] === '[' || text[i + 1] === '=')) {   // long string
            const m = /^\[(=*)\[/.exec(text.slice(i, i + 20));
            if (m) {
                const close = ']' + m[1] + ']';
                const end = text.indexOf(close, i + m[0].length);
                i = end < 0 ? n : end + close.length;
                continue;
            }
        }
        if (/[A-Za-z_]/.test(ch) && !/[A-Za-z0-9_.]/.test(text[i - 1] || ' ')) {
            ident.lastIndex = i;
            const m = ident.exec(text);
            const name = m[0];
            let j = i + name.length;
            if (text[j] === '(') {
                lead.lastIndex = j + 1;
                const a = lead.exec(text);
                const frame = { kind: '(', fn: name };
                if (a) {
                    if (name === 'q') frame.id = +a[1];
                    if (name === 'i') frame.item = +a[1];
                    if (name === 's' && a[2] !== undefined) frame.item = +a[2];
                }
                if (frame.item) {
                    // The innermost enclosing call that owns rewards decides whose item this is.
                    for (let k = stack.length - 1; k >= 0; k--) {
                        const f = stack[k];
                        if (f.fn === 'qo' || f.fn === 'r' || f.fn === 'i' || f.fn === 's') break;
                        if (f.fn === 'q') {
                            if (f.id > 0) {
                                if (!rewards.has(f.id)) rewards.set(f.id, new Set());
                                rewards.get(f.id).add(frame.item);
                            }
                            break;
                        }
                    }
                }
                stack.push(frame);
                i = j + 1;
                continue;
            }
            i = j;
            continue;
        }
        if (ch === '(' || ch === '{') stack.push({ kind: ch });
        else if (ch === ')' || ch === '}') stack.pop();
        i++;
    }
}

// Quest IDs the guide knows.
function knownQuests() {
    const known = new Set();
    const root = path.join(__dirname, '..', 'LevelGuide');
    const db = fs.readFileSync(path.join(root, 'QuestDB.lua'), 'utf8');
    const qStart = db.indexOf('\nq = {');
    const qEnd = db.indexOf('\n},', qStart);
    for (const m of db.slice(qStart, qEnd).matchAll(/^\[(\d+)\]="/gm)) known.add(+m[1]);
    const ids = fs.readFileSync(path.join(root, 'QuestIDs.lua'), 'utf8');
    for (const m of ids.matchAll(/\]\s*=\s*\{([\d,\s]+)\}/g)) {
        for (const id of m[1].split(',')) if (id.trim()) known.add(+id);
    }
    return known;
}

const rewards = new Map();
for (const file of inputs) parse(fs.readFileSync(file, 'utf8'), rewards);
const known = knownQuests();
const ids = [...rewards.keys()].filter(id => known.has(id)).sort((a, b) => a - b);

const lines = [];
lines.push('-- LevelGuide quest rewards: GENERATED by tools\\gen_questrewards.js; do not edit by hand.');
lines.push('-- Regenerate: node tools\\gen_questrewards.js <ATT db\\Camelot\\Categories\\Zones.lua> (see that script\'s header).');
lines.push('--');
lines.push('-- Reward item IDs per quest, from ALL THE THINGS\' World of Warcraft: Forever ("Camelot") database,');
lines.push('-- https://github.com/ATTWoWAddon/AllTheThings (db/Camelot), used under the MIT License:');
lines.push('--');
lines.push('--   MIT License');
lines.push('--');
lines.push('--   Copyright (c) 2026 AllTheThings WoW Addon');
lines.push('--');
lines.push('--   Permission is hereby granted, free of charge, to any person obtaining a copy');
lines.push('--   of this software and associated documentation files (the "Software"), to deal');
lines.push('--   in the Software without restriction, including without limitation the rights');
lines.push('--   to use, copy, modify, merge, publish, distribute, sublicense, and/or sell');
lines.push('--   copies of the Software, and to permit persons to whom the Software is');
lines.push('--   furnished to do so, subject to the following conditions:');
lines.push('--');
lines.push('--   The above copyright notice and this permission notice shall be included in all');
lines.push('--   copies or substantial portions of the Software.');
lines.push('--');
lines.push('--   THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR');
lines.push('--   IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,');
lines.push('--   FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE');
lines.push('--   AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER');
lines.push('--   LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,');
lines.push('--   OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE');
lines.push('--   SOFTWARE.');
lines.push('--');
lines.push('-- Only quests in QuestDB.lua or QuestIDs.lua are kept. r[questID] = "itemID,itemID,...": every reward ATT');
lines.push('-- lists (chosen or given; ATT doesn\'t say which). Names, stats and slots come from the game at run time.');
lines.push(`-- ${ids.length} quests, ${ids.reduce((s, id) => s + rewards.get(id).size, 0)} reward items.`);
lines.push('LevelGuideQuestRewards = {');
lines.push('source = "ATT db/Camelot",');
lines.push('r = {');
for (const id of ids) lines.push(`[${id}]="${[...rewards.get(id)].sort((a, b) => a - b).join(',')}",`);
lines.push('},');
lines.push('}');
fs.writeFileSync(OUT, lines.join('\n') + '\n', 'utf8');
console.log(`${OUT}: ${ids.length} quests with rewards (${rewards.size} in ATT's files, ${known.size} known to the guide)`);
