-- Round 3 #1: ZoneLevels falls back to its own zone table when C_Map.GetMapLevels has nothing (Forever),
-- including Forever-only zones, and never writes into UIErrorsFrame (its own small frame instead).
local base = ADDON_PATH
local out, frames, timers = {}, {}, {}
local SECRET = {}
issecretvalue = function(v) return v == SECRET end

-- Permissive frame mock: any method is a no-op, text/visibility recorded.
local function MockFrame()
    local f = { registered = {}, shown = true, fontStrings = {} }
    f.RegisterEvent = function(self, e) self.registered[e] = true end
    f.SetScript = function(self, what, fn) self[what] = fn end
    f.Show = function(self) self.shown = true end
    f.Hide = function(self) self.shown = false end
    f.IsShown = function(self) return self.shown end
    f.SetText = function(self, t) self.text = t end
    f.CreateFontString = function(self)
        local fs = MockFrame()
        self.fontStrings[#self.fontStrings + 1] = fs
        return fs
    end
    f.CreateTexture = f.CreateFontString
    return setmetatable(f, { __index = function() return function() end end })
end
CreateFrame = function(_, name)
    local f = MockFrame()
    f.name = name
    frames[#frames + 1] = f
    return f
end
UIParent = MockFrame()
C_Timer = { After = function(s, fn) timers[#timers + 1] = fn end }
UIErrorsFrame = setmetatable({}, { __index = function() error("UIErrorsFrame must not be touched") end,
    __newindex = function() error("UIErrorsFrame must not be written") end })
SlashCmdList = {}
local level = 10
UnitLevel = function() return level end
Enum = { UIMapType = { Zone = 3 } }

local maps = {
    [1431] = { name = "Duskwood", mapType = 3, parentMapID = 1415 },
    [1415] = { name = "Eastern Kingdoms", mapType = 2, parentMapID = 947 },
    [2521] = { name = "Zephras Isle", mapType = 3, parentMapID = 2991 },
    [2548] = { name = "Riverglades", mapType = 3, parentMapID = 1415 },
    [2482] = { name = "Mount Hyjal", mapType = 3, parentMapID = 1414 },
    [9001] = { name = "Riverglades", mapType = 3, parentMapID = 1415 },     -- another number, same name
    [9002] = { name = "Some Cave", mapType = 5, parentMapID = 1431 },        -- cave inside Duskwood
    [1453] = { name = "Stormwind City", mapType = 3, parentMapID = 1415 },
}
local apiLevels = {}
local here = 1431
C_Map = {
    GetBestMapForUnit = function() return here end,
    GetMapInfo = function(id) return maps[id] end,
    GetMapLevels = function(id) local l = apiLevels[id] if l then return l[1], l[2] end return 0, 0 end,
}

local function reset() out = {} end
local function has(text) for _, t in ipairs(out) do if t:find(text, 1, true) then return true end end return false end
local function need(text, why) assert(has(text), why .. ": wanted '" .. text .. "' in:\n" .. table.concat(out, "\n")) end

ForeverHub_Receive = function(_, t) out[#out + 1] = t end
assert(loadfile(base .. "/ZoneLevels/ZoneLevels.lua"))("ZoneLevels", {})
local events = frames[1]
local function fire(ev) events.OnEvent(events, ev) end

-- 1. Classic zone with an empty API: our table.
reset(); fire("ZONE_CHANGED_NEW_AREA")
need("Duskwood is level 18-30 and you're level 10. Careful!", "fallback table for Duskwood")

-- 2. Public lookup for other helpers.
assert(type(ForeverZoneLevels) == "function", "public lookup ForeverZoneLevels(mapID)")
local lo, hi, name = ForeverZoneLevels(2521)
assert(lo == 3 and hi == 12 and name == "Zephras Isle", "Zephras Isle 3-12: " .. tostring(lo) .. "-" .. tostring(hi))
lo, hi = ForeverZoneLevels(2548)
assert(lo == 36 and hi == 44, "Riverglades 36-44")
lo, hi = ForeverZoneLevels(2482)
assert(lo and hi == 60, "Mount Hyjal tops out at 60")
assert(ForeverZoneLevels(1453) == nil, "cities have no range")
lo, hi = ForeverZoneLevels(9001)
assert(lo == 36 and hi == 44, "unknown number, known name")
lo, hi, name = ForeverZoneLevels(9002)
assert(lo == 18 and name == "Duskwood", "cave climbs to its zone")

-- 3. The game's own answer wins.
apiLevels[1431] = { 20, 31 }
lo, hi = ForeverZoneLevels(1431)
assert(lo == 20 and hi == 31, "API first")
apiLevels[1431] = { SECRET, SECRET }
lo = ForeverZoneLevels(1431)
assert(lo == 18, "a secret API answer falls back to the table")
apiLevels[1431] = nil

-- 4. Forever zones by slash/page.
here = 2521
reset(); SlashCmdList.ZONELEVELS("")
need("Zephras Isle: level 3-12", "page for Zephras Isle")
level = 30; here = 2548
reset(); fire("ZONE_CHANGED_NEW_AREA")
need("Riverglades is level 36-44 and you're level 30. Careful!", "Riverglades warning")

-- 5. No hub: our own frame, never UIErrorsFrame.
ForeverHub_Receive = nil
level = 5; here = 1431
local before = #frames
fire("ZONE_CHANGED_NEW_AREA")
local shown
for i = before + 1, #frames do
    local f = frames[i]
    for _, fs in ipairs(f.fontStrings) do
        if fs.text and fs.text:find("Duskwood", 1, true) then shown = f end
    end
end
assert(shown and shown.shown, "warning shown in our own frame without the hub")
for _, fn in ipairs(timers) do fn() end
assert(not shown.shown, "our frame hides itself after a while")

-- 6. Source has no UIErrorsFrame reference at all.
-- (UIErrorsFrame above is a trap that errors on any read or write; fengari has no io.open for a source scan.)
if io and io.open then
    local src = assert(io.open(base .. "/ZoneLevels/ZoneLevels.lua", "r")):read("*a")
    assert(not src:find("UIErrorsFrame", 1, true), "no UIErrorsFrame in ZoneLevels.lua")
end
print("test_r3_zonelevels: ok")
