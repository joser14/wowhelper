-- Round 5 #16: RepWatch lists repeatable turn-in materials you hold (bags, bank, other characters) with the
-- turn-ins they make and how many more reach the next standing; it counts your turn-ins and learns their real
-- value from QUEST_TURNED_IN + the bag drop + the reputation gain. It never turns anything in.
-- Run from the harness folder:  node run.js "<workspace root>" test_r5b_repwatch_turnins.lua
local out, failures, frames, forbidden = {}, {}, {}, {}
local realPrint = print
local SECRET = {}
local function check(cond, why) if not cond then failures[#failures + 1] = why end end
issecretvalue = function(v) return v == SECRET end
ForeverHub_Receive = function(_, t) out[#out + 1] = t end
for _, name in ipairs({ "hooksecurefunc", "CompleteQuest", "GetQuestReward", "SelectActiveQuest", "AcceptQuest", "print" }) do
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
FACTION_STANDING_LABEL4, FACTION_STANDING_LABEL5, FACTION_STANDING_LABEL6 = "Neutral", "Friendly", "Honored"
FACTION_STANDING_LABEL7, FACTION_STANDING_LABEL8 = "Revered", "Exalted"
local clock = 500
GetTime = function() return clock end

local factions = {
    { factionID = 576, name = "Timbermaw Hold", currentStanding = 3500, reaction = 5, currentReactionThreshold = 3000, nextReactionThreshold = 9000 },
    { factionID = 72, name = "Stormwind", currentStanding = 42000, reaction = 8, currentReactionThreshold = 42000, nextReactionThreshold = 42999 },
    { factionID = 69, name = "Darnassus", currentStanding = 10000, reaction = 6, currentReactionThreshold = 9000, nextReactionThreshold = 21000 },
}
C_Reputation = {
    GetNumFactions = function() return #factions end,
    GetFactionDataByIndex = function(i) return factions[i] end,
}
local bags, bank = { [21377] = 12, [14047] = 45 }, { [21377] = 3 }
C_Item = { GetItemCount = function(id, includeBank)
    return (bags[id] or 0) + (includeBank and (bank[id] or 0) or 0)
end }
ForeverCharacterKey = function() return "Player-1-0001" end
ItemFinderDB = {
    ["Player-1-0001"] = { items = { bags = { [21377] = 12 } } },   -- this character: not counted twice
    ["Player-1-0002"] = { items = { bags = { [21383] = 4 }, bank = { [21377] = 5 } } },
}

RepWatchDB = nil
assert(loadfile(ADDON_PATH .. "/RepWatch/RepWatch.lua"))("RepWatch", {})
local f = frames[#frames]
local function fire(e, ...) f.fn(f, e, ...) end
local function page() out = {}; SlashCmdList.REPWATCH("all"); return table.concat(out, "\n") end
check(f.registered.QUEST_TURNED_IN and f.registered.BAG_UPDATE_DELAYED, "turn-in events registered")
fire("ADDON_LOADED", "RepWatch")
fire("PLAYER_ENTERING_WORLD")

----- The page: materials you hold, with turn-ins and what's left to the next standing
local text = page()
check(text:find("Repeatable turn-ins", 1, true), "section shown:\n" .. text)
check(text:find("Deadwood Headdress Feather: 12 in bags, 3 in the bank, 5 on other characters = 3 turn-ins of 5, about 900 rep", 1, true),
    "feathers line:\n" .. text)
check(text:find("19 turn-ins (95) to Honored", 1, true), "to the next standing (5500 left / 300):\n" .. text)
check(text:find("Winterfall Spirit Beads: 4 on other characters = 0 turn-ins", 1, true), "alts' beads listed:\n" .. text)
check(text:find("(guide value)", 1, true), "guide values marked until learned")
check(not text:find("Stormwind", 1, true) or not text:find("Runecloth: .-Stormwind"), "exalted factions get no turn-in line")
local _, runecloth = text:gsub("Runecloth:", "")
check(runecloth == 1, "runecloth listed under Darnassus only (Stormwind is Exalted), got " .. runecloth)
check(not text:find("Argent Dawn", 1, true), "factions you haven't met aren't listed")

----- A turn-in: quest turned in, 5 feathers leave the bags, Timbermaw rises by 330 (racial bonus)
fire("QUEST_TURNED_IN", 8461, 0, 0)
clock = clock + 0.5
bags[21377] = 7
fire("BAG_UPDATE_DELAYED")
clock = clock + 0.5
factions[1].currentStanding = 3830
fire("UPDATE_FACTION")
check(RepWatchDB.turnins and RepWatchDB.turnins[576] == 1, "turn-in counted: " .. tostring(RepWatchDB.turnins and RepWatchDB.turnins[576]))
check(RepWatchDB.learned and RepWatchDB.learned[21377] == 330, "real value learned: " .. tostring(RepWatchDB.learned and RepWatchDB.learned[21377]))
text = page()
check(text:find("Timbermaw Hold |cff999999(1 turn-in counted)|r", 1, true), "count shown:\n" .. text)
check(text:find("Deadwood Headdress Feather: 7 in bags, 3 in the bank, 5 on other characters = 2 turn-ins of 5, about 660 rep.", 1, true),
    "learned value used:\n" .. text)

----- Two at once, reputation first this time
clock = clock + 30
factions[1].currentStanding = 4490
fire("UPDATE_FACTION")
clock = clock + 0.2
fire("QUEST_TURNED_IN", 8461, 0, 0)
bags[21377] = 0
bank[21377] = 0
fire("BAG_UPDATE_DELAYED")
check(RepWatchDB.turnins[576] == 1, "bags dropped by 7, not a multiple of 5: not counted")
bags[21377] = 10
fire("BAG_UPDATE_DELAYED")
clock = clock + 30
fire("QUEST_TURNED_IN", 8461, 0, 0)
bags[21377] = 0
fire("BAG_UPDATE_DELAYED")
factions[1].currentStanding = 5150
fire("UPDATE_FACTION")
check(RepWatchDB.turnins[576] == 3 and RepWatchDB.learned[21377] == 330, "two turn-ins in one go: " .. tostring(RepWatchDB.turnins[576]))

----- No turn-in event: a drop and a gain alone aren't a turn-in
clock = clock + 30
bags[14047] = 25
fire("BAG_UPDATE_DELAYED")
factions[3].currentStanding = 10075
fire("UPDATE_FACTION")
check(RepWatchDB.turnins[69] == nil, "no QUEST_TURNED_IN, nothing counted")

----- Too far apart: not matched
clock = clock + 30
fire("QUEST_TURNED_IN", 7811, 0, 0)
clock = clock + 10
bags[14047] = 5
fire("BAG_UPDATE_DELAYED")
factions[3].currentStanding = 10150
fire("UPDATE_FACTION")
check(RepWatchDB.turnins[69] == nil, "events 10 s apart aren't one turn-in")

----- Secret and missing values are quiet
factions[1].currentStanding = SECRET
fire("UPDATE_FACTION")
text = page()
C_Item = nil
text = page()
check(type(text) == "string", "no item API: page still works")
ItemFinderDB = "junk"
fire("BAG_UPDATE_DELAYED")
text = page()

check(#forbidden == 0, "forbidden calls: " .. table.concat(forbidden, ", "))
if #failures > 0 then
    realPrint("FAILURES (" .. #failures .. "):")
    for _, why in ipairs(failures) do realPrint(" - " .. why) end
    os.exit(1)
end
realPrint("test_r5b_repwatch_turnins: all checks passed")
