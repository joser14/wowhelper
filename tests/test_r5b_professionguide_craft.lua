-- Round 5 #17: ProfessionGuide's "craft" page lists what your bags can make now (from recipes read when you open
-- a profession window, else from the guide's steps), marks crafts that would eat materials a guide step still
-- needs, lists materials to keep for later steps, and spare materials with their PriceMemory value. Never crafts.
-- Run from the harness folder:  node run.js "<workspace root>" test_r5b_professionguide_craft.lua
local base = ADDON_PATH .. "/ProfessionGuide/"
local out, failures, frames, forbidden = {}, {}, {}, {}
local realPrint = print
local SECRET = {}
local function check(cond, why) if not cond then failures[#failures + 1] = why end end
issecretvalue = function(v) return v == SECRET end
ForeverHub_Receive = function(_, t) out[#out + 1] = t end
for _, name in ipairs({ "hooksecurefunc", "print", "DoTradeSkill" }) do
    _G[name] = function() forbidden[#forbidden + 1] = name end
end
CreateFrame = function()
    local f = { registered = {} }
    f.RegisterEvent = function(self, e) self.registered[e] = true end
    f.SetScript = function(self, _, fn) self.fn = fn end
    frames[#frames + 1] = f
    return f
end
SlashCmdList = {}
local clock = 100
GetTime = function() return clock end

local files = { "Data_Alchemy.lua", "Data_Blacksmithing.lua", "Data_Enchanting.lua", "Data_Engineering.lua",
    "Data_Leatherworking.lua", "Data_Tailoring.lua", "Data_Mining.lua", "Data_Herbalism.lua", "Data_Skinning.lua",
    "Data_Cooking.lua", "Data_FirstAid.lua", "Data_Fishing.lua", "ProfessionGuide.lua" }
for _, name in ipairs(files) do
    assert(loadfile(base .. name))("ProfessionGuide", {})
end
local scanner = frames[#frames]
check(scanner and scanner.registered.TRADE_SKILL_SHOW and scanner.registered.TRADE_SKILL_LIST_UPDATE, "profession window events registered")
local function page(arg)
    out = {}
    local ok, err = pcall(SlashCmdList.PROFESSIONGUIDE, arg)
    check(ok, "page '" .. arg .. "' errored: " .. tostring(err))
    return table.concat(out, "\n")
end

local professions = { { name = "Tailoring", rank = 40, maxRank = 75, skillLine = 197 } }
GetProfessions = function() return professions[1] and 1, professions[2] and 2 end
GetProfessionInfo = function(index) local p = professions[index]; return p.name, 0, p.rank, p.maxRank, 0, 0, p.skillLine end
C_SkillInfo = { GetSkillLineInfoByID = function() return nil end }
local LINEN, BOLT, THREAD, WOOL = 2589, 2996, 2320, 2592
local bags, bank = { [BOLT] = 5, [THREAD] = 8, [WOOL] = 30, [LINEN] = 10 }, { [LINEN] = 4 }
C_Item = { GetItemCount = function(id, includeBank) return (bags[id] or 0) + (includeBank and (bank[id] or 0) or 0) end }
PriceMemory_Get = function(id) if id == LINEN then return { price = 10 } end end

----- No profession window read yet: the guide's own steps
local text = page("craft")
check(text:find("What you can craft now", 1, true), "page title:\n" .. text)
check(text:find("Linen Belt x5 |cff66dd66(current step)|r", 1, true), "current step craft from bags:\n" .. text)
check(text:find("Bolt of Woolen Cloth x10", 1, true) and text:find("its own step is 55-75", 1, true), "a later step's craft, marked:\n" .. text)
check(not text:find("Bolt of Linen Cloth x", 1, true), "steps already passed aren't listed")
check(text:find("Open a profession window once", 1, true), "says how to list every recipe")
check(text:find("Keep for later steps", 1, true) and text:find("30 Wool Cloth for Tailoring 55-75", 1, true), "wool kept for later:\n" .. text)
check(text:find("More than your guide steps need", 1, true) and text:find("14 Linen Cloth |cff999999(about 1s 40c at the auction house)|r", 1, true),
    "spare linen with its auction value:\n" .. text)
check(not text:find("Bolt of Linen Cloth for", 1, true), "current-step mats aren't 'for later'")
text = page("")
check(text:find("Or: craft", 1, true), "overview names the craft page")

----- The profession window opens: known recipes are read and remembered
local recipes = {
    [101] = { name = "Linen Belt", learned = true, mats = { { BOLT, 1 }, { THREAD, 1 } } },
    [102] = { name = "Bolt of Woolen Cloth", learned = true, mats = { { WOOL, 3 } } },
    [103] = { name = "Brown Linen Vest", learned = true, mats = { { BOLT, 1 }, { THREAD, 1 } } },
    [104] = { name = "Heavy Linen Gloves", learned = false, mats = { { BOLT, 2 } } },
    [105] = { name = "Optional Thing", learned = true, mats = { { LINEN, 1 } }, optional = { 9999, 1 } },
}
local api = {
    GetAllRecipeIDs = function() local ids = {}; for id in pairs(recipes) do ids[#ids + 1] = id end; table.sort(ids); return ids end,
    GetRecipeInfo = function(id) local r = recipes[id]; return r and { recipeID = id, name = r.name, learned = r.learned } end,
    GetRecipeSchematic = function(id)
        local r = recipes[id]
        local slots = {}
        for _, m in ipairs(r.mats) do slots[#slots + 1] = { reagents = { { itemID = m[1] } }, quantityRequired = m[2], required = true } end
        if r.optional then slots[#slots + 1] = { reagents = { { itemID = r.optional[1] } }, quantityRequired = r.optional[2], required = false } end
        return { recipeID = id, name = r.name, outputItemID = id * 10, reagentSlotSchematics = slots }
    end,
    GetBaseProfessionInfo = function() return { professionID = 197, professionName = "Tailoring" } end,
}
C_TradeSkillUI = setmetatable({}, { __index = function(_, k)
    if api[k] then return api[k] end
    failures[#failures + 1] = "C_TradeSkillUI." .. tostring(k) .. " touched (only reads are allowed)"
    return function() end
end })
scanner.fn(scanner, "TRADE_SKILL_SHOW")
local store = ProfessionGuideDB and ProfessionGuideDB.recipes or {}
local n = 0
for _ in pairs(store) do n = n + 1 end
check(n == 4, "learned recipes remembered (unlearned skipped), got " .. n)
check(store[101] and store[101].line == 197 and store[101].prof == "Tailoring" and #store[101].mats == 2, "recipe saved with its mats")
check(store[105] and #store[105].mats == 1, "optional slots don't count as needed")

text = page("craft")
check(text:find("Linen Belt x5 |cff66dd66(current step)|r", 1, true), "current step first:\n" .. text)
check(text:find("Brown Linen Vest x5 |cffff9933keep: uses Bolt of Linen Cloth that Tailoring 35-55 needs|r", 1, true),
    "a craft eating the current step's mats is marked:\n" .. text)
check(text:find("Bolt of Woolen Cloth x10 |cffff9933keep: uses Wool Cloth that Tailoring 55-75 needs|r", 1, true),
    "a craft eating a later step's mats is marked:\n" .. text)
check(text:find("Optional Thing x10", 1, true) and not text:find("Optional Thing x10 |cffff9933", 1, true), "a free craft isn't marked:\n" .. text)
check(not text:find("Heavy Linen Gloves", 1, true), "unlearned recipe not listed")
check(not text:find("Open a profession window once", 1, true), "no hint once recipes are known")

----- Throttle: the list update storm is read at most every 2 s
recipes[106] = { name = "New One", learned = true, mats = { { LINEN, 1 } } }
scanner.fn(scanner, "TRADE_SKILL_LIST_UPDATE")
check(store[106] == nil, "read again too soon: skipped")
clock = clock + 3
scanner.fn(scanner, "TRADE_SKILL_LIST_UPDATE")
check(ProfessionGuideDB.recipes[106] ~= nil, "read after 2 s")

----- A profession you dropped: its recipes aren't offered
professions[1] = { name = "Alchemy", rank = 1, maxRank = 75, skillLine = 171 }
text = page("craft")
check(not text:find("Linen Belt", 1, true), "dropped profession's recipes not listed:\n" .. text)

----- Secret and odd values from the window are skipped quietly
professions[1] = { name = "Tailoring", rank = 40, maxRank = 75, skillLine = 197 }
api.GetAllRecipeIDs = function() return { 101, SECRET, 102 } end
api.GetRecipeInfo = function(id) if id == 102 then return SECRET end; local r = recipes[id]; return r and { name = r.name, learned = true } end
clock = clock + 3
scanner.fn(scanner, "TRADE_SKILL_SHOW")
check(ProfessionGuideDB.recipes[101] and ProfessionGuideDB.recipes[102] == nil, "secret recipe skipped")
api.GetAllRecipeIDs = function() error("boom") end
clock = clock + 3
scanner.fn(scanner, "TRADE_SKILL_SHOW")
check(ProfessionGuideDB.recipes[101], "a failing read keeps what was saved")

----- Bound on remembered recipes
api.GetAllRecipeIDs = function() local ids = {}; for i = 1, 1500 do ids[i] = 1000 + i end; return ids end
api.GetRecipeInfo = function(id) return { name = "R" .. id, learned = true } end
api.GetRecipeSchematic = function() return { reagentSlotSchematics = { { reagents = { { itemID = LINEN } }, quantityRequired = 1 } } } end
clock = clock + 3
scanner.fn(scanner, "TRADE_SKILL_SHOW")
n = 0
for _ in pairs(ProfessionGuideDB.recipes) do n = n + 1 end
check(n <= 1000, "recipes bounded, got " .. n)
text = page("craft")
check(text:find("...and", 1, true), "long list cut with a count")

check(#forbidden == 0, "forbidden calls: " .. table.concat(forbidden, ", "))
if #failures > 0 then
    realPrint("FAILURES (" .. #failures .. "):")
    for _, why in ipairs(failures) do realPrint(" - " .. why) end
    os.exit(1)
end
realPrint("test_r5b_professionguide_craft: all checks passed")
