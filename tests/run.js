const { lua, lauxlib, lualib, to_luastring } = require('fengari');
const L = lauxlib.luaL_newstate();
lualib.luaL_openlibs(L);
lua.lua_pushstring(L, to_luastring(process.argv[2]));
lua.lua_setglobal(L, to_luastring('ADDON_PATH'));
let s = lauxlib.luaL_loadfile(L, to_luastring(process.argv[3]));
if (s === lua.LUA_OK) s = lua.lua_pcall(L, 0, 0, 0);
if (s !== lua.LUA_OK) { console.error(lua.lua_tojsstring(L, -1)); process.exit(1); }
