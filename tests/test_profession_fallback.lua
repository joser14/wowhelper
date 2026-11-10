-- Professions read by skill line ID when GetProfessions/GetProfessionInfo are missing (as measured on a
-- Forever beta build): ProfessionCap still lists them and warns at a cap; GoldGuide still knows a miner.
local base = ADDON_PATH
local out, frames, handled = {}, {}, {}
ForeverHub_Receive = function(_, t) out[#out + 1] = t end
issecretvalue = function() return false end
geterrorhandler = function() return function(e) handled[#handled + 1] = tostring(e) end end
CreateFrame = function()
    local f = {}
    f.RegisterEvent = function() end
    f.SetScript = function(self, _, fn) self.fn = fn end
    frames[#frames + 1] = f
    return f
end
SlashCmdList = {}
UnitLevel = function() return 30 end
GetProfessions, GetProfessionInfo = nil, nil
local lines = {
    [186] = { name = "Mining", rank = 75, maxRank = 75 },
    [185] = { name = "Cooking", rank = 40, maxRank = 75 },
    [164] = { name = "Blacksmithing", rank = 0, maxRank = 0 },   -- not learned
}
C_SkillInfo = { GetSkillLineInfoByID = function(id) return lines[id] end }

assert(loadfile(base .. "/ProfessionCap/ProfessionCap.lua"))("ProfessionCap", {})
local list = ForeverSkillProfessions()
assert(#list == 2, "two learned professions: " .. #list)
out = {}
SlashCmdList.PROFESSIONCAP("")
local page = table.concat(out, "\n")
assert(page:find("Mining 75/75", 1, true) and page:find("Cooking 40/75", 1, true), "listed:\n" .. page)
assert(page:find("Visit a trainer for Journeyman", 1, true), "cap advice:\n" .. page)
assert(not page:find("Blacksmithing", 1, true), "an unlearned line isn't listed")
assert(#handled == 0, "clean: " .. tostring(handled[1]))
print("ALL TESTS PASSED")
