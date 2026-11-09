-- Runs harness validate.lua on every route in Routes.lua. ADDON_PATH = LevelGuide folder.
local base = ADDON_PATH
assert(loadfile(base .. "/Routes.lua"))("LevelGuide", {})
local realLoad = loadfile
local seen = {}
for _, chain in pairs(LevelGuideRoutes.chains) do
  for _, route in ipairs(chain) do
    if not seen[route] then
      seen[route] = true
      loadfile = function(p) if p == "ROUTE" then return function() return route end end return realLoad(p) end
      ADDON_PATH = "ROUTE"
      local v = assert(realLoad([[C:\Users\you\AppData\Local\Temp\claude\cb2f3a55e03b1ab7\c31d37c7-e117-4d9f-bde3-ec6d36fbc336\scratchpad\harness\validate.lua]]))
      v()
    end
  end
end
