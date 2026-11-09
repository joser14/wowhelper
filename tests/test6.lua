local base = ADDON_PATH
local chat, frames = {}, {}
local SECRET = {}
local function reset() chat = {} end
CreateFrame = function()
    local f = { registered = {} }
    f.RegisterEvent = function(self, e) self.registered[e] = true end
    f.SetScript = function(self, _, fn) self.fn = fn end
    frames[#frames + 1] = f
    return f
end
DEFAULT_CHAT_FRAME = { AddMessage = function(_, t) chat[#chat + 1] = t end }
SlashCmdList = {}
issecretvalue = function(v) return v == SECRET end
local level, now = 20, 1000
UnitLevel = function() return level end
GetTime = function() return now end
local function load(name)
    local n = #frames
    assert(loadfile(base .. "/" .. name .. "/" .. name .. ".lua"))(name, {})
    return frames[n + 1]
end
local function fire(f, ev, ...) assert(f.registered[ev], "not registered: " .. ev); f.fn(f, ev, ...) end
local function saw(text) for _, t in ipairs(chat) do if t:find(text, 1, true) then return true end end return false end
local function need(text, why) assert(saw(text), why .. ": wanted '" .. text .. "' in:\n" .. table.concat(chat, "\n")) end
local function never(text, why) assert(not saw(text), why .. ": did not want '" .. text .. "' in:\n" .. table.concat(chat, "\n")) end

-- RestGuard
local resting, rested, maxXP, cdStart, cdDur = false, 500, 1000, 0, 0
IsResting = function() return resting end
GetXPExhaustion = function() return rested end
UnitXPMax = function() return maxXP end
GetBindLocation = function() return "Goldshire" end
C_Container = { GetItemCooldown = function() return cdStart, cdDur, 1 end }
local rg = load("RestGuard")
fire(rg, "PLAYER_CAMPING")
need("logging out outside a rested area", "warns outside")
reset(); resting = true; fire(rg, "PLAYER_CAMPING")
assert(#chat == 0, "quiet in an inn")
resting = false; level = 60; fire(rg, "PLAYER_CAMPING")
assert(#chat == 0, "quiet at max level")
level = 20; resting = SECRET; fire(rg, "PLAYER_CAMPING")
assert(#chat == 0, "secret isn't treated as outside")
resting = true; reset(); SlashCmdList.RESTGUARD("")
need("You're in a rested area", "status")
need("Rested: 50% of this level. About 6.7 days", "(150-50)/0.625 hours")
need("Hearthstone: Goldshire, ready", "ready")
cdStart, cdDur = 900, 1800; reset(); SlashCmdList.RESTGUARD("")
need("ready in 29 min", "cooldown: 1700s left rounds up")
rested = nil; cdStart, cdDur = 0, 0; reset(); SlashCmdList.RESTGUARD("")
need("Rested: 0%", "no rest")
rested = 1500; reset(); SlashCmdList.RESTGUARD("")
need("That's full", "full")
level = 60; reset(); SlashCmdList.RESTGUARD("")
never("Rested:", "hidden at max level")
level = 20

-- RepWatch
reset()
local factions = {}
C_Reputation = { GetNumFactions = function() return #factions end, GetFactionDataByIndex = function(i) return factions[i] end }
FACTION_STANDING_LABEL4, FACTION_STANDING_LABEL5, FACTION_STANDING_LABEL6 = "Neutral", "Friendly", "Honored"
local rw = load("RepWatch")
fire(rw, "PLAYER_ENTERING_WORLD")
factions = { { isHeader = true, name = "Alliance" },
    { factionID = 72, name = "Stormwind", currentStanding = 3100, reaction = 5, currentReactionThreshold = 3000, nextReactionThreshold = 9000 },
    { factionID = 47, name = "Ironforge", currentStanding = 100, reaction = 4, currentReactionThreshold = 0, nextReactionThreshold = 3000 } }
fire(rw, "BAG_UPDATE_DELAYED")
SlashCmdList.REPWATCH("")
need("No reputation gained", "nothing yet")
factions[2].currentStanding = 3350
reset(); SlashCmdList.REPWATCH("")
need("Stormwind: +250 this session. Friendly 350/6000, 5650 to Honored", "gain and progress")
never("Ironforge", "no change")
reset(); SlashCmdList.REPWATCH(" all ")
need("Ironforge: Neutral 100/3000, 2900 to Friendly", "all")
never("Alliance", "plain header skipped")
factions[3].currentStanding = SECRET
reset(); SlashCmdList.REPWATCH("all")
never("Ironforge", "secret skipped")
factions = {}; reset(); SlashCmdList.REPWATCH("all")
need("No factions", "empty")

-- FoodCheck
reset()
local items, bag, tips = {}, {}, {}
NUM_TOTAL_EQUIPPED_BAG_SLOTS = 0
C_Container.GetContainerNumSlots = function() return #bag end
C_Container.GetContainerItemInfo = function(_, i) return bag[i] end
local requested = {}
C_Item = {
    GetItemInfo = function(link) local t = items[link]; if not t then return nil end; return "n", link, 1, 1, t.min, "", "", 1, "", 0, 1, t.c or 0, t.s or 5 end,
    RequestLoadItemDataByID = function(id) requested[id] = true end,
}
C_TooltipInfo = { GetHyperlink = function(link)
    local lines = { { leftText = "Name" } }
    for _, t in ipairs(tips[link] or {}) do lines[#lines + 1] = { leftText = t } end
    return { lines = lines }
end }
local function item(link, min, tip, extra)
    items[link] = extra or { min = min }
    tips[link] = { tip }
end
item("[Bread]", 1, "Use: Restores 61 health over 18 sec.")
item("[Cheese]", 15, "Use: Restores 243 health over 21 sec.")
item("[Roast]", 45, "Use: Restores 2000 health over 27 sec.")
item("[Water]", 5, "Use: Restores 436 mana over 21 sec.")
item("[Both]", 3, "Use: Restores 100 health and 100 mana over 20 sec.")
item("[Odd]", 10, "Tasty.")
item("[Sword]", 1, "Use: Restores 9 health.", { min = 1, c = 2, s = 7 })
load("FoodCheck")
level = 20
bag = { { hyperlink = "[Bread]", stackCount = 5 }, { hyperlink = "[Bread]", stackCount = 2 }, { hyperlink = "[Cheese]", stackCount = 3 },
    { hyperlink = "[Roast]", stackCount = 1 }, { hyperlink = "[Water]", stackCount = 4 }, { hyperlink = "[Sword]", stackCount = 1 } }
SlashCmdList.FOODCHECK("")
need("Best food: [Cheese] x3", "best usable, not too high")
need("Best drink: [Water] x4", "drink")
need("Too high for now: [Roast] (level 45)", "too high")
never("Sword", "not food")
never("Bread] (level", "level 1 food is never outgrown")
level = 30
reset(); SlashCmdList.FOODCHECK("")
need("Outgrown: [Cheese] (level 15)", "15 levels behind")
level = 20
bag = { { hyperlink = "[Both]", stackCount = 2 }, { hyperlink = "[Odd]", stackCount = 1 }, { hyperlink = "[Unknown]", stackCount = 1, itemID = 77 } }
reset(); SlashCmdList.FOODCHECK("")
need("Best food: [Both] x2", "both, food")
need("Best drink: [Both] x2", "both, drink")
need("Couldn't tell what [Odd]", "unclear")
need("still loading", "uncached")
assert(requested[77], "requested")
bag = {}
reset(); SlashCmdList.FOODCHECK("")
need("No usable food", "empty")
need("No usable drink", "empty")

print("ALL TESTS PASSED")
