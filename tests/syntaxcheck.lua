-- Compiles one Lua file without running it. ADDON_PATH is the file.
local chunk, err = loadfile(ADDON_PATH)
if not chunk then
    error("syntax: " .. tostring(err), 0)
end
print("ok " .. ADDON_PATH)
