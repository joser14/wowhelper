// Parses LevelGuide data files (Routes.lua, QuestIDs.lua, Prereqs.lua) into JSON for review checks.
const fs = require('fs');
const path = require('path');
const WS = 'C:/Users/you/AppData/Local/Claude-Data/claude_pzs8sxrjxfjjc/scratch-workspaces/c73d4152-ec25-4579-8c12-afe6c58434bb/b2b91152-4cd0-4fba-ac18-3c0d7474a45f/scratch-2026-11-04-2c8855/LevelGuide';
const OUT = __dirname;

// ---- tiny Lua tokenizer ----
function tokenize(src) {
  const toks = [];
  let i = 0, line = 1;
  while (i < src.length) {
    const c = src[i];
    if (c === '\n') { line++; i++; continue; }
    if (/\s/.test(c)) { i++; continue; }
    if (c === '-' && src[i + 1] === '-') { // comment
      if (src.startsWith('--[[', i)) { const e = src.indexOf(']]', i); i = e < 0 ? src.length : e + 2; continue; }
      while (i < src.length && src[i] !== '\n') i++; continue;
    }
    if (c === '"' || c === "'") {
      let j = i + 1, s = '';
      while (j < src.length && src[j] !== c) {
        if (src[j] === '\\') { const n = src[j + 1]; s += n === 'n' ? '\n' : n === 't' ? '\t' : n; j += 2; }
        else s += src[j++];
      }
      toks.push({ t: 'str', v: s, line }); i = j + 1; continue;
    }
    if (/[0-9]/.test(c) || (c === '.' && /[0-9]/.test(src[i + 1]))) {
      let j = i; while (j < src.length && /[0-9.eE]/.test(src[j])) j++;
      toks.push({ t: 'num', v: parseFloat(src.slice(i, j)), line }); i = j; continue;
    }
    if (/[A-Za-z_]/.test(c)) {
      let j = i; while (j < src.length && /[A-Za-z0-9_]/.test(src[j])) j++;
      toks.push({ t: 'id', v: src.slice(i, j), line }); i = j; continue;
    }
    toks.push({ t: 'p', v: c, line }); i++;
  }
  return toks;
}

// parse a Lua expression limited to tables/literals/identifiers/calls
function Parser(toks) {
  let p = 0;
  const peek = () => toks[p], next = () => toks[p++];
  function expect(v) { const t = next(); if (!t || t.v !== v) throw new Error(`expected ${v} got ${t && t.v} line ${t && t.line}`); }
  function value() {
    const t = peek();
    if (t.t === 'str') { next(); return t.v; }
    if (t.t === 'num') { next(); return t.v; }
    if (t.t === 'id') {
      next();
      if (t.v === 'true') return true; if (t.v === 'false') return false; if (t.v === 'nil') return null;
      if (peek() && peek().v === '(') { // call
        next(); const args = [];
        while (peek().v !== ')') { args.push(value()); if (peek().v === ',') next(); }
        next();
        return { __call: t.v, args, line: t.line };
      }
      return { __id: t.v };
    }
    if (t.v === '{') return table();
    if (t.v === '-') { next(); return -value(); }
    throw new Error(`unexpected ${t.v} line ${t.line}`);
  }
  function table() {
    const start = next(); // {
    const obj = {}; const arr = []; let hasKeys = false;
    while (peek().v !== '}') {
      const t = peek();
      if (t.v === '[') { next(); const k = value(); expect(']'); expect('='); obj[k] = value(); hasKeys = true; }
      else if (t.t === 'id' && toks[p + 1] && toks[p + 1].v === '=') { next(); next(); obj[t.v] = value(); hasKeys = true; }
      else arr.push(value());
      if (peek().v === ',' || peek().v === ';') next();
    }
    next();
    if (hasKeys) { if (arr.length) obj.__arr = arr; obj.__line = start.line; return obj; }
    return arr;
  }
  return { value, pos: () => p, seek: (n) => { p = n; }, peek, next };
}

