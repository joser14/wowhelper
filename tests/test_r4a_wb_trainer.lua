-- Round 4 R16, WindowBadges side: at a class trainer, one badge on the window says whether your reputation gives
-- the 10 % trainer discount: "10% off (Honored)" or "10% off at Honored with <faction>" (the closest one, names
-- from the game). Trainer factions per class from TrainerNotesData (What's Training, MIT); none without it.
-- Mocks trimmed from test_windowbadges.lua.
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
local function badgeText(target)
    for _, f in ipairs(created) do
        if rawget(f, "parent") == overlay and rawget(f, "shown") and rawget(f, "target") == target then
            for _, kid in ipairs(rawget(f, "kids") or {}) do
                if kid.text then return kid.text end
            end
        end
    end
end
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

C_Item = { GetItemInfo = function() end }
SlashCmdList = {}
Enum = { TrainerType = { General = 0, Tradeskills = 2 } }
C_Trainer = { GetTrainerType = function() return 0 end }
GetNumTrainerServices = function() return 0 end
ClassTrainerFrame = button(0)
UnitClass = function() return "Mage", "MAGE" end
UnitFactionGroup = function() return "Alliance" end
TrainerNotesData = { trainerFactions = { MAGE = { Alliance = { 47, 72 }, Horde = { 68 } } } }
local rep = { [47] = { name = "Ironforge", reaction = 5, currentStanding = 4000 }, [72] = { name = "Stormwind", reaction = 5, currentStanding = 9000 } }
C_Reputation = { GetFactionDataByID = function(id) return rep[id] end }

assert(loadfile(ADDON_PATH .. "/WindowBadges/WindowBadges.lua"))("WindowBadges", {})
for _, f in ipairs(created) do local s = rawget(f, "scripts"); if s and s.OnEvent then events = f end end
local function fire(event) events.scripts.OnEvent(events, event); flush() end
fire("PLAYER_LOGIN")

-- 1. Friendly with both: the badge names the closest one (most standing).
fire("TRAINER_SHOW")
local text = badgeText(ClassTrainerFrame)
assert(text == "10% off at Honored with Stormwind", "closest faction named, got " .. tostring(text))
-- 2. Honored with one: the discount is on.
rep[47].reaction = 6
fire("TRAINER_UPDATE")
text = badgeText(ClassTrainerFrame)
assert(text == "10% off (Honored with Ironforge)", "discount on, got " .. tostring(text))
-- 3. A profession trainer: no badge. Reputation unreadable or no data: no badge.
fire("TRAINER_CLOSED")
C_Trainer.GetTrainerType = function() return 2 end
fire("TRAINER_SHOW")
assert(badgeText(ClassTrainerFrame) == nil, "no badge at a profession trainer")
fire("TRAINER_CLOSED")
C_Trainer.GetTrainerType = function() return 0 end
TrainerNotesData = nil
fire("TRAINER_SHOW")
assert(badgeText(ClassTrainerFrame) == nil, "no badge without the trainer faction data")
-- 4. Switched off with the trainer badges.
TrainerNotesData = { trainerFactions = { MAGE = { Alliance = { 47 } } } }
SlashCmdList.WINDOWBADGES("off trainer")
fire("TRAINER_UPDATE")
assert(badgeText(ClassTrainerFrame) == nil, "trainer badges off: no discount badge")
assert(#handled == 0, "no errors: " .. table.concat(handled, "\n"))
print("test_r4a_wb_trainer: ok")