const fs = require('fs');
const path = require('path');
const D = JSON.parse(fs.readFileSync(path.join(__dirname, 'data.json'), 'utf8'));
const { routes, plan, chains, ids, renamed, prereqs } = D;
const out = [];
const log = (...a) => out.push(a.join(' '));
const P = (s) => s.part || 1;
const npcKey = (n) => { if (!n) return null; const m = n.match(/^\s*([^,(]*?)\s*[,(]/); return m ? m[1] : n.trim(); };
const real = (t) => renamed[t] || t;
const idsFor = (t) => ids[t] || ids[real(t)];

const order = Object.values(routes).sort((a, b) => a.steps[0].line - b.steps[0].line);

// ---------- 1. structural ----------
log('# STRUCTURAL');
const acceptsByQ = {}; // title -> [{zone, npc, part, line}]
const turninNoAccept = [];
for (const r of order) {
  const z = r.zone;
  const seenAccept = {}, seenDo = {}, seenTurn = {};
  const keyOf = (s) => s.q + '#' + P(s);
  let minL = 99, maxL = 0;
  r.steps.forEach((s, i) => {
    if (s.x == null || s.y == null || typeof s.x !== 'number' || typeof s.y !== 'number' || s.x < 0 || s.x > 100 || s.y < 0 || s.y > 100) log(`BAD COORD ${z} L${s.line}: ${JSON.stringify([s.x, s.y])} ${s.q || s.text}`);
    if (typeof s.lvl !== 'number') log(`NO LVL ${z} L${s.line}: ${s.q || s.text} lvl=${JSON.stringify(s.lvl)}`);
    else { minL = Math.min(minL, s.lvl); maxL = Math.max(maxL, s.lvl); }
    if (s.rawPart != null && typeof s.rawPart !== 'number') log(`NOTE-IN-PART ${z} L${s.line}: ${s.q} part=${JSON.stringify(s.rawPart)}`);
    if (s.t !== 'go' && s.nargs < 5) log(`FEW ARGS ${z} L${s.line}: ${s.q} nargs=${s.nargs}`);
    if (s.t === 'go' && s.nargs < 4) log(`FEW ARGS(go) ${z} L${s.line}: ${s.text}`);
    if (s.t === 'accept') {
      const k = keyOf(s);
      if (seenAccept[k]) log(`DUP ACCEPT ${z} L${s.line}: ${k} (first L${seenAccept[k].line})`);
      seenAccept[k] = s;
      (acceptsByQ[s.q] = acceptsByQ[s.q] || []).push({ zone: z, npc: s.npc, part: P(s), line: s.line, lvl: s.lvl });
    } else if (s.t === 'do') {
      const k = keyOf(s);
      if (!seenAccept[k]) log(`DO WITHOUT ACCEPT ${z} L${s.line}: ${k} :: ${s.note}`);
      seenDo[k] = (seenDo[k] || 0) + 1;
    } else if (s.t === 'turnin') {
      const k = keyOf(s);
      if (seenTurn[k]) log(`DUP TURNIN ${z} L${s.line}: ${k}`);
      seenTurn[k] = s;
      if (!seenAccept[k]) turninNoAccept.push({ zone: z, line: s.line, k, npc: s.npc });
    }
  });
  for (const [k, s] of Object.entries(seenAccept)) {
    if (!seenTurn[k]) log(`ACCEPT WITHOUT TURNIN ${z} L${s.line}: ${k} (npc ${s.npc}) do-steps=${seenDo[k] || 0}`);
  }
  for (const [k, s] of Object.entries(seenTurn)) {
    const a = seenAccept[k];
    if (a && s.line < a.line) log(`TURNIN BEFORE ACCEPT ${z} L${s.line}: ${k}`);
  }
  // consecutive parts per quest, and accept part N after turnin part N-1
  const byQ = {};
  r.steps.forEach((s) => { if (s.q) (byQ[s.q] = byQ[s.q] || []).push(s); });
  for (const [q, list] of Object.entries(byQ)) {
    const parts = [...new Set(list.map(P))].sort((a, b) => a - b);
    const explicit = list.some((s) => s.part != null);
    if (parts[0] !== 1 || parts.some((p, i) => p !== i + 1)) log(`PARTS NOT CONSECUTIVE ${z}: ${q} parts=${parts.join(',')} L${list[0].line}`);
    if (explicit && list.some((s) => s.part == null)) log(`MIXED PART/NO-PART ${z}: ${q} L${list.filter((s) => s.part == null).map((s) => s.line).join(',')}`);
    for (let p = 2; p <= parts.length; p++) {
      const acc = list.find((s) => s.t === 'accept' && P(s) === p);
      const prevT = list.find((s) => s.t === 'turnin' && P(s) === p - 1);
      if (acc && prevT && acc.line < prevT.line) log(`PART ${p} ACCEPTED BEFORE PART ${p - 1} TURNIN ${z}: ${q} L${acc.line}`);
    }
    // do after turnin
    for (const p of parts) {
      const t = list.find((s) => s.t === 'turnin' && P(s) === p);
      const dos = list.filter((s) => s.t === 'do' && P(s) === p);
      if (t && dos.some((d) => d.line > t.line)) log(`DO AFTER TURNIN ${z}: ${q}#${p} L${dos.filter((d) => d.line > t.line).map((d) => d.line)}`);
    }
  }
  // lvl monotonic-ish
  let prev = 0;
  r.steps.forEach((s) => { if (typeof s.lvl === 'number') { if (s.lvl < prev - 1) log(`LVL DROPS ${z} L${s.line}: ${s.lvl} after ${prev} (${s.q || s.text})`); prev = Math.max(prev, s.lvl); } });
  log(`ROUTE ${z} (${r.var}) min=${r.min} max=${r.max} steps=${r.steps.length} lvl range ${minL}-${maxL}` + (minL < r.min || maxL > r.max ? '  <-- OUT OF RANGE' : ''));
}
log('\n## turn-ins without an accept in the same route');
for (const t of turninNoAccept) {
  const acc = acceptsByQ[t.k.split('#')[0]];
  log(`${t.zone} L${t.line}: ${t.k} -> ${t.npc}` + (acc ? ` [accepted in ${acc.map((a) => a.zone + '#' + a.part).join(', ')}]` : ' [no accept anywhere]'));
}

// plan zones
log('\n## plan zones vs routes');
const zoneSet = new Set(order.map((r) => r.zone));
for (const p of plan) for (const z of p.zones) if (!zoneSet.has(z)) log(`PLAN ${p.min}-${p.max}: "${z}" has no route`);
// plan coverage gaps/overlaps
for (let i = 1; i < plan.length; i++) if (plan[i].min !== plan[i - 1].max) log(`PLAN gap/overlap between ${plan[i - 1].max} and ${plan[i].min}`);
// chains: every route in some chain; route level overlap order
const used = new Set(Object.values(chains).flat());
for (const r of order) if (!used.has(r.var)) log(`ROUTE ${r.var} not in any chain`);
for (const [race, list] of Object.entries(chains)) {
  for (let i = 1; i < list.length; i++) { const a = routes[list[i - 1]], b = routes[list[i]]; if (b.min < a.min) log(`CHAIN ${race}: ${b.zone}(min ${b.min}) after ${a.zone}(min ${a.min})`); }
}

// ---------- 2. cross-file ----------
log('\n# CROSS-FILE');
const routeTitles = {}; // title -> {zones:Set, maxPart}
for (const r of order) for (const s of r.steps) if (s.q) { const e = (routeTitles[s.q] = routeTitles[s.q] || { zones: new Set(), maxPart: 0, accepted: false }); e.zones.add(r.zone); e.maxPart = Math.max(e.maxPart, P(s)); if (s.t === 'accept') e.accepted = true; }
log('## route titles with no QuestIDs entry, by zone');
const missingByZone = {};
for (const [t, e] of Object.entries(routeTitles)) if (!idsFor(t)) for (const z of e.zones) (missingByZone[z] = missingByZone[z] || []).push(t);
for (const r of order) if (missingByZone[r.zone]) log(`${r.zone} (${missingByZone[r.zone].length}): ${missingByZone[r.zone].join(' | ')}`);
log('## QuestIDs part count != route parts');
for (const [t, e] of Object.entries(routeTitles)) { const l = idsFor(t); if (l && l.length !== e.maxPart) log(`${t}: ids=${l.length} [${l.join(',')}] route parts=${e.maxPart} (${[...e.zones].join(',')})`); }
log('## QuestIDs titles not used by any route');
const unused = Object.keys(ids).filter((t) => !routeTitles[t] && !Object.entries(renamed).some(([f, to]) => to === t && routeTitles[f]));
log(unused.length + ': ' + unused.join(' | '));
log('## QuestIDs: same title defined in several parts with different lists (later wins)');
for (const d of D.idDup) if (JSON.stringify(d.prev) !== JSON.stringify(d.now)) log(`${d.title}: part${d.prevPart} [${d.prev}] -> part${d.part} [${d.now}]`);
log('## QuestIDs: same ID under several titles');
const titleOfId = {};
for (const [t, l] of Object.entries(ids)) for (const id of l) { if (titleOfId[id] && titleOfId[id] !== t) log(`${id}: "${titleOfId[id]}" and "${t}"`); titleOfId[id] = t; }
log('## Prereqs IDs not in QuestIDs');
for (const [t, n] of Object.entries(prereqs)) for (const k of ['all', 'any']) for (const id of n[k] || []) if (!titleOfId[id]) log(`${t}.${k} -> ${id} unknown`);
log('## Prereqs titles not in any route');
log(Object.keys(prereqs).filter((t) => !routeTitles[t] && !routeTitles[Object.keys(renamed).find((f) => renamed[f] === t)]).join(' | '));
log('## Prereqs duplicates across parts');
for (const d of D.prereqDup) log(`${d.title}: ${JSON.stringify(d.prev)} -> ${JSON.stringify(d.now)}`);
log('## renamed');
for (const [f, to] of Object.entries(renamed)) log(`${f} -> ${to}: route uses from=${!!routeTitles[f]} to=${!!routeTitles[to]}; ids has from=${!!ids[f]} to=${!!ids[to]}; prereqs has from=${!!prereqs[f]} to=${!!prereqs[to]}`);
log('## Prereqs.level above the accept step lvl (pick-up hidden as "done" until that level)');
for (const r of order) for (const s of r.steps) if (s.t === 'accept') { const n = prereqs[s.q] || prereqs[real(s.q)]; if (n && n.level && typeof s.lvl === 'number' && n.level > s.lvl) log(`${r.zone} L${s.line}: ${s.q}#${P(s)} step lvl ${s.lvl} < prereq level ${n.level} (route min ${r.min})`); }

// ---------- 4. chain hazards ----------
log('\n# CHAIN HAZARDS');
log('## same title given by different NPCs');
for (const [q, list] of Object.entries(acceptsByQ)) {
  const npcs = [...new Set(list.map((a) => npcKey(a.npc)))];
  if (npcs.length > 1) log(`${q}: ${list.map((a) => `${a.zone}#${a.part} ${npcKey(a.npc)} (L${a.line})`).join(' ; ')}`);
}
log('## NpcKey collisions: same key spelled with different full text (info)');
log('## accept whose prerequisite quest is turned in later in the same route or not in this route');
for (const r of order) {
  const turninLine = {}; // title#part -> line (turnin)
  r.steps.forEach((s) => { if (s.t === 'turnin') turninLine[s.q + '#' + P(s)] = s.line; });
  const idLine = (id) => { const t = titleOfId[id]; if (!t) return { t: null }; const l = ids[t]; const part = l.indexOf(id) + 1; const rt = Object.keys(renamed).find((f) => renamed[f] === t) || t; return { t: rt, part, line: turninLine[rt + '#' + part] }; };
  for (const s of r.steps) {
    if (s.t !== 'accept') continue;
    const n = prereqs[s.q] || prereqs[real(s.q)];
    if (!n) continue;
    if (P(s) > 1) continue; // prereq entry describes first part
    for (const id of n.all || []) {
      const w = idLine(id);
      if (!w.t) continue;
      const whereElse = order.filter((o) => o !== r && o.steps.some((x) => x.t === 'turnin' && x.q === w.t && P(x) === w.part)).map((o) => o.zone);
      if (w.line == null) log(`${r.zone} L${s.line}: ${s.q} needs ${id} "${w.t}#${w.part}" which this route never turns in` + (whereElse.length ? ` (turned in in ${whereElse})` : ' (not in any route)'));
      else if (w.line > s.line) log(`${r.zone} L${s.line}: ${s.q} needs ${id} "${w.t}#${w.part}" turned in LATER at L${w.line}`);
    }
    if (n.any && n.any.length) {
      const ws = n.any.map(idLine);
      if (!ws.some((w) => w.t && w.line != null && w.line < s.line)) log(`${r.zone} L${s.line}: ${s.q} needs any of [${n.any}] -> ${ws.map((w) => (w.t ? `${w.t}#${w.part}@${w.line}` : '?')).join(',')} none turned in earlier here`);
    }
  }
}
log('## same NPC: later route pick-up required by an earlier one (order conflict)');
for (const r of order) {
  const byNpc = {};
  r.steps.forEach((s) => { if (s.t === 'accept') (byNpc[npcKey(s.npc)] = byNpc[npcKey(s.npc)] || []).push(s); });
  for (const [npc, list] of Object.entries(byNpc)) {
    for (let i = 0; i < list.length; i++) for (let j = i + 1; j < list.length; j++) {
      const a = list[i], b = list[j];
      const n = prereqs[a.q] || prereqs[real(a.q)];
      const bIds = idsFor(b.q) || [];
      if (n && (n.all || []).concat(n.any || []).some((id) => bIds.includes(id))) log(`${r.zone}: ${npc} gives "${a.q}" (L${a.line}) which needs "${b.q}" picked up later (L${b.line})`);
    }
  }
}
fs.writeFileSync(path.join(__dirname, 'check.txt'), out.join('\n'));
console.log(out.join('\n'));
