-- Round 4 R21: on a Waylaid Crate tooltip, each "- N Material" line under "Use:" gets the counts from ItemFinder
-- across your characters that can mail it to you (same realm and faction): "Soul Dust 20: you 12, Alt 9 - enough".
-- Idea and in-game line format from Alts Forever (MIT, no code).
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

C_Item = { GetItemInfo = function(id)
    if id == 248689 then return "Waylaid Supplies", "link", 1, 1, 1, "t", "s", 1, "", 1, 0, 15, 0, 1 end
end }
ItemFinderDB = {
    ["Juan-R"] = { charName = "Juan", faction = "Alliance", realm = "R", names = { [15000] = "Soul Dust" }, items = { bags = { [15000] = 12 } } },
    ["Alt-R"] = { charName = "Alt", faction = "Alliance", realm = "R", names = { [15000] = "Soul Dust", [2589] = "Linen Cloth" }, items = { bank = { [15000] = 9, [2589] = 3 } } },
    ["Horde-R"] = { charName = "Grunt", faction = "Horde", realm = "R", names = { [15000] = "Soul Dust" }, items = { bags = { [15000] = 50 } } },
    ["Old-R"] = { bags = { ["Linen Cloth"] = 2 } },
}
local function has(text) for _, t in ipairs(tip.lines) do if tostring(t):find(text, 1, true) then return true end end return false end
local function need(text, why) if not has(text) then failures[#failures + 1] = why .. ": wanted '" .. text .. "' in\n  " .. table.concat(tip.lines, "\n  ") end end
local function lack(text, why) if has(text) then failures[#failures + 1] = why .. ": did not want '" .. text .. "' in\n  " .. table.concat(tip.lines, "\n  ") end end
local crateLines = { { leftText = "Waylaid Supplies" }, { leftText = "Use: Fill this crate with one of the bundles below." },
    { leftText = "- 20 Soul Dust" }, { leftText = "- 10 Linen Cloth" }, { leftText = "- 5 Wool Cloth" } }
local function hover(id, lines) tip.lines = {}; local ok, err = pcall(callbacks[0], tip, { id = id, lines = lines }); if not ok then failures[#failures + 1] = tostring(err) end end

assert(loadfile(ADDON_PATH .. "/Tooltips/Tooltips.lua"))("Tooltips", {})
frames[#frames].fn(frames[#frames], "PLAYER_LOGIN")

hover(248689, crateLines)
need("Soul Dust 20: you 12, Alt 9 - enough", "enough across your mailable characters")
lack("Grunt", "the other faction can't mail it to you")
need("Linen Cloth 10: Alt 3, Old 2 - 5 short", "short, with an old name-keyed record")
need("Wool Cloth 5: none", "nobody has it")
-- Not a crate: no lines.
hover(2589, { { leftText = "Linen Cloth" }, { leftText = "- 20 Soul Dust" } })
lack("Soul Dust 20", "only on Waylaid Crates")

if #failures > 0 then error(table.concat(failures, "\n")) end
print("test_r4a_tooltips_crate: ok")