// ---- Routes ----
function parseRoutes() {
  const src = fs.readFileSync(path.join(WS, 'Routes.lua'), 'utf8');
  const toks = tokenize(src);
  const P = Parser(toks);
  const routes = {}; let plan = null, chains = null;
  for (let i = 0; i < toks.length; i++) {
    if (toks[i].v === 'local' && toks[i + 1].t === 'id' && toks[i + 2].v === '=' && toks[i + 3].v === '{') {
      P.seek(i + 3); const v = P.value(); const name = toks[i + 1].v;
      if (name === 'PLAN') plan = v; else routes[name] = v;
      i = P.pos() - 1;
    }
    if (toks[i].v === 'LevelGuideRoutes' && toks[i + 1].v === '=') { P.seek(i + 2); const v = P.value(); chains = v.chains; i = P.pos() - 1; }
  }
  const CALL = { A: 'accept', D: 'do', T: 'turnin', G: 'go' };
  for (const [name, r] of Object.entries(routes)) {
    r.var = name;
    r.steps = r.steps.map((c, idx) => {
      const a = c.args;
      const norm = (part) => (typeof part === 'number' ? part : null);
      let s;
      if (c.__call === 'G') s = { t: 'go', text: a[0], x: a[1], y: a[2], lvl: a[3], note: a[4] };
      else if (c.__call === 'D') s = { t: 'do', q: a[0], note: a[1], x: a[2], y: a[3], lvl: a[4], part: norm(a[5]), rawPart: a[5] };
      else s = { t: CALL[c.__call], q: a[0], npc: a[1], x: a[2], y: a[3], lvl: a[4], part: norm(a[5]), rawPart: a[5] };
      s.line = c.line; s.index = idx + 1; s.nargs = a.length;
      return s;
    });
  }
  for (const k of Object.keys(chains)) { if (k.startsWith('__')) { delete chains[k]; continue; } chains[k] = chains[k].map((x) => x.__id); }
  return { routes, plan, chains };
}

// ---- QuestIDs / Prereqs: parse each `return {` table after `parts[#parts + 1] = (function()` ----
function parseParts(file) {
  const src = fs.readFileSync(path.join(WS, file), 'utf8');
  const toks = tokenize(src);
  const P = Parser(toks);
  const parts = [];
  for (let i = 0; i < toks.length; i++) {
    if (toks[i].v === 'return' && toks[i + 1].v === '{') {
      P.seek(i + 1); const v = P.value(); parts.push({ table: v, line: toks[i].line }); i = P.pos() - 1;
    }
  }
  return parts;
}

const routes = parseRoutes();
const qparts = parseParts('QuestIDs.lua');
const pparts = parseParts('Prereqs.lua');

// merge QuestIDs like the addon does (later parts override)
const MISMATCHED = {};
const ids = {}, renamed = {}, idSources = {};
const dupTitles = [];
qparts.forEach((p, pi) => {
  const t = p.table; const src = t.ids || t;
  for (const [title, list] of Object.entries(src)) {
    if (title.startsWith('__')) continue;
    if (Array.isArray(list) && !MISMATCHED[title]) {
      if (ids[title]) dupTitles.push({ title, prev: ids[title], prevPart: idSources[title], now: list, part: pi });
      ids[title] = list; idSources[title] = pi;
    }
  }
  for (const [f, to] of Object.entries(t.renamed || {})) if (!f.startsWith('__')) renamed[f] = to;
});
const prereqs = {}; const prereqDup = [];
pparts.forEach((p, pi) => {
  for (const [title, need] of Object.entries(p.table)) {
    if (title.startsWith('__')) continue;
    if (typeof need === 'object' && need) { if (prereqs[title]) prereqDup.push({ title, prev: prereqs[title], now: need, part: pi }); prereqs[title] = need; }
  }
});

fs.writeFileSync(path.join(OUT, 'data.json'), JSON.stringify({ ...routes, ids, renamed, idDup: dupTitles, prereqs, prereqDup, qparts: qparts.length, pparts: pparts.length }, null, 1));
console.log('routes', Object.keys(routes.routes).length, 'steps', Object.values(routes.routes).reduce((a, r) => a + r.steps.length, 0));
console.log('ids', Object.keys(ids).length, 'renamed', Object.keys(renamed).length, 'prereqs', Object.keys(prereqs).length, 'qparts', qparts.length, 'pparts', pparts.length);
console.log('id dup titles across parts:', dupTitles.length, 'prereq dups:', prereqDup.length);
