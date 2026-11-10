-- Round 4 R14, Tooltips side: "You have" counts by item ID from ItemFinder's new records (bags, bank, worn,
-- keyring, mail), still reads old name-keyed records, and marks characters of the other faction.
-- Harness trimmed from test_tooltips.lua.
local frames, failures = {}, {}
issecretvalue = function() return false end
ForeverHub_Receive = function() end
CreateFrame = function()
    local f = { registered = {} }
    f.RegisterEvent = function(self, e) self.registered[e] = true end
    f.SetScript = function(self, _, fn) self.fn = fn end
    frames[#frames + 1] = f
    return f
end
SlashCmdList = {}
UnitName = function(u) if u == "player" then return "Juan" end end
GetRealmName = function() return "R" end
UnitFactionGroup = function() return "Alliance" end
time = function() return 1000000 end
local callbacks = {}
Enum = { TooltipDataType = { Item = 0, Unit = 2 }, TooltipDataLineType = { SellPrice = 11 } }
TooltipDataProcessor = { AddTooltipPostCall = function(kind, fn) callbacks[kind] = fn end }
TooltipUtil = { GetDisplayedItem = function() return nil end }
local tip = { lines = {} }
GameTooltip = tip
ItemRefTooltip = { lines = {} }
function tip:AddLine(t) self.lines[#self.lines + 1] = t end
function tip:AddDoubleLine(l, r) self.lines[#self.lines + 1] = l .. " = " .. r end
function tip:GetName() return "GameTooltip" end
function tip:NumLines() return #self.lines end
function tip:GetProcessingTooltipInfo() return nil end
C_Item = { GetItemInfo = function(id)
    if id == 2589 then return "Linen Cloth", "link", 1, 5, 1, "t", "s", 20, "", 1, 13, 7, 0, 0 end
    if id == 5396 then return "Key to Searing Gorge", "link", 1, 5, 1, "t", "s", 1, "", 1, 0, 13, 0, 1 end
end }
C_Container = { GetContainerItemInfo = function() end }

ItemFinderDB = {
    -- New records, keyed by ID; the saved name can differ from the client's (renamed item).
    ["Juan-R"] = { charName = "Juan", faction = "Alliance", names = { [2589] = "Old Linen" },
        items = { bags = { [2589] = 5 }, bank = { [2589] = 7 }, mail = { [2589] = 2 }, keys = { [5396] = 1 }, gear = {} } },
    ["Alt-R"] = { charName = "Alt", faction = "Horde", items = { bags = { [2589] = 3 } } },
    -- An old record, by name.
    ["Old-R"] = { bags = { ["Linen Cloth"] = 1 } },
}

local function has(text) for _, t in ipairs(tip.lines) do if tostring(t):find(text, 1, true) then return true end end return false end
local function need(text, why) if not has(text) then failures[#failures + 1] = why .. ": wanted '" .. text .. "' in\n  " .. table.concat(tip.lines, "\n  ") end end
local function hover(id) tip.lines = {}; local ok, err = pcall(callbacks[0], tip, { id = id }); if not ok then failures[#failures + 1] = tostring(err) end end

assert(loadfile(ADDON_PATH .. "/Tooltips/Tooltips.lua"))("Tooltips", {})
frames[#frames].fn(frames[#frames], "PLAYER_LOGIN")

hover(2589)
need("You have = 18 ", "total over every character, by ID and by old name")
need("Juan 5 bags, 7 bank, 2 mail", "your own places, mail included")
need("Alt 3 (Horde)", "the other faction is named")
need("Old 1", "old name-keyed record still counted")
hover(5396)
need("You have = 1 ", "keyring counted")
need("Juan 1 keyring", "keyring named")

if #failures > 0 then error(table.concat(failures, "\n")) end
print("test_r4a_tooltips_count: ok")
