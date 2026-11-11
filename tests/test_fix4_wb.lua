-- Review 4, note 10 and perf audit 11 (WindowBadges): the trainer discount badge says "10% off (Honored with X)"
-- only when this trainer's prices show the discount (list price from TrainerNotesData, 10 % off); at full prices
-- there is no badge, and when it can't tell it names where the discount applies. The watcher OnUpdate runs only
-- while a reward, merchant or trainer window is open. Mocks copied from test_r4a_wb_trainer.lua.
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
-- A. The watcher only runs while a window is open (perf audit 11).
assert(overlay.scripts.OnUpdate == nil, "no watcher with no window open")

-- B. Trainer discount (review 4, note 10): shown as on only when this trainer's prices show it.
local services = {}
GetNumTrainerServices = function() return #services end
-- Blizzard's return order: name, rank, type.
GetTrainerServiceInfo = function(i) local s = services[i]; if s then return s[1], s[2], s[3] end end
GetTrainerServiceCost = function(i) return services[i] and services[i][4] end
local SPELLS = { [116] = { "Frostbolt", "Rank 1" }, [205] = { "Frostbolt", "Rank 2" }, [143] = { "Fireball", "Rank 2" } }
C_Spell = {
    GetSpellName = function(id) return SPELLS[id] and SPELLS[id][1] end,
    GetSpellSubtext = function(id) return SPELLS[id] and SPELLS[id][2] end,
}
TrainerNotesData = {
    trainerFactions = { MAGE = { Alliance = { 47, 72 } } },
    classes = { MAGE = { spells = { { 4, 116, 100 }, { 8, 205, 1000 }, { 6, 143, 1000 } } } },
}
rep[47].reaction = 6   -- Honored with Ironforge
rep[72].reaction = 5
-- 1. This trainer asks 10 % under the list price: the discount applies here.
services = { { "Frostbolt", "Rank 2", "available", 900 } }
fire("TRAINER_SHOW")
assert(overlay.scripts.OnUpdate, "watcher on while the trainer is open")
local text = badgeText(ClassTrainerFrame)
assert(text == "10% off (Honored with Ironforge)", "discount seen in the prices, got " .. tostring(text))
fire("TRAINER_CLOSED")
assert(overlay.scripts.OnUpdate == nil, "watcher off once the window closes")
-- 2. Full list prices here (another faction's trainer): no discount badge.
services = { { "Frostbolt", "Rank 2", "available", 1000 }, { "Fireball", "Rank 2", "unavailable", 1000 } }
fire("TRAINER_SHOW")
text = badgeText(ClassTrainerFrame)
assert(text == nil, "full prices: no discount badge, got " .. tostring(text))
fire("TRAINER_CLOSED")
-- 3. Nothing priced that the list knows: says where it applies, not that it applies here.
services = { { "Arcane Missiles", "Rank 1", "available", 900 } }
fire("TRAINER_SHOW")
text = badgeText(ClassTrainerFrame)
assert(text == "10% off at Ironforge trainers", "can't tell here, got " .. tostring(text))
fire("TRAINER_CLOSED")
-- 4. The other return order (name, type, _, level, rank) is read too.
GetTrainerServiceInfo = function(i) local s = services[i]; if s then return s[1], s[3], nil, 8, s[2] end end
services = { { "Frostbolt", "Rank 2", "available", 900 } }
fire("TRAINER_SHOW")
text = badgeText(ClassTrainerFrame)
assert(text == "10% off (Honored with Ironforge)", "other order, got " .. tostring(text))
fire("TRAINER_CLOSED")
-- 5. A merchant or a quest window turns the watcher on as well.
fire("MERCHANT_SHOW")
assert(overlay.scripts.OnUpdate, "watcher on at a merchant")
fire("MERCHANT_CLOSED")
fire("QUEST_DETAIL")
assert(overlay.scripts.OnUpdate, "watcher on at a quest")
fire("QUEST_FINISHED")
assert(overlay.scripts.OnUpdate == nil, "and off after")
assert(#handled == 0, "no errors: " .. table.concat(handled, "\n"))
print("test_fix4_wb: ok")
