// Merges the workers' route files into LevelGuide/Routes.lua as local tables, then sets the chains.
const fs = require('fs');
const [, , routesFile, routesDir] = process.argv;
const zones = [
    ['ASHENVALE', 'ashenvale'], ['WETLANDS', 'wetlands'], ['DUSKWOOD', 'duskwood'], ['HILLSBRAD', 'hillsbrad'],
    ['ARATHI', 'arathi'], ['DESOLACE', 'desolace'], ['STRANGLETHORN', 'stranglethorn'], ['TANARIS', 'tanaris'],
    ['FERALAS', 'feralas'], ['HINTERLANDS', 'hinterlands'], ['UNGORO', 'ungoro'], ['FELWOOD', 'felwood'],
    ['BURNING_STEPPES', 'burningsteppes'], ['WESTERN_PLAGUELANDS', 'westernplaguelands'],
    ['EASTERN_PLAGUELANDS', 'easternplaguelands'], ['WINTERSPRING', 'winterspring'], ['SILITHUS', 'silithus'],
];
let routes = fs.readFileSync(routesFile, 'utf8').replace(/\r\n/g, '\n');
const marker = '-- Where to level at every stage';
const start = routes.indexOf('-- Zones researched by worker sessions');
if (start >= 0) routes = routes.slice(0, start) + routes.slice(routes.indexOf(marker));
let block = '-- Zones researched by worker sessions from Forever guide sites; each keeps its own source list.\n\n';
for (const [name, file] of zones) {
    let text = fs.readFileSync(`${routesDir}/${file}.lua`, 'utf8').replace(/\r\n/g, '\n').trim();
    const at = text.search(/^return\s*\{/m);
    if (at < 0) throw new Error(file + ': no return table');
    text = text.slice(0, at) + `local ${name} = ` + text.slice(at).replace(/^return\s*/, '');
    if (name === 'HILLSBRAD') text = text.replace(/min\s*=\s*22/, 'min = 28');
    block += text + '\n\n';
}
routes = routes.replace(marker, block + marker);
const later = 'ASHENVALE, WETLANDS, DUSKWOOD, HILLSBRAD, ARATHI, DESOLACE, STRANGLETHORN, TANARIS, FERALAS, HINTERLANDS, UNGORO, FELWOOD, BURNING_STEPPES, WESTERN_PLAGUELANDS, EASTERN_PLAGUELANDS, WINTERSPRING, SILITHUS';
const easternLater = 'WETLANDS, DUSKWOOD, ASHENVALE, HILLSBRAD, ARATHI, DESOLACE, STRANGLETHORN, HINTERLANDS, TANARIS, FERALAS, BURNING_STEPPES, UNGORO, FELWOOD, WESTERN_PLAGUELANDS, EASTERN_PLAGUELANDS, WINTERSPRING, SILITHUS';
routes = routes.replace(/    chains = \{[\s\S]*?\n    \},\n/, `    chains = {
        NightElf = { TELDRASSIL, DARKSHORE, ${later} },
        Gnome = { DUN_MOROGH, LOCH_MODAN, ${easternLater} },
        Dwarf = { DUN_MOROGH, LOCH_MODAN, ${easternLater} },
        Human = { ${easternLater} },
    },
`);
fs.writeFileSync(routesFile, routes.replace(/\n/g, '\r\n'));
console.log('merged ' + zones.length + ' zones');
