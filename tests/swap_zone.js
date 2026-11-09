// Replaces one zone table in Routes.lua (local NAME = { ... } }) with a worker's rebuilt route file.
const fs = require('fs');
const [, , routesFile, name, workerFile] = process.argv;
let routes = fs.readFileSync(routesFile, 'utf8').replace(/\r\n/g, '\n');
const start = routes.indexOf(`local ${name} = {`);
if (start < 0) throw new Error('no table ' + name);
const end = routes.indexOf('\n} }', start);
if (end < 0) throw new Error('no end for ' + name);
let text = fs.readFileSync(workerFile, 'utf8').replace(/\r\n/g, '\n').trim();
const at = text.search(/^return\s*\{/m);
if (at < 0) throw new Error('no return table');
// Keep the worker's header comments (sources) above the table.
text = text.slice(0, at) + `local ${name} = ` + text.slice(at).replace(/^return\s*/, '');
routes = routes.slice(0, start) + text + routes.slice(end + '\n} }'.length);
fs.writeFileSync(routesFile, routes.replace(/\n/g, '\r\n'));
console.log('swapped ' + name);
