-- Shared Forever character identity (the same copy is in every helper that saves per-character data,
-- so each helper still works alone; whichever loads first defines it). On Forever a character has a
-- first name and a surname (UnitName's second return), so the first name alone is not unique.
-- Key = the player GUID ("Player-<server>-<id>"); when that can't be read, "First Surname-Realm".
do
    local function Plain(value)
        if value == nil or (issecretvalue and issecretvalue(value)) or type(value) ~= "string" or value == "" then
            return nil
        end
        return value
    end
    local function Call(fn, ...)
        if type(fn) ~= "function" then
            return nil
        end
        local ok, a, b = pcall(fn, ...)
        if not ok then
            return nil
        end
        return Plain(a), Plain(b)
    end
    -- "First Surname" on Forever, the plain name elsewhere; nil when unreadable.
    ForeverCharacterName = ForeverCharacterName or function()
        local name, surname = Call(UnitName, "player")
        if not name then
            return nil
        end
        if surname then
            return name .. " " .. surname
        end
        return name
    end
    ForeverCharacterGUID = ForeverCharacterGUID or function()
        local guid = Call(UnitGUID, "player")
        if guid and guid:match("^Player%-") then
            return guid
        end
    end
    -- The key older versions used: first name only, "-", realm.
    ForeverCharacterLegacyKey = ForeverCharacterLegacyKey or function()
        local name = Call(UnitName, "player")
        local realm = Call(GetRealmName)
        return (name or "Unknown") .. "-" .. (realm or "Unknown")
    end
    -- "First Surname-Realm": the key when the GUID can't be read.
    ForeverCharacterNameKey = ForeverCharacterNameKey or function()
        local realm = Call(GetRealmName)
        return (ForeverCharacterName() or "Unknown") .. "-" .. (realm or "Unknown")
    end
    ForeverCharacterKey = ForeverCharacterKey or function()
        return ForeverCharacterGUID() or ForeverCharacterNameKey()
    end
    -- Once per login: moves this character's record from an older key to the current one. Only when
    -- nothing is saved under the current key yet (two records are never merged), and never a record
    -- stamped with another character's GUID. The old key's record is moved, not copied, so a second
    -- character with the same first name starts fresh instead of sharing it. Returns the current key.
    -- oldKeys: optional list of this helper's own older key spellings (default: the legacy key).
    ForeverCharacterAdopt = ForeverCharacterAdopt or function(db, oldKeys)
        local key = ForeverCharacterKey()
        if type(db) ~= "table" or db[key] ~= nil then
            return key
        end
        local guid = ForeverCharacterGUID()
        local candidates = { ForeverCharacterNameKey() }
        for _, old in ipairs(oldKeys or { ForeverCharacterLegacyKey() }) do
            candidates[#candidates + 1] = old
        end
        for _, old in ipairs(candidates) do
            local record = old ~= key and db[old]
            if type(record) == "table" and (record.charGUID == nil or record.charGUID == guid) then
                db[key] = record
                db[old] = nil
                record.migratedFrom = old
                break
            end
        end
        return key
    end
    -- Writes who a record belongs to into it, so pages can show a name instead of parsing the key.
    ForeverCharacterStamp = ForeverCharacterStamp or function(record)
        if type(record) ~= "table" then
            return record
        end
        record.charName = ForeverCharacterName() or record.charName
        record.charGUID = ForeverCharacterGUID() or record.charGUID
        return record
    end
end

local _, ns = ...
-- Shared with ForeverHubExtras.lua (keybindings, settings panel, alerts, hearthstone button), which
-- loads right after this file. Other files in the same bundle share this table, hence the own key.
local extras = {}
if type(ns) == "table" then
    ns.ForeverHub = extras
end

local PANEL_WIDTH, ROW_HEIGHT, MAX_ROWS = 280, 18, 10
local WIDTH, HEIGHT, SIDEBAR_WIDTH = 680, 500, 140
-- The page area starts right of the sidebar; the sidebar's own scroll bar sits inside SIDEBAR_WIDTH.
local PAGE_LEFT = SIDEBAR_WIDTH + 22
local PAGE_WIDTH = WIDTH - SIDEBAR_WIDTH - 64
local NAV_WIDTH = SIDEBAR_WIDTH - 18
local NAV_HEIGHT, HEADER_HEIGHT, HEADER_GAP = 18, 20, 4
local MANAGE_ROW_HEIGHT, MANAGE_HEADER_HEIGHT = 36, 46
local RELOAD_CONFIRM_SECONDS = 5
local TOAST_WIDTH, TOAST_SECONDS, MAX_TOASTS = 300, 6, 3
local REPEAT_SECONDS = 15
local MAX_ALERTS = 100
local MINIMAP_RADIUS = 105
local DEFAULT_ANGLE = 215
local MAX_LEVEL = 60

local GOLD, GRAY, GREEN, ORANGE, RED = "|cffffd100", "|cff999999", "|cff33ff33", "|cffffaa66", "|cffff6666"

-- Most useful first; the panel shows these in this order.
local STATUS_ORDER = { "RareWatch", "DeathNotes", "ItemAdvisor", "Builds", "TalentNudge", "TrainerNotes", "SpellReady", "QuestCheck", "Dungeons",
    "DurabilityWatch", "BagCheck", "SupplyWatch", "ProfessionCap", "ProfessionGuide", "WeaponSkillWatch", "GoldGoal", "GoldGuide" }

-- The sidebar groups, one per installed addon (see build.ps1), in the order they're shown.
-- "core" is the addon that holds the hub itself, so it can never be turned off from here.
local SECTIONS = {
    { key = "guides", title = "Guides", addon = "ForeverGuides" },
    { key = "quests", title = "Quests", addon = "ForeverQuests" },
    { key = "bags", title = "Bags & items", addon = "ForeverBags" },
    { key = "character", title = "Character", addon = "ForeverCharacter" },
    { key = "world", title = "World", addon = "ForeverWorld" },
    { key = "hub", title = "Hub", addon = "!ForeverHub", core = true },
}

-- Every helper, with one plain sentence about what it does. Used by the Home and Manage pages.
-- "where" is for helpers that show up somewhere other than a page in this window.
-- "noSwitch" helpers don't talk to the hub, so switching them off here would do nothing.
-- "sources" lists other names a helper uses when it sends a pop-up.
local HELPERS = {
    { name = "LevelGuide", section = "guides", noSwitch = "Own window", where = "its own window at the top of the screen",
        about = "A step-by-step leveling route with an arrow, worked out from your quest log and map." },
    { name = "ProfessionCap", section = "guides", about = "Warns when a profession hits its skill cap and needs the next rank from a trainer." },
    { name = "ProfessionGuide", section = "guides", about = "A full leveling guide for each profession, with a shopping list and trainer notes." },
    { name = "GoldGoal", section = "guides", about = "Shows how close you are to your next riding skill and mount, or a gold goal you set." },
    { name = "GoldGuide", section = "guides", about = "Good ways to make gold at your level, with tips." },
    { name = "Dungeons", section = "guides", about = "Dungeons that suit your level, with details on each. Pin one to keep it handy." },
    { name = "QuestTracker", section = "quests", sources = { "Quests" }, where = "its own quest list on screen, and pop-ups",
        about = "A cleaner quest tracker: turn-ins first, nearest quests on top, XP on every quest." },
    { name = "QuestCheck", section = "quests", about = "How full your quest log is, what's ready to turn in, and which quests are gray or need a group." },
    { name = "ZoneLevels", section = "quests", about = "Shows a zone's level range and warns when you walk into one above your level." },
    { name = "QuestMobs", section = "quests",
        about = "Shows a marker and your progress (like 3/8) next to enemies you still need for a quest, in the open world." },
    { name = "AutoQuest", section = "quests",
        about = "Accepts quests and turns in finished ones when you talk to a quest giver yourself; you still pick between rewards. Hold Shift to pause." },
    { name = "ItemAdvisor", section = "bags", about = "Says whether to equip, keep, sell or auction each item in your bags." },
    { name = "BagCheck", section = "bags", about = "Warns when your bags are nearly full and shows what your junk is worth." },
    { name = "ItemFinder", section = "bags", about = "Searches the bags, bank and gear of all your characters." },
    { name = "PriceMemory", section = "bags", noSwitch = "Saves prices", where = "item tooltips, through Tooltips",
        about = "Remembers the auction prices from searches you make, for Tooltips and the Gold guide." },
    { name = "Tooltips", section = "bags",
        about = "Adds vendor price, last auction price, how many you own on every character and more to item tooltips." },
    { name = "WindowBadges", section = "bags",
        about = "Marks the best quest reward, upgrades at vendors, and new or higher-rank spells at trainers, right in Blizzard's windows." },
    { name = "FoodCheck", section = "bags", about = "The best food and drink in your bags for your level, and which ones you've outgrown." },
    { name = "SupplyWatch", section = "bags", about = "Warns when ammo or items you choose run low, and lists what to restock." },
    { name = "DurabilityWatch", section = "bags", about = "Warns when gear is nearly broken and shows the repair cost." },
    { name = "Builds", section = "character",
        about = "Recommended talent builds for your class for leveling, PvP and dungeons/raids, and which talent to take next." },
    { name = "TalentNudge", section = "character", about = "Tells you when you have unspent talent points." },
    { name = "TrainerNotes", section = "character", about = "Remembers what your trainers sell and tells you when something new is ready." },
    { name = "WeaponSkillWatch", section = "character", about = "Warns when the weapon you hold is far below its skill cap." },
    { name = "RestGuard", section = "character", about = "Shows your rested XP and warns if you log out outside a rested area." },
    { name = "RepWatch", section = "character", about = "Reputation gained this session and how far each faction is from its next standing." },
    { name = "LevelLog", section = "character", about = "Records your play time and deaths for each level." },
    -- Lives in the ReadyCheck folder, but calls itself SpellReady everywhere it talks to the hub.
    { name = "SpellReady", section = "character", about = "Checks for missing buffs and spells you could train a higher rank of." },
    { name = "Landmarks", section = "world", about = "Remembers vendors, inns, flight masters, mailboxes, banks and trainers you visit, and finds the nearest." },
    { name = "DeathNotes", section = "world", about = "Remembers where you died and warns when you walk back into that spot." },
    { name = "RareWatch", section = "world",
        about = "A pop-up and a sound when a rare appears on your minimap; remembers where and when each was last seen or killed, and estimates your layer." },
    { name = "MapPins", section = "world",
        about = "Draws your guide stops, remembered places, deaths, rares, gold farms and dungeon entrances on the world map and minimap. Click a pin to set a waypoint." },
    { name = "ForeverHelper", section = "hub", about = "Leveling rates, a to-do list for each character, and an overview of your characters." },
    { name = "ErrorLog", section = "hub", about = "Saves Lua errors so you can read them later." },
}
local HELPER_BY_NAME, HELPER_BY_SOURCE = {}, {}
for _, helper in ipairs(HELPERS) do
    HELPER_BY_NAME[helper.name] = helper
    HELPER_BY_SOURCE[helper.name] = helper
    for _, source in ipairs(helper.sources or {}) do
        HELPER_BY_SOURCE[source] = helper
    end
end

-- Pages in the details window, in sidebar order. Home and Manage sit above the groups; every other
-- page belongs to the group of the helper that draws it.
local TABS = {
    { label = "Home", home = true, about = "What every helper does, and how to use this window." },
    { label = "Manage", manage = true, about = "Switch helpers on or off, and see which addons are loaded." },
    { label = "Professions", key = "PROFESSIONCAP", helper = "ProfessionCap" },
    { label = "Profession guide", key = "PROFESSIONGUIDE", helper = "ProfessionGuide", hint = "Type a profession to see its full guide. Or: shopping   Or: trainer alchemy" },
    { label = "Gold goal", key = "GOLDGOAL", helper = "GoldGoal", hint = "Gold and a name: 500 Bags   Or: clear" },
    { label = "Gold guide", key = "GOLDGUIDE", helper = "GoldGuide", hint = "Type a number to pin that farm. Or: all   Or: tips" },
    { label = "Dungeons", key = "DUNGEONS", helper = "Dungeons", hint = "Type a number or name for details. Or: pin 2   Or: all" },
    { label = "Quests", key = "QUESTCHECK", helper = "QuestCheck" },
    { label = "Zone", key = "ZONELEVELS", helper = "ZoneLevels" },
    { label = "Quest mobs", key = "QUESTMOBS", helper = "QuestMobs", hint = "Type: off   Or: on   Or: size large" },
    { label = "Auto quest", key = "AUTOQUEST", helper = "AutoQuest",
        hint = "Type: accept off   Or: handin off   Or: gray on   Or: pause ctrl   Or: ignore   Or: unignore 1" },
    { label = "Bag advice", key = "ITEMADVISOR", helper = "ItemAdvisor", hint = "To change what stats to favor, type: role healer" },
    { label = "Bag space", key = "BAGCHECK", helper = "BagCheck" },
    { label = "Find an item", key = "ITEMFINDER", helper = "ItemFinder", hint = "Type part of an item name and press Enter", emptyHint = "Search your bags, bank, and gear on every character.", search = true },
    { label = "Food and drink", key = "FOODCHECK", helper = "FoodCheck" },
    { label = "Supplies", key = "SUPPLYWATCH", helper = "SupplyWatch", hint = "Item in your bags and how many: Water 20   Or: remove 1   Or: ammo 400", supplies = true },
    { label = "Repairs", key = "DURABILITYWATCH", helper = "DurabilityWatch" },
    { label = "Tooltips", key = "TOOLTIPS", helper = "Tooltips", hint = "Type: off vendor   Or: on id   Or: on npc" },
    { label = "Window badges", key = "WINDOWBADGES", helper = "WindowBadges", hint = "Type: off reward   Or: on merchant   Or: off trainer" },
    { label = "Builds", key = "BUILDS", helper = "Builds", hint = "Goal: leveling, pvp, tank, healer, dps   Or: all   Or: a class name like mage" },
    { label = "Talents", key = "TALENTNUDGE", helper = "TalentNudge" },
    { label = "Trainer", key = "TRAINERNOTES", helper = "TrainerNotes" },
    { label = "Weapon skills", key = "WEAPONSKILLWATCH", helper = "WeaponSkillWatch", arg = "all" },
    { label = "Rested XP", key = "RESTGUARD", helper = "RestGuard" },
    { label = "Reputation", key = "REPWATCH", helper = "RepWatch", arg = "all" },
    { label = "Level log", key = "LEVELLOG", helper = "LevelLog", arg = "all" },
    -- Not READYCHECK: that is Blizzard's own /readycheck command, which the hub must never wrap.
    { label = "Ready check", key = "SPELLREADY", helper = "SpellReady", hint = "Type: ignore Frostbolt   Or: unignore Frostbolt   Or: ignored" },
    { label = "Places", key = "LANDMARKS", helper = "Landmarks", hint = "Type a kind to pin the nearest on your map: repair, vendor, food, inn, flight, mail, bank, trainer" },
    { label = "Deaths", key = "DEATHNOTES", helper = "DeathNotes", hint = "Type a number to pin that death on your map. Or: forget 2   Or: forget all" },
    -- "Rares" exactly: RareWatch's side panel line opens this page by that name.
    { label = "Rares", key = "RAREWATCH", helper = "RareWatch", hint = "Type a number to pin that rare on your map. Or: all   Or: forget all" },
    { label = "Map pins", key = "MAPPINS", helper = "MapPins", hint = "Type: off deaths   Or: on farms   Or: minimap off" },
    { label = "Characters", key = "FOREVERHELPER", helper = "ForeverHelper", arg = "chars", hint = "To-do: add Buy bags   Or: remove 1   Or: reset   Or: window" },
    { label = "Pop-up history", alerts = true, section = "hub", about = "Every pop-up from this session, newest first." },
    { label = "Errors", key = "ERRORLOG", helper = "ErrorLog", hint = "Type a number for details, or: clear" },
}
local PAGE_BY_KEY, PAGE_BY_LABEL = {}, {}
local PAGES_BY_HELPER, TABS_BY_SECTION = {}, {}
for _, tab in ipairs(TABS) do
    PAGE_BY_LABEL[tab.label] = tab
    if tab.key then
        PAGE_BY_KEY[tab.key] = tab
    end
    local helper = tab.helper and HELPER_BY_NAME[tab.helper]
    if helper then
        tab.section = helper.section
        tab.about = tab.about or helper.about
        PAGES_BY_HELPER[helper.name] = PAGES_BY_HELPER[helper.name] or {}
        table.insert(PAGES_BY_HELPER[helper.name], tab)
    end
    if tab.section then
        TABS_BY_SECTION[tab.section] = TABS_BY_SECTION[tab.section] or {}
        table.insert(TABS_BY_SECTION[tab.section], tab)
    end
end

local db, frame, body, scroll, content, inputBox, hintText, panel
local navContent
local sectionHeaders = {}
local manageFrame, manageHeight
local manageSections, manageRows = {}, {}
local reloadButton, reloadConfirmUntil
-- What you asked an addon to be after the next reload, for clients that can't tell us.
local addonWanted = {}
local ownTip
-- Defined further down; the Manage page's buttons need them.
local SelectTab, LayoutSidebar
local statLines, rows = {}, {}
local currentTab, renderedTab
local originals = {}
local alerts = {}
local toasts = {}
local capture
local lastShown = {}
local rowsDirty = true
local session = {}
local XP_WINDOW_SECONDS = 900
-- A rate from the first kill or two swings wildly; wait this long before guessing the time to level.
local XP_WARMUP_SECONDS = 120
-- XP samples kept across a /reload; the 15-minute window rarely holds more than this.
local MAX_SAVED_SAMPLES = 200
-- One early sale or purchase would otherwise read as a huge hourly rate.
local GOLD_RATE_MIN_SECONDS = 600
local xpSamples = {}
local toastSerial = 0
local opening
-- True for the early pass at login, when helpers that load after the hub haven't set up yet.
local quietStatus
local wrappers = {}

local function Safe(value)
    if issecretvalue and issecretvalue(value) then
        return nil
    end
    return value
end

local function FormatGold(copper)
    local gold, silver = math.floor(copper / 10000), math.floor(copper / 100) % 100
    if gold > 0 then
        return string.format("%dg %ds", gold, silver)
    elseif silver > 0 then
        return string.format("%ds %dc", silver, copper % 100)
    end
    return string.format("%dc", copper % 100)
end

local function FormatDuration(seconds)
    local minutes = math.floor(seconds / 60)
    if minutes >= 60 then
        return string.format("%dh %dm", math.floor(minutes / 60), minutes % 60)
    end
    return string.format("%dm", math.max(minutes, 1))
end

local function SetDarkBackdrop(target, alpha)
    target:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 14,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    target:SetBackdropColor(0.04, 0.04, 0.07, alpha)
    target:SetBackdropBorderColor(0.5, 0.5, 0.55, 0.9)
end

-- The hub's own tooltip, so nothing is ever written into Blizzard's shared GameTooltip.
local function Tip()
    if not ownTip then
        ownTip = CreateFrame("GameTooltip", "ForeverHubTooltip", UIParent, "GameTooltipTemplate")
    end
    return ownTip
end

local function HideTip()
    if ownTip then
        ownTip:Hide()
    end
end

-- True when you switched this helper Off on the Manage page. Helpers may ask this themselves;
-- the hub already hides an Off helper's pages, side panel lines and pop-ups for them.
function ForeverHub_IsOff(name)
    -- Before login the saved settings may not be read yet; db is set at login.
    local saved = db or ForeverHubDB
    return type(saved) == "table" and type(saved.off) == "table" and saved.off[name] == true
end

-- Pop-ups name their sender; a few helpers use a friendlier name than their own.
local function SourceIsOff(source)
    local helper = HELPER_BY_SOURCE[source]
    return helper ~= nil and ForeverHub_IsOff(helper.name)
end

local function TabVisible(tab)
    return not (tab.helper and ForeverHub_IsOff(tab.helper))
end

-- Runs an addon's command and returns the lines it wanted to show.
local function RunCommand(key, arg)
    local handler = originals[key] or SlashCmdList[key]
    if not handler then
        return { "|cff999999This addon isn't turned on.|r" }
    end
    local lines = {}
    capture = lines
    local ok, err = pcall(handler, arg or "")
    capture = nil
    if not ok then
        lines[#lines + 1] = "|cffff6666Something went wrong here. It's saved on the Errors page.|r"
        geterrorhandler()(err)
    end
    return lines
end

-- keepScroll leaves the page where you were reading; otherwise a new page starts at the top.
local function SetBody(text, keepScroll)
    local oldPosition = keepScroll and Safe(scroll:GetVerticalScroll()) or 0
    local oldHeight = keepScroll and Safe(content:GetHeight()) or 0
    body:SetText(text)
    local newHeight = math.max((Safe(body:GetStringHeight()) or 0) + 8, 1)
    content:SetHeight(newHeight)
    local position = 0
    if keepScroll and oldPosition > 0 then
        -- Newest lines are added on top, so move down by what was added to keep the same lines in view.
        position = oldPosition + math.max(newHeight - oldHeight, 0)
        local view = Safe(scroll:GetHeight())
        if view then
            position = math.min(position, math.max(newHeight - view, 0))
        end
    end
    scroll:SetVerticalScroll(position)
end

local function AlertsText()
    if #alerts == 0 then
        return "No pop-ups yet this session."
    end
    local parts = {}
    local now = GetTime()
    for index = #alerts, 1, -1 do
        local alert = alerts[index]
        local line = "|cff999999" .. alert.source .. ":|r " .. alert.text
        if alert.count > 1 then
            line = line .. string.format("  |cff999999(%d times)|r", alert.count)
        end
        local age = now - alert.time
        parts[#parts + 1] = line .. "  |cff666666" .. (age < 60 and "just now" or FormatDuration(age) .. " ago") .. "|r"
    end
    return table.concat(parts, "\n")
end

-- Where to look for a helper: its pages in this window, or wherever else it shows things.
local function HelperWhere(helper)
    local pages = PAGES_BY_HELPER[helper.name]
    if pages then
        local labels = {}
        for _, tab in ipairs(pages) do
            labels[#labels + 1] = tab.label
        end
        return "Page: " .. table.concat(labels, ", ")
    end
    return "Shows in " .. (helper.where or "pop-ups")
end

local function HomeText()
    local lines = {
        GOLD .. "How to use the hub|r",
        "Click a page on the left. When a page has a box at the top, type in it and press Enter.",
        "Minimap button: left-click shows or hides the side panel, right-click opens or closes this window. "
            .. "The side panel lists only what needs doing; click a line to open its page.",
        "Keys for this window, the Places page and the nearest repair, inn or flight master can be set in the game's "
            .. "Key Bindings, under AddOns. The game's AddOns menu by the minimap and its Options window (AddOns) list Forever Hub too.",
    }
    for _, section in ipairs(SECTIONS) do
        lines[#lines + 1] = ""
        lines[#lines + 1] = GOLD .. section.title .. "|r"
        if section.core then
            lines[#lines + 1] = "|cffffffffForever Hub|r  This window, the side panel and the pop-ups.  " .. GRAY .. "Page: Pop-up history|r"
        end
        for _, helper in ipairs(HELPERS) do
            if helper.section == section.key then
                local off = ForeverHub_IsOff(helper.name) and ("  " .. RED .. "(switched off)|r") or ""
                lines[#lines + 1] = string.format("|cffffffff%s|r  %s  %s%s|r%s", helper.name, helper.about, GRAY, HelperWhere(helper), off)
            end
        end
    end
    lines[#lines + 1] = ""
    lines[#lines + 1] = GRAY .. "To switch a helper off or on, use the Manage page.|r"
    return table.concat(lines, "\n")
end

local function ManageIntro()
    return table.concat({
        "Switch a helper " .. GOLD .. "Off|r to hide its pages, its side panel lines and its pop-ups. It keeps running quietly; switch it On again any time.",
        "To stop a whole addon from loading, use the button next to its group, then reload.",
        "Sound and taskbar flash for important pop-ups are under " .. GOLD .. "Alerts|r at the bottom.",
    }, "\n")
end

--------------------------------------------------------------------------------------------------
-- Manage page: a list of real buttons under the page text.
--------------------------------------------------------------------------------------------------

-- Any C_AddOns call goes through here: a missing function or an odd answer leaves the page usable.
local function AddOnCall(name, ...)
    local fn = C_AddOns and C_AddOns[name]
    if type(fn) ~= "function" then
        return nil
    end
    local ok, first, second = pcall(fn, ...)
    if ok then
        return Safe(first), Safe(second)
    end
    return nil
end

local function CanSwitchAddOns()
    return C_AddOns ~= nil and type(C_AddOns.EnableAddOn) == "function" and type(C_AddOns.DisableAddOn) == "function"
end

local function CharacterName()
    return UnitName and Safe(UnitName("player")) or nil
end

-- nil when this client can't tell; otherwise what is loaded now and what will load after a reload.
local function AddOnState(addon)
    if not (C_AddOns and type(C_AddOns.IsAddOnLoaded) == "function") then
        return nil
    end
    local state = { exists = true }
    if type(C_AddOns.DoesAddOnExist) == "function" then
        state.exists = AddOnCall("DoesAddOnExist", addon) ~= false
    end
    state.loaded = AddOnCall("IsAddOnLoaded", addon) and true or false
    local character = CharacterName()
    local enableState
    if character then
        enableState = AddOnCall("GetAddOnEnableState", addon, character)
    else
        enableState = AddOnCall("GetAddOnEnableState", addon)
    end
    if type(enableState) == "number" then
        state.enabled = enableState > 0
    elseif addonWanted[addon] ~= nil then
        state.enabled = addonWanted[addon]
    else
        state.enabled = state.loaded
    end
    return state
end

local function AddOnStatusText(section, state)
    if not state.exists then
        return GRAY .. "Not installed|r"
    elseif state.loaded and state.enabled then
        return GREEN .. "Loaded|r"
    elseif state.loaded then
        return ORANGE .. "Loaded now; off after you reload|r"
    elseif state.enabled then
        return ORANGE .. "Not loaded; turns on after you reload|r"
    end
    return GRAY .. "Turned off|r"
end

local function ToggleAddOn(section)
    local state = AddOnState(section.addon)
    if section.core or not state or not CanSwitchAddOns() then
        return
    end
    local character = CharacterName()
    local action = state.enabled and "DisableAddOn" or "EnableAddOn"
    if character then
        AddOnCall(action, section.addon, character)
    else
        AddOnCall(action, section.addon)
    end
    addonWanted[section.addon] = not state.enabled
end

local function SetReloadText()
    if reloadButton then
        reloadButton:SetText(reloadConfirmUntil and "Click again to reload" or "Reload now")
    end
end

-- Reloading closes every window for a moment, so it takes a second click within a few seconds.
local function ReloadClicked()
    local now = GetTime()
    if reloadConfirmUntil and now <= reloadConfirmUntil then
        reloadConfirmUntil = nil
        SetReloadText()
        ReloadUI()
        return
    end
    reloadConfirmUntil = now + RELOAD_CONFIRM_SECONDS
    SetReloadText()
    C_Timer.After(RELOAD_CONFIRM_SECONDS, function()
        if reloadConfirmUntil and GetTime() >= reloadConfirmUntil then
            reloadConfirmUntil = nil
            SetReloadText()
        end
    end)
end

local function ShowButtonTip(owner, title, text)
    local tip = Tip()
    tip:SetOwner(owner, "ANCHOR_RIGHT")
    tip:SetText(title)
    tip:AddLine(text, 1, 1, 1, true)
    tip:Show()
end

local function RefreshManage()
    if not manageFrame then
        return
    end
    reloadButton:SetShown(ReloadUI ~= nil)
    SetReloadText()
    local canSwitch = CanSwitchAddOns()
    for _, header in ipairs(manageSections) do
        local section = header.section
        local state = AddOnState(section.addon)
        if state then
            header.status:SetText(AddOnStatusText(section, state) .. (section.core and ("  " .. GRAY .. "(the hub itself, always on)|r") or ""))
        else
            header.status:SetText("")
        end
        local showToggle = state ~= nil and canSwitch and not section.core and state.exists
        header.toggle:SetShown(showToggle)
        if showToggle then
            header.toggle:SetText(state.enabled and "Turn off whole addon (after reload)" or "Turn on whole addon (after reload)")
        end
    end
    for _, row in ipairs(manageRows) do
        local helper = row.helper
        local off = ForeverHub_IsOff(helper.name)
        row.name:SetText((off and GRAY or "|cffffffff") .. helper.name .. "|r")
        if helper.noSwitch then
            row.switch:Hide()
            row.note:SetText(GRAY .. helper.noSwitch .. "|r")
            row.note:Show()
        else
            row.note:Hide()
            row.switch:SetText(off and (GRAY .. "Off|r") or (GREEN .. "On|r"))
            row.switch:Show()
        end
        row.open:SetShown(PAGES_BY_HELPER[helper.name] ~= nil and not off)
    end
    if extras.RefreshManageAlerts then
        extras.RefreshManageAlerts()
    end
end

local function SetHelperOff(helper, off)
    db.off = db.off or {}
    db.off[helper.name] = off or nil
    rowsDirty = true
    LayoutSidebar()
    RefreshManage()
    -- The Settings panel shows the same switches.
    if extras.OnHelperSwitched then
        extras.OnHelperSwitched()
    end
end

-- Built once, the first time the Manage page opens; RefreshManage keeps it up to date.
local function BuildManage()
    manageFrame = CreateFrame("Frame", nil, content)
    manageFrame:SetWidth(PAGE_WIDTH)
    local y = 0

    reloadButton = CreateFrame("Button", nil, manageFrame, "UIPanelButtonTemplate")
    reloadButton:SetSize(170, 22)
    reloadButton:SetPoint("TOPLEFT", manageFrame, "TOPLEFT", 0, y)
    reloadButton:SetScript("OnClick", ReloadClicked)
    reloadButton:SetScript("OnEnter", function(self)
        ShowButtonTip(self, "Reload now", "Reloads the game's interface so addon changes take effect. Click twice.")
    end)
    reloadButton:SetScript("OnLeave", HideTip)
    y = y - 32

    for _, section in ipairs(SECTIONS) do
        local header = { section = section }
        header.title = manageFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        header.title:SetPoint("TOPLEFT", manageFrame, "TOPLEFT", 0, y - 4)
        header.title:SetText(section.title .. "  " .. GRAY .. "(" .. section.addon .. ")|r")
        header.status = manageFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        header.status:SetPoint("TOPLEFT", manageFrame, "TOPLEFT", 0, y - 24)
        header.status:SetJustifyH("LEFT")
        header.toggle = CreateFrame("Button", nil, manageFrame, "UIPanelButtonTemplate")
        header.toggle:SetSize(230, 20)
        header.toggle:SetPoint("TOPRIGHT", manageFrame, "TOPRIGHT", 0, y - 2)
        header.toggle:SetScript("OnClick", function()
            ToggleAddOn(section)
            RefreshManage()
        end)
        header.toggle:SetScript("OnEnter", function(self)
            ShowButtonTip(self, section.addon, "Stops or starts this whole addon for this character. Takes effect after you reload.")
        end)
        header.toggle:SetScript("OnLeave", HideTip)
        manageSections[#manageSections + 1] = header
        y = y - MANAGE_HEADER_HEIGHT

        for _, helper in ipairs(HELPERS) do
            if helper.section == section.key then
                local row = { helper = helper }
                row.name = manageFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
                row.name:SetPoint("TOPLEFT", manageFrame, "TOPLEFT", 12, y)
                row.about = manageFrame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
                row.about:SetPoint("TOPLEFT", manageFrame, "TOPLEFT", 12, y - 15)
                row.about:SetPoint("RIGHT", manageFrame, "RIGHT", -130, 0)
                row.about:SetJustifyH("LEFT")
                row.about:SetWordWrap(false)
                row.about:SetText(helper.about)

                row.switch = CreateFrame("Button", nil, manageFrame, "UIPanelButtonTemplate")
                row.switch:SetSize(56, 20)
                row.switch:SetPoint("TOPRIGHT", manageFrame, "TOPRIGHT", -66, y - 4)
                row.switch:SetScript("OnClick", function()
                    SetHelperOff(helper, not ForeverHub_IsOff(helper.name))
                end)
                row.switch:SetScript("OnEnter", function(self)
                    ShowButtonTip(self, helper.name, helper.about .. "\n\nOff hides its pages, side panel lines and pop-ups.")
                end)
                row.switch:SetScript("OnLeave", HideTip)
                row.note = manageFrame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
                row.note:SetPoint("TOPRIGHT", manageFrame, "TOPRIGHT", -66, y - 8)

                row.open = CreateFrame("Button", nil, manageFrame, "UIPanelButtonTemplate")
                row.open:SetSize(56, 20)
                row.open:SetPoint("TOPRIGHT", manageFrame, "TOPRIGHT", 0, y - 4)
                row.open:SetText("Open")
                row.open:SetScript("OnClick", function()
                    local pages = PAGES_BY_HELPER[helper.name]
                    if pages then
                        SelectTab(pages[1])
                    end
                end)
                manageRows[#manageRows + 1] = row
                y = y - MANAGE_ROW_HEIGHT
            end
        end
        y = y - 6
    end
    -- The Alerts switches (sound, flash) live in ForeverHubExtras.lua.
    if extras.BuildManageAlerts then
        y = extras.BuildManageAlerts(manageFrame, y) or y
    end
    manageHeight = -y
    manageFrame:SetHeight(manageHeight)
end

-- The list sits under the page text, inside the same scrolling area.
local function ShowManage(show)
    if not show then
        if manageFrame then
            manageFrame:Hide()
        end
        return
    end
    if not manageFrame then
        BuildManage()
    end
    RefreshManage()
    local textHeight = (Safe(body:GetStringHeight()) or 0) + 12
    manageFrame:ClearAllPoints()
    manageFrame:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -textHeight)
    manageFrame:Show()
    content:SetHeight(textHeight + manageHeight)
end

local function RenderPage(prefixLines)
    local tab = currentTab
    -- A new pop-up redraws the history page while you may be scrolled down in it; stay put then.
    -- Choosing a page or opening the window clears renderedTab, so those still start at the top.
    local keepScroll = tab.alerts and renderedTab == tab
    renderedTab = tab
    local text
    if tab.home then
        text = HomeText()
    elseif tab.manage then
        text = ManageIntro()
    elseif tab.alerts then
        text = AlertsText()
    elseif tab.search then
        text = tab.emptyHint
    else
        text = table.concat(RunCommand(tab.key, tab.arg), "\n")
    end
    if text == "" then
        text = "|cff999999Nothing to show right now.|r"
    end
    if prefixLines and #prefixLines > 0 then
        text = table.concat(prefixLines, "\n") .. "\n\n" .. text
    end
    SetBody(text, keepScroll)
    ShowManage(tab.manage)
end

SelectTab = function(tab, prefixLines)
    currentTab = tab
    renderedTab = nil
    for _, candidate in ipairs(TABS) do
        if candidate.button then
            if candidate == tab then
                candidate.button:LockHighlight()
            else
                candidate.button:UnlockHighlight()
            end
        end
    end
    local hasInput = tab.hint ~= nil
    hintText:SetShown(hasInput)
    inputBox:SetShown(hasInput)
    hintText:SetText(tab.hint or "")
    inputBox:SetText("")
    inputBox:ClearFocus()
    scroll:ClearAllPoints()
    scroll:SetPoint("TOPLEFT", frame, "TOPLEFT", PAGE_LEFT, hasInput and -84 or -36)
    scroll:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -34, 14)
    -- A hidden window fills in when it opens. At login, other addons may not have started yet.
    if frame:IsShown() then
        RenderPage(prefixLines)
    end
end

-- Finds an item link in your bags from part of its name, so no one needs to shift-click into chat.
local function FindBagLink(text)
    local needle = text:lower()
    local partial
    for bag = 0, (NUM_TOTAL_EQUIPPED_BAG_SLOTS or NUM_BAG_SLOTS or 4) do
        for slot = 1, Safe(C_Container.GetContainerNumSlots(bag)) or 0 do
            local info = C_Container.GetContainerItemInfo(bag, slot)
            local link = info and Safe(info.hyperlink)
            local name = link and link:match("%[(.-)%]")
            local lower = name and name:lower()
            -- A full name wins, so "Water" isn't taken as "Watermelon" just because it comes first.
            if lower == needle then
                return link
            elseif lower and not partial and lower:find(needle, 1, true) then
                partial = link
            end
        end
    end
    return partial
end

local function SupplyCommand(text)
    local lower = text:lower()
    if lower:match("^remove%s") or lower:match("^ammo%s") then
        return text
    end
    local name, amount = text:match("^(.-)%s+(%d+)$")
    if not name then
        return nil, "Type an item name and an amount, such as: Water 20"
    end
    local link = FindBagLink(name)
    if not link then
        return nil, "Couldn't find \"" .. name .. "\" in your bags."
    end
    return "add " .. link .. " " .. amount
end

local function SubmitInput(text)
    text = text:match("^%s*(.-)%s*$")
    if text == "" or not currentTab or not currentTab.key then
        return
    end
    inputBox:SetText("")
    if currentTab.search then
        local lines = RunCommand(currentTab.key, text)
        -- A blank page would look like the search never ran.
        if #lines == 0 then
            lines = { "|cff999999Nothing found for \"" .. text .. "\".|r" }
        end
        SetBody(table.concat(lines, "\n"))
        return
    end
    local command, problem = text, nil
    if currentTab.supplies then
        command, problem = SupplyCommand(text)
    end
    if not command then
        RenderPage({ "|cffffaa66" .. problem .. "|r" })
        return
    end
    RenderPage(RunCommand(currentTab.key, command))
    rowsDirty = true
end

local function MakeDraggable(target, key)
    target:SetClampedToScreen(true)
    target:SetMovable(true)
    target:EnableMouse(true)
    target:RegisterForDrag("LeftButton")
    target:SetScript("OnDragStart", target.StartMoving)
    target:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local point, _, relativePoint, x, y = self:GetPoint()
        db[key] = { point, relativePoint, x, y }
    end)
end

--------------------------------------------------------------------------------------------------
-- Sidebar: Home and Manage, then one foldable group per addon. It scrolls when it's taller than
-- the window, so folding is a convenience, never a must.
--------------------------------------------------------------------------------------------------

local function SectionCollapsed(section)
    return db.collapsed ~= nil and db.collapsed[section.key] == true
end

local function NavButton(text, indent, isHeader)
    local button = CreateFrame("Button", nil, navContent)
    button:SetSize(NAV_WIDTH, isHeader and HEADER_HEIGHT or NAV_HEIGHT)
    -- Gold headers, white pages; each lights up the other way under the mouse.
    button:SetNormalFontObject(isHeader and GameFontNormalSmall or GameFontHighlightSmall)
    button:SetHighlightFontObject(isHeader and GameFontHighlightSmall or GameFontNormalSmall)
    button:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
    button:SetText(text)
    local label = button:GetFontString()
    if label then
        label:ClearAllPoints()
        label:SetPoint("LEFT", button, "LEFT", indent, 0)
    end
    button:SetScript("OnLeave", HideTip)
    return button
end

local function HeaderText(section)
    if SectionCollapsed(section) then
        return string.format("+ %s  %s(%d)|r", section.title, GRAY, #(TABS_BY_SECTION[section.key] or {}))
    end
    return "- " .. section.title
end

-- Places every visible button from the top down. Runs again whenever a group folds or a helper is switched.
LayoutSidebar = function()
    if not navContent then
        return
    end
    local y = 0
    local function Place(button, height)
        button:ClearAllPoints()
        button:SetPoint("TOPLEFT", navContent, "TOPLEFT", 0, -y)
        button:Show()
        y = y + height
    end
    for _, tab in ipairs(TABS) do
        if not tab.section then
            Place(tab.button, NAV_HEIGHT)
        end
    end
    for _, section in ipairs(SECTIONS) do
        local header = sectionHeaders[section.key]
        y = y + HEADER_GAP
        header:SetText(HeaderText(section))
        Place(header, HEADER_HEIGHT)
        local collapsed = SectionCollapsed(section)
        for _, tab in ipairs(TABS_BY_SECTION[section.key] or {}) do
            if not collapsed and TabVisible(tab) then
                Place(tab.button, NAV_HEIGHT)
            else
                tab.button:Hide()
            end
        end
    end
    navContent:SetHeight(math.max(y, 1))
end

local function BuildSidebar()
    local navScroll = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
    navScroll:SetPoint("TOPLEFT", frame, "TOPLEFT", 8, -30)
    navScroll:SetPoint("BOTTOMRIGHT", frame, "BOTTOMLEFT", 8 + NAV_WIDTH, 12)
    navContent = CreateFrame("Frame", nil, navScroll)
    navContent:SetSize(NAV_WIDTH, 1)
    navScroll:SetScrollChild(navContent)

    for _, tab in ipairs(TABS) do
        local button = NavButton(tab.label, tab.section and 14 or 4, false)
        button:SetScript("OnClick", function()
            SelectTab(tab)
        end)
        button:SetScript("OnEnter", function(self)
            local tip = Tip()
            tip:SetOwner(self, "ANCHOR_RIGHT")
            tip:SetText(tab.label)
            if tab.about then
                tip:AddLine(tab.about, 1, 1, 1, true)
            end
            if tab.hint then
                tip:AddLine("This page has a box to type in.", 0.6, 0.6, 0.6, true)
            end
            tip:Show()
        end)
        tab.button = button
    end
    for _, section in ipairs(SECTIONS) do
        local header = NavButton(HeaderText(section), 4, true)
        header:SetScript("OnClick", function()
            db.collapsed = db.collapsed or {}
            db.collapsed[section.key] = (not SectionCollapsed(section)) or nil
            LayoutSidebar()
        end)
        header:SetScript("OnEnter", function(self)
            ShowButtonTip(self, section.title, "Click to fold or unfold this group. Its pages come from the " .. section.addon .. " addon.")
        end)
        sectionHeaders[section.key] = header
    end
    LayoutSidebar()
end

local function BuildWindow()
    -- Blizzard's own window frame, so it matches the rest of the game.
    frame = CreateFrame("Frame", "ForeverHubFrame", UIParent, "ButtonFrameTemplate")
    frame:SetSize(WIDTH, HEIGHT)
    if ButtonFrameTemplate_HidePortrait then
        ButtonFrameTemplate_HidePortrait(frame)
    end
    if ButtonFrameTemplate_HideAttic then
        ButtonFrameTemplate_HideAttic(frame)
    end
    if ButtonFrameTemplate_HideButtonBar then
        ButtonFrameTemplate_HideButtonBar(frame)
    end
    if frame.SetTitle then
        frame:SetTitle("Forever Hub")
    end
    frame:SetFrameStrata("HIGH")
    MakeDraggable(frame, "position")
    if db.position then
        local p = db.position
        frame:SetPoint(p[1], UIParent, p[2], p[3], p[4])
    else
        frame:SetPoint("CENTER", UIParent, "CENTER", 0, 40)
    end
    frame:Hide()
    table.insert(UISpecialFrames, "ForeverHubFrame")
    frame:SetScript("OnShow", function()
        -- OpenPage draws its own page right after, so drawing the old one first is wasted work.
        if currentTab and not opening then
            renderedTab = nil
            RenderPage()
        end
    end)

    BuildSidebar()

    hintText = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    hintText:SetPoint("TOPLEFT", frame, "TOPLEFT", PAGE_LEFT, -36)
    hintText:SetPoint("RIGHT", frame, "RIGHT", -14, 0)
    hintText:SetJustifyH("LEFT")

    inputBox = CreateFrame("EditBox", nil, frame, "BackdropTemplate")
    inputBox:SetPoint("TOPLEFT", frame, "TOPLEFT", PAGE_LEFT, -52)
    inputBox:SetPoint("RIGHT", frame, "RIGHT", -14, 0)
    inputBox:SetHeight(24)
    SetDarkBackdrop(inputBox, 1)
    inputBox:SetFontObject(GameFontHighlight)
    inputBox:SetTextInsets(8, 8, 0, 0)
    inputBox:SetAutoFocus(false)
    inputBox:SetScript("OnEnterPressed", function(self)
        SubmitInput(self:GetText())
    end)
    inputBox:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
    end)

    scroll = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
    content = CreateFrame("Frame", nil, scroll)
    content:SetSize(PAGE_WIDTH, 1)
    scroll:SetScrollChild(content)
    body = content:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    body:SetPoint("TOPLEFT", content, "TOPLEFT", 0, 0)
    body:SetWidth(PAGE_WIDTH)
    body:SetJustifyH("LEFT")
    body:SetJustifyV("TOP")
    body:SetWordWrap(true)
    body:SetSpacing(3)

    SelectTab(TABS[1])
end

local function OpenPage(tab, prefixLines)
    opening = true
    frame:Show()
    opening = false
    SelectTab(tab, prefixLines)
end

-- XP waiting in quests that are finished but not turned in yet. Read at most every few seconds,
-- since the panel refreshes more often than the quest log changes.
local QUEST_XP_SECONDS = 5
local questXP, questXPAt = 0, -QUEST_XP_SECONDS
local function FinishedQuestXP(now)
    if now - questXPAt < QUEST_XP_SECONDS then
        return questXP
    end
    questXPAt = now
    local total = 0
    if C_QuestLog and C_QuestLog.GetNumQuestLogEntries and C_QuestLog.GetInfo and C_QuestLog.IsComplete and GetQuestLogRewardXP then
        for index = 1, Safe(C_QuestLog.GetNumQuestLogEntries()) or 0 do
            local info = C_QuestLog.GetInfo(index)
            local questID = info and not Safe(info.isHeader) and Safe(info.questID)
            if questID and Safe(C_QuestLog.IsComplete(questID)) then
                total = total + (tonumber(Safe(GetQuestLogRewardXP(questID))) or 0)
            end
        end
    end
    questXP = total
    return total
end

-- The XP and gold session lives in saved data so a /reload keeps it; a real login starts a new one.
-- Who it belongs to, so another character never picks it up.
-- The shared Forever key (GUID, or full name + realm); nil when the name can't be read.
local function SessionOwner()
    local name = UnitName and Safe(UnitName("player"))
    local realm = GetRealmName and Safe(GetRealmName())
    if type(name) == "string" and type(realm) == "string" then
        return ForeverCharacterKey(), name .. "-" .. realm
    end
end

local function SaveSession()
    -- Not before the world has loaded: until then the saved session may still be needed by a /reload.
    if not (db and session.start and session.resolved) then
        return
    end
    local samples = {}
    for index = math.max(#xpSamples - MAX_SAVED_SAMPLES + 1, 1), #xpSamples do
        samples[#samples + 1] = { time = xpSamples[index].time, amount = xpSamples[index].amount }
    end
    db.session = {
        owner = SessionOwner(), loginStamp = session.loginStamp, start = session.start,
        money = session.money, moneySince = session.moneySince, samples = samples,
    }
end

local function NewSession()
    local now = GetTime()
    session.start = now
    -- When this login began, by the clock; the saved session is only trusted with the same stamp.
    session.loginStamp = (time and Safe(time())) or now
    session.money, session.moneySince = Safe(GetMoney()), now
    session.lastXP, session.lastMax = Safe(UnitXP("player")), Safe(UnitXPMax("player"))
    for index = #xpSamples, 1, -1 do
        xpSamples[index] = nil
    end
end

-- After a /reload: pick up the session saved before it. False when there's nothing usable.
local function RestoreSession()
    local saved = db and db.session
    local now = GetTime()
    -- A session saved by the previous version carries the old "Name-Realm" owner; it is still ours.
    local owner, oldOwner = SessionOwner()
    if type(saved) ~= "table" or owner == nil or (saved.owner ~= owner and saved.owner ~= oldOwner) or saved.loginStamp == nil then
        return false
    end
    local start = tonumber(saved.start)
    -- The game clock keeps counting through a /reload; a start "in the future" means it was restarted.
    if not start or start > now then
        return false
    end
    session.start, session.loginStamp = start, saved.loginStamp
    local money, since = tonumber(saved.money), tonumber(saved.moneySince)
    if money and since and since <= now then
        session.money, session.moneySince = money, since
    end
    for index = #xpSamples, 1, -1 do
        xpSamples[index] = nil
    end
    for _, sample in ipairs(type(saved.samples) == "table" and saved.samples or {}) do
        local at, amount = type(sample) == "table" and tonumber(sample.time), type(sample) == "table" and tonumber(sample.amount)
        if at and amount and amount > 0 and at <= now and #xpSamples < MAX_SAVED_SAMPLES then
            xpSamples[#xpSamples + 1] = { time = at, amount = amount }
        end
    end
    return true
end

-- Decided once per login, when the world first loads: keep the session after a /reload, else a new one.
local function ResolveSession(isInitialLogin, isReloadingUi)
    if session.resolved or not session.start then
        return
    end
    session.resolved = true
    if not (Safe(isReloadingUi) == true and Safe(isInitialLogin) ~= true and RestoreSession()) then
        NewSession()
    end
    SaveSession()
end

-- The always-on panel: your rates at the top, then only what needs doing.
local function RefreshStats()
    local now = GetTime()
    local elapsed = math.max(now - session.start, 60)
    while xpSamples[1] and now - xpSamples[1].time > XP_WINDOW_SECONDS do
        table.remove(xpSamples, 1)
    end
    local recentXP = 0
    for _, sample in ipairs(xpSamples) do
        recentXP = recentXP + sample.amount
    end
    local level = Safe(UnitLevel("player"))
    local xp, maxXP = Safe(UnitXP("player")), Safe(UnitXPMax("player"))
    if level and level < MAX_LEVEL and xp and maxXP and maxXP > 0 then
        local banked = FinishedQuestXP(now)
        statLines[1]:SetText(string.format("Level %d  |cffffd100%d%%|r%s", level, math.floor(xp * 100 / maxXP),
            banked > 0 and string.format("  |cff33ff33+%d%% to turn in|r", math.floor(banked * 100 / maxXP)) or ""))
        -- Recent play only, so a break or a long town visit doesn't drag the estimate out.
        local rate = recentXP * 3600 / math.min(elapsed, XP_WINDOW_SECONDS)
        -- XP already earned in finished quests doesn't need grinding; only the rest is timed.
        local toGo = maxXP - xp - banked
        if banked > 0 and toGo <= 0 then
            statLines[2]:SetText("|cff33ff33Turn in to level up|r")
        elseif rate <= 0 then
            statLines[2]:SetText("|cff999999Next level time appears once you earn XP|r")
        elseif now - session.start < XP_WARMUP_SECONDS then
            statLines[2]:SetText(string.format("|cff999999Next level time: warming up (%ds)|r",
                math.ceil(XP_WARMUP_SECONDS - (now - session.start))))
        else
            statLines[2]:SetText(string.format("Next level in %s", FormatDuration(toGo * 3600 / rate)))
        end
        local rested = Safe(GetXPExhaustion()) or 0
        statLines[3]:SetText(rested > 0 and string.format("Rested %d%% of this level", math.floor(rested * 100 / maxXP)) or "|cff999999Not rested|r")
    else
        statLines[1]:SetText(level and string.format("Level %d", level) or "")
        statLines[2]:SetText("")
        statLines[3]:SetText("")
    end
    local money = Safe(GetMoney())
    if money and not session.money then
        -- Gold was hidden at login; start counting from the first time it can be read.
        session.money, session.moneySince = money, now
    end
    if money then
        local earned = money - session.money
        local goldElapsed = now - session.moneySince
        if earned == 0 or goldElapsed < GOLD_RATE_MIN_SECONDS then
            statLines[4]:SetText(FormatGold(money))
        else
            local sign = earned > 0 and "+" or "-"
            statLines[4]:SetText(string.format("%s  |cff999999%s%s/hr|r", FormatGold(money), sign, FormatGold(math.floor(math.abs(earned) * 3600 / goldElapsed))))
        end
    else
        statLines[4]:SetText("")
    end
end

local function GatherStatus()
    local items = {}
    local buildsRow = false
    for _, name in ipairs(STATUS_ORDER) do
        -- A helper you switched off on the Manage page gets no lines here.
        local source = not ForeverHub_IsOff(name) and ForeverHubStatus and ForeverHubStatus[name]
        -- Builds' "take X next" row already covers unspent points, so TalentNudge's row would repeat it.
        if name == "TalentNudge" and buildsRow then
            source = nil
        end
        if source then
            local ok, result = pcall(source)
            if ok then
                -- A helper answering with something other than a list mustn't take the others down.
                for _, entry in ipairs(type(result) == "table" and result or {}) do
                    if type(entry) == "table" then
                        items[#items + 1] = entry
                        buildsRow = buildsRow or name == "Builds"
                    end
                end
            elseif not quietStatus then
                geterrorhandler()(result)
            end
        end
    end
    return items
end

local function GetRow(index)
    if rows[index] then
        return rows[index]
    end
    local row = CreateFrame("Button", nil, panel)
    row:SetSize(PANEL_WIDTH - 16, ROW_HEIGHT)
    row:SetNormalFontObject(GameFontHighlightSmall)
    row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
    row:SetScript("OnClick", function(self)
        local page = self.page and PAGE_BY_LABEL[self.page]
        if page then
            OpenPage(page)
        elseif self.extra then
            frame:Show()
        end
    end)
    row:SetScript("OnEnter", function(self)
        local tip = Tip()
        tip:SetOwner(self, "ANCHOR_RIGHT")
        if self.link then
            -- A malformed link from a helper shouldn't break the panel.
            if not pcall(tip.SetHyperlink, tip, self.link) then
                tip:Hide()
                return
            end
        elseif self.extra then
            for _, text in ipairs(self.extra) do
                tip:AddLine(text, 1, 1, 1)
            end
        else
            -- Long lines are cut off on the panel, so show the whole line on hover.
            local label = self:GetFontString()
            if not (label and label.IsTruncated and Safe(label:IsTruncated())) then
                tip:Hide()
                return
            end
            tip:AddLine(self.fullText, 1, 1, 1)
        end
        tip:Show()
    end)
    row:SetScript("OnLeave", HideTip)
    rows[index] = row
    return row
end

local function RefreshRows()
    local items = GatherStatus()
    if #items > MAX_ROWS then
        -- Say so rather than silently dropping what doesn't fit, and list them on hover.
        local extra = {}
        for index = MAX_ROWS, #items do
            extra[#extra + 1] = tostring(items[index].text)
        end
        items[MAX_ROWS] = { text = string.format("|cff999999%d more. Point here to see them.|r", #extra), extra = extra }
    end
    local shown = math.min(#items, MAX_ROWS)
    for index = 1, shown do
        local item = items[index]
        local row = GetRow(index)
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", panel, "TOPLEFT", 8, -70 - (index - 1) * ROW_HEIGHT)
        row:SetText(item.text)
        local label = row:GetFontString()
        if label then
            label:ClearAllPoints()
            label:SetPoint("LEFT", row, "LEFT", 2, 0)
            label:SetPoint("RIGHT", row, "RIGHT", -2, 0)
            label:SetJustifyH("LEFT")
            label:SetWordWrap(false)
        end
        row.page, row.link, row.extra, row.fullText = item.page, item.link, item.extra, item.text
        row:Show()
    end
    for index = shown + 1, #rows do
        rows[index]:Hide()
    end
    panel.empty:SetShown(shown == 0)
    panel:SetHeight(70 + math.max(shown, 1) * ROW_HEIGHT + 8)
end

local function BuildPanel()
    panel = CreateFrame("Frame", "ForeverHubPanel", UIParent, "BackdropTemplate")
    panel:SetWidth(PANEL_WIDTH)
    SetDarkBackdrop(panel, 0.72)
    MakeDraggable(panel, "panelPosition")
    -- Held by its top-left corner, so the top stays put as rows come and go.
    panel:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local left, top = self:GetLeft(), self:GetTop()
        if left and top then
            self:ClearAllPoints()
            self:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left, top)
            db.panelTopLeft = { left, top }
        end
    end)
    if db.panelTopLeft then
        panel:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", db.panelTopLeft[1], db.panelTopLeft[2])
    else
        panel:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 16, -220)
    end

    local details = CreateFrame("Button", nil, panel)
    details:SetSize(50, 16)
    details:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -24, -6)
    details:SetNormalFontObject(GameFontNormalSmall)
    details:SetHighlightFontObject(GameFontHighlightSmall)
    details:SetText("Details")
    details:SetScript("OnClick", function()
        frame:SetShown(not frame:IsShown())
    end)

    local close = CreateFrame("Button", nil, panel, "UIPanelCloseButton")
    close:SetSize(22, 22)
    close:SetPoint("TOPRIGHT", panel, "TOPRIGHT", 0, 0)

    for index = 1, 4 do
        local line = panel:CreateFontString(nil, "OVERLAY", index == 1 and "GameFontNormal" or "GameFontHighlightSmall")
        line:SetPoint("TOPLEFT", panel, "TOPLEFT", 10, index == 1 and -8 or (-12 - (index - 1) * 14))
        line:SetJustifyH("LEFT")
        statLines[index] = line
    end

    -- Next to the gold line: start the XP and gold rates over, say after a break.
    local restart = CreateFrame("Button", nil, panel)
    restart:SetSize(46, 14)
    restart:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -8, -52)
    restart:SetNormalFontObject(GameFontDisableSmall)
    restart:SetHighlightFontObject(GameFontHighlightSmall)
    restart:SetText("Restart")
    restart:SetScript("OnClick", function()
        NewSession()
        SaveSession()
        RefreshStats()
    end)
    restart:SetScript("OnEnter", function(self)
        ShowButtonTip(self, "Restart rates", "Start measuring XP and gold per hour from now, for example after a break.")
    end)
    restart:SetScript("OnLeave", HideTip)
    panel.restart = restart

    panel.empty = panel:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    panel.empty:SetPoint("TOPLEFT", panel, "TOPLEFT", 10, -74)
    panel.empty:SetText("All caught up.")
    panel:Hide()
end

local function PositionMinimapButton(button)
    local radians = math.rad(db.angle or DEFAULT_ANGLE)
    button:ClearAllPoints()
    button:SetPoint("CENTER", Minimap, "CENTER", math.cos(radians) * MINIMAP_RADIUS, math.sin(radians) * MINIMAP_RADIUS)
end

local function BuildMinimapButton()
    local button = CreateFrame("Button", "ForeverHubMinimapButton", Minimap)
    button:SetSize(32, 32)
    button:SetFrameStrata("MEDIUM")
    button:SetFrameLevel(8)
    local icon = button:CreateTexture(nil, "BACKGROUND")
    icon:SetSize(20, 20)
    icon:SetPoint("CENTER", button, "CENTER", 0, 0)
    icon:SetTexture("Interface\\Icons\\INV_Misc_Book_09")
    local border = button:CreateTexture(nil, "OVERLAY")
    border:SetSize(54, 54)
    border:SetPoint("TOPLEFT", button, "TOPLEFT", 0, 0)
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    button:RegisterForDrag("LeftButton")
    button:SetScript("OnClick", function(_, mouseButton)
        if mouseButton == "RightButton" then
            frame:SetShown(not frame:IsShown())
        else
            panel:SetShown(not panel:IsShown())
        end
    end)
    button:SetScript("OnDragStart", function(self)
        self:SetScript("OnUpdate", function()
            local x, y = GetCursorPosition()
            local scale = Minimap:GetEffectiveScale()
            local centerX, centerY = Minimap:GetCenter()
            db.angle = math.deg(math.atan2(y / scale - centerY, x / scale - centerX))
            PositionMinimapButton(self)
        end)
    end)
    button:SetScript("OnDragStop", function(self)
        self:SetScript("OnUpdate", nil)
    end)
    button:SetScript("OnEnter", function(self)
        local tip = Tip()
        tip:SetOwner(self, "ANCHOR_LEFT")
        tip:SetText("Forever Hub")
        tip:AddLine("Left-click: side panel. Right-click: hub window. Drag: move.", 1, 1, 1)
        tip:Show()
    end)
    button:SetScript("OnLeave", HideTip)
    PositionMinimapButton(button)
end

local function ArrangeToasts()
    local shown = {}
    for _, toast in ipairs(toasts) do
        if toast:IsShown() then
            shown[#shown + 1] = toast
        end
    end
    -- Oldest on top, so a new message doesn't move the one you're reading.
    table.sort(shown, function(a, b)
        return a.shownAt < b.shownAt
    end)
    -- Below the leveling guide, which sits at the top of the screen.
    local offset = 170
    for _, toast in ipairs(shown) do
        toast:ClearAllPoints()
        toast:SetPoint("TOP", UIParent, "TOP", 0, -offset)
        -- Stacked by real height, so a two-line message doesn't cover the next one.
        offset = offset + (Safe(toast:GetHeight()) or 44) + 8
    end
end

local function GetToast()
    for _, toast in ipairs(toasts) do
        if not toast:IsShown() then
            return toast
        end
    end
    if #toasts >= MAX_TOASTS then
        -- All full, so the oldest one makes room.
        local oldest = toasts[1]
        for _, toast in ipairs(toasts) do
            if toast.shownAt < oldest.shownAt then
                oldest = toast
            end
        end
        return oldest
    end
    local toast = CreateFrame("Button", nil, UIParent, "BackdropTemplate")
    toast:SetSize(TOAST_WIDTH, 44)
    SetDarkBackdrop(toast, 0.85)
    toast:SetFrameStrata("MEDIUM")
    toast.message = toast:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    toast.message:SetPoint("TOPLEFT", toast, "TOPLEFT", 10, -10)
    toast.message:SetPoint("RIGHT", toast, "RIGHT", -10, 0)
    toast.message:SetJustifyH("LEFT")
    toast:SetScript("OnClick", function(self)
        self:Hide()
        ArrangeToasts()
    end)
    toasts[#toasts + 1] = toast
    return toast
end

local function ShowToast(text)
    local toast = GetToast()
    -- A counter, not the clock: several messages in one frame share a time, and the
    -- older timer would then hide the newer message early.
    toastSerial = toastSerial + 1
    local stamp = toastSerial
    toast.shownAt = stamp
    toast.message:SetText(text)
    toast:SetHeight(math.max((Safe(toast.message:GetStringHeight()) or 16) + 20, 36))
    toast:Show()
    ArrangeToasts()
    C_Timer.After(TOAST_SECONDS, function()
        -- A newer message may have reused this pop-up, and that one keeps its full time.
        if toast.shownAt == stamp then
            toast:Hide()
            ArrangeToasts()
        end
    end)
end

-- Every helper addon sends its messages here instead of to chat.
function ForeverHub_Receive(source, text)
    -- A helper may pass on something it read from the game; never let that break the hub.
    text, source = Safe(text), Safe(source)
    if text == nil then
        return
    end
    text, source = tostring(text), tostring(source or "")
    if capture then
        capture[#capture + 1] = text
        return
    end
    -- Switched off on the Manage page: no pop-up and nothing in the history.
    if SourceIsOff(source) then
        return
    end
    rowsDirty = true
    local now = GetTime()
    local last = alerts[#alerts]
    if last and last.source == source and last.text == text then
        -- Repeats are counted, so the history isn't one message over and over.
        last.count, last.time = last.count + 1, now
    else
        alerts[#alerts + 1] = { source = source, text = text, time = now, count = 1 }
        if #alerts > MAX_ALERTS then
            table.remove(alerts, 1)
        end
    end
    if frame and frame:IsShown() and currentTab and currentTab.alerts then
        RenderPage()
    end
    if lastShown[text] and now - lastShown[text] < REPEAT_SECONDS then
        return
    end
    -- Old entries are of no use once they can't suppress a repeat any more.
    for key, when in pairs(lastShown) do
        if now - when >= REPEAT_SECONDS then
            lastShown[key] = nil
        end
    end
    lastShown[text] = now
    if frame then
        ShowToast(text)
    end
    -- Sound and taskbar flash for the few pop-ups that matter (ForeverHubExtras.lua decides which).
    if extras.OnPopup then
        local ok, err = pcall(extras.OnPopup, source, text)
        if not ok then
            geterrorhandler()(err)
        end
    end
end

-- Anyone who still types a command gets the window instead of chat lines. Safe to run again: commands
-- already wrapped are skipped, and ones a helper registered (or replaced) since then get wrapped.
local function WrapCommands()
    for key, tab in pairs(PAGE_BY_KEY) do
        local handler = SlashCmdList[key]
        if handler and handler ~= wrappers[key] then
            originals[key] = handler
            wrappers[key] = function(message)
                local arg = message and message:match("^%s*(.-)%s*$") or ""
                OpenPage(tab, arg ~= "" and RunCommand(key, arg) or nil)
            end
            SlashCmdList[key] = wrappers[key]
        end
    end
end

local function TrackXP()
    local xp, maxXP = Safe(UnitXP("player")), Safe(UnitXPMax("player"))
    if not (xp and maxXP) then
        return
    end
    local gained = 0
    if session.lastXP then
        if xp >= session.lastXP then
            gained = xp - session.lastXP
        elseif session.lastMax then
            gained = session.lastMax - session.lastXP + xp
        end
    end
    if gained > 0 then
        xpSamples[#xpSamples + 1] = { time = GetTime(), amount = gained }
    end
    session.lastXP, session.lastMax = xp, maxXP
    if gained > 0 then
        SaveSession()
    end
end

local function Attempt(step)
    local ok, err = pcall(step)
    if not ok then
        geterrorhandler()(err)
    end
end

-- Some lines change with no event the hub hears (walking away from a death spot, a rare leaving the
-- minimap, a buff running out, a talent point spent), so the lines are also read again every few seconds.
local ROWS_REFRESH_SECONDS = 5
local rowsAt

local function OnTick()
    Attempt(RefreshStats)
    local now = GetTime()
    local due = rowsDirty or not rowsAt or now - rowsAt >= ROWS_REFRESH_SECONDS
    if due and panel and panel:IsShown() and not (InCombatLockdown and InCombatLockdown()) then
        rowsDirty = false
        rowsAt = now
        Attempt(RefreshRows)
    end
end

-- You asked for the screen narration voice to stay off; this also keeps it off at the login screen.
-- Game settings are only changed out of combat (a /reload in combat waits for it to end), since the
-- game can refuse some of them to addons while it is locked down.
local narrationPending = false
local function NarrationOff()
    if InCombatLockdown and InCombatLockdown() then
        narrationPending = true
        return
    end
    narrationPending = false
    if C_CVar and C_CVar.SetCVar then
        pcall(C_CVar.SetCVar, "accessibilityScreenNarrationEnabled", "0")
    end
end

local function Start()
    ForeverHubDB = ForeverHubDB or {}
    db = ForeverHubDB
    NarrationOff()
    -- A fresh session for now; the first PLAYER_ENTERING_WORLD swaps in the saved one after a /reload.
    NewSession()
    -- Each step runs on its own, so a problem with one still leaves the rest usable.
    Attempt(BuildWindow)
    Attempt(BuildPanel)
    Attempt(BuildMinimapButton)
    Attempt(WrapCommands)
    Attempt(function()
        panel:Show()
    end)
    if extras.OnStart then
        Attempt(extras.OnStart)
    end
    Attempt(function()
        for index = math.max(#alerts - MAX_TOASTS + 1, 1), #alerts do
            ShowToast(alerts[index].text)
        end
    end)
    -- The hub loads before most helpers, so it hears PLAYER_LOGIN before they set up. This first pass
    -- fills the panel with what's ready and keeps quiet about helpers that aren't yet.
    quietStatus = true
    Attempt(OnTick)
    quietStatus = false
    rowsDirty = true
    -- One frame later every helper has run its login code: wrap the commands they registered there and
    -- check them all again, this time reporting real problems.
    C_Timer.After(0, function()
        Attempt(WrapCommands)
        rowsDirty = true
        Attempt(OnTick)
    end)
    C_Timer.NewTicker(1, function()
        Attempt(OnTick)
    end)
end

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN")
for _, name in ipairs({ "BAG_UPDATE_DELAYED", "PLAYER_EQUIPMENT_CHANGED", "QUEST_LOG_UPDATE", "PLAYER_LEVEL_UP", "PLAYER_MONEY",
    "SKILL_LINES_CHANGED", "TRAINER_UPDATE", "PLAYER_REGEN_ENABLED", "PLAYER_ENTERING_WORLD", "UPDATE_INVENTORY_DURABILITY", "PLAYER_XP_UPDATE",
    "TRAIT_CONFIG_UPDATED", "PLAYER_LOGOUT" }) do
    events:RegisterEvent(name)
end
events:SetScript("OnEvent", function(_, event, ...)
    if event == "PLAYER_LOGIN" then
        Start()
    elseif event == "PLAYER_XP_UPDATE" then
        if session.start then
            TrackXP()
        end
    elseif event == "PLAYER_LOGOUT" then
        -- Also fires on /reload: the gold baseline may have been read only after login.
        Attempt(SaveSession)
    else
        if event == "PLAYER_REGEN_ENABLED" and narrationPending then
            NarrationOff()
        end
        if event == "PLAYER_ENTERING_WORLD" then
            local isInitialLogin, isReloadingUi = ...
            Attempt(function()
                ResolveSession(isInitialLogin, isReloadingUi)
            end)
        end
        rowsDirty = true
    end
end)

-- What ForeverHubExtras.lua may use. Getters, because the window and panel are built at login.
extras.Safe = Safe
extras.Tip = Tip
extras.HideTip = HideTip
extras.ShowButtonTip = ShowButtonTip
extras.RunCommand = RunCommand
extras.HELPERS = HELPERS
extras.SECTIONS = SECTIONS
extras.PAGE_BY_LABEL = PAGE_BY_LABEL
extras.PAGE_BY_KEY = PAGE_BY_KEY
extras.TabVisible = TabVisible
extras.SetHelperOff = function(helper, off)
    if db then
        SetHelperOff(helper, off)
    end
end
extras.GetDB = function()
    return db
end
extras.GetFrame = function()
    return frame
end
extras.GetPanel = function()
    return panel
end
extras.OpenPage = function(tab, prefixLines)
    if frame then
        OpenPage(tab, prefixLines)
    end
end
extras.RefreshManage = RefreshManage

SLASH_FOREVERHUB1 = "/hub"
SlashCmdList.FOREVERHUB = function()
    if panel then
        panel:SetShown(not panel:IsShown())
    end
end
