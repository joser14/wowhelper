-- Round 4 R15 in WindowBadges: no "Most gold" coin when a reward choice can't be scored (ItemAdvisor says "No stats
-- to score" or "Has stats I can't score", e.g. an on-use trinket). Mocks trimmed from test_windowbadges.lua.
local handled, timers = {}, {}
issecretvalue = function() return false end
geterrorhandler = function() return function(e) handled[#handled + 1] = tostring(e) end end
ForeverHub_Receive = function() end
InCombatLockdown = function() return false end
C_Timer = { After = function(_, fn) timers[#timers + 1] = fn end }
local function flush() local g = 0; while #timers > 0 and g < 100 do g = g + 1; table.remove(timers, 1)() end end

local function region(kind)
    local r = { kind = kind, shown = true }
    function r:SetPoint(_, target) self.target = target end
    function r:ClearAllPoints() self.target = nil end
    function r:Show() self.shown = true end
    function r:Hide() self.shown = false end
    function r:SetShown(v) self.shown = v and true or false end
    function r:IsShown() return self.shown end
    function r:SetText(t) self.text = t end
    function r:GetStringWidth() return 10 end
    function r:SetAtlas(a) self.atlas = a; return true end
    function r:SetTexture(t) self.texture = t end
    -- Unknown methods (capitalised) are no-ops; unknown fields stay nil.
    return setmetatable(r, { __index = function(_, k) if type(k) == "string" and k:match("^%u") then return function() end end end })
end
local created, overlay, events = {}, nil, nil
CreateFrame = function(_, name, parent)
    local f = region("frame")
    f.parent = parent
    f.SetScript = function(self, s, fn) rawset(self, "scripts", rawget(self, "scripts") or {}); self.scripts[s] = fn end
    f.RegisterEvent = function() end
    f.CreateTexture = function(self) local t = region("texture"); local k = rawget(self, "kids") or {}; rawset(self, "kids", k); k[#k + 1] = t; return t end
    f.CreateFontString = f.CreateTexture
    created[#created + 1] = f
    if name == "WindowBadgesOverlay" then overlay = f end
    return f
end
local function button(id)
    return { type = "choice", objectType = "item", GetID = function() return id end, IsVisible = function() return true end,
        IsShown = function() return true end, GetTop = function() return 100 end, GetBottom = function() return 80 end }
end
UIParent = button(0)
local rewardButtons = { button(1), button(2), button(3) }
QuestInfoRewardsFrame = { RewardButtons = rewardButtons }
QuestFrame = button(0)
local function gold(target)
    for _, f in ipairs(created) do
        if rawget(f, "parent") == overlay and rawget(f, "shown") and rawget(f, "target") == target then
            for _, kid in ipairs(rawget(f, "kids") or {}) do
                if kid.text == "Most gold" then return true end
            end
        end
    end
    return false
end

local items = {}
local function def(id, name, price) local link = "|Hitem:" .. id .. "::::|h[" .. name .. "]|h"; items[link] = { name = name, price = price }; return link end
C_Item = {
    GetItemInfo = function(link) local i = items[link]; if i then return i.name, link, 2, 10, 1, "", "", 1, "INVTYPE_FINGER", 1, i.price, 4, 1, 0 end end,
    GetItemInfoInstant = function(link) return tonumber(link:match("item:(%d+)")) end,
    RequestLoadItemDataByID = function() end,
}
local reasons = {}
ItemAdvisor_IsUpgrade = function(link) return false, reasons[link] or "Not an upgrade" end
local choices = {}
GetNumQuestChoices = function() return #choices end
GetQuestItemLink = function(_, i) return choices[i] end
GetQuestItemInfo = function() return "name", "tex", 1 end
GetQuestItemInfoLootType = function() return 0 end
SlashCmdList = {}
Enum = {}

assert(loadfile(ADDON_PATH .. "/WindowBadges/WindowBadges.lua"))("WindowBadges", {})
for _, f in ipairs(created) do local s = rawget(f, "scripts"); if s and s.OnEvent then events = f end end
local function fire(event) events.scripts.OnEvent(events, event); flush() end
fire("PLAYER_LOGIN")
SlashCmdList.WINDOWBADGES("on gold")

local cheap, dear, idol = def(1, "Cheap Ring", 100), def(2, "Dear Ring", 900), def(3, "Odd Idol", 300)
choices = { cheap, dear }
fire("QUEST_COMPLETE")
assert(gold(rewardButtons[2]), "scored choices: Most gold on the dearer one")

choices = { cheap, dear, idol }
reasons[idol] = "No stats to score; judge its effect yourself"
fire("QUEST_COMPLETE")
for i = 1, 3 do assert(not gold(rewardButtons[i]), "no Most gold with an unscored choice (button " .. i .. ")") end
reasons[idol] = "Has stats I can't score; compare it yourself"
fire("QUEST_COMPLETE")
for i = 1, 3 do assert(not gold(rewardButtons[i]), "no Most gold with stats we can't score (button " .. i .. ")") end

-- Without ItemAdvisor nothing is known about scoring, so the coin shows as before.
ItemAdvisor_IsUpgrade = nil
fire("QUEST_COMPLETE")
assert(gold(rewardButtons[2]), "no ItemAdvisor: Most gold as before")
assert(#handled == 0, "no errors: " .. table.concat(handled, "\n"))
print("test_r4a_wb_rewards: ok")
